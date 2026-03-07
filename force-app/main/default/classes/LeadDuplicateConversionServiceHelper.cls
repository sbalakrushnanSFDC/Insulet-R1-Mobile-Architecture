/**
 * @description : Helper class to reduce cyclomatic complexity in LeadDuplicateConversionService
 * @author      : Charchit Nirayanwal
 * @created Date: 5th Dec 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       5th Dec 2025        Charchit Nirayanwal     Initial Version(US - NGASIM-1083)
 * V1.0.1       15th Dec 2025       Bijayalaxmi Prusty      Modified(US - NGOMCT-824)
 * V1.0.1       16th Dec 2025       Priyansh Shukla         Modified(US - NGASIM-1163)
 * V1.0.2       21st Jan 2026       Bijayalaxmi Prusty      Updated(US - NGASIM-1885)
 * V1.0.3       22nd Jan 2026       Priyansh Shukla         Modified(US - NGOMCT-1749)
 * V1.0.4       2nd Feb 2026        Bijayalaxmi Prusty      Modified(US - NGASIM-1905)
 * V1.0.5       18th Feb 2026        Bijayalaxmi Prusty      Updated(US - NGOMCT-1961)
 */
public with sharing class LeadDuplicateConversionServiceHelper {

    /**
     * @description Wrapper class to hold categorized match lists based on match type and record type.
     *              This class organizes duplicate matching results into four distinct categories
     *              to simplify scenario evaluation and decision-making logic.
     *
     * Fields:
     * @property fullLeadMatches List of Lead records that are full matches (all criteria fields match)
     * @property partialLeadMatches List of Lead records that are partial matches (2+ criteria fields match)
     * @property fullAccountMatches List of Account records that are full matches (all criteria fields match)
     * @property partialAccountMatches List of Account records that are partial matches (2+ criteria fields match)
     *
     * Usage:
     *   - Used by separateMatches() to organize matching results
     *   - Passed to scenario evaluation methods to determine conversion eligibility
     *   - Helps reduce cyclomatic complexity by providing organized data structure
     *
     * @see separateMatches()
     * @see evaluateAndHandleScenarios()
     */
    public class SeparatedMatches {
        public List<LeadDuplicateMatchingService.MatchingCriteria> fullLeadMatches;
        public List<LeadDuplicateMatchingService.MatchingCriteria> partialLeadMatches;
        public List<LeadDuplicateMatchingService.MatchingCriteria> fullAccountMatches;
        public List<LeadDuplicateMatchingService.MatchingCriteria> partialAccountMatches;

        /**
         * @description Constructor that initializes all match lists as empty collections
         */
        public SeparatedMatches() {
            this.fullLeadMatches = new List<LeadDuplicateMatchingService.MatchingCriteria>();
            this.partialLeadMatches = new List<LeadDuplicateMatchingService.MatchingCriteria>();
            this.fullAccountMatches = new List<LeadDuplicateMatchingService.MatchingCriteria>();
            this.partialAccountMatches = new List<LeadDuplicateMatchingService.MatchingCriteria>();
        }
    }

    /**
     * @description Wrapper class that encapsulates all data needed for scenario evaluation and handling.
     *              This class follows the Parameter Object pattern to reduce excessive parameter lists
     *              and improve code maintainability by grouping related data.
     *
     * Fields:
     * @property currentLead The Lead record being evaluated for conversion eligibility
     * @property matches SeparatedMatches object containing all categorized duplicate match lists
     * @property conversionResult ConversionResult object to store the conversion decision and related data
     *
     * Scenarios Supported:
     *   - Scenario 1: Convert to existing Account (no Lead matches, full Account matches)
     *   - Scenario 2: Merge with existing Lead (full Lead matches, no Account matches)
     *   - Scenario 3: Partial matches with manual review completed
     *
     * Usage:
     *   - Created by processLeadConversionEligibility() in LeadDuplicateConversionService
     *   - Passed to evaluateAndHandleScenarios() for scenario determination
     *   - Passed to scenario handlers (handleScenario1/2/3) for conversion logic
     *
     * @see evaluateAndHandleScenarios()
     * @see LeadDuplicateConversionService.processLeadConversionEligibility()
     */
    public class ScenarioContext {
        public Lead currentLead;
        public SeparatedMatches matches;
        public LeadDuplicateConversionService.ConversionResult conversionResult;

        /**
         * @description Constructor that initializes all context properties
         * @param currentLead The Lead record being processed
         * @param matches SeparatedMatches containing categorized duplicate matches
         * @param conversionResult ConversionResult to store the conversion outcome
         */
        public ScenarioContext(Lead currentLead, SeparatedMatches matches, LeadDuplicateConversionService.ConversionResult conversionResult) {
            this.currentLead = currentLead;
            this.matches = matches;
            this.conversionResult = conversionResult;
        }
    }

    /**
     * @description Separates all matches into categorized lists
     * @param allMatches List of all matching criteria to separate
     * @return SeparatedMatches object containing categorized matches
     */
    public static SeparatedMatches separateMatches(List<LeadDuplicateMatchingService.MatchingCriteria> allMatches) {
        SeparatedMatches result = new SeparatedMatches();

        for (LeadDuplicateMatchingService.MatchingCriteria match : allMatches) {
            categorizeMatch(match, result);
        }

        return result;
    }

    /**
     * @description Categorizes a single match into the appropriate list
     * @param match MatchingCriteria to categorize
     * @param result SeparatedMatches object to add the match to
     */
    private static void categorizeMatch(LeadDuplicateMatchingService.MatchingCriteria match, SeparatedMatches result) {
        Boolean isFullMatch = LeadDuplicateMatchingService.isFullMatch(match);
        Integer matchCount = LeadDuplicateMatchingService.countMatchingFields(match);
        Boolean isPartialMatch = !isFullMatch && matchCount >= 2;

        if (match.recordType == ConstantsUtil.LEAD_OBJECT && isFullMatch) {
            result.fullLeadMatches.add(match);
        } else if (match.recordType == ConstantsUtil.LEAD_OBJECT && isPartialMatch) {
            result.partialLeadMatches.add(match);
        } else if (match.recordType == ConstantsUtil.ACCOUNT_OBJECT && isFullMatch) {
            result.fullAccountMatches.add(match);
        } else if (match.recordType == ConstantsUtil.ACCOUNT_OBJECT && isPartialMatch) {
            result.partialAccountMatches.add(match);
        }
    }

    /**
     * @description Evaluates and handles conversion scenarios
     * @param context ScenarioContext containing all necessary data
     */
    public static void evaluateAndHandleScenarios(ScenarioContext context) {
        if (isScenario1(context.matches)) {
            handleScenario1(context);
        } else if (isScenario2(context.matches)) {
            handleScenario2(context);
        } else if (isScenario3(context.matches, context.currentLead)) {
            handleScenario3(context);
        }
    }

    /**
     * @description Checks if matches represent Scenario 1
     * Scenario 1: No lead matches (full or partial) AND full account matches
     * @param matches SeparatedMatches object
     * @return Boolean indicating if this is Scenario 1
     */
    private static Boolean isScenario1(SeparatedMatches matches) {
        return matches.fullLeadMatches.isEmpty() &&
               matches.partialLeadMatches.isEmpty() &&
               !matches.fullAccountMatches.isEmpty();
    }

    /**
     * @description Handles Scenario 1 conversion logic
     * @param context ScenarioContext containing all necessary data
     */
    private static void handleScenario1(ScenarioContext context) {
        Account matchedAccount = (Account) context.matches.fullAccountMatches[0].record;
        context.conversionResult.leadsWithAccountMatches.put(context.currentLead, matchedAccount);
    }

    /**
     * @description Checks if matches represent Scenario 2
     * Scenario 2: Full lead matches AND no account matches (full or partial)
     * @param matches SeparatedMatches object
     * @return Boolean indicating if this is Scenario 2
     */
    private static Boolean isScenario2(SeparatedMatches matches) {
        return !matches.fullLeadMatches.isEmpty() &&
               matches.fullAccountMatches.isEmpty() &&
               matches.partialAccountMatches.isEmpty();
    }

    /**
     * @description Handles Scenario 2 conversion logic
     * @param context ScenarioContext containing all necessary data
     */
    private static void handleScenario2(ScenarioContext context) {
        context.conversionResult.leadsWithLeadMatches.add(context.currentLead);
        List<Id> matchedLeadIds = new List<Id>();
        for (LeadDuplicateMatchingService.MatchingCriteria match : context.matches.fullLeadMatches) {
            matchedLeadIds.add(match.recordId);
        }
        context.conversionResult.leadsWithMatchedLeadIds.put(context.currentLead, matchedLeadIds);
    }

    /**
     * @description Checks if matches represent Scenario 3
     * Scenario 3: Partial matches ONLY (no full matches to either Lead or Account) AND duplicate review completed
     * @param matches SeparatedMatches object
     * @param currentLead Lead record to check
     * @return Boolean indicating if this is Scenario 3
     */
    private static Boolean isScenario3(SeparatedMatches matches, Lead currentLead) {
        if (!hasNoFullMatches(matches)) {
            return false;
        }
        if (!hasPartialMatches(matches)) {
            return false;
        }
        return currentLead.Duplicate_Review_Completed__c == true;
    }

    /**
     * @description Checks if there are no full matches
     * @param matches SeparatedMatches object
     * @return Boolean indicating if there are no full matches
     */
    private static Boolean hasNoFullMatches(SeparatedMatches matches) {
        return matches.fullLeadMatches.isEmpty() && matches.fullAccountMatches.isEmpty();
    }

    /**
     * @description Checks if there are partial matches
     * @param matches SeparatedMatches object
     * @return Boolean indicating if partial matches exist
     */
    private static Boolean hasPartialMatches(SeparatedMatches matches) {
        return matches.partialLeadMatches.size() > 0 || matches.partialAccountMatches.size() > 0;
    }

    /**
     * @description Handles Scenario 3 conversion logic
     * @param context ScenarioContext containing all necessary data
     */
    private static void handleScenario3(ScenarioContext context) {
        if (context.currentLead.Full_Match_Patient_Account__c == null) {
            context.conversionResult.leadsWithLeadMatches.add(context.currentLead);
            return;
        }

        Account matchedAccount = getAccAccountById(
            context.currentLead.Full_Match_Patient_Account__c,
            context.matches.partialAccountMatches
        );
        if (matchedAccount != null) {
            context.conversionResult.leadsWithAccountMatches.put(context.currentLead, matchedAccount);
        }
    }

    /**
     * @description Finds and returns a specific Account from a MatchingCriteria list by its ID.
     *              If not found in the list, queries the database as a fallback.
     * @param accountId The ID of the account to find
     * @param matchingCriteriaList List of MatchingCriteria containing potential account matches
     * @return Account record if found in list or database, null if accountId is null
     */
    public static Account getAccAccountById(Id accountId, List<LeadDuplicateMatchingService.MatchingCriteria> matchingCriteriaList) {
        if (accountId == null) {
            return null;
        }

        // First, try to find the account in the provided list
        if (matchingCriteriaList != null && !matchingCriteriaList.isEmpty()) {
            for (LeadDuplicateMatchingService.MatchingCriteria criteria : matchingCriteriaList) {
                if (criteria.recordId == accountId && criteria.recordType == ConstantsUtil.ACCOUNT_OBJECT) {
                    return (Account) criteria.record;
                }
            }
        }

        // If not found in list, query the database
        return queryAccountById(accountId);
    }

    /**
     * @description Queries account from database by ID
     * @param accountId The ID of the account to query
     * @return Account record if found, null otherwise
     */
    private static Account queryAccountById(Id accountId) {
        List<Account> accounts = [
            SELECT
                Id,
                Name,
                Salutation,
                FirstName,
                MiddleName,
                LastName,
                Suffix,
                PersonEmail,
                Phone,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode,
                BillingCountry,
                Date_of_Birth__c,
                PersonLeadSource,
                Type_of_Diabetes__c,
                PersonGenderIdentity,
                Preferred_Language__c,
                Sensor_CGM_Continuous_Glucose_Monitor__c,
                Insurance_Type__c,
                Current_Therapy__c,
                PersonIndividualId,
                (
                    SELECT
                        Id,
                        StageName,
                        IsClosed,
                        IsWon,
                        Number_of_time_contacted__c,
                        Last_Contacted_Date__c,
                        Pricebook2Id,
                        Insurance_Name__c,
                        Insurance_Type__c
                    FROM Opportunities
                    WHERE RecordTypeId = :ConstantsUtil.OPPORTUNITY_NCS_RT
                    LIMIT 10
                )
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];

        return accounts.isEmpty() ? null : accounts[0];
    }

    /**
     * @description Builds error message from Database.Error list
     * @param errors List of Database.Error objects
     * @return Concatenated error message string
     */
    public static String buildErrorMessage(List<Database.Error> errors) {
        String errorMsg = '';
        for (Database.Error err : errors) {
            errorMsg += err.getMessage() + '; ';
        }
        return errorMsg;
    }

    /**
     * @description Processes conversion results, logs failures, and handles auto conversion failures
     * @param conversionResults List of conversion results to process
     * @param leadsWithAccountMatches Map of leads to accounts that were converted
     * @param requireCallbackTrue If false, indicates auto conversion - failed leads will be updated to New status
     */
    public static void processConversionResults(
        List<Database.LeadConvertResult> conversionResults,
        Map<Lead, Account> leadsWithAccountMatches,
        Boolean requireCallbackTrue
    ) {
        List<Id> failedLeadIds = new List<Id>();

        // Handle case where conversionResults is empty/null but we have leads that should have been converted
        // This happens when conversion fails before Database.convertLead() is called (e.g., account creation fails)
        if (conversionResults == null || conversionResults.isEmpty()) {
            // If this is auto conversion and we have leads that should have been converted, treat as failure
            if (!requireCallbackTrue && leadsWithAccountMatches != null && !leadsWithAccountMatches.isEmpty()) {
                for (Lead lead : leadsWithAccountMatches.keySet()) {
                    failedLeadIds.add(lead.Id);
                }
            }
        } else {
            // Collect failed lead IDs from conversion results
            failedLeadIds = collectFailedLeadIds(conversionResults, leadsWithAccountMatches, requireCallbackTrue);
            Logger.saveLog();
        }

        // Update failed leads to New status
        if (!requireCallbackTrue && !failedLeadIds.isEmpty()) {
            LeadService.updateFailedLeadsToNew(failedLeadIds);
        }
    }

    /**
     * @description Collects failed lead IDs and logs errors
     * @param conversionResults List of conversion results to process
     * @param leadsWithAccountMatches Map of leads to accounts that were converted
     * @param requireCallbackTrue If false, indicates auto conversion - failed leads will be collected
     * @return List of failed lead IDs
     */
    private static List<Id> collectFailedLeadIds(
        List<Database.LeadConvertResult> conversionResults,
        Map<Lead, Account> leadsWithAccountMatches,
        Boolean requireCallbackTrue
    ) {
        List<Id> failedLeadIds = new List<Id>();
        List<Lead> leadsList = new List<Lead>(leadsWithAccountMatches.keySet());

        for (Integer i = 0; i < conversionResults.size(); i++) {
            if (!conversionResults[i].isSuccess()) {
                String errorMessage = buildErrorMessage(conversionResults[i].getErrors());
                Logger.error('Failed to convert Lead at index ' + i + ' during duplicate conversion process. Errors: ' + errorMessage)
                    .addTag(ConstantsUtil.ASIM_TAG);
                if (!requireCallbackTrue && i < leadsList.size()) {
                    failedLeadIds.add(leadsList[i].Id);
                }
            }
        }

        return failedLeadIds;
    }

    /**
     * @description Updates failed leads to "Pending Review" status and assigns them to Practice_Provider_Lead queue
     *              This is used for auto conversion failures to route leads for manual review
     * @param leadIds List of Lead IDs that failed conversion
     */
    public static void updateFailedLeadsToPendingReview(List<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        Id queueId = findQueueByName(ConstantsUtil.PRACTICE_PROVIDER_LEAD_QUEUE);

        List<Lead> leadsToUpdate = buildLeadsForUpdate(leadIds, queueId);
        if (leadsToUpdate.isEmpty()) {
            return;
        }

        Database.update(leadsToUpdate, false, AccessLevel.USER_MODE);
    }

    /**
     * @description Builds list of leads to update with Pending Review status
     * Only includes leads that are NOT already converted
     * @param leadIds List of lead IDs to update
     * @param queueId Queue ID to assign (can be null)
     * @return List of Lead records ready for update
     */
    private static List<Lead> buildLeadsForUpdate(List<Id> leadIds, Id queueId) {
        // Query leads to check if they're already converted
        List<Lead> existingLeads = [
            SELECT Id, IsConverted, Status, OwnerId
            FROM Lead
            WHERE Id IN :leadIds
            WITH USER_MODE
        ];

        Map<Id, Lead> leadMap = new Map<Id, Lead>(existingLeads);

        List<Lead> leadsToUpdate = new List<Lead>();
        for (Id leadId : leadIds) {
            Lead leadToUpdate = buildSingleLeadForUpdate(leadId, leadMap.get(leadId), queueId);
            if (leadToUpdate != null) {
                leadsToUpdate.add(leadToUpdate);
            }
        }
        return leadsToUpdate;
    }

    /**
     * @description Builds a single lead for update if needed
     * @param leadId ID of the lead to update
     * @param existingLead Existing lead record from database (can be null)
     * @param queueId Queue ID to assign (can be null)
     * @return Lead record ready for update, or null if no update needed
     */
    private static Lead buildSingleLeadForUpdate(Id leadId, Lead existingLead, Id queueId) {
        if (existingLead == null || existingLead.IsConverted) {
            return null;
        }

        Boolean needsStatusUpdate = existingLead.Status != ConstantsUtil.LEAD_STATUS_PENDING_REVIEW;
        Boolean needsOwnerUpdate = queueId != null && existingLead.OwnerId != queueId;

        if (!needsStatusUpdate && !needsOwnerUpdate) {
            return null;
        }

        Lead leadToUpdate = new Lead(Id = leadId);
        if (needsStatusUpdate) {
            leadToUpdate.Status = ConstantsUtil.LEAD_STATUS_PENDING_REVIEW;
        }
        if (needsOwnerUpdate) {
            leadToUpdate.OwnerId = queueId;
        }
        return leadToUpdate;
    }

    /**
     * @description Finds a queue by its DeveloperName
     * @param queueDeveloperName Developer name of the queue
     * @return Queue ID if found, null otherwise
     */
    private static Id findQueueByName(String queueDeveloperName) {
        if (String.isBlank(queueDeveloperName)) {
            return null;
        }

        List<Group> queues = [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE DeveloperName = :queueDeveloperName AND Type = 'Queue'
            WITH USER_MODE
            LIMIT 1
        ];

        return queues.isEmpty() ? null : queues[0].Id;
    }
}