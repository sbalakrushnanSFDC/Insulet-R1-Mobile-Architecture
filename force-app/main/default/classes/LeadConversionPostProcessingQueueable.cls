/**
 * @description Queueable class to handle post-conversion processing for Patient Leads.
 *              Processes Opportunity updates, Provider Relations, Caregiver Relations
 *              (including ContactPoints for minors), ACR creation, Patient-Provider CCRs,
 *              and ContactPointTypeConsent mapping asynchronously.
 *
 * @author      Charchit Nirayanwal
 * @createdDate 20th Feb 2026
 * =========================== Logs ======================================
 * Version      Modified Date           Modified By             Brief Note
 * V1.0.0       20th Feb 2026          Charchit Nirayanwal      Initial Version
 * V1.0.1       24th Feb 2026          Charchit Nirayanwal      Added CCR and Consent mapping (US - NGASIM-2207)
 *
 */
public with sharing class LeadConversionPostProcessingQueueable implements Queueable {

    private List<Id> leadIdsToProcess;
    private String errorTagName;
    private List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList;
    private Map<Lead, Account> leadsToAccountMap;

    /**
     * @description Constructor - accepts lead IDs; queueable queries converted leads for fresh data (IsConverted, ConvertedAccountId, etc.)
     * @param leadIdsToProcess List of Lead IDs to process
     * @param tagName Tag name for logger stream
     * @param mappingDataList Serializable mapping data list for CCR and consent mapping (optional)
     * @param leadsToAccountMap Map of Lead to Account for post-processing (optional)
     */
    public LeadConversionPostProcessingQueueable(
        List<Id> leadIdsToProcess,
        String tagName,
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList,
        Map<Lead, Account> leadsToAccountMap
    ) {
        this.leadIdsToProcess = leadIdsToProcess != null ? leadIdsToProcess : new List<Id>();
        this.errorTagName = tagName != null ? tagName : ConstantsUtil.ASIM_TAG;
        this.mappingDataList = mappingDataList;
        this.leadsToAccountMap = leadsToAccountMap;
    }

    /**
     * @description Constructor without context (for backward compatibility with automatic conversion path)
     * @param leadIdsToProcess List of Lead IDs to process
     * @param tagName Tag name for logger stream
     */
    public LeadConversionPostProcessingQueueable(
        List<Id> leadIdsToProcess,
        String tagName
    ) {
        this(leadIdsToProcess, tagName, null, null);
    }

    /**
     * @description Execute method called by the Queueable framework.
     * Queries converted leads for fresh data (IsConverted, ConvertedAccountId, etc.) before processing.
     * @param context QueueableContext
     */
    public void execute(QueueableContext context) {
        if (leadIdsToProcess == null || leadIdsToProcess.isEmpty()) {
            return;
        }

        try {
            // Query converted leads for fresh data (IsConverted, ConvertedAccountId, ConvertedContactId, etc.)
            List<Lead> leadsToProcess = queryConvertedLeads(leadIdsToProcess);
            if (leadsToProcess.isEmpty()) {
                return;
            }

            List<Lead> minorLeads = new List<Lead>();
            for (Lead ld : leadsToProcess) {
                if (ld.Age__c != null && ld.Age__c < ConstantsUtil.MINOR_AGE_THRESHOLD) {
                    minorLeads.add(ld);
                }
            }

            // 1. Update Opportunities
            OpportunityService.updateConvertedOpportunities(leadsToProcess, errorTagName);

            // 2. Process Provider Relations
            ProviderRelationshipService.processProviderRelations(leadsToProcess, errorTagName);

            // 3. Process Minor Caregiver ContactPoints (must run before processCaregiverRelations)
            if (!minorLeads.isEmpty()) {
                CaregiverRelationshipService.processMinorCaregiverContactPoints(
                    minorLeads,
                    errorTagName
                );
            }

            // 4. Process Caregiver Relations (uses cache from processMinorCaregiverContactPoints)
            CaregiverRelationshipService.processCaregiverRelations(leadsToProcess, errorTagName);

            // 5. Create Patient-Practice ACR records
            AccountContactRelationService.createACRForPatientPractice(
                leadsToProcess,
                errorTagName
            );

            // 6. Create Patient-Provider CCRs and Enqueue ContactPointTypeConsent mapping
            // Filter leadsToAccountMap and mappingDataList to only include leads being processed
            if (mappingDataList != null && !mappingDataList.isEmpty() &&
                leadsToAccountMap != null && !leadsToAccountMap.isEmpty()) {
                    // Create Patient-Provider CCRs using mappingDataList
                    ContactContactRelationService.createPatientProviderCCRsFromMappingData(
                        mappingDataList,
                        leadsToAccountMap,
                        errorTagName
                    );
                    // Enqueue consent mapping using mappingDataList directly
                    // Chaining is allowed: can enqueue from within queueable context
                    if (!Test.isRunningTest()) {System.enqueueJob(new LeadConversionConsentMappingQueueable(mappingDataList));
                    } else {
                        LeadConversionConsentMappingQueueable consentJob = new LeadConversionConsentMappingQueueable(mappingDataList);
                        consentJob.execute(null);
                    }
                }
            }
        catch (Exception ex) {Logger.error('Error processing Lead conversion post-processing in Queueable: ' + ex.getMessage(),new List<SObject>(),ex).addTag(errorTagName);Logger.saveLog();
        }
    }

    /**
     * @description Queries converted leads with all fields required for post-processing.
     * Only returns leads where IsConverted = true.
     * @param leadIds Lead IDs to query
     * @return List of converted Lead records with required fields
     */
    private static List<Lead> queryConvertedLeads(List<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {return new List<Lead>();}
        return [
            SELECT Id, IsConverted, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId,
                   LastModifiedDate, FirstName, MiddleName, LastName, Recommended_Product__c,
                   Provider_Practice_Affiliation__c, Related_Provider__c, Age__c,
                   Caregiver_First_Name__c, Caregiver_Last_Name__c, IndividualId,
                   Phone, MobilePhone, Email
            FROM Lead
            WHERE Id IN :leadIds AND IsConverted = true
            WITH SYSTEM_MODE
        ];
    }

}