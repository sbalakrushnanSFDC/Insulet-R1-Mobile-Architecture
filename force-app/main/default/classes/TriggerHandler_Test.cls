@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(isParallel=true)
private class TriggerHandler_Test {

    private class TestTriggerHandler extends TriggerHandler {
        @SuppressWarnings('PMD.ApexDoc')
        public TriggerOperation method { get; private set;}

        @TestVisible
        protected override void beforeInsert(List<SObject> newRecords) {
            this.method = TriggerOperation.BEFORE_INSERT;
        }
        @TestVisible
        protected override void beforeUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
            this.method = TriggerOperation.BEFORE_UPDATE;
        }
        @TestVisible
        protected override void beforeDelete(Map<Id, SObject> deletedRecordsMap) {
            this.method = TriggerOperation.BEFORE_DELETE;
        }
        @TestVisible
        protected override void afterInsert(Map<Id, SObject> newRecordsMap) {
            this.method = TriggerOperation.AFTER_INSERT;
        }
        @TestVisible
        protected override void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
            this.method = TriggerOperation.AFTER_UPDATE;
        }
        @TestVisible
        protected override void afterDelete(Map<Id, SObject> deletedRecordsMap) {
            this.method = TriggerOperation.AFTER_DELETE;
        }
        @TestVisible
        protected override void afterUndelete(Map<Id, SObject> undeletedRecordsMap) {
            this.method = TriggerOperation.AFTER_UNDELETE;
        }
    }

    @IsTest
    static void performBeforeInsert() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.BEFORE_INSERT;

        testHandler.execute();

        Assert.areEqual(TriggerOperation.BEFORE_INSERT, testHandler.Method, 'Handler execution did not run the correct "before insert" method');
    }

    @IsTest
    static void performBeforeUpdate() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.BEFORE_UPDATE;

        testHandler.execute();

        Assert.areEqual(TriggerOperation.BEFORE_UPDATE, testHandler.Method, 'Handler execution did not run the correct "before update" method');
    }

    @IsTest
    static void performBeforeDelete() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.BEFORE_DELETE;

        testHandler.execute();

        Assert.areEqual(TriggerOperation.BEFORE_DELETE, testHandler.Method, 'Handler execution did not run the correct "before delete" method');
    }

    @IsTest
    static void performAfterInsert() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.AFTER_INSERT;

        testHandler.execute();

        Assert.areEqual(TriggerOperation.AFTER_INSERT, testHandler.Method, 'Handler execution did not run the correct "after insert" method');
    }

    @IsTest
    static void performAfterUpdate() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.AFTER_UPDATE;

        testHandler.execute();

        Assert.areEqual(TriggerOperation.AFTER_UPDATE, testHandler.Method, 'Handler execution did not run the correct "after update" method');
    }

    @IsTest
    static void performAfterDelete() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.AFTER_DELETE;

        testHandler.execute();

        Assert.areEqual(TriggerOperation.AFTER_DELETE, testHandler.Method, 'Handler execution did not run the correct "after delete" method');
    }

    @IsTest
    static void performAfterUndelete() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        TriggerHandler.triggerContext = TriggerOperation.AFTER_UNDELETE;

        testHandler.execute();

        Assert.areEqual(TriggerOperation.AFTER_UNDELETE, testHandler.Method, 'Handler execution did not run the correct "after undelete" method');
    }

    @IsTest
    static void testBypassWithClear() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        String handlerName = testHandler.getHandlerName();
        TriggerHandler.bypass(handlerName);

        Assert.isTrue(TriggerHandler.isBypassed(handlerName), 'Handler not bypassed after bypass method call');

        TriggerHandler.triggerContext = TriggerOperation.BEFORE_INSERT;
        testHandler.execute();

        Assert.isNull(testHandler.Method, 'Handler execution should not run and set a method value');

        TriggerHandler.clearBypass(handlerName);
        testHandler.execute();

        Assert.areEqual(TriggerOperation.BEFORE_INSERT, testHandler.Method, 'Handler execution did not run after clearing bypass');
    }

    @IsTest
    static void testBypassWithClearAll() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        String handlerName = testHandler.getHandlerName();
        TriggerHandler.bypass(handlerName);
        TriggerHandler.triggerContext = TriggerOperation.BEFORE_INSERT;

        testHandler.execute();

        Assert.isNull(testHandler.Method, 'Handler execution should not run and set a method value');

        TriggerHandler.clearAllBypasses();

        testHandler.execute();
        Assert.areEqual(TriggerOperation.BEFORE_INSERT, testHandler.Method, 'Handler execution did not run after clearing bypass');
    }

    @IsTest
    static void testMaxLoopCount() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        testHandler.setMaxLoopCount(2);
        String handlerName = testHandler.getHandlerName();
        TriggerHandler.triggerContext = TriggerOperation.BEFORE_INSERT;

        testHandler.execute();
        testHandler.execute();

        Assert.areEqual(TriggerOperation.BEFORE_INSERT, testHandler.Method, 'Handler execution did not run after clearing bypass');

        Boolean errorThrown = false;
        try {
            testHandler.execute();
        } catch (TriggerHandler.TriggerHandlerException e) {
            errorThrown = true;
        }
        Assert.isTrue(errorThrown, 'Exception should have been thrown on third execution');
    }

    @IsTest
    static void testClearMaxLoopCount() {
        TestTriggerHandler testHandler = new TestTriggerHandler();
        testHandler.setMaxLoopCount(2);
        String handlerName = testHandler.getHandlerName();
        TriggerHandler.triggerContext = TriggerOperation.BEFORE_INSERT;

        testHandler.execute();
        testHandler.execute();

        Assert.areEqual(TriggerOperation.BEFORE_INSERT, testHandler.Method, 'Handler execution did not run after clearing bypass');

        testHandler.clearMaxLoopCount();
        Boolean errorThrown = false;
        try {
            testHandler.execute();
        } catch (TriggerHandler.TriggerHandlerException e) {
            errorThrown = true;
        }
        Assert.isFalse(errorThrown, 'Exception should have been thrown on third execution');
    }

    @IsTest
    static void testLoopCount() {
        // code coverage for LoopCount inner class
        TriggerHandler.LoopCount lc = new TriggerHandler.LoopCount();
        Assert.areEqual(lc.getMax(), 5, 'Expected default constructor to set loop count correctly');
        Assert.areEqual(lc.getCount(), 0, 'Expected default constructor to set loop count correctly');

        lc.setMax(2);
        Assert.areEqual(lc.getMax(), 2, 'Expected setMax to set loop count correctly');

        Boolean incrementResult = lc.increment();
        Assert.areEqual(lc.getCount(), 1, 'Expected increment to set loop count to 1');
        Assert.isFalse(incrementResult, 'Expected increment to return false when count 1 does not exceed max');

        incrementResult = lc.increment();
        Assert.isFalse(incrementResult, 'Expected increment to return false when count 2 does not exceed max');
        Assert.areEqual(lc.getCount(), 2, 'Expected increment to set loop count to 2');

        incrementResult = lc.increment();
        Assert.isTrue(incrementResult, 'Expected increment to return true when max is exceeded');
        Assert.areEqual(lc.getCount(), 3, 'Expected increment to set loop count to 3');
    }

    // invoke the original overridable methods for code coverage.
    // The tests above never invoke the empty virtual methods.
    @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
    @IsTest
    static void invokeEmptyHandlerMethods() {
        TriggerHandler testHandler = new TriggerHandler();

        for (TriggerOperation op : TriggerOperation.values()) {
            TriggerHandler.triggerContext = op;
            testHandler.execute();
        }
    }
}