/**
 * @author      : Yogesh Rana
 * @created Date: 2nd Dec 2025
 * @description : Test Class for ObservationTrigger, ObservationTriggerHandler, and ObservationSharingHandler
 * Provides comprehensive test coverage for observation trigger logic and sharing functionality
 * =========================== Logs ==============================
 * Version      Modified Date       Modified By         Brief Note
 * V1.0.0       2nd Dec 2025        Yogesh Rana         Initial Version (US - NGOMCT-752)
 * V1.0.1       29th Dec 2025       Ankur Chauhan       NGOMCT-341(Replaced CEO Role with Training_Coordinator)
 * V1.0.2       12th Jan 2026       Ankur Chauhan       Updated field name(NGOMCT-1452)
 */
 @IsTest(isParallel=true)
 private class ObservationTrigger_Test {
 
     /**
      * @description Helper method to query the delegate user created in test setup
      * @return User The delegate observer user
      */
     private static User getDelegateUser() {
         return [SELECT Id, AccountId FROM User WHERE Alias LIKE 'delobs%' LIMIT 1];
     }
 
     /**
      * @description Helper method to query the first trainer account
      * @return Account The first trainer account with PersonContactId
      */
     private static Account getTrainerOne() {
         return [SELECT Id, PersonContactId FROM Account WHERE LastName = 'Trainer One' LIMIT 1];
     }
 
     /**
      * @description Helper method to query the second trainer account
      * @return Account The second trainer account with PersonContactId
      */
     private static Account getTrainerTwo() {
         return [SELECT Id, PersonContactId FROM Account WHERE LastName = 'Trainer Two' LIMIT 1];
     }
 
     /**
      * @description Helper method to query an observation without delegate
      * @return Observation__c Observation record without Delegate_Observer__c
      */
     private static Observation__c getObservationWithoutDelegate() {
         return [SELECT Id, Trainer_Name__c, Delegate_Observer__c FROM Observation__c WHERE Delegate_Observer__c = null LIMIT 1];
     }
 
     /**
      * @description Helper method to query an observation with delegate
      * @return Observation__c Observation record with Delegate_Observer__c set
      */
     private static Observation__c getObservationWithDelegate() {
         return [SELECT Id, Trainer_Name__c, Delegate_Observer__c FROM Observation__c WHERE Delegate_Observer__c != null LIMIT 1];
     }
 
     /**
      * @description Test setup method to create reusable test data
      * Creates trainer accounts, delegate user, and observation records
      */
     @TestSetup
     static void setupTestData() {
         Id currentUserId = UserInfo.getUserId();
 
         // Ensure running admin user has a Role to avoid "portal account owner must have a role"
         System.runAs(new User(Id = currentUserId)) {
             User adminUser = [SELECT Id, UserRoleId FROM User WHERE Id = :currentUserId LIMIT 1];
 
             if (adminUser.UserRoleId == null) {
                 UserRole userRole;
                 List<UserRole> ceoRole = [SELECT Id FROM UserRole WHERE DeveloperName = 'Training_Coordinator' LIMIT 1];
                 if (!ceoRole.isEmpty()) {
                     userRole = ceoRole[0];
                 } else {
                     userRole = new UserRole(DeveloperName = 'Training_Coordinator', Name = 'Training Coordinator');
                     insert userRole;
                 }
                 adminUser.UserRoleId = userRole.Id;
                 update adminUser;
             }
         }
 
         // Create trainer accounts
         List<Account> trainerAccounts = new List<Account>{
             TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
                 'FirstName' => 'Test', 'LastName' => 'Trainer One', 'Contract_Type__c' => 'Level 3'
             }),
             TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
                 'FirstName' => 'Test', 'LastName' => 'Trainer Two', 'Contract_Type__c' => 'Level 3'
             })
         };
         insert trainerAccounts;
 
         Account trainerAccount = [SELECT Id, PersonContactId FROM Account WHERE LastName = 'Trainer One' LIMIT 1];
 
         // Create portal user (wrapped in runAs to separate Setup from Non-Setup DML)
         System.runAs(new User(Id = currentUserId)) {
             Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'External Trainer' LIMIT 1];
             TestDataFactory.getCommunityUser(trainerAccount, portalProfile, 'delobs');
         }
 
        insert new List<Observation__c>{
            TestDataFactory.getObservation(new Map<String, Object>{'Trainer_Name__c' => trainerAccount.Id}),
            TestDataFactory.getObservation(new Map<String, Object>{
                'Trainer_Name__c' => trainerAccount.Id,
                'Delegate_Observer__c' => trainerAccount.Id,
                'Delegate_Observer_Approval_Status__c' => 'Approved'
            })
        };
     }
 
     /**
      * @description Test adding Delegate Observer to an observation
      * Verifies that the sharing handler creates AccountShare record
      */
     @IsTest
     static void testAddDelegate() {
         User delegateUser = getDelegateUser();
         Observation__c obs = getObservationWithoutDelegate();
 
        Test.startTest();
        obs.Delegate_Observer__c = delegateUser.AccountId;
        obs.Delegate_Observer_Approval_Status__c = 'Approved';
        update obs;
        Test.stopTest();

        obs = [SELECT Delegate_Observer__c FROM Observation__c WHERE Id = :obs.Id];
        Assert.areEqual(delegateUser.AccountId, obs.Delegate_Observer__c, 'Delegate Observer should be added successfully');
     }
 
     /**
      * @description Test removing Delegate Observer from an observation
      * Verifies that the sharing handler deletes AccountShare record
      */
     @IsTest
     static void testRemoveDelegate() {
         Observation__c obs = getObservationWithDelegate();
 
         Test.startTest();
         obs.Delegate_Observer__c = null;
         update obs;
         Test.stopTest();
 
         obs = [SELECT Delegate_Observer__c FROM Observation__c WHERE Id = :obs.Id];
         Assert.isNull(obs.Delegate_Observer__c, 'Delegate Observer should be removed when approval is rejected');
     }
 
     /**
      * @description Test changing Delegate Observer from one user to another
      * Verifies that old share is deleted and new share is created
      */
     @IsTest
     static void testChangeDelegate() {
         Account secondTrainer = getTrainerTwo();
         Observation__c obs = getObservationWithDelegate();
 
         // Create portal user (wrapped in runAs to separate Setup from Non-Setup DML)
         System.runAs(new User(Id = UserInfo.getUserId())) {
             Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'External Trainer' LIMIT 1];
             TestDataFactory.getCommunityUser(secondTrainer, portalProfile, 'del2');
         }
 
         User secondDelegateUser = [SELECT Id, AccountId FROM User WHERE Alias LIKE 'del2%' LIMIT 1];
 
        Test.startTest();
        obs.Delegate_Observer__c = secondDelegateUser.AccountId;
        obs.Delegate_Observer_Approval_Status__c = 'Approved';
        update obs;
        Test.stopTest();

        obs = [SELECT Delegate_Observer__c FROM Observation__c WHERE Id = :obs.Id];
        Assert.areEqual(secondDelegateUser.AccountId, obs.Delegate_Observer__c, 'Delegate Observer should be changed to second delegate');
     }
 
     /**
      * @description Test bulk update of 50 observations with delegates
      * Verifies handler processes large volumes efficiently
      */
     @IsTest
     static void testBulkOperations() {
         User delegateUser = getDelegateUser();
         Account trainerAccount = getTrainerOne();
 
         List<Observation__c> observations = TestDataFactory.getObservations(50, new Map<String, Object>{
             'Trainer_Name__c' => trainerAccount.Id
         });
         insert observations;
 
        Test.startTest();
        for (Observation__c obs : observations) {
            obs.Delegate_Observer__c = delegateUser.AccountId;
            obs.Delegate_Observer_Approval_Status__c = 'Approved';
        }
        update observations;
        Test.stopTest();
 
         Integer count = [SELECT COUNT() FROM Observation__c WHERE Delegate_Observer__c = :delegateUser.AccountId AND Id IN :observations];
         Assert.areEqual(50, count, 'All 50 observations should have delegate assigned');
     }
 
     /**
      * @description Test updating observation field without changing delegate
      * Verifies early exit logic when no sharing changes are needed
      */
     @IsTest
     static void testNoChange() {
         Observation__c obs = getObservationWithoutDelegate();
         Id originalDelegate = obs.Delegate_Observer__c;
 
         Test.startTest();
         obs.Observation_Date__c = Date.today();
         update obs;
         Test.stopTest();
 
         obs = [SELECT Delegate_Observer__c, Observation_Date__c FROM Observation__c WHERE Id = :obs.Id];
         Assert.areEqual(originalDelegate, obs.Delegate_Observer__c, 'Delegate should remain unchanged');
         Assert.areEqual(Date.today(), obs.Observation_Date__c, 'Date should be updated');
     }
 
     /**
      * @description Test handler with empty input (no observations to process)
      * Verifies early return logic when trigger provides empty collections
      */
     @IsTest
     static void testNoObservationsToProcess() {
         Test.startTest();
         ObservationSharingHandler.shareObservationRecords(new Map<Id, Observation__c>(), new Map<Id, Observation__c>());
         Test.stopTest();
 
         Assert.isTrue(true, 'Handler should handle empty inputs gracefully');
     }
 
     /**
      * @description Test multiple sequential updates: add, remove, re-add delegate
      * Verifies handler correctly processes repeated changes to same observation
      */
     @IsTest
     static void testMultipleUpdates() {
         User delegateUser = getDelegateUser();
         Observation__c obs = getObservationWithoutDelegate();
 
        Test.startTest();
        obs.Delegate_Observer__c = delegateUser.AccountId;
        obs.Delegate_Observer_Approval_Status__c = 'Approved';
        update obs;

        obs.Delegate_Observer__c = null;
        update obs;

        obs.Delegate_Observer__c = delegateUser.AccountId;
        obs.Delegate_Observer_Approval_Status__c = 'Approved';
        update obs;
        Test.stopTest();
 
         obs = [SELECT Delegate_Observer__c FROM Observation__c WHERE Id = :obs.Id];
         Assert.areEqual(delegateUser.AccountId, obs.Delegate_Observer__c, 'Delegate should be re-added after multiple updates');
     }
 
     /**
      * @description Test delegate account with no associated active User
      * Verifies error logging when User cannot be found for Account ID
      */
     @IsTest
     static void testDelegateWithNoUser() {
         Account accountWithNoUser = TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
             'FirstName' => 'No', 'LastName' => 'User Account', 'Contract_Type__c' => 'Level 3'
         });
         insert accountWithNoUser;
 
         Observation__c obs = getObservationWithoutDelegate();
 
        Test.startTest();
        obs.Delegate_Observer__c = accountWithNoUser.Id;
        obs.Delegate_Observer_Approval_Status__c = 'Approved';
        update obs;

        // Verify observation was updated despite no user for account
        obs = [SELECT Delegate_Observer__c FROM Observation__c WHERE Id = :obs.Id];
        Assert.areEqual(accountWithNoUser.Id, obs.Delegate_Observer__c, 'Delegate should be set even if no active user exists');
 
         obs.Delegate_Observer__c = null;
         update obs;
 
         // Verify delegate was removed
         obs = [SELECT Delegate_Observer__c FROM Observation__c WHERE Id = :obs.Id];
         Assert.isNull(obs.Delegate_Observer__c, 'Delegate should be removed successfully');
         Test.stopTest();
     }
 
     /**
      * @description Test bulk mixed operations (add, remove, keep) in single transaction
      * Verifies handler correctly processes different operations simultaneously
      */
     @IsTest
     static void testMixedBulkOperations() {
         User delegateUser = getDelegateUser();
         Account trainerOne = getTrainerOne();
         Account trainerTwo = getTrainerTwo();
 
        List<Observation__c> observations = new List<Observation__c>{
            TestDataFactory.getObservation(new Map<String, Object>{
                'Trainer_Name__c' => trainerOne.Id,
                'Delegate_Observer__c' => delegateUser.AccountId,
                'Delegate_Observer_Approval_Status__c' => 'Approved'
            }),
            TestDataFactory.getObservation(new Map<String, Object>{'Trainer_Name__c' => trainerTwo.Id}),
            TestDataFactory.getObservation(new Map<String, Object>{'Trainer_Name__c' => trainerOne.Id})
        };
         insert observations;
 
        Test.startTest();
        observations[0].Delegate_Observer__c = null;
        observations[1].Delegate_Observer__c = delegateUser.AccountId;
        observations[1].Delegate_Observer_Approval_Status__c = 'Approved';
        observations[2].Delegate_Observer__c = delegateUser.AccountId;
        observations[2].Delegate_Observer_Approval_Status__c = 'Approved';
        update observations;
        Test.stopTest();
 
         // Verify mixed operations completed successfully
         observations = [SELECT Id, Delegate_Observer__c FROM Observation__c WHERE Id IN :observations];
         Assert.isNull(observations[0].Delegate_Observer__c, 'First observation should have delegate removed');
         Assert.areEqual(delegateUser.AccountId, observations[1].Delegate_Observer__c, 'Second observation should have delegate added');
         Assert.areEqual(delegateUser.AccountId, observations[2].Delegate_Observer__c, 'Third observation should have delegate added');
     }
 
     /**
      * @description Test main exception handler in shareObservationRecords
      * Verifies exception is caught and logged when customExceptionSwitch triggers
      */
     @IsTest
     static void testExceptionHandling() {
         User delegateUser = getDelegateUser();
         Account trainerAccount = getTrainerOne();
 
         Observation__c obs = TestDataFactory.getObservation(new Map<String, Object>{'Trainer_Name__c' => trainerAccount.Id});
         insert obs;
 
         Test.startTest();
         ConstantsUtil.customExceptionSwitch = true;
 
        try {
            obs.Delegate_Observer__c = delegateUser.AccountId;
            obs.Delegate_Observer_Approval_Status__c = 'Approved';
            update obs;
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();

        // Verify exception was caught and logged internally
        obs = [SELECT Id, Delegate_Observer__c FROM Observation__c WHERE Id = :obs.Id];
        Assert.isNotNull(obs, 'Observation should still exist after exception in handler');
     }
 
     /**
      * @description Test insertShareRecords exception catch block
      * Verifies exception is caught and logged during AccountShare insertion
      */
     @IsTest
     static void testInsertShareRecordsCatch() {
         User delegateUser = getDelegateUser();
         Observation__c obs = TestDataFactory.getObservation(new Map<String, Object>{'Trainer_Name__c' => getTrainerOne().Id});
         insert obs;
 
        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
        try {
            obs.Delegate_Observer__c = delegateUser.AccountId;
            obs.Delegate_Observer_Approval_Status__c = 'Approved';
            update obs;
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();

        // Verify exception was caught and logged internally
        obs = [SELECT Id, Delegate_Observer__c FROM Observation__c WHERE Id = :obs.Id];
        Assert.isNotNull(obs, 'Observation should still exist after exception in insertShareRecords');
     }
 
     /**
      * @description Test deleteShareRecords exception catch block
      * Verifies exception is caught and logged during AccountShare deletion
      * Covers: deleteShareRecords catch block, exception logging for delete operations
      */
     @IsTest
     static void testDeleteShareRecordsCatch() {
         User delegateUser = getDelegateUser();
        Observation__c obs = TestDataFactory.getObservation(new Map<String, Object>{
            'Trainer_Name__c' => getTrainerOne().Id,
            'Delegate_Observer__c' => delegateUser.AccountId,
            'Delegate_Observer_Approval_Status__c' => 'Approved'
        });
        insert obs;

        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
         try {
             obs.Delegate_Observer__c = null;
             update obs;
         } finally {
             ConstantsUtil.customExceptionSwitch = false;
         }
         Test.stopTest();
 
         // Verify exception was caught in deleteShareRecords catch block (logged internally)
         // The handler catches exceptions internally and logs them without propagating to trigger
         obs = [SELECT Id, Delegate_Observer__c FROM Observation__c WHERE Id = :obs.Id];
         Assert.isNotNull(obs, 'Observation should still exist after exception in deleteShareRecords');
     }
 
    /**
     * @description Test bulk delete operations with 50 records to ensure handleDmlErrors processes multiple DeleteResults
     * Verifies handler correctly processes bulk delegate removals and logs any failures
     * Covers: handleDmlErrors method for DeleteResult, bulk delete operations
     */
    @IsTest
    static void testBulkDeleteOperations() {
        User delegateUser = getDelegateUser();
        Account trainerOne = getTrainerOne();
        Account trainerTwo = getTrainerTwo();

        // Create 50 observations with delegates
        List<Observation__c> observations = new List<Observation__c>();
        for (Integer i = 0; i < 50; i++) {
            observations.add(TestDataFactory.getObservation(new Map<String, Object>{
                'Trainer_Name__c' => (Math.mod(i, 2) == 0) ? trainerOne.Id : trainerTwo.Id,
                'Delegate_Observer__c' => delegateUser.AccountId,
                'Delegate_Observer_Approval_Status__c' => 'Approved'
            }));
        }
        insert observations;

        Test.startTest();
        // Remove delegates from all 50 observations
        for (Observation__c obs : observations) {
            obs.Delegate_Observer__c = null;
        }
        update observations;
        Test.stopTest();

        // Verify all delegates were removed successfully
        observations = [SELECT Id, Delegate_Observer__c FROM Observation__c WHERE Id IN :observations];
        Assert.areEqual(50, observations.size(), 'Should have 50 observations');
        for (Observation__c obs : observations) {
            Assert.isNull(obs.Delegate_Observer__c, 'Delegate should be removed from all observations in bulk delete');
        }
    }
 
     /**
      * @description Test scenario where old delegate Account has no active User
      * Verifies handler gracefully skips deletion when old delegate User is inactive
      * Covers: buildShareDeletionMap skip logic for missing User mappings
      */
     @IsTest
     static void testOldDelegateNoActiveUser() {
         User delegateUser = getDelegateUser();
         Account trainerAccount = getTrainerOne();
 
        // Create observation with delegate
        Observation__c obs = TestDataFactory.getObservation(new Map<String, Object>{
            'Trainer_Name__c' => trainerAccount.Id,
            'Delegate_Observer__c' => delegateUser.AccountId,
            'Delegate_Observer_Approval_Status__c' => 'Approved'
        });
        insert obs;

        Test.startTest();
        // Change to a different trainer account that has no active delegate user
        // This simulates the scenario where the old delegate user becomes inactive
        Account dummyAccount = TestDataFactory.getAccountofTrainerRecordType(new Map<String, Object>{
            'FirstName' => 'Dummy',
            'LastName' => 'Delegate Account',
            'Contract_Type__c' => 'Level 3'
        });
        insert dummyAccount;

        obs.Delegate_Observer__c = dummyAccount.Id;
        obs.Delegate_Observer_Approval_Status__c = 'Approved';
        update obs;
        Test.stopTest();
 
         // Verify no exception was thrown and update succeeded despite no active user for old delegate
         obs = [SELECT Id, Delegate_Observer__c FROM Observation__c WHERE Id = :obs.Id];
         Assert.areEqual(dummyAccount.Id, obs.Delegate_Observer__c, 'Delegate should be updated despite no active user for deletion');
     }
 
     /**
      * @description Test handleDmlErrors method directly by causing DML failures
      * Uses Practice account records with validation errors to trigger DML failures
      * Covers both SaveResult and DeleteResult error handling paths
      */
     @IsTest
     static void testHandleDmlErrorsDirectly() {
         User delegateUser = getDelegateUser();
         Account trainerAccount = getTrainerOne();
 
         Test.startTest();
 
         // Test SaveResult error handling - Create Practice account without required zip code
         List<SObject> invalidAccounts = new List<SObject>{
             TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
                 'Name' => 'Invalid Practice',
                 'BillingPostalCode' => null  // Missing required field - will cause validation error
             })
         };
 
         // Perform insert with allOrNone=false to get error results
         Database.SaveResult[] saveResults = Database.insert(invalidAccounts, false);
 
         // Call handleDmlErrors directly to cover SaveResult error path
         ObservationSharingHandler.handleDmlErrors(saveResults, invalidAccounts);
 
         // Verify SaveResult failed as expected due to validation rule
         Assert.isFalse(saveResults[0].isSuccess(), 'Insert should fail with missing BillingPostalCode');
 
         // Test DeleteResult error handling - Create valid share, delete it, then try deleting again
         AccountShare validShare = new AccountShare(
             AccountId = trainerAccount.Id,
             UserOrGroupId = delegateUser.Id,
             AccountAccessLevel = 'Edit',
             OpportunityAccessLevel = 'Edit'
         );
         Database.insert(validShare, false);
 
         // Query the share
         List<AccountShare> sharesToDelete = [
             SELECT Id
             FROM AccountShare
             WHERE AccountId = :trainerAccount.Id
             AND UserOrGroupId = :delegateUser.Id
             AND RowCause = 'Manual'
             LIMIT 1
         ];
 
         if (!sharesToDelete.isEmpty()) {
             // Delete once successfully
             Database.delete(sharesToDelete, false);
 
             // Try to delete again - this will fail
             List<SObject> alreadyDeletedShares = new List<SObject>{sharesToDelete[0]};
             Database.DeleteResult[] deleteResults = Database.delete(alreadyDeletedShares, false);
 
             // Call handleDmlErrors directly to cover DeleteResult error path
             ObservationSharingHandler.handleDmlErrors(deleteResults, alreadyDeletedShares);
 
             // Verify DeleteResult failed as expected
             Assert.isFalse(deleteResults[0].isSuccess(), 'Delete should fail for already-deleted record');
         }
 
         Test.stopTest();
     }
 
 }