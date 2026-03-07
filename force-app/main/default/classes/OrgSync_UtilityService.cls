/**
 * @description Utility Class for Patient/Physician Sync.
 *              Contains common methods to be used for syncing.
 * Created Date : Jan 20, 2026
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 20, 2026        Neeraj Kumar            Initial Version
 * V1.0.1       Jan 21, 2026        Pradip Kokate          Added method to get Provider NPI values from Identifier records
 * V1.0.2       Feb 10, 2026        Neeraj Kumar            Added variables for controlling recursion(NGCRMI-2467)
 * V1.0.2		Feb 17, 2026		Neeraj Kumar			Added method to generate unique external Id
 * V1.0.3		Feb 18, 2026		Neeraj Kumar			Converted the metadata variable to a list for for empty soql
 * V1.0.4		Feb 24, 2026		Neeraj Kumar			Added provider recursion flags for contact point reverse sync
 * V1.0.5		Feb 24, 2026		Neeraj Kumar			Cached getProviderNPIs and queryAccountsWithFieldSet per transaction
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount,PMD.CognitiveComplexity,PMD.ApexDoc')
public inherited sharing class OrgSync_UtilityService {

    /**Public Static Variables */
    public static Id orgSyncUserId;
    public static Set<Id> parentIds = new Set<Id>();
    public static Boolean isPatientCPPRecsCreated = false;
    public static Boolean isPatientCPARecsCreated = false;
    public static Boolean isPatientCPERecsCreated = false;
    public static Boolean isProviderCPPRecsCreated = false;
    public static Boolean isProviderCPARecsCreated = false;
    public static Boolean isProviderCPERecsCreated = false;
    public static Boolean isProviderContactPointReverseSyncInProgress = false;

    /** Private Static Variables */
    private static List<String> cachedGuardianDemographicFields;
    private static Map<Id, String> cachedProviderNPIs;
    private static Map<String, List<Account>> cachedAccountsWithFieldSet;


    /** Public Static Methods */
    /**
     * @description Checks if the current user is the OrgSync User.
     * @return Boolean True if current user is OrgSync User, else false.
     */
    public static boolean isOrgSyncUser() {
        if(orgSyncUserId == null){
            // Assign to a List to avoid QueryException if empty
            List<XCDC_Connection__mdt> connections = [
                SELECT Current_Org_API_User__c 
                FROM XCDC_Connection__mdt 
                WHERE Current_Org_API_User__c != null  
                WITH SYSTEM_MODE 
                LIMIT 1
            ];
            
            if(!connections.isEmpty()){
                orgSyncUserId = connections[0].Current_Org_API_User__c;
            }
        }
        return orgSyncUserId == UserInfo.getUserId();
    }

    /**
     * @description Extracts External IDs from staging records.
     * @param records List of staging records.
     * @return Set<String> Set of External IDs.
     */
    public Static Set<String> extractExternalIds(List<OrgSync_Patient_Staging__c> records) {
        Set<String> externalIds = new Set<String>();
        for (OrgSync_Patient_Staging__c record : records) {
            if (String.isNotBlank(record.XCDC_ExternalId__c)) {
                externalIds.add(record.XCDC_ExternalId__c);
            }
        }
        return externalIds;
    }

    /**
     * @description Gets the field set members for a given Object and FieldSet Name.
     * @param objectName The API name of the object.
     * @param fieldSetName The API name of the field set.
     * @return List<Schema.FieldSetMember> List of field set members.
     */
    public static List<Schema.FieldSetMember> getFieldSetMembers(String objectName, String fieldSetName) {
        Schema.SObjectType token = Schema.getGlobalDescribe().get(objectName);
        if (token != null) {
            Schema.DescribeSObjectResult dr = token.getDescribe();
            if (dr.fieldSets.getMap().containsKey(fieldSetName)) {
                return dr.fieldSets.getMap().get(fieldSetName).getFields();
            }
        }
        return new List<Schema.FieldSetMember>();
    }

    /**
     * @description Queries Account records with base fields plus validated field set fields.
     * Caches results per transaction to avoid redundant queries when invoked multiple times
     * with the same account IDs and field set (e.g. from handleUpsertProviderToStaging).
     * Field names are validated against Account schema - only metadata-defined fields are used.
     */
    @SuppressWarnings('PMD.ApexSOQLInjection') // Field list validated via Schema.SObjectType.Account.fields.getMap()
    public static List<Account> queryAccountsWithFieldSet(Set<Id> accountIds, List<Schema.FieldSetMember> fieldSetMembers) {
        if (accountIds == null || accountIds.isEmpty()) {
            return new List<Account>();
        }

        String cacheKey = getAccountsWithFieldSetCacheKey(accountIds, fieldSetMembers);
        if (cachedAccountsWithFieldSet != null && cachedAccountsWithFieldSet.containsKey(cacheKey)) {
            return cachedAccountsWithFieldSet.get(cacheKey);
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();
        Set<String> fields = new Set<String>{ 'Id', 'FirstName', 'LastName', 'Custom_UniqueID__c', 'RecordTypeId' };
        if (fieldSetMembers != null) {
            for (Schema.FieldSetMember fsm : fieldSetMembers) {
                if (fieldMap.containsKey(fsm.getFieldPath())) {
                    fields.add(fsm.getFieldPath());
                }
            }
        }
        String soql = 'SELECT ' + String.join(new List<String>(fields), ', ') + ' FROM Account WHERE Id IN :accountIds WITH SYSTEM_MODE';
        List<Account> accounts = (List<Account>) Database.query(soql);

        if (cachedAccountsWithFieldSet == null) {
            cachedAccountsWithFieldSet = new Map<String, List<Account>>();
        }
        cachedAccountsWithFieldSet.put(cacheKey, accounts);
        return accounts;
    }

    /**
     * @description Builds a stable cache key for queryAccountsWithFieldSet.
     * @param accountIds Set of Account IDs.
     * @param fieldSetMembers Field set members (can be null).
     * @return String Cache key.
     */
    private static String getAccountsWithFieldSetCacheKey(Set<Id> accountIds, List<Schema.FieldSetMember> fieldSetMembers) {
        List<String> idStrs = new List<String>();
        for (Id aid : accountIds) {
            idStrs.add(String.valueOf(aid));
        }
        idStrs.sort();
        String idKey = String.join(idStrs, ',');

        List<String> fieldPaths = new List<String>();
        if (fieldSetMembers != null) {
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Account.fields.getMap();
            for (Schema.FieldSetMember fsm : fieldSetMembers) {
                if (fieldMap.containsKey(fsm.getFieldPath())) {
                    fieldPaths.add(fsm.getFieldPath());
                }
            }
            fieldPaths.sort();
        }
        String fieldKey = String.join(fieldPaths, ',');
        return idKey + '|' + fieldKey;
    }

    /**
     * @description Maps the target field name to the source field name.
     * @param targetFieldName String target field name.
     * @return String source field name.
     */
    public static String mapTargetToSourceField(String targetFieldName) {
        String sourceFieldName = targetFieldName;
        if (!sourceFieldName.startsWithIgnoreCase('OrgSync_') && !sourceFieldName.startsWithIgnoreCase('XCDC_')) {
            sourceFieldName = 'OrgSync_' + sourceFieldName;
        }
        if (!sourceFieldName.endsWithIgnoreCase('__c')) {
            sourceFieldName = sourceFieldName + '__c';
        }
        if (sourceFieldName == 'OrgSync_Sensor_CGM_Continuous_Glucose_Monitor__c') {
            sourceFieldName = 'OrgSync_Sensor_Continuous_GlucoseMonitor__c';
        }
        return sourceFieldName;
    }

    /**
     * @description Extracts External IDs from Account records.
     * @param records List of Account records.
     * @return Set<String> Set of External IDs.
     */
    public Static Set<String> extractExternalIdsFromAccounts(List<Account> records) {
        Set<String> externalIds = new Set<String>();
        for (Account acc : records) {
            if (String.isNotBlank(acc.XCDC_ExternalId__c)) {
                externalIds.add(acc.XCDC_ExternalId__c);
            }
        }
        return externalIds;
    }

    /**
     * @description Gets Provider NPI values from Identifier records.
     *              Caches results per transaction to avoid redundant queries when
     *              handleUpsertProviderToStaging is invoked multiple times.
     * @param providerAccountIds Set of Provider Account IDs
     * @return Map of Provider Account ID to NPI (ID_Value__c)
     */
    public static Map<Id, String> getProviderNPIs(Set<Id> providerAccountIds) {
        Map<Id, String> providerAccountToNPIMap = new Map<Id, String>();

        if (providerAccountIds == null || providerAccountIds.isEmpty()) {
            return providerAccountToNPIMap;
        }

        if (cachedProviderNPIs == null) {
            cachedProviderNPIs = new Map<Id, String>();
        }

        Set<Id> uncachedIds = new Set<Id>();
        for (Id accId : providerAccountIds) {
            if (cachedProviderNPIs.containsKey(accId)) {
                providerAccountToNPIMap.put(accId, cachedProviderNPIs.get(accId));
            } else {
                uncachedIds.add(accId);
            }
        }

        if (uncachedIds.isEmpty()) {
            return providerAccountToNPIMap;
        }

        for (Identifier identifier : [
            SELECT Id, ParentRecordId, ID_Value__c
            FROM Identifier
            WHERE ParentRecordId IN :uncachedIds
                AND IdUsageType = :ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
                AND ID_Value__c != null
            WITH SYSTEM_MODE
        ]) {
            if (identifier.ParentRecordId != null && String.isNotBlank(identifier.ID_Value__c)) {
                cachedProviderNPIs.put(identifier.ParentRecordId, identifier.ID_Value__c);
                providerAccountToNPIMap.put(identifier.ParentRecordId, identifier.ID_Value__c);
            }
        }
        for (Id accId : uncachedIds) {
            if (!cachedProviderNPIs.containsKey(accId)) {
                cachedProviderNPIs.put(accId, '');
            }
        }
        return providerAccountToNPIMap;
    }
    
    /**
     * @description Generates a unique external ID to avoid conflicts in parallel tests
     * @param prefix A short prefix to identify the test context
     * @return String A unique external ID
     */
    public static String generateUniqueExtId(String prefix) {
        return prefix + '-' + String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 4);
    }    

    /**
     * @description Returns Guardian demographic field API names: First/Last Name prepended to OrgSync_Guardian_Demographic_Fields field set.
     * @return List<String> Field API names
     */
    public static List<String> getGuardianDemographicFieldNames() {
        if (cachedGuardianDemographicFields != null) {
            return cachedGuardianDemographicFields;
        }
        List<String> fields = new List<String>{
            'OrgSync_Guardian_1_First_Name__c', 'OrgSync_Guardian_1_Last_Name__c',
            'OrgSync_Guardian_2_First_Name__c', 'OrgSync_Guardian_2_Last_Name__c'
        };
        for (Schema.FieldSetMember fsm : getFieldSetMembers('OrgSync_Patient_Staging__c', 'OrgSync_Guardian_Demographic_Fields')) {
            fields.add(fsm.getFieldPath());
        }
        cachedGuardianDemographicFields = fields;
        return fields;
    }

    /**
     * @description Checks if any Guardian demographic field has changed between old and new staging record.
     * @param newRecord New staging record
     * @param oldRecord Old staging record (null for insert)
     * @return Boolean True if any guardian demographic field changed
     */
    public static Boolean hasGuardianDemographicFieldsChanged(OrgSync_Patient_Staging__c newRecord, OrgSync_Patient_Staging__c oldRecord) {
        if (oldRecord == null) {
            return true;
        }
        for (String fieldName : getGuardianDemographicFieldNames()) {
            Object newVal = newRecord.get(fieldName);
            Object oldVal = oldRecord.get(fieldName);
            if (newVal != oldVal && (newVal == null || oldVal == null || !String.valueOf(newVal).equals(String.valueOf(oldVal)))) {
                return true;
            }
        }
        return false;
    }

    /**
     * @description Checks if Guardian N demographic fields changed (for contact point processing - only update the guardian that changed).
     * @param newRecord New staging record
     * @param oldRecord Old staging record (null for insert)
     * @param guardianIndex Guardian index (1 or 2)
     * @return Boolean True if guardian N's demographic fields changed
     */
    public static Boolean hasGuardianNDemographicFieldsChanged(OrgSync_Patient_Staging__c newRecord, OrgSync_Patient_Staging__c oldRecord, Integer guardianIndex) {
        if (oldRecord == null) {
            return true;
        }
        String prefix = 'OrgSync_Guardian_' + guardianIndex + '_';
        for (String fieldName : getGuardianDemographicFieldNames()) {
            if (fieldName.startsWith(prefix)) {
                Object newVal = newRecord.get(fieldName);
                Object oldVal = oldRecord.get(fieldName);
                if (newVal != oldVal && (newVal == null || oldVal == null || !String.valueOf(newVal).equals(String.valueOf(oldVal)))) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * @description Updates guardian fields on the Patient Staging record.
     * @param staging The staging record to update
     * @param guardianNum Guardian number (1 or 2)
     * @param con Related Contact (guardian) - null to clear fields
     */
    public static void updateGuardianFieldsOnStaging(OrgSync_Patient_Staging__c staging, Integer guardianNum, Contact con) {
        String prefix = 'OrgSync_Guardian_' + guardianNum + '_';
        staging.put(prefix + 'Name__c', con?.Name);
        staging.put(prefix + 'First_Name__c', con?.FirstName);
        staging.put(prefix + 'Last_Name__c', con?.LastName);
        staging.put(prefix + 'Email__c', con?.Email);
        staging.put(prefix + 'Home_Phone__c', con?.HomePhone);
        staging.put(prefix + 'Work_Phone__c', con?.Phone);
        staging.put(prefix + 'Mobile_Phone__c', con?.MobilePhone);
    }

    /**
     * @description Updates guardian email on Patient Staging (from CPE sync).
     * @param staging The staging record to update
     * @param guardianNum Guardian number (1 or 2)
     * @param email Email value
     */
    public static void updateGuardianEmailOnStaging(OrgSync_Patient_Staging__c staging, Integer guardianNum, String email) {
        if (staging != null && guardianNum != null && (guardianNum == 1 || guardianNum == 2)) {
            staging.put('OrgSync_Guardian_' + guardianNum + '_Email__c', email);
        }
    }

    /**
     * @description Updates guardian phone field on Patient Staging by UsageType (from CPP sync).
     * @param staging The staging record to update
     * @param guardianNum Guardian number (1 or 2)
     * @param usageType Home, Work, or Mobile
     * @param phoneNumber Phone value
     */
    public static void updateGuardianPhoneOnStaging(OrgSync_Patient_Staging__c staging, Integer guardianNum, String usageType, String phoneNumber) {
        if (staging == null || guardianNum == null || (guardianNum != 1 && guardianNum != 2) || String.isBlank(usageType)) {
            return;
        }
        String fieldSuffix = (usageType == 'Home') ? 'Home_Phone__c' : (usageType == 'Work') ? 'Work_Phone__c' : (usageType == 'Mobile') ? 'Mobile_Phone__c' : null;
        if (fieldSuffix != null) {
            staging.put('OrgSync_Guardian_' + guardianNum + '_' + fieldSuffix, phoneNumber);
        }
    }

    /**
     * @description Sanitizes phone number to contain only digits.
     * @param phoneNumber The phone number to sanitize
     * @return String Sanitized phone number or original if blank
     */
    public static String sanitizePhoneNumber(String phoneNumber) {
        if (String.isBlank(phoneNumber)) {
            return phoneNumber;
        }
        return phoneNumber.replaceAll('[^0-9]', '');
    }
}