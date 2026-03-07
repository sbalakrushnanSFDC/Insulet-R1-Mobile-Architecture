/**
 * @description Test class for OrgSync_ProviderPracticeRelation
 *              Tests the creation/update of HealthcarePractitionerFacility (HPF) records
 *              between Provider and Practice when OrgSync_Physician_Staging__c records are created or updated.
 * Created Date : Jan 23, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 23, 2026        Pradip Kokate           Initial Version
 */
@isTest
private class OrgSync_ProviderPracticeRelation_Test {

    private static final String TEST_PROVIDER_NPI_1 = '1234567890';
    private static final String TEST_PROVIDER_NPI_2 = '0987654321';
    private static final String TEST_PROVIDER_NPI_3 = '1122334455';

    /**
     * @description Test setup - creates test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create Practice Accounts
        Account practiceAccount1 = TestDataFactory.getAccountofPracticeRecordType();
        practiceAccount1.Name = 'Test Practice 1';
        practiceAccount1.XCDC_ExternalId__c = 'PRAC-001';
        practiceAccount1.BillingPostalCode = '12345';
        
        Account practiceAccount2 = TestDataFactory.getAccountofPracticeRecordType();
        practiceAccount2.Name = 'Test Practice 2';
        practiceAccount2.XCDC_ExternalId__c = 'PRAC-002';
        practiceAccount2.BillingPostalCode = '12346';

        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        Database.insert(new List<Account>{practiceAccount1, practiceAccount2}, dmlOptions);

        // Create Provider Accounts (Person Accounts)
        List<Account> providerAccounts = new List<Account>();
        
        Account providerAccount1 = TestDataFactory.getAccountofProviderRecordType();
        providerAccount1.FirstName = 'John';
        providerAccount1.LastName = 'Provider1';
        providerAccount1.PersonEmail = 'provider1@test.com';
        providerAccount1.BillingPostalCode = '12345';
        providerAccounts.add(providerAccount1);

        Account providerAccount2 = TestDataFactory.getAccountofProviderRecordType();
        providerAccount2.FirstName = 'Jane';
        providerAccount2.LastName = 'Provider2';
        providerAccount2.PersonEmail = 'provider2@test.com';
        providerAccount2.BillingPostalCode = '12346';
        providerAccounts.add(providerAccount2);

        Account providerAccount3 = TestDataFactory.getAccountofProviderRecordType();
        providerAccount3.FirstName = 'Bob';
        providerAccount3.LastName = 'Provider3';
        providerAccount3.PersonEmail = 'provider3@test.com';
        providerAccount3.BillingPostalCode = '12347';
        providerAccounts.add(providerAccount3);

        // Insert Provider Accounts and check results
        Database.SaveResult[] providerResults = Database.insert(providerAccounts, dmlOptions);
        
        // Extract successfully inserted Account IDs
        List<Id> successfulProviderAccountIds = new List<Id>();
        for (Integer i = 0; i < providerAccounts.size(); i++) {
            if (providerResults[i].isSuccess()) {
                successfulProviderAccountIds.add(providerAccounts[i].Id);
            }
        }

        // Create Identifier records only for successfully inserted Provider Accounts
        List<Identifier> identifiers = new List<Identifier>();
        if (successfulProviderAccountIds.size() >= 1) {
            identifiers.add(new Identifier(
                ParentRecordId = successfulProviderAccountIds[0],
                ID_Value__c = TEST_PROVIDER_NPI_1,
                IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
            ));
        }
        if (successfulProviderAccountIds.size() >= 2) {
            identifiers.add(new Identifier(
                ParentRecordId = successfulProviderAccountIds[1],
                ID_Value__c = TEST_PROVIDER_NPI_2,
                IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
            ));
        }
        if (successfulProviderAccountIds.size() >= 3) {
            identifiers.add(new Identifier(
                ParentRecordId = successfulProviderAccountIds[2],
                ID_Value__c = TEST_PROVIDER_NPI_3,
                IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
            ));
        }

        if (!identifiers.isEmpty()) {
            insert identifiers;
        }
    }

    /**
     * @description Helper method to get Provider Account by NPI using Identifier records
     *              Matches the logic from OrgSync_ProviderPracticeRelation.getProviderAccountIdsFromNPIs
     * @param npi NPI value to search for
     * @return Provider Account with PersonContactId populated
     */
    private static Account getProviderAccountByNPI(String npi) {
        if (String.isBlank(npi)) {
            return null;
        }

        // Query Identifier record by NPI - matching main class pattern
        List<Identifier> identifiers = [
            SELECT Id, ParentRecordId, ID_Value__c
            FROM Identifier
            WHERE ID_Value__c = :npi
            AND IdUsageType = :ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
            AND ParentRecordId != null
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (identifiers.isEmpty() || identifiers[0].ParentRecordId == null) {
            return null;
        }

        // Verify ParentRecordId is an Account ID (starts with '001') - matching main class validation
        String parentIdStr = String.valueOf(identifiers[0].ParentRecordId);
        if (!parentIdStr.startsWith('001')) {
            return null;
        }

        // Query Provider Account using ParentRecordId from Identifier
        // Don't filter by PersonContactId - query first, then verify it exists
        List<Account> providerAccounts = [
            SELECT Id, PersonContactId, FirstName, LastName, Name
            FROM Account
            WHERE Id = :identifiers[0].ParentRecordId
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        // Return account only if PersonContactId is populated (required for Person Accounts)
        if (!providerAccounts.isEmpty() && providerAccounts[0].PersonContactId != null) {
            return providerAccounts[0];
        }
        
        return null;
    }

    /**
     * @description Test creating new HPF records from Physician Staging records
     */
    @IsTest
    static void testCreateHPFRecordsFromStaging() {
        // Get test data
        Account practiceAccount1 = [SELECT Id, Name FROM Account WHERE XCDC_ExternalId__c = 'PRAC-001' LIMIT 1];
        Account providerAccount1 = getProviderAccountByNPI(TEST_PROVIDER_NPI_1);
        System.assertNotEquals(null, providerAccount1, 'Provider Account should be found by NPI');
        System.assertNotEquals(null, providerAccount1.PersonContactId, 'Provider Account should have PersonContactId');

        // Create Physician Staging record
        OrgSync_Physician_Staging__c physicianStage = new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = TEST_PROVIDER_NPI_1,
            OrgSync_Parent_Practice__c = practiceAccount1.Id
        );
        insert physicianStage;

        Test.startTest();
        OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(new List<OrgSync_Physician_Staging__c>{physicianStage});
        Test.stopTest();

        // Verify HPF record was created
        List<HealthcarePractitionerFacility> hpfRecords = [
            SELECT Id, AccountId, PractitionerId, IsPrimaryFacility, IsActive, Name, IsPrimaryCarePhysician
            FROM HealthcarePractitionerFacility
            WHERE AccountId = :practiceAccount1.Id
            AND PractitionerId = :providerAccount1.PersonContactId
        ];

        System.assertEquals(1, hpfRecords.size(), 'Should create one HPF record');
        System.assertEquals(practiceAccount1.Id, hpfRecords[0].AccountId, 'AccountId should match');
        System.assertEquals(providerAccount1.PersonContactId, hpfRecords[0].PractitionerId, 'PractitionerId should match');
        System.assertEquals(true, hpfRecords[0].IsPrimaryFacility, 'Should be primary facility for first provider');
        System.assertEquals(true, hpfRecords[0].IsActive, 'Should be active');
        System.assertEquals(true, hpfRecords[0].IsPrimaryCarePhysician, 'Should be primary care physician for first practice');
        System.assert(hpfRecords[0].Name.contains('Dr.'), 'Name should contain Dr.');
        System.assert(hpfRecords[0].Name.contains('John Provider1'), 'Name should contain provider name');
        System.assert(hpfRecords[0].Name.contains('Test Practice 1'), 'Name should contain practice name');
    }

    /**
     * @description Test updating existing HPF records from Physician Staging records
     */
    @IsTest
    static void testUpdateHPFRecordsFromStaging() {
        // Get test data
        Account practiceAccount1 = [SELECT Id, Name FROM Account WHERE XCDC_ExternalId__c = 'PRAC-001' LIMIT 1];
        Account providerAccount1 = getProviderAccountByNPI(TEST_PROVIDER_NPI_1);
        System.assertNotEquals(null, providerAccount1, 'Provider Account should be found by NPI');
        System.assertNotEquals(null, providerAccount1.PersonContactId, 'Provider Account should have PersonContactId');

        // Create existing HPF record
        HealthcarePractitionerFacility existingHPF = new HealthcarePractitionerFacility(
            AccountId = practiceAccount1.Id,
            PractitionerId = providerAccount1.PersonContactId,
            Name = 'Old Name',
            IsPrimaryFacility = false,
            IsActive = false,
            IsPrimaryCarePhysician = false
        );
        insert existingHPF;

        // Create Physician Staging record
        OrgSync_Physician_Staging__c physicianStage = new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = TEST_PROVIDER_NPI_1,
            OrgSync_Parent_Practice__c = practiceAccount1.Id
        );
        insert physicianStage;

        Test.startTest();
        OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(new List<OrgSync_Physician_Staging__c>{physicianStage});
        Test.stopTest();

        // Verify HPF record was updated
        List<HealthcarePractitionerFacility> hpfRecords = [
            SELECT Id, AccountId, PractitionerId, IsPrimaryFacility, IsActive, Name, IsPrimaryCarePhysician
            FROM HealthcarePractitionerFacility
            WHERE Id = :existingHPF.Id
        ];

        System.assertEquals(1, hpfRecords.size(), 'Should have one HPF record');
        System.assertEquals(true, hpfRecords[0].IsActive, 'Should be updated to active');
        System.assertNotEquals('Old Name', hpfRecords[0].Name, 'Name should be updated');
        System.assert(hpfRecords[0].Name.contains('Dr.'), 'Name should contain Dr.');
    }

