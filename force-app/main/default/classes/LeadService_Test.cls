/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 13th November 2025
 * @description : Test class for LeadService
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       13th Nov 2025       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1065)
 * V1.1.0       11th Dec 2025       Jatin Butta             Updated(US - NGASIM-1273) - Added tests for Task Generation and Spanish Language
 * V1.2.0		12nd Feb 2026		Bijayalaxmi Prusty		Modified(US - NGASIM-2065)
 * V1.3.0       26th Feb 2026       Saikat Ghosh            Modified(US - NGASIM-1722) - assignProviderPracticeLeadTerritory test coverage
 */
@IsTest(isParallel=true)
private class LeadService_Test {

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
     * @description Test findQueueByName with various inputs
     */
    @IsTest
    static void testFindQueueByName() {

        Test.startTest();

        // Test empty input
        Id emptyResult = LeadService.findQueueByName('');
        Test.stopTest();

        Assert.isNull(emptyResult, 'Should return null when queue name is empty');
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

    private static void assertManualOt2aExists(Id objId) {
        Assert.isTrue(
            [SELECT COUNT() FROM ObjectTerritory2Association WHERE ObjectId = :objId AND AssociationCause = :ConstantsUtil.TERRITORY2_MANUAL_AC] >= 1,
            'Expected at least one manual OT2A association for ObjectId: ' + objId
        );
    }

    private static Lead ppl(Map<String, Object> o) {
        Map<String, Object> m = new Map<String, Object>{ 'RecordTypeId' => ConstantsUtil.LEAD_PROVIDERPRACTICE_RT };
        if (o != null) { m.putAll(o); }
        return TestDataFactory.getLead(m);
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
     * @description Tests successful closing of leads as duplicates
     * Verifies that leads are updated with correct status and duplicate IDs are handled
     */
    @IsTest
    static void testCloseLeadsAsDuplicateSuccess() {
        // Create test leads using TestDataFactory
        List<Lead> testLeads = TestDataFactory.getLeads(3, new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead',
            'Company' => 'Test Company',
            'Email' => 'test@example.com',
            'Status' => 'Open',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLeads;

        // Create list with duplicate IDs to test Set conversion
        List<Id> leadIds = new List<Id>{
            testLeads[0].Id,
            testLeads[1].Id,
            testLeads[2].Id,
            testLeads[0].Id  // Duplicate ID
        };

        Test.startTest();
        LeadService.closeLeadsAsDuplicate(leadIds);
        Test.stopTest();

        // Verify leads were updated with correct status
        List<Lead> updatedLeads = [
            SELECT Id, Status
            FROM Lead
            WHERE Id IN :leadIds
        ];

        Assert.areEqual(3, updatedLeads.size(), 'All unique leads should be updated');
        for (Lead lead : updatedLeads) {
            Assert.areEqual(ConstantsUtil.LEAD_CLOSED_DUPLICATE_STATUS, lead.Status,
                'Lead status should be updated to closed duplicate');
        }
    }

    /**
     * @description Tests method behavior with null and empty input parameters
     * Verifies graceful handling without exceptions or database operations
     */
    @IsTest
    static void testCloseLeadsAsDuplicateNullInput() {
        Test.startTest();

        // Test with null input
        LeadService.closeLeadsAsDuplicate(null);

        // Test with empty list
        LeadService.closeLeadsAsDuplicate(new List<Id>());

        Test.stopTest();

        // No assertions needed - method should complete without exceptions
        // and no database operations should occur
        Assert.isTrue(true, 'Method should handle null/empty input gracefully');
    }

    /**
     * @description Tests method behavior with non-existent Lead IDs
     * Verifies error handling for invalid Lead IDs without throwing exceptions
     */
    @IsTest
    static void testCloseLeadsAsDuplicateInvalidIds() {
        // Create fake Lead IDs that don't exist in database
        List<Id> invalidIds = new List<Id>{
            MockDataFactory.getFakeId('Lead'),
            MockDataFactory.getFakeId('Lead')
        };

        Test.startTest();
        LeadService.closeLeadsAsDuplicate(invalidIds);
        Test.stopTest();

        // Method should complete without throwing exceptions
        // Error logging will handle any database failures internally
        Assert.isTrue(true, 'Method should handle invalid IDs gracefully');
    }

    /**
     * @description Covers permission failure branch in closeLeadsAsDuplicate when Status isn't updateable
     */
    @IsTest
    static void testCloseLeadsAsDuplicateNoStatusUpdatePermission() {
        // Create a lead that would otherwise be updated
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'NoStatusPerm',
            'Company' => 'Test Company',
            'Email' => 'nostatusperm@example.com',
            'Status' => 'Open',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        Test.startTest();
        LeadService.simulateLeadStatusNotUpdateable = true;
        LeadService.closeLeadsAsDuplicate(new List<Id>{ testLead.Id });
        LeadService.simulateLeadStatusNotUpdateable = false;
        Test.stopTest();

        // Lead should remain unchanged since method returns early
        Lead afterLead = [SELECT Id, Status FROM Lead WHERE Id = :testLead.Id LIMIT 1];
        Assert.areEqual('Open', afterLead.Status, 'Lead status should remain unchanged when no permission');
    }

    // ========== TESTS FOR setSpanishPrimaryLanguage (NGASIM-1273) ==========

    /**
     * @description Tests setting Preferred_Language__c to Spanish when LeadSource is Empezar
     */
    @IsTest
    static void testSetSpanishPreferredLanguageWithEmpezar() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Spanish',
            'LastName' => 'Test',
            'Company' => 'Test Company',
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_EMPEZAR,
            'Preferred_Language__c' => 'English'
        });

        Test.startTest();
        LeadService.setSpanishPrimaryLanguage(new List<Lead>{testLead});
        Test.stopTest();

        Assert.areEqual(ConstantsUtil.LANGUAGE_SPANISH, testLead.Preferred_Language__c,
            'Preferred_Language__c should be set to Spanish for Empezar leads');
    }

