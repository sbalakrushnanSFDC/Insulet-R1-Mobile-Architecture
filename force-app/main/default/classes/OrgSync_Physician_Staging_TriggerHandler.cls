/**
 * @description Trigger handler for OrgSync_Physician_Staging__c object.
 *              Extends the standard TriggerHandler framework.
 * Created Date : Jan 06, 2026
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 06, 2026        Neeraj Kumar            Initial Version
 * V1.0.1       Jan 27, 2026        Pradip Kokate           Updated to create/update HPF records.
 * V1.0.2		Feb 24, 2026		Neeraj Kumar			Added changes for demographics
 */
public with sharing class OrgSync_Physician_Staging_TriggerHandler extends TriggerHandler {
    private OrgSync_ProviderHandler providerHandler;
    private OrgSync_ContactPointHandler contactPointHandler;
    /**
     * @description Constructor initializing the handlers
     */
    public OrgSync_Physician_Staging_TriggerHandler() {
        this.providerHandler = new OrgSync_ProviderHandler();
        this.contactPointHandler = new OrgSync_ContactPointHandler();
    }
    /**
     * @description Handles the before insert trigger event.
     * @param newRecords Map of new records from Trigger.newMap
     */
    public override void beforeInsert(List<SObject> newRecords) {
        List<OrgSync_Physician_Staging__c> newRecordList = (List<OrgSync_Physician_Staging__c>)newRecords;
        OrgSync_PublishSettingService.invokeOrgSync(newRecordList, null, XCDC_Constants.OPERATION_INSERT);
    }
    /**
     * @description Handles the after insert trigger event.
     * @param newRecordsMap Map of new records from Trigger.newMap
     */
    public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        List<OrgSync_Physician_Staging__c> newRecords = (List<OrgSync_Physician_Staging__c>)newRecordsMap.values();
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            // 1. Process Provider Records
            providerHandler.handleProviderUpsertFromStaging(newRecords, null);
            // Create/Update HPF records
            OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(newRecords);
            // Create Contact Point records
            contactPointHandler.handlePhysicianUpsert(newRecords,new Map<Id, OrgSync_Physician_Staging__c>());
        }
    }
    /**
     * @description Handles the before update trigger event.
     * @param newRecordsMap Map of new records from Trigger.newMap
     * @param oldRecordsMap Map of old records from Trigger.oldMap
     */
    public override void beforeUpdate(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<OrgSync_Physician_Staging__c> newRecords = (List<OrgSync_Physician_Staging__c>)newRecordsMap.values();
        Map<Id, OrgSync_Physician_Staging__c> oldMap = (Map<Id, OrgSync_Physician_Staging__c>)oldRecordsMap;
        OrgSync_PublishSettingService.invokeOrgSync(newRecords, oldMap, XCDC_Constants.OPERATION_UPDATE);
    }
    /**
     * @description Handles the after update trigger event.
     * @param newRecordsMap Map of new records from Trigger.newMap
     * @param oldRecordsMap Map of old records from Trigger.oldMap
     */
    public override void afterUpdate(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<OrgSync_Physician_Staging__c> newRecords = (List<OrgSync_Physician_Staging__c>)newRecordsMap.values();
        Map<Id, OrgSync_Physician_Staging__c> oldMap = (Map<Id, OrgSync_Physician_Staging__c>)oldRecordsMap;
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            //Process Provider Records (pass oldMap so handler can treat as update)
            providerHandler.handleProviderUpsertFromStaging(newRecords, oldMap);
            //Create Contact Point records
            contactPointHandler.handlePhysicianUpsert(newRecords,new Map<Id, OrgSync_Physician_Staging__c>());
        }
    }

}