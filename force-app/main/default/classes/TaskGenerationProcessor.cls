/**
 * @description Orchestrates task generation across rule retrieval, record queries, rule evaluation, and task insertion.
 *              Coordinates the workflow: fetch rules, query records, evaluate rules, build tasks, and insert them.
 *              Supports creating multiple tasks per record when multiple rules match, while preventing duplicates
 *              by Category + Sub-Category for existing open tasks.
 *              Part of TaskGenerationService refactoring to reduce cyclomatic complexity (NGASIM-1273).
 * @author Jatin Butta
 * @created Date 11th Dec 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Dec 2025       Jatin Butta             Initial Version(US - NGASIM-1273)
 * =======================================================================
 */
public inherited sharing class TaskGenerationProcessor {
    private static final String TAG_NAME = 'TaskGenerationProcessor';

    /**
     * @description Wrapper for record maps used during processing.
     */
    private class RecordMapsContext {
        private Map<Id, SObject> recordsMap;
        private Map<Id, Set<String>> existingTaskMap;

        private RecordMapsContext(Map<Id, SObject> recordsMap, Map<Id, Set<String>> existingTaskMap) {
            this.recordsMap = recordsMap;
            this.existingTaskMap = existingTaskMap;
        }
    }

    /**
     * @description Wrapper for rule evaluation context used during processing.
     */
    private class RuleEvalContext {
        private List<Task_Generation_Rule__mdt> rules;
        private String objectApiName;
        private List<Task> tasksToInsert;

        private RuleEvalContext(List<Task_Generation_Rule__mdt> rules, String objectApiName, List<Task> tasksToInsert) {
            this.rules = rules;
            this.objectApiName = objectApiName;
            this.tasksToInsert = tasksToInsert;
        }
    }

    /**
     * @description Wrapper for all processing dependencies.
     */
    private class ProcessingContext {
        private RecordMapsContext recordMapsContext;
        private RuleEvalContext ruleEvalContext;

        private ProcessingContext(RecordMapsContext recordMapsContext, RuleEvalContext ruleEvalContext) {
            this.recordMapsContext = recordMapsContext;
            this.ruleEvalContext = ruleEvalContext;
        }
    }

    /**
     * @description Processes task requests and returns results (does not throw unless dependencies throw).
     * @param requests Incoming task requests
     * @param testRulesOverride Test-only rule override list (may be null)
     * @return Per-request results
     */
    public static List<TaskGenerationService.TaskResult> process(
        List<TaskGenerationService.TaskRequest> requests,
        List<Task_Generation_Rule__mdt> testRulesOverride
    ) {
        String objectApiName = requests[0].objectApiName;
        String triggerEvent = requests[0].triggerEvent;

        TaskGenerationRecordQuery.validateObjectApiName(objectApiName);

        List<Task_Generation_Rule__mdt> rules = TaskGenerationCore.queryActiveRules(
            objectApiName,
            triggerEvent,
            testRulesOverride
        );

        if (rules.isEmpty()) {
            String logMessage = String.isNotBlank(triggerEvent)
                ? 'No active rules found for trigger event: ' + triggerEvent
                : ConstantsUtil.TASK_GEN_ERROR_NO_ACTIVE_RULES;
            String resultMessage = String.isNotBlank(triggerEvent)
                ? ConstantsUtil.TASK_GEN_ERROR_NO_RULES_FOR_TRIGGER_EVENT
                : ConstantsUtil.TASK_GEN_ERROR_NO_ACTIVE_RULES;

            Logger.info(logMessage).addTag(TAG_NAME);
            return TaskGenerationCore.generateDefaultResults(requests, true, resultMessage);
        }

        Map<Id, SObject> recordsMap = TaskGenerationRecordQuery.queryMatchingRecords(requests, rules, objectApiName);
        Map<Id, Set<String>> existingTaskMap = TaskGenerationCore.getExistingTaskCategorySubCategory(recordsMap.keySet());

        List<Task> tasksToInsert = new List<Task>();
        List<TaskGenerationService.TaskResult> finalResults = new List<TaskGenerationService.TaskResult>();
        Map<Id, TaskGenerationService.TaskResult> resultsByRecordId = new Map<Id, TaskGenerationService.TaskResult>();

        ProcessingContext context = new ProcessingContext(
            new RecordMapsContext(recordsMap, existingTaskMap),
            new RuleEvalContext(rules, objectApiName, tasksToInsert)
        );

        for (TaskGenerationService.TaskRequest request : requests) {
            TaskGenerationService.TaskResult r = processSingleRequest(request, context);
            finalResults.add(r);
            resultsByRecordId.put(request.recordId, r);
        }

        TaskGenerationCore.insertTasksIfAny(tasksToInsert, resultsByRecordId);
        return finalResults;
    }

    private static TaskGenerationService.TaskResult processSingleRequest(
        TaskGenerationService.TaskRequest request,
        ProcessingContext context
    ) {
        TaskGenerationService.TaskResult result = new TaskGenerationService.TaskResult();
        SObject record = context.recordMapsContext.recordsMap.get(request.recordId);

        if (record == null) {
            result.message = ConstantsUtil.TASK_GEN_ERROR_RECORD_NOT_MATCH;
            Logger.warn(result.message + ' Record ID: ' + request.recordId).addTag(TAG_NAME);
            return result;
        }

        // Ensure we store the working set back into the shared map so duplicates are prevented
        // even if the same record appears multiple times in the incoming requests.
        Set<String> existingTaskKeys;
        if (context.recordMapsContext.existingTaskMap.containsKey(request.recordId)) {
            existingTaskKeys = context.recordMapsContext.existingTaskMap.get(request.recordId);
        } else {
            existingTaskKeys = new Set<String>();
            context.recordMapsContext.existingTaskMap.put(request.recordId, existingTaskKeys);
        }

        for (Task_Generation_Rule__mdt rule : context.ruleEvalContext.rules) {
            if (!TaskGenerationCore.checkRecordAgainstRule(record, rule, context.ruleEvalContext.objectApiName)) { continue; }
            String taskKey = rule.Category__c + '|' + rule.Sub_Category__c;
            if (existingTaskKeys.contains(taskKey)) { continue; }
            context.ruleEvalContext.tasksToInsert.add(TaskGenerationTaskBuilder.constructTask(record, rule, request.recordId));
            existingTaskKeys.add(taskKey);
            result.tasksCreated++;
        }

        result.success = true;
        result.message = 'Tasks processed. Created ' + result.tasksCreated + ' task(s).';
        return result;
    }
}