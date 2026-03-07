trigger HealthcarePractitionerFacilityTrigger on HealthcarePractitionerFacility (after insert, after update) {
    new HPFTriggerHandler().execute();
}