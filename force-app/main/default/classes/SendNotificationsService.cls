/**
 * Utility class for sending custom notifications.
 * Provides methods to send notifications for various business scenarios.
 * 
 * @author      Saikat Ghosh
 * @created     25th Feb 2026
 *
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       25th Feb 2026       Saikat Ghosh       (US - NGASIM-2045) Initial version – notification utility class
 */
public with sharing class SendNotificationsService {
    
    // Test flag to simulate CustomNotificationType not found scenario
    @TestVisible
    private static Boolean testSimulateNotificationTypeNotFound = false;
    
    // Test flag to simulate exception during notification send
    @TestVisible
    private static Boolean testSimulateNotificationSendException = false;
    
    // Test flag to simulate exception during getCustomNotificationType query
    @TestVisible
    private static Boolean testSimulateQueryException = false;
    
    /**
     * @description Sends a case closure notification based on approval status
     * @param caseRecord The Case record for which notification should be sent
     * @param parentRecordName The name of the parent record (Provider/Practice or HCPF)
     */
    public static void sendCaseClosureNotification(Case caseRecord, String parentRecordName) {
        if (caseRecord == null || String.isBlank(parentRecordName) || String.isBlank(caseRecord.Approval_Status__c)) {
            Logger.warn('SendNotificationsService: Invalid parameters for sendCaseClosureNotification')
                .addTag(ConstantsUtil.SEND_NOTIFICATIONS_SERVICE_TAG);
            Logger.saveLog();
            return;
        }
        
        try {
            // Get Custom Notification Type - 'Case_Closure_Notification'
            CustomNotificationType notificationType = getCustomNotificationType(ConstantsUtil.CASE_CLOSURE_NOTIFICATION_TYPE);
            if (notificationType == null) {
                Logger.error('SendNotificationsService: Custom Notification Type not found: ' + ConstantsUtil.CASE_CLOSURE_NOTIFICATION_TYPE)
                    .addTag(ConstantsUtil.SEND_NOTIFICATIONS_SERVICE_TAG);
                Logger.saveLog();
                return;
            }
            
            // Build notification body based on approval status
            String notificationBody = buildNotificationBody(parentRecordName, caseRecord.Approval_Status__c);
            
            // Prepare recipient set (Set<String> required for Messaging.CustomNotification.send())
            Set<String> recipientIds = new Set<String>();
            if (caseRecord.CreatedById != null) {
                recipientIds.add(caseRecord.CreatedById);
            }
            
            if (recipientIds.isEmpty()) {
                Logger.warn('SendNotificationsService: No recipients found for notification')
                    .addTag(ConstantsUtil.SEND_NOTIFICATIONS_SERVICE_TAG);
                Logger.saveLog();
                return;
            }
            
            // Create and configure custom notification using Messaging.CustomNotification
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(ConstantsUtil.CASE_CLOSURE_NOTIFICATION_TITLE); // 'Case Closed'
            notification.setBody(notificationBody);
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetId(caseRecord.Id);
            
            // Simulate exception for test coverage
            if (Test.isRunningTest() && testSimulateNotificationSendException) {
                throw new NotificationException('Test exception for coverage');
            }
            
            // Send notification to recipients
            notification.send(recipientIds);
        } catch (Exception e) {
            Logger.error('SendNotificationsService: Error sending notification - ' + e.getMessage(), e)
                .addTag(ConstantsUtil.SEND_NOTIFICATIONS_SERVICE_TAG);
            Logger.saveLog();
        }
    }
    
    /**
     * @description Retrieves Custom Notification Type by DeveloperName
     * @param developerName The DeveloperName of the Custom Notification Type
     * @return CustomNotificationType record or null if not found
     */
    @TestVisible
    private static CustomNotificationType getCustomNotificationType(String developerName) {
        try {
            // Simulate not found scenario for test coverage
            if (Test.isRunningTest() && testSimulateNotificationTypeNotFound) {
                return null;
            }
            
            // Simulate query exception for test coverage
            if (Test.isRunningTest() && testSimulateQueryException) {
                throw new QueryException('Test exception for coverage');
            }
            
            List<CustomNotificationType> notificationTypes = [
                SELECT Id, DeveloperName 
                FROM CustomNotificationType 
                WHERE DeveloperName = :developerName 
                WITH USER_MODE
                LIMIT 1
            ];
            
            return notificationTypes.isEmpty() ? null : notificationTypes[0];
        } catch (Exception e) {
            Logger.error('SendNotificationsService: Error querying Custom Notification Type - ' + e.getMessage(), e)
                .addTag(ConstantsUtil.SEND_NOTIFICATIONS_SERVICE_TAG);
            Logger.saveLog();
            return null;
        }
    }
    
    /**
     * @description Builds the notification body message based on approval status
     * @param parentRecordName The name of the parent record
     * @param approvalStatus The approval status ('Approve' or 'Reject')
     * @return Formatted notification body string
     */
    @TestVisible
    private static String buildNotificationBody(String parentRecordName, String approvalStatus) {
        // Message format: "The update you requested for {parentRecordName} has been Approved."
        if (ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE.equals(approvalStatus)) {
            return ConstantsUtil.CASE_NOTIFICATION_MESSAGE_PREFIX + parentRecordName + 
                   ConstantsUtil.CASE_NOTIFICATION_MESSAGE_SUFFIX + 
                   ConstantsUtil.CASE_NOTIFICATION_STATUS_APPROVED + '.';
        } 
        // Message format: "The update you requested for {parentRecordName} has been Denied."
        else if (ConstantsUtil.CASE_APPROVAL_STATUS_REJECT.equals(approvalStatus)) {
            return ConstantsUtil.CASE_NOTIFICATION_MESSAGE_PREFIX + parentRecordName + 
                   ConstantsUtil.CASE_NOTIFICATION_MESSAGE_SUFFIX + 
                   ConstantsUtil.CASE_NOTIFICATION_STATUS_DENIED + '.';
        } 
        // Message format: "The update you requested for {parentRecordName} has been processed."
        else {
            return ConstantsUtil.CASE_NOTIFICATION_MESSAGE_PREFIX + parentRecordName + 
                   ConstantsUtil.CASE_NOTIFICATION_MESSAGE_SUFFIX + 
                   ConstantsUtil.CASE_NOTIFICATION_STATUS_PROCESSED + '.';
        }
    }
    
    /**
     * @description Custom exception class for notification errors
     */
    public class NotificationException extends Exception {}
    
    /**
     * @description Custom exception class for query errors
     */
    public class QueryException extends Exception {}
}