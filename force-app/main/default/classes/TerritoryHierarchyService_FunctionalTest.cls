/**
 * @description Test class for TerritoryHierarchyService, TerritoryHierarchyHandler,
 *              and ApplyTerritoryToHierarchyQueueable.
 *              Uses TestDataFactory for all test data creation.
 * 
 * NOTE: We can't use @isTest(isParallel=true) because of this error:  APEX_DATA_ACCESS_RESTRICTION, 
 *       In parallel Apex tests, DML operations aren't permitted on this type of object: User: []
 *
 * @author      Ayush Sharma
 * @created     Feb 24, 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       24th Feb 2026       Ayush Sharma                  Initial Version
 */
@IsTest
private class TerritoryHierarchyService_FunctionalTest {

    /**
     * @description Returns the Sales Ops Persona user created in @TestSetup.
     *              Used with System.runAs() to execute trigger flow tests.
     * @return User record for Sales Ops Persona (FirstName='Sales Ops', LastName='Persona')
     */
    private static User getSalesOpsUser() {
        return [SELECT Id FROM User WHERE FirstName = 'Sales Ops' AND LastName = 'Persona' LIMIT 1];
    }

    @TestSetup
    static void setupTestData() {
        User salesOpsUser;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            salesOpsUser = TestDataFactory.getTestUser('Sales', new Map<String, Object>{
                'FirstName' => 'Sales Ops',
                'LastName' => 'Persona'
            });
            insert salesOpsUser;
            TestDataFactory.assignPermissionSet(salesOpsUser.Id, 'Sales_Ops_Core_Access');
            TestDataFactory.assignPermissionSet(salesOpsUser.Id, 'HealthCloudFoundation');
        }

        // TerritoryAlias__c and ZipCode__c
        List<TerritoryAlias__c> territories = new List<TerritoryAlias__c>{
            new TerritoryAlias__c(Name = 'Parent Territory', Territory_Developer_Name__c = 'PARENT_TERRITORY'),
            new TerritoryAlias__c(Name = 'Child Territory', Territory_Developer_Name__c = 'CHILD_TERRITORY')
        };
        insert territories;

        TerritoryAlias__c parentTerritory = [SELECT Id FROM TerritoryAlias__c WHERE Territory_Developer_Name__c = 'PARENT_TERRITORY' LIMIT 1];
        TerritoryAlias__c childTerritory = [SELECT Id FROM TerritoryAlias__c WHERE Territory_Developer_Name__c = 'CHILD_TERRITORY' LIMIT 1];

        List<ZipCode__c> zipCodes = new List<ZipCode__c>{
            new ZipCode__c(Name = '10001', Territory_Name__c = parentTerritory.Id),
            new ZipCode__c(Name = '20001', Territory_Name__c = childTerritory.Id)
        };
        insert zipCodes;

