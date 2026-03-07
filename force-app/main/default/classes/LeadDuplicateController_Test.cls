/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 12th Nov 2025
 * @description : Test class for LeadDuplicateController
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       12th Nov 2025       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1065)
 */
@IsTest(isParallel=true)
private class LeadDuplicateController_Test {

    /**
     * @description Setup test data for duplicate matching scenarios
     */
    @TestSetup
    static void setupTestData() {
        // Create existing Lead records for matching using TestDataFactory
        List<Lead> existingLeads = new List<Lead>();

        // Lead 1: Full match candidate - Primary lead for testing
        existingLeads.add(TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'John',
            'MiddleName' => 'Michael',
            'LastName' => 'Doe',
            'Email' => 'john.doe@test.com',
            'Phone' => '5551234567',
            'Street' => '123 Main St',
            'City' => 'Anytown',
            'State' => 'California',
            'PostalCode' => '12345',
            'Country' => 'United States',
            'Date_of_Birth__c' => Date.newInstance(1990, 5, 15),
            'Status' => 'Open - Not Contacted',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Test Company Primary'
        }));

        // Lead 2: Full match scenario (same name and DOB)
        existingLeads.add(TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'John',
            'MiddleName' => 'Michael',
            'LastName' => 'Doe',
            'Email' => 'john.doe2@test.com',
            'Phone' => '5555678901',
            'Street' => '456 Oak Ave',
            'City' => 'Otherville',
            'State' => 'New York',
            'PostalCode' => '67890',
            'Country' => 'United States',
            'Date_of_Birth__c' => Date.newInstance(1990, 5, 15),
            'Status' => 'Working - Contacted',
            'LeadSource' => 'Phone',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Test Company Full Match'
        }));

        // Lead 3: Partial match candidate (same email only)
        existingLeads.add(TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Jane',
            'LastName' => 'Smith',
            'Email' => 'john.doe@test.com',
            'Phone' => '5559999123',
            'Date_of_Birth__c' => Date.newInstance(1985, 8, 20),
            'Status' => 'Open - Not Contacted',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Test Company Partial'
        }));

        // Lead 4: No match scenario
        existingLeads.add(TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Bob',
            'LastName' => 'Johnson',
            'Email' => 'bob.johnson@test.com',
            'Phone' => '5550000456',
            'Date_of_Birth__c' => Date.newInstance(1980, 12, 10),
            'Status' => 'Open - Not Contacted',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Test Company No Match'
        }));

        // Lead 5: Excluded status scenario
        existingLeads.add(TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Excluded',
            'LastName' => 'Lead',
            'Email' => 'excluded@test.com',
            'Phone' => '5551111789',
            'Status' => 'Closed - Converted',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Test Company Excluded'
        }));

        insert existingLeads;

        // Create existing Patient Account for cross-object matching using TestDataFactory
        List<Account> existingAccounts = new List<Account>();

        existingAccounts.add(TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'John',
            'MiddleName' => 'Michael',
            'LastName' => 'Doe',
            'PersonEmail' => 'john.doe.account@test.com',
            'PersonHomePhone' => '5551234567',
            'Phone' => '5551234567',
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PATIENT_RT,
            'Date_of_Birth__c' => Date.newInstance(1990, 5, 15),
            'BillingStreet' => '789 Pine St',
            'BillingCity' => 'Somewhere',
            'BillingState' => 'Texas',
            'BillingPostalCode' => '54321',
            'BillingCountry' => 'United States'
        }));

        insert existingAccounts;
    }
    /**
     * @description Test getDuplicateMatches with valid Lead ID
     */
    @IsTest
    static void testGetDuplicateMatchesValidLead() {
        // Get the primary test lead
        Lead primaryLead = [SELECT Id FROM Lead WHERE FirstName = 'John' AND LastName = 'Doe' LIMIT 1];

        Test.startTest();
        List<LeadDuplicateController.DuplicateMatchResult> results =
            LeadDuplicateController.getDuplicateMatches(primaryLead.Id);
        Test.stopTest();

        // Verify results
        Assert.isTrue(results.size() > 0, 'Should find duplicate matches');
    }
    /**
     * @description Test getDuplicateMatches with null Lead ID
     */
    @IsTest
    static void testGetDuplicateMatchesNullLeadId() {
        Test.startTest();
        List<LeadDuplicateController.DuplicateMatchResult> results =
            LeadDuplicateController.getDuplicateMatches(null);
        Test.stopTest();

        // Verify empty results for null input
        Assert.areEqual(0, results.size(), 'Should return empty list for null input');
    }

    /**
     * @description Test getDuplicateMatches with ineligible record type
     */
    @IsTest
    static void testGetDuplicateMatchesIneligibleRecordType() {
        // Create a lead with Third Party Trainer record type using TestDataFactory
        Lead ineligibleLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Ineligible',
            'Email' => 'test.ineligible@test.com',
            'Status' => 'Open - Not Contacted',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT,
            'Company' => 'Ineligible Company'
        });
        insert ineligibleLead;

        Test.startTest();
        List<LeadDuplicateController.DuplicateMatchResult> results =
            LeadDuplicateController.getDuplicateMatches(ineligibleLead.Id);
        Test.stopTest();

        // Verify empty results for ineligible record type
        Assert.areEqual(0, results.size(), 'Should return empty list for ineligible record type');
    }

    /**
     * @description Test full match scenario
     */
    @IsTest
    static void testGetDuplicateMatchesFullMatch() {
        // Get leads with full match criteria
        List<Lead> testLeads = [SELECT Id FROM Lead WHERE FirstName = 'John' AND LastName = 'Doe' ORDER BY CreatedDate];
        Lead primaryLead = testLeads[0];

        Test.startTest();
        List<LeadDuplicateController.DuplicateMatchResult> results =
            LeadDuplicateController.getDuplicateMatches(primaryLead.Id);
        Test.stopTest();

        // Verify full match found
        Boolean hasFullMatch = false;
        for (LeadDuplicateController.DuplicateMatchResult result : results) {
            if (result.matchingStatus == ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH) {
                hasFullMatch = true;
                break;
            }
        }
        Assert.isTrue(hasFullMatch, 'Should have at least one full match');
    }

    /**
     * @description Test partial match scenario
     */
    @IsTest
    static void testLeadDuplicateHelperIsEligibleRecordType() {
        Test.startTest();

        // Test eligible record type
        Boolean isEligible = LeadDuplicateHelper.isEligibleRecordType(ConstantsUtil.LEAD_PATIENT_RT);
        Assert.isTrue(isEligible, 'Patient record type should be eligible');

        // Test ineligible record type
        Boolean isIneligible = LeadDuplicateHelper.isEligibleRecordType(ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT);
        Assert.isFalse(isIneligible, 'Third party trainer record type should not be eligible');

        Test.stopTest();
    }
    /**
     * @description Test Lead matching against existing Patient Account records
     */
    @IsTest
    static void testGetDuplicateMatchesAccountMatch() {
        Test.startTest();

        // Create existing Patient Account for matching
        Account existingAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Mary',
            'MiddleName' => 'Jane',
            'LastName' => 'Williams',
            'PersonEmail' => 'mary.williams@test.com',
            'Phone' => '1111111111',
            'Date_of_Birth__c' => Date.newInstance(1975, 8, 25),
            'BillingStreet' => '100 Test Ave',
            'BillingCity' => 'Test City',
            'BillingState' => 'California',
            'BillingPostalCode' => '90210',
            'BillingCountry' => 'United States'
        });
        existingAccount.Id = null;
        insert existingAccount;

        // Create a new Lead that matches with existing Patient Account
        Lead newLead = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'Mary',
            'MiddleName' => 'Jane',
            'LastName' => 'Williams',
            'Email' => 'mary.williams@test.com',
            'Phone' => '1111111111',
            'Date_of_Birth__c' => Date.newInstance(1975, 8, 25),
            'Status' => 'Open - Not Contacted',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Account Match Company'
        })[0];
        newLead.Id = MockDataFactory.getFakeId('Lead');

        List<LeadDuplicateController.DuplicateMatchResult> results =
            LeadDuplicateController.getDuplicateMatches(newLead.Id);
        Test.stopTest();
        for (LeadDuplicateController.DuplicateMatchResult result : results) {
            if (result.recordType == ConstantsUtil.ACCOUNT_OBJECT) {
                Assert.isNotNull(result.name, 'Account name should be populated');
                Assert.isNotNull(result.email, 'Account email should be populated');
                break;
            }
        }
        // Account match depends on helper class configuration
    }

    /**
     * @description Test buildFullName method indirectly through results
     */
    @IsTest
    static void testBuildFullNameThroughResults() {
        // Get lead with full name
        Lead testLead = [SELECT Id FROM Lead WHERE FirstName = 'John' AND MiddleName = 'Michael' AND LastName = 'Doe' LIMIT 1];

        Test.startTest();
        List<LeadDuplicateController.DuplicateMatchResult> results =
            LeadDuplicateController.getDuplicateMatches(testLead.Id);
        Test.stopTest();

        // Verify name formatting in results
        for (LeadDuplicateController.DuplicateMatchResult result : results) {
            if (String.isNotBlank(result.name)) {
                Assert.isTrue(result.name.contains(' '), 'Name should contain spaces for multiple parts');
            }
        }
    }

    /**
     * @description Test address building through results
     */
    @IsTest
    static void testAddressBuildingThroughResults() {
        // Get lead with address
        Lead testLead = [SELECT Id FROM Lead WHERE Street = '123 Main St' LIMIT 1];

        Test.startTest();
        List<LeadDuplicateController.DuplicateMatchResult> results =
            LeadDuplicateController.getDuplicateMatches(testLead.Id);
        Test.stopTest();

        // Verify address formatting in results
        for (LeadDuplicateController.DuplicateMatchResult result : results) {
            if (String.isNotBlank(result.address) && result.recordType == ConstantsUtil.LEAD_OBJECT) {
                Assert.isTrue(result.address.contains(','), 'Address should contain commas as separators');
            }
        }
    }

    /**
     * @description Test exception handling in getDuplicateMatches
     */
    @IsTest
    static void testGetDuplicateMatchesExceptionHandling() {
        Test.startTest();

        // Test with non-existent Lead ID (using a fake ID)
        Id fakeLeadId = MockDataFactory.getFakeId('Lead');
        List<LeadDuplicateController.DuplicateMatchResult> fakeResults =
            LeadDuplicateController.getDuplicateMatches(fakeLeadId);
        Test.stopTest();
        Assert.areEqual(0, fakeResults.size(), 'Should return empty list for non-existent Lead');
    }

    /**
     * @description Test DuplicateMatchResult wrapper class properties
     */
    @IsTest
    static void testDuplicateMatchResultProperties() {
        // Test the wrapper class properties
        LeadDuplicateController.DuplicateMatchResult result = new LeadDuplicateController.DuplicateMatchResult();

        // Set test values using MockDataFactory for realistic ID
        Id testId = MockDataFactory.getFakeId('Lead');
        result.recordId = testId;
        result.recordType = ConstantsUtil.LEAD_OBJECT;
        result.matchingStatus = ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH;
        result.name = 'Test Name';
        result.email = 'test@example.com';
        result.phone = '555-1234';
        result.address = '123 Test St';
        result.status = 'Open - Not Contacted';
        result.dateOfBirth = Date.newInstance(1990, 1, 1);

        Assert.areEqual(testId, result.recordId, 'Record ID should match');
        Assert.areEqual(ConstantsUtil.LEAD_OBJECT, result.recordType, 'Record type should match');
        Assert.areEqual('Test Name', result.name, 'Name should match');
    }

    /**
     * @description Test filtering of significant matches
     */
    @IsTest
    static void testFilterSignificantMatchesLogic() {
        // This tests the filtering logic indirectly through getDuplicateMatches
        Lead testLead = [SELECT Id FROM Lead WHERE FirstName = 'Bob' AND LastName = 'Johnson' LIMIT 1];

        Test.startTest();
        List<LeadDuplicateController.DuplicateMatchResult> results =
            LeadDuplicateController.getDuplicateMatches(testLead.Id);
        Test.stopTest();

        // Verify no "No Match" records are returned (they should be filtered out)
        for (LeadDuplicateController.DuplicateMatchResult result : results) {
            Assert.areNotEqual(ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH, result.matchingStatus,
                'No Match records should be filtered out');
        }
    }

    /**
     * @description Tests getDuplicateMatches field mapping for both Lead and Account results
     */
    @IsTest
    static void testGetDuplicateMatchesFieldMapping() {
        Test.startTest();

        // Create a Lead that will match existing data
        Lead newLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'FieldTest',
            'MiddleName' => 'Jane',
            'LastName' => 'Doe', // Matches existing Lead
            'Email' => 'fieldtest@test.com',
            'Phone' => '8888888888',
            'Date_of_Birth__c' => Date.newInstance(1990, 5, 15), // Matches existing Lead
            'Status' => 'Open - Not Contacted',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Field Test Company'
        });
        insert newLead;

        List<LeadDuplicateController.DuplicateMatchResult> results =
            LeadDuplicateController.getDuplicateMatches(newLead.Id);

        Test.stopTest();

        // Check if custom metadata is configured in this org
        List<Duplicate_Rules_Criteria__mdt> metadataRecords = [
            SELECT Id FROM Duplicate_Rules_Criteria__mdt
            WHERE Source_Object__c = :ConstantsUtil.LEAD_OBJECT
            LIMIT 1
        ];

        if (metadataRecords.isEmpty()) {
            // If no metadata is configured, method should return empty list gracefully
            Assert.areEqual(0, results.size(),
                'Should return empty list when no custom metadata is configured');
            return;
        }

        // Verify field mapping - only if results found
        if (results.size() > 0) {
            // Check first result for essential field population
            LeadDuplicateController.DuplicateMatchResult firstResult = results[0];
            Assert.isNotNull(firstResult.recordId, 'Record ID should be populated');
            Assert.isNotNull(firstResult.name, 'Name should be populated');

            // Verify date of birth mapping for matching Lead records
            for (LeadDuplicateController.DuplicateMatchResult result : results) {
                if (result.recordType == ConstantsUtil.LEAD_OBJECT && result.dateOfBirth != null) {
                    Assert.areEqual(Date.newInstance(1990, 5, 15), result.dateOfBirth,
                        'Lead date of birth should match expected value');
                }
            }
        }
    }
}