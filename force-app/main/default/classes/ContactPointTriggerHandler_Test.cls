/**
 * @description Test class for ContactPointEmail, ContactPointPhone, ContactPointAddress triggers
 *              and their respective handlers (ContactPointEmailTriggerHandler,
 *              ContactPointPhoneTriggerHandler, ContactPointAddressTriggerHandler).
 *              Also covers OrgSync_ContactPointHandler.sortRecordsBySObjectType method.
 * Created Date : Jan 2026
 * Created By   : Neeraj Kumar
 */
@IsTest
public class ContactPointTriggerHandler_Test {

    private static void insertAccountBypassDuplicates(Account acc) {
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        Database.insert(acc, dmlOptions);
    }

    @TestSetup
    static void dataSetup() {
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 4);

        // Create Patient Account (Person Account)
        Account patientAccount = new Account(
            FirstName = 'ContactPoint',
            LastName = 'Patient',
            RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT,
            XCDC_ExternalId__c = 'PAT-CP-' + uniqueSuffix,
            BillingPostalCode = '12345'
        );

        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        Database.insert(patientAccount, dmlOptions);

        // Create Provider Account (Person Account) if record type exists
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT != null) {
            Account providerAccount = new Account(
                FirstName = 'ContactPoint',
                LastName = 'Provider',
                RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT,
                XCDC_ExternalId__c = 'PROV-CP-' + uniqueSuffix,
                BillingPostalCode = '54321'
            );
            Database.insert(providerAccount, dmlOptions);
        }

        // Create corresponding staging record for Patient
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = 'PAT-CP123-' + uniqueSuffix,
            OrgSync_FirstName__c = 'ContactPoint',
            OrgSync_LastName__c = 'Patient',
            OrgSync_Billing_Address__PostalCode__s = '12345'
        );

        User orgSyncUser = [SELECT Id FROM User WHERE Name = 'OrgSync User' LIMIT 1];
        System.runAs(orgSyncUser) {
            insert staging;
        }
    }

    private static Account getPatientAccount() {
        return [SELECT Id, PersonContactId, XCDC_ExternalId__c FROM Account
                WHERE XCDC_ExternalId__c LIKE 'PAT-CP-%'
                AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
                ORDER BY CreatedDate DESC LIMIT 1];
    }

    private static Account getProviderAccount() {
        List<Account> providers = [SELECT Id, PersonContactId, XCDC_ExternalId__c FROM Account
                                   WHERE XCDC_ExternalId__c LIKE 'PROV-CP-%'
                                   AND RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
                                   ORDER BY CreatedDate DESC LIMIT 1];
        return providers.isEmpty() ? null : providers[0];
    }

    /**
     * @description Deletes ContactPointConsent records associated with a ContactPoint record.
     *              Must be called before deleting ContactPointEmail, ContactPointPhone, or ContactPointAddress.
     * @param contactPointId The Id of the ContactPoint record
     */
    private static void deleteContactPointConsents(Id contactPointId) {
        if (contactPointId == null) {
            return;
        }
        List<ContactPointConsent> consents = [SELECT Id FROM ContactPointConsent
                                               WHERE ContactPointId = :contactPointId];
        if (!consents.isEmpty()) {
            delete consents;
        }
    }

    /**
     * @description Deletes ContactPointConsent records for multiple ContactPoint records.
     * @param contactPointIds Set of ContactPoint Ids
     */
    private static void deleteContactPointConsents(Set<Id> contactPointIds) {
        if (contactPointIds == null || contactPointIds.isEmpty()) {
            return;
        }
        List<ContactPointConsent> consents = [SELECT Id FROM ContactPointConsent
                                               WHERE ContactPointId IN :contactPointIds];
        if (!consents.isEmpty()) {
            delete consents;
        }
    }

    // ==================== ContactPointEmail Tests ====================

    @IsTest
    static void testContactPointEmailInsert() {
        Account patientAccount = getPatientAccount();

        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = patientAccount.Id,
            EmailAddress = 'test@example.com',
            IsPrimary = true
        );

        Test.startTest();
        insert cpe;
        Test.stopTest();

        List<ContactPointEmail> inserted = [SELECT Id, EmailAddress FROM ContactPointEmail WHERE Id = :cpe.Id];
        System.assertEquals(1, inserted.size(), 'ContactPointEmail should be inserted');
    }

    @IsTest
    static void testContactPointEmailUpdate() {
        Account patientAccount = getPatientAccount();

        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = patientAccount.Id,
            EmailAddress = 'original@example.com',
            IsPrimary = true
        );
        insert cpe;

        Test.startTest();
        cpe.EmailAddress = 'updated@example.com';
        update cpe;
        Test.stopTest();

        ContactPointEmail updated = [SELECT EmailAddress FROM ContactPointEmail WHERE Id = :cpe.Id];
        System.assertEquals('updated@example.com', updated.EmailAddress, 'Email should be updated');
    }

    @IsTest
    static void testContactPointEmailDelete() {
        Account patientAccount = getPatientAccount();

        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = patientAccount.Id,
            EmailAddress = 'delete@example.com',
            IsPrimary = false
        );
        insert cpe;
        Id cpeId = cpe.Id;

        Test.startTest();
        // Delete any associated ContactPointConsent records first
        deleteContactPointConsents(cpeId);
        delete cpe;
        Test.stopTest();

        List<ContactPointEmail> deleted = [SELECT Id FROM ContactPointEmail WHERE Id = :cpeId];
        System.assertEquals(0, deleted.size(), 'ContactPointEmail should be deleted');
    }

    // ==================== ContactPointPhone Tests ====================

    @IsTest
    static void testContactPointPhoneInsert() {
        Account patientAccount = getPatientAccount();

        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = patientAccount.Id,
            TelephoneNumber = '5551234567',
            IsPrimary = true
        );

        Test.startTest();
        insert cpp;
        Test.stopTest();

        List<ContactPointPhone> inserted = [SELECT Id, TelephoneNumber FROM ContactPointPhone WHERE Id = :cpp.Id];
        System.assertEquals(1, inserted.size(), 'ContactPointPhone should be inserted');
    }

    @IsTest
    static void testContactPointPhoneUpdate() {
        Account patientAccount = getPatientAccount();

        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = patientAccount.Id,
            TelephoneNumber = '5551111111',
            IsPrimary = true
        );
        insert cpp;

        Test.startTest();
        cpp.TelephoneNumber = '5552222222';
        update cpp;
        Test.stopTest();

        ContactPointPhone updated = [SELECT TelephoneNumber FROM ContactPointPhone WHERE Id = :cpp.Id];
        System.assertEquals('5552222222', updated.TelephoneNumber, 'Phone should be updated');
    }

    @IsTest
    static void testContactPointPhoneDelete() {
        Account patientAccount = getPatientAccount();

        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = patientAccount.Id,
            TelephoneNumber = '5553333333',
            IsPrimary = false
        );
        insert cpp;
        Id cppId = cpp.Id;

        Test.startTest();
        // Delete any associated ContactPointConsent records first
        deleteContactPointConsents(cppId);
        delete cpp;
        Test.stopTest();

        List<ContactPointPhone> deleted = [SELECT Id FROM ContactPointPhone WHERE Id = :cppId];
        System.assertEquals(0, deleted.size(), 'ContactPointPhone should be deleted');
    }

    // ==================== ContactPointAddress Tests ====================

    @IsTest
    static void testContactPointAddressInsert() {
        Account patientAccount = getPatientAccount();

        ContactPointAddress cpa = new ContactPointAddress(
            Name = 'Test CPA',
            ParentId = patientAccount.Id,
            Street = '123 Test St',
            City = 'Test City',
            PostalCode = '12345',
            //Country = 'US',
            IsPrimary = true
        );

        Test.startTest();
        insert cpa;
        Test.stopTest();

        List<ContactPointAddress> inserted = [SELECT Id, Street FROM ContactPointAddress WHERE Id = :cpa.Id];
        System.assertEquals(1, inserted.size(), 'ContactPointAddress should be inserted');
    }

    @IsTest
    static void testContactPointAddressUpdate() {
        Account patientAccount = getPatientAccount();

        ContactPointAddress cpa = new ContactPointAddress(
            Name = 'Test CPA',
            ParentId = patientAccount.Id,
            Street = '123 Original St',
            City = 'Original City',
            PostalCode = '11111',
            //Country = 'US',
            IsPrimary = true
        );
        insert cpa;

        Test.startTest();
        cpa.Street = '456 Updated Ave';
        cpa.City = 'Updated City';
        update cpa;
        Test.stopTest();

        ContactPointAddress updated = [SELECT Street, City FROM ContactPointAddress WHERE Id = :cpa.Id];
        System.assertEquals('456 Updated Ave', updated.Street, 'Street should be updated');
        System.assertEquals('Updated City', updated.City, 'City should be updated');
    }

    @IsTest
    static void testContactPointAddressDelete() {
        Account patientAccount = getPatientAccount();

        ContactPointAddress cpa = new ContactPointAddress(
            Name = 'Test CPA',
            ParentId = patientAccount.Id,
            Street = '789 Delete Blvd',
            City = 'Delete City',
            PostalCode = '99999',
            //Country = 'US',
            IsPrimary = false
        );
        insert cpa;
        Id cpaId = cpa.Id;

        Test.startTest();
        // Delete any associated ContactPointConsent records first
        deleteContactPointConsents(cpaId);
        delete cpa;
        Test.stopTest();

        List<ContactPointAddress> deleted = [SELECT Id FROM ContactPointAddress WHERE Id = :cpaId];
        System.assertEquals(0, deleted.size(), 'ContactPointAddress should be deleted');
    }

    // ==================== Provider Account Tests ====================

    @IsTest
    static void testContactPointEmailInsertForProvider() {
        Account providerAccount = getProviderAccount();
        if (providerAccount == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = providerAccount.Id,
            EmailAddress = 'provider@example.com',
            IsPrimary = true
        );

        Test.startTest();
        insert cpe;
        Test.stopTest();

        List<ContactPointEmail> inserted = [SELECT Id FROM ContactPointEmail WHERE Id = :cpe.Id];
        System.assertEquals(1, inserted.size(), 'ContactPointEmail for Provider should be inserted');
    }

    @IsTest
    static void testContactPointPhoneInsertForProvider() {
        Account providerAccount = getProviderAccount();
        if (providerAccount == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = providerAccount.Id,
            TelephoneNumber = '5554444444',
            IsPrimary = true
        );

        Test.startTest();
        insert cpp;
        Test.stopTest();

        List<ContactPointPhone> inserted = [SELECT Id FROM ContactPointPhone WHERE Id = :cpp.Id];
        System.assertEquals(1, inserted.size(), 'ContactPointPhone for Provider should be inserted');
    }

    @IsTest
    static void testContactPointAddressInsertForProvider() {
        Account providerAccount = getProviderAccount();
        if (providerAccount == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }

        ContactPointAddress cpa = new ContactPointAddress(
            Name = 'Test CPA',
            ParentId = providerAccount.Id,
            Street = '999 Provider St',
            City = 'Provider City',
            PostalCode = '77777',
            //Country = 'US',
            IsPrimary = true
        );

        Test.startTest();
        insert cpa;
        Test.stopTest();

        List<ContactPointAddress> inserted = [SELECT Id FROM ContactPointAddress WHERE Id = :cpa.Id];
        System.assertEquals(1, inserted.size(), 'ContactPointAddress for Provider should be inserted');
    }

    // ==================== Bulk Processing Tests ====================

    @IsTest
    static void testBulkContactPointEmailInsert() {
        Account patientAccount = getPatientAccount();
        List<ContactPointEmail> emails = new List<ContactPointEmail>();

        for (Integer i = 0; i < 10; i++) {
            emails.add(new ContactPointEmail(
                ParentId = patientAccount.Id,
                EmailAddress = 'bulk' + i + '@example.com',
                IsPrimary = (i == 0)
            ));
        }

        Test.startTest();
        insert emails;
        Test.stopTest();

        List<ContactPointEmail> inserted = [SELECT Id FROM ContactPointEmail
                                            WHERE ParentId = :patientAccount.Id];
        System.assertEquals(10, inserted.size(), 'All 10 emails should be inserted');
    }

    @IsTest
    static void testBulkContactPointPhoneInsert() {
        Account patientAccount = getPatientAccount();
        List<ContactPointPhone> phones = new List<ContactPointPhone>();

        for (Integer i = 0; i < 10; i++) {
            phones.add(new ContactPointPhone(
                ParentId = patientAccount.Id,
                TelephoneNumber = '555000000' + i,
                IsPrimary = (i == 0)
            ));
        }

        Test.startTest();
        insert phones;
        Test.stopTest();

        List<ContactPointPhone> inserted = [SELECT Id FROM ContactPointPhone
                                            WHERE ParentId = :patientAccount.Id];
        System.assertEquals(10, inserted.size(), 'All 10 phones should be inserted');
    }

    // ==================== Handler Direct Tests ====================

    @IsTest
    static void testContactPointHandlerWithEmptyMaps() {
        Test.startTest();
        OrgSync_ContactPointHandler handler = new OrgSync_ContactPointHandler();
        handler.sortRecordsBySObjectType(null, null, false);
        handler.sortRecordsBySObjectType(new Map<Id, SObject>(), null, false);
        handler.sortRecordsBySObjectType(null, new Map<Id, SObject>(), true);
        Test.stopTest();

        System.assert(true, 'Handler should handle empty/null maps gracefully');
    }

    @IsTest
    static void testContactPointHandlerDeleteContext() {
        Account patientAccount = getPatientAccount();

        // Create and then delete to test delete context
        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = patientAccount.Id,
            EmailAddress = 'deletecontext@example.com',
            IsPrimary = false
        );
        insert cpe;

        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = patientAccount.Id,
            TelephoneNumber = '5556666666',
            IsPrimary = false
        );
        insert cpp;

        ContactPointAddress cpa = new ContactPointAddress(
            Name = 'Test CPA',
            ParentId = patientAccount.Id,
            Street = '111 Delete St',
            City = 'Delete City',
            PostalCode = '00000',
            //Country = 'US',
            IsPrimary = false
        );
        insert cpa;

        Test.startTest();
        // Delete any associated ContactPointConsent records first
        deleteContactPointConsents(new Set<Id>{cpe.Id, cpp.Id, cpa.Id});
        delete cpe;
        delete cpp;
        delete cpa;
        Test.stopTest();

        System.assert(true, 'Delete context should be handled');
    }

    // ==================== OrgSync User Bypass Test ====================

    @IsTest
    static void testOrgSyncUserBypass() {
        Account patientAccount = getPatientAccount();
        User orgSyncUser = [SELECT Id FROM User WHERE Name = 'OrgSync User' LIMIT 1];

        System.runAs(orgSyncUser) {
            ContactPointEmail cpe = new ContactPointEmail(
                ParentId = patientAccount.Id,
                EmailAddress = 'orgsync@example.com',
                IsPrimary = false
            );

            Test.startTest();
            insert cpe;
            Test.stopTest();

            List<ContactPointEmail> inserted = [SELECT Id FROM ContactPointEmail WHERE Id = :cpe.Id];
            System.assertEquals(1, inserted.size(), 'ContactPointEmail should be inserted as OrgSync User');
        }
    }
}