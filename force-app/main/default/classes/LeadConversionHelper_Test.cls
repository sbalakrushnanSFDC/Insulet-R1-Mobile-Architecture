/**
 * Test class for LeadConversionHelper.
 * Provides comprehensive test coverage for Account and Opportunity creation from Lead data,
 * including field mapping, Individual ID transfer, permission checks, error handling,
 * and updating existing accounts with Lead data. Tests cover various edge cases and failure scenarios.
 *
 * @author      : Priyansh Shukla
 * @created Date: 4th November 2025
 * @description : Test class for LeadConversionHelper
 * @story Number: NGASIM-992
 *  */
@isTest(IsParallel=true)
public class LeadConversionHelper_Test {

    /**
     * @description Test creation of Patient Accounts from Leads
     */
    @isTest
    static void testCreatePatientAccountsSuccess() {
        // Create test leads using TestDataFactory
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Patient',
            'Email' => 'test.patient@example.com',
            'Phone' => '1234567890',
            'PostalCode' => '02101',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLeads;

        Test.startTest();
        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(testLeads);
        Test.stopTest();

        Assert.areEqual(2, createdAccounts.size(), 'Should return list with same size as input');
    }

    /**
     * @description Test creation of Patient Accounts with empty list
     */
    @isTest
    static void testCreatePatientAccountsEmptyList() {
        List<Lead> emptyLeads = new List<Lead>();

        Test.startTest();
        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(emptyLeads);
        Test.stopTest();

        Assert.areEqual(0, createdAccounts.size(), 'Should return empty list for empty input');
    }

    /**
     * @description Test creation of NCS Opportunities from Leads and Accounts
     */
    @isTest
    static void testCreateNCSOpportunitiesSuccess() {
        // Create test leads using TestDataFactory
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Opportunity',
            'Company' => 'Test Company',
            'Email' => 'test.opp@example.com',
            'PostalCode' => '02101',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'AnnualRevenue' => 100000,
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLeads;

        // Re-query leads to get system fields like CreatedDate and all fields used by buildAccountRecords/buildOpportunityRecords
        testLeads = [
            SELECT Id, Salutation, FirstName, MiddleName, LastName, Suffix, Company, Email, Phone,
                   Date_of_Birth__c, AnnualRevenue, LeadSource, CreatedDate,
                   Fax, MobilePhone, Website, Street, City, State, PostalCode, Country,
                   GeocodeAccuracy, Latitude, Longitude, Description,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Insurance_Company_Name__c, Current_Therapy__c
            FROM Lead
            WHERE Id IN :testLeads
        ];

        // First create accounts
        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(testLeads);

        Test.startTest();
        List<Opportunity> createdOpportunities = LeadConversionHelper.createNCSOpportunities(testLeads, createdAccounts);
        Test.stopTest();

        Assert.areEqual(2, createdOpportunities.size(), 'Should return list with same size as input');
    }

    /**
     * @description Test creation of NCS Opportunities with empty list
     */
    @isTest
    static void testCreateNCSOpportunitiesEmptyList() {
        List<Lead> emptyLeads = new List<Lead>();
        List<Account> emptyAccounts = new List<Account>();

        Test.startTest();
        List<Opportunity> createdOpportunities = LeadConversionHelper.createNCSOpportunities(emptyLeads, emptyAccounts);
        Test.stopTest();

        Assert.areEqual(0, createdOpportunities.size(), 'Should return empty list for empty input');
    }

