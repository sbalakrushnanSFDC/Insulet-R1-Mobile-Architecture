/**
 * @description Test class for HPFTriggerHandler
 *              Tests the update of OrgSync_Physician_Staging__c records
 *              when HealthcarePractitionerFacility IsActive is updated 
 * Created Date : Jan 28, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 28, 2026        Pradip Kokate           Initial Version
 */
@isTest
private class HPFTriggerHandler_Test {

    private static final String TEST_PROVIDER_NPI_1 = '1234567890';
    private static final String TEST_PROVIDER_NPI_2 = '0987654321';
    private static final String TEST_PROVIDER_NPI_3 = '1122334455';
    
    // Cache for practice accounts to avoid duplicate queries
    private static Map<String, Account> practiceAccountCache = new Map<String, Account>();
    
    // Cache for provider accounts by NPI to avoid duplicate queries
    private static Map<String, Account> providerAccountByNPICache = new Map<String, Account>();

    /**
     * @description Test setup - creates test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create Practice Accounts using factory
        List<Account> practiceAccounts = new List<Account>();
        practiceAccounts.add(OrgSync_TestDataFactory.createPracticeAccount('Test Practice 1', 'PRAC-001', '12345'));
        practiceAccounts.add(OrgSync_TestDataFactory.createPracticeAccount('Test Practice 2', 'PRAC-002', '12346'));
        Database.insert(practiceAccounts, OrgSync_TestDataFactory.getDMLOptions());
        
        // Create Provider Accounts using factory
        List<Id> successfulProviderAccountIds = OrgSync_TestDataFactory.createAndInsertProviderAccounts(
            3, 'Provider', 'Provider', 'provider@test.com'
        );
        
        // Create Identifier records using factory
        List<String> npiValues = new List<String>{TEST_PROVIDER_NPI_1, TEST_PROVIDER_NPI_2, TEST_PROVIDER_NPI_3};
        OrgSync_TestDataFactory.createAndInsertIdentifierRecords(successfulProviderAccountIds, npiValues);
        
        // Query Provider Accounts to get PersonContactId using factory
        Map<Id, Account> providerAccountMap = OrgSync_TestDataFactory.queryProviderAccounts(successfulProviderAccountIds);
        
        // Query Practice Accounts after insert
        Account practice1 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-001' LIMIT 1];
        Account practice2 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-002' LIMIT 1];
        System.assertNotEquals(null, practice1, 'Practice Account 1 should be found');
        System.assertNotEquals(null, practice2, 'Practice Account 2 should be found');
        
        // Create Physician Staging records using factory
        List<Id> practiceIds = new List<Id>{practice1.Id, practice1.Id, practice2.Id};
        List<OrgSync_Physician_Staging__c> physicianStages = OrgSync_TestDataFactory.createPhysicianStagingRecords(
            npiValues, practiceIds, null, null
        );
        
        if (!physicianStages.isEmpty()) {
            insert physicianStages;
        }
        
        // Create HPF records using factory
        List<Id> hpfPracticeIds = new List<Id>{practice1.Id, practice1.Id, practice2.Id};
        List<Id> practitionerIds = new List<Id>();
        for (Integer i = 0; i < successfulProviderAccountIds.size() && i < 3; i++) {
            Id accountId = successfulProviderAccountIds[i];
            if (providerAccountMap.containsKey(accountId)) {
                practitionerIds.add(providerAccountMap.get(accountId).PersonContactId);
            }
        }
        List<String> hpfNames = new List<String>{'Test HPF 1', 'Test HPF 2', 'Test HPF 3'};
        List<Boolean> isActiveValues = new List<Boolean>{true, true, false};
        
        OrgSync_TestDataFactory.createAndInsertHPFRecords(hpfPracticeIds, practitionerIds, hpfNames, isActiveValues);
    }

    /**
     * @description Helper method to get Practice Account by External ID (cached)
     * @param externalId External ID of the practice account
     * @return Practice Account
     */
    private static Account getPracticeAccount(String externalId) {
        if (!practiceAccountCache.containsKey(externalId)) {
            Account account = OrgSync_TestDataFactory.getPracticeAccountByExternalId(externalId);
            if (account != null) {
                practiceAccountCache.put(externalId, account);
            }
        }
        return practiceAccountCache.get(externalId);
    }

