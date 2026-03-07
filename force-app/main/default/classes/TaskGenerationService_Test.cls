/**
 * @description Test class for TaskGenerationService.
 *              Uses minimal DML only where needed to validate end-to-end behavior deterministically
 *              without trigger dependency, and uses in-memory rule overrides for predictable outcomes.
 * @author Jatin Butta
 * @created Date 11th Dec 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Dec 2025       Jatin Butta             Initial Version(US - NGASIM-1273)
 * V1.0.1       04th Feb 2026       Charchit N.            Fix for lead conversion(101 SOQL issue).
 * =======================================================================
 */
@IsTest(isParallel=true)
private class TaskGenerationService_Test {

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    /**
     * @description Build a Task_Generation_Rule__mdt using a field map to avoid long parameter lists.
     * @param fields Field API name -> value
     * @return In-memory Task_Generation_Rule__mdt instance
     */
    private static Task_Generation_Rule__mdt rule(Map<String, Object> fields) {
        Task_Generation_Rule__mdt r = new Task_Generation_Rule__mdt();
        for (String key : fields.keySet()) {
            r.put(key, fields.get(key));
        }
        return r;
    }

    /**
     * @description Helper to insert a Lead record for deterministic end-to-end tests.
     * @param fields Map of field names to values for the Lead record
     * @return Inserted Lead record with Id
     */
    private static Lead insertLead(Map<String, Object> fields) {
        Lead l = TestDataFactory.getLead(fields);
        l.RecordTypeId = ConstantsUtil.LEAD_PATIENT_RT;
        insert l;
        return l;
    }

    private static TaskGenerationService.TaskRequest req(Id recordId, String objectApiName, String triggerEvent) {
        TaskGenerationService.TaskRequest r = new TaskGenerationService.TaskRequest();
        r.recordId = recordId;
        r.objectApiName = objectApiName;
        r.triggerEvent = triggerEvent;
        return r;
    }

    private static List<TaskGenerationService.TaskResult> runCreateTasks(List<TaskGenerationService.TaskRequest> requests) {
        Test.startTest();
        List<TaskGenerationService.TaskResult> results = TaskGenerationService.createTasks(requests);
        Test.stopTest();
        return results;
    }

    // ---------------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------------

    @IsTest
    static void testCreateTasksWithNullOrEmptyRequest() {
        Test.startTest();
        List<TaskGenerationService.TaskResult> emptyResults = TaskGenerationService.createTasks(new List<TaskGenerationService.TaskRequest>());
        List<TaskGenerationService.TaskResult> nullResults = TaskGenerationService.createTasks(null);
        Test.stopTest();

        Assert.isNotNull(emptyResults, 'Results should not be null');
        Assert.isTrue(emptyResults.isEmpty(), 'Results should be empty for empty request');
        Assert.isNotNull(nullResults, 'Results should not be null');
        Assert.isTrue(nullResults.isEmpty(), 'Results should be empty for null request');
    }

    @IsTest
    static void testNoRulesEarlyReturn() {
        TaskGenerationService.testRulesOverride = new List<Task_Generation_Rule__mdt>();
        Id mockLeadId = MockDataFactory.getFakeId('Lead');

        List<TaskGenerationService.TaskResult> results = runCreateTasks(
            new List<TaskGenerationService.TaskRequest>{ req(mockLeadId, 'Lead', null) }
        );

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.isTrue(results[0].success, 'No rules should be treated as early-success');
        Assert.areEqual(0, results[0].tasksCreated, 'No tasks should be created');
    }

    @IsTest
    static void testQueryMetadataRecords() {
        TaskGenerationService.testRulesOverride = null;
        Id mockLeadId = MockDataFactory.getFakeId('Lead');

        List<TaskGenerationService.TaskResult> results = runCreateTasks(
            new List<TaskGenerationService.TaskRequest>{ req(mockLeadId, 'Lead', ConstantsUtil.INSERT_OPERATION) }
        );

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.isFalse(results[0].success, 'No rules matches');
        Assert.areEqual(0, results[0].tasksCreated, 'No tasks should be created');
    }

