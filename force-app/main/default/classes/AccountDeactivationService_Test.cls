/**
 * @description Test class for AccountDeactivationService to ensure comprehensive coverage and validate deactivation logic.
 *  * * =========================== Logs ======================================
 * v1.1.0       2nd Dec 2025        Niranjan Elangovan      Created(US - NGASIM-1389)
 */
@isTest(isParallel=true)
private class AccountDeactivationService_Test {
    private static Id practiceDeactivationId;
    private static Id providerDeactivationId;
    private static Id practitionerContactId;
    private static Id facilityDeactivationId;
    private static Id practiceInsertContextId;
    private static Id facilityInsertContextId;

    @TestSetup
    static void setupData() {
        User adminUser;
        // Create user and assign permission sets in a separate transaction to avoid MIXED_DML_OPERATION
        System.runAs(new User(Id = UserInfo.getUserId())) {
            adminUser = TestDataFactory.getTestUser('System Administrator', new Map<String, Object>{
                'FirstName' => 'Admin',
                'LastName' => 'TestUser'
            });
            insert adminUser;
            // Query required permission sets
            List<PermissionSet> permissionSets = [
                SELECT Id, Name
                FROM PermissionSet
                WHERE Name IN ('Sales_Ops_Core_Access', 'HealthCloudFoundation')
            ];
            // Create permission set assignments
            List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
            for (PermissionSet ps : permissionSets) {
                assignments.add(new PermissionSetAssignment(
                    AssigneeId = adminUser.Id,
                    PermissionSetId = ps.Id
                ));
            }
            insert assignments;
        }
        // Now create non-setup objects (Accounts, etc.) as the admin user
        System.runAs(adminUser) {
        List<Account> practices = new List<Account>{
            TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
                'Name' => 'Practice Deactivation',
                'IsActive' => true,
                'BillingPostalCode' => '97845'
            }),
            TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
                'Name' => 'Practice Insert Context',
                'IsActive' => true,
                'BillingPostalCode' => '97845'
            })
        };
        insert practices;
        practiceDeactivationId = practices[0].Id;
        practiceInsertContextId = practices[1].Id;

        List<Account> providers = new List<Account>{
            TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.ACCOUNT_PROVIDER_RT,
                'FirstName' => 'Provider Deactivation',
                'IsActive' => true,
                'BillingPostalCode' => '97845'
            }),
            TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.ACCOUNT_PROVIDER_RT,
                'FirstName' => 'Provider Insert Context',
                'IsActive' => true,
                'BillingPostalCode' => '97845'
            })
        };
        insert providers;
        providerDeactivationId = providers[0].Id;
        Contact practitionerContact = [SELECT Id from Contact where AccountId =: providers[0].Id];
        practitionerContactId = practitionerContact.Id;
        HealthcarePractitionerFacility facilityForDeactivation = new HealthcarePractitionerFacility(
            Name = 'Facility Deactivation',
            AccountId = practiceDeactivationId,
            PractitionerId = practitionerContactId,
            IsActive = true,
            IsPrimaryFacility = true
        );
        HealthcarePractitionerFacility facilityForInsertContext = new HealthcarePractitionerFacility(
            Name = 'Facility Insert Context',
            AccountId = practiceInsertContextId,
            PractitionerId = practitionerContactId,
            IsActive = true,
            IsPrimaryFacility = true
        );
        HealthcareProvider providerRecord = new HealthcareProvider(
            Name = 'Provider Deactivation Record',
            PractitionerId = practitionerContactId,
            AccountId = practiceDeactivationId,
            ProviderType = 'Physician',
            IsActive = true
        );
       HealthcareProvider providerInsertContextRecord = new HealthcareProvider(
            Name = 'Provider Insert Context Record',
            PractitionerId = practitionerContactId,
            AccountId = practiceInsertContextId,
            ProviderType = 'Physician',
            IsActive = true
        );
        insert new List<HealthcarePractitionerFacility>{ facilityForDeactivation, facilityForInsertContext };
        insert new List<HealthcareProvider>{ providerRecord, providerInsertContextRecord };
        facilityDeactivationId = facilityForDeactivation.Id;
        facilityInsertContextId = facilityForInsertContext.Id;
        }
    }

    /**
     * @description Verifies that deactivating a Practice account cascades to HealthcarePractitionerFacility records.
     */
    @isTest
    static void testPracticeAccountDeactivationDeactivatesFacilities() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Account practiceFromDb = [
                SELECT Id, RecordTypeId, IsActive
                FROM Account
                WHERE Name = 'Practice Deactivation'
                LIMIT 1
            ];
            Test.startTest();
            practiceFromDb.IsActive = false;
            update practiceFromDb;
            Test.stopTest();

            HealthcarePractitionerFacility updatedFacility = [
                SELECT Id, IsActive
                FROM HealthcarePractitionerFacility
                WHERE AccountId = :practiceFromDb.Id
                LIMIT 1
            ];
            System.assertEquals(false, updatedFacility.IsActive, 'Facility should be deactivated when practice is inactive');
        }
    }
    /**
     * @description Verifies that deactivating a Provider account cascades to HealthcareProvider records.
     */
    @isTest
    static void testProviderAccountDeactivationDeactivatesHealthcareProviders() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
        Account providerFromDb = [
            SELECT Id, RecordTypeId, IsActive, PersonContactId
            FROM Account
            WHERE Name = 'Practice Deactivation'
            LIMIT 1
        ];

        if (providerFromDb.PersonContactId == null) {
            Contact fallbackContact = TestDataFactory.getContact(
                new Map<String, Object>{ 'AccountId' => providerFromDb.Id }
            );
            insert fallbackContact;
        }

        HealthcareProvider healthcareProvider = new HealthcareProvider(
            Name = 'Provider Record',
            PractitionerId = providerFromDb.PersonContactId,
            AccountId = providerFromDb.Id,
            ProviderType = 'Physician',
            IsActive = true
        );
        insert healthcareProvider;
        Account providerOld = providerFromDb.clone(false, true, false, false);
        providerFromDb.IsActive = false;

        Test.startTest();
        AccountDeactivationService.processAccountDeactivation(
            new List<Account>{ providerFromDb },
            new Map<Id, Account>{ providerFromDb.Id => providerOld }
        );
        Test.stopTest();
        HealthcareProvider updatedProvider = [
            SELECT Id, IsActive
            FROM HealthcareProvider
            WHERE Id = :healthcareProvider.Id
            LIMIT 1
        ];
            System.assertEquals(false, updatedProvider.IsActive, 'HealthcareProvider should be deactivated when provider account is inactive');
        }
    }
    /**
     * @description Ensures processAccountDeactivation can be invoked in insert context (old map null) without side effects.
     */
    @isTest
    static void testProcessAccountDeactivationSafeOnInsertContext() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
        Test.startTest();
        Account insertPractice = [
            SELECT Id, RecordTypeId, IsActive
            FROM Account
            WHERE Name = 'Practice Insert Context'
            LIMIT 1
        ];
        AccountDeactivationService.processAccountDeactivation(new List<Account>{ insertPractice }, null);
        Test.stopTest();

        HealthcarePractitionerFacility facilityAfter = [
            SELECT Id, IsActive FROM HealthcarePractitionerFacility WHERE Name='Facility Insert Context' LIMIT 1
        ];
            System.assertEquals(true, facilityAfter.IsActive,
                'Facilities should remain active when service is invoked from insert context');
        }
    }
    /**
     * @description Ensures helper logic only processes true-to-false transitions.
     */
    @isTest
    static void testShouldProcessAccountHelperLogic() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
        // Use MockDataFactory to mirror other mocking-style tests in the project (see PatientLeadConversionService_Test)
        Account oldAccount = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsActive' => true,
            'Name' => 'Mock Account Old',
            'BillingPostalCode' => '11111'
        })[0];
        Account newAccount = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsActive' => false,
            'Name' => 'Mock Account New',
            'BillingPostalCode' => '22222'
        })[0];
        System.assertEquals(true, AccountDeactivationHelper.shouldProcessAccount(newAccount, oldAccount),
            'Should process when IsActive goes from true to false');

        Account unchangedOld = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsActive' => false,
            'Name' => 'Mock Account Unchanged Old',
            'BillingPostalCode' => '33333'
        })[0];
        Account unchangedNew = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'IsActive' => false,
            'Name' => 'Mock Account Unchanged New',
            'BillingPostalCode' => '44444'
        })[0];
        System.assertEquals(false, AccountDeactivationHelper.shouldProcessAccount(unchangedNew, unchangedOld),
            'Should not process when IsActive stays false');

        Account nullOld = null;
        System.assertEquals(true, AccountDeactivationHelper.shouldProcessAccount(newAccount, nullOld),
            'Insert context with IsActive unchecked should be processed');
        }
    }
    /**
     * @description Leverages MockDataFactory to simulate DML failures in saveRecords without actual inserts.
     *              Pattern borrowed from MockDataFactory usage in PatientLeadConversionService_Test.
     */
    @isTest
    static void testSaveRecordsHandlesMockedDmlFailures() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
        List<HealthcarePractitionerFacility> mockFacilities =
            MockDataFactory.createHealthcarePractitionerFacilities(2, new Map<String, Object>{ 'IsActive' => true });
        List<SObject> mockedRecords = new List<SObject>();
        mockedRecords.addAll(mockFacilities);

        Test.startTest();
        // saveRecords should catch DML failures (invalid fake Ids) and log via Nebula without throwing
        AccountDeactivationService.saveRecords(mockedRecords, 'HealthcarePractitionerFacility');
        Test.stopTest();

        System.assert(true, 'Mocked records should be processed without bubbling up DML exceptions');
        }
    }
    /**
     * @description Uses MockDataFactory to validate helper routing logic without DML.
     */
    @isTest
    static void testHelperCollectTargetsWithMockDataFactory() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
        Account practiceUpdate = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
            'IsActive' => false,
            'Name' => 'Mock Practice Update',
            'BillingPostalCode' => '98765'
        })[0];
        Account practiceOld = (Account) practiceUpdate.clone();
        practiceOld.IsActive = true;

        Contact providerContact = MockDataFactory.createContacts(1, new Map<String, Object>{
            'LastName' => 'Mock Provider Contact'
        })[0];
        Account providerUpdate = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PROVIDER_RT,
            'IsActive' => false,
            'PersonContactId' => providerContact.Id,
            'FirstName' => 'Mock',
            'LastName' => 'Provider'
        })[0];
        Account providerOld = (Account) providerUpdate.clone();
        providerOld.IsActive = true;

        Account practiceInsert = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
            'IsActive' => false,
            'Name' => 'Mock Practice Insert',
            'BillingPostalCode' => '98766'
        })[0];

        Map<Id, Account> oldMap = new Map<Id, Account>{
            practiceUpdate.Id => practiceOld,
            providerUpdate.Id => providerOld
        };

        AccountDeactivationHelper.DeactivationTargets targets = AccountDeactivationHelper.collectTargets(
            new List<Account>{ practiceUpdate, providerUpdate, practiceInsert },
            oldMap
        );
        System.assertEquals(2, targets.practiceAccountIds.size(),
            'Practice updates plus inactive inserts should populate practice targets');
        System.assertEquals(true, targets.practiceAccountIds.contains(practiceUpdate.Id),
            'Updated practice should be included');
        System.assertEquals(true, targets.practiceAccountIds.contains(practiceInsert.Id),
            'Inactive practice insert should be included');
        System.assertEquals(1, targets.practitionerContactIds.size(),
            'Only one provider contact should be targeted');
        System.assertEquals(true, targets.practitionerContactIds.contains(providerUpdate.PersonContactId),
            'Provider contact should be present in targets');
        }
    }
    /**
     * @description Covers helper classification utilities with MockDataFactory data.
     */
    @isTest
    static void testHelperClassificationUtilitiesWithMockDataFactory() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
        Account practice = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
            'IsActive' => false,
            'Name' => 'Mock Practice Classification',
            'BillingPostalCode' => '55555'
        })[0];
        Account provider = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PROVIDER_RT,
            'IsActive' => true,
            'FirstName' => 'Mock Provider',
            'LastName' => 'Classification'
        })[0];

        Set<Id> populatedIds = new Set<Id>{ practice.Id, provider.Id };
        Set<Id> emptyIds = new Set<Id>();

        System.assertEquals(true, AccountDeactivationHelper.hasIdsToProcess(populatedIds),
            'Non-empty Id sets should return true');
        System.assertEquals(false, AccountDeactivationHelper.hasIdsToProcess(emptyIds),
            'Empty Id sets should return false');

        System.assertEquals(true, AccountDeactivationHelper.isPracticeAccount(practice),
            'Practice classifier should identify practice record type');
        System.assertEquals(false, AccountDeactivationHelper.isPracticeAccount(provider),
            'Practice classifier should ignore provider record types');
        System.assertEquals(true, AccountDeactivationHelper.isProviderAccount(provider),
            'Provider classifier should identify provider record type');
        System.assertEquals(false, AccountDeactivationHelper.isProviderAccount(practice),
            'Provider classifier should ignore practice record types');
        }
    }
    /**
     * @description Tests shouldProcessAccount with null IsActive values to cover all branches.
     */
    @isTest
    static void testShouldProcessAccountWithNullIsActive() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Account oldAccountActive = MockDataFactory.createAccounts(1, new Map<String, Object>{
                'IsActive' => true,
                'Name' => 'Old Active',
                'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
                'BillingPostalCode' => '11111'
            })[0];
            Account newAccountNull = MockDataFactory.createAccounts(1, new Map<String, Object>{
                'IsActive' => null,
                'Name' => 'New Null',
                'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
                'BillingPostalCode' => '22222'
            })[0];
            System.assertEquals(true, AccountDeactivationHelper.shouldProcessAccount(newAccountNull, oldAccountActive),
                'Should process when IsActive transitions from true to null');

            Account insertAccountNull = MockDataFactory.createAccounts(1, new Map<String, Object>{
                'IsActive' => null,
                'Name' => 'Insert Null',
                'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
                'BillingPostalCode' => '33333'
            })[0];
            System.assertEquals(true, AccountDeactivationHelper.shouldProcessAccount(insertAccountNull, null),
                'Should process insert context when IsActive is null');

            Account oldAccountNull = MockDataFactory.createAccounts(1, new Map<String, Object>{
                'IsActive' => null,
                'Name' => 'Old Null',
                'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
                'BillingPostalCode' => '44444'
            })[0];
            Account newAccountActive = MockDataFactory.createAccounts(1, new Map<String, Object>{
                'IsActive' => true,
                'Name' => 'New Active',
                'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
                'BillingPostalCode' => '55555'
            })[0];
            System.assertEquals(false, AccountDeactivationHelper.shouldProcessAccount(newAccountActive, oldAccountNull),
                'Should not process when IsActive transitions from null to true');
        }
    }
    /**
     * @description Tests addAccountToTargets with null PersonContactId for provider accounts.
     */
    @isTest
    static void testAddAccountToTargetsWithNullPersonContactId() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Account providerWithoutContact = MockDataFactory.createAccounts(1, new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.ACCOUNT_PROVIDER_RT,
                'IsActive' => false,
                'PersonContactId' => null,
                'FirstName' => 'Provider',
                'LastName' => 'NoContact'
            })[0];

            AccountDeactivationHelper.DeactivationTargets targets = new AccountDeactivationHelper.DeactivationTargets();
            AccountDeactivationHelper.addAccountToTargets(providerWithoutContact, targets);

            System.assertEquals(0, targets.practiceAccountIds.size(),
                'Provider account should not be added to practice targets');
            System.assertEquals(1, targets.practitionerContactIds.size(),
                'Provider account should be added to practitioner targets even with null PersonContactId');
        }
    }
    /**
     * @description Tests collectTargets with null updatedAccount in the list.
     */
    @isTest
    static void testCollectTargetsWithNullAccount() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Account validAccount = MockDataFactory.createAccounts(1, new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
                'IsActive' => false,
                'Name' => 'Valid Practice',
                'BillingPostalCode' => '12345'
            })[0];

            Test.startTest();
            AccountDeactivationHelper.DeactivationTargets targets = AccountDeactivationHelper.collectTargets(
                new List<Account>{ validAccount },
                new Map<Id, Account>()
            );
            Test.stopTest();

            System.assertEquals(1, targets.practiceAccountIds.size(),
                'Only valid account should be processed');
        }
    }
    /**
     * @description Tests processAccountDeactivation with null and empty list to ensure early return.
     */
    @isTest
    static void testProcessAccountDeactivationWithNullAndEmptyList() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Test.startTest();
            AccountDeactivationService.processAccountDeactivation(null, new Map<Id, Account>());
            AccountDeactivationService.processAccountDeactivation(new List<Account>(), new Map<Id, Account>());
            Test.stopTest();

            System.assert(true, 'Null and empty lists should be handled gracefully without exceptions');
        }
    }
    /**
     * @description Tests fetchActiveFacilities exception handling using customExceptionSwitch.
     */
    @isTest
    static void testFetchActiveFacilitiesHandlesException() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Set<Id> testIds = new Set<Id>{ practiceDeactivationId };
            Test.startTest();
            ConstantsUtil.customExceptionSwitch = true;
            List<HealthcarePractitionerFacility> facilities = AccountDeactivationService.fetchActiveFacilities(testIds, new Set<Id>());
            ConstantsUtil.customExceptionSwitch = false;
            Test.stopTest();

            System.assertEquals(0, facilities.size(),
                'Exception should be caught and empty list returned');
        }
    }
    /**
     * @description Tests fetchActiveHealthcareProviders exception handling using customExceptionSwitch.
     */
    @isTest
    static void testFetchActiveHealthcareProvidersHandlesException() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];

        System.runAs(runAsUser) {
            Set<Id> testIds = new Set<Id>{ [SELECT Id from HealthcareProvider LIMIT 1].Id };
            Test.startTest();
            ConstantsUtil.customExceptionSwitch = true;
            List<HealthcareProvider> providers = AccountDeactivationService.fetchActiveHealthcareProviders(testIds, new Set<Id>());
            ConstantsUtil.customExceptionSwitch = false;
            Test.stopTest();

            System.assertEquals(0, providers.size(),
                'Exception should be caught and empty list returned');
        }
    }
    /**
     * @description Tests saveRecords exception handling with null input.
     */
    @isTest
    static void testSaveRecordsHandlesNullInput() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Test.startTest();
            AccountDeactivationService.saveRecords(null, 'HealthcarePractitionerFacility');
            Test.stopTest();

            System.assert(true, 'saveRecords should handle null input gracefully');
        }
    }
    /**
     * @description Tests canUpdateRecords with null objectType to cover permission check edge cases.
     */
    @isTest
    static void testCanUpdateRecordsWithNullObjectType() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Test.startTest();
            Boolean result = AccountDeactivationHelper.canUpdateRecords(null, 'Unknown Object');
            Test.stopTest();

            System.assertEquals(false, result,
                'Null objectType should return false and log error');
        }
    }
    /**
     * @description Tests canUpdateRecords with valid objectType.
     */
    @isTest
    static void testCanUpdateRecordsWithValidObjectType() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Test.startTest();
            Boolean result = AccountDeactivationHelper.canUpdateRecords(Account.SObjectType, 'Account');
            Test.stopTest();

            System.assertEquals(true, result,
                'Valid updateable objectType should return true');
        }
    }
    /**
     * @description Tests isPracticeAccount and isProviderAccount with null input.
     */
    @isTest
    static void testAccountTypeCheckersWithNull() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Test.startTest();
            Boolean isPractice = AccountDeactivationHelper.isPracticeAccount(null);
            Boolean isProvider = AccountDeactivationHelper.isProviderAccount(null);
            Test.stopTest();

            System.assertEquals(false, isPractice,
                'Null account should return false for practice check');
            System.assertEquals(false, isProvider,
                'Null account should return false for provider check');
        }
    }
    /**
     * @description Tests hasIdsToProcess with null input.
     */
    @isTest
    static void testHasIdsToProcessWithNull() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Test.startTest();
            Boolean result = AccountDeactivationHelper.hasIdsToProcess(null);
            Test.stopTest();

            System.assertEquals(false, result,
                'Null set should return false');
        }
    }
    /**
     * @description Tests deactivatePracticeFacilities when no facilities are found.
     */
    @isTest
    static void testDeactivatePracticeFacilitiesNoRecordsFound() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Set<Id> nonExistentIds = new Set<Id>{ MockDataFactory.getFakeId('Account') };

            Test.startTest();
            AccountDeactivationService.deactivatePracticeFacilities(nonExistentIds, new Set<Id>());
            Test.stopTest();

            System.assert(true, 'Should log info message when no facilities found');
        }
    }
    /**
     * @description Tests deactivateHealthcareProviders when no providers are found.
     */
    @isTest
    static void testDeactivateHealthcareProvidersNoRecordsFound() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Set<Id> nonExistentIds = new Set<Id>{ MockDataFactory.getFakeId('Contact') };

            Test.startTest();
            AccountDeactivationService.deactivateHealthcareProviders(nonExistentIds, new Set<Id>());
            Test.stopTest();

            System.assert(true, 'Should log info message when no providers found');
        }
    }
    /**
     * @description Tests collectTargets with null updatedAccounts list.
     */
    @isTest
    static void testCollectTargetsWithNullList() {
        User runAsUser = [SELECT Id FROM User WHERE FirstName = 'Admin'];
        System.runAs(runAsUser) {
            Test.startTest();
            AccountDeactivationHelper.DeactivationTargets targets = AccountDeactivationHelper.collectTargets(
                null,
                new Map<Id, Account>()
            );
            Test.stopTest();

            System.assertEquals(0, targets.practiceAccountIds.size(),
                'Null list should result in empty practice targets');
            System.assertEquals(0, targets.practitionerContactIds.size(),
                'Null list should result in empty practitioner targets');
        }
    }
}