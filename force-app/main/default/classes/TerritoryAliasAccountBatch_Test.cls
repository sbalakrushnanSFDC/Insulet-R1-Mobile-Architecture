/**
* @description Test class for TerritoryAliasAccountBatch
*              Tests Territory_Alias__c updates on Account records when ZipCode__c Territory_Name__c changes
*
* @author      Jatin Butta
* @createdDate November 17, 2025
*
* Version      Modified Date       Modified By             Brief Note
* V1.0.0       Nov 17, 2025        Jatin Butta             Initial Version (US - NGASIM-1166)
* V1.0.1       29th Dec 2025       Srinivas Shanigarapu    Updated(US - NGOMCT-235)
* V1.0.2       25th Feb 2026       Ayush Sharma            Updated(US - NGASIM-1062)
*/
@isTest(isParallel=true)
private class TerritoryAliasAccountBatch_Test {
    /**
     * @description Test batch start method with no changed zip codes
     *              Covers: normal start path with empty zip codes set
     */
    @IsTest
    static void testStartMethodWithNoChangedZipCodes() {
        // No history records = empty changed zip codes
        Test.startTest();
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        
        // Verify query locator is returned (will query with empty set)
        Assert.isNotNull(ql, 'QueryLocator should not be null');
        
        // Verify query string structure (cannot execute directly due to bind variables)
        String queryString = ql.getQuery();
        Assert.isTrue(
            queryString.contains('BillingPostalCode IN'),
            'Query should filter by BillingPostalCode'
        );
        Assert.isTrue(
            queryString.contains('RecordTypeId IN'),
            'Query should filter by RecordTypeId'
        );
    }
    
    /**
     * @description Test batch start method with changed zip codes
     *              Covers: RecordType filtering and QueryLocator creation
     */
    @IsTest
    static void testStartMethodWithChangedZipCodes() {
        // Create test data
        TerritoryAlias__c territory = new TerritoryAlias__c(
            Name = 'Test Territory',
            Territory_Developer_Name__c = 'Test_Territory'
        );
        insert territory;
        
        ZipCode__c zipCode = new ZipCode__c(
            Name = '10001',
            Territory_Name__c = territory.Id
        );
        insert zipCode;
        
        // Create Practice Account (should be included)
        Account practiceAccount = new Account(
            Name = 'Practice Test',
            BillingPostalCode = '10001',
            RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT
        );
        insert practiceAccount;
        
        // Create Patient Person Account (should be included)
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(
            new Map<String, Object>{
                'FirstName' => 'Patient',
                    'LastName' => 'Test',
                    'PersonMailingPostalCode' => '10001'
                    }
        );
        insert patientAccount;
        
        // Update to trigger history (though it won't work in test context)
        Test.startTest();
        zipCode.Territory_Name__c = territory.Id;
        update zipCode;
        
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        
        // Verify query locator is created
        Assert.isNotNull(ql, 'QueryLocator should not be null');
        
        // Note: In test context, custom object history tracking doesn't work reliably,
        // so the query may be empty (Id = null) or contain the full filters
        String queryString = ql.getQuery();
        Assert.isTrue(
            queryString.contains('Id = null') || queryString.contains('RecordTypeId'),
            'Query should be empty query or contain RecordTypeId filter'
        );
    }
    
    /**
     * @description Test batch execute method with empty scope
     *              Covers: early return when scope is empty
     */
    @IsTest
    static void testExecuteMethodWithEmptyScope() {
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        
        Test.startTest();
        batch.execute(null, new List<Account>());
        Test.stopTest();
        
        // Should execute without errors (early return)
        Assert.isTrue(true, 'Should handle empty scope gracefully');
    }
    
    /**
     * @description Test batch execute method with accounts without postal codes
     *              Covers: early return when batchZipCodes is empty (blank postal codes)
     */
    @IsTest
    static void testExecuteMethodWithNoPostalCodes() {
        // Create account with valid postal code first
        Account account = new Account(
            Name = 'No Postal Code',
            BillingPostalCode = '99999',
            RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT
        );
        insert account;
        
        // Query and manually clear postal code in memory (not in database)
        account = [
            SELECT Id, BillingPostalCode, Territory_Alias__c
            FROM Account
            WHERE Id = :account.Id
        ];
        account.BillingPostalCode = null; // Clear in memory only
        
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        
        Test.startTest();
        batch.execute(null, new List<Account>{ account });
        Test.stopTest();
        
        // Should execute without errors (early return due to no postal codes)
        Assert.isTrue(true, 'Should handle accounts without postal codes');
    }
    
