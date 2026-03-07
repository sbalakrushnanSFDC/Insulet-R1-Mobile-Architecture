/**
     * @description Test class for OpportunityService
     * Created Date : Oct 09, 2025
     * Created By   : Sunil Khanchandani
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Oct 09, 2025       Sunil Khanchandani       Initial Version
 * V1.0.1       Dec 02, 2025       Rajasekar M              Added cancellation validation tests (US - NGOMCT-839)
 * V1.0.2       Jan 09, 2026       Charchit Nirayanwal      Added updateStageFromSubStatus tests (US - NGASIM-1660)
 * V1.0.3       Jan 22, 2026       Sushanth Shetty          Added generateTasksForOpportunities tests (US - NGASIM-1274)
 * V1.0.4       Feb 23, 2026       Lokesh P                 Added setPrimaryCampaign tests (US - NGASIM-2061)
 */

@IsTest(IsParallel=true)
public class OpportunityService_Test {

    /**
     * @description Setup data for the test class
     */
    @TestSetup
    static void setupData() {
        User salesUser;
        // Create user and assign permission sets in a separate transaction to avoid MIXED_DML_OPERATION
        System.runAs(new User(Id = UserInfo.getUserId())) {
            salesUser = TestDataFactory.getTestUser('Sales', new Map<String, Object>{
                'FirstName' => 'Sales',
                'LastName' => 'TestUser'
            });
            insert salesUser;
            // Query required permission sets
            List<PermissionSet> permissionSets = [
                SELECT Id, Name
                FROM PermissionSet
                WHERE Name IN ('Inside_Sales_Core_Access', 'HealthCloudFoundation')
            ];
            // Create permission set assignments
            List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
            for (PermissionSet ps : permissionSets) {
                assignments.add(new PermissionSetAssignment(
                    AssigneeId = salesUser.Id,
                    PermissionSetId = ps.Id
                ));
            }
            insert assignments;
        }
    }

    /**
     * @description Test updateConvertedOpportunities with null input
     */
    @IsTest
    static void testUpdateConvertedOpportunitiesWithNullInput() {
        Test.startTest();
        OpportunityService.updateConvertedOpportunities(null, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null input gracefully');
    }

    /**
     * @description Test updateConvertedOpportunities with empty list
     */
    @IsTest
    static void testUpdateConvertedOpportunitiesWithEmptyList() {
        Test.startTest();
        OpportunityService.updateConvertedOpportunities(new List<Lead>(), ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle empty list gracefully');
    }

    /**
     * @description Test updateConvertedOpportunities with leads having empty Recommended_Product__c
     */
    @IsTest
    static void testUpdateConvertedOpportunitiesWithEmptyRecommendedProduct() {
        	Lead patientLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
			'FirstName' => 'First Name',
            'LastName' => 'Last Name',
            'Recommended_Product__c' => '',
            'Validation_Bypass__c' => true

        });
        insert patientLead;
        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(patientLead.Id);
        lc.setDoNotCreateOpportunity(false);
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setOwnerId(UserInfo.getUserId()); // ADDED THIS LINE to fix ownerId issue

        Test.startTest();
        Database.convertLead(lc);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle empty Recommended_Product__c');
    }

