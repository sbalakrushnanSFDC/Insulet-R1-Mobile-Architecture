/**
 * @description Service class to handle Lead conversion logic based on duplicate matching results.
 * Processes leads for conversion eligibility and handles various conversion scenarios including
 * converting to existing accounts, creating new accounts, and managing duplicate leads.
 *
 * @author      Bijayalaxmi Prusty
 * @createdDate 26th Nov 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       26th Nov 2025       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1050)
 * V1.0.0       27th Nov 2025       Priyansh Shukla         Modified(US - NGASIM-1210)
 * V1.0.1       2nd Dec 2025        Bijayalaxmi Prusty      Modified(US - NGASIM-1080)
 * V1.0.0       2nd Dec 2025        Priyansh Shukla         Modified(US - NGASIM-1211)
 * V1.0.0       4th Dec 2025        Jatin Butta             Modified(US - NGASIM-1082)
 * V1.0.2       4th Dec 2025        Charchit Nirayanwal     Modified(US - NGASIM-1083)
 * V1.0.3       15th Dec 2025       Bijayalaxmi Prusty      Modified(US - NGOMCT-824)
 * V1.0.3       16th Dec 2025       Priyansh Shukla         Modified(US - NGASIM-1163)
 * V1.0.4       22nd Jan 2026       Priyansh Shukla         Modified(US - NGOMCT-1749)
 * V1.0.4       29th Jan 2026       Bijayalaxmi Prusty      Modified(US - NGASIM-1905)
 * V1.0.5       7th Feb 2026        Priyansh Shukla         Updated(US - NGASIM-1898)
 * V1.0.6       16th Feb 2026       Charchit Nirayanwal     Modified(US - NGASIM-2207)
 * V1.0.7       17th Feb 2026       Charchit Nirayanwal     Modified(US - NGASIM-2207)
 * V1.1.0       18th Feb 2026       Bijayalaxmi Prusty      Updated(US - NGOMCT-1961)
 * V1.1.1       24th Feb 2026       Charchit Nirayanwal     Modified(US - NGASIM-2517)
 */
