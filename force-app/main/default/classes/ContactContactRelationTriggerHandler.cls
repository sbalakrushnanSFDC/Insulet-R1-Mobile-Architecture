/**
 * @description Trigger Handler for ContactContactRelation
 * Handles the logic for ContactContactRelation trigger.
 * Created Date : Dec 10, 2025
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 2, 2025        Ramesh Kumar            Initial Version
 * V1.0.1       Dec 10, 2025       Ramesh Kumar            Updated the logic to handle the trigger events.
 * V1.0.2       Jan 21, 2026       Pradip Kokate           Updated the logic to handle the Patient Stage from CCR
 */
public with sharing class ContactContactRelationTriggerHandler extends TriggerHandler {

    public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        List<ContactContactRelation> newRecords = (List<ContactContactRelation>) newRecordsMap.values();
        OrgSync_GuardianCCRHandler.handleCCRInsertForGuardianAndAuthorizedCaller(newRecords);
        OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(newRecords);
    }

    public override void afterUpdate(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<ContactContactRelation> newRecords = (List<ContactContactRelation>) newRecordsMap.values();
        Map<Id, ContactContactRelation> oldRecords = (Map<Id, ContactContactRelation>) oldRecordsMap;
        OrgSync_GuardianCCRHandler.handleCCRUpdateForGuardianAndAuthorizedCaller(newRecords, oldRecords);
        OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(newRecords);
    }

    /**
     * @description Executes at the end of the trigger execution.
     *              Saves any logs generated during the transaction.
     */
    protected override void andFinally() {
        Logger.saveLog();
    }
}