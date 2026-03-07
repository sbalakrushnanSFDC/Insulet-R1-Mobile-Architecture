/**
 * @description Test class for ContactPointAddressHandler
 * Created Date : 11th Feb 2026
 * Created By   : Charchit N.
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ContactPointAddressHandler_Test {

    @TestSetup
    static void setupTestData() {
        // Create test accounts
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType();
        Account providerAccount = TestDataFactory.getAccountofProviderRecordType();
        insert new List<Account>{patientAccount, providerAccount};
    }

    /**
     * @description Returns a sample ContactPointAddress record with default values (not inserted)
     * @param parentId Parent Account ID (can be null)
     * @return ContactPointAddress record with default test values
     */
    private static ContactPointAddress getSampleContactPointAddress(Id parentId) {
        ContactPointAddress address = new ContactPointAddress();
        address.ParentId = parentId;
        address.Name = 'Test Address';
        address.Street = '123 Test St';
        address.City = 'Test City';
        address.State = 'California';
        address.PostalCode = '12345';
        address.Country = 'United States';
        address.IsPrimary = false;
        return address;
    }


    @IsTest
    static void testHandleBeforeInsertSingleAddress() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointAddress address = getSampleContactPointAddress(acc.Id);

        Test.startTest();
        ContactPointAddressHandler.handleBeforeInsert(new List<ContactPointAddress>{address});
        Test.stopTest();

        System.assertEquals(true, address.IsPrimary, 'Single address should be set as primary');
    }

    @IsTest
    static void testHandleBeforeInsertMultipleAddressesOnePrimary() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointAddress address1 = getSampleContactPointAddress(acc.Id);
        address1.Name = 'Test Address 1';
        address1.IsPrimary = true;

        ContactPointAddress address2 = getSampleContactPointAddress(acc.Id);
        address2.Name = 'Test Address 2';
        address2.Street = '456 Test Ave';
        address2.IsPrimary = false;

        List<ContactPointAddress> addresses = new List<ContactPointAddress>{address1, address2};

        Test.startTest();
        ContactPointAddressHandler.handleBeforeInsert(addresses);
        Test.stopTest();

        // One primary should remain primary
        System.assertEquals(true, address1.IsPrimary, 'Address1 should remain primary');
        System.assertEquals(false, address2.IsPrimary, 'Address2 should remain non-primary');
    }

    @IsTest
    static void testHandleBeforeInsertMultipleAddressesMultiplePrimary() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointAddress address1 = getSampleContactPointAddress(acc.Id);
        address1.Name = 'Test Address 1';
        address1.IsPrimary = true;

        ContactPointAddress address2 = getSampleContactPointAddress(acc.Id);
        address2.Name = 'Test Address 2';
        address2.Street = '456 Test Ave';
        address2.IsPrimary = true;

        List<ContactPointAddress> addresses = new List<ContactPointAddress>{address1, address2};

        Test.startTest();
        ContactPointAddressHandler.handleBeforeInsert(addresses);
        Test.stopTest();

        // Last primary address should remain primary
        System.assertEquals(false, address1.IsPrimary, 'Address1 should be set to non-primary');
        System.assertEquals(true, address2.IsPrimary, 'Last address should remain primary');
    }

    @IsTest
    static void testHandleBeforeInsertMultipleAddressesNoPrimary() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointAddress address1 = getSampleContactPointAddress(acc.Id);
        address1.Name = 'Test Address 1';

        ContactPointAddress address2 = getSampleContactPointAddress(acc.Id);
        address2.Name = 'Test Address 2';
        address2.Street = '456 Test Ave';

        List<ContactPointAddress> addresses = new List<ContactPointAddress>{address1, address2};

        Test.startTest();
        ContactPointAddressHandler.handleBeforeInsert(addresses);
        Test.stopTest();

        // Last address should be set as primary
        System.assertEquals(false, address1.IsPrimary, 'Address1 should remain non-primary');
        System.assertEquals(true, address2.IsPrimary, 'Last address should be set as primary');
    }

    @IsTest
    static void testHandleBeforeInsertSkipFlag() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointAddress address = getSampleContactPointAddress(acc.Id);

        ContactPointAddressHandler.skipSetPrimaryOnNewContactPointAddress = true;

        Test.startTest();
        ContactPointAddressHandler.handleBeforeInsert(new List<ContactPointAddress>{address});
        Test.stopTest();

        System.assertEquals(false, address.IsPrimary, 'Address should remain non-primary when skip flag is true');

        // Reset flag
        ContactPointAddressHandler.skipSetPrimaryOnNewContactPointAddress = false;
    }

    @IsTest
    static void testHandleBeforeInsertAddressWithNullParentId() {
        // Test the continue statement for addresses with null ParentId
        ContactPointAddress addressWithNullParent = getSampleContactPointAddress(null);

        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];
        ContactPointAddress addressWithParent = getSampleContactPointAddress(acc.Id);
        addressWithParent.Name = 'Test Address 2';
        addressWithParent.Street = '456 Test Ave';

        List<ContactPointAddress> addresses = new List<ContactPointAddress>{addressWithNullParent, addressWithParent};

        Test.startTest();
        ContactPointAddressHandler.handleBeforeInsert(addresses);
        Test.stopTest();

        // Address with null ParentId should be skipped (not set as primary)
        System.assertEquals(false, addressWithNullParent.IsPrimary, 'Address with null ParentId should be skipped');
        // Address with ParentId should be set as primary (since it's the only one with ParentId)
        System.assertEquals(true, addressWithParent.IsPrimary, 'Address with ParentId should be set as primary');
    }

    @IsTest
    static void testHandleBeforeInsertAllAddressesWithNullParentId() {
        // Test scenario where all addresses have null ParentId - this should result in empty map
        // and the second continue statement (empty list) won't be hit because there are no accountIds in the map
        ContactPointAddress address1 = getSampleContactPointAddress(null);
        address1.Name = 'Test Address 1';

        ContactPointAddress address2 = getSampleContactPointAddress(null);
        address2.Name = 'Test Address 2';
        address2.Street = '456 Test Ave';

        List<ContactPointAddress> addresses = new List<ContactPointAddress>{address1, address2};

        Test.startTest();
        ContactPointAddressHandler.handleBeforeInsert(addresses);
        Test.stopTest();

        // Both addresses should remain non-primary since they have null ParentId
        System.assertEquals(false, address1.IsPrimary, 'Address with null ParentId should remain non-primary');
        System.assertEquals(false, address2.IsPrimary, 'Address with null ParentId should remain non-primary');
    }

    @IsTest
    static void testHandleBeforeInsertNullList() {
        Test.startTest();
        ContactPointAddressHandler.handleBeforeInsert(null);
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle null list gracefully');
    }

    @IsTest
    static void testHandleBeforeInsertEmptyList() {
        Test.startTest();
        ContactPointAddressHandler.handleBeforeInsert(new List<ContactPointAddress>());
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle empty list gracefully');
    }

    @IsTest
    static void testHandleAfterInsertPrimaryAddress() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];
        acc.BillingStreet = null;
        acc.BillingCity = null;
        acc.BillingState = null;
        acc.BillingPostalCode = null;
        acc.BillingCountry = null;
        update acc;

        ContactPointAddress address = getSampleContactPointAddress(acc.Id);
        address.Name = 'Address 1';
        address.IsPrimary = true;
        insert address;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{address.Id => address};

        Test.startTest();
        ContactPointAddressHandler.handleAfterInsert(new List<ContactPointAddress>{address}, newRecordsMap);
        Test.stopTest();

        Account updatedAcc = [SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
                              FROM Account WHERE Id = :acc.Id];
        System.assertEquals('123 Test St', updatedAcc.BillingStreet, 'Account BillingStreet should be updated');
        System.assertEquals('Test City', updatedAcc.BillingCity, 'Account BillingCity should be updated');
    }

    @IsTest
    static void testHandleAfterInsertMultiplePrimaryAddresses() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        ContactPointAddress address1 = getSampleContactPointAddress(acc.Id);
        address1.Name = 'Test Address 1';
        address1.IsPrimary = true;

        ContactPointAddress address2 = getSampleContactPointAddress(acc.Id);
        address2.Name = 'Test Address 2';
        address2.Street = '456 Test Ave';
        address2.IsPrimary = true;
        insert new List<ContactPointAddress>{address1, address2};

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{
            address1.Id => address1,
            address2.Id => address2
        };

        Test.startTest();
        ContactPointAddressHandler.handleAfterInsert(new List<ContactPointAddress>{address1, address2}, newRecordsMap);
        Test.stopTest();

        Account updatedAcc = [SELECT BillingStreet FROM Account WHERE Id = :acc.Id];
        // Should update with one of the primary addresses
        System.assertNotEquals(null, updatedAcc.BillingStreet, 'Account BillingStreet should be updated');
    }

    @IsTest
    static void testHandleAfterUpdatePrimaryAddress() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];
        acc.BillingStreet = 'Old St';
        acc.BillingCity = 'Old City';
        update acc;

        ContactPointAddress address = getSampleContactPointAddress(acc.Id);
        address.Name = 'Address 1';
        address.Street = 'Old St';
        address.City = 'Old City';
        insert address;

        address.IsPrimary = true;
        address.Street = 'New St';
        address.City = 'New City';
        update address;

        Map<Id, SObject> updatedRecordsMap = new Map<Id, SObject>{address.Id => address};
        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>{
            address.Id => new ContactPointAddress(
                Id = address.Id,
                IsPrimary = false,
                Street = 'Old St',
                City = 'Old City'
            )
        };

        Test.startTest();
        ContactPointAddressHandler.handleAfterUpdate(new List<ContactPointAddress>{address}, updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        Account updatedAcc = [SELECT BillingStreet, BillingCity FROM Account WHERE Id = :acc.Id];
        System.assertEquals('New St', updatedAcc.BillingStreet, 'Account BillingStreet should be updated to new primary address');
        System.assertEquals('New City', updatedAcc.BillingCity, 'Account BillingCity should be updated to new primary address');
    }

    @IsTest
    static void testHandleAfterInsertExistingPrimaryAddress() {
        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Patient' LIMIT 1];

        // Create existing primary address
        ContactPointAddress existingAddress = getSampleContactPointAddress(acc.Id);
        existingAddress.Name = 'Address 1';
        existingAddress.Street = 'Existing St';
        existingAddress.City = 'Existing City';
        existingAddress.IsPrimary = true;
        insert existingAddress;

        Test.startTest();
        
        ContactPointAddress newAddress = getSampleContactPointAddress(acc.Id);
        newAddress.Name = 'Address 2';
        newAddress.Street = 'New St';
        newAddress.City = 'New City';
        newAddress.IsPrimary = true;
        insert newAddress;
        
        Test.stopTest();

        // Existing primary address should be set to non-primary
        ContactPointAddress updatedExisting = [SELECT IsPrimary FROM ContactPointAddress WHERE Name = 'Address 1'];
        System.assertEquals(false, updatedExisting.IsPrimary, 'Existing primary address should be set to non-primary');

        // New address should remain primary
        ContactPointAddress updatedNew = [SELECT IsPrimary FROM ContactPointAddress WHERE Name = 'Address 2'];
        System.assertEquals(true, updatedNew.IsPrimary, 'New address should remain primary');
    }

    @IsTest
    static void testHandleAfterInsertNullList() {
        Test.startTest();
        ContactPointAddressHandler.handleAfterInsert(null, null);
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle null list gracefully');
    }

    @IsTest
    static void testHandleAfterInsertEmptyList() {
        Test.startTest();
        ContactPointAddressHandler.handleAfterInsert(new List<ContactPointAddress>(), new Map<Id, SObject>());
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle empty list gracefully');
    }

    @IsTest
    static void testHandleAfterUpdateNullList() {
        Test.startTest();
        ContactPointAddressHandler.handleAfterUpdate(null, null, null);
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle null list gracefully');
    }

    @IsTest
    static void testHandleAfterUpdateEmptyList() {
        Test.startTest();
        ContactPointAddressHandler.handleAfterUpdate(new List<ContactPointAddress>(), new Map<Id, SObject>(), new Map<Id, SObject>());
        Test.stopTest();

        // Should not throw exception
        System.assert(true, 'Should handle empty list gracefully');
    }

    @IsTest
    static void testHandleAfterInsertNullParentId() {
        ContactPointAddress address = getSampleContactPointAddress(null);
        address.IsPrimary = true;

        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>();

        Test.startTest();
        ContactPointAddressHandler.handleAfterInsert(new List<ContactPointAddress>{address}, newRecordsMap);
        Test.stopTest();

        // Should not throw exception - records with null ParentId are skipped
        System.assert(true, 'Should handle null ParentId gracefully');
    }

    @IsTest
    static void testHandleAfterUpdateNullParentId() {
        ContactPointAddress address = getSampleContactPointAddress(null);
        address.IsPrimary = true;

        Map<Id, SObject> updatedRecordsMap = new Map<Id, SObject>();
        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>();

        Test.startTest();
        ContactPointAddressHandler.handleAfterUpdate(new List<ContactPointAddress>{address}, updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        // Should not throw exception - records with null ParentId are skipped
        System.assert(true, 'Should handle null ParentId gracefully');
    }
}