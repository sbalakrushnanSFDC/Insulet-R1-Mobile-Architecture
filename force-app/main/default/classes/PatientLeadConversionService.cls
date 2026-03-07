/**
 * Patient lead conversion service.
 * Handles automatic conversion of eligible Patient Leads into Person Accounts and related Opportunities,
 * including duplicate matching, conversion execution, and post-conversion updates.
 *
 * @author      : Priyansh Shukla
 * @created Date: 30th October 2025
 * @description : Apex service class to process Patient Leads and perform lead conversion
 * @story Number: NGASIM-992
 * =========================== Logs ======================================
 * Version      Modified Date           Modified By                 Brief Note
 * V1.0.0       30th October 2025       Priyansh Shukla             Initial Version(US - NGASIM-992)
 * V1.0.1       26th November 2025      Bijayalaxmi Prusty          Updated(US - NGASIM-1050)
 * V1.0.2       2nd December 2025       Bijayalaxmi Prusty          Updated(US - NGASIM-1080)
 * V1.0.3       15th December 2025      Bijayalaxmi Prusty          Modified(US - NGOMCT-824)
 * V1.0.4       29th JAN 2026           Priyansh Shukla             Updated(US - NGASIM-2120)
 * V1.0.5       12nd Feb 2026           Priyansh Shukla             Modified(US - NGASIM-1898)
 * V1.0.6       12nd Feb 2026           Rucha Kelkar                Modified(US - NGASIM-2251)
 * V1.0.7		12nd Feb 2026		    Bijayalaxmi Prusty			Modified(US - NGASIM-2065)
 */
