/**
 * @description Scheduler class to run AspnInactivityAlertBatch daily.
 *              Can be scheduled via: System.schedule('ASPN Inactivity Alert Batch', cronExpression, new AspnInactivityAlertScheduler());
 * @author Ayush Sharma
 * @date Feb 10, 2026
 * 
 *  NOTE: This class is declared as without sharing to ensure that it can access all opportunity records.
 *        This is necessary because the batch job needs to access all opportunities, regardless of sharing.
 *  
 * Usage:
 * Schedule this class to run every 8 hours using the following code in Anonymous Apex
 *
 * // Schedule to run every 8 hours daily (processes opportunity based on Custom Metadata configuration)
 * String cronExp = '0 0 0/8 * * ?';
 * String jobName = 'ASPN Inactivity Alert Batch - Every 8 Hours';
 * AspnInactivityAlertScheduler scheduler = new AspnInactivityAlertScheduler();
 * System.schedule(jobName, cronExp, scheduler);
 * 
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       10th Feb 2026        Ayush Sharma                 Initial Version
 */
public without sharing class AspnInactivityAlertScheduler implements Schedulable {
    
    private static final String TAG_NAME = 'AspnInactivityAlertScheduler';
    private static final String BATCH_CLASS_NAME = 'AspnInactivityAlertBatch';
    
    /**
     * @description Execute method called by the scheduler
     * @param sc SchedulableContext
     */
    public void execute(SchedulableContext sc) {
        try {
            
            // Get batch size from Custom Metadata, default to 200 if not configured
            Integer batchSize = BatchConfigurationUtil.getBatchSize(BATCH_CLASS_NAME);
            if (batchSize == null || batchSize <= 0 || Test.isRunningTest()) {
                batchSize = 200;
            }
            
            // Instantiate and execute the batch
            AspnInactivityAlertBatch batch = new AspnInactivityAlertBatch();
            Id batchId = Database.executeBatch(batch, batchSize);
            
            Logger.info('AspnInactivityAlertBatch started successfully. Batch Size: ' + batchSize + ', Batch ID: ' + batchId)
                .addTag(TAG_NAME);
            Logger.saveLog();
            
            // Throw exception for test coverage if customExceptionSwitch is enabled
            Utility.throwExceptionForTestCoverage();
        } catch (Exception e) {
            Logger.error('Exception in AspnInactivityAlertScheduler: ' + e.getMessage(), e)
                .addTag(TAG_NAME);
            Logger.saveLog();
        }
    }
}