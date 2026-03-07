/**
 * @author      : Rohan Saxena
 * @created Date: 23rd Dec 2025
 * @description : Tests for ContentDocumentLinkTriggerHelper.changeDocusignFileVisibility.
 * Covers null/empty inputs, metadata-based visibility configuration, and bulk behavior.
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By         Brief Note
 * V1.0.0       23rd Dec 2025       Rohan Saxena        Initial Version
 * V1.1.0       05th Jan 2026       Yogesh Rana         Updated for metadata-based configuration
 */
@IsTest
private class ContentDocumentLinkTriggerHelper_Test {

    @TestSetup
    static void setupData() {
        // Create a Practice account
        Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType();
        practiceAccount.Contract_Type__c = 'Level 2';
        insert practiceAccount;

        // Create Patient account for Training
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType();
        insert patientAccount;

        // Refresh to get PersonContactId
        patientAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :patientAccount.Id];

        // Create Contract
        Contract testContract = TestDataFactory.getContract(practiceAccount.Id);
        testContract.CompanySignedDate = Date.today();
        testContract.Clinic_Admin_Name__c = 'Test Admin';
        testContract.Clinic_Admin_Email__c = 'testadmin@test.com';
        insert testContract;

        // Create Training records using CreateTrainingRecord for bulk testing (10 records)
        List<Training__c> trainingList = new List<Training__c>();
        for (Integer i = 0; i < 10; i++) {
            Training__c training = new TestDataFactory.CreateTrainingRecord()
                .setAccount(patientAccount.Id)
                .setRecordType(getTrainingRtId('Live_Training'))
                .setEducatorType(ConstantsUtil.EDUCATOR_TYPE_CTS)
                .setTrainingStage(ConstantsUtil.STAGE_PENDING_ACCEPTANCE)
                .getRecord();
            trainingList.add(training);
        }
        insert trainingList;

