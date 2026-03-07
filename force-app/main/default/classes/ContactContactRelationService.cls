/**
 * @description Service class responsible ContactContactRelationship
 * Created Date : Oct 10, 2025
 * Created By   : Sunil Khanchandani
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Oct 10, 2025       Sunil Khanchandani       Initial Version
 * V1.1.0       Nov 28, 2025       Bijayalaxmi Prusty      Modified(US NGASIM-1050)
*/

public inherited sharing class ContactContactRelationService {

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null for permission errors)
     */
    private static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    /**
    * @description Inserts ContactContactRelation records using bulk-safe partial DML and logs failures
    * @param relationRecords List of ContactContactRelation records to insert
    * @param tagName Tag name used for structured logging of errors during DML operations
    */
    public static void insertContactContactRelationships(List<ContactContactRelation> relationRecords, String tagName) {
        try {
            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on');
            }

            if(!relationRecords.isEmpty()){
                // Use SYSTEM_MODE to bypass sharing rules when inserting ContactContactRelation records
                // This is necessary because the provider Contact (RelatedContactId) may not be accessible
                // to the current user due to sharing rules, but the system should still be able to create
                // the relationship during lead conversion
                Database.SaveResult[] results = Database.insert(relationRecords, false, AccessLevel.SYSTEM_MODE);
                for (Integer i = 0; i < results.size(); i++) {
                    Database.SaveResult sr = results[i];

                    if (!sr.isSuccess()) {
                        for (Database.Error err : sr.getErrors()) {
                            String errorMessage = 'Failed to insert ContactContactRelation record: ' + err.getMessage();
                            // Provide more context for duplicate errors
                            Logger.error(errorMessage, sr)
                                .setRecord(relationRecords[i])
                                .addTag(tagName);
                        }
                    }
                }
            }

        } catch (Exception ex) {
            List<SObject> relationSObjects = new List<SObject>();
            relationSObjects.addAll(relationRecords);
            for (Integer i = 0; i < relationSObjects.size(); i++) {
                logError('Failed to insert ContactContactRelation at index ' + i + '. Error: ' + ex.getMessage(),
                        new List<SObject>{relationSObjects[i]}, ex);
            }
        }
    }

    /**
    * @description Fetches PartyRoleRelation records matching the provided RelatedRoleName
    * @param relatedRoleName API name of the related role to search for
    * @return List of PartyRoleRelation records matching the relatedRoleName
    */
    public static List<PartyRoleRelation> fetchRoleRelationRecord(String relatedRoleName) {
        return [ SELECT Id FROM PartyRoleRelation WHERE RelatedRoleName = :relatedRoleName WITH SECURITY_ENFORCED];
    }
    /**
    * @description Fetches PartyRoleRelation records matching the provided Party Role Relationship Id
    * @param roleName name of the party role relationship id to search for
    * @return List of PartyRoleRelation records matching the roleName
    */
    public static List<PartyRoleRelation> fetchPartyRoleRelationRecordByName(String roleName) {
        return [ SELECT Id FROM PartyRoleRelation WHERE Name = :roleName WITH SECURITY_ENFORCED];
    }

    /**
     * @description Creates ContactContactRelation records for converted patient leads using serializable mapping data
     * @param mappingDataList List of LeadConversionConsentData containing lead and contact IDs
     * @param leadsToAccountMap Map of leads to their converted accounts
     * @param tagName Tag name for logging context
     */
    public static void createPatientProviderCCRsFromMappingData(
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList,
        Map<Lead, Account> leadsToAccountMap,
        String tagName
    ) {
        try {
            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on');
            }

            if (mappingDataList == null || mappingDataList.isEmpty() ||
                leadsToAccountMap == null || leadsToAccountMap.isEmpty()) {
                return;
            }

            // Collect facility IDs and create lead mapping
            ProcessingContext context = buildProcessingContext(leadsToAccountMap);

            if (context.facilityIds.isEmpty()) { return; }

            // Query HealthcarePractitionerFacility records using separate method
            Map<Id, Id> facilityToProviderContactMap = queryFacilityProviderContacts(context.facilityIds);
            if (facilityToProviderContactMap.isEmpty()) { return; }

            // Build CCR records using mappingDataList
            List<ContactContactRelation> ccrRecords = buildCCRRecordsFromMappingData(
                mappingDataList,
                context.leadIdToLeadMap,
                facilityToProviderContactMap
            );

            // Filter out duplicates before inserting
            List<ContactContactRelation> ccrRecordsToInsert = ContactContactRelationDuplicateFilter.filterDuplicateCCRs(ccrRecords);

            // Use existing method to insert CCR records
            if (!ccrRecordsToInsert.isEmpty()) {
                insertContactContactRelationships(ccrRecordsToInsert, tagName);
            }

        } catch (Exception ex) {
            handleExceptionLogging(ex, leadsToAccountMap);
        }
    }

    /**
     * @description Creates ContactContactRelation records for converted patient leads
     * @param convertResults List of lead conversion results
     * @param leadsToAccountMap Map of leads to their converted accounts
     * @param tagName Tag name for logging context
     */
    public static void createPatientProviderCCRs(List<Database.LeadConvertResult> convertResults, Map<Lead, Account> leadsToAccountMap, String tagName) {
        try {
            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on');
            }

            if (!isValidInput(convertResults, leadsToAccountMap)) {
                return;
            }

            // Collect facility IDs and create lead mapping
            ProcessingContext context = buildProcessingContext(leadsToAccountMap);

            if (context.facilityIds.isEmpty()) { return; }

            // Query HealthcarePractitionerFacility records using separate method
            Map<Id, Id> facilityToProviderContactMap = queryFacilityProviderContacts(context.facilityIds);
            if (facilityToProviderContactMap.isEmpty()) { return; }

            // Build CCR records using separate method
            List<ContactContactRelation> ccrRecords = buildCCRRecords(convertResults, context.leadIdToLeadMap, facilityToProviderContactMap);

            // Filter out duplicates before inserting
            List<ContactContactRelation> ccrRecordsToInsert = ContactContactRelationDuplicateFilter.filterDuplicateCCRs(ccrRecords);

            // Use existing method to insert CCR records
            if (!ccrRecordsToInsert.isEmpty()) {
                insertContactContactRelationships(ccrRecordsToInsert, tagName);
            }

        } catch (Exception ex) {
            handleExceptionLogging(ex, leadsToAccountMap);
        }
    }

    /**
     * @description Validates input parameters for createPatientProviderCCRs method
     * @param convertResults List of lead conversion results
     * @param leadsToAccountMap Map of leads to accounts
     * @return Boolean indicating if inputs are valid
     */
    private static Boolean isValidInput(List<Database.LeadConvertResult> convertResults, Map<Lead, Account> leadsToAccountMap) {
        return convertResults != null && !convertResults.isEmpty() &&
               leadsToAccountMap != null && !leadsToAccountMap.isEmpty();
    }

    /**
     * @description Builds processing context containing facility IDs and lead mapping
     * @param leadsToAccountMap Map of leads to accounts
     * @return ProcessingContext with facility IDs and lead mapping
     */
    private static ProcessingContext buildProcessingContext(Map<Lead, Account> leadsToAccountMap) {
        ProcessingContext context = new ProcessingContext();

        for (Lead lead : leadsToAccountMap.keySet()) {
            context.leadIdToLeadMap.put(lead.Id, lead);
            if (lead.Provider_Practice_Affiliation__c != null) {
                context.facilityIds.add(lead.Provider_Practice_Affiliation__c);
            }
        }

        return context;
    }

    /**
     * @description Handles exception logging for createPatientProviderCCRs method
     * @param ex Exception that occurred
     * @param leadsToAccountMap Map of leads to accounts for context
     */
    private static void handleExceptionLogging(Exception ex, Map<Lead, Account> leadsToAccountMap) {
        List<SObject> leadSObjects = new List<SObject>();
        if (leadsToAccountMap != null) {
            for (Lead leadRec : leadsToAccountMap.keySet()) {
                leadSObjects.add(leadRec);
            }
        }
        for (Integer i = 0; i < leadSObjects.size(); i++) {
            logError('Failed to create ContactContactRelation for Lead at index ' + i + '. Error: ' + ex.getMessage(),
                    new List<SObject>{leadSObjects[i]}, ex);
        }
    }

    /**
     * @description Inner class to hold processing context data
     */
    private class ProcessingContext {
        public Set<Id> facilityIds;
        public Map<Id, Lead> leadIdToLeadMap;

        /**
         * @description Constructor that initializes empty collections for facility IDs and lead mapping
         */
        public ProcessingContext() {
            this.facilityIds = new Set<Id>();
            this.leadIdToLeadMap = new Map<Id, Lead>();
        }
    }

    /**
     * @description Queries HealthcarePractitionerFacility records to get provider contact IDs
     * @param facilityIds Set of HealthcarePractitionerFacility IDs
     * @return Map of HealthcarePractitionerFacility ID to Provider Contact ID
     */
    private static Map<Id, Id> queryFacilityProviderContacts(Set<Id> facilityIds) {
        Map<Id, Id> facilityToProviderContactMap = new Map<Id, Id>();

        for (HealthcarePractitionerFacility facility : [
            SELECT Id, PractitionerId
            FROM HealthcarePractitionerFacility
            WHERE Id IN :facilityIds AND PractitionerId != null
            WITH SECURITY_ENFORCED
        ]) {
            facilityToProviderContactMap.put(facility.Id, facility.PractitionerId);
        }
        return facilityToProviderContactMap;
    }

    /**
     * @description Builds ContactContactRelation records from conversion results
     * @param convertResults List of lead conversion results
     * @param leadIdToLeadMap Map of Lead IDs to Lead records
     * @param facilityToProviderContactMap Map of facility ID to provider contact ID
     * @return List of ContactContactRelation records
     */
    private static List<ContactContactRelation> buildCCRRecords(
        List<Database.LeadConvertResult> convertResults,
        Map<Id, Lead> leadIdToLeadMap,
        Map<Id, Id> facilityToProviderContactMap
    ) {
        List<ContactContactRelation> ccrRecords = new List<ContactContactRelation>();
        // Get PartyRoleRelation ID using existing method
        List<PartyRoleRelation> partyRoleRelations = fetchPartyRoleRelationRecordByName(ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE);
        if (partyRoleRelations.isEmpty()) {
            logError('PartyRoleRelation record not found for role: ' + ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE,
                     new List<SObject>(), null);
            return ccrRecords; // Return empty list if no role relation found
        }
        Id partyRoleRelationId = partyRoleRelations[0].Id;

        for (Database.LeadConvertResult result : convertResults) {
            if (result.isSuccess() && result.getContactId() != null && result.getLeadId() != null) {
                Lead originalLead = leadIdToLeadMap.get(result.getLeadId());
                if (originalLead?.Provider_Practice_Affiliation__c != null) {
                    Id providerContactId = facilityToProviderContactMap.get(originalLead.Provider_Practice_Affiliation__c);
                    if (providerContactId != null) {
                        ccrRecords.add(new ContactContactRelation(
                            ContactId = result.getContactId(),
                            RelatedContactId = providerContactId,
                            IsActive = true,
                            Is_Primary__c = true,
                            PartyRoleRelationId = partyRoleRelationId
                        ));
                    } else {logError('Provider contact not found for HealthcarePractitionerFacility: ' + originalLead.Provider_Practice_Affiliation__c, new List<SObject>{originalLead}, null);
                    }
                }
            }
        }

        return ccrRecords;
    }

    /**
     * @description Builds ContactContactRelation records from mapping data list
     * @param mappingDataList List of LeadConversionConsentData containing lead and contact IDs
     * @param leadIdToLeadMap Map of Lead IDs to Lead records
     * @param facilityToProviderContactMap Map of facility ID to provider contact ID
     * @return List of ContactContactRelation records
     */
    private static List<ContactContactRelation> buildCCRRecordsFromMappingData(
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList,
        Map<Id, Lead> leadIdToLeadMap,
        Map<Id, Id> facilityToProviderContactMap
    ) {
        List<ContactContactRelation> ccrRecords = new List<ContactContactRelation>();
        // Get PartyRoleRelation ID using existing method
        List<PartyRoleRelation> partyRoleRelations = fetchPartyRoleRelationRecordByName(ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE);
        if (partyRoleRelations.isEmpty()) {
            logError('PartyRoleRelation record not found for role: ' + ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE,
                     new List<SObject>(), null);
            return ccrRecords; // Return empty list if no role relation found
        }
        Id partyRoleRelationId = partyRoleRelations[0].Id;

        for (LeadConversionConsentMappingQueueable.LeadConversionConsentData mappingData : mappingDataList) {
            if (mappingData.contactId != null && mappingData.leadId != null) {
                Lead originalLead = leadIdToLeadMap.get(mappingData.leadId);
                if (originalLead?.Provider_Practice_Affiliation__c != null) {
                    Id providerContactId = facilityToProviderContactMap.get(originalLead.Provider_Practice_Affiliation__c);
                    if (providerContactId != null) {
                        ccrRecords.add(new ContactContactRelation(
                            ContactId = mappingData.contactId,
                            RelatedContactId = providerContactId,
                            IsActive = true,
                            Is_Primary__c = true,
                            PartyRoleRelationId = partyRoleRelationId
                        ));
                    } else {
                        logError('Provider contact not found for HealthcarePractitionerFacility: ' + originalLead.Provider_Practice_Affiliation__c, new List<SObject>{originalLead}, null);
                    }
                }
            }
        }

        return ccrRecords;
    }

    /**
    * @description Exception class for Contact Contact Relation Service
    */
    public class MyCustomException extends Exception {}
}