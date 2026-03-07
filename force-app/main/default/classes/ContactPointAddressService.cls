/**
 * @description Service class for ContactPointAddress business logic.
 *              Handles complex primary address processing logic for after insert/update events.
 * Created Date : Dec 2025
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Feb 2026       Charchit N.           Initial Version (NGASIM-2207)
 * V2.0.0       20th Feb 2026       Ayush Shrivastava     Updated the logic to handle address changes (NGASIM-2575)
 */
public with sharing class ContactPointAddressService {

    /**
     * @description Handles primary ContactPointAddress logic from flow.
     *              Sets IsPrimary to true for new records, sets others to false, and updates Account Billing Address fields
     * @param addressRecords List of ContactPointAddress records
     * @param newRecordsMap Map of new records
     * @param oldRecordsMap Map of old records
     */
    public static void handlePrimaryContactPointAddress(List<ContactPointAddress> addressRecords, Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        ProcessingContext context = identifyAddressesToProcess(addressRecords, oldRecordsMap);
        if (context.parentAccountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> parentAccountsMap = queryParentAccounts(context.parentAccountIds);
        Map<Id, List<ContactPointAddress>> parentIdToOtherAddressesMap = queryOtherPrimaryAddresses(context.parentAccountIds, context.currentAddressIds);

        ProcessingDataContext dataContext = new ProcessingDataContext();
        dataContext.addressesToProcessMap = context.addressesToProcessMap;
        dataContext.parentAccountsMap = parentAccountsMap;
        dataContext.parentIdToOtherAddressesMap = parentIdToOtherAddressesMap;
        dataContext.oldRecordsMap = oldRecordsMap;
        dataContext.addressesToUpdate = new List<ContactPointAddress>();
        dataContext.accountsToUpdate = new List<Account>();

        processAddressRecords(dataContext);

        performDMLUpdates(dataContext.addressesToUpdate, dataContext.accountsToUpdate);
    }

    /**
     * @description Inner class to hold processing context
     */
    private class ProcessingContext {
        public Set<Id> parentAccountIds;
        public Set<Id> currentAddressIds;
        public Map<Id, ContactPointAddress> addressesToProcessMap;

        /**
         * @description Constructor that initializes empty collections for processing context
         */
        public ProcessingContext() {
            this.parentAccountIds = new Set<Id>();
            this.currentAddressIds = new Set<Id>();
            this.addressesToProcessMap = new Map<Id, ContactPointAddress>();
        }
    }

    /**
     * @description Inner class to hold processing data context for address records processing
     */
    private class ProcessingDataContext {
        public Map<Id, ContactPointAddress> addressesToProcessMap;
        public Map<Id, Account> parentAccountsMap;
        public Map<Id, List<ContactPointAddress>> parentIdToOtherAddressesMap;
        public Map<Id, SObject> oldRecordsMap;
        public List<ContactPointAddress> addressesToUpdate;
        public List<Account> accountsToUpdate;
    }

    /**
     * @description Identifies addresses that need processing and collects parent account IDs
     * @param addressRecords List of ContactPointAddress records
     * @param oldRecordsMap Map of old records
     * @return ProcessingContext with addresses to process and account IDs
     */
    private static ProcessingContext identifyAddressesToProcess(List<ContactPointAddress> addressRecords, Map<Id, SObject> oldRecordsMap) {
        ProcessingContext context = new ProcessingContext();

        for (ContactPointAddress address : addressRecords) {
            if (address.ParentId == null) {
                continue;
            }

            if (shouldProcessAddress(address, oldRecordsMap)) {
                context.parentAccountIds.add(address.ParentId);
                context.currentAddressIds.add(address.Id);
                context.addressesToProcessMap.put(address.Id, address);
            }
        }

        return context;
    }

    /**
     * @description Determines if an address should be processed
     * @param address ContactPointAddress record
     * @param oldRecordsMap Map of old records
     * @return Boolean indicating if address should be processed
     */
    private static Boolean shouldProcessAddress(ContactPointAddress address, Map<Id, SObject> oldRecordsMap) {
        Boolean isNew = (oldRecordsMap == null || !oldRecordsMap.containsKey(address.Id));

        if (isNew && address.IsPrimary == true) {
            return true;
        }

        if (!isNew && oldRecordsMap.containsKey(address.Id)) {
            ContactPointAddress oldAddress = (ContactPointAddress)oldRecordsMap.get(address.Id);
            Boolean isPrimaryChanged = (address.IsPrimary != oldAddress.IsPrimary);
            Boolean wasPrimary = (oldAddress.IsPrimary == true);

            if (isPrimaryChanged && address.IsPrimary == true && !wasPrimary) {
                return true;
            }else if(address.IsPrimary == true && IsAddressChanged(address,oldAddress)){
                return true;
            }
        }

        return false;
    }

    /**
     * @description Queries parent accounts in batch
     * @param parentAccountIds Set of parent account IDs
     * @return Map of Account ID to Account record
     */
    private static Map<Id, Account> queryParentAccounts(Set<Id> parentAccountIds) {
        Map<Id, Account> parentAccountsMap = new Map<Id, Account>();
        for (Account acc : [
            SELECT Id, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
            FROM Account
            WHERE Id IN :parentAccountIds
            WITH USER_MODE
        ]) {
            parentAccountsMap.put(acc.Id, acc);
        }
        return parentAccountsMap;
    }

    /**
     * @description Queries other primary ContactPointAddress records for parent accounts
     * @param parentAccountIds Set of parent account IDs
     * @param currentAddressIds Set of current address IDs to exclude
     * @return Map of Parent ID to List of other primary ContactPointAddress records
     */
    private static Map<Id, List<ContactPointAddress>> queryOtherPrimaryAddresses(Set<Id> parentAccountIds, Set<Id> currentAddressIds) {
        Map<Id, List<ContactPointAddress>> parentIdToOtherAddressesMap = new Map<Id, List<ContactPointAddress>>();
        for (ContactPointAddress otherAddress : [
            SELECT Id, IsPrimary, ParentId
            FROM ContactPointAddress
            WHERE ParentId IN :parentAccountIds
            AND Id NOT IN :currentAddressIds
            AND IsPrimary = true
            WITH USER_MODE
        ]) {
            if (!parentIdToOtherAddressesMap.containsKey(otherAddress.ParentId)) {
                parentIdToOtherAddressesMap.put(otherAddress.ParentId, new List<ContactPointAddress>());
            }
            parentIdToOtherAddressesMap.get(otherAddress.ParentId).add(otherAddress);
        }
        return parentIdToOtherAddressesMap;
    }

    /**
     * @description Processes address records and updates addresses and accounts
     * @param dataContext ProcessingDataContext containing all necessary data for processing
     */
    private static void processAddressRecords(ProcessingDataContext dataContext) {
        for (ContactPointAddress address : dataContext.addressesToProcessMap.values()) {
            if (address.ParentId == null || !dataContext.parentAccountsMap.containsKey(address.ParentId)) {
                continue;
            }

            Account parentAccount = dataContext.parentAccountsMap.get(address.ParentId);
            Boolean isNew = (dataContext.oldRecordsMap == null || !dataContext.oldRecordsMap.containsKey(address.Id));
            Boolean wasPrimary = getWasPrimary(address, dataContext.oldRecordsMap);
			ContactPointAddress oldAddress = (ContactPointAddress)dataContext?.oldRecordsMap?.get(address.Id);
            if (isPrimaryOnCreateOrUpdate(address, isNew, wasPrimary)) {
                updateOtherAddressesToNonPrimary(address.ParentId, dataContext.parentIdToOtherAddressesMap, dataContext.addressesToUpdate);
                updateAccountBillingAddress(address, parentAccount, dataContext.accountsToUpdate);
                
            }else if(oldAddress != null && IsAddressChanged(address,oldAddress) && address.IsPrimary == true && address.ParentId != null){
                updateAccountBillingAddress(address, parentAccount, dataContext.accountsToUpdate);
            }
        }
    }
    
    
    /**
     * @description check whether address values are changed
     * @param currentAddress current address record
     * @param oldAddress old address record
     * @return Boolean indicating if address is changed or not
     */
     private static Boolean IsAddressChanged(ContactPointAddress currentAddress,ContactPointAddress oldAddress){
         
         if(currentAddress.Street != oldAddress.Street || currentAddress.City != oldAddress.City || currentAddress.State != oldAddress.State || 
           	currentAddress.PostalCode != oldAddress.PostalCode || currentAddress.Country != oldAddress.Country || currentAddress.StateCode != oldAddress.StateCode || 
           	currentAddress.CountryCode != oldAddress.CountryCode){
                return true;
            }
         return false;
        
     }

    /**
     * @description Gets whether the address was primary before
     * @param address ContactPointAddress record
     * @param oldRecordsMap Map of old records
     * @return Boolean indicating if address was primary
     */
    private static Boolean getWasPrimary(ContactPointAddress address, Map<Id, SObject> oldRecordsMap) {
        if (oldRecordsMap != null && oldRecordsMap.containsKey(address.Id)) {
            ContactPointAddress oldAddress = (ContactPointAddress)oldRecordsMap.get(address.Id);
            return (oldAddress.IsPrimary == true);
        }
        return false;
    }

    /**
     * @description Determines if address is primary on create or update
     * @param address ContactPointAddress record
     * @param isNew Boolean indicating if record is new
     * @param wasPrimary Boolean indicating if record was primary before
     * @return Boolean indicating if address is primary on create or update
     */
    private static Boolean isPrimaryOnCreateOrUpdate(ContactPointAddress address, Boolean isNew, Boolean wasPrimary) {
        return (address.IsPrimary == true && (isNew || !wasPrimary) && address.ParentId != null);
    }

    /**
     * @description Updates other addresses to non-primary
     * @param parentId Parent account ID
     * @param parentIdToOtherAddressesMap Map of other addresses by parent
     * @param addressesToUpdate List to collect addresses to update
     */
    private static void updateOtherAddressesToNonPrimary(
        Id parentId,
        Map<Id, List<ContactPointAddress>> parentIdToOtherAddressesMap,
        List<ContactPointAddress> addressesToUpdate
    ) {
        if (parentIdToOtherAddressesMap.containsKey(parentId)) {
            for (ContactPointAddress otherAddress : parentIdToOtherAddressesMap.get(parentId)) {
                otherAddress.IsPrimary = false;
                addressesToUpdate.add(otherAddress);
            }
        }
    }

    /**
     * @description Updates Account Billing Address fields if different
     * @param address ContactPointAddress record
     * @param parentAccount Account record to update
     * @param accountsToUpdate List to collect accounts to update
     */
    private static void updateAccountBillingAddress(ContactPointAddress address, Account parentAccount, List<Account> accountsToUpdate) {
        Boolean needsUpdate = false;

        if (parentAccount.BillingStreet != address.Street) {
            parentAccount.BillingStreet = address.Street;
            needsUpdate = true;
        }
        if (parentAccount.BillingCity != address.City) {
            parentAccount.BillingCity = address.City;
            needsUpdate = true;
        }
        if (parentAccount.BillingState != address.State) {
            parentAccount.BillingState = address.State;
            needsUpdate = true;
        }
        if (parentAccount.BillingPostalCode != address.PostalCode) {
            parentAccount.BillingPostalCode = address.PostalCode;
            needsUpdate = true;
        }
        if (parentAccount.BillingCountry != address.Country) {
            parentAccount.BillingCountry = address.Country;
            needsUpdate = true;
        }

        if (needsUpdate) {
            accountsToUpdate.add(parentAccount);
        }
    }

    /**
     * @description Performs DML updates for addresses and accounts
     * @param addressesToUpdate List of addresses to update
     * @param accountsToUpdate List of accounts to update
     */
    private static void performDMLUpdates(List<ContactPointAddress> addressesToUpdate, List<Account> accountsToUpdate) {
        if (!addressesToUpdate.isEmpty()) {
            Database.update(addressesToUpdate, false, AccessLevel.USER_MODE);
        }

        if (!accountsToUpdate.isEmpty()) {
            Database.update(accountsToUpdate, false, AccessLevel.USER_MODE);
        }
    }
}