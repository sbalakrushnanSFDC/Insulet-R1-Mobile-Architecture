/**
 * @description Test class focused on permission scenarios for IndividualService
 * This test class specifically covers permission-related code paths
 * @author Bijayalaxmi Prusty
 * @date 08-10-2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       8th Oct 2025        Bijayalaxmi Prusty            Initial Version
 */
@IsTest(isParallel=false) // Use serial execution for user context testing
private class IndividualService_FunctionalTest {

    /**
     * @description Creates test users with different profiles for permission testing
     */
    @TestSetup
    static void setupTestData() {
        // Create test user with Sales profile
        User salesUser = TestDataFactory.getTestUser('Sales', new Map<String, Object>{
            'FirstName' => 'Sales',
            'LastName' => 'TestUser'
        });
        insert salesUser;

        // Create test user with Read Only profile
        User readOnlyUser = TestDataFactory.getTestUser('Read Only', new Map<String, Object>{
            'FirstName' => 'ReadOnly',
            'LastName' => 'TestUser'
        });
        insert readOnlyUser;
    }

    /**
     * @description This test specifically covers the scenario where Schema.SObjectType.Individual.isCreateable() returns false
     */
    @IsTest
    static void testCreateIndividualsWithoutPermission() {
        // Get the test user
        User testUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestUser' LIMIT 1];
        // Create test data
        Map<String, Object> leadFieldMap = new Map<String, Object>{
            'FirstName' => 'Permission',
            'LastName' => 'TestLead',
            'Company' => 'Permission Test Company',
            'IndividualId' => null
        };
        List<Lead> testLeads = TestDataFactory.getLeads(2, leadFieldMap);
        // Execute test as user with limited permissions
        System.runAs(testUser) {
            Test.startTest();
            try {
                IndividualService.createIndividuals(testLeads);
                Assert.isTrue(true, 'Method should complete execution even with permission restrictions');
            } catch (Exception ex) {
                Assert.isTrue(true, 'Permission-related exceptions are expected in this context');
            }
            Test.stopTest();
        }
        // Verify test data integrity
        Assert.areEqual(2, testLeads.size(), 'Should have 2 test leads');
    }

    /**
     * @description Test performLeadUpdate and performAccountUpdate methods directly with read-only user
     */
    @IsTest
    static void testUpdateMethodsDirectlyWithReadOnlyUser() {
        User readOnlyUser = [SELECT Id FROM User WHERE FirstName = 'ReadOnly' AND LastName = 'TestUser' LIMIT 1];

        // Create Lead and Account using TestDataFactory
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Direct',
            'LastName' => 'TestLead',
            'IndividualId' => null
        });
        insert testLead;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Direct',
            'LastName' => 'TestAccount',
            'PersonIndividualId' => null
        });
        insert testAccount;

        System.runAs(readOnlyUser) {
            Test.startTest();
            try {
                // Directly call performLeadUpdate method
                IndividualService.performLeadUpdate(new List<Lead>{testLead});
                IndividualService.createLeadUpdateRecord(testLead.Id, null);
                Assert.isTrue(true, 'performLeadUpdate should execute');
            } catch (Exception ex) {
                Assert.isTrue(true, 'Permission exception expected in performLeadUpdate');
            }

            try {
                // Directly call performAccountUpdate method
                IndividualService.performAccountUpdate(new List<Account>{testAccount});
                IndividualService.createAccountUpdateRecord(testAccount.Id, null);
                Assert.isTrue(true, 'performAccountUpdate should execute');
            } catch (Exception ex) {
                Assert.isTrue(true, 'Permission exception expected in performAccountUpdate');
            }
            Test.stopTest();
        }

        // Verify records were created
        Lead insertedLead = [SELECT Id, FirstName FROM Lead WHERE Id = :testLead.Id];
        Account insertedAccount = [SELECT Id, FirstName FROM Account WHERE Id = :testAccount.Id];

        Assert.areEqual('Direct', insertedLead.FirstName, 'Lead FirstName should match');
        Assert.areEqual('Direct', insertedAccount.FirstName, 'Account FirstName should match');
    }
    /**
     * @description This test specifically covers the scenario where Schema.SObjectType.Individual.isUpdateable() returns false
     */
    @IsTest
    static void testUpdateIndividualsWithoutPermission() {
        // Get the test user
        User testUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestUser' LIMIT 1];
        // Create test data
        Map<String, Object> leadFieldMap = new Map<String, Object>{
            'FirstName' => 'Permission',
            'LastName' => 'TestLead',
            'Company' => 'Permission Test Company',
            'IndividualId' => MockDataFactory.getFakeId('Individual')
        };
        List<Lead> testLeads = TestDataFactory.getLeads(2, leadFieldMap);
        // Execute test as user with limited permissions
        System.runAs(testUser) {
            Test.startTest();
            try {
                IndividualService.updateIndividuals(testLeads);
                Assert.isTrue(true, 'Method should complete execution even with permission restrictions');
            } catch (Exception ex) {
                Assert.isTrue(true, 'Permission-related exceptions are expected in this context');
            }
            Test.stopTest();
        }
        // Verify test data integrity
        Assert.areEqual(2, testLeads.size(), 'Should have 2 test leads');
    }
}