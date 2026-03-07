/**
 * @author          :       Sunil Khanchandani
 * @createdDate     :       15th Oct 2025
 * @description
 *  This class is responsible for creating or updating Healthcare Provider records
 *  when a Patient or Provider Account record is created or updated.
 *  It handles both Person Accounts (Providers) and Business Accounts (Practices)
 *  to ensure that HealthcareProvider data remains synchronized and up to date.
 * ============================ Logs =============================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       15th Oct 2025       Sunil Khanchandani            Initial Version
 */

public inherited sharing class HealthCareProviderService {


    // ProviderType picklist values
    private static final String PROVIDER_TYPE_PHYSICIAN = 'Physician';
    private static final String PROVIDER_TYPE_PRACTICE = 'Practice';

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null for permission errors)
     */
    private static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    /**
     * @description Logs debug messages using Logger framework
     * @param message The debug message
     */
    private static void logDebug(String message) {
        Logger.debug(message);
        Logger.saveLog();
    }


    /**
     * @description
     *  Handles the creation of new Healthcare Provider records when new Account records are inserted.
     *  It identifies eligible Provider and Practice type Accounts, prepares corresponding HealthcareProvider
     *  records, and performs upsert operations to maintain data consistency.
     * @param newAccountList
     *  List of newly inserted Account records that need to be processed for HealthcareProvider creation.
     */
    public static void processNewHealthCareRecords(List<Account> newAccountList) {
        // Guard clause to exit early if input list is null or empty
        if (newAccountList == null || newAccountList.isEmpty()) {
            return;
        }

        // Prepare HealthcareProvider records from the new Account list
        List<HealthcareProvider> healthCareRecordsToInsert = prepareHealthCareRecords(newAccountList);

        // Perform  insert HealthcareProvider records
        insertHealthcareProviders(healthCareRecordsToInsert);
    }

    /**
     * @description
     *  Prepares a list of HealthcareProvider records derived from newly inserted Accounts.
     *  Determines whether each Account represents a Provider or Practice and constructs
     *  the appropriate HealthcareProvider record accordingly.
     * @param newAccountList
     *  List of Account records used to create corresponding HealthcareProvider records.
     * @return List<HealthcareProvider>
     *  Returns a list of HealthcareProvider records to be upserted.
     */
    private static List<HealthcareProvider> prepareHealthCareRecords(List<Account> newAccountList) {
        List<HealthcareProvider> healthCareRecordsList = new List<HealthcareProvider>();

        // Loop through each Account to classify and create HealthcareProvider records
        for (Account accountRecord : newAccountList) {
            if (isProviderAccount(accountRecord)) {
                // Build HealthcareProvider record for Provider type Account
                healthCareRecordsList.add(buildProviderHealthcareProvider(accountRecord));
            } else if (isPracticeAccount(accountRecord)) {
                // Build HealthcareProvider record for Practice type Account
                healthCareRecordsList.add(buildPracticeHealthcareProvider(accountRecord));
            }
        }

        return healthCareRecordsList;
    }

    /**
     * @description
     *  Processes Account updates to synchronize corresponding HealthcareProvider__c records.
     *  When an Account name is changed or when new qualifying Provider or Practice Accounts appear,
     *  this method identifies those Accounts, classifies them as Provider or Practice, and
     *  triggers updates for related HealthcareProvider records.
     *
     * @param newAccountList
     *  List of updated Account records from the trigger context (Trigger.new).
     *
     * @param oldAccountMap
     *  Map of previous Account records keyed by Id (Trigger.oldMap), used to compare name changes.
     *
     */
    public static void processHealthcareProvidersOnAccountUpdate(
        List<Account> newAccountList,
        Map<Id, Account> oldAccountMap
    ) {
        // Exit early if no Accounts are provided
        if (newAccountList == null || newAccountList.isEmpty()) {
            return;
        }

        // Maps to hold categorized Accounts by type
        Map<Id, Account> personContactIdAccountMap = new Map<Id, Account>();
        Map<Id, Account> practiceAccountIdAccountMap = new Map<Id, Account>();

        // Iterate through updated Accounts and identify those with name changes
        for (Account updatedAccount : newAccountList) {
            Account oldAccount = oldAccountMap != null ? oldAccountMap.get(updatedAccount.Id) : null;

            // Skip processing if Account name has not changed
            if (!hasNameChanged(updatedAccount, oldAccount)) {
                continue;
            }

            // Categorize the Account as Provider or Practice
            if (isProviderAccount(updatedAccount)) {
                personContactIdAccountMap.put(updatedAccount.PersonContactId, updatedAccount);
            } else if (isPracticeAccount(updatedAccount)) {
                practiceAccountIdAccountMap.put(updatedAccount.Id, updatedAccount);
            }
        }

        // Process and update existing Healthcare Provider records based on Account changes
        processExistingHealthcareProviders(personContactIdAccountMap, practiceAccountIdAccountMap);
    }



    /**
     * @description
     * Processes existing HealthcareProvider records based on updated Account data.
     * This method retrieves Healthcare Provider records that match either Person Contact Ids
     * or Practice Account Ids, rebuilds them with updated Account information, and performs
     * upsert operations to ensure data consistency.
     * @param personContactIdAccountMap
     * Map of Person Contact Ids and their corresponding Account records.
     * @param practiceAccountIdAccountMap
     * Map of Practice Account Ids and their corresponding Account records.
     */
    private static void processExistingHealthcareProviders(
        Map<Id, Account> personContactIdAccountMap,
        Map<Id, Account> practiceAccountIdAccountMap
    ) {
        // Check if there are any providers or practices to process
        Boolean hasProviders = personContactIdAccountMap != null && !personContactIdAccountMap.isEmpty();
        Boolean hasPractices = practiceAccountIdAccountMap != null && !practiceAccountIdAccountMap.isEmpty();
        if (!hasProviders && !hasPractices) {
            return;
        }

        // Fetch existing Healthcare Provider records based on provided Account mappings
        List<HealthcareProvider> existingHealthCareProviders = fetchHealthcareProviders(
            personContactIdAccountMap,
            practiceAccountIdAccountMap
        );

        // Build or update Healthcare Provider records with Account information
        List<HealthcareProvider> recordsToUpdate = buildExistingHealthcareProviders(
            existingHealthCareProviders,
            personContactIdAccountMap,
            practiceAccountIdAccountMap
        );

        // Perform update if there are records to process
        if (!recordsToUpdate.isEmpty()) {
            updateHealthcareProviders(recordsToUpdate);
        }
    }

    /**
     * @description
     *  Performs update operation on a list of HealthcareProvider records.
     *  Ensures that the running user has appropriate create and update permissions
     *  before attempting the DML operation. Logs any errors encountered during processing.
     *
     * @param healthCareProviders
     *  List of HealthcareProvider records to be updated.
     *
     */
    @TestVisible
    private static void updateHealthcareProviders(List<HealthcareProvider> healthCareProviders) {

        // Exit if the list is empty
        if (healthCareProviders.isEmpty()) {
            return;
        }

        // Check for object-level CRUD permissions before performing DML
        if (!Schema.SObjectType.HealthcareProvider.isUpdateable()) {
            logDebug('User does not have permission to update Health Care Provider records');
            return;
        }

        // Perform safe update in user mode and handle any DML exceptions
        try {
            Database.update(healthCareProviders, AccessLevel.USER_MODE);

            /**
            * when customExceptionSwitch static variable is turned on
            * it covers exceptions in test coverage
            */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on');
            }
        } catch (Exception ex) {
            logError('Failed to update Health Care Provider records', healthCareProviders, ex);
            return;
        }
    }

    /**
     * @description
     *  Performs insert operation on a list of HealthcareProvider records.
     *  Ensures that the running user has appropriate create and update permissions
     *  before attempting the DML operation. Logs any errors encountered during processing.
     * @param healthCareProviders
     *  List of HealthcareProvider records to be inserted.
     */
    private static void insertHealthcareProviders(List<HealthcareProvider> healthCareProviders) {
        // Check for object-level CRUD permissions before performing DML
        if (!Schema.SObjectType.HealthcareProvider.isCreateable()) {
            logDebug('User does not have permission to insert Health Care Provider records');
            return;
        }
        // Exit if the list is empty
        if (healthCareProviders.isEmpty()) {
            return;
        }

        // Perform safe upsert in user mode and handle any DML exceptions
        try {
            Database.insert(healthCareProviders, AccessLevel.USER_MODE);
        } catch (DmlException ex) {
            logError('Failed to insert Health Care Provider records', healthCareProviders, ex);
            return;
        }
    }

    /**
     * @description
     *  Determines whether the provided Account record represents a Provider-type Account.
     *  A Provider Account is defined as a Person Account with the Provider Record Type.
     *
     * @param acct
     *  Account record to evaluate.
     *
     * @return Boolean
     *  Returns true if the Account is a Provider Account; otherwise, false.
     */
    private static Boolean isProviderAccount(Account acct) {
        Id providerRtId = ConstantsUtil.ACCOUNT_PROVIDER_RT;
        return acct.RecordTypeId == providerRtId && acct.IsPersonAccount == true;
    }

    /**
     * @description
     *  Determines whether the provided Account record represents a Practice-type Account.
     *  A Practice Account is defined as a Business Account with the Practice Record Type.
     *
     * @param acct
     *  Account record to evaluate.
     *
     * @return Boolean
     *  Returns true if the Account is a Practice Account; otherwise, false.
     */
    private static Boolean isPracticeAccount(Account acct) {
        Id practiceRtId = ConstantsUtil.ACCOUNT_PRACTICE_RT;
        return acct.RecordTypeId == practiceRtId && (acct.IsPersonAccount == null || acct.IsPersonAccount == false);
    }

    /**
     * @description
     *  Checks whether the Account name has changed between the old and new Account versions.
     *  Used to determine whether a related HealthcareProvider__c record should be updated.
     *
     * @param newAcct
     *  The updated Account record (Trigger.new context).
     *
     * @param oldAcct
     *  The previous Account record (Trigger.old context).
     *
     * @return Boolean
     *  Returns true if the Account name has changed or if the old Account is null.
     */
    private static Boolean hasNameChanged(Account newAcct, Account oldAcct) {
        if (oldAcct == null) {
            return true;
        }
        return ((newAcct.Name!=null && newAcct.Name != oldAcct.Name) || (newAcct.FirstName!=oldAcct.FirstName ||newAcct.LastName!=oldAcct.LastName));
    }

    /**
     * @description   Fetches Healthcare Provider records that match given Person Contact Ids
     *                and/or Practice Account Ids dynamically.
     * @param         personContactIdToAccountMap - Map of Person Contact Ids to their related Accounts.
     * @param         practiceAccountIdToAccountMap - Map of Practice Account Ids to their related Accounts.
     * @return        List<Healthcare_Provider__c> - List of matching Healthcare Provider records.
     */
    public static List<HealthcareProvider> fetchHealthcareProviders(
        Map<Id, Account> personContactIdToAccountMap,
        Map<Id, Account> practiceAccountIdToAccountMap
    ) {
        List<HealthcareProvider> healthcareProviders = new List<HealthcareProvider>();

        // Collect Ids for filtering
        Set<Id> personContactIds = (personContactIdToAccountMap != null)
            ? personContactIdToAccountMap.keySet()
            : new Set<Id>();

        Set<Id> practiceAccountIds = (practiceAccountIdToAccountMap != null)
            ? practiceAccountIdToAccountMap.keySet()
            : new Set<Id>();

        // Early return if no conditions to avoid invalid WHERE
        if (personContactIds.isEmpty() && practiceAccountIds.isEmpty()) {
        return healthcareProviders;
        }

        // Combine conditions dynamically
        String finalQuery = buildQuery(personContactIds,practiceAccountIds);
        try{
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on');
            }

            healthcareProviders = Database.query(finalQuery);
        } catch (Exception ex) {
            logError('Failed to fetch Health Care Provider records', healthCareProviders, ex);

        }
        return healthcareProviders;

    }

    /**
     * @description
     *  Builds a dynamic WHERE clause for querying HealthcareProvider__c records.
     *  The method evaluates the provided sets of Person Contact Ids and Practice Account Ids,
     *  and constructs a SOQL WHERE condition that filters HealthcareProvider__c records
     *  based on matching PractitionerId and/or AccountId values.
     *  @param personContactIds -
     *  Set of Person Contact record Ids used to filter HealthcareProvider__c records by PractitionerId.
     * @param practiceAccountIds -
     *  Set of Practice Account record Ids used to filter HealthcareProvider__c records by AccountId.
     * @return String
     *  Returns a dynamically constructed WHERE clause string for SOQL query execution.
     */
    private static List<String> buildWhereCondition(Set<Id> personContactIds, Set<Id> practiceAccountIds) {
        List<String> conditions = new List<String>();

        // Add condition for PractitionerId if personContactIds are provided
    if (!personContactIds.isEmpty()) {
        conditions.add('PractitionerId IN (' + wrapSetValues(personContactIds) + ')');
    }

    // Add condition for AccountId if practiceAccountIds are provided
    if (!practiceAccountIds.isEmpty()) {
        conditions.add('AccountId IN (' + wrapSetValues(practiceAccountIds) + ')');
    }

    return conditions;
    }


    // Helper to wrap string values in single quotes and join with commas
        private static String wrapSetValues(Set<Id> values) {
            List<String> wrapped = new List<String>();
            for (String v : values) {
                wrapped.add('\'' + String.escapeSingleQuotes(v) + '\'');
            }
            return String.join(wrapped, ', ');
        }

    /**
     * @description
     *  Constructs a complete dynamic SOQL query string to retrieve HealthcareProvider__c records.
     *  The method builds a base query, appends a dynamically generated WHERE clause
     *  based on provided Person Contact and Practice Account Id sets, and applies
     *  WITH SECURITY_ENFORCED to respect object and field-level security.
     *
     * @param personContactIds
     *  Set of Person Contact record Ids used for filtering by PractitionerId.
     *
     * @param practiceAccountIds
     *  Set of Practice Account record Ids used for filtering by AccountId.
     *
     * @return String
     *  Returns a complete and secure SOQL query string ready for execution.
     */
    private static String buildQuery(Set<Id> personContactIds, Set<Id> practiceAccountIds) {
        // Define base query selecting required HealthcareProvider fields
        String baseQuery = 'SELECT Id, Name, PractitionerId, AccountId, ProviderType, IsActive FROM HealthcareProvider WHERE ';

        // Generate WHERE clause dynamically using the provided Id sets
        List<String> conditions = buildWhereCondition(personContactIds, practiceAccountIds);

        return baseQuery + String.join(conditions, ' OR ') + ' WITH SECURITY_ENFORCED';
    }


    // ===== Helpers: builders =====
    private static HealthcareProvider buildProviderHealthcareProvider(Account providerAccount) {
            HealthcareProvider record = new HealthcareProvider();
            record.Name = setHealthcareProviderName(providerAccount);
            record.PractitionerId = providerAccount.PersonContactId;
            record.AccountId = providerAccount.Id;
            record.ProviderType = PROVIDER_TYPE_PHYSICIAN;
            record.IsActive = true;
            return record;
        }

    // ===== Helpers: builders =====
    private static HealthcareProvider buildPracticeHealthcareProvider(Account practiceAccount) {
            HealthcareProvider record = new HealthcareProvider();
            record.Name = setHealthcareProviderName(practiceAccount);
            record.AccountId = practiceAccount.Id;
            record.ProviderType = PROVIDER_TYPE_PRACTICE;
            record.IsActive = true;
            return record;
        }

    //============Set Healthcare Provider Name based on Account Name
    private static String setHealthcareProviderName(Account accountRecord){
        String healthCareProviderName;
        if(accountRecord.Name != null){
            healthCareProviderName = accountRecord.Name;
        }else{
            healthCareProviderName = (accountRecord.FirstName!=null)?accountRecord.FirstName + ' ' + accountRecord.LastName:accountRecord.LastName;
        }

        return healthCareProviderName;
    }
    // ===== Helpers: builders =====

    /**
    * @description   Updates existing Healthcare Provider records by setting the Name field
    *                based on matching Person Contact or Practice Account records.
    * @param         existingProviders - List of existing Healthcare Provider records.
    * @param         personContactIdToAccountMap - Map of Person Contact Ids to Accounts.
    * @param         practiceAccountIdToAccountMap - Map of Practice Account Ids to Accounts.
    * @return        List<HealthcareProvider> - Updated Healthcare Provider records.
    */
    private static List<HealthcareProvider> buildExistingHealthcareProviders(
        List<HealthcareProvider> existingProviders,
        Map<Id, Account> personContactIdToAccountMap,
        Map<Id, Account> practiceAccountIdToAccountMap
    ) {
        List<HealthcareProvider> updatedProviders = new List<HealthcareProvider>();

        if (existingProviders == null || existingProviders.isEmpty()) {
            return updatedProviders;
        }

        for (HealthcareProvider hp : existingProviders) {
            // Check match by Practitioner Id (Person Contact)
            Account matchedAccount;
            if (hp.PractitionerId != null && personContactIdToAccountMap != null && personContactIdToAccountMap.containsKey(hp.PractitionerId)) {
                matchedAccount = personContactIdToAccountMap.get(hp.PractitionerId);
            }
            // If not found, check by Account Id (Practice)
            else if (hp.AccountId != null && practiceAccountIdToAccountMap != null && practiceAccountIdToAccountMap.containsKey(hp.AccountId)) {
                matchedAccount = practiceAccountIdToAccountMap.get(hp.AccountId);
            }

            // If any match found, set the Name from Account
            if (matchedAccount != null) {
                hp.Name = setHealthcareProviderName(matchedAccount);
            }

            updatedProviders.add(hp);
        }

        return updatedProviders;
    }

    /**
    * @description Exception class for Account Service
    */
    public class MyCustomException extends Exception {}
}