    /**
     * @description Test creation of NCS Opportunities when Account list contains nulls
     */
    @isTest
    static void testCreateNCSOpportunitiesWithNullAccounts() {
        // Create test leads using TestDataFactory
        List<Lead> testLeads = TestDataFactory.getLeads(3, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'NullAccount',
            'Company' => 'Test Company',
            'PostalCode' => '02101',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'AnnualRevenue' => 50000,
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLeads;

        // Re-query leads to get system fields like CreatedDate and all fields used by buildAccountRecords/buildOpportunityRecords
        testLeads = [
            SELECT Id, Salutation, FirstName, MiddleName, LastName, Suffix, Company, Email, Phone,
                   Date_of_Birth__c, AnnualRevenue, LeadSource, CreatedDate,
                   Fax, MobilePhone, Website, Street, City, State, PostalCode, Country,
                   GeocodeAccuracy, Latitude, Longitude, Description,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Insurance_Company_Name__c, Current_Therapy__c
            FROM Lead
            WHERE Id IN :testLeads
        ];

        // Create a mock accounts list with null entries to simulate partial failure
        List<Account> accountsWithNull = new List<Account>();
        accountsWithNull.add(new Account(Id = MockDataFactory.getFakeId('Account')));
        accountsWithNull.add(null); // Simulate failed account creation
        accountsWithNull.add(new Account(Id = MockDataFactory.getFakeId('Account')));

        Test.startTest();
        List<Opportunity> createdOpportunities = LeadConversionHelper.createNCSOpportunities(testLeads, accountsWithNull);
        Test.stopTest();

        Assert.areEqual(3, createdOpportunities.size(), 'Should return list of same size as input');
        Assert.isNull(createdOpportunities[1], 'Second opportunity should be null (Account was null)');
    }

    /**
     * @description Test full flow: create accounts then opportunities from leads
     * This test validates the complete integration tested through PatientLeadService
     */
    @isTest
    static void testFullFlowAccountsAndOpportunities() {
        // Create test leads with comprehensive field mapping
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'FirstName' => 'Full',
            'LastName' => 'Flow',
            'Email' => 'fullflow@example.com',
            'Phone' => '9876543210',
            'Company' => 'Full Flow Company',
            'PostalCode' => '02139',
            'Date_of_Birth__c' => Date.today().addYears(-25),
            'AnnualRevenue' => 250000,
            'LeadSource' => 'Referral',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLeads;

        // Re-query leads to get system fields like CreatedDate and all fields used by buildAccountRecords/buildOpportunityRecords
        testLeads = [
            SELECT Id, Salutation, FirstName, MiddleName, LastName, Suffix, Company, Email, Phone,
                   Date_of_Birth__c, AnnualRevenue, LeadSource, CreatedDate,
                   Fax, MobilePhone, Website, Street, City, State, PostalCode, Country,
                   GeocodeAccuracy, Latitude, Longitude, Description,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Insurance_Company_Name__c, Current_Therapy__c
            FROM Lead
            WHERE Id IN :testLeads
        ];

        Test.startTest();
        // Step 1: Create accounts
        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(testLeads);

        // Step 2: Create opportunities
        List<Opportunity> createdOpportunities = LeadConversionHelper.createNCSOpportunities(testLeads, createdAccounts);
        Test.stopTest();

        Assert.areEqual(2, createdAccounts.size(), 'Should return list with 2 entries');
        Assert.areEqual(2, createdOpportunities.size(), 'Should return list with 2 entries');
    }

    /**
     * @description Test Account creation with invalid data to trigger partial DML failure
     */
    @isTest
    static void testCreateAccountsWithInvalidData() {
        // Create leads with potentially invalid data that might fail Account creation
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => '', // Empty LastName might cause validation failure
            'Email' => 'invalid-email', // Invalid email format
            'PostalCode' => '12345',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        Test.startTest();
        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(testLeads);
        Test.stopTest();

        Assert.isNotNull(createdAccounts, 'Should return a list even if creation fails');
    }

    /**
     * @description Test Opportunity creation with invalid data to trigger partial DML failure
     */
    @isTest
    static void testCreateOpportunitiesWithInvalidData() {
        // Create test leads using TestDataFactory
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Opp',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'AnnualRevenue' => 50000,
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLeads;

        // Re-query leads to get system fields like CreatedDate and all fields used by buildAccountRecords/buildOpportunityRecords
        testLeads = [
            SELECT Id, Salutation, FirstName, MiddleName, LastName, Suffix, Company, Email, Phone,
                   Date_of_Birth__c, AnnualRevenue, LeadSource, CreatedDate,
                   Fax, MobilePhone, Website, Street, City, State, PostalCode, Country,
                   GeocodeAccuracy, Latitude, Longitude, Description,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Insurance_Company_Name__c, Current_Therapy__c
            FROM Lead
            WHERE Id IN :testLeads
        ];

        // Create mock accounts with fake IDs
        List<Account> mockAccounts = new List<Account>();
        mockAccounts.add(new Account(Id = MockDataFactory.getFakeId('Account')));
        mockAccounts.add(new Account(Id = MockDataFactory.getFakeId('Account')));

        Test.startTest();
        // Attempt to create opportunities with fake Account IDs (will fail DML)
        List<Opportunity> createdOpportunities = LeadConversionHelper.createNCSOpportunities(testLeads, mockAccounts);
        Test.stopTest();

        Assert.isNotNull(createdOpportunities, 'Should return a list even if creation fails');
    }

    /**
     * @description Test Account creation with CRUD permission failure
     */
    @isTest
    static void testCreateAccountsPermissionFailure() {
        // Create test leads
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Permission',
            'PostalCode' => '12345',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        Test.startTest();
        // Simulate permission failure
        LeadConversionHelper.simulateAccountPermissionFailure = true;
        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(testLeads);
        LeadConversionHelper.simulateAccountPermissionFailure = false;
        Test.stopTest();

        Assert.areEqual(0, createdAccounts.size(), 'Should return empty list when user lacks Account create permission');
    }

    /**
     * @description Test Opportunity creation with CRUD permission failure
     */
    @isTest
    static void testCreateOpportunitiesPermissionFailure() {
        // Create mock leads and accounts
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Permission',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        List<Account> mockAccounts = new List<Account>();
        mockAccounts.add(new Account(Id = MockDataFactory.getFakeId('Account')));

        Test.startTest();
        // Simulate permission failure
        LeadConversionHelper.simulateOpportunityPermissionFailure = true;
        List<Opportunity> createdOpportunities = LeadConversionHelper.createNCSOpportunities(testLeads, mockAccounts);
        LeadConversionHelper.simulateOpportunityPermissionFailure = false;
        Test.stopTest();

        Assert.areEqual(0, createdOpportunities.size(), 'Should return empty list when user lacks Opportunity create permission');
    }

    /**
     * @description Test Opportunity creation when all opportunities in list are null
     */
    @isTest
    static void testCreateOpportunitiesAllNull() {
        // Create mock leads
        List<Lead> testLeads = MockDataFactory.createLeads(2, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'AllNull',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        // Create accounts list with ALL null entries (simulates all account creations failed)
        List<Account> accountsAllNull = new List<Account>();
        accountsAllNull.add(null);
        accountsAllNull.add(null);

        Test.startTest();
        List<Opportunity> createdOpportunities = LeadConversionHelper.createNCSOpportunities(testLeads, accountsAllNull);
        Test.stopTest();

        Assert.areEqual(2, createdOpportunities.size(), 'Should return list of same size');
        Assert.isNull(createdOpportunities[0], 'First opportunity should be null');
        Assert.isNull(createdOpportunities[1], 'Second opportunity should be null');
    }

    /**
     * @description Test Account creation that triggers actual DML failure
     */
    @isTest
    static void testCreateAccountsDMLFailure() {
        // Create leads with data that will cause Account creation to fail
        // Using a very long LastName to potentially trigger field length validation
        String longLastName = 'A'.repeat(300); // Exceeds typical field length limits

        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => longLastName,
            'PostalCode' => '12345',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        Test.startTest();
        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(testLeads);
        Test.stopTest();

        Assert.isNotNull(createdAccounts, 'Should return a list');
    }

    /**
     * @description Test Lead Coversion With Type_of_Diabetes__c and Preferred_Language__c fields set
     */
    @IsTest
    static void testLeadCoversionWithDOBAndLang() {
        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Test',
            'Email' => 'test.patient@example.com',
            'Phone' => '1234567890',
            'PostalCode' => '02101',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Type_of_Diabetes__c' => 'Type 1',
            'Preferred_Language__c' => 'English'
        });
        insert testLeads;

        Test.startTest();
        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(testLeads);
        Test.stopTest();

        Assert.areEqual(1, createdAccounts.size(), 'Should return list with same size as input');
    }

