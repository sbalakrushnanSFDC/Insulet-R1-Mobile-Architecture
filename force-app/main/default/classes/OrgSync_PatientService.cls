/**
 * @description Service class for Patient (Account) synchronization.
 * Created Date : Nov 17, 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 02, 2025        Ramesh Dhaka            Initial Version
 * V1.1.0       Dec 16, 2025        Ramesh Dhaka            Updated to use OrgSync_IdentifierService and OrgSync_Patient_ACRService
 */
public inherited sharing class OrgSync_PatientService {
    /**
     * @description Map to store processed Account Ids to avoid query in same transaction.
     */
    public static Map<String, Id> processedAccountIds = new Map<String, Id>();

    /**
     * @description Context class to hold configuration for processing.
     */
    private class PatientSyncContext {
        public List<Schema.FieldSetMember> fieldSetMembers;

        /**
         * @description Constructor initializing the context object.
         */
        public PatientSyncContext() {
            this.fieldSetMembers = OrgSync_UtilityService.getFieldSetMembers('Account','OrgSync_Patient_Mapping');
        }
    }

    /********** Public Methods **********/

    /**
     * @description Upsert Patient Accounts from Staging records.
     * @param stagingRecords List of staging records to upsert.
     */
    public void upsertPatients(List<OrgSync_Patient_Staging__c> stagingRecords) {
        PatientSyncContext ctx = new PatientSyncContext();
        List<Account> accountsToUpsert = new List<Account>();

        for (OrgSync_Patient_Staging__c staging : stagingRecords) {
            Account acc = createAccountFromStaging(staging, ctx);
            if (acc != null) {
                accountsToUpsert.add(acc);
            }
        }

        if (!accountsToUpsert.isEmpty()) {
            performAccountUpsert(accountsToUpsert);
        }
    }

    /**
     * @description Delete Patient Accounts based on deleted Staging records.
     * @param stagingRecords List of deleted staging records.
     */
    public void deletePatients(List<OrgSync_Patient_Staging__c> stagingRecords) {
        Set<String> externalIds = OrgSync_UtilityService.extractExternalIds(stagingRecords);
        if (externalIds.isEmpty()) {
            return;
        }

        List<Account> accountsToDelete = queryAccountsByExternalIds(externalIds);
        if (!accountsToDelete.isEmpty()) {
            List<Database.DeleteResult> results = Database.delete(accountsToDelete, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(results, accountsToDelete, new Map<String, String>{
                'className' => 'OrgSync_PatientService',
                'methodName' => 'deletePatients',
                'operationDescription' => 'deleting patient'
            });
        }
    }

    /**
     * @description Resolves the Account Id based on the External Id.
     * @param records List of OrgSync_Patient_Staging__c records to resolve the Account Id for.
     * @return Map<String, Id> Map of External Id to Account Id.
     */
    public Map<String, Id> resolveAccountIds(List<OrgSync_Patient_Staging__c> records) {
        Set<String> externalIdsToQuery = new Set<String>();
        for (OrgSync_Patient_Staging__c reg : records) {
            if (String.isNotBlank(reg.XCDC_ExternalId__c) && !processedAccountIds.containsKey(reg.XCDC_ExternalId__c)) {
                externalIdsToQuery.add(reg.XCDC_ExternalId__c);
            }
        }

        Map<String, Id> extIdToAccountId = new Map<String, Id>(processedAccountIds);
        if (!externalIdsToQuery.isEmpty()) {
            for (Account acc : [SELECT Id, XCDC_ExternalId__c FROM Account WHERE XCDC_ExternalId__c IN :externalIdsToQuery WITH SYSTEM_MODE]) {
                extIdToAccountId.put(acc.XCDC_ExternalId__c, acc.Id);
            }
        }
        return extIdToAccountId;
    }

    /********** Private Methods **********/

    /**
     * @description Creates an Account record from a Staging record.
     * @param staging OrgSync_Patient_Staging__c record to create an Account record from.
     * @param ctx PatientSyncContext object containing the field set members.
     * @return Account Account record created from the Staging record.
     */
    private Account createAccountFromStaging(OrgSync_Patient_Staging__c staging, PatientSyncContext ctx) {
        if (String.isBlank(staging.XCDC_ExternalId__c)) {
            return null;
        }

        Account acc = new Account();
        acc.RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT;
        acc.XCDC_ExternalId__c = staging.XCDC_ExternalId__c;
        acc.BillingPostalCode = staging.OrgSync_Billing_Address__PostalCode__s;
        acc.Custom_UniqueID__c = staging.OrgSync_CustomerId__c;

        // Map fields from FieldSet
        for (Schema.FieldSetMember fsm : ctx.fieldSetMembers) {
            String targetFieldName = fsm.getFieldPath();
            String sourceFieldName = OrgSync_UtilityService.mapTargetToSourceField(targetFieldName);

            try {
                Object value = staging.get(sourceFieldName);
                acc.put(targetFieldName, value);
            } catch (Exception e) {
                Logger.error('OrgSync_PatientService: upsertPatients: Error mapping field: ' + e.getMessage()).addTag('OrgSync');
            }
        }
        return acc;
    }

    /**
     * @description Performs an Account upsert.
     * @param accountsToUpsert List of Account records to upsert.
     */
    private void performAccountUpsert(List<Account> accountsToUpsert) {
        // Prevent recursion: Add IDs to processed set BEFORE upsert
        for (Account acc : accountsToUpsert) {
            if (String.isNotBlank(acc.XCDC_ExternalId__c)) {
                processedAccountIds.put(acc.XCDC_ExternalId__c, null);
            }
        }

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
                    'className' => 'OrgSync_PatientService',
                    'methodName' => 'upsertPatients',
                    'operationDescription' => 'upserting patient'
                });
                hasErrors = true;
            }
        }
        if (hasErrors) {
            Logger.saveLog();
        }
    }


    /********** Private Methods **********/

    /**
     * @description Queries Accounts by External IDs.
     * @param externalIds Set of External IDs.
     * @return List<Account> List of Account records.
     */
    private List<Account> queryAccountsByExternalIds(Set<String> externalIds) {
        return [SELECT Id, XCDC_ExternalId__c
                FROM Account
                WHERE XCDC_ExternalId__c IN :externalIds
                AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
                WITH SYSTEM_MODE];
    }
}