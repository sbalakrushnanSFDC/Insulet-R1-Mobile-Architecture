/**
 * @description Helper class for HPF processing operations including data retrieval, queries, primary facility management, and DML
 * Created Date : Jan 29, 2026
 * Created By   : Pradip Kokate
 */
@SuppressWarnings('PMD.CognitiveComplexity, PMD.CyclomaticComplexity')
public with sharing class OrgSync_HPFHelper {

    /**
     * @description Inner class to hold account names result
     */
    public class AccountNamesResult {
        /**
         * @description Map of Provider Contact ID to Provider Account Name
         */
        public Map<Id, String> providerContactIdToName;
        /**
         * @description Map of Practice Account ID to Practice Account Name
         */
        public Map<Id, String> practiceAccountIdToName;
    }

    /**
     * @description Inner class to hold account IDs context for processing
     */
    private class AccountIdsContext {
        /**
         * @description Set of Practice Account IDs
         */
        public Set<Id> practiceAccountIds;
        /**
         * @description Set of Provider Contact IDs
         */
        public Set<Id> providerContactIds;
    }

    // ========== Provider Data Retrieval Methods ==========

    /**
     * @description Gets Provider Contact IDs from NPIs via Identifier records
     *              ParentRecordId stores Provider Person Account IDs, so we need to get PersonContactId from Account
     * @param npiValues Set of NPI values
     * @return Map of NPI to Provider Contact ID
     */
    public static Map<String, Id> getProviderContactIdsFromNPIs(Set<String> npiValues) {
        Map<String, Id> npiToProviderContactId = new Map<String, Id>();

        if (npiValues.isEmpty()) {
            return npiToProviderContactId;
        }

        Map<String, Id> npiToProviderAccountId = getProviderAccountIdsFromNPIs(npiValues);
        if (npiToProviderAccountId.isEmpty()) {
            return npiToProviderContactId;
        }

        Map<Id, Id> providerAccountToContactId = getProviderAccountToContactIds(npiToProviderAccountId.values());
        return mapNPIToProviderContactIds(npiToProviderAccountId, providerAccountToContactId);
    }

    /**
     * @description Maps NPI values to Provider Contact IDs using account ID mappings
     * @param npiToProviderAccountId Map of NPI to Provider Account ID
     * @param providerAccountToContactId Map of Provider Account ID to Provider Contact ID
     * @return Map of NPI to Provider Contact ID
     */
    private static Map<String, Id> mapNPIToProviderContactIds(
        Map<String, Id> npiToProviderAccountId,
        Map<Id, Id> providerAccountToContactId
    ) {
        Map<String, Id> npiToProviderContactId = new Map<String, Id>();
        for (String npi : npiToProviderAccountId.keySet()) {
            Id providerAccountId = npiToProviderAccountId.get(npi);
            Id providerContactId = providerAccountToContactId.get(providerAccountId);
            if (providerContactId != null) {
                npiToProviderContactId.put(npi, providerContactId);
            }
        }
        return npiToProviderContactId;
    }

    /**
     * @description Gets Provider Account IDs from Identifier records using NPIs
     *              ParentRecordId stores Provider Person Account IDs (Account IDs start with '001')
     * @param npiValues Set of NPI values
     * @return Map of NPI to Provider Account ID
     */
    private static Map<String, Id> getProviderAccountIdsFromNPIs(Set<String> npiValues) {
        Map<String, Id> npiToProviderAccountId = new Map<String, Id>();

        if (npiValues.isEmpty()) {
            return npiToProviderAccountId;
        }

        List<Identifier> identifiers = queryIdentifiersByNPIs(npiValues);
        for (Identifier identifier : identifiers) {
            processIdentifierForProviderAccount(identifier, npiToProviderAccountId);
        }

        return npiToProviderAccountId;
    }

    /**
     * @description Queries Identifier records by NPI values
     * @param npiValues Set of NPI values
     * @return List of Identifier records
     */
    private static List<Identifier> queryIdentifiersByNPIs(Set<String> npiValues) {
        return [
            SELECT Id, ParentRecordId, ID_Value__c
            FROM Identifier
            WHERE ID_Value__c IN :npiValues
                AND IdUsageType = :ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
                AND ParentRecordId != null
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description Processes an identifier record to extract provider account ID if valid
     * @param identifier Identifier record
     * @param npiToProviderAccountId Map to populate with NPI to Provider Account ID mapping
     */
    private static void processIdentifierForProviderAccount(
        Identifier identifier,
        Map<String, Id> npiToProviderAccountId
    ) {
        if (!isValidIdentifier(identifier)) {
            return;
        }

        if (isProviderAccountId(identifier.ParentRecordId)) {
            npiToProviderAccountId.put(identifier.ID_Value__c, identifier.ParentRecordId);
        }
    }

    /**
     * @description Validates if identifier record is valid
     * @param identifier Identifier record
     * @return Boolean true if valid, false otherwise
     */
    private static Boolean isValidIdentifier(Identifier identifier) {
        return identifier != null 
            && String.isNotBlank(identifier.ID_Value__c) 
            && identifier.ParentRecordId != null;
    }

    /**
     * @description Checks if ParentRecordId is a provider account ID (starts with '001')
     * @param parentRecordId Parent Record ID to check
     * @return Boolean true if provider account ID, false otherwise
     */
    private static Boolean isProviderAccountId(Id parentRecordId) {
        String parentIdStr = String.valueOf(parentRecordId);
        return parentIdStr.startsWith('001');
    }

    /**
     * @description Gets Provider Contact IDs from Provider Account IDs
     * @param providerAccountIds List of Provider Account IDs
     * @return Map of Provider Account ID to Provider Contact ID (PersonContactId)
     */
    private static Map<Id, Id> getProviderAccountToContactIds(List<Id> providerAccountIds) {
        Map<Id, Id> providerAccountToContactId = new Map<Id, Id>();

        if (providerAccountIds.isEmpty()) {
            return providerAccountToContactId;
        }

        for (Account acc : [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id IN :providerAccountIds
                AND PersonContactId != null
                AND RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            WITH SYSTEM_MODE
        ]) {
            if (acc.PersonContactId != null) {
                providerAccountToContactId.put(acc.Id, acc.PersonContactId);
            }
        }

        return providerAccountToContactId;
    }

    /**
     * @description Gets Provider Account names and Practice Account names in a single SOQL query
     *              This method combines getProviderAccountNames and getAccountNames to reduce SOQL queries
     * @param practiceAccountIds Set of Practice Account IDs
     * @param providerContactIds Set of Provider Contact IDs (PersonContactId from Provider Accounts)
     * @return AccountNamesResult containing both provider and practice account name maps
     */
    public static AccountNamesResult getAccountNames(Set<Id> practiceAccountIds, Set<Id> providerContactIds) {
        AccountNamesResult result = initializeAccountNamesResult();

        if (providerContactIds.isEmpty() && practiceAccountIds.isEmpty()) {
            return result;
        }

        AccountIdsContext context = createAccountIdsContext(practiceAccountIds, providerContactIds);
        List<Account> accounts = queryAccountsForNames(practiceAccountIds, providerContactIds);
        populateAccountNames(accounts, result, context);

        return result;
    }

    /**
     * @description Initializes an AccountNamesResult with empty maps
     * @return AccountNamesResult with initialized empty maps
     */
    private static AccountNamesResult initializeAccountNamesResult() {
        AccountNamesResult result = new AccountNamesResult();
        result.providerContactIdToName = new Map<Id, String>();
        result.practiceAccountIdToName = new Map<Id, String>();
        return result;
    }

    /**
     * @description Creates AccountIdsContext from practice and provider account IDs
     * @param practiceAccountIds Set of Practice Account IDs
     * @param providerContactIds Set of Provider Contact IDs
     * @return AccountIdsContext with populated IDs
     */
    private static AccountIdsContext createAccountIdsContext(Set<Id> practiceAccountIds, Set<Id> providerContactIds) {
        AccountIdsContext context = new AccountIdsContext();
        context.practiceAccountIds = practiceAccountIds;
        context.providerContactIds = providerContactIds;
        return context;
    }

    /**
     * @description Populates account names result from account records
     * @param accounts List of Account records
     * @param result AccountNamesResult to populate
     * @param context AccountIdsContext containing practice and provider account IDs
     */
    private static void populateAccountNames(
        List<Account> accounts,
        AccountNamesResult result,
        AccountIdsContext context
    ) {
        for (Account acc : accounts) {
            processAccountForNames(acc, result, context);
        }
    }

    /**
     * @description Queries accounts for provider and practice names
     * @param practiceAccountIds Set of Practice Account IDs
     * @param providerContactIds Set of Provider Contact IDs
     * @return List of Account records
     */
    private static List<Account> queryAccountsForNames(Set<Id> practiceAccountIds, Set<Id> providerContactIds) {
        return [
            SELECT Id, PersonContactId, Name, RecordTypeId
            FROM Account
            WHERE (PersonContactId IN :providerContactIds AND RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT)
                OR Id IN :practiceAccountIds
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description Processes an account record to extract provider and practice names
     * @param acc Account record
     * @param result AccountNamesResult to populate
     * @param context AccountIdsContext containing practice and provider account IDs
     */
    private static void processAccountForNames(
        Account acc,
        AccountNamesResult result,
        AccountIdsContext context
    ) {
        if (String.isBlank(acc.Name)) {
            return;
        }

        addProviderNameIfApplicable(acc, result, context.providerContactIds);
        addPracticeNameIfApplicable(acc, result, context.practiceAccountIds);
    }

    /**
     * @description Adds provider name to result if account is a provider account
     * @param acc Account record
     * @param result AccountNamesResult to populate
     * @param providerContactIds Set of Provider Contact IDs
     */
    private static void addProviderNameIfApplicable(
        Account acc,
        AccountNamesResult result,
        Set<Id> providerContactIds
    ) {
        if (isProviderAccount(acc, providerContactIds)) {
            result.providerContactIdToName.put(acc.PersonContactId, acc.Name);
        }
    }

    /**
     * @description Adds practice name to result if account is a practice account
     * @param acc Account record
     * @param result AccountNamesResult to populate
     * @param practiceAccountIds Set of Practice Account IDs
     */
    private static void addPracticeNameIfApplicable(
        Account acc,
        AccountNamesResult result,
        Set<Id> practiceAccountIds
    ) {
        if (isPracticeAccount(acc, practiceAccountIds)) {
            result.practiceAccountIdToName.put(acc.Id, acc.Name);
        }
    }

    /**
     * @description Checks if account is a provider account
     * @param acc Account record
     * @param providerContactIds Set of Provider Contact IDs
     * @return Boolean true if provider account, false otherwise
     */
    private static Boolean isProviderAccount(Account acc, Set<Id> providerContactIds) {
        return acc.PersonContactId != null && providerContactIds.contains(acc.PersonContactId);
    }

    /**
     * @description Checks if account is a practice account
     * @param acc Account record
     * @param practiceAccountIds Set of Practice Account IDs
     * @return Boolean true if practice account, false otherwise
     */
    private static Boolean isPracticeAccount(Account acc, Set<Id> practiceAccountIds) {
        return practiceAccountIds.contains(acc.Id);
    }

    // ========== HPF Query Methods ==========

    /**
     * @description Gets existing HPF records
     * @param practiceAccountIds Set of Practice Account IDs
     * @param providerContactIds Set of Provider Contact IDs
     * @return Map of HPF key (practiceAccountId_providerContactId) to HPF record
     */
    public static Map<String, HealthcarePractitionerFacility> getExistingHPFRecords(
        List<Id> practiceAccountIds,
        Set<Id> providerContactIds
    ) {
        Map<String, HealthcarePractitionerFacility> existingHPFMap = new Map<String, HealthcarePractitionerFacility>();

        if (practiceAccountIds.isEmpty() || providerContactIds.isEmpty()) {
            return existingHPFMap;
        }

        for (HealthcarePractitionerFacility hpf : [
            SELECT Id, AccountId, PractitionerId, IsPrimaryFacility, IsActive, Name, IsPrimaryCarePhysician
            FROM HealthcarePractitionerFacility
            WHERE AccountId IN :practiceAccountIds
                AND PractitionerId IN :providerContactIds
            WITH SYSTEM_MODE
        ]) {
            String hpfKey = String.valueOf(hpf.AccountId) + '_' + String.valueOf(hpf.PractitionerId);
            existingHPFMap.put(hpfKey, hpf);
        }

        return existingHPFMap;
    }

    /**
     * @description Checks if practice accounts have any existing HPF records
     * @param practiceAccountIds List of Practice Account IDs
     * @return Map of Practice Account ID to Boolean (true if HPF records exist, false otherwise)
     */
    public static Map<Id, Boolean> checkPracticeAccountsHaveHPFRecords(List<Id> practiceAccountIds) {
        Map<Id, Boolean> practiceAccountHasHPFRecords = initializeBooleanMap(practiceAccountIds);

        if (practiceAccountIds.isEmpty()) {
            return practiceAccountHasHPFRecords;
        }

        Set<Id> practiceAccountsWithHPF = queryPracticeAccountsWithHPF(practiceAccountIds);
        updateBooleanMap(practiceAccountHasHPFRecords, practiceAccountsWithHPF);

        return practiceAccountHasHPFRecords;
    }

    /**
     * @description Initializes a boolean map with all IDs set to false
     * @param ids List of IDs to initialize
     * @return Map of ID to Boolean (all false)
     */
    private static Map<Id, Boolean> initializeBooleanMap(List<Id> ids) {
        Map<Id, Boolean> result = new Map<Id, Boolean>();
        for (Id id : ids) {
            result.put(id, false);
        }
        return result;
    }

    /**
     * @description Queries practice accounts that have HPF records
     * @param practiceAccountIds List of Practice Account IDs
     * @return Set of Practice Account IDs that have HPF records
     */
    private static Set<Id> queryPracticeAccountsWithHPF(List<Id> practiceAccountIds) {
        Set<Id> practiceAccountsWithHPF = new Set<Id>();
        for (HealthcarePractitionerFacility hpf : [
            SELECT AccountId
            FROM HealthcarePractitionerFacility
            WHERE AccountId IN :practiceAccountIds
            WITH SYSTEM_MODE
            LIMIT 10000
        ]) {
            if (hpf.AccountId != null) {
                practiceAccountsWithHPF.add(hpf.AccountId);
            }
        }
        return practiceAccountsWithHPF;
    }

    /**
     * @description Updates boolean map with true values for IDs in the set
     * @param booleanMap Map to update
     * @param idsToSetTrue Set of IDs to set to true
     */
    private static void updateBooleanMap(Map<Id, Boolean> booleanMap, Set<Id> idsToSetTrue) {
        for (Id id : idsToSetTrue) {
            booleanMap.put(id, true);
        }
    }

    /**
     * @description Checks if provider contact IDs have any existing HPF records
     * @param providerContactIds Set of Provider Contact IDs
     * @return Map of Provider Contact ID to Boolean (true if HPF records exist, false otherwise)
     */
    public static Map<Id, Boolean> checkProviderContactIdsHaveHPFRecords(Set<Id> providerContactIds) {
        Map<Id, Boolean> providerContactIdHasHPFRecords = initializeBooleanMapFromSet(providerContactIds);

        if (providerContactIds.isEmpty()) {
            return providerContactIdHasHPFRecords;
        }

        Set<Id> providerContactIdsWithHPF = queryProviderContactIdsWithHPF(providerContactIds);
        updateBooleanMap(providerContactIdHasHPFRecords, providerContactIdsWithHPF);

        return providerContactIdHasHPFRecords;
    }

    /**
     * @description Initializes a boolean map with all IDs from set set to false
     * @param ids Set of IDs to initialize
     * @return Map of ID to Boolean (all false)
     */
    private static Map<Id, Boolean> initializeBooleanMapFromSet(Set<Id> ids) {
        Map<Id, Boolean> result = new Map<Id, Boolean>();
        for (Id id : ids) {
            result.put(id, false);
        }
        return result;
    }

    /**
     * @description Queries provider contact IDs that have HPF records
     * @param providerContactIds Set of Provider Contact IDs
     * @return Set of Provider Contact IDs that have HPF records
     */
    private static Set<Id> queryProviderContactIdsWithHPF(Set<Id> providerContactIds) {
        Set<Id> providerContactIdsWithHPF = new Set<Id>();
        for (HealthcarePractitionerFacility hpf : [
            SELECT PractitionerId
            FROM HealthcarePractitionerFacility
            WHERE PractitionerId IN :providerContactIds
            WITH SYSTEM_MODE
            LIMIT 10000
        ]) {
            if (hpf.PractitionerId != null) {
                providerContactIdsWithHPF.add(hpf.PractitionerId);
            }
        }
        return providerContactIdsWithHPF;
    }

    /**
     * @description Checks if provider contact ID has other HPF records (excluding the current one)
     * @param providerContactId Provider Contact ID
     * @param excludeHPFId HPF ID to exclude from the check
     * @return Boolean true if other HPF records exist, false otherwise
     */
    public static Boolean checkProviderHasOtherHPFRecords(Id providerContactId, Id excludeHPFId) {
        if (providerContactId == null) {
            return false;
        }

        Integer count = [
            SELECT COUNT()
            FROM HealthcarePractitionerFacility
            WHERE PractitionerId = :providerContactId
                AND Id != :excludeHPFId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        return count > 0;
    }

    // ========== Primary Facility Management Methods ==========

    /**
     * @description Updates other primary facilities to false for the same providers
     * @param providerContactIds Set of Provider Contact IDs
     * @param hpfToInsert List of HPF records to be inserted
     * @param hpfToUpdate List of HPF records to be updated
     */
    public static void updateOtherPrimaryFacilities(
        Set<Id> providerContactIds,
        List<HealthcarePractitionerFacility> hpfToInsert,
        List<HealthcarePractitionerFacility> hpfToUpdate
    ) {
        if (providerContactIds.isEmpty()) {
            return;
        }

        PrimaryFacilityContext context = buildPrimaryFacilityContext(hpfToInsert, hpfToUpdate);
        List<HealthcarePractitionerFacility> hpfToDeactivate = findHPFsToDeactivate(
            providerContactIds,
            context.newPrimaryHPFIds,
            context.primaryCombinations
        );

        if (!hpfToDeactivate.isEmpty()) {
            updateHPFRecords(hpfToDeactivate);
        }
    }

    /**
     * @description Inner class to hold primary facility context
     */
    private class PrimaryFacilityContext {
        /**
         * @description Set of HPF IDs that will be primary
         */
        public Set<Id> newPrimaryHPFIds;
        /**
         * @description Set of primary combination strings
         */
        public Set<String> primaryCombinations;
    }

    /**
     * @description Builds primary facility context from HPF lists
     * @param hpfToInsert List of HPF records to be inserted
     * @param hpfToUpdate List of HPF records to be updated
     * @return PrimaryFacilityContext with populated data
     */
    private static PrimaryFacilityContext buildPrimaryFacilityContext(
        List<HealthcarePractitionerFacility> hpfToInsert,
        List<HealthcarePractitionerFacility> hpfToUpdate
    ) {
        PrimaryFacilityContext context = new PrimaryFacilityContext();
        context.newPrimaryHPFIds = collectPrimaryHPFIds(hpfToUpdate);
        context.primaryCombinations = collectPrimaryCombinations(hpfToInsert, hpfToUpdate);
        return context;
    }

    /**
     * @description Finds HPF records that need to be deactivated
     * @param providerContactIds Set of Provider Contact IDs
     * @param excludeHPFIds Set of HPF IDs to exclude
     * @param primaryCombinations Set of primary combination keys
     * @return List of HPF records to deactivate
     */
    private static List<HealthcarePractitionerFacility> findHPFsToDeactivate(
        Set<Id> providerContactIds,
        Set<Id> excludeHPFIds,
        Set<String> primaryCombinations
    ) {
        List<HealthcarePractitionerFacility> otherPrimaryHPFs = queryOtherPrimaryHPFs(providerContactIds, excludeHPFIds);
        return filterHPFsToDeactivate(otherPrimaryHPFs, primaryCombinations);
    }

    /**
     * @description Collects HPF IDs that will be set as primary from update list
     * @param hpfToUpdate List of HPF records to be updated
     * @return Set of HPF IDs that will be primary
     */
    private static Set<Id> collectPrimaryHPFIds(List<HealthcarePractitionerFacility> hpfToUpdate) {
        Set<Id> newPrimaryHPFIds = new Set<Id>();
        for (HealthcarePractitionerFacility hpf : hpfToUpdate) {
            if (isPrimaryHPFForUpdate(hpf)) {
                newPrimaryHPFIds.add(hpf.Id);
            }
        }
        return newPrimaryHPFIds;
    }

    /**
     * @description Checks if HPF record is marked as primary and has an ID (for update operations)
     * @param hpf HPF record to check
     * @return Boolean true if primary and has ID, false otherwise
     */
    private static Boolean isPrimaryHPFForUpdate(HealthcarePractitionerFacility hpf) {
        return hpf.IsPrimaryFacility == true && hpf.Id != null;
    }

    /**
     * @description Collects practice account + provider contact combinations that will be set as primary
     * @param hpfToInsert List of HPF records to be inserted
     * @param hpfToUpdate List of HPF records to be updated
     * @return Set of combination strings (AccountId_PractitionerId)
     */
    private static Set<String> collectPrimaryCombinations(
        List<HealthcarePractitionerFacility> hpfToInsert,
        List<HealthcarePractitionerFacility> hpfToUpdate
    ) {
        Set<String> primaryCombinations = new Set<String>();
        addPrimaryCombinationsFromList(hpfToInsert, primaryCombinations);
        addPrimaryCombinationsFromList(hpfToUpdate, primaryCombinations);
        return primaryCombinations;
    }

    /**
     * @description Adds primary combinations from a list of HPF records
     * @param hpfList List of HPF records
     * @param primaryCombinations Set to add combinations to
     */
    private static void addPrimaryCombinationsFromList(
        List<HealthcarePractitionerFacility> hpfList,
        Set<String> primaryCombinations
    ) {
        for (HealthcarePractitionerFacility hpf : hpfList) {
            if (!isPrimaryHPF(hpf)) {
                continue;
            }
            String combination = buildHPFCombinationKey(hpf.AccountId, hpf.PractitionerId);
            if (String.isNotBlank(combination)) {
                primaryCombinations.add(combination);
            }
        }
    }

    /**
     * @description Checks if an HPF record is marked as primary with required fields
     * @param hpf HPF record to check
     * @return Boolean true if primary and has required fields
     */
    private static Boolean isPrimaryHPF(HealthcarePractitionerFacility hpf) {
        return hpf != null 
            && hpf.IsPrimaryFacility == true 
            && hpf.AccountId != null 
            && hpf.PractitionerId != null;
    }

    /**
     * @description Builds a combination key from AccountId and PractitionerId
     * @param accountId Account ID
     * @param practitionerId Practitioner ID
     * @return Combination key string or empty string if either ID is null
     */
    private static String buildHPFCombinationKey(Id accountId, Id practitionerId) {
        if (accountId == null || practitionerId == null) {
            return '';
        }
        return String.valueOf(accountId) + '_' + String.valueOf(practitionerId);
    }

    /**
     * @description Queries other primary HPF records for the given providers
     * @param providerContactIds Set of Provider Contact IDs
     * @param excludeHPFIds Set of HPF IDs to exclude from query
     * @return List of other primary HPF records
     */
    private static List<HealthcarePractitionerFacility> queryOtherPrimaryHPFs(
        Set<Id> providerContactIds,
        Set<Id> excludeHPFIds
    ) {
        return [
            SELECT Id, AccountId, PractitionerId, IsPrimaryFacility
            FROM HealthcarePractitionerFacility
            WHERE PractitionerId IN :providerContactIds
                AND IsPrimaryFacility = true
                AND Id NOT IN :excludeHPFIds
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description Filters HPF records that need to be deactivated
     * @param otherPrimaryHPFs List of other primary HPF records
     * @param primaryCombinations Set of combination keys to exclude
     * @return List of HPF records to deactivate
     */
    private static List<HealthcarePractitionerFacility> filterHPFsToDeactivate(
        List<HealthcarePractitionerFacility> otherPrimaryHPFs,
        Set<String> primaryCombinations
    ) {
        List<HealthcarePractitionerFacility> hpfToDeactivate = new List<HealthcarePractitionerFacility>();
        for (HealthcarePractitionerFacility hpf : otherPrimaryHPFs) {
            if (shouldDeactivateHPF(hpf, primaryCombinations)) {
                hpf.IsPrimaryFacility = false;
                hpfToDeactivate.add(hpf);
            }
        }
        return hpfToDeactivate;
    }

    /**
     * @description Determines if an HPF record should be deactivated
     * @param hpf HPF record to check
     * @param primaryCombinations Set of combination keys to exclude from deactivation
     * @return Boolean true if HPF should be deactivated, false otherwise
     */
    private static Boolean shouldDeactivateHPF(
        HealthcarePractitionerFacility hpf,
        Set<String> primaryCombinations
    ) {
        String combination = buildHPFCombinationKey(hpf.AccountId, hpf.PractitionerId);
        return String.isNotBlank(combination) && !primaryCombinations.contains(combination);
    }

    // ========== DML Methods ==========

    /**
     * @description Inserts HPF records with error handling
     * @param hpfToInsert List of HPF records to insert
     */
    public static void insertHPFRecords(List<HealthcarePractitionerFacility> hpfToInsert) {
        if (hpfToInsert.isEmpty()) {
            return;
        }

        List<Database.SaveResult> results = Database.insert(hpfToInsert, false, AccessLevel.SYSTEM_MODE);
        OrgSync_LoggingUtility.handleDatabaseResults(results, hpfToInsert, new Map<String, String>{
            'className' => 'OrgSync_ProviderPracticeRelation',
            'methodName' => 'insertHPFRecords',
            'operationDescription' => 'inserting HealthcarePractitionerFacility records'
        });
    }

    /**
     * @description Updates HPF records with error handling
     * @param hpfToUpdate List of HPF records to update
     */
    public static void updateHPFRecords(List<HealthcarePractitionerFacility> hpfToUpdate) {
        if (hpfToUpdate.isEmpty()) {
            return;
        }

        List<Database.SaveResult> results = Database.update(hpfToUpdate, false, AccessLevel.SYSTEM_MODE);
        OrgSync_LoggingUtility.handleDatabaseResults(results, hpfToUpdate, new Map<String, String>{
            'className' => 'OrgSync_ProviderPracticeRelation',
            'methodName' => 'updateHPFRecords',
            'operationDescription' => 'updating HealthcarePractitionerFacility records'
        });
    }
}