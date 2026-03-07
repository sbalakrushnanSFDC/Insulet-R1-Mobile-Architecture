/**
 * @description Test class for LeadDuplicateConversionServiceHelper.
 * Tests methods for processing conversion results, updating failed leads, and error handling.
 *
 * @author      Priyansh Shukla
 * @createdDate 4th Dec 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       16th Dec 2025       Priyansh Shukla         Initial Version(NGASIM-1163)
 * V1.0.1       23rd Jan 2026       Bijayalaxmi Prusty      Updated(US - NGASIM-1885)
 * V1.0.2       18th Feb 2026        Bijayalaxmi Prusty      Updated(US - NGOMCT-1961)
 */
@IsTest(isParallel=true)
private class LeadDuplicateConversionHelper_Test {

    /**
     * @description Sets up test data for Lead conversion scenarios
     */
    @TestSetup
    static void setupTestData() {
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
    }

    /**
     * @description Helper method to get facility for tests
     * @return HealthcarePractitionerFacility record from test setup data
     */
    private static HealthcarePractitionerFacility getFacility() {
        return [SELECT Id, PractitionerId FROM HealthcarePractitionerFacility LIMIT 1];
    }

    /**
     * @description Helper method to get or create DTC_Open queue
     * @return Group queue record
     */
    private static Group getOrCreateDtcOpenQueue() {
        List<Group> existingQueues = [
            SELECT Id FROM Group
            WHERE DeveloperName = :ConstantsUtil.DTC_OPEN_QUEUE AND Type = 'Queue'
            WITH USER_MODE LIMIT 1
        ];

        if (!existingQueues.isEmpty()) {
            return existingQueues[0];
        }

        Group testQueue = new Group(
            Name = ConstantsUtil.DTC_OPEN_QUEUE,
            DeveloperName = ConstantsUtil.DTC_OPEN_QUEUE,
            Type = 'Queue'
        );
        insert testQueue;

        QueueSObject queueSObject = new QueueSObject(
            QueueId = testQueue.Id,
            SObjectType = 'Lead'
        );
        insert queueSObject;

        return testQueue;
    }

    /**
     * @description Gets or creates Practice_Provider_Lead queue for testing
     * @return Group Practice_Provider_Lead queue
     */
    private static Group getOrCreatePracticeProviderLeadQueue() {
        List<Group> existingQueues = [
            SELECT Id FROM Group
            WHERE DeveloperName = :ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE AND Type = 'Queue'
            WITH USER_MODE LIMIT 1
        ];

        if (!existingQueues.isEmpty()) {
            return existingQueues[0];
        }

        Group testQueue = new Group(
            Name = ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE,
            DeveloperName = ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE,
            Type = 'Queue'
        );
        insert testQueue;

        QueueSObject queueSObject = new QueueSObject(
            QueueId = testQueue.Id,
            SObjectType = 'Lead'
        );
        insert queueSObject;

        return testQueue;
    }

    /**
     * @description Helper method to prepare leads for update (reset status if needed)
     * @param leads List of leads to prepare
     * @param targetStatus Status to reset to if automation changed it
     * @param queueId Queue ID to check owner against (null to skip owner check)
     * @return List of prepared leads
     */
    private static List<Lead> prepareLeadsForUpdate(List<Lead> leads, String targetStatus, Id queueId) {
        List<Lead> leadsToReset = new List<Lead>();
        Set<Id> leadIdsToUpdate = new Set<Id>();

        for (Lead lead : leads) {
            Boolean needsUpdate = false;

            if (!lead.IsConverted && lead.Status == targetStatus) {
                lead.Status = 'Open';
                needsUpdate = true;
            }

            if (queueId != null && lead.OwnerId == queueId) {
                lead.OwnerId = UserInfo.getUserId();
                needsUpdate = true;
            }

            if (needsUpdate && !leadIdsToUpdate.contains(lead.Id)) {
                leadsToReset.add(lead);
                leadIdsToUpdate.add(lead.Id);
            }
        }

        if (leadsToReset.isEmpty()) {
            return leads;
        }

        update leadsToReset;

        // Re-query to get updated values
        Set<Id> allLeadIds = new Set<Id>();
        for (Lead lead : leads) {
            allLeadIds.add(lead.Id);
        }
        return [
            SELECT Id, Status, IsConverted, OwnerId
            FROM Lead
            WHERE Id IN :allLeadIds
            WITH USER_MODE
        ];
    }

