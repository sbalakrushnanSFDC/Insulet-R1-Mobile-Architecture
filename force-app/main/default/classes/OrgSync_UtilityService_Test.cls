/**
 * @description Test class for OrgSync_UtilityService
 * Created Date : Jan 20, 2026
 * Created By   : Neeraj Kumar
 */
@IsTest
private class OrgSync_UtilityService_Test {

    @IsTest
    static void testIsOrgSyncUserTrueAndFalse() {
        // Force cached user id to avoid querying custom metadata
        OrgSync_UtilityService.orgSyncUserId = UserInfo.getUserId();
        System.assertEquals(true, OrgSync_UtilityService.isOrgSyncUser(), 'Expected OrgSync user to be true');

        // Set to a different Id to test false branch
        OrgSync_UtilityService.orgSyncUserId = '005000000000000AAA'; //Random 18 digit Id not linked to any user
        System.assertEquals(false, OrgSync_UtilityService.isOrgSyncUser(), 'Expected OrgSync user to be false');
    }

    @IsTest
    static void testExtractExternalIdsFromStaging() {
        List<OrgSync_Patient_Staging__c> records = new List<OrgSync_Patient_Staging__c>{
            new OrgSync_Patient_Staging__c(XCDC_ExternalId__c = 'EXT-1'),
            new OrgSync_Patient_Staging__c(XCDC_ExternalId__c = null),
            new OrgSync_Patient_Staging__c(XCDC_ExternalId__c = 'EXT-2')
        };

        Set<String> result = OrgSync_UtilityService.extractExternalIds(records);
        System.assertEquals(2, result.size(), 'Should return only non-blank external ids');
        System.assert(result.contains('EXT-1'), 'Expected EXT-1');
        System.assert(result.contains('EXT-2'), 'Expected EXT-2');
    }

    @IsTest
    static void testExtractExternalIdsFromAccounts() {
        List<Account> accounts = new List<Account>{
            new Account(XCDC_ExternalId__c = 'ACC-1'),
            new Account(XCDC_ExternalId__c = ''),
            new Account(XCDC_ExternalId__c = 'ACC-2')
        };

        Set<String> result = OrgSync_UtilityService.extractExternalIdsFromAccounts(accounts);
        System.assertEquals(2, result.size(), 'Should return only non-blank external ids');
        System.assert(result.contains('ACC-1'), 'Expected ACC-1');
        System.assert(result.contains('ACC-2'), 'Expected ACC-2');
    }

    @IsTest
    static void testMapTargetToSourceField() {
        System.assertEquals('OrgSync_Test_Field__c', OrgSync_UtilityService.mapTargetToSourceField('Test_Field'),'Expected OrgSync_Test_Field__c');
        System.assertEquals('OrgSync_Already__c', OrgSync_UtilityService.mapTargetToSourceField('OrgSync_Already__c'),'Expected OrgSync_Already__c');
        System.assertEquals('XCDC_Custom__c', OrgSync_UtilityService.mapTargetToSourceField('XCDC_Custom'),'Expected XCDC_Custom__c');
        System.assertEquals(
            'OrgSync_Sensor_Continuous_GlucoseMonitor__c',
            OrgSync_UtilityService.mapTargetToSourceField('Sensor_CGM_Continuous_Glucose_Monitor'),'Expected OrgSync_Sensor_Continuous_GlucoseMonitor__c'
        );
    }

    @IsTest
    static void testFieldSetAccessors() {
        List<Schema.FieldSetMember> patientFields = OrgSync_UtilityService.getFieldSetMembers('Account', 'OrgSync_Patient_Mapping');
        List<Schema.FieldSetMember> providerFields = OrgSync_UtilityService.getFieldSetMembers('Account', 'OrgSync_Provider_Mapping');

        System.assertNotEquals(null, patientFields, 'Patient field set list should not be null');
        System.assertNotEquals(null, providerFields, 'Provider field set list should not be null');
    }

    @IsTest
    static void testGetProviderNPIs() {
        Account providerAccount = OrgSync_TestDataFactory.createProviderAccount('Test', 'Provider', 'testprovider@example.com', '12345', null);
        Database.insert(providerAccount, OrgSync_TestDataFactory.getDMLOptions());

        Identifier providerIdentifier = new Identifier(
            ParentRecordId = providerAccount.Id,
            IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE,
            ID_Value__c = '1234567890'
        );
        insert providerIdentifier;

        // Test the getProviderNPIs method
        Set<Id> providerAccountIds = new Set<Id>{ providerAccount.Id };
        Map<Id, String> result = OrgSync_UtilityService.getProviderNPIs(providerAccountIds);

        // Assertions
        System.assertEquals(1, result.size(), 'Should return one NPI mapping');
        System.assert(result.containsKey(providerAccount.Id), 'Map should contain the provider account ID');
        System.assertEquals('1234567890', result.get(providerAccount.Id), 'NPI value should match the Identifier ID_Value__c');
    }

