@isTest
private class HttpIntegrationService_Test {
    /**
     * @description Mock class to simulate a successful HTTP callout
     * @param req The HTTP request object
     * @return HttpResponse The HTTP response object
     */
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        /**
         * @description Mock implementation of the respond method for HTTP callout.
         * @param req The HTTP request object.
         * @return HttpResponse The mocked HTTP response object.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('2025-09-18T19:23:47Z');
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
     * @description Test method to verify the send method of HttpIntegrationService.
     * @Story Number: NGONDL-190
     */
    @IsTest
    static void testSend() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        // Use the defined constructor
        CalloutConfig cfg = new CalloutConfig(
            'MockNamedCredential',
            '/resource',
            'GET'
        );
        User u = [SELECT Id FROM User WHERE LastName = 'WithPerm' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            HttpResponse response = HttpIntegrationService.send(cfg);
            Test.stopTest();
            System.assertEquals(200, response.getStatusCode(),'Assert failed');
            System.assertEquals('2025-09-18T19:23:47Z', response.getBody(),'Assert failed');
        }
    }
    /**
     * @description Test method to verify the send method of HttpIntegrationService with headers and body.
     * @Story Number: NGONDL-190
     */
    @IsTest
    static void testSendWithHeadersAndBody() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        // Use the defined constructor
        CalloutConfig cfg = new CalloutConfig(
            'MockNamedCredential',
            '/resource',
            'POST'
        );
        // Add header and body
        if (cfg.headers == null) {
            cfg.headers = new Map<String, String>();
        }
        cfg.headers.put('Content-Type', 'application/json');
        cfg.body = '{"key":"value"}';
        User u = [SELECT Id FROM User WHERE LastName = 'WithPerm' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            HttpResponse response = HttpIntegrationService.send(cfg);
            Test.stopTest();
            System.assertEquals(200, response.getStatusCode(),'Assert failed');
            System.assertEquals('2025-09-18T19:23:47Z', response.getBody(),'Assert failed');
        }
    }
    /**
     * @description Mock class to simulate an exception during HTTP callout
     */
    @IsTest
    static void testSendThrowsException() {
        Test.setMock(HttpCalloutMock.class, new MockExpThrowingHttpResponseGenerator());
        CalloutConfig cfg = new CalloutConfig(
            'MockNamedCredential',
            '/testError',
            'GET'
        );
        User u = [SELECT Id FROM User WHERE LastName = 'WithPerm' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            try {
                HttpIntegrationService.send(cfg);
                System.assert(false, 'Expected exception was not thrown');
            } catch (Exception e) {
                System.assert(e instanceof CalloutException, 'Exception should be CalloutException');
                System.assertEquals('Simulated network failure', e.getMessage(),'Assert failed');
            }
            Test.stopTest();
        }
    }
}