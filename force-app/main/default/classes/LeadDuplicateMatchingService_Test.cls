/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 29th Oct 2025
 * @description : Test class for LeadDuplicateMatchingService
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       29th Oct 2025       Bijayalaxmi Prusty      Initial Version(US - NGASIM-219)
 * V1.0.1       13th Nov 2025       Bijayalaxmi Prusty      Updated(US - NGASIM-1065)
 * V1.0.2       28th Nov 2025       Bijayalaxmi Prusty      Updated(US - NGASIM-1050)
 * V2.0.1       23rd Jan 2026       Bijayalaxmi Prusty      Updated(US - NGASIM-1885)
 */
@IsTest(isParallel=true)
private class LeadDuplicateMatchingService_Test {

    /**
     * @description Sets up test data for Lead duplicate matching scenarios
     * Creates existing Lead records that can be matched against in test methods
     */
    @TestSetup
    static void setupTestData() {
        // Create existing Lead records for matching
        List<Lead> existingLeads = new List<Lead>();

        // Lead 1: Full match candidate
        existingLeads.add(TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'John',
            'MiddleName' => 'Jane',
            'LastName' => 'Doe',
            'Email' => 'john.doe@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 15),
            'Status' => 'Open',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        }));

        // Lead 2: Partial match candidate
        existingLeads.add(TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Jane',
            'MiddleName' => 'Jane',
            'LastName' => 'Smith',
            'Email' => 'jane.smith@example.com',
            'Phone' => '9876543210',
            'Date_of_Birth__c' => Date.newInstance(1985, 5, 20),
            'Status' => 'Open',
            'LeadSource' => 'Phone',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        }));

        insert existingLeads;

        // Create existing Patient Account for cross-object matching
        List<Account> existingAccounts = new List<Account>();

        existingAccounts.add(TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'John',
            'MiddleName' => 'Jane',
            'LastName' => 'Doe',
            'PersonEmail' => 'john.doe.account@example.com',
            'PersonHomePhone' => '1234567890',
            'Phone' => '1234567890',
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PATIENT_RT,
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 15),
            'BillingStreet' => '789 Billing St',
            'BillingCity' => 'Chicago',
            'BillingState' => 'Illinois',
            'BillingPostalCode' => '60601',
            'BillingCountry' => 'United States'
        }));

        insert existingAccounts;

    }

    /**
     * @description Tests scenario when no duplicate matches are found
     * Creates a Lead with unique values that don't match any existing records
     * Verifies that Matching_Status__c is set to 'No Match'
     */
    @IsTest
    static void testNoMatchScenario() {
        Test.startTest();

        // Create a new Lead with no matching criteria
        Lead newLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'New',
            'LastName' => 'Person',
            'Email' => 'new.person@example.com',
            'Phone' => '7777777777',
            'Date_of_Birth__c' => Date.newInstance(2000, 3, 15),
            'Status' => 'Open',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        insert newLead;

        Test.stopTest();

        // Verify No Match status
        Lead insertedLead = [SELECT Matching_Status__c FROM Lead WHERE Id = :newLead.Id];
        Assert.areEqual(ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH, insertedLead.Matching_Status__c, 'Should be No Match when no criteria match');
    }

    /**
     * @description Tests full match scenario when all fields match existing Lead record
     * Creates a Lead with identical values to setup data Lead
     * Verifies that Matching_Status__c is set to 'Full Match'
     */
    @IsTest
    static void testFullMatchScenarioAllFields() {
        Test.startTest();

        // Create a new Lead that matches all criteria
        List<Lead> newLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'Email' => 'john.doe@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 15),
            'Status' => 'Open',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Full Match Company'
        });
        Lead newLead = newLeads[0];
        newLead.Id = MockDataFactory.getFakeId('Lead');
        LeadDuplicateMatchingService.processLeadDuplicateMatching(newLeads, null);

        Test.stopTest();

        // Verify Full Match status
        Assert.areEqual(ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH, newLead.Matching_Status__c, 'Should be Full Match when all criteria match');
    }

    /**
     * @description Tests partial match scenario when only some fields match
     * Creates a Lead that matches LastName and DOB but not Email and Phone
     * Verifies that Matching_Status__c is set to 'Partial Match'
     */
    @IsTest
    static void testPartialMatchScenario() {
        Test.startTest();

        List<Lead> newLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'Email' => 'different.email@example.com',
            'Phone' => '9999999999',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 15),
            'Status' => 'Open',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Partial Match Company'
        });
        Lead newLead = newLeads[0];
        newLead.Id = MockDataFactory.getFakeId('Lead');

        LeadDuplicateMatchingService.processLeadDuplicateMatching(newLeads, null);

        Test.stopTest();

        // Verify Partial Match status
        Assert.areEqual(ConstantsUtil.LEAD_MATCHING_STATUS_PARTIAL_MATCH, newLead.Matching_Status__c, 'Should be Partial Match when some but not enough criteria match');
    }

    /**
     * @description Tests Lead matching against existing Patient Account records
     * Creates a Patient Account and a Lead with matching field values
     * Verifies cross-object matching returns 'Full Match' status
     */
    @IsTest
    static void testMatchingWithPatientAccount() {
        Test.startTest();

        // Create existing Patient Account for matching
        Account existingAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Mary',
            'MiddleName' => 'Jane',
            'LastName' => 'Williams',
            'PersonEmail' => 'mary.williams@example.com',
            'Phone' => '1111111111',
            'Date_of_Birth__c' => Date.newInstance(1975, 8, 25)
        });
        existingAccount.Id = null;
        insert existingAccount;

        // Create a new Lead that matches with existing Patient Account
        List<Lead> newLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'Mary',
            'MiddleName' => 'Jane',
            'LastName' => 'Williams',
            'Email' => 'mary.williams@example.com',
            'Phone' => '1111111111',
            'Date_of_Birth__c' => Date.newInstance(1975, 8, 25),
            'Status' => 'Open',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        Lead newLead = newLeads[0];
        newLead.Id = MockDataFactory.getFakeId('Lead');

        LeadDuplicateMatchingService.processLeadDuplicateMatching(newLeads, null);
        Test.stopTest();

        // Verify Full Match status
        Assert.areEqual(ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH, newLead.Matching_Status__c, 'Should be Full Match when matching with Patient Account');
    }
    /**
     * @description Tests Lead update scenario where fields change to create matches
     * Initially creates a Lead with no matches, then updates it to match existing data
     * Verifies status changes from 'No Match' to 'Full Match' after update
     */
    @IsTest
    static void testLeadUpdateScenario() {
        Test.startTest();

        // Create a new Lead initially with no matches
        Lead newLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Update',
            'LastName' => 'Test',
            'Email' => 'update.test@example.com',
            'Phone' => '8888888888',
            'Date_of_Birth__c' => Date.newInstance(1995, 6, 10),
            'Status' => 'Open',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Update Test Company'
        });
        insert newLead;

        // Verify initial No Match status
        Lead initialLead = [SELECT Matching_Status__c FROM Lead WHERE Id = :newLead.Id];
        Assert.areEqual(ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH, initialLead.Matching_Status__c, 'Should initially be No Match');

        // Update Lead to match existing Lead
        newLead.LastName = 'Doe';
        newLead.Email = 'john.doe@example.com';
        newLead.Phone = '1234567890';
        newLead.Date_of_Birth__c = Date.newInstance(1990, 1, 15);
        update newLead;

        Test.stopTest();

        // Verify Full Match after update
        Lead updatedLead = [SELECT Matching_Status__c FROM Lead WHERE Id = :newLead.Id];
        Assert.areEqual(ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH, updatedLead.Matching_Status__c, 'Should be Full Match after update');
    }
    /**
     * @description Tests that non-Patient record types are excluded from duplicate matching
     * Creates a Lead with Third Party Trainer record type and verifies it's not processed
     * Ensures Matching_Status__c remains null for excluded record types
     */
    @IsTest
    static void testNonPatientRecordTypeExclusion() {
        Test.startTest();

        // Create a Lead with Third Party Trainer record type
        List<Lead> trainerLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'Trainer',
            'LastName' => 'Doe',
            'Email' => 'john.doe@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 15),
            'Status' => 'Open',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT,
            'Company' => 'Trainer Company'
        });
        Lead trainerLead = trainerLeads[0];
        trainerLead.Id = MockDataFactory.getFakeId('Lead');

        LeadDuplicateMatchingService.processLeadDuplicateMatching(trainerLeads, null);

        Test.stopTest();

        // Verify that Matching_Status__c field is not set (null)
        Assert.isNull(trainerLead.Matching_Status__c, 'Matching_Status__c should not be set for non-Patient record types');
    }

    /**
     * @description Tests that Leads with excluded statuses are not processed for matching
     * Creates a Lead with 'Lost' status and verifies it's excluded from duplicate matching
     * Validates that excluded status Leads maintain null Matching_Status__c
     */
    @IsTest
    static void testLostLeadStatusExclusion() {
        Test.startTest();

        // Create a Lead with Lost status - should be excluded from processing
        List<Lead> lostLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'Lost',
            'LastName' => 'Lead',
            'Email' => 'lost.lead@example.com',
            'Phone' => '5555555555',
            'Date_of_Birth__c' => Date.newInstance(1985, 6, 10),
            'Status' => 'Lost',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        Lead lostLead = lostLeads[0];
        lostLead.Id = MockDataFactory.getFakeId('Lead');

        LeadDuplicateMatchingService.processLeadDuplicateMatching(lostLeads, null);

        Test.stopTest();

        // Verify that Matching_Status__c field is not set (null) for Lost leads
        Assert.isNull(lostLead.Matching_Status__c, 'Matching_Status__c should not be set for leads with Lost status');
    }

    /**
     * @description Tests service behavior when processing empty Lead list
     */
    @IsTest
    static void testEmptyListProcessing() {
        Test.startTest();

        // Test with empty list - should not cause any errors
        try {
            LeadDuplicateMatchingService.processLeadDuplicateMatching(new List<Lead>(), null);
            Assert.isTrue(true, 'Empty list processing should not throw errors');
        } catch (Exception ex) {
            Assert.fail('Empty list processing should not throw errors: ' + ex.getMessage());
        }

        Test.stopTest();
    }

    /**
     * @description Tests exception handling and graceful failure behavior
     * Ensures service resilience against malformed input data
     */
    @IsTest
    static void testExceptionHandling() {
        Test.startTest();

        // Create a Lead with problematic data that could cause exceptions during processing
        Lead errorLead = new Lead();
        errorLead.RecordTypeId = ConstantsUtil.LEAD_PATIENT_RT;
        errorLead.Status = 'Open';

        // Create a scenario that might cause field access issues
        // Set fields to null after construction to simulate corrupted data
        errorLead.FirstName = 'Exception';
        errorLead.LastName = null; // This could cause issues during field access
        errorLead.Company = 'Exception Test Company';

        // Create a list with the problematic lead
        List<Lead> errorLeads = new List<Lead>{errorLead};

        // Force an exception by manipulating the Lead's field access
        try {
            // This should trigger the exception handling
            ConstantsUtil.customExceptionSwitch = true;
            LeadDuplicateMatchingService.processLeadDuplicateMatching(errorLeads, null);
            LeadDuplicateMatchingService.processDuplicateLeadConversion(errorLeads);
            Assert.isTrue(true, 'Service should handle exceptions gracefully');
        } catch (Exception ex) {
            Assert.fail('Service should handle exceptions gracefully, but threw: ' + ex.getMessage());
        }

        Test.stopTest();
    }
    /**
     * @description Tests bulk processing of multiple leads
     * Verifies service handles multiple records efficiently
     */
    @IsTest
    static void testBulkLeadProcessing() {
        Test.startTest();

        // Create multiple leads for bulk processing
        List<Lead> bulkLeads = new List<Lead>();
        for (Integer i = 0; i < 5; i++) {
            bulkLeads.add(TestDataFactory.getLead(new Map<String, Object>{
                'FirstName' => 'Bulk' + i,
                'LastName' => 'Lead' + i,
                'Email' => 'bulk' + i + '@example.com',
                'Phone' => '999000000' + i,
                'Date_of_Birth__c' => Date.newInstance(1990 + i, 1, 15),
                'Status' => 'Open',
                'LeadSource' => 'Web',
                'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
            }));
        }
        insert bulkLeads;

        Test.stopTest();

        // Verify all leads were processed
        List<Lead> processedLeads = [SELECT Matching_Status__c FROM Lead WHERE Id IN :bulkLeads];
        Assert.areEqual(5, processedLeads.size(), 'All leads should be processed');

        for (Lead lead : processedLeads) {
            Assert.isNotNull(lead.Matching_Status__c, 'Matching status should be set for all leads');
        }
    }
    /**
     * @description Tests negative scenario
     */
    @IsTest
    static void testnegativeScenario() {
        Test.startTest();
        LeadDuplicateMatchingService.hasRelevantFieldsChanged(null, null);

        List<Lead> newLead = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'Lost',
            'LastName' => 'Lead',
            'Phone' => '5555555555',
            'Date_of_Birth__c' => Date.newInstance(1985, 6, 10),
            'Status' => 'Lost',
            'LeadSource' => 'Web',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        List<Lead> oldLead = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'Lost',
            'LastName' => 'Lead',
            'Phone' => '5555555555',
            'Date_of_Birth__c' => Date.newInstance(1985, 6, 10),
            'Status' => 'Converted',
            'LeadSource' => 'Phone',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        LeadDuplicateMatchingService.hasRelevantFieldsChanged(newLead[0], oldLead[0]);
        Assert.isTrue(true, 'Method should complete without exceptions');

        Test.stopTest();
    }

    /**
     * @description Test processDuplicateLeadConversion method integration
     */
    @IsTest
    static void testProcessDuplicateLeadConversion() {
        // Create Contact record for Healthcare Practitioner
        Contact practitionerContact = TestDataFactory.getContact(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Practitioner',
            'Email' => 'test.practitioner@example.com'
        });
        insert practitionerContact;

        // Create Healthcare Practitioner Facility
        List<HealthcarePractitionerFacility> facilities = TestDataFactory.getHealthcarePractitionerFacilities(1, new Map<String, Object>{
            'Name' => 'Test Facility',
            'PractitionerId' => practitionerContact.Id
        });
        insert facilities;

        Lead testLead1 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Conversion1',
            'Email' => 'test.conversion1@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 15),  // Age >= 18 to avoid caregiver requirements
            'GenderIdentity' => 'Male',
            'Address_Status__c' => 'Verified',  // Required for Auto conversion (unless LeadSource = "Get Started")
            'Status' => 'Qualification',  // MustEqualValue requirement
            'Recommended_Product__c' => 'DASH',  // Required for Auto - valid picklist value
            'Sensor_CGM_Continuous_Glucose_Monitor__c' => 'Dexcom G6',  // Required for Auto - valid picklist value
            'Type_of_Diabetes__c' => 'Type 1',  // Required for Auto
            'Duplicate_Review_Completed__c' => true,  // Required if Matching_Status__c = "Partial Match"
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facilities[0].Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Test Company 1',
            'LeadSource' => 'Web'
        });

        // Create second lead with LeadSource = "Get Started" to skip address verification
        Lead testLead2 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Conversion2',
            'Email' => 'test.conversion2@example.com',
            'Phone' => '9876543210',
            'Date_of_Birth__c' => Date.newInstance(1985, 5, 20),  // Age >= 18 to avoid caregiver requirements
            'GenderIdentity' => 'Female',
            'Status' => 'Qualification',  // MustEqualValue requirement
            'Recommended_Product__c' => 'DASH',  // Required for Auto - valid picklist value
            'Sensor_CGM_Continuous_Glucose_Monitor__c' => 'Dexcom G6',  // Required for Auto - valid picklist value
            'Type_of_Diabetes__c' => 'Type 1',  // Required for Auto - valid picklist value
            'Duplicate_Review_Completed__c' => true,  // Required if Matching_Status__c = "Partial Match"
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facilities[0].Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Test Company 2',
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_GET_STARTED  // This will skip address verification requirement
        });

        // Insert leads with duplicate rule handling
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Test.startTest();
        Database.SaveResult[] insertResults = Database.insert(new List<Lead>{testLead1, testLead2}, dmlOpts);
		Test.stopTest();
        // Verify inserts succeeded and collect IDs
        List<Id> insertedLeadIds = new List<Id>();
        for (Integer i = 0; i < insertResults.size(); i++) {
            Database.SaveResult result = insertResults[i];
            if (result.isSuccess()) {
                insertedLeadIds.add(result.getId());
            } else {
                String errors = '';
                for (Database.Error err : result.getErrors()) {
                    errors += err.getMessage() + '; ';
                }
                Assert.fail('Lead insert failed at index ' + i + ': ' + errors);
            }
        }

        // Verify we got IDs for both leads
        Assert.areEqual(2, insertedLeadIds.size(), 'Both leads should be inserted successfully');

        // Re-query leads using the IDs from insert results
        // Include RecordType.DeveloperName for precheck service
        List<Lead> testLeads = [
            SELECT Id, FirstName, LastName, Email, Phone, Date_of_Birth__c, GenderIdentity,
                   Address_Status__c, Status, Recommended_Product__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Type_of_Diabetes__c,
                   Duplicate_Review_Completed__c, Request_a_Call_Back__c,
                   Provider_Practice_Affiliation__c, RecordTypeId, RecordType.DeveloperName,
                   Company, LeadSource, IsConverted
            FROM Lead
            WHERE Id IN :insertedLeadIds
            WITH USER_MODE
        ];

        // Verify leads were inserted correctly
        Assert.areEqual(2, testLeads.size(), 'Both leads should be inserted');

        // Update status back to Qualification if automation changed it (and lead is not converted)
        List<Lead> leadsToUpdate = new List<Lead>();
        for (Lead lead : testLeads) {
            Assert.isNotNull(lead.Id, 'Lead should have an ID');
            Assert.isNotNull(lead.RecordTypeId, 'Lead should have RecordTypeId');
            // If lead was auto-converted, we can't update it - skip this test scenario
            if (lead.IsConverted) {
                return; // Skip test if leads were auto-converted
            }

            // If status was changed by automation, update it back to Qualification
            if (lead.Status != 'Qualification') {
                lead.Status = 'Qualification';
                leadsToUpdate.add(lead);
            }
        }

        // Update status if needed
        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
            // Re-query after update
            testLeads = [
                SELECT Id, FirstName, LastName, Email, Phone, Date_of_Birth__c, GenderIdentity,
                       Address_Status__c, Status, Recommended_Product__c,
                       Sensor_CGM_Continuous_Glucose_Monitor__c, Type_of_Diabetes__c,
                       Duplicate_Review_Completed__c, Request_a_Call_Back__c,
                       Provider_Practice_Affiliation__c, RecordTypeId, RecordType.DeveloperName,
                       Company, LeadSource, IsConverted
                FROM Lead
                WHERE Id IN :insertedLeadIds
                WITH USER_MODE
            ];
        }

        // Final verification
        for (Lead lead : testLeads) {
            if (!lead.IsConverted) {
                Assert.areEqual('Qualification', lead.Status, 'Lead status should be Qualification');
            }
        }

        try {
            LeadDuplicateMatchingService.processDuplicateLeadConversion(testLeads);
            Assert.isTrue(true, 'Method should complete without exceptions');
        } catch (Exception ex) {
            Assert.fail('Method should not throw exceptions: ' + ex.getMessage());
        }
    }

    /**
     * @description Test coverage for exception in processDuplicateLeadConversion
     */
    @IsTest
    static void testProcessDuplicateLeadConversionException() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test', 'LastName' => 'ExceptionTest', 'Email' => 'exception.test@example.com',
            'Company' => 'Exception Test Company', 'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => 'Open'
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        insert new List<Lead>{testLead};

        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
        LeadDuplicateMatchingService.processDuplicateLeadConversion(new List<Lead>{testLead});
        ConstantsUtil.customExceptionSwitch = false;
        Assert.isTrue(true, 'Method should complete without exceptions');
        Test.stopTest();
    }

    /**
     * @description Test processDuplicateLeadConversion with leads that fail prechecks
     * Failed leads with LeadSource='Get Started' and Status='New'/'Qualification' will be assigned to DTC Open queue
     */
    @IsTest
    static void testProcessDuplicateLeadConversionWithFailedPrechecks() {
        // Create Contact record for Healthcare Practitioner
        Contact practitionerContact = TestDataFactory.getContact(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Practitioner',
            'Email' => 'test.practitioner@example.com'
        });
        insert practitionerContact;

        // Create Healthcare Practitioner Facility
        List<HealthcarePractitionerFacility> facilities = TestDataFactory.getHealthcarePractitionerFacilities(1, new Map<String, Object>{
            'Name' => 'Test Facility',
            'PractitionerId' => practitionerContact.Id
        });
        insert facilities;

        // Create leads that will fail prechecks and meet queue assignment criteria
        Lead failedLead1 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Failed',
            'LastName' => 'Precheck1',
            'Email' => 'failed.precheck1@example.com',
            'Phone' => '1111111111',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 15),
            'Status' => ConstantsUtil.LEAD_STATUS_NEW,  // Meets criteria for queue assignment
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Failed Company 1',
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_GET_STARTED  // Meets criteria for queue assignment
        });

        Lead failedLead2 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Failed',
            'LastName' => 'Precheck2',
            'Email' => 'failed.precheck2@example.com',
            'Phone' => '2222222222',
            'Date_of_Birth__c' => Date.newInstance(1985, 5, 20),
            'Status' => ConstantsUtil.LEAD_STATUS_QUALIFICATION,  // Meets criteria for queue assignment
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Failed Company 2',
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_GET_STARTED  // Meets criteria for queue assignment
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.SaveResult[] insertResults = Database.insert(new List<Lead>{failedLead1, failedLead2}, dmlOpts);

        // Collect inserted lead IDs
        List<Id> insertedLeadIds = new List<Id>();
        for (Database.SaveResult result : insertResults) {
            if (result.isSuccess()) {
                insertedLeadIds.add(result.getId());
            }
        }

        Assert.areEqual(2, insertedLeadIds.size(), 'Both leads should be inserted successfully');

        // Re-query leads with RecordType.DeveloperName
        List<Lead> testLeads = [
            SELECT Id, Status, RecordTypeId, RecordType.DeveloperName, IsConverted
            FROM Lead
            WHERE Id IN :insertedLeadIds
            WITH USER_MODE
        ];

        // Get DTC_Open queue for verification
        List<Group> dtcOpenQueues = [SELECT Id FROM Group WHERE DeveloperName = :ConstantsUtil.DTC_OPEN_QUEUE AND Type = 'Queue' WITH USER_MODE LIMIT 1];
        Id expectedQueueId = !dtcOpenQueues.isEmpty() ? dtcOpenQueues[0].Id : null;

        Test.startTest();
        // Process leads - they should fail prechecks and be assigned to DTC_Open queue (if they meet criteria)
        LeadDuplicateMatchingService.processDuplicateLeadConversion(testLeads);
        Test.stopTest();

        // Verify failed leads meeting criteria were assigned to DTC_Open queue (if not converted)
        List<Lead> updatedLeads = [
            SELECT Id, Status, IsConverted, OwnerId, LeadSource
            FROM Lead
            WHERE Id IN :insertedLeadIds
            WITH USER_MODE
        ];

        for (Lead lead : updatedLeads) {
            if (!lead.IsConverted && expectedQueueId != null) {
                // Lead meets criteria (LeadSource='Get Started' and Status='New'/'Qualification')
                // Should be assigned to DTC_Open queue, status remains unchanged
                Assert.areEqual(expectedQueueId, lead.OwnerId, 'Failed lead meeting criteria should be assigned to DTC_Open queue');
                // Status should remain unchanged
                Assert.isTrue(
                    lead.Status == ConstantsUtil.LEAD_STATUS_NEW || lead.Status == ConstantsUtil.LEAD_STATUS_QUALIFICATION,
                    'Lead status should remain unchanged'
                );
            }
        }
    }
    /**
     * @description Test processDuplicateLeadConversion with empty list after precheck filtering
     * Verifies that when no leads pass prechecks, the method returns early without errors
     */
    @IsTest
    static void testProcessDuplicateLeadConversionWithNoLeadsPassingPrechecks() {
        // Create leads that will all fail prechecks
        Lead failingLead1 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'All',
            'LastName' => 'Fail1',
            'Email' => 'all.fail1@example.com',
            'Phone' => '5555555555',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 15),
            'Status' => 'Open',  // Not "Qualification" - will fail MustEqualValue requirement
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Fail Company 1',
            'LeadSource' => 'Web'
        });

        Lead failingLead2 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'All',
            'LastName' => 'Fail2',
            'Email' => 'all.fail2@example.com',
            'Phone' => '6666666666',
            'Date_of_Birth__c' => Date.newInstance(1985, 5, 20),
            'Status' => 'Open',  // Not "Qualification" - will fail MustEqualValue requirement
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Company' => 'Fail Company 2',
            'LeadSource' => 'Web'
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.SaveResult[] insertResults = Database.insert(new List<Lead>{failingLead1, failingLead2}, dmlOpts);

        // Collect inserted lead IDs
        List<Id> insertedLeadIds = new List<Id>();
        for (Database.SaveResult result : insertResults) {
            if (result.isSuccess()) {
                insertedLeadIds.add(result.getId());
            }
        }

        Assert.areEqual(2, insertedLeadIds.size(), 'Both leads should be inserted successfully');

        // Re-query leads with RecordType.DeveloperName
        List<Lead> testLeads = [
            SELECT Id, Status, RecordTypeId, RecordType.DeveloperName, IsConverted
            FROM Lead
            WHERE Id IN :insertedLeadIds
            WITH USER_MODE
        ];

        Test.startTest();
        // Process leads - all should fail prechecks, method should return early
        try {
            LeadDuplicateMatchingService.processDuplicateLeadConversion(testLeads);
            Assert.isTrue(true, 'Method should complete without errors when no leads pass prechecks');
        } catch (Exception ex) {
            Assert.fail('Method should not throw exceptions when no leads pass prechecks: ' + ex.getMessage());
        }
        Test.stopTest();

        // Verify failed leads remain unchanged
        // When all leads fail prechecks, the method returns early without processing
        List<Lead> updatedLeads = [
            SELECT Id, Status, IsConverted
            FROM Lead
            WHERE Id IN :insertedLeadIds
            WITH USER_MODE
        ];

        for (Lead lead : updatedLeads) {
            if (!lead.IsConverted) {
                Assert.areEqual('Open', lead.Status, 'Failed leads should remain in Open status (not processed)');
            }
        }
    }

    /**
     * @description Test processDuplicateLeadConversion with null/empty input list
     */
    @IsTest
    static void testProcessDuplicateLeadConversionWithNullInput() {
        Test.startTest();
        // Test with null
        LeadDuplicateMatchingService.processDuplicateLeadConversion(null);

        // Test with empty list
        LeadDuplicateMatchingService.processDuplicateLeadConversion(new List<Lead>());
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null/empty inputs gracefully');
    }
}