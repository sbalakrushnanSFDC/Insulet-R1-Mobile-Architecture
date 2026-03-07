/**
 * @description Handler class for Provider (Account) synchronization.
 * Created Date : Dec 06, 2026
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 06, 2026        Neeraj Kumar            Initial Version
 */
public with sharing class OrgSync_ProviderHandler {
    private OrgSync_ProviderService syncProviderService;
    private OrgSync_IdentifierService identifierService;
    /**
     * @description Constructor initializing the service
     */
    public OrgSync_ProviderHandler() {
        this.syncProviderService = new OrgSync_ProviderService();
        this.identifierService = new OrgSync_IdentifierService();
     }
     /* @description Handles the before insert logic for Practice Account records.
     * Filters eligible records and invokes OrgSync_PublishSettingService.
     * @param records List of Account records
     */
    public static void handleBeforeInsert(List<Account> records) {
        List<Account> eligibleRecords = filterPracticeRecords(records);
        if (eligibleRecords.size() > 0) {
            OrgSync_PublishSettingService.invokeOrgSync(eligibleRecords, null, XCDC_Constants.OPERATION_INSERT);
        }
    }
     /**
     * @description Handles upsert logic (Insert and Update) from Staging to Provider.
     *              Sequence: 1. Upsert Providers, 2. Create Identifiers, 3. Manage ACRs
     * @param newRecords List of new staging records
     * @param oldMap Map of old staging records (null for insert)
     */
    public void handleProviderUpsertFromStaging(List<OrgSync_Physician_Staging__c> newRecords, Map<Id, OrgSync_Physician_Staging__c> oldMap) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }
        OrgSync_ProviderService providerService = (syncProviderService != null) ? syncProviderService : new OrgSync_ProviderService();
        if (syncProviderService == null) {
            syncProviderService = providerService;
        }
        // Step 1: Upsert Provider Accounts first
        providerService.upsertProviders(newRecords);

        // Resolve Account IDs once
        Map<String, Id> extIdToAccountId = providerService.resolveAccountIds(newRecords);

        // Step 2: Create Identifiers only on insert (not on update)
        if (Trigger.isInsert) {
            processIdentifiers(newRecords, oldMap, extIdToAccountId);
        }
    }
    /**
     * @description Checks if an Account record is eligible (has Practice record type).
     * @param account Account record to check
     * @return Boolean True if account has Practice record type, false otherwise
     */
    private static Boolean isEligible(Account account) {
        if (account == null) {
            return false;
        }
        return account.RecordTypeId == ConstantsUtil.ACCOUNT_PROVIDER_RT;
    }
    /**
     * @description Filters the list of Accounts to return only Provider records.
     * @param records List of Account records
     * @return List<Account> List of Provider Account records
     */
    private static List<Account> filterProviderRecords(List<Account> records) {
        List<Account> providerRecords = new List<Account>();
        if (records == null) {
            return providerRecords;
        }

        for (Account acc : records) {
            if (acc.RecordTypeId == ConstantsUtil.ACCOUNT_PROVIDER_RT) {
                providerRecords.add(acc);
            }
        }
        return providerRecords;
    }
    /**
     * @description Handles the synchronization from Account (Provider) to Staging (Insert/Update).
     *              Filters records based on the User context (Not OrgSync User) to break recursion.
     *              Handles both Before (ID generation) and After (Sync to Staging) logic.
     * @param records List of Account records
     * @param oldMap Map of old Account records
     */
    public static void handleUpsertProviderToStaging(List<Account> records, Map<Id, Account> oldMap) {
        // Condition: "when any user update/Create provider record then check whether current user is not OrgSync User"
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            return;
        }
        List<Account> providerRecords = filterProviderRecords(records);
        if (providerRecords.isEmpty()) {
            return;
        }

        if (Trigger.isBefore) {
            OrgSync_PublishSettingService.generateExternalId(providerRecords);
        }

        if (Trigger.isAfter) {
            OrgSync_SyncPhysicianStageService syncProviderStageService = new OrgSync_SyncPhysicianStageService();
            syncProviderStageService.syncToStaging(providerRecords, oldMap);
        }
    }
    /**
     * @description Helper to process Identifier creation.
     * @param records List of staging records.
     * @param oldMap Map of old staging records.
     * @param extIdToAccountId Map of External ID to Account ID.
     */
    @TestVisible
    private void processIdentifiers(List<OrgSync_Physician_Staging__c> records, Map<Id, OrgSync_Physician_Staging__c> oldMap, Map<String, Id> extIdToAccountId) {
        if (records == null || records.isEmpty() || extIdToAccountId.isEmpty()) {
            return;
        }

        Map<String, String> extIdToIdentifierValue = new Map<String, String>();
        for (OrgSync_Physician_Staging__c reg : records) {
            String newVal = reg.OrgSync_NPI__c;
            if (String.isBlank(newVal) || String.isBlank(reg.XCDC_ExternalId__c)) {
                continue;
            }

            // Check if changed from null to non-null
            // If Insert (oldMap is null), previous is considered null.
            String oldVal = (oldMap != null && oldMap.containsKey(reg.Id)) ? oldMap.get(reg.Id).OrgSync_NPI__c : null;

            if (oldVal == null && String.isNotBlank(newVal)) {
                extIdToIdentifierValue.put(reg.XCDC_ExternalId__c, newVal);
            }
        }

        if (!extIdToIdentifierValue.isEmpty()) {
            identifierService.createIdentifiers(extIdToAccountId, extIdToIdentifierValue, 'NPI');
        }
    }
	/**
     * @description Filters the list of Accounts to return only Practice records.
     * @param records List of Account records
     * @return List<Account> List of Practice Account records
     */
    private static List<Account> filterPracticeRecords(List<Account> records) {
        List<Account> practiceRecords = new List<Account>();
        if (records == null) {
            return practiceRecords;
        }

        for (Account acc : records) {
            if (isEligible(acc)) {
                practiceRecords.add(acc);
            }
        }
        return practiceRecords;
    }
}