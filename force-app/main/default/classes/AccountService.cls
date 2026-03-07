/**
 * @description Service class responsible for handling Account updates
 * Created Date : Oct 02, 2025
 * Created By   : Sunil Khanchandani
 * 
 * NOTE -System Mode  : DML and SOQL operations are executed for non-admin users who do not have access to Sobject fields. 
 *                      To allow these operations for non-admin users, they must be executed in system context.
 *
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Oct 02, 2025       Sunil Khanchandani       Initial Version
 * V1.O.1       Oct 06, 2025       Shailja Jain             for US OMCT-343(added updateTrainerAccRecord method)
 * V1.0.2       29th Dec 2025      Srinivas Shanigarapu     for US - NGOMCT-235(added logic Update Account Primary_CSM__c based on Account Territory_Alias__c.)
 * V1.0.3       02nd Feb 2026      Jatin Butta              Fix for lead conversion(101 SOQL issue).
 */

public inherited sharing class AccountService {
  public static String errorTagName;
  public static final String STATUS_ACTIVE = 'Active';
  public static final String ROLE_CLINICAL_SERVICES_MANAGER = 'Clinical Services Manager';
  public static final String ACC_TRIGGER_HANDLER = 'AccountTriggerHandler';
  public static final String ACC_SERVICE = 'AccountService';
    // Cache for getConvertedAccounts results within a transaction
    private static Map<Id, Account> convertedAccountsCache = new Map<Id, Account>();

  /**
   * @description  Retrieves Accounts with the given Ids that match the
   *               specified Record Type (e.g., 'Patient').
   *               Uses caching to ensure query runs only once per transaction.
   *
   * @param accountIds    Set of Account record Ids to query.
   * @return              Map of Account Ids to Account records.
   */
  public static Map<Id, Account> getConvertedAccounts(Set<Id> accountIds) {
    if (accountIds == null || accountIds.isEmpty()) {
        return new Map<Id, Account>();
    }

    // Check cache for already queried accounts
    Set<Id> accountIdsToQuery = new Set<Id>();
    Map<Id, Account> resultMap = new Map<Id, Account>();

    for (Id accountId : accountIds) {
        if (convertedAccountsCache.containsKey(accountId)) {
            resultMap.put(accountId, convertedAccountsCache.get(accountId));
        } else {
            accountIdsToQuery.add(accountId);
        }
    }

    // Query only accounts not in cache
    if (!accountIdsToQuery.isEmpty()) {
        List<Account> accounts = [
            SELECT Id, RecordTypeId, FirstName, LastName, MiddleName, PersonContactId, CreatedDate
            FROM Account
            WHERE Id IN :accountIdsToQuery
            WITH SECURITY_ENFORCED
        ];

        // Add to cache and result map
        for (Account acc : accounts) {
            convertedAccountsCache.put(acc.Id, acc);
            resultMap.put(acc.Id, acc);
        }
    }

    return resultMap;
    }

    /**
     * @description  Performs a safe DML update on the provided list of Account
     *               records. Includes exception handling for DML errors and
     *               logs each failed record for easier debugging.
     *
     * @param accountsToUpdate  List of Account records to be updated.
     */
  @TestVisible
  private static void updateAccounts(List<Account> accountsToUpdate) {
    // Proceed only if list has records
    if (accountsToUpdate == null || accountsToUpdate.isEmpty()) {
      return;
    }

    try {
      // Perform partial DML update
      Database.SaveResult[] results = Database.update(accountsToUpdate, false);

      // Iterate through save results and log failures
      for (Integer i = 0; i < results.size(); i++) {
        Database.SaveResult sr = results[i];
        if (!sr.isSuccess()) {
          for (Database.Error err : sr.getErrors()) {
              Logger.error(
                'Failed to update Account record: ' + err.getMessage(), 
                sr
              )
              .setRecord(accountsToUpdate[i])
              .addTag(errorTagName);
          }
        }
        }
          // Covers the exception from the test class
        if (ConstantsUtil.customExceptionSwitch && Test.isRunningTest()) {
            throw new MyCustomException('customExceptionSwitch is turned on');
        }
      } catch (Exception e) {
          // Log exception for debugging and monitoring
          Logger.error('DML Exception while updating Accounts: ' + e.getMessage())
            .addTag(errorTagName);
      }
  }

    /**
     * @description  Sets the Trainer_Type__c on converted Accounts based on the source Lead.
     *               If Lead.Practice__c is populated, assigns the Clinic Contract trainer type;
     *               otherwise assigns the Certified POD trainer type. Operates in bulk and
     *               safely returns when the input collection is null or empty.
     *
     * @param leadRecords  A list of Lead SObjects (typically from trigger context). Each entry is cast to Lead.
     *                     Only records with IsConverted = true and a non-null ConvertedAccountId are processed.
     * @param omctTagName  Tag name for logging context (used in Logger).
     */
  public static void updateTrainerAccRecord(
    List<SObject> leadRecords,
    String omctTagName
  ) {
        if (leadRecords == null || leadRecords.isEmpty()) {
            return;
        }
        Set<Id> accountIdsToUpdate = new Set<Id>();
        Map<Id, String> accountIdToTrainerType = new Map<Id, String>();
        errorTagName = omctTagName;
        for (SObject record : leadRecords) {
            Lead l = (Lead) record;
            if (l.IsConverted && l.ConvertedAccountId != null) {
                String trainerType = (l.Practice__c != null)
                    ? ConstantsUtil.CLINIC_CONTRACT_TRAINER
                    : ConstantsUtil.CERTIFIED_POD_TRAINER;
                accountIdsToUpdate.add(l.ConvertedAccountId);
                accountIdToTrainerType.put(l.ConvertedAccountId, trainerType);
            }
        }
        if (!accountIdsToUpdate.isEmpty()) {
            List<Account> accountsToUpdate = new List<Account>();
            for (Id accId : accountIdsToUpdate) {
                accountsToUpdate.add(
                  new Account(
                    Id = accId,
                    Trainer_Type__c = accountIdToTrainerType.get(accId)
                )
              );
            }
      TriggerHandler.bypass(ACC_TRIGGER_HANDLER);
      updateAccounts(accountsToUpdate);
      TriggerHandler.clearBypass(ACC_TRIGGER_HANDLER);
    }
  }

  /**
   * @description Updates Account.Primary_CSM__c based on Account.Territory_Alias__c.
   * Refactored to reduce cyclomatic complexity by extracting helper methods.
   * @param newAccounts The list of new or updated Account records from the Trigger.new context.
   * @param oldAccountsMap The map of Account records before updates, used to detect field changes.
   */
  public static void updatePrimaryCsmForAccounts(
    List<Account> newAccounts,
    Map<Id, Account> oldAccountsMap
  ) {
    if (newAccounts == null || newAccounts.isEmpty()) {
      return;
    }

    try {
      // Covers the exception from the test class
      if (ConstantsUtil.customExceptionSwitch && Test.isRunningTest()) {
        throw new MyCustomException('customExceptionSwitch is turned on');
      }
      // Filter records that require processing
      Map<Id, String> recordToAlias = filterAccountsByAliasChange(
        newAccounts,
        oldAccountsMap
      );
      if (recordToAlias.isEmpty()) {
        return;
      }

      // Resolve the Alias to User mappings
      Set<String> aliasSet = new Set<String>(recordToAlias.values());
      aliasSet.remove(null);
      Map<String, Id> aliasToUserMap = getAliasToUserMapping(aliasSet);

      // Apply the logic to the records
      applyPrimaryCsmUpdates(newAccounts, recordToAlias, aliasToUserMap);
    } catch (Exception e) {
      Logger.error(
          'Exception while updating Primary CSM field on Account: ' +
          e.getMessage()
        )
        .addTag(ACC_SERVICE);
      Logger.saveLog();
    }
  }

  /**
   * @description Decision logic to identify which accounts had a Territory Alias change.
   * This filters the incoming records to ensure only those with a new or modified
   * alias are processed, reducing unnecessary downstream queries.
   * @param newAccounts The list of current Account records being processed.
   * @param oldAccountsMap The map of prior Account states (Trigger.oldMap).
   * @return A Map of Account IDs to their respective trimmed Territory Alias strings.
   */
  public static Map<Id, String> filterAccountsByAliasChange(
    List<Account> newAccounts,
    Map<Id, Account> oldAccountsMap
  ) {
    Map<Id, String> recordToAlias = new Map<Id, String>();
    for (Account acc : newAccounts) {
      Boolean isInsert = (oldAccountsMap == null);
      String oldAlias = !isInsert
        ? oldAccountsMap.get(acc.Id).Territory_Alias__c
        : null;

      if (isInsert || acc.Territory_Alias__c != oldAlias) {
        String trimmedAlias = String.isNotBlank(acc.Territory_Alias__c)
          ? acc.Territory_Alias__c.trim()
          : null;
        recordToAlias.put(acc.Id, trimmedAlias);
      }
    }
    return recordToAlias;
  }

  /**
   * @description Queries UserTerritory2Association to find the oldest CSM per alias.
   * This method performs a bulkified query against Territory2 and User associations
   * to resolve which User should be assigned as the Primary CSM for a given alias.
   * @param aliases A set of unique Territory2 DeveloperNames (aliases) to resolve.
   * @return A Map where the key is the Territory Alias (String) and the value is the User ID (Id) of the oldest CSM.
   */
  public static Map<String, Id> getAliasToUserMapping(Set<String> aliases) {
    Map<String, Id> aliasToUser = new Map<String, Id>();
    if (aliases.isEmpty()) {
      return aliasToUser;
    }

    // Bulkified SOQL with sorting to ensure the oldest association is picked
    for (UserTerritory2Association uta : [
      SELECT UserId, Territory2.DeveloperName
      FROM UserTerritory2Association
      WHERE
        Territory2.DeveloperName IN :aliases
        AND Territory2.Territory2Model.State = :STATUS_ACTIVE
        AND RoleInTerritory2 = :ROLE_CLINICAL_SERVICES_MANAGER
        AND User.IsActive = TRUE
        AND IsActive = TRUE
      WITH SYSTEM_MODE
      ORDER BY LastModifiedDate ASC
    ]) {
      if (!aliasToUser.containsKey(uta.Territory2.DeveloperName)) {
        aliasToUser.put(uta.Territory2.DeveloperName, uta.UserId);
      }
    }
    return aliasToUser;
  }

  /**
   * @description Final application of field updates and error handling.
   * Iterates through the targeted accounts to assign the resolved Primary CSM
   * or apply a field-level error if no mapping was found.
   * @param accounts The list of Account records to be updated.
   * @param recordToAlias A map linking Account IDs to their designated Territory Alias.
   * @param aliasToUser A map linking Territory Aliases to the resolved User IDs of the CSMs.
   */
  @TestVisible
  private static void applyPrimaryCsmUpdates(
    List<Account> accounts,
    Map<Id, String> recordToAlias,
    Map<String, Id> aliasToUser
  ) {
    for (Account acc : accounts) {
      if (!recordToAlias.containsKey(acc.Id)) {
        continue;
      }

      String aliasVal = recordToAlias.get(acc.Id);
      if (String.isBlank(aliasVal) || !aliasToUser.containsKey(aliasVal)) {
        acc.Primary_CSM__c = null;
      } else if (aliasToUser.containsKey(aliasVal)) {
        acc.Primary_CSM__c = aliasToUser.get(aliasVal);
      }
        }
    }

    /**
     * @description Exception class for Account Service
     */
    public class MyCustomException extends Exception {
    }
}