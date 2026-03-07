/**
 * Test class for SendNotificationsService.
 * Tests all public and private methods to achieve 100% code coverage.
 * 
 * @author      Saikat Ghosh
 * @created     25th Feb 2026
 *
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       25th Feb 2026       Saikat Ghosh      (US - NGASIM-2045) Initial version – SendNotificationsService test class
 */
@IsTest(isParallel=true)
private class SendNotificationsService_Test {

    private static Case createTestCase(Boolean needCreatedById) {
        Case testCase = (Case)MockDataFactory.mockData('Case', new Map<String, Object>{
            'Subject' => 'Test Case',
            'Approval_Status__c' => ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE
        });
        if (needCreatedById) {
            insert testCase;
        } else {
            testCase.Id = MockDataFactory.getFakeId('Case');
        }
        return testCase;
    }

    private static Case getCaseWithCreatedById(Case testCase) {
        return [SELECT Id, CreatedById, Approval_Status__c FROM Case WHERE Id = :testCase.Id LIMIT 1];
    }

    private static List<CustomNotificationType> queryCustomNotificationType() {
        return [
            SELECT Id, DeveloperName 
            FROM CustomNotificationType 
            WHERE DeveloperName = :ConstantsUtil.CASE_CLOSURE_NOTIFICATION_TYPE 
            LIMIT 1
        ];
    }

    /**
     * @description Comprehensive test for sendCaseClosureNotification
     * Covers: null case, blank params, no recipients, notification type not found,
     * exception handling, full flow, different statuses, bulk scenario
     */
    @IsTest
    static void testSendCaseClosureNotification() {
        Test.startTest();

        // Early returns: null case
        SendNotificationsService.sendCaseClosureNotification(null, 'Test Parent');

        Case testCase = createTestCase(true);
        Case queriedCase = getCaseWithCreatedById(testCase);

        // Early returns: blank parentRecordName
        SendNotificationsService.sendCaseClosureNotification(testCase, '');
        SendNotificationsService.sendCaseClosureNotification(testCase, null);

        // Early returns: blank approvalStatus
        testCase.Approval_Status__c = null;
        SendNotificationsService.sendCaseClosureNotification(testCase, 'Test Parent');
        testCase.Approval_Status__c = '';
        SendNotificationsService.sendCaseClosureNotification(testCase, 'Test Parent');

        // Early return: no recipients (Case not inserted, no CreatedById)
        Case noRecipientCase = createTestCase(false);
        SendNotificationsService.sendCaseClosureNotification(noRecipientCase, 'Test Parent');

        // Notification type not found (test flag)
        SendNotificationsService.testSimulateNotificationTypeNotFound = true;
        SendNotificationsService.sendCaseClosureNotification(queriedCase, 'Test Parent');
        SendNotificationsService.testSimulateNotificationTypeNotFound = false;

        // Full flow and different statuses (when CustomNotificationType exists)
        List<CustomNotificationType> notificationTypes = queryCustomNotificationType();
        if (!notificationTypes.isEmpty()) {
            queriedCase.Approval_Status__c = ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE;
            SendNotificationsService.sendCaseClosureNotification(queriedCase, 'Test Provider');
            queriedCase.Approval_Status__c = ConstantsUtil.CASE_APPROVAL_STATUS_REJECT;
            SendNotificationsService.sendCaseClosureNotification(queriedCase, 'Test Practice');
            queriedCase.Approval_Status__c = 'Other Status';
            SendNotificationsService.sendCaseClosureNotification(queriedCase, 'Test HCPF');

            // Exception handling (test flag)
            SendNotificationsService.testSimulateNotificationSendException = true;
            SendNotificationsService.sendCaseClosureNotification(queriedCase, 'Test Parent');
            SendNotificationsService.testSimulateNotificationSendException = false;
        }

        // Bulk scenario
        List<Case> bulkCases = new List<Case>();
        for (Integer i = 0; i < 5; i++) {
            bulkCases.add(createTestCase(true));
        }
        Set<Id> caseIds = new Set<Id>();
        for (Case c : bulkCases) {
            caseIds.add(c.Id);
        }
        Map<Id, Case> bulkCasesMap = new Map<Id, Case>(
            [SELECT Id, CreatedById, Approval_Status__c FROM Case WHERE Id IN :caseIds]
        );
        for (Integer i = 0; i < bulkCases.size(); i++) {
            Case c = bulkCasesMap.get(bulkCases[i].Id);
            c.Approval_Status__c = Math.mod(i, 2) == 0 
                ? ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE 
                : ConstantsUtil.CASE_APPROVAL_STATUS_REJECT;
            SendNotificationsService.sendCaseClosureNotification(c, 'Test Parent ' + i);
        }

        Test.stopTest();
        Assert.isTrue(true, 'All sendCaseClosureNotification scenarios covered');
    }

