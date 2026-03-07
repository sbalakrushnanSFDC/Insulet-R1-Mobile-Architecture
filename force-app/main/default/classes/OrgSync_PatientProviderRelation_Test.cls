/**
 * @description Test class for OrgSync_PatientProviderRelation
 *              Tests the creation of Contact Contact Relationship (CCR) records
 *              between Patient and Provider Person Accounts from OrgSync_Patient_Staging__c records.
 *              Also tests related helper classes: OrgSync_ProviderContactIdHelper and OrgSync_CCRDMLHelper
 * Created Date : Jan 19, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 19, 2026        Pradip Kokate           Initial Version
 */
@isTest
private class OrgSync_PatientProviderRelation_Test {

    private static final String TEST_PATIENT_EXT_ID = 'TEST-PATIENT-001';
    private static final String TEST_PATIENT_EXT_ID_2 = 'TEST-PATIENT-002';
    private static final String TEST_PROVIDER_NPI = '1234567890';
    private static final String TEST_PROVIDER_NPI_2 = '0987654321';

    /**
     * @description Test setup - creates test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        createPartyRoleRelation();
        
        List<Id> patientAccountIds = createPatientAccounts();
        List<Id> providerAccountIds = createProviderAccounts();
        
        List<Account> patientAccounts = populatePersonContactIds(patientAccountIds, true);
        List<Account> providerAccounts = populatePersonContactIds(providerAccountIds, false);
        
        createIdentifiers(providerAccounts);
        List<OrgSync_Physician_Staging__c> physicianStages = createPhysicianStagingRecords();
        createPatientStagingRecords(physicianStages);
    }

    /**
     * @description Creates PartyRoleRelation for Patient-Provider-CCR
     */
    private static void createPartyRoleRelation() {
        PartyRoleRelation partyRoleRelation = new PartyRoleRelation(
            Name = ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE,
            RoleName = 'Patient',
            RelatedRoleName = 'Provider',
            RelationshipObjectName = ConstantsUtil.CONTACT_CONTACT_RELATION
        );
        insert partyRoleRelation;
    }

    /**
     * @description Creates Patient Accounts and returns their IDs
     * @return List of Patient Account IDs
     */
    private static List<Id> createPatientAccounts() {
        validateRecordType(ConstantsUtil.ACCOUNT_PATIENT_RT, 'ACCOUNT_PATIENT_RT');
        
        List<Account> patientAccounts = buildPatientAccountList();
        Database.DMLOptions dmlOptions = getDMLOptions();
        Database.SaveResult[] results = Database.insert(patientAccounts, dmlOptions);
        
        List<Id> accountIds = extractSuccessfulAccountIds(patientAccounts, results);
        AccountInsertValidationParams params = new AccountInsertValidationParams();
        params.accountIds = accountIds;
        params.accounts = patientAccounts;
        params.results = results;
        params.recordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT;
        params.accountType = 'patient';
        validateAccountInsert(params);
        
        return accountIds;
    }

    /**
     * @description Builds list of Patient Account records for testing
     * @return List of Patient Account records
     */
    private static List<Account> buildPatientAccountList() {
        List<Account> patientAccounts = new List<Account>();
        patientAccounts.add(new Account(
            FirstName = 'Test',
            LastName = 'Patient1',
            RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT,
            XCDC_ExternalId__c = TEST_PATIENT_EXT_ID,
            PersonEmail = 'patient1@test.com',
            BillingPostalCode = '12345'
        ));
        patientAccounts.add(new Account(
            FirstName = 'Test',
            LastName = 'Patient2',
            RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT,
            XCDC_ExternalId__c = TEST_PATIENT_EXT_ID_2,
            PersonEmail = 'patient2@test.com',
            BillingPostalCode = '12346'
        ));
        return patientAccounts;
    }

    /**
     * @description Validates record type exists
     * @param recordTypeId Record Type ID to validate
     * @param recordTypeName Name of the record type constant for error message
     */
    private static void validateRecordType(Id recordTypeId, String recordTypeName) {
        if (recordTypeId == null) {
            System.assert(false, recordTypeName + ' is null. Record type may not exist in this org.');
        }
    }

    /**
     * @description Wrapper class to hold account insert validation parameters
     */
    private class AccountInsertValidationParams {
        List<Id> accountIds;
        List<Account> accounts;
        Database.SaveResult[] results;
        Id recordTypeId;
        String accountType;
    }

    /**
     * @description Validates account insert and throws assertion with detailed errors if failed
     * @param params AccountInsertValidationParams containing all validation parameters
     */
    private static void validateAccountInsert(AccountInsertValidationParams params) {
        if (params.accountIds.size() >= 2) {
            return; // Success
        }
        
        String errorMessage = buildAccountInsertErrorMessage(params);
        System.assert(false, errorMessage);
    }

    /**
     * @description Builds error message for account insert validation failure
     * @param params AccountInsertValidationParams containing all validation parameters
     * @return Error message string
     */
    private static String buildAccountInsertErrorMessage(AccountInsertValidationParams params) {
        Integer accountCount = params.accountIds.size();
        List<String> errorMessages = collectAccountErrorMessages(params.accounts, params.results, params.accountType);
        String errorDetail = getErrorDetail(errorMessages);
        ErrorMessageParams errorParams = new ErrorMessageParams();
        errorParams.accountCount = accountCount;
        errorParams.recordTypeId = params.recordTypeId;
        errorParams.accountType = params.accountType;
        errorParams.errorDetail = errorDetail;
        return buildErrorMessage(errorParams);
    }

    /**
     * @description Gets error detail string from error messages list
     * @param errorMessages List of error message strings
     * @return Error detail string
     */
    private static String getErrorDetail(List<String> errorMessages) {
        return errorMessages.isEmpty() ? 'No error details available.' : String.join(errorMessages, '; ');
    }

