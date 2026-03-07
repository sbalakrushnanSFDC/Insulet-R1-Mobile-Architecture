/**
 * @description Service class to handle Lead conversion precheck logic.
 *              Validates lead fields against metadata-driven rules before conversion.
 * @author      Priyansh Shukla
 * @created Date: 15th Dec 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       15th Dec 2025       Priyansh Shukla         Initial Version(US - NGASIM-1163)
 * V1.0.1       21st Jan 2026       Bijayalaxmi Prusty      Updated(US - NGASIM-1885)
 */
public with sharing class LeadConversionPrecheckService {

    // Cache for queryLeadWithFields results
    private static Map<String, Lead> leadQueryCache = new Map<String, Lead>();

    // Cache for queryLeadsWithFields results
    private static Map<String, Map<Id, Lead>> leadsQueryCache = new Map<String, Map<Id, Lead>>();

    /**
     * @description Result wrapper for precheck validation
     */
    public class PrecheckResult {
        @AuraEnabled public Boolean ok;
        @AuraEnabled public List<String> messages;

        /**
         * @description Constructor
         * @param ok Whether prechecks passed
         * @param messages List of error messages if any
         */
        public PrecheckResult(Boolean ok, List<String> messages) {
            this.ok = ok;
            this.messages = messages;
        }
    }

    /**
     * @description Result wrapper for precheck validation of lead collections
     */
    public class PrecheckCollectionResult {
        public List<Lead> successLeads;
        public List<Id> failedLeadIds;
        public Map<Id, List<String>> leadIdToMessages;

        /**
         * @description Constructor
         * @param successLeads List of Lead records that passed prechecks
         * @param failedLeadIds List of lead IDs that failed prechecks
         * @param leadIdToMessages Map of lead ID to error messages
         */
        public PrecheckCollectionResult(List<Lead> successLeads, List<Id> failedLeadIds, Map<Id, List<String>> leadIdToMessages) {
            this.successLeads = successLeads;
            this.failedLeadIds = failedLeadIds;
            this.leadIdToMessages = leadIdToMessages;
        }
    }

    /**
     * @description Gets active precheck rules for a given record type
     * @param recordTypeDeveloperName Developer name of the record type
     * @param conversionType Conversion type to filter rules (Manual, Auto, or Both)
     * @return List of active precheck rules
     */
    @AuraEnabled(cacheable=true)
    public static List<Lead_Conversion_Precheck__mdt> getActiveRules(String recordTypeDeveloperName, String conversionType) {
        String soql = 'SELECT Condition_Field__c, ' +
                      'Condition_Operator__c, ' +
                      'Condition_Value__c, ' +
                      'Error_Label__c, ' +
                      'Field_Name__c, ' +
                      'Field_Category__c, ' +
                      'Requirement_Type__c, ' +
                      'Conversion_Type__c, ' +
                      'Record_Type__c ' +
                      'FROM Lead_Conversion_Precheck__mdt ' +
                      'WHERE Status__c = \'Active\' ' +
                      'AND (Object_Name__c = \'Lead\' OR Object_Name__c = NULL) ' +
                      'AND (Record_Type__c = :recordTypeDeveloperName OR Record_Type__c = NULL)';

        if (String.isNotBlank(conversionType)) {
            String escapedConversionType = String.escapeSingleQuotes(conversionType);
            soql += ' AND (Conversion_Type__c = \'' + escapedConversionType + '\' OR Conversion_Type__c = \'' + ConstantsUtil.CONVERSION_TYPE_BOTH + '\')';
        }

        soql += ' WITH USER_MODE';

        return Database.query(soql);//NOPMD(escaped single quotes for all passed variable , static code analysis is giving false positive error)
    }

    /**
     * @description Runs prechecks for a lead conversion
     * @param leadId ID of the lead to check
     * @param conversionType Conversion type to filter rules (Manual, Auto, or Both)
     * @return PrecheckResult with validation status and messages
     */
    @AuraEnabled
    public static PrecheckResult runPrechecks(Id leadId, String conversionType) {
        if (leadId == null) {
            return new PrecheckResult(false, new List<String>{'Lead Id is required.'});
        }

        Lead leadWithRt = [
            SELECT Id, RecordType.DeveloperName, Date_of_Birth__c
            FROM Lead
            WHERE Id = :leadId
            WITH USER_MODE
            LIMIT 1
        ];

        List<Lead_Conversion_Precheck__mdt> rules = getActiveRules(leadWithRt.RecordType?.DeveloperName, conversionType);
        if (rules.isEmpty()) {
            return new PrecheckResult(true, new List<String>());
        }

        Set<String> fieldNames = collectFieldNames(rules);
        fieldNames.add('LeadSource');
        Lead leadRecord = queryLeadWithFields(leadId, fieldNames);

        rules = filterAddressVerificationRules(rules, leadRecord);

        if (rules.isEmpty()) {
            return new PrecheckResult(true, new List<String>());
        }

        Map<String, Object> ctx = LeadConversionPrecheckServiceHelper.buildContext(leadRecord);
        List<String> missing = LeadConversionPrecheckServiceHelper.evaluateRules(rules, ctx);
        List<String> groupedMessages = formatGroupedMessages(missing, rules);

        return new PrecheckResult(groupedMessages.isEmpty(), groupedMessages);
    }

    /**
     * @description Runs prechecks for lead collection conversion (Trigger compatible)
     * @param leads List of Lead records to check
     * @param conversionType Conversion type to filter rules (Manual, Auto, or Both)
     * @return PrecheckCollectionResult with success leads (full objects) and failed lead IDs
     */
    public static PrecheckCollectionResult runPrechecksForLeads(List<Lead> leads, String conversionType) {
        PrecheckCollectionResult result = new PrecheckCollectionResult(
            new List<Lead>(),
            new List<Id>(),
            new Map<Id, List<String>>()
        );

        if (leads == null || leads.isEmpty()) {
            return result;
        }

        Set<Id> leadIds = getLeadIds(leads);
        Map<Id, String> leadIdToRecordTypeDevName = LeadConversionPrecheckServiceHelper.getLeadIdToRecordTypeMap(leads);
        Map<String, List<Lead>> leadsByRecordType = groupLeadsByRecordType(leads, leadIdToRecordTypeDevName);

        List<Lead_Conversion_Precheck__mdt> allRules = getActiveRulesForRecordTypes(leadsByRecordType.keySet(), conversionType);
        Map<String, List<Lead_Conversion_Precheck__mdt>> rulesByRecordType = groupRulesByRecordType(allRules);

        Set<String> allFieldNames = collectFieldNames(allRules);
        allFieldNames.add('LeadSource');

        Map<Id, Lead> leadMap = queryLeadsWithFields(leadIds, allFieldNames);

        if (allRules.isEmpty()) {
            result.successLeads.addAll(leadMap.values());
            return result;
        }

        LeadProcessingContext context = new LeadProcessingContext();
        context.leadMap = leadMap;
        context.leadIdToRecordTypeDevName = leadIdToRecordTypeDevName;
        context.rulesByRecordType = rulesByRecordType;
        context.result = result;
        processLeadsForPrechecks(leads, context);

        return result;
    }

    /**
     * @description Wrapper class for lead processing context
     */
    private class LeadProcessingContext {
        Map<Id, Lead> leadMap;
        Map<Id, String> leadIdToRecordTypeDevName;
        Map<String, List<Lead_Conversion_Precheck__mdt>> rulesByRecordType;
        PrecheckCollectionResult result;
    }

    /**
     * @description Processes leads for precheck validation
     * @param leads List of Lead records
     * @param context Lead processing context
     */
    private static void processLeadsForPrechecks(List<Lead> leads, LeadProcessingContext context) {
        for (Lead lead : leads) {
            processSingleLead(lead, context);
        }
    }

    /**
     * @description Processes a single lead for precheck validation
     * @param lead Lead record
     * @param context Lead processing context
     */
    private static void processSingleLead(Lead lead, LeadProcessingContext context) {
        Lead leadRecord = context.leadMap.get(lead.Id);
        if (leadRecord == null) {
            addFailedLead(lead.Id, 'Lead record not found.', context.result);
            return;
        }

        String rtDevName = context.leadIdToRecordTypeDevName.get(lead.Id);
        List<Lead_Conversion_Precheck__mdt> rules = getRulesForRecordType(rtDevName, context.rulesByRecordType);
        rules = filterAddressVerificationRules(rules, leadRecord);

        if (rules.isEmpty()) {
            context.result.successLeads.add(leadRecord);
            return;
        }

        List<String> groupedMessages = LeadConversionPrecheckServiceHelper.evaluateLeadAgainstRules(leadRecord, rules);

        if (groupedMessages.isEmpty()) {
            context.result.successLeads.add(leadRecord);
        } else {
            addFailedLead(lead.Id, groupedMessages, context.result);
        }
    }

    /**
     * @description Adds failed lead to result
     * @param leadId Lead ID
     * @param messages Error messages
     * @param result PrecheckCollectionResult to update
     */
    private static void addFailedLead(Id leadId, List<String> messages, PrecheckCollectionResult result) {
        result.failedLeadIds.add(leadId);
        result.leadIdToMessages.put(leadId, messages);
    }

    /**
     * @description Adds failed lead to result with single message
     * @param leadId Lead ID
     * @param message Error message
     * @param result PrecheckCollectionResult to update
     */
    private static void addFailedLead(Id leadId, String message, PrecheckCollectionResult result) {
        addFailedLead(leadId, new List<String>{message}, result);
    }

    /**
     * @description Queries Lead with validated field names
     * @param leadId Lead ID to query
     * @param fieldNames Set of field names to query
     * @return Lead record
     */
    @TestVisible
    private static Lead queryLeadWithFields(Id leadId, Set<String> fieldNames) {
        if (leadId == null) {
            return null;
        }

        List<String> sortedFields = new List<String>(fieldNames);
        sortedFields.sort();
        String cacheKey = leadId + '|' + String.join(sortedFields, ',');

        if (leadQueryCache.containsKey(cacheKey)) {
            return leadQueryCache.get(cacheKey);
        }

        List<String> validatedFields = validateFieldNames(fieldNames);
        String rawFieldList = validatedFields.isEmpty() ? 'Id' : String.join(validatedFields, ',');
        String fieldList = String.escapeSingleQuotes(rawFieldList);

        String soql = 'SELECT ' + fieldList + ' FROM Lead WHERE Id = :leadId WITH USER_MODE LIMIT 1';

        Lead leadRecord = Database.query(soql);//NOPMD(escaped single quotes for all passed variable , static code analysis is giving false positive error)

        leadQueryCache.put(cacheKey, leadRecord);

        return leadRecord;
    }

    /**
     * @description Queries multiple Leads with validated field names (bulkified)
     * @param leadIds Set of Lead IDs to query
     * @param fieldNames Set of field names to query
     * @return Map of Lead ID to Lead record
     */
    @TestVisible
    private static Map<Id, Lead> queryLeadsWithFields(Set<Id> leadIds, Set<String> fieldNames) {
        if (leadIds == null || leadIds.isEmpty()) {
            return new Map<Id, Lead>();
        }

        List<Id> sortedLeadIds = new List<Id>(leadIds);
        sortedLeadIds.sort();
        List<String> sortedFields = new List<String>(fieldNames);
        sortedFields.sort();
        String cacheKey = String.join(sortedLeadIds, ',') + '|' + String.join(sortedFields, ',');

        if (leadsQueryCache.containsKey(cacheKey)) {
            return leadsQueryCache.get(cacheKey);
        }

        List<String> validatedFields = validateFieldNames(fieldNames);
        String rawFieldList = validatedFields.isEmpty() ? 'Id' : String.join(validatedFields, ',');
        String fieldList = String.escapeSingleQuotes(rawFieldList);

        String soql = 'SELECT ' + fieldList + ' FROM Lead WHERE Id IN :leadIds WITH USER_MODE';

        List<Lead> leads = Database.query(soql);//NOPMD(escaped single quotes for all passed variable , static code analysis is giving false positive error)
        Map<Id, Lead> leadMap = new Map<Id, Lead>(leads);
        leadsQueryCache.put(cacheKey, leadMap);

        return leadMap;
    }

    /**
     * @description Filters out address verification rules if LeadSource = "Get started"
     * @param rules List of precheck rules
     * @param leadRecord Lead record to check LeadSource
     * @return Filtered list of rules (address verification rules removed if LeadSource = "Get started")
     */
    @TestVisible
    private static List<Lead_Conversion_Precheck__mdt> filterAddressVerificationRules(List<Lead_Conversion_Precheck__mdt> rules, Lead leadRecord) {
        if (rules == null || rules.isEmpty()) {
            return rules;
        }

        String leadSource = (String)leadRecord.get(ConstantsUtil.LEAD_SOURCE);
        if (leadSource == null || !leadSource.equalsIgnoreCase(ConstantsUtil.LEAD_SOURCE_GET_STARTED)) {
            return rules;
        }

        List<Lead_Conversion_Precheck__mdt> filteredRules = new List<Lead_Conversion_Precheck__mdt>();
        for (Lead_Conversion_Precheck__mdt rule : rules) {
            if (String.isBlank(rule.Field_Category__c) ||
                !rule.Field_Category__c.equalsIgnoreCase(ConstantsUtil.METADATA_FIELD_CATEGORY_ADDRESS_INFORMATION)) {
                filteredRules.add(rule);
            }
        }
        return filteredRules;
    }

    /**
     * @description Gets active precheck rules for record types and conversion type
     * @param recordTypeDeveloperNames Set of record type developer names
     * @param conversionType Conversion type to filter rules (Manual, Auto, or Both)
     * @return List of active precheck rules
     */
    public static List<Lead_Conversion_Precheck__mdt> getActiveRulesForRecordTypes(Set<String> recordTypeDeveloperNames, String conversionType) {
        return buildAndExecuteQuery(recordTypeDeveloperNames, conversionType);
    }

    /**
     * @description Gets rules applicable to a specific record type (includes global rules)
     * @param recordTypeDevName RecordType DeveloperName
     * @param rulesByRecordType Map of RecordType to List of rules
     * @return List of applicable rules
     */
    public static List<Lead_Conversion_Precheck__mdt> getRulesForRecordType(String recordTypeDevName, Map<String, List<Lead_Conversion_Precheck__mdt>> rulesByRecordType) {
        List<Lead_Conversion_Precheck__mdt> rules = new List<Lead_Conversion_Precheck__mdt>();

        List<Lead_Conversion_Precheck__mdt> recordTypeRules = rulesByRecordType.get(recordTypeDevName);
        if (recordTypeRules != null) {
            rules.addAll(recordTypeRules);
        }

        List<Lead_Conversion_Precheck__mdt> globalRules = rulesByRecordType.get(null);
        if (globalRules != null) {
            rules.addAll(globalRules);
        }

        return rules;
    }

    /**
     * @description Gets set of lead IDs from list of leads
     * @param leads List of Lead records
     * @return Set of Lead IDs
     */
    private static Set<Id> getLeadIds(List<Lead> leads) {
        Set<Id> leadIds = new Set<Id>();
        for (Lead lead : leads) {
            leadIds.add(lead.Id);
        }
        return leadIds;
    }

    /**
     * @description Groups leads by their RecordType DeveloperName
     * @param leads List of Lead records
     * @param leadIdToRecordTypeDevName Map of Lead ID to RecordType DeveloperName
     * @return Map of RecordType DeveloperName to List of Leads
     */
    private static Map<String, List<Lead>> groupLeadsByRecordType(List<Lead> leads, Map<Id, String> leadIdToRecordTypeDevName) {
        Map<String, List<Lead>> leadsByRecordType = new Map<String, List<Lead>>();
        for (Lead lead : leads) {
            String rtDevName = leadIdToRecordTypeDevName.get(lead.Id);
            if (!leadsByRecordType.containsKey(rtDevName)) {
                leadsByRecordType.put(rtDevName, new List<Lead>());
            }
            leadsByRecordType.get(rtDevName).add(lead);
        }
        return leadsByRecordType;
    }

    /**
     * @description Groups rules by RecordType DeveloperName
     * @param rules List of precheck rules
     * @return Map of RecordType DeveloperName to List of rules
     */
    private static Map<String, List<Lead_Conversion_Precheck__mdt>> groupRulesByRecordType(List<Lead_Conversion_Precheck__mdt> rules) {
        Map<String, List<Lead_Conversion_Precheck__mdt>> rulesByRecordType = new Map<String, List<Lead_Conversion_Precheck__mdt>>();
        for (Lead_Conversion_Precheck__mdt rule : rules) {
            String rtDevName = rule.Record_Type__c;
            if (!rulesByRecordType.containsKey(rtDevName)) {
                rulesByRecordType.put(rtDevName, new List<Lead_Conversion_Precheck__mdt>());
            }
            rulesByRecordType.get(rtDevName).add(rule);
        }
        return rulesByRecordType;
    }

    /**
     * @description Validates field names are valid Lead fields
     * @param fieldNames Set of field names to validate
     * @return List of validated field names
     */
    @TestVisible
    private static List<String> validateFieldNames(Set<String> fieldNames) {
        List<String> validatedFields = new List<String>();
        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();

        for (String fieldName : fieldNames) {
            if (isValidFieldName(fieldName, leadFields)) {
                validatedFields.add(fieldName);
            }
        }
        return validatedFields;
    }

    /**
     * @description Checks if a field name is valid for Lead object
     * @param fieldName Field name to validate
     * @param leadFields Map of Lead field names to Schema.SObjectField
     * @return Boolean indicating if field name is valid
     */
    private static Boolean isValidFieldName(String fieldName, Map<String, Schema.SObjectField> leadFields) {
        if (String.isBlank(fieldName)) {
            return false;
        }
        String lowerFieldName = fieldName.toLowerCase();
        return leadFields.containsKey(lowerFieldName) || fieldName == 'Id' || fieldName.contains('__r.') || fieldName.contains('.');
    }

    /**
     * @description Formats error messages by removing duplicates
     * @param missingLabels List of missing field labels
     * @param rules List of precheck rules (not used but kept for signature compatibility)
     * @return List of formatted error messages without duplicates
     */
    private static List<String> formatGroupedMessages(List<String> missingLabels, List<Lead_Conversion_Precheck__mdt> rules) {
        Set<String> uniqueMessages = new Set<String>();
        for (String label : missingLabels) {
            if (String.isNotBlank(label)) {
                uniqueMessages.add(label);
            }
        }
        return new List<String>(uniqueMessages);
    }

    /**
     * @description Collects field names needed for SOQL query from rules
     * @param rules List of precheck rules
     * @return Set of field API names
     */
    private static Set<String> collectFieldNames(List<Lead_Conversion_Precheck__mdt> rules) {
        Set<String> fieldNames = new Set<String>{'Id', 'Date_of_Birth__c'};
        for (Lead_Conversion_Precheck__mdt rule : rules) {
            if (String.isNotBlank(rule.Field_Name__c)) {
                fieldNames.add(rule.Field_Name__c);
            }
            if (String.isNotBlank(rule.Condition_Field__c) && rule.Condition_Field__c != 'age') {
                fieldNames.add(rule.Condition_Field__c);
            }
        }
        return fieldNames;
    }

    /**
     * @description Builds and executes SOQL query for precheck rules
     * @param recordTypeDeveloperNames Set of record type developer names
     * @param conversionType Conversion type to filter rules
     * @return List of active precheck rules
     */
    private static List<Lead_Conversion_Precheck__mdt> buildAndExecuteQuery(Set<String> recordTypeDeveloperNames, String conversionType) {
        String soql = buildBaseSoqlQuery();
        soql = addRecordTypeFilter(soql, recordTypeDeveloperNames);
        soql = addConversionTypeFilter(soql, conversionType);
        soql += ' WITH USER_MODE';

        return Database.query(soql);//NOPMD(escaped single quotes for all passed variable , static code analysis is giving false positive error)
    }

    /**
     * @description Builds base SOQL query for precheck rules
     * @return Base SOQL query string
     */
    private static String buildBaseSoqlQuery() {
        return 'SELECT Condition_Field__c, ' +
               'Condition_Operator__c, ' +
               'Condition_Value__c, ' +
               'Error_Label__c, ' +
               'Field_Name__c, ' +
               'Field_Category__c, ' +
               'Requirement_Type__c, ' +
               'Conversion_Type__c, ' +
               'Record_Type__c ' +
               'FROM Lead_Conversion_Precheck__mdt ' +
               'WHERE Status__c = \'Active\' ' +
               'AND (Object_Name__c = \'Lead\' OR Object_Name__c = NULL)';
    }

    /**
     * @description Adds record type filter to SOQL query
     * @param soql Current SOQL query string
     * @param recordTypeDeveloperNames Set of record type developer names
     * @return SOQL query with record type filter added
     */
    private static String addRecordTypeFilter(String soql, Set<String> recordTypeDeveloperNames) {
        Set<String> nonNullRecordTypes = getNonNullRecordTypes(recordTypeDeveloperNames);

        if (!nonNullRecordTypes.isEmpty()) {
            List<String> escapedRecordTypes = escapeRecordTypes(nonNullRecordTypes);
            String inClause = String.join(escapedRecordTypes, ',');
            soql += ' AND (Record_Type__c IN (' + inClause + ') OR Record_Type__c = NULL)';
        }

        return soql;
    }

    /**
     * @description Escapes record type names for SOQL query
     * @param recordTypes Set of record type developer names
     * @return List of escaped record type strings
     */
    private static List<String> escapeRecordTypes(Set<String> recordTypes) {
        List<String> escapedRecordTypes = new List<String>();
        for (String rt : recordTypes) {
            escapedRecordTypes.add('\'' + String.escapeSingleQuotes(rt) + '\'');
        }
        return escapedRecordTypes;
    }

    /**
     * @description Filters out null values from record type set
     * @param recordTypeDeveloperNames Set of record type developer names
     * @return Set of non-null record type developer names
     */
    private static Set<String> getNonNullRecordTypes(Set<String> recordTypeDeveloperNames) {
        Set<String> nonNullRecordTypes = new Set<String>();
        if (recordTypeDeveloperNames == null) {
            return nonNullRecordTypes;
        }
        for (String rt : recordTypeDeveloperNames) {
            if (String.isNotBlank(rt)) {
                nonNullRecordTypes.add(rt);
            }
        }
        return nonNullRecordTypes;
    }

    /**
     * @description Adds conversion type filter to SOQL query
     * @param soql Current SOQL query string
     * @param conversionType Conversion type to filter
     * @return SOQL query with conversion type filter added
     */
    private static String addConversionTypeFilter(String soql, String conversionType) {
        if (String.isNotBlank(conversionType)) {
            String escapedConversionType = String.escapeSingleQuotes(conversionType);
            soql += ' AND (Conversion_Type__c = \'' + escapedConversionType + '\' OR Conversion_Type__c = \'' + ConstantsUtil.CONVERSION_TYPE_BOTH + '\')';
        }
        return soql;
    }
}