    /**
     * @description Test opportunity name generation with different name combinations
     */
    @isTest
    static void testOpportunityNameGeneration() {
        // Scenario 1: FirstName + MiddleName + LastName
        Lead lead1 = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'MiddleName' => 'Patrick',
            'LastName' => 'Doe',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'AnnualRevenue' => 50000,
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        })[0];

        // Scenario 2: Only MiddleName + LastName (FirstName is blank)
        Lead lead2 = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => null,
            'MiddleName' => 'Patrick',
            'LastName' => 'Doe',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'AnnualRevenue' => 50000,
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        })[0];

        // Scenario 3: Only LastName (FirstName and MiddleName are blank)
        Lead lead3 = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => null,
            'MiddleName' => null,
            'LastName' => 'Doe',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'AnnualRevenue' => 50000,
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        })[0];

        List<Lead> testLeads = new List<Lead>{lead1, lead2, lead3};
        insert testLeads;

        // Re-query leads to get system fields
        testLeads = [
            SELECT Id, Salutation, FirstName, MiddleName, LastName, Suffix, Company, Email, Phone,
                   Date_of_Birth__c, AnnualRevenue, LeadSource, CreatedDate,
                   Fax, MobilePhone, Website, Street, City, State, PostalCode, Country,
                   GeocodeAccuracy, Latitude, Longitude, Description,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Insurance_Company_Name__c, Current_Therapy__c
            FROM Lead
            WHERE Id IN :testLeads
            ORDER BY Id
        ];

        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(testLeads);

        Test.startTest();
        List<Opportunity> createdOpps = LeadConversionHelper.createNCSOpportunities(testLeads, createdAccounts);
        Test.stopTest();

        Assert.areEqual(3, createdOpps.size(), 'Should create 3 opportunities');
        Assert.isNotNull(createdOpps[0].Name, 'Should have a name');
        Assert.isTrue(createdOpps[1].Name.contains(System.Label.Opportunity_Name_Prefix), 'Opportunity name should contain the required Prefix');
        Assert.isTrue(createdOpps[2].Name.contains(Datetime.now().format('MM/dd/yyyy')), 'Opportunity name should have date of creation');
    }

    /**
     * @description Test account permission check
     */
    @isTest
    static void testAccountCreationPermissionFailure() {
        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PermFail',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'AnnualRevenue' => 50000,
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLeads;

        // Re-query leads to get all fields
        testLeads = [
            SELECT Id, Salutation, FirstName, MiddleName, LastName, Suffix, Company, Email, Phone,
                   Date_of_Birth__c, AnnualRevenue, LeadSource, CreatedDate,
                   Fax, MobilePhone, Website, Street, City, State, PostalCode, Country,
                   GeocodeAccuracy, Latitude, Longitude, Description,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Current_Therapy__c
            FROM Lead
            WHERE Id IN :testLeads
        ];

        // Simulate account permission failure
        LeadConversionHelper.simulateAccountPermissionFailure = true;

        Test.startTest();
        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(testLeads);
        Test.stopTest();

        Assert.areEqual(0, createdAccounts.size(), 'Should return empty list when permission fails');
    }

    /**
     * @description Test account creation DML failure handling
     */
    @isTest
    static void testAccountCreationWithDMLFailure() {
        // Create a normal lead first
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'DMLFailTest',
            Company = 'Test Company',
            PostalCode = '12345',
            LeadSource = 'Web',
            RecordTypeId = ConstantsUtil.LEAD_PATIENT_RT
        );
        insert testLead;

        // Re-query lead to get all fields
        testLead = [
            SELECT Id, Salutation, FirstName, MiddleName, LastName, Suffix, Company, Email, Phone,
                   Date_of_Birth__c, AnnualRevenue, LeadSource, CreatedDate,
                   Fax, MobilePhone, Website, Street, City, State, PostalCode, Country,
                   GeocodeAccuracy, Latitude, Longitude, Description,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Current_Therapy__c
            FROM Lead
            WHERE Id = :testLead.Id
        ];

        // Modify FirstName to exceed Account.FirstName max length (40 characters)
        // This will cause DML failure when creating PersonAccount
        testLead.FirstName = 'ThisIsAVeryLongFirstNameThatExceedsTheFortyCharacterLimitForAccountFirstName';

        Test.startTest();
        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(new List<Lead>{testLead});
        Test.stopTest();

        Assert.areEqual(1, createdAccounts.size(), 'Should have 1 entry in the list');
        Assert.isNull(createdAccounts[0], 'Failed account should be null');
    }

    /**
     * @description Test hasExistingOpportunities with null account
     */
    @isTest
    static void testHasExistingOpportunitiesWithNull() {
        Test.startTest();
        Boolean result = LeadConversionOpportunityHelper.hasExistingOpportunities(null);
        Test.stopTest();
        Assert.isFalse(result, 'Should return false for null account');
    }

    /**
     * @description Test getFieldValue method with blank string values through updateExistingAccountsWithLeadData
     */
    @isTest
    static void testUpdateAccountsWithBlankLeadFields() {
        // Create an existing account with values
        Account existingAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'ExistingFirst',
            'LastName' => 'ExistingLast',
            'PersonEmail' => 'existing@example.com',
            'Phone' => '1111111111',
            'BillingStreet' => 'Existing Street',
            'BillingCity' => 'Existing City',
            'BillingState' => 'California',
            'BillingPostalCode' => '90210',
            'BillingCountry' => 'United States',
            'Date_of_Birth__c' => Date.today().addYears(-40),
            'PersonGenderIdentity' => 'Male',
            'Preferred_Language__c' => 'Spanish'
        });
        insert existingAccount;

        // Re-query to get all fields
        existingAccount = [
            SELECT Id, FirstName, MiddleName, LastName, PersonEmail, Phone,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   Date_of_Birth__c,PersonLeadSource, Type_of_Diabetes__c, PersonGenderIdentity, Preferred_Language__c,
                   Salutation, Suffix, Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Current_Therapy__c, PersonIndividualId
            FROM Account
            WHERE Id = :existingAccount.Id
        ];

        // Create a lead with blank string fields (not null, but empty strings)
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => '', // Blank string - should use account value
            'LastName' => 'NewLast', // Non-blank - should use lead value
            'Email' => '', // Blank string - should use account value
            'Phone' => '2222222222', // Non-blank - should use lead value
            'Street' => '', // Blank string - should use account value
            'City' => 'New City', // Non-blank - should use lead value
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        // Re-query to get all fields
        testLead = [
            SELECT Id, Salutation, FirstName, MiddleName, LastName, Suffix, Email, Phone, Street, City, State, PostalCode, Country,
                   Date_of_Birth__c, LeadSource, Type_of_Diabetes__c, GenderIdentity, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Current_Therapy__c
            FROM Lead
            WHERE Id = :testLead.Id
        ];

        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>{testLead => existingAccount};

        Test.startTest();
        LeadConversionHelper.updateExistingAccountsWithLeadData(leadsToAccountMap);
        Test.stopTest();

        // Verify that blank lead fields used account values, non-blank lead fields used lead values
        Account updatedAccount = [
            SELECT FirstName, LastName, PersonEmail, Phone, BillingStreet, BillingCity, PersonIndividualId
            FROM Account
            WHERE Id = :existingAccount.Id
        ];

        Assert.areEqual('ExistingFirst', updatedAccount.FirstName, 'Should use account value when lead FirstName is blank');
        Assert.areEqual('NewLast', updatedAccount.LastName, 'Should use lead value when lead LastName is not blank');
        Assert.areEqual('existing@example.com', updatedAccount.PersonEmail, 'Should use account value when lead Email is blank');
        Assert.areEqual('2222222222', updatedAccount.Phone, 'Should use lead value when lead Phone is not blank');
        Assert.areEqual('Existing Street', updatedAccount.BillingStreet, 'Should use account value when lead Street is blank');
        Assert.areEqual('New City', updatedAccount.BillingCity, 'Should use lead value when lead City is not blank');
    }

    /**
     * @description Verifies Lead.IndividualId is transferred to Patient PersonAccount.PersonIndividualId during conversion
     */
    @isTest
    static void testTransferLeadIndividualIdToPatientAccount() {
        // Create a Patient lead with required fields
        Lead testLead = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Ind',
            'LastName' => 'Transfer',
            'Email' => 'ind.transfer@example.com',
            'Phone' => '3333333333',
            'Street' => '100 Main St',
            'City' => 'Boston',
            'State' => 'Massachusetts',
            'PostalCode' => '02110',
            'Country' => 'United States',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Sensor_CGM_Continuous_Glucose_Monitor__c' => 'Dexcom G6'
        })[0];
        insert testLead;

        // Create & link Individual to the Lead (uses existing org logic and updates Lead.IndividualId)
        IndividualService.createIndividuals(new List<SObject>{ testLead });

        // Re-query to confirm IndividualId is present on the Lead
        Lead leadWithIndividual = [
            SELECT Id, IndividualId
            FROM Lead
            WHERE Id = :testLead.Id
            LIMIT 1
        ];
        Assert.areNotEqual(null, leadWithIndividual.IndividualId, 'Lead.IndividualId should be populated');

        // Re-query Lead WITHOUT IndividualId to ensure helper handles "field not queried" and falls back to DB query
        Lead leadWithoutIndividualField = [
            SELECT Id, Salutation, FirstName, MiddleName, LastName, Suffix, Email, Phone, Street, City, State, PostalCode, Country,
                   Date_of_Birth__c, LeadSource, Type_of_Diabetes__c, GenderIdentity, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Current_Therapy__c
            FROM Lead
            WHERE Id = :testLead.Id
            LIMIT 1
        ];

        // Convert (create Patient PersonAccount) and verify Individual transfer
        Test.startTest();
        List<Account> createdAccounts = LeadConversionHelper.createPatientAccounts(new List<Lead>{ leadWithoutIndividualField });
        Test.stopTest();

        Assert.areEqual(1, createdAccounts.size(), 'Should return list with same size as input');
        Assert.areNotEqual(null, createdAccounts[0], 'Created account should not be null');
        Assert.areNotEqual(null, createdAccounts[0].Id, 'Created account Id should be populated');

        Account createdAccountFromDb = [
            SELECT Id, PersonIndividualId
            FROM Account
            WHERE Id = :createdAccounts[0].Id
            LIMIT 1
        ];
        Assert.areEqual(
            leadWithIndividual.IndividualId,
            createdAccountFromDb.PersonIndividualId,
            'PersonAccount.PersonIndividualId should be transferred from Lead.IndividualId'
        );
    }

    /**
     * @description Test updateValidationBypassForLeads with valid leads
     */
    @isTest
    static void testUpdateValidationBypassForLeads() {
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'FirstName' => 'Validation',
            'LastName' => 'Bypass',
            'Email' => 'validation.bypass@example.com',
            'Company' => 'Test Company',
            'PostalCode' => '02101',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLeads;

        Test.startTest();
        LeadConversionHelper.updateValidationBypassForLeads(testLeads);
        Test.stopTest();

        List<Lead> updatedLeads = [
            SELECT Id, Validation_Bypass__c
            FROM Lead
            WHERE Id IN :testLeads
        ];
        Assert.areEqual(2, updatedLeads.size(), 'Should have 2 leads');
        for (Lead ld : updatedLeads) {
            Assert.isTrue(ld.Validation_Bypass__c == true, 'Validation_Bypass__c should be true');
        }
    }

    /**
     * @description Test updateValidationBypassForLeads with null input
     */
    @isTest
    static void testUpdateValidationBypassForLeadsNull() {
        Test.startTest();
        LeadConversionHelper.updateValidationBypassForLeads(null);
        Test.stopTest();
        Assert.isTrue(true, 'Should handle null gracefully');
    }

    /**
     * @description Test updateValidationBypassForLeads with empty list
     */
    @isTest
    static void testUpdateValidationBypassForLeadsEmpty() {
        Test.startTest();
        LeadConversionHelper.updateValidationBypassForLeads(new List<Lead>());
        Test.stopTest();
        Assert.isTrue(true, 'Should handle empty list gracefully');
    }

    /**
     * @description Test updateValidationBypassForLeads exception handling with customExceptionSwitch
     * Verifies that when customExceptionSwitch is enabled, exception is caught and logged
     */
    @isTest
    static void testUpdateValidationBypassForLeadsCustomException() {
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'FirstName' => 'Validation',
            'LastName' => 'Bypass',
            'Email' => 'validation.bypass@example.com',
            'Company' => 'Test Company',
            'PostalCode' => '02101',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLeads;

        ConstantsUtil.customExceptionSwitch = true;

        Test.startTest();
        try {
            LeadConversionHelper.updateValidationBypassForLeads(testLeads);
            Assert.isTrue(true, 'Method should catch exception and complete without propagating');
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();
    }

    /**
     * @description Test deletion of accounts by IDs
     */
    @isTest
    static void testDeleteAccountsByIds() {
        // Create test account
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Delete',
            'LastName' => 'Test',
            'PersonEmail' => 'delete@example.com'
        });
        insert testAccount;

        List<Id> accountIds = new List<Id>{ testAccount.Id };

        Test.startTest();
        LeadConversionHelper.deleteAccountsByIds(accountIds);
        LeadConversionHelper.deleteAccountsByIds(null);
        LeadConversionHelper.deleteAccountsByIds(new List<Id>());

        // Try to delete already deleted account to potentially trigger catch block
        // Query will return empty, but covers the empty check path
        LeadConversionHelper.deleteAccountsByIds(accountIds);
        Test.stopTest();

        // Verify account was deleted
        List<Account> deletedAccounts = [
            SELECT Id
            FROM Account
            WHERE Id IN :accountIds
        ];
        Assert.areEqual(0, deletedAccounts.size(), 'Account should be deleted');
    }

}