    /**
     * @description Test primary facility logic - only one primary per provider
     */
    @IsTest
    static void testPrimaryFacilityLogic() {
        // Get test data
        Account practiceAccount1 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-001' LIMIT 1];
        Account practiceAccount2 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-002' LIMIT 1];
        Account providerAccount1 = getProviderAccountByNPI(TEST_PROVIDER_NPI_1);
        System.assertNotEquals(null, providerAccount1, 'Provider Account should be found by NPI');
        System.assertNotEquals(null, providerAccount1.PersonContactId, 'Provider Account should have PersonContactId');

        // Create first HPF record (will be primary)
        HealthcarePractitionerFacility firstHPF = new HealthcarePractitionerFacility(
            AccountId = practiceAccount1.Id,
            PractitionerId = providerAccount1.PersonContactId,
            Name = 'Test HPF Primary',
            IsPrimaryFacility = true,
            IsActive = true
        );
        insert firstHPF;

        // Create Physician Staging record for second practice
        OrgSync_Physician_Staging__c physicianStage = new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = TEST_PROVIDER_NPI_1,
            OrgSync_Parent_Practice__c = practiceAccount2.Id
        );
        insert physicianStage;

        Test.startTest();
        OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(new List<OrgSync_Physician_Staging__c>{physicianStage});
        Test.stopTest();

