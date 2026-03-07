/**
 * @description Test class for DataMaskUtil
 */
@IsTest
private class DataMaskUtil_Test {
    
    /**
     * @description Test masking of string fields in a single record JSON
     */
    @IsTest
    static void testMaskJsonDataStringFields() {
        // Arrange
        String inputJson = '[{' +
            '"attributes": {"type": "Case"},' +
            '"Status": "New",' +
            '"Description": "This is a description that may contain sensitive information",' +
            '"Subject": "This is a test subject",' +
            '"Priority": "High"' + 
        '}]';
        
        List<String> sensitiveFields = new List<String>{'Description', 'Subject'};
        DataMaskUtil.mockSensitiveFields = sensitiveFields;
        
        String expectedJson = '[{' +
            '"attributes": {"type": "Case"},' +
            '"Status": "New",' +
            '"Description" : REDACTED,' +
            '"Subject" : REDACTED,' +
            '"Priority": "High"' +
        '}]';
        
        // Act
        String result = DataMaskUtil.maskJsonData(inputJson);
        
        // Assert
        Assert.isTrue(result.contains('"Description" : REDACTED'), 'Description field should be masked');
        Assert.isTrue(result.contains('"Subject" : REDACTED'), 'Subject field should be masked');
        Assert.isTrue(result.contains('"Status": "New"'), 'Non-sensitive fields should remain unchanged');
        Assert.isTrue(result.contains('"Priority": "High"'), 'Non-sensitive fields should remain unchanged');
    }
    
    /**
     * @description Test masking of boolean fields
     */
    @IsTest
    static void testMaskJsonDataBooleanFields() {
        // Arrange
        String inputJson = '[{' +
            '"attributes": {"type": "Case"},' +
            '"IsDeleted": false,' +
            '"Has_Medical_Issue__c": true,' +
            '"IsEscalated": false' +
        '}]';
        
        List<String> sensitiveFields = new List<String>{'Has_Medical_Issue__c'};
        DataMaskUtil.mockSensitiveFields = sensitiveFields;
        
        // Act
        String result = DataMaskUtil.maskJsonData(inputJson);
        
        // Assert
        Assert.isTrue(result.contains('"Has_Medical_Issue__c" : REDACTED'), 'Boolean field should be masked');
        Assert.isTrue(result.contains('"IsDeleted": false'), 'Non-sensitive boolean fields should remain unchanged');
        Assert.isTrue(result.contains('"IsEscalated": false'), 'Non-sensitive boolean fields should remain unchanged');
    }
    
    /**
     * @description Test masking of numeric fields
     */
    @IsTest
    static void testMaskJsonDataNumericFields() {
        // Arrange
        String inputJson = '[{' +
            '"attributes": {"type": "Account"},' +
            '"AnnualRevenue": 1000000,' +
            '"NumberOfEmployees": 500,' +
            '"SSN_Last_Four__c": 1234,' +
            '"Account_Value__c": 25.75' +
        '}]';
        
        List<String> sensitiveFields = new List<String>{'SSN_Last_Four__c', 'Account_Value__c'};
        DataMaskUtil.mockSensitiveFields = sensitiveFields;
        
        // Act
        String result = DataMaskUtil.maskJsonData(inputJson);
        
        // Assert
        Assert.isTrue(result.contains('"SSN_Last_Four__c" : REDACTED'), 'Sensitive numeric field should be masked');
        Assert.isTrue(result.contains('"Account_Value__c" : REDACTED'), 'Sensitive decimal field should be masked');
        Assert.isTrue(result.contains('"AnnualRevenue": 1000000'), 'Non-sensitive numeric fields should remain unchanged');
        Assert.isTrue(result.contains('"NumberOfEmployees": 500'), 'Non-sensitive numeric fields should remain unchanged');
    }
    
