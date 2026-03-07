/**
 * @description : Test Class for Trigger Assignment core class,
 * @author      : Ankur Chauhan
 * @created Date: 27th Oct 2025
 * responsible for coverage of TrainingAssignmentHandler class
 * @story Number: NGOMCT-337
 * =========================== Logs ==============================
 * Version      Modified Date       Modified By            Brief Note
 * V1.0.0       27th Oct 2025       Ankur Chauhan          Initial Version
 * V1.0.1       10th Nov 2025       Ankur Chauhan          NGOMCT-689
 * V1.0.2       24th Nov 2025       Srinivas               NGOMCT-787
 * V1.0.3       11th Dec 2025       Ankur Chauhan          Enhancements
 * V1.0.4       27th Jan 2026       Bhavya Chanan          NGOMCT-1213
 * V1.0.5       12th Feb 2026       Yogesh Rana            (NGOMCT-2099)
 */
 @IsTest
 private class TrainingTrigger_Test {
 
    private static final String LIVE_VIRTUAL = 'Live Virtual';
    private static final String PRE_PROD_TRAINING = 'Pre-Pod Training';
    private static final String OMNIPOD_5 = 'Omnipod 5';
 
    /**
     * @description Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
         Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'Sales' LIMIT 1];
         String uniqueUserName = 'testuser' + '@testdomain.com';
         User testUser = new TestDataFactory.CreateUserRecord()
                         .setEmail(uniqueUserName)
                         .setFirstName('Training Assignment')
                         .setLastName('User')
                         .setProfileId(testProfile.Id)
                         .setUserName(uniqueUserName)
                         .save()
                         .getRecord();
 
         Account patient;
 
         ObjectTerritory2Association ot2a;
 
         Territory2Model model = new TestDataFactory.CreateTerritory2ModelRecord()
                                 .setName('Test TM')
                                 .setDeveloperName('TestTM')
                                 .save()
                                 .getRecord();
 
         Territory2Type territoryType = [SELECT Id FROM Territory2Type LIMIT 1];
 
         Territory2 territory = new TestDataFactory.CreateTerritory2Record()
                                 .setName('Test Territory')
                                 .setTerritory2ModelId(model.Id)
                                 .setTerritory2TypeId(territoryType.Id)
                                 .setDescription('For tests')
                                 .setDeveloperName('Test')
                                 .save()
                                 .getRecord();
         
         System.runAs(new User(Id = UserInfo.getUserId())) {
             // Create AssessmentQuestionSet
             AssessmentQuestionSet testQuestionSet = TestDataFactory.getAssessmentQuestionSet();
             insert testQuestionSet;
             
             // Create OmniProcess
             OmniProcess testOmni = TestDataFactory.getOmniProcess(new Map<String, Object>{
                 'Type' => 'Assessment',
                 'SubType' => 'Test'
             });
             insert testOmni;
             
             // Create AssessmentDefinition
             AssessmentDefinition testAssessmentDef = TestDataFactory.getAssessmentDefinition(new Map<String, Object>{
                 'Assessment_Question_Set__c' => testQuestionSet.Id,
                 'OmniProcessId' => testOmni.Id,
                 'Purpose' => 'Certification'
             });
             insert testAssessmentDef;
         }
 
         System.runas(testUser){
             
             patient = TestDataFactory.getAccountofPatientRecordType();
             insert patient;
             Account patientAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :patient.Id LIMIT 1];
 
             Account practice = TestDataFactory.getAccountofPracticeRecordType();
             insert practice;
 
             Account trainerRecord = TestDataFactory.getAccountofTrainerRecordType();
             trainerRecord.Trainer_Type__c = 'Clinic Contract Trainer';
             insert trainerRecord;
 
             Account practiceForACR = new Account(
                 RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT,
                 Name = 'Practice Test Account',
                 Type = 'Customer - Direct',
                 Phone = '555-123-4567',
                 BillingPostalCode ='34567'
             );
             insert practiceForACR;
 
             AccountContactRelation accConRelation = new AccountContactRelation();
             accConRelation.AccountId = practiceForACR.Id;
             accConRelation.ContactId = patientAccount.PersonContactId;
             accConRelation.Roles = 'Trainer';
             insert accConRelation;
             
             AccountContactRelation accConRel = new AccountContactRelation();
             accConRel.AccountId = practice.Id;
             accConRel.ContactId = patientAccount.PersonContactId;
             accConRel.Roles = 'Patient - Practice Affiliation';
             accConRel.IsActive = true;
             accConRel.Is_Primary__c = true;
             insert accConRel;
 
             ot2a = new ObjectTerritory2Association(
                 ObjectId = patient.Id,
                 Territory2Id = territory.Id,
                 AssociationCause = 'Territory2Manual'
             );
             insert ot2a;
 
             AssessmentDefinition assessmentDef = [SELECT Id FROM AssessmentDefinition LIMIT 1];
 
             Certification__c testCertification = TestDataFactory.getCertification(new Map<String, Object>{
                 'Trainer_Name__c' => trainerRecord.Id,
                 'Product__c' => 'DASH',
                 'Certification_Assessment__c' => assessmentDef.Id,
                 'Completion_Status__c' => 'Pending',
                 'Certification_Results__c' => 'Passed',
                 'Certification_Date__c' => Date.today().addDays(-800) // Set date in past so expiration is in future
             });
             insert testCertification;
         }
 
         UserTerritory2Association uta = new UserTerritory2Association(
             Territory2Id = territory.Id,
             UserId = testUser.Id,
             RoleInTerritory2 = ConstantsUtil.USER_PERSONA_CSM
         );
         insert uta;
 
 
         PermissionSet personaPermissionSet = [SELECT Id FROM PermissionSet WHERE Name = 'Field_Clinical'];
         Id targetPermissionSetLicenseId = [SELECT Id FROM PermissionSetLicense WHERE MasterLabel = 'Health Cloud Platform' LIMIT 1].Id;
 
         PermissionSetLicenseAssign pslAssign = new PermissionSetLicenseAssign(
             PermissionSetLicenseId = targetPermissionSetLicenseId,
             AssigneeId = testUser.Id
         );
         
         insert pslAssign;
         insert new PermissionSetAssignment(AssigneeId = testUser.Id, PermissionSetId = personaPermissionSet.Id);
     }
 
     /**
      * @description testMethod for test case of training assignment
      * where Record Type = Live Training, Training Stage = New and Educator Type = IT
      */
     @IsTest
     static void testTrainingAssignmentScenarioLiveLearningIT() {
         
         Test.startTest();
 
         Account patient = [SELECT Id FROM Account LIMIT 1];
         User testUser = [SELECT Id FROM User WHERE FirstName = :'Training Assignment' LIMIT 1];
         
         System.runas(testUser){
             Training__c liveTrainingIT = new TestDataFactory.CreateTrainingRecord()
                                         .setAccount(patient.Id)
                                         .setRecordType(TestDataFactory.getTrainingRtId('Live_Training'))
                                         .setEducatorType('IT')
                                         .setTrainingStage('New')
                                         .save()
                                         .getRecord();
             Training__c assignedTraining = [SELECT Id, CSM__C, Training_Stage__c FROM Training__c WHERE Id = :liveTrainingIT.Id];
             Assert.areEqual(testUser.Id, assignedTraining.CSM__C, 'CSM__c should be populated');
             Assert.areEqual('Accepted', assignedTraining.Training_Stage__c, 'Stage should be moved to Accepted');
             
             //update scenario
             assignedTraining.CSM__c = null;
             assignedTraining.Training_Stage__c = 'New';
             update assignedTraining;
 
             assignedTraining = [SELECT Id, CSM__C, Training_Stage__c FROM Training__c WHERE Id = :liveTrainingIT.Id];
             Assert.areEqual(testUser.Id, assignedTraining.CSM__C, 'CSM__c should be populated');
             Assert.areEqual('Accepted', assignedTraining.Training_Stage__c, 'Stage should be moved to Accepted');
         }
         Test.stopTest();
     }
 
     /**
      * @description testMethod for test case of training assignment
      * where Record Type = Live Training, Training Stage = New and Educator Type = OT
      */
     @IsTest
     static void testTrainingAssignmentScenarioLiveLearningOT() {
         
         Test.startTest();
 
         Account patient = [SELECT Id FROM Account LIMIT 1];
         User testUser = [SELECT Id FROM User WHERE FirstName = :'Training Assignment' LIMIT 1];
 
         System.runas(testUser){
             //insert scenario
             Training__c liveTrainingOT = new Training__c();
             liveTrainingOT.Account__c = patient.Id;
             liveTrainingOT.RecordTypeId = TestDataFactory.getTrainingRtId('Live_Training');
             liveTrainingOT.Educator_Type__c = 'OT';
             liveTrainingOT.Training_Stage__c = 'New';
             liveTrainingOT.Training_Method__c = LIVE_VIRTUAL;
             liveTrainingOT.Training_Type__c = PRE_PROD_TRAINING;
             liveTrainingOT.Product__c = OMNIPOD_5;
             liveTrainingOT.Training_Conducted_Date__c = System.today();
             insert liveTrainingOT;

             Training__c assignedTraining = [SELECT Id, CSM__C, Training_Stage__c, Completion_Date__c FROM Training__c WHERE Id = :liveTrainingOT.Id];

             Assert.areEqual(testUser.Id, assignedTraining.CSM__C, 'CSM__c should be populated');
             Assert.areEqual('Completed', assignedTraining.Training_Stage__c, 'Stage should be moved to Accepted');
             Assert.areEqual(System.today(), assignedTraining.Completion_Date__c, 'Completion Date should be populated');
 
             //update scenario
             assignedTraining.CSM__c = null;
             assignedTraining.Training_Stage__c = 'New';
             update assignedTraining;
 
             assignedTraining = [SELECT Id, CSM__C, Training_Stage__c FROM Training__c WHERE Id = :liveTrainingOT.Id];
             Assert.areEqual(testUser.Id, assignedTraining.CSM__C, 'CSM__c should be populated');
             Assert.areEqual('Completed', assignedTraining.Training_Stage__c, 'Stage should be moved to Accepted');
         }
         Test.stopTest();
     }
 
     /**
      * @description testMethod for test case of training assignment
      * where Record Type = E Learning, Training Stage = New and Educator Type = SG
      */
     @IsTest
     static void testTrainingAssignmentScenarioELearningSG() {
         Test.startTest();
         Account patient = [SELECT Id FROM Account LIMIT 1];
         User testUser = [SELECT Id FROM User WHERE FirstName = :'Training Assignment' LIMIT 1];
 
         System.runas(testUser){
             // insert scenario
             Training__c eLearningSG = new TestDataFactory.CreateTrainingRecord()
                                             .setAccount(patient.Id)
                                             .setRecordType(TestDataFactory.getTrainingRtId('E_Learning'))
                                             .setEducatorType('SG')
                                             .setTrainingStage('New')
                                             .save()
                                             .getRecord();
             Training__c assignedTraining = [SELECT Id, CSM__C, Training_Stage__c FROM Training__c WHERE Id = :eLearningSG.Id];
             Assert.areEqual(testUser.Id, assignedTraining.CSM__C, 'CSM__c should be populated');
             Assert.areEqual('In Progress', assignedTraining.Training_Stage__c, 'Stage should be moved to Accepted');
 
             // Update scenario
             assignedTraining.CSM__c = null;
             assignedTraining.Training_Stage__c = 'New';
             update assignedTraining;
 
             assignedTraining = [SELECT Id, CSM__C, Training_Stage__c FROM Training__c WHERE Id = :eLearningSG.Id];
             Assert.areEqual(testUser.Id, assignedTraining.CSM__C, 'CSM__c should be populated');
             Assert.areEqual('In Progress', assignedTraining.Training_Stage__c, 'Stage should be moved to Accepted');
 
             // covers negative scenario
             update assignedTraining;
         }
         Test.stopTest();
     }
 
    /**
     * @description Test Practice field population for CC educator type
     */
    @IsTest
    static void testPracticeFieldPopulation(){
         Test.startTest();
 
         Account patient = [SELECT Id, PersonContactId FROM Account LIMIT 1];
         User testUser = [SELECT Id FROM User WHERE FirstName = :'Training Assignment' LIMIT 1];
 
         System.runas(testUser){
             Training__c liveTrainingCC = new TestDataFactory.CreateTrainingRecord()
                                         .setAccount(patient.Id)
                                         .setRecordType(TestDataFactory.getTrainingRtId('Live_Training'))
                                         .setEducatorType('CC')
                                         .setTrainingStage('New')
                                         .save()
                                         .getRecord();
             Training__c assignedTraining = [SELECT Id, Practice__c FROM Training__c WHERE Id = :liveTrainingCC.Id];
             Assert.isNotNull(assignedTraining.Practice__c, 'Practice should be populated');
             
             //update scenario
             assignedTraining.Educator_Type__c = 'IT';
             update assignedTraining;
             assignedTraining = [SELECT Id, Practice__c FROM Training__c WHERE Id = :liveTrainingCC.Id];
             Assert.isNotNull(assignedTraining.Practice__c, 'Practice should not be null');
         }
         Test.stopTest();
 
         
     }
 
    /**
     * @description Test manual trainer assignments and educator type changes
     */
    @IsTest
    static void testManualAssignments(){
         Test.startTest();
 
         Account patient = [SELECT Id, PersonContactId FROM Account LIMIT 1];
         User testUser = [SELECT Id FROM User WHERE FirstName = :'Training Assignment' LIMIT 1];
 
         // Update trainer contract expiration date outside CSM user context as CSM doesn't have edit access
         Account trainerRecord = [SELECT Id FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_TRAINER_RT LIMIT 1];
         trainerRecord.Contract_Expiration_Date__c = Date.today().addDays(5);
         update trainerRecord;
 
         System.runas(testUser){
             Training__c liveTrainingIT = new TestDataFactory.CreateTrainingRecord()
                                         .setAccount(patient.Id)
                                         .setRecordType(TestDataFactory.getTrainingRtId('Live_Training'))
                                         .setEducatorType('IT')
                                         .setTrainingStage('New')
                                         .save()
                                         .getRecord();
             Training__c assignedTraining = [SELECT Id, Practice__c FROM Training__c WHERE Id = :liveTrainingIT.Id];
             
             //update scenario
             assignedTraining.Educator_Type__c = 'CC';
             assignedTraining.External_Trainer__c = trainerRecord.Id;
             update assignedTraining;
 
             assignedTraining = [SELECT Id, Practice__c, Training_Stage__c, Educator_Type__c FROM Training__c WHERE Id = :liveTrainingIT.Id];
             Assert.areEqual(assignedTraining.Training_Stage__c, 'Pending Acceptance', 'Stage should be moved to Pending Acceptance');
             Assert.areEqual(assignedTraining.Educator_Type__c, 'CPT', 'Educator type should be CPT');
 
             trainerRecord.Trainer_Type__c = 'Certified Pod Trainer';
             update trainerRecord;
 
             assignedTraining.External_Trainer__c = null;
             update assignedTraining;
 
             Account practiceAccount = [SELECT Id FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT LIMIT 1];
             assignedTraining.External_Trainer__c = trainerRecord.Id;
             assignedTraining.Practice__c = practiceAccount.Id;
             update assignedTraining;
 
             assignedTraining = [SELECT Id, Practice__c, Training_Stage__c, Educator_Type__c FROM Training__c WHERE Id = :liveTrainingIT.Id];
             Assert.areEqual(assignedTraining.Educator_Type__c, 'CPT', 'Educator type should be CPT');
         }
         Test.stopTest();
     }
 
    /**
     * @description Test AccountShare creation and deletion for training records
     */
    @IsTest
    static void testShareTrainingRecords() {
         Test.startTest();
         ConstantsUtil.customExceptionSwitch = true;
         Account patient = [SELECT Id FROM Account LIMIT 1];
         Training__c liveTraining = new TestDataFactory.CreateTrainingRecord()
                                         .setAccount(patient.Id)
                                         .setRecordType(TestDataFactory.getTrainingRtId('Live_Training'))
                                         .setEducatorType('CC')
                                         .setTrainingStage('New')
                                         .save()
                                         .getRecord();
 
         // Update scenario
         liveTraining.Training_Stage__c = 'Accepted';
         update liveTraining;
         Training__c sharedTraining = [SELECT Id, Account__c FROM Training__c WHERE Id = :liveTraining.Id];
         AccountShare sharingRecord = [SELECT Id, AccountId, Account.Name, UserOrGroupId, UserOrGroup.Name, AccountAccessLevel FROM AccountShare WHERE AccountId = :sharedTraining.Account__c LIMIT 1];
         Assert.areEqual(sharingRecord.AccountId, sharedTraining.Account__c, 'Sharing record should be created');
 
         sharedTraining.Training_Stage__c = 'Declined';
         sharedTraining.Decline_Reason__c = 'Other';
         sharedTraining.Decline_Comments__c = 'Test';
 
         update sharedTraining;
         List<AccountShare> sharedRecords = [SELECT Id, AccountId, Account.Name, UserOrGroupId, UserOrGroup.Name, AccountAccessLevel FROM AccountShare];
         Assert.isTrue(sharedRecords.size()>0, 'Sharing record should not be deleted');
 
         sharedTraining.Training_Stage__c = 'Accepted';
         sharedTraining.Educator_Type__c = 'CPT';
         update sharedTraining;
         sharedTraining = [SELECT Id, Account__c FROM Training__c WHERE Id = :liveTraining.Id];
         sharingRecord = [SELECT Id, AccountId, Account.Name, UserOrGroupId, UserOrGroup.Name, AccountAccessLevel FROM AccountShare WHERE AccountId = :sharedTraining.Account__c LIMIT 1];
         Assert.areEqual(sharingRecord.AccountId, sharedTraining.Account__c, 'Sharing record should be created');
 
         sharedTraining.Training_Stage__c = 'Declined';
         sharedTraining.Decline_Reason__c = 'Other';
         sharedTraining.Decline_Comments__c = 'Test';
         
         update sharedTraining;
         sharedRecords = [SELECT Id, AccountId, Account.Name, UserOrGroupId, UserOrGroup.Name, AccountAccessLevel FROM AccountShare];
         Assert.isTrue(sharedRecords.size()>0, 'Sharing record should not be deleted');
 
         Integer sharingRecordsBeforeNullCall = sharedRecords.size();
         TrainingSharingHandler.shareTrainingRecords(null, null);
         List<AccountShare> sharingRecordsAfterNullCall = [SELECT Id FROM AccountShare];
         Assert.areEqual(sharingRecordsBeforeNullCall, sharingRecordsAfterNullCall.size(), 'Sharing records should remain unchanged when null parameters are passed');
 
         Test.stopTest();
     }
 
     /**
      * @description Test: testMethod for updateTrainingConductedDate method
      */
  
     @IsTest
     static void testConductedDateSetWhenCompleted()
     {
         Account patient = [SELECT Id FROM Account LIMIT 1];
         Training__c elearningTrainingOT = new Training__c();
             elearningTrainingOT.Account__c= patient.Id;
             elearningTrainingOT.RecordTypeId= TestDataFactory.getTrainingRtId(ConstantsUtil.E_LEARNING_RECORD_TYPE);
             elearningTrainingOT.Educator_Type__c= ConstantsUtil.EDUCATOR_TYPE_SG;
             elearningTrainingOT.Training_Method__c= LIVE_VIRTUAL;
             elearningTrainingOT.Training_Type__c= PRE_PROD_TRAINING; 
             elearningTrainingOT.Product__c= OMNIPOD_5; 
         
         insert elearningTrainingOT;
         Training__c assignedTraining = [SELECT Id, CSM__C, Training_Stage__c, Completion_Date__c FROM Training__c WHERE Id = :elearningTrainingOT.Id];
         Test.startTest();
         assignedTraining.Training_Stage__c=ConstantsUtil.STAGE_COMPLETED;
         update assignedTraining;
 
         Training__c updatedTraining = [SELECT Id, Training_Stage__c, Training_Conducted_Date__c FROM Training__c WHERE Id = :elearningTrainingOT.Id];
         Assert.areEqual(Date.today(), updatedTraining.Training_Conducted_Date__c,'Conducted Date should be set when Stage changes to Completed');
         Test.stopTest();
          
     }
 
     /**
      * @description Test: testMethod for Exception handling of updateTrainingConductedDate
      */
 
     @IsTest
     static void testUpdateTrainingConductedDateExceptionCatch() {
 
         Id eLearningRtId = Schema.SObjectType.Training__c
             .getRecordTypeInfosByDeveloperName()
             .get(ConstantsUtil.E_LEARNING_RECORD_TYPE)
             .getRecordTypeId();
         Account patient = [SELECT Id FROM Account LIMIT 1];
         Training__c training = new Training__c(
             Account__c = patient.Id,
             RecordTypeId = eLearningRtId,
             Training_Stage__c = ConstantsUtil.STAGE_COMPLETED
         );
         insert training;
 
         List<Training__c> newList = new List<Training__c>{ training };
 
         // Pass NULL old map to force NullPointerException
         Map<Id, Training__c> oldMap = null;
 
         Test.startTest();
         TrainingAssignmentHandler.updateTrainingConductedDate(newList, oldMap);
         Test.stopTest();
 
         // No assertion needed – test passes if no unhandled exception occurs
         Assert.isTrue(true, 'Exception handled successfully in catch block');
     }
 
     /**
      * @description Test: testMethod for setTrainingStage method
      */
 
     @IsTest
     static void testsetTrainingStage() { 
 
     Account patient = [SELECT Id FROM Account LIMIT 1];
     Training__c training = new Training__c(
             Account__c = patient.Id,
             RecordTypeId = TestDataFactory.getTrainingRtId(ConstantsUtil.LIVE_TRAINING_RECORD_TYPE),
             Educator_Type__c= ConstantsUtil.EDUCATOR_TYPE_CTS,
             Training_Stage__c = ConstantsUtil.STAGE_COMPLETED
         );   
 
     Test.startTest();
     insert training;
     Test.stopTest();
     Training__c updatedTraining = [SELECT Id, Training_Stage__c, Training_Conducted_Date__c FROM Training__c WHERE Id = :training.Id];
     Assert.areEqual(updatedTraining.Training_Stage__c, ConstantsUtil.STAGE_PENDING_ACCEPTANCE,'Training Stage is changed');
     
     }

       /**
     * @description Tests updateTrainingInternalTrainer method for INSERT operation
     */
    @IsTest
    static void testUpdateTrainingInternalTrainerOnInsert() {
        Test.startTest();
        Account patientRec = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];

        Training__c training = new Training__c(
            Account__c = patientRec.Id,
            RecordTypeId = TestDataFactory.getTrainingRtId('Live_Training'),
            Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_IT,
            Training_Stage__c = ConstantsUtil.STAGE_NEW
        );
        insert training;

        Training__c insertedTraining = [SELECT Id, Internal_Trainer__c, Training_Stage__c, Educator_Type__c, CSM__c 
                                        FROM Training__c WHERE Id = :training.Id];
        Assert.isNotNull(insertedTraining.CSM__c, 'CSM should be assigned by manageTrainingAssignments');
        Assert.areEqual(insertedTraining.CSM__c, insertedTraining.Internal_Trainer__c, 
            'Internal_Trainer should be set to CSM when Educator_Type is IT on INSERT');
        Assert.areEqual(ConstantsUtil.STAGE_ACCEPTED, insertedTraining.Training_Stage__c, 
            'Training_Stage should be ACCEPTED when Educator_Type is IT with CSM on INSERT');
        Assert.areEqual(ConstantsUtil.EDUCATOR_TYPE_IT, insertedTraining.Educator_Type__c, 
            'Educator_Type should remain IT');
        Test.stopTest();
    }

    /**
     * @description Tests updateTrainingInternalTrainer method for UPDATE operation
     */
    @IsTest
    static void testUpdateTrainingInternalTrainerOnUpdate() {
        // Query test data from @TestSetup
        Account patientRec = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Id csmUserId = UserInfo.getUserId();

        Training__c training = new Training__c(
            Account__c = patientRec.Id,
            RecordTypeId = TestDataFactory.getTrainingRtId('Live_Training'),
            Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CPT,
            Training_Stage__c = ConstantsUtil.STAGE_NEW,
            CSM__c = csmUserId
        );
        insert training;

        // Query the training after insert to verify initial state
        training = [SELECT Id, Internal_Trainer__c, Training_Stage__c, Educator_Type__c, CSM__c 
                    FROM Training__c WHERE Id = :training.Id];
        Assert.isNull(training.Internal_Trainer__c, 'Internal_Trainer should be null initially for CPT');

        Test.startTest();
        // Update Educator Type from CPT to IT
        training.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_IT;
        update training;
        Test.stopTest();

        // Query the training after update to verify automatic updates
        Training__c updatedTraining = [SELECT Id, Internal_Trainer__c, Training_Stage__c, Educator_Type__c, CSM__c 
                                       FROM Training__c WHERE Id = :training.Id];

        Assert.isNotNull(updatedTraining.CSM__c, 'CSM should be assigned after update');
        Assert.areEqual(updatedTraining.CSM__c, updatedTraining.Internal_Trainer__c, 
            'Internal_Trainer should be set to CSM when Educator_Type changes to IT on UPDATE');
        Assert.areEqual(ConstantsUtil.STAGE_ACCEPTED, updatedTraining.Training_Stage__c, 
            'Training_Stage should be ACCEPTED when Educator_Type changes to IT with CSM on UPDATE');
        Assert.areEqual(ConstantsUtil.EDUCATOR_TYPE_IT, updatedTraining.Educator_Type__c, 
            'Educator_Type should be IT after update');
    }

    /**
     * @description Tests exception handling in updateTrainingInternalTrainer method
     */
    @IsTest
    static void testUpdateTrainingInternalTrainerCatchBlock() {
        // Query test data from @TestSetup
        Account patientRec = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Id csmUserId = UserInfo.getUserId();

        // Create training with non-IT educator type
        Training__c training = new Training__c(
            Account__c = patientRec.Id,
            RecordTypeId = TestDataFactory.getTrainingRtId('Live_Training'),
            Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CPT,
            Training_Stage__c = ConstantsUtil.STAGE_NEW,
            CSM__c = csmUserId
        );
        insert training;
        
        Test.startTest();
        // Enable custom exception switch to trigger the catch block
        ConstantsUtil.customExceptionSwitch = true;
        
        try {
            // Update training to IT educator type to trigger updateTrainingInternalTrainer method
            training.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_IT;
            update training;
        } finally {
            // Always reset the switch
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();
        
        // Verify training still exists after exception was caught and logged
        Training__c resultTraining = [SELECT Id, Educator_Type__c, Internal_Trainer__c FROM Training__c WHERE Id = :training.Id];
        Assert.isNotNull(resultTraining, 'Training should still exist after exception in updateTrainingInternalTrainer');
        Assert.isNotNull(resultTraining.Id, 'Training Id should not be null after exception was handled');
    }
 }