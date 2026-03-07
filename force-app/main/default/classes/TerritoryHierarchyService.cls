/**
 * @description Service class to apply Parent Territory_Alias__c to child Practice accounts.
 *
 * Called from:
 * - TerritoryHierarchyHandler (trigger) - enqueueApplyTerritoryJob
 * - ApplyTerritoryToHierarchyQueueable (queueable) - applyTerritoryToChildAccounts
 * - TerritoryHierarchyBatch (batch) - filterChildAccountsForTerritoryUpdate, updateChildAccountsTerritoryAlias
 * - TerritoryHierarchyHandler (trigger) - addHierarchyErrors
 *
 * NOTE: This class uses WITH SYSTEM_MODE for queries and SYSTEM_MODE for DML, so user permissions are not a concern.
 *
 * @author      Ayush Sharma
 * @created     Feb 19, 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       19th Feb 2026       Ayush Sharma            Initial Version
 * V1.0.1       27th Feb 2026       Ayush Sharma            Added addHierarchyErrors
 */
public inherited sharing class TerritoryHierarchyService {

    private static final String TAG_NAME = ConstantsUtil.ASIM_TAG;

    /**
     * @description Enqueues job with parent IDs. Call from TerritoryHierarchyHandler.
     * @param parentAccountIds Set of parent Account IDs
     */
    public static void enqueueApplyTerritoryJob(Set<Id> parentAccountIds) {
        if (parentAccountIds == null || parentAccountIds.isEmpty()) {
            return;
        }
        try {
            if (!System.isQueueable() && !Test.isRunningTest()) {
                System.enqueueJob(new ApplyTerritoryToHierarchyQueueable(parentAccountIds));
            } else if (Test.isRunningTest()) {
                // In test context, execute synchronously
                ApplyTerritoryToHierarchyQueueable job = new ApplyTerritoryToHierarchyQueueable(parentAccountIds);
                job.execute(null);
            }

            // Throw exception for test coverage if customExceptionSwitch is enabled
            Utility.throwExceptionForTestCoverage();
        } catch (Exception ex) {
            List<SObject> records = new List<SObject>();
            for (Id parentId : parentAccountIds) {
                records.add(new Account(Id = parentId));
            }
            Logger.error('Failed to enqueue Apply Territory to Hierarchy: ' + ex.getMessage(), records, ex)
                .addTag(TAG_NAME);
        }
    }

    /**
     * @description Queries child Practice accounts, processes and updates.
     *              Call from ApplyTerritoryToHierarchyQueueable.
     * @param parentAccountIds Set of parent Account IDs
     */
    public static void applyTerritoryToChildAccounts(Set<Id> parentAccountIds) {
        if (parentAccountIds == null || parentAccountIds.isEmpty()) {
            return;
        }
        try {
            processAndUpdateChildAccounts(parentAccountIds);
            // Throw exception for test coverage if customExceptionSwitch is enabled
            Utility.throwExceptionForTestCoverage();
        } catch (Exception ex) {
            Logger.error('TerritoryHierarchyService.applyTerritoryToChildAccounts failed: ' + ex.getMessage(), ex)
                .addTag(TAG_NAME);
        }
    }

    /**
     * @description Queries child Practice accounts by parent IDs, filters those where
     *              Territory_Alias__c != Parent.Territory_Alias__c, and updates them.
     *              Called by applyTerritoryToChildAccounts.
     * @param parentAccountIds Set of parent Account IDs whose child accounts should be processed
     */
    private static void processAndUpdateChildAccounts(Set<Id> parentAccountIds) {
        List<Account> childAccounts = getChildPracticeAccountsByParentIds(parentAccountIds);
        List<Account> accountsToUpdate = filterChildAccountsForTerritoryUpdate(childAccounts);
        if (!accountsToUpdate.isEmpty()) {
            updateChildAccountsTerritoryAlias(accountsToUpdate);
        }
    }

    /**
     * @description Queries child Practice accounts by parent IDs where Parent.Territory_Alias__c is not blank
     *              and Parent.Apply_Territory_to_Hierarchy__c is checked.
     * @param parentAccountIds Set of parent Account IDs
     * @return List of child Practice Account records with Parent.Territory_Alias__c
     */
    @TestVisible
    private static List<Account> getChildPracticeAccountsByParentIds(Set<Id> parentAccountIds) {
        if (parentAccountIds == null || parentAccountIds.isEmpty()) {
            return new List<Account>();
        }
        return [
            SELECT Id, Territory_Alias__c, ParentId, Parent.Territory_Alias__c
            FROM Account
            WHERE ParentId IN :parentAccountIds
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT
            AND Parent.Territory_Alias__c != null
            AND Parent.Apply_Territory_to_Hierarchy__c = true
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description Filters child accounts where Territory_Alias__c != Parent.Territory_Alias__c.
     *              Used by Batch and processAndUpdateChildAccounts.
     * @param childAccounts List of child Account records with Parent.Territory_Alias__c
     * @return List of Account records with Id and Territory_Alias__c set for DML update
     */
    public static List<Account> filterChildAccountsForTerritoryUpdate(List<Account> childAccounts) {
        List<Account> accountsToUpdate = new List<Account>();
        if (childAccounts == null) {
            return accountsToUpdate;
        }
        for (Account childAcc : childAccounts) {
            String parentTerritory = childAcc.Parent != null ? childAcc.Parent.Territory_Alias__c : null;
            if (String.isNotBlank(parentTerritory) && childAcc.Territory_Alias__c != parentTerritory) {
                accountsToUpdate.add(new Account(Id = childAcc.Id, Territory_Alias__c = parentTerritory));
            }
        }
        return accountsToUpdate;
    }

    /**
     * @description DML - updates child accounts with Territory_Alias__c. Used by Batch and Queueable flow.
     * @param accountsToUpdate List of Account records with Id and Territory_Alias__c set
     * @return Integer count of successfully updated records
     */
    public static Integer updateChildAccountsTerritoryAlias(List<Account> accountsToUpdate) {
        if (accountsToUpdate == null || accountsToUpdate.isEmpty()) {
            return 0;
        }
        Integer successCount = 0;
        try {
            // Throw exception for test coverage if customExceptionSwitch is enabled
            Utility.throwExceptionForTestCoverage();

            Database.SaveResult[] results = Database.update(accountsToUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    successCount++;
                } else {
                    for (Database.Error err : results[i].getErrors()) {
                        Logger.error('Failed to update Territory Alias on Child Account ' + accountsToUpdate[i].Id +
                            ': ' + err.getMessage()
                        ).setRecord(accountsToUpdate[i]).addTag(TAG_NAME);
                    }
                }
            }
        } catch (Exception ex) {
            Logger.error('TerritoryHierarchyService: DML Exception: ' + ex.getMessage(), ex).addTag(TAG_NAME);
        }
        return successCount;
    }

    /**
     * @description Adds hierarchy errors to accounts that have children and are adding a parent.
     *              Caller passes accountIdsAddingParent and accountMap (built from newAccounts/oldAccountsMap).
     * @param accountIdsAddingParent Set of Account IDs that are adding a parent
     * @param accountMap Map of Id to Account for those records
     */
    public static void addHierarchyErrors(
        Set<Id> accountIdsAddingParent,
        Map<Id, Account> accountMap
    ) {
        if (accountIdsAddingParent == null || accountIdsAddingParent.isEmpty() || accountMap == null) {
            return;
        }

        Set<Id> idsWithChildren = new Set<Id>();
        for (Account childAcc : [
            SELECT ParentId FROM Account
            WHERE ParentId IN :accountIdsAddingParent AND RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT
            WITH SYSTEM_MODE
        ]) {
            idsWithChildren.add(childAcc.ParentId);
        }

        for (Id idWithChild : idsWithChildren) {
            if (accountMap.containsKey(idWithChild)) {
                accountMap.get(idWithChild).addError(System.Label.Practice_Hierarchy_Restriction_Error);
            }
        }
    }
}