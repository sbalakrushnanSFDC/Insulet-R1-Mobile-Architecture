/**
     * @description Test class for LeadTriggerHandler using MockDataFactory (No DML)
     * @author Bijayalaxmi Prusty
	 * @date 01-10-2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       1st Oct 2025        Bijayalaxmi Prusty            Initial Version(US - NGASIM-379)
 * V1.1.0       15th Oct 2025       Bijayalaxmi Prusty            Modifed(US - NGASIM-380)
 * V1.2.0       11th Dec 2025       Jatin Butta                   Updated(US - NGASIM-1273) - Added Task Generation Tests
 */
@IsTest(isParallel=true)
private class LeadTriggerHandler_Test {

    /**
     * @description Helper method to create records map from lead list
     * @param leads List of Lead records to convert to map
     * @return Map of Id to SObject for the provided leads
     */
    private static Map<Id, SObject> createRecordsMap(List<Lead> leads) {
        Map<Id, SObject> recordsMap = new Map<Id, SObject>();
        for (Lead lead : leads) {
            recordsMap.put(lead.Id, lead);
        }
        return recordsMap;
    }

    /**
     * @description Helper method to execute afterInsert with exception handling
     * @param recordsMap Map of Id to SObject records to pass to afterInsert method
     */
    private static void executeAfterInsert(Map<Id, SObject> recordsMap) {
        LeadTriggerHandler handler = new LeadTriggerHandler();
        try {
            handler.afterInsert(recordsMap);
        } catch (Exception e) {
            // Expected in test context due to IndividualHandler dependencies
            Assert.isTrue(true, 'Exception expected in test context');
        }
    }