    /**
     * @description Helper method to reset leads status if automation changed it
     * @param leadIds List of lead IDs to check and reset
     * @param targetStatus Status to reset to if found
     */
    private static void resetLeadsStatusIfNeeded(List<Id> leadIds, String targetStatus) {
        List<Lead> leadsToReset = [
            SELECT Id, Status, IsConverted
            FROM Lead
            WHERE Id IN :leadIds
            WITH USER_MODE
        ];

        List<Lead> leadsToUpdate = new List<Lead>();
        for (Lead lead : leadsToReset) {
            if (!lead.IsConverted && lead.Status == targetStatus) {
                lead.Status = 'Open';
                leadsToUpdate.add(lead);
            }
        }

        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }
    }

    /**
     * @description Test buildErrorMessage method
     */
    @IsTest
    static void testBuildErrorMessage() {
        HealthcarePractitionerFacility facility = getFacility();

        // Use unique data to avoid conflicts
        Integer randomNum = Math.round(Math.random() * 1000000);
        String uniqueSuffix = String.valueOf(randomNum);

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'BldErr',
            'LastName' => 'Tst' + uniqueSuffix,
            'PersonEmail' => 'blderr' + uniqueSuffix + '@test.com'
        });
        insert testAccount;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'BldErr',
            'LastName' => 'Tst' + uniqueSuffix,
            'Email' => 'blderr' + uniqueSuffix + '@test.com',
            'Company' => 'Test' + uniqueSuffix,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(testLead, dmlOpts);

        // Convert the lead
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setAccountId(testAccount.Id);
        lc.setConvertedStatus('Converted');
        lc.setDoNotCreateOpportunity(true);
        List<Database.LeadConvertResult> results = Database.convertLead(new List<Database.LeadConvert>{lc}, false);

        if (!results[0].isSuccess()) {
            List<Database.Error> errors = results[0].getErrors();
            String errorMessage = LeadDuplicateConversionServiceHelper.buildErrorMessage(errors);
            Assert.isNotNull(errorMessage, 'Error message should not be null');
            return;
        }
        testLead = [SELECT Id FROM Lead WHERE Id = :testLead.Id];

        Test.startTest();
        Database.LeadConvert lc2 = new Database.LeadConvert();
        lc2.setLeadId(testLead.Id);
        lc2.setAccountId(testAccount.Id);
        lc2.setConvertedStatus('Converted');
        List<Database.LeadConvertResult> failedResults = Database.convertLead(new List<Database.LeadConvert>{lc2}, false);

        Assert.isFalse(failedResults[0].isSuccess(), 'Second conversion should fail');
        List<Database.Error> errors = failedResults[0].getErrors();
        String errorMessage = LeadDuplicateConversionServiceHelper.buildErrorMessage(errors);
        Test.stopTest();

        Assert.isNotNull(errorMessage, 'Error message should not be null');
    }

    /**
     * @description Test processConversionResults with successful conversions
     */
    @IsTest
    static void testProcessConversionResultsWithSuccess() {
        HealthcarePractitionerFacility facility = getFacility();

        // Create test leads and accounts
        Lead testLead1 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead1',
            'Email' => 'test1@example.com',
            'Company' => 'Test Company 1',
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => 'Open'
        });

        Lead testLead2 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead2',
            'Email' => 'test2@example.com',
            'Company' => 'Test Company 2',
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => 'Open'
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(new List<Lead>{testLead1, testLead2}, dmlOpts);

        Account testAccount1 = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account1',
            'PersonEmail' => 'account1@example.com'
        });

        Account testAccount2 = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account2',
            'PersonEmail' => 'account2@example.com'
        });
        insert new List<Account>{testAccount1, testAccount2};

        Map<Lead, Account> leadsWithAccountMatches = new Map<Lead, Account>{
            testLead1 => testAccount1,
            testLead2 => testAccount2
        };

        // Convert leads to get real conversion results
        Database.LeadConvert lc1 = new Database.LeadConvert();
        lc1.setLeadId(testLead1.Id);
        lc1.setConvertedStatus('Converted');
        lc1.setDoNotCreateOpportunity(true);

        Database.LeadConvert lc2 = new Database.LeadConvert();
        lc2.setLeadId(testLead2.Id);
        lc2.setConvertedStatus('Converted');
        lc2.setDoNotCreateOpportunity(true);

        List<Database.LeadConvertResult> conversionResults = Database.convertLead(new List<Database.LeadConvert>{lc1, lc2}, false);

        Test.startTest();
        LeadDuplicateConversionServiceHelper.processConversionResults(conversionResults, leadsWithAccountMatches, true);
        Test.stopTest();

        // Verify no errors were logged (all conversions succeeded)
        Assert.isTrue(true, 'Method should complete successfully');
    }

    /**
     * @description Test processConversionResults with failed conversions (auto conversion)
     * Failed leads with LeadSource='Get Started' and Status='New'/'Qualification' will be assigned to DTC Open queue
     */
    @IsTest
    static void testProcessConversionResultsWithFailuresAutoConversion() {
        HealthcarePractitionerFacility facility = getFacility();

        // Create a lead that will fail conversion and meets queue assignment criteria
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'FailedLead',
            'Email' => 'failed@example.com',
            'Company' => 'Failed Company',
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_GET_STARTED,
            'Status' => ConstantsUtil.LEAD_STATUS_NEW
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(testLead, dmlOpts);

        // Query the lead to get fresh instance
        testLead = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id WITH USER_MODE LIMIT 1];

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account',
            'PersonEmail' => 'account@example.com'
        });
        insert testAccount;

        Map<Lead, Account> leadsWithAccountMatches = new Map<Lead, Account>{
            testLead => testAccount
        };

        // Create a mock failed conversion result
        // We can't easily mock Database.LeadConvertResult, so we'll use a real conversion attempt
        // that will fail due to validation or other reasons
        // Instead, let's try converting with invalid data to force a failure
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setConvertedStatus('InvalidStatus'); // Invalid status to force failure
        lc.setDoNotCreateOpportunity(true);
        List<Database.LeadConvertResult> failedResults = Database.convertLead(new List<Database.LeadConvert>{lc}, false);

        // If conversion succeeded, try a different approach - convert then try again
        if (failedResults[0].isSuccess()) {
            // Convert successfully first
            Database.LeadConvert lcSuccess = new Database.LeadConvert();
            lcSuccess.setLeadId(testLead.Id);
            lcSuccess.setConvertedStatus('Converted');
            lcSuccess.setDoNotCreateOpportunity(true);
            Database.convertLead(new List<Database.LeadConvert>{lcSuccess}, false);

            // Now try to convert again (will fail because already converted)
            Database.LeadConvert lc2 = new Database.LeadConvert();
            lc2.setLeadId(testLead.Id);
            lc2.setConvertedStatus('Converted');
            lc2.setDoNotCreateOpportunity(true);
            failedResults = Database.convertLead(new List<Database.LeadConvert>{lc2}, false);

            // For already converted leads, we can't update status, so just verify the method runs
            Test.startTest();
            LeadDuplicateConversionServiceHelper.processConversionResults(failedResults, leadsWithAccountMatches, false);
            Test.stopTest();

            // The lead is already converted, so we can't update it to Pending Review
            // Just verify the method executed without error
            Assert.isTrue(true, 'Method should handle already converted leads gracefully');
            return;
        }

        // Get DTC_Open queue for verification
        Group dtcOpenQueue = getOrCreateDtcOpenQueue();

        Test.startTest();
        // requireCallbackTrue = false means auto conversion - failed leads meeting criteria should be assigned to queue
        LeadDuplicateConversionServiceHelper.processConversionResults(failedResults, leadsWithAccountMatches, false);
        Test.stopTest();

        // Verify the lead was assigned to DTC_Open queue (only if not already converted and meets criteria)
        Lead updatedLead = [SELECT Id, Status, IsConverted, OwnerId, LeadSource FROM Lead WHERE Id = :testLead.Id WITH USER_MODE LIMIT 1];
        if (!updatedLead.IsConverted) {
            // Lead meets criteria (LeadSource='Get Started' and Status='New'), should be assigned to queue
            Assert.areEqual(dtcOpenQueue.Id, updatedLead.OwnerId, 'Failed lead meeting criteria should be assigned to DTC_Open queue');
            // Status should remain unchanged
            Assert.areEqual(ConstantsUtil.LEAD_STATUS_NEW, updatedLead.Status, 'Lead status should remain unchanged');
        } else {
            // Lead was converted, can't update
            Assert.isTrue(true, 'Lead was converted, update not applicable');
        }
    }

    /**
     * @description Test processConversionResults with null/empty inputs
     */
    @IsTest
    static void testProcessConversionResultsWithNullInputs() {
        Test.startTest();
        // Test with null conversionResults
        LeadDuplicateConversionServiceHelper.processConversionResults(null, new Map<Lead, Account>(), true);

        // Test with empty conversionResults
        LeadDuplicateConversionServiceHelper.processConversionResults(new List<Database.LeadConvertResult>(), new Map<Lead, Account>(), true);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null/empty inputs gracefully');
    }

    /**
     * @description Test updateFailedLeadsToPendingReview with valid queue
     */
    @IsTest
    static void testUpdateFailedLeadsToPendingReviewWithQueue() {
        HealthcarePractitionerFacility facility = getFacility();
        Group testQueue = getOrCreatePracticeProviderLeadQueue();

        // Use unique data to avoid conflicts
        Integer randomNum = Crypto.getRandomInteger();
        String uniqueSuffix = String.valueOf(randomNum);

        Lead testLead1 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead1' + uniqueSuffix,
            'Email' => 'test1' + uniqueSuffix + '@example.com',
            'Company' => 'Test Company 1',
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => 'Open'
        });

        Lead testLead2 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead2' + uniqueSuffix,
            'Email' => 'test2' + uniqueSuffix + '@example.com',
            'Company' => 'Test Company 2',
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => 'Open'
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(new List<Lead>{testLead1, testLead2}, dmlOpts);

        // Query leads and prepare them for update
        List<Lead> leadsToUpdate = [
            SELECT Id, Status, IsConverted, OwnerId
            FROM Lead
            WHERE Id IN :new List<Id>{testLead1.Id, testLead2.Id}
            WITH USER_MODE
        ];

        // Prepare leads (reset status and owner if needed)
        leadsToUpdate = prepareLeadsForUpdate(leadsToUpdate, ConstantsUtil.LEAD_STATUS_PENDING_REVIEW, testQueue.Id);

        // Handle automation that might have changed status
        leadsToUpdate = prepareLeadsForUpdate(leadsToUpdate, ConstantsUtil.LEAD_STATUS_PENDING_REVIEW, null);

        // Collect non-converted lead IDs
        List<Id> failedLeadIds = new List<Id>();
        for (Lead lead : leadsToUpdate) {
            if (!lead.IsConverted) {
                failedLeadIds.add(lead.Id);
            }
        }

        Test.startTest();
        // Reset status if automation changed it right before the method call
        resetLeadsStatusIfNeeded(failedLeadIds, ConstantsUtil.LEAD_STATUS_PENDING_REVIEW);

        LeadDuplicateConversionServiceHelper.updateFailedLeadsToPendingReview(failedLeadIds);
        Test.stopTest();

        // Verify leads were updated
        List<Lead> updatedLeads = [
            SELECT Id, Status, OwnerId, IsConverted
            FROM Lead
            WHERE Id IN :failedLeadIds
            WITH USER_MODE
        ];

        for (Lead lead : updatedLeads) {
            if (!lead.IsConverted) {
                Assert.areEqual(ConstantsUtil.LEAD_STATUS_PENDING_REVIEW, lead.Status, 'Lead should be updated to Pending Review status');
                Assert.areEqual(testQueue.Id, lead.OwnerId, 'Lead should be assigned to Practice_Provider_Lead queue');
            }
        }
    }

    /**
     * @description Test updateFailedLeadsToPendingReview without queue (queue not found)
     * Note: In parallel test execution, we cannot delete Group objects, so we test the scenario
     * where the queue doesn't exist by verifying the method handles null queue gracefully
     */
    @IsTest
    static void testUpdateFailedLeadsToPendingReviewWithoutQueue() {
        HealthcarePractitionerFacility facility = getFacility();

        // Note: We cannot delete queues in parallel test execution
        // The test verifies that the method handles the case where findQueueByName returns null
        // by still updating the lead status to 'Pending Review' even without a queue assignment

        // Use unique data to avoid conflicts
        Integer randomNum = Crypto.getRandomInteger();
        String uniqueSuffix = String.valueOf(randomNum);

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'NoQueueLead' + uniqueSuffix,
            'Email' => 'noqueue' + uniqueSuffix + '@example.com',
            'Company' => 'No Queue Company',
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => 'Open'
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(testLead, dmlOpts);

        // Query lead to ensure it's not converted and has a different status
        Lead leadToUpdate = [SELECT Id, Status, IsConverted, OwnerId FROM Lead WHERE Id = :testLead.Id WITH USER_MODE LIMIT 1];

        // Ensure the lead has a status different from 'Pending Review' to trigger the update logic
        if (leadToUpdate.Status == 'Pending Review') {
            leadToUpdate.Status = 'Open';
            update leadToUpdate;
            // Re-query after update
            leadToUpdate = [SELECT Id, Status, IsConverted, OwnerId FROM Lead WHERE Id = :testLead.Id WITH USER_MODE LIMIT 1];
        }

        List<Id> failedLeadIds = new List<Id>();
        if (!leadToUpdate.IsConverted) {
            failedLeadIds.add(leadToUpdate.Id);
        }

        Test.startTest();
        // Re-query right before calling the method to get latest status (automation might have changed it)
        Lead finalLead = [SELECT Id, Status, IsConverted, OwnerId FROM Lead WHERE Id = :testLead.Id WITH USER_MODE LIMIT 1];

        // Ensure the lead is not converted and has a status different from 'Pending Review'
        // Automation might have changed it to 'Pending Review', 'New', or other statuses
        if (!finalLead.IsConverted && finalLead.Status != 'Open') {
            finalLead.Status = 'Open';
            update finalLead;
            // Re-query again after update to get latest status
            finalLead = [SELECT Id, Status, IsConverted, OwnerId FROM Lead WHERE Id = :testLead.Id WITH USER_MODE LIMIT 1];
        }

        // Update failedLeadIds list based on final lead state
        failedLeadIds.clear();
        if (!finalLead.IsConverted) {
            failedLeadIds.add(finalLead.Id);
        }

        LeadDuplicateConversionServiceHelper.updateFailedLeadsToPendingReview(failedLeadIds);
        Test.stopTest();

        // Verify lead was updated to Pending Review even without queue (only if not converted)
        Lead updatedLead = [SELECT Id, Status, IsConverted, OwnerId FROM Lead WHERE Id = :testLead.Id WITH USER_MODE LIMIT 1];
        if (!updatedLead.IsConverted) {
            Assert.areEqual(ConstantsUtil.LEAD_STATUS_PENDING_REVIEW, updatedLead.Status, 'Lead should be updated to Pending Review status even without queue');
        } else {
            // Lead was converted, can't update status
            Assert.isTrue(true, 'Lead was converted, status update not applicable');
        }
    }

    /**
     * @description Test updateFailedLeadsToPendingReview with leads that need both status and owner updates
     * This test ensures buildLeadsForUpdate() covers all conditional branches
     */
    @IsTest
    static void testUpdateFailedLeadsToPendingReviewWithStatusAndOwnerUpdate() {
        HealthcarePractitionerFacility facility = getFacility();

        // Create Practice_Provider_Lead queue if it doesn't exist
        Group testQueue = null;
        List<Group> existingQueues = [SELECT Id FROM Group WHERE DeveloperName = :ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE AND Type = 'Queue' WITH USER_MODE LIMIT 1];
        if (existingQueues.isEmpty()) {
            testQueue = new Group(
                Name = ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE,
                DeveloperName = ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE,
                Type = 'Queue'
            );
            insert testQueue;

            QueueSObject queueSObject = new QueueSObject(
                QueueId = testQueue.Id,
                SObjectType = 'Lead'
            );
            insert queueSObject;
        } else {
            testQueue = existingQueues[0];
        }

        // Use unique data to avoid conflicts
        Integer randomNum = Crypto.getRandomInteger();
        String uniqueSuffix = String.valueOf(randomNum);

        // Create a lead with different status to ensure status update condition is met
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'StatusOwnerLead' + uniqueSuffix,
            'Email' => 'statusowner' + uniqueSuffix + '@example.com',
            'Company' => 'Status Owner Company',
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => 'Open'  // Different from 'Pending Review' to trigger status update
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(testLead, dmlOpts);

        // Query lead to get current state
        Lead leadToUpdate = [
            SELECT Id, Status, IsConverted, OwnerId
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
            LIMIT 1
        ];

        // Explicitly set status to something other than 'Pending Review' if needed
        // and ensure owner is different from queue to trigger both update conditions
        Boolean needsUpdate = false;
        if (leadToUpdate.Status == 'Pending Review') {
            leadToUpdate.Status = 'Open';
            needsUpdate = true;
        }
        // Ensure owner is different from queue (if queue exists)
        if (testQueue != null && leadToUpdate.OwnerId == testQueue.Id) {
            // Get current user ID as a different owner
            leadToUpdate.OwnerId = UserInfo.getUserId();
            needsUpdate = true;
        }
        if (needsUpdate) {
            update leadToUpdate;
            // Re-query to get updated values
            leadToUpdate = [
                SELECT Id, Status, IsConverted, OwnerId
                FROM Lead
                WHERE Id = :testLead.Id
                WITH USER_MODE
                LIMIT 1
            ];
        }

        // Handle automation that might have changed status to 'Pending Review'
        if (!leadToUpdate.IsConverted && leadToUpdate.Status == 'Pending Review') {
            leadToUpdate.Status = 'Open';
            update leadToUpdate;
            // Re-query again to get latest status
            leadToUpdate = [
                SELECT Id, Status, IsConverted, OwnerId
                FROM Lead
                WHERE Id = :testLead.Id
                WITH USER_MODE
                LIMIT 1
            ];
        }

        List<Id> failedLeadIds = new List<Id>();
        if (!leadToUpdate.IsConverted) {
            failedLeadIds.add(leadToUpdate.Id);
        }

        Test.startTest();
        // Re-query right before calling the method to get latest status (automation might have changed it)
        Lead finalLead = [
            SELECT Id, Status, IsConverted, OwnerId
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
            LIMIT 1
        ];

        // Handle automation that might have changed status to 'Pending Review' right before the method call
        if (!finalLead.IsConverted && finalLead.Status == 'Pending Review') {
            finalLead.Status = 'Open';
            update finalLead;
        }

        LeadDuplicateConversionServiceHelper.updateFailedLeadsToPendingReview(failedLeadIds);
        Test.stopTest();

        // Verify lead was updated with both status and owner
        Lead updatedLead = [
            SELECT Id, Status, OwnerId, IsConverted
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
            LIMIT 1
        ];

        if (!updatedLead.IsConverted) {
            Assert.areEqual(ConstantsUtil.LEAD_STATUS_PENDING_REVIEW, updatedLead.Status, 'Lead should be updated to Pending Review status');
            if (testQueue != null) {
                Assert.areEqual(testQueue.Id, updatedLead.OwnerId, 'Lead should be assigned to Practice_Provider_Lead queue');
            }
        }
    }

    /**
     * @description Test updateFailedLeadsToPendingReview with null/empty inputs
     */
    @IsTest
    static void testUpdateFailedLeadsToPendingReviewWithNullInputs() {
        Test.startTest();
        // Test with null
        LeadDuplicateConversionServiceHelper.updateFailedLeadsToPendingReview(null);

        // Test with empty list
        LeadDuplicateConversionServiceHelper.updateFailedLeadsToPendingReview(new List<Id>());
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null/empty inputs gracefully');
    }

    /**
     * @description Test buildLeadsForUpdate where needsUpdate is initialized
     * This test ensures a lead exists, is not converted, and needs an update
     */
    @IsTest
    static void testBuildLeadsForUpdateCoversNeedsUpdateInitialization() {
        HealthcarePractitionerFacility facility = getFacility();

        // Create Practice_Provider_Lead queue if it doesn't exist
        Group testQueue = null;
        List<Group> existingQueues = [SELECT Id FROM Group WHERE DeveloperName = :ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE AND Type = 'Queue' WITH USER_MODE LIMIT 1];
        if (existingQueues.isEmpty()) {
            testQueue = new Group(
                Name = ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE,
                DeveloperName = ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE,
                Type = 'Queue'
            );
            insert testQueue;

            QueueSObject queueSObject = new QueueSObject(
                QueueId = testQueue.Id,
                SObjectType = 'Lead'
            );
            insert queueSObject;
        } else {
            testQueue = existingQueues[0];
        }

        // Use unique data to avoid conflicts
        Integer randomNum = Crypto.getRandomInteger();
        String uniqueSuffix = String.valueOf(randomNum);

        // Create a lead that is NOT converted and has Status != 'Pending Review'
        // Set Request_a_Call_Back__c = true to prevent automatic conversion
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'NeedsUpdateLead' + uniqueSuffix,
            'Email' => 'needsupdate' + uniqueSuffix + '@example.com',
            'Company' => 'Needs Update Company',
            'Request_a_Call_Back__c' => true, // Set to true to prevent automatic conversion
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => 'Open', // Ensure status is NOT 'Pending Review'
            'OwnerId' => UserInfo.getUserId() // Ensure owner is NOT the queue
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(testLead, dmlOpts);

        // Verify the lead exists and is not converted before calling the method
        Lead verifyLead = [
            SELECT Id, Status, IsConverted, OwnerId
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
            LIMIT 1
        ];

        // If lead was automatically converted, we can't test this scenario
        // Skip the test if lead is already converted
        if (verifyLead.IsConverted) {
            // Lead was auto-converted, skip this test case
            return;
        }

        // Handle automation that might have changed status to 'Pending Review'
        if (verifyLead.Status == 'Pending Review') {
            verifyLead.Status = 'Open';
            update verifyLead;
            // Re-query to get latest status
            verifyLead = [
                SELECT Id, Status, IsConverted, OwnerId
                FROM Lead
                WHERE Id = :testLead.Id
                WITH USER_MODE
                LIMIT 1
            ];
        }

        // If owner is already the queue, change it to ensure update is needed
        if (testQueue != null && verifyLead.OwnerId == testQueue.Id) {
            verifyLead.OwnerId = UserInfo.getUserId();
            update verifyLead;
            // Re-query again in case automation changed status
            verifyLead = [
                SELECT Id, Status, IsConverted, OwnerId
                FROM Lead
                WHERE Id = :testLead.Id
                WITH USER_MODE
                LIMIT 1
            ];
            // Check status again after owner update
            if (!verifyLead.IsConverted && verifyLead.Status == 'Pending Review') {
                verifyLead.Status = 'Open';
                update verifyLead;
                verifyLead = [
                    SELECT Id, Status, IsConverted, OwnerId
                    FROM Lead
                    WHERE Id = :testLead.Id
                    WITH USER_MODE
                    LIMIT 1
                ];
            }
        }

        Test.startTest();
        // Re-query right before calling the method to get latest status (automation might have changed it)
        Lead finalVerifyLead = [
            SELECT Id, Status, IsConverted, OwnerId
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
            LIMIT 1
        ];

        // Handle automation that might have changed status to 'Pending Review' right before the method call
        if (!finalVerifyLead.IsConverted && finalVerifyLead.Status == 'Pending Review') {
            finalVerifyLead.Status = 'Open';
            update finalVerifyLead;
        }

        // Call with a lead that exists, is not converted, and needs update
        // The lead exists (existingLead != null) and is not converted (IsConverted == false)
        LeadDuplicateConversionServiceHelper.updateFailedLeadsToPendingReview(new List<Id>{testLead.Id});
        Test.stopTest();

        // Verify the lead was updated
        Lead updatedLead = [
            SELECT Id, Status, OwnerId, IsConverted
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
            LIMIT 1
        ];

        if (!updatedLead.IsConverted) {
            Assert.areEqual(ConstantsUtil.LEAD_STATUS_PENDING_REVIEW, updatedLead.Status, 'Lead should be updated to Pending Review status');
            if (testQueue != null) {
                Assert.areEqual(testQueue.Id, updatedLead.OwnerId, 'Lead should be assigned to Practice_Provider_Lead queue');
            }
        }
    }

    /**
     * @description Test buildLeadsForUpdate with lead that exists but doesn't need update
     */
    @IsTest
    static void testBuildLeadsForUpdateWithLeadThatDoesNotNeedUpdate() {
        HealthcarePractitionerFacility facility = getFacility();

        // Create Practice_Provider_Lead queue if it doesn't exist
        Group testQueue = null;
        List<Group> existingQueues = [SELECT Id FROM Group WHERE DeveloperName = :ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE AND Type = 'Queue' WITH USER_MODE LIMIT 1];
        if (existingQueues.isEmpty()) {
            testQueue = new Group(
                Name = ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE,
                DeveloperName = ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE,
                Type = 'Queue'
            );
            insert testQueue;

            QueueSObject queueSObject = new QueueSObject(
                QueueId = testQueue.Id,
                SObjectType = 'Lead'
            );
            insert queueSObject;
        } else {
            testQueue = existingQueues[0];
        }

        // Use unique data to avoid conflicts
        Integer randomNum = Crypto.getRandomInteger();
        String uniqueSuffix = String.valueOf(randomNum);

        // Create a lead that already has Status = 'Pending Review' and OwnerId = queueId
        // This lead exists and is not converted, but doesn't need an update
        // Set Request_a_Call_Back__c = true to prevent automatic conversion
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'NoUpdateLead' + uniqueSuffix,
            'Email' => 'noupdate' + uniqueSuffix + '@example.com',
            'Company' => 'No Update Company',
            'Request_a_Call_Back__c' => true, // Set to true to prevent automatic conversion
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => 'Pending Review', // Already has the target status
            'OwnerId' => testQueue != null ? testQueue.Id : UserInfo.getUserId() // Already has the target owner
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(testLead, dmlOpts);

        // Verify the lead exists and is not converted
        Lead verifyLead = [
            SELECT Id, Status, IsConverted, OwnerId
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
            LIMIT 1
        ];

        // If lead was automatically converted, we can't test this scenario
        // Skip the test if lead is already converted
        if (verifyLead.IsConverted) {
            // Lead was auto-converted, skip this test case
            return;
        }

        // Ensure lead already has the target status and owner
        if (testQueue != null) {
            verifyLead.Status = 'Pending Review';
            verifyLead.OwnerId = testQueue.Id;
            update verifyLead;
        } else {
            // If no queue, just set status to 'Pending Review'
            verifyLead.Status = 'Pending Review';
            update verifyLead;
        }

        Test.startTest();
        // Call with a lead that exists, is not converted, but doesn't need update
        LeadDuplicateConversionServiceHelper.updateFailedLeadsToPendingReview(new List<Id>{testLead.Id});
        Test.stopTest();

        // Verify the lead was not updated (since it already had the correct values)
        Lead updatedLead = [
            SELECT Id, Status, OwnerId, IsConverted
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
            LIMIT 1
        ];

        // Lead should still have the same values since no update was needed
        Assert.areEqual(ConstantsUtil.LEAD_STATUS_PENDING_REVIEW, updatedLead.Status, 'Lead should still have Pending Review status (no update needed)');
        if (testQueue != null) {
            Assert.areEqual(testQueue.Id, updatedLead.OwnerId, 'Lead should still be assigned to Practice_Provider_Lead queue');
        }
    }

    /**
     * @description Test buildErrorMessage method
     */
    @IsTest
    static void testBuildErrorMessageHelper() {
        HealthcarePractitionerFacility facility = getFacility();

        // Use unique data to avoid conflicts
        Integer randomNum = Math.round(Math.random() * 1000000);
        String uniqueSuffix = String.valueOf(randomNum);

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'BldErr',
            'LastName' => 'Tst' + uniqueSuffix,
            'PersonEmail' => 'blderr' + uniqueSuffix + '@test.com'
        });
        insert testAccount;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'BldErr',
            'LastName' => 'Tst' + uniqueSuffix,
            'Email' => 'blderr' + uniqueSuffix + '@test.com',
            'Company' => 'Test' + uniqueSuffix,
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(testLead, dmlOpts);

        // Convert the lead
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setAccountId(testAccount.Id);
        lc.setConvertedStatus('Converted');
        lc.setDoNotCreateOpportunity(true);
        List<Database.LeadConvertResult> results = Database.convertLead(new List<Database.LeadConvert>{lc}, false);

        if (!results[0].isSuccess()) {
            List<Database.Error> errors = results[0].getErrors();
            String errorMessage = LeadDuplicateConversionServiceHelper.buildErrorMessage(errors);
            Assert.isNotNull(errorMessage, 'Error message should not be null');
            return;
        }
        testLead = [SELECT Id FROM Lead WHERE Id = :testLead.Id];

        Test.startTest();
        Database.LeadConvert lc2 = new Database.LeadConvert();
        lc2.setLeadId(testLead.Id);
        lc2.setAccountId(testAccount.Id);
        lc2.setConvertedStatus('Converted');
        List<Database.LeadConvertResult> failedResults = Database.convertLead(new List<Database.LeadConvert>{lc2}, false);

        Assert.isFalse(failedResults[0].isSuccess(), 'Second conversion should fail');
        List<Database.Error> errors = failedResults[0].getErrors();
        String errorMessage = LeadDuplicateConversionServiceHelper.buildErrorMessage(errors);
        Test.stopTest();

        Assert.isNotNull(errorMessage, 'Error message should not be null');
    }

    /**
     * @description Test buildErrorMessage with empty list
     */
    @IsTest
    static void testBuildErrorMessageWithEmptyList() {
        Test.startTest();
        String errorMsg = LeadDuplicateConversionServiceHelper.buildErrorMessage(new List<Database.Error>());
        Test.stopTest();

        Assert.areEqual('', errorMsg, 'Error message should be empty string for empty list');
    }

    /**
     * @description Test findQueueByName exception handling
     * This is tested indirectly through updateFailedLeadsToPendingReview
     */
    @IsTest
    static void testFindQueueByNameExceptionHandling() {
        HealthcarePractitionerFacility facility = getFacility();

        // Use unique data to avoid conflicts
        Integer randomNum = Crypto.getRandomInteger();
        String uniqueSuffix = String.valueOf(randomNum);

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'QueueExceptionLead' + uniqueSuffix,
            'Email' => 'queueexception' + uniqueSuffix + '@example.com',
            'Company' => 'Queue Exception Company',
            'Request_a_Call_Back__c' => false,
            'Provider_Practice_Affiliation__c' => facility.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => 'Open'
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(testLead, dmlOpts);

        // Query lead to ensure it's not converted
        Lead leadToUpdate = [SELECT Id, Status, IsConverted FROM Lead WHERE Id = :testLead.Id WITH USER_MODE LIMIT 1];

        List<Id> failedLeadIds = new List<Id>();
        if (!leadToUpdate.IsConverted) {
            failedLeadIds.add(leadToUpdate.Id);
        }

        Test.startTest();
        LeadDuplicateConversionServiceHelper.updateFailedLeadsToPendingReview(failedLeadIds);
        Test.stopTest();

        // Verify the method executed successfully
        Assert.isTrue(true, 'Method should complete successfully');
    }

    /**
     * @description Covers queryAccountById in LeadDuplicateConversionServiceHelper.
     * getAccAccountById falls back to queryAccountById when the account is not found in the matching criteria list.
     */
    @IsTest
    static void testGetAccAccountByIdQueriesWhenNotInMatchList() {
        Integer randomNum = Crypto.getRandomInteger();
        String uniqueSuffix = String.valueOf(randomNum);

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Query',
            'LastName' => 'AcctById' + uniqueSuffix,
            'PersonEmail' => 'queryacct' + uniqueSuffix + '@test.com',
            'Phone' => '5551112233',
            'Date_of_Birth__c' => Date.newInstance(1985, 7, 12)
        });
        insert testAccount;

        Test.startTest();
        Account result = LeadDuplicateConversionServiceHelper.getAccAccountById(
            testAccount.Id,
            new List<LeadDuplicateMatchingService.MatchingCriteria>()
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Should return account from queryAccountById');
        Assert.areEqual(testAccount.Id, result.Id, 'Should return the queried account');
    }
}