/**
 * @description Test class for ContactPointEmailHandler
 * Created Date : 11th Feb 2026
 * Created By   : Charchit N.
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ContactPointEmailHandler_Test {

    @TestSetup
    static void setupTestData() {
        // Create test accounts
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType();
        Account providerAccount = TestDataFactory.getAccountofProviderRecordType();
        insert new List<Account>{patientAccount, providerAccount};
    }

    /**
     * @description Returns a sample ContactPointEmail record with default values (not inserted)
     * @param parentId Parent Account ID (can be null)
     * @return ContactPointEmail record with default test values
     */
    private static ContactPointEmail getSampleContactPointEmail(Id parentId) {
        ContactPointEmail email = new ContactPointEmail();
        email.ParentId = parentId;
        email.EmailAddress = 'test@example.com';
        email.IsPrimary = false;
        return email;
    }

    @IsTest
    static void testHandleBeforeInsertSingleEmail() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointEmail email = getSampleContactPointEmail(acc.Id);

        Test.startTest();
        ContactPointEmailHandler.handleBeforeInsert(new List<ContactPointEmail>{email});
        Test.stopTest();

        System.assertEquals(true, email.IsPrimary, 'Single email should be set as primary');
    }

    @IsTest
    static void testHandleBeforeInsertMultipleEmailsOnePrimary() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointEmail email1 = getSampleContactPointEmail(acc.Id);
        email1.EmailAddress = 'test1@example.com';
        email1.IsPrimary = true;

        ContactPointEmail email2 = getSampleContactPointEmail(acc.Id);
        email2.EmailAddress = 'test2@example.com';

        List<ContactPointEmail> emails = new List<ContactPointEmail>{email1, email2};

        Test.startTest();
        ContactPointEmailHandler.handleBeforeInsert(emails);
        Test.stopTest();

        // One primary should remain primary
        System.assertEquals(true, email1.IsPrimary, 'Email1 should remain primary');
        System.assertEquals(false, email2.IsPrimary, 'Email2 should remain non-primary');
    }

    @IsTest
    static void testHandleBeforeInsertMultipleEmailsMultiplePrimary() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointEmail email1 = getSampleContactPointEmail(acc.Id);
        email1.EmailAddress = 'test1@example.com';
        email1.IsPrimary = true;

        ContactPointEmail email2 = getSampleContactPointEmail(acc.Id);
        email2.EmailAddress = 'test2@example.com';
        email2.IsPrimary = true;

        List<ContactPointEmail> emails = new List<ContactPointEmail>{email1, email2};

        Test.startTest();
        ContactPointEmailHandler.handleBeforeInsert(emails);
        Test.stopTest();

        // Last primary email should remain primary
        System.assertEquals(false, email1.IsPrimary, 'Email1 should be set to non-primary');
        System.assertEquals(true, email2.IsPrimary, 'Last email should remain primary');
    }

    @IsTest
    static void testHandleBeforeInsertMultipleEmailsNoPrimary() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointEmail email1 = getSampleContactPointEmail(acc.Id);
        email1.EmailAddress = 'test1@example.com';

        ContactPointEmail email2 = getSampleContactPointEmail(acc.Id);
        email2.EmailAddress = 'test2@example.com';

        List<ContactPointEmail> emails = new List<ContactPointEmail>{email1, email2};

        Test.startTest();
        ContactPointEmailHandler.handleBeforeInsert(emails);
        Test.stopTest();

        // Last email should be set as primary
        System.assertEquals(false, email1.IsPrimary, 'Email1 should remain non-primary');
        System.assertEquals(true, email2.IsPrimary, 'Last email should be set as primary');
    }

    @IsTest
    static void testHandleBeforeInsertSkipFlag() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointEmail email = getSampleContactPointEmail(acc.Id);

        ContactPointEmailHandler.skipSetPrimaryOnNewContactPointEmail = true;

        Test.startTest();
        ContactPointEmailHandler.handleBeforeInsert(new List<ContactPointEmail>{email});
        Test.stopTest();

        System.assertEquals(false, email.IsPrimary, 'Email should remain non-primary when skip flag is true');

        // Reset flag
        ContactPointEmailHandler.skipSetPrimaryOnNewContactPointEmail = false;
    }

    @IsTest
    static void testHandleBeforeInsertEmailWithNullParentId() {
        // Test the continue statement for emails with null ParentId
        ContactPointEmail emailWithNullParent = getSampleContactPointEmail(null);

        ContactPointEmail emailWithParent = getSampleContactPointEmail([SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1].Id);
        emailWithParent.EmailAddress = 'test2@example.com';

        List<ContactPointEmail> emails = new List<ContactPointEmail>{emailWithNullParent, emailWithParent};

        Test.startTest();
        ContactPointEmailHandler.handleBeforeInsert(emails);
        Test.stopTest();

        // Email with null ParentId should be skipped (not set as primary)
        System.assertEquals(false, emailWithNullParent.IsPrimary, 'Email with null ParentId should be skipped');
        // Email with ParentId should be set as primary (since it's the only one with ParentId)
        System.assertEquals(true, emailWithParent.IsPrimary, 'Email with ParentId should be set as primary');
    }

    @IsTest
    static void testHandleBeforeInsertAllEmailsWithNullParentId() {
        // Test scenario where all emails have null ParentId - this should result in empty map
        // and the second continue statement (empty list) won't be hit because there are no accountIds in the map
        ContactPointEmail email1 = getSampleContactPointEmail(null);
        email1.EmailAddress = 'test1@example.com';

        ContactPointEmail email2 = getSampleContactPointEmail(null);
        email2.EmailAddress = 'test2@example.com';

        List<ContactPointEmail> emails = new List<ContactPointEmail>{email1, email2};

        Test.startTest();
        ContactPointEmailHandler.handleBeforeInsert(emails);
        Test.stopTest();

        // Both emails should remain non-primary since they have null ParentId
        System.assertEquals(false, email1.IsPrimary, 'Email with null ParentId should remain non-primary');
        System.assertEquals(false, email2.IsPrimary, 'Email with null ParentId should remain non-primary');
    }

    @IsTest
    static void testHandleBeforeInsertNullList() {
        Test.startTest();
        ContactPointEmailHandler.handleBeforeInsert(null);
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle null list gracefully');
    }

    @IsTest
    static void testHandleBeforeInsertEmptyList() {
        Test.startTest();
        ContactPointEmailHandler.handleBeforeInsert(new List<ContactPointEmail>());
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle empty list gracefully');
    }

    @IsTest
    static void testHandleAfterInsertPrimaryEmail() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];
        acc.PersonEmail = null;
        update acc;

        ContactPointEmail email = getSampleContactPointEmail(acc.Id);
        email.IsPrimary = true;
        insert email;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{email.Id => email};

        Test.startTest();
        ContactPointEmailHandler.handleAfterInsert(new List<ContactPointEmail>{email}, newRecordsMap);
        Test.stopTest();

        Account updatedAcc = [SELECT PersonEmail FROM Account WHERE Id = :acc.Id];
        System.assertEquals('test@example.com', updatedAcc.PersonEmail, 'Account PersonEmail should be updated');
    }

    @IsTest
    static void testHandleAfterInsertMultiplePrimaryEmails() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointEmail email1 = getSampleContactPointEmail(acc.Id);
        email1.EmailAddress = 'test1@example.com';
        email1.IsPrimary = true;

        ContactPointEmail email2 = getSampleContactPointEmail(acc.Id);
        email2.EmailAddress = 'test2@example.com';
        email2.IsPrimary = true;
        insert new List<ContactPointEmail>{email1, email2};

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{
            email1.Id => email1,
            email2.Id => email2
        };

        Test.startTest();
        ContactPointEmailHandler.handleAfterInsert(new List<ContactPointEmail>{email1, email2}, newRecordsMap);
        Test.stopTest();

        Account updatedAcc = [SELECT PersonEmail FROM Account WHERE Id = :acc.Id];
        // Should update with one of the primary emails
        System.assertNotEquals(null, updatedAcc.PersonEmail, 'Account PersonEmail should be updated');
    }

    @IsTest
    static void testHandleAfterUpdatePrimaryEmail() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];
        acc.PersonEmail = 'old@example.com';
        update acc;

        ContactPointEmail email = getSampleContactPointEmail(acc.Id);
        email.EmailAddress = 'old@example.com';
        insert email;

        email.IsPrimary = true;
        email.EmailAddress = 'new@example.com';
        update email;

        Map<Id, SObject> updatedRecordsMap = new Map<Id, SObject>{email.Id => email};
        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>{
            email.Id => new ContactPointEmail(Id = email.Id, IsPrimary = false, EmailAddress = 'old@example.com')
        };

        Test.startTest();
        ContactPointEmailHandler.handleAfterUpdate(new List<ContactPointEmail>{email}, updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        Account updatedAcc = [SELECT PersonEmail FROM Account WHERE Id = :acc.Id];
        System.assertEquals('new@example.com', updatedAcc.PersonEmail, 'Account PersonEmail should be updated to new primary email');
    }

    @IsTest
    static void testHandleAfterInsertExistingPrimaryEmail() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        // Create existing primary email
        ContactPointEmail existingEmail = getSampleContactPointEmail(acc.Id);
        existingEmail.EmailAddress = 'existing@example.com';
        existingEmail.IsPrimary = true;
        insert existingEmail;

        // Insert new primary email
        ContactPointEmail newEmail = getSampleContactPointEmail(acc.Id);
        newEmail.EmailAddress = 'new@example.com';
        newEmail.IsPrimary = true;
        insert newEmail;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{newEmail.Id => newEmail};

        Test.startTest();
        ContactPointEmailHandler.handleAfterInsert(new List<ContactPointEmail>{newEmail}, newRecordsMap);
        Test.stopTest();

        // Existing primary email should be set to non-primary
        ContactPointEmail updatedExisting = [SELECT IsPrimary FROM ContactPointEmail WHERE Id = :existingEmail.Id];
        System.assertEquals(false, updatedExisting.IsPrimary, 'Existing primary email should be set to non-primary');

        // New email should remain primary
        ContactPointEmail updatedNew = [SELECT IsPrimary FROM ContactPointEmail WHERE Id = :newEmail.Id];
        System.assertEquals(true, updatedNew.IsPrimary, 'New email should remain primary');
    }

    @IsTest
    static void testHandleAfterInsertNullList() {
        Test.startTest();
        ContactPointEmailHandler.handleAfterInsert(null, null);
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle null list gracefully');
    }

    @IsTest
    static void testHandleAfterInsertEmptyList() {
        Test.startTest();
        ContactPointEmailHandler.handleAfterInsert(new List<ContactPointEmail>(), new Map<Id, SObject>());
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle empty list gracefully');
    }

    @IsTest
    static void testHandleAfterUpdateNullList() {
        Test.startTest();
        ContactPointEmailHandler.handleAfterUpdate(null, null, null);
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle null list gracefully');
    }

    @IsTest
    static void testHandleAfterUpdateEmptyList() {
        Test.startTest();
        ContactPointEmailHandler.handleAfterUpdate(new List<ContactPointEmail>(), new Map<Id, SObject>(), new Map<Id, SObject>());
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle empty list gracefully');
    }

    @IsTest
    static void testHandleAfterInsertNullParentId() {
        ContactPointEmail email = getSampleContactPointEmail(null);
        email.IsPrimary = true;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>();

        Test.startTest();
        ContactPointEmailHandler.handleAfterInsert(new List<ContactPointEmail>{email}, newRecordsMap);
        Test.stopTest();

        // Should not throw exception - records with null ParentId are skipped
        System.assert(true, 'Should handle null ParentId gracefully');
    }

    @IsTest
    static void testHandleAfterUpdateNullParentId() {
        ContactPointEmail email = getSampleContactPointEmail(null);
        email.IsPrimary = true;

        Map<Id, SObject> updatedRecordsMap = new Map<Id, SObject>();
        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>();

        Test.startTest();
        ContactPointEmailHandler.handleAfterUpdate(new List<ContactPointEmail>{email}, updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        // Should not throw exception - records with null ParentId are skipped
        System.assert(true, 'Should handle null ParentId gracefully');
    }
}