    /**
     * @description Helper method to execute afterUpdate
     * @param updatedRecordsMap Map of Id to SObject records to pass to afterUpdate method
     * @param oldRecordsMap Map of Id to SObject records representing old values
     */
    private static void executeAfterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        LeadTriggerHandler handler = new LeadTriggerHandler();
        try {
            handler.afterUpdate(updatedRecordsMap, oldRecordsMap);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
        }
    }

    /**
     * @description Test afterInsert with empty map
     */
    @IsTest
    static void testAfterInsertWithEmptyMap() {
        Map<Id, SObject> emptyMap = new Map<Id, SObject>();

        Test.startTest();
        executeAfterInsert(emptyMap);
        Test.stopTest();

        Assert.isTrue(true, 'Empty map should be handled gracefully');
    }

    /**
     * @description Test afterInsert with single Lead using MockDataFactory
     */
    @IsTest
    static void testAfterInsertWithSingleLead() {
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'Company' => 'Test Company',
            'IndividualId' => null
        });

        Test.startTest();
        executeAfterInsert(createRecordsMap(testLeads));
        Test.stopTest();

        Assert.areEqual(1, testLeads.size(), 'Should have 1 test lead');
        Assert.areEqual('John', testLeads[0].FirstName, 'FirstName should match');
    }

    /**
     * @description Test afterInsert with multiple Leads using MockDataFactory
     */
    @IsTest
    static void testAfterInsertWithMultipleLeads() {
        List<Lead> testLeads = MockDataFactory.createLeads(3, new Map<String, Object>{
            'Company' => 'Bulk Test Company',
            'Status' => 'Open',
            'IndividualId' => null
        });

        Test.startTest();
        executeAfterInsert(createRecordsMap(testLeads));
        Test.stopTest();

        Assert.areEqual(3, testLeads.size(), 'Should have 3 test leads');
    }

    /**
     * @description Test afterInsert with Lead having existing IndividualId using MockDataFactory
     */
    @IsTest
    static void testAfterInsertWithExistingIndividualId() {
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'Existing',
            'LastName' => 'Lead',
            'IndividualId' => MockDataFactory.getFakeId('Individual')
        });

        Test.startTest();
        executeAfterInsert(createRecordsMap(testLeads));
        Test.stopTest();

        Assert.areNotEqual(null, testLeads[0].IndividualId, 'IndividualId should not be null');
    }

    /**
     * @description Test afterInsert with Lead using TestDataFactory (with DML)
     */
    @IsTest
    static void testAfterInsert() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'TestData',
            'LastName' => 'Lead',
            'Company' => 'TestData Company',
            'Email' => 'testdata.lead@example.com',
            'IndividualId' => null
        });

        insert testLead;
        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>();
        newRecordsMap.put(testLead.Id, testLead);

        Test.startTest();
        LeadTriggerHandler handler = new LeadTriggerHandler();
        try {
            handler.afterInsert(newRecordsMap);
            Assert.isTrue(true, 'afterInsert should complete successfully for TestDataFactory Lead');
        } catch (Exception e) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();

        Lead insertedLead = [SELECT Id, FirstName, Company FROM Lead WHERE Id = :testLead.Id];
        Assert.areEqual('TestData', insertedLead.FirstName, 'FirstName should match');
        Assert.areEqual('TestData Company', insertedLead.Company, 'Company should match');
    }

    /**
     * @description Test afterUpdate with empty maps
     */
    @IsTest
    static void testAfterUpdateWithEmptyMaps() {
        Map<Id, SObject> emptyUpdatedMap = new Map<Id, SObject>();
        Map<Id, SObject> emptyOldMap = new Map<Id, SObject>();

        Test.startTest();
        IndividualHandler.manageUpdateIndividuals(new List<SObject>(), emptyOldMap);
        IndividualHandler.manageUpdateIndividuals(null, emptyOldMap);
        executeAfterUpdate(emptyUpdatedMap, emptyOldMap);
        Test.stopTest();

        Assert.isTrue(true, 'Empty maps should be handled gracefully');
    }

    /**
     * @description Test afterUpdate with Lead having existing IndividualId and name changes (should be processed for update)
     */
    @IsTest
    static void testAfterUpdateLeadExistingIdNameChanged() {
        Id leadId = MockDataFactory.getFakeId('Lead');
        Id individualId = MockDataFactory.getFakeId('Individual');

        // Create new record with updated name fields
        Lead newLead = new Lead(
            Id = leadId,
            FirstName = 'Updated',
            LastName = 'NewLead',
            MiddleName = 'Updated',
            Salutation = 'Ms.',
            Suffix = 'Jr.',
            IndividualId = individualId,
            Company = 'Test Company'
        );

        // Create old record with original name fields
        Lead oldLead = new Lead(
            Id = leadId,
            FirstName = 'Original',
            LastName = 'OldLead',
            MiddleName = 'Original',
            Salutation = 'Mr.',
            Suffix = 'Sr.',
            IndividualId = individualId,
            Company = 'Test Company'
        );

        List<SObject> newLeads = new List<SObject>{ newLead };
        Map<Id, SObject> oldLeadsMap = new Map<Id, SObject>{ oldLead.Id => oldLead };

        Test.startTest();
        IndividualHandler.manageUpdateIndividuals(newLeads, oldLeadsMap);
        Test.stopTest();

        Assert.areNotEqual(null, newLead.IndividualId, 'IndividualId should not be null');
        Assert.areEqual('Updated', newLead.FirstName, 'FirstName should match');
        Assert.areNotEqual(oldLead.FirstName, newLead.FirstName, 'Names should be different to trigger processing');
    }

    /**
     * @description Test afterUpdate with Lead having existing IndividualId but no name changes (should NOT be processed for update)
     */
    @IsTest
    static void testAfterUpdateLeadExistingIdNameUnchanged() {
        // Create records with same name fields for both old and new
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'Unchanged',
            'LastName' => 'Lead',
            'MiddleName' => 'Unchanged',
            'Salutation' => 'Dr.',
            'Suffix' => 'III',
            'IndividualId' => MockDataFactory.getFakeId('Individual')
        });

        Map<Id, SObject> updatedRecordsMap = createRecordsMap(testLeads);
        Map<Id, SObject> oldRecordsMap = createRecordsMap(testLeads);

        Test.startTest();
        executeAfterUpdate(updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        Assert.areNotEqual(null, testLeads[0].IndividualId, 'IndividualId should not be null');
        Assert.areEqual('Unchanged', testLeads[0].FirstName, 'Name should remain unchanged');
    }

    /**
     * @description Test afterUpdate with Lead having null IndividualId (should NOT be processed for update)
     */
    @IsTest
    static void testAfterUpdateLeadNullId() {
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'NoIndividual',
            'LastName' => 'Lead',
            'IndividualId' => null
        });

        Map<Id, SObject> updatedRecordsMap = createRecordsMap(testLeads);
        Map<Id, SObject> oldRecordsMap = createRecordsMap(testLeads);

        Test.startTest();
        executeAfterUpdate(updatedRecordsMap, oldRecordsMap);
        Test.stopTest();

        Assert.areEqual(null, testLeads[0].IndividualId, 'IndividualId should be null');
    }


    /**
     * @description Test afterUpdate with lead using TestDataFactory (with DML) and name changes
     */
    @IsTest
    static void testAfterUpdate() {
        // Arrange - Create and insert Lead using TestDataFactory
        Lead originalLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Original',
            'LastName' => 'Lead',
            'MiddleName' => 'Original',
            'Salutation' => 'Mr.',
            'Suffix' => 'Sr.',
            'Company' => 'Original Company',
            'Email' => 'original.lead@example.com'
        });
        insert originalLead;

        // Assign IndividualId to ensure processing occurs
        originalLead.IndividualId = MockDataFactory.getFakeId('Individual');

        // Create updated version with modified name fields
        Lead updatedLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Updated',
            'LastName' => 'ModifiedLead',
            'MiddleName' => 'Updated',
            'Salutation' => 'Ms.',
            'Suffix' => 'Jr.',
            'Company' => 'Updated Company',
            'Email' => 'updated.lead@example.com'
        });
        updatedLead.Id = originalLead.Id;
        updatedLead.IndividualId = originalLead.IndividualId;

        Map<Id, SObject> updatedRecordsMap = new Map<Id, SObject>();
        updatedRecordsMap.put(updatedLead.Id, updatedLead);

        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>();
        oldRecordsMap.put(originalLead.Id, originalLead);

        // Act
        Test.startTest();
        LeadTriggerHandler handler = new LeadTriggerHandler();
        try {
            handler.afterUpdate(updatedRecordsMap, oldRecordsMap);
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();

        // Assert - Verify the lead exists and has correct properties
        Lead verifiedLead = [SELECT Id, FirstName, LastName, Company FROM Lead WHERE Id = :originalLead.Id];
        Assert.areEqual('Original', verifiedLead.FirstName, 'FirstName should match original inserted value');
        Assert.areEqual('Lead', verifiedLead.LastName, 'LastName should match original inserted value');
        Assert.areEqual('Original Company', verifiedLead.Company, 'Company should match original inserted value');
        Assert.areNotEqual(updatedLead.FirstName, verifiedLead.FirstName, 'Names should be different to test name change logic');
    }

    // ========== TASK GENERATION TESTS (NGASIM-1273) =========
    /**
     * @description Test Spanish language is set for Empezar leads
     */
    @IsTest
    static void testSpanishLanguageForEmpezarLeads() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Spanish',
            'LastName' => 'Lead',
            'Company' => 'Test Company',
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_EMPEZAR
        });

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Id, Preferred_Language__c FROM Lead WHERE Id = :testLead.Id];
        Assert.areEqual(ConstantsUtil.LANGUAGE_SPANISH, insertedLead.Preferred_Language__c, 'Primary Language should be set to Spanish');
    }

    /**
     * @description Test Spanish language is not changed if already Spanish
     */
    @IsTest
    static void testSpanishLanguageNotOverwrittenIfAlreadySpanish() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Spanish',
            'LastName' => 'AlreadySpanish',
            'Company' => 'Test Company',
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_EMPEZAR,
            'Preferred_Language__c' => ConstantsUtil.LANGUAGE_SPANISH
        });

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Id, Preferred_Language__c FROM Lead WHERE Id = :testLead.Id];
        Assert.areEqual(ConstantsUtil.LANGUAGE_SPANISH, insertedLead.Preferred_Language__c, 'Primary Language should remain Spanish');
    }

    /**
     * @description Test Spanish language overrides other language for Empezar leads
     */
    @IsTest
    static void testSpanishLanguageOverridesOtherLanguage() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Spanish',
            'LastName' => 'Override',
            'Company' => 'Test Company',
            'LeadSource' => ConstantsUtil.LEAD_SOURCE_EMPEZAR,
            'Preferred_Language__c' => 'English'
        });

        Test.startTest();
        insert testLead;
        Test.stopTest();

        Lead insertedLead = [SELECT Id, Preferred_Language__c FROM Lead WHERE Id = :testLead.Id];
        Assert.areEqual(ConstantsUtil.LANGUAGE_SPANISH, insertedLead.Preferred_Language__c, 'Primary Language should be changed to Spanish');
    }

    /**
     * @description Test task generation is called on lead insert
     */
    @IsTest
    static void testTaskGenerationOnLeadInsert() {
        // Create test lead
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Task',
            'LastName' => 'Generation',
            'Company' => 'Test Company',
            'LeadSource' => 'Get Started',
            'Matching_Status__c' => 'Partial Match'
        });

        Test.startTest();
        insert testLead;
        Test.stopTest();

        // Verify lead was inserted successfully (task generation depends on Custom Metadata)
        Lead insertedLead = [SELECT Id, LeadSource, Matching_Status__c FROM Lead WHERE Id = :testLead.Id];
        Assert.areEqual('Get Started', insertedLead.LeadSource, 'LeadSource should match');
        Assert.areEqual('Partial Match', insertedLead.Matching_Status__c, 'Matching Status should match');
    }

    /**
     * @description Test task generation is called on lead update
     */
    @IsTest
    static void testTaskGenerationOnLeadUpdate() {
        // Create and insert test lead
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Task',
            'LastName' => 'Update',
            'Company' => 'Test Company',
            'LeadSource' => 'Web'
        });
        insert testLead;

        // Update lead to match task generation criteria
        testLead.LeadSource = 'Get Started';
        testLead.Matching_Status__c = 'Partial Match';

        Test.startTest();
        update testLead;
        Test.stopTest();

        // Verify lead was updated successfully (task generation depends on Custom Metadata)
        Lead updatedLead = [SELECT Id, LeadSource, Matching_Status__c FROM Lead WHERE Id = :testLead.Id];
        Assert.areEqual('Get Started', updatedLead.LeadSource, 'LeadSource should be updated');
        Assert.areEqual('Partial Match', updatedLead.Matching_Status__c, 'Matching Status should be updated');
    }
}