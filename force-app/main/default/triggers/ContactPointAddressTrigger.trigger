trigger ContactPointAddressTrigger on ContactPointAddress (before insert, after insert, after update, after delete) {
    new ContactPointAddressTriggerHandler().execute();
}