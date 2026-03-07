/**
 * @description Functional Test class for AssetProcessingHandler and AssetProcessingQueueable
 * @author Ayush Shrivastava
 * @created Date 11th Feb 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Feb 2026       Ayush Shrivastava      Initial Version(US - NGOMCT-484)
 * V2.0.0       24th Feb 2026       Ayush Shrivastava      NGOMCT-2634
 * =======================================================================
 */

@isTest
public class AssetProcessingQueueable_FunctionalTest {
 
     /**
     * @description setting up test data.
     */
    @TestSetup
    static void setupData(){
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            user salesIntegrationUser = TestDataFactory.getTestUser('Integration API Only', new Map<String, Object>{
                    'FirstName' => 'Sales',
                    'LastName' => 'TestIntegrationUser'
                });
                insert salesIntegrationUser;
                // Query required permission sets
                List<PermissionSet> permissionSets = [
                    SELECT Id, Name
                    FROM PermissionSet
                    WHERE Name IN ('ASPN_Integration_access')
                ];
                // Create permission set assignments
                List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
                for (PermissionSet ps : permissionSets) {
                    assignments.add(new PermissionSetAssignment(
                        AssigneeId = salesIntegrationUser.Id,
                        PermissionSetId = ps.Id
                    ));
                }
                insert assignments;
        }
        
        Account patient = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{'Territory_Alias__c'=>'Test'});
        insert patient;
        
         System.runAs(new User(Id = UserInfo.getUserId())) {
            
            Territory2Model model= new Territory2Model(Name = 'Test',DeveloperName = 'test');         
      		insert model;   
            Territory2Type territoryType  = [SELECT Id from Territory2Type LIMIT 1];
            
            Territory2 testTerritory = new Territory2(Name = 'Test',DeveloperName = 'Test',Territory2ModelId = model.Id,Territory2TypeId = territoryType.Id);
            insert testTerritory;
             
            ObjectTerritory2Association associatedTerritory = new ObjectTerritory2Association(ObjectId = patient.Id,Territory2Id = testTerritory.Id,AssociationCause = 'Territory2Manual');
            insert associatedTerritory;
        
        }
        
        Map<String, Object> opportunityFieldMap = new Map<String, Object>();
        opportunityFieldMap.put('AccountId',patient.Id);
        Opportunity opp = TestDataFactory.getOpportunity(opportunityFieldMap);
        insert opp;
        Id standardPricebookId = Test.getStandardPricebookId();
        List<Product2> testProduct = new List<Product2>();
        testProduct.add(new Product2(Name = ConstantsUtil.DASH_PRODUCT,IsActive = true));  
        testProduct.add(new Product2(Name = ConstantsUtil.DASH_CONTROLLER_PRODUCT,Product_NDC__c = ConstantsUtil.DASH_CONTROLLER_PRODUCT_NDC,IsActive = true));   
        insert testProduct;
        String controllerAssetRT = Schema.getGlobalDescribe()
                .get('Asset')
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('Controller')
                .getRecordTypeId();
        
        Asset patientAsset = new Asset(RecordTypeId = controllerAssetRT,AccountId = patient.Id, Sales_Credit_Date__c = Date.today(),Product2Id = testProduct[1].Id,Name = 'Test');
        insert patientAsset;
        
        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct[0].Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert stdPbe;
        
        OpportunityLineItem existingLineItem = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = stdPbe.Id,
            Quantity = 1,
            UnitPrice = 100.00
        );
        insert existingLineItem;
        
    }
    
    
  	/**
     * @description testing creating of asset records
     */
    @isTest
    static void testAssetCreation(){
        
        Account patient = [Select Id from Account];
      	
        User integrationUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestIntegrationUser' LIMIT 1];
       
        System.runAs(integrationUser) {
            
            Test.startTest();
            Opportunity op = [Select Id,StageName from Opportunity];
            op.Sub_Status__c = ConstantsUtil.OPPORTUNITY_SUB_STATUS_CHECK[0];
            update op;
            Test.stopTest();
        }
        
        Asset ast = [Select Id,Product2.Name,Sales_Credit_Territory__c ,RegistrationDate__c  from Asset where AccountId = :patient.Id and RegistrationDate__c!= null and Sales_Credit_Territory__c != null and Product2.Name = 'Dash Controller'];
        Assert.areNotEqual(null,ast.Id,'An Asset should exist with worrect values');
     
    } 
    
    
    /**
     * @description testing exception when product does not exist.
     */
    @isTest
    static void testException(){
        
        Product2 product = [Select Id from Product2 where Name = :ConstantsUtil.DASH_CONTROLLER_PRODUCT];
        delete product;
        Account patient = [Select Id from Account];
        
        User integrationUser = [SELECT Id FROM User WHERE FirstName = 'Sales' AND LastName = 'TestIntegrationUser' LIMIT 1];
       
        System.runAs(integrationUser) {
            
            Test.startTest();
            Opportunity op = [Select Id,StageName from Opportunity];
            op.Sub_Status__c = ConstantsUtil.OPPORTUNITY_SUB_STATUS_CHECK[0];
            update op;
            Test.stopTest();
        }
        
        List<Asset> ast = [Select Id from Asset where AccountId = :patient.Id];
        Assert.areEqual(1,ast.size(),'Only 1 asset should exist');
       
     
    } 
    
    

}