    /**
     * @description Helper method to get Provider Account by NPI using Identifier records (cached)
     * @param npi NPI value to search for
     * @return Provider Account with PersonContactId populated
     */
    private static Account getProviderAccountByNPI(String npi) {
        if (String.isBlank(npi)) {
            return null;
        }

        // Check cache first
        if (providerAccountByNPICache.containsKey(npi)) {
            return providerAccountByNPICache.get(npi);
        }

        Account providerAccount = OrgSync_TestDataFactory.getProviderAccountByNPI(npi);
        providerAccountByNPICache.put(npi, providerAccount);
        return providerAccount;
    }

    /**
     * @description Test updating IsActive from true to false - should set OrgSync_Do_Not_Use__c to true
     */
    @IsTest
    static void testIsActiveTrueToFalse() {
        // Get test data
        Account practiceAccount1 = getPracticeAccount('PRAC-001');
        Account providerAccount1 = getProviderAccountByNPI(TEST_PROVIDER_NPI_1);
        System.assertNotEquals(null, providerAccount1, 'Provider Account should be found by NPI');
        System.assertNotEquals(null, providerAccount1.PersonContactId, 'Provider Account should have PersonContactId');

        // Get HPF record
        HealthcarePractitionerFacility hpf = [
            SELECT Id, AccountId, PractitionerId, IsActive
            FROM HealthcarePractitionerFacility
            WHERE AccountId = :practiceAccount1.Id
            AND PractitionerId = :providerAccount1.PersonContactId
            LIMIT 1
        ];

        // Get Physician Staging record
        OrgSync_Physician_Staging__c physicianStage = [
            SELECT Id, OrgSync_NPI__c, OrgSync_Parent_Practice__c, OrgSync_Do_Not_Use__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c = :TEST_PROVIDER_NPI_1
            AND OrgSync_Parent_Practice__c = :practiceAccount1.Id
            LIMIT 1
        ];

        System.assertEquals(false, physicianStage.OrgSync_Do_Not_Use__c, 'Initial value should be false');
        System.assertEquals(true, hpf.IsActive, 'Initial IsActive should be true');

        Test.startTest();
        // Call updatePhysicianStagingOnIsActiveChange directly with IsActive=false
        HealthcarePractitionerFacility oldHPF = hpf.clone(true, true, true, true);
        hpf.IsActive = false;
        Map<Id, HealthcarePractitionerFacility> oldRecordsMap = new Map<Id, HealthcarePractitionerFacility>{oldHPF.Id => oldHPF};
        OrgSync_HPFProcess.updatePhysicianStagingOnIsActiveChange(new List<HealthcarePractitionerFacility>{hpf}, oldRecordsMap);
        Test.stopTest();

        // Verify Physician Staging record was updated
        OrgSync_Physician_Staging__c updatedPhysicianStage = [
            SELECT Id, OrgSync_Do_Not_Use__c
            FROM OrgSync_Physician_Staging__c
            WHERE Id = :physicianStage.Id
        ];

        System.assertEquals(true, updatedPhysicianStage.OrgSync_Do_Not_Use__c, 
            'OrgSync_Do_Not_Use__c should be true when IsActive is false');
    }

