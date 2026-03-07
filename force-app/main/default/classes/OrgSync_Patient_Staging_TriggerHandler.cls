/**
 * @description Trigger handler for OrgSync_Patient_Staging__c object.
 *              Extends the standard TriggerHandler framework.
 * Created Date : Nov 17, 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 02, 2025        Ramesh Dhaka            Initial Version
 * V1.0.1       21 Jan, 2026        Pradip Kokate           Updated to process Patient Provider Relations
 */
public with sharing class OrgSync_Patient_Staging_TriggerHandler extends TriggerHandler {

    private OrgSync_PatientHandler patientHandler;
    private OrgSync_ContactPointHandler contactPointHandler;
    private OrgSync_PatientDelegateHandler delegateHandler;
    private static Id orgSyncUserId;

     /**
     * @description sattic variable to check if the trigger is running from test.
     */
    public static boolean isRunningFromTest = false;

    /**
     * @description Constructor initializing the handlers
     */
    public OrgSync_Patient_Staging_TriggerHandler() {
        this.patientHandler = new OrgSync_PatientHandler();
        this.contactPointHandler = new OrgSync_ContactPointHandler();
        this.delegateHandler = new OrgSync_PatientDelegateHandler();
    }

    /**
     * @description Handles the before insert trigger event.
     * @param newRecords Map of new records from Trigger.newMap
     */
    public override void beforeInsert(List<SObject> newRecords) {
        List<OrgSync_Patient_Staging__c> newRecordList = (List<OrgSync_Patient_Staging__c>)newRecords;
        OrgSync_PublishSettingService.invokeOrgSync(newRecordList, null, XCDC_Constants.OPERATION_INSERT);
    }

    /**
     * @description Handles the after insert trigger event.
     * @param newRecordsMap Map of new records from Trigger.newMap
     */
    public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        List<OrgSync_Patient_Staging__c> newRecords = (List<OrgSync_Patient_Staging__c>)newRecordsMap.values();
        if (OrgSync_UtilityService.isOrgSyncUser() || isRunningFromTest) {
            // 1. Process Patient Records
            patientHandler.handlePatientUpsertFromStaging(newRecords, null);
            // 2. Process Contact Point Objects
            contactPointHandler.handleInsert(newRecords);
            // 3. Process Patient Delegates
            delegateHandler.handleInsert(newRecords);
            // 4. Process Patient Provider Relations
            OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(newRecords);
        }
    }

    /**
     * @description Handles the before update trigger event.
     * @param newRecordsMap Map of new records from Trigger.newMap
     * @param oldRecordsMap Map of old records from Trigger.oldMap
     */
    public override void beforeUpdate(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<OrgSync_Patient_Staging__c> newRecords = (List<OrgSync_Patient_Staging__c>)newRecordsMap.values();
        Map<Id, OrgSync_Patient_Staging__c> oldMap = (Map<Id, OrgSync_Patient_Staging__c>)oldRecordsMap;
        OrgSync_PublishSettingService.invokeOrgSync(newRecords, oldMap, XCDC_Constants.OPERATION_UPDATE);
    }
    /**
     * @description Handles the after update trigger event.
     * @param newRecordsMap Map of new records from Trigger.newMap
     * @param oldRecordsMap Map of old records from Trigger.oldMap
     */
    public override void afterUpdate(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<OrgSync_Patient_Staging__c> newRecords = (List<OrgSync_Patient_Staging__c>)newRecordsMap.values();
        Map<Id, OrgSync_Patient_Staging__c> oldMap = (Map<Id, OrgSync_Patient_Staging__c>)oldRecordsMap;

        if (OrgSync_UtilityService.isOrgSyncUser()) {
            // 1. Process Patient Records
            patientHandler.handlePatientUpsertFromStaging(newRecords, oldMap);
            // 2. Process Contact Point Objects
            contactPointHandler.handleUpdate(newRecords, oldMap);
            // 3. Process Patient Delegates
            delegateHandler.handleUpdate(newRecords, oldMap);
            // 4. Process Patient Provider Relations
            OrgSync_PatientProviderRelation.createOrUpdatePatientProviderRelations(newRecords);
        }
    }

    /**
     * @description Handles the after delete trigger event.
     * @param oldRecordsMap Map of old records from Trigger.oldMap
     */
    public override void afterDelete(Map<Id, SObject> oldRecordsMap) {
        Map<Id, OrgSync_Patient_Staging__c> oldMap = (Map<Id, OrgSync_Patient_Staging__c>)oldRecordsMap;
        List<OrgSync_Patient_Staging__c> oldRecords = oldMap.values();

        if (OrgSync_UtilityService.isOrgSyncUser()) {
            // 1. Process Patient Records
            patientHandler.handlePatientDeleteFromStaging(oldRecords);
        }
    }

    /**
     * @description Executes at the end of the trigger execution.
     *              Saves any logs generated during the transaction.
     */
    protected override void andFinally() {
        Logger.saveLog();
    }
}