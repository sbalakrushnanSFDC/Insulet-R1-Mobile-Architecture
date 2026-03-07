/**
 * @description Batch class that processes AccountHistory records to sync
 *              Territory_Alias__c from Practice (Account) to Person Accounts(Patient, Trainer).
 *              This batch queries AccountHistory records where Territory_Alias__c field
 *              changed in the last 24 hours, then updates related Person accounts(Patient, Trainer)
 *              through primary AccountContactRelation records.
 *
 * @author      Niranjan Elangovan
 * @createdDate November 16, 2025
 *
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Nov 16, 2025        Niranjan Elangovan      Initial Version
 * V1.0.1       29th Dec 2025       Srinivas Shanigarapu    Updated(US - NGOMCT-235)
 */
public class TerritoryAliasSyncBatch implements Database.Batchable<sObject>, Database.Stateful {
  private Integer successCount = 0;
  private Integer errorCount = 0;
  private static final String TAG_NAME = 'TerritoryAliasSyncBatch';
  @TestVisible
  private static Boolean isTestMode = false;

  /**
   * @description Start method to query AccountContactRelation records for Practice accounts
   *              where Territory_Alias__c field was modified in the last 24 hours.
   *              This approach handles scenarios where a single Practice can have
   *              50k+ Person Account(Patient, Trainer) relationships.
   * @param bc Database.BatchableContext
   * @return Database.QueryLocator containing AccountContactRelation records
   */
  public Database.QueryLocator start(Database.BatchableContext bc) {
    DateTime last24Hours = DateTime.now().addHours(-24);
    // First, get Practice Account IDs that had Territory_Alias__c changes in last 24 hours
    Set<Id> practiceAccountIds = new Set<Id>();

    for (AccountHistory history : [
      SELECT AccountId, NewValue
      FROM AccountHistory
      WHERE
        Field = :ConstantsUtil.LEAD_TERRITORY_ALIAS
        AND CreatedDate >= :last24Hours
        AND Account.RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT
      ORDER BY createddate DESC
    ]) {
      if (history.NewValue != null) {
        practiceAccountIds.add(history.AccountId);
      }
    }
    if (Test.isRunningTest() && isTestMode) {
      for (Account obj : [SELECT Id FROM Account LIMIT 2]) {
        practiceAccountIds.add(obj.Id);
      }
    }
    Logger.info(
        'Starting TerritoryAliasSyncBatch. Found ' +
          practiceAccountIds.size() +
          ' Practice accounts with Territory_Alias__c changes in last 24 hours'
      )
      .addTag(TAG_NAME);

    // Query AccountContactRelation records for those Practice accounts
    // This allows processing 50k+ relationships in batches
    String query =
      'SELECT Id, AccountId, ContactId, Is_Primary__c, ' +
      'Account.Territory_Alias__c, Contact.AccountId, Contact.Account.Territory_Alias__c, ' +
      'Contact.Account.RecordTypeId, Contact.Account.PersonContactId, Contact.Account.Trainer_Type__c' +
      ' FROM AccountContactRelation ' +
      'WHERE AccountId IN :practiceAccountIds ' +
      'AND Is_Primary__c = true ' +
      'AND Contact.AccountId != null';
    return Database.getQueryLocator(query);
  }

  /**
   * @description Execute method processes each batch of AccountContactRelation records
   *              and updates related Person accounts(Patient,Trainer) with Territory_Alias__c from Practice accounts.
   *              This method is designed to handle 50k+ ACR records efficiently.
   * @param bc Database.BatchableContext
   * @param scope List of AccountContactRelation records to process
   */
  public void execute(
    Database.BatchableContext bc,
    List<AccountContactRelation> scope
  ) {
    List<AccountWrapper> accountsToUpdate = buildAccountsToUpdate(scope);
    if (accountsToUpdate.isEmpty()) {
      Logger.info(
          'No Person accounts need Territory_Alias__c updates in this batch'
        )
        .addTag(TAG_NAME);
      return;
    }
    if (!accountsToUpdate.isEmpty()) {
      updatePersonAccounts(accountsToUpdate);
    }
  }

  /**
   * @description Builds list of Person accounts(Patient,Trainer) that need Territory_Alias__c updates
   * @param scope List of AccountContactRelation records to process
   * @return List of Account records to update
   */
  private List<AccountWrapper> buildAccountsToUpdate(
    List<AccountContactRelation> scope
  ) {
    List<AccountWrapper> accountsToUpdate = new List<AccountWrapper>();
    Set<Id> processedPersonAccountIds = new Set<Id>();
    for (AccountContactRelation acr : scope) {
      processAccountContactRelation(
        acr,
        accountsToUpdate,
        processedPersonAccountIds
      );
    }
    return accountsToUpdate;
  }

  /**
   * @description Processes a single AccountContactRelation record and adds to update list if needed
   * @param acr AccountContactRelation record to process
   * @param accountsToUpdate List of accounts to update
   * @param processedPersonAccountIds Set of already processed person account IDs
   */
  private void processAccountContactRelation(
    AccountContactRelation acr,
    List<AccountWrapper> accountsToUpdate,
    Set<Id> processedPersonAccountIds
  ) {
    if (!isValidAccountContactRelation(acr)) {
      return;
    }
    Id personAccountId = acr.Contact.AccountId;
    if (processedPersonAccountIds.contains(personAccountId)) {
      return;
    }
    if (needsTerritoryUpdate(acr)) {
      AccountWrapper accountData = new AccountWrapper();
      accountData.accountId = personAccountId;
      accountData.territoryAlias = acr.Account.Territory_Alias__c;
      accountData.recordTypeId = acr.Contact.Account.RecordTypeId;
      accountData.personContactId = acr.Contact.Account.PersonContactId;
      accountData.trainerType = acr.Contact.Account.Trainer_Type__c;

      accountsToUpdate.add(accountData);
      processedPersonAccountIds.add(personAccountId);
    }
  }

