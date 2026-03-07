/**
 * @author      : Jatin Butta
 * @created Date: 17th Nov 2025
 * @description : Service class to handle Territory Alias updates.
 *                Used by both Account and Lead batch classes to avoid code duplication.
 * 
 * NOTE -System Mode  : DML and SOQL operations are executed for non-admin users who do not have access to Sobject fields. 
 *                      To allow these operations for non-admin users, they must be executed in system context.
 * 
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       17th Nov 2025       Jatin Butta             Initial Version (US - NGASIM-1166)
 * V1.0.1       29th Dec 2025       Srinivas Shanigarapu    Updated(US - NGOMCT-235)
 */
public inherited sharing class TerritoryAliasService {
  private static final String TAG_NAME = ConstantsUtil.ASIM_TAG;

  /**
   * @description Wrapper class to return update results with success count
   */
  public class UpdateResult {
    /**
     * @description Number of successfully updated records
     */
    public Integer successCount { get; set; }

    /**
     * @description Constructor initializes success count to zero
     */
    public UpdateResult() {
      this.successCount = 0;
    }
  }

  /**
   * @description Get zip codes that had Territory_Name__c changes in the last 24 hours
   * @return Set of changed zip code values
   */
  public static Set<String> getChangedZipCodesToday() {
    DateTime last24Hours = DateTime.now().addHours(-24);
    List<ZipCode__History> zipCodeHistories = queryZipCodeHistory(last24Hours);
    return processZipCodeHistories(zipCodeHistories);
  }

  /**
   * @description Process zip code history records and extract changed zip codes
   * @param zipCodeHistories List of ZipCode__History records to process
   * @return Set of changed zip code values
   */
  @TestVisible
  private static Set<String> processZipCodeHistories(
    List<ZipCode__History> zipCodeHistories
  ) {
    Set<String> changedZipCodes = new Set<String>();
    if (zipCodeHistories.isEmpty()) {
      return changedZipCodes;
    }

    // Get the ZipCode__c records that changed
    Set<Id> zipCodeIds = extractZipCodeIds(zipCodeHistories);

    // Query the ZipCode__c records to get their Name (zip code value)
    List<ZipCode__c> zipCodes = queryZipCodesByIds(zipCodeIds);

    // Extract zip code names
    for (ZipCode__c zipCode : zipCodes) {
      if (String.isNotBlank(zipCode.Name)) {
        changedZipCodes.add(zipCode.Name);
      }
    }
    return changedZipCodes;
  }

  /**
   * @description Query ZipCode history records for Territory_Name__c changes in the last 24 hours
   * @param last24Hours The datetime threshold for querying history records
   * @return List of history records
   */
  @TestVisible
  private static List<ZipCode__History> queryZipCodeHistory(
    DateTime last24Hours
  ) {
    return [
      SELECT ParentId, NewValue, OldValue, CreatedDate, Field
      FROM ZipCode__History
      WHERE
        Field = :ConstantsUtil.ZIPCODE_TERRITORY_NAME_FIELD
        AND CreatedDate >= :last24Hours
      WITH SECURITY_ENFORCED
      ORDER BY CreatedDate DESC
    ];
  }

  /**
   * @description Extract parent IDs from history records
   * @param zipCodeHistories List of history records
   * @return Set of ZipCode__c IDs
   */
  @TestVisible
  private static Set<Id> extractZipCodeIds(
    List<ZipCode__History> zipCodeHistories
  ) {
    Set<Id> zipCodeIds = new Set<Id>();
    for (ZipCode__History history : zipCodeHistories) {
      zipCodeIds.add(history.ParentId);
    }
    return zipCodeIds;
  }

  /**
   * @description Query ZipCode records by IDs
   * @param zipCodeIds Set of ZipCode__c IDs
   * @return List of ZipCode__c records
   */
  @TestVisible
  private static List<ZipCode__c> queryZipCodesByIds(Set<Id> zipCodeIds) {
    return [
      SELECT Id, Name
      FROM ZipCode__c
      WHERE Id IN :zipCodeIds
      WITH SECURITY_ENFORCED
    ];
  }

  /**
   * @description Get Territory Alias mapping for zip codes
   * @param zipCodes Set of zip code values
   * @return Map of zip code to Territory Alias
   */
  public static Map<String, String> getTerritoryAliasMapping(
    Set<String> zipCodes
  ) {
    Map<String, String> zipToTerritoryAliasMap = new Map<String, String>();
    if (zipCodes == null || zipCodes.isEmpty()) {
      return zipToTerritoryAliasMap;
    }

    // Query ZipCode__c records with Territory information
    List<ZipCode__c> zipCodeRecords = [
      SELECT Name, Territory_Name__r.Territory_Developer_Name__c
      FROM ZipCode__c
      WHERE
        Name IN :zipCodes
        AND Territory_Name__r.Territory_Developer_Name__c != NULL
      WITH SECURITY_ENFORCED
    ];

    for (ZipCode__c zipCode : zipCodeRecords) {
      if (
        String.isNotBlank(zipCode.Name) &&
        String.isNotBlank(zipCode.Territory_Name__r.Territory_Developer_Name__c)
      ) {
        zipToTerritoryAliasMap.put(
          zipCode.Name,
          zipCode.Territory_Name__r.Territory_Developer_Name__c
        );
      }
    }
    return zipToTerritoryAliasMap;
  }

  /**
   * @description Update Territory_Alias__c on Account records
   * @param accounts List of Account records
   * @param zipToTerritoryAliasMap Map of zip code to Territory Alias
   * @return UpdateResult with success and error counts
   */
  public static UpdateResult updateAccountTerritoryAlias(
    List<Account> accounts,
    Map<String, String> zipToTerritoryAliasMap
  ) {
    List<Account> accountsToUpdate = new List<Account>();
    UpdateResult result = new UpdateResult();
    if (
      accounts == null ||
      accounts.isEmpty() ||
      zipToTerritoryAliasMap == null
    ) {
      return result;
    }

    accounts = filterEligibleTrainers(accounts);
    for (Account acc : accounts) {
      String billingZip = acc.BillingPostalCode;

      if (
        String.isNotBlank(billingZip) &&
        zipToTerritoryAliasMap.containsKey(billingZip)
      ) {
        String newTerritoryAlias = zipToTerritoryAliasMap.get(billingZip);

        // Only update if the value has changed
        if (acc.Territory_Alias__c != newTerritoryAlias) {
          acc.Territory_Alias__c = newTerritoryAlias;
          accountsToUpdate.add(acc);
        }
      }
    }

    if (!accountsToUpdate.isEmpty()) {
      return performDMLUpdate(accountsToUpdate, 'Account');
    }
    return result;
  }

  /**
   * @description Filters Accounts eligible for territory assignment based on Trainer Type
   * @param accs List of Account records to evaluate
   * @return List<Account> Eligible Accounts
   */
  @TestVisible
  private static List<Account> filterEligibleTrainers(List<Account> accs) {
    List<Account> eligibleAccounts = new List<Account>();
    List<Account> trainerAccounts = new List<Account>();
    Set<Id> trainerContactIds = new Set<Id>();

    // Separate Trainer and non-Trainer accounts
    for (Account acc : accs) {
      if (acc.RecordTypeId == ConstantsUtil.ACCOUNT_TRAINER_RT) {
        if (acc.PersonContactId != null) {
          trainerContactIds.add(acc.PersonContactId);
        }
        trainerAccounts.add(acc);
      } else {
        // Non-trainer accounts are always eligible
        eligibleAccounts.add(acc);
      }
    }

    //Defaulting to TRUE ensures: Contacts with ZERO ACRs remain eligible
    Map<Id, Boolean> trainerEligibilityMap = new Map<Id, Boolean>();
    for (Id contactId : trainerContactIds) {
      trainerEligibilityMap.put(contactId, true);
    }

    // Any contact having a PRIMARY Trainer ACR becomes ineligible
    for (AggregateResult ar : [
      SELECT ContactId cId, COUNT(Id) cnt
      FROM AccountContactRelation
      WHERE
        ContactId IN :trainerContactIds
        AND Roles = :ConstantsUtil.ACR_ROLE_TRAINER
        AND Is_Primary__c = TRUE
      WITH SYSTEM_MODE
      GROUP BY ContactId
    ]) {
      Id contactId = (Id) ar.get('cId');
      if (((Integer) ar.get('cnt')) > 0) {
        trainerEligibilityMap.put(contactId, false);
      }
    }

    // Apply eligibility rules to Trainer accounts
    for (Account accRec : trainerAccounts) {
      // Certified POD Trainer  always eligible
      if (accRec.Trainer_Type__c == ConstantsUtil.CERTIFIED_POD_TRAINER) {
        eligibleAccounts.add(accRec);
      }
      // Combined Trainer eligible only if no primary ACR exists
      else if (
        accRec.Trainer_Type__c ==
        ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER &&
        trainerEligibilityMap.get(accRec.PersonContactId) == true
      ) {
        eligibleAccounts.add(accRec);
      }
    }
    return eligibleAccounts;
  }

  /**
   * @description Update Territory_Alias__c on Lead records
   * @param leads List of Lead records
   * @param zipToTerritoryAliasMap Map of zip code to Territory Alias
   * @return UpdateResult with success and error counts
   */
  public static UpdateResult updateLeadTerritoryAlias(
    List<Lead> leads,
    Map<String, String> zipToTerritoryAliasMap
  ) {
    List<Lead> leadsToUpdate = new List<Lead>();
    UpdateResult result = new UpdateResult();

    if (leads == null || leads.isEmpty() || zipToTerritoryAliasMap == null) {
      return result;
    }

    for (Lead ld : leads) {
      String postalCode = ld.PostalCode;

      if (
        String.isNotBlank(postalCode) &&
        zipToTerritoryAliasMap.containsKey(postalCode)
      ) {
        String newTerritoryAlias = zipToTerritoryAliasMap.get(postalCode);

        // Only update if the value has changed
        if (ld.Territory_Alias__c != newTerritoryAlias) {
          ld.Territory_Alias__c = newTerritoryAlias;
          leadsToUpdate.add(ld);
        }
      }
    }

    if (!leadsToUpdate.isEmpty()) {
      return performDMLUpdate(leadsToUpdate, 'Lead');
    }
    return result;
  }

  /**
   * @description Perform DML update with error handling
   * @param records List of SObject records to update
   * @param objectName Name of the object (for logging)
   * @return UpdateResult with success count
   */
  @TestVisible
  private static UpdateResult performDMLUpdate(
    List<SObject> records,
    String objectName
  ) {
    UpdateResult result = new UpdateResult();

    try {
      Database.SaveResult[] results = Database.update(records, false);

      // Process results and log any failures
      for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
          result.successCount++;
        } else {
          for (Database.Error error : results[i].getErrors()) {
            // Log detailed error with Logger framework
            Logger.error(
                'Error updating ' +
                  objectName +
                  ' ' +
                  records[i].Id +
                  ': ' +
                  error.getStatusCode() +
                  ' - ' +
                  error.getMessage()
              )
              .setRecord(records[i])
              .addTag(TAG_NAME);
          }
        }
      }
    } catch (Exception ex) {
      Logger.error(
          'DML Exception while updating ' + objectName + ': ' + ex.getMessage(),
          ex
        )
        .addTag(TAG_NAME);
    } finally {
      Logger.saveLog();
    }
    return result;
  }
}