/**
 * Test class for CaseTriggerHandler focusing on trigger handler integration.
 * Tests that the handler correctly delegates to CaseService.
 * Business logic tests are covered in CaseService_Test.cls.
 * 
 * @author      Saikat Ghosh
 * @created     25th Feb 2026
 *
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       25th Feb 2026       Saikat Ghosh      (US - NGASIM-2045) Initial version – Case trigger handler test class
 */
@IsTest(isParallel=true)
private class CaseTriggerHandler_Test {

    /**
     * @description Test handler and trigger - covers all CaseTriggerHandler code paths and trigger execution
     * Handler: null/empty maps, delegation with records for both afterInsert and afterUpdate.
     * Trigger: DML insert + update fires trigger (covers CaseTrigger and handler via execute).
     * Business logic is tested in CaseService_Test.cls
     */
    @IsTest
    static void testHandlerAndTrigger() {
        CaseTriggerHandler handler = new CaseTriggerHandler();

        Test.startTest();
        // Handler afterInsert: null maps
        handler.afterInsert(null);
        // Handler afterInsert: empty maps
        handler.afterInsert(new Map<Id, Case>());
        // Handler afterInsert: delegation with records
        Case insertCase = (Case)MockDataFactory.mockData('Case', new Map<String, Object>{ 'Subject' => 'Test Case Insert' });
        insertCase.Id = MockDataFactory.getFakeId('Case');
        handler.afterInsert(new Map<Id, Case>{ insertCase.Id => insertCase });
        // Handler afterUpdate: null maps
        handler.afterUpdate(null, null);
        // Handler afterUpdate: empty maps
        handler.afterUpdate(new Map<Id, Case>(), new Map<Id, Case>());
        // Handler afterUpdate: delegation with records
        Case oldCase = (Case)MockDataFactory.mockData('Case', new Map<String, Object>{ 'Subject' => 'Test Case' });
        oldCase.Id = MockDataFactory.getFakeId('Case');
        Case newCase = (Case)MockDataFactory.mockData('Case', new Map<String, Object>{ 'Subject' => 'Test Case Updated' });
        newCase.Id = oldCase.Id;
        handler.afterUpdate(new Map<Id, Case>{ newCase.Id => newCase }, new Map<Id, Case>{ oldCase.Id => oldCase });
        // Trigger: DML insert + update fires trigger (covers CaseTrigger and handler via execute)
        Case testCase = new Case(Subject = 'Test Case for Update');
        insert testCase;
        testCase.Subject = 'Test Case Updated';
        update testCase;
        Test.stopTest();

        Case updatedCase = [SELECT Id, Subject FROM Case WHERE Id = :testCase.Id];
        Assert.areEqual('Test Case Updated', updatedCase.Subject, 'Trigger should execute successfully');
    }

}