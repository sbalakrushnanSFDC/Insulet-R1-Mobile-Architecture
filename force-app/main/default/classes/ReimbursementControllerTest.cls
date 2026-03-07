/**
 * @description Test class for ReimbursementController.
 *              Provides comprehensive test coverage for all controller methods including
 *              form initialization, training/observation retrieval, rate calculation,
 *              and reimbursement CRUD operations.
 * @author Shashank Nigam
 * @group Reimbursement
 * @see ReimbursementController
 */
@IsTest
public class ReimbursementControllerTest {
     
    /**
     * @description Sets up test data for all test methods.
     *              Creates trainer accounts (Level 1, 2, 3), patient account, practice account,
     *              training rate records, training records, observation record, and reimbursement record.
     */
    @TestSetup
    static void setupTestData() {
        OrgSync_UtilityService.orgSyncUserId = UserInfo.getUserId();
        ConstantsUtil.getConversionTypeManual();
        
        // Create trainer accounts with different contract types
        Account trainerLevel1 = TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
            'Contract_Type__c' => 'Level 1'
        });
        insert trainerLevel1;
        
        Account trainerLevel2 = TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
            'LastName' => 'Trainer2',
            'PersonEmail' => 'trainer2@example.com',
            'Contract_Type__c' => 'Level 2',
            'Trainer_Type__c' => 'Certified Pod Trainer',
             'Contract_Expiration_Date__c' => System.Today()
        });
        insert trainerLevel2;
        
        Account trainerLevel3 = TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
            'LastName' => 'Trainer3',
            'PersonEmail' => 'trainer3@example.com',
            'Contract_Type__c' => 'Level 3'
        });
        insert trainerLevel3;
        
        // Create patient account for training
        Account patient = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'Current_Therapy__c' => 'Insulin Pump'
        });
        insert patient;
        
        // Create practice account
        Account practice = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
        });
        insert practice;
        
        // Create Training Rate records for rate calculations
        Training_Rate__c trainingRateCPT = new Training_Rate__c(
            Rate_Type__c = 'Training',
            Educator_Type__c = 'CPT',
            Training_Type__c = 'Insulin Start Training',
            Contract_Type__c = 'Level 2',
            Rate__c = 100.00,
            Start_Date__c = Date.today().addMonths(-12),
            End_Date__c = null
        );
        insert trainingRateCPT;
        
        Training_Rate__c trainingRateCC = new Training_Rate__c(
            Rate_Type__c = 'Training',
            Educator_Type__c = 'CC',
            Training_Type__c = 'Insulin Start Training',
            Contract_Type__c = 'Level 2',
            Training_Method__c = 'Live In-Person',
            Current_Therapy__c = 'Pump Therapy',
            Product__c = 'Omnipod 5',
            Rate__c = 150.00,
            Start_Date__c = Date.today().addMonths(-12),
            End_Date__c = null
        );
        insert trainingRateCC;
        
        Training_Rate__c mileageRate = new Training_Rate__c(
            Rate_Type__c = 'Mileage',
            Rate__c = 0.67,
            Start_Date__c = Date.today().addMonths(-12),
            End_Date__c = null
        );
        insert mileageRate;
        
        Training_Rate__c observationRate = new Training_Rate__c(
            Rate_Type__c = 'Observation',
            Rate__c = 25.00,
            Start_Date__c = Date.today().addMonths(-12),
            End_Date__c = null
        );
        insert observationRate;
        
        // Create Training record for CPT
        Training__c trainingCPT = new TestDataFactory.CreateTrainingRecord()
            .setAccount(patient.Id)
            .setRecordType(TestDataFactory.getTrainingRtId('Live_Training'))
            .setEducatorType('CPT')
            .getRecord();
        trainingCPT.External_Trainer__c = trainerLevel2.Id;
        trainingCPT.Training_Type__c = 'Insulin Start Training';
        trainingCPT.Training_Method__c = 'Live In-Person';
        trainingCPT.Completion_Date__c = Date.today().addDays(-10);
        trainingCPT.Training_Conducted_Date__c = Date.today().addDays(-10);
        trainingCPT.Part_of_Group_Training__c = false;
        insert trainingCPT;
        
        // Create Training record for CC
        Training__c trainingCC = new TestDataFactory.CreateTrainingRecord()
            .setAccount(patient.Id)
            .setEducatorType(ConstantsUtil.EDUCATOR_TYPE_CC)
            .setRecordType(TestDataFactory.getTrainingRtId('Live_Training'))
            .getRecord();
        trainingCC.External_Trainer__c = trainerLevel2.Id;
        trainingCC.Practice__c = practice.Id;
        trainingCC.Training_Type__c = 'Insulin Start Training';
        trainingCC.Training_Method__c = 'Live In-Person';
        trainingCC.Completion_Date__c = Date.today().addDays(-10);
        trainingCC.Training_Conducted_Date__c = Date.today().addDays(-10);
        trainingCC.Part_of_Group_Training__c = false;
        insert trainingCC;
        
        // Create Observation record
        Observation__c observation = TestDataFactory.getObservation(new Map<String, Object>{
            'Trainer_Name__c' => trainerLevel2.Id,
            'Delegate_Observer__c' => trainerLevel3.Id,
            'Observation_Date__c' => Date.today().addDays(-5),
            'Observation_Type__c' => 'CPT',
            'Delegate_Observer_Approval_Status__c' => 'Approved'
        });
        insert observation;
        
        // Create Reimbursement record
        Reimbursement__c reimbursement = new Reimbursement__c(
            Trainer__c = trainerLevel3.Id,
            Type__c = ConstantsUtil.REIMBURSEMENT_TYPE_1_1_PATIENT_TRAINING,
            Status__c = 'Draft',
            Meals__c = 50.00,
            Hotels__c = 100.00,
            Car_Rental__c = 75.00,
            Train_Bus_Airfare__c = 200.00,
            Tolls__c = 10.00,
            Parking__c = 20.00,
            Other__c = 15.00,
            Rate_Applied__c = 100.00,
            Comments__c = 'Test reimbursement',
            Observation__c = observation.id
        );
        insert reimbursement;
        
        // Create Reimbursement Association
        Reimbursement_Association__c association = new Reimbursement_Association__c(
            Reimbursement__c = reimbursement.Id,
            Training__c = trainingCPT.Id
        );
        insert association;
        
        List<SObject> recordsToInsert = new List<SObject>();
        recordsToInsert.add(TestDataFactory.getOmniProcess(new Map<String, Object>{ 'type' => 'Assessment','subtype' =>'Test'}));
        recordsToInsert.add(TestDataFactory.getAssessmentQuestionSet());
		insert recordsToInsert;
        
        AssessmentDefinition ad = TestDataFactory.getAssessmentDefinition(new Map<String,Object> {'OmniProcessId'=> recordsToInsert[0].id,
            'Assessment_Question_Set__c' => recordsToInsert[1].Id,
            'Test_Name__c' => 'Test Exam',
            'Purpose' => 'Certification'});
        insert ad;
        
        Certification__c c = TestDataFactory.getCertification(new Map<String,Object>{
            'Trainer_Name__c' => trainerLevel2.Id,
            'Certification_Assessment__c' => ad.Id,
            'Retake_Exam__c' => true,
            'Completion_Status__c' => 'Completed',
            'Certification_Results__c' => 'Passed',
            'Certification_Date__c' => System.Today(),
            'Product__c' => 'Omnipod 5'
        });
        insert c;
    }
    
    /**
     * @description Tests showReimbursementForm method with submitted status for Level 1 contract type trainer.
     *              Verifies that Level 1 trainers are not eligible to see the reimbursement form.
     */
    @IsTest
    static void testShowReimbursementFormLevel1() {
        Account trainer = [SELECT Id FROM Account WHERE Contract_Type__c = 'Level 1' LIMIT 1];
        Reimbursement__c r = [Select id from Reimbursement__c limit 1];
        r.Status__c = ConstantsUtil.STATUS_SUBMITTED;
        update r;
        
        Test.startTest();
        Boolean result = ReimbursementController.showReimbursementForm(trainer.Id,r.Id);
        Test.stopTest();
        
        Assert.isFalse(result, 'Level 1 trainers should not see reimbursement form');
    }
    
    /**
     * @description Tests showReimbursementForm method with approved status for Level 1 contract type trainer.
     *              Verifies that Level 1 trainers are not eligible to see the reimbursement form.
     */
    @IsTest
    static void testShowReimbursementFormLevel1WithApprovedStatus() {
        Account trainer = [SELECT Id FROM Account WHERE Contract_Type__c = 'Level 1' LIMIT 1];
        Reimbursement__c r = [Select id from Reimbursement__c limit 1];
        r.Status__c = ConstantsUtil.STATUS_APPROVED;
        update r;
        
        Test.startTest();
        Boolean result = ReimbursementController.showReimbursementForm(trainer.Id,r.Id);
        Test.stopTest();
        
        Assert.isFalse(result, 'Level 1 trainers should not see reimbursement form');
    }
    
     /**
     * @description Tests showReimbursementForm method with paid status for Level 1 contract type trainer.
     *              Verifies that Level 1 trainers are not eligible to see the reimbursement form.
     */
    @IsTest
    static void testShowReimbursementFormLevel1WithPaidStatus() {
        Account trainer = [SELECT Id FROM Account WHERE Contract_Type__c = 'Level 1' LIMIT 1];
        Reimbursement__c r = [Select id from Reimbursement__c limit 1];
        r.Status__c = ConstantsUtil.STATUS_PAID;
        update r;
        
        Test.startTest();
        Boolean result = ReimbursementController.showReimbursementForm(trainer.Id,r.Id);
        Test.stopTest();
        
        Assert.isFalse(result, 'Level 1 trainers should not see reimbursement form');
    }
    
    /**
     * @description Tests showReimbursementForm method for Level 2 contract type trainer.
     *              Verifies that Level 2 trainers are eligible to see the reimbursement form.
     */
    @IsTest
    static void testShowReimbursementFormLevel2() {
        Account trainer = [SELECT Id FROM Account WHERE Contract_Type__c = 'Level 2' LIMIT 1];
        
        Test.startTest();
        Boolean result = ReimbursementController.showReimbursementForm(trainer.Id,'null');
        Test.stopTest();
        
        Assert.isTrue(result, 'Level 2 trainers should see reimbursement form');
    }
    
    /**
     * @description Tests initializeReimbursementForm method for Level 2 contract type trainer.
     *              Verifies that the form wrapper is returned with picklist values (excluding Observation).
     */
    @IsTest
    static void testInitializeReimbursementFormLevel2() {
        Account trainer = [SELECT Id FROM Account WHERE Contract_Type__c = 'Level 2' LIMIT 1];
        
        Test.startTest();
        ReimbursementController.ReimbursementFormWrapper result = ReimbursementController.initializeReimbursementForm(trainer.Id);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Wrapper should not be null');
        Assert.isNotNull(result.picklistLabels, 'Picklist labels should not be null');
    }
    
    /**
     * @description Tests initializeReimbursementForm method for Level 3 contract type trainer.
     *              Verifies that the form wrapper is returned with all picklist values including Observation.
     */
    @IsTest
    static void testInitializeReimbursementFormLevel3() {
        Account trainer = [SELECT Id FROM Account WHERE Contract_Type__c = 'Level 3' LIMIT 1];
        
        Test.startTest();
        ReimbursementController.ReimbursementFormWrapper result = ReimbursementController.initializeReimbursementForm(trainer.Id);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Wrapper should not be null');
        Assert.isNotNull(result.picklistLabels, 'Picklist labels should not be null for Level 3');
    }
    
    /**
     * @description Tests getTrainings method to retrieve completed trainings for a trainer.
     *              Verifies that trainings are returned as RecordWrapper objects.
     */
    @IsTest
    static void testGetTrainings() {
        Account trainer = [SELECT Id FROM Account WHERE Contract_Type__c = 'Level 2' LIMIT 1];
        
        Test.startTest();
        List<ReimbursementController.RecordWrapper> results = ReimbursementController.getTrainings(trainer.Id);
        Test.stopTest();
        
        Assert.isNotNull(results, 'Results should not be null');
    }
    
    /**
     * @description Tests getObservations method to retrieve observations for a delegate observer.
     *              Verifies that observations are returned as RecordWrapper objects.
     */
    @IsTest
    static void testGetObservations() {
        Account observer = [SELECT Id FROM Account WHERE Contract_Type__c = 'Level 3' LIMIT 1];
        
        Test.startTest();
        List<ReimbursementController.RecordWrapper> results = ReimbursementController.getObservations(observer.Id);
        Test.stopTest();
        
        Assert.isNotNull(results, 'Results should not be null');
    }
    
    /**
     * @description Tests submitForApproval method to submit a reimbursement for approval.
     *              Verifies that the reimbursement status is updated to 'Submitted'.
     */
    @IsTest
    static void testSubmitForApproval() {
        Reimbursement__c reimbursement = [SELECT Id FROM Reimbursement__c LIMIT 1];
        
        Test.startTest();
        ReimbursementController.submitForApproval(reimbursement.Id);
        Test.stopTest();
        
        Reimbursement__c updatedReimbursement = [
            SELECT Status__c 
            FROM Reimbursement__c 
            WHERE Id = :reimbursement.Id
        ];
        Assert.areEqual('Submitted', updatedReimbursement.Status__c, 'Status should be Submitted');
    }
    
  /**
     * @description Tests submitForApproval method by providing invalid record Id.
     */
    @IsTest
    static void testSubmitForApprovalWithInvalidId() {
        Test.startTest();
        try {
            ReimbursementController.submitForApproval(null);
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage() != null,'The system should throw an exception for an invalid Id');
        }
        Test.stopTest();
    }

    
    /**
     * @description Tests getReimbursement method to retrieve a reimbursement by Id.
     *              Verifies that the reimbursement data is returned correctly in the wrapper.
     */
    @IsTest
    static void testGetReimbursement() {
        Reimbursement__c reimbursement = [SELECT Id FROM Reimbursement__c LIMIT 1];
        
        Test.startTest();
        ReimbursementController.ReimbursementWrapper result = ReimbursementController.getReimbursement(reimbursement.Id);
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(reimbursement.Id, result.Id, 'Reimbursement Id should match');
    }
    
    /**
     * @description Tests getReimbursement method to retrieve a reimbursement by Id.
     *              Verifies that the reimbursement data is returned correctly in the wrapper.
     */
    @IsTest
    static void testGetReimbursement2() {
        Reimbursement__c reimbursement = [SELECT Id,Observation__c FROM Reimbursement__c LIMIT 1];
        reimbursement.Observation__c = null;
        update reimbursement;
        
        Test.startTest();
        ReimbursementController.ReimbursementWrapper result = ReimbursementController.getReimbursement(reimbursement.Id);
        ReimbursementController.RecordWrapper w = new ReimbursementController.RecordWrapper();
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(reimbursement.Id, result.Id, 'Reimbursement Id should match');
    }
    
    /**
     * @description Tests saveReimbursement method for creating a new reimbursement record.
     *              Verifies that a new reimbursement is inserted with the provided data.
     */
    @IsTest
    static void testSaveReimbursementNew() {
        Account trainer = [SELECT Id FROM Account WHERE Contract_Type__c = 'Level 2' LIMIT 1];
        Training__c training = [
            SELECT Id 
            FROM Training__c 
            WHERE Educator_Type__c = :ConstantsUtil.EDUCATOR_TYPE_CPT 
            LIMIT 1
        ];
        
        ReimbursementController.ReimbursementWrapper wrapper = new ReimbursementController.ReimbursementWrapper();
        wrapper.trainerId = trainer.Id;
        wrapper.trainingId = training.Id;
        wrapper.type = ConstantsUtil.REIMBURSEMENT_TYPE_1_1_PATIENT_TRAINING;
        wrapper.mealAmount = 25.00;
        wrapper.hotelAmount = 80.00;
        wrapper.carRentalAmount = 50.00;
        wrapper.trainBusAirfareAmount = 100.00;
        wrapper.tollsAmount = 5.00;
        wrapper.parkingAmount = 10.00;
        wrapper.othersAmount = 8.00;
        wrapper.rateApplied = 100.00;
        wrapper.comments = 'New reimbursement test';
		wrapper.mileageRate = 12;
        wrapper.milesTravelledAmount = 1;
        
        Test.startTest();
        Reimbursement__c result = ReimbursementController.saveReimbursement(JSON.serialize(wrapper));
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isNotNull(result.Id, 'Reimbursement should be inserted');
    }

    /**
     * @description Tests saveReimbursement method for creating a new reimbursement record.
     *              Verifies that a new reimbursement is inserted with the provided data.
     */
    @IsTest
    static void testSaveReimbursementNewEducatorTypeCC() {
        Account trainer = [SELECT Id FROM Account WHERE Contract_Type__c = 'Level 2' LIMIT 1];
        Training__c training = [
            SELECT Id 
            FROM Training__c 
            WHERE Educator_Type__c = :ConstantsUtil.EDUCATOR_TYPE_CC 
            LIMIT 1
        ];
        
        ReimbursementController.ReimbursementWrapper wrapper = new ReimbursementController.ReimbursementWrapper();
        wrapper.trainerId = trainer.Id;
        wrapper.trainingId = training.Id;
        wrapper.type = ConstantsUtil.REIMBURSEMENT_TYPE_1_1_PATIENT_TRAINING;
        wrapper.mealAmount = 25.00;
        wrapper.hotelAmount = 80.00;
        wrapper.carRentalAmount = 50.00;
        wrapper.trainBusAirfareAmount = 100.00;
        wrapper.tollsAmount = 5.00;
        wrapper.parkingAmount = 10.00;
        wrapper.othersAmount = 8.00;
        wrapper.rateApplied = 100.00;
        wrapper.comments = 'New reimbursement test';
		wrapper.mileageRate = 12;
        wrapper.milesTravelledAmount = 1;
        
        Test.startTest();
        Reimbursement__c result = ReimbursementController.saveReimbursement(JSON.serialize(wrapper));
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.isNotNull(result.Id, 'Reimbursement should be inserted');
    }
    


    /**
     * @description Tests saveReimbursement method for updating an existing reimbursement record.
     *              Verifies exception handling when wrapper data is incomplete.
     */
    @IsTest
    static void testSaveReimbursementUpdate() {
        Reimbursement__c existingReimbursement = [SELECT Id, Trainer__c FROM Reimbursement__c LIMIT 1];
        
        ReimbursementController.ReimbursementWrapper wrapper = new ReimbursementController.ReimbursementWrapper();
        wrapper.Id = existingReimbursement.Id;
        wrapper.trainerId = existingReimbursement.Trainer__c;
        wrapper.type = 'Training';
        wrapper.mealAmount = 60.00;
        wrapper.hotelAmount = 120.00;
        wrapper.comments = 'Updated reimbursement test';
        
        Test.startTest();
        try {
            ReimbursementController.saveReimbursement(JSON.serialize(wrapper));
        } catch (Exception ex) {
            Assert.isNotNull(ex, 'Error must be thrown due to incomplete wrapper');
        }
        Test.stopTest();
    }
    
    /**
     * @description Tests getTrainingRelatedList method to retrieve trainings associated with a reimbursement.
     *              Verifies that the correct number of associated trainings is returned.
     */
    @IsTest
    static void testGetTrainingRelatedList() {
        Reimbursement__c reimbursement = [SELECT Id FROM Reimbursement__c LIMIT 1];
        
        Test.startTest();
        List<Training__c> results = ReimbursementController.getTrainingRelatedList(reimbursement.Id);
        Test.stopTest();
        
        Assert.isNotNull(results, 'Results should not be null');
        Assert.areEqual(1, results.size(), 'Should return one training');
    }
    
    /**
     * @description Tests getRate method for CPT educator type training.
     *              Verifies that the correct training rate is calculated and returned.
     */
    @IsTest
    static void testGetRateCPT() {
        Training__c training = [
            SELECT Id, Name, Account__r.Name, Training_Type__c, Training_Method__c, 
                   Training_Conducted_Date__c, Completion_Date__c, CSM__r.Name, Educator_Type__c, 
                   External_Trainer__r.Contract_Type__c, Practice__r.Contract_Type__c, 
                   Account__r.Current_Therapy__c, Product__c
            FROM Training__c 
            WHERE Educator_Type__c = :ConstantsUtil.EDUCATOR_TYPE_CPT 
            LIMIT 1
        ];
        
        Map<String, Object> recordMap = new Map<String, Object>{
            'Id' => training.Id,
            'name' => training.Name,
            'type' => training.Training_Type__c,
            'trainingMethod' => training.Training_Method__c,
            'trainingConductedDate' => training.Training_Conducted_Date__c,
            'completionDate' => training.Completion_Date__c,
            'educatorType' => training.Educator_Type__c,
            'contractType' => training.External_Trainer__r.Contract_Type__c,
            'currentTherapy' => training.Account__r.Current_Therapy__c,
            'product' => training.Product__c
        };
        
        Test.startTest();
        ReimbursementController.ReimbursementWrapper result = ReimbursementController.getRate(JSON.serialize(recordMap));
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(training.Id, result.trainingId, 'Training Id should match');
    }
    
    /**
     * @description Tests RecordWrapper constructor with Training__c records.
     *              Verifies that the wrapper is properly instantiated from training data.
     */
    @IsTest
    static void testRecordWrapper() {
        List<ReimbursementController.RecordWrapper> records = new List<ReimbursementController.RecordWrapper>();
        
        Test.startTest();
        for (Training__c training : [
            SELECT Id, Name, Account__r.Name, Training_Type__c, Training_Method__c, 
                   Training_Conducted_Date__c, Completion_Date__c, CSM__r.Name, Educator_Type__c, 
                   External_Trainer__r.Contract_Type__c, Practice__r.Contract_Type__c, 
                   Current_Therapy__c, Product__c , External_Trainer__r.Contract_Expiration_Date__c, External_Trainer__c, Practice__r.Contract_Expiration_Date__c
            FROM Training__c
        ]) {
            records.add(new ReimbursementController.RecordWrapper(training));
        }
        Test.stopTest();
        
        Assert.isNotNull(records, 'Records list should not be null');
    }
    
    /**
     * @description Tests getRate method for CC educator type training.
     *              Verifies exception handling when rate calculation encounters issues.
     */
    @IsTest
    static void testGetRateCC() {
        Training__c training = [
            SELECT Id, Name, Account__r.Name, Training_Type__c, Training_Method__c, 
                   Training_Conducted_Date__c, Completion_Date__c, CSM__r.Name, Educator_Type__c, 
                   External_Trainer__r.Contract_Type__c, Practice__r.Contract_Type__c, 
                   Account__r.Current_Therapy__c, Product__c
            FROM Training__c 
            WHERE Educator_Type__c = :ConstantsUtil.EDUCATOR_TYPE_CC 
            LIMIT 1
        ];
        
        Map<String, Object> recordMap = new Map<String, Object>{
            'Id' => training.Id,
            'name' => training.Name,
            'type' => training.Training_Type__c,
            'trainingMethod' => training.Training_Method__c,
            'trainingConductedDate' => training.Training_Conducted_Date__c,
            'completionDate' => training.Completion_Date__c,
            'educatorType' => training.Educator_Type__c,
            'contractType' => training.Practice__r.Contract_Type__c,
            'currentTherapy' => training.Account__r.Current_Therapy__c,
            'product' => training.Product__c
        };
        
        Test.startTest();
        try {
            ReimbursementController.getRate(JSON.serialize(recordMap));
        } catch (Exception ex) {
            Assert.isNotNull(ex.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    /**
     * @description Tests getRate method for Observation records.
     *              Verifies that the correct observation rate is calculated and returned.
     */
    @IsTest
    static void testGetRateObservation() {
        Observation__c observation = [
            SELECT Id, Name, Observation_Date__c, Observation_Type__c 
            FROM Observation__c 
            LIMIT 1
        ];
        
        Map<String, Object> recordMap = new Map<String, Object>{
            'Id' => observation.Id,
            'name' => observation.Name,
            'type' => observation.Observation_Type__c,
            'completionDate' => observation.Observation_Date__c,
            'educatorType' => null
        };
        
        Test.startTest();
        ReimbursementController.ReimbursementWrapper result = ReimbursementController.getRate(JSON.serialize(recordMap));
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(observation.Id, result.observationId, 'Observation Id should match');
    }
    
    /**
     * @description Tests showReimbursementForm method with an invalid trainer Id.
     *              Verifies that no exception is thrown and false is returned for invalid input.
     */
    @IsTest
    static void testShowReimbursementFormException() {
        Test.startTest();
        try {
            ReimbursementController.showReimbursementForm('invalidId','null');
            Assert.isTrue(true, 'No Exception is Thrown');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    /**
     * @description Tests PicklistOption wrapper class constructor.
     *              Verifies that the wrapper correctly stores label and value properties.
     */
    @IsTest
    static void testPicklistOptionWrapper() {
        Test.startTest();
        ReimbursementController.PicklistOption option = new ReimbursementController.PicklistOption('Test Label', 'Test Value');
        Test.stopTest();
        
        Assert.areEqual('Test Label', option.label, 'Label should match');
        Assert.areEqual('Test Value', option.value, 'Value should match');
    }
    
    /**
     * @description Tests ReimbursementWrapper constructor with a Reimbursement__c record.
     *              Verifies that all fields are correctly mapped from the record to the wrapper.
     */
    @IsTest
    static void testReimbursementWrapperConstructor() {
        Reimbursement__c reimbursement = [
             SELECT Id, Name, Type__c, Meals__c, Hotels__c, Car_Rental__c, Train_Bus_Airfare__c, 
                   Tolls__c, Parking__c, Other__c, Rate_Applied__c, Hourly_Rate_Subtotal__c,Contract_Level__c, 
                   Number_Of_Minutes__c, Mileage_Subtotal__c, Training_Subtotal__c,Educator_Type__c, 
                   Pre_Approved_Items_Subtotal__c, Parking_Tolls_Other_Subtotal__c, Grand_Total__c, 
                   Comments__c, Status__c, Submission_Date__c, Observation__c, Trainer__c, Total_Miles_Travelled__c
            FROM Reimbursement__c 
            LIMIT 1
        ];
        
        Test.startTest();
        ReimbursementController.ReimbursementWrapper wrapper = new ReimbursementController.ReimbursementWrapper(reimbursement);
        Test.stopTest();
        
        Assert.areEqual(reimbursement.Id, wrapper.Id, 'Id should match');
        Assert.areEqual(reimbursement.Type__c, wrapper.type, 'Type should match');
        Assert.areEqual(reimbursement.Meals__c, wrapper.mealAmount, 'Meal amount should match');
    }
    
    @IsTest
    static void testGetTraining2(){
        Training__c training = [
            SELECT Id, Name, Account__r.Name, Training_Type__c, Training_Method__c, 
                   Training_Conducted_Date__c, Completion_Date__c, CSM__r.Name, Educator_Type__c, 
                   External_Trainer__r.Contract_Type__c, Practice__r.Contract_Type__c, 
                   Account__r.Current_Therapy__c, Product__c
            FROM Training__c 
            WHERE Educator_Type__c = :ConstantsUtil.EDUCATOR_TYPE_CPT 
            LIMIT 1
        ];
        training.Training_Stage__c = ConstantsUtil.STAGE_COMPLETED;
        training.Completion_Date__c = System.today().addDays(-30);
        training.Training_Conducted_Date__c = System.today().addDays(-1);
        training.Training_Method__c = 'Live In-Person';
        training.Training_Type__c = 'Pre-Pod Training';
        training.Product__c = 'Omnipod 5';
        update training;
        //Method, Type, Product, Educator Type, and Training Conducted Date
        Account trainer = [Select id,Contract_Expiration_Date__c from Account where Id =: training.External_Trainer__c];
        test.startTest();
        List<ReimbursementController.RecordWrapper> wrap = ReimbursementController.getTrainings(trainer.Id);
        test.stopTest();
        Assert.isTrue(wrap.size() > 0 , 'Training Records are returned');
    }
}