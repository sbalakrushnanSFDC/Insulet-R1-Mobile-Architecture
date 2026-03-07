/**
 * @description Handler for Territory Hierarchy logic on Account.
 *              - Before Update: validates parent-child hierarchy depth.
 *              - After Update: processes Apply_Territory_to_Hierarchy__c checkbox.
 *
 * @author      Ayush Sharma
 * @created     Feb 19, 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       19th Feb 2026       Ayush Sharma            Initial Version
 * V1.0.1       27th Feb 2026       Ayush Sharma            Added validateParentChildHierarchy
 */
public inherited sharing class TerritoryHierarchyHandler {

    /**
     * @description Prevents adding a parent to a Practice account that has children.
     *              Builds accountIdsAddingParent and accountMap, passes to service.
     * @param newAccounts List of updated Account records
     * @param oldAccountsMap Map of Id to old Account records
     */
    public static void validateParentChildHierarchy(
        List<Account> newAccounts,
        Map<Id, Account> oldAccountsMap
    ) {
        if (newAccounts == null || newAccounts.isEmpty() || oldAccountsMap == null) {
            return;
        }
        Set<Id> accountIdsAddingParent = new Set<Id>();
        Map<Id, Account> accountMap = new Map<Id, Account>();
        for (Account acc : newAccounts) {
            if (acc.RecordTypeId != ConstantsUtil.ACCOUNT_PRACTICE_RT) {
                continue;
            }
            Account oldAcc = oldAccountsMap.get(acc.Id);
            Boolean isAddingParent = String.isNotBlank(acc.ParentId) &&
                oldAcc != null &&
                acc.ParentId != oldAcc.ParentId;
            if (isAddingParent) {
                accountIdsAddingParent.add(acc.Id);
                accountMap.put(acc.Id, acc);
            }
        }
        TerritoryHierarchyService.addHierarchyErrors(accountIdsAddingParent, accountMap);
    }

    /**
     * @description Processes accounts where Apply_Territory_to_Hierarchy__c was checked.
     *              Enqueues job to update child accounts' Territory_Alias__c from parent.
     * @param updatedAccounts List of updated Account records
     * @param oldAccountsMap Map of old Account records before update
     */
    public static void processApplyTerritoryToHierarchy(
        List<Account> updatedAccounts,
        Map<Id, Account> oldAccountsMap
    ) {
        if (updatedAccounts == null || updatedAccounts.isEmpty() || oldAccountsMap == null) {
            return;
        }

        Set<Id> parentAccountIds = filterAccountsWithApplyTerritoryChecked(updatedAccounts, oldAccountsMap);

        if (parentAccountIds != null && !parentAccountIds.isEmpty()) {
            TerritoryHierarchyService.enqueueApplyTerritoryJob(parentAccountIds);
        }
    }

    /**
     * @description Filters accounts where Apply_Territory_to_Hierarchy__c changed from false to true.
     *              Returns parent Account IDs that should have their child accounts updated.
     *              Only includes Practice record type accounts.
     * @param updatedAccounts List of updated Account records from trigger context
     * @param oldAccountsMap Map of old Account records before update (Trigger.oldMap)
     * @return Set of parent Account IDs where Apply_Territory_to_Hierarchy__c was checked
     */
    @TestVisible
    private static Set<Id> filterAccountsWithApplyTerritoryChecked(
        List<Account> updatedAccounts,
        Map<Id, Account> oldAccountsMap
    ) {
        Set<Id> accountIds = new Set<Id>();

        for (Account newAcc : updatedAccounts) {
            if (oldAccountsMap != null && oldAccountsMap.containsKey(newAcc.Id) 
                && newAcc.RecordTypeId == ConstantsUtil.ACCOUNT_PRACTICE_RT 
                && oldAccountsMap.get(newAcc.Id).Apply_Territory_to_Hierarchy__c == false && newAcc.Apply_Territory_to_Hierarchy__c == true) {
                accountIds.add(newAcc.Id);
            }
        }

        return accountIds;
    }
}