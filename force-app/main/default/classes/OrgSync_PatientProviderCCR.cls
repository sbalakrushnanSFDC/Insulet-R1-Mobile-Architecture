/**
 * @description Service class for updating OrgSync_Patient_Staging__c records
 *              when ContactContactRelation records are created or updated with
 *              Is_Primary__c = true, IsActive = true, and Party Role Relations = Patient-Provider-CCR
 * Created Date : Jan 21, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 21, 2026        Pradip Kokate           Initial Version
 */
@SuppressWarnings('PMD.CognitiveComplexity')
public with sharing class OrgSync_PatientProviderCCR {

    /**
     * @description Tag name for logging purposes
     */
    private static final String TAG_NAME = 'OrgSync';
    
    /**
     * @description Cached PartyRoleRelation ID for Patient-Provider-CCR role
     */
    private static Id partyRoleRelationId;

    /**
     * @description Main method to process CCR records and update Patient Staging records
     * @param records List of ContactContactRelation records
     */
    public static void updatePatientStagingFromCCR(List<ContactContactRelation> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        try {
            List<ContactContactRelation> relevantCCRs = filterRelevantCCRs(records);
            if (relevantCCRs.isEmpty() || !validatePartyRoleRelation()) {
                return;
            }

            ContactCollectionContext contactContext = collectContactIds(relevantCCRs);
            if (!contactContext.isValid()) {
                return;
            }

            DataCollectionContext dataContext = gatherRequiredData(contactContext);
            PatientStageUpdateContext updateContext = buildUpdateContext(contactContext, dataContext);
            updatePatientStageRecords(updateContext);

        } catch (Exception ex) {
            Logger.error('Error in updatePatientStagingFromCCR: ' + ex.getMessage(), records, ex).addTag(TAG_NAME);
        }
    }

    /**
     * @description Validates that PartyRoleRelation ID exists
     * @return Boolean true if valid, false otherwise
     */
    private static Boolean validatePartyRoleRelation() {
        partyRoleRelationId = getPartyRoleRelationId();
        if (partyRoleRelationId == null) {
            return false;
        }
        return true;
    }

    /**
     * @description Inner class to hold contact collection context
     */
    private class ContactCollectionContext {
        /**
         * @description Set of Patient Contact IDs
         */
        public Set<Id> patientContactIds;
        
        /**
         * @description Set of Provider Contact IDs
         */
        public Set<Id> providerContactIds;
        
        /**
         * @description Map of Patient Contact ID to CCR record
         */
        public Map<Id, ContactContactRelation> patientContactToCCRMap;

        /**
         * @description Validates that contact collections are not empty
         * @return Boolean true if both patient and provider contact IDs are present
         */
        public Boolean isValid() {
            return patientContactIds != null 
                && !patientContactIds.isEmpty() 
                && providerContactIds != null 
                && !providerContactIds.isEmpty();
        }
    }

    /**
     * @description Collects Patient and Provider Contact IDs from CCR records
     * @param relevantCCRs List of filtered CCR records
     * @return ContactCollectionContext containing contact IDs and CCR map
     */
    private static ContactCollectionContext collectContactIds(List<ContactContactRelation> relevantCCRs) {
        ContactCollectionContext context = new ContactCollectionContext();
        context.patientContactIds = new Set<Id>();
        context.providerContactIds = new Set<Id>();
        context.patientContactToCCRMap = new Map<Id, ContactContactRelation>();

        for (ContactContactRelation ccr : relevantCCRs) {
            if (ccr.ContactId != null && ccr.RelatedContactId != null) {
                context.patientContactIds.add(ccr.ContactId);
                context.providerContactIds.add(ccr.RelatedContactId);
                context.patientContactToCCRMap.put(ccr.ContactId, ccr);
            }
        }

        return context;
    }

    /**
     * @description Inner class to hold data collection context
     */
    private class DataCollectionContext {
        /**
         * @description Map of Patient Contact ID to External ID
         */
        public Map<Id, String> patientContactToExtIdMap;
        
        /**
         * @description Map of Provider Contact ID to Provider Account ID
         */
        public Map<Id, Id> providerContactToAccountMap;
        
        /**
         * @description Map of External ID to Patient Stage record
         */
        public Map<String, OrgSync_Patient_Staging__c> extIdToPatientStageMap;
        
        /**
         * @description Map of Provider Account ID to NPI value
         */
        public Map<Id, String> providerAccountToNPIMap;
        
        /**
         * @description Map of PracticeId_NPI key to Physician Stage ID
         */
        public Map<String, Id> practiceNpiToPhysicianStageMap;
    }

    /**
     * @description Inner class to hold Account query results
     */
    private class AccountQueryResult {
        /**
         * @description Map of Patient Contact ID to External ID
         */
        public Map<Id, String> patientContactToExtIdMap;
        
        /**
         * @description Map of Provider Contact ID to Provider Account ID
         */
        public Map<Id, Id> providerContactToAccountMap;
    }

    /**
     * @description Gathers all required data through queries
     * @param contactContext ContactCollectionContext with contact IDs
     * @return DataCollectionContext containing all queried data
     */
    private static DataCollectionContext gatherRequiredData(ContactCollectionContext contactContext) {
        DataCollectionContext dataContext = new DataCollectionContext();

        AccountQueryResult accountResult = getPatientAndProviderAccounts(
            contactContext.patientContactIds,
            contactContext.providerContactIds
        );
        dataContext.patientContactToExtIdMap = accountResult.patientContactToExtIdMap;
        dataContext.providerContactToAccountMap = accountResult.providerContactToAccountMap;

        Set<String> externalIds = new Set<String>(dataContext.patientContactToExtIdMap.values());
        dataContext.extIdToPatientStageMap = getPatientStageRecords(externalIds);

        Set<Id> providerAccountIds = new Set<Id>(dataContext.providerContactToAccountMap.values());
        dataContext.providerAccountToNPIMap = OrgSync_UtilityService.getProviderNPIs(providerAccountIds);

        dataContext.practiceNpiToPhysicianStageMap = getPhysicianStageRecords(
            dataContext.extIdToPatientStageMap.values(),
            dataContext.providerAccountToNPIMap.values()
        );

        return dataContext;
    }

    /**
     * @description Builds the update context from contact and data contexts
     * @param contactContext ContactCollectionContext
     * @param dataContext DataCollectionContext
     * @return PatientStageUpdateContext ready for update
     */
    private static PatientStageUpdateContext buildUpdateContext(
        ContactCollectionContext contactContext,
        DataCollectionContext dataContext
    ) {
        PatientStageUpdateContext updateContext = new PatientStageUpdateContext();
        updateContext.patientContactToCCRMap = contactContext.patientContactToCCRMap;
        updateContext.patientContactToExtIdMap = dataContext.patientContactToExtIdMap;
        updateContext.providerContactToAccountMap = dataContext.providerContactToAccountMap;
        updateContext.providerAccountToNPIMap = dataContext.providerAccountToNPIMap;
        updateContext.extIdToPatientStageMap = dataContext.extIdToPatientStageMap;
        updateContext.practiceNpiToPhysicianStageMap = dataContext.practiceNpiToPhysicianStageMap;
        return updateContext;
    }

    /**
     * @description Filters CCR records based on criteria:
     *              Is_Primary__c = true, IsActive = true, PartyRoleRelationId = Patient-Provider-CCR
     * @param records List of ContactContactRelation records
     * @return List of filtered CCR records
     */
    private static List<ContactContactRelation> filterRelevantCCRs(List<ContactContactRelation> records) {
        List<ContactContactRelation> relevantCCRs = new List<ContactContactRelation>();
        
        partyRoleRelationId = getPartyRoleRelationId();
        if (partyRoleRelationId == null) {
            return relevantCCRs;
        }

        for (ContactContactRelation ccr : records) {
            if (isRelevantCCR(ccr)) {
                relevantCCRs.add(ccr);
            }
        }

        return relevantCCRs;
    }

    /**
     * @description Checks if a CCR record meets the relevance criteria
     * @param ccr ContactContactRelation record to check
     * @return Boolean true if relevant, false otherwise
     */
    private static Boolean isRelevantCCR(ContactContactRelation ccr) {
        return ccr.Is_Primary__c == true 
            && ccr.IsActive == true 
            && ccr.PartyRoleRelationId == partyRoleRelationId;
    }

    /**
     * @description Gets PartyRoleRelation ID for Patient-Provider-CCR
     * @return Id of PartyRoleRelation or null if not found
     */
    private static Id getPartyRoleRelationId() {
        if (partyRoleRelationId != null) {
            return partyRoleRelationId;
        }

        List<PartyRoleRelation> partyRoleRelations = ContactContactRelationService.fetchPartyRoleRelationRecordByName(
            ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
        );

        if (!partyRoleRelations.isEmpty()) {
            partyRoleRelationId = partyRoleRelations[0].Id;
        }

        return partyRoleRelationId;
    }

    /**
     * @description Gets Patient Account External IDs and Provider Account IDs in a single SOQL query
     * @param patientContactIds Set of Patient Contact IDs
     * @param providerContactIds Set of Provider Contact IDs
     * @return AccountQueryResult containing both patient and provider account maps
     */
    private static AccountQueryResult getPatientAndProviderAccounts(
        Set<Id> patientContactIds,
        Set<Id> providerContactIds
    ) {
        AccountQueryResult result = new AccountQueryResult();
        result.patientContactToExtIdMap = new Map<Id, String>();
        result.providerContactToAccountMap = new Map<Id, Id>();

        // Combine both contact ID sets for a single query
        Set<Id> allContactIds = new Set<Id>();
        if (patientContactIds != null && !patientContactIds.isEmpty()) {
            allContactIds.addAll(patientContactIds);
        }
        if (providerContactIds != null && !providerContactIds.isEmpty()) {
            allContactIds.addAll(providerContactIds);
        }

        if (allContactIds.isEmpty()) {
            return result;
        }

        // Single SOQL query to fetch both Patient and Provider Accounts
        for (Account acc : [
            SELECT Id, PersonContactId, XCDC_ExternalId__c, RecordTypeId
            FROM Account
            WHERE PersonContactId IN :allContactIds
                AND (
                    (RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT AND XCDC_ExternalId__c != null)
                    OR RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
                )
            WITH SYSTEM_MODE
        ]) {
            // Process Patient Accounts
            if (acc.RecordTypeId == ConstantsUtil.ACCOUNT_PATIENT_RT 
                && acc.PersonContactId != null 
                && String.isNotBlank(acc.XCDC_ExternalId__c)) {
                result.patientContactToExtIdMap.put(acc.PersonContactId, acc.XCDC_ExternalId__c);
            }
            
            // Process Provider Accounts
            if (acc.RecordTypeId == ConstantsUtil.ACCOUNT_PROVIDER_RT 
                && acc.PersonContactId != null) {
                result.providerContactToAccountMap.put(acc.PersonContactId, acc.Id);
            }
        }

        return result;
    }

    /**
     * @description Gets Patient Stage records based on External IDs
     * @param externalIds Set of External IDs
     * @return Map of External ID to Patient Stage record
     */
    private static Map<String, OrgSync_Patient_Staging__c> getPatientStageRecords(Set<String> externalIds) {
        Map<String, OrgSync_Patient_Staging__c> extIdToPatientStageMap = new Map<String, OrgSync_Patient_Staging__c>();

        if (externalIds.isEmpty()) {
            return extIdToPatientStageMap;
        }

        for (OrgSync_Patient_Staging__c patientStage : [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Practice__c, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c IN :externalIds
                AND OrgSync_Practice__c != null
            WITH SYSTEM_MODE
        ]) {
            addPatientStage(extIdToPatientStageMap, patientStage);
        }

        return extIdToPatientStageMap;
    }

    /**
     * @description Adds Patient Stage to map if valid
     * @param extIdToPatientStageMap Map to populate
     * @param patientStage Patient Stage record
     */
    private static void addPatientStage(
        Map<String, OrgSync_Patient_Staging__c> extIdToPatientStageMap,
        OrgSync_Patient_Staging__c patientStage
    ) {
        if (String.isNotBlank(patientStage.XCDC_ExternalId__c) && patientStage.OrgSync_Practice__c != null) {
            extIdToPatientStageMap.put(patientStage.XCDC_ExternalId__c, patientStage);
        }
    }


    /**
     * @description Gets Physician Stage records based on Practice and NPI
     * @param patientStages List of Patient Stage records
     * @param npiValues Collection of NPI values
     * @return Map of PracticeId_NPI to Physician Stage ID
     */
    private static Map<String, Id> getPhysicianStageRecords(
        List<OrgSync_Patient_Staging__c> patientStages,
        List<String> npiValues
    ) {
        Map<String, Id> practiceNpiToPhysicianStageMap = new Map<String, Id>();

        if (patientStages.isEmpty() || npiValues.isEmpty()) {
            return practiceNpiToPhysicianStageMap;
        }

        Set<Id> practiceIds = collectPracticeIds(patientStages);
        if (practiceIds.isEmpty()) {
            return practiceNpiToPhysicianStageMap;
        }

        return queryPhysicianStages(practiceIds, new Set<String>(npiValues));
    }

    /**
     * @description Collects Practice IDs from Patient Stage records
     * @param patientStages List of Patient Stage records
     * @return Set of Practice IDs
     */
    private static Set<Id> collectPracticeIds(List<OrgSync_Patient_Staging__c> patientStages) {
        Set<Id> practiceIds = new Set<Id>();
        for (OrgSync_Patient_Staging__c patientStage : patientStages) {
            addPracticeIdIfValid(practiceIds, patientStage);
        }
        return practiceIds;
    }

    /**
     * @description Adds Practice ID to set if valid
     * @param practiceIds Set to populate
     * @param patientStage Patient Stage record
     */
    private static void addPracticeIdIfValid(Set<Id> practiceIds, OrgSync_Patient_Staging__c patientStage) {
        if (patientStage.OrgSync_Practice__c != null) {
            practiceIds.add(patientStage.OrgSync_Practice__c);
        }
    }

    /**
     * @description Queries Physician Stage records and builds the map
     * @param practiceIds Set of Practice IDs
     * @param npiSet Set of NPI values
     * @return Map of PracticeId_NPI to Physician Stage ID
     */
    private static Map<String, Id> queryPhysicianStages(Set<Id> practiceIds, Set<String> npiSet) {
        Map<String, Id> practiceNpiToPhysicianStageMap = new Map<String, Id>();

        for (OrgSync_Physician_Staging__c physicianStage : [SELECT Id, OrgSync_Parent_Practice__c, OrgSync_NPI__c FROM OrgSync_Physician_Staging__c WHERE OrgSync_Parent_Practice__c IN :practiceIds AND OrgSync_NPI__c IN :npiSet AND OrgSync_NPI__c != null WITH SYSTEM_MODE]) {
            addPhysicianStage(practiceNpiToPhysicianStageMap, physicianStage);
        }

        return practiceNpiToPhysicianStageMap;
    }

    /**
     * @description Adds Physician Stage to map if valid
     * @param practiceNpiToPhysicianStageMap Map to populate
     * @param physicianStage Physician Stage record
     */
    private static void addPhysicianStage(
        Map<String, Id> practiceNpiToPhysicianStageMap,
        OrgSync_Physician_Staging__c physicianStage
    ) {
        if (physicianStage.OrgSync_Parent_Practice__c != null && String.isNotBlank(physicianStage.OrgSync_NPI__c)) {
            String key = String.valueOf(physicianStage.OrgSync_Parent_Practice__c) + '_' + physicianStage.OrgSync_NPI__c;
            practiceNpiToPhysicianStageMap.put(key, physicianStage.Id);
        }
    }

    /**
     * @description Inner class to hold Patient Stage update context data
     */
    private class PatientStageUpdateContext {
        /**
         * @description Map of Patient Contact ID to CCR record
         */
        public Map<Id, ContactContactRelation> patientContactToCCRMap;
        
        /**
         * @description Map of Patient Contact ID to External ID
         */
        public Map<Id, String> patientContactToExtIdMap;
        
        /**
         * @description Map of Provider Contact ID to Provider Account ID
         */
        public Map<Id, Id> providerContactToAccountMap;
        
        /**
         * @description Map of Provider Account ID to NPI value
         */
        public Map<Id, String> providerAccountToNPIMap;
        
        /**
         * @description Map of External ID to Patient Stage record
         */
        public Map<String, OrgSync_Patient_Staging__c> extIdToPatientStageMap;
        
        /**
         * @description Map of PracticeId_NPI key to Physician Stage ID
         */
        public Map<String, Id> practiceNpiToPhysicianStageMap;
    }

    /**
     * @description Updates Patient Stage records with Physician Stage ID
     * @param context PatientStageUpdateContext containing all required data maps
     */
    private static void updatePatientStageRecords(PatientStageUpdateContext context) {
        List<OrgSync_Patient_Staging__c> patientStagesToUpdate = collectPatientStagesToUpdate(context);

        if (!patientStagesToUpdate.isEmpty()) {
            executePatientStageUpdate(patientStagesToUpdate);
        }
    }

    /**
     * @description Collects Patient Stage records that need to be updated
     * @param context PatientStageUpdateContext containing all required data maps
     * @return List of Patient Stage records to update
     */
    private static List<OrgSync_Patient_Staging__c> collectPatientStagesToUpdate(PatientStageUpdateContext context) {
        List<OrgSync_Patient_Staging__c> patientStagesToUpdate = new List<OrgSync_Patient_Staging__c>();

        for (Id patientContactId : context.patientContactToCCRMap.keySet()) {
            OrgSync_Patient_Staging__c patientStage = findPatientStageForUpdate(
                patientContactId,
                context
            );
            if (patientStage != null) {
                patientStagesToUpdate.add(patientStage);
            }
        }

        return patientStagesToUpdate;
    }

    /**
     * @description Finds and updates Patient Stage record for a given patient contact
     * @param patientContactId Patient Contact ID
     * @param context PatientStageUpdateContext
     * @return Patient Stage record if update needed, null otherwise
     */
    private static OrgSync_Patient_Staging__c findPatientStageForUpdate(
        Id patientContactId,
        PatientStageUpdateContext context
    ) {
        ContactContactRelation ccr = context.patientContactToCCRMap.get(patientContactId);
        String externalId = context.patientContactToExtIdMap.get(patientContactId);
        Id providerAccountId = context.providerContactToAccountMap.get(ccr.RelatedContactId);
        String npi = context.providerAccountToNPIMap.get(providerAccountId);

        if (!hasRequiredData(externalId, providerAccountId, npi)) {
            return null;
        }

        OrgSync_Patient_Staging__c patientStage = context.extIdToPatientStageMap.get(externalId);
        if (!isValidPatientStage(patientStage)) {
            return null;
        }

        return updatePatientStageIfNeeded(patientStage, npi, context);
    }

    /**
     * @description Checks if required data is present
     * @param externalId External ID
     * @param providerAccountId Provider Account ID
     * @param npi NPI value
     * @return Boolean true if all required data present
     */
    private static Boolean hasRequiredData(String externalId, Id providerAccountId, String npi) {
        return String.isNotBlank(externalId) && providerAccountId != null && String.isNotBlank(npi);
    }

    /**
     * @description Validates Patient Stage record
     * @param patientStage Patient Stage record
     * @return Boolean true if valid
     */
    private static Boolean isValidPatientStage(OrgSync_Patient_Staging__c patientStage) {
        return patientStage != null && patientStage.OrgSync_Practice__c != null;
    }

    /**
     * @description Updates Patient Stage if Physician Stage ID needs to be set
     * @param patientStage Patient Stage record
     * @param npi NPI value
     * @param context PatientStageUpdateContext
     * @return Patient Stage record if updated, null otherwise
     */
    private static OrgSync_Patient_Staging__c updatePatientStageIfNeeded(
        OrgSync_Patient_Staging__c patientStage,
        String npi,
        PatientStageUpdateContext context
    ) {
        String practiceNpiKey = String.valueOf(patientStage.OrgSync_Practice__c) + '_' + npi;
        Id physicianStageId = context.practiceNpiToPhysicianStageMap.get(practiceNpiKey);

        if (physicianStageId != null && patientStage.OrgSync_Provider__c != physicianStageId) {
            patientStage.OrgSync_Provider__c = physicianStageId;
            return patientStage;
        }

        return null;
    }

    /**
     * @description Executes the database update for Patient Stage records
     * @param patientStagesToUpdate List of Patient Stage records to update
     */
    private static void executePatientStageUpdate(List<OrgSync_Patient_Staging__c> patientStagesToUpdate) {
        List<Database.SaveResult> results = Database.update(patientStagesToUpdate, false, AccessLevel.SYSTEM_MODE);
        OrgSync_LoggingUtility.handleDatabaseResults(results, patientStagesToUpdate, new Map<String, String>{'className' => 'OrgSync_PatientProviderCCR','methodName' => 'updatePatientStageRecords','operationDescription' => 'updating Patient Stage records with Provider'
        });
    }
}