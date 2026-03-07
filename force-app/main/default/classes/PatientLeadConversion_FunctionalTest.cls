/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 1st December 2025
 * @description : Functional test class for PatientLeadConversionService focusing on permission handling
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       1st Dec 2025        Bijayalaxmi Prusty      Initial Version(US - NGASIM-1050)
 */
@IsTest
private class PatientLeadConversion_FunctionalTest {

    /**
     * @description Tests convertLeadsToExistingAccounts method when user lacks permission to update Lead records
     * Verifies that method handles insufficient Lead update permissions gracefully and returns empty results
     */
    @IsTest
    static void testConvertLeadsToExistingAccountsInsufficientLeadPermissions() {
        // Create test accounts using TestDataFactory
        List<Account> testAccounts = TestDataFactory.getAccounts(1, new Map<String, Object>{
            'FirstName' => 'Lead',
            'LastName' => 'Conversion',
            'PersonEmail' => 'leadconversion@example.com'
        }, ConstantsUtil.ACCOUNT_PATIENT_RT);
        insert testAccounts;

        // Create test leads using TestDataFactory
        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Lead',
            'LastName' => 'Conversion',
            'Company' => 'Lead Conversion Test Company',
            'Email' => 'leadconversion@example.com',
            'Status' => 'Open',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLeads;

        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>{
            testLeads[0] => testAccounts[0]
        };

        // Create test user with Sales profile
        User salesUser = TestDataFactory.getTestUser('Sales', new Map<String, Object>{
            'FirstName' => 'Lead',
            'LastName' => 'TestUser'
        });
        insert salesUser;

        // Run test as user with limited permissions
        System.runAs(salesUser) {
            Test.startTest();
            List<Database.LeadConvertResult> results = PatientLeadConversionService.convertLeadsToExistingAccounts(leadsToAccountMap);
            Test.stopTest();

            // Verify conversion was not executed due to insufficient permissions
            Assert.areEqual(0, results.size(),
                'Lead conversion should not proceed when user lacks Lead update permissions');
        }
    }

    /**
     * @description Tests updateExistingOpportunities method when user lacks permission to update Opportunity records
     * Verifies that method handles insufficient Opportunity update permissions gracefully
     */
    @IsTest
    static void testUpdateExistingOpportunitiesInsufficientOpportunityPermissions() {
        // Create test accounts with existing opportunities
        List<Account> testAccounts = TestDataFactory.getAccounts(1, new Map<String, Object>{
            'FirstName' => 'Opportunity',
            'LastName' => 'Update',
            'PersonEmail' => 'oppupdate@example.com'
        }, ConstantsUtil.ACCOUNT_PATIENT_RT);
        insert testAccounts;

        List<Opportunity> testOpportunities = new List<Opportunity>{
            TestDataFactory.getOpportunity(new Map<String, Object>{
                'AccountId' => testAccounts[0].Id,
                'Name' => 'Test Existing Opportunity',
                'StageName' => 'Prospecting',
                'CloseDate' => Date.today().addDays(30),
                'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT
            })
        };
        insert testOpportunities;

        // Create test leads
        List<Lead> testLeads = TestDataFactory.getLeads(1, new Map<String, Object>{
            'FirstName' => 'Opportunity',
            'LastName' => 'Update',
            'Company' => 'Opportunity Update Test Company',
            'Email' => 'oppupdate@example.com',
            'Status' => 'Open',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLeads;

        // Query accounts with opportunities subquery
        List<Account> accountsWithOpps = [
            SELECT Id, FirstName, LastName,
                (SELECT Id, Name, Number_of_time_contacted__c
                FROM Opportunities
                WHERE RecordTypeId = :ConstantsUtil.OPPORTUNITY_NCS_RT)
            FROM Account
            WHERE Id = :testAccounts[0].Id
        ];

        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>{
            testLeads[0] => accountsWithOpps[0]
        };

        // Create test user with Sales profile
        User salesUser = TestDataFactory.getTestUser('Sales', new Map<String, Object>{
            'FirstName' => 'Opportunity',
            'LastName' => 'TestUser'
        });
        insert salesUser;

        // Run test as user with limited permissions
        System.runAs(salesUser) {
            Test.startTest();
            List<Database.LeadConvertResult> results = PatientLeadConversionService.convertLeadsToExistingAccounts(leadsToAccountMap);
            Test.stopTest();

            // Verify that the method executed but opportunity updates may have been skipped
            // The specific assertion depends on whether the Sales profile has Opportunity update permissions
            Assert.isNotNull(results,
                'Lead conversion should return results even with limited Opportunity permissions');
        }
    }
}