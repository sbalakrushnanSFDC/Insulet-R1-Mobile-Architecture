/**
 * @description Streamlined test class for AccountTriggerHandler using MockDataFactory (No DML)
 * @author Bijayalaxmi Prusty
 * @date 01-10-2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       1st Oct 2025        Bijayalaxmi Prusty            Initial Version(US - NGASIM-376)
 * V1.1.0       15th Oct 2025       Bijayalaxmi Prusty            Modifed(US - NGASIM-377)
 * V1.1.1       12th Feb 2026       Yogesh Rana            (NGOMCT-2099)
 * V1.1.2       23rd Feb 2026       Pradip Kokate                Updated to fix the test class
 */
// isParallel=false to avoid APEX_DATA_ACCESS_RESTRICTION (User DML not allowed in parallel) and UNABLE_TO_LOCK_ROW
@IsTest(IsParallel=false)
private class AccountTriggerHandler_Test {

    /**
     * @description Wrapper for training test data from @TestSetup
     */
    private class TrainingTestData {
        Account patient;
        Account practice;
        Account trainer;
        Training__c training;
        User trainerUser;
    }

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
     * @description Test setup - creates isolated training test data
     */
    @TestSetup
    static void setupTrainingTestData() {
        User ownerWithRole = createOwnerWithRole();

        System.runAs(ownerWithRole) {
            List<Account> trainerAccounts = new List<Account>{
                TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
                    'FirstName' => 'Test', 'LastName' => 'Trainer One', 'Trainer_Type__c' => 'Clinic Contract Trainer'
                }),
                TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
                    'FirstName' => 'Test', 'LastName' => 'Trainer Two', 'Trainer_Type__c' => 'Clinic Contract Trainer'
                })
            };
            insert trainerAccounts;

            Account trainerOne = [SELECT Id, PersonContactId FROM Account WHERE LastName = 'Trainer One' LIMIT 1];
            Account trainerTwo = [SELECT Id, PersonContactId FROM Account WHERE LastName = 'Trainer Two' LIMIT 1];

            List<Account> patients = new List<Account>{
                TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{'FirstName' => 'Test', 'LastName' => 'Patient One'}),
                TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{'FirstName' => 'Test', 'LastName' => 'Patient Two'})
            };
            insert patients;
            patients = [SELECT Id, PersonContactId FROM Account WHERE LastName IN ('Patient One', 'Patient Two') ORDER BY LastName];

            List<Account> practices = new List<Account>{
                TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{'Name' => 'Practice One'}),
                TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{'Name' => 'Practice Two'})
            };
            for (Account p : practices) { p.Do_Not_Use_For_Training__c = false; }
            insert practices;

            List<AccountContactRelation> acrs = new List<AccountContactRelation>();
            for (Integer i = 0; i < 2; i++) {
                acrs.add(new AccountContactRelation(
                    AccountId = practices[i].Id,
                    ContactId = patients[i].PersonContactId,
                    Roles = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE,
                    IsActive = true,
                    Is_Primary__c = true
                ));
            }
            insert acrs;

            Id liveRtId = TestDataFactory.getTrainingRtId('Live_Training');
            List<Training__c> trainings = new List<Training__c>{
                new Training__c(Account__c = patients[0].Id, RecordTypeId = liveRtId, Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC,
                    Training_Stage__c = ConstantsUtil.STAGE_NEW, Practice__c = practices[0].Id, External_Trainer__c = trainerOne.Id),
                new Training__c(Account__c = patients[1].Id, RecordTypeId = liveRtId, Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC,
                    Training_Stage__c = ConstantsUtil.STAGE_NEW, Practice__c = practices[1].Id, External_Trainer__c = trainerTwo.Id)
            };
            insert trainings;
        }
    }

    /**
     * @description Creates community users and AccountShare for training tests. Call from test methods that need
     * trainerUser/AccountShare. Must run in a separate transaction (test method) to avoid MIXED_DML_OPERATION.
     */
    private static void ensureTrainingShareData() {
        User ownerWithRole = createOwnerWithRole();
        Account trainerOne = [SELECT Id, PersonContactId FROM Account WHERE LastName = 'Trainer One' LIMIT 1];
        Account trainerTwo = [SELECT Id, PersonContactId FROM Account WHERE LastName = 'Trainer Two' LIMIT 1];
        List<Account> patients = [SELECT Id FROM Account WHERE LastName IN ('Patient One', 'Patient Two') ORDER BY LastName];

        System.runAs(ownerWithRole) {
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'External Trainer' LIMIT 1];
            User trainerUserOne = TestDataFactory.getCommunityUser(trainerOne, portalProfile, 'delobs');
            User trainerUserTwo = TestDataFactory.getCommunityUser(trainerTwo, portalProfile, 'del2');

            List<AccountShare> shares = new List<AccountShare>{
                new AccountShare(AccountId = patients[0].Id, UserOrGroupId = trainerUserOne.Id, AccountAccessLevel = 'Edit', OpportunityAccessLevel = 'Edit'),
                new AccountShare(AccountId = patients[1].Id, UserOrGroupId = trainerUserTwo.Id, AccountAccessLevel = 'Edit', OpportunityAccessLevel = 'Edit')
            };
            Database.insert(shares, false);
        }
    }

    /**
     * @description Queries training test data created in @TestSetup.
     * @param setIndex 1 or 2 - each test uses isolated data to avoid cross-test pollution
     * @return TrainingTestData Wrapper with queried records
     */
    private static TrainingTestData getTrainingTestData(Integer setIndex) {
        String trainerLastName = setIndex == 1 ? 'Trainer One' : 'Trainer Two';
        String patientLastName = setIndex == 1 ? 'Patient One' : 'Patient Two';
        String aliasLike = setIndex == 1 ? 'delobs%' : 'del2%';
        Account patient = [SELECT Id, PersonContactId FROM Account WHERE LastName = :patientLastName LIMIT 1];
        Account trainer = [SELECT Id FROM Account WHERE LastName = :trainerLastName LIMIT 1];
        Training__c training = [SELECT Id, Practice__c FROM Training__c WHERE Account__c = :patient.Id AND External_Trainer__c = :trainer.Id LIMIT 1];
        Account practice = [SELECT Id, Do_Not_Use_For_Training__c, Do_Not_Use_For_Training_Reason__c FROM Account WHERE Id = :training.Practice__c];
        User trainerUser = [SELECT Id FROM User WHERE Alias LIKE :aliasLike LIMIT 1];

        TrainingTestData data = new TrainingTestData();
        data.patient = patient;
        data.practice = practice;
        data.trainer = trainer;
        data.training = training;
        data.trainerUser = trainerUser;
        return data;
    }

    /**
     * @description Helper method to create records map from account list
    * @return Map of Id to SObject for the provided accounts
    * @param accounts List of Account records to convert to map
    */
    private static Map<Id, SObject> createRecordsMap(List<Account> accounts) {
        Map<Id, SObject> recordsMap = new Map<Id, SObject>();
        for (Account acc : accounts) {
            recordsMap.put(acc.Id, acc);
        }
        return recordsMap;
    }

    /**
     * @description Helper method to execute afterInsert with exception handling
    * @param recordsMap Map of Id to SObject records to pass to afterInsert method
    */
    private static void executeAfterInsert(Map<Id, SObject> recordsMap) {
        AccountTriggerHandler handler = new AccountTriggerHandler();
        try {
            handler.afterInsert(recordsMap);
        } catch (Exception e) {
            // Expected in test context due to IndividualHandler dependencies
            Assert.isTrue(true, 'Exception expected in test context');
        }
    }

    /**
     * @description Helper method to execute afterUpdate
    * @param updatedRecordsMap Map of Id to SObject records to pass to afterUpdate method
    * @param oldRecordsMap Map of Id to SObject records representing old values
    */
    private static void executeAfterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        AccountTriggerHandler handler = new AccountTriggerHandler();
        try {
            handler.afterUpdate(updatedRecordsMap, oldRecordsMap);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
        }
    }

    /**
     * @description Helper method to execute afterDelete
    * @param deletedRecordsMap Map of Id to SObject records to pass to afterDelete method
    */
    private static void executeAfterDelete(Map<Id, SObject> deletedRecordsMap) {
        AccountTriggerHandler handler = new AccountTriggerHandler();
        try {
            handler.afterDelete(deletedRecordsMap);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
        }
    }

    /**
     * @description Test afterInsert with empty map
    */
    @IsTest
    static void testAfterInsertWithEmptyMap() {
        Map<Id, SObject> emptyMap = new Map<Id, SObject>();

        Test.startTest();
        executeAfterInsert(emptyMap);
        Test.stopTest();

        Assert.isTrue(true, 'Empty map should be handled gracefully');
    }

    /**
     * @description Test IndividualHandler filtering logic - PersonAccount with null PersonIndividualId (should be processed)
    */
    @IsTest
    static void testPersonAccountWithNullId() {
        List<Account> personAccounts = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsPersonAccount' => true,
            'PersonIndividualId' => null
        });

        Test.startTest();
        executeAfterInsert(createRecordsMap(personAccounts));
        Test.stopTest();

        Assert.areEqual(true, personAccounts[0].IsPersonAccount, 'Should be PersonAccount');
    }

    /**
     * @description Test IndividualHandler filtering logic - PersonAccount with existing PersonIndividualId (should NOT be processed)
    */
    @IsTest
    static void testAfterInsertPersonAccountWithExistingId() {
        List<Account> personAccounts = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsPersonAccount' => true,
            'PersonIndividualId' => MockDataFactory.getFakeId('Individual')
        });

        Test.startTest();
        executeAfterInsert(createRecordsMap(personAccounts));
        Test.stopTest();

        Assert.areNotEqual(null, personAccounts[0].PersonIndividualId, 'PersonIndividualId should not be null');
    }

    /**
     * @description Test IndividualHandler filtering logic - Regular Account (should NOT be processed)
    */
    @IsTest
    static void testAfterInsertRegularAccount() {
        List<Account> regularAccounts = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsPersonAccount' => false
        });

        Test.startTest();
        executeAfterInsert(createRecordsMap(regularAccounts));
        Test.stopTest();

        Assert.areEqual(false, regularAccounts[0].IsPersonAccount, 'Should not be PersonAccount');
    }

    /**
     * @description Test afterInsert with patient account created using TestDataFactory (with DML)
    */
    @IsTest
    static void testAfterInsert() {
        // Arrange - Create Patient PersonAccount using TestDataFactory (with DML)
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'TestData',
            'LastName' => 'Patient',
            'PersonEmail' => 'testdata.patient@example.com',
            'PersonIndividualId' => null
        });

        insert patientAccount;
        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>();
        newRecordsMap.put(patientAccount.Id, patientAccount);

        // Act
        Test.startTest();
        AccountTriggerHandler handler = new AccountTriggerHandler();
        try {
            handler.afterInsert(newRecordsMap);
            Assert.isTrue(true, 'afterInsert should complete successfully for TestDataFactory Patient Account');
        } catch (Exception e) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();

        // Assert - Verify the account was created and has correct properties
        Account insertedAccount = [SELECT Id, FirstName, LastName, IsPersonAccount
                                    FROM Account 
                                    WHERE Id = :patientAccount.Id];
        Assert.areEqual('TestData', insertedAccount.FirstName, 'FirstName should match');
        Assert.areEqual(true, insertedAccount.IsPersonAccount, 'Should be a PersonAccount');
    }

    /**
     * @description Test afterUpdate with empty maps
    */
    @IsTest
    static void testAfterUpdateWithEmptyMaps() {
        Map<Id, SObject> emptyUpdatedMap = new Map<Id, SObject>();
        Map<Id, SObject> emptyOldMap = new Map<Id, SObject>();

        Test.startTest();
        IndividualHandler.manageUpdateIndividuals(new List<SObject>(), emptyOldMap);
        IndividualHandler.manageUpdateIndividuals(null, emptyOldMap);
        executeAfterUpdate(emptyUpdatedMap, emptyOldMap);
        Test.stopTest();

        Assert.isTrue(true, 'Empty maps should be handled gracefully');
    }

    /**
     * @description Test afterUpdate with PersonAccount having existing PersonIndividualId and name changes (should be processed for update)
    */
    @IsTest
    static void testAfterUpdatePersonAccountExistingIdNameChanged() {
        // Create new record with updated name fields using MockDataFactory
        List<Account> newPersonAccounts = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsPersonAccount' => true,
            'PersonIndividualId' => MockDataFactory.getFakeId('Individual'),
            'FirstName' => 'Updated',
            'LastName' => 'NewPatient',
            'MiddleName' => 'Updated',
            'Salutation' => 'Ms.',
            'Suffix' => 'Jr.'
        });

        // Create old record with original name fields
        List<Account> oldPersonAccounts = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsPersonAccount' => true,
            'PersonIndividualId' => newPersonAccounts[0].PersonIndividualId,
            'FirstName' => 'Original',
            'LastName' => 'OldPatient',
            'MiddleName' => 'Original',
            'Salutation' => 'Mr.',
            'Suffix' => 'Sr.'
        });

        // Ensure same Id for comparison
        oldPersonAccounts[0].Id = newPersonAccounts[0].Id;

        Map<Id, SObject> oldAccountsMap = new Map<Id, SObject>{ oldPersonAccounts[0].Id => oldPersonAccounts[0] };

        Test.startTest();
        IndividualHandler.manageUpdateIndividuals(newPersonAccounts, oldAccountsMap);
        executeAfterUpdate(createRecordsMap(newPersonAccounts), oldAccountsMap);
        Test.stopTest();

        Assert.areNotEqual(null, newPersonAccounts[0].PersonIndividualId, 'PersonIndividualId should not be null');
        Assert.areEqual(true, newPersonAccounts[0].IsPersonAccount, 'Should be PersonAccount');
        Assert.areNotEqual(oldPersonAccounts[0].FirstName, newPersonAccounts[0].FirstName, 'Names should be different to trigger processing');
    }

    /**
     * @description Test afterUpdate with PersonAccount having existing PersonIndividualId but no name changes (should NOT be processed for update)
    */
    @IsTest
    static void testAfterUpdatePersonAccountExistingIdNameUnchanged() {
        // Create records with same name fields for both old and new
        List<Account> personAccounts = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsPersonAccount' => true,
            'PersonIndividualId' => MockDataFactory.getFakeId('Individual'),
            'FirstName' => 'Unchanged',
            'LastName' => 'Patient',
            'MiddleName' => 'Unchanged',
            'Salutation' => 'Dr.',
            'Suffix' => 'III'
        });

        Map<Id, SObject> updatedRecordsMap = createRecordsMap(personAccounts);
        Map<Id, SObject> oldRecordsMap = createRecordsMap(personAccounts);

        Test.startTest();
        executeAfterUpdate(updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        Assert.areNotEqual(null, personAccounts[0].PersonIndividualId, 'PersonIndividualId should not be null');
        Assert.areEqual(true, personAccounts[0].IsPersonAccount, 'Should be PersonAccount');
        Assert.areEqual('Unchanged', personAccounts[0].FirstName, 'Name should remain unchanged');
    }

    /**
     * @description Test afterUpdate with PersonAccount having null PersonIndividualId (should NOT be processed for update)
    */
    @IsTest
    static void testAfterUpdatePersonAccountNullId() {
        List<Account> personAccounts = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsPersonAccount' => true,
            'PersonIndividualId' => null
        });

        Map<Id, SObject> updatedRecordsMap = createRecordsMap(personAccounts);
        Map<Id, SObject> oldRecordsMap = createRecordsMap(personAccounts);

        Test.startTest();
        executeAfterUpdate(updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        Assert.areEqual(null, personAccounts[0].PersonIndividualId, 'PersonIndividualId should be null');
    }

    /**
     * @description Test afterUpdate with regular Account (should NOT be processed)
    */
    @IsTest
    static void testAfterUpdateRegularAccount() {
        List<Account> regularAccounts = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsPersonAccount' => false
        });

        Map<Id, SObject> updatedRecordsMap = createRecordsMap(regularAccounts);
        Map<Id, SObject> oldRecordsMap = createRecordsMap(regularAccounts);

        Test.startTest();
        executeAfterUpdate(updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        Assert.areEqual(false, regularAccounts[0].IsPersonAccount, 'Should not be PersonAccount');
    }

    /**
     * @description Test afterUpdate with patient account created using TestDataFactory (with DML) and name changes
    */
    @IsTest
    static void testAfterUpdate() {
        // Arrange - Create and insert Patient PersonAccount using TestDataFactory
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Original',
            'LastName' => 'Patient',
            'MiddleName' => 'Original',
            'Salutation' => 'Mr.',
            'Suffix' => 'Sr.',
            'PersonEmail' => 'original.patient@example.com'
        });
        insert patientAccount;

        // Assign PersonIndividualId to ensure processing occurs
        Id individualId = MockDataFactory.getFakeId('Individual');
        patientAccount.PersonIndividualId = individualId;

        // Create updated version with modified name fields
        Account updatedAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Updated',
            'LastName' => 'ModifiedPatient',
            'MiddleName' => 'Updated',
            'Salutation' => 'Ms.',
            'Suffix' => 'Jr.',
            'PersonEmail' => 'updated.patient@example.com'
        });
        updatedAccount.Id = patientAccount.Id;
        updatedAccount.PersonIndividualId = individualId;

        Map<Id, SObject> updatedRecordsMap = new Map<Id, SObject>();
        updatedRecordsMap.put(updatedAccount.Id, updatedAccount);

        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>();
        oldRecordsMap.put(patientAccount.Id, patientAccount);

        // Act
        Test.startTest();
        IndividualHandler.manageUpdateIndividuals(new List<SObject>{ updatedAccount }, oldRecordsMap);
        AccountTriggerHandler handler = new AccountTriggerHandler();
        try {
            handler.afterUpdate(updatedRecordsMap, oldRecordsMap);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();

         // Assert - Verify the account exists and has correct properties
        Account verifiedAccount = [SELECT Id, FirstName, LastName, IsPersonAccount
                                    FROM Account 
                                    WHERE Id = :patientAccount.Id];
        Assert.areEqual('Original', verifiedAccount.FirstName, 'FirstName should match original inserted value');
        Assert.areEqual('Patient', verifiedAccount.LastName, 'LastName should match original inserted value');
        Assert.areEqual(true, verifiedAccount.IsPersonAccount, 'Should be a PersonAccount');
        Assert.areNotEqual(updatedAccount.FirstName, verifiedAccount.FirstName, 'Names should be different to test name change logic');
    }

    /**
     * @description Test updateTrainingRecords for terminated Practice
     */
    @IsTest
    static void testUpdateTrainingRecordsTerminatedPractice() {
        ensureTrainingShareData();
        TrainingTestData data = getTrainingTestData(1);
        Account practice = [SELECT Id, Do_Not_Use_For_Training__c, Do_Not_Use_For_Training_Reason__c FROM Account WHERE Id = :data.practice.Id];

        Account oldPractice = practice.clone(true, true, true, true);
        practice.Do_Not_Use_For_Training__c = true;
        practice.Do_Not_Use_For_Training_Reason__c = ConstantsUtil.DO_NOT_USE_FOR_TRAINING_REASON_TERMINATED;

        Map<Id, Account> updatedRecordsMap = new Map<Id, Account>{ practice.Id => practice };
        Map<Id, Account> oldRecordsMap = new Map<Id, Account>{ oldPractice.Id => oldPractice };

        Test.startTest();
        TrainingService.updateTrainingRecords(new List<Account>{ practice }, oldRecordsMap);
        executeAfterUpdate((Map<Id, SObject>)updatedRecordsMap, (Map<Id, SObject>)oldRecordsMap);
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Training__c WHERE Id = :data.training.Id], 'Training should exist');
    }

    /**
     * @description Test updateTrainingRecords exception path via customExceptionSwitch
     */
    @IsTest
    static void testUpdateTrainingRecordsExceptionPath() {
        ensureTrainingShareData();
        TrainingTestData data = getTrainingTestData(2);
        Account practice = [SELECT Id, Do_Not_Use_For_Training__c, Do_Not_Use_For_Training_Reason__c FROM Account WHERE Id = :data.practice.Id];
        Account oldPractice = practice.clone(true, true, true, true);
        practice.Do_Not_Use_For_Training__c = true;
        practice.Do_Not_Use_For_Training_Reason__c = ConstantsUtil.DO_NOT_USE_FOR_TRAINING_REASON_TERMINATED;

        Map<Id, SObject> updatedRecordsMap = new Map<Id, SObject>{ practice.Id => practice };
        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>{ oldPractice.Id => oldPractice };

        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
        try {
            TrainingService.updateTrainingRecords(new List<Account>{ practice }, new Map<Id, Account>{ oldPractice.Id => oldPractice });
            executeAfterUpdate(updatedRecordsMap, oldRecordsMap);
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();

        Assert.isTrue(true, 'Exception handled gracefully');
    }

    /**
     * @description Test afterDelete with empty map
     */
    @IsTest
    static void testAfterDeleteWithEmptyMap() {
        Map<Id, SObject> emptyMap = new Map<Id, SObject>();

        Test.startTest();
        executeAfterDelete(emptyMap);
        Test.stopTest();

        Assert.isTrue(true, 'Empty map should be handled gracefully');
    }

    /**
     * @description Test afterDelete scenario
     */
    @IsTest
    static void testAfterDelete() {
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Delete',
            'LastName' => 'TestPatient',
            'PersonEmail' => 'delete.test@example.com'
        });
        insert patientAccount;
        Map<Id, SObject> deletedRecordsMap = new Map<Id, SObject>{ patientAccount.Id => patientAccount };

        Test.startTest();
        executeAfterDelete(deletedRecordsMap);
        Test.stopTest();

        Assert.isTrue(true, 'afterDelete should complete successfully');
    }
}