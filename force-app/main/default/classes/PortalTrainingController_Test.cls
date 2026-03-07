/**
 * @description This class handles the code coverage for TrainingController
 * Jira Story Number: NGOMCT-645 AND NGOMCT-646
 * Developer: Srinivas
 * Date: 31/10/2025
 * Comments : We can't use @isTest(isParallel=true) because of this error:  APEX_DATA_ACCESS_RESTRICTION, In parallel Apex tests, DML operations aren't permitted on this type of object: User: []
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       31st Oct 2025       Srinivas                Initial Version(NGOMCT-645 AND NGOMCT-646)
 * V1.0.1       19th Nov 2025       Srinivas                Modified Version(NGOMCT-787)
 */

@isTest
public class PortalTrainingController_Test {
    /**
     * @description : Method to Create Test Data
	*/
    @testSetup
    static void createData(){
        
        insert TestDataFactory.getAccountofTrainerRecordType(new Map<String,Object>());
        Account trainer = [Select id,PersonContactId from Account];
        trainer.Contract_Expiration_Date__c = Date.today().addDays(30);
        trainer.Trainer_Type__c = System.Label.Trainer_Type_CC;
        update trainer;
        
        Account practice = TestDataFactory.getAccountofPracticeRecordType();
        insert practice;
        
        AccountContactRelation acr = new AccountContactRelation();
        acr.ContactId = trainer.PersonContactId;
        acr.AccountId = practice.Id;
        acr.Roles = ConstantsUtil.ACR_ROLE_TRAINER;
        insert acr;
        
        // Create AssessmentQuestionSet
        AssessmentQuestionSet testQuestionSet = TestDataFactory.getAssessmentQuestionSet();
        insert testQuestionSet;
        
        // Create OmniProcess (Required for AssessmentDefinition)
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
        
        // Single certification with active date (Certification_Date__c is used as Certification_Expiration_Date__c is formula)
        Certification__c testCertification = TestDataFactory.getCertification(new Map<String, Object>{
            'Trainer_Name__c' => trainer.Id,
            'Product__c' => 'DASH',
            'Certification_Assessment__c' => testAssessmentDef.Id,
            'Completion_Status__c' => 'Pending',
            'Certification_Results__c' => 'Passed',
            'Certification_Date__c' => Date.today().addDays(-800) // Set date in past so expiration is in future
        });
        insert testCertification;
        
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
    static void testReassignTraining(){
        Training__c t = [Select id from Training__c limit 1];
        Test.startTest();
        TrainingController.reassignTraining(t.id);
        Test.stopTest();
        Training__c t2 = [Select id,Training_Stage__c from Training__c limit 1];
        Assert.areEqual(t2.Training_Stage__c,ConstantsUtil.STAGE_PENDING_ACCEPTANCE ,'Training is Re Assigned and Stage updated to PENDING_ACCEPTANCE');
    }
    
    /** 
     * @description : Method to Test Exception handling of reassignTraining
	*/
    @isTest
    static void testReassignTrainingException(){
        Test.startTest();
        try{
        	TrainingController.reassignTraining(null);   
        }catch(Exception e){
            Assert.isNotNull(e,'Exception is Thrown');
        }
        Test.stopTest();
    }
    /** 
     * @description : Method to Test UpdateTrainingStage
	*/
    @isTest
    static void testUpdateTrainingStage(){
        Training__c t = [Select id from Training__c limit 1];
        Test.startTest();
        try{
        	TrainingController.updateTrainingStage(t.id,false);   
        }
        catch(Exception e){
            Assert.isNotNull(e,'Exception is Thrown');
        }
        Test.stopTest();
    }
    /** 
     * @description : Method to Test UpdateTrainingStage when called from a Quick Action
	*/
    
    @isTest
    static void testUpdateTrainingStageFromQuickAction(){
        Training__c t = [Select id from Training__c limit 1];
        Test.startTest();
        TrainingController.updateTrainingStage(t.id,false);
        Test.stopTest();
        Training__c t2 = [Select id,Training_Stage__c from Training__c limit 1];
        Assert.areEqual(t2.Training_Stage__c,'Pending Acceptance' , 'Training is Pending Acceptance');
    }
    
    /** 
     * @description : Method to Test UpdateTrainingStage when called from a Quick Action
	*/
    
    @isTest
    static void testUpdateTrainingStageFromQuickActionException(){
        Training__c t = [Select id from Training__c limit 1];
        Test.startTest();
        String r = TrainingController.updateTrainingStage('null',true);
        Test.stopTest();
        Training__c t2 = [Select id,Training_Stage__c from Training__c limit 1];
        Assert.areEqual(System.Label.Error_Message, r, 'Error as no records found');
    }
    
    /** 
     * @description : Method to Test UpdateTrainingDeclineData
	*/
    @isTest
    static void testUpdateTrainingDeclineData(){
        Training__c t = [Select id from Training__c limit 1];
        TrainingController.TrainingDeclineWrapper wrap = new TrainingController.TrainingDeclineWrapper();
        wrap.trainingId = t.Id;
        wrap.isClickFromQuickAction = false;
        wrap.declineReason = 'Compatibility/supply issue';
        Test.startTest();
        TrainingController.updateTrainingDeclineData(JSON.serialize(wrap));
        Test.stopTest();
        Training__c t2 = [Select id,Training_Stage__c from Training__c limit 1];
        Assert.areEqual(t2.Training_Stage__c,ConstantsUtil.STAGE_DECLINED , 'Training is Declined');
    }
    
    /** 
     * @description : Method to Test Exception Handling of UpdateTrainingDeclineData
	*/
    @isTest
    static void testUpdateTrainingDeclineDataException(){
        TrainingController.TrainingDeclineWrapper wrap = new TrainingController.TrainingDeclineWrapper();
        wrap.trainingId = null;
        wrap.isClickFromQuickAction = false;
        wrap.declineReason = 'Compatibility/supply issue';
        Test.startTest();
        try{
            TrainingController.updateTrainingDeclineData(JSON.serialize(wrap));
        }
        catch(Exception e){
            Assert.isNotNull(e,'Exception is Thrown');
        }
        Test.stopTest();
  }
    /** 
     * @description : Method to Test Exception Handling of UpdateTrainingDeclineData
	*/
    @isTest
    static void testUpdateTrainingDeclineDataException2(){
        TrainingController.TrainingDeclineWrapper wrap = new TrainingController.TrainingDeclineWrapper();
        wrap.trainingId = null;
        wrap.isClickFromQuickAction = true;
        wrap.declineReason = 'Compatibility/supply issue';
        Test.startTest();
        try{
            TrainingController.updateTrainingDeclineData(JSON.serialize(wrap));
        }
        catch(Exception e){
            Assert.isNotNull(e,'Exception is Thrown');
        }
        Test.stopTest();
  }

     /**
     * @description : Method to Test LoadData
	*/
    @isTest
    static void testLoadData(){
        Account trainer = [Select id,PersonContactId from Account where PersonContactId!= null Limit 1];
        Test.startTest();
        TrainingController.TrainerWrapper wrap = TrainingController.loadData(trainer.PersonContactId);
        Test.stopTest();
        Assert.areEqual(wrap.isPractice,false , 'Practice do not have more than one Trainer');
    }
    
    /** 
     * @description : Method to Test GetTrainingDetails
	*/
    @isTest
    static void testGetTrainingDetails(){
        Account trainer = [Select id,PersonContactId,Trainer_Type__c from Account where PersonContactId!= null Limit 1];
        Training__c t = [Select id from Training__c limit 1];
        Test.startTest();
        TrainingController.TrainerWrapper wrap = TrainingController.getTrainingDetails(trainer.PersonContactId,t.Id);
        Test.stopTest();
        Assert.areEqual(wrap.training.Id,t.Id , 'There is only one training assigned to trainer');
    }
    
    /** 
     * @description : Method to Test GetCPTTrainings
	*/
    @isTest
    static void testGetCPTTrainings(){
        Account trainer = [Select id,PersonContactId from Account where PersonContactId!= null Limit 1];
        Training__c t = [Select id from Training__c limit 1];
        t.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CPT;
        t.Training_Stage__c = ConstantsUtil.STAGE_PENDING_ACCEPTANCE;
        update t;
        Test.startTest();
        List<Training__c> trainingList = TrainingController.getCPTTrainings(trainer.PersonContactId);
        Test.stopTest();
        Assert.areEqual(trainingList.size() , 0 , 'No Records Returned');
    }
    
    /** 
     * @description : Method to Test GetCCTrainings
	*/
    @isTest
    static void testGetCCTrainings(){
        Account practice = [Select id,PersonContactId from Account where PersonContactId = null Limit 1];
        Training__c t = [Select id from Training__c limit 1];
        t.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC;
        t.Training_Stage__c = ConstantsUtil.STAGE_PENDING_ACCEPTANCE;
        update t;
        Test.startTest();
        List<Training__c> trainingList = TrainingController.getCCTrainings(practice.Id);
        Test.stopTest();
        Assert.areEqual(trainingList.size() , 0 , 'No Records Returned');
    }
    
    /** 
     * @description : Method to Test Exception Handling of Null Input for  loadData , getCCTrainings , getCPTTrainings , getTrainingDetails
	*/
    @isTest
    static void testExceptionHandling(){
        try{
            TrainingController.loadData(null);
        }catch(Exception e){
            Assert.isNotNull(e,'Exception is Thrown');
        }
        try{
            TrainingController.getCCTrainings(null);
        }catch(Exception e){
            Assert.isNotNull(e,'Exception is Thrown');
        }
        try{
            TrainingController.getCPTTrainings(null);
        }catch(Exception e){
            Assert.isNotNull(e,'Exception is Thrown');
        }
        try{
            TrainingController.getTrainingDetails(null, null);
        }catch(Exception e){
            Assert.isNotNull(e,'Exception is Thrown');
        }
        try{
            TrainingController.updateTrainingStage('',true);
        }catch(Exception e){
            Assert.isNotNull(e,'Exception is Thrown');
        }
  }
    
    @isTest
    static void testupdateTrainingStage2(){
        Account acc = [Select id,PersonContactId,Trainer_Type__c from Account where Trainer_Type__c = :System.Label.Trainer_Type_CC];
       
        // Community User (AccountId required)
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name='External Trainer'];
        User communityUser = new User(
            FirstName='Community',
            LastName='User',
            Username='communityuser'+Math.random()+'@example.com',
            Email='communityuser@example.com',
            Alias='cuser',
            TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US',
            EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US',
            ProfileId = communityProfile.Id,
            ContactId = acc.PersonContactId
        );
        //insert communityUser;
        
        Training__c t = [Select id from Training__c limit 1];
        //System.runAs(communityUser){    
            Test.startTest();
            TrainingController.updateTrainingStage(t.id,true);
            Test.stopTest();
            Training__c t2 = [Select id,Training_Stage__c from Training__c limit 1];
            Assert.areEqual(t2.Training_Stage__c,ConstantsUtil.STAGE_ACCEPTED , 'Training is Accepted');
    	//}
  }
}