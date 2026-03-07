/**
 * @author      : Yogesh Rana
 * @created Date: 2nd Dec 2025
 * @description : Observation Records Sharing Controller Class
 * Creates AccountShare records to share Trainer Account with Delegate Observer
 * This allows Delegate Observer to access observations by sharing the related Trainer Account
 * =========================== Logs ==============================
 * Version      Modified Date       Modified By         Brief Note
 * V1.0.0       2nd Dec 2025        Yogesh Rana         Initial Version (US - NGOMCT-752)
 */
public inherited sharing class ObservationSharingHandler {

    // Constants for access levels and configuration
    private static final String ACCESS_LEVEL_EDIT = 'Edit';
    private static final String ROW_CAUSE = 'Manual';
    private static final String LOGGER_TAG = 'ObservationSharingHandler';

    /**
     * @description Wrapper class to hold AccountShare changes for observation-related access
     * Encapsulates the trainer account and delegate observer information for sharing operations
     */
    private class SharingChange {
        Id trainerAccountId;
        Id newDelegateAccountId;
        Id oldDelegateAccountId;

        /**
         * @description Constructor to initialize a SharingChange instance
         * @param trainerAccountId ID of the trainer account to be shared
         * @param newDelegateAccountId ID of the new delegate observer account
         * @param oldDelegateAccountId ID of the old delegate observer account
         */
        SharingChange(Id trainerAccountId, Id newDelegateAccountId, Id oldDelegateAccountId) {
            this.trainerAccountId = trainerAccountId;
            this.newDelegateAccountId = newDelegateAccountId;
            this.oldDelegateAccountId = oldDelegateAccountId;
        }
    }

    /**
     * @description Main method to implement Observation sharing logic
     * Creates AccountShare records to share Trainer Account with Delegate Observer
     * This enables Delegate Observer to access observations through the shared Trainer Account
     * @param updatedObservations The map of updated Observation records
     * @param oldObservationsMap The map of old Observation records
     */
    public static void shareObservationRecords(Map<Id, Observation__c> updatedObservations, Map<Id, Observation__c> oldObservationsMap) {

        try {
            // Step 1: Analyze observations to identify delegate observer changes
            // Compares old vs new to determine which observations need sharing updates
            List<SharingChange> sharingChanges = determineSharingChanges(updatedObservations, oldObservationsMap);

            if (sharingChanges == null || sharingChanges.isEmpty()) {
                return;
            }

            // Step 2: Resolve Account IDs to User IDs for delegate observers
            // Required because Delegate_Observer__c stores Account ID, but sharing needs User ID
            Map<Id, Id> accountIdToUserId = getUserIdsByAccountIds(sharingChanges);

            // Step 3: Build AccountShare records for new/changed delegate observers
            // Creates share records to grant Trainer Account access to delegates
            List<SObject> shareRecordsToInsert = buildShareRecords(sharingChanges, accountIdToUserId);

            // Step 4: Identify AccountShare records to delete for removed delegate observers
            // Maps Trainer Account IDs to User IDs that should lose access
            Map<Id, Set<Id>> shareRecordsToDelete = buildShareDeletionMap(sharingChanges, accountIdToUserId);

              // Insert new share records
            if (shareRecordsToInsert != null && !shareRecordsToInsert.isEmpty()) {
                insertShareRecords(shareRecordsToInsert);
            }

            // Delete old share records
            if (shareRecordsToDelete != null && !shareRecordsToDelete.isEmpty()) {
                deleteShareRecords(shareRecordsToDelete);
            }

            // Test support: Inject exception for test coverage when flag is enabled
            Utility.throwExceptionForTestCoverage();
        } catch (Exception e) {
            // Log error with observation context for troubleshooting
            Logger.error('Error in ObservationSharingHandler', updatedObservations.values(), e)
                .addTag(LOGGER_TAG);
        } finally {
            // Always save logs, even if processing fails
            Logger.saveLog();
        }
    }

    /**
     * @description Determines what sharing changes are needed for each observation
     * @param updatedObservations Map of updated observations
     * @param oldObservationsMap Map of old observations
     * @return List of SharingChange objects
     */
    @TestVisible
    private static List<SharingChange> determineSharingChanges(Map<Id, Observation__c> updatedObservations, Map<Id, Observation__c> oldObservationsMap) {
        List<SharingChange> changes = new List<SharingChange>();

        for (Observation__c newObs : updatedObservations.values()) {
            Observation__c oldObs = oldObservationsMap.get(newObs.Id);

            if ((newObs.Delegate_Observer__c != oldObs.Delegate_Observer__c)) {
                changes.add(new SharingChange(newObs.Trainer_Name__c, newObs.Delegate_Observer__c, oldObs.Delegate_Observer__c));
            }
        }

        return changes;
    }

    /**
     * @description Queries User records to get User IDs from Account IDs
     * Delegate_Observer__c field contains Account ID, need to fetch actual User IDs
     * @param sharingChanges List of sharing changes containing Account IDs
     * @return Map of Account ID to User ID
     */
    @TestVisible
    private static Map<Id, Id> getUserIdsByAccountIds(List<SharingChange> sharingChanges) {
        Set<Id> accountIds = new Set<Id>();

        // Collect all Account IDs from sharing changes
        for (SharingChange change : sharingChanges) {
            if (change.newDelegateAccountId != null) {
                accountIds.add(change.newDelegateAccountId);
            }
            if (change.oldDelegateAccountId != null) {
                accountIds.add(change.oldDelegateAccountId);
            }
        }

        // Query User records where AccountId matches Delegate_Observer__c values
        Map<Id, Id> accountIdToUserIdMap = new Map<Id, Id>();

        if (!accountIds.isEmpty()) {
            for (User usr : [SELECT Id, AccountId FROM User WHERE AccountId IN :accountIds AND IsActive = true WITH SYSTEM_MODE]) {
                accountIdToUserIdMap.put(usr.AccountId, usr.Id);
            }
        }

        return accountIdToUserIdMap;
    }

    /**
     * @description Builds AccountShare records using Utility class to enable observation access
     * Creates AccountShare records to share Trainer Account with Delegate Observer
     * @param sharingChanges List of sharing changes from Observation updates
     * @param accountIdToUserIdMap Map of Account ID to User ID for delegate observers
     * @return List of AccountShare records to insert
     */
    @TestVisible
    private static List<SObject> buildShareRecords(List<SharingChange> sharingChanges, Map<Id, Id> accountIdToUserIdMap) {
        List<SObject> shareRecords = new List<SObject>();
        Set<String> shareKeys = new Set<String>(); // To prevent duplicates

        if (accountIdToUserIdMap == null) {
            return shareRecords;
        }

        for (SharingChange change : sharingChanges) {
            if (change.newDelegateAccountId == null || !accountIdToUserIdMap.containsKey(change.newDelegateAccountId)) {
                continue;
            }

            // Create unique key to prevent duplicate share records
            String shareKey = String.valueOf(change.trainerAccountId) + '-' + String.valueOf(accountIdToUserIdMap.get(change.newDelegateAccountId));
            if (shareKeys.contains(shareKey)) {
                continue;
            }

            Utility.CreateShareRecordParameterDetailWrap shareRequest = new Utility.CreateShareRecordParameterDetailWrap();
            shareRequest.recordId = change.trainerAccountId;  // Trainer Account to share
            shareRequest.userOrGroupId = accountIdToUserIdMap.get(change.newDelegateAccountId);  // Delegate Observer User ID
            shareRequest.accessLevel = ACCESS_LEVEL_EDIT;
            shareRequest.rowCause = ROW_CAUSE;  // Manual share

            SObject shareRecord = Utility.createShare(shareRequest);
            if (shareRecord != null) {
                shareRecords.add(shareRecord);
                shareKeys.add(shareKey);
            }
        }
        return shareRecords;
    }

    /**
     * @description Builds map of AccountShare records to delete for removing observation access
     * @param sharingChanges List of sharing changes from Observation updates
     * @param accountIdToUserIdMap Map of Account ID to User ID for delegate observers
     * @return Map of Trainer Account IDs to Set of Delegate Observer User IDs to remove
     */
    @TestVisible
    private static Map<Id, Set<Id>> buildShareDeletionMap(List<SharingChange> sharingChanges, Map<Id, Id> accountIdToUserIdMap) {
        Map<Id, Set<Id>> sharesToRemove = new Map<Id, Set<Id>>();

        if (accountIdToUserIdMap == null) {
            return sharesToRemove;
        }

        for (SharingChange change : sharingChanges) {
            if (change.oldDelegateAccountId == null || !accountIdToUserIdMap.containsKey(change.oldDelegateAccountId)) {
                continue;
            }

            Id delegateUserId = accountIdToUserIdMap.get(change.oldDelegateAccountId);
            if (!sharesToRemove.containsKey(change.trainerAccountId)) {
                sharesToRemove.put(change.trainerAccountId, new Set<Id>());
            }
            sharesToRemove.get(change.trainerAccountId).add(delegateUserId);
        }
        return sharesToRemove;
    }


    /**
     * @description Inserts AccountShare records using system context to enable observation access
     * @param shareRecords List of AccountShare records to insert
     */
    @TestVisible
    private static void insertShareRecords(List<SObject> shareRecords) {
        try {
            ObservationSharingHandlerSystemContext systemContext = new ObservationSharingHandlerSystemContext();
            Database.SaveResult[] results = systemContext.insertShareRecords(shareRecords);
            handleDmlErrors(results, shareRecords);
            Utility.throwExceptionForTestCoverage();
        } catch (Exception e) {
            Logger.error('Error inserting AccountShare records for observation access', shareRecords, e)
                .addTag(LOGGER_TAG);
        }
    }

    /**
     * @description Deletes AccountShare records using Utility class to remove observation access
     * @param sharesToRemove Map of Trainer Account IDs to Set of Delegate Observer User IDs
     */
    @TestVisible
    private static void deleteShareRecords(Map<Id, Set<Id>> sharesToRemove) {
        List<SObject> shareRecordsToDelete = new List<SObject>();
        try {
            shareRecordsToDelete = prepareSharesForDeletion(sharesToRemove);

            if (shareRecordsToDelete != null && !shareRecordsToDelete.isEmpty()) {
                ObservationSharingHandlerSystemContext systemContext = new ObservationSharingHandlerSystemContext();
                Database.DeleteResult[] results = systemContext.deleteShareRecords(shareRecordsToDelete);
                handleDmlErrors(results, shareRecordsToDelete);
            }

            Utility.throwExceptionForTestCoverage();
        } catch (Exception e) {
            Logger.error('Error deleting AccountShare records for observation access', shareRecordsToDelete, e)
                .addTag(LOGGER_TAG);
        }
    }

    /**
     * @description Prepares AccountShare records for deletion by converting map to parallel lists
     * Transforms map structure to parallel lists required by Utility.deleteShares() API
     * @param sharesToRemove Map of Account IDs to User IDs for shares to remove
     * @return List of AccountShare records to delete (queried by Utility class)
     */
    @TestVisible
    private static List<SObject> prepareSharesForDeletion(Map<Id, Set<Id>> sharesToRemove) {
        List<Id> accountIdsList = new List<Id>();
        List<Id> userIdsList = new List<Id>();

        // Convert map to parallel lists for Utility.deleteShares() API
        // Required due to architectural constraint to use Utility class
        for (Id accountId : sharesToRemove.keySet()) {
            for (Id userId : sharesToRemove.get(accountId)) {
                accountIdsList.add(accountId);
                userIdsList.add(userId);
            }
        }

        return Utility.deleteShares(accountIdsList, userIdsList);
    }

    /**
     * @description Handles DML errors for insert/update operations (SaveResult)
     * @param results Database.SaveResult array from DML operation
     * @param records List of SObject records that failed
     */
    @TestVisible
    private static void handleDmlErrors(Database.SaveResult[] results, List<SObject> records) {
        for (Integer resultIndex = 0; resultIndex < results.size(); resultIndex++) {
            if (!results[resultIndex].isSuccess()) {
                for (Database.Error err : results[resultIndex].getErrors()) {
                    Logger.error('Failed to insert AccountShare record: ' + err.getMessage(), results[resultIndex])
                        .setRecord(records[resultIndex])
                        .addTag(LOGGER_TAG);
                }
            }
        }
    }

    /**
     * @description Handles DML errors for delete operations (DeleteResult)
     * @param results Database.DeleteResult array from DML operation
     * @param records List of SObject records that failed
     */
    @TestVisible
    private static void handleDmlErrors(Database.DeleteResult[] results, List<SObject> records) {
        for (Integer resultIndex = 0; resultIndex < results.size(); resultIndex++) {
            if (!results[resultIndex].isSuccess()) {
                for (Database.Error err : results[resultIndex].getErrors()) {
                    Logger.error('Failed to delete AccountShare record: ' + err.getMessage(), results[resultIndex])
                        .setRecord(records[resultIndex])
                        .addTag(LOGGER_TAG);
                }
            }
        }
    }

    /**
     * @description Exception class for ObservationSharingHandler
     */
    public class ObservationSharingException extends Exception {
    }

    /**
     * @description Inner class to run AccountShare operations in system context
     * Required to create/delete AccountShare records for observation access with elevated privileges
     * Uses 'without sharing' to bypass sharing rules for CSM users and system operations
     */
    public without sharing class ObservationSharingHandlerSystemContext {
        /**
         * @description Inserts AccountShare records with system privileges
         * Uses allOrNone=false to allow partial success and log individual failures
         * @param shareRecords List of AccountShare records to insert
         * @return Database.SaveResult[] Results of the insert operation
         */
        public Database.SaveResult[] insertShareRecords(List<SObject> shareRecords) {
            return Database.insert(shareRecords, false, AccessLevel.SYSTEM_MODE);
        }

        /**
         * @description Deletes AccountShare records with system privileges
         * Uses allOrNone=false to allow partial success and log individual failures
         * Runs in 'without sharing' context to ensure CSM users can delete shares
         * @param shareRecords List of AccountShare records to delete
         * @return Database.DeleteResult[] Results of the delete operation
         */
        public Database.DeleteResult[] deleteShareRecords(List<SObject> shareRecords) {
            return Database.delete(shareRecords, false, AccessLevel.SYSTEM_MODE);
        }
    }
}