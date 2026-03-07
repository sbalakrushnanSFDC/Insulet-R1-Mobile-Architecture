/**
 * @description Test class for OrgSync_PhysicianContactPointService.
 * Covers processContactPoints (create, update, delete), getPrimaryContactPointPhone,
 * getPrimaryContactPointPhones, no-match and empty external ID scenarios.
 * Created Date : Jan 28, 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 28, 2026        Initial                 Initial Version
 * V1.0.1       Feb 20, 2026       Expanded coverage       Delete, getPrimary, no-match, multi-phone/email/address
 * V1.0.2       Feb 20, 2026       Added testUpdateHealthcarePractitionerFacilities for HPF Phone/Email/Address coverage
 */
@IsTest
private class OrgSync_PhysCPService_Test {
    private static void insertAccountBypassDuplicates(Account acc) {
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        Database.insert(acc, dmlOptions);
    }

    private static String uniqueSuffix() {
        return String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 4);
    }

    private static Account createProviderAccount(String externalId) {
        Account provider = new Account(
            FirstName = 'Physician',
            LastName = 'Contact',
            RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT,
            XCDC_ExternalId__c = externalId,
            PersonEmail = 'provider_' + externalId + '@example.com',
            BillingPostalCode = '12345'
        );
        insertAccountBypassDuplicates(provider);
        return provider;
    }

    @IsTest
    static void testProcessContactPointsCreate() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String extId = 'PHYS-CP-' + uniqueSuffix();
        Account provider = createProviderAccount(extId);

        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Physician CP ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_PersonEmail__c = 'primary@example.com',
            OrgSync_Work_Email__c = 'work@example.com',
            OrgSync_MobilePhone__c = '5552223333',
            OrgSync_Preferred_Phone_Number__c = 'Mobile',
            OrgSync_Mailing_Address__Street__s = '123 Main St',
            OrgSync_Mailing_Address__City__s = 'Austin',
            OrgSync_Mailing_Address__StateCode__s = 'TX',
            OrgSync_Mailing_Address__PostalCode__s = '78701'
        );

        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{staging},
            null
        );
        Test.stopTest();

        List<ContactPointEmail> emails = [SELECT Id FROM ContactPointEmail WHERE ParentId = :provider.Id];
        List<ContactPointPhone> phones = [SELECT Id FROM ContactPointPhone WHERE ParentId = :provider.Id];
        List<ContactPointAddress> addresses = [SELECT Id FROM ContactPointAddress WHERE ParentId = :provider.Id];

        System.assertEquals(2, emails.size(), 'Expected two email records');
        System.assertEquals(1, phones.size(), 'Expected one phone record');
        System.assertEquals(1, addresses.size(), 'Expected one address record');
    }

    @IsTest
    static void testProcessContactPointsUpdateExisting() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String extId = 'PHYS-CP-UPD-' + uniqueSuffix();
        Account provider = createProviderAccount(extId);

        // Create contact points via service first (staging in-memory only to avoid trigger)
        OrgSync_Physician_Staging__c stagingCreate = new OrgSync_Physician_Staging__c(
            Name = 'Physician CP Update ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_PersonEmail__c = 'old@example.com',
            OrgSync_Phone__c = '5550001111',
            OrgSync_Mailing_Address__Street__s = 'Old St',
            OrgSync_Mailing_Address__City__s = 'Old City',
            OrgSync_Mailing_Address__StateCode__s = 'TX',
            OrgSync_Mailing_Address__PostalCode__s = '78701'
        );

        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{stagingCreate},
            null
        );

        Integer emailCount = [SELECT COUNT() FROM ContactPointEmail WHERE ParentId = :provider.Id];
        Integer phoneCount = [SELECT COUNT() FROM ContactPointPhone WHERE ParentId = :provider.Id];
        System.assert(emailCount >= 1, 'Setup: at least one email created, got ' + emailCount);
        System.assert(phoneCount >= 1, 'Setup: at least one phone created, got ' + phoneCount);

        // Update with new values; pass non-null oldMap to trigger loadExistingData and update path
        OrgSync_Physician_Staging__c stagingUpdate = new OrgSync_Physician_Staging__c(
            Name = 'Physician CP Update ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_PersonEmail__c = 'new@example.com',
            OrgSync_Phone__c = '(555) 999-8888',
            OrgSync_Mailing_Address__Street__s = '999 New St',
            OrgSync_Mailing_Address__City__s = 'New City',
            OrgSync_Mailing_Address__StateCode__s = 'WA',
            OrgSync_Mailing_Address__PostalCode__s = '98101'
        );
        Map<Id, OrgSync_Physician_Staging__c> oldMap = new Map<Id, OrgSync_Physician_Staging__c>();

        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{stagingUpdate},
            oldMap
        );
        Test.stopTest();

        List<ContactPointEmail> emailsAfter = [SELECT EmailAddress FROM ContactPointEmail WHERE ParentId = :provider.Id AND PreferenceRank = 1];
        List<ContactPointPhone> phonesAfter = [SELECT TelephoneNumber FROM ContactPointPhone WHERE ParentId = :provider.Id];
        List<ContactPointAddress> addrsAfter = [SELECT Street, City FROM ContactPointAddress WHERE ParentId = :provider.Id AND AddressType = 'Mailing'];

        System.assert(!emailsAfter.isEmpty(), 'Email record should exist');
        System.assertEquals('new@example.com', emailsAfter[0].EmailAddress, 'Email should be updated');
        System.assert(!phonesAfter.isEmpty(), 'Phone record should exist');
        System.assertEquals('5559998888', phonesAfter[0].TelephoneNumber, 'Phone should be sanitized and updated');
        System.assert(!addrsAfter.isEmpty(), 'Address record should exist');
        System.assertEquals('999 New St', addrsAfter[0].Street, 'Address street should be updated');
        System.assertEquals('New City', addrsAfter[0].City, 'Address city should be updated');
    }

    @IsTest
    static void testProcessContactPointsDeleteWhenBlank() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String extId = 'PHYS-CP-DEL-' + uniqueSuffix();
        Account provider = createProviderAccount(extId);

        ContactPointEmail existingEmail = new ContactPointEmail(
            ParentId = provider.Id,
            EmailAddress = 'del_' + extId + '@example.com',
            PreferenceRank = 1,
            IsPrimary = true
        );
        ContactPointPhone existingPhone = new ContactPointPhone(
            ParentId = provider.Id,
            TelephoneNumber = '555' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 7),
            UsageType = 'Mobile',
            PreferenceRank = 1
        );
        ContactPointAddress existingAddress = new ContactPointAddress(
            Name = 'Old Mailing ' + extId,
            ParentId = provider.Id,
            Street = 'Old St ' + extId,
            City = 'Old City',
            AddressType = 'Mailing',
            IsPrimary = true,
            PreferenceRank = 1
        );
        Database.insert(new List<SObject>{ existingEmail, existingPhone, existingAddress }, OrgSync_TestDataFactory.getDMLOptions());

        // Use in-memory staging with blank values to avoid insert/duplicate rules
        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Physician CP Delete ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_PersonEmail__c = null,
            OrgSync_MobilePhone__c = null,
            OrgSync_Mailing_Address__Street__s = null
        );
        Map<Id, OrgSync_Physician_Staging__c> oldMap = new Map<Id, OrgSync_Physician_Staging__c>();

        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{staging},
            oldMap
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContactPointEmail WHERE Id = :existingEmail.Id], 'Email should be deleted');
        System.assertEquals(0, [SELECT COUNT() FROM ContactPointPhone WHERE Id = :existingPhone.Id], 'Phone should be deleted');
        System.assertEquals(0, [SELECT COUNT() FROM ContactPointAddress WHERE Id = :existingAddress.Id], 'Address should be deleted');
    }

    @IsTest
    static void testProcessContactPointsNoMatchingAccount() {
        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'No Match',
            XCDC_ExternalId__c = 'NON-EXISTENT-' + uniqueSuffix(),
            OrgSync_PersonEmail__c = 'nomatch@example.com'
        );
        insert staging;

        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{staging},
            null
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContactPointEmail], 'No email should be created');
    }

    @IsTest
    static void testProcessContactPointsEmptyExternalId() {
        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Blank Ext',
            XCDC_ExternalId__c = null,
            OrgSync_PersonEmail__c = 'blank@example.com'
        );
        insert staging;

        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{staging},
            null
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContactPointEmail], 'No email should be created');
    }

    @IsTest
    static void testGetPrimaryContactPointPhone() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String extId = 'PHYS-CP-PRIM-' + uniqueSuffix();
        Account provider = createProviderAccount(extId);

        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Physician Primary ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_PersonEmail__c = 'prim@example.com',
            OrgSync_Phone__c = '5556667777',
            OrgSync_Mailing_Address__Street__s = '100 Primary St'
        );

        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{staging},
            null
        );
        ContactPointPhone primary = OrgSync_PhysicianContactPointService.getPrimaryContactPointPhone(provider.Id);
        Map<Id, ContactPointPhone> allPrimary = OrgSync_PhysicianContactPointService.getPrimaryContactPointPhones();
        Test.stopTest();

        System.assertNotEquals(null, primary, 'Primary ContactPointPhone should be returned');
        System.assertEquals(provider.Id, primary.ParentId, 'Primary should belong to provider');
        System.assertEquals(true, primary.IsPrimary, 'Returned phone should be IsPrimary');
        System.assert(allPrimary.containsKey(provider.Id), 'Map should contain provider primary');
    }

    @IsTest
    static void testProcessContactPointsAllFourPhones() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String extId = 'PHYS-CP-4PH-' + uniqueSuffix();
        Account provider = createProviderAccount(extId);

        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Physician 4Ph ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_PersonEmail__c = 'four@example.com',
            OrgSync_PersonHomePhone__c = '5551111111',
            OrgSync_MobilePhone__c = '5552222222',
            OrgSync_Phone__c = '5553333333',
            OrgSync_Fax__c = '5554444444',
            OrgSync_Mailing_Address__Street__s = '200 Four St'
        );
        insert staging;

        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{staging},
            null
        );
        Test.stopTest();

        List<ContactPointPhone> phones = [SELECT TelephoneNumber, UsageType, IsPrimary FROM ContactPointPhone WHERE ParentId = :provider.Id ORDER BY PreferenceRank];
        System.assertEquals(4, phones.size(), 'Expected four phone records');
        // Work (OrgSync_Phone__c) is primary
        for (ContactPointPhone cpp : phones) {
            if (cpp.UsageType == 'Work') {
                System.assertEquals(true, cpp.IsPrimary, 'Work phone should be primary');
                System.assertEquals('5553333333', cpp.TelephoneNumber, 'Work number should match');
            }
        }
    }

    @IsTest
    static void testProcessContactPointsMultipleEmails() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String extId = 'PHYS-CP-ME-' + uniqueSuffix();
        Account provider = createProviderAccount(extId);

        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Physician MultiEmail ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_PersonEmail__c = 'rank1@example.com',
            OrgSync_Email_2__c = 'rank2@example.com',
            OrgSync_Work_Email__c = 'rank3@example.com',
            OrgSync_Backup_Email__c = 'rank4@example.com',
            OrgSync_Secondary_Backup_Email__c = 'rank5@example.com',
            OrgSync_MobilePhone__c = '5551111111',
            OrgSync_Mailing_Address__Street__s = '300 Email St'
        );
        insert staging;

        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{staging},
            null
        );
        Test.stopTest();

        List<ContactPointEmail> emails = [SELECT EmailAddress, PreferenceRank, IsPrimary, UsageType FROM ContactPointEmail WHERE ParentId = :provider.Id ORDER BY PreferenceRank];
        System.assertEquals(5, emails.size(), 'Expected five email records');
        System.assertEquals('rank1@example.com', emails[0].EmailAddress, 'Primary email should match');
        System.assertEquals(true, emails[0].IsPrimary, 'First email should be primary');
        System.assertEquals('Work', emails[0].UsageType, 'Primary email (OrgSync_PersonEmail__c) should default UsageType to Work on create');
        System.assertEquals('Work', emails[1].UsageType, 'Second email (OrgSync_Email_2__c) should default UsageType to Work on create');
    }

    @IsTest
    static void testProcessContactPointsShippingAddress() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String extId = 'PHYS-CP-SHIP-' + uniqueSuffix();
        Account provider = createProviderAccount(extId);

        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Physician Ship ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_PersonEmail__c = 'ship@example.com',
            OrgSync_MobilePhone__c = '5551111111',
            OrgSync_Mailing_Address__Street__s = '400 Mailing St',
            OrgSync_Mailing_Address__City__s = 'Mailing City',
            OrgSync_Other_Address__Street__s = '500 Shipping St',
            OrgSync_Other_Address__City__s = 'Shipping City',
            OrgSync_Other_Address__StateCode__s = 'CA',
            OrgSync_Other_Address__PostalCode__s = '90210'
        );
        insert staging;

        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{staging},
            null
        );
        Test.stopTest();

        List<ContactPointAddress> addresses = [SELECT Street, City, AddressType FROM ContactPointAddress WHERE ParentId = :provider.Id];
        System.assertEquals(2, addresses.size(), 'Expected Mailing and Shipping addresses');
        for (ContactPointAddress cpa : addresses) {
            if (cpa.AddressType == 'Mailing') {
                System.assertEquals('400 Mailing St', cpa.Street, 'Mailing street should match');
            } else if (cpa.AddressType == 'Shipping') {
                System.assertEquals('500 Shipping St', cpa.Street, 'Shipping street should match');
                System.assertEquals('Shipping City', cpa.City, 'Shipping city should match');
            }
        }
    }

    @IsTest
    static void testProcessContactPointsEmptyRecords() {
        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>(),
            null
        );
        Test.stopTest();
        System.assert(true, 'Empty list should not throw');
    }

    @IsTest
    static void testGetPrimaryContactPointPhoneWhenNone() {
        ContactPointPhone result = OrgSync_PhysicianContactPointService.getPrimaryContactPointPhone(null);
        System.assertEquals(null, result, 'Should return null for null accountId');
    }

    /**
     * Covers processedAccountIds path - when external ID is already in OrgSync_ProviderService.processedAccountIds.
     */
    @IsTest
    static void testProcessContactPointsUsesProcessedAccountIds() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String extId = 'PHYS-PROC-' + uniqueSuffix();
        Account provider = createProviderAccount(extId);
        OrgSync_ProviderService.processedAccountIds.put(extId, provider.Id);

        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Physician Processed ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_PersonEmail__c = 'processed@example.com',
            OrgSync_MobilePhone__c = '5553334444',
            OrgSync_Mailing_Address__Street__s = '700 Processed St'
        );

        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{ staging },
            null
        );
        Test.stopTest();

        List<ContactPointEmail> emails = [SELECT Id FROM ContactPointEmail WHERE ParentId = :provider.Id];
        System.assert(!emails.isEmpty(), 'Should create email using cached account ID');
    }

    /**
     * @description Covers updateHealthcarePractitionerFacilities - HPF Phone__c, Email__c, Address__c
     *              populated from primary ContactPointPhone, ContactPointEmail, and Mailing ContactPointAddress.
     */
    @IsTest
    static void testUpdateHealthcarePractitionerFacilities() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        String extId = 'PHYS-CP-HPF-' + uniqueSuffix();
        Account provider = createProviderAccount(extId);
        provider = [SELECT Id, PersonContactId FROM Account WHERE Id = :provider.Id];
        if (provider.PersonContactId == null) {
            System.assert(true, 'PersonContactId not available on Provider - skipping HPF test');
            return;
        }

        Account practice = OrgSync_TestDataFactory.createPracticeAccount('HPF Practice', 'PRAC-HPF-' + uniqueSuffix(), '12345');
        Database.insert(practice, OrgSync_TestDataFactory.getDMLOptions());

        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = practice.Id,
            PractitionerId = provider.PersonContactId,
            Name = 'HPF for CP Test ' + extId,
            IsActive = true
        );
        insert hpf;

        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Physician HPF ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_PersonEmail__c = 'hpf@example.com',
            OrgSync_Phone__c = '5558889999',
            OrgSync_Mailing_Address__Street__s = '600 HPF St',
            OrgSync_Mailing_Address__City__s = 'HPF City',
            OrgSync_Mailing_Address__StateCode__s = 'CA',
            OrgSync_Mailing_Address__PostalCode__s = '90210'
        );

        Test.startTest();
        new OrgSync_PhysicianContactPointService().processContactPoints(
            new List<OrgSync_Physician_Staging__c>{staging},
            null
        );
        Test.stopTest();

        HealthcarePractitionerFacility updatedHpf = [
            SELECT Id, Phone__c, Email__c, Address__c
            FROM HealthcarePractitionerFacility
            WHERE Id = :hpf.Id
        ];
        System.assertNotEquals(null, updatedHpf.Phone__c, 'HPF Phone__c should be set from primary ContactPointPhone');
        System.assertNotEquals(null, updatedHpf.Email__c, 'HPF Email__c should be set from primary ContactPointEmail');
        System.assertNotEquals(null, updatedHpf.Address__c, 'HPF Address__c should be set from Mailing ContactPointAddress');

        ContactPointPhone cpp = [SELECT Id FROM ContactPointPhone WHERE ParentId = :provider.Id AND IsPrimary = true LIMIT 1];
        ContactPointEmail cpe = [SELECT Id FROM ContactPointEmail WHERE ParentId = :provider.Id AND PreferenceRank = 1 LIMIT 1];
        ContactPointAddress cpa = [SELECT Id FROM ContactPointAddress WHERE ParentId = :provider.Id AND AddressType = 'Mailing' LIMIT 1];
        System.assertEquals(cpp.Id, updatedHpf.Phone__c, 'HPF Phone__c should reference primary ContactPointPhone');
        System.assertEquals(cpe.Id, updatedHpf.Email__c, 'HPF Email__c should reference primary ContactPointEmail');
        System.assertEquals(cpa.Id, updatedHpf.Address__c, 'HPF Address__c should reference Mailing ContactPointAddress');
    }
}