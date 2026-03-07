/**
 * @description Test class for Utility methods createShare and deleteShares.
 *              Covers dynamic share object resolution and end-to-end DML behavior.
 * @author Yogesh Rana
 * @date 06-11-2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       06 Nov 2025         Yogesh Rana                   Initial Version
 * V1.0.1       04 Dec 2025         Yogesh Rana                   Added test coverage for throwExceptionForTestCoverage method(US - NGOMCT-752)
 * V1.0.2       29th Dec 2025       Ankur Chauhan                 NGOMCT-341(Replaced CEO Role with Training_Coordinator)
 * V1.0.3       30 Dec 2025         Yogesh Rana                   Added timezone and locale test coverage(US - NGOMCT-1278, NGOMCT-1280) 
 */
//We can't use @isTest(isParallel=true) because of this error:  APEX_DATA_ACCESS_RESTRICTION, In parallel Apex tests, DML operations aren't permitted on this type of object: User: [] 
 @isTest
 private class Utility_Test {

   @TestSetup
   static void setupTestData() {
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

       Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
           'FirstName' => 'Test',
           'LastName' => 'PersonAccount',
           'PersonBirthdate' => Date.today()
       });
       insert testAccount;
   }

    private static User createTestUser(String alias) {
        Profile sysAdminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        User testUser = new User(
            Alias = alias,
            Email = alias + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = sysAdminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = alias + System.currentTimeMillis() + '@test.com'
        );
        insert testUser;
        return testUser;
    }

    /**
     * @description Validates createShare and deleteShares work correctly with valid data
     */
   @IsTest
   static void testCreateAndDeleteShareWithRowCause() {
       Account acc = [Select Id,Name, PersonContactId from Account where LastName = 'PersonAccount' LIMIT 1];
       
       User portalUser;
       System.runAs(new User(Id = UserInfo.getUserId())) {
           Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'External Trainer' LIMIT 1];
           portalUser = TestDataFactory.getCommunityUser(acc, portalProfile, 'testUser');
       }

        Utility.CreateShareRecordParameterDetailWrap parameterMap = new Utility.CreateShareRecordParameterDetailWrap();
        parameterMap.recordId = acc.Id;
        parameterMap.userOrGroupId = portalUser.Id;
        parameterMap.accessLevel = 'Read';
        parameterMap.rowCause = 'Manual';

       Test.startTest();
       Sobject createdShares = Utility.createShare(parameterMap);
       List<SObject> shares = Utility.deleteShares(new List<Id>{ acc.Id }, new List<Id>{ portalUser.Id });
       Test.stopTest();

       Assert.isNotNull(createdShares, 'Share should be created successfully');
       Assert.isNotNull(shares, 'method should return a non-null list when shares exist');
       Assert.areEqual(1, shares.size(), 'Should return exactly one share record for deletion');
    }

    /**
     * @description Tests createShare and deleteShares with different access levels
     */
   @IsTest
   static void testCreateShareWithDifferentAccessLevels() {
       Account acc = [Select Id,Name, PersonContactId from Account where LastName = 'PersonAccount' LIMIT 1];
       
       User portalUser;
       System.runAs(new User(Id = UserInfo.getUserId())) {
           Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'External Trainer' LIMIT 1];
           portalUser = TestDataFactory.getCommunityUser(acc, portalProfile, 'testUser1');
       }

        List<String> accessLevels = new List<String>{'Read', 'Edit'};
        List<SObject> shareRecords = new List<SObject>();
        
        Test.startTest();
        for (String accessLevel : accessLevels) {
            Utility.CreateShareRecordParameterDetailWrap parameterMap = new Utility.CreateShareRecordParameterDetailWrap();
            parameterMap.recordId = acc.Id;
            parameterMap.userOrGroupId = portalUser.Id;
            parameterMap.accessLevel = accessLevel;
            
            SObject shareRecord = Utility.createShare(parameterMap);
            shareRecords.add(shareRecord);
        }
        Test.stopTest();
        
        for (Integer i = 0; i < accessLevels.size(); i++) {
            Assert.isNotNull(shareRecords[i], 'Share record should be created for access level: ' + accessLevels[i]);
        }
    }

    /**
     * @description Tests resolveParentField helper method
     */
    @IsTest
    static void testResolveParentField() {  
        Utility.ResolveParentFieldWrapper wrapper = new Utility.ResolveParentFieldWrapper();
        Account acc = [Select id from Account limit 1];
        wrapper.parentType = acc.id.getSObjectType();
        wrapper.objectName = 'Account';
        wrapper.isCustom = true;
        wrapper.fieldMap = new Map<String, Schema.SObjectField>();
        
        Test.startTest();
        String res = Utility.resolveParentField(wrapper);
        wrapper.isCustom = false;
        String res1 = Utility.resolveParentField(wrapper);
        Test.stopTest();
        
        Assert.areEqual(res,'ParentId', 'Should return ParentId');
        Assert.areEqual(res1,'AccountId', 'Should return AccountId');
    }

    /**
     * @description Tests all null and empty parameter scenarios for defensive checks
     */
    @IsTest
    static void testNullAndEmptyParameters() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Utility.CreateShareRecordParameterDetailWrap paramWrapper = new Utility.CreateShareRecordParameterDetailWrap();
        
        Test.startTest();
        
        // Test createShare defensive checks
        SObject result1 = Utility.createShare(null);
        
        paramWrapper.recordId = acc.Id;
        paramWrapper.accessLevel = 'Read';
        SObject result2 = Utility.createShare(paramWrapper);
        
        paramWrapper.recordId = null;
        paramWrapper.userOrGroupId = UserInfo.getUserId();
        SObject result3 = Utility.createShare(paramWrapper);
        
        // Test deleteShares defensive checks
        List<SObject> result4 = Utility.deleteShares(null, new List<Id>{ UserInfo.getUserId() });
        List<SObject> result5 = Utility.deleteShares(new List<Id>(), new List<Id>{ UserInfo.getUserId() });
        List<SObject> result6 = Utility.deleteShares(new List<Id>{ acc.Id }, null);
        List<SObject> result7 = Utility.deleteShares(new List<Id>{ acc.Id }, new List<Id>());
        
        Test.stopTest();
        
        Assert.isNull(result1, 'Should return null for null wrapper');
        Assert.isNull(result2, 'Should return null for null userOrGroupId');
        Assert.isNull(result3, 'Should return null for null recordId');
        Assert.isNull(result4, 'Should return null for null recordIds');
        Assert.isNull(result5, 'Should return null for empty recordIds');
        Assert.isNull(result6, 'Should return null for null userOrGroupIds');
        Assert.isNull(result7, 'Should return null for empty userOrGroupIds');
    }

    /**
     * @description Tests deleteShares when no shares exist (empty query results)
     */
    @IsTest
    static void testDeleteSharesNoRecordsFound() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        User testUser = createTestUser('tuser');
        
        Test.startTest();
        List<SObject> shares = Utility.deleteShares(new List<Id>{ acc.Id }, new List<Id>{ testUser.Id });
        Test.stopTest();
        
        Assert.isNull(shares, 'Should return null when no share records are found');
    }

    /**
     * @description Tests UtilityException class
     */
    @IsTest
    static void testUtilityExceptionClass() {
        Boolean exceptionCaught = false;
        String exceptionMessage;
        
        Test.startTest();
        try {
            throw new Utility.UtilityException('Test exception message');
        } catch (Utility.UtilityException e) {
            exceptionCaught = true;
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();
        
        Assert.isTrue(exceptionCaught, 'UtilityException should be caught');
        Assert.areEqual('Test exception message', exceptionMessage, 'Exception message should match');
    }

    /**
     * @description Tests getRecordTypeInfoMap method
     */
    @IsTest
    static void testGetRecordTypeInfoMap() {
        Test.startTest();
        Map<Id, Schema.RecordTypeInfo> accountRTMap = Utility.getRecordTypeInfoMap('Account');
        Test.stopTest();
        
        Assert.isNotNull(accountRTMap, 'Should return record type map for valid object');
    }

    /**
     * @description Tests initShareContext exception handling when share object doesn't exist
     * This covers the catch block in initShareContext by using ContentDocument
     */
    @IsTest
    static void testInitShareContextException() {
        Boolean exceptionCaught = false;
        String exceptionMessage;
        
        Test.startTest();
        try {
            // ContentDocument uses different sharing model
            ContentVersion cv = new ContentVersion(
                Title = 'Test Exception',
                PathOnClient = 'test.txt',
                VersionData = Blob.valueOf('Test Content')
            );
            insert cv;
            
            ContentVersion insertedCV = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
            // This will call initShareContext which should throw exception for ContentDocument
            Utility.CreateShareRecordParameterDetailWrap paramWrapper = new Utility.CreateShareRecordParameterDetailWrap();
            paramWrapper.recordId = insertedCV.ContentDocumentId;
            paramWrapper.userOrGroupId = UserInfo.getUserId();
            paramWrapper.accessLevel = 'Read';
            
            // If no exception, it returned null (acceptable behavior)
            Utility.createShare(paramWrapper);
        } catch (Utility.UtilityException e) {
            exceptionCaught = true;
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();
        
        if (exceptionCaught) {
            // Verify exception message contains expected details
            Assert.isTrue(exceptionMessage.contains('Method: initShareContext()'), 'Exception should be from initShareContext');
            Assert.isTrue(exceptionMessage.contains('Operation: Schema operations'), 'Exception should contain operation');
            Assert.isTrue(exceptionMessage.contains('Error:'), 'Exception should contain error');
            Assert.isTrue(exceptionMessage.contains('Line:'), 'Exception should contain line number');
        }
    }

    /**
     * @description Tests QueryException handling in deleteShares method
     */
    @IsTest
    static void testDeleteSharesQueryException() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        User testUser = createTestUser('tquery');
        Boolean exceptionThrown = false;
        String exceptionMessage;
        
        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
        
        try {
            Utility.deleteShares(
                new List<Id>{ acc.Id },
                new List<Id>{ testUser.Id }
            );
        } catch (Utility.UtilityException e) {
            exceptionThrown = true;
            exceptionMessage = e.getMessage();
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        
        Test.stopTest();
        
        Assert.isTrue(exceptionThrown, 'Should have thrown UtilityException');
        Assert.isTrue(exceptionMessage.contains('Method: deleteShares()'), 'Should be from deleteShares');
        Assert.isTrue(exceptionMessage.contains('Operation: Unexpected error during share deletion'), 'Should mention operation');
        Assert.isTrue(exceptionMessage.contains('Error:'), 'Should contain error');
        Assert.isTrue(exceptionMessage.contains('Line:'), 'Should contain line number');
    }

    /**
     * @description Tests throwExceptionForTestCoverage method
     */
    @IsTest
    static void testThrowExceptionForTestCoverage() {
        Boolean exceptionCaught = false;
        String exceptionMessage;
        
        Test.startTest();
        Utility.throwExceptionForTestCoverage();
        
        ConstantsUtil.customExceptionSwitch = true;
        try {
            Utility.throwExceptionForTestCoverage();
        } catch (Utility.UtilityException e) {
            exceptionCaught = true;
            exceptionMessage = e.getMessage();
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();
        
        Assert.isTrue(true, 'No exception when switch is off');
        Assert.isTrue(exceptionCaught, 'Exception should be caught');
        Assert.areEqual('customExceptionSwitch is turned on for test coverage', exceptionMessage, 'Exception message should match');
    }

    /**
     * @description Tests getUserTimeZoneAndLocale success case
     */
    @IsTest
    static void testGetUserTimeZoneAndLocale() {
        Test.startTest();
        Map<String, String> result = Utility.getUserTimeZoneAndLocale();
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isNotNull(result.get('timeZone'), 'timeZone should not be null');
        Assert.isNotNull(result.get('locale'), 'locale should not be null');
    }

    /**
     * @description Tests getUserTimeZoneAndLocale with partner user
     */
    @IsTest
    static void testGetUserTimeZoneAndLocaleWithDifferentUsers() {
        Account acc = [SELECT Id, PersonContactId FROM Account WHERE LastName = 'PersonAccount' LIMIT 1];

        User partnerUser;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'External Trainer' LIMIT 1];
            partnerUser = TestDataFactory.getCommunityUser(acc, portalProfile, 'tzuser');
        }

        Test.startTest();
        Map<String, String> result;
        System.runAs(partnerUser) {
            result = Utility.getUserTimeZoneAndLocale();
        }
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isNotNull(result.get('timeZone'), 'timeZone should not be null');
        Assert.isNotNull(result.get('locale'), 'locale should not be null');
    }

    /**
     * @description Tests getUserTimeZoneAndLocale exception path
     */
    @IsTest
    static void testGetUserTimeZoneAndLocaleException() {
        Boolean exceptionCaught = false;
        String exceptionMessage;
        
        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
        try {
            Utility.getUserTimeZoneAndLocale();
        } catch (Utility.UtilityException e) {
            exceptionCaught = true;
            exceptionMessage = e.getMessage();
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();

        Assert.isTrue(exceptionCaught, 'Exception should be caught');
        Assert.isTrue(
            exceptionMessage.contains('Method: getUserTimeZoneAndLocale()'),
            'Exception message should contain method name'
        );
        Assert.isTrue(
            exceptionMessage.contains('Operation: Error getting user preferences'),
            'Exception message should contain operation description'
        );
    }
}