/**
 * @description Consolidated core services for TaskGenerationService.
 *              Contains rule retrieval (CMDT), formula evaluation, owner resolution, DML handling,
 *              and date calculations.
 *              Part of TaskGenerationService refactoring (NGASIM-1273).
 * @author Jatin Butta
 * @created Date 11th Dec 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Dec 2025       Jatin Butta             Initial Version(US - NGASIM-1273)
 * V1.0.1       04th Feb 2026       Jatin Butta             Fix for lead conversion(101 SOQL issue).
 * =======================================================================
 */
public inherited sharing class TaskGenerationCore {
    private static final String TAG_NAME = 'TaskGenerationCore';

    // ---------------------------- DATE HELPERS ----------------------------
    /**
     * @description Returns the next business date, skipping weekends (Saturday/Sunday).
     *              If the provided date falls on Saturday, returns the following Monday.
     *              If it falls on Sunday, returns the following Monday.
     *              Otherwise, returns the original date.
     * @param targetDate Date to normalize to a business day
     * @return Next business date (weekend-skipped)
     */
    public static Date getNextBusinessDate(Date targetDate) {
        if (targetDate == null) { return null; }

        // Apex Date doesn't reliably expose a day-of-week helper in all orgs/APIs; derive day-of-week from a DateTime instead.
        // ISO day-of-week via format('u'): 1 = Monday ... 6 = Saturday, 7 = Sunday
        DateTime dt = DateTime.newInstance(targetDate, Time.newInstance(0, 0, 0, 0));
        Integer isoDow = Integer.valueOf(dt.format('u'));
        if (isoDow == 6) { // Saturday
            return targetDate.addDays(2);
        }
        if (isoDow == 7) { // Sunday
            return targetDate.addDays(1);
        }
        return targetDate;
    }

    // ---------------------------- RULE REPOSITORY ----------------------------
    /**
     * @description Returns active Task Generation Rules from Custom Metadata (via getAll()) or uses test overrides when provided.
     * @param objectApiName API name of the target object
     * @param triggerEvent Optional trigger event filter (INSERT or UPDATE). If blank, returns all active rules for the object.
     * @param testRulesOverride Test-only rule overrides (may be null)
     * @return List of active task generation rules matching the specified criteria
     */
    public static List<Task_Generation_Rule__mdt> queryActiveRules(
        String objectApiName,
        String triggerEvent,
        List<Task_Generation_Rule__mdt> testRulesOverride
    ) {
        if (Test.isRunningTest() && testRulesOverride != null) {
            return filterTestRules(objectApiName,
                                    triggerEvent,
                                    testRulesOverride);
        }

        // Use Custom Metadata getAll() to avoid SOQL and avoid PMD ApexCRUDViolation for metadata queries.
        // Note: getAll() returns a Map; iteration order is not guaranteed. We sort by DeveloperName to ensure deterministic behavior.
        Map<String, Task_Generation_Rule__mdt> allRules = Task_Generation_Rule__mdt.getAll();
        List<Task_Generation_Rule__mdt> filtered = new List<Task_Generation_Rule__mdt>();
        for (Task_Generation_Rule__mdt rule : allRules.values()) {
            if (isRuleMatchingCriteria(rule, objectApiName, triggerEvent)) {
                filtered.add(rule);
            }
        }
        filtered.sort(new RuleDeveloperNameComparator());
        return filtered;
    }

    /**
     * @description Comparator for deterministic rule ordering.
     */
    private class RuleDeveloperNameComparator implements Comparator<Task_Generation_Rule__mdt> {
        /**
         * @description Compares two rules by DeveloperName in a case-insensitive manner for deterministic ordering.
         * @param a First rule
         * @param b Second rule
         * @return Negative if a < b, zero if equal, positive if a > b
         */
        public Integer compare(Task_Generation_Rule__mdt a, Task_Generation_Rule__mdt b) {
            String an = a != null ? a.DeveloperName : null;
            String bn = b != null ? b.DeveloperName : null;
            if (an == bn) { return 0; }
            if (an == null) { return -1; }
            if (bn == null) { return 1; }
            // Apex String doesn't support compareToIgnoreCase; normalize case for deterministic ordering.
            return an.toLowerCase().compareTo(bn.toLowerCase());
        }
    }

    private static List<Task_Generation_Rule__mdt> filterTestRules(
        String objectApiName,
        String triggerEvent,
        List<Task_Generation_Rule__mdt> testRulesOverride
    ) {
        List<Task_Generation_Rule__mdt> filtered = new List<Task_Generation_Rule__mdt>();
        for (Task_Generation_Rule__mdt rule : testRulesOverride) {
            if (isRuleMatchingCriteria(rule, objectApiName, triggerEvent)) {
                filtered.add(rule);
            }
        }
        return filtered;
    }

    private static Boolean isRuleMatchingCriteria(Task_Generation_Rule__mdt rule, String objectApiName, String triggerEvent) {
        if (rule == null || rule.Active__c != true || rule.Object_Name__c != objectApiName) { return false; }
        return (String.isBlank(triggerEvent) || String.isBlank(rule.Trigger_Event__c) || rule.Trigger_Event__c == triggerEvent);
    }

    // ---------------------------- RESULT FACTORY ----------------------------
    /**
     * @description Generates default TaskResult objects for all requests with the same message.
     * @param requests List of task requests
     * @param success Whether the operation was successful
     * @param message Message to include in all results
     * @return List of TaskResult objects
     */
    public static List<TaskGenerationService.TaskResult> generateDefaultResults(List<TaskGenerationService.TaskRequest> requests
                                                                                ,Boolean success
                                                                                ,String message
    ) {
        List<TaskGenerationService.TaskResult> results = new List<TaskGenerationService.TaskResult>();
        for (TaskGenerationService.TaskRequest req : requests) {
            TaskGenerationService.TaskResult result = new TaskGenerationService.TaskResult();
            result.success = success;
            result.message = message;
            results.add(result);
        }
        return results;
    }

    // ---------------------------- EXISTING TASK SERVICE ----------------------------
    // Cache for getExistingTaskCategorySubCategory results within a transaction
    private static Map<Id, Set<String>> existingTaskCategorySubCategoryCache = new Map<Id, Set<String>>();

    /**
     * @description Retrieves existing open/incomplete tasks for the specified records.
     *              Uses caching to ensure query runs only once per transaction.
     * @param parentRecordIds Set of parent record IDs
     * @return Map of parent record ID to Set of existing task keys (Category|Sub-category)
     */
    public static Map<Id, Set<String>> getExistingTaskCategorySubCategory(Set<Id> parentRecordIds) {
        Map<Id, Set<String>> existingTaskMap = new Map<Id, Set<String>>();
        if (parentRecordIds == null || parentRecordIds.isEmpty()) {
            return existingTaskMap;
        }

        // Check cache for already queried parent record IDs
        Set<Id> parentRecordIdsToQuery = new Set<Id>();
        for (Id parentId : parentRecordIds) {
            if (existingTaskCategorySubCategoryCache.containsKey(parentId)) {
                existingTaskMap.put(parentId, existingTaskCategorySubCategoryCache.get(parentId));
            } else {
                parentRecordIdsToQuery.add(parentId);
            }
        }

        // Query only parent record IDs not in cache
        if (!parentRecordIdsToQuery.isEmpty()) {
            List<Task> existingTasks = [
                SELECT Category__c, Sub_Category__c, WhatId, WhoId
                FROM Task
                WHERE (WhatId IN :parentRecordIdsToQuery OR WhoId IN :parentRecordIdsToQuery)
                AND Status != :ConstantsUtil.TASK_STATUS_COMPLETED
                AND Status != :ConstantsUtil.TASK_STATUS_CLOSED
                WITH SYSTEM_MODE
            ];

            Map<Id, Set<String>> newlyQueriedMap = new Map<Id, Set<String>>();
            for (Task t : existingTasks) {
                Id parentId = (t.WhoId != null && parentRecordIdsToQuery.contains(t.WhoId)) ? t.WhoId : t.WhatId;
                if (parentId == null || String.isBlank(t.Category__c) || String.isBlank(t.Sub_Category__c)) { continue; }

                if (!newlyQueriedMap.containsKey(parentId)) {
                    newlyQueriedMap.put(parentId, new Set<String>());
                }
                newlyQueriedMap.get(parentId).add(t.Category__c + '|' + t.Sub_Category__c);
            }

            // Add newly queried results to cache and result map
            for (Id parentId : newlyQueriedMap.keySet()) {
                existingTaskCategorySubCategoryCache.put(parentId, newlyQueriedMap.get(parentId));
                existingTaskMap.put(parentId, newlyQueriedMap.get(parentId));
            }

            // Ensure all requested parent IDs are in the result map (even if no tasks found)
            for (Id parentId : parentRecordIdsToQuery) {
                if (!existingTaskMap.containsKey(parentId)) {
                    Set<String> emptySet = new Set<String>();
                    existingTaskCategorySubCategoryCache.put(parentId, emptySet);
                    existingTaskMap.put(parentId, emptySet);
                }
            }
        }

        return existingTaskMap;
    }

    // ---------------------------- RULE EVALUATOR ----------------------------
    /**
     * @description Evaluates a record against a rule using FormulaEval API.
     *              Supports RecordType checks using: RecordType.DeveloperName = 'Value'
     *              Any formula parse/evaluation errors are logged and treated as "no match" (false)
     *              to avoid failing the entire batch due to a malformed CMDT formula.
     * @param record SObject record to evaluate
     * @param rule Task Generation Rule metadata
     * @param objectApiName API name of the object being evaluated
     * @return True if record matches the rule condition, false otherwise
     */
    public static Boolean checkRecordAgainstRule(SObject record, Task_Generation_Rule__mdt rule, String objectApiName) {
        if (String.isBlank(rule.Condition_Formula__c)) {
            String ruleName = String.isNotBlank(rule.DeveloperName) ? rule.DeveloperName : 'Unknown';
            Logger.warn('Empty condition formula for rule: ' + ruleName).addTag(TAG_NAME);
            return false;
        }
        if (!Schema.getGlobalDescribe().containsKey(objectApiName)) { return false; }

        try {
            formulaeval.FormulaInstance formula = Formula.builder()
                .withType(Schema.getGlobalDescribe().get(objectApiName))
                .withFormula(rule.Condition_Formula__c)
                .withReturnType(formulaeval.FormulaReturnType.BOOLEAN)
                .build();

            Object result = formula.evaluate(record);
            return result != null ? (Boolean)result : false;
        } catch (System.FormulaEvaluationException e) { String ruleName = String.isNotBlank(rule.DeveloperName) ? rule.DeveloperName : 'Unknown';
            Logger.error('Formula evaluation error for Task_Generation_Rule__mdt rule: ' + ruleName + '. Formula: ' + rule.Condition_Formula__c + '. Error: ' + e.getMessage(), e).addTag(TAG_NAME);
            return false;
        } catch (Exception e) {
            String ruleName = String.isNotBlank(rule.DeveloperName) ? rule.DeveloperName : 'Unknown';
            Logger.error('Unexpected error evaluating formula for Task_Generation_Rule__mdt rule: '
                         + ruleName +'. Error: '
                         + e.getMessage(), e)
                .addTag(TAG_NAME);
            return false;
        }
    }

    /**
     * @description Extracts all fields referenced in a formula dynamically.
     *              If the formula cannot be parsed (e.g., syntax error / missing parenthesis),
     *              returns an empty set and logs a warning so record querying can fall back safely.
     * @param formulaText Formula expression text
     * @param objectApiName API name of the object
     * @return Set of field API names referenced in the formula
     */
    public static Set<String> getReferencedFieldsFromFormula(String formulaText, String objectApiName) {
        if (String.isBlank(formulaText)) {
            return new Set<String>();
        }
        if (!Schema.getGlobalDescribe().containsKey(objectApiName)) { return new Set<String>(); }

        try {
            formulaeval.FormulaInstance formula = Formula.builder()
                .withType(Schema.getGlobalDescribe().get(objectApiName))
                .withFormula(formulaText)
                .withReturnType(formulaeval.FormulaReturnType.BOOLEAN)
                .build();

            return formula.getReferencedFields();
        } catch (Exception e) {
            Logger.warn('Error parsing formula for field extraction: ' + e.getMessage())
                .addTag(TAG_NAME);
            return new Set<String>();
        }
    }

    // ---------------------------- OWNER RESOLVER ----------------------------
    private static final Map<String, Id> OWNER_CACHE = new Map<String, Id>();

    /**
     * @description Resolves task owner ID based on owner identifier (Queue name, User name, or Email).
     * @param ownerIdentifier Owner name or identifier from Custom Metadata
     * @return Id of the resolved owner (Queue or User), or null if not found
     */
    public static Id resolveOwner(String ownerIdentifier) {
        if (String.isBlank(ownerIdentifier)) {
            return null;
        }
        if (OWNER_CACHE.containsKey(ownerIdentifier)) { return OWNER_CACHE.get(ownerIdentifier); }

        Id ownerId = findOwnerByIdentifier(ownerIdentifier);
        cacheOwnerResult(ownerIdentifier, ownerId);
        return ownerId;
    }

    private static Id findOwnerByIdentifier(String ownerIdentifier) {
        Id ownerId = findQueueByIdentifier(ownerIdentifier);
        return (ownerId == null
            ? findUserByIdentifier(ownerIdentifier) : ownerId);
    }

    private static Id findQueueByIdentifier(String ownerIdentifier) {
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :ownerIdentifier AND Type = :ConstantsUtil.GROUP_TYPE_QUEUE
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return queues.isEmpty() ? null : queues[0].Id;
    }

    private static Id findUserByIdentifier(String ownerIdentifier) {
        List<User> users = [
            SELECT Id
            FROM User
            WHERE Name = :ownerIdentifier OR Email = :ownerIdentifier
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return (users.isEmpty() ? null : users[0].Id);
    }

    private static void cacheOwnerResult(String ownerIdentifier, Id ownerId) {
        if (ownerId != null) {
            OWNER_CACHE.put(ownerIdentifier, ownerId);
        } else { Logger.warn('Task owner not found for identifier: ' + ownerIdentifier).addTag(TAG_NAME); }
    }

    // ---------------------------- DML SERVICE ----------------------------
    /**
     * @description Inserts tasks (if any) and updates results with DML outcomes.
     * @param tasksToInsert Tasks to insert
     * @param resultsByRecordId Per-record results keyed by record Id, to update with created Task Ids / errors
     */
    public static void insertTasksIfAny(List<Task> tasksToInsert, Map<Id, TaskGenerationService.TaskResult> resultsByRecordId) {
        if (tasksToInsert == null || tasksToInsert.isEmpty()) {
            return;
        }

        Database.SaveResult[] srList = Database.insert(tasksToInsert, false, AccessLevel.SYSTEM_MODE);
        processDmlResults(tasksToInsert, resultsByRecordId, srList);
        Logger.info('Successfully created ' + tasksToInsert.size() + ' task(s)').addTag(TAG_NAME);
    }

    private static void processDmlResults(
        List<Task> tasksToInsert,
        Map<Id, TaskGenerationService.TaskResult> resultsByRecordId,
        List<Database.SaveResult> srList
    ) {
        Integer sizeToProcess = Math.min(tasksToInsert.size(), srList.size());
        for (Integer i = 0; i < sizeToProcess; i++) {
            Task attempted = tasksToInsert[i];
            Database.SaveResult sr = srList[i];

            if (sr.isSuccess()) {
                Id parentId = (attempted.WhoId != null)
                    ? attempted.WhoId : attempted.WhatId;
                if (parentId != null && resultsByRecordId != null && resultsByRecordId.containsKey(parentId)) {
                    resultsByRecordId.get(parentId).taskIds.add(sr.getId());
                }
            } else {
                for (Database.Error err : sr.getErrors()) { Logger.error('Failed to insert task: ' + err.getMessage() + ' Fields: ' + err.getFields()).addTag(TAG_NAME); }
            }
        }
    }
}