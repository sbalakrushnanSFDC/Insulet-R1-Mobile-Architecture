trigger ContractFileAccountShareTrigger on ContentDocumentLink (after insert) {
    Set<Id> contractIds = new Set<Id>();
    
    // 1. Identify CDLs linked to Contracts
    for (ContentDocumentLink cdl : Trigger.new) {
        if (cdl.LinkedEntityId.getSObjectType() == Contract.sObjectType) {
            contractIds.add(cdl.LinkedEntityId);
        }
    }
    
    if (contractIds.isEmpty()) return;

    // 2. Extract Parent Account IDs from the Contracts
    Map<Id, Contract> contractMap = new Map<Id, Contract>([
        SELECT Id, AccountId FROM Contract WHERE Id IN :contractIds
    ]);

    List<AccountShare> sharesToInsert = new List<AccountShare>();
    
    for (ContentDocumentLink cdl : Trigger.new) {
        if (contractMap.containsKey(cdl.LinkedEntityId)) {
            Id accId = contractMap.get(cdl.LinkedEntityId).AccountId;
            
            // 3. Create the Account Share for the User
            sharesToInsert.add(new AccountShare(
                AccountId = accId,
                UserOrGroupId = UserInfo.getUserId(),
                AccountAccessLevel = 'Read',
                OpportunityAccessLevel = 'None',
                CaseAccessLevel = 'None',
                RowCause = 'Manual'
            ));
        }
    }

    // 4. Insert shares (use Database.insert with allOrNone=false to skip existing shares)
    if (!sharesToInsert.isEmpty()) {
        Database.insert(sharesToInsert, false);
    }
}