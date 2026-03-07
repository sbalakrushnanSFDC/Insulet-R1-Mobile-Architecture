/**
 * @description Batch class to fix child Practice accounts where Territory_Alias__c != Parent.Territory_Alias__c.
 *              Builds List<Account> from scope and calls updateChildAccountsTerritoryAlias.
 * 
 * NOTE: This class is declared as without sharing to ensure that it can access all account records.
 *       This is necessary because the batch job needs to access all accounts, regardless of sharing.
 *       The batch uses WITH SYSTEM_MODE for queries and SYSTEM_MODE for DML, so user permissions are not a concern.
 *
 * @author      Ayush Sharma
 * @created     Feb 24, 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       24th Feb 2026       Ayush Sharma            Initial Version
 */
public without sharing class TerritoryHierarchyBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Integer successCount = 0;
    private Integer totalChildAccMismatch = 0;
    private static final String TAG_NAME = ConstantsUtil.ASIM_TAG;

    /**
     * @description Start method - queries child accounts where Parent.Territory_Alias__c is not blank.
     * @param bc BatchableContext
     * @return Database.QueryLocator for child Account records
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Logger.info('TerritoryHierarchyBatch started')
            .addTag(TAG_NAME);
        Logger.saveLog();

        return Database.getQueryLocator([
            SELECT Id, Territory_Alias__c, ParentId, Parent.Territory_Alias__c
            FROM Account
            WHERE ParentId != null
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT
            AND Parent.Apply_Territory_to_Hierarchy__c = true
            AND Parent.Territory_Alias__c != null
            WITH SYSTEM_MODE
        ]);
    }

    /**
     * @description Execute - builds List<Account> for mismatched records, updates directly.
     * @param bc BatchableContext
     * @param childAccounts List of child Account records from query
     */
    public void execute(Database.BatchableContext bc, List<Account> childAccounts) {
        if (childAccounts == null || childAccounts.isEmpty()) {
            Logger.info('TerritoryHierarchyBatch: No child accounts in scope')
                .addTag(TAG_NAME);
            Logger.saveLog();
            return;
        }

        try {
            List<Account> accountsToUpdate = TerritoryHierarchyService.filterChildAccountsForTerritoryUpdate(childAccounts);

            if (!accountsToUpdate.isEmpty()) {
                totalChildAccMismatch += accountsToUpdate.size();
                successCount += TerritoryHierarchyService.updateChildAccountsTerritoryAlias(accountsToUpdate);
            }

            Utility.throwExceptionForTestCoverage();
        } catch (Exception e) {
            Logger.error('Error in TerritoryHierarchyBatch.execute for batch of ' + childAccounts.size() +
                ' child account(s): ' + e.getMessage(), e)
                .addTag(TAG_NAME);
        }

        Logger.saveLog();
    }

    /**
     * @description Finish method called after all batches complete
     * @param bc BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT Id, Status, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
        String summary = 'TerritoryHierarchyBatch ' + job.Status +
            ' - Child account(s) with parent territory alias mismatch: ' + totalChildAccMismatch +
            '. Updated ' + successCount + ' child account(s) territory alias.';
        Logger.info(summary)
            .addTag(TAG_NAME);
        Logger.saveLog();
    }
}