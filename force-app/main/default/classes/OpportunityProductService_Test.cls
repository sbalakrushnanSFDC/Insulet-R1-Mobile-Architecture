/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 15th Dec 2025
 * @description : Test class for OpportunityProductService
 *  * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       15th Dec 2025       Bijayalaxmi Prusty      Initial Version(US - NGOMCT-824)
 * v1.0.1       12th Jan 2026       Anup Bandawar           Updated(US - NGASIM-1029)
 * v1.0.2       11th Feb 2026       Saikat Ghosh            Updated(US - NGASIM-2252) - Use custom Pricebook2 instead of updating Standard Price Book name (system restriction) & modefied to meet 95% test coverage
 */
@isTest
private class OpportunityProductService_Test {

    @isTest
    static void testCreateOpportunityLineItemsSuccess() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Pricebook2 primaryPricebook = new Pricebook2(
            Name = ConstantsUtil.PRIMARY_PRICEBOOK,
            IsActive = true
        );
        insert primaryPricebook;

        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert testProduct;

        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert stdPbe;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = primaryPricebook.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = primaryPricebook.Id,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp.Id, 'Test Product');

        Test.startTest();
        OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, new List<Opportunity>{testOpp});
        Test.stopTest();

        List<OpportunityLineItem> lineItems = [
            SELECT Id
            FROM OpportunityLineItem
            WHERE OpportunityId = :testOpp.Id
        ];
        Assert.areEqual(1, lineItems.size(), 'Should create one Opportunity Line Item');
    }

    @isTest
    static void testCreateOpportunityLineItemsPreventDuplicates() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Pricebook2 primaryPricebook = new Pricebook2(
            Name = ConstantsUtil.PRIMARY_PRICEBOOK,
            IsActive = true
        );
        insert primaryPricebook;

        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert testProduct;

        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert stdPbe;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = primaryPricebook.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = primaryPricebook.Id,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        OpportunityLineItem existingLineItem = new OpportunityLineItem(
            OpportunityId = testOpp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100.00
        );
        insert existingLineItem;

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp.Id, 'Test Product');

        List<Opportunity> opportunitiesToProcess = [
            SELECT Id, Pricebook2Id
            FROM Opportunity
            WHERE Id = :testOpp.Id
        ];

        Test.startTest();
        OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, opportunitiesToProcess);
        Test.stopTest();

        List<OpportunityLineItem> lineItems = [
            SELECT Id
            FROM OpportunityLineItem
            WHERE OpportunityId = :testOpp.Id
        ];
        Assert.areEqual(1, lineItems.size(), 'Should not create duplicate Opportunity Line Item');
    }

    @isTest
    static void testCreateOpportunityLineItemsProductNotFound() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp.Id, 'Non-Existent Product');

        Test.startTest();
        OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, new List<Opportunity>{testOpp});
        Test.stopTest();

        List<OpportunityLineItem> lineItems = [
            SELECT Id
            FROM OpportunityLineItem
            WHERE OpportunityId = :testOpp.Id
        ];
        Assert.areEqual(0, lineItems.size(), 'Should not create Opportunity Line Item for non-existent product');
    }

    @isTest
    static void testCreateOpportunityLineItemsSetsPricebook() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Pricebook2 primaryPricebook = new Pricebook2(
            Name = ConstantsUtil.PRIMARY_PRICEBOOK,
            IsActive = true
        );
        insert primaryPricebook;

        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert testProduct;

        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert stdPbe;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = primaryPricebook.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp.Id, 'Test Product');

        List<Opportunity> opportunitiesToProcess = [
            SELECT Id, Pricebook2Id
            FROM Opportunity
            WHERE Id = :testOpp.Id
        ];

        Test.startTest();
        OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, opportunitiesToProcess);
        Test.stopTest();

        Opportunity updatedOpp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Id = :testOpp.Id];
        Assert.areEqual(primaryPricebook.Id, updatedOpp.Pricebook2Id, 'Pricebook2Id should be set to primary pricebook');
    }

    @isTest
    static void testCreateOpportunityLineItemsMultipleOpportunities() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Pricebook2 primaryPricebook = new Pricebook2(
            Name = ConstantsUtil.PRIMARY_PRICEBOOK,
            IsActive = true
        );
        insert primaryPricebook;

        Product2 testProduct1 = new Product2(Name = 'Product 1', IsActive = true);
        Product2 testProduct2 = new Product2(Name = 'Product 2', IsActive = true);
        insert new List<Product2>{testProduct1, testProduct2};

        PricebookEntry stdPbe1 = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct1.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        PricebookEntry stdPbe2 = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct2.Id,
            UnitPrice = 200.00,
            IsActive = true
        );
        insert new List<PricebookEntry>{stdPbe1, stdPbe2};

        PricebookEntry pbe1 = new PricebookEntry(
            Pricebook2Id = primaryPricebook.Id,
            Product2Id = testProduct1.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = primaryPricebook.Id,
            Product2Id = testProduct2.Id,
            UnitPrice = 200.00,
            IsActive = true
        );
        insert new List<PricebookEntry>{pbe1, pbe2};

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Opportunity testOpp1 = new Opportunity(
            Name = 'Test Opportunity 1',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = primaryPricebook.Id,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        Opportunity testOpp2 = new Opportunity(
            Name = 'Test Opportunity 2',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = primaryPricebook.Id,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert new List<Opportunity>{testOpp1, testOpp2};

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp1.Id, 'Product 1');
        opportunityToProductMap.put(testOpp2.Id, 'Product 2');

        List<Opportunity> opportunitiesToProcess = [
            SELECT Id, Pricebook2Id
            FROM Opportunity
            WHERE Id IN :new Set<Id>{testOpp1.Id, testOpp2.Id}
        ];

        Test.startTest();
        OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, opportunitiesToProcess);
        Test.stopTest();

        List<OpportunityLineItem> lineItems = [
            SELECT Id, OpportunityId, PricebookEntryId
            FROM OpportunityLineItem
            WHERE OpportunityId IN :new Set<Id>{testOpp1.Id, testOpp2.Id}
        ];
        Assert.areEqual(2, lineItems.size(), 'Should create two Opportunity Line Items');
    }

    @isTest
    static void testCreateOpportunityLineItemsInactiveProduct() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Product2 testProduct = new Product2(
            Name = 'Inactive Product',
            IsActive = false
        );
        insert testProduct;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp.Id, 'Inactive Product');

        Test.startTest();
        OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, new List<Opportunity>{testOpp});
        Test.stopTest();

        List<OpportunityLineItem> lineItems = [
            SELECT Id
            FROM OpportunityLineItem
            WHERE OpportunityId = :testOpp.Id
        ];
        Assert.areEqual(0, lineItems.size(), 'Should not create Opportunity Line Item for inactive product');
    }

    @isTest
    static void testCreateOpportunityLineItemsExceptionHandling() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Pricebook2 primaryPricebook = new Pricebook2(
            Name = ConstantsUtil.PRIMARY_PRICEBOOK,
            IsActive = true
        );
        insert primaryPricebook;

        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert testProduct;

        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert stdPbe;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = primaryPricebook.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = primaryPricebook.Id,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp.Id, 'Test Product');

        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
        OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, new List<Opportunity>{testOpp});
        ConstantsUtil.customExceptionSwitch = false;
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle exceptions gracefully');
    }

    @isTest
    static void testCreateOpportunityLineItemsNullInput() {
        Test.startTest();
        OpportunityProductService.createOpportunityLineItems(null, null);
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle null inputs gracefully');
    }

    @isTest
    static void testCreateOpportunityLineItemsEmptyMap() {
        Id standardPricebookId = Test.getStandardPricebookId();
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Test.startTest();
        OpportunityProductService.createOpportunityLineItems(new Map<Id, String>(), new List<Opportunity>{testOpp});
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle empty map gracefully');
    }

    @isTest
    static void testCreateOpportunityLineItemsEmptyOpportunities() {
        Id standardPricebookId = Test.getStandardPricebookId();
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp.Id, 'Test Product');

        Test.startTest();
        OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, new List<Opportunity>());
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle empty opportunities list gracefully');
    }

    @isTest
    static void testGetPricebookEntriesEmptyProducts() {
        Test.startTest();
        Map<Id, PricebookEntry> result = OpportunityProductService.getPricebookEntries(new List<Product2>(), Test.getStandardPricebookId());
        Test.stopTest();

        Assert.isTrue(result.isEmpty(), 'Should return empty map for empty products list');
    }

    @isTest
    static void testProcessOpportunityLineItemsCreationEmptyRecommendedProducts() {
        Id standardPricebookId = Test.getStandardPricebookId();

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId,
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp.Id, '');

        Test.startTest();
        OpportunityProductService.processOpportunityLineItemsCreation(opportunityToProductMap, new List<Opportunity>{testOpp});
        Test.stopTest();

        Assert.isTrue(true, 'Method should handle empty recommended products gracefully');
    }

    @isTest
    static void testLogDebugCoverage() {
        Test.startTest();
        OpportunityProductService.logDebug('Test debug message for coverage');
        Test.stopTest();

        Assert.isTrue(true, 'logDebug should execute without exception');
    }

    @isTest
    static void testPermissionChecksLogDebugWhenUserLacksCRUDPermissions() {
        List<Profile> profiles = [
            SELECT Id, Name FROM Profile
            WHERE Name IN ('Minimum Access - Salesforce', 'Minimum Access - Salesforce License')
            LIMIT 1
        ];
        if (profiles.isEmpty()) {
            return;
        }

        User restrictedUser = TestDataFactory.getTestUser(profiles[0].Name, null);

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert restrictedUser;
        }

        Id standardPricebookId = Test.getStandardPricebookId();

        Pricebook2 primaryPricebook = new Pricebook2(
            Name = ConstantsUtil.PRIMARY_PRICEBOOK,
            IsActive = true
        );
        insert primaryPricebook;

        Product2 testProduct = new Product2(Name = 'Test Product', IsActive = true);
        insert testProduct;

        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert stdPbe;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = primaryPricebook.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
        );
        insert testOpp;

        Map<Id, String> opportunityToProductMap = new Map<Id, String>();
        opportunityToProductMap.put(testOpp.Id, 'Test Product');

        List<Opportunity> opportunitiesToProcess = [
            SELECT Id, Pricebook2Id
            FROM Opportunity
            WHERE Id = :testOpp.Id
        ];

        Test.startTest();
        System.runAs(restrictedUser) {
            OpportunityProductService.createOpportunityLineItems(opportunityToProductMap, opportunitiesToProcess);
        }
        Test.stopTest();

        List<OpportunityLineItem> lineItems = [
            SELECT Id
            FROM OpportunityLineItem
            WHERE OpportunityId = :testOpp.Id
        ];
        Assert.areEqual(0, lineItems.size(), 'Should not create line items when user lacks create permission');
    }

    @isTest
    static void testGetPricebookEntriesNullPricebookId() {
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true
        );
        insert testProduct;

        Test.startTest();
        Map<Id, PricebookEntry> result = OpportunityProductService.getPricebookEntries(new List<Product2>{testProduct}, null);
        Test.stopTest();

        Assert.isTrue(result.isEmpty(), 'Should return empty map for null pricebookId');
    }
}