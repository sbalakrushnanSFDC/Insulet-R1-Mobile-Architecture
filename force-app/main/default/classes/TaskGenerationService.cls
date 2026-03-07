/**
 * @description Service class for automated task generation based on Custom Metadata rules.
 *              Uses FormulaEval API for dynamic condition evaluation and supports bulk operations.
 * @author Jatin Butta
 * @created Date 11th Dec 2025
 */
public inherited sharing class TaskGenerationService {
    private static final String TAG_NAME = 'TaskGenerationService';

    /**
     * @description Test-only rule injection to avoid depending on org metadata in unit tests.
     *              When set (and tests are running), the service will use these rules instead of querying CMDT.
     */
    @TestVisible
    private static List<Task_Generation_Rule__mdt> testRulesOverride;

    /**
     * @description Wrapper class for Task Generation requests.
     */
    public class TaskRequest {
        @InvocableVariable(required=true label='Record ID' description='ID of the record to process')
        public Id recordId;

        @InvocableVariable(required=true label='Object API Name' description='API name of the object (e.g., Lead, Account)')
        public String objectApiName;

        @InvocableVariable(required=false label='Trigger Event' description='Event type: INSERT or UPDATE')
        public String triggerEvent;
    }

    /**
     * @description Wrapper class for Task Generation results.
     */
    public class TaskResult {
        @InvocableVariable(label='Success' description='Whether the operation was successful')
        public Boolean success = false;

        @InvocableVariable(label='Message' description='Result message or error description')
        public String message;

        @InvocableVariable(label='Tasks Created' description='Number of tasks created for this request')
        public Integer tasksCreated = 0;

        @InvocableVariable(label='Task IDs' description='IDs of created tasks')
        public List<Id> taskIds = new List<Id>();
    }

    /**
     * @description Main entry point: generates tasks for the given requests.
     * @param requests Task generation requests
     * @return Per-request results
     */
    public static List<TaskResult> createTasks(List<TaskRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            Logger.warn(ConstantsUtil.TASK_GEN_ERROR_EMPTY_REQUEST).addTag(TAG_NAME);
            Logger.saveLog();
            return new List<TaskResult>();
        }

        try {
            List<TaskResult> results = TaskGenerationProcessor.process(requests, testRulesOverride);
            Logger.saveLog();
            return results;
        } catch (Exception e) {
            /**
             * When ConstantsUtil.customExceptionSwitch is enabled in tests, throw a deterministic exception
             * to exercise exception paths and improve coverage.
             */
            if (ConstantsUtil.customExceptionSwitch && Test.isRunningTest()) {
                throw new MyCustomException('customExceptionSwitch is turned on');
            }

            String errorMsg = ConstantsUtil.TASK_GEN_ERROR_PROCESSING_BATCH + ' ' + e.getMessage();
            Logger.error(errorMsg, e).addTag(TAG_NAME);
            Logger.saveLog();
            return TaskGenerationCore.generateDefaultResults(requests, false, errorMsg);
        }
    }

    /**
     * @description Exception class for Task Generation Service.
     */
    public class MyCustomException extends Exception {}
}