    @IsTest
    static void testHasGuardianDemographicFieldsChanged() {
        OrgSync_Patient_Staging__c newRecord = new OrgSync_Patient_Staging__c(
            OrgSync_Guardian_1_First_Name__c = 'John',
            OrgSync_Guardian_1_Last_Name__c = 'Doe'
        );
        OrgSync_Patient_Staging__c oldRecord = new OrgSync_Patient_Staging__c(
            OrgSync_Guardian_1_First_Name__c = 'Jane',
            OrgSync_Guardian_1_Last_Name__c = 'Doe'
        );
        System.assertEquals(true, OrgSync_UtilityService.hasGuardianDemographicFieldsChanged(newRecord, oldRecord), 'Should detect change');

        oldRecord.OrgSync_Guardian_1_First_Name__c = 'John';
        System.assertEquals(false, OrgSync_UtilityService.hasGuardianDemographicFieldsChanged(newRecord, oldRecord), 'No change when same');

        System.assertEquals(true, OrgSync_UtilityService.hasGuardianDemographicFieldsChanged(newRecord, null), 'Insert always changed');
    }

    @IsTest
    static void testSanitizePhoneNumber() {
        System.assertEquals('5551234567', OrgSync_UtilityService.sanitizePhoneNumber('555-123-4567'), 'Should remove dashes');
        System.assertEquals('5551234567', OrgSync_UtilityService.sanitizePhoneNumber('(555) 123-4567'), 'Should remove parens and spaces');
        System.assertEquals('', OrgSync_UtilityService.sanitizePhoneNumber(''), 'Blank returns blank');
        System.assertEquals(null, OrgSync_UtilityService.sanitizePhoneNumber(null), 'Null returns null');
    }

    @IsTest
    static void testQueryAccountsWithFieldSet() {
        if (ConstantsUtil.ACCOUNT_PROVIDER_RT == null) {
            System.assert(true, 'Provider record type not available - skipping test');
            return;
        }
        Account acc = OrgSync_TestDataFactory.createProviderAccount('Query', 'Test', 'query@test.com', '12345', null);
        Database.insert(acc, OrgSync_TestDataFactory.getDMLOptions());

        Set<Id> accountIds = new Set<Id>{ acc.Id };
        List<Schema.FieldSetMember> fieldSetMembers = OrgSync_UtilityService.getFieldSetMembers('Account', 'OrgSync_Provider_Mapping');
        List<Account> result = OrgSync_UtilityService.queryAccountsWithFieldSet(accountIds, fieldSetMembers);
        System.assert(!result.isEmpty(), 'Should return accounts');
        System.assertEquals(acc.Id, result[0].Id, 'Should return matching account');

        List<Account> result2 = OrgSync_UtilityService.queryAccountsWithFieldSet(accountIds, null);
        System.assert(!result2.isEmpty(), 'Should handle null field set');
    }

    @IsTest
    static void testGetFieldSetMembersInvalidObject() {
        List<Schema.FieldSetMember> result = OrgSync_UtilityService.getFieldSetMembers('InvalidObject__c', 'SomeFieldSet');
        System.assertEquals(0, result.size(), 'Invalid object should return empty list');
    }

    @IsTest
    static void testGetFieldSetMembersInvalidFieldSet() {
        List<Schema.FieldSetMember> result = OrgSync_UtilityService.getFieldSetMembers('Account', 'NonExistentFieldSet_xyz');
        System.assertEquals(0, result.size(), 'Invalid field set should return empty list');
    }

    @IsTest
    static void testGetGuardianDemographicFieldNames() {
        List<String> fields = OrgSync_UtilityService.getGuardianDemographicFieldNames();
        System.assert(!fields.isEmpty(), 'Should return guardian field names');
        System.assert(fields.contains('OrgSync_Guardian_1_First_Name__c'), 'Should contain Guardian 1 First Name');
        // Second call should return cached
        List<String> cached = OrgSync_UtilityService.getGuardianDemographicFieldNames();
        System.assertEquals(fields.size(), cached.size(), 'Cached result should match');
    }

