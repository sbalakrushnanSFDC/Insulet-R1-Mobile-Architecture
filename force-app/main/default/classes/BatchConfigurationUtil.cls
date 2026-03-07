/**
 * @description Utility class to retrieve batch configuration from Custom Metadata.
 *              Provides centralized access to Batch_Configuration__mdt records
 *              for all batch classes in the org. Supports caching for performance.
 *
 * @author      Niranjan Elangovan
 * @createdDate November 16, 2025
 *
 * Usage Example:
 *     Integer batchSize = BatchConfigurationUtil.getBatchSize('TerritoryAliasSyncBatch');
 *     Integer waitTime = BatchConfigurationUtil.getWaitTimeAfterCreation('DTCIncompleteTaskBatch');
 *     Integer window = BatchConfigurationUtil.getProcessingWindow('DTCIncompleteTaskBatch');
 *
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Nov 16, 2025        Niranjan Elangovan      Initial Version
 * V1.1.0       Dec 19, 2025        Anup Bandawar           Added Wait Time and Processing Window support
 */
public inherited sharing class BatchConfigurationUtil {
    private static final String TAG_NAME = 'BatchConfigurationUtil';
    private static final Integer DEFAULT_BATCH_SIZE = 200;
    private static final Integer MAX_BATCH_SIZE = 2000;
    private static final Integer MIN_BATCH_SIZE = 1;
    @TestVisible private static Map<String, Batch_Configuration__mdt> configCache = new Map<String, Batch_Configuration__mdt>();
    private static Boolean cacheLoaded = false;
    /**
     * @description Loads all batch configurations into cache
     * @comment This method is called automatically when needed, but can be called manually for testing purposes
     */
    private static void loadCache() {
        if (!cacheLoaded) {
            try {
                List<Batch_Configuration__mdt> configs = [
                    SELECT Batch_Class_Name__c, Batch_Size__c, Wait_Time_After_Creation__c, Processing_Window__c
                    FROM Batch_Configuration__mdt
                    WHERE Is_Active__c = true
                    WITH SECURITY_ENFORCED
                ];
                for (Batch_Configuration__mdt config : configs) {
                    if (String.isNotBlank(config.Batch_Class_Name__c)) {
                        configCache.put(config.Batch_Class_Name__c, config);
                    }
                }
                cacheLoaded = true;
            } catch (Exception e) {
                Logger.error('Error loading batch configurations: ' + e.getMessage(), e)
                    .addTag(TAG_NAME);
            }
        }
    }
    /**
     * @description Gets the batch size for a specific batch class
     * @param batchClassName The API name of the batch class
     * @return Integer batch size (defaults to 200 if not found)
     */
    public static Integer getBatchSize(String batchClassName) {
        if (String.isBlank(batchClassName)) {
            return DEFAULT_BATCH_SIZE;
        }
        loadCache();
        Batch_Configuration__mdt config = configCache.get(batchClassName);
        if (config != null && config.Batch_Size__c != null) {
            Integer batchSize = config.Batch_Size__c.intValue();
            return validateBatchSize(batchSize);
        }
        return DEFAULT_BATCH_SIZE;
    }
    /**
     * @description Validates batch size is within Salesforce limits
     * @param batchSize The batch size to validate
     * @return Integer validated batch size
     */
    @TestVisible
    private static Integer validateBatchSize(Integer batchSize) {
        if (batchSize < MIN_BATCH_SIZE) {
            Logger.warn('Batch size ' + batchSize + ' is below minimum (' + MIN_BATCH_SIZE + '). Using minimum.')
                .addTag(TAG_NAME);
            return MIN_BATCH_SIZE;
        }
        if (batchSize > MAX_BATCH_SIZE) {
            Logger.warn('Batch size ' + batchSize + ' exceeds maximum (' + MAX_BATCH_SIZE + '). Using maximum.')
                .addTag(TAG_NAME);
            return MAX_BATCH_SIZE;
        }
        return batchSize;
    }
    /**
     * @description Gets the wait time after creation (in minutes) for a specific batch class
     * @param batchClassName The API name of the batch class
     * @return Integer wait time in minutes (returns null if not configured)
     */
    public static Integer getWaitTimeAfterCreation(String batchClassName) {
        if (String.isBlank(batchClassName)) {
            return null;
        }
        loadCache();
        Batch_Configuration__mdt config = configCache.get(batchClassName);
        if (config != null && config.Wait_Time_After_Creation__c != null) {
            return config.Wait_Time_After_Creation__c.intValue();
        }
        return null;
    }

    /**
     * @description Gets the processing window (in minutes) for a specific batch class
     * @param batchClassName The API name of the batch class
     * @return Integer processing window in minutes (returns null if not configured)
     */
    public static Integer getProcessingWindow(String batchClassName) {
        if (String.isBlank(batchClassName)) {
            return null;
        }
        loadCache();
        Batch_Configuration__mdt config = configCache.get(batchClassName);
        if (config != null && config.Processing_Window__c != null) {
            return config.Processing_Window__c.intValue();
        }
        return null;
    }

    /**
     * @description Clears the configuration cache (useful for testing)
     */
    @TestVisible
    private static void clearCache() {
        configCache.clear();
        cacheLoaded = false;
    }
}