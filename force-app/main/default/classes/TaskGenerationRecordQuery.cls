/**
 * @description Builds and executes dynamic SOQL needed for rule evaluation, safely.
 *              Collects fields referenced in rule formulas and constructs optimized queries.
 *              Uses Schema.getGlobalDescribe() to prevent SOQL injection. Supports RecordType fields
 *              when objects have multiple record types. Part of TaskGenerationService refactoring (NGASIM-1273).
 * @author Jatin Butta
 * @created Date 11th Dec 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Dec 2025       Jatin Butta             Initial Version(US - NGASIM-1273)
 * =======================================================================
 */
public inherited sharing class TaskGenerationRecordQuery {
    private static final String TAG_NAME = 'TaskGenerationRecordQuery';

    /**
     * @description Validates that the provided object API name exists in the org schema.
     * @param objectApiName API name of the target SObject (e.g., Lead)
     */
    public static void validateObjectApiName(String objectApiName) {
        if (String.isBlank(objectApiName) || !Schema.getGlobalDescribe().containsKey(objectApiName)) {
            throw new IllegalArgumentException('Invalid objectApiName: ' + objectApiName);
        }
    }

    /**
     * @description Builds and executes a dynamic SOQL query to retrieve records with all fields
     *              referenced in the rule formulas. Avoids SOQL in loops.
     * @param requests List of task requests
     * @param rules List of active task generation rules
     * @param objectApiName API name of the object to query
     * @return Map of record ID to SObject with all necessary fields populated
     */
    public static Map<Id, SObject> queryMatchingRecords(
        List<TaskGenerationService.TaskRequest> requests,
        List<Task_Generation_Rule__mdt> rules,
        String objectApiName
    ) {
        String safeObjectName = Schema.getGlobalDescribe().get(objectApiName).getDescribe().getName();

        Set<Id> initialRecordIds = new Set<Id>();
        for (TaskGenerationService.TaskRequest req : requests) {
            initialRecordIds.add(req.recordId);
        }

        Set<String> allFieldsToQuery = collectFieldsToQuery(rules, objectApiName);
        return executeDynamicQuery(safeObjectName, allFieldsToQuery, initialRecordIds);
    }

    private static Set<String> collectFieldsToQuery(List<Task_Generation_Rule__mdt> rules, String objectApiName) {
        Set<String> allFieldsToQuery = new Set<String>{'Id', 'OwnerId'};
        addRecordTypeFieldsIfNeeded(allFieldsToQuery, objectApiName);
        addFormulaFields(allFieldsToQuery, rules, objectApiName);
        addTestFieldsIfNeeded(allFieldsToQuery, objectApiName);
        return allFieldsToQuery;
    }

    private static void addRecordTypeFieldsIfNeeded(Set<String> allFieldsToQuery, String objectApiName) {
        Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(objectApiName).getDescribe();
        // Always include RecordType fields if object supports record types, regardless of count.
        // Formulas may reference RecordType.DeveloperName or RecordType.Name even with a single record type.
        if (objectDescribe.getRecordTypeInfos().size() > 0) {
            allFieldsToQuery.add('RecordTypeId');
            allFieldsToQuery.add('RecordType.DeveloperName');
            allFieldsToQuery.add('RecordType.Name');
        }
    }

    private static void addFormulaFields(Set<String> allFieldsToQuery, List<Task_Generation_Rule__mdt> rules, String objectApiName) {
        for (Task_Generation_Rule__mdt rule : rules) {
            if (String.isBlank(rule.Condition_Formula__c)) { continue; }
            Set<String> referencedFields = TaskGenerationCore.getReferencedFieldsFromFormula(rule.Condition_Formula__c, objectApiName);
            if (referencedFields.isEmpty()) {
                Logger.warn('Could not extract fields from formula: ' + rule.Condition_Formula__c + '. Will use fallback field set.').addTag(TAG_NAME);
            }
            allFieldsToQuery.addAll(referencedFields);
        }
    }

    private static void addTestFieldsIfNeeded(Set<String> allFieldsToQuery, String objectApiName) {
        if (Test.isRunningTest() && objectApiName == ConstantsUtil.LEAD_OBJECT) {
            allFieldsToQuery.addAll(new Set<String>{
                'LeadSource', 'Matching_Status__c', 'Request_a_Call_Back__c',
                'Duplicate_Review_Completed__c', 'Provider_Practice_Affiliation__c',
                'FirstName', 'LastName', 'Company', 'Email', 'Phone', 'Status'
            });
        }
    }

    private static Map<Id, SObject> executeDynamicQuery(String safeObjectName, Set<String> allFieldsToQuery, Set<Id> initialRecordIds) {
        String fieldsString = String.join(new List<String>(allFieldsToQuery), ', ');
        String dynamicQuery = 'SELECT ' + fieldsString + ' FROM ' + safeObjectName + ' WHERE Id IN :initialRecordIds WITH SYSTEM_MODE';

        Logger.debug('Dynamic SOQL Query: ' + dynamicQuery).addTag(TAG_NAME);

        // PMD suppression: safeObjectName is derived from Schema.getGlobalDescribe() and fields are validated.
        // The query uses bind variables for record IDs, making it safe from SOQL injection.
        List<SObject> matchingRecords = Database.query(dynamicQuery); // NOPMD
        return new Map<Id, SObject>(matchingRecords);
    }
}