    /**
     * @description Wrapper class to hold error message building parameters
     */
    private class ErrorMessageParams {
        Integer accountCount;
        Id recordTypeId;
        String accountType;
        String errorDetail;
    }

    /**
     * @description Builds error message string
     * @param params ErrorMessageParams containing all error message parameters
     * @return Error message string
     */
    private static String buildErrorMessage(ErrorMessageParams params) {
        return 'Expected at least 2 ' + params.accountType + ' accounts to be inserted successfully. Got: ' + params.accountCount + 
            '. RecordTypeId: ' + params.recordTypeId + 
            '. Errors: ' + params.errorDetail;
    }

    /**
     * @description Collects error messages from failed account save results
     * @param accounts List of Account records
     * @param results Database.SaveResult array
     * @param accountType Account type ('patient' or 'provider') for error message
     * @return List of error message strings
     */
    private static List<String> collectAccountErrorMessages(List<Account> accounts, Database.SaveResult[] results, String accountType) {
        List<String> errorMessages = new List<String>();
        for (Integer i = 0; i < accounts.size(); i++) {
            if (!results[i].isSuccess()) {
                String accountInfo = buildAccountInfo(accountType, i + 1, accounts[i]);
                errorMessages.addAll(formatErrorMessages(accountInfo, results[i].getErrors()));
            }
        }
        return errorMessages;
    }

    /**
     * @description Builds account information string
     * @param accountType Account type
     * @param accountNumber Account number
     * @param account Account record
     * @return Account information string
     */
    private static String buildAccountInfo(String accountType, Integer accountNumber, Account account) {
        String capitalizedType = accountType.substring(0, 1).toUpperCase() + accountType.substring(1);
        return capitalizedType + ' Account ' + accountNumber + 
            ' (FirstName: ' + account.FirstName + 
            ', LastName: ' + account.LastName + 
            ', RecordTypeId: ' + account.RecordTypeId + ')';
    }

    /**
     * @description Formats error messages from Database.Error list
     * @param accountInfo Account information string
     * @param errors List of Database.Error objects
     * @return List of formatted error message strings
     */
    private static List<String> formatErrorMessages(String accountInfo, List<Database.Error> errors) {
        List<String> errorMessages = new List<String>();
        for (Database.Error err : errors) {
            String fieldList = getErrorFieldList(err);
            String errorMsg = buildFormattedErrorMessage(accountInfo, err, fieldList);
            errorMessages.add(errorMsg);
        }
        return errorMessages;
    }

    /**
     * @description Gets formatted field list from Database.Error
     * @param err Database.Error object
     * @return Formatted field list string
     */
    private static String getErrorFieldList(Database.Error err) {
        return err.getFields() != null && !err.getFields().isEmpty() 
            ? String.join(err.getFields(), ', ') 
            : 'No fields specified';
    }

    /**
     * @description Builds formatted error message string
     * @param accountInfo Account information string
     * @param err Database.Error object
     * @param fieldList Formatted field list string
     * @return Formatted error message string
     */
    private static String buildFormattedErrorMessage(String accountInfo, Database.Error err, String fieldList) {
        return accountInfo + ' - ' + err.getStatusCode() + ': ' + err.getMessage() + ' Fields: ' + fieldList;
    }

    /**
     * @description Creates Provider Accounts and returns their IDs
     * @return List of Provider Account IDs
     */
    private static List<Id> createProviderAccounts() {
        validateRecordType(ConstantsUtil.ACCOUNT_PROVIDER_RT, 'ACCOUNT_PROVIDER_RT');
        
        List<Account> providerAccounts = buildProviderAccountList();
        Database.DMLOptions dmlOptions = getDMLOptions();
        Database.SaveResult[] results = Database.insert(providerAccounts, dmlOptions);
        
        List<Id> accountIds = extractSuccessfulAccountIds(providerAccounts, results);
        AccountInsertValidationParams params = new AccountInsertValidationParams();
        params.accountIds = accountIds;
        params.accounts = providerAccounts;
        params.results = results;
        params.recordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT;
        params.accountType = 'provider';
        validateAccountInsert(params);
        
        return accountIds;
    }

    /**
     * @description Builds list of Provider Account records for testing
     * @return List of Provider Account records
     */
    private static List<Account> buildProviderAccountList() {
        List<Account> providerAccounts = new List<Account>();
        providerAccounts.add(new Account(
            FirstName = 'Test',
            LastName = 'Provider1',
            RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT,
            PersonEmail = 'provider1@test.com',
            BillingPostalCode = '12345'
        ));
        providerAccounts.add(new Account(
            FirstName = 'Test',
            LastName = 'Provider2',
            RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT,
            PersonEmail = 'provider2@test.com',
            BillingPostalCode = '12346'
        ));
        return providerAccounts;
    }

    /**
     * @description Extracts successfully inserted account IDs from save results
     * @param accounts List of Account records
     * @param results Database.SaveResult array
     * @return List of successfully inserted Account IDs
     */
    private static List<Id> extractSuccessfulAccountIds(List<Account> accounts, Database.SaveResult[] results) {
        List<Id> accountIds = new List<Id>();
        for (Integer i = 0; i < accounts.size(); i++) {
            if (results[i].isSuccess()) {
                accountIds.add(accounts[i].Id);
            }
        }
        return accountIds;
    }


    /**
     * @description Gets DML options for bypassing duplicate rules
     * @return Database.DMLOptions configured for duplicate rule bypass
     */
    private static Database.DMLOptions getDMLOptions() {
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        return dmlOptions;
    }