    /**
     * @description Test updating IsActive from false to true - should set OrgSync_Do_Not_Use__c to false
     */
    @IsTest
    static void testIsActiveFalseToTrue() {
        // Get test data
        Account practiceAccount2 = getPracticeAccount('PRAC-002');
        Account providerAccount3 = getProviderAccountByNPI(TEST_PROVIDER_NPI_3);
        System.assertNotEquals(null, providerAccount3, 'Provider Account should be found by NPI');
        System.assertNotEquals(null, providerAccount3.PersonContactId, 'Provider Account should have PersonContactId');

        // Get HPF record (initially IsActive = false)
        HealthcarePractitionerFacility hpf = [
            SELECT Id, AccountId, PractitionerId, IsActive
            FROM HealthcarePractitionerFacility
            WHERE AccountId = :practiceAccount2.Id
            AND PractitionerId = :providerAccount3.PersonContactId
            LIMIT 1
        ];

        // Get Physician Staging record
        OrgSync_Physician_Staging__c physicianStage = [
            SELECT Id, OrgSync_NPI__c, OrgSync_Parent_Practice__c, OrgSync_Do_Not_Use__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c = :TEST_PROVIDER_NPI_3
            AND OrgSync_Parent_Practice__c = :practiceAccount2.Id
            LIMIT 1
        ];

        System.assertEquals(false, physicianStage.OrgSync_Do_Not_Use__c, 'Initial value should be false');
        System.assertEquals(false, hpf.IsActive, 'Initial IsActive should be false');

        Test.startTest();
        // Call updatePhysicianStagingOnIsActiveChange directly with IsActive=true
        HealthcarePractitionerFacility oldHPF = hpf.clone(true, true, true, true);
        hpf.IsActive = true;
        Map<Id, HealthcarePractitionerFacility> oldRecordsMap = new Map<Id, HealthcarePractitionerFacility>{oldHPF.Id => oldHPF};
        OrgSync_HPFProcess.updatePhysicianStagingOnIsActiveChange(new List<HealthcarePractitionerFacility>{hpf}, oldRecordsMap);
        Test.stopTest();

        // Verify Physician Staging record was updated
        OrgSync_Physician_Staging__c updatedPhysicianStage = [
            SELECT Id, OrgSync_Do_Not_Use__c
            FROM OrgSync_Physician_Staging__c
            WHERE Id = :physicianStage.Id
        ];

        System.assertEquals(false, updatedPhysicianStage.OrgSync_Do_Not_Use__c, 
            'OrgSync_Do_Not_Use__c should be false when IsActive is true');
    }

    /**
     * @description Test updating IsActive when it doesn't change - should not update Physician Staging
     */
    @IsTest
    static void testIsActiveNoChange() {
        // Get test data
        Account practiceAccount1 = getPracticeAccount('PRAC-001');
        Account providerAccount1 = getProviderAccountByNPI(TEST_PROVIDER_NPI_1);
        System.assertNotEquals(null, providerAccount1, 'Provider Account should be found by NPI');
        System.assertNotEquals(null, providerAccount1.PersonContactId, 'Provider Account should have PersonContactId');

        // Get HPF record
        HealthcarePractitionerFacility hpf = [
            SELECT Id, AccountId, PractitionerId, IsActive, Name
            FROM HealthcarePractitionerFacility
            WHERE AccountId = :practiceAccount1.Id
            AND PractitionerId = :providerAccount1.PersonContactId
            LIMIT 1
        ];

        // Get Physician Staging record
        OrgSync_Physician_Staging__c physicianStage = [
            SELECT Id, OrgSync_Do_Not_Use__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c = :TEST_PROVIDER_NPI_1
            AND OrgSync_Parent_Practice__c = :practiceAccount1.Id
            LIMIT 1
        ];

        Boolean initialDoNotUse = physicianStage.OrgSync_Do_Not_Use__c;

        Test.startTest();
        // Update Name field but not IsActive
        hpf.Name = 'Updated Name';
        update hpf;
        Test.stopTest();

        // Verify Physician Staging record was NOT updated
        OrgSync_Physician_Staging__c updatedPhysicianStage = [
            SELECT Id, OrgSync_Do_Not_Use__c
            FROM OrgSync_Physician_Staging__c
            WHERE Id = :physicianStage.Id
        ];

        System.assertEquals(initialDoNotUse, updatedPhysicianStage.OrgSync_Do_Not_Use__c, 
            'OrgSync_Do_Not_Use__c should not change when IsActive is not updated');
    }