    /**
     * @description Test masking with mixed data types
     */
    @IsTest
    static void testMaskJsonDataMixedDataTypes() {
        // Arrange
        String inputJson = '[{' +
            '"attributes": {"type": "Contact"},' +
            '"FirstName": "John",' +
            '"LastName": "Doe",' +
            '"IsPersonAccount": true,' +
            '"Age__c": 35,' +
            '"Salary__c": 75000.50,' +
            '"Email": "john.doe@example.com"' +
        '}]';
        
        List<String> sensitiveFields = new List<String>{'FirstName', 'LastName', 'Age__c', 'Salary__c'};
        DataMaskUtil.mockSensitiveFields = sensitiveFields;
        
        // Act
        String result = DataMaskUtil.maskJsonData(inputJson);
        
        // Assert
        Assert.isTrue(result.contains('"FirstName" : REDACTED'), 'String field should be masked');
        Assert.isTrue(result.contains('"LastName" : REDACTED'), 'String field should be masked');
        Assert.isTrue(result.contains('"Age__c" : REDACTED'), 'Integer field should be masked');
        Assert.isTrue(result.contains('"Salary__c" : REDACTED'), 'Decimal field should be masked');
        Assert.isTrue(result.contains('"IsPersonAccount": true'), 'Non-sensitive boolean should remain unchanged');
        Assert.isTrue(result.contains('"Email": "john.doe@example.com"'), 'Non-sensitive string should remain unchanged');
    }
    
    /**
     * @description Test masking with no sensitive fields defined
     */
    @IsTest
    static void testMaskJsonDataNoSensitiveFields() {
        // Arrange
        String inputJson = '[{' +
            '"attributes": {"type": "Case"},' +
            '"Status": "New",' +
            '"Description": "This is a description",' +
            '"Priority": "High"' +
        '}]';
        
        DataMaskUtil.mockSensitiveFields = new List<String>();
        
        // Act
        String result = DataMaskUtil.maskJsonData(inputJson);
        
        // Assert
        Assert.areEqual(inputJson, result, 'JSON should remain unchanged when no sensitive fields are defined');
    }
    
    /**
     * @description Test masking with empty sensitive fields list
     */
    @IsTest
    static void testMaskJsonDataEmptySensitiveFieldsList() {
        // Arrange
        String inputJson = '[{' +
            '"attributes": {"type": "Case"},' +
            '"Status": "New",' +
            '"Description": "This is a description"' +
        '}]';
        
        // Act & Assert - This should execute the FieldDefinition query path
        // We're not asserting specific behavior since we don't have test data in FieldDefinition
        // This test ensures the method executes without errors when mockSensitiveFields is null
        String result = DataMaskUtil.maskJsonData(inputJson);
        Assert.areNotEqual(null, result, 'Result should not be null');
    }
    
    /**
     * @description Test masking with multiple records in JSON array
     */
    @IsTest
    static void testMaskJsonDataMultipleRecords() {
        // Arrange
        String inputJson = '[{' +
            '"attributes": {"type": "Case"},' +
            '"Status": "New",' +
            '"Description": "First case description",' +
            '"Subject": "First case subject"' +
        '}, {' +
            '"attributes": {"type": "Case"},' +
            '"Status": "Closed",' +
            '"Description": "Second case description",' +
            '"Subject": "Second case subject"' +
        '}]';
        
        List<String> sensitiveFields = new List<String>{'Description', 'Subject'};
        DataMaskUtil.mockSensitiveFields = sensitiveFields;
        
        // Act
        String result = DataMaskUtil.maskJsonData(inputJson);
        
        // Assert
        Assert.isTrue(result.contains('"Description" : REDACTED'), 'All Description fields should be masked');
        Assert.isTrue(result.contains('"Subject" : REDACTED'), 'All Subject fields should be masked');
        Assert.isTrue(result.contains('"Status": "New"'), 'Non-sensitive fields should remain unchanged');
        Assert.isTrue(result.contains('"Status": "Closed"'), 'Non-sensitive fields should remain unchanged');
        
        // Count occurrences to ensure both records are processed
        Integer redactedCount = result.countMatches('REDACTED');
        Assert.areEqual(4, redactedCount, 'Should have 4 REDACTED values (2 fields x 2 records)');
    }
    