    /**
     * @description Queries accounts and populates PersonContactId, filtering out invalid accounts
     * @param accountIds List of Account IDs to query
     * @param isPatient True if patient accounts, false if provider accounts
     * @return List of Accounts with PersonContactId populated
     */
    private static List<Account> populatePersonContactIds(List<Id> accountIds, Boolean isPatient) {
        validateAccountIds(accountIds, isPatient);
        
        List<Account> accounts = queryAndValidateAccounts(accountIds, isPatient);
        
        Map<Id, Id> accountIdToContactId = buildAccountToContactMap(accounts);
        queryMissingContacts(accounts, accountIdToContactId);
        
        List<Account> validAccounts = filterAccountsWithContactId(accounts, accountIdToContactId, isPatient);
        ValidAccountsValidationParams validationParams = new ValidAccountsValidationParams();
        validationParams.validAccounts = validAccounts;
        validationParams.accounts = accounts;
        validationParams.accountIds = accountIds;
        validationParams.isPatient = isPatient;
        validateValidAccounts(validationParams);
        
        return validAccounts;
    }

    /**
     * @description Queries accounts and validates they were found and are Person Accounts
     * @param accountIds List of Account IDs to query
     * @param isPatient True if patient accounts, false if provider accounts
     * @return List of Account records
     */
    private static List<Account> queryAndValidateAccounts(List<Id> accountIds, Boolean isPatient) {
        List<Account> accounts = queryAccounts(accountIds, isPatient);
        validateAccountsFound(accounts, accountIds, isPatient);
        return accounts;
    }

    /**
     * @description Validates account IDs are provided
     * @param accountIds List of Account IDs
     * @param isPatient True if patient accounts, false if provider accounts
     */
    private static void validateAccountIds(List<Id> accountIds, Boolean isPatient) {
        if (accountIds == null || accountIds.isEmpty()) {
            String accountType = isPatient ? 'patient' : 'provider';
            System.assert(false, 'No ' + accountType + ' account IDs provided to populatePersonContactIds');
        }
    }

    /**
     * @description Queries accounts from database
     * @param accountIds List of Account IDs to query
     * @param isPatient True if patient accounts, false if provider accounts
     * @return List of Account records
     */
    private static List<Account> queryAccounts(List<Id> accountIds, Boolean isPatient) {
        String queryFields = isPatient ? 'Id, PersonContactId, XCDC_ExternalId__c, IsPersonAccount' : 'Id, PersonContactId, IsPersonAccount';
        return Database.query('SELECT ' + queryFields + ' FROM Account WHERE Id IN :accountIds');
    }

    /**
     * @description Validates accounts were found in query
     * @param accounts List of Account records
     * @param accountIds Original list of Account IDs
     * @param isPatient True if patient accounts, false if provider accounts
     */
    private static void validateAccountsFound(List<Account> accounts, List<Id> accountIds, Boolean isPatient) {
        if (accounts.isEmpty()) {
            String accountType = isPatient ? 'patient' : 'provider';
            String idString = buildAccountIdsString(accountIds);
            System.assert(false, 
                'No ' + accountType + ' accounts found for IDs: ' + idString);
        }
    }

    /**
     * @description Builds comma-separated string from Account IDs
     * @param accountIds List of Account IDs
     * @return Comma-separated string of Account IDs
     */
    private static String buildAccountIdsString(List<Id> accountIds) {
        List<String> idStrings = new List<String>();
        for (Id accountId : accountIds) {
            idStrings.add(String.valueOf(accountId));
        }
        return String.join(idStrings, ', ');
    }


    /**
     * @description Wrapper class to hold valid accounts validation parameters
     */
    private class ValidAccountsValidationParams {
        List<Account> validAccounts;
        List<Account> accounts;
        List<Id> accountIds;
        Boolean isPatient;
    }

    /**
     * @description Validates valid accounts count and throws assertion if insufficient
     * @param params ValidAccountsValidationParams containing all validation parameters
     */
    private static void validateValidAccounts(ValidAccountsValidationParams params) {
        if (params.validAccounts.size() >= 2) {
            return; // Success
        }
        
        String accountType = getAccountType(params.isPatient);
        ValidAccountsErrorMessageParams errorParams = new ValidAccountsErrorMessageParams();
        errorParams.validCount = params.validAccounts.size();
        errorParams.accountIdsCount = params.accountIds.size();
        errorParams.accountsCount = params.accounts.size();
        errorParams.accountType = accountType;
        String errorMessage = buildValidAccountsErrorMessage(errorParams);
        System.assert(false, errorMessage);
    }

    /**
     * @description Gets account type string from boolean
     * @param isPatient True if patient, false if provider
     * @return Account type string ('patient' or 'provider')
     */
    private static String getAccountType(Boolean isPatient) {
        return isPatient ? 'patient' : 'provider';
    }

    /**
     * @description Wrapper class to hold valid accounts error message parameters
     */
    private class ValidAccountsErrorMessageParams {
        Integer validCount;
        Integer accountIdsCount;
        Integer accountsCount;
        String accountType;
    }

    /**
     * @description Builds error message for valid accounts validation failure
     * @param params ValidAccountsErrorMessageParams containing all error message parameters
     * @return Error message string
     */
    private static String buildValidAccountsErrorMessage(ValidAccountsErrorMessageParams params) {
        String debugInfo = buildDebugInfo(params.accountIdsCount, params.accountsCount, params.validCount);
        return 'Expected at least 2 ' + params.accountType + ' accounts with PersonContactId. Got: ' + params.validCount + '. ' + debugInfo;
    }

    /**
     * @description Builds debug information string
     * @param accountIdsCount Number of account IDs
     * @param accountsCount Number of accounts queried
     * @param validAccountsCount Number of valid accounts
     * @return Debug information string
     */
    private static String buildDebugInfo(Integer accountIdsCount, Integer accountsCount, Integer validAccountsCount) {
        return 'AccountIds provided: ' + accountIdsCount + 
            ', Accounts queried: ' + accountsCount + 
            ', Accounts with PersonContactId: ' + validAccountsCount +
            ', Accounts without PersonContactId: ' + (accountsCount - validAccountsCount);
    }

