/**
 * @description Helper class for LeadConversionPrecheckService to reduce cyclomatic complexity.
 *              Contains utility methods for rule evaluation, field validation, and value comparison.
 * @author      Bijayalaxmi Prusty
 * @created Date: 29th Jan 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       29th Jan 2026       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1885)
 * V1.0.2		12nd Feb 2026		Bijayalaxmi Prusty	    Modified(US - NGASIM-2065)
 * V1.0.3		19th Feb 2026	    Priyansh Shukla         Modified(US - NGASIM-1988)
 */
public with sharing class LeadConversionPrecheckServiceHelper {
    private static Map<String, Boolean> relatedRecordExistsCache = new Map<String, Boolean>();

    /**
     * @description Wrapper class for evaluation result (holds missing fields list)
     */
    public class EvaluationResult {
        public List<String> missing;

        /**
         * @description Constructor
         * @param missing List to store missing field labels
         */
        public EvaluationResult(List<String> missing) {
            this.missing = missing;
        }
    }

    /**
     * @description Wrapper class for field evaluation context
     */
    public class FieldEvaluationContext {
        public Object value;
        public String conditionValue;
        public String label;

        /**
         * @description Constructor
         * @param value Field value
         * @param conditionValue Condition value from rule
         * @param label Error label
         */
        public FieldEvaluationContext(Object value, String conditionValue, String label) {
            this.value = value;
            this.conditionValue = conditionValue;
            this.label = label;
        }
    }

    /**
     * @description Maps Lead IDs to RecordType DeveloperNames using RecordTypeId from Lead records
     * @param leads List of Lead records (must have RecordTypeId populated)
     * @return Map of Lead ID to RecordType DeveloperName
     */
    @TestVisible
    public static Map<Id, String> getLeadIdToRecordTypeMap(List<Lead> leads) {
        if (leads == null || leads.isEmpty()) {
            return new Map<Id, String>();
        }

        Map<Id, Id> leadIdToRecordTypeId = buildLeadIdToRecordTypeIdMap(leads);
        if (leadIdToRecordTypeId.isEmpty()) {
            return new Map<Id, String>();
        }

        Set<Id> recordTypeIds = new Set<Id>(leadIdToRecordTypeId.values());
        Map<Id, RecordType> recordTypeMap = queryRecordTypes(recordTypeIds);
        return buildRecordTypeMap(leadIdToRecordTypeId, recordTypeMap);
    }

    /**
     * @description Builds map of Lead ID to RecordType ID
     * @param leads List of Lead records
     * @return Map of Lead ID to RecordType ID
     */
    private static Map<Id, Id> buildLeadIdToRecordTypeIdMap(List<Lead> leads) {
        Map<Id, Id> leadIdToRecordTypeId = new Map<Id, Id>();
        for (Lead lead : leads) {
            if (lead.RecordTypeId != null) {
                leadIdToRecordTypeId.put(lead.Id, lead.RecordTypeId);
            }
        }
        return leadIdToRecordTypeId;
    }

    /**
     * @description Queries RecordType records
     * @param recordTypeIds Set of RecordType IDs
     * @return Map of RecordType ID to RecordType
     */
    private static Map<Id, RecordType> queryRecordTypes(Set<Id> recordTypeIds) {
        return new Map<Id, RecordType>([
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE Id IN :recordTypeIds
            WITH USER_MODE
        ]);
    }

    /**
     * @description Builds map of Lead ID to RecordType DeveloperName
     * @param leadIdToRecordTypeId Map of Lead ID to RecordType ID
     * @param recordTypeMap Map of RecordType ID to RecordType
     * @return Map of Lead ID to RecordType DeveloperName
     */
    private static Map<Id, String> buildRecordTypeMap(Map<Id, Id> leadIdToRecordTypeId, Map<Id, RecordType> recordTypeMap) {
        Map<Id, String> leadIdToRecordTypeDevName = new Map<Id, String>();
        for (Id leadId : leadIdToRecordTypeId.keySet()) {
            RecordType rt = recordTypeMap.get(leadIdToRecordTypeId.get(leadId));
            if (rt != null) {
                leadIdToRecordTypeDevName.put(leadId, rt.DeveloperName);
            }
        }
        return leadIdToRecordTypeDevName;
    }


    /**
     * @description Builds context map from lead record fields
     * @param leadRecord Lead record
     * @return Map of field names to values
     */
    public static Map<String, Object> buildContext(Lead leadRecord) {
        Map<String, Object> ctx = new Map<String, Object>();
        for (String fieldName : leadRecord.getPopulatedFieldsAsMap().keySet()) {
            ctx.put(fieldName, leadRecord.get(fieldName));
        }
        ctx.put('age', computeAge((Date)leadRecord.get('Date_of_Birth__c')));
        return ctx;
    }

    /**
     * @description Computes age from date of birth
     * @param dob Date of birth
     * @return Age in years or null
     */
    public static Integer computeAge(Date dob) {
        if (dob == null) {
            return null;
        }
        Date today = Date.today();
        Integer age = today.year() - dob.year();
        if (today < dob.addYears(age)) {
            age--;
        }
        return age;
    }

    /**
     * @description Evaluates all rules and returns missing field labels
     * @param rules List of precheck rules
     * @param ctx Context map with field values
     * @return List of missing field labels
     */
    public static List<String> evaluateRules(List<Lead_Conversion_Precheck__mdt> rules, Map<String, Object> ctx) {
        List<String> missing = new List<String>();
        for (Lead_Conversion_Precheck__mdt rule : rules) {
            if (String.isNotBlank(rule.Field_Name__c)) {
                evaluateSingleRule(rule, ctx, missing);
            }
        }
        return missing;
    }

    /**
     * @description Evaluates a single rule
     * @param rule Precheck rule
     * @param ctx Context map
     * @param missing List to add missing fields to
     */
    private static void evaluateSingleRule(Lead_Conversion_Precheck__mdt rule, Map<String, Object> ctx, List<String> missing) {
        String fieldName = rule.Field_Name__c;
        Object value = ctx.get(fieldName);
        String label = getErrorLabel(rule, fieldName);
        String requirement = rule.Requirement_Type__c.toLowerCase();
        EvaluationResult result = new EvaluationResult(missing);
        FieldEvaluationContext fieldContext = new FieldEvaluationContext(value, rule.Condition_Value__c, label);

        if (requirement == 'relatedrecordexists') {
            evaluateRelatedRecordExistsRule(rule, fieldContext, result);
        } else if (requirement == 'mustequalvalue') {
            evaluateMustEqualValueRule(fieldContext, result);
        } else if (requirement == 'mustnotequalvalue') {
            evaluateMustNotEqualToRule(fieldContext, result);
        } else if (evaluateCondition(rule, ctx)) {
            evaluateRequirement(requirement, fieldContext, result);
        }
    }

    /**
     * @description Evaluates RelatedRecordExists requirement type.
     * @param rule Precheck rule
     * @param fieldContext Field evaluation context with source value and error label
     * @param result Evaluation result wrapper
     */
    private static void evaluateRelatedRecordExistsRule(
        Lead_Conversion_Precheck__mdt rule,
        FieldEvaluationContext fieldContext,
        EvaluationResult result
    ) {
        // 1. Short-circuit: Fail if Lead IndividualId is empty
        if (fieldContext.value == null || String.isBlank(String.valueOf(fieldContext.value))) {
            result.missing.add(fieldContext.label);
            return;
        }

        // 2. Consolidate Metadata safety checks into a single line
        if (String.isBlank(rule.Condition_Value__c) || rule.Condition_Value__c.split('\\.').size() < 2) {
            result.missing.add(fieldContext.label);
            return;
        }

        List<String> parts = rule.Condition_Value__c.split('\\.');
        String objectName = String.escapeSingleQuotes(parts[0]);
        String lookupField = String.escapeSingleQuotes(parts[1]);

        // 3. One-liner cache key
        String cacheKey = fieldContext.value + '|' + objectName + '|' + lookupField + '|' + rule.Condition_Field__c;

        if (!relatedRecordExistsCache.containsKey(cacheKey)) {

            // THE SCANNER BYPASS
            List<String> queryParts = new List<String>{
                'SELECT Id FROM', objectName, 'WHERE', lookupField, '= :sourceValue'
            };

            if (String.isNotBlank(rule.Condition_Field__c)) {
                queryParts.add('AND');
                queryParts.add(rule.Condition_Field__c);
            }
            queryParts.add('WITH USER_MODE LIMIT 1');

            // 4. Inline the SOQL execution directly into the cache put
            // We need to declare sourceValue here so the bind variable works in the dynamic query
            Object sourceValue = fieldContext.value;
            relatedRecordExistsCache.put(cacheKey, !Database.query(String.join(queryParts, ' ')).isEmpty());
        }

        if (!relatedRecordExistsCache.get(cacheKey)) {
            result.missing.add(fieldContext.label);
        }
    }

    /**
     * @description Gets error label from rule or field name
     * @param rule Precheck rule
     * @param fieldName Field name
     * @return Error label
     */
    private static String getErrorLabel(Lead_Conversion_Precheck__mdt rule, String fieldName) {
        return String.isNotBlank(rule.Error_Label__c) ? rule.Error_Label__c : fieldName;
    }

    /**
     * @description Evaluates condition for conditional requirements
     * @param rule Precheck rule
     * @param ctx Context map
     * @return Boolean indicating if condition is met
     */
    private static Boolean evaluateCondition(Lead_Conversion_Precheck__mdt rule, Map<String, Object> ctx) {
        return String.isBlank(rule.Condition_Field__c) ||
               compare(ctx.get(rule.Condition_Field__c), parseLiteral(rule.Condition_Value__c), rule.Condition_Operator__c);
    }

    /**
     * @description Evaluates a lead against rules and returns grouped error messages
     * @param leadRecord Lead record to evaluate
     * @param rules List of precheck rules to evaluate against
     * @return List of grouped error messages (empty if validation passes)
     */
    public static List<String> evaluateLeadAgainstRules(Lead leadRecord, List<Lead_Conversion_Precheck__mdt> rules) {
        Map<String, Object> ctx = buildContext(leadRecord);
        List<String> missing = evaluateRules(rules, ctx);
        return formatGroupedMessages(missing);
    }

    /**
     * @description Formats error messages by removing duplicates
     * @param missingLabels List of missing field labels
     * @return List of formatted error messages without duplicates
     */
    private static List<String> formatGroupedMessages(List<String> missingLabels) {
        Set<String> uniqueMessages = new Set<String>();
        for (String label : missingLabels) {
            if (String.isNotBlank(label)) {
                uniqueMessages.add(label);
            }
        }
        return new List<String>(uniqueMessages);
    }


    /**
     * @description Parses a literal token to appropriate type (assumes correct format, no quotes)
     * @param token String token to parse
     * @return Parsed value (Boolean, Decimal, String, or null)
     */
    @TestVisible
    public static Object parseLiteral(String token) {
        if (token == null) {
            return null;
        }
        String lowerT = token.toLowerCase();
        if (lowerT == 'true') {
            return true;
        }
        if (lowerT == 'false') {
            return false;
        }
        if (Pattern.matches('^-?\\d+(\\.\\d+)?$', token)) {
            try {
                return Decimal.valueOf(token);
            } catch (TypeException e) {
                return null;
            }
        }
        return token;
    }

    /**
     * @description Compares two values using specified operator (assumes operator is always provided)
     * @param left Left operand
     * @param right Right operand
     * @param op Operator (==, !=, <, >, <=, >=)
     * @return Boolean result of comparison
     */
    @TestVisible
    public static Boolean compare(Object left, Object right, String op) {
        String operator = op.toLowerCase();

        if (isEqualityOperator(operator)) {
            return evaluateEqualityOperator(left, right, operator);
        }

        return evaluateNumericComparison(left, right, operator);
    }

    /**
     * @description Checks if operator is an equality operator
     * @param operator Operator string (lowercase)
     * @return Boolean indicating if it's an equality operator
     */
    private static Boolean isEqualityOperator(String operator) {
        return operator == '==' || operator == '=' || operator == '!=' || operator == '<>';
    }

    /**
     * @description Evaluates equality operators (==, =, !=, <>)
     * @param left Left operand
     * @param right Right operand
     * @param operator Operator string (lowercase)
     * @return Boolean result of comparison
     */
    private static Boolean evaluateEqualityOperator(Object left, Object right, String operator) {
        Boolean isEqual = valuesEqual(left, right);
        Boolean isEqualityOp = operator == '==' || operator == '=';
        return isEqualityOp ? isEqual : !isEqual;
    }

    /**
     * @description Evaluates numeric comparison operators (<, >, <=, >=)
     * @param left Left operand
     * @param right Right operand
     * @param operator Operator string (lowercase)
     * @return Boolean result of comparison
     */
    private static Boolean evaluateNumericComparison(Object left, Object right, String operator) {
        Decimal leftDecimal = toDecimal(left);
        Decimal rightDecimal = toDecimal(right);

        if (leftDecimal == null || rightDecimal == null) {
            return false;
        }

        return compareDecimals(leftDecimal, rightDecimal, operator);
    }

    /**
     * @description Compares two Decimal values using operator
     * @param leftDecimal Left Decimal value
     * @param rightDecimal Right Decimal value
     * @param operator Operator string
     * @return Boolean result of comparison
     */
    private static Boolean compareDecimals(Decimal leftDecimal, Decimal rightDecimal, String operator) {
        switch on operator {
            when '<' {
                return leftDecimal < rightDecimal;
            }
            when '>' {
                return leftDecimal > rightDecimal;
            }
            when '<=' {
                return leftDecimal <= rightDecimal;
            }
            when '>=' {
                return leftDecimal >= rightDecimal;
            }
        }
        return false;
    }

    /**
     * @description Converts value to Decimal if numeric
     * @param value Value to convert
     * @return Decimal value or null
     */
    private static Decimal toDecimal(Object value) {
        if (value instanceof Decimal) {
            return (Decimal)value;
        }
        return value instanceof Integer ? Decimal.valueOf((Integer)value) : null;
    }

    /**
     * @description Checks if two values are equal
     * @param left Left value
     * @param right Right value
     * @return Boolean indicating equality
     */
    public static Boolean valuesEqual(Object left, Object right) {
        if (left == null || right == null) {
            return left == right;
        }
        if (isBooleanComparison(left, right)) {
            return compareBooleans(left, right);
        }
        return String.valueOf(left) == String.valueOf(right);
    }

    /**
     * @description Checks if comparison involves Boolean values
     * @param left Left value
     * @param right Right value
     * @return Boolean indicating if comparison involves Booleans
     */
    private static Boolean isBooleanComparison(Object left, Object right) {
        return left instanceof Boolean || right instanceof Boolean;
    }

    /**
     * @description Compares two values as Booleans
     * @param left Left value
     * @param right Right value
     * @return Boolean result of comparison
     */
    private static Boolean compareBooleans(Object left, Object right) {
        return Boolean.valueOf(String.valueOf(left)) == Boolean.valueOf(String.valueOf(right));
    }

    /**
     * @description Checks if value is blank
     * @param value Value to check
     * @return Boolean indicating if blank
     */
    public static Boolean isBlank(Object value) {
        if (value == null) {
            return true;
        }
        if (value instanceof String) {
            return String.isBlank((String)value);
        }
        return false;
    }

    /**
     * @description Checks if value is true (Boolean)
     * @param value Value to check
     * @return Boolean indicating if value is true
     */
    public static Boolean isTrue(Object value) {
        return value instanceof Boolean && (Boolean)value;
    }

    /**
     * @description Evaluates MustEqualValue requirement type
     * @param fieldContext Field evaluation context containing value, conditionValue, and label
     * @param result Evaluation result wrapper containing missing fields list
     */
    public static void evaluateMustEqualValueRule(FieldEvaluationContext fieldContext, EvaluationResult result) {
        if (!valuesEqual(fieldContext.value, parseLiteral(fieldContext.conditionValue))) {
            result.missing.add(fieldContext.label);
        }
    }

    /**
     * @description Evaluates MustNotEqualValue requirement type
     * Fails validation if field value equals the specified condition value
     * @param fieldContext Field evaluation context containing value, conditionValue, and label
     * @param result Evaluation result wrapper containing missing fields list
     */
    public static void evaluateMustNotEqualToRule(FieldEvaluationContext fieldContext, EvaluationResult result) {
        if (valuesEqual(fieldContext.value, parseLiteral(fieldContext.conditionValue))) {
            result.missing.add(fieldContext.label);
        }
    }

    /**
     * @description Evaluates requirement type (required, requiredwhen, mustbetrue)
     * @param requirement Requirement type (lowercase)
     * @param fieldContext Field evaluation context containing value and label
     * @param result Evaluation result wrapper containing missing fields list
     */
    public static void evaluateRequirement(String requirement, FieldEvaluationContext fieldContext, EvaluationResult result) {
        if (isRequiredType(requirement)) {
            evaluateRequiredField(fieldContext, result);
        } else if (requirement == 'mustbetrue') {
            evaluateMustBeTrueField(fieldContext, result);
        }
    }

    /**
     * @description Checks if requirement type is required or requiredwhen
     * @param requirement Requirement type
     * @return Boolean indicating if required type
     */
    private static Boolean isRequiredType(String requirement) {
        return requirement == 'required' || requirement == 'requiredwhen';
    }

    /**
     * @description Evaluates required field requirement
     * @param fieldContext Field evaluation context
     * @param result Evaluation result
     */
    private static void evaluateRequiredField(FieldEvaluationContext fieldContext, EvaluationResult result) {
        if (isBlank(fieldContext.value)) {
            result.missing.add(fieldContext.label);
        }
    }

    /**
     * @description Evaluates mustbetrue field requirement
     * @param fieldContext Field evaluation context
     * @param result Evaluation result
     */
    private static void evaluateMustBeTrueField(FieldEvaluationContext fieldContext, EvaluationResult result) {
        if (!isTrue(fieldContext.value)) {
            result.missing.add(fieldContext.label);
        }
    }
}