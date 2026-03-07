/**
* @author      : Jatin Butta
* @created Date: 17th Nov 2025
* @description : Batch class to update Territory_Alias__c on Account records
*                when Territory_Name__c changes on ZipCode__c records.
*                Uses BillingPostalCode to match against ZipCode__c.Name
*
* Version      Modified Date       Modified By             Brief Note
* V1.0.0       17th Nov 2025       Jatin Butta             Initial Version (US - NGASIM-1166)
* V1.0.1       29th Dec 2025       Srinivas Shanigarapu    Updated(US - NGOMCT-235)
* V1.0.2       25th Feb 2026       Ayush Sharma            Updated(US - NGASIM-1062) - Added Parent_Territory_Alias = null check
*/
public class TerritoryAliasAccountBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Integer successCount = 0;
    private Integer totalRecordsProcessed = 0;
    private static final String TAG_NAME = ConstantsUtil.ASIM_TAG;
    private static final String TERRITORY_HIERARCHY_BATCH_CLASS_NAME = 'TerritoryHierarchyBatch';
    @TestVisible
    private static Boolean simulateResult = false;
    
    /**
     * @description Start method to query Accounts that need Territory_Alias__c update
     * @param bc BatchableContext
     * @return Database.QueryLocator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Set<String> changedZipCodes = new Set<String>();
        
        try {
            // Get changed zip codes from today's history records using service class
            changedZipCodes = TerritoryAliasService.getChangedZipCodesToday();
            Logger.info(
                'TerritoryAliasAccountBatch started. Found ' +
                changedZipCodes.size() +
                ' changed zip codes.'
            ).addTag(TAG_NAME);
        } catch (Exception ex) {
            Logger.error('Error retrieving changed zip codes in start method', ex).addTag(TAG_NAME);
        }
        // Save logs
        Logger.saveLog();
        
        // Query Accounts using BillingPostalCode that matches changed zip codes
        // Filter for Practice and Trainer Person Account RecordTypes only
        Set<Id> accountRecordTypes = new Set<Id>{
            ConstantsUtil.ACCOUNT_PRACTICE_RT,
            ConstantsUtil.ACCOUNT_TRAINER_RT
        };

        String excludedSpecialty = ConstantsUtil.SPECIALTY_PEDIATRIC;
        String excludeTrainerType = ConstantsUtil.CLINIC_CONTRACT_TRAINER;
        
        return Database.getQueryLocator(
            'SELECT Id, BillingPostalCode, Territory_Alias__c, RecordTypeId, PersonContactId, Trainer_Type__c FROM Account ' +
            'WHERE BillingPostalCode IN :changedZipCodes ' +
            'AND RecordTypeId IN :accountRecordTypes ' +
            'AND Specialty__c != :excludedSpecialty ' +
            'AND Trainer_Type__c != :excludeTrainerType ' +
            'AND Parent_Territory_Alias__c = null'
        );
    }
    
    /**
     * @description Execute method to update Territory_Alias__c on Accounts
     * @param bc BatchableContext
     * @param scope List of Account records
     */
    public void execute(Database.BatchableContext bc, List<Account> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }
        
        totalRecordsProcessed += scope.size();
        
        try {
            // Extract unique zip codes from current batch
            Set<String> batchZipCodes = new Set<String>();
            for (Account acc : scope) {
                if (String.isNotBlank(acc.BillingPostalCode)) {
                    batchZipCodes.add(acc.BillingPostalCode);
                }
            }
            
            if (batchZipCodes.isEmpty()) {
                return;
            }
            
            // Get Territory Alias mapping and update accounts
            Map<String, String> zipToTerritoryAliasMap = TerritoryAliasService.getTerritoryAliasMapping(
                batchZipCodes
            );
            
            // Update accounts using service class
            TerritoryAliasService.UpdateResult result = TerritoryAliasService.updateAccountTerritoryAlias(
                scope,
                zipToTerritoryAliasMap
            );
            // Allow test to simulate result to throw exception
            if (Test.isRunningTest() && simulateResult) {
                result = null;
            }
            successCount += result.successCount;
        } catch (Exception ex) {
            Logger.error(
                'Error executing TerritoryAliasAccountBatch for batch of ' +
                scope.size() +
                ' records',
                ex
            ).addTag(TAG_NAME);
        }
        
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
        String summary =
            'TerritoryAliasAccountBatch ' +
            job.Status +
            ' - Total records processed: ' +
            totalRecordsProcessed +
            ', Success: ' +
            successCount;
        Logger.info(summary).addTag(TAG_NAME);
        
        try {
            Integer batchSize = BatchConfigurationUtil.getBatchSize(TERRITORY_HIERARCHY_BATCH_CLASS_NAME);
            if (batchSize == null || batchSize <= 0 || Test.isRunningTest()) {
                batchSize = 200;
            }
            
            TerritoryHierarchyBatch batch = new TerritoryHierarchyBatch();
            Id batchId = Database.executeBatch(batch, batchSize);
            
            Logger.info(
                'TerritoryHierarchyBatch started successfully. Batch Size: ' + batchSize +
                ', Batch ID: ' + batchId
            ).addTag(TAG_NAME);
            
            // Throw exception for test coverage if customExceptionSwitch is enabled
            Utility.throwExceptionForTestCoverage();
        } catch (Exception e) {
            Logger.error('Exception in TerritoryHierarchyScheduler: ' + e.getMessage(), e).addTag(TAG_NAME);
        }
        // Saves Log
        Logger.saveLog();
    }
}