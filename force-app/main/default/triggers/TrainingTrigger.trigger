trigger TrainingTrigger on Training__c (before insert, before update, after update , after insert) {
    new TrainingTriggerHandler().execute();
}