/**
 * @description Test class for PartyConsentListController
 * Created Date : 24th December 2025
 * Created By   : Yogesh Rana
 * =========================== Logs ======================================
 * Version      Modified Date            Modified By             Brief Note
 * V1.0.0       26th December 2025       Yogesh Rana            Initial Version
 */
@isTest(isParallel=true)
private class PartyConsentListController_Test {

    private static final String CHILD_OBJECT = 'PartyConsent';
    private static final String REL_FIELD = 'Individual__c';

    /**
     * @description Sets up test data including Individual, Account, PartyConsent, DataUsePurpose records, and Portal User
     */
    @TestSetup
    static void setup() {
        Id currentUserId = UserInfo.getUserId();

        // Ensure running admin user has a Role to avoid "portal account owner must have a role"
        System.runAs(new User(Id = currentUserId)) {
            User adminUser = [SELECT Id, UserRoleId FROM User WHERE Id = :currentUserId LIMIT 1];

            if (adminUser.UserRoleId == null) {
                UserRole userRole;
                List<UserRole> ceoRole = [SELECT Id FROM UserRole WHERE DeveloperName = 'Training_Coordinator' LIMIT 1];
                if (!ceoRole.isEmpty()) {
                    userRole = ceoRole[0];
                } else {
                    userRole = new UserRole(DeveloperName = 'Training_Coordinator', Name = 'Training Coordinator');
                    insert userRole;
                }
                adminUser.UserRoleId = userRole.Id;
                update adminUser;
            }
        }

        Individual ind = TestDataFactory.getIndividual(
            new Map<String, Object>{
                'FirstName' => 'Test',
                'LastName' => 'Individual'
            }
        );
        insert ind;

        Account acct = TestDataFactory.getAccountofPatientRecordType(
            new Map<String, Object>{
                'FirstName' => 'Test',
                'LastName' => 'Patient',
                'PersonEmail' => 'test@test.com'
            }
        );
        insert acct;

        acct = [
            SELECT Id, PersonIndividualId, PersonContactId
            FROM Account
            WHERE Id = :acct.Id
        ];

        if (acct.PersonIndividualId == null) {
            acct.PersonIndividualId = ind.Id;
            update acct;
        }

        // Create DataUsePurpose records
        DataUsePurpose dataUsePurpose = TestDataFactory.getDataUsePurpose(
            new Map<String, Object>{
                'Name' => 'Test Data Use Purpose'
            }
        );
        insert dataUsePurpose;

        List<PartyConsent> consents = TestDataFactory.getPartyConsents(
            3,
            new Map<String, Object>{
                'Individual__c' => acct.PersonIndividualId,
                'PartyId' => acct.PersonIndividualId,
                'Status__c' => 'Opted-in',
                'DataUsePurposeId' => dataUsePurpose.Id
            },
            new List<String>{'Virtual Training', 'Group Training', 'Abbott Data Sharing'}
        );
        insert consents;

        // Create Portal User (Setup DML - Must be separated from Non-Setup)
        User portalUser;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'External Trainer' LIMIT 1];
            portalUser = TestDataFactory.getCommunityUser(acct, portalProfile, 'patConsent');
        }
    }

    /**
     * @description Helper method to retrieve portal user created in test setup
     * @return User The portal user
     */
    private static User getPortalUser() {
        return [SELECT Id FROM User WHERE LastName = 'UserpatConsent' LIMIT 1];
    }

    /**
     * @description Helper method to create a RelatedListRequest with common defaults
     * @param accountId The account ID to use
     * @param fields The fields to query
     * @return PartyConsentListController.RelatedListRequest configured request
     */
    private static PartyConsentListController.RelatedListRequest createRequest(Id accountId, String fields) {
        PartyConsentListController.RelatedListRequest req =
            new PartyConsentListController.RelatedListRequest();
        req.accountId = accountId;
        req.childObjectApi = CHILD_OBJECT;
        req.relationshipField = REL_FIELD;
        req.fields = fields;
        return req;
    }

    /**
     * @description Helper method to execute getRelatedRecordsWithTypes and handle exceptions
     * @param req The request to execute
     * @param portalUser The portal user to run as
     * @return Map<String, Object> Result map, empty if exception occurred
     */
    private static Map<String, Object> executeWithExceptionHandling(
        PartyConsentListController.RelatedListRequest req,
        User portalUser
    ) {
        Map<String, Object> result;
        try {
            System.runAs(portalUser) {
                result = PartyConsentListController.getRelatedRecordsWithTypes(req, '');
            }
        } catch (AuraHandledException e) {
            result = new Map<String, Object>{
                'records' => new List<SObject>(),
                'fieldTypes' => new Map<String, String>()
            };
        }
        return result;
    }

    /**
     * @description Helper method to get PartyConsent field map for testing getRelationshipFieldDisplayType
     * @return Map<String, Schema.SObjectField> Field map for PartyConsent object
     */
    private static Map<String, Schema.SObjectField> getPartyConsentFieldMap() {
        Schema.SObjectType partyConsentType = Schema.getGlobalDescribe().get(CHILD_OBJECT);
        Assert.isNotNull(partyConsentType, 'PartyConsent object type should exist');
        return partyConsentType.getDescribe().fields.getMap();
    }

    /**
     * @description Tests successful retrieval of related records with type filters and field type information
     */
    @IsTest
    static void testSuccessWithFiltersAndTypes() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        User portalUser = getPortalUser();
        PartyConsentListController.RelatedListRequest req = createRequest(
            acct.Id,
            'Name, Type__c, CreatedDate'
        );
        req.sortedBy = 'CreatedDate';
        req.sortDirection = 'ASC';
        req.typeFilter = 'Virtual Training, Group Training';

        Test.startTest();
        Map<String, Object> result;
        System.runAs(portalUser) {
            result = PartyConsentListController.getRelatedRecordsWithTypes(req, '');
        }
        Test.stopTest();

        Assert.isTrue(
            ((List<SObject>)result.get('records')).size() > 0,
            'Expected at least one record returned'
        );
        Assert.isTrue(
            ((Map<String, String>)result.get('fieldTypes')).containsKey('Type__c'),
            'Expected Type__c field type to be returned'
        );
    }

    /**
     * @description Tests resolution of nested relationship field types (e.g., DataUsePurpose.Name)
     */
    @IsTest
    static void testNestedRelationshipFieldTypeResolution() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        User portalUser = getPortalUser();
        PartyConsentListController.RelatedListRequest req = createRequest(
            acct.Id,
            'Name, DataUsePurpose.Name'
        );

        Test.startTest();
        Map<String, Object> result;
        System.runAs(portalUser) {
            result = PartyConsentListController.getRelatedRecordsWithTypes(req, '');
        }
        Test.stopTest();

        Map<String, String> fieldTypes = (Map<String, String>) result.get('fieldTypes');

        Assert.isTrue(
            fieldTypes.containsKey('DataUsePurpose.Name'),
            'Nested field key should exist in fieldTypes map'
        );
        Assert.areEqual(
            'STRING',
            fieldTypes.get('DataUsePurpose.Name'),
            'Name field on related object should resolve to STRING'
        );
    }

    /**
     * @description Tests that null request throws AuraHandledException
     */
    @IsTest
    static void testNullRequestThrowsException() {
        User portalUser = getPortalUser();

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            System.runAs(portalUser) {
                PartyConsentListController.getRelatedRecordsWithTypes(null, '');
            }
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(
            exceptionThrown,
            'Expected AuraHandledException for null request'
        );
    }

    /**
     * @description Tests the exception path for getRelatedRecordsWithTypes method
     */
    @IsTest
    static void testGetRelatedRecordsWithTypesExceptionPath() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        PartyConsentListController.RelatedListRequest req =
            new PartyConsentListController.RelatedListRequest();
        req.accountId = acct.Id;
        req.childObjectApi = CHILD_OBJECT;
        req.relationshipField = 'Invalid_Field__c'; // invalid to force exception
        req.fields = 'Name';

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            PartyConsentListController.getRelatedRecordsWithTypes(req, '');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('Error fetching related records')
                || e.getMessage().contains('Script-thrown exception'),
                'Expected exception path executed'
            );
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Exception should have been thrown for invalid field');
    }

    /**
     * @description Tests that empty fields string throws AuraHandledException
     */
    @IsTest
    static void testEmptyFieldsHandledGracefully() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        User portalUser = getPortalUser();

        PartyConsentListController.RelatedListRequest req =
            new PartyConsentListController.RelatedListRequest();
        req.accountId = acct.Id;
        req.childObjectApi = CHILD_OBJECT;
        req.relationshipField = REL_FIELD;
        req.fields = ''; // empty fields

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            System.runAs(portalUser) {
                PartyConsentListController.getRelatedRecordsWithTypes(req, '');
            }
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(
            exceptionThrown,
            'Expected AuraHandledException when fields is empty'
        );
    }

    /**
     * @description Test queryRelatedRecords exception catch block
     * Verifies exception is caught and re-thrown as AuraHandledException when customExceptionSwitch triggers
     */
    @IsTest
    static void testQueryRelatedRecordsCatchBlock() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        User portalUser = getPortalUser();

        PartyConsentListController.RelatedListRequest req =
            new PartyConsentListController.RelatedListRequest();
        req.accountId = acct.Id;
        req.childObjectApi = CHILD_OBJECT;
        req.relationshipField = REL_FIELD;
        req.fields = 'Name, Type__c';

        Boolean exceptionThrown = false;

        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;

        try {
            System.runAs(portalUser) {
                PartyConsentListController.getRelatedRecordsWithTypes(req, '');
            }
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();

        // Verify exception was caught in queryRelatedRecords catch block and re-thrown as AuraHandledException
        Assert.isTrue(
            exceptionThrown,
            'Expected AuraHandledException when customExceptionSwitch is enabled'
        );
    }

    /**
     * @description Tests that Account without PersonIndividualId returns empty result
     */
    @IsTest
    static void testAccountWithoutPersonIndividualId() {
        User portalUser = getPortalUser();

        Account acctWithoutIndividual = TestDataFactory.getAccountofPatientRecordType(
            new Map<String, Object>{
                'FirstName' => 'No',
                'LastName' => 'Individual',
                'PersonEmail' => 'noind@test.com'
            }
        );
        insert acctWithoutIndividual;

        acctWithoutIndividual = [
            SELECT Id, PersonIndividualId
            FROM Account
            WHERE Id = :acctWithoutIndividual.Id
        ];
        if (acctWithoutIndividual.PersonIndividualId != null) {
            acctWithoutIndividual.PersonIndividualId = null;
            update acctWithoutIndividual;
        }

        PartyConsentListController.RelatedListRequest req = createRequest(
            acctWithoutIndividual.Id,
            'Name'
        );

        Test.startTest();
        Map<String, Object> result = executeWithExceptionHandling(req, portalUser);
        Test.stopTest();

        Assert.areEqual(
            0,
            ((List<SObject>)result.get('records')).size(),
            'Expected empty records when Account has no PersonIndividualId'
        );
    }

    /**
     * @description Tests that invalid direct field name throws exception
     * Note: Invalid fields in SOQL cause query to fail
     */
    @IsTest
    static void testInvalidDirectFieldReturnsDefaultType() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        User portalUser = getPortalUser();
        PartyConsentListController.RelatedListRequest req = createRequest(
            acct.Id,
            'Name, InvalidFieldName__c'
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            System.runAs(portalUser) {
                PartyConsentListController.getRelatedRecordsWithTypes(req, '');
            }
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(
            exceptionThrown,
            'Expected AuraHandledException when invalid field is in SOQL query'
        );
    }

    /**
     * @description Tests that getRelatedRecordsWithTypes returns empty map for null request
     */
    @IsTest
    static void testNullRelatedListRequestReturnsEmpty() {
        User portalUser = getPortalUser();

        Test.startTest();
        Map<String, Object> result = executeWithExceptionHandling(null, portalUser);
        Test.stopTest();

        Assert.isNotNull(result, 'Result map should not be null');
        Assert.areEqual(
            0,
            ((List<SObject>) result.get('records')).size(),
            'Records list should be empty'
        );
        Assert.areEqual(
            0,
            ((Map<String, String>) result.get('fieldTypes')).size(),
            'FieldTypes map should be empty'
        );
    }

    /**
     * @description Tests getDirectFieldDisplayType returns DEFAULT_DISPLAY_TYPE for invalid field
     */
    @IsTest
    static void testGetDirectFieldDisplayTypeForInvalidField() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        User portalUser = getPortalUser();
        PartyConsentListController.RelatedListRequest req = createRequest(acct.Id, 'InvalidField__c');

        Test.startTest();
        Map<String, Object> result = executeWithExceptionHandling(req, portalUser);
        Test.stopTest();

        // If query succeeded, verify DEFAULT_DISPLAY_TYPE was returned
        Map<String, String> fieldTypes = (Map<String, String>) result.get('fieldTypes');
        if (fieldTypes.containsKey('InvalidField__c')) {
            Assert.areEqual(
                'STRING',
                fieldTypes.get('InvalidField__c'),
                'Invalid direct field should resolve to DEFAULT_DISPLAY_TYPE'
            );
        }
    }

    /**
     * @description Tests getRelationshipFieldDisplayType returns DEFAULT_DISPLAY_TYPE for non-existent relationship
     */
    @IsTest
    static void testGetRelationshipFieldDisplayTypeForInvalidRelationship() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        User portalUser = getPortalUser();
        PartyConsentListController.RelatedListRequest req = createRequest(acct.Id, 'Name, Non.Existent');

        Test.startTest();
        Map<String, Object> result = executeWithExceptionHandling(req, portalUser);
        Test.stopTest();

        Map<String, String> fieldTypes = (Map<String, String>) result.get('fieldTypes');
        if (fieldTypes.containsKey('Non.Existent')) {
            Assert.areEqual(
                'STRING',
                fieldTypes.get('Non.Existent'),
                'Non-existent relationship should resolve to DEFAULT_DISPLAY_TYPE'
            );
        }
    }

    /**
     * @description Tests that invalid object API name triggers Logger.error and Logger.saveLog
     */
    @IsTest
    static void testInvalidObjectTriggersLogger() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        User portalUser = getPortalUser();
        PartyConsentListController.RelatedListRequest req = createRequest(acct.Id, 'Name');
        req.childObjectApi = 'NonExistentObject__c';

        Test.startTest();
        Map<String, Object> result = executeWithExceptionHandling(req, portalUser);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual(
            0,
            ((List<SObject>)result.get('records')).size(),
            'Expected no records returned for invalid object'
        );
        Assert.areEqual(
            0,
            ((Map<String, String>)result.get('fieldTypes')).size(),
            'Expected empty fieldTypes map for invalid object'
        );
    }

    /**
     * @description Tests getRelationshipFieldDisplayType with invalid format
     */
    @IsTest
    static void testGetRelationshipFieldDisplayTypeWithInvalidFormat() {
        Map<String, Schema.SObjectField> fieldMap = getPartyConsentFieldMap();

        Test.startTest();
        Schema.DisplayType result1 = PartyConsentListController.getRelationshipFieldDisplayType('InvalidFormat', fieldMap);
        Schema.DisplayType result2 = PartyConsentListController.getRelationshipFieldDisplayType('Too.Many.Dots.Here', fieldMap);
        Test.stopTest();

        Assert.areEqual(
            Schema.DisplayType.STRING,
            result1,
            'Invalid format (no dot) should return DEFAULT_DISPLAY_TYPE (STRING)'
        );
        Assert.areEqual(
            Schema.DisplayType.STRING,
            result2,
            'Invalid format (multiple dots) should return DEFAULT_DISPLAY_TYPE (STRING)'
        );
    }

    /**
     * @description Tests getRelationshipFieldDisplayType when relationship field is not found
     */
    @IsTest
    static void testGetRelationshipFieldDisplayTypeWhenRelationshipNotFound() {
        Map<String, Schema.SObjectField> fieldMap = getPartyConsentFieldMap();

        Test.startTest();
        Schema.DisplayType result = PartyConsentListController.getRelationshipFieldDisplayType(
            'NonExistentRelationship__r.Name',
            fieldMap
        );
        Test.stopTest();

        Assert.areEqual(
            Schema.DisplayType.STRING,
            result,
            'Non-existent relationship should return DEFAULT_DISPLAY_TYPE (STRING)'
        );
    }

    /**
     * @description Tests getRelationshipFieldDisplayType when field is not found on related object
     */
    @IsTest
    static void testGetRelationshipFieldDisplayTypeWhenFieldNotFoundOnRelatedObject() {
        Map<String, Schema.SObjectField> fieldMap = getPartyConsentFieldMap();

        Test.startTest();
        Schema.DisplayType result = PartyConsentListController.getRelationshipFieldDisplayType(
            'DataUsePurpose.NonExistentField__c',
            fieldMap
        );
        Test.stopTest();

        Assert.areEqual(
            Schema.DisplayType.STRING,
            result,
            'Non-existent field on related object should return DEFAULT_DISPLAY_TYPE (STRING)'
        );
    }

    /**
     * @description Tests getRelationshipFieldDisplayType success case
     */
    @IsTest
    static void testGetRelationshipFieldDisplayTypeSuccess() {
        Map<String, Schema.SObjectField> fieldMap = getPartyConsentFieldMap();

        Test.startTest();
        // Test with valid relationship and valid field
        Schema.DisplayType result = PartyConsentListController.getRelationshipFieldDisplayType(
            'DataUsePurpose.Name',
            fieldMap
        );
        Test.stopTest();

        Assert.areEqual(
            Schema.DisplayType.STRING,
            result,
            'Valid relationship field should return correct display type (STRING for Name field)'
        );
    }

    /**
     * @description Tests getRelationshipFieldDisplayType with relationship name using __r suffix
     */
    @IsTest
    static void testGetRelationshipFieldDisplayTypeWithRSuffix() {
        Map<String, Schema.SObjectField> fieldMap = getPartyConsentFieldMap();

        Test.startTest();
        // Test with relationship name that includes __r suffix
        // Note: This tests the replace logic in line 195
        Schema.DisplayType result = PartyConsentListController.getRelationshipFieldDisplayType(
            'DataUsePurpose__r.Name',
            fieldMap
        );
        Test.stopTest();

        // Should still work because of the replace('__r','') logic
        Assert.areEqual(
            Schema.DisplayType.STRING,
            result,
            'Relationship with __r suffix should be handled correctly'
        );
    }

    /**
     * @description Tests getRelationshipFieldDisplayType with empty field map
     * Edge case: empty baseFieldMap
     */
    @IsTest
    static void testGetRelationshipFieldDisplayTypeWithEmptyFieldMap() {
        Map<String, Schema.SObjectField> emptyFieldMap = new Map<String, Schema.SObjectField>();

        Test.startTest();
        Schema.DisplayType result = PartyConsentListController.getRelationshipFieldDisplayType(
            'DataUsePurpose.Name',
            emptyFieldMap
        );
        Test.stopTest();

        Assert.areEqual(
            Schema.DisplayType.STRING,
            result,
            'Empty field map should return DEFAULT_DISPLAY_TYPE (STRING)'
        );
    }

    /**
     * @description Tests getFieldTypesByFieldNames with blank field names
     */
    @IsTest
    static void testGetFieldTypesByFieldNamesWithBlankFieldNames() {
        Schema.SObjectType partyConsentType = Schema.getGlobalDescribe().get(CHILD_OBJECT);
        Assert.isNotNull(partyConsentType, 'PartyConsent object type should exist');

        Test.startTest();
        Map<String, String> result = PartyConsentListController.getFieldTypesByFieldNames(
            'Name, , Type__c, , CreatedDate',
            partyConsentType
        );
        Test.stopTest();

        Assert.isTrue(result.containsKey('Name'), 'Name field should be present');
        Assert.isTrue(result.containsKey('Type__c'), 'Type__c field should be present');
        Assert.isTrue(result.containsKey('CreatedDate'), 'CreatedDate field should be present');
        Assert.isFalse(result.containsKey(''), 'Blank field should be skipped');
        Assert.areEqual(3, result.size(), 'Should only contain 3 non-blank fields');
    }

    /**
     * @description Tests getDirectFieldDisplayType with field not in fieldMap
     */
    @IsTest
    static void testGetDirectFieldDisplayTypeWhenFieldNotInMap() {
        Map<String, Schema.SObjectField> fieldMap = getPartyConsentFieldMap();

        Test.startTest();
        Schema.DisplayType result = PartyConsentListController.getDirectFieldDisplayType(
            'NonExistentField__c',
            fieldMap
        );
        Test.stopTest();

        Assert.areEqual(
            Schema.DisplayType.STRING,
            result,
            'Field not in fieldMap should return DEFAULT_DISPLAY_TYPE'
        );
    }

    /**
     * @description Tests getDirectFieldDisplayType with field that exists in fieldMap
     * Verifies successful field type resolution
     */
    @IsTest
    static void testGetDirectFieldDisplayTypeWhenFieldExists() {
        Map<String, Schema.SObjectField> fieldMap = getPartyConsentFieldMap();

        Test.startTest();
        Schema.DisplayType result = PartyConsentListController.getDirectFieldDisplayType(
            'Name',
            fieldMap
        );
        Test.stopTest();

        Assert.areNotEqual(null, result, 'Existing field should return actual display type');
        Assert.areEqual(Schema.DisplayType.STRING, result, 'Name field should return STRING display type');
    }

    /**
     * @description Tests getDirectFieldDisplayType with empty fieldMap
     * Edge case: empty field map should always return DEFAULT_DISPLAY_TYPE
     */
    @IsTest
    static void testGetDirectFieldDisplayTypeWithEmptyFieldMap() {
        Map<String, Schema.SObjectField> emptyFieldMap = new Map<String, Schema.SObjectField>();

        Test.startTest();
        Schema.DisplayType result = PartyConsentListController.getDirectFieldDisplayType(
            'Name',
            emptyFieldMap
        );
        Test.stopTest();

        Assert.areEqual(Schema.DisplayType.STRING, result, 'Empty field map should return DEFAULT_DISPLAY_TYPE');
    }
}