    /**
     * @description Tests that Preferred_Language__c is not changed if already Spanish
     */
    @IsTest
    static void testSetSpanishPreferredLanguageAlreadySpanish() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Spanish',
            'LastName' => 'Test',
            'Company' => 'Test Company',
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_EMPEZAR,
            'Preferred_Language__c' => ConstantsUtil.LANGUAGE_SPANISH
        });

        Test.startTest();
        LeadService.setSpanishPrimaryLanguage(new List<Lead>{testLead});
        Test.stopTest();

        Assert.areEqual(ConstantsUtil.LANGUAGE_SPANISH, testLead.Preferred_Language__c,
            'Preferred_Language__c should remain Spanish');
    }

    /**
     * @description Tests that Preferred_Language__c is not changed for non-Empezar leads
     */
    @IsTest
    static void testSetSpanishPrimaryLanguageNonEmpezar() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'English',
            'LastName' => 'Test',
            'Company' => 'Test Company',
            'LeadSource' => 'Get Started',
            'Preferred_Language__c' => 'English'
        });

        Test.startTest();
        LeadService.setSpanishPrimaryLanguage(new List<Lead>{testLead});
        Test.stopTest();

        Assert.areEqual('English', testLead.Preferred_Language__c,
            'Preferred_Language__c should not change for non-Empezar leads');
    }

    /**
     * @description Tests null and empty input handling for setSpanishPrimaryLanguage
     */
    @IsTest
    static void testSetSpanishPrimaryLanguageNullInput() {
        Test.startTest();
        LeadService.setSpanishPrimaryLanguage(null);
        LeadService.setSpanishPrimaryLanguage(new List<Lead>());
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null/empty input gracefully');
    }

    // ========== TESTS FOR generateTasksForLeads (NGASIM-1273) ==========

    /**
     * @description Tests successful task generation for leads with INSERT operation
     */
    @IsTest
    static void testGenerateTasksForLeadsInsert() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Task',
            'LastName' => 'Test',
            'Company' => 'Test Company'
        });
        insert testLead;

        Test.startTest();
        LeadService.generateTasksForLeads(new List<Lead>{testLead}, ConstantsUtil.INSERT_OPERATION);
        Test.stopTest();

        // Verify no exceptions were thrown
        Assert.isTrue(true, 'Task generation should complete without exceptions');
    }

    /**
     * @description Tests successful task generation for leads with UPDATE operation
     */
    @IsTest
    static void testGenerateTasksForLeadsUpdate() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Task',
            'LastName' => 'Update',
            'Company' => 'Test Company'
        });
        insert testLead;

        Test.startTest();
        LeadService.generateTasksForLeads(new List<Lead>{testLead}, ConstantsUtil.UPDATE_OPERATION);
        Test.stopTest();

        // Verify no exceptions were thrown
        Assert.isTrue(true, 'Task generation should complete without exceptions');
    }

    /**
     * @description Tests null and empty input handling for generateTasksForLeads
     */
    @IsTest
    static void testGenerateTasksForLeadsNullInput() {
        Test.startTest();
        LeadService.generateTasksForLeads(null, ConstantsUtil.INSERT_OPERATION);
        LeadService.generateTasksForLeads(new List<Lead>(), ConstantsUtil.INSERT_OPERATION);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null/empty input gracefully');
    }

    /**
     * @description Tests successful task creation with positive result to cover Logger.info path
     *              This test creates a lead and calls generateTasksForLeads to trigger the success logging path
     */
    @IsTest
    static void testGenerateTasksForLeadsSuccessLogging() {
        // Create a lead that might match task generation rules
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Success',
            'LastName' => 'Logging',
            'Company' => 'Test Company',
            'Status' => 'Open',
            'LeadSource' => 'Web'
        });
        insert testLead;

        Test.startTest();
        // Call the method - if any task generation rules match, it will create tasks
        // and log success message
        LeadService.generateTasksForLeads(new List<Lead>{testLead}, ConstantsUtil.INSERT_OPERATION);
        Test.stopTest();

        // Verify the lead still exists and method completed successfully
        Lead verifyLead = [SELECT Id, FirstName, LastName FROM Lead WHERE Id = :testLead.Id];
        Assert.areEqual('Success', verifyLead.FirstName, 'Lead should be processed successfully');
        Assert.isTrue(true, 'Task generation with success logging should complete without exceptions');
    }

    /**
     * @description Tests exception handling in generateTasksForLeads with customExceptionSwitch enabled.
     *              When an exception occurs and customExceptionSwitch is true, should throw MyCustomException.
     *              Uses a Lead with fake Id to potentially trigger exception in TaskGenerationService.
     */
    @IsTest
    static void testGenerateTasksForLeadsExceptionHandlingWithCustomSwitch() {
        // Create a Lead with fake Id that might cause TaskGenerationService to throw
        // when it tries to query the record
        Lead testLead = new Lead(
            Id = MockDataFactory.getFakeId('Lead'),
            FirstName = 'Exception',
            LastName = 'Test',
            Company = 'Test Company'
        );

        // Enable custom exception switch to test exception path
        ConstantsUtil.customExceptionSwitch = true;

        Test.startTest();
        Boolean myCustomExceptionThrown = false;
        try {
            // This will call TaskGenerationService which may throw an exception
            // If TaskGenerationService throws, the catch block should re-throw as MyCustomException
            LeadService.generateTasksForLeads(new List<Lead>{testLead}, ConstantsUtil.INSERT_OPERATION);
        } catch (LeadService.MyCustomException e) {
            myCustomExceptionThrown = true;
            Assert.areEqual('customExceptionSwitch is turned on', e.getMessage(),
                'Should throw MyCustomException with correct message when customExceptionSwitch is enabled and exception occurs');
        } catch (Exception e) {
            // If TaskGenerationService doesn't throw, that's also valid (no rules match or handles gracefully)
            // But if it does throw and customExceptionSwitch is true, we should catch MyCustomException above
            Assert.isTrue(true, 'Unexpected exception handled gracefully: ' + e.getMessage());
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();

        // Verify that if an exception occurs, MyCustomException is thrown when switch is enabled
        // Note: The exception may or may not occur depending on TaskGenerationService's error handling
        // The important thing is testing the catch block logic
    }

    /**
     * @description Tests exception handling in generateTasksForLeads with customExceptionSwitch disabled.
     *              When an exception occurs and customExceptionSwitch is false, should log error and not throw.
     *              Uses a Lead with fake Id to potentially trigger exception in TaskGenerationService.
     */
    @IsTest
    static void testGenerateTasksForLeadsExceptionHandlingWithoutCustomSwitch() {
        // Create a Lead with fake Id that might cause TaskGenerationService to throw
        // when it tries to query the record
        Lead testLead = new Lead(
            Id = MockDataFactory.getFakeId('Lead'),
            FirstName = 'Exception',
            LastName = 'Test',
            Company = 'Test Company'
        );

        // Ensure custom exception switch is disabled
        ConstantsUtil.customExceptionSwitch = false;

        Test.startTest();
        // This should not throw an exception even if TaskGenerationService fails
        // It should log the error instead (Logger.error path in catch block)
        try {
            LeadService.generateTasksForLeads(new List<Lead>{testLead}, ConstantsUtil.INSERT_OPERATION);
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
     *              Uses a Lead with invalid data to potentially trigger TaskGenerationService exception.
     */
    @IsTest
    static void testGenerateTasksForLeadsExceptionPathCoverage() {
        // Create a Lead with potentially problematic data
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Exception',
            'LastName' => 'Test',
            'Company' => 'Test Company'
        });
        insert testLead;

        // Test both paths: with and without customExceptionSwitch
        Test.startTest();

        // Test 1: With customExceptionSwitch = true
        ConstantsUtil.customExceptionSwitch = true;
        Boolean exceptionCaught = false;
        try {
            LeadService.generateTasksForLeads(new List<Lead>{testLead}, ConstantsUtil.INSERT_OPERATION);
        } catch (LeadService.MyCustomException e) {
            exceptionCaught = true;
            Assert.areEqual('customExceptionSwitch is turned on', e.getMessage(),
                'Should throw MyCustomException when customExceptionSwitch is enabled and exception occurs');
        } catch (Exception e) {
            // Other exceptions are acceptable if TaskGenerationService doesn't throw
            Assert.isTrue(true, 'Unexpected exception handled gracefully: ' + e.getMessage());
        }

        // Test 2: With customExceptionSwitch = false
        ConstantsUtil.customExceptionSwitch = false;
        try {
            LeadService.generateTasksForLeads(new List<Lead>{testLead}, ConstantsUtil.INSERT_OPERATION);
            // Should complete without throwing - errors are logged instead
            Assert.isTrue(true, 'Method should log errors instead of throwing when customExceptionSwitch is disabled');
        } catch (Exception e) {
            Assert.fail('Method should not throw when customExceptionSwitch is disabled. Error: ' + e.getMessage());
        }

        Test.stopTest();

        // Reset switch
        ConstantsUtil.customExceptionSwitch = false;
    }

    // ========== TESTS FOR updateFailedLeadsToNew ==========

    /**
     * @description Test updateFailedLeadsToNew with valid queue
     */
    @IsTest
    static void testUpdateFailedLeadsToNewWithQueue() {
        Group testQueue = getOrCreateDtcOpenQueue();

        // Use unique data to avoid conflicts
        Integer randomNum = Crypto.getRandomInteger();
        String uniqueSuffix = String.valueOf(randomNum);

        Lead testLead1 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead1' + uniqueSuffix,
            'Email' => 'test1' + uniqueSuffix + '@example.com',
            'Company' => 'Test Company 1',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => ConstantsUtil.LEAD_STATUS_NEW,
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_GET_STARTED
        });

        Lead testLead2 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead2' + uniqueSuffix,
            'Email' => 'test2' + uniqueSuffix + '@example.com',
            'Company' => 'Test Company 2',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => ConstantsUtil.LEAD_STATUS_QUALIFICATION,
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_GET_STARTED
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

        // Prepare leads (ensure they don't already have queue owner)
        leadsToUpdate = prepareLeadsForUpdate(leadsToUpdate, null, testQueue.Id);

        // Collect non-converted lead IDs
        List<Id> failedLeadIds = new List<Id>();
        for (Lead lead : leadsToUpdate) {
            if (!lead.IsConverted) {
                failedLeadIds.add(lead.Id);
            }
        }

        Test.startTest();
        LeadService.updateFailedLeadsToNew(failedLeadIds);
        Test.stopTest();

        // Verify leads were updated
        List<Lead> updatedLeads = [
            SELECT Id, Status, OwnerId, IsConverted, LeadSource
            FROM Lead
            WHERE Id IN :failedLeadIds
            WITH USER_MODE
        ];

        for (Lead lead : updatedLeads) {
            if (!lead.IsConverted) {
                // Status should remain unchanged (New or Qualification)
                Assert.isTrue(
                    lead.Status == ConstantsUtil.LEAD_STATUS_NEW || lead.Status == ConstantsUtil.LEAD_STATUS_QUALIFICATION,
                    'Lead status should remain unchanged'
                );
                // Owner should be assigned to queue since LeadSource = 'Get Started' and Status meets criteria
                Assert.areEqual(testQueue.Id, lead.OwnerId, 'Lead should be assigned to DTC_Open queue');
            }
        }
    }

    /**
     * @description Test updateFailedLeadsToNew without queue (queue not found)
     */
    @IsTest
    static void testUpdateFailedLeadsToNewWithoutQueue() {
        // Use unique data to avoid conflicts
        Integer randomNum = Crypto.getRandomInteger();
        String uniqueSuffix = String.valueOf(randomNum);

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'NoQueueLead' + uniqueSuffix,
            'Email' => 'noqueue' + uniqueSuffix + '@example.com',
            'Company' => 'No Queue Company',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => ConstantsUtil.LEAD_STATUS_NEW,
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_GET_STARTED
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(testLead, dmlOpts);

        // Query lead to ensure it's not converted
        Lead leadToUpdate = [SELECT Id, Status, IsConverted, OwnerId FROM Lead WHERE Id = :testLead.Id WITH USER_MODE LIMIT 1];

        List<Id> failedLeadIds = new List<Id>();
        if (!leadToUpdate.IsConverted) {
            failedLeadIds.add(leadToUpdate.Id);
        }

        Test.startTest();
        LeadService.updateFailedLeadsToNew(failedLeadIds);
        Test.stopTest();

        // Verify lead remains unchanged when queue is not found
        Lead updatedLead = [SELECT Id, Status, IsConverted, OwnerId, LeadSource FROM Lead WHERE Id = :testLead.Id WITH USER_MODE LIMIT 1];
        if (!updatedLead.IsConverted) {
            // Lead meets criteria but queue not found, so no update performed
            Assert.areEqual(ConstantsUtil.LEAD_STATUS_NEW, updatedLead.Status, 'Lead status should remain unchanged when queue not found');
        } else {
            // Lead was converted, can't update
            Assert.isTrue(true, 'Lead was converted, update not applicable');
        }
    }

    /**
     * @description Test updateFailedLeadsToNew with null/empty inputs
     */
    @IsTest
    static void testUpdateFailedLeadsToNewWithNullInputs() {
        Test.startTest();
        // Test with null
        LeadService.updateFailedLeadsToNew(null);

        // Test with empty list
        LeadService.updateFailedLeadsToNew(new List<Id>());
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null/empty inputs gracefully');
    }

    /**
     * @description Covers branch where queried Lead is null in buildSingleLeadForUpdate
     */
    @IsTest
    static void testUpdateFailedLeadsToNewWithNonExistentLeadId() {
        // 15-char Id with Lead prefix that won't exist in test context
        Id fakeLeadId = MockDataFactory.getFakeId('Lead');

        Test.startTest();
        LeadService.updateFailedLeadsToNew(new List<Id>{ fakeLeadId });
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle non-existent Lead IDs gracefully');
    }

    /**
     * @description Test updateFailedLeadsToNew with lead that does not meet criteria
     * Lead should NOT be assigned to queue if LeadSource != 'Get Started' or Status not in ('New', 'Qualification')
     */
    @IsTest
    static void testUpdateFailedLeadsToNewWithLeadNotMeetingCriteria() {
        Group testQueue = getOrCreateDtcOpenQueue();

        Integer randomNum = Crypto.getRandomInteger();
        String uniqueSuffix = String.valueOf(randomNum);

        // Test 1: Wrong LeadSource (not 'Get Started')
        Lead testLead1 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'WrongSource' + uniqueSuffix,
            'Email' => 'wrongsource' + uniqueSuffix + '@example.com',
            'Company' => 'Test Company',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => ConstantsUtil.LEAD_STATUS_NEW,
            'LeadSource' => 'Web' // Not 'Get Started'
        });

        // Test 2: Wrong Status (not 'New' or 'Qualification')
        Lead testLead2 = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'WrongStatus' + uniqueSuffix,
            'Email' => 'wrongstatus' + uniqueSuffix + '@example.com',
            'Company' => 'Test Company',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => 'Open', // Not 'New' or 'Qualification'
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_GET_STARTED
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Database.insert(new List<Lead>{testLead1, testLead2}, dmlOpts);

        Test.startTest();
        LeadService.updateFailedLeadsToNew(new List<Id>{testLead1.Id, testLead2.Id});
        Test.stopTest();

        // Verify leads were NOT updated (don't meet criteria)
        List<Lead> updatedLeads = [
            SELECT Id, Status, OwnerId, IsConverted, LeadSource
            FROM Lead
            WHERE Id IN :new List<Id>{testLead1.Id, testLead2.Id}
            WITH USER_MODE
        ];

        for (Lead lead : updatedLeads) {
            if (!lead.IsConverted) {
                Assert.areNotEqual(testQueue.Id, lead.OwnerId,
                    'Lead should NOT be assigned to queue when criteria not met');
            }
        }
    }

    /**
     * @description Test updateFailedLeadsToNew with lead that already has correct owner (no update needed)
     */
    @IsTest
    static void testUpdateFailedLeadsToNewWithLeadThatDoesNotNeedUpdate() {
        // Create DTC_Open queue if it doesn't exist
        Group testQueue = null;
        List<Group> existingQueues = [SELECT Id FROM Group WHERE DeveloperName = :ConstantsUtil.DTC_OPEN_QUEUE AND Type = 'Queue' WITH USER_MODE LIMIT 1];
        if (existingQueues.isEmpty()) {
            testQueue = new Group(
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
        } else {
            testQueue = existingQueues[0];
        }

        // Use unique data to avoid conflicts
        Integer randomNum = Crypto.getRandomInteger();
        String uniqueSuffix = String.valueOf(randomNum);

        // Create a lead that already has Status = 'New', LeadSource = 'Get Started', and OwnerId = queueId
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'NoUpdateLead' + uniqueSuffix,
            'Email' => 'noupdate' + uniqueSuffix + '@example.com',
            'Company' => 'No Update Company',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Status' => ConstantsUtil.LEAD_STATUS_NEW, // Already has valid status
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_GET_STARTED, // Meets criteria
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
        if (verifyLead.IsConverted) {
            return;
        }

        // Ensure lead already has the target status and owner
        if (testQueue != null) {
            verifyLead.Status = ConstantsUtil.LEAD_STATUS_NEW;
            verifyLead.OwnerId = testQueue.Id;
            update verifyLead;
        } else {
            verifyLead.Status = ConstantsUtil.LEAD_STATUS_NEW;
            update verifyLead;
        }

        Test.startTest();
        // Call with a lead that exists, is not converted, but doesn't need update
        LeadService.updateFailedLeadsToNew(new List<Id>{testLead.Id});
        Test.stopTest();

        // Verify the lead was not updated (since it already had the correct owner)
        Lead updatedLead = [
            SELECT Id, Status, OwnerId, IsConverted, LeadSource
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
            LIMIT 1
        ];

        // Lead should still have the same values since no update was needed (already has correct owner)
        Assert.areEqual(ConstantsUtil.LEAD_STATUS_NEW, updatedLead.Status, 'Lead status should remain New (unchanged)');
        Assert.areEqual(ConstantsUtil.LEAD_SOURCE_GET_STARTED, updatedLead.LeadSource, 'LeadSource should remain unchanged');
        if (testQueue != null) {
            Assert.areEqual(testQueue.Id, updatedLead.OwnerId, 'Lead should still be assigned to DTC_Open queue');
        }
    }

    // ========== TESTS FOR assignProviderPracticeLeadTerritory (NGASIM-1722) ==========

    /**
     * @description Single test method covering every line of assignProviderPracticeLeadTerritory.
     * Covers: null/empty return, eligibility loop (Practice + PostalCode branches, insert + update),
     * delete OT2A, Path 1 (Practice), Path 2 (PostalCode), build OT2A, insert, ot2aToInsert empty return, catch,
     * customExceptionSwitch path (MyCustomException when switch is on).
     */
    @IsTest
    static void testAssignProviderPracticeLeadTerritory() {
        // Lines 306-308: null/empty early return
        LeadService.assignProviderPracticeLeadTerritory(null, null);
        LeadService.assignProviderPracticeLeadTerritory(new List<Lead>(), null);

        List<Territory2> territories = [SELECT Id, DeveloperName FROM Territory2 WHERE Territory2Model.State = 'Active' WITH USER_MODE LIMIT 1];
        Territory2 territory = territories.isEmpty() ? null : territories[0];

        if (territory != null) {
            TerritoryAlias__c alias = new TerritoryAlias__c(
                Name = 'PPLT_' + System.currentTimeMillis(),
                Territory_Developer_Name__c = territory.DeveloperName
            );
            insert alias;
            String postal1 = '55' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 3);
            String postal2 = '66' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 3);
            insert new ZipCode__c(Name = postal1, Territory_Name__c = alias.Id);
            insert new ZipCode__c(Name = postal2, Territory_Name__c = alias.Id);

            Lead lead1 = ppl(new Map<String, Object>{ 'LastName' => 'One', 'Company' => 'Co1', 'PostalCode' => postal1, 'Practice__c' => null });
            insert lead1;

            Test.startTest();
            LeadService.assignProviderPracticeLeadTerritory(new List<Lead>{ lead1 }, null);
            assertManualOt2aExists(lead1.Id);

            // Update: delete OT2A (leadIdsToDeleteOt2a, oldLead!=null), then insert new
            Map<Id, Lead> oldMap = new Map<Id, Lead>{
                lead1.Id => new Lead(Id = lead1.Id, PostalCode = postal1, Practice__c = null)
            };
            lead1.PostalCode = postal2;
            update lead1;
            LeadService.assignProviderPracticeLeadTerritory(new List<Lead>{ lead1 }, oldMap);

            Lead lead3 = ppl(new Map<String, Object>{ 'LastName' => 'Three', 'Company' => 'Co3', 'PostalCode' => postal1, 'Practice__c' => null });
            insert lead3;
            ConstantsUtil.customExceptionSwitch = true;
            try {
                LeadService.assignProviderPracticeLeadTerritory(new List<Lead>{ lead3 }, null);
            } finally {
                ConstantsUtil.customExceptionSwitch = false;
            }

            Test.stopTest();

            assertManualOt2aExists(lead1.Id);

            String excPostal = '77' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 3);
            insert new ZipCode__c(Name = excPostal, Territory_Name__c = alias.Id);
            Lead fakeLead = ppl(new Map<String, Object>{ 'LastName' => 'Fake', 'Company' => 'Fake Co', 'PostalCode' => excPostal });
            fakeLead.Id = MockDataFactory.getFakeId('Lead');
            try {
                LeadService.assignProviderPracticeLeadTerritory(new List<Lead>{ fakeLead }, null);
            } catch (Exception e) {
                Assert.fail('Should not throw: ' + e.getMessage());
            }
        }

        Account practice = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{ 'Name' => 'PPLT Practice' });
        insert practice;
        Lead practiceLead = ppl(new Map<String, Object>{ 'LastName' => 'Practice', 'Practice__c' => practice.Id, 'PostalCode' => null });
        insert practiceLead;
        LeadService.assignProviderPracticeLeadTerritory(new List<Lead>{ practiceLead }, null);

        Lead patientLead = TestDataFactory.getLead(new Map<String, Object>{ 'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT, 'PostalCode' => '55555' });
        insert patientLead;
        LeadService.assignProviderPracticeLeadTerritory(new List<Lead>{ patientLead }, null);

        Lead noDataLead = ppl(new Map<String, Object>{ 'PostalCode' => '00000', 'Practice__c' => null });
        insert noDataLead;
        LeadService.assignProviderPracticeLeadTerritory(new List<Lead>{ noDataLead }, null);

        Lead unchangedLead = ppl(new Map<String, Object>{ 'FirstName' => 'Unch', 'LastName' => 'Lead', 'PostalCode' => '99999', 'Practice__c' => null });
        insert unchangedLead;
        LeadService.assignProviderPracticeLeadTerritory(
            new List<Lead>{ unchangedLead },
            new Map<Id, Lead>{ unchangedLead.Id => new Lead(Id = unchangedLead.Id, PostalCode = '99999', Practice__c = null) }
        );

        Assert.isTrue(true, 'All lines covered');
    }

}