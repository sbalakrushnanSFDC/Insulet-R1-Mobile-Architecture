/**
 * Helper class for Opportunity-related operations during Lead conversion.
 * Handles building NCS Opportunities, inserting with error handling, and updating existing Opportunities.
 *
 * @author      : Jatin Butta
 * @created Date: 16th January 2026
 * @description : Helper for Opportunity-related operations during Lead conversion
 * @story Number: NGASIM-1901
 * =========================== Logs ======================================
 * Version      Modified Date           Modified By                 Brief Note
 * V1.0.0       16th January 2026      Jatin Butta                 Initial Version(US - NGASIM-1901)
 * V1.1.0       18th February 2026     Bijayalaxmi Prusty          Updated(US- NGOMCT - 1961)
 * V1.2.0       Feb 23, 2026       	   Ayushi Gaikwad              Added Opp Name update to follow naming convention (US - NGOMCT-2366)
 */
public inherited sharing class LeadConversionOpportunityHelper {
    /**
     * @description Creates NCS Opportunity records for the provided Accounts.
     * @param leadsToConvert The list of Lead records
     * @param accountsCreated The list of created Account records
     * @param simulateOpportunityPermissionFailure Test-only toggle to simulate CRUD failure
     * @return List of created and inserted Opportunity records (empty list if insert fails)
     */
    public static List<Opportunity> createNCSOpportunities(
        List<Lead> leadsToConvert,
        List<Account> accountsCreated,
        Boolean simulateOpportunityPermissionFailure
    ) {
        // Check CRUD permission for Opportunity creation
        if (!Schema.SObjectType.Opportunity.isCreateable() || (Test.isRunningTest() && simulateOpportunityPermissionFailure)) {
            LeadConversionLogUtil.logDebug('User does not have permission to create Opportunity records');
            return new List<Opportunity>();
        }

        List<Opportunity> opportunitiesToInsert = buildOpportunityRecords(leadsToConvert, accountsCreated, ConstantsUtil.OPPORTUNITY_NCS_RT);

        if (!opportunitiesToInsert.isEmpty()) {
            return insertOpportunitiesWithErrorHandling(opportunitiesToInsert);
        }

        return opportunitiesToInsert;
    }

    /**
     * @description Updates existing opportunities with lead tracking fields.
     * @param opportunitiesToUpdate List of Opportunity records with tracking fields to update
     */
    public static void updateExistingOpportunities(List<Opportunity> opportunitiesToUpdate) {
        if (!Schema.SObjectType.Opportunity.isUpdateable()) {
            LeadConversionLogUtil.logDebug('User does not have permission to update Opportunity records');
            return;
        }

        List<Database.SaveResult> updateResults = Database.update(opportunitiesToUpdate, false, AccessLevel.SYSTEM_MODE);

        for (Integer i = 0; i < updateResults.size(); i++) {
            if (!updateResults[i].isSuccess()) {
                LeadConversionLogUtil.logError(
                    'Failed to update existing Opportunity at index ' + i + '. Errors: ' +
                    LeadConversionLogUtil.buildErrorMessage(updateResults[i].getErrors())
                );
            }
        }
    }

    /**
     * @description Checks if an Account has existing related Opportunities.
     * @param account Account record to check for opportunities
     * @return Boolean indicating if account has existing opportunities
     */
    public static Boolean hasExistingOpportunities(Account account) {
        if (account == null) {
            return false;
        }
        return (account.Opportunities?.size() > 0);
    }

    /**
     * @description Builds Opportunity records from Lead and Account data with specified record type.
     * @param leadsToConvert The list of Lead records
     * @param accountsCreated The list of created Account records
     * @param opportunityRecordTypeId The RecordType Id to use for the created Opportunities
     * @return List of Opportunity records ready for insert (with nulls for failed Accounts)
     */
    private static List<Opportunity> buildOpportunityRecords(List<Lead> leadsToConvert, List<Account> accountsCreated, Id opportunityRecordTypeId) {
        List<Opportunity> opportunitiesToInsert = new List<Opportunity>();

        for (Integer i = 0; i < accountsCreated.size(); i++) {
            Account acc = accountsCreated[i];
            Lead ld = leadsToConvert[i];

            // Skip if Account creation failed (null placeholder)
            if (acc == null || acc.Id == null) {
                opportunitiesToInsert.add(null); // Add null to maintain index positions
                continue;
            }
            String opportunityName = OpportunityService.getBenefitsInvestigationOpportunityName();

            opportunitiesToInsert.add(new Opportunity(
                RecordTypeId = opportunityRecordTypeId,
                Name = opportunityName,
                AccountId = acc.Id,
                StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
                CloseDate = Date.today().addDays(30),
                LeadSource = ld.LeadSource,
                Number_of_time_contacted__c = 1,
                Last_Contacted_Date__c = ld.CreatedDate != null ? ld.CreatedDate.date() : Date.today(),
                Insurance_Name__c = ld.Insurance_Company_Name__c,
                Insurance_Type__c = ld.Insurance_Type__c
            ));
        }

        return opportunitiesToInsert;
    }

    /**
     * @description Inserts Opportunity records with error handling and maintains index positions.
     * @param opportunitiesToInsert List of Opportunity records to insert
     * @return List of Opportunities with null entries for failed records
     */
    private static List<Opportunity> insertOpportunitiesWithErrorHandling(List<Opportunity> opportunitiesToInsert) {
        // Filter out null entries and track their original indices
        List<Opportunity> oppsToInsert = new List<Opportunity>();
        List<Integer> validIndices = new List<Integer>();

        for (Integer i = 0; i < opportunitiesToInsert.size(); i++) {
            if (opportunitiesToInsert[i] != null) {
                oppsToInsert.add(opportunitiesToInsert[i]);
                validIndices.add(i);
            }
        }

        if (oppsToInsert.isEmpty()) {
            return opportunitiesToInsert;
        }

        List<Database.SaveResult> saveResults = Database.insert(oppsToInsert, false, AccessLevel.USER_MODE);

        for (Integer i = 0; i < saveResults.size(); i++) {
            if (!saveResults[i].isSuccess()) {
                Integer originalIndex = validIndices[i];
                String errors = LeadConversionLogUtil.buildErrorMessage(saveResults[i].getErrors());
                LeadConversionLogUtil.logError('Failed to create NCS Opportunity at index ' + originalIndex + '. Errors: ' + errors);
                opportunitiesToInsert[originalIndex] = null; // Mark as failed
            }
        }

        return opportunitiesToInsert;
    }
}