/**
 * @description Scheduler class to run DTCIncompleteTaskBatch hourly.
 *              Fetches configuration from Batch_Configuration__mdt Custom Metadata (Wait Time After Creation,
 *              Processing Window, Batch Size) and passes them to the batch job.
 *              Replaces the time-based flow Lead_After_Insert (NGASIM-1273).
 * @author Jatin Butta
 * @created Date 11th Dec 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Dec 2025       Jatin Butta             Initial Version(US - NGASIM-1273)
 * V1.1.0       Dec 19, 2025        Anup Bandawar           Added Custom Metadata support for time windows
 * =======================================================================
 *
 * Usage:
 * Schedule this class to run hourly using the following code in Anonymous Apex:
 *
 * // Schedule to run every hour (processes Leads based on Custom Metadata configuration)
 * String cronExp = '0 0 * * * ?';
 * String jobName = 'Hourly DTC Incomplete Task Batch';
 * DTCIncompleteTaskScheduler scheduler = new DTCIncompleteTaskScheduler();
 * System.schedule(jobName, cronExp, scheduler);
 */
public class DTCIncompleteTaskScheduler implements Schedulable {
    private static final String TAG_NAME = 'DTCIncompleteTaskScheduler';
    private static final String BATCH_CLASS_NAME = 'DTCIncompleteTaskBatch';
    @TestVisible private static Boolean forceException = false;

    /**
     * @description Execute method called by the scheduler
     * @param sc SchedulableContext
     */
    public void execute(SchedulableContext sc) {
        try {
            // Test flag to force exception for code coverage
            if (Test.isRunningTest() && forceException) {
                throw new SchedulerException('Forced exception for testing');
            }

            // Get batch size from Custom Metadata, default to 200 if not configured
            Integer batchSize = BatchConfigurationUtil.getBatchSize(BATCH_CLASS_NAME);
            if (batchSize == null || batchSize <= 0) {
                batchSize = 200;
            }

            // Get wait time and processing window from Custom Metadata
            Integer waitTimeMinutes = BatchConfigurationUtil.getWaitTimeAfterCreation(BATCH_CLASS_NAME);
            Integer processingWindowMinutes = BatchConfigurationUtil.getProcessingWindow(BATCH_CLASS_NAME);

            // Instantiate and execute the batch with metadata-driven time windows
            DTCIncompleteTaskBatch batch = new DTCIncompleteTaskBatch(waitTimeMinutes, processingWindowMinutes);
            Id batchId = Database.executeBatch(batch, batchSize);

            Logger.info('DTCIncompleteTaskBatch started successfully. Batch Size: ' + batchSize +
                       ', Wait Time: ' + waitTimeMinutes + ' min, Window: ' + processingWindowMinutes +
                       ' min, Batch ID: ' + batchId)
                .addTag(TAG_NAME);
            Logger.saveLog();
        } catch (Exception e) {
            Logger.error('Exception in DTCIncompleteTaskScheduler: ' + e.getMessage(), e)
                .addTag(TAG_NAME);
            Logger.saveLog();
        }
    }

    /**
     * @description Custom exception class for scheduler
     */
    public class SchedulerException extends Exception {}
}