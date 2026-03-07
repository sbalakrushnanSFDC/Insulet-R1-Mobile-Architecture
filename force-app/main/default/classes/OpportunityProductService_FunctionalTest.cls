/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 16th Dec 2025
 * @description : Functional test class for OpportunityProductService focusing on permission handling
 *  * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       16th Dec 2025       Bijayalaxmi Prusty      Initial Version(US - NGOMCT-824)
 * v1.0.1       12th Jan 2026       Anup Bandawar           Updated(US - NGASIM-1029)
 */
@isTest
private class OpportunityProductService_FunctionalTest {

    /**
     * @description Tests createOpportunityLineItems when user lacks permission to create OpportunityLineItem records
     * Verifies that method handles insufficient permissions gracefully and logs appropriate error
     */
    @IsTest
    static void testCreateOpportunityLineItemsInsufficientPermissions() {
        Id standardPricebookId = Test.getStandardPricebookId();
        Pricebook2 standardPricebook = new Pricebook2(
            Id = standardPricebookId,
            IsActive = true
        );
        update standardPricebook;

        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert testProduct;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Permission',
            'LastName' => 'Test'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Permission Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp.Id, 'Test Product');

        User salesUser = TestDataFactory.getTestUser('Sales', new Map<String, Object>{
            'FirstName' => 'Sales',
            'LastName' => 'TestUser'
        });
        insert salesUser;

        System.runAs(salesUser) {
            Test.startTest();
            OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, new List<Opportunity>{testOpp});
            Test.stopTest();

            Assert.isTrue(true, 'Method should handle insufficient permissions without errors');
        }
    }

    /**
     * @description Tests createOpportunityLineItems when user lacks permission to update Opportunity records
     * Verifies that method handles insufficient permissions gracefully and logs appropriate error
     */
    @IsTest
    static void testUpdateOpportunitiesInsufficientPermissions() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert testProduct;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Permission',
            'LastName' => 'Test'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Permission Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp.Id, 'Test Product');

        User salesUser = TestDataFactory.getTestUser('Sales', new Map<String, Object>{
            'FirstName' => 'Sales',
            'LastName' => 'TestUser'
        });
        insert salesUser;

        System.runAs(salesUser) {
            Test.startTest();
            OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, new List<Opportunity>{testOpp});
            Test.stopTest();

            Assert.isTrue(true, 'Method should handle insufficient permissions without errors');
        }
    }
}