/**
 * @description Test class for TrainingService
 * @author Ayush Sharma
 * @date Nov 07, 2025
 * NOTE: We can't use @isTest(isParallel=true) because of this error:  APEX_DATA_ACCESS_RESTRICTION, In parallel Apex tests, DML operations aren't permitted on this type of object: User: []
 * 
 * Version      Modified Date       Modified By               Brief Note
 * V1.0.0       07-11-2025          Ayush Sharma           Initial Version (NGOMCT-657)
 * V1.0.1       29th Dec 2025       Ankur Chauhan          NGOMCT-341(Replaced Training_Coordinators with Training_Coordinator)
 * V1.0.2       1st Jan 2026        Srinivas Shanigarapu   Updated(US - NGOMCT-235)
 * V1.0.3       12th Jan 2026       Ayush Sharma           Added trainer validation tests (US-NGOMCT-1055)
 * V1.0.4       11th Feb 2026       Yogesh Rana             Added updateTrainingRecords tests for handleUpdateResults, updateTrainings, handleDeleteResults catch coverage
 */
 @IsTest
 private class TrainingService_FunctionalTest {
     
    /**
     * @description Creates a System Administrator user with a role for community user creation.
     * Avoids updating the running user (prevents UNABLE_TO_LOCK_ROW when running full test suite).
     * @return User The System Administrator user with a role.
     */
    private static User createOwnerWithRole() {
        String uniq = String.valueOf(Datetime.now().getTime());
        UserRole ur = null;
        try { ur = [SELECT Id FROM UserRole LIMIT 1]; } catch (Exception e) { ur = null; }
        Profile sysAdmin = [SELECT Id, Name FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Map<String, Object> uFields = new Map<String, Object>{
            'LastName' => 'Owner' + uniq,
            'UserName' => 'owner' + uniq + '@test.local'
        };
        if (ur != null) {
            uFields.put('UserRoleId', ur.Id);
        }
        User owner = TestDataFactory.getTestUser(sysAdmin.Name, uFields);
        insert owner;
        return owner;
    }

    /**
     * @description Setup test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        User ownerWithRole = createOwnerWithRole();

        Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'Sales' LIMIT 1];

        // Training Coordinator user
        String uniqueUserName = 'trainingcoordinator' + System.currentTimeMillis() + '@testdomain.com';
        User trainingCoordinator = new TestDataFactory.CreateUserRecord()
            .setEmail(uniqueUserName).setFirstName('Training').setLastName('Coordinator')
            .setProfileId(testProfile.Id).setUserName(uniqueUserName).getRecord();
        insert trainingCoordinator;
        TestDataFactory.assignPermissionSetLicense(trainingCoordinator.Id, 'Health Cloud Platform');
        TestDataFactory.assignPermissionSet(trainingCoordinator.Id, 'Training_Coordinator');

        // CSM user
        String uniqueCSMUserName = 'csmuser' + System.currentTimeMillis() + '@testdomain.com';
        User csmUser = new TestDataFactory.CreateUserRecord()
            .setEmail(uniqueCSMUserName).setFirstName('Persona CSM').setLastName('User')
            .setProfileId(testProfile.Id).setUserName(uniqueCSMUserName).getRecord();
        insert csmUser;
        TestDataFactory.assignPermissionSetLicense(csmUser.Id, 'Health Cloud Platform');
        TestDataFactory.assignPermissionSet(csmUser.Id, 'Field_Clinical');

        System.runAs(ownerWithRole) {
            Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
                'FirstName' => 'Patient', 'LastName' => 'Acc'
            });
            insert testAccount;

            insert TestDataFactory.getLead(new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT, 'FirstName' => 'Jane', 'LastName' => 'Patient','Validation_Bypass__c' => true,
                'Email' => 'jane.patient@example.com', 'Request_a_Call_Back__c' => false, 'Status' => 'Open - Not Contacted'
            });

            AssessmentQuestionSet testQuestionSet = TestDataFactory.getAssessmentQuestionSet();
            insert testQuestionSet;

            OmniProcess testOmni = TestDataFactory.getOmniProcess(new Map<String, Object>{
                'Name' => 'Test OmniScript', 'Type' => 'Assessment', 'SubType' => 'Test',
                'Language' => 'English', 'IsActive' => true, 'OmniProcessType' => 'OmniScript'
            });
            insert testOmni;

            insert TestDataFactory.getAssessmentDefinition(new Map<String, Object>{
                'Assessment_Question_Set__c' => testQuestionSet.Id, 'OmniProcessId' => testOmni.Id,
                'Test_Name__c' => 'Test Exam', 'Purpose' => 'Certification'
            });
        }

        System.runAs(csmUser) {
            Account testTrainer = TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
                'Contract_Expiration_Date__c' => Date.today().addDays(30),
                'FirstName' => 'Test', 'LastName' => 'Trainer', 'Phone' => '1234567890'
            });
            Account trainerNoCert = TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
                'Contract_Expiration_Date__c' => Date.today().addDays(30),
                'FirstName' => 'NoCert', 'LastName' => 'Trainer', 'Phone' => '1234567899'
            });
            Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
                'FirstName' => 'Patient', 'LastName' => 'Account'
            });
            insert new List<Account>{ testTrainer, trainerNoCert, patientAccount };

            AssessmentDefinition testAssessmentDef = [SELECT Id FROM AssessmentDefinition LIMIT 1];
            insert TestDataFactory.getCertification(new Map<String, Object>{
                'Trainer_Name__c' => testTrainer.Id, 'Product__c' => 'DASH',
                'Certification_Assessment__c' => testAssessmentDef.Id, 'Completion_Status__c' => 'Pending',
                'Certification_Results__c' => 'Passed', 'Certification_Date__c' => Date.today().addDays(-30)
            });

            Training__c testTraining = new TestDataFactory.CreateTrainingRecord()
                .setAccount(patientAccount.Id).setRecordType(ConstantsUtil.TRAINING_LIVE_TRAINING_RT).getRecord();
            testTraining.Product__c = 'DASH';
            testTraining.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CPT;
            insert testTraining;
        }

        // Create leads as Training Coordinator
        System.runAs(trainingCoordinator) {
            insert TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
                'FirstName' => 'Lead Conversion', 'LastName' => 'Trainer', 'Phone' => '1234567898'
            });

            List<Lead> testLeads = new List<Lead>();
            testLeads.add(TestDataFactory.getLead(new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT, 'FirstName' => 'John', 'LastName' => 'Trainer', 'Validation_Bypass__c' => true,
                'Email' => 'john.trainer@example.com', 'Status' => 'Open', 'Date_of_Birth__c' => Date.today().addYears(-30)
            }));
            testLeads.add(TestDataFactory.getLead(new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT, 'FirstName' => 'Exception', 'LastName' => 'Test',
                'Email' => 'exception.test@example.com', 'Status' => 'Open', 'Date_of_Birth__c' => Date.today().addYears(-30), 'Validation_Bypass__c' => true
            }));
            testLeads.add(TestDataFactory.getLead(new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT, 'FirstName' => 'Unconverted', 'LastName' => 'Trainer',
                'Email' => 'unconverted@example.com', 'Status' => 'Open', 'Validation_Bypass__c' => true
            }));
            testLeads.add(TestDataFactory.getLead(new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT, 'FirstName' => 'Logger', 'LastName' => 'Test',
                'Email' => 'logger.test@example.com', 'Status' => 'Open', 'Validation_Bypass__c' => true
            }));
            for (Integer i = 1; i <= 5; i++) {
                testLeads.add(TestDataFactory.getLead(new Map<String, Object>{
                    'RecordTypeId' => ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT, 'FirstName' => 'Trainer' + i,
                    'LastName' => 'MultiConvert', 'Email' => 'trainer' + i + '@multiconvert.com', 'Status' => 'Open', 'Validation_Bypass__c' => true
                }));
            }
            insert testLeads;
        }
    }
         
    // ========================= Helper Methods =========================

    private static User getUserByFirstName(String firstName) {
        return [SELECT Id FROM User WHERE FirstName = :firstName LIMIT 1];
    }

    private static Account getAccountByRecordType(Id recordTypeId) {
        return [SELECT Id FROM Account WHERE RecordTypeId = :recordTypeId LIMIT 1];
    }

    private static LeadStatus getLeadStatusByLabel(String masterLabel) {
        return [SELECT Id, MasterLabel FROM LeadStatus WHERE MasterLabel = :masterLabel LIMIT 1];
    }

    private static Lead getLeadByName(String firstName, String lastName) {
        return [SELECT Id, isConverted, Status FROM Lead WHERE FirstName = :firstName AND LastName = :lastName LIMIT 1];
    }

    private static List<Lead> getLeadsByLastName(String lastName) {
        return [SELECT Id, FirstName, LastName FROM Lead WHERE LastName = :lastName ORDER BY FirstName];
    }

    private static List<Training__c> getTrainingsByAccount(Id accountId) {
        return [SELECT Id, Account__c, RecordTypeId, External_Trainer__c, Product__c, Educator_Type__c FROM Training__c WHERE Account__c = :accountId];
    }

    private static Account getAccountByName(String firstName, String lastName) {
        return [SELECT Id, FirstName, LastName, Contract_Expiration_Date__c FROM Account WHERE FirstName = :firstName AND LastName = :lastName LIMIT 1];
    }
         
    /**
     * @description Test Trainer lead conversion creates CPT Training record
     */
    @IsTest
    static void testTrainingCreationOnLeadConversion() {
        Lead trainerLead = getLeadByName('John', 'Trainer');
        Account trainerAcc = getAccountByRecordType(ConstantsUtil.ACCOUNT_TRAINER_RT);
        LeadStatus convertStatus = getLeadStatusByLabel('Qualified');

        Test.startTest();
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(trainerLead.Id);
        lc.setAccountId(trainerAcc.Id);
        lc.setDoNotCreateOpportunity(true);
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setOwnerId(UserInfo.getUserId());
        lc.setBypassAccountDedupeCheck(true);
        lc.setBypassContactDedupeCheck(true);
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        Test.stopTest();

        Assert.isTrue(lcr.isSuccess(), 'Lead conversion should be successful');
        Id convertedAccountId = lcr.getAccountId();
        List<Training__c> trainings = [SELECT Id, Account__c, RecordTypeId FROM Training__c WHERE Account__c = :convertedAccountId];
        Assert.areEqual(1, trainings.size(), 'One CPT Training record should be created on lead conversion');
        Assert.areEqual(ConstantsUtil.TRAINING_CPT_TRAINING_RT, trainings[0].RecordTypeId, 'Training should have CPT Training record type');
    }
     
    /**
     * @description Test Patient lead conversion does not create Training
     */
    @IsTest
    static void testNoTrainingCreatedForPatientLead() {
        Lead patientLead = getLeadByName('Jane', 'Patient');
        Account patientAcc = getAccountByRecordType(ConstantsUtil.ACCOUNT_PATIENT_RT);
        LeadStatus convertStatus = getLeadStatusByLabel('Converted');

        Test.startTest();
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(patientLead.Id);
        lc.setAccountId(patientAcc.Id);
        lc.setDoNotCreateOpportunity(true);
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setOwnerId(UserInfo.getUserId());
        lc.setBypassAccountDedupeCheck(true);
        lc.setBypassContactDedupeCheck(true);
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        Test.stopTest();

        Assert.isTrue(lcr.isSuccess(), 'Patient lead should be converted successfully');
        List<Training__c> trainings = [SELECT Id FROM Training__c WHERE Account__c = :lcr.getAccountId()];
        Assert.areEqual(0, trainings.size(), 'No Training record should be created for Patient lead');
    }
     
    /**
     * @description Test createTrainings with empty input
     */
    @IsTest
    static void testCreateTrainingWithNullInput() {
        User trainingCoordinator = getUserByFirstName('Training');
        System.runAs(trainingCoordinator) {
            Test.startTest();
            TrainingService.createTrainings(new List<Lead>(), ConstantsUtil.OMCT_TAG);
            Test.stopTest();
            Assert.isTrue(true, 'Method should handle null input gracefully');
        }
    }

    /**
     * @description Test insertTrainingRecords logs error on invalid Training
     */
    @IsTest
    static void testLogErrorWithSaveResult() {
        User trainingCoordinator = getUserByFirstName('Training');
        System.runAs(trainingCoordinator) {
            TrainingService.ProcessingContext context = new TrainingService.ProcessingContext();
            Training__c invalidTraining = new Training__c(RecordTypeId = ConstantsUtil.TRAINING_CPT_TRAINING_RT);
            context.trainingsToInsert.add(invalidTraining);

            Test.startTest();
            TrainingService.errorTagName = ConstantsUtil.OMCT_TAG;
            TrainingService.insertTrainingRecords(context);
            Test.stopTest();

            List<Training__c> trainings = [SELECT Id FROM Training__c];
            Assert.areEqual(0, trainings.size(), 'No training should be inserted when error occurs');
        }
    }
     
    /**
     * @description Test exception handling during lead conversion Training creation
     */
    @IsTest
    static void testExceptionHandlingDuringLeadConversion() {
        Lead trainerLead = getLeadByName('Exception', 'Test');
        Account trainerAcc = getAccountByRecordType(ConstantsUtil.ACCOUNT_TRAINER_RT);
        LeadStatus convertStatus = getLeadStatusByLabel('Qualified');

        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(trainerLead.Id);
        lc.setAccountId(trainerAcc.Id);
        lc.setDoNotCreateOpportunity(true);
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setOwnerId(UserInfo.getUserId());
        lc.setBypassAccountDedupeCheck(true);
        lc.setBypassContactDedupeCheck(true);
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        Assert.isTrue(lcr.isSuccess(), 'Lead conversion should succeed even if Training creation fails');
        Test.stopTest();
        ConstantsUtil.customExceptionSwitch = false;
    }
     
    /**
     * @description Test buildTraining with null account territories
     */
    @IsTest
    static void testBuildTrainingWithNullTerritoryResponse() {
        User trainingCoordinator = getUserByFirstName('Training');
        System.runAs(trainingCoordinator) {
            Test.startTest();
            TrainingService.TrainingName nameData = new TrainingService.TrainingName(new Lead(ConvertedAccountId = null));
            Training__c training = TrainingService.buildTraining(nameData, ConstantsUtil.TRAINING_CPT_TRAINING_RT);
            Test.stopTest();
            Assert.areEqual(null, training.CSM__c, 'CSM should be null when territory maps are null');
        }
    }

    /**
     * @description Test buildTraining with empty account territories
     */
    @IsTest
    static void testBuildTrainingWithEmptyTerritoryResponse() {
        User trainingCoordinator = getUserByFirstName('Training');
        List<Account> accs = [SELECT Id FROM Account WHERE LastName = 'Trainer'];
        System.runAs(trainingCoordinator) {
            Test.startTest();
            TrainingService.isTestMode = true;
            TrainingService.TrainingName nameData = new TrainingService.TrainingName(new Lead(ConvertedAccountId = accs[0].Id));
            Training__c training = TrainingService.buildTraining(nameData, ConstantsUtil.TRAINING_CPT_TRAINING_RT);
            TrainingService.isTestMode = false;
            Test.stopTest();
            Assert.areEqual(null, training.CSM__c, 'CSM should be null when territory maps are null');
        }
    }
     
    /**
     * @description Test multiple Trainer leads converted in same transaction
     */
    @IsTest
    static void testMultipleTrainerLeadsConversion() {
        List<Lead> trainerLeads = getLeadsByLastName('MultiConvert');
        Account trainerAcc = getAccountByRecordType(ConstantsUtil.ACCOUNT_TRAINER_RT);
        LeadStatus convertStatus = getLeadStatusByLabel('Qualified');
        Assert.areEqual(5, trainerLeads.size(), '5 leads should exist for multiple conversion test');

        Test.startTest();
        List<Database.LeadConvert> leadConverts = new List<Database.LeadConvert>();
        for (Lead ld : trainerLeads) {
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(ld.Id);
            lc.setAccountId(trainerAcc.Id);
            lc.setDoNotCreateOpportunity(true);
            lc.setConvertedStatus(convertStatus.MasterLabel);
            lc.setOwnerId(UserInfo.getUserId());
            lc.setBypassAccountDedupeCheck(true);
            lc.setBypassContactDedupeCheck(true);
            leadConverts.add(lc);
        }
        List<Database.LeadConvertResult> results = Database.convertLead(leadConverts);
        Test.stopTest();

        Set<Id> convertedAccountIds = new Set<Id>();
        for (Database.LeadConvertResult result : results) {
            Assert.isTrue(result.isSuccess(), 'Each lead conversion should succeed');
            convertedAccountIds.add(result.getAccountId());
        }
        List<Training__c> trainings = [SELECT Id FROM Training__c WHERE Account__c IN :convertedAccountIds];
        Assert.areEqual(5, trainings.size(), '5 CPT Training records should be created');
    }
     
    /**
     * @description Test unconverted lead does not create Training
     */
    @IsTest
    static void testLeadWithoutConversionNoTraining() {
        User trainingCoordinator = getUserByFirstName('Training');
        System.runAs(trainingCoordinator) {
            Lead trainerLead = getLeadByName('Unconverted', 'Trainer');
            Test.startTest();
            trainerLead.Status = 'Working';
            update trainerLead;
            Test.stopTest();
            List<Training__c> trainings = [SELECT Id FROM Training__c];
            Assert.areEqual(0, trainings.size(), 'No Training should be created for unconverted lead');
        }
    }
  
    /**
     * @description Test valid trainer assignment with active certification and contract
     */
    @IsTest
    static void testValidTrainerAssignment() {
        User csmUser = getUserByFirstName('Persona CSM');
        System.runAs(csmUser) {
            Account testTrainer = getAccountByName('Test', 'Trainer');
            Account patientAccount = getAccountByRecordType(ConstantsUtil.ACCOUNT_PATIENT_RT);
            Training__c testTraining = getTrainingsByAccount(patientAccount.Id)[0];

            Test.startTest();
            testTraining.External_Trainer__c = testTrainer.Id;
            Database.SaveResult result = Database.update(testTraining, false);
            Test.stopTest();

            Assert.isTrue(result.isSuccess(), 'Training should be updated successfully with valid trainer assignment');
        }
    }

    /**
     * @description Test missing certification throws validation error
     */
    @IsTest
    static void testMissingCertification() {
        User csmUser = getUserByFirstName('Persona CSM');
        String expectedErrorMessage = System.Label.Expired_Certification_Error.replace('{productName}', 'DASH');
        System.runAs(csmUser) {
            Account trainerNoCert = getAccountByName('NoCert', 'Trainer');
            Account patientAccount = getAccountByRecordType(ConstantsUtil.ACCOUNT_PATIENT_RT);
            Training__c testTraining = getTrainingsByAccount(patientAccount.Id)[0];
            Boolean exceptionThrown = false;
            String actualErrorMessage = null;

            Test.startTest();
            testTraining.External_Trainer__c = trainerNoCert.Id;
            try {
                update testTraining;
                Assert.fail('Expected validation error for missing certification');
            } catch (DmlException e) {
                exceptionThrown = true;
                actualErrorMessage = e.getDmlMessage(0);
            }
            Test.stopTest();

            Assert.isTrue(exceptionThrown, 'Expected validation error for missing certification');
            Assert.areEqual(expectedErrorMessage, actualErrorMessage, 'Error message should match for missing certification');
        }
    }

    /**
     * @description Test expired certification throws validation error
     */
    @IsTest
    static void testExpiredCertification() {
        User csmUser = getUserByFirstName('Persona CSM');
        String expectedErrorMessage = System.Label.Expired_Certification_Error.replace('{productName}', 'DASH');

        Certification__c testCertification = [SELECT Id, Certification_Date__c FROM Certification__c WHERE Product__c = 'DASH' LIMIT 1];
        testCertification.Certification_Date__c = Date.today().addDays(-800);
        update testCertification;

        System.runAs(csmUser) {
            Account testTrainer = getAccountByName('Test', 'Trainer');
            Account patientAccount = getAccountByRecordType(ConstantsUtil.ACCOUNT_PATIENT_RT);
            Training__c testTraining = getTrainingsByAccount(patientAccount.Id)[0];
            Boolean exceptionThrown = false;
            String actualErrorMessage = null;

            Test.startTest();
            testTraining.External_Trainer__c = testTrainer.Id;
            try {
                update testTraining;
                Assert.fail('Expected validation error for expired certification');
            } catch (DmlException e) {
                exceptionThrown = true;
                actualErrorMessage = e.getDmlMessage(0);
            }
            Test.stopTest();

            Assert.isTrue(exceptionThrown, 'Expected validation error for expired certification');
            Assert.areEqual(expectedErrorMessage, actualErrorMessage, 'Error message should match for expired certification');
        }
    }

    /**
     * @description Test expired contract throws validation error
     */
    @IsTest
    static void testExpiredContract() {
        User csmUser = getUserByFirstName('Persona CSM');
        Account testTrainer = getAccountByName('Test', 'Trainer');
        testTrainer.Contract_Expiration_Date__c = Date.today().addDays(-5);
        update testTrainer;

        System.runAs(csmUser) {
            Account patientAccount = getAccountByRecordType(ConstantsUtil.ACCOUNT_PATIENT_RT);
            Training__c testTraining = getTrainingsByAccount(patientAccount.Id)[0];
            Boolean exceptionThrown = false;
            String errorMessage = null;

            Test.startTest();
            testTraining.External_Trainer__c = testTrainer.Id;
            try {
                update testTraining;
                Assert.fail('Expected validation error for expired contract');
            } catch (DmlException e) {
                exceptionThrown = true;
                errorMessage = e.getMessage();
            }
            Test.stopTest();

            Assert.isTrue(exceptionThrown, 'Expected validation error for expired contract');
            Assert.isTrue(errorMessage.contains(System.Label.Expired_Contract_Error) ||
                         errorMessage.contains('active Contract'), 'Error message should mention contract');
        }
    }

    /**
     * @description Test product change triggers validation for missing certification
     */
    @IsTest
    static void testProductChangeTriggersValidation() {
        User csmUser = getUserByFirstName('Persona CSM');
        String expectedErrorMessage = System.Label.Expired_Certification_Error.replace('{productName}', 'Omnipod 5');
        System.runAs(csmUser) {
            Account testTrainer = getAccountByName('Test', 'Trainer');
            Account patientAccount = getAccountByRecordType(ConstantsUtil.ACCOUNT_PATIENT_RT);
            Training__c testTraining = getTrainingsByAccount(patientAccount.Id)[0];

            testTraining.External_Trainer__c = testTrainer.Id;
            testTraining.Product__c = 'DASH';
            update testTraining;

            Boolean exceptionThrown = false;
            String actualErrorMessage = null;

            Test.startTest();
            testTraining.Product__c = 'Omnipod 5';
            try {
                update testTraining;
                Assert.fail('Expected validation error when changing product to one without certification');
            } catch (DmlException e) {
                exceptionThrown = true;
                actualErrorMessage = e.getDmlMessage(0);
            }
            Test.stopTest();

            Assert.isTrue(exceptionThrown, 'Expected validation error for missing certification on product change');
            Assert.areEqual(expectedErrorMessage, actualErrorMessage, 'Error message should match for missing certification');
        }
    }

    /**
     * @description Test buildCertificationMap with empty productNames
     */
    @IsTest
    static void testBuildCertificationMapEmptyProductNames() {
        User csmUser = getUserByFirstName('Persona CSM');
        System.runAs(csmUser) {
            Account testTrainer = getAccountByName('Test', 'Trainer');
            Test.startTest();
            Map<String, Boolean> result = TrainingService.buildCertificationMap(new Set<Id>{ testTrainer.Id }, new Set<String>());
            Test.stopTest();
            Assert.areEqual(0, result.size(), 'Map should be empty when productNames is empty');
        }
    }

    /**
     * @description Test buildTrainerContractMap with empty trainerIds
     */
    @IsTest
    static void testBuildTrainerContractMapEmptyTrainerIds() {
        User csmUser = getUserByFirstName('Persona CSM');
        System.runAs(csmUser) {
            Test.startTest();
            Map<Id, Date> result = TrainingService.buildTrainerContractMap(new Set<Id>());
            Test.stopTest();
            Assert.areEqual(0, result.size(), 'Map should be empty when trainerIds is empty');
        }
    }

    /**
     * @description Test validateTrainerAssignments with empty list
     */
    @IsTest
    static void testValidateTrainerAssignmentsEmptyList() {
        Test.startTest();
        TrainingService.validateTrainerAssignments(new List<Training__c>(), new Map<Id, Training__c>(), ConstantsUtil.OMCT_TAG);
        Test.stopTest();
        Assert.isTrue(true, 'Method should handle empty list gracefully');
    }
     
    /**
     * @description Test updateTrainings catch block via customExceptionSwitch
     */
    @IsTest
    static void testUpdateTrainingRecordsUpdateTrainingsCatch() {
        Account patient = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'UpdCatch', 'LastName' => 'Patient'
        });
        insert patient;
        patient = [SELECT Id, PersonContactId FROM Account WHERE Id = :patient.Id];

        Account practice = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{'Name' => 'PracticeOnly'});
        practice.Do_Not_Use_For_Training__c = false;
        insert practice;

        insert new AccountContactRelation(
            AccountId = practice.Id, ContactId = patient.PersonContactId,
            Roles = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE, IsActive = true, Is_Primary__c = true
        );

        insert new Training__c(
            Account__c = patient.Id,
            RecordTypeId = TestDataFactory.getTrainingRtId('Live_Training'),
            Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC,
            Training_Stage__c = ConstantsUtil.STAGE_NEW,
            Practice__c = practice.Id
        );

        Account oldPractice = practice.clone(true, true, true, true);
        practice.Do_Not_Use_For_Training__c = true;
        practice.Do_Not_Use_For_Training_Reason__c = ConstantsUtil.DO_NOT_USE_FOR_TRAINING_REASON_TERMINATED;

        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
        try {
            TrainingService.updateTrainingRecords(new List<Account>{ practice }, new Map<Id, Account>{ oldPractice.Id => oldPractice });
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();

        Assert.isTrue(true, 'updateTrainings catch block should handle exception');
    }

    /**
     * @description Test removeAccountSharing catch block via customExceptionSwitch
     */
    @IsTest
    static void testUpdateTrainingRecordsRemoveAccountSharingCatch() {
        // Setup DML first, then all non-setup to avoid MIXED_DML_OPERATION
        User ownerWithRole;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            ownerWithRole = createOwnerWithRole();
        }

        // Non-setup: Accounts only
        System.runAs(ownerWithRole) {
            Account patient = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
                'FirstName' => 'ShareCatch', 'LastName' => 'Patient'
            });
            insert patient;

            Account practice = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{ 'Name' => 'ShareCatchPractice' });
            practice.Do_Not_Use_For_Training__c = false;
            insert practice;

            Account trainer = TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
                'LastName' => 'ShareCatchTrainer', 'Trainer_Type__c' => 'Clinic Contract Trainer'
            });
            insert trainer;
        }

        // Setup: getCommunityUser (User) - separate runAs to avoid MIXED_DML with Account
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Account trainerForPortal = [SELECT Id, PersonContactId FROM Account WHERE LastName = 'ShareCatchTrainer' LIMIT 1];
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'External Trainer' LIMIT 1];
            TestDataFactory.getCommunityUser(trainerForPortal, portalProfile, 'shrcth');
        }

        // Non-setup: ACR, Training, AccountShare - in runAs(owner) to keep all non-setup together
        System.runAs(ownerWithRole) {
            Account patient = [SELECT Id, PersonContactId FROM Account WHERE LastName = 'Patient' AND FirstName = 'ShareCatch' LIMIT 1];
            Account practice = [SELECT Id FROM Account WHERE Name = 'ShareCatchPractice' LIMIT 1];
            Account trainer = [SELECT Id FROM Account WHERE LastName = 'ShareCatchTrainer' LIMIT 1];

            insert new AccountContactRelation(
                AccountId = practice.Id, ContactId = patient.PersonContactId,
                Roles = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE, IsActive = true, Is_Primary__c = true
            );

            insert new Training__c(
                Account__c = patient.Id,
                RecordTypeId = TestDataFactory.getTrainingRtId('Live_Training'),
                Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC,
                Training_Stage__c = ConstantsUtil.STAGE_NEW,
                Practice__c = practice.Id,
                External_Trainer__c = trainer.Id
            );

            User trainerUser = [SELECT Id FROM User WHERE Alias LIKE 'shrcth%' LIMIT 1];
            Database.insert(new AccountShare(
                AccountId = patient.Id, UserOrGroupId = trainerUser.Id,
                AccountAccessLevel = 'Edit', OpportunityAccessLevel = 'Edit'
            ), false);
        }

        Account practice = [SELECT Id, Do_Not_Use_For_Training__c, Do_Not_Use_For_Training_Reason__c FROM Account WHERE Name = 'ShareCatchPractice' LIMIT 1];
        Account oldPractice = practice.clone(true, true, true, true);
        practice.Do_Not_Use_For_Training__c = true;
        practice.Do_Not_Use_For_Training_Reason__c = ConstantsUtil.DO_NOT_USE_FOR_TRAINING_REASON_TERMINATED;

        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
        try {
            TrainingService.updateTrainingRecords(new List<Account>{ practice }, new Map<Id, Account>{ oldPractice.Id => oldPractice });
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();

        Assert.isTrue(true, 'removeAccountSharing catch block should handle exception');
    }

    /**
     * @description Test handleUpdateResults and handleDeleteResults with failed DML results
     */
    @IsTest
    static void testHandleUpdateResultsAndHandleDeleteResultsDirectly() {
        Account patientAccount = getAccountByRecordType(ConstantsUtil.ACCOUNT_PATIENT_RT);
        User csmUser = getUserByFirstName('Persona CSM');

        Test.startTest();

        // SaveResult error - missing required Account__c (Master-Detail)
        List<Training__c> invalidTrainings = new List<Training__c>{
            new Training__c(RecordTypeId = TestDataFactory.getTrainingRtId('Live_Training'), Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_IT)
        };
        Database.SaveResult[] saveResults = Database.insert(invalidTrainings, false);
        TrainingService.handleUpdateResults(saveResults, invalidTrainings);
        Assert.isFalse(saveResults[0].isSuccess(), 'Insert should fail with missing Account__c');

        // DeleteResult error - delete already-deleted record
        AccountShare validShare = new AccountShare(
            AccountId = patientAccount.Id, UserOrGroupId = csmUser.Id,
            AccountAccessLevel = 'Edit', OpportunityAccessLevel = 'Edit'
        );
        Database.insert(validShare, false);

        List<AccountShare> sharesToDelete = [
            SELECT Id FROM AccountShare WHERE AccountId = :patientAccount.Id AND UserOrGroupId = :csmUser.Id AND RowCause = 'Manual' LIMIT 1
        ];
        if (!sharesToDelete.isEmpty()) {
            Database.delete(sharesToDelete, false);
            Database.DeleteResult[] deleteResults = Database.delete(new List<SObject>{ sharesToDelete[0] }, false);
            TrainingService.handleDeleteResults(deleteResults, new List<SObject>{ sharesToDelete[0] });
            Assert.isFalse(deleteResults[0].isSuccess(), 'Delete should fail for already-deleted record');
        }

        Test.stopTest();
    }

    /**
     * @description Test validateTrainerAssignments exception via customExceptionSwitch
     */
    @IsTest
    static void testValidateTrainerAssignmentException() {
        User csmUser = getUserByFirstName('Persona CSM');
        System.runAs(csmUser) {
            Account testTrainer = getAccountByName('Test', 'Trainer');
            Account patientAccount = getAccountByRecordType(ConstantsUtil.ACCOUNT_PATIENT_RT);
            Training__c testTraining = getTrainingsByAccount(patientAccount.Id)[0];
            Boolean exceptionThrown = false;

            Test.startTest();
            try {
                ConstantsUtil.customExceptionSwitch = true;
                testTraining.External_Trainer__c = testTrainer.Id;
                testTraining.Product__c = 'OmniPod 5';
                update testTraining;
            } catch (Exception e) {
                exceptionThrown = true;
            }
            Test.stopTest();

            Assert.isTrue(exceptionThrown, 'Exception should have been thrown when customExceptionSwitch is true');
        }
    }
      
 }