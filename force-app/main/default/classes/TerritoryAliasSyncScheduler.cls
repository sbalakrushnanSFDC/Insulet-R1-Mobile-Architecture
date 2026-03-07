/**
 * @description Schedulable class to run TerritoryAliasSyncBatch daily.
 *              This scheduler executes the batch job that syncs Territory_Alias__c
 *              from Practice accounts to Patient accounts based on AccountHistory changes.
 *
 * @author      Niranjan Elangovan
 * @createdDate November 16, 2025
 *
 * Usage:
 * Schedule this class to run daily using the following code in Anonymous Apex:
 *
 * // Schedule to run daily at 2 AM
 * String cronExp = '0 0 2 * * ?';
 * String jobName = 'Daily Territory Alias Sync';
 * TerritoryAliasSyncScheduler scheduler = new TerritoryAliasSyncScheduler();
 * System.schedule(jobName, cronExp, scheduler);
 *
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Nov 16, 2025        Niranjan Elangovan      Initial Version
 */
public without sharing class TerritoryAliasSyncScheduler implements Schedulable {
    private static final String TAG_NAME = 'TerritoryAliasSyncScheduler';
    private static final String BATCH_CLASS_NAME = 'TerritoryAliasSyncBatch';
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
            // Get batch size from Custom Metadata
            Integer batchSize = BatchConfigurationUtil.getBatchSize(BATCH_CLASS_NAME);
            // Instantiate and execute the batch
            TerritoryAliasSyncBatch batch = new TerritoryAliasSyncBatch();
            Id batchId = Database.executeBatch(batch, batchSize);
            Logger.info('TerritoryAliasSyncBatch started successfully with batch size: ' + batchSize + ', Batch ID: ' + batchId)
                .addTag(TAG_NAME);
        } catch (Exception e) {
            Logger.error('Exception in TerritoryAliasSyncScheduler: ' + e.getMessage(), e)
                .addTag(TAG_NAME);
        }
    }
    /**
     * @description Custom exception class for scheduler
     */
    public class SchedulerException extends Exception {}
}