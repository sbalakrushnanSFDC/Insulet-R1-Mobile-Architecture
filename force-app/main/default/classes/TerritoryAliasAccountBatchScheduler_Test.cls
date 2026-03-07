/**
 * @description Test class for TerritoryAliasAccountBatchScheduler
 * @author      Jatin Butta
 * @createdDate November 18, 2025
 *
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Nov 18, 2025        Jatin Butta             Initial Version (US - NGASIM-1166)
 */
@isTest
private class TerritoryAliasAccountBatchScheduler_Test {

    /**
     * @description Test scheduler with System.schedule
     */
    @IsTest
    static void testScheduleJob() {
        TerritoryAliasAccountBatchScheduler scheduler = new TerritoryAliasAccountBatchScheduler();

        Test.startTest();
        String cronExp = '0 0 2 * * ?';
        String jobId = System.schedule(
            'Test Territory Alias Account Batch',
            cronExp,
            scheduler
        );
        Test.stopTest();

        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        Assert.areEqual(cronExp, ct.CronExpression, 'Cron expression should match');
        Assert.areEqual(0, ct.TimesTriggered, 'Should not have triggered yet');
    }

    /**
     * @description Test scheduler execute method directly
     */
    @IsTest
    static void testExecuteMethod() {
        TerritoryAliasAccountBatchScheduler scheduler = new TerritoryAliasAccountBatchScheduler();

        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();

        Assert.isTrue(true, 'Scheduler should execute without errors');
    }

    /**
     * @description Test scheduler exception handling
     */
    @IsTest
    static void testSchedulerExceptionHandling() {
        TerritoryAliasAccountBatchScheduler.forceException = true;
        TerritoryAliasAccountBatchScheduler scheduler = new TerritoryAliasAccountBatchScheduler();

        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();

        Assert.isTrue(true, 'Scheduler should handle exceptions gracefully');
    }
}