public with sharing class LeadDuplicateConversionService {

    // Storage for duplicate rule criteria (cached to avoid SOQL queries in loops)
    private static List<LeadDuplicateMatchingService.DuplicateRuleCriteria> duplicateCriteria;

    /**
     * @description Enqueues LeadConversionPostProcessingQueueable with context data.
     *              Called after conversion completes to ensure context is available in async execution.
     * @param conversionResults List of lead conversion results
     * @param leadsWithAccountMatches Map of Lead to Account for converted leads
     */
    private static void enqueuePostProcessingQueueable(
        List<Database.LeadConvertResult> conversionResults,
        Map<Lead, Account> leadsWithAccountMatches
    ) {
        if (conversionResults == null || conversionResults.isEmpty() ||
            leadsWithAccountMatches == null || leadsWithAccountMatches.isEmpty()) {
            return;
        }

        // Extract lead IDs (queueable will query converted leads for fresh data)
        List<Id> convertedLeadIds = new List<Id>();
        for (Lead ld : leadsWithAccountMatches.keySet()) {
            convertedLeadIds.add(ld.Id);
        }
        
        // Build serializable mapping data list instead of passing non-serializable Database.LeadConvertResult
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList =
            LeadConversionEnqueueConsentMapping.buildMappingDataList(conversionResults, leadsWithAccountMatches);

        // Enqueue queueable with mappingDataList and leadsToAccountMap (both serializable)
        // Note: Map<Lead, Account> is serializable as Lead and Account are SObjects
        if (!System.isQueueable() && !Test.isRunningTest()) {
            System.enqueueJob(
                new LeadConversionPostProcessingQueueable(convertedLeadIds,ConstantsUtil.ASIM_TAG,mappingDataList,leadsWithAccountMatches)
            );
        }
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
     * @description Queries opportunities for an account and adds them to the result map
     * @param result The result map to add opportunity data to
     * @param accountId The ID of the account to query opportunities for
     */
    private static void queryAndAddOpportunities(Map<String, Object> result, Id accountId) {
        List<Opportunity> opps = [
            SELECT Id, Name
            FROM Opportunity
            WHERE AccountId = :accountId
            AND IsClosed = false
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ];

        if (!opps.isEmpty()) {
            // Return the first opportunity ID for direct link
            result.put('opportunityId', opps[0].Id);
            result.put('opportunityName', opps[0].Name);

            // Return all opportunities for "View All" functionality
            List<Map<String, Object>> oppList = new List<Map<String, Object>>();
            for (Opportunity opp : opps) {
                Map<String, Object> oppData = new Map<String, Object>();
                oppData.put('id', opp.Id);
                oppData.put('name', opp.Name);
                oppList.add(oppData);
            }
            result.put('opportunities', oppList);
            result.put('opportunityCount', opps.size());
        }
    }

    /**
     * @description Result wrapper class containing the conversion-eligible leads
     */
    public class ConversionResult {
        public Map<Lead, Account> leadsWithAccountMatches; // Leads with no lead matches but full account matches
        public List<Lead> leadsWithLeadMatches; // Leads with no account matches but full lead matches OR partial matches ONLY (no full matches to either) AND duplicate review completed, that need new account creation (Scenario 2 & 3)
        public List<Lead> leadsWithNoMatches; // Leads with no matches to Lead or Account (Scenario 4)
        public Map<Lead, List<Id>> leadsWithMatchedLeadIds; // Map of leads to their matched lead IDs for duplicate closure (Scenario 2 only)

        /**
         * @description Constructor to initialize ConversionResult with empty collections
         */
        public ConversionResult() {
            this.leadsWithAccountMatches = new Map<Lead, Account>();
            this.leadsWithLeadMatches = new List<Lead>();
            this.leadsWithNoMatches = new List<Lead>();
            this.leadsWithMatchedLeadIds = new Map<Lead, List<Id>>();
        }
    }

    /**
     * @description Processing context wrapper to comply with 3-parameter method limit
     */
    public class ProcessingContext {
        public List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria;
        public ConversionResult result;

        /**
         * @description Constructor to initialize ProcessingContext with duplicate criteria and conversion result
         * @param criteria List of duplicate rule criteria for processing
         * @param result ConversionResult object to store processing results
         */
        public ProcessingContext(List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria, ConversionResult result) {
            this.criteria = criteria;
            this.result = result;
        }
    }

    /**
     * @description Post-conversion context wrapper to comply with 3-parameter method limit
     */
    private class PostConversionContext {
        public ConversionResult result;
        public Boolean requireCallbackTrue;
        public List<Lead> originalLeads;

        /**
         * @description Constructor to initialize PostConversionContext
         * @param result ConversionResult containing matched lead information
         * @param requireCallbackTrue If false, indicates auto conversion - failed leads will be updated to Pending Review
         * @param originalLeads Original list of leads that were converted
         */
        public PostConversionContext(ConversionResult result, Boolean requireCallbackTrue, List<Lead> originalLeads) {
            this.result = result;
            this.requireCallbackTrue = requireCallbackTrue;
            this.originalLeads = originalLeads;
        }
    }

    /**
     * @description Processes lead conversion and retrieves account information
     * @param convertedLeadCheck Lead record queried after conversion attempt (IsConverted, ConvertedAccountId)
     * @param conversionResult Result from processLeadsForConversion
     * @return Map with account information or null if conversion failed
     */
    private static Map<String, Object> processLeadConversionAndGetAccount(Lead convertedLeadCheck, ConversionResult conversionResult) {
        Map<String, Object> accountInfo = new Map<String, Object>();

        if (convertedLeadCheck == null || !convertedLeadCheck.IsConverted) {
            return null;
        }

        // Lead was converted, get account info
        Id accountId = null;

        // Scenario 1: Convert to existing account (no lead matches + full account matches)
        if (conversionResult != null && !conversionResult.leadsWithAccountMatches.isEmpty()) {
            Account matchedAccount = conversionResult.leadsWithAccountMatches.values()[0];
            accountId = matchedAccount.Id;
            accountInfo.put('accountId', accountId);
            accountInfo.put('accountName', matchedAccount.Name);
        }
        // Scenarios 2, 3 & 4: Create new account (get from converted lead)
        else if (convertedLeadCheck.ConvertedAccountId != null) {
            accountId = convertedLeadCheck.ConvertedAccountId;
            Account newAccount = [
                SELECT Id, Name
                FROM Account
                WHERE Id = :accountId
                WITH USER_MODE
                LIMIT 1
            ];
            accountInfo.put('accountId', accountId);
            accountInfo.put('accountName', newAccount.Name);
        }

        return accountInfo;
    }

    /**
     * @description LWC-callable wrapper that processes a single lead for conversion
     * Supports four scenarios:
     * 1. No lead matches + Full account matches → Convert to existing account
     * 2. Full lead matches + No account matches → Create new account
     * 3. Partial matches ONLY + Duplicate Review Complete → Create new account (LWC ONLY - this is the ONLY path for Scenario 3)
     * 4. No lead matches + No account matches → Create new account (LWC ONLY)
     * * Requires: Request_a_Call_Back__c = true, Provider_Practice_Affiliation__c populated
     * @param leadId ID of the lead to convert
     * @return Map with conversion result
     */
    @AuraEnabled
    public static Map<String, Object> processLeadForConversionFromLWC(Id leadId) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Query the lead with all necessary fields
            Lead leadToProcess = [
                SELECT Id, FirstName, MiddleName, LastName, Email, Phone, Date_of_Birth__c,
                       Request_a_Call_Back__c, Provider_Practice_Affiliation__c, Duplicate_Review_Completed__c,
                       RecordTypeId, Status, IsConverted, LeadSource,
                       Matching_Status__c, CreatedDate, Street, City, State, PostalCode, Country, Type_of_Diabetes__c, GenderIdentity, Preferred_Language__c,
                       Salutation, Suffix, Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c, Insurance_Company_Name__c, Current_Therapy__c,
                       Full_Match_Patient_Account__c, Recommended_Product__c, IndividualId
                FROM Lead
                WHERE Id = :leadId
                WITH USER_MODE
                LIMIT 1
            ];

            // Collect matching data for this lead
            LeadDuplicateMatchingService.MatchDataContainer matchData = LeadDuplicateMatchingService.collectMatchingData(new List<Lead>{leadToProcess});

            // Process the lead with requireCallbackTrue = true (LWC requirement)
            ConversionResult conversionResult = processLeadsForConversion(
                new List<Lead>{leadToProcess},
                matchData,
                true  // LWC requires Request_a_Call_Back__c = true
            );

            Lead convertedLeadCheck = [
                SELECT Id, IsConverted, ConvertedAccountId
                FROM Lead
                WHERE Id = :leadId
                WITH USER_MODE
                LIMIT 1
            ];

            // Process conversion and get account information
            Map<String, Object> accountInfo = processLeadConversionAndGetAccount(convertedLeadCheck, conversionResult);

            if (accountInfo == null) {
                String errorMsg = Label.PLC_Failed;

                result.put('success', false);
                result.put('error', errorMsg);
                return result;
            }

            // Add account information to result
            result.putAll(accountInfo);

            // Set conversion status and handle opportunities
            result.put('success', true);
            result.put('converted', true);
            queryAndAddOpportunities(result, (Id)accountInfo.get('accountId'));

        } catch (Exception ex) {
            result.put('success', false);
            result.put('error', ex.getMessage());
            logError('Error processing lead for conversion from LWC: ' + ex.getMessage(), new List<SObject>(), ex);
        }

        return result;
    }

    /**
     * @description Backward-compatible overload - uses default validation (Request_a_Call_Back__c = false)
     * @param leadsToProcess List of leads to evaluate for conversion
     * @param matchData Container with potential matching data
     * @return ConversionResult containing eligible leads categorized by match type
     */
    public static ConversionResult processLeadsForConversion(List<Lead> leadsToProcess, LeadDuplicateMatchingService.MatchDataContainer matchData) {
        return processLeadsForConversion(leadsToProcess, matchData, false);
    }

    /**
     * @description Processes leads for conversion eligibility based on duplicate matching status
     * @param leadsToProcess List of leads to evaluate for conversion
     * @param matchData Container with potential matching data
     * @param requireCallbackTrue If true, requires Request_a_Call_Back__c = true; if false, requires false
     * @return ConversionResult containing eligible leads categorized by match type
     */
    public static ConversionResult processLeadsForConversion(List<Lead> leadsToProcess, LeadDuplicateMatchingService.MatchDataContainer matchData, Boolean requireCallbackTrue) {
        ConversionResult result = new ConversionResult();

        try {
            if (leadsToProcess == null || leadsToProcess.isEmpty()) {
                return result;
            }

            // First validate leads meet basic conversion criteria
            List<Lead> validatedLeads = validateLeadsForConversion(leadsToProcess, requireCallbackTrue);

            if (validatedLeads.isEmpty()) {
                return result;
            }

            // Get criteria once for all leads (cached to avoid SOQL in loop)
            List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria = getDuplicateCriteria();

            // Create processing context to comply with 3-parameter limit
            ProcessingContext context = new ProcessingContext(criteria, result);

            // Process each validated lead to determine conversion eligibility
            for (Lead currentLead : validatedLeads) {
                processLeadConversionEligibility(currentLead, matchData, context);
            }

            // V1.0.7
            // Enrich matched accounts with Opportunities (queried separately for performance —
            // the broad Account matching query runs without the expensive Opportunities subquery)
            if (!result.leadsWithAccountMatches.isEmpty()) {
                LeadDuplicateMatchingServiceHelper.enrichAccountsWithOpportunities(result.leadsWithAccountMatches);
            }

            // Convert eligible leads to their matched accounts (Scenario 1)
            if (!result.leadsWithAccountMatches.isEmpty()) {
                List<Database.LeadConvertResult> conversionResults =
                    PatientLeadConversionService.convertLeadsToExistingAccounts(result.leadsWithAccountMatches);

                // Process conversion results and log any failures
                // processConversionResults will handle null/empty conversionResults internally
                LeadDuplicateConversionServiceHelper.processConversionResults(
                    conversionResults,
                    result.leadsWithAccountMatches,
                    requireCallbackTrue
                );

                // Enqueue queueable directly with context after conversion completes
                // We have all required data here: conversionResults and leadsWithAccountMatches
                enqueuePostProcessingQueueable(conversionResults, result.leadsWithAccountMatches);

            }
            // Convert leads that need new accounts (Scenario 2, 3 & 4)
            if (!result.leadsWithLeadMatches.isEmpty() || !result.leadsWithNoMatches.isEmpty()) {
                processLeadsWithLeadMatches(result, requireCallbackTrue);
            }

        } catch (Exception ex) {logError('Failed to process leads for conversion. Error: ' + ex.getMessage(),(List<SObject>)leadsToProcess, ex);
        }

        return result;
    }

    /**
     * @description Validates leads meet basic conversion criteria
     * @param leadsToProcess List of leads to validate
     * @param requireCallbackTrue If true, requires callback = true; if false, requires callback = false
     * @return List of leads that meet validation criteria
     */
    private static List<Lead> validateLeadsForConversion(List<Lead> leadsToProcess, Boolean requireCallbackTrue) {
        List<Lead> validatedLeads = new List<Lead>();

        for (Lead currentLead : leadsToProcess) {
            if (meetsConversionValidation(currentLead, requireCallbackTrue)) {
                validatedLeads.add(currentLead);
            }
        }

        return validatedLeads;
    }

    /**
     * @description Validates if a lead meets conversion criteria
     * @param currentLead Lead to validate
     * @param requireCallbackTrue If true, requires callback = true; if false, requires callback = false
     * @return Boolean indicating if lead meets validation criteria
     */
    private static Boolean meetsConversionValidation(Lead currentLead, Boolean requireCallbackTrue) {
        try {
            Boolean requestCallbackValid = isRequestCallbackValid(currentLead, requireCallbackTrue);
            Boolean providerAffiliationValid = isProviderAffiliationValid(currentLead);

            return requestCallbackValid && providerAffiliationValid;

        } catch (Exception ex) {
            logError('Error during lead conversion validation: ' + ex.getMessage(),
                    new List<SObject>{currentLead}, ex);
            return false;
        }
    }

    /**
     * @description Validates if the lead's request callback field meets conversion criteria
     * @param currentLead Lead to validate
     * @param requireCallbackTrue If true, requires callback = true; if false/null, requires callback = false
     * @return Boolean indicating if Request_a_Call_Back__c meets the requirement
     */
    public static Boolean isRequestCallbackValid(Lead currentLead, Boolean requireCallbackTrue) {
        Boolean expectedValue = (requireCallbackTrue == true) ? true : false;
        return (currentLead.Request_a_Call_Back__c == expectedValue);
    }

    /**
     * @description Validates if the lead has a provider practice affiliation
     * @param currentLead Lead to validate
     * @return Boolean indicating if Provider_Practice_Affiliation__c is not null
     */
    public static Boolean isProviderAffiliationValid(Lead currentLead) {
        return (currentLead.Provider_Practice_Affiliation__c != null);
    }

    /**
     * @description Processes a single lead to determine conversion eligibility based on match results
     * Supports four conversion scenarios:
     * 1. No lead matches + Full account matches → Convert to existing account (Trigger & LWC)
     * 2. Full lead matches + No account matches → Create new account (Trigger & LWC)
     * 3. Partial matches ONLY (no full matches to either) + Duplicate review complete → Create new account (LWC ONLY)
     * 4. No lead matches + No account matches → Create new account (LWC ONLY)
     * @param currentLead Lead to process
     * @param matchData Container with potential matching data
     * @param context Processing context containing criteria and result
     */
    private static void processLeadConversionEligibility(Lead currentLead, LeadDuplicateMatchingService.MatchDataContainer matchData, ProcessingContext context) {
        // Find all matches for this lead
        List<LeadDuplicateMatchingService.MatchingCriteria> allMatches = findMatchingRecordsFromCollection(currentLead, matchData, context.criteria);

        // Scenario 4: No matches to Lead or Account → Create new account
        if (allMatches.isEmpty()) {
            context.result.leadsWithNoMatches.add(currentLead);
            return;
        }

        // Separate matches into categories using helper
        LeadDuplicateConversionServiceHelper.SeparatedMatches separatedMatches =
            LeadDuplicateConversionServiceHelper.separateMatches(allMatches);

        // Check if matches qualify as Full or Partial
        Boolean hasFullLeadMatch = (separatedMatches.fullLeadMatches != null && !separatedMatches.fullLeadMatches.isEmpty());
        Boolean hasPartialLeadMatch = (separatedMatches.partialLeadMatches != null && !separatedMatches.partialLeadMatches.isEmpty());
        Boolean hasFullAccountMatch = (separatedMatches.fullAccountMatches != null && !separatedMatches.fullAccountMatches.isEmpty());
        Boolean hasPartialAccountMatch = (separatedMatches.partialAccountMatches != null && !separatedMatches.partialAccountMatches.isEmpty());

        // If no Full or Partial matches, these should be filtered out (Scenario 4)
        if (!hasFullLeadMatch && !hasPartialLeadMatch && !hasFullAccountMatch && !hasPartialAccountMatch) {
            context.result.leadsWithNoMatches.add(currentLead); return;
        }

        // Create scenario context and evaluate
        LeadDuplicateConversionServiceHelper.ScenarioContext scenarioContext =
            new LeadDuplicateConversionServiceHelper.ScenarioContext(currentLead, separatedMatches, context.result);

        LeadDuplicateConversionServiceHelper.evaluateAndHandleScenarios(scenarioContext);
    }

    /**
     * @description Finds matching records using collected data (similar to LeadDuplicateMatchingService method)
     * @param currentLead Lead to find matches for
     * @param matchData Collected matching data
     * @param criteria Duplicate rule criteria (passed to avoid SOQL in loop)
     * @return List of matching criteria
     */
    private static List<LeadDuplicateMatchingService.MatchingCriteria> findMatchingRecordsFromCollection(Lead currentLead, LeadDuplicateMatchingService.MatchDataContainer matchData, List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria) {
        List<LeadDuplicateMatchingService.MatchingCriteria> matches = new List<LeadDuplicateMatchingService.MatchingCriteria>();

        // Find Lead matches from collected data
        List<LeadDuplicateMatchingService.MatchingCriteria> leadMatches = LeadDuplicateMatchingServiceHelper.findLeadMatchesFromCollection(currentLead, matchData, criteria);
        matches.addAll(leadMatches);

        // Find Account matches from collected data
        List<LeadDuplicateMatchingService.MatchingCriteria> accountMatches = LeadDuplicateMatchingServiceHelper.findAccountMatchesFromCollection(currentLead, matchData, criteria);
        matches.addAll(accountMatches);

        return matches;
    }

    /**
     * @description Gets duplicate criteria with caching (using same logic as LeadDuplicateMatchingService)
     * Uses static caching to avoid SOQL queries in loops
     * @return List of duplicate rule criteria
     */
    private static List<LeadDuplicateMatchingService.DuplicateRuleCriteria> getDuplicateCriteria() {
        if (duplicateCriteria == null) {
            duplicateCriteria = new List<LeadDuplicateMatchingService.DuplicateRuleCriteria>();
            List<Duplicate_Rules_Criteria__mdt> metadata = Database.query(
                'SELECT Source_Field__c, Source_Object__c, Target_Field__c, Target_Object__c ' +
                'FROM Duplicate_Rules_Criteria__mdt ' +
                'WHERE Source_Object__c = \'' + String.escapeSingleQuotes(ConstantsUtil.LEAD_OBJECT) + '\' ' +
                'ORDER BY Source_Field__c',
                AccessLevel.USER_MODE
            );

            for (Duplicate_Rules_Criteria__mdt record : metadata) {
                duplicateCriteria.add(new LeadDuplicateMatchingService.DuplicateRuleCriteria(record));
            }
        }

        return duplicateCriteria;
    }

    /**
     * @description Processes leads that need new account creation (Scenario 2, 3 & 4)
     * Scenario 2: Full lead matches + no account matches → Creates new account and closes matched duplicate leads (Trigger & LWC)
     * Scenario 3: Partial matches only + duplicate review complete → Creates new account (LWC ONLY, no duplicates to close)
     * Scenario 4: No lead matches + no account matches → Creates new account (LWC ONLY, no duplicates to close)
     * @param result ConversionResult containing leads that need new accounts
     * @param requireCallbackTrue If false, indicates auto conversion - failed leads will be updated to Pending Review
     */
    @TestVisible
    private static void processLeadsWithLeadMatches(ConversionResult result, Boolean requireCallbackTrue) {
        try {
            // Determine which list has leads (only one will have data for manual conversion)
            List<Lead> leadsToConvert = result.leadsWithLeadMatches.isEmpty()
                ? result.leadsWithNoMatches
                : result.leadsWithLeadMatches;

            if (leadsToConvert.isEmpty()) {return;}

            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on for processLeadsWithLeadMatches');
            }
            
            // Convert eligible leads to new accounts using automatic conversion
            List<Database.LeadConvertResult> conversionResults =
                PatientLeadConversionService.processAutomaticLeadConversionWithResults(leadsToConvert);

            // Process post-conversion activities (logs failures, creates CCRs, closes duplicates if any)
            // This will also enqueue the queueable with context after conversion completes
            PostConversionContext postContext = new PostConversionContext(result, requireCallbackTrue, leadsToConvert);
            processPostConversionActivities(conversionResults, postContext);

        } catch (Exception ex) {
            List<SObject> leadSObjects = new List<SObject>();
            leadSObjects.addAll(result.leadsWithLeadMatches);
            leadSObjects.addAll(result.leadsWithNoMatches);
            logError('Failed to process leads with lead matches. Error: ' + ex.getMessage(), leadSObjects, ex);
        }
    }

    /**
     * @description Processes post-conversion activities including logging failures, creating CCRs, and closing duplicates
     * @param conversionResults List of conversion results from lead conversion
     * @param context PostConversionContext containing result, requireCallbackTrue, and originalLeads
     */
    @TestVisible
    private static void processPostConversionActivities(
        List<Database.LeadConvertResult> conversionResults,
        PostConversionContext context
    ) {
        // Build map of leads to accounts for processConversionResults (similar to Scenario 1)
        // IMPORTANT: Include ALL leads (even failed ones) so processConversionResults can map failures correctly
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>();

        // Build map from conversion results
        // If conversionResults is empty, all leads will be mapped to null
        for (Integer i = 0; i < context.originalLeads.size(); i++) {
            Lead currentLead = context.originalLeads[i];
            // Check if conversionResults exists, has data at index i, and conversion was successful
            if (conversionResults != null && !conversionResults.isEmpty() &&
                i < conversionResults.size() && conversionResults[i].isSuccess() &&
                conversionResults[i].getAccountId() != null) {
                // Create a dummy account object with just the ID for the map
                Account acc = new Account(Id = conversionResults[i].getAccountId());
                leadsToAccountMap.put(currentLead, acc);
            } else {
                // For failed conversions or empty conversionResults, add lead with null account
                leadsToAccountMap.put(currentLead, null);
            }
        }

        // Process conversion results and handle auto conversion failures (same as Scenario 1)
        // processConversionResults will handle empty conversionResults case internally
        LeadDuplicateConversionServiceHelper.processConversionResults(
            conversionResults,
            leadsToAccountMap,
            context.requireCallbackTrue
        );

        // Only create CCRs and MemberPlans if we have successful conversion results
        if (conversionResults != null && !conversionResults.isEmpty()) {
            // Determine which list has leads (only one will have data for manual conversion)
            List<Lead> convertedLeads = context.result.leadsWithLeadMatches.isEmpty()
                ? context.result.leadsWithNoMatches
                : context.result.leadsWithLeadMatches;

            // Create mapping of leads to their newly created accounts for CCR creation
            Map<Lead, Account> convertedLeadsToAccountMap = buildConvertedLeadsToAccountMap(
                conversionResults, convertedLeads);

            // Enqueue queueable directly with context after conversion completes
            // This ensures context (with conversion results) is available in async execution
            enqueuePostProcessingQueueable(conversionResults, convertedLeadsToAccountMap);

            // Close matched duplicate leads after successful conversion (only for Scenario 2)
        // Scenario 2: Has Full Match to Lead → closes duplicates (leadsWithMatchedLeadIds populated)
        // Scenario 3: Has Partial Match ONLY → does NOT close duplicates (leadsWithMatchedLeadIds empty)
        // Scenario 4: No matches → does NOT close duplicates (leadsWithNoMatches, not in leadsWithLeadMatches)
        // Only close duplicates if there are matched lead IDs (Scenario 2 only)
        if (!context.result.leadsWithMatchedLeadIds.isEmpty()) {
            closeDuplicateLeadsAfterConversion(context.result);
        }
        }
    }

    /**
     * @description Closes duplicate leads after successful conversion
     * @param result ConversionResult containing matched lead information
     */
    @TestVisible
    private static void closeDuplicateLeadsAfterConversion(ConversionResult result) {
        List<Id> allDuplicateLeadIds = new List<Id>();
        for (Lead currentLead : result.leadsWithLeadMatches) {
            List<Id> matchedLeadIds = result.leadsWithMatchedLeadIds.get(currentLead);
            if (matchedLeadIds != null && !matchedLeadIds.isEmpty()) {
                allDuplicateLeadIds.addAll(matchedLeadIds);
            }
        }

        // Close duplicate leads if any were found
        if (!allDuplicateLeadIds.isEmpty()) {
            LeadService.closeLeadsAsDuplicate(allDuplicateLeadIds);
        }
    }

    /**
     * @description Builds a map of converted leads to their newly created accounts
     * @param conversionResults List of lead conversion results
     * @param originalLeads List of original leads that were converted
     * @return Map of Lead to Account for successful conversions
     */
    @TestVisible
    private static Map<Lead, Account> buildConvertedLeadsToAccountMap(List<Database.LeadConvertResult> conversionResults, List<Lead> originalLeads) {
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>();

        if (conversionResults == null || originalLeads == null ||
            conversionResults.size() != originalLeads.size()) {
            return leadsToAccountMap;
        }

        // Collect account IDs from successful conversions
        Set<Id> accountIds = new Set<Id>();
        Map<Id, Lead> accountIdToLeadMap = new Map<Id, Lead>();

        for (Integer i = 0; i < conversionResults.size(); i++) {
            Database.LeadConvertResult result = conversionResults[i];
            Lead originalLead = originalLeads[i];

            if (result.isSuccess() && result.getAccountId() != null) {
                accountIds.add(result.getAccountId());
                accountIdToLeadMap.put(result.getAccountId(), originalLead);
            }
        }

        // Query the newly created accounts if any exist
        if (!accountIds.isEmpty()) {
            try {
                Map<Id, Account> accountMap = new Map<Id, Account>([
                    SELECT Id, Name, FirstName, LastName, PersonEmail, Phone,
                           BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                           Date_of_Birth__c, PersonLeadSource, Type_of_Diabetes__c, PersonGenderIdentity,
                           Preferred_Language__c, Sensor_CGM_Continuous_Glucose_Monitor__c,
                           Insurance_Type__c, Current_Therapy__c, PersonIndividualId
                    FROM Account
                    WHERE Id IN :accountIds
                    WITH USER_MODE
                ]);

                // Build the mapping
                for (Id accountId : accountIds) {
                    if (accountMap.containsKey(accountId) && accountIdToLeadMap.containsKey(accountId)) {
                        leadsToAccountMap.put(accountIdToLeadMap.get(accountId), accountMap.get(accountId));
                    }
                }
            } catch (Exception ex) { logError('Failed to query newly created accounts for CCR creation. Error: ' + ex.getMessage(), new List<SObject>(), ex);}
        }

        return leadsToAccountMap;
    }

    /**
    * @description Exception class for LeadDuplicateConversionService
    */
    public class MyCustomException extends Exception {}

}