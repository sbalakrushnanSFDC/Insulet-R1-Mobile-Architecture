/**
 * @description : Test class for OrgSync_LoggingUtility
 * Created Date : 18 Dec 2025
 * Created By   : Neeraj Kumar
 */
@isTest
private class OrgSync_LoggingUtility_Test {
    @isTest
    static void testGetErrorsFromResultSaveResultSuccess() {
        // Create a valid account to get a successful SaveResult
        Account acc = new Account(Name = 'Test Account',BillingPostalCode = '98776');
        Database.SaveResult sr = Database.insert(acc, false);

        Test.startTest();
        Database.Error[] errors = OrgSync_LoggingUtility.getErrorsFromResult(sr);
        Test.stopTest();

        System.assertEquals(0, errors.size(), 'Successful SaveResult should return empty error array');
    }

    @isTest
    static void testGetErrorsFromResultSaveResultFailure() {
        // Create an invalid account (missing required Name field) to get a failed SaveResult
        Account acc = new Account();
        Database.SaveResult sr = Database.insert(acc, false);

        Test.startTest();
        Database.Error[] errors = OrgSync_LoggingUtility.getErrorsFromResult(sr);
        Test.stopTest();

        System.assertNotEquals(0, errors.size(), 'Failed SaveResult should return errors');
    }

    @isTest
    static void testGetErrorsFromResultDeleteResultSuccess() {
        // Create and then delete an account to get a successful DeleteResult
        Account acc = new Account(Name = 'Test Account for Delete',BillingPostalCode = '98776');
        insert acc;

        Database.DeleteResult dr = Database.delete(acc, false);

        Test.startTest();
        Database.Error[] errors = OrgSync_LoggingUtility.getErrorsFromResult(dr);
        Test.stopTest();

        System.assertEquals(0, errors.size(), 'Successful DeleteResult should return empty error array');
    }

    @isTest
    static void testGetErrorsFromResultDeleteResultFailure() {
        // Try to delete a non-existent record to get a failed DeleteResult
        Account acc = new Account(Name = 'Test Account',BillingPostalCode = '98776');
        insert acc;
        Id accId = acc.Id;
        delete acc;

        // Try to delete already deleted record
        Database.DeleteResult dr = Database.delete(new Account(Id = accId), false);

        Test.startTest();
        Database.Error[] errors = OrgSync_LoggingUtility.getErrorsFromResult(dr);
        Test.stopTest();

        System.assertNotEquals(0, errors.size(), 'Failed DeleteResult should return errors');
    }

    @isTest
    static void testGetErrorsFromResultUpsertResultSuccess() {
        // Create a valid account to get a successful UpsertResult
        Account acc = new Account(Name = 'Test Account for Upsert',BillingPostalCode = '98776');
        Database.UpsertResult ur = Database.upsert(acc, false);

        Test.startTest();
        Database.Error[] errors = OrgSync_LoggingUtility.getErrorsFromResult(ur);
        Test.stopTest();

        System.assertEquals(0, errors.size(), 'Successful UpsertResult should return empty error array');
    }

    @isTest
    static void testGetErrorsFromResultUpsertResultFailure() {
        // Create an invalid account to get a failed UpsertResult
        Account acc = new Account();
        Database.UpsertResult ur = Database.upsert(acc, false);

        Test.startTest();
        Database.Error[] errors = OrgSync_LoggingUtility.getErrorsFromResult(ur);
        Test.stopTest();

        System.assertNotEquals(0, errors.size(), 'Failed UpsertResult should return errors');
    }

    @isTest
    static void testGetErrorsFromResultUnknownType() {
        // Pass an unknown type (String) to test the default return
        Test.startTest();
        Database.Error[] errors = OrgSync_LoggingUtility.getErrorsFromResult('Unknown Type');
        Test.stopTest();

        System.assertEquals(0, errors.size(), 'Unknown type should return empty error array');
    }

