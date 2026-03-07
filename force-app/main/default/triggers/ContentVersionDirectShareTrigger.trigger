trigger ContentVersionDirectShareTrigger on ContentVersion (after insert) {
    // 1. Fetch the Group that represents your Profile/User set
    // Replacing Profile-sharing with Group-sharing
    Group targetGroup = [SELECT Id FROM Group WHERE DeveloperName = 'Porta_Users' LIMIT 1];
    
    if (targetGroup == null) return;

    List<ContentDocumentLink> shareLinks = new List<ContentDocumentLink>();

    for (ContentVersion cv : Trigger.new) {
        if (cv.ContentDocumentId != null) {
            shareLinks.add(new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId = targetGroup.Id, // Use Group ID here
                ShareType = 'V', 
                Visibility = 'AllUsers' // Required for Portal/Community access
            ));
        }
    }

    if (!shareLinks.isEmpty()) {
        Database.insert(shareLinks, false);
    }
}