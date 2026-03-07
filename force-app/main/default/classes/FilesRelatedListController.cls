/**
 * @description : The FilesRelatedListController provides server-side logic for retrieving
 * all ContentDocument files associated with a specific Salesforce record.
 * Jira Story Number: NGOMCT-724
 * Developer: Srinivas
 * Date: 30/11/2025
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       30th Nov 2025       Srinivas                Initial (NGOMCT-724)
 */
public with sharing class FilesRelatedListController {
    
    /**
     * @description Retrieves a list of files for a specified record.
     * @param recordId The Id of the record.
     * @return A list of FileItem objects.
     */
    @AuraEnabled(cacheable=true)
    public static List<FileItem> getFilesForRecord(String recordId) {
        
        try{
            if (recordId == null) {
                throw new AuraHandledException('Invalid Record Id '+recordId);
            }
            
            List<ContentDocumentLink> contentDocumentlinks = [
            SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.FileExtension,
                   ContentDocument.Owner.Name,
                   ContentDocument.LatestPublishedVersionId,
                   ContentDocument.LatestPublishedVersion.ContentSize,
                   ContentDocument.LatestPublishedVersion.FileType,
                   ContentDocument.LatestPublishedVersion.LastModifiedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId WITH USER_MODE
            ORDER BY ContentDocument.LatestPublishedVersion.LastModifiedDate DESC 
        ];
            List<FileItem> fileItemOutList = new List<FileItem>();
            String downloadURL = Label.File_Download_URL;
            
            for (ContentDocumentLink contentDocumentlinkRec : contentDocumentlinks) {
                FileItem fileItem = new FileItem();
                fileItem.contentDocumentId = contentDocumentlinkRec.ContentDocumentId;
                fileItem.versionId = contentDocumentlinkRec.ContentDocument.LatestPublishedVersionId;
                fileItem.title = contentDocumentlinkRec.ContentDocument.Title;
                fileItem.fileExtension = contentDocumentlinkRec.ContentDocument.FileExtension;
                fileItem.fileType = String.valueOf(contentDocumentlinkRec.ContentDocument.LatestPublishedVersion.FileType);
                fileItem.contentSize = (Integer) contentDocumentlinkRec.ContentDocument.LatestPublishedVersion.ContentSize;
                fileItem.lastModifiedDate = contentDocumentlinkRec.ContentDocument.LatestPublishedVersion.LastModifiedDate;
                fileItem.ownerName = contentDocumentlinkRec.ContentDocument.Owner.Name;
                fileItem.downloadUrl = downloadURL + fileItem.versionId;
                
                fileItemOutList.add(fileItem);
            }
            return fileItemOutList.isEmpty() ? null : fileItemOutList;
            
        } catch (Exception e) {
            Logger.error('An error occurred while retriving files related to record:'+recordId).addTag('FilesRelatedListController');
            Logger.saveLog();
            throw new AuraHandledException('An error occurred while retriving files related to record: ' +recordId );
        }
    }
    
    /**
     * @description Inner class for FileItem details to LWCs, using @AuraEnabled properties
     */
    public class FileItem {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id versionId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileExtension;
        @AuraEnabled public String fileType;
        @AuraEnabled public Integer contentSize;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String downloadUrl;
    }
}