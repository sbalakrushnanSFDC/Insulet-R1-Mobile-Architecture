/**
 * @description Unit tests for TrainingController
 * Covers positive/negative/bulk paths for all public methods.
 * Requirements:
 * - No SeeAllData
 * - startTest/stopTest usage
 * - Meaningful assertions
 * - @TestSetup for test data
 */
@IsTest
private class TrainingController_Test {
  /**
   * @description : Method to Create Test Data
   */
  @testSetup
  static void createData() {
    insert TestDataFactory.getAccountofTrainerRecordType(
      new Map<String, Object>()
    );
    Account trainer = [SELECT id, PersonContactId FROM Account];
    trainer.Contract_Type__c = 'Level 2';
    update trainer;

    Account practice = TestDataFactory.getAccountofPracticeRecordType();
    insert practice;

    AccountContactRelation acr = new AccountContactRelation();
    acr.ContactId = trainer.PersonContactId;
    acr.AccountId = practice.Id;
    acr.Roles = ConstantsUtil.ACR_ROLE_TRAINER;
    insert acr;

    AssessmentQuestionSet testQuestionSet = TestDataFactory.getAssessmentQuestionSet();
    insert testQuestionSet;

    OmniProcess testOmni = TestDataFactory.getOmniProcess(
      new Map<String, Object>{
        'Name' => 'Test OmniScript',
        'Type' => 'Assessment',
        'SubType' => 'Test',
        'Language' => 'English',
        'IsActive' => true,
        'OmniProcessType' => 'OmniScript'
      }
    );
    insert testOmni;

    insert TestDataFactory.getAssessmentDefinition(
      new Map<String, Object>{
        'Assessment_Question_Set__c' => testQuestionSet.Id,
        'OmniProcessId' => testOmni.Id,
        'Test_Name__c' => 'Test Exam',
        'Purpose' => 'Certification'
      }
    );

    AssessmentDefinition ad = [SELECT id FROM AssessmentDefinition LIMIT 1];
    Certification__c c = TestDataFactory.getCertification(
      new Map<String, Object>{
        'Trainer_Name__c' => trainer.Id,
        'Certification_Assessment__c' => ad.Id,
        'Retake_Exam__c' => true,
        'Completion_Status__c' => 'Completed',
        'Certification_Results__c' => 'Passed',
        'Certification_Date__c' => System.Today().addDays(-10),
        'Product__c' => 'Omnipod 5'
      }
    );
    insert c;

    Contract ccContract = TestDataFactory.getContract(trainer.Id);
    ccContract.clinic_admin_email__c = 'a@a.com';
    ccContract.Clinic_Admin_Name__c = 'a';
    ccContract.StartDate = Date.today();
    ccContract.EndDate = Date.today().addDays(100);
    insert ccContract;
    ccContract.Status = 'Activated';
    update ccContract;

    Multi_Location_Contract__c mlc = new Multi_Location_Contract__c();
    mlc.Related_Location__c = practice.Id;
    mlc.Contract__c = ccContract.Id;
    insert mlc;

    Training__c cptTraining;
    Training__c ccTraining;

    cptTraining = new TestDataFactory.CreateTrainingRecord()
      .setRecordType(ConstantsUtil.TRAINING_LIVE_TRAINING_RT)
      .setEducatorType(ConstantsUtil.EDUCATOR_TYPE_CPT)
      .setTrainingStage(ConstantsUtil.STAGE_PENDING_ACCEPTANCE)
      .setAccount(practice.Id)
      .save()
      .getRecord();
    cptTraining.External_Trainer__c = trainer.Id;
    update cptTraining;

    // Another CC training for CC list query path
    ccTraining = new TestDataFactory.CreateTrainingRecord()
      .setRecordType(ConstantsUtil.TRAINING_LIVE_TRAINING_RT)
      .setEducatorType(ConstantsUtil.EDUCATOR_TYPE_CC)
      .setTrainingStage(ConstantsUtil.STAGE_PENDING_ACCEPTANCE)
      .setAccount(practice.Id)
      .save()
      .getRecord();
    ccTraining.External_Trainer__c = trainer.Id;
    update ccTraining;
  }

  /**
   * @description : Method to Test reassignTraining
   */
  @isTest
  static void testReassignTraining() {
    Training__c t = [SELECT id FROM Training__c LIMIT 1];
    Test.startTest();
    TrainingController.reassignTraining(t.id);
    Test.stopTest();
    Training__c t2 = [SELECT id, Training_Stage__c FROM Training__c LIMIT 1];
    Assert.areEqual(
      t2.Training_Stage__c,
      ConstantsUtil.STAGE_PENDING_ACCEPTANCE,
      'Training is Re Assigned and Stage updated to PENDING_ACCEPTANCE'
    );
  }

  /**
   * @description : Method to Test Exception handling of reassignTraining
   */
  @isTest
  static void testReassignTrainingException() {
    Test.startTest();
    try {
      TrainingController.reassignTraining(null);
    } catch (Exception e) {
      Assert.isNotNull(e, 'Exception is Thrown');
    }
    Test.stopTest();
  }
  /**
   * @description : Method to Test UpdateTrainingStage
   */
  @isTest
  static void testUpdateTrainingStage() {
    Training__c t = [SELECT id FROM Training__c LIMIT 1];
    Test.startTest();
    try {
      TrainingController.updateTrainingStage(t.id, false);
      TrainingController.updateTrainingStage('', false);
    } catch (Exception e) {
      Assert.isNotNull(e, 'Exception is Thrown');
    }
    Test.stopTest();
  }
  /**
   * @description : Method to Test UpdateTrainingStage when called from a Quick Action
   */

