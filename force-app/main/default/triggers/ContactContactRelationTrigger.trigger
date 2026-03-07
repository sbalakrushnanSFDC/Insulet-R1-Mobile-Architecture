trigger ContactContactRelationTrigger on ContactContactRelation (after insert, after update) {
    new ContactContactRelationTriggerHandler().execute();
}