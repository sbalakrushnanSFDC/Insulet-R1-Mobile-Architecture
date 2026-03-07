/**
 * @description Service class for Provider (Account) synchronization.
 * Created Date : Dec 06, 2026
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 06, 2026        Neeraj Kumar            Initial Version
 * V1.0.1		Feb 18, 2026		Neeraj Kumar			Added mapping for Custom Unique Id field
 */
public inherited sharing class OrgSync_ProviderService {
    /**
     * @description Map to store processed Account Ids to avoid query in same transaction.
     */
    public static Map<String, Id> processedAccountIds = new Map<String, Id>();

    /**
     * @description Context class to hold configuration for processing.
     */
    private class ProviderSyncContext {
        public List<Schema.FieldSetMember> fieldSetMembers;

        /**
         * @description Constructor initializing the context object.
         */
        public ProviderSyncContext() {
            //this.fieldSetMembers = OrgSync_UtilityService.getFieldSetMembers('OrgSync_Physician_Staging__c','OrgSync_Provider_Mapping');
            this.fieldSetMembers = getProviderFieldSetFields();
        }
    }
    /**
     * @description Upsert Provider Accounts from Staging records.
     * @param stagingRecords List of staging records to upsert.
     */
    public void upsertProviders(List<OrgSync_Physician_Staging__c> stagingRecords) {
        ProviderSyncContext ctx = new ProviderSyncContext();
        List<Account> accountsToInsert = new List<Account>();
        List<OrgSync_Physician_Staging__c> stagingForNewProviders = new List<OrgSync_Physician_Staging__c>();
        List<OrgSync_Physician_Staging__c> stagingForExistingProviders = new List<OrgSync_Physician_Staging__c>();

        // Get NPIs that already exist on another OrgSync_Physician_Staging__c record (do not create duplicate provider)
        Set<String> existingNpisInStaging = getExistingNpisInStaging(stagingRecords);
        Set<String> npisUsedInThisBatch = new Set<String>();
        for (OrgSync_Physician_Staging__c staging : stagingRecords) {
            // Do not create provider if another staging record already has the same NPI (in DB or in this batch)
            Boolean npiAlreadyExists = String.isNotBlank(staging.OrgSync_NPI__c)
                && (existingNpisInStaging.contains(staging.OrgSync_NPI__c) || npisUsedInThisBatch.contains(staging.OrgSync_NPI__c));
            if (npiAlreadyExists) {
                // NPI already on another staging record - do not create; keep for future processing
                stagingForExistingProviders.add(staging);
            } else {
                // New provider - create Account
                Account acc = createAccountFromStaging(staging, ctx);
                if (acc != null) {
                    accountsToInsert.add(acc);
                    stagingForNewProviders.add(staging);
                    if (String.isNotBlank(staging.OrgSync_NPI__c)) {
                        npisUsedInThisBatch.add(staging.OrgSync_NPI__c);
                    }
                    if (String.isNotBlank(acc.XCDC_ExternalId__c)) {
                        processedAccountIds.put(acc.XCDC_ExternalId__c, null);
                    }
                }
            }
        }

        // Process inserts - Create new Provider Accounts using XCDC_ExternalId__c
        if (!accountsToInsert.isEmpty()) {
            performAccountUpsert(accountsToInsert);
        }
    }

    /**
     * @description Performs an Account upsert using XCDC_ExternalId__c as the external ID.
     * @param accountsToUpsert List of Account records to upsert.
     */
    private void performAccountUpsert(List<Account> accountsToUpsert) {
        // processedAccountIds already populated in upsertProviders when building accountsToInsert
        Schema.SObjectField externalIdField = Account.Fields.XCDC_ExternalId__c;
        List<Database.UpsertResult> results = Database.upsert(accountsToUpsert, externalIdField, false, AccessLevel.SYSTEM_MODE);

        // Handle errors and update Map with actual Ids
        Boolean hasErrors = false;
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                Account acc = accountsToUpsert[i];
                if (String.isNotBlank(acc.XCDC_ExternalId__c)) {
                    processedAccountIds.put(acc.XCDC_ExternalId__c, results[i].getId());
                }
            } else {
                String extId = accountsToUpsert[i].XCDC_ExternalId__c;
                if (String.isNotBlank(extId)) {
                    processedAccountIds.remove(extId);
                }
                OrgSync_LoggingUtility.logErrorsWithRecord(results[i].getErrors(), accountsToUpsert[i], new Map<String, String>{
                    'className' => 'OrgSync_ProviderService',
                    'methodName' => 'upsertProviders',
                    'operationDescription' => 'upserting provider'
                });
                hasErrors = true;
            }
        }
        if (hasErrors) {
            Logger.saveLog();
        }
    }
    /**
     * @description Returns NPIs that already exist on OrgSync_Physician_Staging__c (excluding current batch).
     * If any existing staging record has the same NPI, a provider account should not be created.
     * @param stagingRecords Current batch of staging records to check against.
     * @return Set<String> NPIs that already exist on another staging record.
     */
    private Set<String> getExistingNpisInStaging(List<OrgSync_Physician_Staging__c> stagingRecords) {
        Set<String> existingNpis = new Set<String>();
        Set<String> npiValues = new Set<String>();
        Set<Id> currentStagingIds = new Set<Id>();

        for (OrgSync_Physician_Staging__c staging : stagingRecords) {
            if (String.isNotBlank(staging.OrgSync_NPI__c)) {
                npiValues.add(staging.OrgSync_NPI__c);
            }
            if (staging.Id != null) {
                currentStagingIds.add(staging.Id);
            }
        }

        if (npiValues.isEmpty()) {
            return existingNpis;
        }

        for (OrgSync_Physician_Staging__c stage : [
            SELECT Id, OrgSync_NPI__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c IN :npiValues
            AND OrgSync_NPI__c != null
            WITH SYSTEM_MODE
        ]) {
            // Only treat as "existing" if it's outside the current batch
            if (currentStagingIds.isEmpty() || !currentStagingIds.contains(stage.Id)) {
                existingNpis.add(stage.OrgSync_NPI__c);
            }
        }

        return existingNpis;
    }

    /**
     * @description Checks for existing practices based on NPI number after provider creation.
     * @param stagingRecords List of staging records for newly created providers.
     */
    /*private void processExistingPractices(List<OrgSync_Physician_Staging__c> stagingRecords) {
        // TODO: Implement practice lookup based on OrgSync_Parent_Practice__c (NPI)
    }*/
    /**
     * @description Creates an Account record from a Staging record.
     * @param staging OrgSync_Physician_Staging__c record to create an Account record from.
     * @param ctx ProviderSyncContext object containing the field set members.
     * @return Account Account record created from the Staging record.
     */
    private Account createAccountFromStaging(OrgSync_Physician_Staging__c staging, ProviderSyncContext ctx) {
        if (String.isBlank(staging.XCDC_ExternalId__c)) {
            return null;
        }

        Account acc = new Account();
        acc.RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT;
        acc.XCDC_ExternalId__c = staging.XCDC_ExternalId__c;
        acc.BillingPostalCode = staging.OrgSync_Mailing_Address__PostalCode__s;
        acc.Custom_UniqueID__c = staging.OrgSync_NPI__c;
        // Map fields from FieldSet
        for (Schema.FieldSetMember fsm : ctx.fieldSetMembers) {
            String targetFieldName = fsm.getFieldPath();
            String sourceFieldName = OrgSync_UtilityService.mapTargetToSourceField(targetFieldName);

            try {
                Object value = staging.get(sourceFieldName);
                acc.put(targetFieldName, value);
            } catch (Exception e) {
                Logger.error('OrgSync_ProviderService: upsertProviders: Error mapping field: ' + e.getMessage()).addTag('OrgSync');
            }
        }
        return acc;
    }
    /**
     * @description Resolves the Account Id based on the External Id.
     * @param records List of OrgSync_Provider_Staging__c records to resolve the Account Id for.
     * @return Map<String, Id> Map of External Id to Account Id.
     */
    public Map<String, Id> resolveAccountIds(List<OrgSync_Physician_Staging__c> records) {
        Map<String, Id> processedIds = (processedAccountIds != null) ? processedAccountIds : new Map<String, Id>();
        Map<String, Id> extIdToAccountId = new Map<String, Id>(processedIds);
        if (records == null || records.isEmpty()) {
            return extIdToAccountId;
        }

        Set<String> externalIdsToQuery = new Set<String>();
        for (OrgSync_Physician_Staging__c reg : records) {
            if (reg != null && String.isNotBlank(reg.XCDC_ExternalId__c) && !processedIds.containsKey(reg.XCDC_ExternalId__c)) {
                externalIdsToQuery.add(reg.XCDC_ExternalId__c);
            }
        }
        if (!externalIdsToQuery.isEmpty()) {
            for (Account acc : [SELECT Id, XCDC_ExternalId__c FROM Account WHERE XCDC_ExternalId__c IN :externalIdsToQuery WITH SYSTEM_MODE]) {
                if (acc != null && acc.XCDC_ExternalId__c != null) {
                    extIdToAccountId.put(acc.XCDC_ExternalId__c, acc.Id);
                }
            }
        }
        return extIdToAccountId;
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