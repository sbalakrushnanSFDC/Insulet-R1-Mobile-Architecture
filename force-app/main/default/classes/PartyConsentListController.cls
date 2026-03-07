/**
 * @author      : Yogesh Rana
 * @created Date: 26th December 2025
 * @description : PartyListController class is used to fetch the related records for the Party Consents related list.
 *                Runs in 'without sharing' mode as per requirement in NGOMCT-1278, NGOMCT-1280.
 * =========================== Logs ======================================
 * Version      Modified Date            Modified By             Brief Note
 * V1.0.0       26th December 2025       Yogesh Rana            Initial Version
 */
public without sharing class PartyConsentListController {
    private static final String DEFAULT_SORT_DIRECTION = 'DESC';
    private static final Integer DEFAULT_RECORD_LIMIT = 10;
    private static final Schema.DisplayType DEFAULT_DISPLAY_TYPE = Schema.DisplayType.STRING;

    private static Map<String, Schema.DescribeSObjectResult> describeCache = new Map<String, Schema.DescribeSObjectResult>();

    /**
     * @description Used to fetch the related records for the Party Consents related list.
     * @param request RelatedListRequest wrapper containing all query parameters:
     *               - accountId: Id of the Account record (used to fetch IndividualId)
     *               - childObjectApi: API name of the child object
     *               - relationshipField: Lookup field name on child object
     *               - fields: Comma-separated field list (supports nested fields)
     *               - sortedBy: Field name for sorting
     *               - sortDirection: ASC or DESC
     *               - recordLimit: Maximum number of records to return
     *               - typeFilter: Comma-separated Type__c picklist values for filtering
     * @param refreshApex String parameter used by the framework to force cache refresh when cacheable=true
     * @return Map containing:
     *         - 'records': List<SObject> - The queried records
     *         - 'fieldTypes': Map<String,String> - Field names mapped to their display types
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRelatedRecordsWithTypes(RelatedListRequest request, String refreshApex) {
        Map<String, Object> result = new Map<String, Object>{
            'records' => new List<SObject>(),
            'fieldTypes' => new Map<String, String>()
        };
        try{
            if (!validateRequest(request)) {
                throw new AuraHandledException('Invalid request parameters');
            }

            Id parentId = getIndividualIdByAccountId(request.accountId);
            if (parentId == null) {
                Logger.error('PartyConsentListController.getRelatedRecordsWithTypes', 'Account does not have a Individual Record associated with it');
                Logger.saveLog();
                return result;
            }

            Schema.SObjectType childObjType = Schema.getGlobalDescribe().get(request.childObjectApi);
            if (childObjType == null) {
                Logger.error('PartyConsentListController.getRelatedRecordsWithTypes', 'Invalid child object API name: ' + request.childObjectApi);
                Logger.saveLog();
                return result;
            }

            // build the SOQL query string
            String soql = buildSoqlQueryString(request);
            if (String.isBlank(soql)){
                return result;
            }

            result.put('records', queryRelatedRecords(soql, parentId, request.typeFilter));
            result.put('fieldTypes', getFieldTypesByFieldNames(request.fields, childObjType));
        } catch (Exception e) {
            Logger.error('Error while fetching related records', e)
                .addTag('PartyConsentListController');
            Logger.saveLog();
            throw new AuraHandledException('Error fetching related records: ' + e.getMessage());
        }
        return result;
    }

    /**
     * @description Validates the RelatedListRequest object to ensure all required fields are present
     * @param req RelatedListRequest object to validate
     * @return Boolean true if request is valid, false otherwise
     */
    private static Boolean validateRequest(RelatedListRequest req) {
        return req != null
            && req.accountId != null
            && !String.isBlank(req.fields)
            && !String.isBlank(req.childObjectApi)
            && !String.isBlank(req.relationshipField);
    }

    /**
     * @description Queries related records using dynamic SOQL with bind variables
     * @param soql SOQL query string with bind variable placeholders
     * @param parentId The parent record Id to bind to :parentId
     * @param typeFilter Comma-separated Type__c values to filter by (optional)
     * @return List<SObject> The queried records
     */
    private static List<SObject> queryRelatedRecords(String soql, Id parentId, String typeFilter) {
        Map<String, Object> bindVars = new Map<String, Object>{ 'parentId' => parentId };
        if (String.isNotBlank(typeFilter)) {
            bindVars.put('typeValues', sanitizeTypeFilterValues(typeFilter));
        }

        // Test support: Inject exception for test coverage when flag is enabled
        Utility.throwExceptionForTestCoverage();
        return Database.queryWithBinds(soql, bindVars, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Builds dynamic SOQL query string based on request parameters
     * @param req RelatedListRequest containing query parameters
     * @return SOQL query string with bind variable placeholders (:parentId, :typeValues)
     */
    private static String buildSoqlQueryString(RelatedListRequest req) {
        String sortDir = String.isNotBlank(req.sortDirection) ? req.sortDirection.toUpperCase() : DEFAULT_SORT_DIRECTION;
        Integer limitSize = req.recordLimit != null ? req.recordLimit : DEFAULT_RECORD_LIMIT;

        String soql =
            'SELECT ' + req.fields +
            ' FROM ' + req.childObjectApi +
            ' WHERE ' + req.relationshipField + ' = :parentId';

        if (String.isNotBlank(req.typeFilter)) {
            soql += ' AND Type__c IN :typeValues';
        }

        if (String.isNotBlank(req.sortedBy)) {
            soql += ' ORDER BY ' + req.sortedBy + ' ' + sortDir;
        }

        soql += ' LIMIT ' + limitSize;
        return soql;
    }

    /**
     * @description Gets field display types for all fields in the field list
     * Handles both direct fields and nested relationship fields
     * @param fields Comma-separated field list
     * @param childObjType Child object Schema type
     * @return Map of field names to their display types
     */
    @TestVisible
    private static Map<String, String> getFieldTypesByFieldNames(String fields, Schema.SObjectType childObjType) {
        Map<String, String> fieldTypes = new Map<String, String>();

        Schema.DescribeSObjectResult baseDescribe = getObjectDescribeResult(childObjType);
        Map<String, Schema.SObjectField> baseFieldMap = baseDescribe.fields.getMap();

        for (String rawField : fields.split(',')) {
            String fieldName = rawField.trim();
            if (String.isBlank(fieldName)){
                continue;
            }

            Schema.DisplayType displayType = fieldName.contains('.') ? getRelationshipFieldDisplayType(fieldName, baseFieldMap) : getDirectFieldDisplayType(fieldName, baseFieldMap);
            fieldTypes.put(fieldName, String.valueOf(displayType));
        }
        return fieldTypes;
    }

    /**
     * @description Gets display type for direct fields on the child object
     * Returns the field's display type from schema, or DEFAULT_DISPLAY_TYPE if field not found
     * @param fieldName The field name to resolve
     * @param fieldMap Map of field names to Schema.SObjectField objects
     * @return Display type of the field, or DEFAULT_DISPLAY_TYPE if not found
     */
    @TestVisible
    private static Schema.DisplayType getDirectFieldDisplayType(String fieldName, Map<String, Schema.SObjectField> fieldMap) {
        return fieldMap.containsKey(fieldName)
            ? fieldMap.get(fieldName).getDescribe().getType()
            : DEFAULT_DISPLAY_TYPE;
    }

    /**
     * @description Gets display type for nested relationship fields
     * Resolves the display type by traversing the relationship field to the related object
     * @param fullFieldName e.g. 'DataUsePurpose.Name' or 'CustomLookup__r.CustomField__c'
     * @param baseFieldMap Map of child object fields
     * @return Display type of the nested field, or DEFAULT_DISPLAY_TYPE if not found
     */
    @TestVisible
    private static Schema.DisplayType getRelationshipFieldDisplayType(String fullFieldName, Map<String, Schema.SObjectField> baseFieldMap) {
        List<String> parts = fullFieldName.split('\\.', 2);
        if (parts.size() != 2){
            return DEFAULT_DISPLAY_TYPE;
        }

        String relationshipName = parts[0].replace('__r', '');
        String relatedFieldName = parts[1];
        Schema.SObjectField relationshipField;

        // find the actual lookup field matching the relationshipName
        for (String fieldApi : baseFieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = baseFieldMap.get(fieldApi).getDescribe();
            for (Schema.SObjectType refType : dfr.getReferenceTo()) {
                if (refType.getDescribe().getName() == relationshipName) {
                    relationshipField = baseFieldMap.get(fieldApi);
                    break;
                }
            }
            if (relationshipField != null){
                break;
            }
        }

        if (relationshipField == null) {
            return DEFAULT_DISPLAY_TYPE;
        }

        for (Schema.SObjectType refType : relationshipField.getDescribe().getReferenceTo()) {
            Map<String, Schema.SObjectField> refFieldMap = getObjectDescribeResult(refType).fields.getMap();
            if (refFieldMap.containsKey(relatedFieldName)) {
                return refFieldMap.get(relatedFieldName).getDescribe().getType();
            }
        }

        return DEFAULT_DISPLAY_TYPE;
    }

    /**
     * @description Gets Schema.DescribeSObjectResult for an object type using caching
     * Uses cache to avoid repeated describe calls for better performance
     * @param objType The Schema.SObjectType to describe
     * @return Cached describe result
     */
    private static Schema.DescribeSObjectResult getObjectDescribeResult(Schema.SObjectType objType) {
        String key = String.valueOf(objType);
        if (!describeCache.containsKey(key)) {
            describeCache.put(key, objType.getDescribe());
        }
        return describeCache.get(key);
    }

    /**
     * @description Sanitizes comma-separated Type__c filter values
     * Removes blank values and trims whitespace from each value
     * @param values Comma-separated string of values
     * @return List of sanitized, non-blank values
     */
    private static List<String> sanitizeTypeFilterValues(String values) {
        List<String> sanitized = new List<String>();
        for (String v : values.split(',')) {
            if (String.isNotBlank(v)){
                sanitized.add(v.trim());
            }
        }
        return sanitized;
    }

    /**
     * @description Gets PersonIndividualId from an Account record
     * Queries Account record to retrieve the PersonIndividualId field value
     * @param accountId The Account Id
     * @return PersonIndividualId, or null if not found
     */
    private static Id getIndividualIdByAccountId(Id accountId) {
        List<Account> accList = [SELECT PersonIndividualId FROM Account WHERE Id = :accountId WITH SYSTEM_MODE];
        return accList != null && !accList.isEmpty() ? accList[0].PersonIndividualId : null;
    }

    /**
     * @description Wrapper class for related list request parameters.
     *              Used to pass query configuration from LWC component to Apex controller.
     */
    public class RelatedListRequest {
        /** @description Account Id used to fetch PersonIndividualId for querying related records */
        @AuraEnabled public Id accountId { get; set; }
        /** @description API name of the child object to query (e.g., 'PartyConsent') */
        @AuraEnabled public String childObjectApi { get; set; }
        /** @description Lookup field name on child object that references the parent (e.g., 'Individual__c') */
        @AuraEnabled public String relationshipField { get; set; }
        /** @description Comma-separated list of fields to query. Supports nested fields (e.g., 'Name, Type__c, DataUsePurpose.Name') */
        @AuraEnabled public String fields { get; set; }
        /** @description Field name to sort by (optional) */
        @AuraEnabled public String sortedBy { get; set; }
        /** @description Sort direction: 'ASC' or 'DESC' (defaults to 'DESC' if not provided) */
        @AuraEnabled public String sortDirection { get; set; }
        /** @description Maximum number of records to return (defaults to 10 if not provided) */
        @AuraEnabled public Integer recordLimit { get; set; }
        /** @description Comma-separated Type__c picklist values for filtering records (optional) */
        @AuraEnabled public String typeFilter { get; set; }
    }
}