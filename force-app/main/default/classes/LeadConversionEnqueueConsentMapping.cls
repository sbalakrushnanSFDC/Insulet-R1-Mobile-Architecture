/**
 * @description Service class to enqueue ContactPointTypeConsent mapping Queueable job
 *              after Lead conversion. Handles building mapping data and enqueueing the job.
 *
 * @author      Bijayalaxmi Prusty
 * @createdDate 27th Jan 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       27th Jan 2026       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1905)
 */
public with sharing class LeadConversionEnqueueConsentMapping {

    /**
     * @description Enqueues ContactPointTypeConsent mapping Queueable job
     * @param conversionResults List of lead conversion results
     * @param leadsWithAccountMatches Map of Lead to Account
     */
    public static void enqueueConsentMapping(
        List<Database.LeadConvertResult> conversionResults,
        Map<Lead, Account> leadsWithAccountMatches
    ) {
        if (conversionResults == null || conversionResults.isEmpty() || leadsWithAccountMatches == null || leadsWithAccountMatches.isEmpty()) {
            return;
        }

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList = buildMappingDataList(conversionResults, leadsWithAccountMatches);

        if (!mappingDataList.isEmpty()) {
            enqueueMappingJob(mappingDataList);
        }
    }

    /**
     * @description Enqueues ContactPointTypeConsent mapping Queueable job for Provider account conversions.
     * Used when Lead is converted to Provider Account (Provider_Practice_Lead record type).
     * @param lead Lead record with IndividualId (must be captured before conversion)
     * @param providerAccount Provider Account with PersonIndividualId
     */
    public static void enqueueConsentMappingForProvider(Lead lead, Account providerAccount) {
        if (lead == null || providerAccount == null ||
            lead.IndividualId == null || providerAccount.PersonIndividualId == null) {
            return;
        }

        LeadConversionConsentMappingQueueable.LeadConversionConsentData mappingData =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        mappingData.accountId = providerAccount.Id;
        mappingData.leadId = lead.Id;
        mappingData.patientIndividualId = providerAccount.PersonIndividualId;
        mappingData.leadIndividualId = lead.IndividualId;
        mappingData.newlyUpsertedPhoneIds = (AccountRelatedObjectsServiceHelper.contactPointPhoneIdsToUpsert != null &&
            !AccountRelatedObjectsServiceHelper.contactPointPhoneIdsToUpsert.isEmpty())
            ? new Set<Id>(AccountRelatedObjectsServiceHelper.contactPointPhoneIdsToUpsert)
            : new Set<Id>();

        enqueueMappingJob(new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>{ mappingData });
    }

    /**
     * @description Builds mapping data list from conversion results and leads with account matches
     * @param conversionResults List of lead conversion results
     * @param leadsWithAccountMatches Map of Lead to Account
     * @return List of LeadConversionConsentData
     */
    public static List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> buildMappingDataList(
        List<Database.LeadConvertResult> conversionResults,
        Map<Lead, Account> leadsWithAccountMatches
    ) {
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        for (Database.LeadConvertResult result : conversionResults) {
            if (!result.isSuccess() || result.getAccountId() == null || result.getLeadId() == null) {
                continue;
            }

            LeadMatchingResult matchingResult = findMatchingLeadAndAccount(result, leadsWithAccountMatches);

            if (matchingResult.isValid()) {
                LeadConversionConsentMappingQueueable.LeadConversionConsentData mappingData =
                    new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
                mappingData.accountId = matchingResult.account.Id;
                mappingData.leadId = matchingResult.lead.Id;
                mappingData.contactId = result.getContactId(); // Add contactId from conversion result
                mappingData.patientIndividualId = matchingResult.account.PersonIndividualId;
                mappingData.leadIndividualId = matchingResult.lead.IndividualId;

                // Pass newly upserted ContactPointPhone IDs from the main transaction
                if (AccountRelatedObjectsServiceHelper.contactPointPhoneIdsToUpsert != null &&
                    !AccountRelatedObjectsServiceHelper.contactPointPhoneIdsToUpsert.isEmpty()) {
                    mappingData.newlyUpsertedPhoneIds = new Set<Id>(AccountRelatedObjectsServiceHelper.contactPointPhoneIdsToUpsert);
                } else {
                    mappingData.newlyUpsertedPhoneIds = new Set<Id>();
                }

                mappingDataList.add(mappingData);
            }
        }

        return mappingDataList;
    }

    /**
     * @description Finds matching Lead and Account from the map based on conversion result
     * Ensures Lead has IndividualId populated from IndividualService static map if needed
     * @param result Lead conversion result
     * @param leadsWithAccountMatches Map of Lead to Account
     * @return LeadMatchingResult containing Lead and Account if found
     */
    private static LeadMatchingResult findMatchingLeadAndAccount(
        Database.LeadConvertResult result,
        Map<Lead, Account> leadsWithAccountMatches
    ) {
        LeadMatchingResult matchingResult = new LeadMatchingResult();

        for (Lead ld : leadsWithAccountMatches.keySet()) {
            if (ld.Id == result.getLeadId()) {
                Account acc = leadsWithAccountMatches.get(ld);

                // After Lead conversion, Lead.IndividualId is null
                // Populate it from IndividualService static map or Account.PersonIndividualId
                Lead leadWithIndividualId = new Lead(Id = ld.Id);

                if (ld.IndividualId != null) {
                    leadWithIndividualId.IndividualId = ld.IndividualId;
                } else if (IndividualService.leadIdToIndividualIdMap != null &&
                           IndividualService.leadIdToIndividualIdMap.containsKey(ld.Id)) {
                    leadWithIndividualId.IndividualId = IndividualService.leadIdToIndividualIdMap.get(ld.Id);
                }

                matchingResult.lead = leadWithIndividualId;
                matchingResult.account = acc;
                break;
            }
        }

        return matchingResult;
    }

    /**
     * @description Enqueues the mapping Queueable job
     * @param mappingDataList List of mapping data to process
     */
    private static void enqueueMappingJob(List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList) {
        if (!System.isQueueable() && !Test.isRunningTest()) {
            System.enqueueJob(new LeadConversionConsentMappingQueueable(mappingDataList));
        } else if (Test.isRunningTest() && !mappingDataList.isEmpty()) {
            LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(mappingDataList);
            job.execute(null);
        }
    }

    /**
     * @description Wrapper class to hold Lead and Account matching result
     */
    private class LeadMatchingResult {
        public Lead lead;
        public Account account;

        /**
         * @description Checks if the matching result is valid
         * Lead.IndividualId is populated from IndividualService static map or Account.PersonIndividualId
         * @return True if both Lead and Account exist and have IndividualIds
         */
        public Boolean isValid() {
            return lead != null && account != null &&
                   account.PersonIndividualId != null && lead.IndividualId != null;
        }
    }
}