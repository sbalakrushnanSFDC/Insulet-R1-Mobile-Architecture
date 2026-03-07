/**
 * Lead duplicate matching helper.
 * Provides reusable query and evaluation utilities used by duplicate matching services
 * to identify potential Lead/Account matches while keeping calling services simpler.
 *
 * @author      : Bijayalaxmi Prusty
 * @created Date: 25th Nov 2025
 * @description : Helper class for Lead duplicate matching operations to reduce cyclomatic complexity
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       25th Nov 2025       Bijayalaxmi Prusty      Initial Version(US - NGASIM-219)
 * V1.0.1       26th Nov 2025       Bijayalaxmi Prusty      Updated(US - NGASIM-1050)
 * V1.0.2       14th Jan 2026       Jatin Butta             Modified(US - NGASIM-1901, NGASIM-1602)
 * V1.0.3       22nd Jan 2026       Priyansh Shukla         Modified(US - NGOMCT-1749)
 * V1.0.4       16th Feb 2026       Charchit Nirayanwal     Modified(US - NGASIM-2207)
 * V1.0.5       17th Feb 2026       Charchit Nirayanwal     Modified(US - NGASIM-2207)
 * V1.1.0       18th Feb 2026       Bijayalaxmi Prusty      Updated(US - NGOMCT-1961)
 */
