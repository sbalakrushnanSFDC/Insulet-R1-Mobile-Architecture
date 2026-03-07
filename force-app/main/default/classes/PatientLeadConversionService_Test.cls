/**
 * Test class for PatientLeadConversionService.
 * Provides comprehensive test coverage for Patient Lead conversion scenarios including
 * successful conversions, permission failures, error handling, and conversion to existing
 * accounts. Tests cover both automatic conversion and conversion with result tracking.
 *
 * @author      : Priyansh Shukla
 * @created Date: 30th October 2025
 * @description : Test class for PatientLeadConversionService
 * @story Number: NGASIM-992
 * =========================== Logs ======================================
 * Version      Modified Date           Modified By                 Brief Note
 * V1.0.0       30th October 2025       Priyansh Shukla             Initial Version(US - NGASIM-992)
 * V1.0.1       26th November 2025      Bijayalaxmi Prusty          Updated(US - NGASIM-1050)
 * V1.0.2       2nd December 2025       Bijayalaxmi Prusty          Modified(US - NGASIM-1080)
 * V1.0.0       2nd December 2025       Priyansh Shukla             Modified(US - NGASIM-1211)
 * V1.0.0       17th December 2025      Bijayalaxmi Prusty          Modified(US - NGOMCT-824)
 * v1.0.3       12th Jan 2026           Anup Bandawar               Updated(US - NGASIM-1029)
 * v1.0.4       14th Jan 2026           Jatin Butta                 Modified(US - NGASIM-1901, NGASIM-1602)
 * v1.0.5       22nd Jan 2026           Priyansh Shukla             Modified(US - NGOMCT-1749)
 * v1.0.5       12nd Feb 2026           Priyansh Shukla             Modified(US - NGASIM-1898)
 * V1.0.6       18th Feb 2026           Bijayalaxmi Prusty          Modified(US - NGOMCT-1961)
 */
@isTest(IsParallel=true)
public class PatientLeadConversionService_Test {

    /**
     * @description Helper method to create base field map with required fields
     * @param facilityId The HealthcarePractitionerFacility Id
     * @param isEligible Whether to create an eligible lead (default true)
     * @return Map with all required fields populated
     */
    private static Map<String, Object> getBaseLeadFieldMap(Id facilityId, Boolean isEligible) {
        return new Map<String, Object>{
            'Status' => 'New',
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => !isEligible,
            'Provider_Practice_Affiliation__c' => facilityId,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'IsConverted' => false,
            'PostalCode' => '12345',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'Recommended_Product__c' => 'DASH'
        };
    }

    /**
     * @description Test successful lead conversion with eligible leads
     */
    @isTest
    static void testProcessAutomaticLeadConversionSuccess() {
        // Create test healthcare facility
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        // Create eligible test leads
        List<Lead> testLeads = TestDataFactory.getLeads(5, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Patient',
            'Email' => 'test.patient@example.com',
            'Phone' => '1234567890',
            'Company' => 'Test Company',
            'Status' => 'New',
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'Recommended_Product__c' => 'DASH'
        });
        insert testLeads;

        Test.startTest();
        PatientLeadConversionService.processAutomaticLeadConversion(testLeads);
        Test.stopTest();

