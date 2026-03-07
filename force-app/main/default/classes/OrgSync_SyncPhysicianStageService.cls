/**
 * @description Trigger handler for OrgSync_Physician_Staging__c object.
 *              Extends the standard TriggerHandler framework.
 * Created Date : Jan 06, 2026
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 06, 2026        Neeraj Kumar            Initial Version
 * V1.0.1       Jan 27, 2026        Pradip Kokate           Updated to create/update HPF records.
 * V1.0.2		Feb 18, 2026		Neeraj Kumar			Added mapping for Custom Unique Id field
 * V1.0.3		Feb 20, 2026		Neeraj Kumar			On account update, update all staging records where OrgSync_NPI__c = Custom_UniqueID__c
 * V1.0.4		Feb 24, 2026		Neeraj Kumar			Cached staging query/DML per transaction to avoid redundant work on second invocation
 * V1.0.5		Feb 26, 2026		Neeraj Kumar			Skip XCDC_ExternalId__c in update path to preserve HPF composite ID on reverse sync
 */
public inherited sharing class OrgSync_SyncPhysicianStageService {
    /** Cache of NPI set keys already processed this transaction to avoid redundant query/DML on second invocation. */
    private static Set<String> processedNpiSetKeys;

    /**
     * @description Context class to hold configuration for processing.
     */
    private class ProviderSyncContext {
        public List<Schema.FieldSetMember> fieldSetMembers;

        /**
         * @description Constructor initializing the context object.
         */
        public ProviderSyncContext() {
            this.fieldSetMembers = getProviderFieldSetFields(); 
        }
    }
    /**
     * @description Syncs Account changes to Staging object.
     * @Handles Scenario: Create/Update Staging record when Provider is Created/Updated.
     * - On insert: upserts one staging per account keyed by XCDC_ExternalId__c.
     * - On update: finds all staging records where OrgSync_NPI__c = account.Custom_UniqueID__c and updates them.
     * @param records List of Accounts being processed.
     * @param oldMap Map of old Account records (for updates).
     */
    public void syncToStaging(List<Account> records, Map<Id, Account> oldMap) {
        try {
            ProviderSyncContext ctx = new ProviderSyncContext();

            if (oldMap != null && !oldMap.isEmpty()) {
                // Update path: find all physician staging records by Custom_UniqueID__c (OrgSync_NPI__c) and update them
                updateStagingByCustomUniqueId(records, ctx);
                return;
            }

            // Insert path: create/upsert one staging per account by XCDC_ExternalId__c
            List<OrgSync_Physician_Staging__c> stagingToUpsert = new List<OrgSync_Physician_Staging__c>();
            for (Account acc : records) {
                OrgSync_Physician_Staging__c staging = createStagingFromAccount(acc, ctx);
                if (staging != null) {
                    stagingToUpsert.add(staging);
                }
            }

            if (!stagingToUpsert.isEmpty()) {
                Schema.SObjectField externalIdField = OrgSync_Physician_Staging__c.Fields.XCDC_ExternalId__c;
                List<Database.UpsertResult> results = Database.upsert(stagingToUpsert, externalIdField, false, AccessLevel.SYSTEM_MODE);
                OrgSync_LoggingUtility.handleDatabaseResults(results, stagingToUpsert, new Map<String, String>{
                    'className' => 'OrgSync_SyncPhysicianStageService',
                    'methodName' => 'syncToStaging',
                    'operationDescription' => 'upserting provider staging'
                });
            }
        } catch (Exception e) {
            Logger.error('OrgSync_SyncPhysicianStageService: syncToStaging: ' + e.getMessage()).addTag('OrgSync');
        }
    }

    /**
     * @description On account update, finds all physician staging records where OrgSync_NPI__c equals
     * the account's Custom_UniqueID__c (or NPI from Identifier when blank) and updates them.
     * Re-queries Accounts to ensure all field-set fields are populated (trigger records may be partial).
     * @param records List of Provider Accounts being processed (after update).
     * @param ctx ProviderSyncContext with field set members.
     */
    private void updateStagingByCustomUniqueId(List<Account> records, ProviderSyncContext ctx) {
        Set<Id> providerAccountIds = new Set<Id>();
        for (Account acc : records) {
            if (acc.RecordTypeId != ConstantsUtil.ACCOUNT_PROVIDER_RT) {
                continue;
            }
            providerAccountIds.add(acc.Id);
        }
        if (providerAccountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> fullAccountMap = requeryProviderAccountsWithFieldSet(providerAccountIds, ctx);
        Map<Id, String> accountIdToNpi = OrgSync_UtilityService.getProviderNPIs(providerAccountIds);
        Set<String> npiSet = new Set<String>();
        Map<String, Account> npiToAccount = new Map<String, Account>();

        for (Account acc : fullAccountMap.values()) {
            String npi = String.isNotBlank(acc.Custom_UniqueID__c) ? acc.Custom_UniqueID__c : accountIdToNpi.get(acc.Id);
            if (String.isNotBlank(npi)) {
                npiSet.add(npi);
                npiToAccount.put(npi, acc);
            }
        }
        if (npiSet.isEmpty()) {
            return;
        }

        String cacheKey = getStagingCacheKey(npiSet);
        if (processedNpiSetKeys != null && processedNpiSetKeys.contains(cacheKey)) {
            return;
        }
        if (processedNpiSetKeys == null) {
            processedNpiSetKeys = new Set<String>();
        }

        List<OrgSync_Physician_Staging__c> stagingToUpdate = [
            SELECT Id, OrgSync_NPI__c, Name
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c IN :npiSet
            AND OrgSync_NPI__c != null
            WITH SYSTEM_MODE
        ];

        for (OrgSync_Physician_Staging__c staging : stagingToUpdate) {
            Account acc = npiToAccount.get(staging.OrgSync_NPI__c);
            if (acc != null) {
                applyAccountToStaging(acc, staging, ctx);
            }
        }

        if (!stagingToUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(stagingToUpdate, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(results, stagingToUpdate, new Map<String, String>{
                'className' => 'OrgSync_SyncPhysicianStageService',
                'methodName' => 'updateStagingByCustomUniqueId',
                'operationDescription' => 'updating provider staging by NPI'
            });
        }
        processedNpiSetKeys.add(cacheKey);
    }

    /**
     * @description Builds a stable cache key from NPI set for transaction-scoped deduplication.
     * @param npiSet Set of NPI values.
     * @return String Sorted, comma-separated NPIs.
     */
    private static String getStagingCacheKey(Set<String> npiSet) {
        List<String> sorted = new List<String>(npiSet);
        sorted.sort();
        return String.join(sorted, ',');
    }

    private Map<Id, Account> requeryProviderAccountsWithFieldSet(Set<Id> accountIds, ProviderSyncContext ctx) {
        List<Account> accounts = OrgSync_UtilityService.queryAccountsWithFieldSet(accountIds, ctx.fieldSetMembers);
        Map<Id, Account> result = new Map<Id, Account>();
        for (Account a : accounts) {
            result.put(a.Id, a);
        }
        return result;
    }

    /**
     * @description Applies Account field values to an existing Staging record (same mapping as createStagingFromAccount).
     * @param acc Account record.
     * @param staging Existing staging record to update.
     * @param ctx ProviderSyncContext with field set members.
     */
    private void applyAccountToStaging(Account acc, OrgSync_Physician_Staging__c staging, ProviderSyncContext ctx) {
        staging.Name = acc.FirstName + ' ' + acc.LastName;
        staging.OrgSync_NPI__c = acc.Custom_UniqueID__c;
        for (Schema.FieldSetMember fsm : ctx.fieldSetMembers) {
            String accFieldName = fsm.getFieldPath();
            if (accFieldName == 'XCDC_ExternalId__c') {
                continue;
            }
            String stagingFieldName = OrgSync_UtilityService.mapTargetToSourceField(accFieldName);
            try {
                staging.put(stagingFieldName, acc.get(accFieldName));
            } catch (Exception e) {
                Logger.error('OrgSync_SyncPhysicianStageService: applyAccountToStaging: Error mapping field: ' + e.getMessage()).addTag('OrgSync');
            }
        }
    }
    /**
     * @description Creates a Staging record from an Account record.
     * @param acc Account record to create a Staging record from.
     * @param ctx PatientSyncContext object containing the field set members.
     * @return OrgSync_Patient_Staging__c Staging record created from the Account record.
     */
    private OrgSync_Physician_Staging__c createStagingFromAccount(Account acc, ProviderSyncContext ctx) {
        // Filter: Patient Record Type ONLY
        if (acc.RecordTypeId != ConstantsUtil.ACCOUNT_PROVIDER_RT || String.isBlank(acc.XCDC_ExternalId__c)) {
            return null;
        }

        // Create Staging Record
        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c();
        staging.XCDC_ExternalId__c = acc.XCDC_ExternalId__c;
        staging.Name = acc.FirstName + ' ' + acc.LastName;
        staging.OrgSync_NPI__c = acc.Custom_UniqueID__c;

        for (Schema.FieldSetMember fsm : ctx.fieldSetMembers) {
            String accFieldName = fsm.getFieldPath();
            String stagingFieldName = OrgSync_UtilityService.mapTargetToSourceField(accFieldName);
            try {
                staging.put(stagingFieldName, acc.get(accFieldName));
            } catch (Exception e) {
                Logger.error('OrgSync_SyncPhysicianStageService: syncToStaging: Error mapping field: ' + e.getMessage()).addTag('OrgSync');
            }
        }
        return staging;
    }
    
    /**
     * @description Gets the field set members for the Provider field set.
     * @return List<Schema.FieldSetMember> List of field set members.
     */
    private static List<Schema.FieldSetMember> getProviderFieldSetFields() {
        Schema.FieldSet fs = Schema.SObjectType.Account.fieldSets.getMap().get('OrgSync_Provider_Mapping');
        if (fs != null) {
            return fs.getFields();
        }
        return new List<Schema.FieldSetMember>();
    }
}