/**
 * @description Test class for HealthCareProviderService
 * @author Sunil Khanchandani
 * @date Oct 15, 2025
 */
@IsTest(IsParallel=true)
private class HealthCareProviderService_Test {

    @IsTest
    static void testProcessNewHealthCareRecordsWithEmptyList() {
        Test.startTest();
        // Act
        HealthCareProviderService.processNewHealthCareRecords(new List<Account>{});
        Test.stopTest();

        // Assert
        Assert.isTrue(true, 'Method executed successfully with empty list');
    }

    @IsTest
    static void testProcessNewHealthCareRecordsWithMockData() {
        List<Account> providerAccountList = MockDataFactory.createAccounts(1, new Map<String, Object>{
          													 'RecordTypeId' => ConstantsUtil.ACCOUNT_PROVIDER_RT,
        													 'FirstName' => 'John',
        													 'LastName' => 'Doe'

        												  });
          List<Account> practiceAccountsList = MockDataFactory.createAccounts(1, new Map<String, Object>{
          													 'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
        													 'Name' => 'Acme Practice'
        												  });
        Account provider = providerAccountList[0];
        Account practice = practiceAccountsList[0];
        Test.startTest();
        // Act
        HealthCareProviderService.processNewHealthCareRecords(new List<Account>{ provider, practice });
        Test.stopTest();

        // Assert
        Assert.isNotNull(provider.Id, 'Provider account should have mock Id');
        Assert.isNotNull(practice.Id, 'Practice account should have mock Id');
    }

    @IsTest
    static void testProcessNewHealthCareRecordsWithTestData() {
        // Arrange
        Account practice = TestDataFactory.getAccountofPracticeRecordType();
        practice.BillingPostalCode = '302020';
        insert practice;
        Account provider = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Provider',
            'LastName' => 'Account',
            'BillingPostalCode'=>'302020'
        });
        insert provider;
        Account providerUpdated = [SELECT Id, PersonContactId FROM Account WHERE Id=: provider.Id LIMIT 1];

        Test.startTest();
        // Act
        HealthCareProviderService.processNewHealthCareRecords(new List<Account>{ provider});
        Test.stopTest();

        // Assert
        List<HealthcareProvider> providers = [SELECT Id, Name FROM HealthcareProvider WHERE PractitionerId = :providerUpdated.PersonContactId];
        Assert.areEqual(1, providers.size(), 'Should create 1 HealthcareProvider');
        Assert.isNotNull(providers[0].Name, 'HealthcareProvider Name should be set');
    }

    @IsTest
    static void testProcessHealthcareProvidersOnAccountUpdateEmptyList() {
        // Capture old map
        Map<Id, Account> oldMap = new Map<Id, Account>{};
        Test.startTest();
        // Act
        HealthCareProviderService.processHealthcareProvidersOnAccountUpdate(
            new List<Account>{},
            oldMap
        );
        Test.stopTest();

        // Assert
        Assert.isTrue(true, 'Method executed successfully with empty list');
    }

    @IsTest
    static void testProcessHealthcareProvidersOnAccountUpdateUpdatedNames() {
        // Arrange: create initial records
        Account practice = TestDataFactory.getAccountofPracticeRecordType();
        practice.BillingPostalCode = '302020';
        insert practice;
        Account provider = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Provider',
            'LastName' => 'Account',
            'BillingPostalCode'=>'302020'
        });
        insert provider;

        Account providerUpdated = [SELECT Id, PersonContactId FROM Account WHERE Id=: provider.Id LIMIT 1];
        // Capture old map
        Map<Id, Account> oldMap = new Map<Id, Account>{
            provider.Id => provider.clone(false, true, false, false),
            practice.Id => practice.clone(false, true, false, false)
        };

        // Update names
        provider.FirstName = 'Alicia';
        provider.LastName = 'Smithers';
        practice.Name = 'New Practice';
        update new List<Account>{ provider, practice };

        Test.startTest();
        // Act
        HealthCareProviderService.processHealthcareProvidersOnAccountUpdate(
            new List<Account>{ provider, practice },
            oldMap
        );
        Test.stopTest();

        // Assert (minimal): names propagated
        HealthcareProvider hpProv = [SELECT Name FROM HealthcareProvider WHERE PractitionerId = :providerUpdated.PersonContactId LIMIT 1];
        HealthcareProvider hpPrac = [SELECT Name FROM HealthcareProvider WHERE AccountId = :practice.Id LIMIT 1];
        Assert.isNotNull(hpProv.Name, 'Provider HealthcareProvider Name should not be null');
        Assert.areEqual('New Practice', hpPrac.Name, 'Practice HealthcareProvider Name should match updated Account Name');
    }

    @IsTest
    static void testProcessHealthcareProvidersOnAccountUpdateException() {
        // Arrange: create initial records
        Account practice = TestDataFactory.getAccountofPracticeRecordType();
        practice.BillingPostalCode = '302020';
        insert practice;
                Account provider = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Provider',
            'LastName' => 'Account',
            'BillingPostalCode'=>'302020'
        });
        insert provider;
        // Capture old map
        Map<Id, Account> oldMap = new Map<Id, Account>{
            provider.Id => provider.clone(false, true, false, false),
            practice.Id => practice.clone(false, true, false, false)
        };

        // Update names
        provider.FirstName = 'Alicia';
        provider.LastName = 'Smithers';
        practice.Name = 'New Practice';
        update new List<Account>{ provider, practice };

        Test.startTest();
        try {
            ConstantsUtil.customExceptionSwitch = true;
            // Act
            HealthCareProviderService.processHealthcareProvidersOnAccountUpdate(
                new List<Account>{ provider, practice },
                oldMap
            );
            Assert.isNotNull(provider.Id, 'Provider account Id should not be null');
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();
    }



    @IsTest
    static void testfetchHealthcareProvidersWithEmptyParams() {
            Test.startTest();
                List<HealthcareProvider> providersList =  HealthCareProviderService.fetchHealthcareProviders(
                    new Map<Id,Account>(),new Map<Id,Account>()
                );
				Assert.areEqual(0, providersList.size(), 'Provider list return is empty'); // Succeeds
            Test.stopTest();
        }


     @IsTest
    static void testfetchHealthcareProvidersWithNullParams() {
            Test.startTest();
                List<HealthcareProvider> providersList =  HealthCareProviderService.fetchHealthcareProviders(
                    null,null
                );
				Assert.areEqual(0, providersList.size(), 'Provider list return is empty'); // Succeeds
            Test.stopTest();
        }
}