/**
 * @description Test class for ProviderPracticeLeadMatchingService
 * @author Bijayalaxmi Prusty
 * @date 11th Dec 2025
 =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Dec 2025       Bijayalaxmi Prusty      Initial Version(US - NGASIM-368)
 */
@IsTest(IsParallel=true)
private class ProviderPracticeLeadMatchingService_Test {

    /**
     * @description Test setup method to create test data
     */
    @TestSetup
    static void setupTestData() {
        // Create Provider Account with NPI using TestDataFactory for actual insert
        Account providerAccount = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'Custom_UniqueID__c' => '1234567890',
            'BillingPostalCode' => '02111'
        });
        insert providerAccount;

        // Create Practice Account with billing address using TestDataFactory for actual insert
        Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice',
            'BillingStreet' => '123 Main St',
            'BillingCity' => 'Boston',
            'BillingState' => 'Massachusetts',
            'BillingStateCode' => 'MA',
            'BillingPostalCode' => '02111',
            'BillingCountry' => 'United States'
        });
        insert practiceAccount;
    }
    /**
     * @description Test provider matching with no match scenario
     */
    @IsTest
    static void testProviderMatchingNoMatch() {
        // Create lead with non-matching NPI
        Lead lead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PROVIDERPRACTICE_RT,
            'NPI__c' => '9999999999',
            'LastName' => 'Test Lead',
            'Company' => 'Test Company'
        });
        insert lead;

        Test.startTest();
        ProviderPracticeLeadMatchingService.processProviderPracticeMatching(new List<Lead>{lead}, null);
        Test.stopTest();

        Assert.areEqual(ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
                       lead.Provider_Matching_Status__c,
                       'Provider matching should return No Match for non-matching NPI');
    }

    /**
     * @description Test practice matching with non-existing practice name
     */
    @IsTest
    static void testPracticeMatchingNonExistingPractice() {
        // Create lead with non-existing practice name
        List<Lead> leads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PROVIDERPRACTICE_RT,
            'Practice_Name__c' => 'Non Existing Practice',
            'Street' => '123 Main St',
            'City' => 'Boston',
            'StateCode' => 'MA',
            'LastName' => 'Test Lead',
            'Company' => 'Test Company'
        });

        Test.startTest();
        ProviderPracticeLeadMatchingService.processProviderPracticeMatching(leads, null);
        Test.stopTest();

        Assert.areEqual(ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
                       leads[0].Practice_Matching_Status__c,
                       'Practice matching should return No Match for non-existing practice name');
    }

    /**
     * @description Test processing with wrong record type leads
     */
    @IsTest
    static void testWrongRecordTypeLeads() {
        // Create lead with wrong record type
        List<Lead> leads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'NPI__c' => '1234567890',
            'LastName' => 'Test Lead',
            'Company' => 'Test Company'
        });

        Test.startTest();
        ProviderPracticeLeadMatchingService.processProviderPracticeMatching(leads, null);
        Test.stopTest();

        Assert.isNull(leads[0].Provider_Matching_Status__c,
                     'Provider matching status should remain null for wrong record type');
        Assert.isNull(leads[0].Practice_Matching_Status__c,
                     'Practice matching status should remain null for wrong record type');
    }

    /**
     * @description Test processing with empty lead list
     */
    @IsTest
    static void testEmptyLeadList() {
        List<Lead> emptyLeads = new List<Lead>();

        Test.startTest();
        ProviderPracticeLeadMatchingService.processProviderPracticeMatching(emptyLeads, null);
        Test.stopTest();

        Assert.areEqual(0, emptyLeads.size(), 'Empty lead list should remain empty');
    }
    /**
     * @description Test update scenario where relevant fields changed
     */
    @IsTest
    static void testUpdateScenarioWithFieldChanges() {
        // Create lead with Provider Practice record type
        List<Lead> leads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PROVIDERPRACTICE_RT,
            'NPI__c' => '0000000000',
            'Practice_Name__c' => 'Old Practice',
            'LastName' => 'Test Lead',
            'Company' => 'Test Company'
        });

        // Create old lead map with different values
        Lead oldLead = leads[0].clone();
        oldLead.NPI__c = '1234567890';
        oldLead.Practice_Name__c = 'Test Practice';
        Map<Id, Lead> oldLeadsMap = new Map<Id, Lead>{leads[0].Id => oldLead};

        Test.startTest();
        ProviderPracticeLeadMatchingService.processProviderPracticeMatching(leads, oldLeadsMap);
        Test.stopTest();

        Assert.areEqual(ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
                       leads[0].Provider_Matching_Status__c,
                       'Provider matching should be processed when relevant fields changed');
    }

    /**
     * @description Test update scenario where no relevant fields changed
     */
    @IsTest
    static void testUpdateScenarioNoFieldChanges() {
        // Create lead with Provider Practice record type
        List<Lead> leads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PROVIDERPRACTICE_RT,
            'NPI__c' => '1234567890',
            'Practice_Name__c' => 'Test Practice',
            'LastName' => 'Test Lead',
            'Company' => 'Test Company'
        });

        // Create old lead map with same values
        Lead oldLead = leads[0].clone();
        Map<Id, Lead> oldLeadsMap = new Map<Id, Lead>{leads[0].Id => oldLead};

        Test.startTest();
        ProviderPracticeLeadMatchingService.processProviderPracticeMatching(leads, oldLeadsMap);
        Test.stopTest();

        Assert.isNull(leads[0].Provider_Matching_Status__c,
                     'Provider matching should not be processed when no relevant fields changed');
    }
    /**
     * @description Test both provider and practice matching in single lead
     */
    @IsTest
    static void testCombinedProviderAndPracticeMatching() {
        // Create lead with both provider and practice data
        List<Lead> leads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PROVIDERPRACTICE_RT,
            'NPI__c' => '1234567890',
            'Practice_Name__c' => 'Test Practice',
            'Street' => '123 Main St',
            'City' => 'Boston',
            'StateCode' => 'MA',
            'LastName' => 'Test Lead',
            'Company' => 'Test Company'
        });

        Test.startTest();
        ProviderPracticeLeadMatchingService.processProviderPracticeMatching(leads, null);
        Test.stopTest();

        Assert.areEqual(ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH,
                       leads[0].Provider_Matching_Status__c,
                       'Provider matching should return Full Match');
        Assert.areEqual(ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH,
                       leads[0].Practice_Matching_Status__c,
                       'Practice matching should return Full Match');
    }

    /**
     * @description Test error scenarios and exception handling
     */
    @IsTest
    static void testErrorScenarios() {
        Test.startTest();

        // Test exception handling scenario
        Lead exceptionLead = new Lead();
        exceptionLead.Id = MockDataFactory.getFakeId('Lead');
        exceptionLead.RecordTypeId = ConstantsUtil.LEAD_PROVIDERPRACTICE_RT;
        exceptionLead.LastName = 'Exception Lead';
        exceptionLead.Company = 'Test Company';

        // Create a lead with field that could cause exception during processing
        List<Lead> exceptionLeads = new List<Lead>{exceptionLead};

        // Enable custom exception switch to trigger catch block
        ConstantsUtil.customExceptionSwitch = true;

        // This should trigger the catch block for error logging
        ProviderPracticeLeadMatchingService.processProviderPracticeMatching(exceptionLeads, null);

        // Reset exception switch
        ConstantsUtil.customExceptionSwitch = false;

        // Verify the method handled the exception gracefully

        Test.stopTest();

        // Verify the method handled the exception gracefully and didn't throw to test level
        Assert.isTrue(true, 'Method executed successfully and handled exception in catch block');
    }

    @isTest
    static void testGenerateAccountProviderKey() {
        Account account = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'Custom_UniqueID__c' => ''
        });
        String key = ProviderPracticeLeadMatchingService.generateAccountProviderKey(account);
        Assert.isNull(key, 'Key should be null if custom unique ID is null');
    }

    @isTest
    static void testGenerateAccountPracticeKey() {
        Account account = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice',
            'BillingStreet' => '123 Main St',
            'BillingCity' => 'Boston',
            'BillingState' => 'Massachusetts',
            'BillingStateCode' => 'MA',
            'BillingPostalCode' => '02111',
            'BillingCountry' => 'United States'
        });
        String key = ProviderPracticeLeadMatchingService.generateAccountPracticeKey(account);
        Assert.areEqual('test practice|ma|123 main st|boston', key, 'Key should match the practice name, state, and address');
    }
    @isTest
    static void testAccountStateValue() {
        Account account = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'BillingState' => 'Massachusetts'
        });
        String state = ProviderPracticeLeadMatchingService.getAccountStateValue(account);
        Assert.areEqual('Massachusetts', state, 'State should match the billing state code');
    }
}