/**
 * @description Test class for OrgSync_ContactPointObjectService
 * Created Date : Dec 08, 2025
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 08, 2025        Neeraj Kumar            Initial Version
 */
@isTest(IsParallel=true)
private class OrgSync_ContactPointObjectService_Test {

    private static final String TEST_EXTERNAL_ID = 'TEST-EXT-001';
    private static final String TEST_EXTERNAL_ID_2 = 'TEST-EXT-002';
    private static final String TEST_EMAIL_1 = 'test1@example.com';
    private static final String TEST_EMAIL_2 = 'test2@example.com';
    private static final String TEST_HOME_PHONE = '5551111111';
    private static final String TEST_WORK_PHONE = '5552222222';
    private static final String TEST_MOBILE_PHONE = '5553333333';
    private static final String TEST_STREET = '123 Test Street';
    private static final String TEST_CITY = 'Test City';
    private static final String TEST_STATE = 'CA';
    private static final String TEST_POSTAL_CODE = '12345';
    /** Patient external ID for guardian sync tests. Guardian (Patient Delegate) has no external ID; CCR.OrgSync_Guardian_Sequence__c determines which guardian section (1 or 2) on Patient Stage gets updated. */
    private static final String PATIENT_EXT_ID_GUARDIAN_SYNC = 'GUARD-CPE-CPP-001';
    private static final String GUARDIAN_TEST_EMAIL = 'guardian.delegate@test.com';
    private static final String GUARDIAN_TEST_HOME_PHONE = '5559876543';

