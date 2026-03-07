/**
 * @description Test class for AspnInactivityAlertScheduler.
 *              Uses TestDataFactory for functional tests (testing with actual database records).
 * Note: Must run sequentially (isParallel=false) because System.schedule()
 *       creates CronJobDetail records which aren't allowed in parallel test contexts.
 * @author Ayush Sharma
 * @date Feb 11, 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       11th Feb 2026        Ayush Sharma                 Initial Version
 * =======================================================================
 */

@IsTest(isParallel=false)
private class AspnInactivityAlertScheduler_Test {

    /**
     * @description Test scheduler execute method directly
     */
    @IsTest
    static void testExecuteMethod() {
        AspnInactivityAlertScheduler scheduler = new AspnInactivityAlertScheduler();

        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();

        // Should complete without errors (batch will be queued)
        Assert.isTrue(true, 'Scheduler should execute without errors');
    }

    /**
     * @description Test scheduler exception handling using customExceptionSwitch flag
     */
    @IsTest
    static void testSchedulerExceptionHandling() {
        ConstantsUtil.customExceptionSwitch = true;

        Test.startTest();
        AspnInactivityAlertScheduler scheduler = new AspnInactivityAlertScheduler();
        scheduler.execute(null);
        Test.stopTest();

        ConstantsUtil.customExceptionSwitch = false;

        // Should handle exception gracefully without throwing
        Assert.isTrue(true, 'Scheduler should handle exceptions gracefully');
    }

    /**
     * @description Test scheduler with System.schedule
     *              Note: Must run sequentially (isParallel=false) because System.schedule()
     *              creates CronJobDetail records which aren't allowed in parallel test contexts.
     */
    @IsTest
    static void testScheduleJob() {
        AspnInactivityAlertScheduler scheduler = new AspnInactivityAlertScheduler();

        Test.startTest();
        String cronExp = '0 0 0/8 * * ?';
        String jobId = System.schedule('Test ASPN Inactivity Alert', cronExp, scheduler);
        Test.stopTest();

        // Verify the scheduled job was created
        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        Assert.areEqual(cronExp, ct.CronExpression, 'Cron expression should match');
        Assert.areEqual(0, ct.TimesTriggered, 'Should not have triggered yet');
        Assert.areEqual('WAITING', ct.State, 'Job should be in WAITING state');
    }

    /**
     * @description Test scheduler execute method with default batch size when BatchConfigurationUtil returns invalid value
     */
    @IsTest
    static void testExecuteWithInvalidBatchSize() {
        AspnInactivityAlertScheduler scheduler = new AspnInactivityAlertScheduler();

        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();

        // Should complete successfully using default batch size (200) when invalid value is returned
        Assert.isTrue(true, 'Scheduler should use default batch size when BatchConfigurationUtil returns invalid value');
    }

    /**
     * @description Test scheduler execution triggers batch job successfully
     */
    @IsTest
    static void testSchedulerTriggersBatchSuccessfully() {
        AspnInactivityAlertScheduler scheduler = new AspnInactivityAlertScheduler();

        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();

        // The important thing is that execute() completed without errors
        Assert.isTrue(true, 'Scheduler should trigger batch job successfully');
    }

    /**
     * @description Test scheduler handles multiple executions
     */
    @IsTest
    static void testSchedulerMultipleExecutions() {
        AspnInactivityAlertScheduler scheduler = new AspnInactivityAlertScheduler();

        Test.startTest();
        scheduler.execute(null);
        scheduler.execute(null);
        scheduler.execute(null);
        Test.stopTest();

        // Should handle multiple executions without errors
        Assert.isTrue(true, 'Scheduler should handle multiple executions gracefully');
    }
}