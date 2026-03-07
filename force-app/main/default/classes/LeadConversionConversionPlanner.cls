/**
 * Planner/executor class for Lead conversion that builds Database.LeadConvert requests,
 * creates or reuses Opportunities as needed, and performs the conversion.
 *
 * @author      : Jatin Butta
 * @created Date: 16th January 2026
 * @description : Planner/executor for Lead conversion that builds Database.LeadConvert requests
 * @story Number: NGASIM-1901
 * =========================== Logs ======================================
 * Version      Modified Date           Modified By                 Brief Note
 * V1.0.0       16th January 2026      Jatin Butta                 Initial Version(US - NGASIM-1901)
 * V1.0.1       12nd Feb 2026          Rucha Kelkar                Modified(US - NGASIM-2251)
 * V1.0.2       18th Feb 2026          Bijayalaxmi Prusty          Modified(US - NGOMCT-1961)
 */
public inherited sharing class LeadConversionConversionPlanner {
    /**
     * @description Prepares all data needed for lead conversion including categorization, opportunity creation, and convert objects.
     * @param leadsToAccountMap Map of leads to convert and their matched accounts
     * @param simulateOpportunityPermissionFailure Test-only toggle to simulate CRUD failure for Opportunity
     * @return LeadConversionHelper.LeadConversionData containing prepared conversion objects
     */
    public static LeadConversionHelper.LeadConversionData prepareLeadConversionData(
        Map<Lead, Account> leadsToAccountMap,
        Boolean simulateOpportunityPermissionFailure
    ) {
        LeadConversionHelper.LeadConversionData result = new LeadConversionHelper.LeadConversionData();

        List<Lead> leadsNeedingOpportunities = new List<Lead>();
        List<Account> accountsNeedingOpportunities = new List<Account>();
        Set<Id> accountsWithExistingOpportunities = new Set<Id>();

        for (Lead leadToConvert : leadsToAccountMap.keySet()) {
            Account targetAccount = leadsToAccountMap.get(leadToConvert);
            if (targetAccount?.Id == null) {
                continue;
            }

            if (LeadConversionOpportunityHelper.hasExistingOpportunities(targetAccount)) {
                accountsWithExistingOpportunities.add(targetAccount.Id);
            } else {
                leadsNeedingOpportunities.add(leadToConvert);
                accountsNeedingOpportunities.add(targetAccount);
            }
        }

        Map<Id, Opportunity> opportunityByAccountId = new Map<Id, Opportunity>();
        if (!leadsNeedingOpportunities.isEmpty()) {
            List<Opportunity> newOpportunities = LeadConversionOpportunityHelper.createNCSOpportunities(
                leadsNeedingOpportunities,
                accountsNeedingOpportunities,
                simulateOpportunityPermissionFailure
            );
            for (Integer i = 0; i < accountsNeedingOpportunities.size(); i++) {
                if (i >= newOpportunities.size()) {
                    break;
                }
                if (newOpportunities[i] != null) {
                    opportunityByAccountId.put(accountsNeedingOpportunities[i].Id, newOpportunities[i]);
                }
            }
        }

        LeadConversionHelper.LeadConvertBuildContext buildContext = new LeadConversionHelper.LeadConvertBuildContext(
            leadsToAccountMap,
            accountsWithExistingOpportunities,
            opportunityByAccountId
        );
        buildLeadConvertObjects(buildContext, result);

        return result;
    }

    /**
     * @description Executes lead conversions and handles results.
     * @param conversionData LeadConversionHelper.LeadConversionData containing conversion objects
     * @return List of lead conversion results
     */
    public static List<Database.LeadConvertResult> executeLeadConversions(LeadConversionHelper.LeadConversionData conversionData) {
        List<Database.LeadConvertResult> convertResults = new List<Database.LeadConvertResult>();

        if (conversionData == null || conversionData.leadConverts.isEmpty()) {
            return convertResults;
        }

        convertResults = Database.convertLead(conversionData.leadConverts, false, AccessLevel.SYSTEM_MODE);

        for (Integer i = 0; i < convertResults.size(); i++) {
            if (!convertResults[i].isSuccess()) {
                LeadConversionLogUtil.logError(
                    'Failed to convert Lead at index ' + i + '. Errors: ' +
                    LeadConversionLogUtil.buildErrorMessage(convertResults[i].getErrors())
                );
            }
        }

        if (!conversionData.existingOpportunitiesToUpdate.isEmpty()) {
            LeadConversionOpportunityHelper.updateExistingOpportunities(conversionData.existingOpportunitiesToUpdate);
        }

        return convertResults;
    }

    /**
     * @description Builds Database.LeadConvert objects and configures opportunity assignments.
     * @param buildContext LeadConversionHelper.LeadConvertBuildContext containing all required input data
     * @param result LeadConversionHelper.LeadConversionData to populate with conversion objects
     */
    private static void buildLeadConvertObjects(LeadConversionHelper.LeadConvertBuildContext buildContext, LeadConversionHelper.LeadConversionData result) {
        for (Lead leadToConvert : buildContext.leadsToAccountMap.keySet()) {
            Account targetAccount = buildContext.leadsToAccountMap.get(leadToConvert);
            if (targetAccount?.Id == null) {
                continue;
            }

            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(leadToConvert.Id);
            lc.setAccountId(targetAccount.Id);
            // Ensure converted records are owned by the current user
            lc.setOwnerId(UserInfo.getUserId());
            lc.setConvertedStatus('Converted');

            Boolean hasExistingOpps = buildContext.accountsWithExistingOpportunities.contains(targetAccount.Id);
            Boolean hasOpportunityData = (targetAccount.Opportunities?.size() > 0);

            if (hasExistingOpps && hasOpportunityData) {
                lc.setOpportunityId(targetAccount.Opportunities[0].Id);

                for (Opportunity existingOpp : targetAccount.Opportunities) {
                    Integer contactCount = 1;
                    if (existingOpp.Number_of_time_contacted__c != null) {
                        contactCount = Integer.valueOf(existingOpp.Number_of_time_contacted__c + 1);
                    }
                    result.existingOpportunitiesToUpdate.add(new Opportunity(
                        Id = existingOpp.Id,
                        Number_of_time_contacted__c = contactCount,
                        Last_Contacted_Date__c = leadToConvert.CreatedDate.date(),
                        Insurance_Name__c = leadToConvert.Insurance_Company_Name__c,
                        Insurance_Type__c = leadToConvert.Insurance_Type__c
                    ));
                }
                result.leadConverts.add(lc);
                continue;
            }

            Opportunity createdOpp = buildContext.opportunityByAccountId.get(targetAccount.Id);
            if (createdOpp?.Id != null) {
                lc.setOpportunityId(createdOpp.Id);
                result.leadConverts.add(lc);
            }
        }
    }
}