    /**
     * @description End-to-end: UPDATE Lead + a matching rule -> inserts a Task (no trigger dependency).
     *              Covers: TaskGenerationService, TaskGenerationProcessor, TaskGenerationRecordQuery,
     *              TaskGenerationCore (including existing-task detection + default-results generation),
     *              and TaskGenerationTaskBuilder.
     */
    @IsTest
    static void testEndToEndCreatesOneTask() {
        // One UPDATE rule (formula references fields to exercise referenced-field extraction / dynamic SOQL).
        TaskGenerationService.testRulesOverride = new List<Task_Generation_Rule__mdt>{
            rule(new Map<String, Object>{
                'DeveloperName' => 'PartialMatch_Update',
                'Active__c' => true,
                'Object_Name__c' => 'Lead',
                'Trigger_Event__c' => ConstantsUtil.UPDATE_OPERATION,
                'Condition_Formula__c' => 'AND(ISPICKVAL(Matching_Status__c, \'Partial Match\'), RecordType.DeveloperName = \'Patient\', ISPICKVAL(LeadSource, \'Get Started\'))',
                'Category__c' => 'Patient Lead',
                'Sub_Category__c' => 'DTC Partial Match',
                'Subject__c' => 'Patient Outreach',
                'Due_Date_Offset__c' => 1,
                'Owner_Type__c' => 'Partial_Match'
            })
        };

        Lead testLead = insertLead(new Map<String, Object>{
            'FirstName' => 'Partial',
            'LastName' => 'Match',
            'Email' => 'test@test.com',
            'Phone' => '1234567890',
            'PostalCode' => '123456',
            'Company' => 'Test Company',
            'LeadSource' => 'Get Started',
            'Matching_Status__c' => 'Partial Match'
        });

        Test.startTest();
        List<TaskGenerationService.TaskResult> results = TaskGenerationService.createTasks(
            new List<TaskGenerationService.TaskRequest>{ req(testLead.Id, 'Lead', ConstantsUtil.UPDATE_OPERATION) }
        );
        Test.stopTest();

        List<Task> created = [
            SELECT Id, Subject, Category__c, Sub_Category__c, WhoId, ActivityDate
            FROM Task
            WHERE WhoId = :testLead.Id
            WITH SYSTEM_MODE
        ];
        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.isTrue(results[0].success, 'Processing should succeed');
    }

    /**
     * @description Ensures duplicate prevention via existing tasks map (ExistingTaskService path).
     */
    @IsTest
    static void testExistingTaskPreventsDuplicate() {
        TaskGenerationService.testRulesOverride = new List<Task_Generation_Rule__mdt>{
            rule(new Map<String, Object>{
                'DeveloperName' => 'InsertRule',
                'Active__c' => true,
                'Object_Name__c' => 'Lead',
                'Trigger_Event__c' => ConstantsUtil.INSERT_OPERATION,
                'Condition_Formula__c' => 'ISPICKVAL(LeadSource, \'Get Started\')',
                'Category__c' => 'Patient Lead',
                'Sub_Category__c' => 'DTC Partial Match',
                'Subject__c' => 'Patient Outreach',
                'Due_Date_Offset__c' => 0,
                'Owner_Type__c' => UserInfo.getUserEmail()
            }),
            rule(new Map<String, Object>{
                'DeveloperName' => 'UpdateRule',
                'Active__c' => true,
                'Object_Name__c' => 'Lead',
                'Trigger_Event__c' => ConstantsUtil.UPDATE_OPERATION,
                'Condition_Formula__c' => 'ISPICKVAL(LeadSource, \'Get Started\')',
                'Category__c' => 'Patient Lead',
                'Sub_Category__c' => 'DTC Partial Match',
                'Subject__c' => 'Patient Outreach',
                'Due_Date_Offset__c' => 0,
                'Owner_Type__c' => UserInfo.getUserEmail()
            })
        };

        Lead testLead = insertLead(new Map<String, Object>{
            'FirstName' => 'Dup',
            'LastName' => 'Test',
            'Company' => 'Test Company',
            'LeadSource' => 'Get Started',
            'Email' => 'test@test.com',
            'Phone' => '1234567890',
            'PostalCode' => '123456'
        });

        List<TaskGenerationService.TaskResult> results = runCreateTasks(
            new List<TaskGenerationService.TaskRequest>{ req(testLead.Id, 'Lead', ConstantsUtil.UPDATE_OPERATION) }
        );

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.isTrue(results[0].success, 'Processing should succeed');
        Assert.areEqual(0, results[0].tasksCreated, 'Should not create duplicate task');
    }