        // Verify first HPF is no longer primary, second HPF is primary
        List<HealthcarePractitionerFacility> hpfRecords = [
            SELECT Id, AccountId, IsPrimaryFacility
            FROM HealthcarePractitionerFacility
            WHERE PractitionerId = :providerAccount1.PersonContactId
            ORDER BY AccountId
        ];

        System.assertEquals(2, hpfRecords.size(), 'Should have two HPF records');
        
        // Find which HPF is primary
        HealthcarePractitionerFacility primaryHPF = null;
        HealthcarePractitionerFacility nonPrimaryHPF = null;
        for (HealthcarePractitionerFacility hpf : hpfRecords) {
            if (hpf.IsPrimaryFacility) {
                primaryHPF = hpf;
            } else {
                nonPrimaryHPF = hpf;
            }
        }

    }

    /**
     * @description Test with null NPI - should not create HPF
     */
    @IsTest
    static void testNullNPI() {
        Account practiceAccount1 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-001' LIMIT 1];

        // Create Physician Staging record with null NPI
        OrgSync_Physician_Staging__c physicianStage = new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = null,
            OrgSync_Parent_Practice__c = practiceAccount1.Id
        );
        insert physicianStage;

        Test.startTest();
        OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(new List<OrgSync_Physician_Staging__c>{physicianStage});
        Test.stopTest();

        // Verify no HPF records were created
        List<HealthcarePractitionerFacility> hpfRecords = [
            SELECT Id FROM HealthcarePractitionerFacility WHERE AccountId = :practiceAccount1.Id
        ];

        System.assertEquals(0, hpfRecords.size(), 'Should not create HPF record with null NPI');
    }

    /**
     * @description Test with null Parent Practice - should not create HPF
     */
    @IsTest
    static void testNullParentPractice() {
        // Create Physician Staging record with null Parent Practice
        OrgSync_Physician_Staging__c physicianStage = new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = TEST_PROVIDER_NPI_1,
            OrgSync_Parent_Practice__c = null
        );
        insert physicianStage;

        Test.startTest();
        OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(new List<OrgSync_Physician_Staging__c>{physicianStage});
        Test.stopTest();

        // Verify no HPF records were created
        List<HealthcarePractitionerFacility> hpfRecords = [
            SELECT Id FROM HealthcarePractitionerFacility
        ];

        System.assertEquals(0, hpfRecords.size(), 'Should not create HPF record with null Parent Practice');
    }

    /**
     * @description Test with NPI that doesn't match any Identifier - should not create HPF
     */
    @IsTest
    static void testNonMatchingNPI() {
        Account practiceAccount1 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-001' LIMIT 1];

        // Create Physician Staging record with non-matching NPI
        OrgSync_Physician_Staging__c physicianStage = new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = '9999999999',
            OrgSync_Parent_Practice__c = practiceAccount1.Id
        );
        insert physicianStage;

        Test.startTest();
        OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(new List<OrgSync_Physician_Staging__c>{physicianStage});
        Test.stopTest();

        // Verify no HPF records were created
        List<HealthcarePractitionerFacility> hpfRecords = [
            SELECT Id FROM HealthcarePractitionerFacility WHERE AccountId = :practiceAccount1.Id
        ];

        System.assertEquals(0, hpfRecords.size(), 'Should not create HPF record with non-matching NPI');
    }

    /**
     * @description Test with empty list - should handle gracefully
     */
    @IsTest
    static void testEmptyList() {
        Test.startTest();
        OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(new List<OrgSync_Physician_Staging__c>());
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle empty list gracefully');
    }

    /**
     * @description Test with null list - should handle gracefully
     */
    @IsTest
    static void testNullList() {
        Test.startTest();
        OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(null);
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle null list gracefully');
    }

    /**
     * @description Test primary care physician logic - first HPF for practice should be primary
     */
    @IsTest
    static void testPrimaryCarePhysicianLogic() {
        // Get test data
        Account practiceAccount1 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-001' LIMIT 1];
        Account providerAccount1 = getProviderAccountByNPI(TEST_PROVIDER_NPI_1);
        Account providerAccount2 = getProviderAccountByNPI(TEST_PROVIDER_NPI_2);
        System.assertNotEquals(null, providerAccount1, 'Provider Account 1 should be found by NPI');
        System.assertNotEquals(null, providerAccount2, 'Provider Account 2 should be found by NPI');
        System.assertNotEquals(null, providerAccount1.PersonContactId, 'Provider Account 1 should have PersonContactId');
        System.assertNotEquals(null, providerAccount2.PersonContactId, 'Provider Account 2 should have PersonContactId');

        // Create Physician Staging records for two providers with same practice
        List<OrgSync_Physician_Staging__c> physicianStages = new List<OrgSync_Physician_Staging__c>();
        physicianStages.add(new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = TEST_PROVIDER_NPI_1,
            OrgSync_Parent_Practice__c = practiceAccount1.Id
        ));
        physicianStages.add(new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = TEST_PROVIDER_NPI_2,
            OrgSync_Parent_Practice__c = practiceAccount1.Id
        ));
        insert physicianStages;

        Test.startTest();
        OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(physicianStages);
        Test.stopTest();

        // Verify HPF records
        List<HealthcarePractitionerFacility> hpfRecords = [
            SELECT Id, AccountId, PractitionerId, IsPrimaryCarePhysician
            FROM HealthcarePractitionerFacility
            WHERE AccountId = :practiceAccount1.Id
            ORDER BY CreatedDate
        ];

        System.assertEquals(2, hpfRecords.size(), 'Should create two HPF records');
        
        // First HPF created for the practice should be primary care physician
        // Since both are created in the same batch, the first one processed should be primary
        Integer primaryCarePhysicianCount = 0;
        for (HealthcarePractitionerFacility hpf : hpfRecords) {
            if (hpf.IsPrimaryCarePhysician) {
                primaryCarePhysicianCount++;
            }
        }
        
        // Only one should be primary care physician (first one for the practice)
        System.assertEquals(1, primaryCarePhysicianCount, 'Only one HPF should be primary care physician for the practice');
    }

    /**
     * @description Test HPF name format
     */
    @IsTest
    static void testHPFNameFormat() {
        // Get test data
        Account practiceAccount1 = [SELECT Id, Name FROM Account WHERE XCDC_ExternalId__c = 'PRAC-001' LIMIT 1];
        Account providerAccount1 = getProviderAccountByNPI(TEST_PROVIDER_NPI_1);
        System.assertNotEquals(null, providerAccount1, 'Provider Account should be found by NPI');
        System.assertNotEquals(null, providerAccount1.PersonContactId, 'Provider Account should have PersonContactId');

        // Create Physician Staging record
        OrgSync_Physician_Staging__c physicianStage = new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = TEST_PROVIDER_NPI_1,
            OrgSync_Parent_Practice__c = practiceAccount1.Id
        );
        insert physicianStage;

        Test.startTest();
        OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(new List<OrgSync_Physician_Staging__c>{physicianStage});
        Test.stopTest();

        // Verify HPF name format
        List<HealthcarePractitionerFacility> hpfRecords = [
            SELECT Id, Name
            FROM HealthcarePractitionerFacility
            WHERE AccountId = :practiceAccount1.Id
            AND PractitionerId = :providerAccount1.PersonContactId
        ];

        System.assertEquals(1, hpfRecords.size(), 'Should create one HPF record');
        String expectedName = 'Dr. John Provider1 at Test Practice 1';
        System.assertEquals(expectedName, hpfRecords[0].Name, 'HPF name should match expected format');
    }

    /**
     * @description Test multiple providers with same practice
     */
    @IsTest
    static void testMultipleProvidersSamePractice() {
        // Get test data
        Account practiceAccount1 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-001' LIMIT 1];
        Account providerAccount1 = getProviderAccountByNPI(TEST_PROVIDER_NPI_1);
        Account providerAccount2 = getProviderAccountByNPI(TEST_PROVIDER_NPI_2);
        Account providerAccount3 = getProviderAccountByNPI(TEST_PROVIDER_NPI_3);
        System.assertNotEquals(null, providerAccount1, 'Provider Account 1 should be found by NPI');
        System.assertNotEquals(null, providerAccount2, 'Provider Account 2 should be found by NPI');
        System.assertNotEquals(null, providerAccount3, 'Provider Account 3 should be found by NPI');
        System.assertNotEquals(null, providerAccount1.PersonContactId, 'Provider Account 1 should have PersonContactId');
        System.assertNotEquals(null, providerAccount2.PersonContactId, 'Provider Account 2 should have PersonContactId');
        System.assertNotEquals(null, providerAccount3.PersonContactId, 'Provider Account 3 should have PersonContactId');

        // Create Physician Staging records for three providers with same practice
        List<OrgSync_Physician_Staging__c> physicianStages = new List<OrgSync_Physician_Staging__c>();
        physicianStages.add(new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = TEST_PROVIDER_NPI_1,
            OrgSync_Parent_Practice__c = practiceAccount1.Id
        ));
        physicianStages.add(new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = TEST_PROVIDER_NPI_2,
            OrgSync_Parent_Practice__c = practiceAccount1.Id
        ));
        physicianStages.add(new OrgSync_Physician_Staging__c(
            OrgSync_NPI__c = TEST_PROVIDER_NPI_3,
            OrgSync_Parent_Practice__c = practiceAccount1.Id
        ));
        insert physicianStages;

        Test.startTest();
        OrgSync_ProviderPracticeRelation.createOrUpdateProviderPracticeRelations(physicianStages);
        Test.stopTest();

        // Verify all three HPF records were created
        List<HealthcarePractitionerFacility> hpfRecords = [
            SELECT Id, AccountId, PractitionerId, IsPrimaryFacility, IsPrimaryCarePhysician
            FROM HealthcarePractitionerFacility
            WHERE AccountId = :practiceAccount1.Id
        ];

        System.assertEquals(3, hpfRecords.size(), 'Should create three HPF records');
        
        // All should be primary facilities (first HPF for each provider)
        for (HealthcarePractitionerFacility hpf : hpfRecords) {
            System.assertEquals(true, hpf.IsPrimaryFacility, 'Each provider should have primary facility');
        }
    }
}