trigger LeadTrigger on Lead (before insert, after insert, before update, after update, before delete) {
    new LeadTriggerHandler().execute();
}