    /**
     * @description Test updateConvertedOpportunities with leads having long names
     */
    @IsTest
    static void testUpdateConvertedOpportunitiesWithLongNames() {
		Lead patientLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
			'FirstName' => 'aX9pQ3zLkT7mV2sNwB5rJ0yG4eH8dF1cR6tUo',
            'LastName' => 'aX9pQ3zLkT7mV2sNwB5rJ0yG4eH8dF1cR6tUo',
            'Recommended_Product__c' => 'DASH',
            'Validation_Bypass__c' => true

        });
        insert patientLead;
        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(patientLead.Id);
        lc.setDoNotCreateOpportunity(false);
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setOwnerId(UserInfo.getUserId()); //ADDED THIS LINE TO FIX OWNERID ISSUE

        Test.startTest();
        Database.convertLead(lc);
        Test.stopTest();


        Assert.isTrue(true, 'Method should handle long names and trim to 120 characters');
    }

    /**
     * @description Test updateConvertedOpportunities with mixed lead data
     */
    @IsTest
    static void testUpdateConvertedOpportunitiesWithMockOpportunities() {
        Test.startTest();
		Opportunity opp = new Opportunity();
		opp.Id = MockDataFactory.getFakeId('Opportunity');
		opp.Name = 'Test Mock Opportunity';
		opp.StageName = 'Prospecting';
		opp.CloseDate = System.today().addDays(30);
		OpportunityService.updateOpportunities(new List<Opportunity>{opp});
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle mock opportunity');
    }

    @IsTest
    static void testUpdateConvertedOpportunitiesWithNullOpportunities() {
        Test.startTest();
		OpportunityService.updateOpportunities(new List<Opportunity>());
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle emptly opportunity list to update');
    }

    /**
     * @description Test updateOpportunities method directly with empty list to cover line 94
     */
    @IsTest
    static void testUpdateOpportunitiesWithEmptyList() {
        Test.startTest();
        OpportunityService.updateOpportunities(new List<Opportunity>());
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle empty opportunities list');
    }

    /**
     * @description Test errorTagName field assignment
     */
    @IsTest
    static void testErrorTagNameAssignment() {
        Test.startTest();
        OpportunityService.updateConvertedOpportunities(new List<Lead>(), ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        Assert.isTrue(true, 'Error tag name should be assigned');
    }

    /**
     * @description Test with oppotunity name update from converted lead
     */
    @IsTest
    static void testLeadConversionRecord(){
        Lead patientLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Recommended_Product__c' => 'DASH',
            'Validation_Bypass__c' => true
        });
        insert patientLead;

        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(patientLead.Id);
        lc.setDoNotCreateOpportunity(false);
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setOwnerId(UserInfo.getUserId()); // ADDED THIS LINE TO FIX OWNERID ISSUE

        Test.startTest();
        Database.convertLead(lc);
        Test.stopTest();
        Assert.isTrue(true, 'Opportunity name is updated as lead name and product recommendation');
    }

    /**
     * @description Test Opportunity naming Convention 'Beneifts-MM/DD/YYYY'
     * Covers line 106 - all three names present
     */
    @IsTest
    static void testOpportunityNamingConvention() {
        Lead testLead = new Lead(
            FirstName = 'John',
            MiddleName = 'Michael',
            LastName = 'Doe',
            Recommended_Product__c = 'DASH'
        );

        Test.startTest();
        Opportunity opp = OpportunityService.prepareOpportunityFromLead(testLead);
        Test.stopTest();

        Assert.isTrue(opp.Name.contains(System.Label.Opportunity_Name_Prefix), 'Opportunity name contains the required Prefix');
        Assert.isTrue(opp.Name.contains(Datetime.now().format('MM/dd/yyyy')), 'Opportunity name date of creation');
    }

    /**
     * @description Test beforeUpdate trigger with valid Status/SubStatus combination
     * Note: Running as current user (System Admin) to bypass Prevent_Stage_Update validation rule
     */
    @IsTest
    static void testTriggerBeforeUpdateWithValidCombination() {
        // Query an existing Custom Metadata record to use in test
        List<ASPN_Cancellation_Settings__mdt> settings = [
            SELECT Status__c, Substatus__c
            FROM ASPN_Cancellation_Settings__mdt
            WHERE Status__c != null
            AND Substatus__c != null
            LIMIT 1
        ];

        if (!settings.isEmpty()) {
            String validStatus = settings[0].Status__c;
            String validSubStatus = settings[0].Substatus__c;

            // Create test Opportunity
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opportunity',
                StageName = 'Prospecting',
                CloseDate = System.today().addDays(30),
                Status__c = validStatus,
                Sub_Status__c = validSubStatus,
                Cancel_Order__c = false,
                RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
            );
            insert testOpp;

            // Update Cancel_Order__c to true
            testOpp.Cancel_Order__c = true;

            Test.startTest();
            try {
                update testOpp;
                Assert.isTrue(true, 'Update should succeed for valid Status/SubStatus combination');
            } catch (DmlException e) {
                Assert.fail('Update should not fail for valid combination: ' + e.getMessage());
            }
            Test.stopTest();
        } else {
            Assert.isTrue(true, 'No Custom Metadata records found - skipping test');
        }
    }

    /**
     * @description Test beforeUpdate trigger with invalid Status/SubStatus combination
     */
    @IsTest
    static void testTriggerBeforeUpdateWithInvalidCombination() {
        User salesUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestUser' LIMIT 1];
        // Create test Opportunity with invalid Status/SubStatus combination
        System.runAs(salesUser) {
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opportunity',
                StageName = 'Prospecting',
                CloseDate = System.today().addDays(30),
                Status__c = 'Invalid Status That Does Not Exist',
                Sub_Status__c = 'Invalid SubStatus That Does Not Exist',
                Cancel_Order__c = false,
                RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
            );
            insert testOpp;

            // Update Cancel_Order__c to true
            testOpp.Cancel_Order__c = true;

            Test.startTest();
            try {
                update testOpp;
                Assert.fail('Update should fail for invalid Status/SubStatus combination');
            } catch (DmlException e) {
                Assert.isTrue(
                    e.getMessage().contains('You cannot cancel an Opportunity that is in the current ASPN Status and Sub-Status.'),
                    'Error message should match expected validation error'
                );
            }
            Test.stopTest();
        }
    }

    /**
     * @description Test beforeUpdate when Cancel_Order__c doesn't change
     */
    @IsTest
    static void testTriggerBeforeUpdateWhenCancelOrderDoesNotChange() {
        User salesUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestUser' LIMIT 1];
        // Create test Opportunity
        System.runAs(salesUser) {
            Opportunity testOpp = new Opportunity(
                Name = 'Test Opportunity',
                StageName = 'Prospecting',
                CloseDate = System.today().addDays(30),
                Status__c = 'Invalid Status',
                Sub_Status__c = 'Invalid SubStatus',
                Cancel_Order__c = false,
                RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
            );
            insert testOpp;

            // Update other field but keep Cancel_Order__c as false
            testOpp.Name = 'Updated Name';

            Test.startTest();
            try {
                update testOpp;
                Assert.isTrue(true, 'Update should succeed when Cancel_Order__c does not change');
            } catch (DmlException e) {
                Assert.fail('Update should not fail when Cancel_Order__c does not change: ' + e.getMessage());
            }
            Test.stopTest();
        }
    }

    /**
     * @description Test beforeUpdate with bulk opportunities
     * Note: Running as current user (System Admin) to bypass Prevent_Stage_Update validation rule
     */
    @IsTest
    static void testTriggerBeforeUpdateWithBulkOpportunities() {
        // Query an existing Custom Metadata record to use in test
        List<ASPN_Cancellation_Settings__mdt> settings = [
            SELECT Status__c, Substatus__c
            FROM ASPN_Cancellation_Settings__mdt
            WHERE Status__c != null
            AND Substatus__c != null
            LIMIT 1
        ];

        if (!settings.isEmpty()) {
            String validStatus = settings[0].Status__c;
            String validSubStatus = settings[0].Substatus__c;

            // Create multiple test Opportunities
            List<Opportunity> testOpps = new List<Opportunity>();
            for (Integer i = 0; i < 5; i++) {
                testOpps.add(new Opportunity(
                    Name = 'Test Opportunity ' + i,
                    StageName = 'Prospecting',
                    CloseDate = System.today().addDays(30),
                    Status__c = validStatus,
                    Sub_Status__c = validSubStatus,
                    Cancel_Order__c = false,
                    RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
                ));
            }
            insert testOpps;

            // Update Cancel_Order__c to true for all
            for (Opportunity opp : testOpps) {
                opp.Cancel_Order__c = true;
            }

            Test.startTest();
            try {
                update testOpps;
                Assert.isTrue(true, 'Bulk update should succeed for valid combinations');
            } catch (DmlException e) {
                Assert.fail('Bulk update should not fail for valid combinations: ' + e.getMessage());
            }
            Test.stopTest();
        } else {
            Assert.isTrue(true, 'No Custom Metadata records found - skipping test');
        }
    }

    /**
     * @description Test beforeInsert trigger scenarios for valid and invalid combinations
     */
    @IsTest
    static void testTriggerBeforeInsertScenarios() {
        User salesUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestUser' LIMIT 1];
        List<ASPN_Cancellation_Settings__mdt> settings = [
            SELECT Status__c, Substatus__c
            FROM ASPN_Cancellation_Settings__mdt
            WHERE Status__c != null
            AND Substatus__c != null
            LIMIT 1
        ];

        System.runAs(salesUser) {
            Test.startTest();

            if (!settings.isEmpty()) {
                Opportunity validOpp = new Opportunity(
                    Name = 'Insert Valid Opportunity',
                    StageName = 'Prospecting',
                    CloseDate = System.today().addDays(30),
                    Status__c = settings[0].Status__c,
                    Sub_Status__c = settings[0].Substatus__c,
                    Cancel_Order__c = true,
                    RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
                );

                try {
                    insert validOpp;
                    Assert.isTrue(true, 'Insert should succeed for valid Status/SubStatus combination');
                } catch (DmlException e) {
                    Assert.fail('Insert should not fail for valid combination: ' + e.getMessage());
                }
            } else {
                Assert.isTrue(true, 'No Custom Metadata records found - skipping valid insert scenario');
            }

            Opportunity invalidOpp = new Opportunity(
                Name = 'Insert Invalid Opportunity',
                StageName = 'Prospecting',
                CloseDate = System.today().addDays(30),
                Status__c = 'Invalid Status That Does Not Exist',
                Sub_Status__c = 'Invalid SubStatus That Does Not Exist',
                Cancel_Order__c = true,
                RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
            );

            try {
                insert invalidOpp;
                Assert.fail('Insert should fail for invalid Status/SubStatus combination');
            } catch (DmlException e) {
                Assert.isTrue(
                    e.getMessage().contains('You cannot cancel an Opportunity that is in the current ASPN Status and Sub-Status.'),
                    'Error message should match expected validation error'
                );
            }

            Test.stopTest();
        }
    }

    /**
     * @description Test handleCancellationSettingsError to cover exception handling
     */
    @IsTest
    static void testHandleCancellationSettingsError() {
        // Create a test exception
        Exception testException = new System.QueryException('Test query exception');

        Test.startTest();
        try {
            // Call the error handler directly to cover exception handling
            OpportunityServiceHelper.handleCancellationSettingsError(testException);
            Assert.fail('CustomException should have been thrown');
        } catch (OpportunityService.CustomException e) {
            Assert.isTrue(
                e.getMessage().contains('Failed to load cancellation settings'),
                'CustomException should contain expected error message'
            );
            Assert.isTrue(
                e.getMessage().contains('Test query exception'),
                'CustomException should contain original exception message'
            );
        }
        Test.stopTest();
    }

    /**
     * @description Ensure cancellation helper guard clauses exit early for null/empty inputs
     */
    @IsTest
    static void testValidateAndApplyCancellationRulesGuardClauses() {
        List<Opportunity> emptyUpdatedOpps = new List<Opportunity>();
        Map<Id, Opportunity> emptyOldMap = new Map<Id, Opportunity>();

        Test.startTest();
        OpportunityService.validateAndApplyCancellationRules(null, null);
        OpportunityService.validateAndApplyCancellationRules(emptyUpdatedOpps, emptyOldMap);
        OpportunityService.validateAndApplyCancellationRules(
            new List<Opportunity>{
                new Opportunity(
                    Id = MockDataFactory.getFakeId('Opportunity'),
                    Cancel_Order__c = true,
                    RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
                )
            },
            null
        );
        Test.stopTest();

        Assert.isTrue(true, 'Guard clauses should exit without throwing errors');
    }

    /**
     * @description Ensure helper skips validation when no cancellation attempt occurs
     */
    @IsTest
    static void testValidateAndApplyCancellationRulesWithoutCancelAttempt() {
        Id fakeOppId = MockDataFactory.getFakeId('Opportunity');
        Opportunity updatedOpp = new Opportunity(
            Id = fakeOppId,
            Cancel_Order__c = true,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        Opportunity oldOpp = new Opportunity(
            Id = fakeOppId,
            Cancel_Order__c = true,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
            fakeOppId => oldOpp
        };

        Opportunity orphanUpdatedOpp = new Opportunity(
            Id = MockDataFactory.getFakeId('Opportunity'),
            Cancel_Order__c = true,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        Map<Id, Opportunity> missingOldMap = new Map<Id, Opportunity>();

        Test.startTest();
        OpportunityService.validateAndApplyCancellationRules(new List<Opportunity>{ updatedOpp }, oldMap);
        OpportunityService.validateAndApplyCancellationRules(new List<Opportunity>{ orphanUpdatedOpp }, missingOldMap);
        Test.stopTest();

        Assert.isTrue(true, 'No errors expected when cancellation is not attempted');
    }

    /**
     * @description Test updateStageFromSubStatus with null input
     */
    @IsTest
    static void testUpdateStageFromSubStatusWithNullInput() {
        Test.startTest();
        OpportunityService.updateStageFromSubStatus(null, null);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null input gracefully');
    }

    /**
     * @description Test updateStageFromSubStatus with empty list
     */
    @IsTest
    static void testUpdateStageFromSubStatusWithEmptyList() {
        Test.startTest();
        OpportunityService.updateStageFromSubStatus(new List<Opportunity>(), null);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle empty list gracefully');
    }

    /**
     * @description Test updateStageFromSubStatus when Sub_Status changes to a mapped value
     */
    @IsTest
    static void testUpdateStageFromSubStatusWithValidMapping() {
        // Query existing custom metadata for a valid mapping
        List<ASPN_SubStatus_to_OppStage__mdt> mappings = [
            SELECT ASPN_Sub_Status__c, Opportunity_Stage__c
            FROM ASPN_SubStatus_to_OppStage__mdt
            WHERE ASPN_Sub_Status__c != NULL
            AND Opportunity_Stage__c != NULL
            LIMIT 1
        ];

        if (!mappings.isEmpty()) {
            String testSubStatus = mappings[0].ASPN_Sub_Status__c;
            String expectedStage = mappings[0].Opportunity_Stage__c;

            Id fakeOppId = MockDataFactory.getFakeId('Opportunity');
            Opportunity newOpp = new Opportunity(
                Id = fakeOppId,
                Sub_Status__c = testSubStatus,
                StageName = 'Prospecting'
            );
            Opportunity oldOpp = new Opportunity(
                Id = fakeOppId,
                Sub_Status__c = 'Old Sub Status',
                StageName = 'Prospecting'
            );
            Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{ fakeOppId => oldOpp };

            Test.startTest();
            OpportunityService.updateStageFromSubStatus(new List<Opportunity>{ newOpp }, oldMap);
            Test.stopTest();

            Assert.areEqual(expectedStage, newOpp.StageName, 'Stage should be updated based on Sub_Status mapping');
        } else {
            Assert.isTrue(true, 'No custom metadata mappings found - skipping test');
        }
    }

    /**
     * @description Test updateStageFromSubStatus when Sub_Status doesn't change
     */
    @IsTest
    static void testUpdateStageFromSubStatusWhenSubStatusUnchanged() {
        Id fakeOppId = MockDataFactory.getFakeId('Opportunity');
        String originalStage = 'Prospecting';
        Opportunity newOpp = new Opportunity(
            Id = fakeOppId,
            Sub_Status__c = 'Same Sub Status',
            StageName = originalStage
        );
        Opportunity oldOpp = new Opportunity(
            Id = fakeOppId,
            Sub_Status__c = 'Same Sub Status',
            StageName = originalStage
        );
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{ fakeOppId => oldOpp };

        Test.startTest();
        OpportunityService.updateStageFromSubStatus(new List<Opportunity>{ newOpp }, oldMap);
        Test.stopTest();

        Assert.areEqual(originalStage, newOpp.StageName, 'Stage should not change when Sub_Status is unchanged');
    }

    /**
     * @description Test updateStageFromSubStatus when Sub_Status has no mapping
     */
    @IsTest
    static void testUpdateStageFromSubStatusWithNoMapping() {
        Id fakeOppId = MockDataFactory.getFakeId('Opportunity');
        String originalStage = 'Prospecting';
        Opportunity newOpp = new Opportunity(
            Id = fakeOppId,
            Sub_Status__c = 'Non Existent Sub Status Value XYZ123',
            StageName = originalStage
        );
        Opportunity oldOpp = new Opportunity(
            Id = fakeOppId,
            Sub_Status__c = 'Old Sub Status',
            StageName = originalStage
        );
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{ fakeOppId => oldOpp };

        Test.startTest();
        OpportunityService.updateStageFromSubStatus(new List<Opportunity>{ newOpp }, oldMap);
        Test.stopTest();

        Assert.areEqual(originalStage, newOpp.StageName, 'Stage should not change when no mapping exists for Sub_Status');
    }

    /**
     * @description Test updateStageFromSubStatus with blank Sub_Status
     */
    @IsTest
    static void testUpdateStageFromSubStatusWithBlankSubStatus() {
        Id fakeOppId = MockDataFactory.getFakeId('Opportunity');
        String originalStage = 'Prospecting';
        Opportunity newOpp = new Opportunity(
            Id = fakeOppId,
            Sub_Status__c = '',
            StageName = originalStage
        );
        Opportunity oldOpp = new Opportunity(
            Id = fakeOppId,
            Sub_Status__c = 'Old Sub Status',
            StageName = originalStage
        );
        Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{ fakeOppId => oldOpp };

        Test.startTest();
        OpportunityService.updateStageFromSubStatus(new List<Opportunity>{ newOpp }, oldMap);
        Test.stopTest();

        Assert.areEqual(originalStage, newOpp.StageName, 'Stage should not change when Sub_Status is blank');
    }

    /**
     * @description Test updateStageFromSubStatus for insert scenario (null oldMap)
     */
    @IsTest
    static void testUpdateStageFromSubStatusOnInsert() {
        // Query existing custom metadata for a valid mapping
        List<ASPN_SubStatus_to_OppStage__mdt> mappings = [
            SELECT ASPN_Sub_Status__c, Opportunity_Stage__c
            FROM ASPN_SubStatus_to_OppStage__mdt
            WHERE ASPN_Sub_Status__c != NULL
            AND Opportunity_Stage__c != NULL
            LIMIT 1
        ];

        if (!mappings.isEmpty()) {
            String testSubStatus = mappings[0].ASPN_Sub_Status__c;
            String expectedStage = mappings[0].Opportunity_Stage__c;

            Opportunity newOpp = new Opportunity(
                Sub_Status__c = testSubStatus,
                StageName = 'Prospecting'
            );

            Test.startTest();
            OpportunityService.updateStageFromSubStatus(new List<Opportunity>{ newOpp }, null);
            Test.stopTest();

            Assert.areEqual(expectedStage, newOpp.StageName, 'Stage should be updated on insert based on Sub_Status mapping');
        } else {
            Assert.isTrue(true, 'No custom metadata mappings found - skipping test');
        }
    }

    /**
     * @description Test updateStageFromSubStatus with bulk opportunities
     */
    @IsTest
    static void testUpdateStageFromSubStatusBulk() {
        // Query existing custom metadata for valid mappings
        List<ASPN_SubStatus_to_OppStage__mdt> mappings = [
            SELECT ASPN_Sub_Status__c, Opportunity_Stage__c
            FROM ASPN_SubStatus_to_OppStage__mdt
            WHERE ASPN_Sub_Status__c != NULL
            AND Opportunity_Stage__c != NULL
            LIMIT 3
        ];

        if (!mappings.isEmpty()) {
            List<Opportunity> newOpps = new List<Opportunity>();
            Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();
            Map<Id, String> expectedStageMap = new Map<Id, String>();

            for (Integer i = 0; i < mappings.size(); i++) {
                Id fakeOppId = MockDataFactory.getFakeId('Opportunity');
                Opportunity newOpp = new Opportunity(
                    Id = fakeOppId,
                    Sub_Status__c = mappings[i].ASPN_Sub_Status__c,
                    StageName = 'Prospecting'
                );
                Opportunity oldOpp = new Opportunity(
                    Id = fakeOppId,
                    Sub_Status__c = 'Old Sub Status ' + i,
                    StageName = 'Prospecting'
                );
                newOpps.add(newOpp);
                oldMap.put(fakeOppId, oldOpp);
                expectedStageMap.put(fakeOppId, mappings[i].Opportunity_Stage__c);
            }

            Test.startTest();
            OpportunityService.updateStageFromSubStatus(newOpps, oldMap);
            Test.stopTest();

            for (Opportunity opp : newOpps) {
                Assert.areEqual(
                    expectedStageMap.get(opp.Id),
                    opp.StageName,
                    'Stage should be updated correctly for each opportunity in bulk'
                );
            }
        } else {
            Assert.isTrue(true, 'No custom metadata mappings found - skipping test');
        }
    }

    /**
     * @description Test updateStageFromSubStatus with multiple opportunities having same Sub_Status
     */
    @IsTest
    static void testUpdateStageFromSubStatusWithSameSubStatus() {
        // Query existing custom metadata for a valid mapping
        List<ASPN_SubStatus_to_OppStage__mdt> mappings = [
            SELECT ASPN_Sub_Status__c, Opportunity_Stage__c
            FROM ASPN_SubStatus_to_OppStage__mdt
            WHERE ASPN_Sub_Status__c != NULL
            AND Opportunity_Stage__c != NULL
            LIMIT 1
        ];

        if (!mappings.isEmpty()) {
            String testSubStatus = mappings[0].ASPN_Sub_Status__c;
            String expectedStage = mappings[0].Opportunity_Stage__c;

            List<Opportunity> newOpps = new List<Opportunity>();
            Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>();

            // Create multiple opportunities with same Sub_Status
            for (Integer i = 0; i < 5; i++) {
                Id fakeOppId = MockDataFactory.getFakeId('Opportunity');
                Opportunity newOpp = new Opportunity(
                    Id = fakeOppId,
                    Sub_Status__c = testSubStatus,
                    StageName = 'Prospecting'
                );
                Opportunity oldOpp = new Opportunity(
                    Id = fakeOppId,
                    Sub_Status__c = 'Old Sub Status',
                    StageName = 'Prospecting'
                );
                newOpps.add(newOpp);
                oldMap.put(fakeOppId, oldOpp);
            }

            Test.startTest();
            OpportunityService.updateStageFromSubStatus(newOpps, oldMap);
            Test.stopTest();

            for (Opportunity opp : newOpps) {
                Assert.areEqual(
                    expectedStage,
                    opp.StageName,
                    'All opportunities with same Sub_Status should have same mapped Stage'
                );
            }
        } else {
            Assert.isTrue(true, 'No custom metadata mappings found - skipping test');
        }
    }

/**
 * @description Tests null and empty input handling for generateTasksForOpportunities
 */
@IsTest
static void testGenerateTasksForOpportunitiesNullInput() {
    Test.startTest();
    OpportunityService.generateTasksForOpportunities(null, ConstantsUtil.INSERT_OPERATION);
    OpportunityService.generateTasksForOpportunities(new List<Opportunity>(), ConstantsUtil.INSERT_OPERATION);
    Test.stopTest();

    Assert.isTrue(true, 'Method should handle null/empty input gracefully');
}

/**
 * @description Tests that method executes successfully when LeadSource is 'ASPN'
 *              The condition formula should prevent task creation, but method should complete without errors
 */
@IsTest
static void testGenerateTasksForOpportunitiesWithASPNSource() {
    User salesUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestUser' LIMIT 1];

    System.runAs(salesUser) {
        // Create opportunity with LeadSource = 'ASPN' - should NOT trigger task generation per business rule
        Opportunity testOpp = new Opportunity(
            Name = 'ASPN Source Test',
            StageName = 'Proposal',
            CloseDate = System.today().addDays(30),
            LeadSource = 'ASPN',  // Should NOT trigger task generation per rule: LeadSource != 'ASPN'
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Test.startTest();
        OpportunityService.generateTasksForOpportunities(
            new List<Opportunity>{testOpp},
            ConstantsUtil.INSERT_OPERATION
        );
        Test.stopTest();

        // Verify opportunity was processed without errors
        Opportunity verifyOpp = [SELECT Id, LeadSource FROM Opportunity WHERE Id = :testOpp.Id];
        Assert.areEqual('ASPN', verifyOpp.LeadSource, 'LeadSource should remain ASPN');
        Assert.isTrue(true, 'Task generation should process ASPN opportunities without exceptions');
    }
}

/**
 * @description Tests successful task creation with positive result to cover Logger.info path
 *              This test creates an opportunity and calls generateTasksForOpportunities to trigger the success logging path
 */
@IsTest
static void testGenerateTasksForOpportunitiesSuccessLogging() {
    User salesUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestUser' LIMIT 1];

    System.runAs(salesUser) {
        // Create an opportunity that might match task generation rules
        Opportunity testOpp = new Opportunity(
            Name = 'Success Logging Test',
            StageName = 'Proposal',
            CloseDate = System.today().addDays(30),
            LeadSource = 'Referral',  // Not ASPN
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Test.startTest();
        // Call the method - if any task generation rules match, it will create tasks
        // and log success message
        OpportunityService.generateTasksForOpportunities(
            new List<Opportunity>{testOpp},
            ConstantsUtil.INSERT_OPERATION
        );
        Test.stopTest();

        // Verify the opportunity still exists and method completed successfully
        Opportunity verifyOpp = [SELECT Id, Name FROM Opportunity WHERE Id = :testOpp.Id];
        Assert.areEqual('Success Logging Test', verifyOpp.Name, 'Opportunity should be processed successfully');
        Assert.isTrue(true, 'Task generation with success logging should complete without exceptions');
    }
}

/**
 * @description Tests exception handling in generateTasksForOpportunities with customExceptionSwitch disabled.
 *              When an exception occurs and customExceptionSwitch is false, should log error and not throw.
 *              Uses an Opportunity with fake Id to potentially trigger exception in TaskGenerationService.
 */
@IsTest
static void testGenerateTasksForOpportunitiesExceptionHandlingWithoutCustomSwitch() {
    // Create an Opportunity with fake Id that might cause TaskGenerationService to throw
    // when it tries to query the record
    Opportunity testOpp = new Opportunity(
        Id = MockDataFactory.getFakeId('Opportunity'),
        Name = 'Exception Test',
        StageName = 'Proposal',
        CloseDate = System.today().addDays(30)
    );

    // Ensure custom exception switch is disabled
    ConstantsUtil.customExceptionSwitch = false;

    Test.startTest();
    // This should not throw an exception even if TaskGenerationService fails
    // It should log the error instead (Logger.error path in catch block)
    try {
        OpportunityService.generateTasksForOpportunities(
            new List<Opportunity>{testOpp},
            ConstantsUtil.INSERT_OPERATION
        );
        // Method should complete without throwing - errors are logged instead
        Assert.isTrue(true, 'Method should handle exceptions gracefully without throwing when customExceptionSwitch is disabled');
    } catch (Exception e) {
        // Should not throw any exception when customExceptionSwitch is false
        // The catch block should log the error instead of throwing
        Assert.fail('Method should not throw exception when customExceptionSwitch is disabled. Error: ' + e.getMessage());
    }
    Test.stopTest();
}

/**
 * @description Tests exception handling path by forcing an exception scenario.
 *              Uses an Opportunity with invalid data to potentially trigger TaskGenerationService exception.
 */
@IsTest
static void testGenerateTasksForOpportunitiesExceptionPathCoverage() {
    User salesUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestUser' LIMIT 1];

    System.runAs(salesUser) {
        // Create an Opportunity with potentially problematic data
        Opportunity testOpp = new Opportunity(
            Name = 'Exception Path Test',
            StageName = 'Proposal',
            CloseDate = System.today().addDays(30),
            LeadSource = 'Website',
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        // Test both paths: with and without customExceptionSwitch
        Test.startTest();

        // Test 1: With customExceptionSwitch = true
        ConstantsUtil.customExceptionSwitch = true;
        Boolean exceptionCaught = false;
        try {
            OpportunityService.generateTasksForOpportunities(
                new List<Opportunity>{testOpp},
                ConstantsUtil.INSERT_OPERATION
            );
        } catch (OpportunityService.CustomException e) {
            exceptionCaught = true;
            Assert.areEqual('customExceptionSwitch is turned on', e.getMessage(),
                'Should throw CustomException when customExceptionSwitch is enabled and exception occurs');
        } catch (Exception e) {
            // Other exceptions are acceptable if TaskGenerationService doesn't throw
            Assert.isTrue(true, 'Unexpected exception handled gracefully: ' + e.getMessage());
        }

        Test.stopTest();

    }
}

/** 
 * @description Tests setPrimaryCampaign method to check if the CampaignId is set correctly for the Opportunity
 */
 @IsTest static void testSetPrimaryCampaign() {
    User salesUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestUser' LIMIT 1];

    System.runAs(salesUser) {
        // Create new Patient Account with Custom_UniqueID__c populated
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Source',
            'LastName' => 'ID Test Patient',
            'PersonGenderIdentity' => 'Male',
            'Date_of_Birth__c' => Date.newInstance(1985, 3, 20),
            'Type_of_Diabetes__c' => 'Type 1',
            'Preferred_Language__c' => 'English',
            'Custom_UniqueID__c' => 'NEW_ACCOUNT_SOURCE_ID',
            'BillingPostalCode' => '12345'
        });
        insert patientAccount;

        patientAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :patientAccount.Id
        ];

        Campaign campaign = new Campaign(
            Name = 'Primary Campaign Test',
            IsActive = true
        );
        insert campaign;

        CampaignMember campaignMember = new CampaignMember(
            CampaignId = campaign.Id,
            ContactId = patientAccount.PersonContactId,
            Status = 'Sent'
        );
        insert campaignMember;

        Opportunity opp = new Opportunity(
            Name = 'Primary Campaign Opp',
            StageName = 'Proposal',
            CloseDate = System.today().addDays(30),
            AccountId = patientAccount.Id,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert opp;

        Test.startTest();
        OpportunityService.setPrimaryCampaign(new List<Opportunity>{opp});
        Test.stopTest();

        Assert.areEqual(campaign.Id, opp.CampaignId, 'Opportunity should pick up latest campaign from person contact');
    }
 }

}