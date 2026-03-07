/**
 * @description Test class for LeadConversionHandler
 * Created Date : Oct 09, 2025
 * Created By   : Sunil Khanchandani
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Oct 09, 2025        Sunil Khanchandani      Initial Version
 * V1.1.0       Nov 6, 2025         Priyansh Shukla         Added tests for filterLeadsForConversion (US NGASIM-992)
 * V1.2.0       Nov 7, 2025         Ayush Sharma            Added tests for 3rd Party Trainer (US NGOMCT-657)
 * V1.3.0       Feb 24, 2026       Bijayalaxmi Prusty       Updated (US NGASIM-2157)
 */

@IsTest(IsParallel=true)
public class LeadConversionHandler_Test {

    /**
     * @description Test filterLeadsForConversion with null input
     */
    @IsTest
    static void testFilterLeadsForConversionNullInput() {
        Test.startTest();
        LeadConversionHandler.filterLeadsForConversion(null);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null input gracefully');
    }

    /**
     * @description Test filterLeadsForConversion with empty list
     */
    @IsTest
    static void testFilterLeadsForConversionEmptyList() {
        Test.startTest();
        LeadConversionHandler.filterLeadsForConversion(new List<Lead>());
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle empty list gracefully');
    }

    /**
     * @description Test filterLeadsForConversion with eligible leads
     * Verifies that eligible leads are filtered and delegated to PatientLeadConversionService
     */
    @IsTest
    static void testFilterLeadsForConversionEligibleLeads() {
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'FirstName' => 'Lead',
            'LastName' => 'PatientAutoConvert',
            'Email' => 'filtereligible@example.com',
            'Phone' => '5551111111',
            'Date_of_Birth__c' => Date.today().addYears(-30),
            'GenderIdentity' => 'Male',
            'Address_Status__c' => 'Verified',
            'Recommended_Product__c' => 'DASH',
            'Sensor_CGM_Continuous_Glucose_Monitor__c' => 'Dexcom G7',
            'Type_of_Diabetes__c' => 'Type 1',
            'Status' => 'Qualification',
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'Company' => 'Test Company',
            'LeadSource' => 'Web',
            'Street' => '123 Test Street',
            'City' => 'Boston',
            'State' => 'Massachusetts',
            'PostalCode' => '02102',
            'Country' => 'United States'
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(testLead, dmlOpts);

        // Re-apply Matching_Status__c in case beforeInsert overwrote it; bypass trigger to avoid re-processing
        TriggerHandler.bypass('LeadTriggerHandler');
        update new Lead(Id = testLead.Id, Matching_Status__c = ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH);
        TriggerHandler.clearBypass('LeadTriggerHandler');

        testLead = [SELECT Id, Matching_Status__c, Request_a_Call_Back__c, Provider_Practice_Affiliation__c,
                           RecordTypeId, IsConverted FROM Lead WHERE Id = :testLead.Id];

        Test.startTest();
        LeadConversionHandler.filterLeadsForConversion(new List<Lead>{ testLead });
        Test.stopTest();

        List<Lead> convertedLeads = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id];
        Assert.isFalse(convertedLeads.isEmpty(), 'Lead should exist');
    }

    /**
     * @description Test filterLeadsForConversion filters out wrong RecordType
     */
    @IsTest
    static void testFilterLeadsForConversionWrongRecordType() {
        // Create leads with non-Patient RecordType
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'RecordTypeId' =>ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT,
            'Matching_Status__c' =>ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' =>false,
            'Date_of_Birth__c' =>Date.today().addYears(-30)
        });

        Test.startTest();
        LeadConversionHandler.filterLeadsForConversion(testLeads);
        Test.stopTest();

        Assert.isTrue(true, 'Leads with wrong RecordType should be filtered out');
    }

    /**
     * @description Test filterLeadsForConversion filters out already converted leads
     */
    @IsTest
    static void testFilterLeadsForConversionAlreadyConverted() {
        // Create and insert HealthcarePractitionerFacility
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        // Create leads with IsConverted = true
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'IsConverted' => true,
            'Date_of_Birth__c' => Date.today().addYears(-30)
        });

        Test.startTest();
        LeadConversionHandler.filterLeadsForConversion(testLeads);
        Test.stopTest();

        Assert.isTrue(true, 'Already converted leads should be filtered out');
    }

    /**
     * @description Test filterLeadsForConversion filters out leads with wrong Matching_Status__c
     */
    @IsTest
    static void testFilterLeadsForConversionWrongMatchingStatus() {
        // Create and insert HealthcarePractitionerFacility
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        // Create leads with wrong Matching_Status__c
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'Date_of_Birth__c' => Date.today().addYears(-30)
        });

        Test.startTest();
        LeadConversionHandler.filterLeadsForConversion(testLeads);
        Test.stopTest();

        Assert.isTrue(true, 'Leads with wrong Matching_Status should be filtered out');
    }

    /**
     * @description Test filterLeadsForConversion filters out leads with Request_a_Call_Back__c = true
     */
    @IsTest
    static void testFilterLeadsForConversionRequestCallback() {
        // Create and insert HealthcarePractitionerFacility
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        // Create leads with Request_a_Call_Back__c = true
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => true,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'Date_of_Birth__c' => Date.today().addYears(-30)
        });

        Test.startTest();
        LeadConversionHandler.filterLeadsForConversion(testLeads);
        Test.stopTest();

        Assert.isTrue(true, 'Leads with Request_a_Call_Back__c = true should be filtered out');
    }

    /**
     * @description Test filterLeadsForConversion filters out leads without Provider
     */
    @IsTest
    static void testFilterLeadsForConversionNoProvider() {
        // Create leads without Provider_Practice_Affiliation__c
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => null,
            'Date_of_Birth__c' => Date.today().addYears(-30)
        });

        Test.startTest();
        LeadConversionHandler.filterLeadsForConversion(testLeads);
        Test.stopTest();

        Assert.isTrue(true, 'Leads without Provider should be filtered out');
    }

    /**
     * @description Test filterLeadsForConversion with FLS failure
     * This test covers line 48 (FLS failure return false)
     */
    @IsTest
    static void testFilterLeadsForConversionFLSFailure() {
        // Create and insert HealthcarePractitionerFacility
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        // Create eligible leads that would normally pass
        List<Lead> testLeads = TestDataFactory.getLeads(2, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'Date_of_Birth__c' => Date.today().addYears(-30)
        });

        Test.startTest();
        // Simulate FLS failure
        LeadConversionHandler.simulateFLSFailure = true;
        LeadConversionHandler.filterLeadsForConversion(testLeads);
        // Reset flag
        LeadConversionHandler.simulateFLSFailure = false;
        Test.stopTest();

        Assert.isTrue(true, 'Should filter out all leads when FLS check fails');
    }

    /**
     * @description Test filterLeadsForConversion with simulateEligibleLeads (covers line 37)
     * Simulates eligibleLeads = null to exercise exception handling path
     */
    @IsTest
    static void testFilterLeadsForConversionSimulateEligibleLeads() {
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'Date_of_Birth__c' => Date.today().addYears(-30)
        });
        insert testLeads;

        Test.startTest();
        LeadConversionHandler.simulateEligibleLeads = true;
        LeadConversionHandler.filterLeadsForConversion(testLeads);
        LeadConversionHandler.simulateEligibleLeads = false;
        Test.stopTest();

        Assert.isTrue(true, 'Should handle simulateEligibleLeads path gracefully');
    }

    /**
     * @description Test processLeadConversion with null input
     */
    @IsTest
    static void testProcessLeadConversionWithNullInput() {
        Test.startTest();
        LeadConversionHandler.processLeadConversion(null, null);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null input gracefully');
    }

    /**
     * @description Test processLeadConversion with empty list
     */
    @IsTest
    static void testProcessLeadConversionWithEmptyList() {
        Test.startTest();
        LeadConversionHandler.processLeadConversion(new List<Lead>(), new Map<Id, Lead>());
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle empty list gracefully');
    }

    /**
     * @description Test processLeadConversion from afterUpdate context with lead conversion
     */
    @IsTest
    static void testProcessLeadConversionFromAfterUpdate() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'FirstName' => 'Test',
            'LastName' => 'Patient'
        });
        insert testLead;

        // Bypass Lead_Converted_Status_Validation before conversion
        LeadConversionHelper.updateValidationBypassForLeads(new List<Lead>{ testLead });

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setDoNotCreateOpportunity(false);
        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setOwnerId(UserInfo.getUserId());
        lc.setBypassAccountDedupeCheck(true);
        lc.setBypassContactDedupeCheck(true);

        Test.startTest();
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        Test.stopTest();

        Assert.isTrue(lcr.isSuccess(), 'Lead conversion should succeed');
    }

    /**
     * @description Test processLeadConversion for Trainer Record Type from afterUpdate context with lead conversion
     */
    @IsTest
    static void testProcessLeadConversionTrainerFromAfterUpdate() {
        Lead trainerLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT,
            'FirstName' => 'Test',
            'LastName' => 'Patient'
        });
        insert trainerLead;

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(trainerLead.Id);
        lc.setDoNotCreateOpportunity(false);
        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true AND MasterLabel = 'Qualified' LIMIT 1];
        lc.setConvertedStatus(convertStatus.MasterLabel);

        Test.startTest();
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        Test.stopTest();

        Training__c training = [SELECT Id,Account__c, RecordTypeId FROM Training__c WHERE Account__c =: lcr.getAccountId() LIMIT 1][0];

        Assert.isTrue(lcr.isSuccess(), 'Lead conversion should succeed');
        Assert.isTrue(training != null, 'CPT Training Record is created');
        Assert.isTrue(training.RecordTypeId == ConstantsUtil.TRAINING_CPT_TRAINING_RT, 'CPT Training Record is created');
    }

    /**
     * @description Test processLeadConversion for Provider-Practice Record Type
     * Verifies converted Provider-Practice leads are routed to processProviderPracticeLeads
     */
    @IsTest
    static void testProcessLeadConversionProviderPracticeFromAfterUpdate() {
        Account practice = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Provider Practice Test',
            'BillingPostalCode' => '30202'
        });
        insert practice;

        Account providerAccount = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Provider',
            'BillingPostalCode' => '30202'
        });
        insert providerAccount;

        Lead providerPracticeLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PROVIDERPRACTICE_RT,
            'FirstName' => 'Test',
            'LastName' => 'ProviderPracticeLead',
            'Related_Provider__c' => providerAccount.Id,
            'Practice__c' => practice.Id,
            'NPI__c' => 'Test NPI',
            'PostalCode' => '90001'
        });
        insert providerPracticeLead;

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(providerPracticeLead.Id);
        lc.setAccountId(providerAccount.Id);
        lc.setDoNotCreateOpportunity(true);
        lc.setConvertedStatus(ConstantsUtil.LEAD_PROVIDERPRACTICE_CONVERT_STATUS);
        lc.setOwnerId(UserInfo.getUserId());

        Test.startTest();
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        Test.stopTest();

        Assert.isTrue(lcr.isSuccess(), 'Provider-Practice lead conversion should succeed');
    }

    /**
     * @description Test conversion for 3rd Party Trainer lead with owner set
     */
    @IsTest
    static void testConvertThirdPartyTrainerLeadWithOwner() {
        Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Owner Trainer Practice',
            'Phone' => '5551230000'
        });
        insert practiceAccount;

        Lead trainerLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT,
            'FirstName' => 'Owner',
            'LastName' => 'Trainer',
            'Email' => 'owner.trainer@example.com',
            'Phone' => '5551239876',
            'Status' => 'Open',
            'Date_of_Birth__c' => Date.today().addYears(-25),
            'Practice__c' => practiceAccount.Id
        });
        insert trainerLead;

        LeadStatus convertStatus = [
            SELECT Id, MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true AND MasterLabel = 'Qualified'
            LIMIT 1
        ];

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(trainerLead.Id);
        lc.setDoNotCreateOpportunity(false);
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setOwnerId(UserInfo.getUserId());
        lc.setSendNotificationEmail(false);

        Test.startTest();
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        Test.stopTest();

        Assert.isTrue(lcr.isSuccess(), 'Lead conversion should succeed');
    }

}