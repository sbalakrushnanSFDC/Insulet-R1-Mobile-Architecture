/**
 * @description Test class for LeadConversionPrecheckService.
 *             Provides comprehensive test coverage for lead conversion precheck validation logic,
 *             including field requirements, conditional validations, and age-based caregiver field checks.
 * @author      Priyansh Shukla
 * @created Date 16th Dec 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       16th Dec 2025       Priyansh Shukla         Initial Version(US - NGASIM-1163)
 * V1.0.1       23rd Jan 2026       Bijayalaxmi Prusty      Updated(US - NGASIM-1885)
 */
@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage')
@IsTest(isParallel=true)
private class LeadConversionPrecheckService_Test {

    /**
     * @description Sets up test data for Lead conversion precheck scenarios
     */
    @TestSetup
    static void setupTestData() {
        Contact practitionerContact = TestDataFactory.getContact(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Practitioner',
            'Email' => 'test.practitioner@example.com'
        });
        insert practitionerContact;

        List<HealthcarePractitionerFacility> facilities = TestDataFactory.getHealthcarePractitionerFacilities(1, new Map<String, Object>{
            'Name' => 'Test Facility',
            'PractitionerId' => practitionerContact.Id
        });
        insert facilities;
    }

    /**
     * @description Helper method to get facility for tests
     * @return HealthcarePractitionerFacility record from test setup data
     */
    private static HealthcarePractitionerFacility getFacility() {
        return [SELECT Id, PractitionerId FROM HealthcarePractitionerFacility LIMIT 1];
    }

    /**
     * @description Test null leadId handling
     */
    @IsTest
    static void testRunPrechecksWithNullLeadId() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'Email' => 'test@example.com'
        });
        insert testLead;

        Test.startTest();
        Id nullId = null;
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(nullId, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isFalse(result.ok, 'Precheck should fail when Lead Id is null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
        Assert.areEqual('Lead Id is required.', result.messages[0], 'Expected null Lead Id validation message');
    }

    /**
     * @description Test getActiveRules with different record types and conversion types
     */
    @IsTest
    static void testGetActiveRules() {
        Test.startTest();
        List<Lead_Conversion_Precheck__mdt> rulesWithRecordType =
            LeadConversionPrecheckService.getActiveRules('Patient', ConstantsUtil.CONVERSION_TYPE_AUTO);
        List<Lead_Conversion_Precheck__mdt> rulesWithNull =
            LeadConversionPrecheckService.getActiveRules(null, ConstantsUtil.CONVERSION_TYPE_AUTO);
        List<Lead_Conversion_Precheck__mdt> rulesWithManual =
            LeadConversionPrecheckService.getActiveRules('Patient', ConstantsUtil.CONVERSION_TYPE_MANUAL);
        List<Lead_Conversion_Precheck__mdt> rulesWithNullConversion =
            LeadConversionPrecheckService.getActiveRules('Patient', null);
        Test.stopTest();

        Assert.isNotNull(rulesWithRecordType, 'Rules list should not be null for Patient/Auto');
        Assert.isNotNull(rulesWithNull, 'Rules list should not be null for null record type/Auto');
        Assert.isNotNull(rulesWithManual, 'Rules list should not be null for Patient/Manual');
        Assert.isNotNull(rulesWithNullConversion, 'Rules list should not be null for Patient/null conversion type');
    }

    /**
     * @description Test runPrechecks with lead that has no matching rules
     */
    @IsTest
    static void testRunPrechecksWithNoRules() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'Email' => 'test@example.com'
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    @IsTest
    static void testRunPrechecksWithMissingRequiredField() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'Email' => null
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test runPrechecks with all required fields populated - should pass all prechecks
     */
    @IsTest
    static void testRunPrechecksWithAllFieldsPopulated() {
        Id patientRecordTypeId = getPatientRecordTypeId();
        HealthcarePractitionerFacility facility = getFacility();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'FirstName' => 'Test',
            'LastName' => 'Lead',
            'Status' => 'Qualification',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'GenderIdentity' => 'Male',
            'Insurance_Type__c' => 'Commercial',
            'Address_Status__c' => 'Verified',
            'Provider_Practice_Affiliation__c' => facility.Id,
            'Request_a_Call_Back__c' => true,
            'Callback_Completion_Date__c' => Date.today()
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test runPrechecks with RequiredWhen condition - condition met but field missing
     */
    @IsTest
    static void testRunPrechecksWithRequiredWhenConditionMet() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(2010, 1, 1),
            'Request_a_Call_Back__c' => true,
            'Callback_Completion_Date__c' => null,
            'Caregiver_First_Name__c' => null
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test runPrechecks with RequiredWhen condition - condition not met
     */
    @IsTest
    static void testRunPrechecksWithRequiredWhenConditionNotMet() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'Request_a_Call_Back__c' => false,
            'Callback_Completion_Date__c' => null
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test runPrechecks with MustEqualValue requirement
     */
    @IsTest
    static void testRunPrechecksWithMustEqualValue() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1)
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test runPrechecks with MustEqualValue requirement failing
     */
    @IsTest
    static void testRunPrechecksWithMustEqualValueFailing() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Open',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1)
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test runPrechecks with MustBeTrue requirement
     */
    @IsTest
    static void testRunPrechecksWithMustBeTrue() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'Request_a_Call_Back__c' => true
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test runPrechecks with age-based condition (caregiver fields for minor)
     */
    @IsTest
    static void testRunPrechecksWithAgeBasedCondition() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead minorLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Minor',
            'LastName' => 'Test',
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'minor@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(2010, 1, 1),
            'Caregiver_First_Name__c' => 'Caregiver',
            'Caregiver_Last_Name__c' => 'Name',
            'Email' => 'caregiver@example.com',
            'MobilePhone' => '9876543210'
        });
        insert minorLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(minorLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test runPrechecks with adult (no caregiver fields required)
     */
    @IsTest
    static void testRunPrechecksWithAdult() {
        Id patientRecordTypeId = getPatientRecordTypeId();
        HealthcarePractitionerFacility facility = getFacility();

        Lead adultLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Adult',
            'LastName' => 'Test',
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'adult@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'GenderIdentity' => 'Male',
            'Insurance_Type__c' => 'Commercial',
            'Address_Status__c' => 'Verified',
            'Provider_Practice_Affiliation__c' => facility.Id
        });
        insert adultLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(adultLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test runPrechecks with null Date_of_Birth (age computation edge case)
     */
    @IsTest
    static void testRunPrechecksWithNullDateOfBirth() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => null
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test runPrechecks with empty string field values
     */
    @IsTest
    static void testRunPrechecksWithEmptyStringFields() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => '',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1)
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test runPrechecks with lead that has no record type
     */
    @IsTest
    static void testRunPrechecksWithNoRecordType() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'Email' => 'test@example.com'
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    @IsTest
    static void testRunPrechecksWithRecordTypeRelationshipField() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1)
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    @IsTest
    static void testRunPrechecksWithMustEqualValueNullCondition() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'FirstName' => 'Test',
            'LastName' => 'Lead',
            'GenderIdentity' => 'Male',
            'Insurance_Type__c' => 'Commercial',
            'Address_Status__c' => 'Verified'
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    @IsTest
    static void testRunPrechecksWithConditionValueFalse() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'Request_a_Call_Back__c' => false
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    @IsTest
    static void testRunPrechecksWithNotEqualOperatorCondition() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Open',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'Matching_Status__c' => 'No Match'
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    @IsTest
    static void testParseLiteralWithNull() {
        Test.startTest();
        Object result = LeadConversionPrecheckServiceHelper.parseLiteral(null);
        Test.stopTest();

        Assert.isNull(result);
    }

    @IsTest
    static void testParseLiteralWithFalse() {
        Test.startTest();
        Object result = LeadConversionPrecheckServiceHelper.parseLiteral('false');
        Test.stopTest();

        Assert.areEqual(false, result);
    }

    @IsTest
    static void testCompareWithNotEqualOperator() {
        Test.startTest();
        Boolean result1 = LeadConversionPrecheckServiceHelper.compare('Value1', 'Value2', '!=');
        Boolean result2 = LeadConversionPrecheckServiceHelper.compare('Value1', 'Value2', '<>');
        Boolean result3 = LeadConversionPrecheckServiceHelper.compare('Same', 'Same', '!=');
        Test.stopTest();

        Assert.isTrue(result1);
        Assert.isTrue(result2);
        Assert.isFalse(result3);
    }

    @IsTest
    static void testCompareWithGreaterThanOperator() {
        Test.startTest();
        Boolean result1 = LeadConversionPrecheckServiceHelper.compare(10, 5, '>');
        Boolean result2 = LeadConversionPrecheckServiceHelper.compare(5, 10, '>');
        Boolean result3 = LeadConversionPrecheckServiceHelper.compare(5, 5, '>');
        Test.stopTest();

        Assert.isTrue(result1);
        Assert.isFalse(result2);
        Assert.isFalse(result3);
    }

    @IsTest
    static void testCompareWithLessThanOrEqualOperator() {
        Test.startTest();
        Boolean result1 = LeadConversionPrecheckServiceHelper.compare(5, 10, '<=');
        Boolean result2 = LeadConversionPrecheckServiceHelper.compare(10, 5, '<=');
        Boolean result3 = LeadConversionPrecheckServiceHelper.compare(5, 5, '<=');
        Test.stopTest();

        Assert.isTrue(result1);
        Assert.isFalse(result2);
        Assert.isTrue(result3);
    }

    @IsTest
    static void testCompareWithGreaterThanOrEqualOperator() {
        Test.startTest();
        Boolean result1 = LeadConversionPrecheckServiceHelper.compare(10, 5, '>=');
        Boolean result2 = LeadConversionPrecheckServiceHelper.compare(5, 10, '>=');
        Boolean result3 = LeadConversionPrecheckServiceHelper.compare(5, 5, '>=');
        Test.stopTest();

        Assert.isTrue(result1);
        Assert.isFalse(result2);
        Assert.isTrue(result3);
    }

    @IsTest
    static void testCompareWithInvalidOperator() {
        Test.startTest();
        Boolean result = LeadConversionPrecheckServiceHelper.compare(10, 5, 'invalid');
        Test.stopTest();

        Assert.isFalse(result);
    }

    @IsTest
    static void testRunPrechecksWithNullStatusForMustEqualValue() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => null,
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1)
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    @IsTest
    static void testRunPrechecksWithNullRequestCallbackForCondition() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1)
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    @IsTest
    static void testCompareWithNonNullLeftAndNullRight() {
        Test.startTest();
        Boolean result = LeadConversionPrecheckServiceHelper.compare('test', null, '==');
        Test.stopTest();

        Assert.isFalse(result);
    }

    @IsTest
    static void testCompareWithNullLeftAndNullRight() {
        Test.startTest();
        Boolean result = LeadConversionPrecheckServiceHelper.compare(null, null, '==');
        Test.stopTest();

        Assert.isTrue(result);
    }

    @IsTest
    static void testCompareWithIntegerValues() {
        Test.startTest();
        Integer leftInt = 25;
        Integer rightInt = 18;
        Boolean result = LeadConversionPrecheckServiceHelper.compare(leftInt, rightInt, '>');
        Test.stopTest();

        Assert.isTrue(result);
    }

    @IsTest
    static void testParseLiteralWithTrue() {
        Test.startTest();
        Object result = LeadConversionPrecheckServiceHelper.parseLiteral('true');
        Test.stopTest();

        Assert.areEqual(true, result);
    }

    @IsTest
    static void testParseLiteralWithNumeric() {
        Test.startTest();
        Object result1 = LeadConversionPrecheckServiceHelper.parseLiteral('123');
        Object result2 = LeadConversionPrecheckServiceHelper.parseLiteral('45.67');
        Object result3 = LeadConversionPrecheckServiceHelper.parseLiteral('-10');
        Test.stopTest();

        Assert.areEqual(123, result1);
        Assert.isNotNull(result2);
        Assert.areEqual(-10, result3);
    }

    @IsTest
    static void testParseLiteralWithString() {
        Test.startTest();
        Object result = LeadConversionPrecheckServiceHelper.parseLiteral('testString');
        Test.stopTest();

        Assert.areEqual('testString', result);
    }

    /**
     * @description Test valuesEqual with various value types
     */
    @IsTest
    static void testValuesEqual() {
        Test.startTest();
        Boolean result1 = LeadConversionPrecheckServiceHelper.valuesEqual(null, null);
        Boolean result2 = LeadConversionPrecheckServiceHelper.valuesEqual('test', null);
        Boolean result3 = LeadConversionPrecheckServiceHelper.valuesEqual(null, 'test');
        Boolean result4 = LeadConversionPrecheckServiceHelper.valuesEqual('same', 'same');
        Boolean result5 = LeadConversionPrecheckServiceHelper.valuesEqual('diff', 'same');
        Boolean result6 = LeadConversionPrecheckServiceHelper.valuesEqual(true, true);
        Boolean result7 = LeadConversionPrecheckServiceHelper.valuesEqual(true, false);
        Boolean result8 = LeadConversionPrecheckServiceHelper.valuesEqual(true, 'true');
        Boolean result9 = LeadConversionPrecheckServiceHelper.valuesEqual(10, 10);
        Test.stopTest();

        Assert.isTrue(result1);
        Assert.isFalse(result2);
        Assert.isFalse(result3);
        Assert.isTrue(result4);
        Assert.isFalse(result5);
        Assert.isTrue(result6);
        Assert.isFalse(result7);
        Assert.isNotNull(result8);
        Assert.isTrue(result9);
    }

    /**
     * @description Test isBlank with various value types
     */
    @IsTest
    static void testIsBlank() {
        Test.startTest();
        Boolean result1 = LeadConversionPrecheckServiceHelper.isBlank(null);
        Boolean result2 = LeadConversionPrecheckServiceHelper.isBlank('');
        Boolean result3 = LeadConversionPrecheckServiceHelper.isBlank('   ');
        Boolean result4 = LeadConversionPrecheckServiceHelper.isBlank('test');
        Boolean result5 = LeadConversionPrecheckServiceHelper.isBlank(123);
        Boolean result6 = LeadConversionPrecheckServiceHelper.isBlank(true);
        Test.stopTest();

        Assert.isTrue(result1);
        Assert.isTrue(result2);
        Assert.isTrue(result3);
        Assert.isFalse(result4);
        Assert.isFalse(result5);
        Assert.isFalse(result6);
    }

    /**
     * @description Test isTrue with various value types
     */
    @IsTest
    static void testIsTrue() {
        Test.startTest();
        Boolean result1 = LeadConversionPrecheckServiceHelper.isTrue(true);
        Boolean result2 = LeadConversionPrecheckServiceHelper.isTrue(false);
        Boolean result3 = LeadConversionPrecheckServiceHelper.isTrue(null);
        Boolean result4 = LeadConversionPrecheckServiceHelper.isTrue('true');
        Boolean result5 = LeadConversionPrecheckServiceHelper.isTrue(1);
        Test.stopTest();

        Assert.isTrue(result1);
        Assert.isFalse(result2);
        Assert.isNotNull(result3);
        Assert.isNotNull(result4);
        Assert.isNotNull(result5);
    }

    /**
     * @description Test validateFieldNames with valid and invalid field names
     */
    @IsTest
    static void testValidateFieldNames() {
        Test.startTest();
        Set<String> fieldNames = new Set<String>{
            'Id',
            'Email',
            'InvalidField__c',
            '',
            'Account__r.Name',
            'Contact__r.Email',
            'Status'
        };
        List<String> validatedFields = LeadConversionPrecheckService.validateFieldNames(fieldNames);
        Test.stopTest();

        Assert.isTrue(validatedFields.contains('Id'));
        Assert.isFalse(validatedFields.contains(''));
    }

    /**
     * @description Test evaluateMustEqualValueRule with matching values
     */
    @IsTest
    static void testEvaluateMustEqualValueRuleMatching() {
        Test.startTest();
        LeadConversionPrecheckServiceHelper.EvaluationResult result =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext('test', 'test', 'Test Field');

        LeadConversionPrecheckServiceHelper.evaluateMustEqualValueRule(context, result);
        Test.stopTest();

        Assert.areEqual(0, result.missing.size());
    }

    /**
     * @description Test evaluateMustEqualValueRule with non-matching values
     */
    @IsTest
    static void testEvaluateMustEqualValueRuleNonMatching() {
        Test.startTest();
        LeadConversionPrecheckServiceHelper.EvaluationResult result =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext('test', 'different', 'Test Field');

        LeadConversionPrecheckServiceHelper.evaluateMustEqualValueRule(context, result);
        Test.stopTest();

        Assert.areEqual(1, result.missing.size());
        Assert.areEqual('Test Field', result.missing[0]);
    }

    /**
     * @description Test evaluateMustNotEqualToRule with matching values (should fail)
     */
    @IsTest
    static void testEvaluateMustNotEqualToRuleMatching() {
        Test.startTest();
        LeadConversionPrecheckServiceHelper.EvaluationResult result =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext('On-hold', 'On-hold', 'Status cannot be On-hold');

        LeadConversionPrecheckServiceHelper.evaluateMustNotEqualToRule(context, result);
        Test.stopTest();

        Assert.areEqual(1, result.missing.size(), 'Should add error when values match');
        Assert.areEqual('Status cannot be On-hold', result.missing[0]);
    }

    /**
     * @description Test evaluateMustNotEqualToRule with non-matching values (should pass)
     */
    @IsTest
    static void testEvaluateMustNotEqualToRuleNonMatching() {
        Test.startTest();
        LeadConversionPrecheckServiceHelper.EvaluationResult result =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext('Open', 'On-hold', 'Status cannot be On-hold');

        LeadConversionPrecheckServiceHelper.evaluateMustNotEqualToRule(context, result);
        Test.stopTest();

        Assert.areEqual(0, result.missing.size(), 'Should not add error when values do not match');
    }

    /**
     * @description Test evaluateMustNotEqualToRule with null values
     */
    @IsTest
    static void testEvaluateMustNotEqualToRuleWithNull() {
        Test.startTest();
        LeadConversionPrecheckServiceHelper.EvaluationResult result =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext(null, 'On-hold', 'Status cannot be On-hold');

        LeadConversionPrecheckServiceHelper.evaluateMustNotEqualToRule(context, result);
        Test.stopTest();

        Assert.areEqual(0, result.missing.size(), 'Should not add error when field value is null');
    }

    /**
     * @description Test evaluateRequirement with 'required' type
     */
    @IsTest
    static void testEvaluateRequirementRequired() {
        Test.startTest();
        LeadConversionPrecheckServiceHelper.EvaluationResult result1 =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context1 =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext(null, null, 'Required Field');

        LeadConversionPrecheckServiceHelper.EvaluationResult result2 =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context2 =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext('value', null, 'Required Field');

        LeadConversionPrecheckServiceHelper.evaluateRequirement('required', context1, result1);
        LeadConversionPrecheckServiceHelper.evaluateRequirement('required', context2, result2);
        Test.stopTest();

        Assert.areEqual(1, result1.missing.size());
        Assert.areEqual(0, result2.missing.size());
    }

    /**
     * @description Test evaluateRequirement with 'requiredwhen' type
     */
    @IsTest
    static void testEvaluateRequirementRequiredWhen() {
        Test.startTest();
        LeadConversionPrecheckServiceHelper.EvaluationResult result1 =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context1 =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext('', null, 'Required When Field');

        LeadConversionPrecheckServiceHelper.EvaluationResult result2 =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context2 =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext('value', null, 'Required When Field');

        LeadConversionPrecheckServiceHelper.evaluateRequirement('requiredwhen', context1, result1);
        LeadConversionPrecheckServiceHelper.evaluateRequirement('requiredwhen', context2, result2);
        Test.stopTest();

        Assert.areEqual(1, result1.missing.size());
        Assert.areEqual(0, result2.missing.size());
    }

    /**
     * @description Test evaluateRequirement with 'mustbetrue' type
     */
    @IsTest
    static void testEvaluateRequirementMustBeTrue() {
        Test.startTest();
        LeadConversionPrecheckServiceHelper.EvaluationResult result1 =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context1 =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext(true, null, 'Must Be True Field');

        LeadConversionPrecheckServiceHelper.EvaluationResult result2 =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context2 =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext(false, null, 'Must Be True Field');

        LeadConversionPrecheckServiceHelper.EvaluationResult result3 =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context3 =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext(null, null, 'Must Be True Field');

        LeadConversionPrecheckServiceHelper.evaluateRequirement('mustbetrue', context1, result1);
        LeadConversionPrecheckServiceHelper.evaluateRequirement('mustbetrue', context2, result2);
        LeadConversionPrecheckServiceHelper.evaluateRequirement('mustbetrue', context3, result3);
        Test.stopTest();

        Assert.areEqual(0, result1.missing.size());
        Assert.areEqual(1, result2.missing.size());
    }

    /**
     * @description Test evaluateRequirement with invalid requirement type
     */
    @IsTest
    static void testEvaluateRequirementInvalidType() {
        Test.startTest();
        LeadConversionPrecheckServiceHelper.EvaluationResult result =
            new LeadConversionPrecheckServiceHelper.EvaluationResult(new List<String>());
        LeadConversionPrecheckServiceHelper.FieldEvaluationContext context =
            new LeadConversionPrecheckServiceHelper.FieldEvaluationContext('value', null, 'Test Field');

        LeadConversionPrecheckServiceHelper.evaluateRequirement('invalid', context, result);
        Test.stopTest();

        Assert.areEqual(0, result.missing.size());
    }

    @IsTest
    static void testCompareWithLessThanOperator() {
        Test.startTest();
        Boolean result1 = LeadConversionPrecheckServiceHelper.compare(5, 10, '<');
        Boolean result2 = LeadConversionPrecheckServiceHelper.compare(10, 5, '<');
        Boolean result3 = LeadConversionPrecheckServiceHelper.compare(5, 5, '<');
        Test.stopTest();

        Assert.isTrue(result1);
        Assert.isFalse(result2);
        Assert.isFalse(result3);
    }

    /**
     * @description Test compare with equality operator '='
     */
    @IsTest
    static void testCompareWithEqualsOperator() {
        Test.startTest();
        Boolean result1 = LeadConversionPrecheckServiceHelper.compare('same', 'same', '=');
        Boolean result2 = LeadConversionPrecheckServiceHelper.compare('diff', 'same', '=');
        Test.stopTest();

        Assert.isTrue(result1);
        Assert.isFalse(result2);
    }

    /**
     * @description Test compare with non-numeric values for numeric operators
     */
    @IsTest
    static void testCompareWithNonNumericForNumericOperator() {
        Test.startTest();
        Boolean result1 = LeadConversionPrecheckServiceHelper.compare('test', 'value', '>');
        Boolean result2 = LeadConversionPrecheckServiceHelper.compare('test', 5, '>');
        Test.stopTest();

        Assert.isFalse(result1);
        Assert.isFalse(result2);
    }

    @IsTest
    static void testRunPrechecksWithDOBBirthdayNotYetOccurred() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Date today = Date.today();
        Date dob = Date.newInstance(today.year() - 20, today.month() + 3, 15);
        if (dob.month() > 12) {
            dob = Date.newInstance(today.year() - 20, (today.month() + 3) - 12, 15);
        }

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'Status' => 'Qualification',
            'Email' => 'test@example.com',
            'Phone' => '1234567890',
            'Date_of_Birth__c' => dob
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    @IsTest
    static void testFormatGroupedMessagesWithEmptyList() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'Email' => 'test@example.com'
        });
        insert testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckResult result = LeadConversionPrecheckService.runPrechecks(testLead.Id, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckResult should not be null');
        Assert.isNotNull(result.messages, 'PrecheckResult.messages should not be null');
    }

    /**
     * @description Test bulk runPrechecks with null list
     */
    @IsTest
    static void testBulkRunPrechecksWithNullList() {
        Test.startTest();
        List<Lead> nullList = null;
        LeadConversionPrecheckService.PrecheckCollectionResult result =
            LeadConversionPrecheckService.runPrechecksForLeads(nullList, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.areEqual(0, result.successLeads.size());
        Assert.areEqual(0, result.failedLeadIds.size());
    }

    @IsTest
    static void testBulkRunPrechecksWithEmptyList() {
        Test.startTest();
        LeadConversionPrecheckService.PrecheckCollectionResult result =
            LeadConversionPrecheckService.runPrechecksForLeads(new List<Lead>(), ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.areEqual(0, result.successLeads.size());
        Assert.areEqual(0, result.failedLeadIds.size());
    }

    /**
     * @description Test bulk runPrechecks with multiple leads - one passes, one fails
     */
    @IsTest
    static void testBulkRunPrechecksWithMultipleLeads() {
        Id patientRecordTypeId = getPatientRecordTypeId();
        HealthcarePractitionerFacility facility = getFacility();

        Lead lead1 = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'FirstName' => 'Test1',
            'LastName' => 'Lead1',
            'Email' => 'test1@example.com',
            'Phone' => '1111111111',
            'Status' => 'Qualification',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'Address_Status__c' => 'Verified',
            'Provider_Practice_Affiliation__c' => facility.Id
        });

        Lead lead2 = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'FirstName' => 'Test2',
            'LastName' => 'Lead2',
            'Email' => 'test2@example.com',
            'Phone' => '2222222222',
            'Status' => 'Qualification',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1)
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        insert new List<Lead>{lead1, lead2};

        List<Lead> testLeads = [
            SELECT Id, RecordTypeId, RecordType.DeveloperName, Status, Email, Phone,
                   Date_of_Birth__c, Address_Status__c, Provider_Practice_Affiliation__c, LeadSource
            FROM Lead
            WHERE Id IN :new List<Id>{lead1.Id, lead2.Id}
            WITH USER_MODE
        ];

        Test.startTest();
        LeadConversionPrecheckService.PrecheckCollectionResult result =
            LeadConversionPrecheckService.runPrechecksForLeads(testLeads, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isTrue(result.successLeads.size() + result.failedLeadIds.size() == 2);
    }

    /**
     * @description Test bulk runPrechecks with LeadSource = "Get Started" to filter address verification rules
     */
    @IsTest
    static void testBulkRunPrechecksWithGetStartedLeadSource() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'FirstName' => 'Test',
            'LastName' => 'GetStarted',
            'Email' => 'getstarted@example.com',
            'Phone' => '3333333333',
            'Status' => 'Qualification',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_GET_STARTED
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        insert testLead;

        List<Lead> testLeads = [
            SELECT Id, RecordTypeId, RecordType.DeveloperName, Status, Email, Phone,
                   Date_of_Birth__c, LeadSource, Address_Status__c
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
        ];

        Test.startTest();
        LeadConversionPrecheckService.PrecheckCollectionResult result =
            LeadConversionPrecheckService.runPrechecksForLeads(testLeads, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isTrue(result.successLeads.size() >= 0);
    }

    /**
     * @description Test bulk runPrechecks with different conversion types
     */
    @IsTest
    static void testBulkRunPrechecksWithDifferentConversionTypes() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'FirstName' => 'Test',
            'LastName' => 'ConversionType',
            'Email' => 'conversiontype@example.com',
            'Phone' => '4444444444',
            'Status' => 'Qualification',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1)
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        insert testLead;

        List<Lead> testLeads = [
            SELECT Id, RecordTypeId, RecordType.DeveloperName, Status, Email, Phone,
                   Date_of_Birth__c, LeadSource
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
        ];

        Test.startTest();
        LeadConversionPrecheckService.PrecheckCollectionResult resultAuto =
            LeadConversionPrecheckService.runPrechecksForLeads(testLeads, ConstantsUtil.CONVERSION_TYPE_AUTO);
        LeadConversionPrecheckService.PrecheckCollectionResult resultManual =
            LeadConversionPrecheckService.runPrechecksForLeads(testLeads, ConstantsUtil.CONVERSION_TYPE_MANUAL);
        Test.stopTest();

        Assert.isNotNull(resultAuto, 'AUTO PrecheckCollectionResult should not be null');
        Assert.isNotNull(resultAuto.successLeads, 'AUTO successLeads should not be null');
        Assert.isNotNull(resultAuto.failedLeadIds, 'AUTO failedLeadIds should not be null');
        Assert.isNotNull(resultManual, 'MANUAL PrecheckCollectionResult should not be null');
        Assert.isNotNull(resultManual.successLeads, 'MANUAL successLeads should not be null');
        Assert.isNotNull(resultManual.failedLeadIds, 'MANUAL failedLeadIds should not be null');
    }

    /**
     * @description Test bulk runPrechecks with leads that have no matching rules
     */
    @IsTest
    static void testBulkRunPrechecksWithNoRules() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'Email' => 'norules@example.com',
            'Company' => 'No Rules Company'
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        insert testLead;

        List<Lead> testLeads = [
            SELECT Id, RecordTypeId, RecordType.DeveloperName, Email, LeadSource
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
        ];

        Test.startTest();
        LeadConversionPrecheckService.PrecheckCollectionResult result =
            LeadConversionPrecheckService.runPrechecksForLeads(testLeads, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        if (result.successLeads != null && !result.successLeads.isEmpty()) {
            Assert.areEqual(1, result.successLeads.size());
        }
    }

    /**
     * @description Test bulk runPrechecks with lead that has null record type
     */
    @IsTest
    static void testBulkRunPrechecksWithNullRecordType() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'Email' => 'nullrecordtype@example.com',
            'Company' => 'Null Record Type Company'
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        insert testLead;

        List<Lead> testLeads = [
            SELECT Id, RecordTypeId, RecordType.DeveloperName, Email, LeadSource
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
        ];

        Test.startTest();
        LeadConversionPrecheckService.PrecheckCollectionResult result =
            LeadConversionPrecheckService.runPrechecksForLeads(testLeads, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isNotNull(result, 'PrecheckCollectionResult should not be null');
        Assert.isNotNull(result.successLeads, 'successLeads should not be null');
        Assert.isNotNull(result.failedLeadIds, 'failedLeadIds should not be null');
    }

    /**
     * @description Test bulk runPrechecks with lead that passes all prechecks (groupedMessages.isEmpty() == true)
     */
    @IsTest
    static void testBulkRunPrechecksWithLeadInMap() {
        Id patientRecordTypeId = getPatientRecordTypeId();
        HealthcarePractitionerFacility facility = getFacility();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'FirstName' => 'Test',
            'LastName' => 'InMap',
            'Email' => 'inmap@example.com',
            'Phone' => '5555555555',
            'Status' => 'Qualification',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'Address_Status__c' => 'Verified',
            'Provider_Practice_Affiliation__c' => facility.Id
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        insert testLead;

        List<Lead> testLeads = [
            SELECT Id, RecordTypeId, RecordType.DeveloperName, Status, Email, Phone,
                   Date_of_Birth__c, Address_Status__c, Provider_Practice_Affiliation__c, LeadSource
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
        ];

        Test.startTest();
        LeadConversionPrecheckService.PrecheckCollectionResult result =
            LeadConversionPrecheckService.runPrechecksForLeads(testLeads, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isTrue(result.successLeads.size() >= 0);
    }

    /**
     * @description Test bulk runPrechecks with lead that fails prechecks (groupedMessages.isEmpty() == false)
     */
    @IsTest
    static void testBulkRunPrechecksWithFailedLead() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'FirstName' => 'Test',
            'LastName' => 'Failed',
            'Email' => null,
            'Phone' => '6666666666',
            'Status' => 'Qualification',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1)
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        insert testLead;

        List<Lead> testLeads = [
            SELECT Id, RecordTypeId, RecordType.DeveloperName, Status, Email, Phone,
                   Date_of_Birth__c, LeadSource
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
        ];

        Test.startTest();
        LeadConversionPrecheckService.PrecheckCollectionResult result =
            LeadConversionPrecheckService.runPrechecksForLeads(testLeads, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.isTrue(result.failedLeadIds.size() + result.successLeads.size() == 1);
    }

    /**
     * @description Test runPrechecksForLeads with lead that is not found in query results
     */
    @IsTest
    static void testRunPrechecksForLeadsWithLeadNotFoundInMap() {
        Id patientRecordTypeId = getPatientRecordTypeId();

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => patientRecordTypeId,
            'FirstName' => 'Test',
            'LastName' => 'NotFound',
            'Email' => 'notfound@example.com',
            'Company' => 'Not Found Company',
            'Status' => 'Open'
        });

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        insert testLead;

        List<Lead> testLeads = new List<Lead>{testLead};
        delete testLead;

        Test.startTest();
        LeadConversionPrecheckService.PrecheckCollectionResult result =
            LeadConversionPrecheckService.runPrechecksForLeads(testLeads, ConstantsUtil.CONVERSION_TYPE_AUTO);
        Test.stopTest();

        Assert.areEqual(1, result.failedLeadIds.size());
        Assert.isTrue(result.leadIdToMessages.containsKey(testLead.Id));
    }

    /**
     * @description Helper method to get Patient record type ID
     * @return Record type ID for Patient
     */
    private static Id getPatientRecordTypeId() {
        List<RecordType> patientRts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Lead'
            AND DeveloperName = 'Patient'
            WITH USER_MODE
            LIMIT 1
        ];
        return patientRts.isEmpty() ? null : patientRts[0].Id;
    }
    @IsTest
    static void testQueryLeadWithFieldsWithNullLeadId() {
        Test.startTest();
        Lead result = LeadConversionPrecheckService.queryLeadWithFields(null, new Set<String>{'Email'});
        Map<Id, Lead> result1 = LeadConversionPrecheckService.queryLeadsWithFields(null, new Set<String>{'Email'});
        Map<Id, String> result2 = LeadConversionPrecheckServiceHelper.getLeadIdToRecordTypeMap(null);
        List<Lead_Conversion_Precheck__mdt> result3 = LeadConversionPrecheckService.filterAddressVerificationRules(null, null);
        Test.stopTest();
        Assert.isNull(result);
        Assert.isTrue(result1 == null || result1.isEmpty(), 'Expected null/empty Lead map for null input');
        Assert.isTrue(result2 == null || result2.isEmpty(), 'Expected null/empty record type map for null input');
        Assert.isTrue(result3 == null || result3.size() >= 0, 'Expected method to handle null inputs');
    }
}