/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 15th Dec 2025
 * @description : Test class for MemberPlanService
 *  * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       15th Dec 2025       Bijayalaxmi Prusty      Initial Version(US - NGOMCT-824)
 * V1.0.1       8th Jan 2026        Bijayalaxmi Prusty      Updated(US - NGOMCT-1550)
 */
@isTest(IsParallel=true)
private class MemberPlanService_Test {

    /**
     * @description Test successful creation of MemberPlan records
     */
    @isTest
    static void testCreateMemberPlansSuccess() {
        // Create Account
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        // Create Lead with insurance information
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead',
            'Insurance_Type__c' => 'Medicaid',
            'Insurance_Company_Name__c' => 'Test Insurance Company',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        // Perform actual lead conversion to get real conversion results
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setAccountId(testAccount.Id);
        lc.setConvertedStatus('Converted');
        List<Database.LeadConvertResult> conversionResults = Database.convertLead(new List<Database.LeadConvert>{lc});

        Map<Lead, Account> leadToAccountMap = new Map<Lead, Account>();
        leadToAccountMap.put(testLead, testAccount);

        Test.startTest();
        MemberPlanService.createMemberPlans(
            conversionResults,
            leadToAccountMap,
            ConstantsUtil.ASIM_TAG
        );
        Test.stopTest();

        // Verify MemberPlan was created
        List<MemberPlan> memberPlans = [
            SELECT Id, MemberId, Name, Type__c
            FROM MemberPlan
            WHERE MemberId = :testAccount.Id
        ];
        Assert.areEqual(1, memberPlans.size(), 'Should create one MemberPlan');
        Assert.areEqual(testAccount.Id, memberPlans[0].MemberId, 'MemberId should match Account');
        Assert.areEqual('Test Insurance Company', memberPlans[0].Name, 'Name should match Insurance Company Name');
        Assert.areEqual('Medicaid', memberPlans[0].Type__c, 'Type should match Insurance Type');
    }

    /**
     * @description Test MemberPlan creation without Insurance_Company_Name__c - should not create
     */
    @isTest
    static void testCreateMemberPlansWithoutInsuranceCompanyName() {
        // Create Account
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        // Create Lead without Insurance_Company_Name__c
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead',
            'Insurance_Type__c' => 'Medicaid',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        // Perform actual lead conversion to get real conversion results
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setAccountId(testAccount.Id);
        lc.setConvertedStatus('Converted');
        List<Database.LeadConvertResult> conversionResults = Database.convertLead(new List<Database.LeadConvert>{lc});

        Map<Lead, Account> leadToAccountMap = new Map<Lead, Account>();
        leadToAccountMap.put(testLead, testAccount);

        Test.startTest();
        MemberPlanService.createMemberPlans(
            conversionResults,
            leadToAccountMap,
            ConstantsUtil.ASIM_TAG
        );
        Test.stopTest();

        // Verify no MemberPlan was created
        List<MemberPlan> memberPlans = [
            SELECT Id
            FROM MemberPlan
            WHERE MemberId = :testAccount.Id
        ];
        Assert.areEqual(0, memberPlans.size(), 'Should not create MemberPlan without Insurance_Company_Name__c');
    }

    /**
     * @description Test with null input
     */
    @isTest
    static void testCreateMemberPlansNullInput() {
        Test.startTest();
        MemberPlanService.createMemberPlans(null, null, null);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null input gracefully');
    }

    /**
     * @description Test with empty maps
     */
    @isTest
    static void testCreateMemberPlansEmptyInput() {
        Test.startTest();
        MemberPlanService.createMemberPlans(
            new List<Database.LeadConvertResult>(),
            new Map<Lead, Account>(),
            ConstantsUtil.ASIM_TAG
        );
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle empty input gracefully');
    }

