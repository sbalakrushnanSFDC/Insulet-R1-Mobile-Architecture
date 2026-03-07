trigger ContentDocumentLinkTrigger on ContentDocumentLink (before insert) {
new ContentDocumentLinkTriggerHandler().execute();
}