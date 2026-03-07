/**
 * @description Handler class for AccountContactRelation trigger responsible for invoking the
 *              centralized logic in OrgSync_ACRHandler.
 *              It delegates processing of Insert, Update, and Delete events.
 * Created Date : Dec 2025
 * Created By   : Ramesh Dhaka
 */
public with sharing class AccountContactRelationTriggerHandler extends TriggerHandler {

    /**
     * @description Handles the after insert trigger event.
     * @param newRecordsMap Map of new records from Trigger.newMap
     */
    public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        new OrgSync_ACRHandler().handleAfterInsert((List<AccountContactRelation>)newRecordsMap.values());
    }

    /**
     * @description Handles the after update trigger event.
     * @param updatedRecordsMap Map of updated records from Trigger.newMap
     * @param oldRecordsMap Map of old records from Trigger.oldMap
     */
    public override void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        new OrgSync_ACRHandler().handleAfterUpdate((List<AccountContactRelation>)updatedRecordsMap.values(), (Map<Id, AccountContactRelation>)oldRecordsMap);
    }

    /**
     * @description Handles the after delete trigger event.
     * @param deletedRecordsMap Map of deleted records from Trigger.oldMap
     */
    public override void afterDelete(Map<Id, SObject> deletedRecordsMap) {
        new OrgSync_ACRHandler().handleAfterDelete((Map<Id, AccountContactRelation>)deletedRecordsMap);
    }

    /**
     * @description Executes at the end of the trigger execution.
     *              Saves any logs generated during the transaction.
     */
    protected override void andFinally() {
        Logger.saveLog();
    }
}