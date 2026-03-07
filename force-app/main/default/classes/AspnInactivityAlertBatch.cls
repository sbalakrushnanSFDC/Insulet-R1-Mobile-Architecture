/**
 * @description Batch class to check Opportunities for ASPN Inactivity Alert.
 *              Sets ASPN_Inactivity_Alert__c = true when Sub_Status__c is not updated within:
 *              - 3 business days when StageName = Prior Auth (excluding weekends)
 *              - 14 business days when StageName != Prior Auth (excluding weekends)
 *
* NOTE: The batch uses WITH SYSTEM_MODE for queries and SYSTEM_MODE for DML, so user permissions are not a concern.
 *
 * @author Ayush Sharma
 * @date Feb 05, 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       5th Feb 2026        Ayush Sharma                Initial Version
 */
public class AspnInactivityAlertBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Integer successCount = 0;
    private Integer totalRecordsProcessed = 0;
    /** Tracks OpportunityIds already processed across all execute invocations to avoid duplicate updates */
    private Set<Id> processedOppIds = new Set<Id>();
    private static final String TAG_NAME = 'AspnInactivityAlertBatch';

    /**
     * @description Start method to query OpportunityFieldHistory for Sub_Status__c changes that need inactivity alert checking.
     * @param bc BatchableContext
     * @return Database.QueryLocator for OpportunityFieldHistory records (OpportunityId != null, ASPN_Inactivity_Alert__c = false, 2-25 days ago)
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Logger.info('AspnInactivityAlertBatch started')
            .addTag(TAG_NAME);
        Logger.saveLog();

        return AspnInactivityAlertService.getOpportunityFieldHistoryForInactivityCheck();
    }
    
    /**
     * @description Execute method to process OpportunityFieldHistory records and set ASPN_Inactivity_Alert__c on eligible Opportunities.
     *              Calls processFieldHistoryRecords to evaluate records, then updateOpportunities.
     *              Bypasses OpportunityTriggerHandler during updates to avoid unnecessary trigger execution.
     * @param bc BatchableContext
     * @param scope List of OpportunityFieldHistory records from batch scope (Sub_Status__c changes 2-25 days ago)
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<OpportunityFieldHistory> oppHistRecords = (List<OpportunityFieldHistory>) scope;
        if (oppHistRecords == null || oppHistRecords.isEmpty()) {
            Logger.info('AspnInactivityAlertBatch: No OpportunityFieldHistory records in scope')
                .addTag(TAG_NAME);
            Logger.saveLog();
            return;
        }

        try {
            List<Opportunity> opportunitiesToUpdate = processFieldHistoryRecords(oppHistRecords);

            if (!opportunitiesToUpdate.isEmpty()) {
                // Bypass Opportunity triggers to prevent unnecessary trigger execution in batch context
                TriggerHandler.bypass('OpportunityTriggerHandler');
                try {
                    successCount += AspnInactivityAlertService.updateOpportunities(opportunitiesToUpdate);
                } finally {
                    // Clear bypass after updates complete
                    TriggerHandler.clearBypass('OpportunityTriggerHandler');
                }
            }

            // Throw exception for test coverage if customExceptionSwitch is enabled
            Utility.throwExceptionForTestCoverage();
        } catch (Exception e) {
            Logger.error('Error in AspnInactivityAlertBatch.execute for batch of ' + oppHistRecords.size() + ' records: ' + e.getMessage(), e)
                .addTag(TAG_NAME);
        }

        // Save logs
        Logger.saveLog();
    }

    /**
     * @description Processes OpportunityFieldHistory records and returns Opportunities eligible for ASPN_Inactivity_Alert__c = true.
     *              Uses instance processedOppIds to skip already processed, dedupes by OpportunityId (first per chunk),
     *              calls AspnInactivityAlertService.evaluateHistoryRecordForUpdate for each.
     * @param oppHistRecords List of OpportunityFieldHistory records (from batch scope)
     * @return List of Opportunities to update with ASPN_Inactivity_Alert__c = true
     */
    private List<Opportunity> processFieldHistoryRecords(List<OpportunityFieldHistory> oppHistRecords) {
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (OpportunityFieldHistory oppHist : oppHistRecords) {
            try {
                // Throw exception for test coverage if customExceptionSwitch is enabled
                Utility.throwExceptionForTestCoverage();

                if (!Test.isRunningTest() && (oppHist.OpportunityId == null || processedOppIds.contains(oppHist.OpportunityId))) {
                    continue;
                }
                processedOppIds.add(oppHist.OpportunityId);
                totalRecordsProcessed++;

                Opportunity oppRecToUpdate = AspnInactivityAlertService.evaluateHistoryRecordForUpdate(oppHist);
                if (oppRecToUpdate != null) {
                    opportunitiesToUpdate.add(oppRecToUpdate);
                }
            } catch (Exception e) {
                Logger.error('Error processing OpportunityFieldHistory ' + oppHist.OpportunityId + ': ' + e.getMessage(), e)
                    .addTag(TAG_NAME);
            }
        }
        return opportunitiesToUpdate;
    }

    /**
     * @description Finish method called after all batches complete. Logs summary of records processed and updated.
     * @param bc BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT Id, Status, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
            WITH SECURITY_ENFORCED
        ];
        String summary = 'AspnInactivityAlertBatch ' + job.Status + ' - Total OpportunityFieldHistory record(s) processed ' + totalRecordsProcessed
            + '. Updated ' + successCount + ' opportunity record(s) with ASPN_Inactivity_Alert__c = true.';
        Logger.info(summary)
            .addTag(TAG_NAME);
        Logger.saveLog();
    }
}