  /**
   * @description Filters Accounts eligible for territory assignment
   * @param accs List of Account records to evaluate
   * @return List<Account> Eligible Accounts
   */
  private static List<Account> filterEligibleAccounts(
    List<AccountWrapper> accs
  ) {
    List<AccountWrapper> eligibleAccounts = new List<AccountWrapper>();
    List<AccountWrapper> trainerAccounts = new List<AccountWrapper>();
    Set<Id> trainerContactIds = new Set<Id>();

    // Separate Trainer and non-Trainer accounts
    for (AccountWrapper acc : accs) {
      if (acc.recordTypeId == ConstantsUtil.ACCOUNT_TRAINER_RT) {
        if (acc.personContactId != null) {
          trainerContactIds.add(acc.personContactId);
        }
        trainerAccounts.add(acc);
      } else {
        // Non-trainer accounts are always eligible
        eligibleAccounts.add(acc);
      }
    }

    //Defaulting to FALSE ensures: Contacts with ZERO ACRs remain ineligible
    Map<Id, Boolean> trainerEligibilityMap = new Map<Id, Boolean>();
    for (Id contactId : trainerContactIds) {
      trainerEligibilityMap.put(contactId, false);
    }

    // Any contact having a PRIMARY Trainer ACR becomes eligible
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
        trainerEligibilityMap.put(contactId, true);
      }
    }

    // Apply eligibility rules to Trainer accounts
    for (AccountWrapper accRec : trainerAccounts) {
      // Clinic Contract Trainer  always eligible
      if (accRec.trainerType == ConstantsUtil.CLINIC_CONTRACT_TRAINER) {
        eligibleAccounts.add(accRec);
      }
      // Combined Trainer eligible only if primary ACR exists
      else if (
        accRec.trainerType ==
        ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER &&
        trainerEligibilityMap.get(accRec.personContactId) == true
      ) {
        eligibleAccounts.add(accRec);
      }
    }

    //Preparing list of Accounts to update
    List<Account> accountsToUpdate = new List<Account>();
    for (AccountWrapper accData : eligibleAccounts) {
      accountsToUpdate.add(
        new Account(
          Id = accData.accountId,
          Territory_Alias__c = accData.territoryAlias
        )
      );
    }
    return accountsToUpdate;
  }

  /**
   * @description Validates if AccountContactRelation has all required fields populated
   * @param acr AccountContactRelation record to validate
   * @return Boolean true if all required fields are present
   */
  private Boolean isValidAccountContactRelation(AccountContactRelation acr) {
    return acr.Contact != null &&
      acr.Contact.AccountId != null &&
      acr.Account != null &&
      acr.Account.Territory_Alias__c != null;
  }

  /**
   * @description Checks if Person Account needs Territory_Alias__c update
   * @param acr AccountContactRelation record to check
   * @return Boolean true if territory update is needed
   */
  private Boolean needsTerritoryUpdate(AccountContactRelation acr) {
    String practiceTerritory = acr.Account.Territory_Alias__c;
    String personAccountTerritory = acr.Contact.Account.Territory_Alias__c;
    return practiceTerritory != personAccountTerritory;
  }

  /**
   * @description Updates Person Account(Patient,Trainer) records with new Territory_Alias__c values
   * @param accountsToUpdate List of Patient Account records to update
   */
  private void updatePersonAccounts(List<AccountWrapper> accountsToUpdate) {
    List<Account> accountRecs = filterEligibleAccounts(accountsToUpdate);

    if (accountRecs.isEmpty()) {
      return;
    }
    Database.SaveResult[] results = Database.update(accountRecs, false);
    // Process results and log any failures
    for (Integer i = 0; i < results.size(); i++) {
      Database.SaveResult sr = results[i];
      if (sr.isSuccess()) {
        successCount++;
      } else {
        errorCount++;
        for (Database.Error err : sr.getErrors()) {
          Logger.error(
              'Failed to update Person Account: ' + err.getMessage(),
              sr
            )
            .setRecord(accountRecs[i])
            .addTag(TAG_NAME);
        }
      }
    }
  }

  /**
   * @description Finish method logs the batch execution summary
   * @param bc Database.BatchableContext
   */
  public void finish(Database.BatchableContext bc) {
    // Query batch job status
    AsyncApexJob job = [
      SELECT
        Id,
        Status,
        NumberOfErrors,
        JobItemsProcessed,
        TotalJobItems,
        CreatedBy.Email
      FROM AsyncApexJob
      WHERE Id = :bc.getJobId()
    ];
    String summary =
      'TerritoryAliasSyncBatch completed. ' +
      'Success: ' +
      successCount +
      ', Errors: ' +
      errorCount +
      ', Job Status: ' +
      job.Status +
      ', Items Processed: ' +
      job.JobItemsProcessed +
      ', Total Items: ' +
      job.TotalJobItems;
    Logger.info(summary).addTag(TAG_NAME);
    Logger.saveLog();
  }

  /**
   * @description Wrapper class to store account data
   */
  public class AccountWrapper {
    public Id accountId;
    public String territoryAlias;
    public Id recordTypeId;
    public Id personContactId;
    public String trainerType;
  }
}