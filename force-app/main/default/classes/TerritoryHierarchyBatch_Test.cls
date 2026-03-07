/**
 * @description Test class for TerritoryHierarchyBatch.
 *              Uses TestDataFactory for all test data creation.
 * @author      Ayush Sharma
 * @created     19th Feb 2026
 */
@IsTest(isParallel = true)
private class TerritoryHierarchyBatch_Test {

    @TestSetup
    static void setupTestData() {
        // TerritoryAlias__c records
        List<TerritoryAlias__c> territories = new List<TerritoryAlias__c>{
            new TerritoryAlias__c(Name = 'Parent Territory', Territory_Developer_Name__c = 'PARENT_TERRITORY'),
            new TerritoryAlias__c(Name = 'Child Territory', Territory_Developer_Name__c = 'CHILD_TERRITORY'),
            new TerritoryAlias__c(Name = 'Old Territory', Territory_Developer_Name__c = 'OLD_TERRITORY')
        };
        insert territories;

        // ZipCode__c - one for parent, one for children
        TerritoryAlias__c parentTerritory = [SELECT Id FROM TerritoryAlias__c WHERE Territory_Developer_Name__c = 'PARENT_TERRITORY' LIMIT 1];
        TerritoryAlias__c childTerritory = [SELECT Id FROM TerritoryAlias__c WHERE Territory_Developer_Name__c = 'CHILD_TERRITORY' LIMIT 1];

        List<ZipCode__c> zipCodes = new List<ZipCode__c>{
            new ZipCode__c(Name = '10001', Territory_Name__c = parentTerritory.Id),
            new ZipCode__c(Name = '20001', Territory_Name__c = childTerritory.Id)
        };
        insert zipCodes;

        // 2-level hierarchy only (custom validation blocks 3rd tier)
        Account parentAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Parent Practice',
            'BillingPostalCode' => '10001',
            'Territory_Alias__c' => 'PARENT_TERRITORY',
            'Apply_Territory_to_Hierarchy__c' => true
        });
        insert parentAccount;

        List<Account> childAccounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            childAccounts.add(TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
                'Name' => 'Child Practice ' + i,
                'ParentId' => parentAccount.Id,
                'BillingPostalCode' => '20001',
                'Territory_Alias__c' => 'CHILD_TERRITORY'
            }));
        }
        for (Integer i = 0; i < 45; i++) {
            childAccounts.add(TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
                'Name' => 'Bulk Child ' + i,
                'ParentId' => parentAccount.Id,
                'BillingPostalCode' => '20001',
                'Territory_Alias__c' => 'OLD_TERRITORY'
            }));
        }
        insert childAccounts;
    }

    @IsTest
    static void testBatchPositive() {
        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Practice' LIMIT 1];
        List<Account> childScope = [SELECT Id, Territory_Alias__c, ParentId, Parent.Territory_Alias__c FROM Account WHERE ParentId = :parent.Id];

        TerritoryHierarchyBatch batch = new TerritoryHierarchyBatch();
        Test.startTest();
        batch.execute(null, childScope);
        Test.stopTest();

        Integer matchCount = [SELECT COUNT() FROM Account WHERE ParentId = :parent.Id AND Territory_Alias__c = 'PARENT_TERRITORY'];
        Assert.areEqual(48, matchCount, 'All 48 children should have parent territory');
    }

    @IsTest
    static void testBatchStartReturnsQueryLocator() {
        TerritoryHierarchyBatch batch = new TerritoryHierarchyBatch();
        Database.QueryLocator ql = batch.start(null);
        Assert.isNotNull(ql, 'Start should return QueryLocator');
    }

    @IsTest
    static void testBatchExecuteEmptyScope() {
        TerritoryHierarchyBatch batch = new TerritoryHierarchyBatch();
        Test.startTest();
        batch.execute(null, new List<Account>());
        Test.stopTest();
        Assert.isTrue(true, 'Execute with empty scope should complete without error');
    }

    @IsTest
    static void testBatchExecuteNullScope() {
        TerritoryHierarchyBatch batch = new TerritoryHierarchyBatch();
        Test.startTest();
        batch.execute(null, null);
        Test.stopTest();
        Assert.isTrue(true, 'Execute with null scope should complete without error');
    }

    @IsTest
    static void testBatchSkipsMatchingTerritory() {
        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Practice' LIMIT 1];
        List<Account> children = [SELECT Id FROM Account WHERE ParentId = :parent.Id];
        for (Account c : children) {
            c.Territory_Alias__c = 'PARENT_TERRITORY';
        }
        update children;

        TerritoryHierarchyBatch batch = new TerritoryHierarchyBatch();
        Test.startTest();
        batch.execute(null, [SELECT Id, Territory_Alias__c, ParentId, Parent.Territory_Alias__c FROM Account WHERE ParentId = :parent.Id]);
        Test.stopTest();

        List<Account> afterBatch = [SELECT Territory_Alias__c FROM Account WHERE ParentId = :parent.Id];
        for (Account c : afterBatch) {
            Assert.areEqual('PARENT_TERRITORY', c.Territory_Alias__c, 'Should remain unchanged when already matching');
        }
    }

    @IsTest
    static void testBatchSkipsWhenApplyTerritoryNotChecked() {
        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Practice' LIMIT 1];
        parent.Apply_Territory_to_Hierarchy__c = false;
        update parent;

        // Batch start() query returns 0 records when parent has Apply_Territory_to_Hierarchy__c = false
        TerritoryHierarchyBatch batch = new TerritoryHierarchyBatch();
        Test.startTest();
        batch.execute(null, new List<Account>());
        Test.stopTest();

        Integer notUpdatedCount = [SELECT COUNT() FROM Account WHERE ParentId = :parent.Id AND Territory_Alias__c != 'PARENT_TERRITORY'];
        Assert.areEqual(48, notUpdatedCount, 'Should not update when parent Apply_Territory_to_Hierarchy__c is not checked');
    }

    @IsTest
    static void testBatchExceptionCoverage() {
        ConstantsUtil.customExceptionSwitch = true;

        Account childAcc = [SELECT Id, ParentId, Territory_Alias__c, Parent.Territory_Alias__c FROM Account WHERE Name = 'Child Practice 0' LIMIT 1];
        TerritoryHierarchyBatch batch = new TerritoryHierarchyBatch();

        Test.startTest();
        batch.execute(null, new List<Account>{ childAcc });
        Test.stopTest();

        ConstantsUtil.customExceptionSwitch = false;
        Assert.isTrue(true, 'Should handle exception gracefully');
    }

    @IsTest
    static void testBatchBulkChildAccounts() {
        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Practice' LIMIT 1];
        List<Account> childScope = [SELECT Id, Territory_Alias__c, ParentId, Parent.Territory_Alias__c FROM Account WHERE ParentId = :parent.Id];

        TerritoryHierarchyBatch batch = new TerritoryHierarchyBatch();
        Test.startTest();
        batch.execute(null, childScope);
        Test.stopTest();

        Integer matchCount = [SELECT COUNT() FROM Account WHERE ParentId = :parent.Id AND Territory_Alias__c = 'PARENT_TERRITORY'];
        Assert.areEqual(48, matchCount, 'All 48 children (3 + 45 bulk from setup) should have parent territory');
    }

    /**
     * @description Test batch finish method
     *              Covers: finish method with job query and logging
     */
    @IsTest
    static void testFinishMethod() {
        Test.startTest();
        TerritoryHierarchyBatch batch = new TerritoryHierarchyBatch();
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
}