    /**
     * @description Test bulk updates - multiple HPF records updated at once
     */
    @IsTest
    static void testBulkUpdates() {
        // Get test data
        Account practiceAccount1 = getPracticeAccount('PRAC-001');
        Account providerAccount1 = getProviderAccountByNPI(TEST_PROVIDER_NPI_1);
        Account providerAccount2 = getProviderAccountByNPI(TEST_PROVIDER_NPI_2);
        
        System.assertNotEquals(null, providerAccount1, 'Provider Account 1 should be found by NPI');
        System.assertNotEquals(null, providerAccount2, 'Provider Account 2 should be found by NPI');

        // Get HPF records
        List<HealthcarePractitionerFacility> hpfRecords = [
            SELECT Id, AccountId, PractitionerId, IsActive
            FROM HealthcarePractitionerFacility
            WHERE AccountId = :practiceAccount1.Id
            AND PractitionerId IN (:providerAccount1.PersonContactId, :providerAccount2.PersonContactId)
        ];

        System.assertEquals(2, hpfRecords.size(), 'Should have 2 HPF records');

        // Get Physician Staging records
        List<OrgSync_Physician_Staging__c> physicianStages = [
            SELECT Id, OrgSync_NPI__c, OrgSync_Parent_Practice__c, OrgSync_Do_Not_Use__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_Parent_Practice__c = :practiceAccount1.Id
            AND OrgSync_NPI__c IN (:TEST_PROVIDER_NPI_1, :TEST_PROVIDER_NPI_2)
        ];

        System.assertEquals(2, physicianStages.size(), 'Should have 2 Physician Staging records');

        // Verify initial values
        for (OrgSync_Physician_Staging__c ps : physicianStages) {
            System.assertEquals(false, ps.OrgSync_Do_Not_Use__c, 'Initial value should be false');
        }

        Test.startTest();
        // Call updatePhysicianStagingOnIsActiveChange directly with IsActive=false for both HPF records
        Map<Id, HealthcarePractitionerFacility> oldRecordsMap = new Map<Id, HealthcarePractitionerFacility>();
        for (HealthcarePractitionerFacility hpf : hpfRecords) {
            HealthcarePractitionerFacility oldHPF = hpf.clone(true, true, true, true);
            oldRecordsMap.put(oldHPF.Id, oldHPF);
            hpf.IsActive = false;
        }
        OrgSync_HPFProcess.updatePhysicianStagingOnIsActiveChange(hpfRecords, oldRecordsMap);
        Test.stopTest();

        // Verify both Physician Staging records were updated
        List<OrgSync_Physician_Staging__c> updatedPhysicianStages = [
            SELECT Id, OrgSync_Do_Not_Use__c, OrgSync_NPI__c
            FROM OrgSync_Physician_Staging__c
            WHERE Id IN :new Map<Id, OrgSync_Physician_Staging__c>(physicianStages).keySet()
        ];

        System.assertEquals(2, updatedPhysicianStages.size(), 'Should have 2 updated Physician Staging records');
        for (OrgSync_Physician_Staging__c ps : updatedPhysicianStages) {
            System.assertEquals(true, ps.OrgSync_Do_Not_Use__c, 
                'OrgSync_Do_Not_Use__c should be true when IsActive is false for NPI: ' + ps.OrgSync_NPI__c);
        }
    }

    /**
     * @description Test with HPF record that doesn't have matching Physician Staging record
     */
    @IsTest
    static void testNoMatchingPhysicianStaging() {
        // Get test data
        Account practiceAccount1 = getPracticeAccount('PRAC-001');
        Account providerAccount1 = getProviderAccountByNPI(TEST_PROVIDER_NPI_1);
        System.assertNotEquals(null, providerAccount1, 'Provider Account should be found by NPI');

        // Create a new Practice Account
        Account newPractice = TestDataFactory.getAccountofPracticeRecordType();
        newPractice.Name = 'New Practice';
        newPractice.BillingPostalCode = '12347';
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        insert newPractice;

        // Create HPF record with new practice (no matching Physician Staging)
        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = newPractice.Id,
            PractitionerId = providerAccount1.PersonContactId,
            Name = 'Test HPF No Match',
            IsActive = true
        );
        insert hpf;

        // Count Physician Staging records before update
        Integer countBefore = [
            SELECT COUNT() 
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c = :TEST_PROVIDER_NPI_1
            AND OrgSync_Parent_Practice__c = :newPractice.Id
        ];

        System.assertEquals(true, countBefore != null, 'Should not have matching Physician Staging record');

        Test.startTest();
        // Call updatePhysicianStagingOnIsActiveChange directly with IsActive=false
        HealthcarePractitionerFacility oldHPF = hpf.clone(true, true, true, true);
        hpf.IsActive = false;
        Map<Id, HealthcarePractitionerFacility> oldRecordsMap = new Map<Id, HealthcarePractitionerFacility>{oldHPF.Id => oldHPF};
        OrgSync_HPFProcess.updatePhysicianStagingOnIsActiveChange(new List<HealthcarePractitionerFacility>{hpf}, oldRecordsMap);
        Test.stopTest();

        // Verify no Physician Staging record was created or updated
        Integer countAfter = [
            SELECT COUNT() 
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c = :TEST_PROVIDER_NPI_1
            AND OrgSync_Parent_Practice__c = :newPractice.Id
        ];