    /**
     * @description Test masking with fields containing special characters and quotes
     */
    @IsTest
    static void testMaskJsonDataSpecialCharacters() {
        // Arrange
        String inputJson = '[{' +
            '"attributes": {"type": "Case"},' +
            '"Description": "This contains \\"quotes\\" and special chars: !@#$%",' +
            '"Notes__c": "Line 1\\nLine 2\\tTabbed",' +
            '"Status": "New"' +
        '}]';
        
        List<String> sensitiveFields = new List<String>{'Description', 'Notes__c'};
        DataMaskUtil.mockSensitiveFields = sensitiveFields;
        
        // Act
        String result = DataMaskUtil.maskJsonData(inputJson);
        
        // Assert
        Assert.isTrue(result.contains('"Description" : REDACTED'), 'Field with quotes should be masked');
        Assert.isTrue(result.contains('"Notes__c" : REDACTED'), 'Field with escaped characters should be masked');
        Assert.isTrue(result.contains('"Status": "New"'), 'Non-sensitive fields should remain unchanged');
    }
    
    /**
     * @description Test with malformed JSON input
     */
    @IsTest
    static void testMaskJsonDataMalformedJson() {
        // Arrange
        String inputJson = '[{"attributes": {"type": "Case"}, "Status": "New", "Description": "Test"}'; // Missing closing bracket
        
        List<String> sensitiveFields = new List<String>{'Description'};
        DataMaskUtil.mockSensitiveFields = sensitiveFields;
        
        // Act & Assert - Should not throw exception even with malformed JSON
        String result = DataMaskUtil.maskJsonData(inputJson);
        Assert.areNotEqual(null, result, 'Result should not be null even with malformed JSON');
    }
    
    /**
     * @description Test with JSON missing object type attribute
     */
    @IsTest
    static void testMaskJsonDataMissingObjectType() {
        // Arrange
        String inputJson = '[{' +
            '"Status": "New",' +
            '"Description": "Test description"' +
        '}]';
        
        // Act
        String result = DataMaskUtil.maskJsonData(inputJson);
        
        // Assert
        Assert.areEqual(inputJson, result, 'Result should be the same as input JSON if object type is missing');
    }
    

    /**
     * @description Test with whitespace variations in JSON
     */
    @IsTest
    static void testMaskJsonDataWhitespaceVariations() {
        // Arrange
        String inputJson = '[{' +
            '"attributes" : { "type" : "Case" },' +
            '"Status"  :  "New",' +
            '"Description"   :   "Test description",' +
            '"Priority":"High"' +
        '}]';
        
        List<String> sensitiveFields = new List<String>{'Description'};
        DataMaskUtil.mockSensitiveFields = sensitiveFields;
        
        // Act
        String result = DataMaskUtil.maskJsonData(inputJson);
        
        // Assert
        Assert.isTrue(result.contains('"Description" : REDACTED'), 'Should handle various whitespace patterns');
        Assert.isTrue(result.contains('"Status"  :  "New"'), 'Non-sensitive fields should maintain their formatting');
    }
    
    /**
     * @description Test to verify FieldDefinition query execution (without mocking)
     * This test ensures the getSensitiveFields method executes the SOQL query path
     */
    @IsTest
    static void testGetSensitiveFieldsQueryExecution() {
        // Arrange
        String inputJson = '[{' +
            '"attributes": {"type": "Case"},' +
            '"Status": "New",' +
            '"Description": "Test description"' +
        '}]';
        
        // Don't set mockSensitiveFields - this will trigger the FieldDefinition query
        DataMaskUtil.mockSensitiveFields = null;
        
        // Act & Assert - This test just ensures the method executes without errors
        // We can't predict what fields will be marked as sensitive in the org
        Test.startTest();
        String result = DataMaskUtil.maskJsonData(inputJson);
        Test.stopTest();
        
        Assert.areNotEqual(null, result, 'Method should execute successfully and return a result');
        Assert.isTrue(result.contains('"Status"'), 'JSON should still contain expected fields');
    }
    
