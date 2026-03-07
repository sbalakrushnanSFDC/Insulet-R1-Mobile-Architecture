trigger OrgSync_Patient_Staging_Trigger on OrgSync_Patient_Staging__c (before insert, after insert, before update, after update, after delete) {
    new OrgSync_Patient_Staging_TriggerHandler().execute();
}