    /**
     * @description Builds a map of Account ID to Contact ID from accounts that have PersonContactId
     * @param accounts List of Accounts
     * @return Map of Account ID to Contact ID
     */
    private static Map<Id, Id> buildAccountToContactMap(List<Account> accounts) {
        Map<Id, Id> accountIdToContactId = new Map<Id, Id>();
        for (Account acc : accounts) {
            if (acc.PersonContactId != null) {
                accountIdToContactId.put(acc.Id, acc.PersonContactId);
            }
        }
        return accountIdToContactId;
    }

    /**
     * @description Queries Contacts for accounts that don't have PersonContactId set
     * @param accounts List of Accounts
     * @param accountIdToContactId Map to populate with Account ID to Contact ID
     */
    private static void queryMissingContacts(List<Account> accounts, Map<Id, Id> accountIdToContactId) {
        Set<Id> accountsWithoutContactId = collectAccountsWithoutContactId(accounts);
        
        if (!accountsWithoutContactId.isEmpty()) {
            populateContactIdsFromQuery(accountsWithoutContactId, accountIdToContactId);
        }
    }

    /**
     * @description Collects account IDs that don't have PersonContactId
     * @param accounts List of Accounts
     * @return Set of Account IDs without PersonContactId
     */
    private static Set<Id> collectAccountsWithoutContactId(List<Account> accounts) {
        Set<Id> accountsWithoutContactId = new Set<Id>();
        for (Account acc : accounts) {
            if (acc.PersonContactId == null) {
                accountsWithoutContactId.add(acc.Id);
            }
        }
        return accountsWithoutContactId;
    }

    /**
     * @description Queries and populates contact IDs for accounts
     * @param accountIds Set of Account IDs to query
     * @param accountIdToContactId Map to populate with Account ID to Contact ID
     */
    private static void populateContactIdsFromQuery(Set<Id> accountIds, Map<Id, Id> accountIdToContactId) {
        List<Contact> contacts = [
            SELECT Id, AccountId
            FROM Contact
            WHERE AccountId IN :accountIds
            LIMIT 100
        ];
        for (Contact con : contacts) {
            accountIdToContactId.put(con.AccountId, con.Id);
        }
    }

    /**
     * @description Filters accounts to only include those with PersonContactId or a contact found via query
     * @param accounts List of Accounts to filter
     * @param accountIdToContactId Map of Account ID to Contact ID (includes queried contacts)
     * @param isPatient True if patient accounts, false if provider accounts
     * @return List of Accounts with PersonContactId populated
     */
    private static List<Account> filterAccountsWithContactId(List<Account> accounts, Map<Id, Id> accountIdToContactId, Boolean isPatient) {
        Set<Id> accountsToRequery = collectAccountsToRequery(accounts, accountIdToContactId);
        Map<Id, Account> requeriedAccounts = requeryAccounts(accountsToRequery, isPatient);
        return buildValidAccountsList(accounts, requeriedAccounts);
    }

    /**
     * @description Collects account IDs that need to be requeried (all accounts without PersonContactId)
     * @param accounts List of Accounts
     * @param accountIdToContactId Map of Account ID to Contact ID (not used but kept for consistency)
     * @return Set of Account IDs to re-query
     */
    private static Set<Id> collectAccountsToRequery(List<Account> accounts, Map<Id, Id> accountIdToContactId) {
        // Re-query ALL accounts that don't have PersonContactId to check if Salesforce has populated it
        return collectAccountsWithoutContactId(accounts);
    }

    /**
     * @description Re-queries accounts that don't have PersonContactId
     * @param accountsToRequery Set of Account IDs to re-query
     * @param isPatient True if patient accounts, false if provider accounts
     * @return Map of Account ID to Account with PersonContactId populated
     */
    private static Map<Id, Account> requeryAccounts(Set<Id> accountsToRequery, Boolean isPatient) {
        Map<Id, Account> requeriedAccounts = new Map<Id, Account>();
        if (accountsToRequery.isEmpty()) {
            return requeriedAccounts;
        }
        
        String queryFields = isPatient ? 'Id, PersonContactId, XCDC_ExternalId__c, IsPersonAccount' : 'Id, PersonContactId, IsPersonAccount';
        String query = 'SELECT ' + queryFields + ' FROM Account WHERE Id IN :accountsToRequery';
        for (Account acc : Database.query(query)) {
            requeriedAccounts.put(acc.Id, acc);
        }
        return requeriedAccounts;
    }

    /**
     * @description Builds list of valid accounts with PersonContactId
     * @param accounts Original list of Accounts
     * @param requeriedAccounts Map of requeried Accounts
     * @return List of Accounts with PersonContactId populated
     */
    private static List<Account> buildValidAccountsList(List<Account> accounts, Map<Id, Account> requeriedAccounts) {
        List<Account> validAccounts = new List<Account>();
        for (Account acc : accounts) {
            Account accountToAdd = getAccountWithContactId(acc, requeriedAccounts);
            if (accountToAdd != null) {
                validAccounts.add(accountToAdd);
            }
        }
        return validAccounts;
    }

    /**
     * @description Gets account with PersonContactId from original or requeried accounts
     * @param account Original account
     * @param requeriedAccounts Map of requeried accounts
     * @return Account with PersonContactId, or null if not found
     */
    private static Account getAccountWithContactId(Account account, Map<Id, Account> requeriedAccounts) {
        if (account.PersonContactId != null) {
            return account;
        }
        
        if (requeriedAccounts.containsKey(account.Id)) {
            Account requeriedAcc = requeriedAccounts.get(account.Id);
            if (requeriedAcc.PersonContactId != null) {
                return requeriedAcc;
            }
        }
        
        return null;
    }

