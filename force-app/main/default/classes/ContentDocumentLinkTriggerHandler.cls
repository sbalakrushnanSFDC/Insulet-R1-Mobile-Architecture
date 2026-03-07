/**
 * @author      : Rohan Saxena
 * @created Date: 23rd Dec 2025
 * @description : Content Document Link Handler Class
 * @story Number: NGOMCT-936
 * Version      Modified Date       Modified By         Brief Note
 */
public with sharing class ContentDocumentLinkTriggerHandler extends TriggerHandler{
	public override void beforeInsert(List<SObject> newRecords) {
        List<ContentDocumentLink> newTrainings = (List<ContentDocumentLink>) newRecords;
        ContentDocumentLinkTriggerHelper.changeDocusignFileVisibility(newTrainings);
    }
}