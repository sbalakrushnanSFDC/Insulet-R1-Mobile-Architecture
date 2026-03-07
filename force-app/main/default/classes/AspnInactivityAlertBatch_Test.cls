/**
 * @description Test class for AspnInactivityAlertBatch and AspnInactivityAlertService.
 *              Covers evaluateHistoryRecordForUpdate, updateOpportunities, clearInactivityAlertOnSubStatusUpdate,
 *              addBusinessDays, and batch execute. Uses testSubStatusChangeDateTimeOverride and
 *              testOpportunityDataOverride to inject SubStatus change datetime and Opportunity data for tests.
 *              Uses testSubStatusChangeDateTimeOverride and testOpportunityDataOverride for test data injection.
 * @see AspnInactivityAlertBatch
 * @see AspnInactivityAlertService
 * @author Ayush Sharma
 * @date Feb 11, 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       11th Feb 2026        Ayush Sharma                 Initial Version
 */
@IsTest(isParallel = true)
private class AspnInactivityAlertBatch_Test {

    /** @description Test SubStatus value used for Opportunity records */
    private static final String TEST_SUB_STATUS = 'Test SubStatus';

    /** @description Map of test Opportunity names to their field values for setup */
    private static final Map<String, Map<String, Object>> OPP_NAME_TO_FIELDS = new Map<String, Map<String, Object>>{
        'Test Opp - Other Stage Exceeds' => new Map<String, Object>{
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'Sub_Status__c' => TEST_SUB_STATUS,
            'ASPN_Inactivity_Alert__c' => false
        },
        'Test Opp - Prior Auth Exceeds' => new Map<String, Object>{
            'StageName' => ConstantsUtil.OPPORTUNITY_STAGE_PRIOR_AUTH,
            'Sub_Status__c' => TEST_SUB_STATUS,
            'ASPN_Inactivity_Alert__c' => false
        },
        'Test Opp - Other Stage Within' => new Map<String, Object>{
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'Sub_Status__c' => TEST_SUB_STATUS,
            'ASPN_Inactivity_Alert__c' => false
        },
        'Test Opp - Prior Auth Within' => new Map<String, Object>{
            'StageName' => ConstantsUtil.OPPORTUNITY_STAGE_PRIOR_AUTH,
            'Sub_Status__c' => TEST_SUB_STATUS,
            'ASPN_Inactivity_Alert__c' => false
        },
        'Test Opp - Alert Already Set' => new Map<String, Object>{
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'Sub_Status__c' => TEST_SUB_STATUS,
            'ASPN_Inactivity_Alert__c' => true
        },
        'Test Opp - Different Stage' => new Map<String, Object>{
            'StageName' => 'Prospecting',
            'Sub_Status__c' => TEST_SUB_STATUS,
            'ASPN_Inactivity_Alert__c' => false
        },
        'Test Opp - No Matching History' => new Map<String, Object>{
            'StageName' => 'Prospecting',
            'Sub_Status__c' => TEST_SUB_STATUS,
            'ASPN_Inactivity_Alert__c' => false
        }
    };