@SuppressWarnings('PMD.ExcessiveParameterList,PMD.CyclomaticComplexity,PMD.CognitiveComplexity')
public without sharing class LeadDuplicateMatchingServiceHelper {

    // Static cache for Account query results to avoid redundant SOQL in the same transaction
    private static List<Account> cachedAccountMatches;
    private static String cachedAccountCacheKey;

    // Static cache for Lead query results to avoid redundant SOQL in the same transaction
    private static List<Lead> cachedLeadMatches;
    private static String cachedLeadCacheKey;

    /**
     * @description Dynamic container for field-specific criteria values, keyed by source field API name.
     * Uses Map-based storage so that any new field added to the Duplicate_Rules_Criteria__mdt custom
     * metadata is automatically handled without code changes to this class.
     */
    public class FieldCriteriaValues {
        private Map<String, Set<String>> stringCriteriaMap;
        private Map<String, Set<Date>> dateCriteriaMap;

        /**
         * @description Constructor to initialize empty maps for criteria storage
         */
        public FieldCriteriaValues() {
            this.stringCriteriaMap = new Map<String, Set<String>>();
            this.dateCriteriaMap = new Map<String, Set<Date>>();
        }

        /**
         * @description Adds a criteria value, automatically routing to string or date map based on type
         * @param sourceField The source field API name from the criteria metadata
         * @param value The field value to store
         */
        public void addValue(String sourceField, Object value) {
            if (value instanceof Date) {
                if (!dateCriteriaMap.containsKey(sourceField)) {
                    dateCriteriaMap.put(sourceField, new Set<Date>());
                }
                dateCriteriaMap.get(sourceField).add((Date)value);
            } else {
                if (!stringCriteriaMap.containsKey(sourceField)) {
                    stringCriteriaMap.put(sourceField, new Set<String>());
                }
                stringCriteriaMap.get(sourceField).add(String.valueOf(value));
            }
        }

        /**
         * @description Returns the map of source field name to string criteria values
         * @return Map of field name to Set of string values
         */
        public Map<String, Set<String>> getStringCriteriaMap() {
            return stringCriteriaMap;
        }

        /**
         * @description Returns the map of source field name to date criteria values
         * @return Map of field name to Set of date values
         */
        public Map<String, Set<Date>> getDateCriteriaMap() {
            return dateCriteriaMap;
        }

        /**
         * @description Checks if all criteria maps are empty
         * @return Boolean true if no criteria values exist in any map
         */
        public Boolean isEmpty() {
            for (Set<String> vals : stringCriteriaMap.values()) {
                if (!vals.isEmpty()) {
                    return false;
                }
            }
            for (Set<Date> vals : dateCriteriaMap.values()) {
                if (!vals.isEmpty()) {
                    return false;
                }
            }
            return true;
        }
    }

    /**
     * @description Collects criteria values from leads, dynamically routed by source field.
     * No hardcoded field names — any field defined in the Duplicate_Rules_Criteria__mdt
     * metadata is automatically collected into the appropriate map entry.
     * @param leads List of leads to extract criteria from
     * @param criteria Duplicate rule criteria defining which fields to collect
     * @return FieldCriteriaValues with values keyed by source field name
     */
    public static FieldCriteriaValues collectFieldCriteriaValues(List<Lead> leads, List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria) {
        FieldCriteriaValues values = new FieldCriteriaValues();

        for (Lead lead : leads) {
            for (LeadDuplicateMatchingService.DuplicateRuleCriteria criterion : criteria) {
                Object fieldValue = lead.get(criterion.sourceField);
                Boolean shouldExclude = criterion.excludedSources.contains(lead.LeadSource);

                if (!isFieldValueBlank(fieldValue) && !shouldExclude) {
                    values.addValue(criterion.sourceField, fieldValue);
                }
            }
        }

        return values;
    }

    /**
     * @description Queries potential Lead matches using dynamically built WHERE clause and static caching.
     * Criteria fields and bind variables are derived from the metadata at runtime, so new fields
     * added to Duplicate_Rules_Criteria__mdt are automatically included without code changes.
     * @param leadsToProcess Current leads being processed (used to build exclude list)
     * @param fieldCriteria Field-specific criteria values keyed by source field name
     * @param criteria Duplicate rule criteria defining source-to-target field mapping
     * @return List of potential Lead matches
     */
    public static List<Lead> queryPotentialLeadMatches(List<Lead> leadsToProcess, FieldCriteriaValues fieldCriteria, List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria) {
        // Safely extract non-null Ids
        Set<Id> excludeIds = new Set<Id>();
        for (Lead leadRec : leadsToProcess) {
            if (leadRec.Id != null) {
                excludeIds.add(leadRec.Id);
            }
        }

        // Return cached results if this exact query was already executed in this transaction
        String cacheKey = buildCacheKey(fieldCriteria, excludeIds);
        if (cachedLeadMatches != null && cachedLeadCacheKey == cacheKey) {
            return cachedLeadMatches;
        }

        // Base SELECT fields always needed for UI/logic; criteria target fields are added dynamically below
        Set<String> selectFields = new Set<String>{
            'Id', 'FirstName', 'MiddleName', 'LastName', 'Email', 'Phone',
            'Street', 'City', 'State', 'PostalCode', 'Country',
            'Status', 'LeadSource', 'Date_of_Birth__c'
        };

        // Dynamically build bind map and field conditions from criteria metadata
        DynamicQueryComponents queryComponents = buildDynamicQueryComponents(fieldCriteria, criteria, ConstantsUtil.LEAD_OBJECT, selectFields);

        // If no field conditions were built, no criteria values exist — return empty list
        if (queryComponents.fieldConditions.isEmpty()) {
            return new List<Lead>();
        }

        // Build base query with shared filters; each per-field query appends a single AND condition
        String baseQuery = 'SELECT ' + String.join(new List<String>(selectFields), ', ') +
                          ' FROM Lead WHERE RecordTypeId = \'' +
                          String.escapeSingleQuotes(ConstantsUtil.LEAD_PATIENT_RT) + '\' AND ' +
                          'Status NOT IN :excludedStatuses';

        if (!excludeIds.isEmpty()) {
            baseQuery += ' AND Id NOT IN :excludeIds';
        }

        // Shared bind variables needed by every sub-query (status filter, Id exclusion)
        Map<String, Object> sharedBinds = new Map<String, Object>();
        sharedBinds.put('excludedStatuses', ConstantsUtil.EXCLUDED_LEAD_STATUSES);
        if (!excludeIds.isEmpty()) {
            sharedBinds.put('excludeIds', excludeIds);
        }

        List<Lead> results = new List<Lead>();
        for (SObject sObj : executePerFieldQueries(baseQuery, queryComponents, sharedBinds)) {
            results.add((Lead) sObj);
        }

        // Cache results for subsequent calls with the same criteria
        cachedLeadCacheKey = cacheKey;
        cachedLeadMatches = results;

        return results;
    }

    /**
     * @description Queries potential Account matches using dynamically built WHERE clause and static caching.
     * Criteria fields and bind variables are derived from the metadata at runtime, so new fields
     * added to Duplicate_Rules_Criteria__mdt are automatically included without code changes.
     * @param fieldCriteria Field-specific criteria values keyed by source field name
     * @param criteria Duplicate rule criteria defining source-to-target field mapping
     * @return List of potential Account matches
     */
    public static List<Account> queryPotentialAccountMatches(FieldCriteriaValues fieldCriteria, List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria) {
        // Return cached results if this exact query was already executed in this transaction
        String cacheKey = buildCacheKey(fieldCriteria, null);
        if (cachedAccountMatches != null && cachedAccountCacheKey == cacheKey) {
            return cachedAccountMatches;
        }

        // Base SELECT fields always needed for UI/logic; criteria target fields are added dynamically below
        Set<String> selectFields = new Set<String>{
            'Id', 'Salutation', 'Suffix', 'Name', 'FirstName', 'MiddleName', 'LastName',
            'PersonEmail', 'Phone', 'BillingStreet', 'BillingCity', 'BillingState',
            'BillingPostalCode', 'BillingCountry', 'Date_of_Birth__c', 'PersonLeadSource',
            'Type_of_Diabetes__c', 'PersonGenderIdentity', 'Preferred_Language__c',
            'Sensor_CGM_Continuous_Glucose_Monitor__c', 'Insurance_Type__c',
            'PersonIndividualId', 'Current_Therapy__c'
        };

        // Dynamically build bind map and field conditions from criteria metadata
        DynamicQueryComponents queryComponents = buildDynamicQueryComponents(fieldCriteria, criteria, ConstantsUtil.ACCOUNT_OBJECT, selectFields);

        // If no field conditions were built, no criteria values exist — return empty list
        if (queryComponents.fieldConditions.isEmpty()) {
            return new List<Account>();
        }

        // Build base query; each per-field query appends a single AND condition
        String baseQuery = 'SELECT ' + String.join(new List<String>(selectFields), ', ') +
                          ' FROM Account WHERE ' +
                          'IsPersonAccount = true AND RecordTypeId = \'' +
                          String.escapeSingleQuotes(ConstantsUtil.ACCOUNT_PATIENT_RT) + '\'';

        List<Account> results = new List<Account>();
        for (SObject sObj : executePerFieldQueries(baseQuery, queryComponents, null)) {
            results.add((Account) sObj);
        }

        // Cache results for subsequent calls with the same criteria
        cachedAccountCacheKey = cacheKey;
        cachedAccountMatches = results;

        return results;
    }

    /**
     * @description Executes one SOQL query per criteria field condition and merges the results,
     * deduplicating by record Id. This allows Salesforce to use selective indexes on each
     * individual field rather than falling back to a full table scan with broad OR conditions.
     * @param baseQuery The shared SELECT ... FROM ... WHERE ... prefix (without trailing field condition)
     * @param queryComponents Contains per-field conditions, bind names, and bind values
     * @param sharedBindVariables Optional bind variables shared across all sub-queries (e.g. excludedStatuses)
     * @return Deduplicated list of SObject records from all per-field queries
     */
    private static List<SObject> executePerFieldQueries(String baseQuery, DynamicQueryComponents queryComponents, Map<String, Object> sharedBindVariables) {
        Map<Id, SObject> mergedResults = new Map<Id, SObject>();

        for (Integer i = 0; i < queryComponents.fieldConditions.size(); i++) {
            String singleQuery = baseQuery + ' AND ' + queryComponents.fieldConditions[i] + ' LIMIT 20000';

            Map<String, Object> singleBindMap = new Map<String, Object>();
            if (sharedBindVariables != null) {
                singleBindMap.putAll(sharedBindVariables);
            }
            singleBindMap.put(queryComponents.bindNames[i], queryComponents.bindMap.get(queryComponents.bindNames[i]));

            List<SObject> partial = Database.queryWithBinds(singleQuery, singleBindMap, AccessLevel.SYSTEM_MODE);//NOPMD
            for (SObject record : partial) {
                mergedResults.put(record.Id, record);
            }
        }

        return mergedResults.values();
    }

    /**
     * @description Enriches matched Account records with their related Opportunities.
     * Called after matching is complete but before conversion, so the initial broad Account query
     * can run without the expensive Opportunities subquery. Only the small set of matched accounts
     * are re-queried with Opportunities, which is fast since it uses an indexed Id filter.
     * @param leadsWithAccountMatches Map of leads to their matched accounts to enrich with Opportunities
     */
    public static void enrichAccountsWithOpportunities(Map<Lead, Account> leadsWithAccountMatches) {
        if (leadsWithAccountMatches == null || leadsWithAccountMatches.isEmpty()) {
            return;
        }

        // Collect unique Account IDs from matched accounts
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : leadsWithAccountMatches.values()) {
            if (acc != null && acc.Id != null) {
                accountIds.add(acc.Id);
            }
        }

        if (accountIds.isEmpty()) {
            return;
        }

        // Re-query only the matched accounts with all needed fields + Opportunities subquery
        Map<Id, Account> enrichedAccounts = new Map<Id, Account>([
            SELECT Id, Salutation, Suffix, Name, FirstName, MiddleName, LastName,
                   PersonEmail, Phone, BillingStreet, BillingCity, BillingState,
                   BillingPostalCode, BillingCountry, Date_of_Birth__c, PersonLeadSource,
                   Type_of_Diabetes__c, PersonGenderIdentity, Preferred_Language__c,
                   Sensor_CGM_Continuous_Glucose_Monitor__c, Insurance_Type__c,
                   PersonIndividualId, Current_Therapy__c,
                   (SELECT Id, StageName, IsClosed, IsWon, Number_of_time_contacted__c, Last_Contacted_Date__c,
                    Insurance_Name__c, Insurance_Type__c
                    FROM Opportunities
                    WHERE RecordTypeId = :ConstantsUtil.OPPORTUNITY_NCS_RT
                    LIMIT 10)
            FROM Account
            WHERE Id IN :accountIds
            WITH SYSTEM_MODE
        ]); //NOPMD

        // Replace the Account references in the map with the enriched versions
        for (Lead ld : leadsWithAccountMatches.keySet()) {
            Account originalAccount = leadsWithAccountMatches.get(ld);
            if (originalAccount != null && enrichedAccounts.containsKey(originalAccount.Id)) {
                leadsWithAccountMatches.put(ld, enrichedAccounts.get(originalAccount.Id));
            }
        }
    }

    /**
     * @description Container for dynamically built query components shared by Lead and Account queries.
     */
    private class DynamicQueryComponents {
        public Map<String, Object> bindMap;
        public List<String> fieldConditions;
        public List<String> bindNames;

        /**
         * @description Constructor to initialize empty collections for bind map, field conditions, and bind names
         */
        public DynamicQueryComponents() {
            this.bindMap = new Map<String, Object>();
            this.fieldConditions = new List<String>();
            this.bindNames = new List<String>();
        }
    }

    /**
     * @description Builds bind-map entries and field conditions from criteria metadata for a given target object.
     * Also adds each criteria target field to the provided selectFields set so the query returns all
     * columns needed by the evaluation methods.
     * @param fieldCriteria Field-specific criteria values keyed by source field name
     * @param criteria Duplicate rule criteria defining source-to-target field mapping
     * @param targetObjectName API name of the target object to filter criteria by
     * @param selectFields Mutable set of SELECT field names — target fields are added in place
     * @return DynamicQueryComponents containing the bind map and field condition strings
     */
    private static DynamicQueryComponents buildDynamicQueryComponents(FieldCriteriaValues fieldCriteria, List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria, String targetObjectName, Set<String> selectFields) {
        DynamicQueryComponents components = new DynamicQueryComponents();

        Integer bindIndex = 0;
        for (LeadDuplicateMatchingService.DuplicateRuleCriteria criterion : criteria) {
            if (criterion.targetObject != targetObjectName) {
                continue;
            }

            String sourceField = criterion.sourceField;
            String targetField = criterion.targetField;
            selectFields.add(targetField);

            Set<String> strValues = fieldCriteria.getStringCriteriaMap().get(sourceField);
            Set<Date> dateValues = fieldCriteria.getDateCriteriaMap().get(sourceField);

            if (strValues != null && !strValues.isEmpty()) {
                String bindName = 'v' + bindIndex++;
                components.bindMap.put(bindName, strValues);
                components.fieldConditions.add(targetField + ' IN :' + bindName);
                components.bindNames.add(bindName);
            } else if (dateValues != null && !dateValues.isEmpty()) {
                String bindName = 'v' + bindIndex++;
                components.bindMap.put(bindName, dateValues);
                components.fieldConditions.add(targetField + ' IN :' + bindName);
                components.bindNames.add(bindName);
            }
        }

        return components;
    }

    /**
     * @description Builds a deterministic cache key from dynamic field criteria maps.
     * Iterates all entries in the string and date maps in sorted order to produce a
     * consistent key regardless of insertion order.
     * @param fieldCriteria Dynamic field-specific criteria values
     * @param excludeIds Optional set of Ids to include in the cache key (used by Lead query)
     * @return String cache key representing the unique combination of criteria
     */
    private static String buildCacheKey(FieldCriteriaValues fieldCriteria, Set<Id> excludeIds) {
        List<String> keyParts = new List<String>();

        // Add string criteria to key — fields sorted alphabetically, values sorted within each field
        Map<String, Set<String>> stringMap = fieldCriteria.getStringCriteriaMap();
        List<String> sortedFieldNames = new List<String>(stringMap.keySet());
        sortedFieldNames.sort();
        for (String fieldName : sortedFieldNames) {
            List<String> sortedValues = new List<String>(stringMap.get(fieldName));
            sortedValues.sort();
            keyParts.add(fieldName + ':' + String.join(sortedValues, ','));
        }

        // Add date criteria to key — same sorted approach
        Map<String, Set<Date>> dateMap = fieldCriteria.getDateCriteriaMap();
        List<String> sortedDateFieldNames = new List<String>(dateMap.keySet());
        sortedDateFieldNames.sort();
        for (String fieldName : sortedDateFieldNames) {
            List<String> sortedDates = new List<String>();
            for (Date d : dateMap.get(fieldName)) {
                sortedDates.add(String.valueOf(d));
            }
            sortedDates.sort();
            keyParts.add(fieldName + ':' + String.join(sortedDates, ','));
        }

        String key = String.join(keyParts, '|');

        if (excludeIds != null && !excludeIds.isEmpty()) {
            List<String> sortedIds = new List<String>();
            for (Id i : excludeIds) {
                sortedIds.add(String.valueOf(i));
            }
            sortedIds.sort();
            key += '|X:' + String.join(sortedIds, ',');
        }

        return key;
    }

    /**
     * @description Evaluates if Lead is a match
     * @param currentLead Current lead
     * @param potentialMatch Potential matching lead
     * @param criteria Matching criteria
     * @return MatchingCriteria if match found, null otherwise
     */
    public static LeadDuplicateMatchingService.MatchingCriteria evaluateLeadMatch(Lead currentLead, Lead potentialMatch, List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria) {
        return evaluateMatch(currentLead, potentialMatch, ConstantsUtil.LEAD_OBJECT, criteria);
    }

    /**
     * @description Evaluates if Account is a match
     * @param currentLead Current lead
     * @param potentialMatch Potential matching account
     * @param criteria Matching criteria
     * @return MatchingCriteria if match found, null otherwise
     */
    public static LeadDuplicateMatchingService.MatchingCriteria evaluateAccountMatch(Lead currentLead, Account potentialMatch, List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria) {
        return evaluateMatch(currentLead, potentialMatch, ConstantsUtil.ACCOUNT_OBJECT, criteria);
    }

    /**
     * @description Shared evaluation logic for both Lead and Account matches.
     * Compares source field values on the current lead against target field values on the
     * potential match record, filtered to criteria belonging to the specified target object.
     * @param currentLead Current lead being evaluated
     * @param potentialMatch Potential matching record (Lead or Account)
     * @param targetObjectName API name of the target object to filter criteria by
     * @param criteria Duplicate rule criteria defining field mappings
     * @return MatchingCriteria if at least one field matches, null otherwise
     */
    private static LeadDuplicateMatchingService.MatchingCriteria evaluateMatch(Lead currentLead, SObject potentialMatch, String targetObjectName, List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria) {
        Map<String, Boolean> fieldMatches = new Map<String, Boolean>();
        Boolean hasAnyMatch = false;

        for (LeadDuplicateMatchingService.DuplicateRuleCriteria criterion : criteria) {
            if (criterion.targetObject != targetObjectName) {
                continue;
            }

            Boolean shouldExclude = criterion.excludedSources.contains(currentLead.LeadSource);
            Object sourceValue = currentLead.get(criterion.sourceField);
            Object targetValue = potentialMatch.get(criterion.targetField);

            Boolean fieldsMatch = !shouldExclude && !isFieldValueBlank(sourceValue) &&
                                !isFieldValueBlank(targetValue) && (sourceValue == targetValue);

            fieldMatches.put(criterion.sourceField, fieldsMatch);
            if (fieldsMatch) {
                hasAnyMatch = true;
            }
        }

        if (!hasAnyMatch) {
            return null;
        }

        LeadDuplicateMatchingService.MatchingCriteria matchCriteria = new LeadDuplicateMatchingService.MatchingCriteria();
        matchCriteria.recordId = potentialMatch.Id;
        matchCriteria.recordType = targetObjectName;
        matchCriteria.fieldMatches = fieldMatches;
        matchCriteria.record = potentialMatch;

        return matchCriteria;
    }

    /**
     * @description Finds Lead matches from collected data
     * @param currentLead Current lead
     * @param matchData Collected data
     * @param criteria Matching criteria
     * @return List of Lead matches
     */
    public static List<LeadDuplicateMatchingService.MatchingCriteria> findLeadMatchesFromCollection(Lead currentLead, LeadDuplicateMatchingService.MatchDataContainer matchData, List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria) {
        List<LeadDuplicateMatchingService.MatchingCriteria> matches = new List<LeadDuplicateMatchingService.MatchingCriteria>();
        Set<Id> processedIds = new Set<Id>();

        for (Lead potentialMatch : matchData.allPotentialLeadMatches) {
            if (processedIds.contains(potentialMatch.Id)) {
                continue;
            }

            LeadDuplicateMatchingService.MatchingCriteria matchCriteria = evaluateLeadMatch(currentLead, potentialMatch, criteria);
            if (matchCriteria != null) {
                matches.add(matchCriteria);
                processedIds.add(potentialMatch.Id);
            }
        }

        return matches;
    }

    /**
     * @description Finds Account matches from collected data
     * @param currentLead Current lead
     * @param matchData Collected data
     * @param criteria Matching criteria
     * @return List of Account matches
     */
    public static List<LeadDuplicateMatchingService.MatchingCriteria> findAccountMatchesFromCollection(Lead currentLead, LeadDuplicateMatchingService.MatchDataContainer matchData, List<LeadDuplicateMatchingService.DuplicateRuleCriteria> criteria) {
        List<LeadDuplicateMatchingService.MatchingCriteria> matches = new List<LeadDuplicateMatchingService.MatchingCriteria>();

        for (Account potentialMatch : matchData.allPotentialAccountMatches) {
            LeadDuplicateMatchingService.MatchingCriteria matchCriteria = evaluateAccountMatch(currentLead, potentialMatch, criteria);
            if (matchCriteria != null) {
                matches.add(matchCriteria);
            }
        }

        return matches;
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
}