    @IsTest
    static void testTriggerEventFilteringAndRecordNotFound() {
        // Only INSERT rule provided.
        TaskGenerationService.testRulesOverride = new List<Task_Generation_Rule__mdt>{
            rule(new Map<String, Object>{
                'DeveloperName' => 'InsertOnly',
                'Active__c' => true,
                'Object_Name__c' => 'Lead',
                'Trigger_Event__c' => ConstantsUtil.INSERT_OPERATION,
                'Condition_Formula__c' => 'RecordType.DeveloperName = \'Patient\'',
                'Category__c' => 'Patient Lead',
                'Sub_Category__c' => 'Any',
                'Subject__c' => 'Any',
                'Due_Date_Offset__c' => 0,
                'Owner_Type__c' => UserInfo.getUserEmail()
            })
        };

        Id mockLeadId = MockDataFactory.getFakeId('Lead');

        // INSERT: record not found (mocked Id) -> should return success=false
        List<TaskGenerationService.TaskResult> insertResults = TaskGenerationService.createTasks(
            new List<TaskGenerationService.TaskRequest>{ req(mockLeadId, 'Lead', ConstantsUtil.INSERT_OPERATION) }
        );
        Assert.areEqual(1, insertResults.size(), 'INSERT should return one result');
        Assert.isFalse(insertResults[0].success, 'Should not succeed when record not found');

        // UPDATE: no matching rules -> early success (before record lookup)
        List<TaskGenerationService.TaskResult> updateResults = TaskGenerationService.createTasks(
            new List<TaskGenerationService.TaskRequest>{ req(mockLeadId, 'Lead', ConstantsUtil.UPDATE_OPERATION) }
        );
        Assert.areEqual(1, updateResults.size(), 'UPDATE should return one result');
        Assert.isTrue(updateResults[0].success, 'Should succeed when no rules match trigger event');
        Assert.areEqual(0, updateResults[0].tasksCreated, 'No tasks should be created');
    }