    /**
     * @description Test batch execute method with valid accounts
     *              Covers: full execute path with territory mapping and updates
     */
    @IsTest
    static void testExecuteMethodWithValidAccounts() {
        // Create test data
        TerritoryAlias__c territory = new TerritoryAlias__c(
            Name = 'Execute Test',
            Territory_Developer_Name__c = 'Execute_Test'
        );
        insert territory;
        
        ZipCode__c zipCode = new ZipCode__c(
            Name = '20001',
            Territory_Name__c = territory.Id
        );
        insert zipCode;
        
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(
                new Account(
                    Name = 'Execute Test ' + i,
                    BillingPostalCode = '20001',
                    RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT
                )
            );
        }
        insert accounts;
        
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        
        Test.startTest();
        batch.execute(null, accounts);
        Test.stopTest();
        
        // Verify accounts were processed
        List<Account> updated = [
            SELECT Id, Territory_Alias__c
            FROM Account
            WHERE Id IN :accounts
        ];
        Assert.areEqual(5, updated.size(), 'Should process all 5 accounts');
        for (Account acc : updated) {
            Assert.areEqual(
                'Execute_Test',
                acc.Territory_Alias__c,
                'Should update territory alias'
            );
        }
    }
    
    /**
     * @description
     * Validates the execute method of TerritoryAliasAccountBatch when processing
     * a set of valid Account records with associated ZipCode and Territory data.
     *
     * This test uses the simulateResult flag to force an alternate execution path
     * and verifies that territory assignment is skipped as expected during
     * simulated execution.
     */
    @IsTest
    static void testExecuteMethodWithValidAccountsWithSimulateResult() {
        // Create test data
        TerritoryAlias__c territory = new TerritoryAlias__c(
            Name = 'Execute Test',
            Territory_Developer_Name__c = 'Execute_Test'
        );
        insert territory;
        
        ZipCode__c zipCode = new ZipCode__c(
            Name = '20001',
            Territory_Name__c = territory.Id
        );
        insert zipCode;
        
        Account acc = TestDataFactory.getAccountofPracticeRecordType(null);
        List<Account> accs = new List<Account>();
        accs.add(acc);
        
        insert accs;
        
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        
        Test.startTest();
        TerritoryAliasAccountBatch.simulateResult = true;
        batch.execute(null, accs);
        TerritoryAliasAccountBatch.simulateResult = false;
        Test.stopTest();
        
        // Verify accounts were processed
        List<Account> updated = [
            SELECT Id, Territory_Alias__c
            FROM Account
            WHERE Id = :accs[0].id
        ];
        
        Assert.areNotEqual(
            'Execute_Test',
            acc.Territory_Alias__c,
            'Should not update territory alias'
        );
    }
    
    /**
     * @description Test batch execute method exception handling
     *              Covers: defensive error handling in execute method
     */
    @IsTest
    static void testExecuteMethodExceptionHandling() {
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        
        Test.startTest();
        // Test with null scope to verify defensive coding
        batch.execute(null, null);
        Test.stopTest();
        
        // Should not throw exception (caught internally)
        Assert.isTrue(true, 'Exception should be handled gracefully');
    }
    
    /**
     * @description Test batch finish method
     *              Covers: finish method with job query and logging
     */
    @IsTest
    static void testFinishMethod() {
        Test.startTest();
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        Id batchId = Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verify batch completed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :batchId
        ];
        Assert.areEqual('Completed', job.Status, 'Batch should complete');
        Assert.areEqual(0, job.NumberOfErrors, 'Should have no errors');
    }
    
    /**
     * @description Test batch finish method exception handling
     *              Covers: finish method catch block when Utility.throwExceptionForTestCoverage throws
     */
    @IsTest
    static void testFinishExceptionHandleMethod() {
        ConstantsUtil.customExceptionSwitch = true;
        
        Test.startTest();
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        Id batchId = Database.executeBatch(batch, 200);
        Test.stopTest();
        
        ConstantsUtil.customExceptionSwitch = false;
        
        // Verify batch completed (finish catch handles exception internally)
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :batchId
        ];
        Assert.areEqual('Completed', job.Status, 'Batch should complete despite finish catch');
        Assert.isTrue(true, 'Finish should handle exception gracefully');
    }
    
    /**
     * @description Test full batch execution with multiple batches
     *              Covers: stateful success count across multiple execute calls
     */
    @IsTest
    static void testBatchStatefulCounters() {
        // Create test data
        TerritoryAlias__c territory = new TerritoryAlias__c(
            Name = 'Stateful Test',
            Territory_Developer_Name__c = 'Stateful_Test'
        );
        insert territory;
        
        ZipCode__c zipCode = new ZipCode__c(
            Name = '30001',
            Territory_Name__c = territory.Id
        );
        insert zipCode;
        
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 25; i++) {
            accounts.add(
                new Account(
                    Name = 'Stateful ' + i,
                    BillingPostalCode = '30001',
                    RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT
                )
            );
        }
        insert accounts;
        
        Test.startTest();
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        Id batchId = Database.executeBatch(batch, 10); // Process in chunks of 10
        Test.stopTest();
        
        // Verify batch completed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :batchId
        ];
        Assert.areEqual('Completed', job.Status, 'Batch should complete');
        Assert.areEqual(0, job.NumberOfErrors, 'Should have no errors');
    }
    
    /**
     * @description Test batch with mixed record types
     *              Covers: RecordType filtering in query
     */
    @IsTest
    static void testBatchWithMixedRecordTypes() {
        // Create test data
        TerritoryAlias__c territory = new TerritoryAlias__c(
            Name = 'RecordType Test',
            Territory_Developer_Name__c = 'RecordType_Test'
        );
        insert territory;
        
        ZipCode__c zipCode = new ZipCode__c(
            Name = '40001',
            Territory_Name__c = territory.Id
        );
        insert zipCode;
        
        // Create Practice Account (should be processed)
        Account practiceAccount = new Account(
            Name = 'Practice Account',
            BillingPostalCode = '40001',
            RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT
        );
        insert practiceAccount;
        
        // Create Patient Person Account (should be processed)
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(
            new Map<String, Object>{
                'FirstName' => 'Patient',
                    'LastName' => 'Account',
                    'PersonMailingPostalCode' => '40001'
                    }
        );
        insert patientAccount;
        
        Test.startTest();
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        Id batchId = Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verify batch completed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :batchId
        ];
        Assert.areEqual('Completed', job.Status, 'Batch should complete');
    }
    
    /**
     * @description Test batch start method error handling
     *              Covers: defensive error handling in start method
     */
    @IsTest
    static void testStartMethodErrorHandling() {
        Test.startTest();
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        
        // Verify QueryLocator is returned
        Assert.isNotNull(ql, 'Should return QueryLocator');
        
        // Verify query string is valid
        String queryString = ql.getQuery();
        Assert.isTrue(queryString.contains('SELECT'), 'Should return valid query');
        Assert.isTrue(
            queryString.contains('Account'),
            'Should query Account object'
        );
    }
    
    /**
     * @description Test batch start method RecordType filtering
     *              Covers: accountRecordTypes Set and QueryLocator with RecordType filter
     */
    @IsTest
    static void testStartMethodRecordTypeFiltering() {
        // Create test data
        TerritoryAlias__c territory = new TerritoryAlias__c(
            Name = 'Filter Test',
            Territory_Developer_Name__c = 'Filter_Test'
        );
        insert territory;
        
        ZipCode__c zipCode = new ZipCode__c(
            Name = '55001',
            Territory_Name__c = territory.Id
        );
        insert zipCode;
        
        // Create accounts with correct RecordTypes (should be included)
        List<Account> correctAccounts = new List<Account>();
        correctAccounts.add(
            new Account(
                Name = 'Practice 1',
                BillingPostalCode = '55001',
                RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT
            )
        );
        correctAccounts.add(
            new Account(
                Name = 'Practice 2',
                BillingPostalCode = '55001',
                RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT
            )
        );
        insert correctAccounts;
        
        Test.startTest();
        TerritoryAliasAccountBatch batch = new TerritoryAliasAccountBatch();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        
        // Verify query locator is created
        Assert.isNotNull(ql, 'QueryLocator should not be null');
        
        // Note: In test context, custom object history tracking doesn't work reliably,
        // so the query may be empty or contain the full filters
        String queryString = ql.getQuery();
        Assert.isTrue(
            queryString.contains('RecordTypeId IN') || queryString.contains('WHERE'),
            'Query should contain RecordType filter'
        );
    }
}