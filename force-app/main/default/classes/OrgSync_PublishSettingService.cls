/**
 * @description Service class responsible for dynamically retrieving OrgSync publish settings
 *              based on sObject type. This class follows the Service Layer pattern
 *              and is designed to be bulk-safe, secure, and governor limit-aware.
 *              This service is GENERIC and works with ANY sObject type.
 * Created Date : Nov 17, 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Nov 17, 2025        Ramesh Dhaka            Initial Version
 */
public inherited sharing class OrgSync_PublishSettingService {
    /**
     * @description Cache to store publish settings to avoid repeated SOQL queries
     */
    private static Map<String, OrgSync_PublishSetting_Mapping__mdt> publishSettingCache;
    private static String operationType;

    /**
     * @description Invokes the OrgSync package with dynamically retrieved publish settings
     *              for ANY sObject records. This method is bulk-safe and can handle 200+ records.
     *              This is a GENERIC method that works with any sObject type.
     * @param newRecords List of SObject records from trigger context (e.g., List<Account>, List<Lead>, etc.)
     * @param oldMap Map of old SObject records (can be null for insert operations)
     * @param operation The operation type (e.g., XCDC_Constants.OPERATION_INSERT or OPERATION_UPDATE)
     * @example
     * For Account
     * OrgSyncPublishSettingService.invokeOrgSync(newAccounts, oldAccountMap, 'INSERT');
     * For Lead
     * OrgSyncPublishSettingService.invokeOrgSync(newLeads, oldLeadMap, 'UPDATE');
     */
    public static void invokeOrgSync(List<SObject> newRecords, Map<Id, SObject> oldMap, String operation) {
        // Guard clause for null or empty input
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        try {
            operationType = operation;
            // Determine the sObject type from the first record
            String sObjectType = String.valueOf(newRecords[0].getSObjectType());
            // Get publish setting metadata (only one per sObject type)
            OrgSync_PublishSetting_Mapping__mdt publishSetting = getPublishSetting(sObjectType);
            // If no publish setting found, log error and return
            if (publishSetting == null) {
                return;
            }
            // Process all records with the publish setting
            processRecords(newRecords, oldMap, publishSetting);
        } catch (Exception e) {
            // Log exception for monitoring
            Logger.error('Exception in OrgSyncPublishSettingService: ' + e.getMessage()).addTag('OrgSync');
            Logger.saveLog();
        }
    }

    /**
     * @description Generates External Id for the records
     *              It generates the External Id based on the Org Settings and the sObject type.
     *              It should be invoked on before insert of the records where ever using staging object for sync
     * @param records List of sObject records
     */
    public static void generateExternalId(List<SObject> records){
        for(SObject record : records){
            if(record.get('XCDC_ExternalId__c') == null){
                String extIdPrefix = XCDC_OrgSettings__c.getInstance().ExternalIdOrgprefix__c
                                + XCDC_Constants.HYPHEN
                                + record.getSObjectType().getDescribe().getKeyPrefix()
                                + XCDC_Constants.HYPHEN;
                record.put('XCDC_ExternalId__c', new XCDC_Uuid(extIdPrefix).getValue());
            }
        }
    }
    /**
     * @description Retrieves publish setting metadata based on sObject type
     * @param sObjectType The API name of the sObject (e.g., 'Account')
     * @return The publish setting metadata, or null if not found
     */
    public static OrgSync_PublishSetting_Mapping__mdt getPublishSetting(String sObjectType) {
        // Guard clause for null inputs
        if (String.isBlank(sObjectType)) {
            return null;
        }
        // Initialize cache if not already done
        if (publishSettingCache == null) {
            loadPublishSettingsCache();
        }
        // Create a unique key for cache lookup
        String cacheKey = buildCacheKey(sObjectType);
        // Return cached value if exists
        return publishSettingCache.get(cacheKey);
    }
    /**
     * @description Loads all active publish settings into cache to avoid repeated SOQL queries.
     *              This method is called only once per transaction.
     */
    @TestVisible
    private static void loadPublishSettingsCache() {
        publishSettingCache = new Map<String, OrgSync_PublishSetting_Mapping__mdt>();
        try {
            // Query all active publish settings with security enforced
            List<OrgSync_PublishSetting_Mapping__mdt> settings = [
                SELECT
                    Id,
                    DeveloperName,
                    SObject_API_Name__c,
                    Publish_Setting_Developer_Name__c,
                    IsActive__c,
                    IsRaceConditionApplicable__c
                FROM OrgSync_PublishSetting_Mapping__mdt
                WHERE IsActive__c = true
                WITH SYSTEM_MODE
            ];
            // Build cache map
            for (OrgSync_PublishSetting_Mapping__mdt setting : settings) {
                String cacheKey = buildCacheKey(setting.SObject_API_Name__c);
                publishSettingCache.put(cacheKey, setting);
            }
        } catch (Exception e) {
            // Log exception and initialize empty cache to prevent null pointer
            Logger.error('Failed to load publish settings cache: ' + e.getMessage())
                .addTag('OrgSync');
            publishSettingCache = new Map<String, OrgSync_PublishSetting_Mapping__mdt>();
        }
    }

    /**
     * @description Builds a cache key from sObject type
     * @param sObjectType The API name of the sObject
     * @return A unique cache key string
     */
    @TestVisible
    private static String buildCacheKey(String sObjectType) {
        return String.isNotBlank(sObjectType) ? sObjectType.toLowerCase() : '';
    }

    /**
     * @description Processes records with their publish setting.
     *              Since there's only one publish setting per sObject type, all records are processed together.
     * @param records List of records to process
     * @param oldMap Map of old SObject records (null for INSERT, populated for UPDATE)
     * @param publishSetting The publish setting metadata for this sObject type
     */
    @TestVisible
    private static void processRecords(
        List<SObject> records,
        Map<Id, SObject> oldMap,
        OrgSync_PublishSetting_Mapping__mdt publishSetting
    ) {
        // Guard clause
        if (records == null || records.isEmpty() || publishSetting == null) {
            return;
        }

        try {
            // Create a filtered oldMap for these records
            Map<Id, SObject> filteredOldMap = filterOldMap(oldMap, records);
            // Get values from metadata
            String publishSettingName = publishSetting.Publish_Setting_Developer_Name__c;
            Boolean isRaceConditionApplicable = publishSetting.IsRaceConditionApplicable__c;

            // Invoke OrgSync handler
            XCDC_sObjectPublishHandler publishHandler = new XCDC_sObjectPublishHandler();
            publishHandler.processRecordsForPublisher(
                records,
                filteredOldMap,
                publishSettingName,
                operationType,
                isRaceConditionApplicable
            );
        } catch (Exception e) {
            Logger.error('Failed to process records: ' + e.getMessage())
                .addTag('OrgSync');
        }
    }

    /**
     * @description Filters old map to include only records from the records list
     * @param oldMap Original old map from trigger context
     * @param records List of sObject records to filter for
     * @return Filtered map containing only relevant old records
     */
    @TestVisible
    private static Map<Id, SObject> filterOldMap(Map<Id, SObject> oldMap, List<SObject> records) {
        Map<Id, SObject> filteredMap = new Map<Id, SObject>();
        if (oldMap == null || records == null) {
            return filteredMap;
        }
        for (SObject record : records) {
            if (oldMap.containsKey(record.Id)) {
                filteredMap.put(record.Id, oldMap.get(record.Id));
            }
        }
        return filteredMap;
    }

    /**
     * @description Clears the publish settings cache. Used primarily for testing.
     */
    @TestVisible
    private static void clearCache() {
        publishSettingCache = null;
    }
}