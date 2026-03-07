/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 12th Nov 2025
 * @description : Helper class for Lead duplicate matching operations
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       12th Nov 2025       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1065)
 */
public with sharing class LeadDuplicateHelper {

    // Cache for duplicate rule criteria
    private static List<DuplicateRuleCriteria> duplicateCriteria;
    
    /**
     * @description Wrapper class for duplicate rule criteria
     */
    private class DuplicateRuleCriteria {
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
     * @description Checks if the record type is eligible for duplicate matching
     * @param recordTypeId Record Type Id to check
     * @return Boolean indicating if record type is eligible
     */
    public static Boolean isEligibleRecordType(Id recordTypeId) {
        return recordTypeId == ConstantsUtil.LEAD_PATIENT_RT;
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
     * @description Checks if a field value is considered blank (null, empty, or whitespace only)
     * @param value The field value to check
     * @return Boolean indicating if the value is blank
     */
    private static Boolean isFieldValueBlank(Object value) {
        if (value == null) {
            return true;
        }

        String stringValue = String.valueOf(value);
        return String.isBlank(stringValue);
    }

    /**
     * @description Finds matching Lead and Account records
     * @param currentLead Lead record to find matches for
     * @return List of matching criteria objects
     */
    public static List<MatchingCriteria> findMatchingRecords(Lead currentLead) {
        List<MatchingCriteria> matchingResults = new List<MatchingCriteria>();

        // Find matching Leads
        matchingResults.addAll(findMatchingLeads(currentLead));

        // Find matching Patient Accounts
        matchingResults.addAll(findMatchingAccounts(currentLead));

        return matchingResults;
    }

    /**
     * @description Finds matching Lead records
     * @param currentLead Lead record to find matches for
     * @return List of matching criteria for Leads
     */
    private static List<MatchingCriteria> findMatchingLeads(Lead currentLead) {
        List<MatchingCriteria> matches = new List<MatchingCriteria>();
        List<DuplicateRuleCriteria> criteria = getDuplicateCriteria();

        QueryConditions queryConditions = buildLeadQueryConditions(currentLead, criteria);
        if (queryConditions.conditions.isEmpty()) {
            return matches;
        }

        String query = buildLeadQuery(currentLead, queryConditions);
        List<Lead> matchingLeads = Database.query(query, AccessLevel.USER_MODE);//NOPMD (escaped single quotes for all passed variable , static code analysis is giving false positive error)

        return processLeadMatches(currentLead, matchingLeads, criteria);
    }

    /**
     * @description Builds query conditions for Lead matching
     * @param currentLead Lead record to match against
     * @param criteria List of duplicate rule criteria
     * @return QueryConditions with conditions and fields
     */
    private static QueryConditions buildLeadQueryConditions(Lead currentLead, List<DuplicateRuleCriteria> criteria) {
        QueryConditions queryConditions = new QueryConditions();
        queryConditions.fieldsToSelect.addAll(new Set<String>{
            ConstantsUtil.ID, ConstantsUtil.LEAD_SOURCE, ConstantsUtil.LEAD_STATUS,
            ConstantsUtil.LEAD_FIRST_NAME, ConstantsUtil.LEAD_MIDDLE_NAME, ConstantsUtil.LEAD_STREET,
            ConstantsUtil.LEAD_CITY, ConstantsUtil.LEAD_STATE, ConstantsUtil.LEAD_POSTAL_CODE, ConstantsUtil.LEAD_COUNTRY
        });

        for (DuplicateRuleCriteria criterion : criteria) {
            if (criterion.targetObject != ConstantsUtil.LEAD_OBJECT) {
                continue;
            }

            queryConditions.fieldsToSelect.add(criterion.targetField);
            Object fieldValue = currentLead.get(criterion.sourceField);
            Boolean shouldExclude = criterion.excludedSources.contains(currentLead.LeadSource);

            if (!isFieldValueBlank(fieldValue) && !shouldExclude) {
                String condition = buildFieldCondition(criterion.targetField, fieldValue);
                if (String.isNotBlank(condition)) {
                    queryConditions.conditions.add(condition);
                }
            }
        }

        return queryConditions;
    }

    /**
     * @description Builds complete Lead query string
     * @param currentLead Lead record being matched
     * @param queryConditions Query conditions with fields and conditions
     * @return Complete SOQL query string
     */
    private static String buildLeadQuery(Lead currentLead, QueryConditions queryConditions) {
        List<String> escapedFields = escapeFieldNames(queryConditions.fieldsToSelect);
        String excludedStatuses = buildExcludedStatusClause();

        return 'SELECT ' + String.join(escapedFields, ', ') +
               ' FROM ' + ConstantsUtil.LEAD_OBJECT + ' WHERE ' + ConstantsUtil.ID + ' != \'' + String.escapeSingleQuotes(currentLead.Id) + '\' ' +
               'AND RecordTypeId = \'' + String.escapeSingleQuotes(ConstantsUtil.LEAD_PATIENT_RT) + '\' ' +
               'AND (' + String.join(queryConditions.conditions, ' OR ') + ') ' +
               'AND ' + ConstantsUtil.LEAD_STATUS + ' NOT IN (' + excludedStatuses + ')';
    }

    /**
     * @description Processes matching Lead records to create MatchingCriteria
     * @param currentLead Original Lead record
     * @param matchingLeads List of matching Lead records
     * @param criteria List of duplicate rule criteria
     * @return List of MatchingCriteria objects
     */
    private static List<MatchingCriteria> processLeadMatches(Lead currentLead, List<Lead> matchingLeads, List<DuplicateRuleCriteria> criteria) {
        List<MatchingCriteria> matches = new List<MatchingCriteria>();

        for (Lead matchingLead : matchingLeads) {
            MatchingCriteria matchCriteria = createLeadMatchCriteria(currentLead, matchingLead, criteria);
            matches.add(matchCriteria);
        }

        return matches;
    }

    /**
     * @description Creates MatchingCriteria for a specific Lead match
     * @param currentLead Original Lead record
     * @param matchingLead Matching Lead record
     * @param criteria List of duplicate rule criteria
     * @return MatchingCriteria object
     */
    private static MatchingCriteria createLeadMatchCriteria(Lead currentLead, Lead matchingLead, List<DuplicateRuleCriteria> criteria) {
        MatchingCriteria matchCriteria = new MatchingCriteria();
        matchCriteria.recordId = matchingLead.Id;
        matchCriteria.recordType = ConstantsUtil.LEAD_OBJECT;
        matchCriteria.fieldMatches = new Map<String, Boolean>();
        matchCriteria.record = matchingLead;

        for (DuplicateRuleCriteria criterion : criteria) {
            if (criterion.targetObject != ConstantsUtil.LEAD_OBJECT) {
                continue;
            }

            Boolean shouldExclude = criterion.excludedSources.contains(currentLead.LeadSource);
            Object sourceValue = currentLead.get(criterion.sourceField);
            Object targetValue = matchingLead.get(criterion.targetField);

            Boolean fieldsMatch = !shouldExclude &&
                !isFieldValueBlank(sourceValue) &&
                !isFieldValueBlank(targetValue) &&
                (sourceValue == targetValue);
            matchCriteria.fieldMatches.put(criterion.sourceField, fieldsMatch);
        }

        return matchCriteria;
    }

    /**
     * @description Finds matching Patient Account records
     * @param currentLead Lead record to find matches for
     * @return List of matching criteria for Accounts
     */
    private static List<MatchingCriteria> findMatchingAccounts(Lead currentLead) {
        List<MatchingCriteria> matches = new List<MatchingCriteria>();
        List<DuplicateRuleCriteria> criteria = getDuplicateCriteria();

        QueryConditions queryConditions = buildAccountQueryConditions(currentLead, criteria);
        if (queryConditions.conditions.isEmpty()) {
            return matches;
        }

        String query = buildAccountQuery(queryConditions);
        List<Account> matchingAccounts = Database.query(query, AccessLevel.USER_MODE);//NOPMD (escaped single quotes for all passed variable , static code analysis is giving false positive error)

        return processAccountMatches(currentLead, matchingAccounts, criteria);
    }

    /**
     * @description Builds query conditions for Account matching
     * @param currentLead Lead record to match against
     * @param criteria List of duplicate rule criteria
     * @return QueryConditions with conditions and fields
     */
    private static QueryConditions buildAccountQueryConditions(Lead currentLead, List<DuplicateRuleCriteria> criteria) {
        QueryConditions queryConditions = new QueryConditions();
        queryConditions.fieldsToSelect.addAll(new Set<String>{
            ConstantsUtil.ID, ConstantsUtil.ACCOUNT_FIRST_NAME, ConstantsUtil.ACCOUNT_MIDDLE_NAME,
            ConstantsUtil.ACCOUNT_BILLING_STREET, ConstantsUtil.ACCOUNT_BILLING_CITY, ConstantsUtil.ACCOUNT_BILLING_STATE,
            ConstantsUtil.ACCOUNT_BILLING_POSTAL_CODE, ConstantsUtil.ACCOUNT_BILLING_COUNTRY
        });

        for (DuplicateRuleCriteria criterion : criteria) {
            if (criterion.targetObject != ConstantsUtil.ACCOUNT_OBJECT) {
                continue;
            }

            queryConditions.fieldsToSelect.add(criterion.targetField);
            Object leadFieldValue = currentLead.get(criterion.sourceField);
            Boolean shouldExclude = criterion.excludedSources.contains(currentLead.LeadSource);

            if (!isFieldValueBlank(leadFieldValue) && !shouldExclude) {
                String condition = buildFieldCondition(criterion.targetField, leadFieldValue);
                if (String.isNotBlank(condition)) {
                    queryConditions.conditions.add(condition);
                }
            }
        }

        return queryConditions;
    }

    /**
     * @description Builds complete Account query string
     * @param queryConditions Query conditions with fields and conditions
     * @return Complete SOQL query string
     */
    private static String buildAccountQuery(QueryConditions queryConditions) {
        List<String> escapedFields = escapeFieldNames(queryConditions.fieldsToSelect);

        return 'SELECT ' + String.join(escapedFields, ', ') +
               ' FROM ' + ConstantsUtil.ACCOUNT_OBJECT + ' WHERE IsPersonAccount = true ' +
               'AND RecordTypeId = \'' + String.escapeSingleQuotes(ConstantsUtil.ACCOUNT_PATIENT_RT) + '\' ' +
               'AND (' + String.join(queryConditions.conditions, ' OR ') + ')';
    }

    /**
     * @description Processes matching Account records to create MatchingCriteria
     * @param currentLead Original Lead record
     * @param matchingAccounts List of matching Account records
     * @param criteria List of duplicate rule criteria
     * @return List of MatchingCriteria objects
     */
    private static List<MatchingCriteria> processAccountMatches(Lead currentLead, List<Account> matchingAccounts, List<DuplicateRuleCriteria> criteria) {
        List<MatchingCriteria> matches = new List<MatchingCriteria>();

        for (Account matchingAccount : matchingAccounts) {
            MatchingCriteria matchCriteria = createAccountMatchCriteria(currentLead, matchingAccount, criteria);
            matches.add(matchCriteria);
        }

        return matches;
    }

    /**
     * @description Creates MatchingCriteria for a specific Account match
     * @param currentLead Original Lead record
     * @param matchingAccount Matching Account record
     * @param criteria List of duplicate rule criteria
     * @return MatchingCriteria object
     */
    private static MatchingCriteria createAccountMatchCriteria(Lead currentLead, Account matchingAccount, List<DuplicateRuleCriteria> criteria) {
        MatchingCriteria matchCriteria = new MatchingCriteria();
        matchCriteria.recordId = matchingAccount.Id;
        matchCriteria.recordType = ConstantsUtil.ACCOUNT_OBJECT;
        matchCriteria.fieldMatches = new Map<String, Boolean>();
        matchCriteria.record = matchingAccount;

        for (DuplicateRuleCriteria criterion : criteria) {
            if (criterion.targetObject != ConstantsUtil.ACCOUNT_OBJECT) {
                continue;
            }

            Boolean shouldExclude = criterion.excludedSources.contains(currentLead.LeadSource);
            Object sourceValue = currentLead.get(criterion.sourceField);
            Object targetValue = matchingAccount.get(criterion.targetField);

            Boolean fieldsMatch = !shouldExclude &&
                !isFieldValueBlank(sourceValue) &&
                !isFieldValueBlank(targetValue) &&
                (sourceValue == targetValue);
            matchCriteria.fieldMatches.put(criterion.sourceField, fieldsMatch);
        }

        return matchCriteria;
    }

    /**
     * @description Builds a query condition for a field value
     * @param fieldName Name of the field
     * @param fieldValue Value of the field
     * @return String query condition
     */
    private static String buildFieldCondition(String fieldName, Object fieldValue) {
        if (fieldValue == null) {
            return '';
        }

        String escapedFieldName = String.escapeSingleQuotes(fieldName);

        if (fieldValue instanceof String) {
            return escapedFieldName + ' = \'' + String.escapeSingleQuotes((String)fieldValue) + '\'';
        } else if (fieldValue instanceof Date) {
            return escapedFieldName + ' = ' + String.valueOf((Date)fieldValue);
        } else {
            return escapedFieldName + ' = \'' + String.escapeSingleQuotes(String.valueOf(fieldValue)) + '\'';
        }
    }

    /**
     * @description Escapes field names for security
     * @param fieldsToSelect Set of field names to escape
     * @return List of escaped field names
     */
    private static List<String> escapeFieldNames(Set<String> fieldsToSelect) {
        List<String> escapedFields = new List<String>();
        for (String fieldName : fieldsToSelect) {
            escapedFields.add(String.escapeSingleQuotes(fieldName));
        }
        return escapedFields;
    }

    /**
     * @description Builds excluded status clause for Lead queries
     * @return String with excluded statuses clause
     */
    private static String buildExcludedStatusClause() {
        List<String> excludedStatusList = new List<String>();
        for (String status : ConstantsUtil.EXCLUDED_LEAD_STATUSES) {
            excludedStatusList.add('\'' + String.escapeSingleQuotes(status) + '\'');
        }
        return String.join(excludedStatusList, ', ');
    }

    /**
     * @description Determines if a matching criteria represents a full match
     * @param criteria MatchingCriteria to evaluate
     * @return Boolean indicating if it's a full match
     */
     public static Boolean isFullMatch(MatchingCriteria criteria) {
        List<DuplicateRuleCriteria> duplicateRules = getDuplicateCriteria();

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
     * @description Inner class to hold matching criteria results
     */
    public class MatchingCriteria {
        public Id recordId;
        public String recordType;
        public Map<String, Boolean> fieldMatches;
        public SObject record; // Store the actual record for field access
    }

    /**
     * @description Wrapper class for query conditions
     */
    private class QueryConditions {
        public List<String> conditions;
        public Set<String> fieldsToSelect;
        /**
         * @description Constructor initializes empty collections for conditions and fields
         */
        public QueryConditions() {
            this.conditions = new List<String>();
            this.fieldsToSelect = new Set<String>();
        }
    }
}