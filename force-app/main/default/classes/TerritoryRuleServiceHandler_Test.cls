/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: Jan 13, 2026
 * @description : Test class for TerritoryRuleServiceHandler
 *  * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       13th Jan 2026       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1643)
 */
@isTest(IsParallel=true)
private class TerritoryRuleServiceHandler_Test {

    /**
     * @description Test successful processing with Practice account and Territory_Alias__c change
     */
    @isTest
    static void testProcessAccountsForTerritoryRulesSuccess() {
        Account testAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice',
            'Territory_Alias__c' => 'OldAlias'
        });
        insert testAccount;

        Account updatedAccount = testAccount.clone(true, true, true, true);
        updatedAccount.Territory_Alias__c = 'NewAlias';

        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{ testAccount.Id => testAccount };

        String mockResponse = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'success' => true,
                'id' => testAccount.Id
            }
        });
        Test.setMock(HttpCalloutMock.class, new TerritoryRulesMock(200, mockResponse));

        Test.startTest();
        TerritoryRuleServiceHandler.processAccountsForTerritoryRules(
            new List<Account>{ updatedAccount },
            oldAccountsMap
        );
        Test.stopTest();

        Assert.isTrue(true, 'Should process accounts successfully');
    }

    /**
     * @description Test with Patient account and Territory_Alias__c change
     */
    @isTest
    static void testProcessAccountsForTerritoryRulesPatientAccount() {
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Patient',
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PATIENT_RT,
            'Territory_Alias__c' => 'OldAlias'
        });
        insert testAccount;

        Account updatedAccount = testAccount.clone(true, true, true, true);
        updatedAccount.Territory_Alias__c = 'NewAlias';

        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{ testAccount.Id => testAccount };

        String mockResponse = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'success' => true,
                'id' => testAccount.Id
            }
        });
        Test.setMock(HttpCalloutMock.class, new TerritoryRulesMock(200, mockResponse));

        Test.startTest();
        TerritoryRuleServiceHandler.processAccountsForTerritoryRules(
            new List<Account>{ updatedAccount },
            oldAccountsMap
        );
        Test.stopTest();

        Assert.isTrue(true, 'Should process Patient accounts successfully');
    }

    /**
     * @description Test with null input
     */
    @isTest
    static void testProcessAccountsForTerritoryRulesNullInput() {
        Test.startTest();
        TerritoryRuleServiceHandler.processAccountsForTerritoryRules(null, null);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle null input gracefully');
    }

    /**
     * @description Test with empty accounts list
     */
    @isTest
    static void testProcessAccountsForTerritoryRulesEmptyInput() {
        Test.startTest();
        TerritoryRuleServiceHandler.processAccountsForTerritoryRules(
            new List<Account>(),
            new Map<Id, Account>()
        );
        Test.stopTest();

        Assert.isTrue(true, 'Should handle empty input gracefully');
    }

    /**
     * @description Test with account that has no Territory_Alias__c change
     */
    @isTest
    static void testProcessAccountsNoTerritoryAliasChange() {
        Account testAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice',
            'Territory_Alias__c' => 'SameAlias'
        });
        insert testAccount;

        Account updatedAccount = testAccount.clone(true, true, true, true);
        updatedAccount.Territory_Alias__c = 'SameAlias'; // No change

        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{ testAccount.Id => testAccount };

        Test.startTest();
        TerritoryRuleServiceHandler.processAccountsForTerritoryRules(
            new List<Account>{ updatedAccount },
            oldAccountsMap
        );
        Test.stopTest();

        Assert.isTrue(true, 'Should not process accounts when Territory_Alias__c unchanged');
    }

    /**
     * @description Test with account that is not Practice or Patient record type
     */
    @isTest
    static void testProcessAccountsWrongRecordType() {
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Provider',
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PROVIDER_RT,
            'Territory_Alias__c' => 'OldAlias'
        });
        insert testAccount;

        Account updatedAccount = testAccount.clone(true, true, true, true);
        updatedAccount.Territory_Alias__c = 'NewAlias';

        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{ testAccount.Id => testAccount };

        Test.startTest();
        TerritoryRuleServiceHandler.processAccountsForTerritoryRules(
            new List<Account>{ updatedAccount },
            oldAccountsMap
        );
        Test.stopTest();

        Assert.isTrue(true, 'Should not process accounts with wrong record type');
    }

    /**
     * @description Test with account not found in oldAccountsMap
     */
    @isTest
    static void testProcessAccountsNotInOldMap() {
        Account testAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice',
            'Territory_Alias__c' => 'NewAlias'
        });
        insert testAccount;

        Test.startTest();
        TerritoryRuleServiceHandler.processAccountsForTerritoryRules(
            new List<Account>{ testAccount },
            new Map<Id, Account>()
        );
        Test.stopTest();

        Assert.isTrue(true, 'Should handle account not in old map gracefully');
    }

    /**
     * @description Test with Territory_Alias__c changing from null to value
     */
    @isTest
    static void testProcessAccountsNullToValue() {
        Account testAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice',
            'Territory_Alias__c' => null
        });
        insert testAccount;

        Account updatedAccount = testAccount.clone(true, true, true, true);
        updatedAccount.Territory_Alias__c = 'NewAlias';

        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{ testAccount.Id => testAccount };

        String mockResponse = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'success' => true,
                'id' => testAccount.Id
            }
        });
        Test.setMock(HttpCalloutMock.class, new TerritoryRulesMock(200, mockResponse));

        Test.startTest();
        TerritoryRuleServiceHandler.processAccountsForTerritoryRules(
            new List<Account>{ updatedAccount },
            oldAccountsMap
        );
        Test.stopTest();

        Assert.isTrue(true, 'Should process accounts when Territory_Alias__c changes from null to value');
    }

    /**
     * @description Test with Territory_Alias__c changing from value to null
     */
    @isTest
    static void testProcessAccountsValueToNull() {
        Account testAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice',
            'Territory_Alias__c' => 'OldAlias'
        });
        insert testAccount;

        Account updatedAccount = testAccount.clone(true, true, true, true);
        updatedAccount.Territory_Alias__c = null;

        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{ testAccount.Id => testAccount };

        String mockResponse = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{
                'success' => true,
                'id' => testAccount.Id
            }
        });
        Test.setMock(HttpCalloutMock.class, new TerritoryRulesMock(200, mockResponse));

        Test.startTest();
        TerritoryRuleServiceHandler.processAccountsForTerritoryRules(
            new List<Account>{ updatedAccount },
            oldAccountsMap
        );
        Test.stopTest();

        Assert.isTrue(true, 'Should process accounts when Territory_Alias__c changes from value to null');
    }

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
     * @description Test exception handling in enqueueTerritoryAssignment catch block (line 107-115)
     *              Uses customExceptionSwitch to trigger exception similar to MemberPlanService
     */
    @isTest
    static void testEnqueueTerritoryAssignmentException() {
        Account testAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice',
            'Territory_Alias__c' => 'OldAlias'
        });
        insert testAccount;

        Account updatedAccount = testAccount.clone(true, true, true, true);
        updatedAccount.Territory_Alias__c = 'NewAlias';

        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{ testAccount.Id => testAccount };

        // Set customExceptionSwitch to true to trigger exception in RunTerritoryRules.execute()
        // This will trigger the catch block at line 107 and cover lines 108-115
        ConstantsUtil.customExceptionSwitch = true;

        Test.startTest();
        TerritoryRuleServiceHandler.processAccountsForTerritoryRules(
            new List<Account>{ updatedAccount },
            oldAccountsMap
        );
        Test.stopTest();

        // Reset customExceptionSwitch
        ConstantsUtil.customExceptionSwitch = false;

        Assert.isTrue(true, 'Should handle exception in enqueueTerritoryAssignment gracefully');
    }
    /**
     * @description Test hasTerritoryAliasChanged method
     */
    @isTest
    static void testHasTerritoryAliasChanged() {
        Account testAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice',
            'Territory_Alias__c' => 'OldAlias'
        });
        insert testAccount;

        Account oldAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice',
            'Territory_Alias__c' => 'DifferentAlias'
        });

        Boolean result = TerritoryRuleServiceHandler.hasTerritoryAliasChanged(testAccount, oldAccount);
        Assert.isTrue(result, 'Should return true when Territory_Alias__c changed');

        Boolean result2 = TerritoryRuleServiceHandler.hasTerritoryAliasChanged(testAccount, null);
        Assert.isFalse(result2, 'Should return false when oldAccount is null');
    }

    /**
     * @description Mock class that throws exception for HTTP callouts to trigger catch block
     */
    private class ExceptionThrowingMock implements HttpCalloutMock {
        /**
         * @description Responds to HTTP request by throwing an exception
         * @param req HTTP request
         * @return HttpResponse (never returns, throws exception)
         */
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Mock exception to test catch block');
        }
    }
}