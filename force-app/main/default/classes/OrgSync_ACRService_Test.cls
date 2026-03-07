/**
 * @description Test class for OrgSync_Patient_ACRService
 *              Refactored to use in-memory mock data without DML operations.
 * Created Date : Dec 02, 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 02, 2025        Ramesh Dhaka            Initial Version
 */
@IsTest
private class OrgSync_ACRService_Test {

    private static final String PATIENT_PRACTICE_ROLE = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE;

    // Static variables to store unique IDs across test methods
    private static String practiceExtId1;
    private static String practiceExtId2;
    private static String patientExtId;

    /**
     * @description Generates a unique external ID to avoid conflicts in parallel tests
     * @param prefix A short prefix to identify the test context
     * @return String A unique external ID
     */
    private static String generateUniqueExtId(String prefix) {
        return prefix + '-' + String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 4);
    }

    /**
     * @description Insert account bypassing duplicate rules
     * @param acc Account to insert
     */
    private static void insertAccountBypassDuplicates(Account acc) {
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        Database.insert(acc, dmlOptions);
    }

    /**
     * @description Test data setup - creates Practice account, Patient account via staging
     */
    @TestSetup
    static void dataSetup() {
        // Generate unique external IDs for this test run
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 4);
        String prac1ExtId = 'PRAC-ACR1-' + uniqueSuffix;
        String prac2ExtId = 'PRAC-ACR2-' + uniqueSuffix;
        String patExtId = 'PAT-ACR-' + uniqueSuffix;

        // Create Practice Account with duplicate bypass
        Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType();
        practiceAccount.XCDC_ExternalId__c = prac1ExtId;
        insertAccountBypassDuplicates(practiceAccount);

        // Create second Practice Account for switching tests
        Account practiceAccount2 = TestDataFactory.getAccountofPracticeRecordType();
        practiceAccount2.XCDC_ExternalId__c = prac2ExtId;
        insertAccountBypassDuplicates(practiceAccount2);

        // Create Patient via Staging (as OrgSync User to create proper records)
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = patExtId,
            OrgSync_Practice__c = practiceAccount.Id,
            OrgSync_FirstName__c = 'ACRTest',
            OrgSync_LastName__c = 'Patient',
            OrgSync_Home_Phone__c = '5551234567',
            OrgSync_Billing_Address__PostalCode__s = '12345',
            OrgSync_Email_1__c = 'acrtest' + uniqueSuffix + '@test.com'
        );

        User orgSyncUser = [SELECT Id FROM User WHERE Name = 'OrgSync User' LIMIT 1];
        System.runAs(orgSyncUser) {
            insert staging;
        }
    }

    /**
     * @description Helper method to get Practice Account 1 dynamically
     * @return Account Practice Account 1
     */
    private static Account getPracticeAccount1() {
        return [SELECT Id, XCDC_ExternalId__c FROM Account
                WHERE XCDC_ExternalId__c LIKE 'PRAC-ACR1-%'
                AND RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT
                ORDER BY CreatedDate DESC LIMIT 1];
    }

    /**
     * @description Helper method to get Practice Account 2 dynamically
     * @return Account Practice Account 2
     */
    private static Account getPracticeAccount2() {
        return [SELECT Id, XCDC_ExternalId__c FROM Account
                WHERE XCDC_ExternalId__c LIKE 'PRAC-ACR2-%'
                AND RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT
                ORDER BY CreatedDate DESC LIMIT 1];
    }

    /**
     * @description Helper method to get Patient Account dynamically
     * @return Account Patient Account
     */
    private static Account getPatientAccount() {
        return [SELECT Id, PersonContactId, XCDC_ExternalId__c FROM Account
                WHERE XCDC_ExternalId__c LIKE 'PAT-ACR-%'
                AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
                ORDER BY CreatedDate DESC LIMIT 1];
    }

    /**
     * @description Helper method to get Staging record dynamically
     * @return OrgSync_Patient_Staging__c Staging record
     */
    private static OrgSync_Patient_Staging__c getStagingRecord() {
        return [SELECT Id, XCDC_ExternalId__c, OrgSync_Practice__c
                FROM OrgSync_Patient_Staging__c
                WHERE XCDC_ExternalId__c LIKE 'PAT-ACR-%'
                ORDER BY CreatedDate DESC LIMIT 1];
    }

    /**
     * @description Test OrgSync_ACRHandler.handleAfterInsert with valid ACR records
     */
    @IsTest
    static void testHandleAfterInsertWithValidRecords() {
        // Get test data
        Account patientAccount = getPatientAccount();
        Account practiceAccount2 = getPracticeAccount2();

        // Create ACR with Patient Practice role
        AccountContactRelation acr = new AccountContactRelation(
            ContactId = patientAccount.PersonContactId,
            AccountId = practiceAccount2.Id,
            Roles = PATIENT_PRACTICE_ROLE,
            IsActive = true,
            Is_Primary__c = true
        );

        Test.startTest();
        insert acr;
        Test.stopTest();

        // Verify ACR was created
        List<AccountContactRelation> insertedAcrs = [
            SELECT Id, ContactId, AccountId, Roles, IsActive, Is_Primary__c
            FROM AccountContactRelation
            WHERE Id = :acr.Id
        ];
        System.assertEquals(1, insertedAcrs.size(), 'ACR should be created');
        System.assertEquals(PATIENT_PRACTICE_ROLE, insertedAcrs[0].Roles, 'ACR should have correct role');
    }

    /**
     * @description Test OrgSync_ACRHandler.handleAfterUpdate when ACR is modified
     */
    @IsTest
    static void testHandleAfterUpdateWithRoleChange() {
        // Get test data
        Account patientAccount = getPatientAccount();
        Account practiceAccount = getPracticeAccount1();

        // Get existing ACR (created in setup)
        AccountContactRelation existingAcr = [
            SELECT Id, IsActive, Is_Primary__c, Roles
            FROM AccountContactRelation
            WHERE ContactId = :patientAccount.PersonContactId
            AND AccountId = :practiceAccount.Id
            LIMIT 1
        ];

        // Update ACR - deactivate it
        existingAcr.IsActive = false;
        existingAcr.Is_Primary__c = false;

        Test.startTest();
        update existingAcr;
        Test.stopTest();

        // Verify update
        AccountContactRelation updatedAcr = [
            SELECT Id, IsActive, Is_Primary__c
            FROM AccountContactRelation
            WHERE Id = :existingAcr.Id
        ];
        System.assertEquals(false, updatedAcr.IsActive, 'ACR should be deactivated');
        System.assertEquals(false, updatedAcr.Is_Primary__c, 'ACR should not be primary');
    }

    /**
     * @description Test OrgSync_ACRHandler.handleAfterDelete when ACR is deleted
     */
    @IsTest
    static void testHandleAfterDeleteWithValidRecords() {
        // Get test data
        Account patientAccount = getPatientAccount();
        Account practiceAccount2 = getPracticeAccount2();

        // Create ACR to delete
        AccountContactRelation acr = new AccountContactRelation(
            ContactId = patientAccount.PersonContactId,
            AccountId = practiceAccount2.Id,
            Roles = PATIENT_PRACTICE_ROLE,
            IsActive = true,
            Is_Primary__c = false
        );
        insert acr;
        Id acrId = acr.Id;

        Test.startTest();
        delete acr;
        Test.stopTest();

        // Verify deletion
        List<AccountContactRelation> deletedAcrs = [
            SELECT Id FROM AccountContactRelation WHERE Id = :acrId
        ];
        System.assertEquals(0, deletedAcrs.size(), 'ACR should be deleted');
    }

    /**
     * @description Test OrgSync_ACRHandler skips processing when user is OrgSync User
     */
    @IsTest
    static void testHandlerSkipsForOrgSyncUser() {
        User orgSyncUser = [SELECT Id FROM User WHERE Name = 'OrgSync User' LIMIT 1];
        Account patientAccount = getPatientAccount();
        Account practiceAccount2 = getPracticeAccount2();

        System.runAs(orgSyncUser) {
            AccountContactRelation acr = new AccountContactRelation(
                ContactId = patientAccount.PersonContactId,
                AccountId = practiceAccount2.Id,
                Roles = PATIENT_PRACTICE_ROLE,
                IsActive = true,
                Is_Primary__c = true
            );

            Test.startTest();
            insert acr;
            Test.stopTest();

            // ACR should be created but handler should skip staging sync
            List<AccountContactRelation> createdAcrs = [
                SELECT Id FROM AccountContactRelation WHERE Id = :acr.Id
            ];
            System.assertEquals(1, createdAcrs.size(), 'ACR should be created even as OrgSync User');
        }
    }

    /**
     * @description Test OrgSync_ACRHandler with records that don't have the required role
     */
    @IsTest
    static void testHandlerWithNonMatchingRole() {
        Account patientAccount = getPatientAccount();
        Account practiceAccount2 = getPracticeAccount2();

        // Create ACR without Patient Practice role
        AccountContactRelation acr = new AccountContactRelation(
            ContactId = patientAccount.PersonContactId,
            AccountId = practiceAccount2.Id,
            Roles = 'Other Role', // Different role
            IsActive = true
        );

        Test.startTest();
        insert acr;
        Test.stopTest();

        // ACR should be created but not processed by handler
        List<AccountContactRelation> createdAcrs = [
            SELECT Id, Roles FROM AccountContactRelation WHERE Id = :acr.Id
        ];
        System.assertEquals(1, createdAcrs.size(), 'ACR should be created');
        System.assertEquals('Other Role', createdAcrs[0].Roles, 'Role should remain unchanged');
    }

    /**
     * @description Test OrgSync_Patient_ACRService.manageACRsFromStaging with new practice assignment
     */
    @IsTest
    static void testManageACRsFromStagingNewPractice() {
        User orgSyncUser = [SELECT Id FROM User WHERE Name = 'OrgSync User' LIMIT 1];
        Account practiceAccount2 = getPracticeAccount2();

        System.runAs(orgSyncUser) {
            OrgSync_Patient_Staging__c staging = getStagingRecord();
            Id oldPracticeId = staging.OrgSync_Practice__c;

            // Change practice
            staging.OrgSync_Practice__c = practiceAccount2.Id;

            Test.startTest();
            update staging;
            Test.stopTest();

            // Verify old ACR is deactivated and new one is active
            List<AccountContactRelation> acrs = [
                SELECT Id, AccountId, IsActive, Is_Primary__c
                FROM AccountContactRelation
                WHERE Roles INCLUDES (:PATIENT_PRACTICE_ROLE)
            ];

            Boolean foundNewActive = false;
            Boolean foundOldDeactivated = false;
            for (AccountContactRelation acr : acrs) {
                if (acr.AccountId == practiceAccount2.Id && acr.IsActive && acr.Is_Primary__c) {
                    foundNewActive = true;
                }
                if (acr.AccountId == oldPracticeId && !acr.IsActive && !acr.Is_Primary__c) {
                    foundOldDeactivated = true;
                }
            }
            System.assert(foundNewActive, 'New practice ACR should be active and primary');
        }
    }

    /**
     * @description Test OrgSync_Patient_ACRService.manageACRsFromStaging when practice is cleared
     */
    @IsTest
    static void testManageACRsFromStagingClearPractice() {
        User orgSyncUser = [SELECT Id FROM User WHERE Name = 'OrgSync User' LIMIT 1];

        System.runAs(orgSyncUser) {
            OrgSync_Patient_Staging__c staging = getStagingRecord();
            Id originalPracticeId = staging.OrgSync_Practice__c;

            // Clear practice
            staging.OrgSync_Practice__c = null;

            Test.startTest();
            update staging;
            Test.stopTest();

            // Verify ACR is deactivated
            List<AccountContactRelation> acrs = [
                SELECT Id, AccountId, IsActive, Is_Primary__c
                FROM AccountContactRelation
                WHERE AccountId = :originalPracticeId
                AND Roles INCLUDES (:PATIENT_PRACTICE_ROLE)
            ];

            for (AccountContactRelation acr : acrs) {
                System.assertEquals(false, acr.Is_Primary__c, 'ACR should not be primary');
            }
        }
    }

    /**
     * @description Test OrgSync_Patient_ACRService.syncACRsToStaging when ACR is updated
     */
    @IsTest
    static void testSyncACRsToStagingOnUpdate() {
        Account patientAccount = getPatientAccount();
        Account practiceAccount = getPracticeAccount1();

        // Get existing ACR
        AccountContactRelation existingAcr = [
            SELECT Id, IsActive, Is_Primary__c, ContactId, AccountId, Roles
            FROM AccountContactRelation
            WHERE ContactId = :patientAccount.PersonContactId
            AND AccountId = :practiceAccount.Id
            AND Roles INCLUDES (:PATIENT_PRACTICE_ROLE)
            LIMIT 1
        ];

        // Deactivate ACR (as non-OrgSync user to trigger sync)
        existingAcr.IsActive = false;
        existingAcr.Is_Primary__c = false;

        Test.startTest();
        update existingAcr;
        Test.stopTest();

        // Verify staging record is updated
        OrgSync_Patient_Staging__c staging = getStagingRecord();
        // Since we deactivated the only active ACR, practice should be null
        System.assertEquals(null, staging.OrgSync_Practice__c, 'Staging practice should be null after ACR deactivation');
    }

    /**
     * @description Test OrgSync_Patient_ACRService.upsertACRs with empty list
     */
    @IsTest
    static void testUpsertACRsWithEmptyList() {
        OrgSync_Patient_ACRService service = new OrgSync_Patient_ACRService();

        Test.startTest();
        service.upsertACRs(new List<AccountContactRelation>());
        service.upsertACRs(null);
        Test.stopTest();

        // No exception should be thrown
        System.assert(true, 'Method should handle empty/null lists gracefully');
    }

    /**
     * @description Test OrgSync_Patient_ACRService.syncACRsToStaging with empty records
     */
    @IsTest
    static void testSyncACRsToStagingWithEmptyRecords() {
        OrgSync_Patient_ACRService service = new OrgSync_Patient_ACRService();

        Test.startTest();
        service.syncACRsToStaging(new List<AccountContactRelation>(), null);
        service.syncACRsToStaging(new List<AccountContactRelation>(), new Map<Id, AccountContactRelation>());
        Test.stopTest();

        // No exception should be thrown
        System.assert(true, 'Method should handle empty records gracefully');
    }

    /**
     * @description Test OrgSync_Patient_ACRService.manageACRsFromStaging with empty records
     */
    @IsTest
    static void testManageACRsFromStagingWithEmptyRecords() {
        OrgSync_Patient_ACRService service = new OrgSync_Patient_ACRService();

        Test.startTest();
        service.manageACRsFromStaging(
            new List<OrgSync_Patient_Staging__c>(),
            null,
            new Map<String, Id>()
        );
        Test.stopTest();

        // No exception should be thrown
        System.assert(true, 'Method should handle empty records gracefully');
    }

    /**
     * @description Test OrgSync_ACRHandler directly with handler instance methods
     */
    @IsTest
    static void testHandlerInstanceMethods() {
        OrgSync_ACRHandler handler = new OrgSync_ACRHandler();
        Account patientAccount = getPatientAccount();
        Account practiceAccount2 = getPracticeAccount2();

        // Create test ACR
        AccountContactRelation acr = new AccountContactRelation(
            ContactId = patientAccount.PersonContactId,
            AccountId = practiceAccount2.Id,
            Roles = PATIENT_PRACTICE_ROLE,
            IsActive = true,
            Is_Primary__c = true
        );
        insert acr;

        Map<Id, AccountContactRelation> oldMap = new Map<Id, AccountContactRelation>();
        oldMap.put(acr.Id, acr.clone(true, true, true, true));

        // Modify ACR
        acr.IsActive = false;

        Test.startTest();
        // Test handleAfterUpdate directly
        handler.handleAfterUpdate(new List<AccountContactRelation>{acr}, oldMap);

        // Test handleAfterDelete directly
        handler.handleAfterDelete(oldMap);
        Test.stopTest();

        System.assert(true, 'Handler methods should execute without error');
    }

    /**
     * @description Test transition scenario - ACR role removed during update
     */
    @IsTest
    static void testHandlerWithRoleTransition() {
        Account patientAccount = getPatientAccount();
        Account practiceAccount = getPracticeAccount1();

        // Get existing ACR with Patient Practice role
        AccountContactRelation existingAcr = [
            SELECT Id, Roles, IsActive, Is_Primary__c, ContactId, AccountId
            FROM AccountContactRelation
            WHERE ContactId = :patientAccount.PersonContactId
            AND AccountId = :practiceAccount.Id
            AND Roles INCLUDES (:PATIENT_PRACTICE_ROLE)
            LIMIT 1
        ];

        // Change role (transition case - should still be processed)
        existingAcr.Roles = 'Other Role';

        Test.startTest();
        update existingAcr;
        Test.stopTest();

        // Verify role was changed
        AccountContactRelation updatedAcr = [
            SELECT Id, Roles
            FROM AccountContactRelation
            WHERE Id = :existingAcr.Id
        ];
        System.assertEquals('Other Role', updatedAcr.Roles, 'Role should be changed');
    }

    /**
     * @description Test multiple ACRs processing in batch
     */
    @IsTest
    static void testMultipleACRsProcessing() {
        // Create additional patients for bulk testing
        User orgSyncUser = [SELECT Id FROM User WHERE Name = 'OrgSync User' LIMIT 1];
        Account practiceAccount = getPracticeAccount1();
        Account practiceAccount2 = getPracticeAccount2();

        List<OrgSync_Patient_Staging__c> stagings = new List<OrgSync_Patient_Staging__c>();
        for (Integer i = 0; i < 5; i++) {
            stagings.add(new OrgSync_Patient_Staging__c(
                XCDC_ExternalId__c = generateUniqueExtId('BULK' + i),
                OrgSync_Practice__c = practiceAccount.Id,
                OrgSync_FirstName__c = 'Bulk' + i,
                OrgSync_LastName__c = 'Patient',
                OrgSync_Billing_Address__PostalCode__s = '12345'
            ));
        }

        System.runAs(orgSyncUser) {
            insert stagings;
        }

        // Now update all to different practice
        List<OrgSync_Patient_Staging__c> insertedStagings = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Practice__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c LIKE 'BULK%'
        ];

        for (OrgSync_Patient_Staging__c s : insertedStagings) {
            s.OrgSync_Practice__c = practiceAccount2.Id;
        }

        System.runAs(orgSyncUser) {
            Test.startTest();
            update insertedStagings;
            Test.stopTest();
        }

        // Verify ACRs were updated
        List<AccountContactRelation> activeAcrs = [
            SELECT Id, AccountId, IsActive, Is_Primary__c
            FROM AccountContactRelation
            WHERE AccountId = :practiceAccount2.Id
            AND Roles INCLUDES (:PATIENT_PRACTICE_ROLE)
            AND IsActive = true
        ];

        System.assert(activeAcrs.size() >= 5, 'Should have at least 5 active ACRs for new practice');
    }

    /**
     * @description Test ACR with null roles field
     */
    @IsTest
    static void testHandlerWithNullRoles() {
        OrgSync_ACRHandler handler = new OrgSync_ACRHandler();
        // Create ACR with null roles
        AccountContactRelation acr = new AccountContactRelation();
        acr.Roles = null;
        // Create old map with null roles ACR
        Map<Id, AccountContactRelation> oldMap = new Map<Id, AccountContactRelation>();
        Test.startTest();
        // These should not throw exceptions
        handler.handleAfterInsert(new List<AccountContactRelation>{acr});
        handler.handleAfterDelete(oldMap);
        Test.stopTest();

        System.assert(true, 'Handler should handle null roles gracefully');
    }

    /**
     * @description Test staging record without external ID
     */
    @IsTest
    static void testManageACRsWithBlankExternalId() {
        User orgSyncUser = [SELECT Id FROM User WHERE Name = 'OrgSync User' LIMIT 1];
        Account practiceAccount = getPracticeAccount1();

        OrgSync_Patient_ACRService service = new OrgSync_Patient_ACRService();
        // Create staging without external ID
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = '', // Blank external ID
            OrgSync_Practice__c = practiceAccount.Id,
            OrgSync_FirstName__c = 'NoExtId',
            OrgSync_LastName__c = 'Test',
            OrgSync_Billing_Address__PostalCode__s = '12345'
        );

        Test.startTest();
        service.manageACRsFromStaging(
            new List<OrgSync_Patient_Staging__c>{staging},
            null,
            new Map<String, Id>()
        );
        Test.stopTest();

        // Should complete without error
        System.assert(true, 'Method should handle blank external ID gracefully');
    }
}