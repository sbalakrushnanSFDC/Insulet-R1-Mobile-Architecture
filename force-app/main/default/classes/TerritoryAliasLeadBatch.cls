/**
 * @author      : Jatin Butta
 * @created Date: 17th Nov 2025
 * @description : Batch class to update Territory_Alias__c on Lead records
 *                when Territory_Name__c changes on ZipCode__c records.
 *                Uses PostalCode to match against ZipCode__c.Name
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       17th Nov 2025       Jatin Butta             Initial Version (US - NGASIM-1166)
 */
public class TerritoryAliasLeadBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Integer successCount = 0;
    private Integer totalRecordsProcessed = 0;
    private static final String TAG_NAME = ConstantsUtil.ASIM_TAG;

    /**
     * @description Start method to query Leads that need Territory_Alias__c update
     * @param bc BatchableContext
     * @return Database.QueryLocator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Set<String> changedZipCodes = new Set<String>();

        try {
            // Get changed zip codes from today's history records using service class
            changedZipCodes = TerritoryAliasService.getChangedZipCodesToday();
            Logger.info('TerritoryAliasLeadBatch started. Found '
            + changedZipCodes.size()
            + ' changed zip codes.')
            .addTag(TAG_NAME);
        } catch (Exception ex) { Logger.error('Error retrieving changed zip codes in start method', ex).addTag(TAG_NAME); }

        // Query Leads using PostalCode that matches changed zip codes
        // Filter for Patient and Provider-Practice Lead RecordTypes only
        Set<Id> leadRecordTypes = new Set<Id>{
            ConstantsUtil.LEAD_PATIENT_RT
        };

        return Database.getQueryLocator(
            'SELECT Id, PostalCode, Territory_Alias__c, RecordTypeId ' +
            'FROM Lead ' +
            'WHERE PostalCode IN :changedZipCodes ' +
            'AND RecordTypeId IN :leadRecordTypes'
        );
    }

    /**
     * @description Execute method to update Territory_Alias__c on Leads
     * @param bc BatchableContext
     * @param scope List of Lead records
     */
    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        totalRecordsProcessed += scope.size();

        try {
            // Get zip codes from the current batch
            Set<String> batchZipCodes = new Set<String>();
            for (Lead ld : scope) {
                if (String.isNotBlank(ld.PostalCode)) {
                    batchZipCodes.add(ld.PostalCode);
                }
            }

            if (batchZipCodes.isEmpty()) {
                return;
            }

            // Get Territory Alias mapping using service class
            Map<String, String> zipToTerritoryAliasMap =
                TerritoryAliasService.getTerritoryAliasMapping(batchZipCodes);

            // Update leads using service class
            TerritoryAliasService.UpdateResult result =
                TerritoryAliasService.updateLeadTerritoryAlias(scope, zipToTerritoryAliasMap);
            successCount += result.successCount;

        } catch (Exception ex) { Logger.error('Error executing TerritoryAliasLeadBatch for batch of ' + scope.size() + ' records', ex).addTag(TAG_NAME); }

        // Save logs after each execute to persist errors across transactions
        Logger.saveLog();
    }

    /**
     * @description Finish method called after all batches are complete
     * @param bc BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        // Query batch job status
        AsyncApexJob job = [
            SELECT Id, Status, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
        String summary = 'TerritoryAliasLeadBatch '
            + job.Status
            + ' - Total records processed: ' + totalRecordsProcessed
            + ', Success: ' + successCount;
        Logger.info(summary)
            .addTag(TAG_NAME);
        Logger.saveLog();
    }
}