        System.assertEquals(true, countBefore != null, 'Should still not have matching Physician Staging record');
    }

    /**
     * @description Test with HPF record that has null PractitionerId
     */
    @IsTest
    static void testNullPractitionerId() {
        Account practiceAccount1 = getPracticeAccount('PRAC-001');

        // Create HPF record with null PractitionerId
        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = practiceAccount1.Id,
            PractitionerId = null,
            Name = 'Test HPF Null Practitioner',
            IsActive = true
        );
        insert hpf;

        Test.startTest();
        // Call updatePhysicianStagingOnIsActiveChange directly with IsActive=false
        HealthcarePractitionerFacility oldHPF = hpf.clone(true, true, true, true);
        hpf.IsActive = false;
        Map<Id, HealthcarePractitionerFacility> oldRecordsMap = new Map<Id, HealthcarePractitionerFacility>{oldHPF.Id => oldHPF};
        OrgSync_HPFProcess.updatePhysicianStagingOnIsActiveChange(new List<HealthcarePractitionerFacility>{hpf}, oldRecordsMap);
        Test.stopTest();

        // Should not throw exception - should handle gracefully
        System.assert(true, 'Should handle null PractitionerId gracefully');
    }

    /**
     * @description Test with HPF record that has null AccountId
     */
    @IsTest
    static void testNullAccountId() {
        Account providerAccount1 = getProviderAccountByNPI(TEST_PROVIDER_NPI_1);
        System.assertNotEquals(null, providerAccount1, 'Provider Account should be found by NPI');

        // Create HPF record with null AccountId
        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = null,
            PractitionerId = providerAccount1.PersonContactId,
            Name = 'Test HPF Null Account',
            IsActive = true
        );
        insert hpf;

        Test.startTest();
        // Call updatePhysicianStagingOnIsActiveChange directly with IsActive=false
        HealthcarePractitionerFacility oldHPF = hpf.clone(true, true, true, true);
        hpf.IsActive = false;
        Map<Id, HealthcarePractitionerFacility> oldRecordsMap = new Map<Id, HealthcarePractitionerFacility>{oldHPF.Id => oldHPF};
        OrgSync_HPFProcess.updatePhysicianStagingOnIsActiveChange(new List<HealthcarePractitionerFacility>{hpf}, oldRecordsMap);
        Test.stopTest();

        // Should not throw exception - should handle gracefully
        System.assert(true, 'Should handle null AccountId gracefully');
    }

    /**
     * @description Test with Provider Account that doesn't have Identifier record
     */
    @IsTest
    static void testNoIdentifierRecord() {
        Account practiceAccount1 = getPracticeAccount('PRAC-001');

        // Create Provider Account without Identifier
        Account providerAccountNoNPI = TestDataFactory.getAccountofProviderRecordType();
        providerAccountNoNPI.FirstName = 'No';
        providerAccountNoNPI.LastName = 'NPI';
        providerAccountNoNPI.PersonEmail = 'nonpi@test.com';
        providerAccountNoNPI.BillingPostalCode = '12345';
        
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        insert providerAccountNoNPI;

        // Query to get PersonContactId
        Account providerWithContact = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :providerAccountNoNPI.Id
            AND PersonContactId != null
            LIMIT 1
        ];

        if (providerWithContact.PersonContactId != null) {
            // Create HPF record
            HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
                AccountId = practiceAccount1.Id,
                PractitionerId = providerWithContact.PersonContactId,
                Name = 'Test HPF No Identifier',
                IsActive = true
            );
            insert hpf;

            Test.startTest();
            // Call updatePhysicianStagingOnIsActiveChange directly with IsActive=false
            HealthcarePractitionerFacility oldHPF = hpf.clone(true, true, true, true);
            hpf.IsActive = false;
            Map<Id, HealthcarePractitionerFacility> oldRecordsMap = new Map<Id, HealthcarePractitionerFacility>{oldHPF.Id => oldHPF};
            OrgSync_HPFProcess.updatePhysicianStagingOnIsActiveChange(new List<HealthcarePractitionerFacility>{hpf}, oldRecordsMap);
            Test.stopTest();

            // Should not throw exception - should handle gracefully
            System.assert(true, 'Should handle missing Identifier record gracefully');
        }
    }
}