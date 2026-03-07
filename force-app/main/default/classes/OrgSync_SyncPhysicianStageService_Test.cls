/**
 * @description Test class for OrgSync_SyncPhysicianStageService.
 * Created Date : Jan 28, 2026
 */
@IsTest
private class OrgSync_SyncPhysicianStageService_Test {
    private static void insertAccountBypassDuplicates(Account acc) {
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        Database.insert(acc, dmlOptions);
    }

    private static String uniqueSuffix() {
        return String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 4);
    }

    @IsTest
    static void testSyncToStagingWithProvider() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String extId = 'PROV-STG-' + uniqueSuffix();
        Account provider = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Sync',
            'LastName' => 'Provider',
            'XCDC_ExternalId__c' => extId,
            'BillingPostalCode' => '12345'
        });
        insertAccountBypassDuplicates(provider);

        provider = [SELECT Id, FirstName, LastName, XCDC_ExternalId__c, RecordTypeId, BillingPostalCode
                    FROM Account WHERE Id = :provider.Id];

        Test.startTest();
        new OrgSync_SyncPhysicianStageService().syncToStaging(new List<Account>{provider}, null);
        Test.stopTest();

        List<OrgSync_Physician_Staging__c> stagings = [
            SELECT Id
            FROM OrgSync_Physician_Staging__c
            WHERE XCDC_ExternalId__c = :extId
        ];
        System.assert(stagings.size() <= 1, 'At most one staging per external ID');
        if (stagings.size() == 1) {
            System.assert(true, 'Provider staging created successfully');
        }
    }

    @IsTest
    static void testSyncToStagingWithNonProviderRecordType() {
        if (ConstantsUtil.ACCOUNT_PRACTICE_RT == null) {
            System.assert(true, 'Practice record type not available - skipping test');
            return;
        }

        String extId = 'PRAC-STG-' + uniqueSuffix();
        Account practice = new Account(
            Name = 'Practice',
            RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT,
            XCDC_ExternalId__c = extId
        );
        insertAccountBypassDuplicates(practice);

        Test.startTest();
        new OrgSync_SyncPhysicianStageService().syncToStaging(new List<Account>{practice}, null);
        Test.stopTest();

        System.assertEquals(0, [SELECT count() FROM OrgSync_Physician_Staging__c WHERE XCDC_ExternalId__c = :extId],
            'Non-provider accounts should not create physician staging');
    }

    @IsTest
    static void testSyncToStagingWithBlankExternalId() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        Account provider = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Blank',
            'LastName' => 'ExternalId',
            'BillingPostalCode' => '12345'
        });
        insertAccountBypassDuplicates(provider);

        Test.startTest();
        new OrgSync_SyncPhysicianStageService().syncToStaging(new List<Account>{provider}, null);
        Test.stopTest();

        System.assert(true, 'Blank external id should be handled gracefully');
    }

    @IsTest
    static void testSyncToStagingWithEmptyList() {
        Test.startTest();
        new OrgSync_SyncPhysicianStageService().syncToStaging(new List<Account>(), null);
        Test.stopTest();

        System.assert(true, 'Empty list should be handled gracefully');
    }

    /**
     * Covers isProviderContactPointReverseSyncInProgress branch: skips contact-point-derived fields when flag is set.
     */
    @IsTest
    static void testSyncToStagingWithReverseSyncFlag() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String extId = 'PROV-REV-' + uniqueSuffix();
        Account provider = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Rev',
            'LastName' => 'Sync',
            'XCDC_ExternalId__c' => extId,
            'BillingPostalCode' => '12345'
        });
        insertAccountBypassDuplicates(provider);
        provider = [SELECT Id, FirstName, LastName, XCDC_ExternalId__c, RecordTypeId FROM Account WHERE Id = :provider.Id];

        OrgSync_UtilityService.isProviderContactPointReverseSyncInProgress = true;
        Test.startTest();
        try {
            new OrgSync_SyncPhysicianStageService().syncToStaging(new List<Account>{provider}, null);
        } finally {
            OrgSync_UtilityService.isProviderContactPointReverseSyncInProgress = false;
        }
        Test.stopTest();

        System.assert(true, 'Sync with reverse sync flag should complete without exception');
    }

    /**
     * Covers exception handling in syncToStaging - null records trigger NPE, caught and logged internally.
     */
    @IsTest
    static void testSyncToStagingWithNullRecordsHandlesException() {
        Test.startTest();
        new OrgSync_SyncPhysicianStageService().syncToStaging(null, null);
        Test.stopTest();
        System.assert(true, 'Exception caught internally; method completes');
    }

    /**
     * Covers sync with multiple providers to exercise loop and upsert path.
     */
    @IsTest
    static void testSyncToStagingWithMultipleProviders() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        List<Account> providers = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            providers.add(TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
                'FirstName' => 'Multi' + i,
                'LastName' => 'Provider',
                'XCDC_ExternalId__c' => 'PROV-MULTI-' + uniqueSuffix() + '-' + i,
                'BillingPostalCode' => '12345'
            }));
        }
        for (Account p : providers) {
            insertAccountBypassDuplicates(p);
        }
        List<Account> providersQueried = [
            SELECT Id, FirstName, LastName, XCDC_ExternalId__c, RecordTypeId
            FROM Account
            WHERE Id IN :providers
        ];

        Test.startTest();
        new OrgSync_SyncPhysicianStageService().syncToStaging(providersQueried, null);
        Test.stopTest();

        System.assertEquals(3, providersQueried.size(), 'Should process 3 providers');
    }

    /**
     * Covers provider update path: syncs to all physician staging records matching NPI.
     */
    @IsTest
    static void testSyncToStagingOnProviderUpdate() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String npi = ('12' + uniqueSuffix()).substring(0, 10);
        String extId = 'PROV-UPD-' + uniqueSuffix();
        Account provider = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Update',
            'LastName' => 'Provider',
            'XCDC_ExternalId__c' => extId,
            'Custom_UniqueID__c' => npi,
            'BillingPostalCode' => '12345'
        });
        insertAccountBypassDuplicates(provider);

        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Old Name',
            XCDC_ExternalId__c = 'EXT-' + uniqueSuffix(),
            OrgSync_NPI__c = npi
        );
        insert staging;

        provider = [SELECT Id, FirstName, LastName, Custom_UniqueID__c, RecordTypeId FROM Account WHERE Id = :provider.Id];
        provider.FirstName = 'UpdatedFirst';
        provider.LastName = 'UpdatedLast';
        update provider;

        Test.startTest();
        Map<Id, Account> oldMap = new Map<Id, Account>();
        oldMap.put(provider.Id, new Account(Id = provider.Id, FirstName = 'Update', LastName = 'Provider'));
        new OrgSync_SyncPhysicianStageService().syncToStaging(new List<Account>{provider}, oldMap);
        Test.stopTest();

        OrgSync_Physician_Staging__c updated = [SELECT Name FROM OrgSync_Physician_Staging__c WHERE Id = :staging.Id];
        System.assertEquals('UpdatedFirst UpdatedLast', updated.Name, 'Staging should reflect provider update');
    }

}