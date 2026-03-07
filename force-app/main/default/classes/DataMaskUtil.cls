/**
 * @description This class is intended to be used to mask record JSON stored by Nebula logger
 * For background, see https://confluence.insulet.com/display/NASFL/Nebula+Logger%3A+Analysis
 */
public without sharing class DataMaskUtil {

    @TestVisible
    private static List<String> mockSensitiveFields;

    /**
     * @description  These correspond to "Compliance Categorization" picklist available on the field definition.
     * Add values here if we need more complaince groups masked when storing JSON in logs.
     */
    public static List<String> sensitiveComplianceGroups = new List<String> {
        'HIPAA',
        'PII',
        'PCI'
    };

    /**
     * @description  Given a JSON for an sObject record, this method masks all
     * sensitive fields as identified by sensitiveComplianceGroups. Values will
     * be replaced by the word "REDACTED".
     * @param  jsonObj A JSON string representing an sObject record
     * @return A JSON string with sensitive fields masked
     */
    public static String maskJsonData(String jsonObj) {
        String objectName = getObjectName(jsonObj);
        List<String> sensitiveFields = getSensitiveFields(objectName);
        return maskFields(jsonObj, sensitiveFields);
    }

    /**
     * @description  Extracts the name of the object (value of the type attribute) from the JSON string
     * @param  jsonObj A JSON string representing an sObject record
     * @return The name of the object
     */
    private static String getObjectName(String jsonObj) {
        // matches "type" : "Object_Name__c", with a capturing group for Object_Name__c.
        // the matching group ensures that we can extract Object_Name__c once the match is found.
        Pattern objPattern = Pattern.compile('"type"\\s*:\\s*"([a-zA-Z0-9_.]+)"');
        Matcher objMatcher = objPattern.matcher(jsonObj);
        if 
         (objMatcher.find() && objMatcher.groupCount() > 0) {
            return objMatcher.group(1);
        }
        return null;
    }

    /**
     * @description  Retrieves a list of fields that have a sensitive compliance categorization set on the object
     * @param  objectName The name of the object
     * @return  List of field names that have a sensitive compliance categorization set on the object
     */
    private static List<String> getSensitiveFields(String objectName) {
        if (mockSensitiveFields != null) {
            return mockSensitiveFields;
        }

        // ComplianceGroup is a multiselect picklist, which is why we're not doing an IN clause
        List<FieldDefinition> fields = [
            SELECT Id, QualifiedApiName, SecurityClassification, ComplianceGroup
            FROM FieldDefinition 
            WHERE EntityDefinitionId = :objectName AND ComplianceGroup != null
            WITH SYSTEM_MODE
        ];

        List<String> sensitiveFields = new List<String>();
        for (FieldDefinition field : fields) {
            if (fieldIsSensitive(field)) {
                sensitiveFields.add(field.QualifiedApiName);
            }
        }

        return sensitiveFields;
    }

    /**
     * @description Determines if a field is sensitive based on its compliance categorization
     * @param  field A FieldDefinition object
     * @return True if the field is sensitive, false otherwise
     */
    @TestVisible
    private static Boolean fieldIsSensitive(FieldDefinition field) {
        // Handle null ComplianceGroup gracefully
        if (field.ComplianceGroup == null) {
            return false;
        }
        
        for (String sensitiveComplianceGroup : sensitiveComplianceGroups) {
            if (field.ComplianceGroup.contains(sensitiveComplianceGroup)) {
                return true;
            }
        }
        return false;
    }
 
    /**
     * @description Masks sensitive fields in a JSON string by replacing the values with the word "REDACTED"
     * @param  jsonObj A JSON string representing an sObject record
     * @param  sensitiveFields A list of field names that have a sensitive compliance categorization set on the object
     * @return A JSON string with sensitive fields masked
     */
    private static String maskFields(String jsonObj, List<String> sensitiveFields) {
        if (sensitiveFields == null || sensitiveFields.isEmpty()) {
            return jsonObj;
        }

        /**
         * Explanation of the regex being generated below:
         * 
         * Given this example JSON:
         * {
         *   "Field_1__c" : "Value 1",
         *   "Field_2__c" : "Value 2",
         *   "Field_3__c" : "Value 2"
         * }
         * 
         * ("Field_1__c"|"Field_3__c") 
         *   The above portion of the regex matches the field names, which are the keys in this JSON.
         *   The paranthesis creates a capturing group that we can use in the replacement string.
         * 
         * \\s*:\\s*
         *   The above portion matches whitespace characters, followed by a colon, followed by whitespace
         * 
         * (?: ... )
         *   Creates a grouping to match the values. We will match string values, booleans and numbers.
         * 
         * "[^"\\\\]*(?:\\\\.[^"\\\\]*)*"
         *   - " matches the starting double quote of the string.
         *   - [^"\\\\]* matches any character that is not a double quote or a backslash.
         *   - (?:\\\\.[^"\\\\]*)* matches any escaped characters (including double quotes) within the string. The ?: makes this group non-capturing.
         *   - " matches the ending double quote of the string.
         *   - I don't know how I came up with this and my brain hurts when I read it now, but it works.
         * 
         * |false|true|[0-9]*\\.?[0-9]*
         *   - Matches booleans and numbers.
         *   - [0-9]*\\.?[0-9]* matches 0 or more numbers, followed by an optional decimal, and zero or more numbers.
         * 
         * Want to play around with this regex and see how it matches strings?
         *   Go to regex101.com
         *   Paste ("Field_4__c"|"Field_3__c"|"Field_5__c")\s*:\s*(?:"[^"\\]*(?:\\.[^"\\]*)*"|false|true|[0-9]*\.?[0-9]*) as the regex.
         *   (notice that I've replaced \\ with \ in the above string. The \\ is just there to write \ in Apex)
         *   Paste a JSON (like the example above), and see how it matches sensitive fields.
         */
        String regex = '(';
        for (String field : sensitiveFields) {
            regex += (regex == '(' ? '' : '|') + '"' + field + '"';
        }
        regex += ')\\s*:\\s*(?:"[^"\\\\]*(?:\\\\.[^"\\\\]*)*"|false|true|[0-9]*\\.?[0-9]*)';

        Pattern pattern = Pattern.compile(regex);
        Matcher matcher = pattern.matcher(jsonObj);
        return matcher.replaceAll('$1 : REDACTED');
    }
}