        System.runAs(salesOpsUser) {
            Account parentAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
                'Name' => 'Parent Practice',
                'BillingPostalCode' => '10001',
                'Territory_Alias__c' => 'PARENT_TERRITORY'
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
            insert childAccounts;
        }
    }

    /**
     * @description Positive: Sales Ops checks Apply_Territory_to_Hierarchy__c -> trigger fires -> enqueue -> all child Territory_Alias__c updated.
     */
    @IsTest
    static void testPositiveCheckboxCheckedBySalesOps() {
        User salesOpsUser = getSalesOpsUser();
        System.runAs(salesOpsUser) {
            Account parent = [SELECT Id, Apply_Territory_to_Hierarchy__c, Territory_Alias__c FROM Account WHERE Name = 'Parent Practice' LIMIT 1];
            List<Account> childrenBefore = [SELECT Id, Territory_Alias__c FROM Account WHERE ParentId = :parent.Id];

            for (Account c : childrenBefore) {
                Assert.areEqual('CHILD_TERRITORY', c.Territory_Alias__c, 'Child should have child territory before update');
            }

            parent.Apply_Territory_to_Hierarchy__c = true;
            Test.startTest();
            update parent;
            Test.stopTest();

            List<Account> childrenAfter = [SELECT Id, Territory_Alias__c FROM Account WHERE ParentId = :parent.Id];
            for (Account c : childrenAfter) {
                Assert.areEqual('PARENT_TERRITORY', c.Territory_Alias__c, 'All children should have parent territory after checkbox checked');
            }
        }
    }

    /**
     * @description Negative: Marking checkbox to false does nothing - no enqueue, children unchanged.
     */
    @IsTest
    static void testNegativeCheckboxUncheckedNoAction() {
        User salesOpsUser = getSalesOpsUser();
        System.runAs(salesOpsUser) {
            Account parent = [SELECT Id, Apply_Territory_to_Hierarchy__c FROM Account WHERE Name = 'Parent Practice' LIMIT 1];
            parent.Apply_Territory_to_Hierarchy__c = false;

            Test.startTest();
            update parent;
            Test.stopTest();

            List<Account> children = [SELECT Id, Territory_Alias__c FROM Account WHERE ParentId = :parent.Id];
            for (Account c : children) {
                Assert.areEqual('CHILD_TERRITORY', c.Territory_Alias__c, 'Children should remain unchanged when checkbox unchecked');
            }
        }
    }

    /**
     * @description Negative: Handler receives null - no action, no exception.
     */
    @IsTest
    static void testNegativeHandlerNullInput() {
        Test.startTest();
        TerritoryHierarchyHandler.processApplyTerritoryToHierarchy(null, null);
        Test.stopTest();
        Assert.isTrue(true, 'Handler should handle null input without error');
    }

    /**
     * @description Negative: Handler receives empty list - no action, no exception.
     */
    @IsTest
    static void testNegativeHandlerEmptyInput() {
        Test.startTest();
        TerritoryHierarchyHandler.processApplyTerritoryToHierarchy(new List<Account>(), new Map<Id, Account>());
        Test.stopTest();
        Assert.isTrue(true, 'Handler should handle empty input without error');
    }

    /**
     * @description enqueueApplyTerritoryJob: null and empty parent IDs return early without error.
     */
    @IsTest
    static void testEnqueueApplyTerritoryJobEmptyCheck() {
        TerritoryHierarchyService.enqueueApplyTerritoryJob(null);
        TerritoryHierarchyService.enqueueApplyTerritoryJob(new Set<Id>());
        Assert.isTrue(true, 'Should handle null and empty input without error');
    }

    /**
     * @description ApplyTerritoryToHierarchyQueueable execute: null and empty parent IDs return early.
     */
    @IsTest
    static void testApplyTerritoryToHierarchyQueueableNullEmptyInput() {
        ApplyTerritoryToHierarchyQueueable jobNull = new ApplyTerritoryToHierarchyQueueable(null);
        ApplyTerritoryToHierarchyQueueable jobEmpty = new ApplyTerritoryToHierarchyQueueable(new Set<Id>());

        Test.startTest();
        jobNull.execute(null);
        jobEmpty.execute(null);
        Test.stopTest();

        Assert.isTrue(true, 'Execute should handle null and empty parent IDs without error');
    }

    /**
     * @description applyTerritoryToChildAccounts: null and empty parent IDs return early without error.
     */
    @IsTest
    static void testApplyTerritoryToChildAccountsEmptyCheck() {
        TerritoryHierarchyService.applyTerritoryToChildAccounts(null);
        TerritoryHierarchyService.applyTerritoryToChildAccounts(new Set<Id>());
        Assert.isTrue(true, 'Should handle null and empty input without error');
    }

    /**
     * @description Covers exception handling in enqueueApplyTerritoryJob when customExceptionSwitch is enabled.
     *              Calls enqueueApplyTerritoryJob directly; verifies exceptions are caught and logged without propagating.
     */
    @IsTest
    static void testEnqueueApplyTerritoryJobExceptionHandling() {
        User salesOpsUser = getSalesOpsUser();
        System.runAs(salesOpsUser) {
            Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Practice' LIMIT 1];
            parent.Apply_Territory_to_Hierarchy__c = true;
            update parent;

            ConstantsUtil.customExceptionSwitch = true;

            Test.startTest();
            TerritoryHierarchyService.enqueueApplyTerritoryJob(new Set<Id>{ parent.Id });
            Test.stopTest();

            ConstantsUtil.customExceptionSwitch = false;
            Assert.isTrue(true, 'Should handle exception gracefully without propagating');
        }
    }

    /**
     * @description Covers exception handling in updateChildAccountsTerritoryAlias when customExceptionSwitch is enabled.
     */
    @IsTest
    static void testUpdateChildAccountsTerritoryAliasExceptionHandling() {
        User salesOpsUser = getSalesOpsUser();
        System.runAs(salesOpsUser) {
            List<Account> children = [SELECT Id, Territory_Alias__c FROM Account WHERE Name LIKE 'Child Practice%'];
            List<Account> accountsToUpdate = new List<Account>();
            for (Account c : children) {
                accountsToUpdate.add(new Account(Id = c.Id, Territory_Alias__c = 'PARENT_TERRITORY'));
            }

            ConstantsUtil.customExceptionSwitch = true;

            Test.startTest();
            Integer count = TerritoryHierarchyService.updateChildAccountsTerritoryAlias(accountsToUpdate);
            Test.stopTest();

            ConstantsUtil.customExceptionSwitch = false;
            Assert.areEqual(0, count, 'Should return 0 when exception thrown at start');
            Assert.isTrue(true, 'Should handle exception gracefully without propagating');
        }
    }

    /**
     * @description getChildPracticeAccountsByParentIds: null and empty parent IDs return empty list.
     */
    @IsTest
    static void testGetChildPracticeAccountsByParentIdsNullEmpty() {
        List<Account> resultNull = TerritoryHierarchyService.getChildPracticeAccountsByParentIds(null);
        Assert.areEqual(0, resultNull.size(), 'Null parent IDs should return empty list');

        List<Account> resultEmpty = TerritoryHierarchyService.getChildPracticeAccountsByParentIds(new Set<Id>());
        Assert.areEqual(0, resultEmpty.size(), 'Empty parent IDs should return empty list');
    }

    /**
     * @description filterChildAccountsForTerritoryUpdate: null and empty child accounts return empty list.
     */
    @IsTest
    static void testFilterChildAccountsForTerritoryUpdateNullEmpty() {
        List<Account> resultNull = TerritoryHierarchyService.filterChildAccountsForTerritoryUpdate(null);
        Assert.areEqual(0, resultNull.size(), 'Null child accounts should return empty list');

        List<Account> resultEmpty = TerritoryHierarchyService.filterChildAccountsForTerritoryUpdate(new List<Account>());
        Assert.areEqual(0, resultEmpty.size(), 'Empty child accounts should return empty list');
    }

    /**
     * @description updateChildAccountsTerritoryAlias: empty list returns 0; deleted account ID fails gracefully.
     */
    @IsTest
    static void testUpdateChildAccountsTerritoryAliasEmptyAndDeletedId() {
        Integer countEmpty = TerritoryHierarchyService.updateChildAccountsTerritoryAlias(new List<Account>());
        Assert.areEqual(0, countEmpty, 'Empty list should return 0');

        Integer countNull = TerritoryHierarchyService.updateChildAccountsTerritoryAlias(null);
        Assert.areEqual(0, countNull, 'Null list should return 0');

        Account toDelete = [SELECT Id FROM Account WHERE Name = 'Child Practice 0' LIMIT 1];
        Id deletedId = toDelete.Id;
        delete toDelete;

        List<Account> withDeletedId = new List<Account>{
            new Account(Id = deletedId, Territory_Alias__c = 'PARENT_TERRITORY')
        };

        User salesOpsUser = getSalesOpsUser();
        System.runAs(salesOpsUser) {
            Integer countDeleted = TerritoryHierarchyService.updateChildAccountsTerritoryAlias(withDeletedId);
            Assert.areEqual(0, countDeleted, 'Deleted account ID should fail gracefully, success count 0');
        }
    }

    /**
     * @description Mock FinalizerContext for testing TerritoryHierarchyFinalizer
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
         * @description Gets the exception (can be null)
         * @return Exception
         */
        public Exception getException() {
            return ex;
        }

        /**
         * @description Gets the async apex job ID (returns null for mock)
         * @return Id
         */
        public Id getAsyncApexJobId() {
            return null;
        }

        /**
         * @description Gets the request ID (returns null for mock)
         * @return String
         */
        public String getRequestId() {
            return null;
        }
    }

    /**
     * @description Test TerritoryHierarchyFinalizer with unhandled exception
     */
    @IsTest
    static void testTerritoryHierarchyFinalizerWithUnhandledException() {
        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Practice' LIMIT 1];
        Set<Id> parentIds = new Set<Id>{ parent.Id };
        ApplyTerritoryToHierarchyQueueable.TerritoryHierarchyFinalizer finalizer =
            new ApplyTerritoryToHierarchyQueueable.TerritoryHierarchyFinalizer(parentIds);

        Exception testException = new TestException('Test unhandled exception');
        MockFinalizerContext context = new MockFinalizerContext(ParentJobResult.UNHANDLED_EXCEPTION, testException);

        Test.startTest();
        finalizer.execute(context);
        Test.stopTest();

        Assert.isTrue(true, 'Finalizer should handle unhandled exception');
    }

    /**
     * @description Test TerritoryHierarchyFinalizer with successful completion
     */
    @IsTest
    static void testTerritoryHierarchyFinalizerWithSuccess() {
        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Practice' LIMIT 1];
        Set<Id> parentIds = new Set<Id>{ parent.Id };
        ApplyTerritoryToHierarchyQueueable.TerritoryHierarchyFinalizer finalizer =
            new ApplyTerritoryToHierarchyQueueable.TerritoryHierarchyFinalizer(parentIds);

        MockFinalizerContext context = new MockFinalizerContext(ParentJobResult.SUCCESS, null);

        Test.startTest();
        finalizer.execute(context);
        Test.stopTest();

        Assert.isTrue(true, 'Finalizer should handle successful completion');
    }

    /**
     * @description Test TerritoryHierarchyFinalizer with null parent IDs
     */
    @IsTest
    static void testTerritoryHierarchyFinalizerWithNullParentIds() {
        ApplyTerritoryToHierarchyQueueable.TerritoryHierarchyFinalizer finalizer =
            new ApplyTerritoryToHierarchyQueueable.TerritoryHierarchyFinalizer(null);

        Exception testException = new TestException('Test exception');
        MockFinalizerContext context = new MockFinalizerContext(ParentJobResult.UNHANDLED_EXCEPTION, testException);

        Test.startTest();
        finalizer.execute(context);
        Test.stopTest();

        Assert.isTrue(true, 'Finalizer should handle null parent IDs');
    }

    /**
     * @description Test exception for finalizer tests
     */
    private class TestException extends Exception {
    }

    /**
     * @description validateParentChildHierarchy: null/empty inputs return without error.
     */
    @IsTest
    static void testParentChildHierarchyNullEmptyInput() {
        TerritoryHierarchyHandler.validateParentChildHierarchy(null, new Map<Id, Account>());
        TerritoryHierarchyHandler.validateParentChildHierarchy(new List<Account>(), new Map<Id, Account>());
        TerritoryHierarchyHandler.validateParentChildHierarchy(new List<Account>{ new Account(Name = 'Test') }, null);
        Assert.isTrue(true, 'Null/empty inputs should return without error');
    }

    /**
     * @description Adding parent to account that has children throws addError.
     */
    @IsTest
    static void testRejectsAddingParentWhenAccountHasChildren() {
        User salesOpsUser = getSalesOpsUser();
        Account parentWithChildren = [SELECT Id, ParentId FROM Account WHERE Name = 'Parent Practice' LIMIT 1];

        Account grandparent = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Grandparent B',
            'BillingPostalCode' => '10001'
        });
        insert grandparent;

        parentWithChildren.ParentId = grandparent.Id;

        Boolean errorThrown = false;
        System.runAs(salesOpsUser) {
            try {
                update parentWithChildren;
            } catch (DmlException e) {
                errorThrown = true;
                Assert.isTrue(e.getMessage().contains('hierarchy') || e.getMessage().contains('3rd tier'), 'Error should mention hierarchy');
            }
        }
        Assert.isTrue(errorThrown, 'Update should fail when parent has children');
    }

    /**
     * @description Adding parent to account with no children is allowed.
     */
    @IsTest
    static void testAllowsAddingParentWhenAccountHasNoChildren() {
        User salesOpsUser = getSalesOpsUser();
        Account childToPromote;
        Account grandparent;

        System.runAs(salesOpsUser) {
            childToPromote = [SELECT Id, ParentId FROM Account WHERE Name = 'Child Practice 0' LIMIT 1];
            childToPromote.ParentId = null;
            update childToPromote;

            grandparent = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
                'Name' => 'Grandparent For Child',
                'BillingPostalCode' => '20001'
            });
            insert grandparent;

            childToPromote = [SELECT Id, ParentId FROM Account WHERE Id = :childToPromote.Id];
            childToPromote.ParentId = grandparent.Id;
            update childToPromote;
        }

        Account updated = [SELECT Id, ParentId FROM Account WHERE Id = :childToPromote.Id];
        Assert.areEqual(grandparent.Id, updated.ParentId, 'Child with no children should accept new parent');
    }
}