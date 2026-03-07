/**
 * @description Service class for creating/updating HealthcarePractitionerFacility (HPF) records
 *              between Provider and Practice when OrgSync_Physician_Staging__c records are created or updated.
 * Created Date : Jan 21, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 21, 2026        Pradip Kokate           Initial Version
 */

public with sharing class OrgSync_ProviderPracticeRelation {

    /**
     * @description Tag name used for logging purposes
     */
    private static final String TAG_NAME = 'OrgSync';

    /**
     * @description Main method to process Physician Stage records and create/update HPF records
     * @param records List of OrgSync_Physician_Staging__c records
     */
    public static void createOrUpdateProviderPracticeRelations(List<OrgSync_Physician_Staging__c> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        try {
            HPFProcessingContext hpfContext = buildHPFProcessingContext(records);
            if (hpfContext == null) {
                return;
            }

            executeHPFProcessing(hpfContext);
        } catch (Exception ex) {
            Logger.error('Error in createOrUpdateProviderPracticeRelations: ' + ex.getMessage(), records, ex)
                .addTag(TAG_NAME);
        }
    }

    /**
     * @description Builds HPF processing context by collecting all required data
     * @param records List of Physician Stage records
     * @return HPFProcessingContext or null if data collection fails
     */
    private static HPFProcessingContext buildHPFProcessingContext(List<OrgSync_Physician_Staging__c> records) {
        // Step 1: Collect NPIs and Practice IDs from Physician Stage records
        ProcessingContext context = collectProcessingData(records);
        if (!context.isValid()) {
            return null;
        }

        // Step 2: Find Provider Contact IDs from NPIs via Identifier records (ParentRecordId stores Person Account IDs)
        Map<String, Id> npiToProviderContactId = OrgSync_HPFHelper.getProviderContactIdsFromNPIs(context.npiValues);
        if (npiToProviderContactId.isEmpty()) {
            return null;
        }

        // Step 3: Get Account and Provider Account names for HPF Name field
        // context.practiceIds already contains Account IDs (OrgSync_Parent_Practice__c is a lookup to Account)
        OrgSync_HPFHelper.AccountNamesResult accountNamesResult = OrgSync_HPFHelper.getAccountNames(context.practiceIds, new Set<Id>(npiToProviderContactId.values()));
        Map<Id, String> accountIdToName = accountNamesResult.practiceAccountIdToName;
        Map<Id, String> contactIdToName = accountNamesResult.providerContactIdToName;

        // Step 4: Get existing HPF records
        Set<Id> providerContactIds = new Set<Id>(npiToProviderContactId.values());
        Map<String, HealthcarePractitionerFacility> existingHPFMap = OrgSync_HPFHelper.getExistingHPFRecords(
            new List<Id>(context.practiceIds),
            providerContactIds
        );

        // Step 5: Check which practice accounts have existing HPF records
        Map<Id, Boolean> practiceAccountHasHPFRecords = OrgSync_HPFHelper.checkPracticeAccountsHaveHPFRecords(
            new List<Id>(context.practiceIds)
        );

        // Step 6: Check which provider contact IDs have existing HPF records
        Map<Id, Boolean> providerContactIdHasHPFRecords = OrgSync_HPFHelper.checkProviderContactIdsHaveHPFRecords(
            providerContactIds
        );

        // Build and return context
        HPFProcessingContext hpfContext = new HPFProcessingContext();
        hpfContext.processingContext = context;
        hpfContext.npiToProviderContactId = npiToProviderContactId;
        hpfContext.accountIdToName = accountIdToName;
        hpfContext.contactIdToName = contactIdToName;
        hpfContext.existingHPFMap = existingHPFMap;
        hpfContext.practiceAccountHasHPFRecords = practiceAccountHasHPFRecords;
        hpfContext.providerContactIdHasHPFRecords = providerContactIdHasHPFRecords;

        return hpfContext;
    }

    /**
     * @description Executes HPF processing including create/update operations
     * @param hpfContext HPFProcessingContext containing all required data
     */
    private static void executeHPFProcessing(HPFProcessingContext hpfContext) {
        // Step 6: Process HPF records (create or update)
        HPFProcessingResult result = processHPFRecords(hpfContext);

        // Step 7: Ensure only one IsPrimaryFacility = true per provider
        if (!result.providerContactIds.isEmpty()) {
            OrgSync_HPFHelper.updateOtherPrimaryFacilities(
                result.providerContactIds,
                result.hpfToInsert,
                result.hpfToUpdate
            );
        }

        // Step 8: Insert new HPF records
        if (!result.hpfToInsert.isEmpty()) {
            OrgSync_HPFHelper.insertHPFRecords(result.hpfToInsert);
        }

        // Step 9: Update existing HPF records
        if (!result.hpfToUpdate.isEmpty()) {
            OrgSync_HPFHelper.updateHPFRecords(result.hpfToUpdate);
        }
    }

    /**
     * @description Inner class to hold processing context data
     */
    private class ProcessingContext {
        /**
         * @description Set of NPI values collected from Physician Stage records
         */
        public Set<String> npiValues;
        /**
         * @description Set of Practice Account IDs collected from Physician Stage records
         */
        public Set<Id> practiceIds;
        /**
         * @description Map of Physician Stage record IDs to Physician Stage records
         */
        public Map<Id, OrgSync_Physician_Staging__c> physicianStageMap;

        /**
         * @description Validates if the processing context contains valid data
         * @return Boolean true if context is valid (has NPIs and Practice IDs), false otherwise
         */
        public Boolean isValid() {
            return npiValues != null 
                && !npiValues.isEmpty() 
                && practiceIds != null 
                && !practiceIds.isEmpty();
        }
    }

    /**
     * @description Collects NPIs and Practice IDs from Physician Stage records
     * @param records List of Physician Stage records
     * @return ProcessingContext containing collected data
     */
    private static ProcessingContext collectProcessingData(List<OrgSync_Physician_Staging__c> records) {
        ProcessingContext context = new ProcessingContext();
        context.npiValues = new Set<String>();
        context.practiceIds = new Set<Id>();
        context.physicianStageMap = new Map<Id, OrgSync_Physician_Staging__c>();

        for (OrgSync_Physician_Staging__c physicianStage : records) {
            if (String.isNotBlank(physicianStage.OrgSync_NPI__c) && physicianStage.OrgSync_Parent_Practice__c != null) {
                context.npiValues.add(physicianStage.OrgSync_NPI__c);
                context.practiceIds.add(physicianStage.OrgSync_Parent_Practice__c);
                context.physicianStageMap.put(physicianStage.Id, physicianStage);
            }
        }

        return context;
    }


    /**
     * @description Inner class to hold HPF processing context data
     */
    private class HPFProcessingContext {
        /**
         * @description Processing context containing collected NPIs, Practice IDs, and Physician Stage records
         */
        public ProcessingContext processingContext;
        /**
         * @description Map of NPI values to Provider Contact IDs
         */
        public Map<String, Id> npiToProviderContactId;
        /**
         * @description Map of Practice Account ID to Practice Account Name
         */
        public Map<Id, String> accountIdToName;
        /**
         * @description Map of Provider Contact ID to Provider Account Name
         */
        public Map<Id, String> contactIdToName;
        /**
         * @description Map of HPF key (practiceAccountId_providerContactId) to existing HPF records
         */
        public Map<String, HealthcarePractitionerFacility> existingHPFMap;
        /**
         * @description Map of Practice Account ID to Boolean indicating if HPF records exist
         */
        public Map<Id, Boolean> practiceAccountHasHPFRecords;
        /**
         * @description Map of Provider Contact ID to Boolean indicating if HPF records exist
         */
        public Map<Id, Boolean> providerContactIdHasHPFRecords;
    }

    /**
     * @description Inner class to hold HPF processing results
     */
    private class HPFProcessingResult {
        /**
         * @description List of HPF records to be inserted
         */
        public List<HealthcarePractitionerFacility> hpfToInsert;
        /**
         * @description List of HPF records to be updated
         */
        public List<HealthcarePractitionerFacility> hpfToUpdate;
        /**
         * @description Set of Provider Contact IDs that have HPF records being processed
         */
        public Set<Id> providerContactIds;

        /**
         * @description Constructor to initialize HPFProcessingResult with empty lists and sets
         */
        public HPFProcessingResult() {
            this.hpfToInsert = new List<HealthcarePractitionerFacility>();
            this.hpfToUpdate = new List<HealthcarePractitionerFacility>();
            this.providerContactIds = new Set<Id>();
        }
    }

    /**
     * @description Inner class to hold HPF update context data
     */
    private class HPFUpdateContext {
        /**
         * @description Provider Account Name
         */
        public String providerName;
        /**
         * @description Practice Account Name
         */
        public String practiceName;
        /**
         * @description HPF processing result containing HPFs to insert/update
         */
        public HPFProcessingResult result;
        /**
         * @description Practice Account ID
         */
        public Id practiceAccountId;
        /**
         * @description Provider Contact ID
         */
        public Id providerContactId;
        /**
         * @description Boolean indicating if practice account has existing HPF records
         */
        public Boolean practiceAccountHasHPFRecords;
        /**
         * @description Boolean indicating if provider contact ID has existing HPF records
         */
        public Boolean providerContactIdHasHPFRecords;
        /**
         * @description Physician Stage record being processed
         */
        public OrgSync_Physician_Staging__c physicianStage;
    }

    /**
     * @description Inner class to hold batch tracking context for HPF processing
     */
    private class HPFBatchTrackingContext {
        /**
         * @description Practice Account ID
         */
        public Id practiceAccountId;
        /**
         * @description Provider Contact ID
         */
        public Id providerContactId;
        /**
         * @description Set of practice accounts with new HPF in batch
         */
        public Set<Id> practiceAccountsWithNewHPFInBatch;
        /**
         * @description Set of provider contact IDs with new HPF in batch
         */
        public Set<Id> providerContactIdsWithNewHPFInBatch;
    }

    /**
     * @description Inner class to hold provider HPF records status context
     */
    private class ProviderHPFRecordsStatusContext {
        /**
         * @description Provider Contact ID
         */
        public Id providerContactId;
        /**
         * @description Boolean from context indicating if provider has HPF records
         */
        public Boolean providerContactIdHasHPFRecords;
        /**
         * @description Set of provider contact IDs with new HPF in batch
         */
        public Set<Id> providerContactIdsWithNewHPFInBatch;
    }

    /**
     * @description Inner class to hold HPF record processing context
     */
    private class HPFRecordProcessingContext {
        /**
         * @description Physician Stage record being processed
         */
        public OrgSync_Physician_Staging__c physicianStage;
        /**
         * @description Existing HPF record or null
         */
        public HealthcarePractitionerFacility existingHPF;
        /**
         * @description HPF processing result
         */
        public HPFProcessingResult result;
    }

    /**
     * @description Processes HPF records and prepares them for insert/update
     * @param hpfContext HPFProcessingContext containing all required data
     * @return HPFProcessingResult containing HPFs to insert/update
     */
    private static HPFProcessingResult processHPFRecords(HPFProcessingContext hpfContext) {
        HPFProcessingResult result = new HPFProcessingResult();
        ProcessingContext context = hpfContext.processingContext;
        // Track practice accounts that are getting HPF records created in this batch
        Set<Id> practiceAccountsWithNewHPFInBatch = new Set<Id>();
        // Track provider contact IDs that are getting HPF records created in this batch
        Set<Id> providerContactIdsWithNewHPFInBatch = new Set<Id>();

        for (Id physicianStageId : context.physicianStageMap.keySet()) {
            OrgSync_Physician_Staging__c physicianStage = context.physicianStageMap.get(physicianStageId);
            
            String npi = physicianStage.OrgSync_NPI__c;
            Id practiceAccountId = physicianStage.OrgSync_Parent_Practice__c;
            Id providerContactId = hpfContext.npiToProviderContactId.get(npi);

            if (!isValidHPFData(practiceAccountId, providerContactId)) {
                continue;
            }

            String hpfKey = String.valueOf(practiceAccountId) + '_' + String.valueOf(providerContactId);
            HealthcarePractitionerFacility existingHPF = hpfContext.existingHPFMap.get(hpfKey);

            HPFBatchTrackingContext batchContext = new HPFBatchTrackingContext();
            batchContext.practiceAccountId = practiceAccountId;
            batchContext.providerContactId = providerContactId;
            batchContext.practiceAccountsWithNewHPFInBatch = practiceAccountsWithNewHPFInBatch;
            batchContext.providerContactIdsWithNewHPFInBatch = providerContactIdsWithNewHPFInBatch;

            HPFRecordProcessingContext recordContext = new HPFRecordProcessingContext();
            recordContext.physicianStage = physicianStage;
            recordContext.existingHPF = existingHPF;
            recordContext.result = result;

            HPFUpdateContext updateContext = buildHPFUpdateContext(
                hpfContext,
                batchContext,
                recordContext
            );

            processHPFRecord(existingHPF, updateContext, batchContext);
        }

        return result;
    }

    /**
     * @description Validates if HPF data is valid for processing
     * @param practiceAccountId Practice Account ID
     * @param providerContactId Provider Contact ID
     * @return Boolean true if data is valid, false otherwise
     */
    private static Boolean isValidHPFData(Id practiceAccountId, Id providerContactId) {
        return practiceAccountId != null && providerContactId != null;
    }

    /**
     * @description Builds HPF update context with all required data
     * @param hpfContext HPFProcessingContext containing all required data
     * @param batchContext HPFBatchTrackingContext containing batch tracking data
     * @param recordContext HPFRecordProcessingContext containing record processing data
     * @return HPFUpdateContext with all required data populated
     */
    private static HPFUpdateContext buildHPFUpdateContext(
        HPFProcessingContext hpfContext,
        HPFBatchTrackingContext batchContext,
        HPFRecordProcessingContext recordContext
    ) {
        Id practiceAccountId = batchContext.practiceAccountId;
        Id providerContactId = batchContext.providerContactId;

        String practiceName = hpfContext.accountIdToName.get(practiceAccountId);
        String providerName = hpfContext.contactIdToName.get(providerContactId);
        Boolean practiceAccountHasHPFRecords = hpfContext.practiceAccountHasHPFRecords.get(practiceAccountId);
        Boolean providerContactIdHasHPFRecords = hpfContext.providerContactIdHasHPFRecords.get(providerContactId);

        HPFUpdateContext updateContext = new HPFUpdateContext();
        updateContext.providerName = providerName;
        updateContext.practiceName = practiceName;
        updateContext.result = recordContext.result;
        updateContext.practiceAccountId = practiceAccountId;
        updateContext.providerContactId = providerContactId;
        updateContext.physicianStage = recordContext.physicianStage;
        
        Boolean hasPracticeHPFRecords = practiceAccountHasHPFRecords || batchContext.practiceAccountsWithNewHPFInBatch.contains(practiceAccountId);
        updateContext.practiceAccountHasHPFRecords = hasPracticeHPFRecords;
        
        ProviderHPFRecordsStatusContext statusContext = new ProviderHPFRecordsStatusContext();
        statusContext.providerContactId = providerContactId;
        statusContext.providerContactIdHasHPFRecords = providerContactIdHasHPFRecords;
        statusContext.providerContactIdsWithNewHPFInBatch = batchContext.providerContactIdsWithNewHPFInBatch;

        Boolean hasProviderHPFRecords = determineProviderHPFRecordsStatus(recordContext.existingHPF, statusContext);
        updateContext.providerContactIdHasHPFRecords = hasProviderHPFRecords;

        return updateContext;
    }

    /**
     * @description Determines if provider has HPF records based on existing HPF status
     * @param existingHPF Existing HPF record or null
     * @param statusContext ProviderHPFRecordsStatusContext containing provider HPF records status data
     * @return Boolean true if provider has HPF records, false otherwise
     */
    private static Boolean determineProviderHPFRecordsStatus(
        HealthcarePractitionerFacility existingHPF,
        ProviderHPFRecordsStatusContext statusContext
    ) {
        if (existingHPF != null) {
            return OrgSync_HPFHelper.checkProviderHasOtherHPFRecords(statusContext.providerContactId, existingHPF.Id);
        }
        return statusContext.providerContactIdHasHPFRecords 
            || statusContext.providerContactIdsWithNewHPFInBatch.contains(statusContext.providerContactId);
    }

    /**
     * @description Processes a single HPF record (create or update)
     * @param existingHPF Existing HPF record or null
     * @param updateContext HPFUpdateContext containing all required data
     * @param batchContext HPFBatchTrackingContext containing batch tracking data
     */
    private static void processHPFRecord(
        HealthcarePractitionerFacility existingHPF,
        HPFUpdateContext updateContext,
        HPFBatchTrackingContext batchContext
    ) {
        if (existingHPF != null) {
            handleExistingHPF(existingHPF, updateContext);
        } else {
            createNewHPF(updateContext.practiceAccountId, updateContext.providerContactId, updateContext);
            batchContext.practiceAccountsWithNewHPFInBatch.add(updateContext.practiceAccountId);
            batchContext.providerContactIdsWithNewHPFInBatch.add(updateContext.providerContactId);
        }
    }

    /**
     * @description Handles existing HPF record - updates if needed
     * @param existingHPF Existing HPF record
     * @param updateContext HPFUpdateContext containing provider name, practice name, and result
     */
    private static void handleExistingHPF(
        HealthcarePractitionerFacility existingHPF,
        HPFUpdateContext updateContext
    ) {
        Boolean needsUpdate = updateHPFName(existingHPF, updateContext);
        needsUpdate = updateHPFPrimaryFacility(existingHPF, updateContext) || needsUpdate;
        needsUpdate = updateHPFIsActive(existingHPF, updateContext) || needsUpdate;
        needsUpdate = updateHPFPrimaryCarePhysician(existingHPF, updateContext) || needsUpdate;

        if (needsUpdate) {
            updateContext.result.hpfToUpdate.add(existingHPF);
        }
        updateContext.result.providerContactIds.add(existingHPF.PractitionerId);
    }

    /**
     * @description Updates HPF Name field if needed
     * @param existingHPF Existing HPF record
     * @param updateContext HPFUpdateContext containing provider name and practice name
     * @return Boolean true if update was made, false otherwise
     */
    private static Boolean updateHPFName(
        HealthcarePractitionerFacility existingHPF,
        HPFUpdateContext updateContext
    ) {
        String expectedName = buildHPFName(updateContext.providerName, updateContext.practiceName);
        if (String.isNotBlank(expectedName) && existingHPF.Name != expectedName) {
            existingHPF.Name = expectedName;
            return true;
        }
        return false;
    }

    /**
     * @description Updates HPF IsPrimaryFacility field if needed
     * @param existingHPF Existing HPF record
     * @param updateContext HPFUpdateContext containing provider HPF records status
     * @return Boolean true if update was made, false otherwise
     */
    private static Boolean updateHPFPrimaryFacility(
        HealthcarePractitionerFacility existingHPF,
        HPFUpdateContext updateContext
    ) {
        // Determine what IsActive should be based on physician stage record
        Boolean shouldBeActive = determineIsActiveValue(updateContext.physicianStage);
        // Set IsPrimaryFacility = true only if IsActive = true and no HPF records exist for this provider
        Boolean shouldBePrimaryFacility = shouldBeActive == true 
            && updateContext.providerContactIdHasHPFRecords == false;
        if (existingHPF.IsPrimaryFacility != shouldBePrimaryFacility) {
            existingHPF.IsPrimaryFacility = shouldBePrimaryFacility;
            return true;
        }
        return false;
    }

    /**
     * @description Updates HPF IsActive field if needed
     * @param existingHPF Existing HPF record
     * @param updateContext HPFUpdateContext containing physician stage record
     * @return Boolean true if update was made, false otherwise
     */
    private static Boolean updateHPFIsActive(
        HealthcarePractitionerFacility existingHPF,
        HPFUpdateContext updateContext
    ) {
        Boolean shouldBeActive = determineIsActiveValue(updateContext.physicianStage);
        if (existingHPF.IsActive != shouldBeActive) {
            existingHPF.IsActive = shouldBeActive;
            return true;
        }
        return false;
    }

    /**
     * @description Determines the IsActive value based on Physician Stage record
     * @param physicianStage Physician Stage record or null
     * @return Boolean true if active, false otherwise
     */
    private static Boolean determineIsActiveValue(OrgSync_Physician_Staging__c physicianStage) {
        if (physicianStage == null) {
            return true;
        }
        return !physicianStage.OrgSync_Do_Not_Use__c;
    }

    /**
     * @description Updates HPF IsPrimaryCarePhysician field if needed
     * @param existingHPF Existing HPF record
     * @param updateContext HPFUpdateContext containing practice account HPF records status
     * @return Boolean true if update was made, false otherwise
     */
    private static Boolean updateHPFPrimaryCarePhysician(
        HealthcarePractitionerFacility existingHPF,
        HPFUpdateContext updateContext
    ) {
        Boolean shouldBePrimaryCarePhysician = updateContext.practiceAccountHasHPFRecords == false;
        if (existingHPF.IsPrimaryCarePhysician != shouldBePrimaryCarePhysician) {
            existingHPF.IsPrimaryCarePhysician = shouldBePrimaryCarePhysician;
            return true;
        }
        return false;
    }

    /**
     * @description Creates a new HPF record
     * @param practiceAccountId Practice Account ID
     * @param providerContactId Provider Contact ID
     * @param updateContext HPFUpdateContext containing provider name, practice name, and result
     */
    private static void createNewHPF(
        Id practiceAccountId,
        Id providerContactId,
        HPFUpdateContext updateContext
    ) {
        // Sync IsActive with OrgSync_Do_Not_Use__c from Physician Staging
        // If OrgSync_Do_Not_Use__c is true, then IsActive should be false
        // If OrgSync_Do_Not_Use__c is false, then IsActive should be true
        Boolean isActive = updateContext.physicianStage != null 
            ? !updateContext.physicianStage.OrgSync_Do_Not_Use__c
            : true; // Default to true if physicianStage is null
        
        // Set IsPrimaryFacility = true only if IsActive = true and no HPF records exist for this provider contact ID
        Boolean isPrimaryFacility = isActive == true 
            && updateContext.providerContactIdHasHPFRecords == false;
        // Set IsPrimaryCarePhysician = true if no HPF records exist for this practice account
        Boolean isPrimaryCarePhysician = updateContext.practiceAccountHasHPFRecords == false;
        
        HealthcarePractitionerFacility newHPF = new HealthcarePractitionerFacility(
            AccountId = practiceAccountId,
            PractitionerId = providerContactId,
            Name = buildHPFName(updateContext.providerName, updateContext.practiceName),
            IsPrimaryFacility = isPrimaryFacility,
            IsActive = isActive,
            IsPrimaryCarePhysician = isPrimaryCarePhysician
        );
        updateContext.result.hpfToInsert.add(newHPF);
        updateContext.result.providerContactIds.add(providerContactId);
    }

    /**
     * @description Builds HPF Name in format "Dr. {Provider Name} at {Practice Name}"
     * @param providerName Provider name
     * @param practiceName Practice name
     * @return Formatted HPF Name
     */
    private static String buildHPFName(String providerName, String practiceName) {
        String name = '';
        
        if (String.isNotBlank(providerName)) {
            name = 'Dr. ' + providerName;
        }
        
        if (String.isNotBlank(practiceName)) {
            if (String.isNotBlank(name)) {
                name += ' at ' + practiceName;
            } else {
                name = 'Dr. at ' + practiceName;
            }
        }
        
        return name;
    }

}