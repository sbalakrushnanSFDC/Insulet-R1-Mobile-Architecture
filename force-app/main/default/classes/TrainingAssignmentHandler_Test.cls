/**
 * @description : Test Class for Trigger Assignment Handler class
 * @author      : Ankur Chauhan
 * @created Date: 27th Oct 2025
 * responsible for test coverage of negative scenarios of TrainingAssignmentHandler class
 * @story Number: NGOMCT-337
 * Version      Modified Date       Modified By            Brief Note
 * V1.0.0       27th Oct 2025       Ankur Chauhan          Initial Version
 * V1.0.1       19th Nov 2025       Srinivas               Modified Version(NGOMCT-787)
 * V1.0.2       11th Dec 2025       Ankur Chauhan          Enhancements
 * V1.0.3       12th Feb 2026       Yogesh Rana            (NGOMCT-2099)
 * V1.0.4		20th Feb 2026		Shashank Nigam			NGOMCT-2102
 */
 @IsTest(isParallel=true)
 private class TrainingAssignmentHandler_Test {
 
     /**
      * @description Test setup method to create test data
      */
     @TestSetup
     static void setupTestData() {
         Account patient = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
             'PersonEmail' => 'patient' + System.currentTimeMillis() + '@example.com'
         });
         Insert patient;
         Account patientRec = [SELECT Id, PersonContactId FROM Account LIMIT 1];
         
         Account validPractice = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{ 'Name' => 'Valid Practice ' + System.currentTimeMillis() });
         validPractice.Do_Not_Use_For_Training__c = false;
         insert validPractice;

         Account invalidPractice = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{ 'Name' => 'Invalid Practice ' + System.currentTimeMillis() });
         invalidPractice.Do_Not_Use_For_Training__c = true;
         invalidPractice.Do_Not_Use_For_Training_Reason__c = ConstantsUtil.DO_NOT_USE_FOR_TRAINING_REASON_TERMINATED;
         insert invalidPractice;

         Account trainer = TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
             'PersonEmail' => 'trainer' + System.currentTimeMillis() + '@example.com'
         });
         insert trainer;

         new TestDataFactory.CreateTrainingRecord()
             .setAccount(patientRec.Id)
             .setRecordType(TestDataFactory.getTrainingRtId('Live_Training'))
             .setEducatorType(ConstantsUtil.EDUCATOR_TYPE_CTS)
             .save()
             .getRecord();
     }
 
     /**
      * @description testMethod for negative test case of training assignment
      * where Training List is passed as an empty list
      */
     @IsTest
     static void testTrainingAssignmentNegative1() {
         Test.startTest();
         List<Training__c> trainingList = new List<Training__c>();
         TrainingAssignmentHandler.manageTrainingAssignments(trainingList, null);
         Assert.isTrue(trainingList.isEmpty(), 'Training Assignment automation failed');
         Test.stopTest();
     }
 
     /**
      * @description testMethod for negative test case of training assignment
      * covers the catch block in the method
      */
     @IsTest
     static void testTrainingAssignmentNegative2() {
         Test.startTest();
         List<Training__c> trainingList = new List<Training__c>();
         Training__c trainingRecord = new Training__c(
             Educator_Type__c = 'IT');
         trainingList.add(trainingRecord);
         TrainingAssignmentHandler.manageTrainingAssignments(trainingList, null);
         Assert.isNull(trainingList[0].CSM__c, 'CSM should not be assigned when training record is incomplete');
         Test.stopTest();
     }

     /**
      * @description testMethod to test the scenario where the training stage Accepted if Educator type is CTS and Internal Trainer != null
      * training stage Pending Acceptance if Educator type is CTS and Internal Trainer = null
      */
     @IsTest
     static void testUpdateTrainingStage(){
       
         List<Training__c> trainingList = [SELECT id,Training_Stage__c from Training__c WHERE Educator_Type__c =: ConstantsUtil.EDUCATOR_TYPE_CTS AND Internal_Trainer__c = null  LIMIT 1];
         
         Assert.areEqual(ConstantsUtil.STAGE_PENDING_ACCEPTANCE,trainingList[0].Training_Stage__c, 'Training stage should be Pending Acceptance');
         
         Test.startTest();
         
         trainingList[0].Internal_Trainer__c = UserInfo.getUserId();
         UPDATE trainingList;
         List<Training__c> trainingRecList = [SELECT id,Training_Stage__c from Training__c WHERE Id =: trainingList[0].id ];
         
         Assert.areEqual(ConstantsUtil.STAGE_ACCEPTED,trainingRecList[0].Training_Stage__c, 'Training stage should be Accepted');
         Test.stopTest(); 
     }

       /**
     * @description Tests getEligibleTrainingRecords method - INSERT and UPDATE with eligible trainings
     * Covers both operations when trainings meet eligibility criteria
     */
    @IsTest
    static void testGetEligibleTrainingRecordsEligible() {
        Account practice = [SELECT Id FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT AND Do_Not_Use_For_Training__c = false LIMIT 1];
        Training__c setupTraining = [SELECT Id FROM Training__c LIMIT 1];

        Test.startTest();
        // Test INSERT using real Training Id from setup
        List<Training__c> trainingList = new List<Training__c>();
        Training__c eligibleTraining = new Training__c(
            Id = setupTraining.Id,
            Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC,
            Training_Stage__c = ConstantsUtil.STAGE_NEW,
            Practice__c = practice.Id
        );
        trainingList.add(eligibleTraining);
        
        Map<Id, Training__c> insertResult = TrainingAssignmentHandler.getEligibleTrainingRecords(
            trainingList, new Map<Id, Training__c>(), ConstantsUtil.INSERT_OPERATION
        );
        Assert.areEqual(1, insertResult.size(), 'Should return 1 eligible training on INSERT');
        
        Training__c updateTraining = new Training__c(
            Id = setupTraining.Id
        );
        updateTraining.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC;
        updateTraining.Training_Stage__c = ConstantsUtil.STAGE_ACCEPTED;
        updateTraining.Practice__c = practice.Id;
        
        Training__c oldTraining = updateTraining.clone(true);
        updateTraining.Training_Stage__c = ConstantsUtil.STAGE_NEW;
        
        Map<Id, Training__c> updateResult = TrainingAssignmentHandler.getEligibleTrainingRecords(
            new List<Training__c>{updateTraining}, 
            new Map<Id, Training__c>{updateTraining.Id => oldTraining}, 
            ConstantsUtil.UPDATE_OPERATION
        );
        
        Test.stopTest();
        Assert.areEqual(1, updateResult.size(), 'Should return 1 eligible training on UPDATE');
    }

    /**
     * @description Tests getEligibleTrainingRecords method - Ineligible trainings
     * Covers scenarios where trainings don't meet eligibility criteria
     */
    @IsTest
    static void testGetEligibleTrainingRecordsIneligible() {
        Account patientRec = [SELECT Id FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Account practice = [SELECT Id FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT AND Do_Not_Use_For_Training__c = false LIMIT 1];

        List<Training__c> trainingList = new List<Training__c>();
        
        trainingList.add(new Training__c(
            Account__c = patientRec.Id,
            RecordTypeId = TestDataFactory.getTrainingRtId('Live_Training'),
            Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_IT,
            Training_Stage__c = ConstantsUtil.STAGE_NEW,
            Practice__c = practice.Id
        ));
        
        trainingList.add(new Training__c(
            Account__c = patientRec.Id,
            RecordTypeId = TestDataFactory.getTrainingRtId('Live_Training'),
            Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC,
            Training_Stage__c = ConstantsUtil.STAGE_NEW,
            Practice__c = null
        ));
        
        Test.startTest();
        Map<Id, Training__c> result = TrainingAssignmentHandler.getEligibleTrainingRecords(
            trainingList, new Map<Id, Training__c>(), ConstantsUtil.INSERT_OPERATION
        );
        Test.stopTest();
        
        Assert.areEqual(0, result.size(), 'Should return 0 - all trainings are ineligible');
    }

    /**
     * @description Tests getPracticeAccountMap method
     * Verifies that the method correctly queries and returns practice accounts
     */
     @IsTest
     static void testGetPracticeAccountMap() {
         Account validPractice = [SELECT Id FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT AND Do_Not_Use_For_Training__c = false LIMIT 1];
         Account invalidPractice = [SELECT Id FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT AND Do_Not_Use_For_Training__c = true LIMIT 1];
 
         List<Training__c> trainings = new List<Training__c>{
             new Training__c(Practice__c = validPractice.Id),
             new Training__c(Practice__c = invalidPractice.Id)
         };
         
         Test.startTest();
         Map<Id, Account> practiceAccountMap = TrainingAssignmentHandler.getPracticeAccountMap(trainings);
         Test.stopTest();
         
         Assert.areEqual(2, practiceAccountMap.size(), 'Should return 2 practice accounts');
         Assert.isFalse(practiceAccountMap.get(validPractice.Id).Do_Not_Use_For_Training__c, 
             'Valid practice should have Do_Not_Use_For_Training = false');
         Assert.isTrue(practiceAccountMap.get(invalidPractice.Id).Do_Not_Use_For_Training__c, 
             'Invalid practice should have Do_Not_Use_For_Training = true');
     }

     /**
     * @description Tests updateTrainingRecords method - Invalid practice scenario
     * Verifies that trainings with invalid practices are auto-corrected
     */
    @IsTest
    static void testUpdateTrainingRecordsInvalidPractice() {
        Account patientRec = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Account invalidPractice = [SELECT Id, Do_Not_Use_For_Training__c FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT AND Do_Not_Use_For_Training__c = true LIMIT 1];
        Account trainer = [SELECT Id FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_TRAINER_RT LIMIT 1];

        Training__c training = new Training__c(
            Account__c = patientRec.Id,
            Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC,
            Training_Stage__c = ConstantsUtil.STAGE_NEW,
            Practice__c = invalidPractice.Id,
            External_Trainer__c = trainer.Id
        );

        Id setupTrainingId = [SELECT Id FROM Training__c LIMIT 1].Id;
        Map<Id, Training__c> trainingMap = new Map<Id, Training__c>{setupTrainingId => training};
        Map<Id, Account> practiceAccountMap = new Map<Id, Account>{invalidPractice.Id => invalidPractice};
        
        Test.startTest();
        TrainingAssignmentHandler.updateTrainingRecords(trainingMap, practiceAccountMap);
        Test.stopTest();
        
        Assert.areEqual(ConstantsUtil.STAGE_ACCEPTED, training.Training_Stage__c, 'Stage should be ACCEPTED');
        Assert.areEqual(ConstantsUtil.EDUCATOR_TYPE_IT, training.Educator_Type__c, 'Type should be IT');
        Assert.isNull(training.Practice__c, 'Practice should be cleared');
        Assert.isNull(training.External_Trainer__c, 'External_Trainer should be cleared');
    }

    /**
     * @description Tests updateTrainingRecords method - Valid practice scenario
     * Verifies that trainings with valid practices are NOT modified
     */
    @IsTest
    static void testUpdateTrainingRecordsValidPractice() {
        Account patientRec = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Account validPractice = [SELECT Id, Do_Not_Use_For_Training__c FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT AND Do_Not_Use_For_Training__c = false LIMIT 1];

        Training__c training = new Training__c(
            Account__c = patientRec.Id,
            Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC,
            Training_Stage__c = ConstantsUtil.STAGE_NEW,
            Practice__c = validPractice.Id
        );

        Id setupTrainingId = [SELECT Id FROM Training__c LIMIT 1].Id;
        Map<Id, Training__c> trainingMap = new Map<Id, Training__c>{setupTrainingId => training};
        Map<Id, Account> practiceAccountMap = new Map<Id, Account>{validPractice.Id => validPractice};
        
        Test.startTest();
        TrainingAssignmentHandler.updateTrainingRecords(trainingMap, practiceAccountMap);
        Test.stopTest();
        
        Assert.areEqual(ConstantsUtil.STAGE_NEW, training.Training_Stage__c, 'Stage should remain NEW');
        Assert.areEqual(ConstantsUtil.EDUCATOR_TYPE_CC, training.Educator_Type__c, 'Type should remain CC');
        Assert.areEqual(validPractice.Id, training.Practice__c, 'Practice should remain set');
    }

     /**
     * @description Tests ManageManualAssignments method - null scenario
     */
     @isTest
     static void testManageManualAssignments(){
         Test.startTest();
         TrainingAssignmentHandler.manageManualAssignments(null,null);
         Test.stopTest();
         Assert.isTrue(true, 'No Exception thrown with smooth method exit');
     }
 }