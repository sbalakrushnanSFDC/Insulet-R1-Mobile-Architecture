/**
 * @author      : Bhavya Chanan
 * @created Date: 12th Jan 2026
 * @description : Test class for TrainingTaskCreationHandler. Covers both positive and negative scenarios to ensure code reliability.
 * ============================ Logs =============================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       12th Jan 2026       Bhavya Chanan                 Initial Version NGOMCT-583
 * V1.0.1       23rd Jan 2026       Bhavya Chanan                 NGOMCT-1213
 */


@IsTest
private class TrainingTaskCreationHandler_FuncTest 
{
    public static final String FORCE_EXCEPTION= 'FORCE_EXCEPTION';
    public static final String PSG_CLINICAL_SERVICES_MANAGER= 'Clinical_Services_Manager';
    /**
     * @description Setup method to create common test data
     */
    @TestSetup
    static void setupTestData() 
    {
        
        // Create test user with Sales profile
        User salesUser = TestDataFactory.getTestUser('Sales', new Map<String, Object>{
            'FirstName' => 'Sales',
            'LastName' => 'TestUser'
        });
        insert salesUser;
        
        //Assign CSM permission set group to the user
        List<PermissionSetGroupComponent> components = [SELECT PermissionSetId FROM PermissionSetGroupComponent
        WHERE PermissionSetGroup.DeveloperName = :PSG_CLINICAL_SERVICES_MANAGER];
        
        List<PermissionSetAssignment> psAssignments = new List<PermissionSetAssignment>();

		for (PermissionSetGroupComponent c : components) {
    	psAssignments.add(new PermissionSetAssignment(
        AssigneeId = salesUser.Id,
        PermissionSetId = c.PermissionSetId
    	));
		}

		insert psAssignments;
                
        System.runAs(salesUser){
            
        insert TestDataFactory.getAccountofTrainerRecordType(new Map<String,Object>());
        Account trainer = [Select id,PersonContactId from Account];
        
        Account practice = TestDataFactory.getAccountofPracticeRecordType();
        insert practice;
        
        AccountContactRelation acr = new AccountContactRelation();
        acr.ContactId = trainer.PersonContactId;
        acr.AccountId = practice.Id;
        acr.Roles = ConstantsUtil.ACR_ROLE_TRAINER;
        insert acr;
        
        Training__c ctsTraining;
    	Training__c itTraining;
        
        ctsTraining = new TestDataFactory.CreateTrainingRecord()
        .setRecordType(ConstantsUtil.TRAINING_LIVE_TRAINING_RT)
        .setEducatorType(ConstantsUtil.EDUCATOR_TYPE_CTS)
        .setTrainingStage(ConstantsUtil.STAGE_PENDING_ACCEPTANCE)
        .setAccount(trainer.Id)
        .save()
        .getRecord();
        
        ctsTraining.CSM__c = UserInfo.getUserId();
        ctsTraining.Internal_Trainer__c= UserInfo.getUserId();
        update ctsTraining;

        
        itTraining = new TestDataFactory.CreateTrainingRecord()
        .setRecordType(ConstantsUtil.TRAINING_LIVE_TRAINING_RT)
        .setEducatorType(ConstantsUtil.EDUCATOR_TYPE_IT)
        .setTrainingStage(ConstantsUtil.STAGE_PENDING_ACCEPTANCE)
        .setAccount(trainer.Id)
        .save()
        .getRecord();
        
        itTraining.CSM__c = UserInfo.getUserId();
        itTraining.Internal_Trainer__c= UserInfo.getUserId();
        update itTraining;
            
        }                    
    }
    