    /**
     * @description Test the sensitive compliance groups functionality
     */
    @IsTest
    static void testSensitiveComplianceGroups() {
        // Act & Assert
        List<String> groups = DataMaskUtil.sensitiveComplianceGroups;
        
        Assert.areNotEqual(null, groups, 'Sensitive compliance groups should not be null');
        Assert.isTrue(groups.contains('HIPAA'), 'Should contain HIPAA');
        Assert.isTrue(groups.contains('PII'), 'Should contain PII');
    }
    
    /**
     * @description Test masking with zero values
     */
    @IsTest
    static void testMaskJsonDataZeroValues() {
        // Arrange
        String inputJson = '[{' +
            '"attributes": {"type": "Case"},' +
            '"Amount__c": 0,' +
            '"Percentage__c": 0.0,' +
            '"Count__c": 0,' +
            '"Status": "New"' +
        '}]';
        
        List<String> sensitiveFields = new List<String>{'Amount__c', 'Percentage__c'};
        DataMaskUtil.mockSensitiveFields = sensitiveFields;
        
        // Act
        String result = DataMaskUtil.maskJsonData(inputJson);
        
        // Assert
        Assert.isTrue(result.contains('"Amount__c" : REDACTED'), 'Zero integer should be masked');
        Assert.isTrue(result.contains('"Percentage__c" : REDACTED'), 'Zero decimal should be masked');
        Assert.isTrue(result.contains('"Count__c": 0'), 'Non-sensitive zero should remain unchanged');
    }

    /**
     * @description Helper method to create FieldDefinition test data using JSON deserialization
     * This bypasses the read-only field restrictions on FieldDefinition.ComplianceGroup
     * @param qualifiedApiName The API name of the field
     * @param complianceGroup The compliance group value (e.g., 'HIPAA', 'PII', 'PCI')
     * @return A FieldDefinition object with the specified values
     */
    private static FieldDefinition createTestFieldDefinition(String qualifiedApiName, String complianceGroup) {
        String fieldJson = '{' +
            '"attributes": {"type": "FieldDefinition"},' +
            '"Id": "00N000000000000",' +
            '"QualifiedApiName": "' + qualifiedApiName + '",' +
            (complianceGroup != null ? '"ComplianceGroup": "' + complianceGroup + '",' : '') +
            '"SecurityClassification": "Restricted"' +
        '}';
        
        return (FieldDefinition) JSON.deserialize(fieldJson, FieldDefinition.class);
    }
    
    /**
     * @description Test that fields with HIPAA compliance group are identified as sensitive
     */
    @IsTest
    static void testFieldIsSensitive() {
        // Arrange
        FieldDefinition hipaaField = createTestFieldDefinition('Patient_SSN__c', 'HIPAA');
        
        // Act
        Boolean result = DataMaskUtil.fieldIsSensitive(hipaaField);
        
        // Assert
        Assert.isTrue(result, 'Field with HIPAA compliance group should be sensitive');
    }
    

    /**
     * @description Test that fields without sensitive compliance groups are not identified as sensitive
     */
    @IsTest
    static void testFieldIsNotSensitive() {
        // Arrange
        FieldDefinition nonSensitiveField = createTestFieldDefinition('Regular_Field__c', 'Internal');
        
        // Act
        Boolean result = DataMaskUtil.fieldIsSensitive(nonSensitiveField);
        
        // Assert
        Assert.isFalse(result, 'Field without sensitive compliance group should not be sensitive');
    }
    
    /**
     * @description Test that fields with null compliance group are not identified as sensitive
     */
    @IsTest
    static void testFieldIsNotSensitiveNullComplianceGroup() {
        // Arrange
        FieldDefinition nullField = createTestFieldDefinition('Normal_Field__c', null);
        
        // Act
        Boolean result = DataMaskUtil.fieldIsSensitive(nullField);
        
        // Assert
        Assert.isFalse(result, 'Field with null compliance group should not be sensitive');
    }
}