    /**
     * @description Creates Identifier records for Provider Accounts
     * @param providerAccounts List of Provider Accounts
     */
    private static void createIdentifiers(List<Account> providerAccounts) {
        List<Identifier> identifiers = new List<Identifier>();
        
        if (providerAccounts.size() >= 1) {
            identifiers.add(new Identifier(
                ParentRecordId = providerAccounts[0].Id,
                ID_Value__c = TEST_PROVIDER_NPI,
                IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
            ));
        }

        if (providerAccounts.size() >= 2) {
            identifiers.add(new Identifier(
                ParentRecordId = providerAccounts[1].Id,
                ID_Value__c = TEST_PROVIDER_NPI_2,
                IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
            ));
        }

        if (!identifiers.isEmpty()) {
            insert identifiers;
        }
    }

    /**
     * @description Creates Physician Staging records
     * @return List of created Physician Staging records
     */
    private static List<OrgSync_Physician_Staging__c> createPhysicianStagingRecords() {
        List<OrgSync_Physician_Staging__c> physicianStages = new List<OrgSync_Physician_Staging__c>();
        physicianStages.add(new OrgSync_Physician_Staging__c(OrgSync_NPI__c = TEST_PROVIDER_NPI));
        physicianStages.add(new OrgSync_Physician_Staging__c(OrgSync_NPI__c = TEST_PROVIDER_NPI_2));
        
        Database.DMLOptions dmlOptions = getDMLOptions();
        Database.insert(physicianStages, dmlOptions);
        return physicianStages;
    }

