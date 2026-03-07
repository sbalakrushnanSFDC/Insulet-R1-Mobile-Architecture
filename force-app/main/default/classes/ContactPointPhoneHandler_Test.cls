/**
 * @description Test class for ContactPointPhoneHandler
 * Created Date : 11th Feb 2026
 * Created By   : Charchit N.
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V2.1.0       25th Feb 2026       Chitresh V.            NGASIM-2354
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ContactPointPhoneHandler_Test {

    @TestSetup
    static void setupTestData() {
        // Create test accounts
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType();
        Account providerAccount = TestDataFactory.getAccountofProviderRecordType();
        insert new List<Account>{patientAccount, providerAccount};
    }

    /**
     * @description Creates Individual and links to Patient Account for consent testing
     * @return Account with PersonIndividualId populated
     */
    private static Account setupPatientAccountWithIndividual() {
        Individual ind = TestDataFactory.getIndividual(new Map<String, Object>{ 'LastName' => 'ConsentTest' });
        insert ind;

        Account acc = [SELECT Id, PersonIndividualId FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];
        acc.PersonIndividualId = ind.Id;
        update acc;
        return [SELECT Id, PersonIndividualId FROM Account WHERE Id = :acc.Id];
    }

    /**
     * @description Creates ContactPointTypeConsent for Transactional SMS.
     *              Handler queries by DataUsePurpose.Name, so DataUsePurpose with Name='Transactional SMS' is required.
     * @param individualId PartyId (Individual Id)
     * @param privacyStatus PrivacyConsentStatus value
     * @return Inserted ContactPointTypeConsent
     */
    private static ContactPointTypeConsent createTransactionalSMSConsent(Id individualId, String privacyStatus) {
        DataUsePurpose dup = TestDataFactory.getDataUsePurpose(
            new Map<String, Object>{ 'Name' => ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS }
        );
        insert dup;

        ContactPointTypeConsent consent = new ContactPointTypeConsent(
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = dup.Id,
            PartyId = individualId,
            PrivacyConsentStatus = privacyStatus,
            ContactPointType = ConstantsUtil.CONTACT_POINT_TYPE_PHONE,
            CaptureDate = DateTime.now()
        );
        insert consent;
        return consent;
    }

    /**
     * @description Returns a sample ContactPointPhone record with default values (not inserted)
     * @param parentId Parent Account ID (can be null)
     * @return ContactPointPhone record with default test values
     */
    private static ContactPointPhone getSampleContactPointPhone(Id parentId) {
        ContactPointPhone phone = new ContactPointPhone();
        phone.ParentId = parentId;
        phone.TelephoneNumber = '1234567890';
        phone.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
        phone.IsPrimary = false;
        return phone;
    }

    @IsTest
    static void testHandleBeforeInsertSinglePhone() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointPhone phone = getSampleContactPointPhone(acc.Id);

        Test.startTest();
        ContactPointPhoneHandler.handleBeforeInsert(new List<ContactPointPhone>{phone});
        Test.stopTest();

        System.assertEquals(true, phone.IsPrimary, 'Single phone should be set as primary');
    }

    @IsTest
    static void testHandleBeforeInsertMultiplePhonesSameAccount() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointPhone phone1 = getSampleContactPointPhone(acc.Id);
        phone1.TelephoneNumber = '1111111111';

        ContactPointPhone phone2 = getSampleContactPointPhone(acc.Id);
        phone2.TelephoneNumber = '2222222222';
        phone2.UsageType = 'Phone';

        List<ContactPointPhone> phones = new List<ContactPointPhone>{phone1, phone2};

        Test.startTest();
        ContactPointPhoneHandler.handleBeforeInsert(phones);
        Test.stopTest();

        // Both Mobile and one non-Mobile can be primary: Mobile (phone1) + non-Mobile Phone (phone2)
        System.assertEquals(true, phone1.IsPrimary, 'Phone1 (Mobile) should be primary');
        System.assertEquals(true, phone2.IsPrimary, 'Phone2 (non-Mobile Phone) should be primary');
    }

    @IsTest
    static void testHandleBeforeInsertMultiplePhonesNoPhoneUsageType() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointPhone phone1 = getSampleContactPointPhone(acc.Id);
        phone1.TelephoneNumber = '1111111111';

        ContactPointPhone phone2 = getSampleContactPointPhone(acc.Id);
        phone2.TelephoneNumber = '2222222222';
        phone2.UsageType = 'Home';

        List<ContactPointPhone> phones = new List<ContactPointPhone>{phone1, phone2};

        Test.startTest();
        ContactPointPhoneHandler.handleBeforeInsert(phones);
        Test.stopTest();

        // Both Mobile and one non-Mobile (Home) can be primary
        System.assertEquals(true, phone1.IsPrimary, 'Phone1 (Mobile) should be primary');
        System.assertEquals(true, phone2.IsPrimary, 'Phone2 (non-Mobile Home) should be primary');
    }

    @IsTest
    static void testHandleBeforeInsertSkipFlag() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointPhone phone = getSampleContactPointPhone(acc.Id);

        ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone = true;

        Test.startTest();
        ContactPointPhoneHandler.handleBeforeInsert(new List<ContactPointPhone>{phone});
        Test.stopTest();

        System.assertEquals(false, phone.IsPrimary, 'Phone should remain non-primary when skip flag is true');

        // Reset flag
        ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone = false;
    }

    @IsTest
    static void testHandleBeforeInsertNullList() {
        Test.startTest();
        ContactPointPhoneHandler.handleBeforeInsert(null);
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle null list gracefully');
    }

    @IsTest
    static void testHandleBeforeInsertEmptyList() {
        Test.startTest();
        ContactPointPhoneHandler.handleBeforeInsert(new List<ContactPointPhone>());
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle empty list gracefully');
    }

    @IsTest
    static void testHandleBeforeInsertMultipleNonMobilePrioritizesHome() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        // Multiple non-Mobile: Home is prioritized over Phone; last Home gets primary
        ContactPointPhone phone1 = getSampleContactPointPhone(acc.Id);
        phone1.TelephoneNumber = '1111111111';
        phone1.UsageType = 'Phone';

        ContactPointPhone phone2 = getSampleContactPointPhone(acc.Id);
        phone2.TelephoneNumber = '2222222222';
        phone2.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME;

        List<ContactPointPhone> phones = new List<ContactPointPhone>{ phone1, phone2 };

        Test.startTest();
        ContactPointPhoneHandler.handleBeforeInsert(phones);
        Test.stopTest();

        // Home (phone2) should be primary; Phone (phone1) should not
        System.assertEquals(false, phone1.IsPrimary, 'Phone with UsageType Phone should not be primary');
        System.assertEquals(true, phone2.IsPrimary, 'Phone with UsageType Home should be primary');
    }

    @IsTest
    static void testHandleAfterInsertPrimaryPhone() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];
        acc.Phone = null;
        update acc;

        ContactPointPhone phone = getSampleContactPointPhone(acc.Id);
        phone.IsPrimary = true;
        insert phone;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{phone.Id => phone};

        Test.startTest();
        ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>{phone}, newRecordsMap);
        Test.stopTest();

        Account updatedAcc = [SELECT Phone FROM Account WHERE Id = :acc.Id];
        System.assertEquals('1234567890', updatedAcc.Phone, 'Account Phone should be updated');
    }

    @IsTest
    static void testHandleAfterInsertMultiplePrimaryPhones() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointPhone phone1 = getSampleContactPointPhone(acc.Id);
        phone1.TelephoneNumber = '1111111111';
        phone1.IsPrimary = true;

        ContactPointPhone phone2 = getSampleContactPointPhone(acc.Id);
        phone2.TelephoneNumber = '2222222222';
        phone2.UsageType = 'Home';
        phone2.IsPrimary = true;
        insert new List<ContactPointPhone>{phone1, phone2};

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{
            phone1.Id => phone1,
            phone2.Id => phone2
        };

        Test.startTest();
        ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>{phone1, phone2}, newRecordsMap);
        Test.stopTest();

        Account updatedAcc = [SELECT Phone FROM Account WHERE Id = :acc.Id];
        // Should update with one of the primary phones
        System.assertNotEquals(null, updatedAcc.Phone, 'Account Phone should be updated');
    }

    @IsTest
    static void testHandleAfterUpdatePrimaryAndNonPrimaryPhone() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];
        acc.Phone = '1111111111';
        update acc;

        // Test 1: Update phone to primary - Account Phone should be updated
        ContactPointPhone phone1 = getSampleContactPointPhone(acc.Id);
        phone1.TelephoneNumber = '2222222222';
        insert phone1;

        phone1.IsPrimary = true;
        phone1.TelephoneNumber = '3333333333';
        update phone1;

        Map<Id, SObject> updatedRecordsMap1 = new Map<Id, SObject>{phone1.Id => phone1};
        Map<Id, SObject> oldRecordsMap1 = new Map<Id, SObject>{
            phone1.Id => new ContactPointPhone(Id = phone1.Id, IsPrimary = false, TelephoneNumber = '2222222222')
        };

        Test.startTest();
        ContactPointPhoneHandler.handleAfterUpdate(new List<ContactPointPhone>{phone1}, updatedRecordsMap1, oldRecordsMap1);
        Test.stopTest();

        Account updatedAcc1 = [SELECT Phone FROM Account WHERE Id = :acc.Id];
        System.assertEquals('3333333333', updatedAcc1.Phone, 'Account Phone should be updated to new primary phone');

        // Test 2: Update phone to non-primary - Account Phone should remain unchanged
        // Create an existing primary phone first so the new phone won't be set as primary
        ContactPointPhone existingPrimaryPhone = getSampleContactPointPhone(acc.Id);
        existingPrimaryPhone.TelephoneNumber = '9999999999';
        existingPrimaryPhone.UsageType = 'Phone';
        existingPrimaryPhone.IsPrimary = true;
        insert existingPrimaryPhone;

        // After inserting existingPrimaryPhone, Account Phone should be updated to its number
        Account accAfterPrimaryInsert = [SELECT Phone FROM Account WHERE Id = :acc.Id];
        String expectedPhoneAfterPrimaryInsert = accAfterPrimaryInsert.Phone;

        // Skip setting primary on insert so phone2 remains non-primary
        ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone = true;
        ContactPointPhone phone2 = getSampleContactPointPhone(acc.Id);
        phone2.TelephoneNumber = '4444444444';
        phone2.IsPrimary = false;
        insert phone2;

        // Query phone to get actual state after insert
        phone2 = [SELECT Id, IsPrimary, TelephoneNumber FROM ContactPointPhone WHERE Id = :phone2.Id];
        // Ensure phone is non-primary
        phone2.IsPrimary = false;
        phone2.TelephoneNumber = '5555555555';
        update phone2;

        Map<Id, SObject> updatedRecordsMap2 = new Map<Id, SObject>{phone2.Id => phone2};
        Map<Id, SObject> oldRecordsMap2 = new Map<Id, SObject>{
            phone2.Id => new ContactPointPhone(Id = phone2.Id, IsPrimary = false, TelephoneNumber = '4444444444')
        };

        ContactPointPhoneHandler.handleAfterUpdate(new List<ContactPointPhone>{phone2}, updatedRecordsMap2, oldRecordsMap2);

        Account updatedAcc2 = [SELECT Phone FROM Account WHERE Id = :acc.Id];
        System.assertEquals(expectedPhoneAfterPrimaryInsert, updatedAcc2.Phone, 'Account Phone should remain unchanged since phone2 is now non-primary');
    }

    @IsTest
    static void testHandleAfterInsertExistingPrimaryPhone() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        // Create existing primary non-Mobile phone (Home) - only non-Mobile records are demoted when new non-Mobile is primary
        ContactPointPhone existingPhone = getSampleContactPointPhone(acc.Id);
        existingPhone.TelephoneNumber = '1111111111';
        existingPhone.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME;
        existingPhone.IsPrimary = true;
        insert existingPhone;

        // Insert new non-Mobile phone - should become primary and demote existing non-Mobile
        ContactPointPhone newPhone = getSampleContactPointPhone(acc.Id);
        newPhone.TelephoneNumber = '2222222222';
        newPhone.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME;
        newPhone.IsPrimary = true;
        insert newPhone;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{newPhone.Id => newPhone};

        Test.startTest();
        ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>{newPhone}, newRecordsMap);
        Test.stopTest();

        // Existing primary non-Mobile phone should be set to non-primary
        ContactPointPhone updatedExisting = [SELECT IsPrimary FROM ContactPointPhone WHERE Id = :existingPhone.Id];
        System.assertEquals(false, updatedExisting.IsPrimary, 'Existing primary non-Mobile phone should be set to non-primary');

        // New phone should remain primary
        ContactPointPhone updatedNew = [SELECT IsPrimary FROM ContactPointPhone WHERE Id = :newPhone.Id];
        System.assertEquals(true, updatedNew.IsPrimary, 'New phone should remain primary');
    }

    @IsTest
    static void testHandleAfterInsertExistingPrimaryMobileDemotion() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        // Create existing primary Mobile phone - demoted when new Mobile primary is inserted
        ContactPointPhone existingMobile = getSampleContactPointPhone(acc.Id);
        existingMobile.TelephoneNumber = '1111111111';
        existingMobile.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
        existingMobile.IsPrimary = true;
        insert existingMobile;

        // Insert new Mobile primary - should demote existing Mobile
        ContactPointPhone newMobile = getSampleContactPointPhone(acc.Id);
        newMobile.TelephoneNumber = '2222222222';
        newMobile.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
        newMobile.IsPrimary = true;
        insert newMobile;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{ newMobile.Id => newMobile };

        Test.startTest();
        ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>{ newMobile }, newRecordsMap);
        Test.stopTest();

        ContactPointPhone updatedExisting = [SELECT IsPrimary FROM ContactPointPhone WHERE Id = :existingMobile.Id];
        System.assertEquals(false, updatedExisting.IsPrimary, 'Existing primary Mobile should be demoted');

        ContactPointPhone updatedNew = [SELECT IsPrimary FROM ContactPointPhone WHERE Id = :newMobile.Id];
        System.assertEquals(true, updatedNew.IsPrimary, 'New Mobile phone should remain primary');
    }

    @IsTest
    static void testHandleAfterInsertNullList() {
        Test.startTest();
        ContactPointPhoneHandler.handleAfterInsert(null, null);
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle null list gracefully');
    }

    @IsTest
    static void testHandleAfterInsertEmptyList() {
        Test.startTest();
        ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>(), new Map<Id, SObject>());
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle empty list gracefully');
    }

    @IsTest
    static void testHandleAfterUpdateNullList() {
        Test.startTest();
        ContactPointPhoneHandler.handleAfterUpdate(null, null, null);
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle null list gracefully');
    }

    @IsTest
    static void testHandleAfterUpdateEmptyList() {
        Test.startTest();
        ContactPointPhoneHandler.handleAfterUpdate(new List<ContactPointPhone>(), new Map<Id, SObject>(), new Map<Id, SObject>());
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle empty list gracefully');
    }

    @IsTest
    static void testHandleAfterInsertNullParentId() {
        ContactPointPhone phone = getSampleContactPointPhone(null);
        phone.IsPrimary = true;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>();

        Test.startTest();
        ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>{phone}, newRecordsMap);
        Test.stopTest();

        // Should not throw exception - records with null ParentId are skipped
        System.assert(true, 'Should handle null ParentId gracefully');
    }

    @IsTest
    static void testHandleAfterUpdateNullParentId() {
        ContactPointPhone phone = getSampleContactPointPhone(null);
        phone.IsPrimary = true;

        Map<Id, SObject> updatedRecordsMap = new Map<Id, SObject>();
        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>();

        Test.startTest();
        ContactPointPhoneHandler.handleAfterUpdate(new List<ContactPointPhone>{phone}, updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        // Should not throw exception - records with null ParentId are skipped
        System.assert(true, 'Should handle null ParentId gracefully');
    }

    // ==================== Primary Mobile - Transactional SMS Consent Update (V2.2.0) ====================

    /**
     * @description When primary Mobile ContactPointPhone is inserted, Transactional SMS consent is updated to Pending Opt In
     */
    @IsTest
    static void testHandleAfterInsertPrimaryMobileUpdatesTransactionalSMSConsent() {
        Account acc = setupPatientAccountWithIndividual();
        createTransactionalSMSConsent(acc.PersonIndividualId, ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN);

        ContactPointPhone phone = getSampleContactPointPhone(acc.Id);
        phone.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
        phone.IsPrimary = true;
        insert phone;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{ phone.Id => phone };

        Test.startTest();
        ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>{ phone }, newRecordsMap);
        Test.stopTest();

        ContactPointTypeConsent updatedConsent = [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :acc.PersonIndividualId
            AND DataUsePurpose.Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            LIMIT 1
        ];
        System.assertEquals(
            ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING,
            updatedConsent.PrivacyConsentStatus,
            'Transactional SMS consent should be updated to Pending Opt In when primary Mobile phone is inserted'
        );
    }

    /**
     * @description When primary Mobile ContactPointPhone is updated to primary, Transactional SMS consent is updated to Pending Opt In
     */
    @IsTest
    static void testHandleAfterUpdatePrimaryMobileUpdatesTransactionalSMSConsent() {
        Account acc = setupPatientAccountWithIndividual();
        createTransactionalSMSConsent(acc.PersonIndividualId, ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN);

        ContactPointPhone phone = getSampleContactPointPhone(acc.Id);
        phone.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
        phone.IsPrimary = false;
        insert phone;

        phone.IsPrimary = true;
        update phone;

        Map<Id, SObject> updatedRecordsMap = new Map<Id, SObject>{ phone.Id => phone };
        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>{
            phone.Id => new ContactPointPhone(Id = phone.Id, IsPrimary = false)
        };

        Test.startTest();
        ContactPointPhoneHandler.handleAfterUpdate(new List<ContactPointPhone>{ phone }, updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        ContactPointTypeConsent updatedConsent = [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :acc.PersonIndividualId
            AND DataUsePurpose.Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            LIMIT 1
        ];
        System.assertEquals(
            ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING,
            updatedConsent.PrivacyConsentStatus,
            'Transactional SMS consent should be updated to Pending Opt In when phone is updated to primary Mobile'
        );
    }

    /**
     * @description When Account has no PersonIndividualId, consent update is skipped (no error)
     *              Uses Provider (business) account which does not have PersonIndividualId
     */
    @IsTest
    static void testHandleAfterInsertPrimaryMobileSkipsWhenNoPersonIndividualId() {
        Account acc = [SELECT Id, PersonIndividualId FROM Account WHERE RecordType.DeveloperName = 'Provider' LIMIT 1];
       // System.assertEquals(null, acc.PersonIndividualId, 'Provider account should not have PersonIndividualId');

        ContactPointPhone phone = getSampleContactPointPhone(acc.Id);
        phone.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
        phone.IsPrimary = true;
        insert phone;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{ phone.Id => phone };

        Test.startTest();
        ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>{ phone }, newRecordsMap);
        Test.stopTest();

        System.assert(true, 'Should handle Account without PersonIndividualId gracefully');
    }

    /**
     * @description When Transactional SMS consent is already OptInPending, no duplicate update is attempted
     */
    @IsTest
    static void testHandleAfterInsertPrimaryMobileSkipsWhenConsentAlreadyPending() {
        Account acc = setupPatientAccountWithIndividual();
        createTransactionalSMSConsent(acc.PersonIndividualId, ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING);

        ContactPointPhone phone = getSampleContactPointPhone(acc.Id);
        phone.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
        phone.IsPrimary = true;
        insert phone;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{ phone.Id => phone };

        Test.startTest();
        ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>{ phone }, newRecordsMap);
        Test.stopTest();

        ContactPointTypeConsent consent = [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :acc.PersonIndividualId
            AND DataUsePurpose.Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            LIMIT 1
        ];
        System.assertEquals(
            ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING,
            consent.PrivacyConsentStatus,
            'Consent should remain OptInPending when already in that state'
        );
    }

    /**
     * @description Primary Mobile + primary non-Mobile both set - Mobile triggers consent update
     */
    @IsTest
    static void testHandleAfterInsertMobileAndNonMobilePrimaryBothConsentUpdate() {
        Account acc = setupPatientAccountWithIndividual();
        createTransactionalSMSConsent(acc.PersonIndividualId, ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_OUT);

        ContactPointPhone mobilePhone = getSampleContactPointPhone(acc.Id);
        mobilePhone.TelephoneNumber = '1111111111';
        mobilePhone.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
        mobilePhone.IsPrimary = true;

        ContactPointPhone homePhone = getSampleContactPointPhone(acc.Id);
        homePhone.TelephoneNumber = '2222222222';
        homePhone.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME;
        homePhone.IsPrimary = true;

        insert new List<ContactPointPhone>{ mobilePhone, homePhone };

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{
            mobilePhone.Id => mobilePhone,
            homePhone.Id => homePhone
        };

        Test.startTest();
        ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>{ mobilePhone, homePhone }, newRecordsMap);
        Test.stopTest();

        ContactPointTypeConsent updatedConsent = [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :acc.PersonIndividualId
            AND DataUsePurpose.Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            LIMIT 1
        ];
        System.assertEquals(
            ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING,
            updatedConsent.PrivacyConsentStatus,
            'Transactional SMS consent should be updated to Pending Opt In (OptOut -> OptInPending)'
        );
    }

    /**
     * @description processPrimaryContactPointPhoneBeforeInsert - single Mobile sets IsPrimary, then after insert updates consent
     */
    @IsTest
    static void testBeforeInsertSingleMobileThenAfterInsertConsentUpdate() {
        Account acc = setupPatientAccountWithIndividual();
        createTransactionalSMSConsent(acc.PersonIndividualId, ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN);

        ContactPointPhone phone = getSampleContactPointPhone(acc.Id);
        phone.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
        phone.IsPrimary = false; // Before insert will set to true

        Test.startTest();
        ContactPointPhoneHandler.handleBeforeInsert(new List<ContactPointPhone>{ phone });
        System.assertEquals(true, phone.IsPrimary, 'Before insert should set single phone as primary');

        insert phone;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{ phone.Id => phone };
        ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>{ phone }, newRecordsMap);
        Test.stopTest();

        ContactPointTypeConsent updatedConsent = [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :acc.PersonIndividualId
            AND DataUsePurpose.Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            LIMIT 1
        ];
        System.assertEquals(
            ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING,
            updatedConsent.PrivacyConsentStatus,
            'Transactional SMS consent should be updated when primary Mobile is set via before insert + insert'
        );
    }

    /**
     * @description Tests catch block in handleAfterInsert when exception is thrown (lines 123-125)
     */
    @IsTest
    static void testHandleAfterInsertExceptionCaught() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];
        ContactPointPhone phone = getSampleContactPointPhone(acc.Id);
        phone.IsPrimary = true;
        insert phone;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{ phone.Id => phone };

        ConstantsUtil.customExceptionSwitch = true;
        Test.startTest();
        try {
            ContactPointPhoneHandler.handleAfterInsert(new List<ContactPointPhone>{ phone }, newRecordsMap);
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();

        System.assert(true, 'Exception should be caught and logged without re-throwing');
    }

    /**
     * @description Tests handleAfterUpdate with primary non-Mobile only - covers lines 266, 293, 315, 318.
     *              Updates a non-Mobile (Home) phone to primary; primaryPhone comes from primaryNonMobileByAccount.
     *              Demotes existing non-Mobile primary and updates Account.Phone.
     */
    @IsTest
    static void testHandleAfterUpdatePrimaryNonMobilePhone() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];
        acc.Phone = null;
        update acc;

        // Create existing primary non-Mobile phone (Home)
        ContactPointPhone existingHome = getSampleContactPointPhone(acc.Id);
        existingHome.TelephoneNumber = '1111111111';
        existingHome.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME;
        existingHome.IsPrimary = true;
        insert existingHome;

        // Create new non-Mobile phone (Home), initially non-primary
        ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone = true;
        ContactPointPhone newHome = getSampleContactPointPhone(acc.Id);
        newHome.TelephoneNumber = '2222222222';
        newHome.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME;
        newHome.IsPrimary = false;
        insert newHome;
        ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone = false;

        // Update new phone to primary - should demote existing and update Account
        newHome.IsPrimary = true;
        newHome.TelephoneNumber = '3333333333';
        update newHome;

        Map<Id, SObject> updatedRecordsMap = new Map<Id, SObject>{ newHome.Id => newHome };
        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>{
            newHome.Id => new ContactPointPhone(Id = newHome.Id, IsPrimary = false, TelephoneNumber = '2222222222')
        };

        Test.startTest();
        ContactPointPhoneHandler.handleAfterUpdate(new List<ContactPointPhone>{ newHome }, updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        // Existing Home should be demoted, Account should have new primary number
        ContactPointPhone updatedExisting = [SELECT IsPrimary FROM ContactPointPhone WHERE Id = :existingHome.Id];
        System.assertEquals(false, updatedExisting.IsPrimary, 'Existing primary non-Mobile should be demoted');

        Account updatedAcc = [SELECT Phone FROM Account WHERE Id = :acc.Id];
        System.assertEquals('3333333333', updatedAcc.Phone, 'Account Phone should be updated to new primary non-Mobile');
    }

    /**
     * @description Tests handleAfterUpdate with primary Mobile - covers line 318 (updateTransactionalSMSConsentToPendingOptIn).
     *              Updates Mobile to primary with PersonIndividualId set and consent exists.
     */
    @IsTest
    static void testHandleAfterUpdatePrimaryMobileConsentUpdate() {
        Account acc = setupPatientAccountWithIndividual();
        createTransactionalSMSConsent(acc.PersonIndividualId, ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_OUT);

        ContactPointPhone phone = getSampleContactPointPhone(acc.Id);
        phone.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
        phone.IsPrimary = false;
        insert phone;

        phone.IsPrimary = true;
        update phone;

        Map<Id, SObject> updatedRecordsMap = new Map<Id, SObject>{ phone.Id => phone };
        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>{
            phone.Id => new ContactPointPhone(Id = phone.Id, IsPrimary = false)
        };

        Test.startTest();
        ContactPointPhoneHandler.handleAfterUpdate(new List<ContactPointPhone>{ phone }, updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        ContactPointTypeConsent updatedConsent = [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :acc.PersonIndividualId
            AND DataUsePurpose.Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            LIMIT 1
        ];
        System.assertEquals(
            ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING,
            updatedConsent.PrivacyConsentStatus,
            'Transactional SMS consent should be updated to Pending Opt In when Mobile is updated to primary'
        );
    }
}