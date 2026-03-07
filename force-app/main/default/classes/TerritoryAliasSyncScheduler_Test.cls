/**
 * @description Test class for TerritoryAliasSyncScheduler
 *              Uses TestDataFactory for consistent test data creation,Is parallel is not allowed on the current method
 *
 * @author      Niranjan Elangovan
 * @createdDate November 16, 2025
 *
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Nov 16, 2025        Niranjan Elangovan      Initial Version
 * V1.0.1       Nov 16, 2025        Niranjan Elangovan      Updated to use TestDataFactory
 * V1.0.2       Nov 16, 2025        Niranjan Elangovan      Added System.runAs for PMD compliance
 */
@isTest
private class TerritoryAliasSyncScheduler_Test {
    /**
     * @description Test scheduler executes successfully
     */
    @isTest
    static void testSchedulerExecution() {
        User testUser = TestDataFactory.getTestUser();
        insert testUser;
        System.runAs(testUser) {
            Test.startTest();
            // Schedule the job
            String cronExp = '0 0 2 * * ?';
            String jobName = 'Test Territory Alias Sync Scheduler';
            TerritoryAliasSyncScheduler scheduler = new TerritoryAliasSyncScheduler();
            String jobId = System.schedule(jobName, cronExp, scheduler);
            // Verify job was scheduled
            CronTrigger ct = [
                SELECT Id, CronExpression, TimesTriggered, NextFireTime
                FROM CronTrigger
                WHERE Id = :jobId
            ];
            System.assertNotEquals(null, ct, 'Scheduled job should exist');
            System.assertEquals(cronExp, ct.CronExpression, 'Cron expression should match');
            System.assertEquals(0, ct.TimesTriggered, 'Job should not have run yet');
            Test.stopTest();
            // After Test.stopTest(), verify the scheduled job ran
            System.assertNotEquals(null, ct.NextFireTime, 'Next fire time should be set');
        }
    }
    /**
     * @description Test scheduler executes the batch job
     */
    @isTest
    static void testSchedulerExecutesBatch() {
        User testUser = TestDataFactory.getTestUser();
        insert testUser;
        System.runAs(testUser) {
            // Create test data using TestDataFactory
            Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType(
                new Map<String, Object>{
                    'Territory_Alias__c' => 'TERR-TEST'
                }
            );
            insert practiceAccount;
            Test.startTest();
            // Execute the scheduler directly
            TerritoryAliasSyncScheduler scheduler = new TerritoryAliasSyncScheduler();
            scheduler.execute(null);
            Test.stopTest();
            // Verify batch was executed by checking AsyncApexJob
            List<AsyncApexJob> jobs = [
                SELECT Id, Status, ApexClass.Name
                FROM AsyncApexJob
                WHERE ApexClass.Name = 'TerritoryAliasSyncBatch'
                AND JobType = 'BatchApex'
            ];
            System.assertNotEquals(0, jobs.size(), 'Batch job should have been queued');
            System.assertEquals('TerritoryAliasSyncBatch', jobs[0].ApexClass.Name, 'Correct batch class should be executed');
        }
    }
    /**
     * @description Test multiple scheduler instances
     */
    @isTest
    static void testMultipleSchedulerInstances() {
        User testUser = TestDataFactory.getTestUser();
        insert testUser;
        System.runAs(testUser) {
            Test.startTest();
            // Schedule multiple jobs
            String cronExp1 = '0 0 2 * * ?';
            String jobName1 = 'Territory Sync Job 1';
            String cronExp2 = '0 0 14 * * ?';
            String jobName2 = 'Territory Sync Job 2';
            TerritoryAliasSyncScheduler scheduler1 = new TerritoryAliasSyncScheduler();
            String jobId1 = System.schedule(jobName1, cronExp1, scheduler1);
            TerritoryAliasSyncScheduler scheduler2 = new TerritoryAliasSyncScheduler();
            String jobId2 = System.schedule(jobName2, cronExp2, scheduler2);
            Test.stopTest();
            // Verify both jobs were scheduled
            List<CronTrigger> scheduledJobs = [
                SELECT Id, CronJobDetail.Name
                FROM CronTrigger
                WHERE Id IN (:jobId1, :jobId2)
            ];
            System.assertEquals(2, scheduledJobs.size(), 'Both jobs should be scheduled');
        }
    }
    /**
     * @description Test scheduler with exception handling
     *              Tests that exceptions in execute() are caught and logged
     */
    @isTest
    static void testSchedulerExceptionHandling() {
        User testUser = TestDataFactory.getTestUser();
        insert testUser;
        System.runAs(testUser) {
            Test.startTest();
            // Set flag to force exception
            TerritoryAliasSyncScheduler.forceException = true;
            TerritoryAliasSyncScheduler scheduler = new TerritoryAliasSyncScheduler();
            Boolean exceptionThrown = false;
            try {
                scheduler.execute(null);
            } catch (Exception e) {
                exceptionThrown = true;
            }
            // Verify exception was caught internally (not thrown to caller)
            System.assertEquals(false, exceptionThrown, 'Scheduler should catch exceptions internally and not throw to caller');
            // Reset flag
            TerritoryAliasSyncScheduler.forceException = false;
            Test.stopTest();
        }
    }
    /**
     * @description Test unscheduling a job
     */
    @isTest
    static void testUnscheduleJob() {
        User testUser = TestDataFactory.getTestUser();
        insert testUser;
        System.runAs(testUser) {
            // Schedule a job
            String cronExp = '0 0 2 * * ?';
            String jobName = 'Test Territory Alias Sync to Unschedule';
            TerritoryAliasSyncScheduler scheduler = new TerritoryAliasSyncScheduler();
            String jobId = System.schedule(jobName, cronExp, scheduler);
            // Verify job was scheduled
            List<CronTrigger> scheduledJobs = [
                SELECT Id
                FROM CronTrigger
                WHERE Id = :jobId
            ];
            System.assertEquals(1, scheduledJobs.size(), 'Job should be scheduled');
            Test.startTest();
            // Unschedule the job
            System.abortJob(jobId);
            Test.stopTest();
            // Verify job was unscheduled
            scheduledJobs = [
                SELECT Id, State
                FROM CronTrigger
                WHERE Id = :jobId
            ];
            if (!scheduledJobs.isEmpty()) {
                System.assertEquals('DELETED', scheduledJobs[0].State, 'Job should be deleted');
            }
        }
    }
}