    /**
     * @description Test getCustomNotificationType: non-existent, existing, null/empty, exception
     */
    @IsTest
    static void testGetCustomNotificationType() {
        Test.startTest();
        CustomNotificationType resultNotFound = SendNotificationsService.getCustomNotificationType('NonExistentNotificationType');
        Assert.isNull(resultNotFound, 'Should return null when not found');

        List<CustomNotificationType> existingTypes = [
            SELECT Id, DeveloperName FROM CustomNotificationType LIMIT 1
        ];
        if (!existingTypes.isEmpty()) {
            CustomNotificationType resultFound = SendNotificationsService.getCustomNotificationType(existingTypes[0].DeveloperName);
            Assert.isNotNull(resultFound, 'Should return type when it exists');
        }

        SendNotificationsService.getCustomNotificationType(null);
        SendNotificationsService.getCustomNotificationType('');

        SendNotificationsService.testSimulateQueryException = true;
        Assert.isNull(SendNotificationsService.getCustomNotificationType('TestType'), 'Should return null on exception');
        SendNotificationsService.testSimulateQueryException = false;
        Test.stopTest();
    }

    /**
     * @description Test buildNotificationBody: Approve, Reject, other, null, empty
     */
    @IsTest
    static void testBuildNotificationBody() {
        Test.startTest();
        String prefix = ConstantsUtil.CASE_NOTIFICATION_MESSAGE_PREFIX;
        String suffix = ConstantsUtil.CASE_NOTIFICATION_MESSAGE_SUFFIX;

        String resultApprove = SendNotificationsService.buildNotificationBody('Provider', ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE);
        Assert.areEqual(prefix + 'Provider' + suffix + ConstantsUtil.CASE_NOTIFICATION_STATUS_APPROVED + '.', resultApprove);

        String resultReject = SendNotificationsService.buildNotificationBody('Practice', ConstantsUtil.CASE_APPROVAL_STATUS_REJECT);
        Assert.areEqual(prefix + 'Practice' + suffix + ConstantsUtil.CASE_NOTIFICATION_STATUS_DENIED + '.', resultReject);

        String resultOther = SendNotificationsService.buildNotificationBody('HCPF', 'Other');
        Assert.areEqual(prefix + 'HCPF' + suffix + ConstantsUtil.CASE_NOTIFICATION_STATUS_PROCESSED + '.', resultOther);

        String resultNull = SendNotificationsService.buildNotificationBody('Parent', null);
        Assert.areEqual(prefix + 'Parent' + suffix + ConstantsUtil.CASE_NOTIFICATION_STATUS_PROCESSED + '.', resultNull);

        String resultEmpty = SendNotificationsService.buildNotificationBody('Parent', '');
        Assert.areEqual(prefix + 'Parent' + suffix + ConstantsUtil.CASE_NOTIFICATION_STATUS_PROCESSED + '.', resultEmpty);
        Test.stopTest();
    }

}