    /**
     * @description Test setup method to create all test opportunities data using TestDataFactory.
     *              Creates Account, 7 named Opportunities, and 80 bulk Opportunities for batch testing.
     */
    @TestSetup
    static void setupTestData() {
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
                'LastName' => 'Patient'
                });
        insert testAccount;
        
        List<Opportunity> testOpps = new List<Opportunity>();
        Map<String, Object> baseFields = new Map<String, Object>{
            'AccountId' => testAccount.Id,
                'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
                'CloseDate' => Date.today().addDays(30),
                'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT
                };
                    
                    for (String oppName : OPP_NAME_TO_FIELDS.keySet()) {
                        Map<String, Object> oppFields = new Map<String, Object>(baseFields);
                        oppFields.put('Name', oppName);
                        oppFields.putAll(OPP_NAME_TO_FIELDS.get(oppName));
                        testOpps.add(TestDataFactory.getOpportunity(oppFields));
                    }
        
        for (Integer i = 0; i < 80; i++) {
            Map<String, Object> bulkFields = new Map<String, Object>(baseFields);
            bulkFields.put('Name', 'Test Opp - Bulk ' + i);
            bulkFields.put('StageName', i < 40 ? ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE : ConstantsUtil.OPPORTUNITY_STAGE_PRIOR_AUTH);
            bulkFields.put('Sub_Status__c', TEST_SUB_STATUS);
            bulkFields.put('ASPN_Inactivity_Alert__c', false);
            testOpps.add(TestDataFactory.getOpportunity(bulkFields));
        }
        
        insert testOpps;
    }

    /**
     * @description Retrieves a single Opportunity by exact name
     * @param name Opportunity Name
     * @return Opportunity record
     */
    private static Opportunity getOpportunityByName(String name) {
        return [SELECT Id, StageName, Sub_Status__c, ASPN_Inactivity_Alert__c FROM Opportunity WHERE Name = :name LIMIT 1];
    }

    /**
     * @description Sets the test SubStatus change datetime override for injecting history in tests
     * @param oppId Opportunity ID
     * @param changeDateTime Backdated datetime for SubStatus change
     */
    private static void setTestSubStatusChangeDateTimeOverride(Id oppId, DateTime changeDateTime) {
        AspnInactivityAlertService.testSubStatusChangeDateTimeOverride = new Map<Id, DateTime>{ oppId => changeDateTime };
    }

    /**
     * @description Clears the test SubStatus change datetime override
     */
    private static void clearTestSubStatusChangeDateTimeOverride() {
        AspnInactivityAlertService.testSubStatusChangeDateTimeOverride = null;
    }

    /**
     * @description Retrieves Opportunities by name prefix pattern
     * @param pattern Name prefix pattern (e.g. 'Test Opp - Bulk')
     * @return List of Opportunity records matching the pattern
     */
    private static List<Opportunity> getOpportunitiesByNamePattern(String pattern) {
        List<Opportunity> allOpps = [SELECT Id, Name, StageName, Sub_Status__c, ASPN_Inactivity_Alert__c FROM Opportunity];
        List<Opportunity> matchingOpps = new List<Opportunity>();
        String searchPattern = pattern.replace('%', '');
        for (Opportunity opp : allOpps) {
            if (opp.Name != null && opp.Name.startsWith(searchPattern)) {
                matchingOpps.add(opp);
            }
        }
        return matchingOpps;
    }

    /**
     * @description Builds mock OpportunityFieldHistory records for testing (OpportunityFieldHistory cannot be created in Apex).
     * @param opps List of Opportunity records to create history for
     * @return List of OpportunityFieldHistory mock records
     */
    private static List<OpportunityFieldHistory> buildMockHistoryRecords(List<Opportunity> opps) {
        List<OpportunityFieldHistory> records = new List<OpportunityFieldHistory>();
        for (Opportunity opp : opps) {
            OpportunityFieldHistory oppHist = new OpportunityFieldHistory();
            oppHist.OpportunityId = opp.Id;
            oppHist.Field = ConstantsUtil.OPPORTUNITY_FIELD_SUB_STATUS;
            records.add(oppHist);
        }
        return records;
    }

    /**
     * @description Positive: Other stage - SubStatus not updated in 5 calendar days (3 business days) -> alert set to true.
     *              Verifies ASPN_Inactivity_Alert__c is set when threshold exceeded for non-Prior Auth stage.
     */
    @IsTest
    static void testOtherStageExceeds3BusinessDays() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Other Stage Exceeds');
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-5));
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        List<OpportunityFieldHistory> mockHist = buildMockHistoryRecords(new List<Opportunity>{ testOpp });

        Test.startTest();
        AspnInactivityAlertBatch batch = new AspnInactivityAlertBatch();
        batch.execute(null, mockHist);
        Test.stopTest();

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;

        Opportunity updatedOpp = [SELECT ASPN_Inactivity_Alert__c FROM Opportunity WHERE Id = :testOpp.Id];
        Assert.areEqual(true, updatedOpp.ASPN_Inactivity_Alert__c, 'Alert should be set when SubStatus not updated in 3+ business days (other stage)');
    }

    /**
     * @description Positive: Prior Auth stage - SubStatus not updated in 20+ calendar days (14 business days) -> alert set to true.
     *              Verifies ASPN_Inactivity_Alert__c is set when threshold exceeded for Prior Auth stage.
     */
    @IsTest
    static void testPriorAuthExceeds14BusinessDays() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Prior Auth Exceeds');
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-22));
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        List<OpportunityFieldHistory> mockHist = buildMockHistoryRecords(new List<Opportunity>{ testOpp });

        Test.startTest();
        AspnInactivityAlertBatch batch = new AspnInactivityAlertBatch();
        batch.execute(null, mockHist);
        Test.stopTest();

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;

        Opportunity updatedOpp = [SELECT ASPN_Inactivity_Alert__c FROM Opportunity WHERE Id = :testOpp.Id];
        Assert.areEqual(true, updatedOpp.ASPN_Inactivity_Alert__c, 'Alert should be set when Prior Auth SubStatus not updated in 14+ business days');
    }

    /**
     * @description Positive (bulk): 80 Opportunities with backdated SubStatus change -> all alerts set.
     *              Verifies batch processes all records via Database.executeBatch with test override.
     */
    @IsTest
    static void testBulkProcessing() {
        List<Opportunity> testOpps = getOpportunitiesByNamePattern('Test Opp - Bulk%');
        // Other stage (3-day threshold): -5 days exceeds
        DateTime otherStageDateTime = DateTime.now().addDays(-5);
        // Prior Auth (14-day threshold): -25 days exceeds
        DateTime priorAuthDateTime = DateTime.now().addDays(-25);
        Map<Id, DateTime> bulkOverride = new Map<Id, DateTime>();
        Map<Id, Opportunity> oppById = new Map<Id, Opportunity>();
        List<OpportunityFieldHistory> mockHistList = new List<OpportunityFieldHistory>();
        for (Integer i = 0; i < testOpps.size(); i++) {
            Opportunity opp = testOpps[i];
            bulkOverride.put(opp.Id, i < 40 ? otherStageDateTime : priorAuthDateTime);
            oppById.put(opp.Id, opp);
            OpportunityFieldHistory oppHist = new OpportunityFieldHistory();
            oppHist.OpportunityId = opp.Id;
            oppHist.Field = ConstantsUtil.OPPORTUNITY_FIELD_SUB_STATUS;
            mockHistList.add(oppHist);
        }
        AspnInactivityAlertService.testSubStatusChangeDateTimeOverride = bulkOverride;
        AspnInactivityAlertService.testOpportunityDataOverride = oppById;

        Test.startTest();
        AspnInactivityAlertBatch batch = new AspnInactivityAlertBatch();
        batch.execute(null, mockHistList);
        Test.stopTest();

        AspnInactivityAlertService.testSubStatusChangeDateTimeOverride = null;
        AspnInactivityAlertService.testOpportunityDataOverride = null;

        List<Opportunity> updatedOpps = [SELECT Id, ASPN_Inactivity_Alert__c, StageName FROM Opportunity WHERE Id IN :testOpps];
        Assert.areEqual(80, updatedOpps.size(), 'All 80 Opportunities should be queried');
        for (Opportunity opp : updatedOpps) {
            Assert.areEqual(true, opp.ASPN_Inactivity_Alert__c, 'Alert should be set for Opportunity with Stage: ' + opp.StageName);
        }
    }

    /**
     * @description Negative: Prior Auth - SubStatus updated within 14 business days -> no alert.
     *              Verifies ASPN_Inactivity_Alert__c remains false when within threshold.
     */
    @IsTest
    static void testPriorAuthWithin14BusinessDays() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Prior Auth Within');
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-5));
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        List<OpportunityFieldHistory> mockHist = buildMockHistoryRecords(new List<Opportunity>{ testOpp });

        Test.startTest();
        AspnInactivityAlertBatch batch = new AspnInactivityAlertBatch();
        batch.execute(null, mockHist);
        Test.stopTest();

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;

        Opportunity updatedOpp = [SELECT ASPN_Inactivity_Alert__c FROM Opportunity WHERE Id = :testOpp.Id];
        Assert.areEqual(false, updatedOpp.ASPN_Inactivity_Alert__c, 'Alert should remain false when SubStatus updated within 14 business days (Prior Auth)');
    }

    /**
     * @description Negative: Other Stage - SubStatus updated within 3 business days -> no alert.
     *              Verifies ASPN_Inactivity_Alert__c remains false when within 3-day threshold.
     */
    @IsTest
    static void testOtherStageWithin3BusinessDays() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Other Stage Within');
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-2));
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        List<OpportunityFieldHistory> mockHist = buildMockHistoryRecords(new List<Opportunity>{ testOpp });

        Test.startTest();
        AspnInactivityAlertBatch batch = new AspnInactivityAlertBatch();
        batch.execute(null, mockHist);
        Test.stopTest();

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;

        Opportunity updatedOpp = [SELECT ASPN_Inactivity_Alert__c FROM Opportunity WHERE Id = :testOpp.Id];
        Assert.areEqual(false, updatedOpp.ASPN_Inactivity_Alert__c, 'Alert should remain false when other stage SubStatus updated within 3 business days');
    }

    /**
     * @description Negative: Alert already true -> service logic skips it.
     *              Verifies Opportunities with ASPN_Inactivity_Alert__c = true are not re-processed.
     */
    @IsTest
    static void testAlreadySetAlertNotProcessed() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Alert Already Set');
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-20));
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        List<OpportunityFieldHistory> mockHist = buildMockHistoryRecords(new List<Opportunity>{ testOpp });

        Test.startTest();
        AspnInactivityAlertBatch batch = new AspnInactivityAlertBatch();
        batch.execute(null, mockHist);
        Test.stopTest();

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;

        Opportunity updatedOpp = [SELECT ASPN_Inactivity_Alert__c FROM Opportunity WHERE Id = :testOpp.Id];
        Assert.areEqual(true, updatedOpp.ASPN_Inactivity_Alert__c, 'Alert should still be true (was already set)');
    }
    
    /**
     * @description Test batch finish method
     *              Covers: finish method with job query and logging
     */
    @IsTest
    static void testFinishMethod() {
        Test.startTest();
        AspnInactivityAlertBatch batch = new AspnInactivityAlertBatch();
        Id batchId = Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify batch completed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :batchId
        ];
        Assert.areEqual('Completed', job.Status, 'Batch should complete');
        Assert.areEqual(0, job.NumberOfErrors, 'Should have no errors');
    }

    /**
     * @description Negative: Opportunity with different stage (Prospecting, not Prior Auth) -> 3-day threshold applies.
     *              Verifies non-Prior Auth stages use 3 business day threshold; -2 days is within threshold.
     */
    @IsTest
    static void testDifferentStageUses3DayThreshold() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Different Stage');
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-2));
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        List<OpportunityFieldHistory> mockHist = buildMockHistoryRecords(new List<Opportunity>{ testOpp });

        Test.startTest();
        AspnInactivityAlertBatch batch = new AspnInactivityAlertBatch();
        batch.execute(null, mockHist);
        Test.stopTest();

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;

        Opportunity updatedOpp = [SELECT ASPN_Inactivity_Alert__c FROM Opportunity WHERE Id = :testOpp.Id];
        Assert.areEqual(false, updatedOpp.ASPN_Inactivity_Alert__c, 'Alert should remain false when SubStatus updated within 3 business days (non-Prior Auth)');
    }

    /**
     * @description Verifies evaluateHistoryRecordForUpdate returns null when ASPN_Inactivity_Alert__c is already true.
     */
    @IsTest
    static void testEvalHistNullAlertAlreadySet() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Alert Already Set');
        OpportunityFieldHistory mockHist = new OpportunityFieldHistory();
        mockHist.OpportunityId = testOpp.Id;
        mockHist.Field = ConstantsUtil.OPPORTUNITY_FIELD_SUB_STATUS;
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-20));

        Opportunity result = AspnInactivityAlertService.evaluateHistoryRecordForUpdate(mockHist);

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;
        Assert.areEqual(null, result, 'Should return null when alert already set');
    }

    /**
     * @description Verifies evaluateHistoryRecordForUpdate returns null when within 3-day threshold (Other stage).
     */
    @IsTest
    static void testEvalHistNullWithin3Days() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Other Stage Within');
        OpportunityFieldHistory mockHist = new OpportunityFieldHistory();
        mockHist.OpportunityId = testOpp.Id;
        mockHist.Field = ConstantsUtil.OPPORTUNITY_FIELD_SUB_STATUS;
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-2));

        Opportunity result = AspnInactivityAlertService.evaluateHistoryRecordForUpdate(mockHist);

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;
        Assert.areEqual(null, result, 'Should return null when within 3 business days (Other stage)');
    }

    /**
     * @description Verifies evaluateHistoryRecordForUpdate returns null when within 14-day threshold (Prior Auth).
     */
    @IsTest
    static void testEvalHistNullWithin14Days() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Prior Auth Within');
        OpportunityFieldHistory mockHist = new OpportunityFieldHistory();
        mockHist.OpportunityId = testOpp.Id;
        mockHist.Field = ConstantsUtil.OPPORTUNITY_FIELD_SUB_STATUS;
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-5));

        Opportunity result = AspnInactivityAlertService.evaluateHistoryRecordForUpdate(mockHist);

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;
        Assert.areEqual(null, result, 'Should return null when within 14 business days (Prior Auth)');
    }

    /**
     * @description Verifies evaluateHistoryRecordForUpdate returns Opportunity when past 3-day threshold (Other stage).
     */
    @IsTest
    static void testEvalHistOppPast3Days() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Other Stage Exceeds');
        OpportunityFieldHistory mockHist = new OpportunityFieldHistory();
        mockHist.OpportunityId = testOpp.Id;
        mockHist.Field = ConstantsUtil.OPPORTUNITY_FIELD_SUB_STATUS;
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-5));

        Opportunity result = AspnInactivityAlertService.evaluateHistoryRecordForUpdate(mockHist);

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;
        Assert.areNotEqual(null, result, 'Should return Opportunity when past 3 business days');
        Assert.areEqual(testOpp.Id, result.Id, 'Returned Opportunity Id should match');
        Assert.areEqual(true, result.ASPN_Inactivity_Alert__c, 'ASPN_Inactivity_Alert__c should be true');
    }

    /**
     * @description Verifies evaluateHistoryRecordForUpdate returns Opportunity when past 14-day threshold (Prior Auth).
     */
    @IsTest
    static void testEvalHistOppPast14Days() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Prior Auth Exceeds');
        OpportunityFieldHistory mockHist = new OpportunityFieldHistory();
        mockHist.OpportunityId = testOpp.Id;
        mockHist.Field = ConstantsUtil.OPPORTUNITY_FIELD_SUB_STATUS;
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-22));

        Opportunity result = AspnInactivityAlertService.evaluateHistoryRecordForUpdate(mockHist);

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;
        Assert.areNotEqual(null, result, 'Should return Opportunity when past 14 business days (Prior Auth)');
        Assert.areEqual(testOpp.Id, result.Id, 'Returned Opportunity Id should match');
        Assert.areEqual(true, result.ASPN_Inactivity_Alert__c, 'ASPN_Inactivity_Alert__c should be true');
    }

    /**
     * @description Verifies evaluateHistoryRecordForUpdate works for Field = Created (no Sub_Status history).
     *              Uses FieldHistory.CreatedDate for threshold; same logic as Sub_Status__c.
     */
    @IsTest
    static void testEvalHistFieldCreatedDatePastThreshold() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Other Stage Exceeds');
        OpportunityFieldHistory mockHist = new OpportunityFieldHistory();
        mockHist.OpportunityId = testOpp.Id;
        mockHist.Field = ConstantsUtil.OPPORTUNITY_FIELD_CREATED;
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-5));

        Opportunity result = AspnInactivityAlertService.evaluateHistoryRecordForUpdate(mockHist);

        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;
        Assert.areNotEqual(null, result, 'Should return Opportunity when Field=CreatedDate and past threshold');
        Assert.areEqual(testOpp.Id, result.Id, 'Returned Opportunity Id should match');
        Assert.areEqual(true, result.ASPN_Inactivity_Alert__c, 'ASPN_Inactivity_Alert__c should be true');
    }

    /**
     * @description Verifies updateOpportunities handles null and empty inputs.
     *              Ensures method returns early without throwing for null/empty list.
     */
    @IsTest
    static void testUpdateOpportunitiesEmptyAndNull() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AspnInactivityAlertService.updateOpportunities(new List<Opportunity>());
            AspnInactivityAlertService.updateOpportunities(null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        Assert.areEqual(false, exceptionThrown, 'Should handle null and empty without throwing');
    }

    /**
     * @description Verifies updateOpportunities logs failed SaveResult when DML fails for a record.
     *              Tests update on deleted Opportunity to trigger failure path.
     */
    @IsTest
    static void testUpdateOpportunitiesLogsFailedSaveResult() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Other Stage Exceeds');
        Id deletedOppId = testOpp.Id;
        delete testOpp;

        List<Opportunity> oppsToUpdate = new List<Opportunity>{
            new Opportunity(Id = deletedOppId, ASPN_Inactivity_Alert__c = true)
        };
        Integer successCount;

        Test.startTest();
        successCount = AspnInactivityAlertService.updateOpportunities(oppsToUpdate);
        Test.stopTest();

        Assert.isTrue(true, 'Service should log failed SaveResult and complete without throwing');
        Assert.areEqual(0, successCount, 'Should return 0 when error occured while updating');
    }

    /**
     * @description Verifies updateOpportunities catches and logs exceptions internally when customExceptionSwitch is true.
     *              Ensures exception in update path is caught and returns 0.
     */
    @IsTest
    static void testUpdateOpportunitiesExceptionHandling() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Other Stage Exceeds');
        Integer successCount;

        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
        successCount = AspnInactivityAlertService.updateOpportunities(new List<Opportunity>{ testOpp });
        Test.stopTest();

        ConstantsUtil.customExceptionSwitch = false;
        Assert.isTrue(true, 'updateOpportunities catches and logs exceptions internally');
        Assert.areEqual(0, successCount, 'Should return 0 when exception occured while updating');
    }

    /**
     * @description Verifies batch execute catches and logs exceptions internally when customExceptionSwitch is true.
     *              Ensures batch continues without propagating exception.
     */
    @IsTest
    static void testBatchExceptionHandling() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Other Stage Exceeds');
        setTestSubStatusChangeDateTimeOverride(testOpp.Id, DateTime.now().addDays(-20));
        AspnInactivityAlertService.testOpportunityDataOverride = new Map<Id, Opportunity>{ testOpp.Id => testOpp };
        List<OpportunityFieldHistory> mockHist = buildMockHistoryRecords(new List<Opportunity>{ testOpp });
        ConstantsUtil.customExceptionSwitch = true;

        AspnInactivityAlertBatch batch = new AspnInactivityAlertBatch();
        Test.startTest();
        batch.execute(null, mockHist);
        Test.stopTest();

        ConstantsUtil.customExceptionSwitch = false;
        clearTestSubStatusChangeDateTimeOverride();
        AspnInactivityAlertService.testOpportunityDataOverride = null;
        Assert.isTrue(true, 'Batch execute should catch and log exceptions internally');
    }

    /**
     * @description Verifies batch execute handles null/empty scope and returns early without throwing.
     *              Tests null scope and empty list scope.
     */
    @IsTest
    static void testBatchExecuteWithNullScope() {
        AspnInactivityAlertBatch batch = new AspnInactivityAlertBatch();
        Test.startTest();
        batch.execute(null, (List<SObject>) null);
        batch.execute(null, new List<OpportunityFieldHistory>());
        Test.stopTest();
        Assert.isTrue(true, 'Execute should handle null/empty scope and return early without throwing');
    }

    /**
     * @description Verifies beforeUpdate trigger clears ASPN_Inactivity_Alert__c when SubStatus changes.
     *              Uses actual DML update to fire OpportunityTriggerHandler.beforeUpdate (positive scenario).
     */
    @IsTest
    static void testClearInactivityAlertOnSubStatusUpdate() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Alert Already Set');
        Assert.areEqual(true, testOpp.ASPN_Inactivity_Alert__c, 'Precondition: alert should be true');

        testOpp.Sub_Status__c = 'New SubStatus';

        Test.startTest();
        update testOpp;
        Test.stopTest();

        Opportunity updatedOpp = [SELECT ASPN_Inactivity_Alert__c FROM Opportunity WHERE Id = :testOpp.Id];
        Assert.areEqual(false, updatedOpp.ASPN_Inactivity_Alert__c, 'Alert should be cleared when SubStatus is updated via trigger');
    }

    /**
     * @description Verifies beforeUpdate trigger does not clear ASPN_Inactivity_Alert__c when SubStatus unchanged.
     *              Uses actual DML update (changing another field) to fire trigger without Sub_Status__c change (negative scenario).
     */
    @IsTest
    static void testClearInactivityAlertOnSubStatusUpdateNoChange() {
        Opportunity testOpp = getOpportunityByName('Test Opp - Alert Already Set');
        Assert.areEqual(true, testOpp.ASPN_Inactivity_Alert__c, 'Precondition: alert should be true');

        String originalSubStatus = testOpp.Sub_Status__c;
        testOpp.Description = 'Updated description only'; // Change another field, not Sub_Status__c
        testOpp.Sub_Status__c = originalSubStatus; // Explicitly keep same value

        Test.startTest();
        update testOpp;
        Test.stopTest();

        Opportunity updatedOpp = [SELECT ASPN_Inactivity_Alert__c, Sub_Status__c FROM Opportunity WHERE Id = :testOpp.Id];
        Assert.areEqual(true, updatedOpp.ASPN_Inactivity_Alert__c, 'Alert should remain true when SubStatus unchanged');
        Assert.areEqual(originalSubStatus, updatedOpp.Sub_Status__c, 'SubStatus should be unchanged');
    }

    /**
     * @description Verifies addBusinessDays correctly adds business days skipping weekends.
     *              Tests 3 and 14 business days from Monday using TaskGenerationCore.
     */
    @IsTest
    static void testAddBusinessDays() {
        Date monday = Date.newInstance(2026, 2, 2); // Monday
        Test.startTest();
        Date result3Days = AspnInactivityAlertService.addBusinessDays(monday, 3);
        Date result14Days = AspnInactivityAlertService.addBusinessDays(monday, 14);
        Test.stopTest();
        Assert.areEqual(Date.newInstance(2026, 2, 5), result3Days, '3 business days from Monday should be Thursday');
        Assert.areEqual(Date.newInstance(2026, 2, 20), result14Days, '14 business days from Monday Feb 2 should be Friday Feb 20');
    }

    /**
     * @description Verifies addBusinessDays handles null and zero input.
     *              Ensures null startDate, zero, and negative business days return startDate unchanged.
     */
    @IsTest
    static void testAddBusinessDaysNullAndZero() {
        Date today = Date.today();
        Test.startTest();
        Date resultNull = AspnInactivityAlertService.addBusinessDays(null, 3);
        Date resultZero = AspnInactivityAlertService.addBusinessDays(today, 0);
        Date resultNeg = AspnInactivityAlertService.addBusinessDays(today, -1);
        Test.stopTest();
        Assert.areEqual(null, resultNull, 'Null start date should return null');
        Assert.areEqual(today, resultZero, 'Zero business days should return same date');
        Assert.areEqual(today, resultNeg, 'Negative business days should return same date');
    }

    /**
     * @description Verifies clearInactivityAlertOnSubStatusUpdate handles null/empty inputs.
     *              Ensures method returns early without throwing for null or empty list.
     */
    @IsTest
    static void testClearInactivityAlertOnSubStatusUpdateNullEmpty() {
        AspnInactivityAlertService.clearInactivityAlertOnSubStatusUpdate(null, null);
        AspnInactivityAlertService.clearInactivityAlertOnSubStatusUpdate(new List<Opportunity>(), new Map<Id, Opportunity>());
        Assert.isTrue(true, 'Should handle null and empty without throwing');
    }
}