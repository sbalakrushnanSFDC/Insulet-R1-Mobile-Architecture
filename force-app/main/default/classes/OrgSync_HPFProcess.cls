/**
 * @description Service class for updating OrgSync_Physician_Staging__c records
 *              when HealthcarePractitionerFacility (HPF) IsActive is updated
 * Created Date : Jan 29, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 29, 2026        Pradip Kokate           Initial Version
 */
@SuppressWarnings('PMD.CognitiveComplexity')
public with sharing class OrgSync_HPFProcess {

    private static final String TAG_NAME = 'OrgSync';
    private static final String REASON_CODE_OTHER = 'Other';
    private static final String OTHER_REASON_CODE_VALUE = 'See Infinity';
    /**
     * @description Updates OrgSync_Do_Not_Use__c field on OrgSync_Physician_Staging__c records
     *              when IsActive field is updated on HealthcarePractitionerFacility records
     * @param newRecords List of new HPF records
     * @param oldRecords Map of old HPF records
     */
    public static void updatePhysicianStagingOnIsActiveChange(
        List<HealthcarePractitionerFacility> newRecords,
        Map<Id, HealthcarePractitionerFacility> oldRecords
    ) {
        if (newRecords == null || newRecords.isEmpty() || oldRecords == null || oldRecords.isEmpty()) {
            return;
        }

        try {
            // Step 1-6: Filter HPF records where IsActive field changed and collect data
            ProcessingDataContext context = buildProcessingDataContext(newRecords, oldRecords);
            if (!context.isValid()) {
                return;
            }

            // Step 7: Update Physician Staging records
            List<OrgSync_Physician_Staging__c> physicianStagesToUpdate = preparePhysicianStagesForUpdate(
                context,
                oldRecords
            );

            // Step 8: Perform bulk update
            if (!physicianStagesToUpdate.isEmpty()) {
                List<Database.SaveResult> results = Database.update(physicianStagesToUpdate, false, AccessLevel.SYSTEM_MODE);
                logUpdateResults(results, physicianStagesToUpdate);
            }

        } catch (Exception ex) {
            Logger.error('Error in updatePhysicianStagingOnIsActiveChange: ' + ex.getMessage(), newRecords, ex)
                .addTag(TAG_NAME);
        }
    }

    /**
     * @description Inner class to hold processing data context
     */
    private class ProcessingDataContext {
        Set<Id> providerContactIds;
        Set<Id> practiceAccountIds;
        Map<Id, Id> contactIdToProviderAccountIdMap;
        Map<Id, String> providerAccountIdToNPIMap;
        Map<String, HealthcarePractitionerFacility> practiceNpiToHPFMap;
        Map<String, OrgSync_Physician_Staging__c> practiceNpiToPhysicianStageMap;

        Boolean isValid() {
            return providerContactIds != null && !providerContactIds.isEmpty()
                && practiceAccountIds != null && !practiceAccountIds.isEmpty()
                && contactIdToProviderAccountIdMap != null && !contactIdToProviderAccountIdMap.isEmpty()
                && providerAccountIdToNPIMap != null && !providerAccountIdToNPIMap.isEmpty()
                && practiceNpiToHPFMap != null && !practiceNpiToHPFMap.isEmpty()
                && practiceNpiToPhysicianStageMap != null && !practiceNpiToPhysicianStageMap.isEmpty();
        }
    }

    /**
     * @description Builds processing data context by filtering HPF records with IsActive change
     *              and collecting all required data
     * @param newRecords List of new HPF records
     * @param oldRecords Map of old HPF records
     * @return ProcessingDataContext containing all collected data
     */
    private static ProcessingDataContext buildProcessingDataContext(
        List<HealthcarePractitionerFacility> newRecords,
        Map<Id, HealthcarePractitionerFacility> oldRecords
    ) {
        ProcessingDataContext context = new ProcessingDataContext();
        context.providerContactIds = new Set<Id>();
        context.practiceAccountIds = new Set<Id>();
        List<HealthcarePractitionerFacility> hpfRecordsWithIsActiveChange = new List<HealthcarePractitionerFacility>();

        // Filter records where IsActive changed and collect IDs in a single loop
        for (HealthcarePractitionerFacility newRecord : newRecords) {
            HealthcarePractitionerFacility oldRecord = oldRecords.get(newRecord.Id);
            if (oldRecord != null && newRecord.IsActive != oldRecord.IsActive) {
                hpfRecordsWithIsActiveChange.add(newRecord);
                if (newRecord.PractitionerId != null && newRecord.AccountId != null) {
                    context.providerContactIds.add(newRecord.PractitionerId);
                    context.practiceAccountIds.add(newRecord.AccountId);
                }
            }
        }
        
        if (context.providerContactIds.isEmpty() || context.practiceAccountIds.isEmpty()) {
            return context;
        }

        context.contactIdToProviderAccountIdMap = getProviderAccountsFromContactIds(context.providerContactIds);
        if (context.contactIdToProviderAccountIdMap.isEmpty()) {
            return context;
        }

        Set<Id> providerAccountIds = new Set<Id>(context.contactIdToProviderAccountIdMap.values());
        context.providerAccountIdToNPIMap = getProviderNPIs(providerAccountIds);
        if (context.providerAccountIdToNPIMap.isEmpty()) {
            return context;
        }

        context.practiceNpiToHPFMap = buildPracticeNpiToHPFMap(
            hpfRecordsWithIsActiveChange,
            context.contactIdToProviderAccountIdMap,
            context.providerAccountIdToNPIMap
        );

        if (context.practiceNpiToHPFMap.isEmpty()) {
            return context;
        }

        context.practiceNpiToPhysicianStageMap = queryPhysicianStagingRecords(
            context.practiceAccountIds,
            new Set<String>(context.providerAccountIdToNPIMap.values())
        );

        return context;
    }



    /**
     * @description Prepares Physician Staging records for update based on HPF IsActive changes
     * @param context ProcessingDataContext containing all required data
     * @param oldRecords Map of old HPF records
     * @return List of Physician Staging records to update
     */
    private static List<OrgSync_Physician_Staging__c> preparePhysicianStagesForUpdate(
        ProcessingDataContext context,
        Map<Id, HealthcarePractitionerFacility> oldRecords
    ) {
        List<OrgSync_Physician_Staging__c> physicianStagesToUpdate = new List<OrgSync_Physician_Staging__c>();

        for (String practiceNpiKey : context.practiceNpiToHPFMap.keySet()) {
            HealthcarePractitionerFacility hpf = context.practiceNpiToHPFMap.get(practiceNpiKey);
            OrgSync_Physician_Staging__c physicianStage = context.practiceNpiToPhysicianStageMap.get(practiceNpiKey);

            if (physicianStage != null && hpf != null && oldRecords.containsKey(hpf.Id)) {
                Boolean doNotUseValue = !hpf.IsActive;
                if (physicianStage.OrgSync_Do_Not_Use__c != doNotUseValue) {
                    physicianStage.OrgSync_Do_Not_Use__c = doNotUseValue;
                    populateReasonCodesIfDoNotUse(physicianStage, doNotUseValue);
                    physicianStagesToUpdate.add(physicianStage);
                }
            }
        }

        return physicianStagesToUpdate;
    }



    /**
     * @description Gets Provider Account IDs from Contact IDs (PersonContactId)
     * @param contactIds Set of Contact IDs
     * @return Map of Contact ID to Provider Account ID
     */
    public static Map<Id, Id> getProviderAccountsFromContactIds(Set<Id> contactIds) {
        Map<Id, Id> contactIdToProviderAccountIdMap = new Map<Id, Id>();

        if (contactIds == null || contactIds.isEmpty()) {
            return contactIdToProviderAccountIdMap;
        }

        for (Account acc : [
            SELECT Id, PersonContactId
            FROM Account
            WHERE PersonContactId IN :contactIds
                AND PersonContactId != null
                AND RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            WITH SYSTEM_MODE
        ]) {
            contactIdToProviderAccountIdMap.put(acc.PersonContactId, acc.Id);
        }

        return contactIdToProviderAccountIdMap;
    }

    /**
     * @description Gets Provider NPI values from Identifier records
     * @param providerAccountIds Set of Provider Account IDs
     * @return Map of Provider Account ID to NPI (ID_Value__c)
     */
    private static Map<Id, String> getProviderNPIs(Set<Id> providerAccountIds) {
        Map<Id, String> providerAccountIdToNPIMap = new Map<Id, String>();

        if (providerAccountIds == null || providerAccountIds.isEmpty()) {
            return providerAccountIdToNPIMap;
        }

        for (Identifier identifier : [
            SELECT Id, ParentRecordId, ID_Value__c
            FROM Identifier
            WHERE ParentRecordId IN :providerAccountIds
                AND IdUsageType = :ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
                AND ID_Value__c != null
            WITH SYSTEM_MODE
        ]) {
            if (identifier.ParentRecordId != null && String.isNotBlank(identifier.ID_Value__c)) {
                providerAccountIdToNPIMap.put(identifier.ParentRecordId, identifier.ID_Value__c);
            }
        }

        return providerAccountIdToNPIMap;
    }

    /**
     * @description Builds a map of Practice Account ID + NPI combination to HPF record
     * @param hpfRecords List of HPF records
     * @param contactIdToProviderAccountIdMap Map of Contact ID to Provider Account ID
     * @param providerAccountIdToNPIMap Map of Provider Account ID to NPI
     * @return Map of practiceNpiKey (practiceAccountId_npi) to HPF record
     */
    private static Map<String, HealthcarePractitionerFacility> buildPracticeNpiToHPFMap(
        List<HealthcarePractitionerFacility> hpfRecords,
        Map<Id, Id> contactIdToProviderAccountIdMap,
        Map<Id, String> providerAccountIdToNPIMap
    ) {
        Map<String, HealthcarePractitionerFacility> practiceNpiToHPFMap = new Map<String, HealthcarePractitionerFacility>();

        for (HealthcarePractitionerFacility hpf : hpfRecords) {
            if (hpf.PractitionerId != null && hpf.AccountId != null) {
                Id providerAccountId = contactIdToProviderAccountIdMap.get(hpf.PractitionerId);
                if (providerAccountId != null) {
                    if (String.isNotBlank(providerAccountIdToNPIMap.get(providerAccountId))) {
                        String practiceNpiKey = String.valueOf(hpf.AccountId) + '_' + providerAccountIdToNPIMap.get(providerAccountId);
                        practiceNpiToHPFMap.put(practiceNpiKey, hpf);
                    }
                }
            }
        }

        return practiceNpiToHPFMap;
    }


    /**
     * @description Queries Physician Staging records matching Practice Account IDs and NPIs
     * @param practiceAccountIds Set of Practice Account IDs
     * @param npiValues Set of NPI values
     * @return Map of practiceNpiKey (practiceAccountId_npi) to Physician Staging record
     */
    public static Map<String, OrgSync_Physician_Staging__c> queryPhysicianStagingRecords(
        Set<Id> practiceAccountIds,
        Set<String> npiValues
    ) {
        Map<String, OrgSync_Physician_Staging__c> practiceNpiToPhysicianStageMap = new Map<String, OrgSync_Physician_Staging__c>();

        if (practiceAccountIds == null || practiceAccountIds.isEmpty() || 
            npiValues == null || npiValues.isEmpty()) {
            return practiceNpiToPhysicianStageMap;
        }

        for (OrgSync_Physician_Staging__c physicianStage : [
            SELECT Id, OrgSync_Parent_Practice__c, OrgSync_NPI__c, OrgSync_Do_Not_Use__c,
                   OrgSync_Reason_Code__c, OrgSync_Other_Reason_Code__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_Parent_Practice__c IN :practiceAccountIds
                AND OrgSync_NPI__c IN :npiValues
                AND OrgSync_NPI__c != null
            WITH SYSTEM_MODE
        ]) {
            if (physicianStage.OrgSync_Parent_Practice__c != null && 
                String.isNotBlank(physicianStage.OrgSync_NPI__c)) {
                String practiceNpiKey = String.valueOf(physicianStage.OrgSync_Parent_Practice__c) + '_' + 
                                        physicianStage.OrgSync_NPI__c;
                practiceNpiToPhysicianStageMap.put(practiceNpiKey, physicianStage);
            }
        }

        return practiceNpiToPhysicianStageMap;
    }

    /**
     * @description Populates reason code fields based on OrgSync_Do_Not_Use__c value
     *              If true: populates with 'Other' and 'Other Reason' if blank/null
     *              If false: sets both fields to blank
     * @param physicianStage Physician Staging record to update
     * @param doNotUseValue Value of OrgSync_Do_Not_Use__c field
     */
    private static void populateReasonCodesIfDoNotUse(
        OrgSync_Physician_Staging__c physicianStage,
        Boolean doNotUseValue
    ) {
        if (doNotUseValue == true) {
            if (String.isBlank(physicianStage.OrgSync_Reason_Code__c)) {
                physicianStage.OrgSync_Reason_Code__c = REASON_CODE_OTHER;
            }
            if (String.isBlank(physicianStage.OrgSync_Other_Reason_Code__c)) {
                physicianStage.OrgSync_Other_Reason_Code__c = OTHER_REASON_CODE_VALUE;
            }
        } else if (doNotUseValue == false) {
            physicianStage.OrgSync_Reason_Code__c = '';
            physicianStage.OrgSync_Other_Reason_Code__c = '';
        }
    }

    /**
     * @description Logs update results for Physician Staging records
     * @param results List of Database.SaveResult
     * @param records List of Physician Staging records that were updated
     */
    private static void logUpdateResults(
        List<Database.SaveResult> results,
        List<OrgSync_Physician_Staging__c> records
    ) {
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult result = results[i];
            OrgSync_Physician_Staging__c record = records[i];

            if (!result.isSuccess()) {
                String errorMessage = 'Failed to update Physician Staging record: ' + record.Id;
                for (Database.Error error : result.getErrors()) {
                    errorMessage += ' - ' + error.getMessage();
                }
                Logger.error(errorMessage, record).addTag(TAG_NAME);
            }
        }
    }
}