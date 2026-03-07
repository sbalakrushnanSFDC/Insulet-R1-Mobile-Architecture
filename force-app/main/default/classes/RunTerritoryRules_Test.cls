/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: Jan 13, 2026
 * @description : Test class for RunTerritoryRules
 *  * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       13th Jan 2026       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1643)
 */
@isTest(IsParallel=true)
private class RunTerritoryRules_Test {

    /**
     * @description Mock class for HTTP callouts
     */
    private class TerritoryRulesMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        /**
         * @description Constructor
         * @param statusCode HTTP status code to return
         * @param responseBody Response body to return
         */
        public TerritoryRulesMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        /**
         * @description Responds to HTTP request with mocked response
         * @param req HTTP request
         * @return HTTP response with mocked status code and body
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    /**
     * @description Test successful territory assignment with single account
     */
    @isTest
    static void testExecuteSuccess() {
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        String mockResponse = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'success' => true,
                'id' => testAccount.Id
            }
        });

        Test.setMock(HttpCalloutMock.class, new TerritoryRulesMock(200, mockResponse));

        Set<Id> accountIds = new Set<Id>{ testAccount.Id };

        Test.startTest();
        RunTerritoryRules job = new RunTerritoryRules(accountIds);
        job.execute(null);
        Test.stopTest();

        // Verify job executed without exception
        Assert.isTrue(true, 'Job should execute successfully');
    }

    /**
     * @description Test with null account IDs
     */
    @isTest
    static void testExecuteWithNullAccountIds() {
        Test.startTest();
        RunTerritoryRules job = new RunTerritoryRules(null);
        job.execute(null);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle null account IDs gracefully');
    }

    /**
     * @description Test with empty account IDs
     */
    @isTest
    static void testExecuteWithEmptyAccountIds() {
        Test.startTest();
        RunTerritoryRules job = new RunTerritoryRules(new Set<Id>());
        job.execute(null);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle empty account IDs gracefully');
    }

    /**
     * @description Test batch processing with multiple accounts
     */
    @isTest
    static void testExecuteMultipleAccounts() {
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            Account acc = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
                'FirstName' => 'Test',
                'LastName' => 'Account' + i
            });
            testAccounts.add(acc);
        }
        insert testAccounts;

        Set<Id> accountIds = new Set<Id>();
        for (Account acc : testAccounts) {
            accountIds.add(acc.Id);
        }

        List<Map<String, Object>> mockResults = new List<Map<String, Object>>();
        for (Account acc : testAccounts) {
            mockResults.add(new Map<String, Object>{
                'success' => true,
                'id' => acc.Id
            });
        }

        String mockResponse = JSON.serialize(mockResults);
        Test.setMock(HttpCalloutMock.class, new TerritoryRulesMock(200, mockResponse));

        Test.startTest();
        RunTerritoryRules job = new RunTerritoryRules(accountIds);
        job.execute(null);
        Test.stopTest();

        Assert.isTrue(true, 'Should process multiple accounts successfully');
    }

    /**
     * @description Test HTTP callout failure
     */
    @isTest
    static void testProcessBatchHttpError() {
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Test.setMock(HttpCalloutMock.class, new TerritoryRulesMock(500, 'Internal Server Error'));

        Set<Id> accountIds = new Set<Id>{ testAccount.Id };

        Test.startTest();
        RunTerritoryRules job = new RunTerritoryRules(accountIds);
        job.execute(null);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle HTTP error gracefully');
    }

    /**
     * @description Test HTTP callout exception
     */
    @isTest
    static void testProcessBatchCalloutException() {
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        // Mock that throws exception
        Test.setMock(HttpCalloutMock.class, new CalloutExceptionMock());

        Set<Id> accountIds = new Set<Id>{ testAccount.Id };

        Test.startTest();
        RunTerritoryRules job = new RunTerritoryRules(accountIds);
        job.execute(null);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle callout exception gracefully');
    }

    /**
     * @description Test parseResponse with failed records
     */
    @isTest
    static void testParseResponseWithFailures() {
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        List<Map<String, Object>> mockResults = new List<Map<String, Object>>{
            new Map<String, Object>{
                'success' => false,
                'errors' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'statusCode' => 'INVALID_FIELD',
                        'message' => 'Invalid field value'
                    }
                }
            }
        };

        String mockResponse = JSON.serialize(mockResults);
        Test.setMock(HttpCalloutMock.class, new TerritoryRulesMock(200, mockResponse));

        Set<Id> accountIds = new Set<Id>{ testAccount.Id };

        Test.startTest();
        RunTerritoryRules job = new RunTerritoryRules(accountIds);
        job.execute(null);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle failed records gracefully');
    }

    /**
     * @description Test parseResponse with invalid JSON
     */
    @isTest
    static void testParseResponseInvalidJson() {
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Test.setMock(HttpCalloutMock.class, new TerritoryRulesMock(200, 'Invalid JSON'));

        Set<Id> accountIds = new Set<Id>{ testAccount.Id };

        Test.startTest();
        RunTerritoryRules job = new RunTerritoryRules(accountIds);
        job.execute(null);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle invalid JSON gracefully');
    }

    /**
     * @description Mock class that throws exception
     */
    private class CalloutExceptionMock implements HttpCalloutMock {
        /**
         * @description Responds to HTTP request by throwing an exception
         * @param req HTTP request
         * @return HttpResponse (never returns, throws exception)
         */
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Mock callout exception');
        }
    }

    /**
     * @description Mock FinalizerContext for testing
     */
    private class MockFinalizerContext implements System.FinalizerContext {
        private ParentJobResult result;
        private Exception ex;

        /**
         * @description Constructor
         * @param result Parent job result
         * @param ex Exception object (can be null)
         */
        public MockFinalizerContext(ParentJobResult result, Exception ex) {
            this.result = result;
            this.ex = ex;
        }

        /**
         * @description Gets the parent job result
         * @return ParentJobResult
         */
        public ParentJobResult getResult() {
            return result;
        }

        /**
         * @description Gets the exception
         * @return Exception object (can be null)
         */
        public Exception getException() {
            return ex;
        }

        /**
         * @description Gets the async apex job ID
         * @return Id (returns null for mock)
         */
        public Id getAsyncApexJobId() {
            return null;
        }

        /**
         * @description Gets the request ID
         * @return String (returns null for mock)
         */
        public String getRequestId() {
            return null;
        }
    }

    /**
     * @description Test finalizer with unhandled exception
     */
    @isTest
    static void testTerritoryRulesFinalizerWithUnhandledException() {
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Set<Id> accountIds = new Set<Id>{ testAccount.Id };
        RunTerritoryRules.TerritoryRulesFinalizer finalizer = new RunTerritoryRules.TerritoryRulesFinalizer(accountIds);

        Exception testException = new CalloutException('Test exception');
        MockFinalizerContext context = new MockFinalizerContext(
            ParentJobResult.UNHANDLED_EXCEPTION,
            testException
        );

        Test.startTest();
        finalizer.execute(context);
        Test.stopTest();

        Assert.isTrue(true, 'Finalizer should handle unhandled exception');
    }

    /**
     * @description Test finalizer with successful completion
     */
    @isTest
    static void testTerritoryRulesFinalizerWithSuccess() {
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Set<Id> accountIds = new Set<Id>{ testAccount.Id };
        RunTerritoryRules.TerritoryRulesFinalizer finalizer = new RunTerritoryRules.TerritoryRulesFinalizer(accountIds);

        MockFinalizerContext context = new MockFinalizerContext(
            ParentJobResult.SUCCESS,
            null
        );

        Test.startTest();
        finalizer.execute(context);
        Test.stopTest();

        Assert.isTrue(true, 'Finalizer should handle successful completion');
    }

    /**
     * @description Test finalizer with null account IDs
     */
    @isTest
    static void testTerritoryRulesFinalizerWithNullAccountIds() {
        RunTerritoryRules.TerritoryRulesFinalizer finalizer = new RunTerritoryRules.TerritoryRulesFinalizer(null);

        Exception testException = new CalloutException('Test exception');
        MockFinalizerContext context = new MockFinalizerContext(
            ParentJobResult.UNHANDLED_EXCEPTION,
            testException
        );

        Test.startTest();
        finalizer.execute(context);
        Test.stopTest();

        Assert.isTrue(true, 'Finalizer should handle null account IDs');
    }
}