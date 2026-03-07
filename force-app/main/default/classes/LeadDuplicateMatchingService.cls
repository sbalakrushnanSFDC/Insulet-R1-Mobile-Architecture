/**
 * Service class to handle Lead duplicate matching logic.
 *
 * @author      : Bijayalaxmi Prusty
 * @created Date: 29th Oct 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       29th Oct 2025       Bijayalaxmi Prusty      Initial Version(US - NGASIM-219)
 * V1.0.1       13th Nov 2025       Bijayalaxmi Prusty      Updated(US - NGASIM-1065)
 * V1.0.2       26th Nov 2025       Bijayalaxmi Prusty      Updated(US - NGASIM-1050)
 * V1.0.0       2nd Dec 2025        Priyansh Shukla         Modified(US - NGASIM-1211)
 * V2.0.1       21st Jan 2026       Bijayalaxmi Prusty      Updated(US - NGASIM-1885)
 * V2.0.2       16th Feb 2026       Charchit Nirayanwal     Modified(US - NGASIM-2207)
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.CognitiveComplexity')
public with sharing class LeadDuplicateMatchingService {

    // Storage for duplicate rule criteria
    private static List<DuplicateRuleCriteria> duplicateCriteria;

    /**
     * @description Test hook to inject match data for testing purposes
     * When set, collectMatchingData will return this data instead of querying
     */
    @TestVisible
    private static MatchDataContainer testMatchData = null;

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
    private static void logDebug(String message) {
        Logger.debug(message);
        Logger.saveLog();
    }

    /**
     * @description Wrapper class for duplicate rule criteria
     */
    public class DuplicateRuleCriteria {
        public String sourceField;
        public String targetField;
        public String sourceObject;
        public String targetObject;
        public Boolean requiredForFullMatch;
        public Set<String> excludedSources;

        /**
         * @description Constructor to initialize duplicate rule criteria from custom metadata
         * @param metadata The custom metadata record containing duplicate rule configuration
         */
        public DuplicateRuleCriteria(Duplicate_Rules_Criteria__mdt metadata) {
            this.sourceField = metadata.Source_Field__c;
            this.targetField = metadata.Target_Field__c;
            this.sourceObject = metadata.Source_Object__c;
            this.targetObject = metadata.Target_Object__c;
            this.requiredForFullMatch = getRequiredForFullMatch(metadata.Source_Field__c);
            this.excludedSources = getExcludedSources(metadata.Source_Field__c);
        }
         /**
         * @description Determines if a source field is required for a full match
         * @param sourceField The name of the source field to check
         * @return Boolean indicating if the field is required for full match
         */
         private Boolean getRequiredForFullMatch(String sourceField) {
            // Required fields for full match (must have LastName and Date of Birth)
            Set<String> requiredFields = new Set<String>{ConstantsUtil.LEAD_LAST_NAME, ConstantsUtil.LEAD_DATE_OF_BIRTH};
            return requiredFields.contains(sourceField);
        }

        /**
         * @description Gets the excluded LeadSource values for a given source field
         * @param sourceField The name of the source field to get exclusions for
         * @return Set of LeadSource values to exclude from matching
         */
        private Set<String> getExcludedSources(String sourceField) {
            // Email field exclusion when LeadSource = 'ASPN'
            if (sourceField == ConstantsUtil.LEAD_EMAIL) {
                return new Set<String>{ConstantsUtil.LEAD_SOURCE_ASPN};
            }
            return new Set<String>();
        }
    }

    /**
     * @description Loads duplicate rule criteria from custom metadata for a specific source object
     * @return List of duplicate rule criteria for the source object
     */
    private static List<DuplicateRuleCriteria> getDuplicateCriteria() {
        if (duplicateCriteria == null) {
            duplicateCriteria = new List<DuplicateRuleCriteria>();
            List<Duplicate_Rules_Criteria__mdt> metadata = Database.query(
                'SELECT Source_Field__c, Source_Object__c, Target_Field__c, Target_Object__c ' +
                'FROM Duplicate_Rules_Criteria__mdt ' +
                'WHERE Source_Object__c = \'' + String.escapeSingleQuotes(ConstantsUtil.LEAD_OBJECT) + '\' ' +
                'ORDER BY Source_Field__c',
                AccessLevel.USER_MODE
            );

            for (Duplicate_Rules_Criteria__mdt record : metadata) {
                duplicateCriteria.add(new DuplicateRuleCriteria(record));
            }
        }
        return duplicateCriteria;
    }

    /**
     * @description Processes Lead records to determine duplicate matching status
     * Only processes records when duplicate-matching relevant fields have changed (for updates)
     * @param newLeads List of new Lead records
     * @param oldLeadsMap Map of old Lead records (for updates)
     */
    public static void processLeadDuplicateMatching(List<Lead> newLeads, Map<Id, Lead> oldLeadsMap) {
        try {
            if (newLeads == null || newLeads.isEmpty()) {
                return;
            }

            List<Lead> leadsToProcess = filterLeadsForProcessing(newLeads, oldLeadsMap);

            if (leadsToProcess.isEmpty()) {
                return;
            }

            MatchDataContainer matchData = collectMatchingData(leadsToProcess);

            for (Lead currentLead : leadsToProcess) {
                String matchingStatus = determineMatchingStatusFromCollection(currentLead, matchData);
                currentLead.put('Matching_Status__c', matchingStatus);
            }

            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on');
            }

        } catch (Exception ex) {
            List<SObject> leadSObjects = new List<SObject>();
            leadSObjects.addAll(newLeads);
            for (Integer i = 0; i < leadSObjects.size(); i++) {
                logError('Failed to process Lead duplicate matching at index ' + i + '. Errors: ' + ex.getMessage(),
                            new List<SObject>{leadSObjects[i]}, ex);
            }
        }
    }

    /**
     * @description Processes Lead records for conversion eligibility after duplicate matching
     * This method is designed to be called from after triggers to handle lead conversion
     * @param newLeads List of Lead records that have been processed for duplicate matching
     */
    public static void processDuplicateLeadConversion(List<Lead> newLeads) {
        try {
            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on');
            }

            if (newLeads == null || newLeads.isEmpty()) {
                return;
            }

            // Filter leads that are eligible for conversion processing
            List<Lead> leadsToProcess = filterLeadsForProcessing(newLeads, null);

            if (leadsToProcess.isEmpty()) {
                return;
            }

            // Run prechecks and get leads that passed
            List<Lead> leadsThatPassedPrecheck = runPrechecksAndFilterLeads(leadsToProcess);

            if (leadsThatPassedPrecheck.isEmpty()) {
                return;
            }

            // Collect matching data for conversion eligible leads
            MatchDataContainer matchData = collectMatchingData(leadsThatPassedPrecheck);

            // Process leads for conversion eligibility (only leads that passed prechecks)
            LeadDuplicateConversionService.ConversionResult conversionResult =
                LeadDuplicateConversionService.processLeadsForConversion(leadsThatPassedPrecheck, matchData);

            // Process conversion results and log any failures
            if (conversionResult != null) {
                logDebug('Lead Conversion Results: ' + conversionResult.toString());
            }


        } catch (Exception ex) {
            List<SObject> leadSObjects = new List<SObject>();
            leadSObjects.addAll(newLeads);
            for (Integer i = 0; i < leadSObjects.size(); i++) {
                logError('Failed to process Lead conversion from trigger at index ' + i + '. Errors: ' + ex.getMessage(),
                            new List<SObject>{leadSObjects[i]}, ex);
            }
        }
    }

    /**
     * @description Runs prechecks for leads and returns only those that passed
     * @param leadsToProcess List of Lead records to run prechecks on
     * @return List of Lead records that passed prechecks (empty if none passed)
     */
    private static List<Lead> runPrechecksAndFilterLeads(List<Lead> leadsToProcess) {
        // Run prechecks for lead conversion
        LeadConversionPrecheckService.PrecheckCollectionResult precheckResult =
            LeadConversionPrecheckService.runPrechecksForLeads(leadsToProcess, ConstantsUtil.CONVERSION_TYPE_AUTO);

        // Handle failed leads
        List<Id> failedLeadIds = precheckResult.failedLeadIds;
        if (failedLeadIds != null && !failedLeadIds.isEmpty()) {
            LeadService.updateFailedLeadsToNew(failedLeadIds);
        }

        // Return early if no leads passed prechecks
        if (precheckResult.successLeads.isEmpty()) {
            return new List<Lead>();
        }

        // Filter original leads to only include those that passed prechecks (to preserve all fields)
        Set<Id> successLeadIds = new Set<Id>();
        for (Lead successLead : precheckResult.successLeads) {
            successLeadIds.add(successLead.Id);
        }

        List<Lead> leadsThatPassedPrecheck = new List<Lead>();
        for (Lead lead : leadsToProcess) {
            if (successLeadIds.contains(lead.Id)) {
                leadsThatPassedPrecheck.add(lead);
            }
        }

        return leadsThatPassedPrecheck;
    }

    /**
     * @description Filters leads that need duplicate matching processing
     * @param newLeads List of new Lead records
     * @param oldLeadsMap Map of old Lead records (for updates)
     * @return List of Leads that need processing
     */
    private static List<Lead> filterLeadsForProcessing(List<Lead> newLeads, Map<Id, Lead> oldLeadsMap) {
        List<Lead> leadsToProcess = new List<Lead>();

        for (Lead currentLead : newLeads) {
            // Only process Patient record types
            if (!isEligibleRecordType(currentLead.RecordTypeId)) {
                continue;
            }

            // Only process leads that are NOT in excluded statuses
            if (ConstantsUtil.EXCLUDED_LEAD_STATUSES.contains(currentLead.Status)) {
                continue;
            }

            // For updates, only process if duplicate-matching relevant fields have changed
            if (oldLeadsMap != null && !hasRelevantFieldsChanged(currentLead, oldLeadsMap.get(currentLead.Id))) {
                continue;
            }

            leadsToProcess.add(currentLead);
        }

        return leadsToProcess;
    }

    /**
     * @description Checks if the record type is eligible for duplicate matching
     * @param recordTypeId Record Type Id to check
     * @return Boolean indicating if record type is eligible
     */
    public static Boolean isEligibleRecordType(Id recordTypeId) {
        return recordTypeId == ConstantsUtil.LEAD_PATIENT_RT;
    }

    /**
     * @description Checks if any duplicate-matching relevant fields have changed
     * @param newLead The new Lead record
     * @param oldLead The old Lead record
     * @return Boolean indicating if any relevant fields have changed
     */
     @TestVisible
    private static Boolean hasRelevantFieldsChanged(Lead newLead, Lead oldLead) {
        if (oldLead == null) {
            return true;
        }

        List<DuplicateRuleCriteria> criteria = getDuplicateCriteria();
        for (DuplicateRuleCriteria criterion : criteria) {
            Object newValue = newLead.get(criterion.sourceField);
            Object oldValue = oldLead.get(criterion.sourceField);

            // Check if the field value has changed
            if (hasFieldValueChanged(newValue, oldValue)) {
                return true;
            }
        }

        // Also check if LeadSource changed as it affects exclusion logic
        if (newLead.LeadSource != oldLead.LeadSource) {
            return true;
        }

        // Also check if Status changed as it affects filtering logic
        if (newLead.Status != oldLead.Status) {
            return true;
        }

        return false;
    }

    /**
     * @description Checks if a single field value has changed between old and new records
     * @param newValue The new field value
     * @param oldValue The old field value
     * @return Boolean indicating if the field value has changed
     */
    private static Boolean hasFieldValueChanged(Object newValue, Object oldValue) {
        // Both null - no change
        if (newValue == null && oldValue == null) {
            return false;
        }

        // One is null, other is not - changed
        if (newValue == null || oldValue == null) {
            return true;
        }

        // Both have values - compare them
        return newValue != oldValue;
    }

    /**
     * @description Counts the number of matching fields in a MatchingCriteria object
     * @param criteria MatchingCriteria object to evaluate
     * @return Integer count of matching fields
     */
    public static Integer countMatchingFields(MatchingCriteria criteria) {
        Integer matchCount = 0;
        if (criteria.fieldMatches != null) {
            for (Boolean fieldMatch : criteria.fieldMatches.values()) {
                if (fieldMatch == true) {
                    matchCount++;
                }
            }
        }
        return matchCount;
    }


    /**
     * @description Collects matching data for all leads in 2 queries
     * @param leadsToProcess List of leads to find matches for
     * @return MatchDataContainer containing all potential matches
     */
    public static MatchDataContainer collectMatchingData(List<Lead> leadsToProcess) {
        // Return test data if provided (test hook)
        if (Test.isRunningTest() && testMatchData != null) {
            return testMatchData;
        }

        MatchDataContainer matchData = new MatchDataContainer();
        List<DuplicateRuleCriteria> criteria = getDuplicateCriteria();

        // Collect criteria values separated by field type for targeted IN clauses
        LeadDuplicateMatchingServiceHelper.FieldCriteriaValues fieldCriteria = LeadDuplicateMatchingServiceHelper.collectFieldCriteriaValues(leadsToProcess, criteria);

        if (fieldCriteria.isEmpty()) {
            return matchData;
        }

        matchData.allPotentialLeadMatches = LeadDuplicateMatchingServiceHelper.queryPotentialLeadMatches(leadsToProcess, fieldCriteria, criteria);
        matchData.allPotentialAccountMatches = LeadDuplicateMatchingServiceHelper.queryPotentialAccountMatches(fieldCriteria, criteria);

        return matchData;
    }

    /**
     * @description Determines matching status
     * @param currentLead Lead to evaluate
     * @param matchData Collected matching data
     * @return String matching status
     */
    private static String determineMatchingStatusFromCollection(Lead currentLead, MatchDataContainer matchData) {
        List<MatchingCriteria> matches = findMatchingRecordsFromCollection(currentLead, matchData);
        return evaluateMatches(matches);
    }

    /**
     * @description Evaluates matches to determine status
     * @param matches List of matching criteria
     * @return String matching status
     */
    private static String evaluateMatches(List<MatchingCriteria> matches) {
        if (matches.isEmpty()) {
            return ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH;
        }

        for (MatchingCriteria match : matches) {
            if (isFullMatch(match)) {
                return ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH;
            }
        }

        for (MatchingCriteria match : matches) {
            if (countMatchingFields(match) >= 2) {
                return ConstantsUtil.LEAD_MATCHING_STATUS_PARTIAL_MATCH;
            }
        }

        return ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH;
    }
    /**
     * @description Determines if a matching criteria represents a full match
     * @param criteria MatchingCriteria to evaluate
     * @return Boolean indicating if it's a full match
     */
     public static Boolean isFullMatch(MatchingCriteria criteria) {
        List<DuplicateRuleCriteria> duplicateRules = getDuplicateCriteria();

        // Count total matches and check required field matches
        Integer totalMatches = 0;
        Integer requiredMatches = 0;
        Integer requiredFieldsMatched = 0;

        for (DuplicateRuleCriteria rule : duplicateRules) {
            Boolean fieldMatches = criteria.fieldMatches.get(rule.sourceField) == true;

            if (fieldMatches) {
                totalMatches++;
                if (rule.requiredForFullMatch) {
                    requiredFieldsMatched++;
                }
            }

            if (rule.requiredForFullMatch) {
                requiredMatches++;
            }

        }

        // Full Match scenarios:
        // 1. All fields match
        if (totalMatches == duplicateRules.size()) {
            return true;
        }

        // 2. All required fields match + at least one additional field
        if (requiredMatches > 0 && requiredFieldsMatched == requiredMatches &&
            totalMatches >= (requiredMatches + 1)) {
            return true;
        }

        return false;
    }

    /**
     * @description Finds matching records using collected data
     * @param currentLead Lead to find matches for
     * @param matchData Collected matching data
     * @return List of matching criteria
     */
    private static List<MatchingCriteria> findMatchingRecordsFromCollection(Lead currentLead, MatchDataContainer matchData) {
        List<MatchingCriteria> matches = new List<MatchingCriteria>();
        List<DuplicateRuleCriteria> criteria = getDuplicateCriteria();

        // Find Lead matches from collected data
        matches.addAll(LeadDuplicateMatchingServiceHelper.findLeadMatchesFromCollection(currentLead, matchData, criteria));

        // Find Account matches from collected data
        matches.addAll(LeadDuplicateMatchingServiceHelper.findAccountMatchesFromCollection(currentLead, matchData, criteria));

        return matches;
    }

    /**
     * @description Inner class to hold matching criteria results
     */
    public class MatchingCriteria {
        public Id recordId;
        public String recordType;
        public Map<String, Boolean> fieldMatches;
        public SObject record; // Store the actual record for field access
    }

    /**
     * @description Data container for efficient matching
     */
    public class MatchDataContainer {
        public List<Lead> allPotentialLeadMatches;
        public List<Account> allPotentialAccountMatches;

        /**
         * @description Constructor to initialize empty collections for Lead and Account matches
         * Initializes both allPotentialLeadMatches and allPotentialAccountMatches as empty lists
         * to prepare the container for storing potential duplicate records during the matching process
         */
        public MatchDataContainer() {
            this.allPotentialLeadMatches = new List<Lead>();
            this.allPotentialAccountMatches = new List<Account>();
        }
    }

    /**
    * @description Exception class for Product Recommendation Engine
    */
    public class MyCustomException extends Exception {}
}