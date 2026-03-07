trigger ContactPointEmailTrigger on ContactPointEmail (before insert, after insert, after update, after delete) {
    new ContactPointEmailTriggerHandler().execute();
}