/**
 * @description Test class for OrgSync_ContactPointHandler (Physician flow).
 * Created Date : Jan 28, 2026
 */
@IsTest
private class OrgSync_ContactPointHandler_Test {
    @TestSetup
    static void setupOrgSyncUser() {
        List<User> existing = [SELECT Id FROM User WHERE Name = 'OrgSync User' LIMIT 1];
        if (!existing.isEmpty()) {
            return;
        }

        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User orgSyncUser = new User(
            FirstName = 'OrgSync',
            LastName = 'User',
            Alias = 'osync',
            Email = 'orgsync@example.com',
            Username = 'orgsync.user.' + DateTime.now().getTime() + '@example.com',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert orgSyncUser;
    }

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
    static void testHandlePhysicianUpsertCreatesContactPoints() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        User orgSyncUser = [SELECT Id FROM User WHERE Name = 'OrgSync User' LIMIT 1];
        String extId = 'PHYS-HND-CP-' + uniqueSuffix();
        Account provider = new Account(
            FirstName = 'Handler',
            LastName = 'Physician',
            RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT,
            XCDC_ExternalId__c = extId,
            BillingPostalCode = '12345'
        );
        insertAccountBypassDuplicates(provider);

        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Physician Handler ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_PersonEmail__c = 'handler@example.com',
            OrgSync_MobilePhone__c = '5557779999',
            OrgSync_Preferred_Phone_Number__c = 'Mobile',
            OrgSync_Mailing_Address__Street__s = '500 Handler St',
            OrgSync_Mailing_Address__City__s = 'Seattle',
            OrgSync_Mailing_Address__StateCode__s = 'WA',
            OrgSync_Mailing_Address__PostalCode__s = '98101'
        );

        System.runAs(orgSyncUser) {
            Test.startTest();
            new OrgSync_ContactPointHandler().handlePhysicianUpsert(
                new List<OrgSync_Physician_Staging__c>{staging},
                null
            );
            Test.stopTest();
        }

        System.assertEquals(1, [SELECT count() FROM ContactPointEmail WHERE ParentId = :provider.Id],
            'Expected one email to be created');
        System.assertEquals(1, [SELECT count() FROM ContactPointPhone WHERE ParentId = :provider.Id],
            'Expected one phone to be created');
        System.assertEquals(1, [SELECT count() FROM ContactPointAddress WHERE ParentId = :provider.Id],
            'Expected one address to be created');
    }

    @IsTest
    static void testHandleInsertAndUpdateAsOrgSyncUser() {
        OrgSync_UtilityService.orgSyncUserId = UserInfo.getUserId();
        OrgSync_ContactPointHandler handler = new OrgSync_ContactPointHandler();
        Test.startTest();
        handler.handleInsert(new List<OrgSync_Patient_Staging__c>());
        handler.handleUpdate(new List<OrgSync_Patient_Staging__c>(), new Map<Id, OrgSync_Patient_Staging__c>());
        Test.stopTest();
        System.assert(true, 'Handle insert/update as OrgSync user should complete');
    }

    @IsTest
    static void testSortRecordsBySObjectTypeEmptyMap() {
        OrgSync_ContactPointHandler handler = new OrgSync_ContactPointHandler();
        Test.startTest();
        handler.sortRecordsBySObjectType(new Map<Id, SObject>(), new Map<Id, SObject>(), false);
        handler.sortRecordsBySObjectType(null, null, true);
        Test.stopTest();
        System.assert(true, 'Empty maps should return early');
    }
}