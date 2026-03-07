/**
 * @description Test class for OrgSync_HandleHPFInsertion
 *              Tests the creation of OrgSync_Physician_Staging__c records
 *              when new HealthcarePractitionerFacility records are inserted
 * Created Date : Jan 30, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 30, 2026        Pradip Kokate           Initial Version
 * V1.1.0       Feb 23, 2026        Pradip Kokate           Updated for Provider Account-based Physician Stage creation
 */
@isTest
private class OrgSync_HandleHPFInsertion_Test {

    private static final String TEST_PROVIDER_NPI_1 = '1234567890';
    private static final String TEST_PROVIDER_NPI_2 = '0987654321';
    private static final String TEST_PROVIDER_NPI_3 = '1122334455';
    private static final String TEST_PROVIDER_NPI_4 = '5555555555';

    /**
     * @description Test setup - creates test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // XCDC_OrgSettings__c required for composite External ID generation
        XCDC_OrgSettings__c orgSetting = XCDC_OrgSettings__c.getOrgDefaults();
        if (orgSetting == null) {
            orgSetting = new XCDC_OrgSettings__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        orgSetting.ExternalIdOrgprefix__c = 'SRC';
        upsert orgSetting;

        // Create Practice Accounts using factory
        List<Account> practiceAccounts = new List<Account>();
        practiceAccounts.add(OrgSync_TestDataFactory.createPracticeAccount('Test Practice 1', 'PRAC-001', '12345'));
        practiceAccounts.add(OrgSync_TestDataFactory.createPracticeAccount('Test Practice 2', 'PRAC-002', '12346'));
        practiceAccounts.add(OrgSync_TestDataFactory.createPracticeAccount('Test Practice 3', 'PRAC-003', '12347'));
        Database.insert(practiceAccounts, OrgSync_TestDataFactory.getDMLOptions());

        // Create Provider Accounts using factory (FirstName=Provider1, LastName=Provider1, etc.)
        List<Id> successfulProviderAccountIds = OrgSync_TestDataFactory.createAndInsertProviderAccounts(
            4, 'Provider', 'Provider', 'provider@test.com'
        );

        // Create Identifier records for NPI (fallback when Custom_UniqueID__c is blank)
        List<String> npiValues = new List<String>{
            TEST_PROVIDER_NPI_1,
            TEST_PROVIDER_NPI_2,
            TEST_PROVIDER_NPI_3,
            TEST_PROVIDER_NPI_4
        };
        OrgSync_TestDataFactory.createAndInsertIdentifierRecords(successfulProviderAccountIds, npiValues);
    }

    /**
     * @description Test creating new Physician Staging record when HPF is inserted.
     *              Physician Stage is created from Provider Account (Provider1, Provider1).
     */
    @isTest
    static void testCreatePhysicianStageForNewHPF() {
        Account practice2 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-002' LIMIT 1];
        Account providerAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE PersonEmail = 'provider1@test.com'
            LIMIT 1
        ];

        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = practice2.Id,
            PractitionerId = providerAccount.PersonContactId,
            Name = 'Test HPF New',
            IsActive = true
        );

        Test.startTest();
        insert hpf;
        Test.stopTest();

        List<OrgSync_Physician_Staging__c> createdStages = [
            SELECT Id, OrgSync_NPI__c, OrgSync_Parent_Practice__c, OrgSync_Do_Not_Use__c,
                   OrgSync_FirstName__c, OrgSync_LastName__c, XCDC_ExternalId__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_Parent_Practice__c = :practice2.Id
            AND OrgSync_NPI__c = :TEST_PROVIDER_NPI_1
        ];

        System.assertEquals(1, createdStages.size(), 'Should create one Physician Staging record');
        System.assertEquals(TEST_PROVIDER_NPI_1, createdStages[0].OrgSync_NPI__c, 'NPI should match');
        System.assertEquals(practice2.Id, createdStages[0].OrgSync_Parent_Practice__c, 'Practice should match');
        System.assertEquals(false, createdStages[0].OrgSync_Do_Not_Use__c, 'Do Not Use should be opposite of IsActive');
        System.assertNotEquals(null, createdStages[0].XCDC_ExternalId__c, 'External ID should be set');
        // Composite External ID format: prefix-providerId-practiceId
        System.assert(createdStages[0].XCDC_ExternalId__c.contains(String.valueOf(providerAccount.Id)), 
            'External ID should contain provider Account Id');
        System.assert(createdStages[0].XCDC_ExternalId__c.contains(String.valueOf(practice2.Id)), 
            'External ID should contain practice Account Id');
        // Fields mapped from Provider Account (Provider1, Provider1)
        System.assertEquals('Provider1', createdStages[0].OrgSync_FirstName__c, 'First Name should be from Provider Account');
        System.assertEquals('Provider1', createdStages[0].OrgSync_LastName__c, 'Last Name should be from Provider Account');
    }

    /**
     * @description Test that Physician Staging record IS created for each HPF insert,
     *              even when a record already exists for same practice+NPI (one per provider-practice HPF)
     */
    @isTest
    static void testCreatePhysicianStagePerHPF() {
        Account practice1 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-001' LIMIT 1];
        Account providerAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE PersonEmail = 'provider1@test.com'
            LIMIT 1
        ];

        // Count existing records for practice1 + NPI 1
        Integer countBefore = [
            SELECT COUNT()
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_Parent_Practice__c = :practice1.Id
            AND OrgSync_NPI__c = :TEST_PROVIDER_NPI_1
        ];

        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = practice1.Id,
            PractitionerId = providerAccount.PersonContactId,
            Name = 'Test HPF',
            IsActive = true
        );

        Test.startTest();
        insert hpf;
        Test.stopTest();

        Integer countAfter = [
            SELECT COUNT()
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_Parent_Practice__c = :practice1.Id
            AND OrgSync_NPI__c = :TEST_PROVIDER_NPI_1
        ];

        System.assertEquals(countBefore + 1, countAfter, 'Should create one Physician Staging record per HPF insert');
    }

    /**
     * @description Test bulk HPF insertions
     */
    @isTest
    static void testBulkHPFInsertion() {
        // Get test data
        Account practice2 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-002' LIMIT 1];
        Account practice3 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-003' LIMIT 1];
        
        List<Account> providerAccounts = [
            SELECT Id, PersonContactId 
            FROM Account 
            WHERE PersonEmail IN ('provider2@test.com', 'provider3@test.com', 'provider4@test.com')
        ];
        
        // Create multiple HPF records
        List<HealthcarePractitionerFacility> hpfRecords = new List<HealthcarePractitionerFacility>();
        hpfRecords.add(new HealthcarePractitionerFacility(
            AccountId = practice2.Id,
            PractitionerId = providerAccounts[0].PersonContactId,
            Name = 'Bulk HPF 1',
            IsActive = true
        ));
        hpfRecords.add(new HealthcarePractitionerFacility(
            AccountId = practice3.Id,
            PractitionerId = providerAccounts[1].PersonContactId,
            Name = 'Bulk HPF 2',
            IsActive = false
        ));
        hpfRecords.add(new HealthcarePractitionerFacility(
            AccountId = practice2.Id,
            PractitionerId = providerAccounts[2].PersonContactId,
            Name = 'Bulk HPF 3',
            IsActive = true
        ));
        
        Test.startTest();
        insert hpfRecords;
        Test.stopTest();
        
        // Verify all Physician Staging records were created
        List<OrgSync_Physician_Staging__c> createdStages = [
            SELECT Id, OrgSync_NPI__c, OrgSync_Parent_Practice__c, OrgSync_Do_Not_Use__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_Parent_Practice__c IN (:practice2.Id, :practice3.Id)
        ];
        
        System.assertEquals(3, createdStages.size(), 'Should create 3 Physician Staging records');
        
        // Verify Do Not Use is set correctly (opposite of IsActive)
        for (OrgSync_Physician_Staging__c stage : createdStages) {
            if (stage.OrgSync_Parent_Practice__c == practice3.Id) {
                System.assertEquals(true, stage.OrgSync_Do_Not_Use__c, 
                    'Do Not Use should be true when IsActive is false');
            } else {
                System.assertEquals(false, stage.OrgSync_Do_Not_Use__c, 
                    'Do Not Use should be false when IsActive is true');
            }
        }
    }

    /**
     * @description Test that Physician Staging record IS created when Provider has no NPI
     *              (NPI from Identifier/Custom_UniqueID__c may be null; record is still created from Provider Account)
     */
    @isTest
    static void testPhysicianStageCreatedWhenNoNPI() {
        Account practice2 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-002' LIMIT 1];
        Account providerAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE PersonEmail = 'provider1@test.com'
            LIMIT 1
        ];

        // Delete Identifier to simulate no NPI (Custom_UniqueID__c on Account is also typically blank)
        List<Identifier> identifiers = [
            SELECT Id
            FROM Identifier
            WHERE ParentRecordId = :providerAccount.Id
            AND IdUsageType = :ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
        ];
        delete identifiers;

        Integer countBefore = [
            SELECT COUNT()
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_Parent_Practice__c = :practice2.Id
        ];

        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = practice2.Id,
            PractitionerId = providerAccount.PersonContactId,
            Name = 'Test HPF No NPI',
            IsActive = true
        );

        Test.startTest();
        insert hpf;
        Test.stopTest();

        Integer countAfter = [
            SELECT COUNT()
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_Parent_Practice__c = :practice2.Id
        ];

        System.assertEquals(countBefore + 1, countAfter, 'Should create Physician Staging record from Provider Account even when NPI is null');
    }

    /**
     * @description Test that no Physician Staging record is created when HPF has null PractitionerId
     */
    @isTest
    static void testNoPhysicianStageWhenNullPractitionerId() {
        // Get test data
        Account practice2 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-002' LIMIT 1];
        
        // Count before
        Integer countBefore = [
            SELECT COUNT() 
            FROM OrgSync_Physician_Staging__c 
            WHERE OrgSync_Parent_Practice__c = :practice2.Id
        ];
        
        // Create HPF record with null PractitionerId
        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = practice2.Id,
            PractitionerId = null,
            Name = 'Test HPF No Practitioner',
            IsActive = true
        );
        
        Test.startTest();
        insert hpf;
        Test.stopTest();
        
        // Verify no Physician Staging record was created
        Integer countAfter = [
            SELECT COUNT() 
            FROM OrgSync_Physician_Staging__c 
            WHERE OrgSync_Parent_Practice__c = :practice2.Id
        ];
        
        System.assertEquals(countBefore, countAfter, 
            'Should not create Physician Staging record when PractitionerId is null');
    }

    /**
     * @description Test field mapping from Provider Account to Physician Staging record
     */
    @isTest
    static void testFieldMappingFromProviderAccount() {
        Account practice2 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-002' LIMIT 1];
        Account providerAccount = [
            SELECT Id, PersonContactId, FirstName, LastName
            FROM Account
            WHERE PersonEmail = 'provider2@test.com'
            LIMIT 1
        ];

        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = practice2.Id,
            PractitionerId = providerAccount.PersonContactId,
            Name = 'Test HPF Field Mapping',
            IsActive = true
        );

        Test.startTest();
        insert hpf;
        Test.stopTest();

        OrgSync_Physician_Staging__c createdStage = [
            SELECT OrgSync_FirstName__c, OrgSync_LastName__c, OrgSync_NPI__c, OrgSync_Parent_Practice__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_Parent_Practice__c = :practice2.Id
            AND OrgSync_NPI__c = :TEST_PROVIDER_NPI_2
            LIMIT 1
        ];

        System.assertEquals(providerAccount.FirstName, createdStage.OrgSync_FirstName__c,
            'First Name should be mapped from Provider Account');
        System.assertEquals(providerAccount.LastName, createdStage.OrgSync_LastName__c,
            'Last Name should be mapped from Provider Account');
        System.assertEquals(TEST_PROVIDER_NPI_2, createdStage.OrgSync_NPI__c, 'NPI should match');
        System.assertEquals(practice2.Id, createdStage.OrgSync_Parent_Practice__c, 'Practice should match');
    }

    /**
     * @description Test that method handles null input gracefully
     */
    @isTest
    static void testHandleNullInput() {
        Test.startTest();
        OrgSync_HandleHPFInsertion.handleHPFInsertion(null);
        OrgSync_HandleHPFInsertion.handleHPFInsertion(new List<HealthcarePractitionerFacility>());
        Test.stopTest();
        
        // Should complete without errors
        System.assert(true, 'Should handle null and empty list gracefully');
    }

    /**
     * @description Test that method handles HPF with null AccountId gracefully
     */
    @isTest
    static void testHandleNullAccountId() {
        Account providerAccount = [
            SELECT Id, PersonContactId 
            FROM Account 
            WHERE PersonEmail = 'provider1@test.com' 
            LIMIT 1
        ];
        
        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = null,
            PractitionerId = providerAccount.PersonContactId,
            Name = 'Test HPF Null Account',
            IsActive = true
        );
        
        Test.startTest();
        insert hpf;
        Test.stopTest();
        
        // Should complete without errors
        System.assert(true, 'Should handle null AccountId gracefully');
    }

    /**
     * @description Test that no Physician Staging is created when OrgSync user creates HPF (early return).
     */
    @isTest
    static void testHandleHPFInsertionSkipsWhenOrgSyncUser() {
        OrgSync_UtilityService.orgSyncUserId = UserInfo.getUserId();
        Account practice2 = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-002' LIMIT 1];
        Account providerAccount = [SELECT Id, PersonContactId FROM Account WHERE PersonEmail = 'provider1@test.com' LIMIT 1];

        Integer countBefore = [SELECT COUNT() FROM OrgSync_Physician_Staging__c WHERE OrgSync_Parent_Practice__c = :practice2.Id];

        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = practice2.Id,
            PractitionerId = providerAccount.PersonContactId,
            Name = 'Test HPF OrgSync Skip',
            IsActive = true
        );

        Test.startTest();
        OrgSync_HandleHPFInsertion.handleHPFInsertion(new List<HealthcarePractitionerFacility>{ hpf });
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM OrgSync_Physician_Staging__c WHERE OrgSync_Parent_Practice__c = :practice2.Id];
        System.assertEquals(countBefore, countAfter, 'Should not create staging when OrgSync user');
    }
}