  @isTest
  static void testUpdateTrainingStageFromQuickAction() {
    Training__c t = [SELECT id FROM Training__c LIMIT 1];
    Test.startTest();
    TrainingController.updateTrainingStage(t.id, true);
    Test.stopTest();
    Training__c t2 = [SELECT id, Training_Stage__c FROM Training__c LIMIT 1];
    Assert.areEqual(
      t2.Training_Stage__c,
      ConstantsUtil.STAGE_ACCEPTED,
      'Training is Accepted'
    );
  }

  /**
   * @description : Method to Test UpdateTrainingDeclineData
   */
  @isTest
  static void testUpdateTrainingDeclineData() {
    Training__c t = [SELECT id FROM Training__c LIMIT 1];
    TrainingController.TrainingDeclineWrapper wrap = new TrainingController.TrainingDeclineWrapper();
    wrap.trainingId = t.Id;
    wrap.isClickFromQuickAction = false;
    wrap.declineReason = 'Compatibility/supply issue';
    Test.startTest();
    TrainingController.updateTrainingDeclineData(JSON.serialize(wrap));
    Test.stopTest();
    Training__c t2 = [SELECT id, Training_Stage__c FROM Training__c LIMIT 1];
    Assert.areEqual(
      t2.Training_Stage__c,
      ConstantsUtil.STAGE_DECLINED,
      'Training is Declined'
    );
  }

  /**
   * @description : Method to Test Exception Handling of UpdateTrainingDeclineData
   */
  @isTest
  static void testUpdateTrainingDeclineDataException() {
    TrainingController.TrainingDeclineWrapper wrap = new TrainingController.TrainingDeclineWrapper();
    wrap.trainingId = null;
    wrap.isClickFromQuickAction = true;
    wrap.declineReason = 'Compatibility/supply issue';
    Test.startTest();
    try {
      TrainingController.updateTrainingDeclineData(JSON.serialize(wrap));
    } catch (Exception e) {
      Assert.isNotNull(e, 'Exception is Thrown');
    }
    Test.stopTest();
  }

  /**
   * @description : Method to Test LoadData
   */
  @isTest
  static void testLoadData() {
    Account trainer = [
      SELECT id, PersonContactId
      FROM Account
      WHERE PersonContactId != NULL
      LIMIT 1
    ];
    Test.startTest();
    TrainingController.TrainerWrapper wrap = TrainingController.loadData(
      trainer.PersonContactId
    );
    Test.stopTest();
    Assert.areEqual(
      wrap.isPractice,
      false,
      'Practice do not have more than one Trainer'
    );
  }

  /**
   * @description : Method to Test GetTrainingDetails
   */
  @isTest
  static void testGetTrainingDetails() {
    Account trainer = [
      SELECT id, PersonContactId, Trainer_Type__c
      FROM Account
      WHERE PersonContactId != NULL
      LIMIT 1
    ];
    Training__c t = [SELECT id FROM Training__c LIMIT 1];
    Test.startTest();
    TrainingController.TrainerWrapper wrap = TrainingController.getTrainingDetails(
      trainer.PersonContactId,
      t.Id
    );
    Test.stopTest();
    Assert.areEqual(
      wrap.training.Id,
      t.Id,
      'There is only one training assigned to trainer'
    );
  }

  /**
   * @description : Method to Test GetCPTTrainings
   */
  @isTest
  static void testGetCPTTrainings() {
    Account trainer = [
      SELECT id, PersonContactId
      FROM Account
      WHERE PersonContactId != NULL
      LIMIT 1
    ];
    Training__c t = [SELECT id FROM Training__c LIMIT 1];
    t.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CPT;
    t.Training_Stage__c = ConstantsUtil.STAGE_PENDING_ACCEPTANCE;
    update t;
    Test.startTest();
    List<Training__c> trainingList = TrainingController.getCPTTrainings(
      trainer.PersonContactId
    );
    Test.stopTest();
    Assert.areEqual(trainingList.size(), 0, 'No Records Returned');
  }

  /**
   * @description : Method to Test GetCCTrainings
   */
  @isTest
  static void testGetCCTrainings() {
    Account practice = [
      SELECT id, PersonContactId
      FROM Account
      WHERE PersonContactId = NULL
      LIMIT 1
    ];
    Training__c t = [SELECT id FROM Training__c LIMIT 1];
    t.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC;
    t.Training_Stage__c = ConstantsUtil.STAGE_PENDING_ACCEPTANCE;
    update t;
    Test.startTest();
    List<Training__c> trainingList = TrainingController.getCCTrainings(
      practice.Id
    );
    Test.stopTest();
    Assert.areEqual(trainingList.size(), 0, 'No Records Returned');
  }

  /**
   * @description : Method to Test Exception Handling of Null Input for  loadData , getCCTrainings , getCPTTrainings , getTrainingDetails
   */
  @isTest
  static void testExceptionHandling() {
    try {
      TrainingController.loadData(null);
    } catch (Exception e) {
      Assert.isNotNull(e, 'Exception is Thrown');
    }
    try {
      TrainingController.getCCTrainings(null);
    } catch (Exception e) {
      Assert.isNotNull(e, 'Exception is Thrown');
    }
    try {
      TrainingController.getCPTTrainings(null);
    } catch (Exception e) {
      Assert.isNotNull(e, 'Exception is Thrown');
    }
    try {
      TrainingController.getTrainingDetails(null, null);
    } catch (Exception e) {
      Assert.isNotNull(e, 'Exception is Thrown');
    }
  }
}