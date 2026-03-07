trigger ContactPointPhoneTrigger on ContactPointPhone (before insert, after insert, after update, after delete) {
    new ContactPointPhoneTriggerHandler().execute();
}