/**
 * @description Controller that prepares contract list view data for Lightning components.
 *              Provides entry points to retrieve Activated Contracts for:
 *              - Certified Care (CC) trainers across multiple Practice Accounts
 *              - CPT trainers for a single Trainer Account
 *
 *              Access controls:
 *              - Uses Security.stripInaccessible(READABLE) to enforce FLS on queried fields
 *              - Uses explicit SOQL execution modes (WITH USER_MODE / WITH SYSTEM_MODE) where needed
 *
 *              Returned data is wrapped in lightweight Apex classes (ListViewWrapper, ContractWrapper)
 *              to facilitate serialization for Aura/LWC clients.
 *
 * @group Contracts
 * Developer: Shashank Nigam
 * Date: 8/1/2026
 * Version      Modified Date       Modified By             Brief Note
 * v1.0.0       8th JAN 2026        Shashank Nigam          Initial (NGOMCT-1353)
 * v1.0.1       23rd Feb 2026       Ankur Chauhan           NGOMCT-2305(Added logic to retrieve indirect contracts from MLC)
 * 
 * Note: CPT/CC users do not have access to the indirect contracts which are not owned by them, to access those records this class is marked as without sharing
 */
public without sharing class ContractListViewController {
    private static List<Contract> contractList;
    private static Map<String,String> contractVsDocumentMap;
    
    /**
     * @description Loads trainer-centric context and returns contract data based on the trainer type.
     *              - Resolves the Trainer Account from the provided Contact Id
     *              - Collects associated Practice Account Ids when trainer is a CC
     *              - Dispatches to CC or CPT contract retrieval based on Trainer_Type__c
     *
     * @param contactId The Contact Id of the person record related to the Trainer Account (required, cannot be blank).
     * @return ListViewWrapper containing trainer id, practice account ids (comma-separated),
     *         trainer type, and a list of ContractWrapper records.
     * @throws AuraHandledException when contactId is blank or any unexpected error occurs.
     */
    @AuraEnabled(cacheable = true)
    public static ListViewWrapper loadData(String contactId){
        try {
            if(String.isBlank(contactId)){
            	throw new AuraHandledException('Contact Id is required');
        	}
            ListViewWrapper wrapper = new ListViewWrapper();
            Account trainerAccount = [SELECT Id,Trainer_Type__c,PersonContactId FROM Account WHERE PersonContactId = :contactId WITH SYSTEM_MODE]; // Get Trainer Record
            List<String> practiceAccountIdList = new List<String>();
            for(AccountContactRelation  acr: [Select AccountId from AccountContactRelation where ContactId = :contactId AND Roles =:ConstantsUtil.ACR_ROLE_TRAINER AND IsActive = true  WITH SYSTEM_MODE]){
                practiceAccountIdList.add(acr.AccountId);
            }
            wrapper.trainerId = trainerAccount.Id;
            wrapper.practiceAccountIds = String.join(practiceAccountIdList, ',');
            wrapper.trainerType = trainerAccount.Trainer_Type__c;
            wrapper.contracts = trainerAccount.Trainer_Type__c == System.Label.Trainer_Type_CC ? getCCContracts(String.join(practiceAccountIdList, ',')) : getCPTContracts(trainerAccount.Id);
            return wrapper;
        } catch (Exception e) {
            throw new AuraHandledException( 'loadData' + e.getMessage() + e.getLineNumber());  
        }
    }

    /**
     * @description Returns ContractWrapper list for CC trainers by querying Activated Contracts
     *              for the provided comma-separated Practice Account Ids.
     *
     *              Field-level security is enforced via Security.stripInaccessible(READABLE).
     *
     * @param practiceIds Comma-separated list of Practice Account Ids.
     * @return List of ContractWrapper representing activated contracts tied to the provided accounts.
     * @throws AuraHandledException when an unexpected error occurs during retrieval.
     */
    @AuraEnabled
    public static List<ContractWrapper> getCCContracts(String practiceIds){
        try {
            List<String> contractIdList = new List<String>();
            for(Multi_Location_Contract__c mlc: [SELECT Id, Contract__c FROM Multi_Location_Contract__c WHERE Related_Location__c IN : practiceIds.split(',') AND Contract_Status__c = :ConstantsUtil.CONTRACT_STATUS_ACTIVATED AND Contract_Expiration_Date__c >= TODAY WITH SYSTEM_MODE]){
                contractIdList.add(mlc.Contract__c);
            }
            SObjectAccessDecision decision = Security.stripInaccessible(
	                                   AccessType.READABLE,
                                       [
                                        SELECT Id,Name,Account.Name,Status,ContractNumber,StartDate,EndDate,
                                        Account_Contract_Type__c,CompanySignedDate,CustomerSignedDate
                                        FROM Contract
                                        WHERE (AccountId IN : practiceIds.split(',') OR Id IN : contractIdList)
                                        AND Status = :ConstantsUtil.CONTRACT_STATUS_ACTIVATED
                                        WITH SYSTEM_MODE
                                        ORDER BY Account.Name DESC , EndDate DESC
                                       ]);
            contractList = decision.getRecords();
            return getContracts();
        } catch (Exception e) {
            throw new AuraHandledException( 'getCCContracts' + e.getMessage() + e.getLineNumber());
        }
    }

    /**
     * @description Returns ContractWrapper list for CPT trainers by querying Activated Contracts
     *              for the provided Trainer Account Id.
     *
     *              Field-level security is enforced via Security.stripInaccessible(READABLE).
     *
     * @param trainerId Trainer Account Id.
     * @return List of ContractWrapper representing activated contracts tied to the trainer account.
     * @throws AuraHandledException when an unexpected error occurs during retrieval.
     */
    @AuraEnabled
    public static List<ContractWrapper> getCPTContracts(String trainerId){
        try {
            SObjectAccessDecision decision = Security.stripInaccessible(
	                                   AccessType.READABLE,
                                       [
                                        SELECT Id,Name,Account.Name,Status,ContractNumber,StartDate,EndDate,
                                        Account_Contract_Type__c,CompanySignedDate,CustomerSignedDate
                                        FROM Contract
                                        WHERE AccountId = : trainerId 
                                        AND Status = :ConstantsUtil.CONTRACT_STATUS_ACTIVATED
                                        WITH USER_MODE 
                                       ]);
            contractList = decision.getRecords();
            return getContracts();
        } catch (Exception e) {
            throw new AuraHandledException('getCPTContracts' + e.getMessage() + e.getLineNumber());
        }
    }

    /**
     * @description Internal helper that transforms queried Contract sObjects into ContractWrapper DTOs.
     *              Also enriches each wrapper with the latest ContentVersion id for download links.
     *
     *              Prerequisites:
     *              - contractList must be populated by a prior call to getCCContracts/getCPTContracts.
     *
     * @return List of ContractWrapper built from the current contractList.
     */
    @TestVisible
    private static List<ContractWrapper> getContracts(){
        getDocumentVersions();
        List<ContractWrapper> contracts = new List<ContractWrapper>();
        ContractWrapper wrapper;
        for(Contract c : contractList){
            wrapper = new ContractWrapper();
            wrapper.contractId = c.Id;
            wrapper.status = c.Status;
            wrapper.startDate = String.valueOf(c.StartDate);
            wrapper.endDate = String.valueOf(c.EndDate);
            wrapper.accountName = c.Account.Name;
            wrapper.type = c.Account_Contract_Type__c;
            wrapper.companySignedDate = String.valueOf(c.CompanySignedDate);
            wrapper.customerSignedDate = String.valueOf(c.CustomerSignedDate);
            wrapper.contractURL = contractVsDocumentMap.get(c.Id);
            if(c.EndDate != null && c.EndDate < System.today()){
                wrapper.statusIcon = ConstantsUtil.CONTRACT_LIST_ICON;
                wrapper.statusClass = ConstantsUtil.CONTRACT_LIST_ERROR_CLASS;
            }else if(c.EndDate != null && c.EndDate >= System.Today() && c.EndDate <= System.Today().addDays(60)){
                wrapper.statusIcon = ConstantsUtil.CONTRACT_LIST_ICON;
                wrapper.statusClass = ConstantsUtil.CONTRACT_LIST_WARNING_CLASS;
            }
            contracts.add(wrapper);
        }
        // Flush class variables to avoid memory leaks.
        if(contractList!=null) 
        {
            contractList.clear();
        }
        if(contractVsDocumentMap!=null){ 
            contractVsDocumentMap.clear();
        }
        return contracts;
    } 

    /**
     * @description Internal helper that builds a map of Contract Id to latest ContentVersion Id
     *              by traversing ContentDocumentLinks related to the contracts in scope.
     *
     *              Side effects:
     *              - Populates contractVsDocumentMap used to set ContractWrapper.contractURL.
     */
    @TestVisible
    private static void getDocumentVersions(){
        List<Id> contractIds = new List<Id>();
        for(Contract c : contractList){
            contractIds.add(c.Id);
        }
        if(contractIds.isEmpty()){
            return;
        }
        contractVsDocumentMap = new Map<String,String>();
        for (ContentDocumentLink cdl : [SELECT ContentDocumentId,
                   ContentDocument.Title,
                   ContentDocument.LatestPublishedVersionId,
                   LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId In :contractIds WITH SYSTEM_MODE]) {
                contractVsDocumentMap.put(cdl.LinkedEntityId,cdl.ContentDocument.LatestPublishedVersionId);
        }
    }


/**
 * @description Wrapper returned to the client when loading the list view.
 *              Contains trainer context and a list of contracts to render.
 */
public class ListViewWrapper{
    /** Trainer Account Id resolved from the provided Contact Id. */
    @AuraEnabled public string trainerId;
    /** Comma-separated list of Practice Account Ids (for CC trainers). */
    @AuraEnabled public string practiceAccountIds;
    /** Trainer type value used to choose CC vs CPT logic. */
    @AuraEnabled public string trainerType;
    /** Contracts ready for UI consumption. */
    @AuraEnabled public List<ContractWrapper> contracts;
}

/**
 * @description Data Transfer Object (DTO) representing a Contract record for the UI.
 *              Dates are serialized as strings for consistent client-side formatting.
 */
public class ContractWrapper{
    /** Contract Id. */
    @AuraEnabled public string contractId;
    /** Contract Account name. */
    @AuraEnabled public string accountName;
    /** Contract status (e.g., Activated). */
    @AuraEnabled public string status;
    /** Contract start date (string). */
    @AuraEnabled public string startDate;
    /** Contract end date (string). */
    @AuraEnabled public string endDate;
    /** Account_Contract_Type__c value. */
    @AuraEnabled public string type;
    /** CompanySignedDate (string). */
    @AuraEnabled public string companySignedDate;
    /** CustomerSignedDate (string). */
    @AuraEnabled public string customerSignedDate;
    /** LatestPublishedVersionId used for download URL. */
    @AuraEnabled public string contractURL;
    /**  Status Icon [Setting it as utility:warning if condition satifies else blank] */
    @AuraEnabled public string statusIcon = '';
    /** Status Class to setup foreground color of icon to distinguish between error and warning else blank*/
    @AuraEnabled public string statusClass = '';
}

}