trigger AccountContactRelationTrigger on AccountContactRelation (after insert, after update, after delete) {
    new AccountContactRelationTriggerHandler().execute();
}