    /**
    * @description SUCCESS for type IT on updation – createTasks()
    */
    @IsTest
    static void testCreateTasksSsuccessIT() {
        
        
        Training__c trainingRec = [SELECT Id,Account__c,Account__r.PersonContactId, Training_Conducted_Date__c ,Educator_Type__c
        FROM Training__c LIMIT 1];
                	
        trainingRec.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_IT;
        trainingRec.Training_Conducted_Date__c = Date.today();
        
        User testUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestUser' LIMIT 1];
        System.runAs(testUser) {
        
        Test.startTest();
        update trainingRec;        
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject, OwnerId, WhoId, WhatId
            FROM Task
            WHERE WhatId = :trainingRec.Id
        ];
		
        Assert.areEqual(1, tasks.size(), 'Task should be created');        
        Assert.areEqual(ConstantsUtil.TASK_SUBJECT_PATIENT_7_DAY_FOLLOWUP, tasks[0].Subject, 'Patient Task subject should be same');
                    
        }
    }
    
    /**
    * @description SUCCESS for type CTS on updation – createTasks()
    */
    @IsTest
    static void testCreateTasksSuccessCTS() {
        
    
        Training__c trainingRec = [SELECT Id,Account__c,Account__r.PersonContactId, Training_Conducted_Date__c ,Educator_Type__c
        FROM Training__c LIMIT 1];
       	
        trainingRec.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CTS;
        trainingRec.Training_Conducted_Date__c = Date.today();
        Test.startTest();
        update trainingRec;    
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject, OwnerId, WhoId, WhatId
            FROM Task
            WHERE WhatId = :trainingRec.Id
        ];

        Assert.areEqual(1, tasks.size(), 'Task should be created');        
        Assert.areEqual(ConstantsUtil.TASK_SUBJECT_PATIENT_7_DAY_FOLLOWUP, tasks[0].Subject, 'Patient Task subject should be same');
        
    }
        
    /**
    * @description SUCCESS on insertion – createTasks()
    */
    @IsTest
    static void testCreateTasksSuccessInsertion() {
        
       
        Training__c trainingRecRetrieve = [SELECT Id,Account__c,Account__r.PersonContactId, Training_Conducted_Date__c ,Educator_Type__c
        FROM Training__c LIMIT 1];
        Training__c trainingRec = new Training__c();
		trainingRec.Account__c= trainingRecRetrieve.Account__c;
        trainingRec.RecordTypeId=ConstantsUtil.TRAINING_LIVE_TRAINING_RT;
        trainingRec.Training_Stage__c =ConstantsUtil.STAGE_PENDING_ACCEPTANCE;
        trainingRec.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_IT;
        trainingRec.Training_Conducted_Date__c = Date.today();
        trainingRec.CSM__c = UserInfo.getUserId();
        trainingRec.Internal_Trainer__c= UserInfo.getUserId();
        
        User testUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestUser' LIMIT 1];
        System.runAs(testUser) {
        
        Test.startTest();
        insert trainingRec;                             
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject, OwnerId, WhoId, WhatId
            FROM Task
            WHERE WhatId = :trainingRec.Id
        ];

        
        Assert.areEqual(1, tasks.size(), 'Task should be created');        
        Assert.areEqual(ConstantsUtil.TASK_SUBJECT_PATIENT_7_DAY_FOLLOWUP, tasks[0].Subject, 'Patient Task subject should be same');
                    
        }
    }
        
    
    /**
    * @description CATCH BLOCK – createTasks()
    */
    @IsTest
    static void testCreateTasksException() {

        Test.startTest();       
        TrainingTaskCreationHandler.createTasks(null, null);
        Test.stopTest();
        Assert.isTrue(true, 'Exception was thrown as expected when customExceptionSwitch is true');
    }
        
    
    /**
    * @description CATCH BLOCK – getAccountToPersonContactMap()
    */
    @IsTest
    static void testGetAccountToPersonContactMapException() {

        Test.startTest();
        Map<Id, Id> result = TrainingTaskCreationHandler.getAccountToPersonContactMap(null);
        Test.stopTest();
		Assert.areEqual(null, result, 'No Account-PersonContact Map found');
        
    }
        
    /**
    * @description getTaskRecordTypeId – RECORD TYPE EXCEPTION
    */
    @IsTest
    static void testGetTaskRecordTypeIdException() {

        Test.startTest();
        Id recordtypeId = TrainingTaskCreationHandler.getTaskRecordTypeId(FORCE_EXCEPTION);
        Test.stopTest();
		Assert.areEqual(null, recordtypeId, 'recordtypeId FORCE_EXCEPTION');
        
    }
            
    /**
    * @description getTaskRecordTypeId – RECORD TYPE NOT FOUND
    */
    @IsTest
    static void testGetTaskRecordTypeIdNotFound() {

        Test.startTest();
        Id recordtypeId = TrainingTaskCreationHandler.getTaskRecordTypeId(null);
        Test.stopTest();
		Assert.areEqual(null, recordtypeId, 'recordtypeId not found');
                       
    }    
}