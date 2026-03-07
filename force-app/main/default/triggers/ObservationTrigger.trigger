trigger ObservationTrigger on Observation__c (after update) {
    new ObservationTriggerHandler().execute();
}