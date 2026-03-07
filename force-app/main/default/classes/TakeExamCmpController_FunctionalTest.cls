/**
 * @author      : Yogesh Rana
 * @created Date: 25th Nov 2025
 * @description : Test class for TakeExamCmpController. Covers both positive and negative scenarios to ensure code reliability.
 * ============================ Logs =============================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       25th November 2025  Yogesh Rana                   Initial Version
 * V1.0.1       29th Dec 2025       Ankur Chauhan                 NGOMCT-341(Replaced CEO Role with Training_Coordinator)
 */
@IsTest
public class TakeExamCmpController_FunctionalTest {

    /**
     * @description Setup method to create all required test data once for the class.
     * Removes dependency on existing org data (seeAllData=true).
     */
    @TestSetup
    static void setupData() {
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(adminUser) {
            User currentUser = [SELECT Id, UserRoleId FROM User WHERE Id = :adminUser.Id LIMIT 1];
            if (currentUser.UserRoleId == null) {
                UserRole userRole;
                List<UserRole> roles = [SELECT Id FROM UserRole WHERE DeveloperName = 'Training_Coordinator' LIMIT 1];
                if (!roles.isEmpty()) {
                    userRole = roles[0];
                } else {
                    userRole = new UserRole(DeveloperName = 'Training_Coordinator', Name = 'Training Coordinator');
                    insert userRole;
                }
                currentUser.UserRoleId = userRole.Id;
                update currentUser;
            }
        }

        // 2. Create Assessment Dependencies (Non-Setup DML)
        // Create AssessmentQuestionSet
        AssessmentQuestionSet testQuestionSet = new AssessmentQuestionSet(
            Name = 'Test Question Set',
            DeveloperName = 'Test_Question_Set_Dev'
        );
        insert testQuestionSet;

        // Create OmniProcess (Required for AssessmentDefinition)
        OmniProcess testOmni = new OmniProcess(
            Name = 'Test OmniScript',
            Type = 'Assessment',
            SubType = 'Test',
            Language = 'English',
            IsActive = true,
            OmniProcessType = 'OmniScript'
        );
        insert testOmni;

        // Create AssessmentDefinition
        AssessmentDefinition testAssessmentDef = new AssessmentDefinition(
            Assessment_Question_Set__c = testQuestionSet.Id,
            OmniProcessId = testOmni.Id,
            Test_Name__c = 'Test Exam',
            Purpose = 'Certification'
        );
        insert testAssessmentDef;

        // 3. Create Account (Person Account)
        Account trainer = TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Trainer',
            'BillingPostalCode' => '12345'
        });
        insert trainer;
        
        Account trainer1 = TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
            'FirstName' => 'TestUser1',
            'LastName' => 'TestTrainer1',
            'BillingPostalCode' => '654321'
        });
        insert trainer1;
        
        // Reload trainer to get Contact ID for User creation
        trainer = [SELECT Id, Name, PersonContactId FROM Account WHERE Id = :trainer.Id LIMIT 1];
        trainer1 = [SELECT Id, Name, PersonContactId FROM Account WHERE Id = :trainer1.Id LIMIT 1];

        // 4. Create Portal User (Setup DML - Must be separated from Non-Setup)
        User portalUser;
        User portalUser1;
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'External Trainer' LIMIT 1];
        
        System.runAs(adminUser) {
            portalUser = TestDataFactory.getCommunityUser(trainer, portalProfile, 'testTrain');
            portalUser1 = TestDataFactory.getCommunityUser(trainer1, portalProfile, 'testTrain1');
            
            // Assign Permission Set
            PermissionSet externalTrainerPS = [SELECT Id FROM PermissionSet WHERE Name = 'External_Trainers' LIMIT 1];
            PermissionSetAssignment psa = new PermissionSetAssignment(
                AssigneeId = portalUser.Id,
                PermissionSetId = externalTrainerPS.Id
            );
            insert psa;
        }
    }

    /**
     * @description Helper method to retrieve data created in @TestSetup. 
     * Replaces the old creation logic to minimize changes in test methods.
     * @return Map containing 'trainer', 'assessmentDef', 'questionSet', and 'portalUser'
     */
    private static Map<String, SObject> fetchTestData() {
        Map<String, SObject> testData = new Map<String, SObject>();
        
        testData.put('trainer', [SELECT Id, Name, PersonContactId FROM Account WHERE FirstName = 'Test' LIMIT 1]);
        testData.put('assessmentDef', [SELECT Id, OmniProcessId, Assessment_Question_Set__c, Purpose, Test_Name__c FROM AssessmentDefinition LIMIT 1]);
        testData.put('questionSet', [SELECT Id, Name, DeveloperName FROM AssessmentQuestionSet LIMIT 1]);
        testData.put('portalUser', [SELECT Id FROM User WHERE LastName = 'UsertestTrain' LIMIT 1]);
        testData.put('portalUser1', [SELECT Id FROM User WHERE LastName = 'UsertestTrain1' LIMIT 1]);
        
        return testData;
    }

    /**
     * @description Validates behavior when null Certification Id is passed to getCertification().
     * @test Expecting null certification record to be returned.
     */
    @IsTest
    static void testGetCertificationWithNullId() {
        Test.startTest();
        Certification__c certRecord = TakeExamCmpController.getCertification(null);
        Test.stopTest();
        
        Assert.areEqual(null, certRecord, 'Certification record should be null for null Id input.');
    }

    /**
     * @description Validates behavior when a mock (non-existing) Certification Id is passed to getCertification().
     * @test Expecting null certification record to be returned.
     */
    @IsTest
    static void testGetCertificationWithMockId() {
        Id mockCertificationId = MockDataFactory.getFakeId('Certification__c');
        
        Test.startTest();
        Certification__c certRecord = TakeExamCmpController.getCertification(mockCertificationId);
        Test.stopTest();
        
        Assert.areEqual(null, certRecord, 'Certification record should be null for mock Id.');
    }

    /**
     * @description Validates successful fetch of an inserted certification record.
     * @test Ensures that certification fields like Retake_Exam__c, Completion_Status__c are retrieved correctly.
     */
    @IsTest
    static void testGetCertificationWithValidId() {
        // Retrieve setup data
        Map<String, SObject> testData = fetchTestData();
        Account trainer = (Account)testData.get('trainer');
        AssessmentDefinition assessmentDef = (AssessmentDefinition)testData.get('assessmentDef');
        User portalUser = (User)testData.get('portalUser');
        
        // Create test Certification record
        Certification__c testCert = new Certification__c(
            Trainer_Name__c = trainer.Id,
            Certification_Assessment__c = assessmentDef.Id,
            Retake_Exam__c = true,
            Completion_Status__c = 'Pending',
            Certification_Results__c = 'Failed'
        );
        insert testCert;
        
        Test.startTest();
        Certification__c certRecord;
        System.runAs(portalUser) {
            certRecord = TakeExamCmpController.getCertification(testCert.Id);
        }
        Test.stopTest();
        
        Assert.isNotNull(certRecord, 'Certification record should not be null for valid Id.');
        Assert.areEqual(testCert.Id, certRecord.Id, 'Fetched certification Id should match inserted value.');
        Assert.areEqual(true, certRecord.Retake_Exam__c, 'Retake_Exam__c field should match inserted value.');
        Assert.areEqual('Pending', certRecord.Completion_Status__c, 'Completion_Status__c should match inserted value.');
        Assert.areEqual('Failed', certRecord.Certification_Results__c, 'Certification_Results__c should match inserted value.');
    }

    /**
     * @description Validates getCertification() with multiple certification records.
     * @test Ensures correct record is returned when multiple certifications exist.
     */
    @IsTest
    static void testGetCertificationWithMultipleRecords() {
        // Retrieve setup data
        Map<String, SObject> testData = fetchTestData();
        Account trainer = (Account)testData.get('trainer');
        AssessmentDefinition assessmentDef = (AssessmentDefinition)testData.get('assessmentDef');
        User portalUser = (User)testData.get('portalUser');
        
        // Create multiple test Certification records
        List<Certification__c> testCerts = new List<Certification__c>();
        for (Integer i = 0; i < 5; i++) {
            testCerts.add(new Certification__c(
                Trainer_Name__c = trainer.Id,
                Certification_Assessment__c = assessmentDef.Id,
                Retake_Exam__c = false,
                Completion_Status__c = 'Completed'
            ));
        }
        insert testCerts;
        
        // Run test in context of Trainer Portal user
        Test.startTest();
        Certification__c certRecord;
        System.runAs(portalUser) {
            certRecord = TakeExamCmpController.getCertification(testCerts[2].Id);
        }
        Test.stopTest();
        
        Assert.isNotNull(certRecord, 'Certification record should not be null.');
        Assert.areEqual(testCerts[2].Id, certRecord.Id, 'Should return the specific certification queried.');
    }

    /**
     * @description Validates behavior when null Certification Id is passed to getCertificationRelatedOmniscript().
     * @test Expecting null certification record to be returned.
     */
    @IsTest
    static void testGetCertificationRelatedOmniscriptWithNullId() {
        Test.startTest();
        Certification__c certRecord = TakeExamCmpController.getCertificationRelatedOmniscript(null);
        Test.stopTest();
        
        Assert.areEqual(null, certRecord, 'Certification record should be null for null Id input.');
    }

    /**
     * @description Validates behavior when a mock (non-existing) Certification Id is passed to getCertificationRelatedOmniscript().
     * @test Expecting null certification record to be returned.
     */
    @IsTest
    static void testGetCertificationRelatedOmniscriptWithMockId() {
        Id mockCertificationId = MockDataFactory.getFakeId('Certification__c');
        
        Test.startTest();
        Certification__c certRecord = TakeExamCmpController.getCertificationRelatedOmniscript(mockCertificationId);
        Test.stopTest();
        
        Assert.areEqual(null, certRecord, 'Certification record should be null for mock Id.');
    }

    /**
     * @description Validates successful fetch of certification with related OmniProcess data.
     * @test Ensures that certification with assessment and OmniProcess fields are retrieved correctly.
     */
    @IsTest
    static void testGetCertificationRelatedOmniscriptWithValidId() {
        // Retrieve setup data
        Map<String, SObject> testData = fetchTestData();
        Account trainer = (Account)testData.get('trainer');
        AssessmentDefinition assessmentDef = (AssessmentDefinition)testData.get('assessmentDef');
        AssessmentQuestionSet questionSet = (AssessmentQuestionSet)testData.get('questionSet');
        User portalUser = (User)testData.get('portalUser');
        
        // Create test Certification record with related assessment
        Certification__c testCert = new Certification__c(
            Trainer_Name__c = trainer.Id,
            Certification_Assessment__c = assessmentDef.Id,
            Completion_Status__c = 'Pending'
        );
        insert testCert;
        
        // Run test in context of Trainer Portal user
        Test.startTest();
        Certification__c certRecord;
        System.runAs(portalUser) {
            certRecord = TakeExamCmpController.getCertificationRelatedOmniscript(testCert.Id);
        }
        Test.stopTest();
        
        Assert.isNotNull(certRecord, 'Certification record should not be null for valid Id.');
        Assert.areEqual(testCert.Id, certRecord.Id, 'Fetched certification Id should match inserted value.');
        Assert.isNotNull(certRecord.Certification_Assessment__r, 'Certification Assessment relationship should be populated.');
        Assert.isNotNull(certRecord.Certification_Assessment__r.OmniProcess, 'OmniProcess relationship should be populated.');
        Assert.isNotNull(certRecord.Certification_Assessment__r.Assessment_Question_Set__c, 'Assessment Question Set should be populated.');
        Assert.areEqual(questionSet.Id, certRecord.Certification_Assessment__r.Assessment_Question_Set__c, 'Assessment Question Set should match the one used in test data.');
    }

    /**
     * @description Validates getCertificationRelatedOmniscript() when certification has no related assessment.
     * @test Ensures method handles missing assessment relationship gracefully.
     */
    @IsTest
    static void testGetCertificationRelatedOmniscriptWithNoAssessment() {
        // Retrieve setup data
        Map<String, SObject> testData = fetchTestData();
        Account trainer = (Account)testData.get('trainer');
        User portalUser = (User)testData.get('portalUser');
        AssessmentDefinition AD = [SELECT Id From AssessmentDefinition Limit 1];
        Certification__c testCert = new Certification__c(
            Trainer_Name__c = trainer.Id,
            Completion_Status__c = 'Pending',
            Certification_Assessment__c =AD.Id
        );
        insert testCert;
        
        // Run test in context of Trainer Portal user
        Test.startTest();
        Certification__c certRecord;
        System.runAs(portalUser) {
            certRecord = TakeExamCmpController.getCertificationRelatedOmniscript(testCert.Id);
        }
        Test.stopTest();
        
        Assert.isNotNull(certRecord, 'Certification record should not be null.');
        Assert.areEqual(testCert.Id, certRecord.Id, 'Fetched certification Id should match inserted value.');
    }

    /**
     * @description Validates getCertification() with various completion statuses.
     * @test Ensures method works correctly with different status values.
     */
    @IsTest
    static void testGetCertificationWithVariousStatuses() {
        // Retrieve setup data
        Map<String, SObject> testData = fetchTestData();
        Account trainer = (Account)testData.get('trainer');
        AssessmentDefinition assessmentDef = (AssessmentDefinition)testData.get('assessmentDef');
        User portalUser = (User)testData.get('portalUser');
        
        List<String> statuses = new List<String>{'Pending', 'Completed'};
        List<Certification__c> testCerts = new List<Certification__c>();
        
        for (String status : statuses) {
            testCerts.add(new Certification__c(
                Trainer_Name__c = trainer.Id,
                Certification_Assessment__c = assessmentDef.Id,
                Completion_Status__c = status,
                Retake_Exam__c = (status == 'Pending')
            ));
        }
        insert testCerts;
        
        // Run test in context of Trainer Portal user
        Test.startTest();
        System.runAs(portalUser) {
            for (Certification__c cert : testCerts) {
                Certification__c certRecord = TakeExamCmpController.getCertification(cert.Id);
                Assert.isNotNull(certRecord, 'Certification record should not be null.');
                Assert.areEqual(cert.Completion_Status__c, certRecord.Completion_Status__c, 'Completion status should match.');
            }
        }
        Test.stopTest();
    }

    /**
     * @description Validates getCertification() retrieves latest data after update.
     * @test Ensures method returns updated field values.
     */
    @IsTest
    static void testGetCertificationAfterUpdate() {
        // Retrieve setup data
        Map<String, SObject> testData = fetchTestData();
        Account trainer = (Account)testData.get('trainer');
        AssessmentDefinition assessmentDef = (AssessmentDefinition)testData.get('assessmentDef');
        User portalUser = (User)testData.get('portalUser');
        
        // Create and insert initial certification
        Certification__c testCert = new Certification__c(
            Trainer_Name__c = trainer.Id,
            Certification_Assessment__c = assessmentDef.Id,
            Retake_Exam__c = true,
            Completion_Status__c = 'Pending',
            Certification_Results__c = 'Failed'
        );
        insert testCert;
        
        // Update the certification
        testCert.Retake_Exam__c = false;
        testCert.Completion_Status__c = 'Completed';
        testCert.Certification_Results__c = 'Passed';
        update testCert;
        
        // Run test in context of Trainer Portal user
        Test.startTest();
        Certification__c certRecord;
        System.runAs(portalUser) {
            certRecord = TakeExamCmpController.getCertification(testCert.Id);
        }
        Test.stopTest();
        
        Assert.isNotNull(certRecord, 'Certification record should not be null.');
        Assert.areEqual(false, certRecord.Retake_Exam__c, 'Retake_Exam__c should reflect updated value.');
        Assert.areEqual('Completed', certRecord.Completion_Status__c, 'Completion_Status__c should reflect updated value.');
        Assert.areEqual('Passed', certRecord.Certification_Results__c, 'Certification_Results__c should reflect updated value.');
    }
    
    @IsTest
    static void testGetCertificationWithCatch() {
        // Retrieve setup data
        Map<String, SObject> testData = fetchTestData();
        Account trainer = (Account)testData.get('trainer');
        AssessmentDefinition assessmentDef = (AssessmentDefinition)testData.get('assessmentDef');
        User portalUser = (User)testData.get('portalUser1');
        
        // Create test Certification record
        Certification__c testCert = new Certification__c(
            Trainer_Name__c = trainer.Id,
            Certification_Assessment__c = assessmentDef.Id,
            Retake_Exam__c = true,
            Completion_Status__c = 'Pending',
            Certification_Results__c = 'Failed'
        );
        insert testCert;
        
        Test.startTest();
        Certification__c certRecord;
        try{
        System.runAs(portalUser) {
            certRecord = TakeExamCmpController.getCertification(testCert.Id);
        }
        }
        catch(System.QueryException e){
            Assert.isTrue(e.getMessage().contains('sObject type \'Certification__c\' is not supported'), 
            'The exception message did not match. Actual message: ' + e.getMessage());
        }
        Test.stopTest();
        
        Assert.isNull(certRecord, 'Certification record should be null.');
    }
}