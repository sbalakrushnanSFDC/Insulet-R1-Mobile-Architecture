/**
 * @description This class handles the code coverage for FilesRelatedListController
 * Jira Story Number: NGOMCT-724
 * Developer: Srinivas
 * Date: 30/11/2025
 * Comments : We can't use @isTest(isParallel=true) because of this error:  APEX_DATA_ACCESS_RESTRICTION, In parallel Apex tests, DML operations aren't permitted on this type of object: ContentWorkspace:
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       30th Nov 2025       Srinivas                Create (NGOMCT-724)
 */

@isTest
public class FilesRelatedListControllerTest {
    
    /**
     * @description Test setup method to create test data
     */
    @TestSetup
    static void setupTestData() {
        Account patient = TestDataFactory.getAccountofPatientRecordType();
        Insert patient;
        Account patientRec = [SELECT Id, PersonContactId FROM Account LIMIT 1];
        
        new TestDataFactory.CreateTrainingRecord()
            .setAccount(patientRec.Id)
            .setRecordType(getTrainingRtId(ConstantsUtil.LIVE_TRAINING_RECORD_TYPE))
            .setEducatorType(ConstantsUtil.EDUCATOR_TYPE_CTS)
            .save()
            .getRecord();
    }
    
    /**
     * @description Test method to verify the getFilesForRecord method
     */
    @isTest
    static void testGetFilesForRecord() {
        // Create test data
        List<Training__c> trainingList = [SELECT id,Training_Stage__c from Training__c WHERE Educator_Type__c =: ConstantsUtil.EDUCATOR_TYPE_CTS  LIMIT 1];
        List<ContentVersion> contentVerList = TestDataFactory.createContentVersions(1);
        
        TestDataFactory.createContentDocumentLinks(trainingList[0].id, contentVerList);
        
        Test.startTest();
        List<FilesRelatedListController.FileItem> files = FilesRelatedListController.getFilesForRecord(trainingList[0].id);
        Test.stopTest();
        
        Assert.areNotEqual(0, files.size(), 'Files should be returned for the record.');
        Assert.areEqual(contentVerList.size(), files.size(), 'The number of returned files should match the number of created documents.');
        Assert.areEqual(contentVerList[0].Title, files[0].title, 'File title should match.');
    }
    
    /**
     * @description Test method to verify the getFilesForRecord method with a recordId that has no files
     */
    @isTest
    static void testGetFilesForRecordWithNoFiles() {
        List<Training__c> trainingList = [SELECT id,Training_Stage__c from Training__c WHERE Educator_Type__c =: ConstantsUtil.EDUCATOR_TYPE_CTS  LIMIT 1];
        
        Test.startTest();
        List<FilesRelatedListController.FileItem> files = FilesRelatedListController.getFilesForRecord(trainingList[0].id);
        Test.stopTest();
        
        Assert.areEqual(null, files, 'No files should be returned for a record with no files.');
    }
    
    /**
     * @description method gets the Training Record Type Id
     * @param developerName The developer name of the record type
     * @return Id of the record type or null if not found
     */
    private static Id getTrainingRtId(String developerName) {
        return Schema.SObjectType.Training__c.getRecordTypeInfosByDeveloperName().get(developerName).getRecordTypeId();
    }
    
    /**
     * @description Test method to verify the getFilesForRecord method with an invalid recordId
     * @throws Exception
     */
    @IsTest
    static void testGetFilesForRecordExceptionPath() {
        Test.startTest();
        try {
            FilesRelatedListController.getFilesForRecord(null);
        } catch (Exception ex) {
            Assert.isTrue(
                ex.getMessage().contains('Script-thrown'),
            'Unexpected error message: ' + ex.getMessage()
                );
        }
        Test.stopTest();
    }
}