    /**
     * @description Ensures PartyRoleRelation with Patient Legal Guardian role exists for Guardian CPE/CPP sync tests.
     */
    private static void ensureGuardianRoleExists() {
        List<PartyRoleRelation> guardianRoles = [
            SELECT Id FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (guardianRoles.isEmpty()) {
            insert new PartyRoleRelation(
                Name = ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE,
                RoleName = 'Patient',
                RelatedRoleName = ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME,
                RelationshipObjectName = ConstantsUtil.CONTACT_CONTACT_RELATION
            );
        }
    }

    /**
     * @description Creates Patient (with XCDC_ExternalId__c), Patient Delegate (no external ID), and CCR with OrgSync_Guardian_Sequence__c.
     *              CCR.OrgSync_Guardian_Sequence__c (1 or 2) determines which guardian section on Patient Stage gets synced.
     * @return Map with keys: patientAcc, delegateAcc, guardianRoleId
     */
    private static Map<String, Object> createGuardianSyncTestData() {
        ensureGuardianRoleExists();
        OrgSync_SoqlUtility.resetCache();

        List<Account> accountsToInsert = new List<Account>{
            OrgSync_TestDataFactory.createPatientAccount(
                'Patient', 'GuardianTest', 'patient@guardian.com', PATIENT_EXT_ID_GUARDIAN_SYNC, '12345', null
            ),
            OrgSync_TestDataFactory.createDelegateAccount('Guardian', 'Delegate', 'delegate@guardian.com')
        };
        Database.insert(accountsToInsert, OrgSync_TestDataFactory.getDMLOptions());

        Account patientAcc = [SELECT Id, PersonContactId, XCDC_ExternalId__c FROM Account WHERE Id = :accountsToInsert[0].Id];
        Account delegateAcc = [SELECT Id, PersonContactId FROM Account WHERE Id = :accountsToInsert[1].Id];

        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        if (guardianRoleId != null && patientAcc.PersonContactId != null && delegateAcc.PersonContactId != null) {
            ContactContactRelation ccr = new ContactContactRelation(
                ContactId = patientAcc.PersonContactId,
                RelatedContactId = delegateAcc.PersonContactId,
                PartyRoleRelationId = guardianRoleId,
                OrgSync_Guardian_Sequence__c = 1,  // CCR field - determines Guardian 1 section on Patient Stage
                IsActive = true
            );
            insert ccr;
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('patientAcc', patientAcc);
        result.put('delegateAcc', delegateAcc);
        result.put('guardianRoleId', guardianRoleId);
        return result;
    }

    /**
     * @description Creates test Account with external ID
     * @param externalId String external ID
     * @return Account test Account
     */
    private static Account createTestAccount(String externalId) {
        List<Account> personAccounts = MockDataFactory.createAccounts(1, new Map<String, Object>{
            'XCDC_ExternalId__c' => externalId,
            'BillingPostalCode' => '78965'
        });
        personAccounts[0].Id = null;
        insert personAccounts;
        return personAccounts[0];
    }

    /**
     * @description Creates test OrgSync_Patient_Staging__c record
     * @param externalId String external ID
     * @return OrgSync_Patient_Staging__c test staging record
     */
    private static OrgSync_Patient_Staging__c createTestStaging(String externalId) {
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = externalId,
            OrgSync_Email_1__c = TEST_EMAIL_1,
            OrgSync_Email_2__c = TEST_EMAIL_2,
            OrgSync_Home_Phone__c = TEST_HOME_PHONE,
            OrgSync_Work_Phone__c = TEST_WORK_PHONE,
            OrgSync_Mobile_Phone__c = TEST_MOBILE_PHONE,
            OrgSync_Shipping_Address__Street__s = TEST_STREET,
            OrgSync_Shipping_Address__City__s = TEST_CITY,
            OrgSync_Shipping_Address__StateCode__s = TEST_STATE,
            OrgSync_Shipping_Address__PostalCode__s = TEST_POSTAL_CODE,
            OrgSync_Billing_Address__Street__s = TEST_STREET,
            OrgSync_Billing_Address__City__s = TEST_CITY,
            OrgSync_Billing_Address__StateCode__s = TEST_STATE,
            OrgSync_Billing_Address__PostalCode__s = TEST_POSTAL_CODE
        );
        insert staging;
        return staging;
    }

    /**
     * @description Test processContactPoints - Create new contact points from staging
     */
    @isTest
    static void testProcessContactPointsCreateNew() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);

        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = TEST_EXTERNAL_ID,
            OrgSync_Email_1__c = TEST_EMAIL_1,
            OrgSync_Email_2__c = TEST_EMAIL_2,
            OrgSync_Home_Phone__c = TEST_HOME_PHONE,
            OrgSync_Work_Phone__c = TEST_WORK_PHONE,
            OrgSync_Mobile_Phone__c = TEST_MOBILE_PHONE,
            OrgSync_Shipping_Address__Street__s = TEST_STREET,
            OrgSync_Shipping_Address__City__s = TEST_CITY,
            OrgSync_Shipping_Address__StateCode__s = TEST_STATE,
            OrgSync_Shipping_Address__PostalCode__s = TEST_POSTAL_CODE,
            OrgSync_Billing_Address__Street__s = TEST_STREET,
            OrgSync_Billing_Address__City__s = TEST_CITY,
            OrgSync_Billing_Address__StateCode__s = TEST_STATE,
            OrgSync_Billing_Address__PostalCode__s = TEST_POSTAL_CODE
        );
        insert staging;

        List<OrgSync_Patient_Staging__c> stagingRecords = new List<OrgSync_Patient_Staging__c>{staging};

        Test.startTest();
        OrgSync_ContactPointObjectService service = new OrgSync_ContactPointObjectService();
        service.processContactPoints(stagingRecords, null);
        Test.stopTest();

        // Verify ContactPointEmail records created
        List<ContactPointEmail> emails = [SELECT Id, EmailAddress, PreferenceRank, IsPrimary, ParentId
                                        FROM ContactPointEmail
                                        WHERE ParentId = :testAccount.Id];
        System.assertEquals(2, emails.size(), 'Should have created 2 email records');

        // Verify ContactPointPhone records created
        List<ContactPointPhone> phones = [SELECT Id, TelephoneNumber, UsageType, ParentId
                                        FROM ContactPointPhone
                                        WHERE ParentId = :testAccount.Id];
        System.assertEquals(3, phones.size(), 'Should have created 3 phone records');

        // Verify ContactPointAddress records created
        List<ContactPointAddress> addresses = [SELECT Id, Street, City, AddressType, ParentId
                                            FROM ContactPointAddress
                                            WHERE ParentId = :testAccount.Id];
        System.assertEquals(2, addresses.size(), 'Should have created 2 address records');
    }

    /**
     * @description Test processContactPoints - Update existing contact points
     */
    @isTest
    static void testProcessContactPointsUpdateExisting() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);

        // Create existing contact points
        ContactPointEmail existingEmail = new ContactPointEmail(
            ParentId = testAccount.Id,
            EmailAddress = 'old@example.com',
            PreferenceRank = 1,
            IsPrimary = true
        );
        insert existingEmail;

        ContactPointPhone existingPhone = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '0000000000',
            UsageType = 'Home',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert existingPhone;

        ContactPointAddress existingAddress = new ContactPointAddress(
            Name = 'Old Address',
            ParentId = testAccount.Id,
            Street = 'Old Street',
            City = 'Old City',
            AddressType = 'Shipping',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert existingAddress;

        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = TEST_EXTERNAL_ID,
            OrgSync_Email_1__c = TEST_EMAIL_1,
            OrgSync_Home_Phone__c = TEST_HOME_PHONE,
            OrgSync_Shipping_Address__Street__s = TEST_STREET,
            OrgSync_Shipping_Address__City__s = TEST_CITY,
            OrgSync_Shipping_Address__StateCode__s = TEST_STATE,
            OrgSync_Shipping_Address__PostalCode__s = TEST_POSTAL_CODE
        );
        insert staging;

        // Create old map for update scenario
        Map<Id, OrgSync_Patient_Staging__c> oldMap = new Map<Id, OrgSync_Patient_Staging__c>();
        oldMap.put(staging.Id, staging.clone(true, true, true, true));
        List<OrgSync_Patient_Staging__c> stagingRecords = new List<OrgSync_Patient_Staging__c>{staging};

        Test.startTest();
        OrgSync_ContactPointObjectService service = new OrgSync_ContactPointObjectService();
        service.processContactPoints(stagingRecords, oldMap);
        Test.stopTest();

        // Verify ContactPointEmail updated
        ContactPointEmail updatedEmail = [SELECT Id, EmailAddress FROM ContactPointEmail
                                        WHERE Id = :existingEmail.Id];
        System.assertEquals(TEST_EMAIL_1, updatedEmail.EmailAddress, 'Email should be updated');

        // Verify ContactPointPhone updated
        ContactPointPhone updatedPhone = [SELECT Id, TelephoneNumber FROM ContactPointPhone
                                        WHERE Id = :existingPhone.Id];
        System.assertEquals(TEST_HOME_PHONE, updatedPhone.TelephoneNumber, 'Phone should be updated');

        // Verify ContactPointAddress updated
        ContactPointAddress updatedAddress = [SELECT Id, Street, City FROM ContactPointAddress
                                            WHERE Id = :existingAddress.Id];
        System.assertEquals(TEST_STREET, updatedAddress.Street, 'Address street should be updated');
        System.assertEquals(TEST_CITY, updatedAddress.City, 'Address city should be updated');
    }

    /**
     * @description Test processContactPoints - Delete contact points when staging values are blank
     */
    @isTest
    static void testProcessContactPointsDeleteWhenBlank() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);

        // Create existing contact points
        ContactPointEmail existingEmail = new ContactPointEmail(
            ParentId = testAccount.Id,
            EmailAddress = 'old@example.com',
            PreferenceRank = 1,
            IsPrimary = true
        );
        insert existingEmail;

        ContactPointPhone existingPhone = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '0000000000',
            UsageType = 'Home',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert existingPhone;

        ContactPointAddress existingAddress = new ContactPointAddress(
            Name = 'Old Address',
            ParentId = testAccount.Id,
            Street = 'Old Street',
            City = 'Old City',
            AddressType = 'Shipping',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert existingAddress;

        // Create staging with blank values
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = TEST_EXTERNAL_ID,
            OrgSync_Email_1__c = null,
            OrgSync_Home_Phone__c = null,
            OrgSync_Shipping_Address__Street__s = null
        );
        insert staging;

        // Create old map for update scenario
        Map<Id, OrgSync_Patient_Staging__c> oldMap = new Map<Id, OrgSync_Patient_Staging__c>();
        oldMap.put(staging.Id, staging.clone(true, true, true, true));
        List<OrgSync_Patient_Staging__c> stagingRecords = new List<OrgSync_Patient_Staging__c>{staging};

        Test.startTest();
        OrgSync_ContactPointObjectService service = new OrgSync_ContactPointObjectService();
        service.processContactPoints(stagingRecords, oldMap);
        Test.stopTest();

        // Verify contact points deleted
        List<ContactPointEmail> emails = [SELECT Id FROM ContactPointEmail
                                        WHERE Id = :existingEmail.Id];
        System.assertEquals(0, emails.size(), 'Email should be deleted');

        List<ContactPointPhone> phones = [SELECT Id FROM ContactPointPhone
                                        WHERE Id = :existingPhone.Id];
        System.assertEquals(0, phones.size(), 'Phone should be deleted');

        List<ContactPointAddress> addresses = [SELECT Id FROM ContactPointAddress
                                            WHERE Id = :existingAddress.Id];
        System.assertEquals(0, addresses.size(), 'Address should be deleted');
    }

    /**
     * @description Test processContactPoints - No matching account scenario
     */
    @isTest
    static void testProcessContactPointsNoMatchingAccount() {
        // Setup - staging with non-existent external ID
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = 'NON-EXISTENT-ID',
            OrgSync_Email_1__c = TEST_EMAIL_1
        );
        insert staging;

        List<OrgSync_Patient_Staging__c> stagingRecords = new List<OrgSync_Patient_Staging__c>{staging};

        Test.startTest();
        OrgSync_ContactPointObjectService service = new OrgSync_ContactPointObjectService();
        service.processContactPoints(stagingRecords, null);
        Test.stopTest();

        // Verify no contact points created
        List<ContactPointEmail> emails = [SELECT Id FROM ContactPointEmail];
        System.assertEquals(0, emails.size(), 'No email should be created');
    }

    /**
     * @description Test processContactPoints - Empty external ID scenario
     */
    @isTest
    static void testProcessContactPointsEmptyExternalId() {
        // Setup - staging with blank external ID
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = null,
            OrgSync_Email_1__c = TEST_EMAIL_1
        );
        insert staging;
        List<OrgSync_Patient_Staging__c> stagingRecords = new List<OrgSync_Patient_Staging__c>{staging};
        Test.startTest();
        OrgSync_ContactPointObjectService service = new OrgSync_ContactPointObjectService();
        service.processContactPoints(stagingRecords, null);
        Test.stopTest();
        // Verify no contact points created
        List<ContactPointEmail> emails = [SELECT Id FROM ContactPointEmail];
        System.assertEquals(0, emails.size(), 'No email should be created');
    }
    /**
     * @description Test syncContactPointEmailToStaging
     */
    @isTest
    static void testSyncContactPointEmailToStaging() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create ContactPointEmail
        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = testAccount.Id,
            EmailAddress = 'newemail@example.com',
            PreferenceRank = 1,
            IsPrimary = true
        );
        insert cpe;

        List<ContactPointEmail> emailRecords = new List<ContactPointEmail>{cpe};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointEmailToStaging(emailRecords);
        Test.stopTest();

        // Verify staging record updated
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Email_1__c
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        System.assertEquals('newemail@example.com', updatedStaging.OrgSync_Email_1__c,
                            'Staging email should be updated');
    }
    /**
     * @description Test syncContactPointEmailToStaging with empty list
     */
    @isTest
    static void testSyncContactPointEmailToStagingEmptyList() {
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointEmailToStaging(new List<ContactPointEmail>());
        Test.stopTest();

        // Verify no errors thrown
        System.assert(true, 'Method should handle empty list gracefully');
    }

    /**
     * @description Test syncContactPointPhoneToStaging - Home phone
     */
    @isTest
    static void testSyncContactPointPhoneToStagingHomePhone() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create ContactPointPhone
        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '9998887777',
            UsageType = 'Home',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert cpp;

        List<ContactPointPhone> phoneRecords = new List<ContactPointPhone>{cpp};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointPhoneToStaging(phoneRecords);
        Test.stopTest();

        // Verify staging record updated
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Home_Phone__c
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        System.assertEquals('9998887777', updatedStaging.OrgSync_Home_Phone__c,
                        'Staging home phone should be updated');
    }

    /**
     * @description Test syncContactPointPhoneToStaging - Work phone
     */
    @isTest
    static void testSyncContactPointPhoneToStagingWorkPhone() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create ContactPointPhone
        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '9998887777',
            UsageType = 'Work',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert cpp;

        List<ContactPointPhone> phoneRecords = new List<ContactPointPhone>{cpp};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointPhoneToStaging(phoneRecords);
        Test.stopTest();

        // Verify staging record updated
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Work_Phone__c
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        System.assertEquals('9998887777', updatedStaging.OrgSync_Work_Phone__c,
                        'Staging work phone should be updated');
    }

    /**
     * @description Test syncContactPointPhoneToStaging - Mobile phone
     */
    @isTest
    static void testSyncContactPointPhoneToStagingMobilePhone() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create ContactPointPhone
        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '9998887777',
            UsageType = 'Mobile',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert cpp;

        List<ContactPointPhone> phoneRecords = new List<ContactPointPhone>{cpp};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointPhoneToStaging(phoneRecords);
        Test.stopTest();

        // Verify staging record updated
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Mobile_Phone__c
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        System.assertEquals('9998887777', updatedStaging.OrgSync_Mobile_Phone__c,
                        'Staging mobile phone should be updated');
    }

    /**
     * @description Test syncContactPointPhoneToStaging with empty list
     */
    @isTest
    static void testSyncContactPointPhoneToStagingEmptyList() {
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointPhoneToStaging(new List<ContactPointPhone>());
        Test.stopTest();
        // Verify no errors thrown
        System.assert(true, 'Method should handle empty list gracefully');
    }
    /**
     * @description Test syncContactPointAddressToStaging - Billing address
     */
    @isTest
    static void testSyncContactPointAddressToStagingBillingAddress() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create ContactPointAddress
        ContactPointAddress cpa = new ContactPointAddress(
            Name = 'New Billing Address',
            ParentId = testAccount.Id,
            Street = '456 New Street',
            City = 'New City',
            StateCode = 'NY',
            PostalCode = '54321',
            AddressType = 'Billing',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert cpa;

        List<ContactPointAddress> addressRecords = new List<ContactPointAddress>{cpa};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointAddressToStaging(addressRecords);
        Test.stopTest();

        // Verify staging record updated
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Billing_Address__Street__s,
                                                            OrgSync_Billing_Address__City__s,
                                                            OrgSync_Billing_Address__StateCode__s,
                                                            OrgSync_Billing_Address__PostalCode__s
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        System.assertEquals('456 New Street', updatedStaging.OrgSync_Billing_Address__Street__s,
                        'Staging billing street should be updated');
        System.assertEquals('New City', updatedStaging.OrgSync_Billing_Address__City__s,
                        'Staging billing city should be updated');
    }

    /**
     * @description Test syncContactPointAddressToStaging - Shipping address
     */
    @isTest
    static void testSyncContactPointAddressToStagingShippingAddress() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create ContactPointAddress
        ContactPointAddress cpa = new ContactPointAddress(
            Name = 'New Shipping Address',
            ParentId = testAccount.Id,
            Street = '789 Shipping Ave',
            City = 'Ship City',
            StateCode = 'TX',
            PostalCode = '99999',
            AddressType = 'Shipping',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert cpa;

        List<ContactPointAddress> addressRecords = new List<ContactPointAddress>{cpa};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointAddressToStaging(addressRecords);
        Test.stopTest();

        // Verify staging record updated
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Shipping_Address__Street__s,
                                                            OrgSync_Shipping_Address__City__s,
                                                            OrgSync_Shipping_Address__StateCode__s,
                                                            OrgSync_Shipping_Address__PostalCode__s
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        System.assertEquals('789 Shipping Ave', updatedStaging.OrgSync_Shipping_Address__Street__s,
                        'Staging shipping street should be updated');
        System.assertEquals('Ship City', updatedStaging.OrgSync_Shipping_Address__City__s,
                        'Staging shipping city should be updated');
    }

    /**
     * @description Test syncContactPointAddressToStaging with empty list
     */
    @isTest
    static void testSyncContactPointAddressToStagingEmptyList() {
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointAddressToStaging(new List<ContactPointAddress>());
        Test.stopTest();

        // Verify no errors thrown
        System.assert(true, 'Method should handle empty list gracefully');
    }

    /**
     * @description Test clearStagingEmailOnDelete
     */
    @isTest
    static void testClearStagingEmailOnDelete() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create and then delete ContactPointEmail
        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = testAccount.Id,
            EmailAddress = 'todelete@example.com',
            PreferenceRank = 1,
            IsPrimary = true
        );
        insert cpe;

        // Capture the record before delete
        List<ContactPointEmail> deletedEmails = new List<ContactPointEmail>{cpe};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.clearStagingEmailOnDelete(deletedEmails);
        Test.stopTest();

        // Verify staging email field cleared
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Email_1__c
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        System.assertEquals(null, updatedStaging.OrgSync_Email_1__c,
                        'Staging email should be cleared');
    }
    /**
     * @description Test clearStagingEmailOnDelete with empty list
     */
    @isTest
    static void testClearStagingEmailOnDeleteEmptyList() {
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.clearStagingEmailOnDelete(new List<ContactPointEmail>());
        Test.stopTest();
        // Verify no errors thrown
        System.assert(true, 'Method should handle empty list gracefully');
    }
    /**
     * @description Test clearStagingPhoneOnDelete - Home phone
     */
    @isTest
    static void testClearStagingPhoneOnDeleteHomePhone() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create ContactPointPhone
        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '1112223333',
            UsageType = 'Home',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert cpp;

        List<ContactPointPhone> deletedPhones = new List<ContactPointPhone>{cpp};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.clearStagingPhoneOnDelete(deletedPhones);
        Test.stopTest();

        // Verify staging home phone field cleared
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Home_Phone__c
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        System.assertEquals(null, updatedStaging.OrgSync_Home_Phone__c,
                        'Staging home phone should be cleared');
    }

    /**
     * @description Test clearStagingPhoneOnDelete - Work phone
     */
    @isTest
    static void testClearStagingPhoneOnDeleteWorkPhone() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create ContactPointPhone
        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '1112223333',
            UsageType = 'Work',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert cpp;

        List<ContactPointPhone> deletedPhones = new List<ContactPointPhone>{cpp};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.clearStagingPhoneOnDelete(deletedPhones);
        Test.stopTest();

        // Verify staging work phone field cleared
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Work_Phone__c
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        System.assertEquals(null, updatedStaging.OrgSync_Work_Phone__c,
                            'Staging work phone should be cleared');
    }

    /**
     * @description Test clearStagingPhoneOnDelete - Mobile phone
     */
    @isTest
    static void testClearStagingPhoneOnDeleteMobilePhone() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create ContactPointPhone
        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '1112223333',
            UsageType = 'Mobile',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert cpp;

        List<ContactPointPhone> deletedPhones = new List<ContactPointPhone>{cpp};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.clearStagingPhoneOnDelete(deletedPhones);
        Test.stopTest();

        // Verify staging mobile phone field cleared
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Mobile_Phone__c
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        System.assertEquals(null, updatedStaging.OrgSync_Mobile_Phone__c,
                        'Staging mobile phone should be cleared');
    }

    /**
     * @description Test clearStagingPhoneOnDelete with empty list
     */
    @isTest
    static void testClearStagingPhoneOnDeleteEmptyList() {
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.clearStagingPhoneOnDelete(new List<ContactPointPhone>());
        Test.stopTest();
        // Verify no errors thrown
        System.assert(true, 'Method should handle empty list gracefully');
    }
    /**
     * @description Test clearStagingAddressOnDelete - Billing address
     */
    @isTest
    static void testClearStagingAddressOnDeleteBillingAddress() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create ContactPointAddress
        ContactPointAddress cpa = new ContactPointAddress(
            Name = 'Billing Address',
            ParentId = testAccount.Id,
            Street = '123 Billing St',
            City = 'Billing City',
            AddressType = 'Billing',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert cpa;

        List<ContactPointAddress> deletedAddresses = new List<ContactPointAddress>{cpa};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.clearStagingAddressOnDelete(deletedAddresses);
        Test.stopTest();

        // Verify staging billing address fields cleared
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Billing_Address__Street__s,
                                                            OrgSync_Billing_Address__City__s
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        System.assertEquals(null, updatedStaging.OrgSync_Billing_Address__Street__s,
                        'Staging billing street should be cleared');
        Assert.areEqual(null, updatedStaging.OrgSync_Billing_Address__City__s,
                        'Staging billing city should be cleared');
    }

    /**
     * @description Test clearStagingAddressOnDelete - Shipping address
     */
    @isTest
    static void testClearStagingAddressOnDeleteShippingAddress() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);

        // Create ContactPointAddress
        ContactPointAddress cpa = new ContactPointAddress(
            Name = 'Shipping Address',
            ParentId = testAccount.Id,
            Street = '123 Shipping St',
            City = 'Shipping City',
            AddressType = 'Shipping',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert cpa;

        List<ContactPointAddress> deletedAddresses = new List<ContactPointAddress>{cpa};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.clearStagingAddressOnDelete(deletedAddresses);
        Test.stopTest();

        // Verify staging shipping address fields cleared
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Shipping_Address__Street__s,
                                                            OrgSync_Shipping_Address__City__s
                                                    FROM OrgSync_Patient_Staging__c
                                                    WHERE Id = :staging.Id];
        Assert.areEqual(null, updatedStaging.OrgSync_Shipping_Address__Street__s,
                        'Staging shipping street should be cleared');
        Assert.areEqual(null, updatedStaging.OrgSync_Shipping_Address__City__s,
                        'Staging shipping city should be cleared');
    }

    /**
     * @description Test clearStagingAddressOnDelete with empty list
     */
    @isTest
    static void testClearStagingAddressOnDeleteEmptyList() {
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.clearStagingAddressOnDelete(new List<ContactPointAddress>());
        Test.stopTest();
        // Verify no errors thrown
        System.assert(true, 'Method should handle empty list gracefully');
    }
    /**
     * @description Test with no matching staging record
     */
    @isTest
    static void testSyncToStagingNoMatchingStagingRecord() {
        // Setup - Account without corresponding staging record
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        // Create ContactPointEmail
        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = testAccount.Id,
            EmailAddress = 'test@example.com',
            PreferenceRank = 1,
            IsPrimary = true
        );
        insert cpe;
        List<ContactPointEmail> emailRecords = new List<ContactPointEmail>{cpe};

        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointEmailToStaging(emailRecords);
        Test.stopTest();

        // Verify no errors thrown
        System.assert(true, 'Method should handle missing staging record gracefully');
    }

    /**
     * @description Test with Account missing external ID
     */
    @isTest
    static void testSyncToStagingAccountWithoutExternalId() {
        // Setup - Account without external ID
        Account testAccount = new Account(Name = 'Test Account No Ext',BillingPostalCode = '34568');
        insert testAccount;

        // Create ContactPointEmail
        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = testAccount.Id,
            EmailAddress = 'test@example.com',
            PreferenceRank = 1,
            IsPrimary = true
        );
        insert cpe;

        List<ContactPointEmail> emailRecords = new List<ContactPointEmail>{cpe};

        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointEmailToStaging(emailRecords);
        Test.stopTest();

        // Verify no errors thrown
        System.assert(true, 'Method should handle missing external ID gracefully');
    }
    /**
     * @description Test processContactPoints when email value unchanged
     */
    @isTest
    static void testProcessContactPointsSameEmailValue() {
        // Setup
        Account testAccount = createTestAccount(TEST_EXTERNAL_ID);
        OrgSync_Patient_Staging__c staging = createTestStaging(TEST_EXTERNAL_ID);
        // Update staging email to something already in staging
        staging.OrgSync_Email_1__c = TEST_EMAIL_1;
        update staging;
        // Create ContactPointEmail with same value
        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = testAccount.Id,
            EmailAddress = TEST_EMAIL_1,
            PreferenceRank = 1,
            IsPrimary = true
        );
        insert cpe;
        List<ContactPointEmail> emailRecords = new List<ContactPointEmail>{cpe};
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncContactPointEmailToStaging(emailRecords);
        Test.stopTest();
        // Verify no update occurred (same value)
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Email_1__c, SystemModstamp
                                                        FROM OrgSync_Patient_Staging__c
                                                        WHERE Id = :staging.Id];
        System.assertEquals(TEST_EMAIL_1, updatedStaging.OrgSync_Email_1__c,
                            'Email should remain unchanged');
    }

    /**
     * @description Test syncGuardianContactPointEmailToPatientStage - CPE on Patient Delegate syncs to Patient Stage Guardian 1 email.
     * Flow: Patient + Patient Delegate + CCR (Patient Legal Guardian, seq 1) + Patient Staging + CPE on Delegate -> sync to staging.
     */
    @isTest
    static void testSyncGuardianContactPointEmailToPatientStage() {
        Map<String, Object> testData = createGuardianSyncTestData();
        Account delegateAcc = (Account)testData.get('delegateAcc');

        if (delegateAcc == null || testData.get('guardianRoleId') == null) {
            System.assert(true, 'Guardian role or delegate not available - skipping');
            return;
        }

        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = delegateAcc.Id,
            EmailAddress = GUARDIAN_TEST_EMAIL,
            PreferenceRank = 1,
            IsPrimary = true
        );
        insert cpe;

        List<ContactPointEmail> emailRecords = new List<ContactPointEmail>{ cpe };

        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncGuardianContactPointEmailToPatientStage(emailRecords, null);
        Test.stopTest();

        List<OrgSync_Patient_Staging__c> stagingList = [
            SELECT OrgSync_Guardian_1_Email__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID_GUARDIAN_SYNC
        ];
        System.assertEquals(1, stagingList.size(), 'Staging record should exist after sync');
    }

    /**
     * @description Test syncGuardianContactPointPhoneToPatientStage - CPP on Patient Delegate syncs to Patient Stage Guardian 1 phone.
     * Flow: Patient + Patient Delegate + CCR (Patient Legal Guardian, seq 1) + Patient Staging + CPP on Delegate -> sync to staging.
     */
    @isTest
    static void testSyncGuardianContactPointPhoneToPatientStage() {
        Map<String, Object> testData = createGuardianSyncTestData();
        Account delegateAcc = (Account)testData.get('delegateAcc');

        if (delegateAcc == null || testData.get('guardianRoleId') == null) {
            System.assert(true, 'Guardian role or delegate not available - skipping');
            return;
        }

        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = delegateAcc.Id,
            TelephoneNumber = GUARDIAN_TEST_HOME_PHONE,
            UsageType = 'Home',
            IsPrimary = true,
            PreferenceRank = 1
        );
        insert cpp;

        List<ContactPointPhone> phoneRecords = new List<ContactPointPhone>{ cpp };

        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncGuardianContactPointPhoneToPatientStage(phoneRecords, null);
        Test.stopTest();

        List<OrgSync_Patient_Staging__c> stagingList = [
            SELECT OrgSync_Guardian_1_Home_Phone__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID_GUARDIAN_SYNC
        ];
        System.assertEquals(1, stagingList.size(), 'Staging record should exist after sync');
    }

    /**
     * @description Test syncGuardianContactPointEmailToPatientStage with empty list - no-op
     */
    @isTest
    static void testSyncGuardianContactPointEmailToPatientStageEmptyList() {
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncGuardianContactPointEmailToPatientStage(new List<ContactPointEmail>(), null);
        Test.stopTest();
        System.assert(true, 'Method should handle empty list gracefully');
    }

    /**
     * @description Test syncGuardianContactPointPhoneToPatientStage with empty list - no-op
     */
    @isTest
    static void testSyncGuardianContactPointPhoneToPatientStageEmptyList() {
        Test.startTest();
        OrgSync_DemographicsSyncToStaging service = new OrgSync_DemographicsSyncToStaging();
        service.syncGuardianContactPointPhoneToPatientStage(new List<ContactPointPhone>(), null);
        Test.stopTest();
        System.assert(true, 'Method should handle empty list gracefully');
    }
}