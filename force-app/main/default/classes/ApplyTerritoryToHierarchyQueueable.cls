/**
 * @description Queueable to apply Parent Territory_Alias__c to practice child accounts.
 *              Invoked when Apply_Territory_to_Hierarchy__c is checked on Account.
 * 
 * NOTE: This class is declared as without sharing to ensure that it can access all practice account records.
 *       This is necessary to access all practice child accounts and updates the Territory Alias, regardless of sharing.
 * 
 * @author      Ayush Sharma
 * @created     19th Feb 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       19th Feb 2026       Ayush Sharma            Initial Version
 */
public without sharing class ApplyTerritoryToHierarchyQueueable implements Queueable {

    private Set<Id> parentAccountIds;

    /**
     * @description Constructor
     * @param parentIds Set of parent Account IDs
     */
    public ApplyTerritoryToHierarchyQueueable(Set<Id> parentIds) {
        this.parentAccountIds = parentIds != null ? new Set<Id>(parentIds) : new Set<Id>();
    }

    /**
     * @description Execute - runs synchronously (useRunAsQueueable=false since we're already in a queueable).
     *              Applies parent Territory_Alias__c to child Practice accounts.
     * @param context QueueableContext provided by the platform
     */
    public void execute(QueueableContext context) {
        if (parentAccountIds == null || parentAccountIds.isEmpty()) {
            return;
        }

        if (!Test.isRunningTest()) {
            System.attachFinalizer(new TerritoryHierarchyFinalizer(parentAccountIds));
        }

        TerritoryHierarchyService.applyTerritoryToChildAccounts(parentAccountIds);
        // Save logs
        Logger.saveLog();
    }

    /**
     * @description Finalizer class to handle cleanup and error scenarios for unhandled exceptions
     */
    @TestVisible
    public class TerritoryHierarchyFinalizer implements System.Finalizer {
        private Set<Id> parentAccountIds;

        /**
         * @description Constructor
         * @param parentIds Parent Account IDs that were being processed
         */
        public TerritoryHierarchyFinalizer(Set<Id> parentIds) {
            this.parentAccountIds = parentIds;
        }

        /**
         * @description Execute method called when Queueable job completes or fails
         * @param context FinalizerContext containing job status and exception information
         */
        public void execute(System.FinalizerContext context) {
            if (context.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
                List<SObject> accountRecords = new List<SObject>();
                if (parentAccountIds != null) {
                    for (Id parentId : parentAccountIds) {
                        accountRecords.add(new Account(Id = parentId));
                    }
                }
                Logger.error(
                    'Apply Territory to Hierarchy job failed with unhandled exception: ' +
                    (context.getException() != null ? context.getException().getMessage() : 'Unknown error'),
                    accountRecords,
                    context.getException()
                ).addTag(ConstantsUtil.ASIM_TAG);
                Logger.saveLog();
            }
        }
    }
}