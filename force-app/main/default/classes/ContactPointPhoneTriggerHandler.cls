/**
 * @description Handler class for ContactPointPhone trigger responsible for invoking the
 *              centralized logic in OrgSync_ContactPointHandler and ContactPointPhoneHandler.
 *              It delegates processing of Insert, Update, Delete, and Undelete events.
 * Created Date : Dec 2025
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 2025            Ramesh Kumar            Initial Version
 * V1.1.0       11th Feb 2026       Charchit N.            Added ContactPointPhoneHandler integration
 */
public with sharing class ContactPointPhoneTriggerHandler extends TriggerHandler {
    /**
     * @description Handles the before insert trigger event.
     * @param newRecords List of new records from Trigger.new
     */
    public override void beforeInsert(List<SObject> newRecords) {
        ContactPointPhoneHandler.handleBeforeInsert((List<ContactPointPhone>) newRecords);
    }

    /**
     * @description Handles the after insert trigger event.
     * @param newRecordsMap Map of new records from Trigger.newMap
     */
    public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        OrgSync_ContactPointHandler obj = new OrgSync_ContactPointHandler();
        obj.sortRecordsBySObjectType(newRecordsMap,null,false);
        ContactPointPhoneHandler.handleAfterInsert((List<ContactPointPhone>) newRecordsMap.values(), newRecordsMap);
    }

    /**
     * @description Handles the after update trigger event.
     * @param updatedRecordsMap Map of updated records from Trigger.newMap
     * @param oldRecordsMap Map of old records from Trigger.oldMap
     */
    public override void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        OrgSync_ContactPointHandler obj = new OrgSync_ContactPointHandler();
        obj.sortRecordsBySObjectType(updatedRecordsMap, oldRecordsMap,false);
        ContactPointPhoneHandler.handleAfterUpdate((List<ContactPointPhone>) updatedRecordsMap.values(), updatedRecordsMap, oldRecordsMap);
    }

    /**
     * @description Handles the after delete trigger event.
     * @param deletedRecordsMap Map of deleted records from Trigger.oldMap
     */
    public override void afterDelete(Map<Id, SObject> deletedRecordsMap) {
        OrgSync_ContactPointHandler obj = new OrgSync_ContactPointHandler();
        obj.sortRecordsBySObjectType(null,deletedRecordsMap, true);
    }

    /**
     * @description Executes at the end of the trigger execution.
     *              Saves any logs generated during the transaction.
     */
    protected override void andFinally() {
        Logger.saveLog();
    }
}