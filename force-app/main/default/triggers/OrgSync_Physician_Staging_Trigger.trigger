trigger OrgSync_Physician_Staging_Trigger on OrgSync_Physician_Staging__c (before insert, after insert, before update, after update) {
	new OrgSync_Physician_Staging_TriggerHandler().execute();
}