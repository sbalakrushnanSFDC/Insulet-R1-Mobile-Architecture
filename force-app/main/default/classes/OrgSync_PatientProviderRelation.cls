/**
 * @description Service class for creating Contact Contact Relationship (CCR) records
 *              between Patient and Provider Person Accounts from OrgSync_Patient_Staging__c records.
 * Created Date : Jan 19, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 19, 2026        Pradip Kokate      Initial Version
 * V1.0.1       Feb 16, 2026        Pradip Kokate      Updated to handle PartyRoleRelationId in CCR records.
 */
public with sharing class OrgSync_PatientProviderRelation {

    /**
     * @description Tag name for logging purposes
     */
    private static final String TAG_NAME = 'OrgSync';
    
    /**
     * @description Cached PartyRoleRelation ID for Patient-Provider-CCR role
     */
    private static Id partyRoleRelationId;

    /**
     * @description Main method to process Patient Staging records and create/update CCR records
     * @param records List of OrgSync_Patient_Staging__c records
     */
    public static void createOrUpdatePatientProviderRelations(List<OrgSync_Patient_Staging__c> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        try {
            // Get PartyRoleRelation ID
            partyRoleRelationId = getPartyRoleRelationId();
            if (partyRoleRelationId == null) {
                Logger.error('PartyRoleRelation record not found for role: ' + ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE).addTag(TAG_NAME);
                return;
            }

            // Step 1: Identify Patient Person Accounts
            Map<String, Id> patientExtIdToContactId = getPatientContactIds(records);

            // Step 2: Identify Provider Person Accounts
            Map<Id, Id> providerStagingToContactId = OrgSync_ProviderContactIdHelper.getProviderContactIds(records);

            // Step 3: Get existing CCR records
            Map<String, ContactContactRelation> existingCCRMap = getExistingCCRs(patientExtIdToContactId.values());

            // Step 4: Process CCR records (create or update)
            CCRProcessingContext context = new CCRProcessingContext();
            context.records = records;
            context.patientExtIdToContactId = patientExtIdToContactId;
            context.providerStagingToContactId = providerStagingToContactId;
            context.existingCCRMap = existingCCRMap;
            CCRProcessingResult processingResult = processCCRRecords(context);

            // Step 5: Update other primary providers to false before inserting/updating
            if (!processingResult.patientContactIds.isEmpty()) {
                updateOtherPrimaryProviders(processingResult.patientContactIds,processingResult.ccrToInsert,processingResult.ccrToUpdate);
            }

            // Step 6: Insert new CCR records
            if (!processingResult.ccrToInsert.isEmpty()) {
                OrgSync_CCRDMLHelper.insertCCRs(processingResult.ccrToInsert);
            }

            // Step 7: Update existing CCR records
            if (!processingResult.ccrToUpdate.isEmpty()) {
                OrgSync_CCRDMLHelper.updateCCRs(processingResult.ccrToUpdate);
            }

        } catch (Exception ex) {
            Logger.error('Error in createOrUpdatePatientProviderRelations: ' + ex.getMessage(), records, ex).addTag(TAG_NAME);
        }
    }

    /**
     * @description Inner class to hold CCR processing context
     */
    private class CCRProcessingContext {
        /**
         * @description List of Patient Staging records to process
         */
        public List<OrgSync_Patient_Staging__c> records;
        
        /**
         * @description Map of Patient External ID to Patient Contact ID
         */
        public Map<String, Id> patientExtIdToContactId;
        
        /**
         * @description Map of Provider Staging ID to Provider Contact ID
         */
        public Map<Id, Id> providerStagingToContactId;
        
        /**
         * @description Map of CCR key (patientContactId_providerContactId) to existing CCR record
         */
        public Map<String, ContactContactRelation> existingCCRMap;
        
        /**
         * @description CCR processing result containing records to insert/update
         */
        public CCRProcessingResult result;

        /**
         * @description Constructor to initialize CCRProcessingContext with empty collections
         */
        public CCRProcessingContext() {
            this.records = new List<OrgSync_Patient_Staging__c>();
            this.patientExtIdToContactId = new Map<String, Id>();
            this.providerStagingToContactId = new Map<Id, Id>();
            this.existingCCRMap = new Map<String, ContactContactRelation>();
            this.result = new CCRProcessingResult();
        }
    }

    /**
     * @description Inner class to hold CCR processing results
     */
    private class CCRProcessingResult {
        /**
         * @description List of CCR records to be inserted
         */
        public List<ContactContactRelation> ccrToInsert;
        
        /**
         * @description List of CCR records to be updated
         */
        public List<ContactContactRelation> ccrToUpdate;
        
        /**
         * @description Set of Patient Contact IDs that have CCR records to process
         */
        public Set<Id> patientContactIds;

        /**
         * @description Constructor to initialize CCRProcessingResult with empty collections
         */
        public CCRProcessingResult() {
            this.ccrToInsert = new List<ContactContactRelation>();
            this.ccrToUpdate = new List<ContactContactRelation>();
            this.patientContactIds = new Set<Id>();
        }
    }

    /**
     * @description Processes Patient Staging records and prepares CCR records for insert/update
     * @param context CCRProcessingContext containing all processing data
     * @return CCRProcessingResult containing CCRs to insert/update and patient contact IDs
     */
    private static CCRProcessingResult processCCRRecords(CCRProcessingContext context) {
        for (OrgSync_Patient_Staging__c patientStage : context.records) {
            if (String.isBlank(patientStage.XCDC_ExternalId__c) || patientStage.OrgSync_Provider__c == null) {
                continue;
            }

            Id patientContactId = context.patientExtIdToContactId.get(patientStage.XCDC_ExternalId__c);
            Id providerContactId = context.providerStagingToContactId.get(patientStage.OrgSync_Provider__c);

            if (patientContactId == null || providerContactId == null) {
                continue;
            }

            processSingleCCR(patientContactId, providerContactId, context);
        }

        return context.result;
    }

    /**
     * @description Processes a single CCR record (create or update)
     * @param patientContactId Patient Contact ID
     * @param providerContactId Provider Contact ID
     * @param context CCRProcessingContext containing existing CCR map and result
     */
    private static void processSingleCCR(
        Id patientContactId,
        Id providerContactId,
        CCRProcessingContext context
    ) {
        String ccrKey = patientContactId + '_' + providerContactId;
        ContactContactRelation existingCCR = context.existingCCRMap.get(ccrKey);

        if (existingCCR != null && existingCCR.PartyRoleRelationId == partyRoleRelationId) {
            handleExistingCCR(existingCCR, patientContactId, context.result);
        } else {
            createNewCCR(patientContactId, providerContactId, context.result);
        }
    }

    /**
     * @description Handles existing CCR record - updates if needed
     * @param existingCCR Existing CCR record
     * @param patientContactId Patient Contact ID
     * @param result CCRProcessingResult to populate
     */
    private static void handleExistingCCR(ContactContactRelation existingCCR,Id patientContactId,CCRProcessingResult result) {
        Boolean needsUpdate = false;
        if (existingCCR.IsActive != true) {
            existingCCR.IsActive = true;
            needsUpdate = true;
        }
        if (existingCCR.Is_Primary__c != true) {
            existingCCR.Is_Primary__c = true;
            needsUpdate = true;
        }
       
        if (needsUpdate) {
            result.ccrToUpdate.add(existingCCR);
            result.patientContactIds.add(patientContactId);
        }
    }

    /**
     * @description Creates a new CCR record
     * @param patientContactId Patient Contact ID
     * @param providerContactId Provider Contact ID
     * @param result CCRProcessingResult to populate
     */
    private static void createNewCCR(
        Id patientContactId,
        Id providerContactId,
        CCRProcessingResult result
    ) {
        ContactContactRelation newCCR = new ContactContactRelation(ContactId = patientContactId,RelatedContactId = providerContactId,IsActive = true,Is_Primary__c = true,PartyRoleRelationId = partyRoleRelationId);
        result.ccrToInsert.add(newCCR);
        result.patientContactIds.add(patientContactId);
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
     * @description Identifies Patient Person Account Contact IDs based on XCDC_ExternalId__c
     * @param records List of Patient Staging records
     * @return Map of External ID to Patient Contact ID
     */
    private static Map<String, Id> getPatientContactIds(List<OrgSync_Patient_Staging__c> records) {
        Map<String, Id> patientExtIdToContactId = new Map<String, Id>();
        Set<String> externalIds = new Set<String>();

        for (OrgSync_Patient_Staging__c record : records) {
            if (String.isNotBlank(record.XCDC_ExternalId__c)) {
                externalIds.add(record.XCDC_ExternalId__c);
            }
        }

        if (!externalIds.isEmpty()) {
            for (Account acc : [SELECT Id, PersonContactId, XCDC_ExternalId__c FROM Account WHERE XCDC_ExternalId__c IN :externalIds AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT AND PersonContactId != null WITH SYSTEM_MODE]) {
                if (String.isNotBlank(acc.XCDC_ExternalId__c) && acc.PersonContactId != null) {
                    patientExtIdToContactId.put(acc.XCDC_ExternalId__c, acc.PersonContactId);
                }
            }
        }

        return patientExtIdToContactId;
    }


    /**
     * @description Gets existing CCR records for the given patient contact IDs
     * @param patientContactIds Set of Patient Contact IDs
     * @return Map of CCR key (patientContactId_providerContactId) to CCR record
     */
    private static Map<String, ContactContactRelation> getExistingCCRs(List<Id> patientContactIds) {
        Map<String, ContactContactRelation> existingCCRMap = new Map<String, ContactContactRelation>();

        if (patientContactIds.isEmpty()) {
            return existingCCRMap;
        }

        for (ContactContactRelation ccr : [SELECT Id, ContactId, RelatedContactId, IsActive, Is_Primary__c, PartyRoleRelationId FROM ContactContactRelation WHERE ContactId IN :patientContactIds WITH SYSTEM_MODE]) {
            String ccrKey = String.valueOf(ccr.ContactId) + '_' + String.valueOf(ccr.RelatedContactId);
            existingCCRMap.put(ccrKey, ccr);
        }

        return existingCCRMap;
    }

    /**
     * @description Updates other primary providers to false for the same patients
     * @param patientContactIds Set of Patient Contact IDs
     * @param ccrToInsert List of CCR records to be inserted
     * @param ccrToUpdate List of CCR records to be updated
     */
    private static void updateOtherPrimaryProviders(Set<Id> patientContactIds,List<ContactContactRelation> ccrToInsert,List<ContactContactRelation> ccrToUpdate) {
        // Collect provider contact IDs that will be set as primary
        Set<Id> newPrimaryProviderContactIds = new Set<Id>();
        for (ContactContactRelation ccr : ccrToInsert) {
            newPrimaryProviderContactIds.add(ccr.RelatedContactId);
        }
        for (ContactContactRelation ccr : ccrToUpdate) {
            newPrimaryProviderContactIds.add(ccr.RelatedContactId);
        }

        // Find other primary providers for the same patients
        List<ContactContactRelation> otherPrimaryCCRs = [SELECT Id, ContactId, RelatedContactId, Is_Primary__c, PartyRoleRelationId FROM ContactContactRelation WHERE ContactId IN :patientContactIds AND Is_Primary__c = true AND RelatedContactId NOT IN :newPrimaryProviderContactIds WITH SYSTEM_MODE];

        if (!otherPrimaryCCRs.isEmpty()) {
            for (ContactContactRelation ccr : otherPrimaryCCRs) {
                ccr.Is_Primary__c = false;
            }
            OrgSync_CCRDMLHelper.updateCCRs(otherPrimaryCCRs);
        }
    }

}