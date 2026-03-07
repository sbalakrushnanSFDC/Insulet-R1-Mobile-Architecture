/**
 * @description Async process, creates Asset for patient for Dash Controller Product.
 * note: This needs to run in without sharing because integration user might not have view all
 * access on Asset
 * @author Ayush Shrivastava
 * @created Date 11th Feb 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Feb 2026       Ayush Shrivastava      Initial Version(US - NGOMCT-484)
 * =======================================================================
 */

public without sharing class AssetProcessingQueueable implements Queueable, Finalizer {
    private Set<Id> opportunityIds;

    /**
     * @description Constructor.
     * @param opportunityIds The list of updated Opportunity ids
     */
    public AssetProcessingQueueable(Set<Id> opportunityIds) {
        this.opportunityIds = opportunityIds;
    }
    /**
     * @description default Constructor.
     */
    public AssetProcessingQueueable(){
        this.opportunityIds = new Set<Id>();
    }
    
    /**
     * @description finalizer execute method.
     * @param context finalizere context
     */
    public void execute(FinalizerContext context) {
        
        Logger.debug('Finalizer' + context.getResult());
    
    }
    
    
	/**
     * @description main execute method.
     * @param context queueable context
     */
    public void execute(QueueableContext context) {
        try {
            
           Finalizer finalizer = new AssetProcessingQueueable();
           System.attachFinalizer(finalizer);
            
           Product2 dashControllerProduct = [
                SELECT Id, Name
                FROM Product2
                WHERE Product_NDC__c = :ConstantsUtil.DASH_CONTROLLER_PRODUCT_NDC
                LIMIT 1
            ];

            if (dashControllerProduct == null) {
                return;
            }

            Set<Id> accountIds = getAccountsToProcess(opportunityIds);

            List<Asset> assetsToInsert = getAssetsToInsert(accountIds,dashControllerProduct); 
           	
            if (!assetsToInsert.isEmpty()) {
                insert assetsToInsert;
            }
            
        }catch (Exception e) {
            Logger.error('Error in creating asset record ' + e.getMessage(), e);
            Logger.saveLog();
        }
    }
    
    /**
     * @description Fetch accounts to create asset fors
     * @param opportunityIds The list of updated Opportunity ids
     * @return set of accountids
     */
    private Set<Id> getAccountsToProcess(Set<Id> opportunityIds){
        	
        	Set<Id> accountIds = new Set<Id>();

            for (OpportunityLineItem oppLnItem : [
                SELECT Id, Opportunity.AccountId
                FROM OpportunityLineItem
                WHERE Product2.Name = :ConstantsUtil.DASH_PRODUCT
                AND OpportunityId IN :opportunityIds
            ]) {
                accountIds.add(oppLnItem.Opportunity.AccountId);
            }
        	
        	return accountIds;
    }
    
    /**
     * @description Create asset records to insert
     * @param accountIds Account ids for which asset needs to be created
     * @param dashControllerProduct the product against which asset needs to be created
     * @return list of asset records to be inserted
     */
    private List<Asset> getAssetsToInsert(Set<Id> accountIds, Product2 dashControllerProduct ){
        	
         	List<Asset> assetsToInsert = new List<Asset>();
        	String controllerAssetRT = ConstantsUtil.ASSET_CONTROLLER_RT;
        	
        	for (Asset acc : [
                SELECT Id, AccountId, RegistrationDate__c
                FROM Asset
                WHERE Product2.Name = :ConstantsUtil.DASH_CONTROLLER_PRODUCT
                AND AccountId IN :accountIds
            ]) {
                if (acc.RegistrationDate__c != null) {
                    accountIds.remove(acc.AccountId);
                }
            }

            for (Id accountId : accountIds) {
                assetsToInsert.add(
                    new Asset(
                        Sales_Credit_Date__c = Date.today(),
                        RegistrationDate__c = Date.today(),
                        Product2Id = dashControllerProduct.Id,
                        Name = dashControllerProduct.Name,
                        RecordTypeId = controllerAssetRT,
                        AccountId = accountId
                    )
                );
            }
        	
        	return assetsToInsert;
    }

}