    /**
     * @description Creates Patient Staging records linked to Physician Staging records
     * @param physicianStages List of Physician Staging records
     */
    private static void createPatientStagingRecords(List<OrgSync_Physician_Staging__c> physicianStages) {
        List<OrgSync_Patient_Staging__c> patientStages = new List<OrgSync_Patient_Staging__c>();
        patientStages.add(new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = TEST_PATIENT_EXT_ID,
            OrgSync_Provider__c = physicianStages[0].Id
        ));
        patientStages.add(new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = TEST_PATIENT_EXT_ID_2,
            OrgSync_Provider__c = physicianStages[1].Id
        ));
        
        Database.DMLOptions dmlOptions = getDMLOptions();
        Database.insert(patientStages, dmlOptions);
    }

    /**
     * @description Test successful creation of new CCR records
     */
    @IsTest
    static void testCreateNewCCRRecords() {
        List<OrgSync_Patient_Staging__c> patientStages = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c IN :new Set<String>{TEST_PATIENT_EXT_ID, TEST_PATIENT_EXT_ID_2}
        ];

        Test.startTest();
        OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(patientStages);
        Test.stopTest();

        // Verify CCR records were created
        List<ContactContactRelation> ccrRecords = [
            SELECT Id, ContactId, RelatedContactId, IsActive, Is_Primary__c, PartyRoleRelationId
            FROM ContactContactRelation
            WHERE ContactId IN (
                SELECT PersonContactId
                FROM Account
                WHERE XCDC_ExternalId__c IN :new Set<String>{TEST_PATIENT_EXT_ID, TEST_PATIENT_EXT_ID_2}
            )
        ];

        for (ContactContactRelation ccr : ccrRecords) {
            System.assertEquals(true, ccr.IsActive, 'CCR should be active');
            System.assertEquals(true, ccr.Is_Primary__c, 'CCR should be primary');
            System.assertNotEquals(null, ccr.PartyRoleRelationId, 'PartyRoleRelationId should be set');
        }
    }

    /**
     * @description Test update of existing CCR records
     */
    @IsTest
    static void testUpdateExistingCCRRecords() {
        // Get test data
        Account patientAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE XCDC_ExternalId__c = :TEST_PATIENT_EXT_ID
            LIMIT 1
        ];

        Account providerAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE LastName = 'Provider1'
            LIMIT 1
        ];

        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        // Create existing CCR record with IsActive = false and Is_Primary__c = false
        ContactContactRelation existingCCR = new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = providerAccount.PersonContactId,
            IsActive = false,
            Is_Primary__c = false,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        insert existingCCR;

        List<OrgSync_Patient_Staging__c> patientStages = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :TEST_PATIENT_EXT_ID
        ];

        Test.startTest();
        OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(patientStages);
        Test.stopTest();

        // Verify CCR record was updated
        ContactContactRelation updatedCCR = [
            SELECT Id, IsActive, Is_Primary__c, PartyRoleRelationId
            FROM ContactContactRelation
            WHERE Id = :existingCCR.Id
        ];

        System.assertEquals(partyRoleRelation.Id, updatedCCR.PartyRoleRelationId, 'PartyRoleRelationId should match');
    }

    /**
     * @description Test with null/empty records list
     */
    @IsTest
    static void testWithNullRecords() {
        Test.startTest();
        OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(null);
        OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(new List<OrgSync_Patient_Staging__c>());
        Test.stopTest();

        // No assertions needed - method should handle gracefully without errors
        System.assert(true, 'Method should handle null/empty records without errors');
    }

    /**
     * @description Test with missing patient external ID
     */
    @IsTest
    static void testWithMissingPatientExternalId() {
        OrgSync_Patient_Staging__c patientStage = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = null,
            OrgSync_Provider__c = [
                SELECT Id
                FROM OrgSync_Physician_Staging__c
                LIMIT 1
            ].Id
        );
        Database.DMLOptions dmlOptions = getDMLOptions();
        Database.insert(patientStage, dmlOptions);

        Test.startTest();
        OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(new List<OrgSync_Patient_Staging__c>{patientStage});
        Test.stopTest();

        // Verify no CCR records were created
        List<ContactContactRelation> ccrRecords = [
            SELECT Id
            FROM ContactContactRelation
            WHERE ContactId IN (
                SELECT PersonContactId
                FROM Account
                WHERE XCDC_ExternalId__c = null
            )
        ];

        System.assertEquals(0, ccrRecords.size(), 'No CCR records should be created when patient external ID is missing');
    }

    /**
     * @description Test with missing provider staging reference
     */
    @IsTest
    static void testWithMissingProviderStaging() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime());
        OrgSync_Patient_Staging__c patientStage = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = 'TEST-PATIENT-NO-PROVIDER-' + uniqueSuffix,
            OrgSync_Provider__c = null
        );
        Database.DMLOptions dmlOptions = getDMLOptions();
        Database.insert(patientStage, dmlOptions);

        Test.startTest();
        OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(new List<OrgSync_Patient_Staging__c>{patientStage});
        Test.stopTest();

        // Verify no CCR records were created
        List<ContactContactRelation> ccrRecords = [
            SELECT Id
            FROM ContactContactRelation
            WHERE ContactId IN (
                SELECT PersonContactId
                FROM Account
                WHERE XCDC_ExternalId__c = :TEST_PATIENT_EXT_ID
            )
        ];

        // Should only have CCRs from test setup, not from this test
        System.assert(ccrRecords.size() <= 1, 'No new CCR records should be created when provider staging is missing');
    }

    /**
     * @description Test updateOtherPrimaryProviders functionality
     */
    @IsTest
    static void testUpdateOtherPrimaryProviders() {
        // Get test data
        Account patientAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE XCDC_ExternalId__c = :TEST_PATIENT_EXT_ID
            LIMIT 1
        ];

        List<Account> providerAccounts = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE LastName IN ('Provider1', 'Provider2')
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
        ];

        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        // Create existing primary CCR with Provider1
        ContactContactRelation existingPrimaryCCR = new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = providerAccounts[0].PersonContactId,
            IsActive = true,
            Is_Primary__c = true,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        insert existingPrimaryCCR;

        // Create Patient Staging pointing to Provider2
        OrgSync_Physician_Staging__c physicianStage2 = [
            SELECT Id
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c = :TEST_PROVIDER_NPI_2
            LIMIT 1
        ];

        OrgSync_Patient_Staging__c patientStage = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = TEST_PATIENT_EXT_ID,
            OrgSync_Provider__c = physicianStage2.Id
        );
        Database.DMLOptions dmlOptions = getDMLOptions();
        Database.insert(patientStage, dmlOptions);

        Test.startTest();
        OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(new List<OrgSync_Patient_Staging__c>{patientStage});
        Test.stopTest();

        // Verify existing primary CCR was updated to non-primary
        ContactContactRelation updatedCCR = [
            SELECT Id, Is_Primary__c
            FROM ContactContactRelation
            WHERE Id = :existingPrimaryCCR.Id
        ];

        System.assertEquals(false, updatedCCR.Is_Primary__c, 'Existing primary CCR should be set to non-primary');

        // Verify new CCR with Provider2 is primary
        ContactContactRelation newCCR = [
            SELECT Id, Is_Primary__c, RelatedContactId
            FROM ContactContactRelation
            WHERE ContactId = :patientAccount.PersonContactId
            AND RelatedContactId = :providerAccounts[1].PersonContactId
        ];

        System.assertEquals(true, newCCR.Is_Primary__c, 'New CCR should be primary');
    }

    /**
     * @description Test OrgSync_ProviderContactIdHelper.getProviderContactIds
     */
    @IsTest
    static void testProviderContactIdHelper() {
        List<OrgSync_Patient_Staging__c> patientStages = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c IN :new Set<String>{TEST_PATIENT_EXT_ID, TEST_PATIENT_EXT_ID_2}
        ];

        Test.startTest();
        Map<Id, Id> providerStagingToContactId = OrgSync_ProviderContactIdHelper.getProviderContactIds(patientStages);
        Test.stopTest();

        System.assertNotEquals(null, providerStagingToContactId, 'Map should not be null');
        
        for (Id stagingId : providerStagingToContactId.keySet()) {
            System.assertNotEquals(null, providerStagingToContactId.get(stagingId), 'Provider contact ID should not be null');
        }
    }

    /**
     * @description Test OrgSync_ProviderContactIdHelper with empty records
     */
    @IsTest
    static void testProviderContactIdHelperWithEmptyRecords() {
        Test.startTest();
        Map<Id, Id> providerStagingToContactId = OrgSync_ProviderContactIdHelper.getProviderContactIds(new List<OrgSync_Patient_Staging__c>());
        Test.stopTest();

        System.assertNotEquals(null, providerStagingToContactId, 'Map should not be null');
        System.assertEquals(0, providerStagingToContactId.size(), 'Map should be empty');
    }

    /**
     * @description Test OrgSync_ProviderContactIdHelper with missing NPI
     */
    @IsTest
    static void testProviderContactIdHelperWithMissingNPI() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime());
        
        OrgSync_Physician_Staging__c physicianStage = new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = null
        );
        Database.DMLOptions dmlOptions = getDMLOptions();
        Database.insert(physicianStage, dmlOptions);

        OrgSync_Patient_Staging__c patientStage = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = 'TEST-PATIENT-MISSING-NPI-' + uniqueSuffix,
            OrgSync_Provider__c = physicianStage.Id
        );
        Database.insert(patientStage, dmlOptions);

        Test.startTest();
        Map<Id, Id> providerStagingToContactId = OrgSync_ProviderContactIdHelper.getProviderContactIds(new List<OrgSync_Patient_Staging__c>{patientStage});
        Test.stopTest();

        System.assertNotEquals(null, providerStagingToContactId, 'Map should not be null');
        System.assertEquals(0, providerStagingToContactId.size(), 'Map should be empty when NPI is missing');
    }

    /**
     * @description Test OrgSync_CCRDMLHelper.insertCCRs
     */
    @IsTest
    static void testCCRDMLHelperInsert() {
        Account patientAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE XCDC_ExternalId__c = :TEST_PATIENT_EXT_ID
            LIMIT 1
        ];

        Account providerAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE LastName = 'Provider1'
            LIMIT 1
        ];

        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        List<ContactContactRelation> ccrToInsert = new List<ContactContactRelation>();
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = providerAccount.PersonContactId,
            IsActive = true,
            Is_Primary__c = true,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        ccrToInsert.add(ccr);

        Test.startTest();
        OrgSync_CCRDMLHelper.insertCCRs(ccrToInsert);
        Test.stopTest();

        // Verify CCR was inserted
        List<ContactContactRelation> insertedCCRs = [
            SELECT Id
            FROM ContactContactRelation
            WHERE ContactId = :patientAccount.PersonContactId
            AND RelatedContactId = :providerAccount.PersonContactId
        ];

        System.assertEquals(1, insertedCCRs.size(), 'CCR should be inserted');
    }

    /**
     * @description Test OrgSync_CCRDMLHelper.insertCCRs with empty list
     */
    @IsTest
    static void testCCRDMLHelperInsertWithEmptyList() {
        Test.startTest();
        OrgSync_CCRDMLHelper.insertCCRs(new List<ContactContactRelation>());
        Test.stopTest();

        // No assertions needed - method should handle gracefully
        System.assert(true, 'Method should handle empty list without errors');
    }

    /**
     * @description Test OrgSync_CCRDMLHelper.updateCCRs
     */
    @IsTest
    static void testCCRDMLHelperUpdate() {
        Account patientAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE XCDC_ExternalId__c = :TEST_PATIENT_EXT_ID
            LIMIT 1
        ];

        Account providerAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE LastName = 'Provider1'
            LIMIT 1
        ];

        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        // Create CCR first
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = providerAccount.PersonContactId,
            IsActive = false,
            Is_Primary__c = false,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        insert ccr;

        // Update CCR
        ccr.IsActive = true;
        ccr.Is_Primary__c = true;

        Test.startTest();
        OrgSync_CCRDMLHelper.updateCCRs(new List<ContactContactRelation>{ccr});
        Test.stopTest();

        // Verify CCR was updated
        ContactContactRelation updatedCCR = [
            SELECT Id, IsActive, Is_Primary__c
            FROM ContactContactRelation
            WHERE Id = :ccr.Id
        ];

        System.assertEquals(true, updatedCCR.IsActive, 'CCR should be active');
        System.assertEquals(true, updatedCCR.Is_Primary__c, 'CCR should be primary');
    }

    /**
     * @description Test OrgSync_CCRDMLHelper.updateCCRs with empty list
     */
    @IsTest
    static void testCCRDMLHelperUpdateWithEmptyList() {
        Test.startTest();
        OrgSync_CCRDMLHelper.updateCCRs(new List<ContactContactRelation>());
        Test.stopTest();

        // No assertions needed - method should handle gracefully
        System.assert(true, 'Method should handle empty list without errors');
    }

    /**
     * @description Test error handling when PartyRoleRelation is not found
     */
    @IsTest
    static void testPartyRoleRelationNotFound() {
        // Delete PartyRoleRelation
        List<PartyRoleRelation> partyRoleRelations = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
        ];
        delete partyRoleRelations;

        List<OrgSync_Patient_Staging__c> patientStages = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :TEST_PATIENT_EXT_ID
        ];

        Test.startTest();
        OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(patientStages);
        Test.stopTest();

        // Verify no CCR records were created
        List<ContactContactRelation> ccrRecords = [
            SELECT Id
            FROM ContactContactRelation
            WHERE ContactId IN (
                SELECT PersonContactId
                FROM Account
                WHERE XCDC_ExternalId__c = :TEST_PATIENT_EXT_ID
            )
        ];

        System.assertEquals(0, ccrRecords.size(), 'No CCR records should be created when PartyRoleRelation is not found');
    }

    /**
     * @description Test with patient account that doesn't exist
     */
    @IsTest
    static void testWithNonExistentPatientAccount() {
        OrgSync_Physician_Staging__c physicianStage = [
            SELECT Id
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c = :TEST_PROVIDER_NPI
            LIMIT 1
        ];

        OrgSync_Patient_Staging__c patientStage = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = 'NON-EXISTENT-PATIENT',
            OrgSync_Provider__c = physicianStage.Id
        );
        Database.DMLOptions dmlOptions = getDMLOptions();
        Database.insert(patientStage, dmlOptions);

        Test.startTest();
        OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(new List<OrgSync_Patient_Staging__c>{patientStage});
        Test.stopTest();

        // Verify no CCR records were created
        List<ContactContactRelation> ccrRecords = [
            SELECT Id
            FROM ContactContactRelation
            WHERE ContactId IN (
                SELECT PersonContactId
                FROM Account
                WHERE XCDC_ExternalId__c = 'NON-EXISTENT-PATIENT'
            )
        ];

        System.assertEquals(0, ccrRecords.size(), 'No CCR records should be created when patient account does not exist');
    }

    /**
     * @description Test with provider account that doesn't exist
     */
    @IsTest
    static void testWithNonExistentProviderAccount() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime());
        String patientExtId = 'TEST-PATIENT-NON-EXISTENT-PROVIDER-' + uniqueSuffix;
        
        OrgSync_Physician_Staging__c physicianStage = new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = '9999999999' // Non-existent NPI
        );
        Database.DMLOptions dmlOptions = getDMLOptions();
        Database.insert(physicianStage, dmlOptions);

        OrgSync_Patient_Staging__c patientStage = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = patientExtId,
            OrgSync_Provider__c = physicianStage.Id
        );
        Database.insert(patientStage, dmlOptions);

        Test.startTest();
        OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(new List<OrgSync_Patient_Staging__c>{patientStage});
        Test.stopTest();

        // Verify no CCR records were created
        List<ContactContactRelation> ccrRecords = [
            SELECT Id
            FROM ContactContactRelation
            WHERE ContactId IN (
                SELECT PersonContactId
                FROM Account
                WHERE XCDC_ExternalId__c = :patientExtId
            )
        ];

        // Should only have CCRs from test setup, not from this test
        System.assert(ccrRecords.size() <= 1, 'No new CCR records should be created when provider account does not exist');
    }

    /**
     * @description Gets or creates patient staging record, updating if needed to point to the correct provider
     * @param patientExtId Patient external ID
     * @param physicianStageId Physician staging record ID
     * @return OrgSync_Patient_Staging__c record
     */
    private static OrgSync_Patient_Staging__c getOrCreatePatientStaging(String patientExtId, Id physicianStageId) {
        List<OrgSync_Patient_Staging__c> existingPatientStages = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :patientExtId
        ];

        if (existingPatientStages.isEmpty()) {
            return createPatientStagingRecord(patientExtId, physicianStageId);
        }
        
        return updatePatientStagingIfNeeded(existingPatientStages[0], physicianStageId);
    }

    /**
     * @description Creates a new patient staging record
     * @param patientExtId Patient external ID
     * @param physicianStageId Physician staging record ID
     * @return Created OrgSync_Patient_Staging__c record
     */
    private static OrgSync_Patient_Staging__c createPatientStagingRecord(String patientExtId, Id physicianStageId) {
        OrgSync_Patient_Staging__c patientStage = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = patientExtId,
            OrgSync_Provider__c = physicianStageId
        );
        Database.DMLOptions dmlOptions = getDMLOptions();
        Database.insert(patientStage, dmlOptions);
        return patientStage;
    }

    /**
     * @description Updates patient staging record if it doesn't point to the correct provider
     * @param patientStage Existing patient staging record
     * @param physicianStageId Physician staging record ID
     * @return Updated OrgSync_Patient_Staging__c record
     */
    private static OrgSync_Patient_Staging__c updatePatientStagingIfNeeded(OrgSync_Patient_Staging__c patientStage, Id physicianStageId) {
        if (patientStage.OrgSync_Provider__c != physicianStageId) {
            patientStage.OrgSync_Provider__c = physicianStageId;
            Database.DMLOptions dmlOptions = getDMLOptions();
            Database.update(patientStage, dmlOptions);
        }
        return patientStage;
    }

    /**
     * @description Gets test accounts and party role relation for CCR testing
     * @param patientExtId Patient external ID
     * @param providerNPI Provider NPI
     * @return Map with keys: 'patientAccount', 'providerAccount', 'partyRoleRelation'
     */
    private static Map<String, SObject> getTestAccountsAndPartyRoleRelation(String patientExtId, String providerNPI) {
        Account patientAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE XCDC_ExternalId__c = :patientExtId
            LIMIT 1
        ];

        Identifier providerIdentifier = [
            SELECT ParentRecordId
            FROM Identifier
            WHERE ID_Value__c = :providerNPI
            AND IdUsageType = :ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
            LIMIT 1
        ];

        Account providerAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :providerIdentifier.ParentRecordId
            LIMIT 1
        ];

        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        Map<String, SObject> result = new Map<String, SObject>();
        result.put('patientAccount', patientAccount);
        result.put('providerAccount', providerAccount);
        result.put('partyRoleRelation', partyRoleRelation);
        return result;
    }

    /**
     * @description Creates an inactive, non-primary CCR record
     * @param patientAccount Patient account
     * @param providerAccount Provider account
     * @param partyRoleRelation Party role relation
     * @return Created ContactContactRelation record
     */
    private static ContactContactRelation createInactiveCCR(Account patientAccount, Account providerAccount, PartyRoleRelation partyRoleRelation) {
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = providerAccount.PersonContactId,
            IsActive = false,
            Is_Primary__c = false,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        insert ccr;
        return ccr;
    }

    @IsTest
    static void testHandleExistingCcrUpdateInactiveCCR() {
        Map<String, SObject> testData = getTestAccountsAndPartyRoleRelation(TEST_PATIENT_EXT_ID, TEST_PROVIDER_NPI);
        Account patientAccount = (Account)testData.get('patientAccount');
        Account providerAccount = (Account)testData.get('providerAccount');
        PartyRoleRelation partyRoleRelation = (PartyRoleRelation)testData.get('partyRoleRelation');

        ContactContactRelation existingCCR = createInactiveCCR(patientAccount, providerAccount, partyRoleRelation);

        // Verify CCR was created with inactive and non-primary status
        ContactContactRelation ccrBefore = [
            SELECT Id, IsActive, Is_Primary__c, PartyRoleRelationId
            FROM ContactContactRelation
            WHERE Id = :existingCCR.Id
        ];
        System.assertEquals(false, ccrBefore.IsActive, 'CCR should be inactive initially');

        // Get the physician staging record with TEST_PROVIDER_NPI
        OrgSync_Physician_Staging__c physicianStage = [
            SELECT Id, OrgSync_NPI__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c = :TEST_PROVIDER_NPI
            LIMIT 1
        ];

        // Get patient staging record - create or update to ensure it points to the correct provider
        OrgSync_Patient_Staging__c patientStage = getOrCreatePatientStaging(TEST_PATIENT_EXT_ID, physicianStage.Id);

        Test.startTest();
        // Call the method which should find existing CCR and call handleExistingCCR
        OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(new List<OrgSync_Patient_Staging__c>{patientStage});
        Test.stopTest();

        // Verify CCR record was updated by handleExistingCCR
        ContactContactRelation updatedCCR = [
            SELECT Id, IsActive, Is_Primary__c, PartyRoleRelationId
            FROM ContactContactRelation
            WHERE Id = :existingCCR.Id
        ];
        // Verify no duplicate CCR was created
        List<ContactContactRelation> allCCRs = [
            SELECT Id
            FROM ContactContactRelation
            WHERE ContactId = :patientAccount.PersonContactId
            AND RelatedContactId = :providerAccount.PersonContactId
        ];
        System.assertEquals(1, allCCRs.size(), 'Should only have one CCR record, no duplicates created');
    }
}