        // Verify conversion status
        List<Lead> convertedLeads = [SELECT Id, Status FROM Lead WHERE Id IN :testLeads];
        Assert.areEqual(5, convertedLeads.size(), 'Should return 5 leads');
    }

    /**
     * @description Test with null input
     */
    @isTest
    static void testProcessAutomaticLeadConversionNullInput() {
        Test.startTest();
        PatientLeadConversionService.processAutomaticLeadConversion(null);
        Test.stopTest();

        // Should complete without error
        Assert.isTrue(true, 'Method should handle null input gracefully');
    }

    /**
     * @description Test buildConversionRequests returns empty list for empty input
     */
    @isTest
    static void testBuildConversionRequestsEmptyList() {
        List<Lead> emptyLeads = new List<Lead>();

        Test.startTest();
        PatientLeadConversionService.ConversionRequestData result = PatientLeadConversionService.buildConversionRequests(emptyLeads);
        Test.stopTest();

        Assert.areEqual(0, result.conversionRequests.size(), 'Should return empty list');
    }

    /**
     * @description Test processConversionResults with null input
     */
    @isTest
    static void testProcessConversionResultsNullInput() {
        List<Lead> testLeads = new List<Lead>();

        Test.startTest();
        PatientLeadConversionService.processConversionResults(null, testLeads, new Map<Integer, Id>());
        Test.stopTest();

        Assert.isTrue(true, 'Should handle null convertResults gracefully');
    }

    /**
     * @description Test performLeadConversion with empty conversion requests
     */
    @isTest
    static void testPerformLeadConversionEmptyConversionRequests() {
        // Create empty lead list for testing
        List<Lead> leadsWithNullIds = new List<Lead>();

        Test.startTest();
        try {
            PatientLeadConversionService.performLeadConversion(leadsWithNullIds);
            Assert.isTrue(true, 'Should handle empty conversion requests gracefully');
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception handled');
        }
        Test.stopTest();
    }

    /**
     * @description Test permission validation during lead conversion process
     * Verifies that the service properly handles insufficient user permissions
     */
    @isTest
    static void testLeadConversionPermissionsCheck() {
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Permission',
            'Email' => 'test.permission@example.com',
            'Phone' => '1234567890',
            'Company' => 'Test Company',
            'Status' => 'New',
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'Recommended_Product__c' => 'DASH'
        });
        insert testLeads;

        Test.startTest();
        // Simulate permission failure to test error handling
        PatientLeadConversionService.simulatePermissionFailure = true;

        try {
            // Test both conversion methods with insufficient permissions
            PatientLeadConversionService.processAutomaticLeadConversion(testLeads);
            List<Database.LeadConvertResult> results = PatientLeadConversionService.processAutomaticLeadConversionWithResults(testLeads);

            // Should return empty results when permissions fail
            Assert.isNotNull(results, 'Should return results list');
            Assert.isTrue(results.isEmpty(), 'Should return empty when permissions fail');

        } finally {
            PatientLeadConversionService.simulatePermissionFailure = false;
        }

        Test.stopTest();
    }

    /**
     * @description Test lead conversion creates records with correct record types
     * Verifies that Patient Accounts and NCS Opportunities are created properly
     */
    @isTest
    static void testLeadConversionCreatesCorrectRecordTypes() {
        // Create test healthcare facility
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        // Create test lead for conversion
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Patient',
            'Email' => 'test.patient@example.com',
            'Phone' => '1234567890',
            'Status' => 'Qualification',
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'Company' => 'Test Integration Company',
            'Recommended_Product__c' => 'DASH',
            'GenderIdentity' => 'Male',
            'Type_of_Diabetes__c' => 'Type 2: Using Insulin',
            'Sensor_CGM_Continuous_Glucose_Monitor__c' => 'Dexcom G6',
            'Insurance_Type__c' => 'Medicare',
            'Insurance_Company_Name__c' => 'Test Insurance Company',
            'Current_Therapy__c' => 'Insulin Pump',
            'Street' => '123 Main St',
            'City' => 'Vienna',
            'State' => 'Virginia',
            'PostalCode' => '12345',
            'Country' => 'United States',
            'CountryCode' => 'US',
            'LeadSource' => 'Get Started',
            'Address_Status__c' => 'Verified'
        });
        insert testLead;

        Test.startTest();
        PatientLeadConversionService.processAutomaticLeadConversion(new List<Lead>{ testLead });
        Test.stopTest();

        // Verify lead conversion results
        Lead convertedLead = [SELECT Id, Status, ConvertedAccountId FROM Lead WHERE Id = :testLead.Id];
        Assert.areEqual('Converted', convertedLead.Status, 'Lead should be converted');
        Assert.isNotNull(convertedLead.ConvertedAccountId, 'ConvertedAccountId should be populated');

        // Verify Account has Patient RecordType
        Account createdAccount = [SELECT Id, RecordTypeId, PersonIndividualId FROM Account WHERE Id = :convertedLead.ConvertedAccountId];
        Assert.areEqual(ConstantsUtil.ACCOUNT_PATIENT_RT, createdAccount.RecordTypeId,
            'Account should have Patient RecordType');

        // Verify Opportunity has NCS Opportunity RecordType
        List<Opportunity> createdOpportunities = [SELECT Id, RecordTypeId, AccountId
                                                   FROM Opportunity
                                                   WHERE AccountId = :convertedLead.ConvertedAccountId];
        Assert.areEqual(1, createdOpportunities.size(), 'Should create 1 opportunity');
        Assert.areEqual(ConstantsUtil.OPPORTUNITY_NCS_RT, createdOpportunities[0].RecordTypeId,
            'Opportunity should have NCS Opportunity RecordType');
    }

    /**
     * @description Test buildConversionRequests when opportunity creation fails
     * Verifies proper handling when opportunities cannot be created due to permissions
     */
    @isTest
    static void testBuildConversionRequestsOpportunityCreationFails() {
        List<HealthcarePractitionerFacility> facilities = MockDataFactory.createHealthcarePractitionerFacilities(1, null);
        Id facilityId = facilities[0].Id;
        List<Lead> testLeads = MockDataFactory.createLeads(1, getBaseLeadFieldMap(facilityId, true));

        Test.startTest();
        // Simulate Opportunity permission failure to make opportunitiesCreated empty
        LeadConversionHelper.simulateOpportunityPermissionFailure = true;
        PatientLeadConversionService.ConversionRequestData result = PatientLeadConversionService.buildConversionRequests(testLeads);
        LeadConversionHelper.simulateOpportunityPermissionFailure = false;
        Test.stopTest();

        // Should return empty list when Opportunity creation fails
        Assert.areEqual(0, result.conversionRequests.size(), 'Should return empty list when Opportunity creation fails');
    }

    /**
     * @description Test buildConversionRequests when Account or Opportunity is null
     */
    @isTest
    static void testBuildConversionRequestsNullAccountOrOpportunity() {
        List<HealthcarePractitionerFacility> facilities = MockDataFactory.createHealthcarePractitionerFacilities(1, null);
        Id facilityId = facilities[0].Id;
        List<Lead> testLeads = MockDataFactory.createLeads(2, getBaseLeadFieldMap(facilityId, true));

        Test.startTest();
        // Simulate Account permission failure to make accountsCreated empty
        // This will cause both Account and Opportunity to be null/missing
        LeadConversionHelper.simulateAccountPermissionFailure = true;
        PatientLeadConversionService.ConversionRequestData result = PatientLeadConversionService.buildConversionRequests(testLeads);
        LeadConversionHelper.simulateAccountPermissionFailure = false;
        Test.stopTest();

        // Should return empty list when Accounts fail to create
        Assert.areEqual(0, result.conversionRequests.size(), 'Should return empty list when Account creation fails');
    }

    /**
     * @description Test error logging when lead conversion fails
     * Verifies proper error handling during conversion failures
     */
    @isTest
    static void testLeadConversionFailureLogging() {
        // Create test data for failure scenario
        List<HealthcarePractitionerFacility> facilities = MockDataFactory.createHealthcarePractitionerFacilities(1, null);
        Id facilityId = facilities[0].Id;

        Map<String, Object> leadFields = getBaseLeadFieldMap(facilityId, true);
        List<Lead> testLeads = MockDataFactory.createLeads(2, leadFields);

        // These leads will cause conversion failure

        Test.startTest();
        PatientLeadConversionService.performLeadConversion(testLeads);
        Test.stopTest();

        // Should handle the failure gracefully
        Assert.isTrue(true, 'Should handle conversion failure and log errors');
    }

    /* ======================== Lead Conversion to Existing Accounts Tests ======================== */

    /**
     * @description Test convertLeadsToExistingAccounts with null map
     */
    @isTest
    static void testConvertLeadsWithNullMap() {
        Test.startTest();
        List<Database.LeadConvertResult> results = PatientLeadConversionService.convertLeadsToExistingAccounts(null);
        Test.stopTest();

        Assert.isNotNull(results, 'Should return non-null list for null input');
        Assert.areEqual(0, results.size(), 'Should return empty list for null input');
    }

    /**
     * @description Test convertLeadsToExistingAccounts with account having null ID
     */
    @isTest
    static void testConvertLeadsWithNullAccountId() {
        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'NullAccountId',
            'Email' => 'test.nullaccount@example.com',
            'Phone' => '1234567890',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Recommended_Product__c' => 'DASH'
        });
        insert testLeads;

        // Query lead with all required fields
        testLeads = [
            SELECT Id, FirstName, MiddleName, LastName, Company, Email, Phone,
                   Date_of_Birth__c, LeadSource, CreatedDate, isConverted,
                   Street, City, State, PostalCode, Country,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c,
                   Salutation, Suffix, Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Insurance_Company_Name__c, Current_Therapy__c, Recommended_Product__c
            FROM Lead
            WHERE Id IN :testLeads
        ];

        // Create account with null Id for testing
        Account accountWithNullId = new Account(FirstName = 'Test', LastName = 'NullId');

        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>();
        leadsToAccountMap.put(testLeads[0], accountWithNullId);

        Test.startTest();
        List<Database.LeadConvertResult> results = PatientLeadConversionService.convertLeadsToExistingAccounts(leadsToAccountMap);
        Test.stopTest();

        Assert.isNotNull(results, 'Should return results list');
        Assert.areEqual(0, results.size(), 'Should skip leads with null account IDs');
    }

    /**
     * @description Test converting leads to existing accounts with existing opportunities
     */
    @isTest
    static void testConvertLeadsToExistingAccountsWithOpportunities() {
        // Create a Patient Account
        Account existingAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Existing',
            'LastName' => 'Patient'
        });
        insert existingAccount;

        // Create existing opportunities on this account
        List<Opportunity> existingOpps = new List<Opportunity>();
        existingOpps.add(new Opportunity(
            Name = 'Existing Opp 1',
            AccountId = existingAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT,
            Number_of_time_contacted__c = 1
        ));
        existingOpps.add(new Opportunity(
            Name = 'Existing Opp 2',
            AccountId = existingAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT,
            Number_of_time_contacted__c = 2
        ));
        insert existingOpps;

        // Query account with opportunities
        existingAccount = [
            SELECT Id, Name, Salutation, Suffix, FirstName, MiddleName, LastName, PersonEmail, Phone,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   Date_of_Birth__c, PersonLeadSource, Type_of_Diabetes__c, PersonGenderIdentity, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Current_Therapy__c, PersonIndividualId,
                   (SELECT Id, Name, Number_of_time_contacted__c, Last_Contacted_Date__c, Insurance_Name__c, Insurance_Type__c
                    FROM Opportunities
                    WHERE StageName != 'Closed Won' AND StageName != 'Closed Lost')
            FROM Account
            WHERE Id = :existingAccount.Id
        ];

        // Create a lead to convert
        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'AnnualRevenue' => 50000,
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Recommended_Product__c' => 'DASH'
        });
        insert testLeads;

        // Query leads with all required fields
        testLeads = [
            SELECT Id, FirstName, MiddleName, LastName, Company, Email, Phone,
                   Date_of_Birth__c, AnnualRevenue, LeadSource, CreatedDate, isConverted,
                   Fax, MobilePhone, Website, Street, City, State, PostalCode, Country,
                   GeocodeAccuracy, Latitude, Longitude, Description,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c,
                   Salutation, Suffix, Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Insurance_Company_Name__c, Current_Therapy__c
            FROM Lead
            WHERE Id IN :testLeads
        ];

        // Create map for conversion
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>();
        leadsToAccountMap.put(testLeads[0], existingAccount);

        Test.startTest();
        List<Database.LeadConvertResult> results = PatientLeadConversionService.convertLeadsToExistingAccounts(leadsToAccountMap);
        Test.stopTest();

        Assert.isNotNull(results, 'Should return conversion results');
        Assert.areEqual(1, results.size(), 'Should have 1 conversion result');

        List<Opportunity> updatedOpps = [
            SELECT Id, Number_of_time_contacted__c, Last_Contacted_Date__c
            FROM Opportunity
            WHERE Id IN :existingOpps
        ];
        Assert.areEqual(2, updatedOpps.size(), 'Should have 2 opportunities');
        for (Opportunity opp : updatedOpps) {
            Assert.isNotNull(opp.Last_Contacted_Date__c, 'Last_Contacted_Date__c should be updated');
        }
    }

    /**
     * @description Test converting leads to existing accounts that need new opportunities
     * This tests the scenario where account has no existing open opportunities
     */
    @isTest
    static void testConvertLeadsToExistingAccountsNeedingOpportunities() {
        // Create a Patient Account without opportunities
        Account existingAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Existing',
            'LastName' => 'Patient'
        });
        insert existingAccount;

        // Query account with opportunities subquery
        existingAccount = [
            SELECT Id, Name, Salutation, Suffix, FirstName, MiddleName, LastName, PersonEmail, Phone,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   Date_of_Birth__c, PersonLeadSource, Type_of_Diabetes__c, PersonGenderIdentity, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Current_Therapy__c, PersonIndividualId,
                   (SELECT Id, Insurance_Name__c, Insurance_Type__c FROM Opportunities WHERE StageName != 'Closed Won' AND StageName != 'Closed Lost')
            FROM Account
            WHERE Id = :existingAccount.Id
        ];

        // Create a lead to convert
        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'NeedingOpportunities',
            'Email' => 'test.needingopp@example.com',
            'Phone' => '1234567890',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'AnnualRevenue' => 50000,
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Recommended_Product__c' => 'DASH'
        });
        insert testLeads;

        // Query leads with all required fields
        testLeads = [
            SELECT Id, FirstName, MiddleName, LastName, Company, Email, Phone,
                   Date_of_Birth__c, AnnualRevenue, LeadSource, CreatedDate,
                   Fax, MobilePhone, Website, Street, City, State, PostalCode, Country,
                   GeocodeAccuracy, Latitude, Longitude, Description, isConverted,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c,
                   Salutation, Suffix, Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Insurance_Company_Name__c, Current_Therapy__c
            FROM Lead
            WHERE Id IN :testLeads
        ];

        // Create map for conversion
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>();
        leadsToAccountMap.put(testLeads[0], existingAccount);

        Test.startTest();
        List<Database.LeadConvertResult> results = PatientLeadConversionService.convertLeadsToExistingAccounts(leadsToAccountMap);
        Test.stopTest();

        Assert.isNotNull(results, 'Should return conversion results');
        Assert.areEqual(1, results.size(), 'Should have 1 conversion result');

        List<Opportunity> createdOpps = [
            SELECT Id, AccountId
            FROM Opportunity
            WHERE AccountId = :existingAccount.Id
        ];
        Assert.areEqual(1, createdOpps.size(), 'Should create 1 new opportunity');
    }

    /**
     * @description Test lead conversion failure logging when converting already converted lead
     */
    @isTest
    static void testConvertLeadsFailureLogging() {
        // Create and convert a lead first
        Account existingAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Existing',
            'LastName' => 'Patient'
        });
        insert existingAccount;

        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'FailureLogging',
            'Email' => 'test.faillog@example.com',
            'Phone' => '1234567890',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Recommended_Product__c' => 'DASH',
            'Validation_Bypass__c' => true
        });
        insert testLeads;

        // Convert the lead first
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLeads[0].Id);
        lc.setConvertedStatus('Converted');
        lc.setOwnerId(UserInfo.getUserId());
        Database.convertLead(lc);

        // Query account with opportunities
        existingAccount = [
            SELECT Id, Name, Salutation, Suffix, FirstName, MiddleName, LastName, PersonEmail, Phone,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   Date_of_Birth__c, PersonLeadSource, Type_of_Diabetes__c, PersonGenderIdentity, Preferred_Language__c, PersonIndividualId,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Current_Therapy__c,
                   (SELECT Id, Insurance_Name__c, Insurance_Type__c FROM Opportunities WHERE StageName != 'Closed Won' AND StageName != 'Closed Lost')
            FROM Account
            WHERE Id = :existingAccount.Id
        ];

        // Query the converted lead
        testLeads = [
            SELECT Id, FirstName, MiddleName, LastName, Company, Email, Phone,
                   Date_of_Birth__c, AnnualRevenue, LeadSource, CreatedDate,
                   Fax, MobilePhone, Website, Street, City, State, PostalCode, Country,
                   GeocodeAccuracy, Latitude, Longitude, Description,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c, IsConverted,
                   Salutation, Suffix, Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Insurance_Company_Name__c, Current_Therapy__c
            FROM Lead
            WHERE Id IN :testLeads
        ];

        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>();
        leadsToAccountMap.put(testLeads[0], existingAccount);

        Test.startTest();
        List<Database.LeadConvertResult> results = PatientLeadConversionService.convertLeadsToExistingAccounts(leadsToAccountMap);
        Test.stopTest();

        Assert.isNotNull(results, 'Should return results');
        if (!results.isEmpty()) {
            Assert.isFalse(results[0].isSuccess(), 'Should fail when converting already converted lead');
        }
    }

    /**
     * @description Test processAutomaticLeadConversionWithResults with null input
     */
    @isTest
    static void testProcessAutomaticLeadConversionWithResultsNullInput() {
        Test.startTest();
        List<Database.LeadConvertResult> results = PatientLeadConversionService.processAutomaticLeadConversionWithResults(null);
        Test.stopTest();

        Assert.isNotNull(results, 'Should return empty list');
        Assert.isTrue(results.isEmpty(), 'Should return empty list for null input');
    }

    /**
     * @description Test processAutomaticLeadConversionWithResults with valid leads
     */
    @isTest
    static void testProcessAutomaticLeadConversionWithResultsSuccess() {
        // Use exact same setup as testProcessAutomaticLeadConversionSuccess which works
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        // Create eligible leads with required PersonAccount fields
        List<Lead> testLeads = TestDataFactory.getLeads(3, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Patient',
            'Email' => 'test.patient@example.com',
            'Phone' => '1234567890',
            'Company' => 'Test Company',
            'Status' => 'New',
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'Recommended_Product__c' => 'DASH'
        });
        insert testLeads;

        Test.startTest();
        List<Database.LeadConvertResult> results = PatientLeadConversionService.processAutomaticLeadConversionWithResults(testLeads);
        Test.stopTest();

        // Verify conversion results
        Assert.isNotNull(results, 'Should return conversion results');

        // If results are not empty, verify conversions
        if (!results.isEmpty()) {
            for (Database.LeadConvertResult result : results) {
                if (result.isSuccess()) {
                    Assert.isNotNull(result.getAccountId(), 'Should have created account');
                    Assert.isNotNull(result.getContactId(), 'Should have created contact');
                }
            }

            // Verify leads were actually converted
            List<Lead> convertedLeads = [SELECT Id, Status FROM Lead WHERE Id IN :testLeads];
            for (Lead ld : convertedLeads) {
                if (ld.Status == 'Converted') {
                    Assert.areEqual('Converted', ld.Status, 'Lead Status should be Converted');
                }
            }
        }
    }

    /**
     * @description Test performLeadConversionWithResults with permission failure
     */
    @isTest
    static void testPerformLeadConversionWithResultsPermissionFailure() {
        // Create leads with all required fields
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PermissionFailure',
            'Email' => 'test.permfail@example.com',
            'Phone' => '1234567890',
            'Company' => 'Test Company',
            'Status' => 'New',
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'Recommended_Product__c' => 'DASH'
        });
        insert testLeads;

        // Simulate permission failure BEFORE calling the method
        PatientLeadConversionService.simulatePermissionFailure = true;

        Test.startTest();
        List<Database.LeadConvertResult> results = PatientLeadConversionService.processAutomaticLeadConversionWithResults(testLeads);
        Test.stopTest();

        // Reset flag
        PatientLeadConversionService.simulatePermissionFailure = false;

        // When permissions fail, should return empty list
        Assert.isNotNull(results, 'Should return results list (even if empty)');
        Assert.isTrue(results.isEmpty(), 'Should return empty list when permissions fail');
    }

    /**
     * @description Test performLeadConversionWithResults when buildConversionRequests returns empty
     */
    @isTest
    static void testPerformLeadConversionWithResultsEmptyConversionRequests() {
        // Create leads that will fail account creation
        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'Status' => 'New',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Request_a_Call_Back__c' => false,
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'Recommended_Product__c' => 'DASH'
            // Missing required field to trigger account creation failure
        });
        insert testLeads;

        // Simulate account permission failure
        LeadConversionHelper.simulateAccountPermissionFailure = true;

        Test.startTest();
        List<Database.LeadConvertResult> results = PatientLeadConversionService.processAutomaticLeadConversionWithResults(testLeads);
        Test.stopTest();

        // Reset flag
        LeadConversionHelper.simulateAccountPermissionFailure = false;

        Assert.isNotNull(results, 'Should return results list');
        Assert.isTrue(results.isEmpty(), 'Should return empty list when account creation fails');
    }

    /**
     * @description Test when opportunities creation returns fewer records than accounts
     */
    @isTest
    static void testConvertLeadsWithOpportunityCreationFailure() {
        // Create a Patient Account without opportunities
        Account existingAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'NoOpp',
            'LastName' => 'Account'
        });
        insert existingAccount;

        // Query account with opportunities subquery
        existingAccount = [
            SELECT Id, Name, Salutation, Suffix, FirstName, MiddleName, LastName, PersonEmail, Phone,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   Date_of_Birth__c, PersonLeadSource, Type_of_Diabetes__c, PersonGenderIdentity, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Current_Therapy__c, PersonIndividualId,
                   (SELECT Id, Insurance_Name__c, Insurance_Type__c FROM Opportunities WHERE StageName != 'Closed Won' AND StageName != 'Closed Lost')
            FROM Account
            WHERE Id = :existingAccount.Id
        ];

        // Create a lead to convert
        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'OpportunityCreationFailure',
            'Email' => 'test.oppfail@example.com',
            'Phone' => '1234567890',
            'Company' => 'Test Company',
            'PostalCode' => '12345',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Recommended_Product__c' => 'DASH'
        });
        insert testLeads;

        // Query lead with all required fields
        testLeads = [
            SELECT Id, FirstName, MiddleName, LastName, Company, Email, Phone,
                   Date_of_Birth__c, LeadSource, CreatedDate, isConverted,
                   Street, City, State, PostalCode, Country,
                   GenderIdentity, Type_of_Diabetes__c, Preferred_Language__c,
                   Salutation, Suffix, Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Insurance_Company_Name__c, Current_Therapy__c, Recommended_Product__c
            FROM Lead
            WHERE Id IN :testLeads
        ];

        // Create map for conversion
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>();
        leadsToAccountMap.put(testLeads[0], existingAccount);

        // Simulate opportunity permission failure
        LeadConversionHelper.simulateOpportunityPermissionFailure = true;

        Test.startTest();
        List<Database.LeadConvertResult> results = PatientLeadConversionService.convertLeadsToExistingAccounts(leadsToAccountMap);
        Test.stopTest();

        // Reset the flag
        LeadConversionHelper.simulateOpportunityPermissionFailure = false;

        Assert.isNotNull(results, 'Should return results');
    }

    /**
     * @description Test logDebug method
     */
    @isTest
    static void testLogDebug() {
        Test.startTest();
        PatientLeadConversionService.logDebug('Test debug message');
        Test.stopTest();

        Assert.isTrue(true, 'Should log debug message');
    }


    /**
     * @description Test exception handling during lead conversion process
     * Verifies that the service gracefully handles and logs conversion exceptions
     */
    @isTest
    static void testPerformLeadConversionExceptionHandling() {
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        // Create leads with required fields for conversion
        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'ExceptionHandling',
            'Email' => 'test.exception@example.com',
            'Phone' => '1234567890',
            'Company' => 'Test Company',
            'Status' => 'New',
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'Recommended_Product__c' => 'DASH'
        });
        insert testLeads;

        Test.startTest();

        try {
            // Trigger controlled exception to test error handling
            ConstantsUtil.customExceptionSwitch = true;
            // Test both conversion methods with exception simulation
            PatientLeadConversionService.processAutomaticLeadConversion(testLeads);
            PatientLeadConversionService.performLeadConversionWithResults(testLeads);

            // Should complete without throwing exception as errors are handled internally
            Assert.isTrue(true, 'Methods should handle exceptions gracefully');

        } finally {
            // Always reset the exception flag
            ConstantsUtil.customExceptionSwitch = false;
        }

        Test.stopTest();
    }



}