public inherited sharing class PatientLeadConversionService {
    @TestVisible
    private static Boolean simulatePermissionFailure = false;

    /**
     * @description Processes automatic Patient lead conversion
     * Called from LeadConversionHandler after leads have been filtered for eligibility
     * @param eligibleLeads List of pre-filtered eligible Lead records
     */
    public static void processAutomaticLeadConversion(List<Lead> eligibleLeads) {

        if (eligibleLeads == null || eligibleLeads.isEmpty()) {
            return;
        }

        // Perform lead conversion on pre-filtered eligible leads
        performLeadConversion(eligibleLeads);
    }

    /**
     * @description Processes automatic Patient lead conversion and returns conversion results
     * Similar to processAutomaticLeadConversion but returns the conversion results for tracking
     * @param eligibleLeads List of pre-filtered eligible Lead records
     * @return List of Database.LeadConvertResult containing conversion results
     */
    public static List<Database.LeadConvertResult> processAutomaticLeadConversionWithResults(List<Lead> eligibleLeads) {
        if (eligibleLeads == null || eligibleLeads.isEmpty()) {
            return new List<Database.LeadConvertResult>();
        }

        return performLeadConversionWithResults(eligibleLeads);
    }

    /* ======================== Data Operations ======================== */

    /**
     * @description Performs the bulk conversion DML on a list of eligible leads.
     * Includes CRUD/FLS checks for Lead, Account, Contact, and Opportunity.
     * @param leadsToConvert The pre-filtered list of leads to convert
     */
    @TestVisible
    private static void performLeadConversion(List<Lead> leadsToConvert) {
            // Check CRUD permissions before lead conversion
            if (!hasLeadConversionPermissions()) {
                logError('User does not have sufficient permissions to convert leads', leadsToConvert, null);
                return;
            }

            ConversionRequestData requestData = buildConversionRequests(leadsToConvert);

            if (requestData.conversionRequests.isEmpty()) {
                return;
            }

        try {
            // Update Validation_Bypass__c to true before conversion to bypass validation rule
            LeadConversionHelper.updateValidationBypassForLeads(leadsToConvert);
            List<Database.LeadConvertResult> convertResults = Database.convertLead(requestData.conversionRequests, false);
            processConversionResults(convertResults, leadsToConvert, requestData.indexToAccountIdMap);
        } catch (Exception e) {
            logError('Critical error during bulk lead conversion', leadsToConvert, e);
        }
    }

    /**
     * @description Performs the bulk conversion DML on a list of eligible leads and returns results.
     * Similar to performLeadConversion but returns conversion results for tracking.
     * Includes CRUD/FLS checks for Lead, Account, Contact, and Opportunity.
     * @param leadsToConvert The pre-filtered list of leads to convert
     * @return List of Database.LeadConvertResult containing conversion results
     */
    @TestVisible
    private static List<Database.LeadConvertResult> performLeadConversionWithResults(List<Lead> leadsToConvert) {
        List<Database.LeadConvertResult> convertResults = new List<Database.LeadConvertResult>();
        try {
            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new System.DmlException('customExceptionSwitch is turned on for performLeadConversion');
            }

            // Check CRUD permissions before lead conversion
            if (!hasLeadConversionPermissions()) {
                logError('User does not have sufficient permissions to convert leads', leadsToConvert, null);
                return convertResults;
            }

            ConversionRequestData requestData = buildConversionRequests(leadsToConvert);

            if (requestData.conversionRequests.isEmpty()) {
                return convertResults;
            }

            // Update Validation_Bypass__c to true before conversion to bypass validation rule
            LeadConversionHelper.updateValidationBypassForLeads(leadsToConvert);
            convertResults = Database.convertLead(requestData.conversionRequests, false);
            processConversionResults(convertResults, leadsToConvert, requestData.indexToAccountIdMap);

            return convertResults;
        } catch (Exception e) {
            logError('Critical error during bulk lead conversion', leadsToConvert, e);
            return convertResults;
        }
    }

    /**
     * @description Checks if the user has all necessary permissions to convert leads.
     * Lead conversion requires permissions to update Lead and create Account, Contact, and Opportunity.
     * @return True if user has all required permissions, false otherwise
     */
    private static Boolean hasLeadConversionPermissions() {
        if (simulatePermissionFailure) {
            return false;
        }
        return Schema.SObjectType.Lead.isUpdateable()
			&& Schema.SObjectType.Account.isCreateable()
            && Schema.SObjectType.Contact.isCreateable()
            && Schema.SObjectType.Opportunity.isCreateable();
    }

    /**
     * @description Builds a list of Database.LeadConvert objects for bulk conversion.
     * Creates Patient Account and NCS Opportunity records with specific record types.
     * @param leadsToConvert The list of Lead records to convert
     * @return ConversionRequestData containing conversion requests and account ID mapping
     */
    @TestVisible
    private static ConversionRequestData buildConversionRequests(List<Lead> leadsToConvert) {
        ConversionRequestData requestData = new ConversionRequestData();

        // Create and insert Patient Accounts using helper class
        List<Account> accountsCreated = LeadConversionHelper.createPatientAccounts(leadsToConvert);

        if (accountsCreated.isEmpty()) {
            return requestData;
        }

        // Create and insert NCS Opportunities using helper class
        List<Opportunity> opportunitiesCreated = LeadConversionHelper.createNCSOpportunities(leadsToConvert, accountsCreated);

        if (opportunitiesCreated.isEmpty()) {
            return requestData;
        }

        // Build conversion requests with validation
        Integer conversionRequestIndex = 0;
        for (Integer i = 0; i < leadsToConvert.size(); i++) {
            Lead ld = leadsToConvert[i];
            Account acc = (i < accountsCreated.size()) ? accountsCreated[i] : null;
            Opportunity opp = (i < opportunitiesCreated.size()) ? opportunitiesCreated[i] : null;

            // Skip if Account or Opportunity missing
            if (acc == null || acc.Id == null || opp == null || opp.Id == null) {
                continue;
            }

            // Create and add LeadConvert object
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(ld.Id);
            lc.setAccountId(acc.Id);
            lc.setOpportunityId(opp.Id);
            // Ensure converted records are owned by the current user
            lc.setOwnerId(UserInfo.getUserId());
            lc.setConvertedStatus('Converted');
            lc.setBypassAccountDedupeCheck(true);
            lc.setBypassContactDedupeCheck(true);
            requestData.conversionRequests.add(lc);
            // Map conversion request index to Account ID for tracking
            requestData.indexToAccountIdMap.put(conversionRequestIndex, acc.Id);
            conversionRequestIndex++;
        }

        return requestData;
    }


    /**
     * @description Processes conversion results and logs any failures.
     * Creates opportunity products for successfully converted leads.
     * @param convertResults The results from Database.convertLead operation
     * @param leadsToConvert The original list of leads that were converted
     * @param indexToAccountIdMap The original list of account map to lead index
     */
    @TestVisible
    private static void processConversionResults(List<Database.LeadConvertResult> convertResults, List<Lead> leadsToConvert, Map<Integer, Id> indexToAccountIdMap) {
        if (convertResults == null) {
            return;
        }

        ProcessConversionContext context = new ProcessConversionContext();
        context.leadsToConvert = leadsToConvert;
        context.indexToAccountIdMap = indexToAccountIdMap;

        // Process results and create opportunity products for successful conversions
        processConversionResultsAndCreateProducts(convertResults, context);
    }
    /* ======================== Lead Conversion to Existing Accounts ======================== */

    /**
     * @description Converts leads to existing matched accounts
     * @param leadsToAccountMap Map of leads to convert and their matched accounts
     * @return List of LeadConvert results with success/failure information
     */
    public static List<Database.LeadConvertResult> convertLeadsToExistingAccounts(Map<Lead, Account> leadsToAccountMap) {
        List<Database.LeadConvertResult> convertResults = new List<Database.LeadConvertResult>();

        if (leadsToAccountMap == null || leadsToAccountMap.isEmpty()) {
            return convertResults;
        }

        // Check CRUD permissions for lead conversion
        if (!Schema.SObjectType.Lead.isUpdateable()) {
            logDebug('User does not have permission to convert Lead records');
            return convertResults;
        }

        // Update existing accounts with lead data
        LeadConversionHelper.updateExistingAccountsWithLeadData(leadsToAccountMap);

        // Prepare all conversion data (categorization, opportunity creation, and build convert objects)
        LeadConversionHelper.LeadConversionData conversionData = LeadConversionHelper.prepareLeadConversionData(leadsToAccountMap);

        // Update Validation_Bypass__c to true before conversion to bypass validation rule
        List<Lead> leadsToConvert = new List<Lead>(leadsToAccountMap.keySet());
        LeadConversionHelper.updateValidationBypassForLeads(leadsToConvert);

        // Execute conversions and handle results
        convertResults = LeadConversionHelper.executeLeadConversions(conversionData);

        ProcessConversionContext context = new ProcessConversionContext();
        context.leadsToAccountMap = leadsToAccountMap;

        // Process conversion results and create opportunity products for successful conversions
        processConversionResultsAndCreateProducts(convertResults, context);

        return convertResults;
    }

    /* ======================== Opportunity Product Creation ======================== */

    /**
     * @description Processes conversion results and creates opportunity products for successful conversions
     * Maintains proper Lead-to-Opportunity mapping based on conversion results index
     * Also deletes accounts created for failed conversions (bulk conversion cleanup)
     * @param convertResults List of lead conversion results
     * @param context ProcessConversionContext containing leads, account maps, and index mapping
     */
    private static void processConversionResultsAndCreateProducts(List<Database.LeadConvertResult> convertResults, ProcessConversionContext context) {
        if (convertResults == null || convertResults.isEmpty()) {
            return;
        }

        ProcessConversionInput input = buildProcessConversionInput(context);
        ConversionResultsData resultsData = processConversionResults(convertResults, input);

        if (!resultsData.accountsToDelete.isEmpty()) {
            LeadConversionHelper.deleteAccountsByIds(resultsData.accountsToDelete);
        }

        if (!resultsData.opportunities.isEmpty() && !resultsData.leads.isEmpty()) {
            createOpportunityProducts(resultsData.opportunities, resultsData.leads);
        }
    }

    /**
     * @description Builds ProcessConversionInput from ProcessConversionContext
     * @param context ProcessConversionContext containing conversion context
     * @return ProcessConversionInput for processing conversion results
     */
    private static ProcessConversionInput buildProcessConversionInput(ProcessConversionContext context) {
        ProcessConversionInput input = new ProcessConversionInput();
        input.leadsToConvert = context.leadsToConvert;
        input.leadIdToLeadMap = buildLeadIdToLeadMap(context.leadsToAccountMap);
        input.indexToAccountIdMap = context.indexToAccountIdMap;
        return input;
    }

    /**
     * @description Data structure to hold processed conversion results
     */
    @TestVisible
    private class ConversionResultsData {
        List<Opportunity> opportunities;
        List<Lead> leads;
        List<Id> accountsToDelete;

        ConversionResultsData() {
            this.opportunities = new List<Opportunity>();
            this.leads = new List<Lead>();
            this.accountsToDelete = new List<Id>();
        }
    }

    /**
     * @description Data structure to hold conversion request data including created accounts
     */
    @TestVisible
    private class ConversionRequestData {
        public List<Database.LeadConvert> conversionRequests;
        public Map<Integer, Id> indexToAccountIdMap; // Maps conversion request index to Account ID

        ConversionRequestData() {
            this.conversionRequests = new List<Database.LeadConvert>();
            this.indexToAccountIdMap = new Map<Integer, Id>();
        }
    }

    /**
     * @description Data structure to hold context for processing conversion results
     */
    @TestVisible
    private class ProcessConversionContext {
        List<Lead> leadsToConvert;
        Map<Lead, Account> leadsToAccountMap;
        Map<Integer, Id> indexToAccountIdMap;

        ProcessConversionContext() {
            this.leadsToConvert = null;
            this.leadsToAccountMap = null;
            this.indexToAccountIdMap = null;
        }
    }

    /**
     * @description Data structure to hold input for processing conversion results
     */
    @TestVisible
    private class ProcessConversionInput {
        List<Lead> leadsToConvert;
        Map<Id, Lead> leadIdToLeadMap;
        Map<Integer, Id> indexToAccountIdMap;

        ProcessConversionInput() {
            this.leadsToConvert = null;
            this.leadIdToLeadMap = null;
            this.indexToAccountIdMap = null;
        }
    }

    /**
     * @description Data structure to hold conversion result context
     */
    @TestVisible
    private class ConversionResultContext {
        Database.LeadConvertResult result;
        Lead currentLead;
        Integer index;

        ConversionResultContext(Database.LeadConvertResult result, Lead currentLead, Integer index) {
            this.result = result;
            this.currentLead = currentLead;
            this.index = index;
        }
    }

    /**
     * @description Processes conversion results and collects opportunities, leads, and accounts to delete
     * @param convertResults List of lead conversion results
     * @param input ProcessConversionInput containing leads, lead map, and index mapping
     * @return ConversionResultsData containing processed results
     */
    @TestVisible
    private static ConversionResultsData processConversionResults(List<Database.LeadConvertResult> convertResults, ProcessConversionInput input) {
        ConversionResultsData resultsData = new ConversionResultsData();

        for (Integer i = 0; i < convertResults.size(); i++) {
            Database.LeadConvertResult result = convertResults.get(i);
            Lead currentLead = findCurrentLead(result, input, i);
            ConversionResultContext context = new ConversionResultContext(result, currentLead, i);

            if (!result.isSuccess()) {
                handleFailedConversion(context, input, resultsData);
            } else {
                handleSuccessfulConversion(result, currentLead, resultsData);
            }
        }

        return resultsData;
    }

    /**
     * @description Finds the current lead for a conversion result
     * @param result Lead conversion result
     * @param input ProcessConversionInput containing lead mappings
     * @param index Index of the conversion result
     * @return Lead record if found, null otherwise
     */
    private static Lead findCurrentLead(Database.LeadConvertResult result, ProcessConversionInput input, Integer index) {
        if (input.leadsToConvert != null && index < input.leadsToConvert.size()) {
            return input.leadsToConvert[index];
        }
        if (input.leadIdToLeadMap != null && result.getLeadId() != null) {
            return input.leadIdToLeadMap.get(result.getLeadId());
        }
        return null;
    }

    /**
     * @description Handles failed conversion by logging error and tracking account for deletion
     * @param context ConversionResultContext containing result, lead, and index
     * @param input ProcessConversionInput containing index mapping
     * @param resultsData ConversionResultsData to update
     */
    private static void handleFailedConversion(ConversionResultContext context, ProcessConversionInput input, ConversionResultsData resultsData) {
        if (context.currentLead != null) {
            logFailedConversion(context.result, context.currentLead);
        }

        Id accountIdToDelete = getAccountIdForDeletion(context, input);
        if (input.leadsToConvert != null && accountIdToDelete != null) {
            resultsData.accountsToDelete.add(accountIdToDelete);
        }
    }

    /**
     * @description Gets Account ID for deletion from result or index map
     * @param context ConversionResultContext containing result and index
     * @param input ProcessConversionInput containing index mapping
     * @return Account ID to delete, null if not found
     */
    private static Id getAccountIdForDeletion(ConversionResultContext context, ProcessConversionInput input) {
        if (context.result.getAccountId() != null) {
            return context.result.getAccountId();
        }
        if (input.indexToAccountIdMap != null && input.indexToAccountIdMap.containsKey(context.index)) {
            return input.indexToAccountIdMap.get(context.index);
        }
        return null;
    }

    /**
     * @description Handles successful conversion by adding opportunity and lead to results
     * @param result Successful conversion result
     * @param currentLead Lead record that was converted
     * @param resultsData ConversionResultsData to update
     */
    private static void handleSuccessfulConversion(Database.LeadConvertResult result, Lead currentLead, ConversionResultsData resultsData) {
        if (result.getOpportunityId() != null && currentLead != null) {
            resultsData.opportunities.add(new Opportunity(Id = result.getOpportunityId()));
            resultsData.leads.add(currentLead);
        }
    }

    /**
     * @description Builds a map of Lead ID to Lead from leadsToAccountMap
     * @param leadsToAccountMap Map of Lead to Account (can be null)
     * @return Map of Lead ID to Lead
     */
    @TestVisible
    private static Map<Id, Lead> buildLeadIdToLeadMap(Map<Lead, Account> leadsToAccountMap) {
        Map<Id, Lead> leadIdToLeadMap = new Map<Id, Lead>();
        if (leadsToAccountMap != null) {
            for (Lead lead : leadsToAccountMap.keySet()) {
                leadIdToLeadMap.put(lead.Id, lead);
            }
        }
        return leadIdToLeadMap;
    }
    /**
     * @description Creates opportunity products for successfully converted leads
     * Creates Map<OpportunityId, RecommendedProduct> for efficient product assignment
     * @param opportunities List of Opportunity records (with Id populated)
     * @param leads List of Lead records with recommended product information
     */
    private static void createOpportunityProducts(List<Opportunity> opportunities, List<Lead> leads) {
        if (opportunities == null || opportunities.isEmpty() || leads == null || leads.isEmpty()) {
            return;
        }

        try {
            // Create direct mapping of OpportunityId to Recommended Product
            Map<Id, String> opportunityToProductMap = new Map<Id, String>();

            // Build the mapping - assuming same index mapping from conversion results
            for (Integer i = 0; i < Math.min(opportunities.size(), leads.size()); i++) {
                if (String.isNotBlank(leads[i].Recommended_Product__c)) {
                    opportunityToProductMap.put(opportunities[i].Id, leads[i].Recommended_Product__c);
                }
            }

            if (!opportunityToProductMap.isEmpty()) {
                OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, opportunities);
            }
        } catch (Exception ex) {
            logError('Error creating opportunity products after lead conversion', leads, ex);
        }
    }

    /* ======================== Logging Methods ======================== */


    /**
     * @description Logs a failed lead conversion with error details.
     * @param result The failed LeadConvertResult
     * @param failedLead The Lead record that failed to convert
     */
    private static void logFailedConversion(Database.LeadConvertResult result, Lead failedLead) {
        String errorMsg = 'Failed to convert Lead';

        if (result.getErrors() != null && !result.getErrors().isEmpty()) {
            errorMsg += ': ' + result.getErrors()[0].getMessage();
        }

        logError(errorMsg, new List<SObject>{ failedLead }, null);
    }

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
     * @description Logs debug messages using Logger framework
     * @param message The debug message
     */
    @TestVisible
    private static void logDebug(String message) {
        Logger.debug(message);
        Logger.saveLog();
    }

}