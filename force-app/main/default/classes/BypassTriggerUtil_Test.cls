@IsTest
private class BypassTriggerUtil_Test {
    @testSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User userWithPerm = new User(
            Alias = 'yperm',
            Email = 'userWithPerm@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'WithPerm',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'userWithPerm' + DateTime.now().getTime() + '@example.com'
        );
        insert userWithPerm;
    }

    @IsTest
    static void testIsTriggerBypassEnabledNormalPath() {
        User u = [SELECT Id FROM User WHERE LastName = 'WithPerm' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            Boolean result = BypassTriggerUtil.isTriggerBypassEnabled();
            Test.stopTest();
            // In test context, FeatureManagement.checkPermission() always returns false
            System.assertEquals(false, result,'Expected false since CP cannot be simulated in tests.');
        }
    }

    // Mock class to simulate an exception
    private class MockPermissionChecker extends BypassTriggerUtil.PermissionChecker {
        public override Boolean hasPermission(String customPermissionName) {
            throw new DmlException('Mock Exception for Test');
        }
    }

    @IsTest
    static void testIsTriggerBypassEnabledExceptionPath() {
        MockPermissionChecker mockChecker = new MockPermissionChecker();
        User u = [SELECT Id FROM User WHERE LastName = 'WithPerm' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            Boolean result = BypassTriggerUtil.isTriggerBypassEnabled(ConstantsUtil.BYPASS_APEX_TRIGGER, mockChecker);
            Test.stopTest();
            System.assertEquals(false, result,'The method should return false when an exception occurs.');
        }
    }
}