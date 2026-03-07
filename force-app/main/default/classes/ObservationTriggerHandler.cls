/**
 * @description : Handles all trigger logic for the Observation object
 * Created Date : 2nd Dec 2025
 * Created By   : Yogesh Rana
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       2nd Dec 2025        Yogesh Rana            Initial Version (US - NGOMCT-752)
 */
public with sharing class ObservationTriggerHandler extends TriggerHandler {

    public override void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        Map<Id, Observation__c> updatedObservations = (Map<Id, Observation__c>) updatedRecordsMap;
        Map<Id, Observation__c> oldObservationsMap = (Map<Id, Observation__c>) oldRecordsMap;
        
        // After update logic to share the Observation records
        ObservationSharingHandler.shareObservationRecords(updatedObservations, oldObservationsMap);
    }
}