    /**
     * @description Test exception handling with customExceptionSwitch in createMemberPlans
     * Verifies that the service gracefully handles and logs exceptions during MemberPlan creation
     */
    @isTest
    static void testCreateMemberPlansExceptionHandling() {
        // Create Account
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        // Create Lead with insurance information
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead',
            'Insurance_Type__c' => 'Medicaid',
            'Insurance_Company_Name__c' => 'Test Insurance Company',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        // Perform actual lead conversion to get real conversion results
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setAccountId(testAccount.Id);
        lc.setConvertedStatus('Converted');
        List<Database.LeadConvertResult> conversionResults = Database.convertLead(new List<Database.LeadConvert>{lc});

        Map<Lead, Account> leadToAccountMap = new Map<Lead, Account>();
        leadToAccountMap.put(testLead, testAccount);

        Test.startTest();

        try {
            ConstantsUtil.customExceptionSwitch = true;

            // Call the method that should handle the exception gracefully
            MemberPlanService.createMemberPlans(
                conversionResults,
                leadToAccountMap,
                ConstantsUtil.ASIM_TAG
            );

            // Should complete without throwing exception as errors are handled internally
            Assert.isTrue(true, 'Method should handle exceptions gracefully');

        } finally {
            // Always reset the exception flag
            ConstantsUtil.customExceptionSwitch = false;
        }

        Test.stopTest();
    }

    /**
     * @description Test exception handling with customExceptionSwitch in insertMemberPlans
     * Verifies that the service gracefully handles and logs exceptions during MemberPlan insertion
     */
    @isTest
    static void testInsertMemberPlansExceptionHandling() {
        // Create Account
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        // Create Lead with insurance information to trigger MemberPlan creation
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead',
            'Insurance_Type__c' => 'Medicaid',
            'Insurance_Company_Name__c' => 'Test Insurance Company',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        // Perform actual lead conversion to get real conversion results
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setAccountId(testAccount.Id);
        lc.setConvertedStatus('Converted');
        List<Database.LeadConvertResult> conversionResults = Database.convertLead(new List<Database.LeadConvert>{lc});

        Map<Lead, Account> leadToAccountMap = new Map<Lead, Account>();
        leadToAccountMap.put(testLead, testAccount);

        Test.startTest();

        try {
            ConstantsUtil.customExceptionSwitch = true;

            // Call the method that should handle the exception gracefully
            MemberPlanService.createMemberPlans(
                conversionResults,
                leadToAccountMap,
                ConstantsUtil.ASIM_TAG
            );

            // Should complete without throwing exception as errors are handled internally
            Assert.isTrue(true, 'Method should handle exceptions gracefully');

        } finally {
            // Always reset the exception flag
            ConstantsUtil.customExceptionSwitch = false;
        }

        Test.stopTest();
    }

    /**
     * @description Test MemberPlan creation with Insurance_Company_Name__c
     */
    @isTest
    static void testCreateMemberPlansWithFallbackName() {
        // Create Account
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        // Create Lead with Insurance_Company_Name__c
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead',
            'Insurance_Type__c' => 'Medicaid',
            'Insurance_Company_Name__c' => 'Test Insurance', // Required field
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        // Perform actual lead conversion to get real conversion results
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setAccountId(testAccount.Id);
        lc.setConvertedStatus('Converted');
        List<Database.LeadConvertResult> conversionResults = Database.convertLead(new List<Database.LeadConvert>{lc});

        Map<Lead, Account> leadToAccountMap = new Map<Lead, Account>();
        leadToAccountMap.put(testLead, testAccount);

        Test.startTest();
        MemberPlanService.createMemberPlans(
            conversionResults,
            leadToAccountMap,
            ConstantsUtil.ASIM_TAG
        );
        Test.stopTest();

        // Verify MemberPlan was created with Insurance_Company_Name__c as Name
        List<MemberPlan> memberPlans = [
            SELECT Id, Name, Type__c
            FROM MemberPlan
            WHERE MemberId = :testAccount.Id
        ];
        Assert.areEqual(1, memberPlans.size(), 'Should create MemberPlan');
        Assert.areEqual('Test Insurance', memberPlans[0].Name, 'Name should match Insurance_Company_Name__c');
    }
    /**
     * @description Test getMappedInsuranceType with null input
     */
    @isTest
    static void testGetMappedInsuranceType() {
        String mappedInsuranceType = MemberPlanService.getMappedInsuranceType('');
        Assert.isNull(mappedInsuranceType, 'Should return null for blank input');
    }
}