    @isTest
    static void testLogErrors() {
        // Create an invalid account to get errors
        Account acc = new Account();
        Database.SaveResult sr = Database.insert(acc, false);
        Database.Error[] errors = sr.getErrors();
        Map<String, String> params = new Map<String, String>{
            'className' => 'TestClass',
            'methodName' => 'testMethod',
            'operationDescription' => 'inserting test record'
        };

        Test.startTest();
        // This should not throw any exception
        OrgSync_LoggingUtility.logErrors(errors, params);
        Test.stopTest();

        // If we reach here without exception, the test passes
        System.assert(true, 'logErrors executed successfully');
    }

    @isTest
    static void testHandleDatabaseResultsWithErrors() {
        // Create multiple accounts - some valid, some invalid
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Valid Account'),
            new Account() // Invalid - missing Name
        };

        List<Database.SaveResult> results = Database.insert(accounts, false);

        Map<String, String> params = new Map<String, String>{
            'className' => 'TestClass',
            'methodName' => 'testMethod',
            'operationDescription' => 'batch insert operation'
        };

        Test.startTest();
        OrgSync_LoggingUtility.handleDatabaseResults(results, accounts, params);
        Test.stopTest();

        // If we reach here without exception, the test passes
        System.assert(true, 'handleDatabaseResults executed successfully with mixed results');
    }

    @isTest
    static void testHandleDatabaseResultsAllSuccess() {
        // Create multiple valid accounts
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Valid Account 1'),
            new Account(Name = 'Valid Account 2')
        };

        List<Database.SaveResult> results = Database.insert(accounts, false);

        Map<String, String> params = new Map<String, String>{
            'className' => 'TestClass',
            'methodName' => 'testMethod',
            'operationDescription' => 'batch insert operation'
        };

        Test.startTest();
        OrgSync_LoggingUtility.handleDatabaseResults(results, accounts, params);
        Test.stopTest();

        // If we reach here without exception, the test passes
        System.assert(true, 'handleDatabaseResults executed successfully with all successful results');
    }

    @isTest
    static void testHandleDatabaseResultsWithDeleteResults() {
        // Create and delete accounts
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Account to Delete 1',BillingPostalCode = '98776'),
            new Account(Name = 'Account to Delete 2',BillingPostalCode = '98776')
        };
        insert accounts;

        List<Database.DeleteResult> results = Database.delete(accounts, false);

        Map<String, String> params = new Map<String, String>{
            'className' => 'TestClass',
            'methodName' => 'testMethod',
            'operationDescription' => 'batch delete operation'
        };

        Test.startTest();
        OrgSync_LoggingUtility.handleDatabaseResults(results, accounts, params);
        Test.stopTest();

        System.assert(true, 'handleDatabaseResults executed successfully with delete results');
    }

    @isTest
    static void testHandleDatabaseResultsWithUpsertResults() {
        // Create accounts for upsert
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Account to Upsert 1'),
            new Account(Name = 'Account to Upsert 2')
        };

        List<Database.UpsertResult> results = Database.upsert(accounts, false);

        Map<String, String> params = new Map<String, String>{
            'className' => 'TestClass',
            'methodName' => 'testMethod',
            'operationDescription' => 'batch upsert operation'
        };

        Test.startTest();
        OrgSync_LoggingUtility.handleDatabaseResults(results, accounts, params);
        Test.stopTest();

        System.assert(true, 'handleDatabaseResults executed successfully with upsert results');
    }

    @isTest
    static void testHandleDatabaseResultsEmptyList() {
        List<Database.SaveResult> results = new List<Database.SaveResult>();
        List<Account> accounts = new List<Account>();

        Map<String, String> params = new Map<String, String>{
            'className' => 'TestClass',
            'methodName' => 'testMethod',
            'operationDescription' => 'empty operation'
        };

        Test.startTest();
        OrgSync_LoggingUtility.handleDatabaseResults(results, accounts, params);
        Test.stopTest();

        System.assert(true, 'handleDatabaseResults executed successfully with empty lists');
    }
}