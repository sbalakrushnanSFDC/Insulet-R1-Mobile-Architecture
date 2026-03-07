/**
 * @description Service class for syncing Patient (Account) records to Patient Staging object.
 * Created Date : Dec 02, 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 16, 2025        Ramesh Dhaka            Initial Version
 */
public inherited sharing class OrgSync_SyncPatientStageService {

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

    /**
     * @description Syncs Account changes to Staging object.
     *              Handles Scenario: Create/Update Staging record when Patient is Created/Updated.
     * @param records List of Accounts being processed.
     * @param oldMap Map of old Account records (for updates).
     */
    public void syncToStaging(List<Account> records, Map<Id, Account> oldMap) {
        try {
            PatientSyncContext ctx = new PatientSyncContext();
            List<OrgSync_Patient_Staging__c> stagingToUpsert = new List<OrgSync_Patient_Staging__c>();

            for (Account acc : records) {
                OrgSync_Patient_Staging__c staging = createStagingFromAccount(acc, ctx);
                if (staging != null) {
                    stagingToUpsert.add(staging);
                }
            }

            if (!stagingToUpsert.isEmpty()) {
                Schema.SObjectField externalIdField = OrgSync_Patient_Staging__c.Fields.XCDC_ExternalId__c;
                List<Database.UpsertResult> results = Database.upsert(stagingToUpsert, externalIdField, false, AccessLevel.SYSTEM_MODE);
                OrgSync_LoggingUtility.handleDatabaseResults(results, stagingToUpsert, new Map<String, String>{
                    'className' => 'OrgSync_SyncPatientStageService',
                    'methodName' => 'syncToStaging',
                    'operationDescription' => 'upserting patient staging'
                });
            }
        } catch (Exception e) {
            Logger.error('OrgSync_SyncPatientStageService: syncToStaging: ' + e.getMessage()).addTag('OrgSync');
        }
    }

    /**
     * @description Deletes Patient Staging records when Patient Accounts are deleted.
     * @param deletedRecords List of deleted Account records
     */
    public void deletePatientStaging(List<Account> deletedRecords) {
        Set<String> externalIds = OrgSync_UtilityService.extractExternalIdsFromAccounts(deletedRecords);
        if (externalIds.isEmpty()) {
            return;
        }

        List<OrgSync_Patient_Staging__c> stagingToDelete = [SELECT Id FROM OrgSync_Patient_Staging__c
                                                            WHERE XCDC_ExternalId__c IN :externalIds WITH SYSTEM_MODE];
        if (!stagingToDelete.isEmpty()) {
            List<Database.DeleteResult> results = Database.delete(stagingToDelete, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(results, stagingToDelete, new Map<String, String>{
                'className' => 'OrgSync_SyncPatientStageService',
                'methodName' => 'deletePatientStaging',
                'operationDescription' => 'deleting patient staging'
            });
        }
    }

    /********** Private Methods **********/

    /**
     * @description Creates a Staging record from an Account record.
     * @param acc Account record to create a Staging record from.
     * @param ctx PatientSyncContext object containing the field set members.
     * @return OrgSync_Patient_Staging__c Staging record created from the Account record.
     */
    private OrgSync_Patient_Staging__c createStagingFromAccount(Account acc, PatientSyncContext ctx) {
        // Filter: Patient Record Type ONLY
        if (acc.RecordTypeId != ConstantsUtil.ACCOUNT_PATIENT_RT || String.isBlank(acc.XCDC_ExternalId__c)) {
            return null;
        }

        // Create Staging Record
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c();
        staging.XCDC_ExternalId__c = acc.XCDC_ExternalId__c;
        staging.Name = acc.FirstName + ' ' + acc.LastName;

        for (Schema.FieldSetMember fsm : ctx.fieldSetMembers) {
            String accFieldName = fsm.getFieldPath();
            String stagingFieldName = OrgSync_UtilityService.mapTargetToSourceField(accFieldName);
            try {
                staging.put(stagingFieldName, acc.get(accFieldName));
            } catch (Exception e) {
                Logger.error('OrgSync_SyncPatientStageService: syncToStaging: Error mapping field: ' + e.getMessage()).addTag('OrgSync');
            }
        }
        return staging;
    }

}