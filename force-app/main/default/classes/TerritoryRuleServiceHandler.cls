/**
 * @description Handler class to handle territory rule assignment for accounts
 *              Filters Practice accounts where Territory_Alias__c changed
 * @author      Bijayalaxmi Prusty
 * @created     Jan 12, 2026
 *  * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.1       12th Jan 2026       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1643)
 */
public with sharing class TerritoryRuleServiceHandler {

    /**
     * @description Processes accounts to trigger territory rule assignment
     *              Filters Practice accounts where Territory_Alias__c changed
     * @param updatedAccounts List of updated Account records
     * @param oldAccountsMap Map of old Account records before update
     */
    public static void processAccountsForTerritoryRules(
        List<Account> updatedAccounts,
        Map<Id, Account> oldAccountsMap
    ) {
        // Validate input parameters
        if (updatedAccounts == null || updatedAccounts.isEmpty()) {
            return;
        }

        // Filter accounts where Territory Alias changed
        Set<Id> accountIdsToProcess = filterAccountsWithTerritoryAliasChange(
            updatedAccounts,
            oldAccountsMap
        );

        // If there are accounts to process, enqueue the territory assignment job
        if (!accountIdsToProcess.isEmpty()) {
            enqueueTerritoryAssignment(accountIdsToProcess);
        }
    }

    /**
     * @description Filters Practice accounts where Territory_Alias__c field changed
     * @param updatedAccounts List of updated Account records
     * @param oldAccountsMap Map of old Account records before update
     * @return Set of Account IDs that need territory rule assignment
     */
    private static Set<Id> filterAccountsWithTerritoryAliasChange(
        List<Account> updatedAccounts,
        Map<Id, Account> oldAccountsMap
    ) {
        Set<Id> accountIdsToProcess = new Set<Id>();

        for (Account newAccount : updatedAccounts) {
            // Check if this is a Practice account
            if (newAccount.RecordTypeId == ConstantsUtil.ACCOUNT_PRACTICE_RT ||
                newAccount.RecordTypeId == ConstantsUtil.ACCOUNT_PATIENT_RT ||
                newAccount.RecordTypeId == ConstantsUtil.ACCOUNT_TRAINER_RT) {

                // For afterUpdate, check if Territory_Alias__c changed
                if (oldAccountsMap != null && oldAccountsMap.containsKey(newAccount.Id)) {
                    Account oldAccount = oldAccountsMap.get(newAccount.Id);

                    // Check if Territory_Alias__c field changed
                    if (hasTerritoryAliasChanged(newAccount, oldAccount)) {
                        accountIdsToProcess.add(newAccount.Id);
                    }
                }
            }
        }

        return accountIdsToProcess;
    }

    /**
     * @description Checks if Territory_Alias__c field has changed
     * @param newAccount New Account record
     * @param oldAccount Old Account record
     * @return Boolean True if Territory_Alias__c changed
     */
     @testvisible
    private static Boolean hasTerritoryAliasChanged(Account newAccount, Account oldAccount) {
        if (oldAccount == null) {
            return false;
        }
        if (newAccount.Territory_Alias__c != oldAccount.Territory_Alias__c) {
            return true;
        }
        return false;
    }

    /**
     * @description Enqueues the territory assignment queueable job
     * @param accountIds Set of Account IDs to process
     */
    @TestVisible
    private static void enqueueTerritoryAssignment(Set<Id> accountIds) {
        try {
            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new TerritoryRuleServiceException('customExceptionSwitch is turned on');
            }

            // Check if we're already in a queueable context to avoid chaining limits
            if (!System.isQueueable() && !Test.isRunningTest()) {
                System.enqueueJob(new RunTerritoryRules(accountIds));
            } else if (Test.isRunningTest()) {
                // In test context, execute synchronously
                RunTerritoryRules job = new RunTerritoryRules(accountIds);
                job.execute(null);
            }
        } catch (Exception e) {
            List<SObject> accountRecords = new List<SObject>();
            for (Id accId : accountIds) {
                accountRecords.add(new Account(Id = accId));
            }
            logError('Failed to enqueue territory assignment job. Error: ' + e.getMessage(),
                    accountRecords, e);
        }
    }

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null for permission errors)
     */
     private static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    /**
     * @description Exception class for Territory Rule Service Handler
     */
    public class TerritoryRuleServiceException extends Exception {}
}