    @IsTest
    static void testHasGuardianNDemographicFieldsChanged() {
        OrgSync_Patient_Staging__c newRecord = new OrgSync_Patient_Staging__c(OrgSync_Guardian_1_First_Name__c = 'John');
        OrgSync_Patient_Staging__c oldRecord = new OrgSync_Patient_Staging__c(OrgSync_Guardian_1_First_Name__c = 'Jane');
        System.assertEquals(true, OrgSync_UtilityService.hasGuardianNDemographicFieldsChanged(newRecord, oldRecord, 1), 'Should detect Guardian 1 change');
        System.assertEquals(false, OrgSync_UtilityService.hasGuardianNDemographicFieldsChanged(newRecord, newRecord, 1), 'No change when same');
        System.assertEquals(true, OrgSync_UtilityService.hasGuardianNDemographicFieldsChanged(newRecord, null, 1), 'Insert always changed');
    }

    @IsTest
    static void testUpdateGuardianFieldsOnStaging() {
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c();
        Contact con = new Contact(FirstName = 'Guard', LastName = 'Test', Email = 'guard@test.com', HomePhone = '5551111111', Phone = '5552222222', MobilePhone = '5553333333');
        OrgSync_UtilityService.updateGuardianFieldsOnStaging(staging, 1, con);
        System.assertEquals('Guard', staging.get('OrgSync_Guardian_1_First_Name__c'), 'First name should be set');
        System.assertEquals('Test', staging.get('OrgSync_Guardian_1_Last_Name__c'), 'Last name should be set');
        System.assertEquals('guard@test.com', staging.get('OrgSync_Guardian_1_Email__c'), 'Email should be set');
        OrgSync_UtilityService.updateGuardianFieldsOnStaging(staging, 2, null);
        System.assertEquals(null, staging.get('OrgSync_Guardian_2_Name__c'), 'Null con should clear');
    }

    @IsTest
    static void testUpdateGuardianEmailOnStaging() {
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c();
        OrgSync_UtilityService.updateGuardianEmailOnStaging(staging, 1, 'guard1@test.com');
        System.assertEquals('guard1@test.com', staging.OrgSync_Guardian_1_Email__c, 'Guardian 1 email should be set');
        OrgSync_UtilityService.updateGuardianEmailOnStaging(staging, 2, 'guard2@test.com');
        System.assertEquals('guard2@test.com', staging.OrgSync_Guardian_2_Email__c, 'Guardian 2 email should be set');
    }

    @IsTest
    static void testUpdateGuardianEmailOnStagingInvalidInputs() {
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c();
        OrgSync_UtilityService.updateGuardianEmailOnStaging(null, 1, 'test@test.com');
        OrgSync_UtilityService.updateGuardianEmailOnStaging(staging, null, 'test@test.com');
        OrgSync_UtilityService.updateGuardianEmailOnStaging(staging, 3, 'test@test.com');
        System.assert(true, 'Invalid inputs should not throw');
    }

    @IsTest
    static void testUpdateGuardianPhoneOnStaging() {
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c();
        OrgSync_UtilityService.updateGuardianPhoneOnStaging(staging, 1, 'Home', '5551111111');
        System.assertEquals('5551111111', staging.OrgSync_Guardian_1_Home_Phone__c, 'Guardian 1 home phone should be set');
        OrgSync_UtilityService.updateGuardianPhoneOnStaging(staging, 1, 'Work', '5552222222');
        System.assertEquals('5552222222', staging.OrgSync_Guardian_1_Work_Phone__c, 'Guardian 1 work phone should be set');
        OrgSync_UtilityService.updateGuardianPhoneOnStaging(staging, 1, 'Mobile', '5553333333');
        System.assertEquals('5553333333', staging.OrgSync_Guardian_1_Mobile_Phone__c, 'Guardian 1 mobile phone should be set');
    }

    @IsTest
    static void testUpdateGuardianPhoneOnStagingInvalidInputs() {
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c();
        OrgSync_UtilityService.updateGuardianPhoneOnStaging(null, 1, 'Home', '5551111111');
        OrgSync_UtilityService.updateGuardianPhoneOnStaging(staging, null, 'Home', '5551111111');
        OrgSync_UtilityService.updateGuardianPhoneOnStaging(staging, 3, 'Home', '5551111111');
        OrgSync_UtilityService.updateGuardianPhoneOnStaging(staging, 1, '', '5551111111');
        System.assert(true, 'Invalid inputs should not throw');
    }

    @IsTest
    static void testGenerateUniqueExtId() {
        String result = OrgSync_UtilityService.generateUniqueExtId('TST');
        System.assert(result.startsWith('TST-'), 'Should start with prefix');
        System.assert(result.length() > 10, 'Should generate unique value');
    }

    @IsTest
    static void testGetProviderNPIsNullAndEmpty() {
        System.assertEquals(0, OrgSync_UtilityService.getProviderNPIs(null).size(), 'Null should return empty map');
        System.assertEquals(0, OrgSync_UtilityService.getProviderNPIs(new Set<Id>()).size(), 'Empty set should return empty map');
    }

}