/**
 * @description Trigger Handler for HealthcarePractitionerFacility
 * Handles the logic for HealthcarePractitionerFacility trigger.
 * Created Date : Jan 23, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 23, 2026        Pradip Kokate           Initial Version
 * V2.0.1		Feb 24, 2026		Neeraj Kumar			Added invocation of Demographics method to sync primary cp records
 */
public with sharing class HPFTriggerHandler extends TriggerHandler {

    public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        List<HealthcarePractitionerFacility> newRecords = (List<HealthcarePractitionerFacility>) newRecordsMap.values();
        // Create Physician Staging records for new HPF records if needed
        OrgSync_HandleHPFInsertion.handleHPFInsertion(newRecords);
    }

    public override void afterUpdate(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<HealthcarePractitionerFacility> newRecords = (List<HealthcarePractitionerFacility>) newRecordsMap.values();
        Map<Id, HealthcarePractitionerFacility> oldRecords = (Map<Id, HealthcarePractitionerFacility>) oldRecordsMap;

        // Update OrgSync_Do_Not_Use__c on Physician Staging records when HPF IsActive field changes
        OrgSync_HPFProcess.updatePhysicianStagingOnIsActiveChange(newRecords, oldRecords);

        // Sync Phone, Email, Mailing Address on Physician Staging when HPF contact point lookups change.
        if (!OrgSync_UtilityService.isOrgSyncUser()) {
            new OrgSync_ProviderDemographicsSync().syncStagingFromHPFContactPointLookupChange(newRecords, oldRecords);
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