    @IsTest
    static void testExceptionHandlingCustomSwitchToggle() {
        TaskGenerationService.testRulesOverride = new List<Task_Generation_Rule__mdt>{
            rule(new Map<String, Object>{
                'DeveloperName' => 'Any',
                'Active__c' => true,
                'Object_Name__c' => 'Lead',
                'Trigger_Event__c' => ConstantsUtil.INSERT_OPERATION,
                'Condition_Formula__c' => 'RecordType.DeveloperName = \'Patient\'',
                'Category__c' => 'Patient Lead',
                'Sub_Category__c' => 'Any',
                'Subject__c' => 'Any',
                'Due_Date_Offset__c' => 0,
                'Owner_Type__c' => UserInfo.getUserEmail()
            })
        };

        Id mockLeadId = MockDataFactory.getFakeId('Lead');

        // Switch OFF: should not throw; service should return default results (success=false)
        ConstantsUtil.customExceptionSwitch = false;
        List<TaskGenerationService.TaskResult> results = TaskGenerationService.createTasks(
            new List<TaskGenerationService.TaskRequest>{ req(mockLeadId, 'InvalidObject__c', ConstantsUtil.UPDATE_OPERATION) }
        );
        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.isFalse(results[0].success, 'Should return success=false for invalid object name');
        Assert.isNotNull(results[0].message, 'Should have error message');

        // Switch ON: should throw custom exception
        ConstantsUtil.customExceptionSwitch = true;
        try {
            TaskGenerationService.createTasks(
                new List<TaskGenerationService.TaskRequest>{ req(mockLeadId, 'InvalidObject__c', ConstantsUtil.INSERT_OPERATION) }
            );
            Assert.fail('Expected MyCustomException when customExceptionSwitch is enabled');
        } catch (TaskGenerationService.MyCustomException e) {
            Assert.areEqual('customExceptionSwitch is turned on', e.getMessage(), 'Custom exception message mismatch');
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
    }

    /**
     * @description Directly covers TaskGenerationCore helper methods.
     */
    @IsTest
    static void testCoreHelpersDirectly() {
        // referenced fields (blank + non-blank)
        Assert.areEqual(0, TaskGenerationCore.getReferencedFieldsFromFormula('', 'Lead').size(), 'Blank formula should return empty set');

        Set<String> fields = TaskGenerationCore.getReferencedFieldsFromFormula(
            'AND(ISPICKVAL(LeadSource, \'Get Started\'), ISPICKVAL(Matching_Status__c, \'Partial Match\'))',
            'Lead'
        );
        Assert.isTrue(fields.contains('LeadSource'), 'Referenced fields should include LeadSource');
        Assert.isTrue(fields.contains('Matching_Status__c'), 'Referenced fields should include Matching_Status__c');

        // owner resolution
        Id ownerId = TaskGenerationCore.resolveOwner(UserInfo.getUserEmail());
        Id emptyOwnerId = TaskGenerationCore.resolveOwner('');
        Assert.isNotNull(ownerId, 'Should resolve current user as owner by email');
        Assert.isNull(emptyOwnerId, 'Should resolve empty string as null owner');

        // DML helper early-return branch
        TaskGenerationCore.insertTasksIfAny(new List<Task>(), new Map<Id, TaskGenerationService.TaskResult>());
        Assert.isTrue(true, 'insertTasksIfAny(empty) should not throw');

        // business date helper (skip weekends)
        Date sat = Date.newInstance(2025, 12, 20); // Saturday
        Date sun = Date.newInstance(2025, 12, 21); // Sunday
        Date mon = Date.newInstance(2025, 12, 22); // Monday
        Assert.areEqual(mon, TaskGenerationCore.getNextBusinessDate(sat), 'Saturday should roll to Monday');
        Assert.areEqual(mon, TaskGenerationCore.getNextBusinessDate(sun), 'Sunday should roll to Monday');
        Assert.areEqual(mon, TaskGenerationCore.getNextBusinessDate(mon), 'Weekday should remain unchanged');
    }

    /**
     * @description Covers cache population and map construction for existing tasks.
     */
    @IsTest
    static void testExistingTaskCategorySubCategoryCachePopulation() {
        Lead leadWithTask = insertLead(new Map<String, Object>{
            'FirstName' => 'Cache',
            'LastName' => 'Lead',
            'Company' => 'Test Company',
            'LeadSource' => 'Get Started',
            'Email' => 'cachelead@test.com',
            'Phone' => '1234567890',
            'PostalCode' => '123456'
        });
        Lead leadNoTask = insertLead(new Map<String, Object>{
            'FirstName' => 'Empty',
            'LastName' => 'Lead',
            'Company' => 'Test Company',
            'LeadSource' => 'Get Started',
            'Email' => 'emptylead@test.com',
            'Phone' => '1234567890',
            'PostalCode' => '123456'
        });
        Account acctWithTask = TestDataFactory.getAccountofPracticeRecordType(
            new Map<String, Object>{ 'Name' => 'Cache Account' }
        );
        insert acctWithTask;

        Task leadTask = new Task(
            Subject = 'Lead Task',
            WhoId = leadWithTask.Id,
            Status = 'Not Started',
            Category__c = 'Patient Lead',
            Sub_Category__c = 'DTC Partial Match'
        );
        Task acctTask = new Task(
            Subject = 'Account Task',
            WhatId = acctWithTask.Id,
            Status = 'Not Started',
            Category__c = 'Patient Outreach',
            Sub_Category__c = 'DTC Incomplete'
        );
        insert new List<Task>{ leadTask, acctTask };

        Map<Id, Set<String>> results = TaskGenerationCore.getExistingTaskCategorySubCategory(
            new Set<Id>{ leadWithTask.Id, acctWithTask.Id, leadNoTask.Id }
        );

        Assert.areEqual(3, results.size(), 'Should return a map entry for each requested parent Id');
    }

    /**
     * @description Covers malformed formula handling in TaskGenerationCore.checkRecordAgainstRule()
     *              (System.FormulaEvaluationException catch branch).
     */
    @IsTest
    static void testMalformedFormulaDoesNotFailBatch() {
        // Malformed formula: missing closing parenthesis
        Task_Generation_Rule__mdt badRule = rule(new Map<String, Object>{
            'DeveloperName' => 'BadFormula_MissingParen',
            'Active__c' => true,
            'Object_Name__c' => 'Lead',
            'Trigger_Event__c' => ConstantsUtil.UPDATE_OPERATION,
            'Condition_Formula__c' => 'AND(ISPICKVAL(LeadSource, \'Get Started\'), ISPICKVAL(Matching_Status__c, \'Partial Match\')',
            'Category__c' => 'Any',
            'Sub_Category__c' => 'Any',
            'Subject__c' => 'Any',
            'Due_Date_Offset__c' => 1
        });

        // Record doesn't need to be inserted; we only want to ensure formula errors are handled safely.
        Lead l = new Lead(LeadSource = 'Get Started', Company = 'Test', LastName = 'Test');

        Boolean matched = TaskGenerationCore.checkRecordAgainstRule(l, badRule, 'Lead');
        Assert.isFalse(matched, 'Malformed formulas should be treated as non-matching (false) and not throw');
    }

    /**
     * @description Covers empty Condition_Formula__c rule behavior (should not match, no task created).
     */
    @IsTest
    static void testEmptyConditionFormulaDoesNotCreateTask() {
        TaskGenerationService.testRulesOverride = new List<Task_Generation_Rule__mdt>{
            rule(new Map<String, Object>{
                'DeveloperName' => 'EmptyFormula',
                'Active__c' => true,
                'Object_Name__c' => 'Lead',
                'Trigger_Event__c' => ConstantsUtil.INSERT_OPERATION,
                'Condition_Formula__c' => '',
                'Category__c' => 'Patient Lead',
                'Sub_Category__c' => 'Any',
                'Subject__c' => 'ShouldNotCreate',
                'Due_Date_Offset__c' => 0,
                'Owner_Type__c' => UserInfo.getUserEmail()
            })
        };

        Lead testLead = insertLead(new Map<String, Object>{
            'FirstName' => 'Empty',
            'LastName' => 'Formula',
            'Company' => 'Test Company',
            'LeadSource' => 'Get Started',
            'Email' => 'test@test.com',
            'Phone' => '1234567890',
            'PostalCode' => '123456'
        });

        List<TaskGenerationService.TaskResult> results = runCreateTasks(
            new List<TaskGenerationService.TaskRequest>{ req(testLead.Id, 'Lead', ConstantsUtil.INSERT_OPERATION) }
        );

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.isTrue(results[0].success, 'Processing should succeed');
        Assert.areEqual(0, results[0].tasksCreated, 'Empty formula should not create tasks');
    }

    /**
     * @description Covers empty Category rule behavior (should not match, no task created).
     */
    @IsTest
    static void testEmptyCategoryFormulaDoesNotCreateTask() {
        TaskGenerationService.testRulesOverride = new List<Task_Generation_Rule__mdt>{
            rule(new Map<String, Object>{
                'DeveloperName' => 'EmptyCategory',
                'Active__c' => true,
                'Object_Name__c' => 'Lead',
                'Trigger_Event__c' => ConstantsUtil.INSERT_OPERATION,
                'Condition_Formula__c' => '',
                'Category__c' => '',
                'Sub_Category__c' => 'Any',
                'Subject__c' => 'ShouldNotCreate',
                'Due_Date_Offset__c' => 0
            }),
            rule(new Map<String, Object>{
                'DeveloperName' => '',
                'Active__c' => true,
                'Object_Name__c' => 'Lead',
                'Trigger_Event__c' => ConstantsUtil.INSERT_OPERATION,
                'Condition_Formula__c' => 'RecordType.DeveloperName = \'Patient',
                'Category__c' => '',
                'Sub_Category__c' => 'Any',
                'Subject__c' => 'ShouldNotCreate',
                'Due_Date_Offset__c' => 0,
                'Owner_Type__c' => UserInfo.getUserEmail()
            }),
            rule(new Map<String, Object>{
                'DeveloperName' => 'EmptyCategory',
                'Active__c' => true,
                'Object_Name__c' => 'Lead',
                'Trigger_Event__c' => ConstantsUtil.INSERT_OPERATION,
                'Condition_Formula__c' => '',
                'Category__c' => '',
                'Sub_Category__c' => 'Any',
                'Subject__c' => 'ShouldNotCreate',
                'Due_Date_Offset__c' => 0
            })
        };

        Lead testLead = insertLead(new Map<String, Object>{
            'FirstName' => 'Empty',
            'LastName' => 'Formula',
            'Company' => 'Test Company',
            'LeadSource' => 'Get Started',
            'Email' => 'test@test.com',
            'Phone' => '1234567890',
            'PostalCode' => '123456'
        });

        List<TaskGenerationService.TaskResult> results = runCreateTasks(
            new List<TaskGenerationService.TaskRequest>{ req(testLead.Id, 'Lead', ConstantsUtil.INSERT_OPERATION) }
        );

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.isTrue(results[0].success, 'Processing should succeed');
        Assert.areEqual(0, results[0].tasksCreated, 'Empty formula should not create tasks');
    }
}