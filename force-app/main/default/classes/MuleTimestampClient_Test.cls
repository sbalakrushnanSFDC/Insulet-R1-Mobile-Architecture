@isTest
private class MuleTimestampClient_Test {
    /**
     * @description Mock class to simulate a successful HTTP callout returning a fixed timestamp.
     */
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        /**
         * @description Mocks the HTTP response for a successful timestamp callout.
         * @param req The HTTP request sent by the callout.
         * @return A mocked HTTPResponse with a fixed timestamp.
         */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('2025-09-18T19:23:47Z');
            res.setStatusCode(200);
            return res;
        }
    }
    /**
     * @description Test setup method to create necessary test data.
     * @Story Number: NGONDL-190
     */
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
    /**
     * @description Test method to verify the getTimestamp method of MuleTimestampClient.
     * @Story Number: NGONDL-190
     */
    @IsTest
    static void testGetTimestamp() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        User u = [SELECT Id FROM User WHERE LastName = 'WithPerm' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            String timestamp = MuleTimestampClient.getTimestamp();
            Test.stopTest();
            System.assertEquals('2025-09-18T19:23:47Z', timestamp, 'Timestamp should match the mocked response');
        }
    }
    /**
     * @description Test method to verify the getTimestamp method of MuleTimestampClient when callout fails.
     * @Story Number: NGONDL-190
     */
    @IsTest
    static void testGetTimestampcalloutFailsthrowsException(){
        Test.setMock(HttpCalloutMock.class, new MockFailedHttpResponseGenerator());
        User u = [SELECT Id FROM User WHERE LastName = 'WithPerm' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            try {
                MuleTimestampClient.getTimestamp();
                System.assert(false, 'Exception was expected but not thrown');
            } catch (CalloutException ex) {
                System.assert(ex.getMessage().contains('Failed: null - Error occurred'), 'Exception message should indicate failure');
            }
            Test.stopTest();
        }
    }
}