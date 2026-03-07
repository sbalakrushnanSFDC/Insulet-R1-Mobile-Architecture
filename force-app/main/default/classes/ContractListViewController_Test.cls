/**
 * @description Test Class for ContractListViewController
 * @group Contracts
 * Developer: Shashank Nigam
 * Date: 8/1/2026
 * Version      Modified Date       Modified By             Brief Note
 * v1.0.0       8th JAN 2026        Shashank Nigam          Initial (NGOMCT-1353)
 */
@IsTest(isParallel = true)
public class ContractListViewController_Test {
    
    /**
     * @description Setup Method to Prepare Data
     */
	@testSetup
    static void createData(){
        
        insert TestDataFactory.getAccountofTrainerRecordType(new Map<String,Object>());
        Account trainer = [Select id,PersonContactId from Account];
                
        Account practice = TestDataFactory.getAccountofPracticeRecordType();
        practice.Contract_Type__c = 'Level 1';
        insert practice;
        
        insert TestDataFactory.getAccountContactRelation(practice.Id,trainer.PersonContactId,ConstantsUtil.ACR_ROLE_TRAINER);
        String manual = ConstantsUtil.getConversionTypeManual();
        Contract cptContract;
        Contract ccContract;
        
        cptContract = TestDataFactory.getContract(trainer.Id);
        ccContract = TestDataFactory.getContract(practice.Id);
        ccContract.clinic_admin_email__c = 'a@a.com';
        ccContract.Clinic_Admin_Name__c = 'a';
        
        //insert cptContract;
        insert ccContract;
        
    }
    
    /**
     * @description Test Method to call loadData and prepare wrapper if called by CC / CPTCC trainer
     */
    @isTest
    static void testLoadDataCC(){
        Account trainer = [Select id,PersonContactId from Account where PersonContactId!=null limit 1];
        trainer.Trainer_Type__c = System.Label.Trainer_Type_CC;
        update trainer;
        Contract c = [Select id,Status from Contract limit 1];
        c.status = ConstantsUtil.CONTRACT_STATUS_ACTIVATED;
        c.EndDate = System.today().addDays(-1);
        update c;
        Test.startTest();
        ContractListViewController.ListViewWrapper	wrap = ContractListViewController.loadData(trainer.PersonContactId); 
        c.EndDate = System.today().addDays(1);
        update c;
        ContractListViewController.loadData(trainer.PersonContactId); 
        Test.stopTest();
        Assert.areEqual(wrap.trainerId,trainer.Id,'Data is Loaded on Initialization');
        Assert.areEqual(wrap.contracts.size(),1,'CC Contracts are present');
    }
    
    /**
     * @description Test Method to call loadData and prepare wrapper if called by CPT / CPTCC trainer
     */
    @isTest
    static void testLoadDataCPT(){
        Account trainer = [Select id,PersonContactId from Account where PersonContactId!=null limit 1];
        trainer.Trainer_Type__c = System.Label.Trainer_Type_CPT;
        trainer.Contract_Type__c = 'Level 1';
        update trainer;
        Contract c = [Select id,Status from Contract limit 1];
        c.status = ConstantsUtil.CONTRACT_STATUS_ACTIVATED;
        c.EndDate = System.today();
        update c;
        Test.startTest();
        ContractListViewController.ListViewWrapper	wrap = ContractListViewController.loadData(trainer.PersonContactId);   
        Test.stopTest();
        Assert.areEqual(wrap.trainerId,trainer.Id,'Data is Loaded on Initialization');
        Assert.areEqual(wrap.contracts.size(),0,'No CPT Contracts are present');
    }
	
    /**
     * @description Test Method to verify Runtime Exception Handling
     */
    @isTest
    static void testExceptions(){
        
        Account trainer = [Select id,PersonContactId from Account where PersonContactId!=null limit 1];
        trainer.Trainer_Type__c = System.Label.Trainer_Type_CC;
        update trainer;
        
		delete [Select id from AccountContactRelation limit 1];        
        Test.startTest();
        try{
            ContractListViewController.loadData(null);  
        }
        catch(Exception e){
            Assert.areNotEqual(e.getMessage(),null,'Exception is Thrown');
        }
        
        try{
            ContractListViewController.loadData(trainer.PersonContactId);  
        }
        catch(Exception e){
            Assert.areNotEqual(e.getMessage(),null,'Exception is Thrown');
        }
        
        try{
            ContractListViewController.getCCContracts(null);
        }
        catch(Exception e){
            Assert.areNotEqual(e.getMessage(),null,'Exception is Thrown');
        } 
        Test.stopTest();
    }
}