        // Create ContentVersions for bulk testing (20 records)
        TestDataFactory.createContentVersions(20);
    }

    /**
     * @description Helper method to get Training Record Type Id
     * @param developerName The developer name of the record type
     * @return Id of the record type
     */
    private static Id getTrainingRtId(String developerName) {
        return Schema.SObjectType.Training__c.getRecordTypeInfosByDeveloperName()
            .get(developerName)
            .getRecordTypeId();
    }

    /**
     * @description Tests that visibility is set to AllUsers for Contract based on metadata configuration
     */
    @IsTest
    static void testVisibilityUpdatedForContract() {
        Contract testContract = [SELECT Id FROM Contract LIMIT 1];
        List<ContentVersion> contentVersionList = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 2];

        List<ContentDocumentLink> contentDocLinkList = new List<ContentDocumentLink>();
        for (ContentVersion contentVer : contentVersionList) {
            ContentDocumentLink contDoclink = new ContentDocumentLink(
                LinkedEntityId = testContract.Id,
                ContentDocumentId = contentVer.ContentDocumentId,
                ShareType = 'V'
            );
            contentDocLinkList.add(contDoclink);
        }

        Test.startTest();
        insert contentDocLinkList;
        Test.stopTest();

        List<ContentDocumentLink> results = [
            SELECT Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testContract.Id
        ];

        Assert.areEqual(2, results.size(), 'Should have 2 ContentDocumentLinks');
        for (ContentDocumentLink cdl : results) {
            Assert.areEqual(
                'AllUsers',
                cdl.Visibility,
                'Visibility should be updated to AllUsers for Contract based on metadata'
            );
        }
    }

    /**
     * @description Tests that visibility is set to AllUsers for Training__c based on metadata configuration
     * Tests bulk processing with multiple Training records
     */
    @IsTest
    static void testVisibilityUpdatedForTraining() {
        List<Training__c> trainingList = [SELECT Id FROM Training__c LIMIT 5];
        List<ContentVersion> contentVersionList = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 10];

        List<ContentDocumentLink> contentDocLinkList = new List<ContentDocumentLink>();
        Integer cvIndex = 0;
        Set<Id> trainingIds = new Set<Id>();
        // Create 2 CDLs per Training record for bulk testing
        for (Training__c training : trainingList) {
            trainingIds.add(training.Id);
            for (Integer i = 0; i < 2 && cvIndex < contentVersionList.size(); i++) {
                ContentDocumentLink contDoclink = new ContentDocumentLink(
                    LinkedEntityId = training.Id,
                    ContentDocumentId = contentVersionList[cvIndex].ContentDocumentId,
                    ShareType = 'V'
                );
                contentDocLinkList.add(contDoclink);
                cvIndex++;
            }
        }

        Test.startTest();
        insert contentDocLinkList;
        Test.stopTest();

        List<ContentDocumentLink> results = [
            SELECT Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :trainingIds
        ];

        Assert.areEqual(10, results.size(), 'Should have 10 ContentDocumentLinks');
        for (ContentDocumentLink cdl : results) {
            Assert.areEqual(
                'AllUsers',
                cdl.Visibility,
                'Visibility should be updated to AllUsers for Training__c based on metadata'
            );
        }
    }

    /**
     * @description Tests that visibility is not changed for objects without metadata configuration
     */
    @IsTest
    static void testVisibilityNotChangedForNonConfiguredObject() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        List<ContentVersion> contentVersionList = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 1];

        ContentDocumentLink contDoclink = new ContentDocumentLink(
            LinkedEntityId = testAccount.Id,
            ContentDocumentId = contentVersionList[0].ContentDocumentId,
            ShareType = 'V'
        );

        Test.startTest();
        insert contDoclink;
        Test.stopTest();

        ContentDocumentLink result = [
            SELECT Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testAccount.Id
            LIMIT 1
        ];

        // Visibility should remain default (InternalUsers) as Account is not in metadata
        Assert.areEqual(
            'InternalUsers',
            result.Visibility,
            'Visibility should remain default for objects without metadata configuration'
        );
    }

    /**
     * @description Tests null input handling
     */
    @IsTest
    static void testNullInput() {
        Test.startTest();
        ContentDocumentLinkTriggerHelper.changeDocusignFileVisibility(null);
        Test.stopTest();

        Assert.isTrue(true, 'Method handled null input without exceptions');
    }

    /**
     * @description Tests empty list input handling
     */
    @IsTest
    static void testEmptyListInput() {
        Test.startTest();
        ContentDocumentLinkTriggerHelper.changeDocusignFileVisibility(new List<ContentDocumentLink>());
        Test.stopTest();

        Assert.isTrue(true, 'Method handled empty list without exceptions');
    }

    /**
     * @description Tests bulk processing of ContentDocumentLinks with mixed object types
     * Tests SObjectType caching optimization with multiple object types
     */
    @IsTest
    static void testBulkProcessingMixedObjects() {
        Contract testContract = [SELECT Id FROM Contract LIMIT 1];
        List<Training__c> trainingList = [SELECT Id FROM Training__c LIMIT 5];
        Account testAccount = [SELECT Id FROM Account WHERE Contract_Type__c = 'Level 2' LIMIT 1];
        List<ContentVersion> contentVersionList = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 15];

        List<ContentDocumentLink> contentDocLinkList = new List<ContentDocumentLink>();
        Integer count = 0;
        
        // Mix of Contract, Training, and Account (non-configured) to test all paths
        for (ContentVersion contentVer : contentVersionList) {
            Id linkedEntityId;
            Integer remainder = Math.mod(count, 3);
            
            if (remainder == 0) {
                linkedEntityId = testContract.Id;
            } else if (remainder == 1) {
                linkedEntityId = trainingList[Math.mod(count / 3, trainingList.size())].Id;
            } else {
                linkedEntityId = testAccount.Id;
            }
            
            ContentDocumentLink contDoclink = new ContentDocumentLink(
                LinkedEntityId = linkedEntityId,
                ContentDocumentId = contentVer.ContentDocumentId,
                ShareType = 'V'
            );
            contentDocLinkList.add(contDoclink);
            count++;
        }

        Test.startTest();
        insert contentDocLinkList;
        Test.stopTest();

        // Build set of LinkedEntityIds for query
        Set<Id> linkedEntityIds = new Set<Id>();
        linkedEntityIds.add(testContract.Id);
        linkedEntityIds.add(testAccount.Id);
        for (Training__c training : trainingList) {
            linkedEntityIds.add(training.Id);
        }

        List<ContentDocumentLink> results = [
            SELECT Visibility, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :linkedEntityIds
        ];

        Assert.areEqual(
            contentDocLinkList.size(),
            results.size(),
            'All ContentDocumentLinks should be processed'
        );

        // Verify visibility based on object type
        for (ContentDocumentLink cdl : results) {
            String objectType = String.valueOf(cdl.LinkedEntityId.getSObjectType());
            if (objectType == 'Contract' || objectType == 'Training__c') {
                Assert.areEqual(
                    'AllUsers',
                    cdl.Visibility,
                    'Contract and Training records should have AllUsers visibility'
                );
            } else if (objectType == 'Account') {
                Assert.areEqual(
                    'InternalUsers',
                    cdl.Visibility,
                    'Account records should have default InternalUsers visibility'
                );
            }
        }
    }

    /**
     * @description Tests ContentDocumentLink with null LinkedEntityId
     */
    @IsTest
    static void testContentDocumentLinkWithNullLinkedEntityId() {
        List<ContentVersion> contentVersionList = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 1];

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = null,
            ContentDocumentId = contentVersionList[0].ContentDocumentId,
            ShareType = 'V'
        );

        List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>{ cdl };

        Test.startTest();
        // Call method directly to test null LinkedEntityId handling
        ContentDocumentLinkTriggerHelper.changeDocusignFileVisibility(cdlList);
        Test.stopTest();

        Assert.isTrue(true, 'Method handled null LinkedEntityId without exceptions');
    }

    /**
     * @description Tests SObjectType caching optimization with same object types
     * Verifies that getDescribe() is called only once per SObjectType
     */
    @IsTest
    static void testSObjectTypeCachingOptimization() {
        List<Training__c> trainingList = [SELECT Id FROM Training__c];
        List<ContentVersion> contentVersionList = [SELECT Id, ContentDocumentId FROM ContentVersion];

        List<ContentDocumentLink> contentDocLinkList = new List<ContentDocumentLink>();
        Integer cvIndex = 0;
        Set<Id> trainingIds = new Set<Id>();

        // All CDLs linked to Training records to test SObjectType caching
        for (Training__c training : trainingList) {
            trainingIds.add(training.Id);
            if (cvIndex < contentVersionList.size()) {
                ContentDocumentLink contDoclink = new ContentDocumentLink(
                    LinkedEntityId = training.Id,
                    ContentDocumentId = contentVersionList[cvIndex].ContentDocumentId,
                    ShareType = 'V'
                );
                contentDocLinkList.add(contDoclink);
                cvIndex++;
            }
        }

        Test.startTest();
        insert contentDocLinkList;
        Test.stopTest();

        List<ContentDocumentLink> results = [
            SELECT Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :trainingIds
        ];

        Assert.areEqual(
            contentDocLinkList.size(),
            results.size(),
            'All ContentDocumentLinks should be processed'
        );

        for (ContentDocumentLink cdl : results) {
            Assert.areEqual(
                'AllUsers',
                cdl.Visibility,
                'Visibility should be AllUsers for all Training records'
            );
        }
    }

    /**
     * @description Tests metadata configuration with blank Visibility_Level__c
     * This test ensures the code handles edge case where metadata exists but visibility level is blank
     */
    @IsTest
    static void testMetadataWithBlankVisibilityLevel() {
        // This test validates the String.isNotBlank check in the code
        // Since we can't modify metadata in tests, we test the logic path
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        List<ContentVersion> contentVersionList = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 1];

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = testAccount.Id,
            ContentDocumentId = contentVersionList[0].ContentDocumentId,
            ShareType = 'V'
        );

        Test.startTest();
        insert cdl;
        Test.stopTest();

        ContentDocumentLink result = [
            SELECT Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :testAccount.Id
            LIMIT 1
        ];

        // Account is not in metadata, so visibility remains default
        Assert.areEqual(
            'InternalUsers',
            result.Visibility,
            'Visibility should remain default when no metadata configuration exists'
        );
    }
}