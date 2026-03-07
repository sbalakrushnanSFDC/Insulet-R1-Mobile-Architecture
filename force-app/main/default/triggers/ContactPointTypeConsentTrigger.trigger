trigger ContactPointTypeConsentTrigger on ContactPointTypeConsent (before insert, before update) {
    new ContactPointTypeConsentTriggerHandler().execute();
}