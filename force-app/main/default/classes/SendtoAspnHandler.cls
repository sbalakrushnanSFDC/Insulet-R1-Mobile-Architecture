/**
 * @description Determines which opportunities are eligible for ASPN platform events and invokes the service class.
 *              Handles Cancel_Order__c scenarios, ASPN Source ID Updates, and Insulet Standard events.
 * @author Anup Bandawar
 * @date 26th Nov 2025
 *
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       26th Nov 2025       Anup Bandawar           Initial Version(US - NGOMCT-725)
 * V1.0.1       2nd Dec 2025        Anup Bandawar           Updated(US - NGOMCT-781)
 * V1.0.2       15th Dec 2025       Anup Bandawar           Updated(US - NGOMCT-1202)
 * V1.0.3       29th Dec 2025       Charchit Nirayanwal     Updated(US - NGOMCT-1454) - Removed ASPN source check, added Account trigger logic
 * V1.0.4       29th Dec 2025       Charchit Nirayanwal     Updated(US - NGOMCT-1358) - Added Insulet source logic for Standard events
 * V1.0.5       30th Nov 2025       Saikat Ghosh            Updated(US - NGOMCT-1750) - Disabled Insulet opportunity processing on insert and added Opportunity Product after-insert logic
 */
public inherited sharing class SendtoAspnHandler { // NOPMD
    /**
     * @description Filters opportunities for ASPN processing based on Cancel_Order__c = true
     * @param newOpportunities List of new or updated Opportunity records
     * @param oldOpportunitiesMap Map of old Opportunity records (optional, used for afterUpdate)
     * @return List of opportunities that meet ASPN processing criteria
     */
    public static List<Opportunity> filterSendToAspnOpportunities(
        List<Opportunity> newOpportunities,
        Map<Id, Opportunity> oldOpportunitiesMap
    ) {
        List<Opportunity> sendToAspnOpportunities = new List<Opportunity>();

        if (newOpportunities == null || newOpportunities.isEmpty()) {
            return sendToAspnOpportunities;
        }

        for (Opportunity opp : newOpportunities) {
            if (isEligibleForAspnProcessing(opp, oldOpportunitiesMap)) {
                sendToAspnOpportunities.add(opp);
            }
        }

        return sendToAspnOpportunities;
    }

    /**
     * @description Checks if an opportunity is eligible for ASPN processing
     * @param opp The opportunity to check
     * @param oldOpportunitiesMap Map of old Opportunity records (null for afterInsert)
     * @return True if the opportunity meets ASPN processing criteria
     */
    private static Boolean isEligibleForAspnProcessing(Opportunity opp, Map<Id, Opportunity> oldOpportunitiesMap) {
        if (opp.Cancel_Order__c != true || opp.RecordTypeId != ConstantsUtil.OPPORTUNITY_NCS_RT) {
            return false;
        }

        // For afterInsert: add all opportunities that meet criteria
        if (oldOpportunitiesMap == null) {
            return true;
        }

        // For afterUpdate: check if Cancel_Order__c changed to true
        Opportunity oldOpp = oldOpportunitiesMap.get(opp.Id);
        return oldOpp != null && hasRelevantFieldChanged(opp, oldOpp);
    }

    /**
     * @description Checks if relevant fields have changed for ASPN processing
     * @param newOpp New Opportunity record
     * @param oldOpp Old Opportunity record
     * @return Boolean True if Cancel_Order__c changed to true
     * Note: StageName = 'Send to ASPN' check removed per NGOMCT-1358
     * Note: Opportunity_Source__c check removed - logic moved to processSourceIdUpdateForAspn (NGOMCT-1454)
     */
    private static Boolean hasRelevantFieldChanged(Opportunity newOpp, Opportunity oldOpp) {
        // Check if Cancel_Order__c changed to true
        Boolean cancelOrderChanged = (newOpp.Cancel_Order__c == true && oldOpp.Cancel_Order__c != true);

        return cancelOrderChanged;
    }

    /**
     * @description Processes Source ID Update for ASPN opportunities when Custom_UniqueID__c is saved/updated
     *              This handles the scenario where a Patient's Custom_UniqueID__c is populated and they have
     *              an open Opportunity with Opportunity_Source__c = 'ASPN'
     * @param accountsToProcess List of Account records to process
     * @param oldAccountsMap Map of old Account records (null for afterInsert)
     */
    public static void processSourceIdUpdateForAspn(List<Account> accountsToProcess, Map<Id, Account> oldAccountsMap) {
        if (accountsToProcess == null || accountsToProcess.isEmpty()) {
            return;
        }

        // Filter accounts where Custom_UniqueID__c was populated or updated
        Set<Id> accountIdsToProcess = filterAccountsWithCustomUniqueId(accountsToProcess, oldAccountsMap);

        if (accountIdsToProcess.isEmpty()) {
            return;
        }

        // Query open opportunities with Opportunity_Source__c = 'ASPN' for these accounts
        List<Opportunity> aspnOpportunities = [
            SELECT Id, AccountId, Opportunity_Source__c, RecordTypeId, IsClosed
            FROM Opportunity
            WHERE AccountId IN :accountIdsToProcess
            AND Opportunity_Source__c = :ConstantsUtil.OPPORTUNITY_SOURCE_ASPN
            AND RecordTypeId = :ConstantsUtil.OPPORTUNITY_NCS_RT
            AND IsClosed = false
            WITH USER_MODE
        ];

        if (!aspnOpportunities.isEmpty()) {
            // Process opportunities through SendtoAspnService
            // Note: We bypass filterSendToAspnOpportunities since we've already filtered
            // for ASPN opportunities. SendtoAspnService will determine the transaction type.
            SendtoAspnService.processSendToAspn(aspnOpportunities);
        }
    }

    /**
     * @description Processes Standard event for Insulet opportunities when Custom_UniqueID__c is saved/updated
     *              This handles the scenario where a Patient's Custom_UniqueID__c is populated/updated and they have
     *              an open Opportunity with Opportunity_Source__c = 'Insulet'
     *              Per NGOMCT-1358: Triggers "Standard" platform event when Custom_UniqueID__c is updated
     * @param accountsToProcess List of Account records to process
     * @param oldAccountsMap Map of old Account records (null for afterInsert)
     */
    public static void processStandardEventForInsulet(List<Account> accountsToProcess, Map<Id, Account> oldAccountsMap) {
        if (accountsToProcess == null || accountsToProcess.isEmpty()) {
            return;
        }

        // Filter accounts where Custom_UniqueID__c was populated or updated
        Set<Id> accountIdsToProcess = filterAccountsWithCustomUniqueId(accountsToProcess, oldAccountsMap);

        if (accountIdsToProcess.isEmpty()) {
            return;
        }

        // Query open opportunities with Opportunity_Source__c = 'Insulet' for these accounts
        // Limit to one opportunity per Account
        List<Opportunity> insuletOpportunities = [
            SELECT Id, AccountId, Opportunity_Source__c, RecordTypeId, IsClosed
            FROM Opportunity
            WHERE AccountId IN :accountIdsToProcess
            AND Opportunity_Source__c = :ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
            AND RecordTypeId = :ConstantsUtil.OPPORTUNITY_NCS_RT
            AND IsClosed = false
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 5000
        ];

        // Per NGOMCT-1358 AC1: Only process ONE opportunity per Account
        processOpportunitiesOnePerAccount(insuletOpportunities);
    }

    /**
     * @description Processes Insulet source opportunities when created with Patient having existing Custom_UniqueID__c
     *              Per NGOMCT-1358 AC2: Triggers "Standard" platform event when Opportunity is created for Patient
     *              with existing Custom_UniqueID__c (not blank) and Opportunity_Source__c = 'Insulet'
     *              Only called in afterInsert (removed from afterUpdate per NGOMCT-1358)
     * @param newOpportunities List of newly created Opportunity records
     */
    public static void processInsuletOpportunitiesOnInsert(List<Opportunity> newOpportunities) {
        if (newOpportunities == null || newOpportunities.isEmpty()) {
            return;
        }

        // Collect Account IDs for Insulet opportunities
        Set<Id> accountIds = new Set<Id>();
        List<Opportunity> insuletOpportunities = new List<Opportunity>();
        for (Opportunity opp : newOpportunities) {
            if (opp.Opportunity_Source__c == ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
                && opp.RecordTypeId == ConstantsUtil.OPPORTUNITY_NCS_RT
                && opp.AccountId != null) {
                accountIds.add(opp.AccountId);
                insuletOpportunities.add(opp);
            }
        }

        if (accountIds.isEmpty()) {
            return;
        }

        // Query Accounts to check if Custom_UniqueID__c is populated
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE Id IN :accountIds
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
            AND Custom_UniqueID__c != NULL
            WITH USER_MODE
        ]);

        // Filter opportunities where Patient has Custom_UniqueID__c
        List<Opportunity> insuletOppsWithCustomId = new List<Opportunity>();
        for (Opportunity opp : insuletOpportunities) {
            if (accountMap.containsKey(opp.AccountId)) {
                insuletOppsWithCustomId.add(opp);
            }
        }

        if (!insuletOppsWithCustomId.isEmpty()) {
            SendtoAspnService.processSendToAspn(insuletOppsWithCustomId);
        }
    }

    /**
     * @description Processes all ASPN-related logic for newly created Opportunities
     *              Handles Cancel_Order__c scenarios and Insulet source opportunities
     *              Per NGOMCT-1358: Triggers platform events for Insulet opportunities when Patient has Custom_UniqueID__c
     *              Per NGOMCT-1358: Removed 'Send to ASPN' stage check - only processes Cancel_Order__c = true
     * @param newOpportunities List of newly created Opportunity records
     */
    public static void processOpportunitiesOnInsert(List<Opportunity> newOpportunities) {
        if (newOpportunities == null || newOpportunities.isEmpty()) {
            return;
        }

        // Filter opportunities with Cancel_Order__c = true
        List<Opportunity> sendToAspnOpportunities = filterSendToAspnOpportunities(
            newOpportunities,
            null
        );

        // Process filtered opportunities if any found
        if (!sendToAspnOpportunities.isEmpty()) {
            SendtoAspnService.processSendToAspn(sendToAspnOpportunities);
        }
    }

    /**
     * @description Processes all ASPN-related logic for updated Opportunities
     *              Handles Cancel_Order__c changes only
     *              Per NGOMCT-1358: Removed 'Send to ASPN' stage check - only processes Cancel_Order__c = true
     *              Per NGOMCT-1358: Insulet source logic removed from afterUpdate (only in afterInsert)
     * @param updatedOpportunities List of updated Opportunity records
     * @param oldOpportunitiesMap Map of old Opportunity records
     */
    public static void processOpportunitiesOnUpdate(
        List<Opportunity> updatedOpportunities,
        Map<Id, Opportunity> oldOpportunitiesMap
    ) {
        if (updatedOpportunities == null || updatedOpportunities.isEmpty()) {
            return;
        }

        // Filter opportunities with Cancel_Order__c = true
        List<Opportunity> sendToAspnOpportunities = filterSendToAspnOpportunities(
            updatedOpportunities,
            oldOpportunitiesMap
        );

        // Process filtered opportunities if any found
        if (!sendToAspnOpportunities.isEmpty()) {
            SendtoAspnService.processSendToAspn(sendToAspnOpportunities);
        }
    }

    /**
     * @description Processes all ASPN-related logic for Account updates
     *              Handles both ASPN Source ID Update and Insulet Standard events when Custom_UniqueID__c is saved/updated
     *              Per NGOMCT-1454: Triggers Source ID Update events for ASPN source opportunities
     *              Per NGOMCT-1358: Triggers Standard events for Insulet source opportunities
     *              Optimized: Combines account filtering, opportunity queries, and service calls to reduce SOQL calls
     * @param accountsToProcess List of Account records to process
     * @param oldAccountsMap Map of old Account records (null for afterInsert)
     */
    public static void processAccountUpdatesForAspn(List<Account> accountsToProcess, Map<Id, Account> oldAccountsMap) {
        if (accountsToProcess == null || accountsToProcess.isEmpty()) {
            return;
        }

        // Filter accounts where Custom_UniqueID__c was populated or updated (shared logic)
        Set<Id> accountIdsToProcess = filterAccountsWithCustomUniqueId(accountsToProcess, oldAccountsMap);

        if (accountIdsToProcess.isEmpty()) {
            return;
        }

        // Query open opportunities for both ASPN and Insulet sources in a single query
        List<Opportunity> allOpportunities = [
            SELECT Id, AccountId, Opportunity_Source__c, RecordTypeId, IsClosed
            FROM Opportunity
            WHERE AccountId IN :accountIdsToProcess
            AND Opportunity_Source__c IN (:ConstantsUtil.OPPORTUNITY_SOURCE_ASPN, :ConstantsUtil.OPPORTUNITY_SOURCE_INSULET)
            AND RecordTypeId = :ConstantsUtil.OPPORTUNITY_NCS_RT
            AND IsClosed = false
            WITH USER_MODE
        ];

        if (allOpportunities.isEmpty()) {
            return;
        }

        // Split opportunities by source for clarity
        // Note: SendtoAspnService.buildSingleAspnEvent() determines event type based on Opportunity_Source__c,
        // so combining them would work, but splitting provides better clarity and explicit control
        List<Opportunity> aspnOpportunities = new List<Opportunity>();
        List<Opportunity> insuletOpportunities = new List<Opportunity>();

        for (Opportunity opp : allOpportunities) {
            if (opp.Opportunity_Source__c == ConstantsUtil.OPPORTUNITY_SOURCE_ASPN) {
                aspnOpportunities.add(opp);
            } else if (opp.Opportunity_Source__c == ConstantsUtil.OPPORTUNITY_SOURCE_INSULET) {
                insuletOpportunities.add(opp);
            }
        }

        // Process ASPN opportunities for Source ID Update (NGOMCT-1454)
        processOpportunitiesOnePerAccount(aspnOpportunities);

        // Process Insulet opportunities for Standard event (NGOMCT-1358)
        processOpportunitiesOnePerAccount(insuletOpportunities);
    }

    /**
     * @description Processes opportunities limiting to one per Account to ensure only one event per Account update
     * @param opportunities List of opportunities to process
     */
    private static void processOpportunitiesOnePerAccount(List<Opportunity> opportunities) {
        if (opportunities == null || opportunities.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> accountToOpportunityMap = new Map<Id, Opportunity>();
        for (Opportunity opp : opportunities) {
            if (!accountToOpportunityMap.containsKey(opp.AccountId)) {
                accountToOpportunityMap.put(opp.AccountId, opp);
            }
        }

        List<Opportunity> opportunitiesToProcess = new List<Opportunity>(accountToOpportunityMap.values());
        SendtoAspnService.processSendToAspn(opportunitiesToProcess);
    }

    /**
     * @description Helper method to filter Patient accounts where Custom_UniqueID__c was populated or updated
     *              Extracted to avoid code duplication between processSourceIdUpdateForAspn and processStandardEventForInsulet
     * @param accountsToProcess List of Account records to process
     * @param oldAccountsMap Map of old Account records (null for afterInsert)
     * @return Set<Id> Set of Account IDs that meet the criteria
     */
    private static Set<Id> filterAccountsWithCustomUniqueId(List<Account> accountsToProcess, Map<Id, Account> oldAccountsMap) {
        Set<Id> accountIdsToProcess = new Set<Id>();

        for (Account acc : accountsToProcess) {
            // Check if this is a Patient account
            if (acc.RecordTypeId != ConstantsUtil.ACCOUNT_PATIENT_RT) {
                continue;
            }

            // For afterInsert: check if Custom_UniqueID__c is populated
            if (oldAccountsMap == null) {
                if (String.isNotBlank(acc.Custom_UniqueID__c)) {
                    accountIdsToProcess.add(acc.Id);
                }
            } else {
                // For afterUpdate: check if Custom_UniqueID__c changed and new value is not blank
                Account oldAccount = oldAccountsMap.get(acc.Id);
                if (oldAccount != null
                    && String.isNotBlank(acc.Custom_UniqueID__c)
                    && oldAccount.Custom_UniqueID__c != acc.Custom_UniqueID__c) {
                    accountIdsToProcess.add(acc.Id);
                }
            }
        }

        return accountIdsToProcess;
    }
    
    /**
     * @description Handles Opportunity Product after-insert processing.
     *              Collects related Opportunities and routes them for ASPN processing.
     *              (US – NGOMCT-1750)
     * @param newRecordsMap Map of newly inserted OpportunityLineItem records
     */
    public static void handleOpportunityProductAfterInsert(Map<Id, SObject> newRecordsMap) {
        List<OpportunityLineItem> opptyLIToProcess =(List<OpportunityLineItem>) newRecordsMap?.values();
        if (opptyLIToProcess == null || opptyLIToProcess.isEmpty()) {
            return;
        }
        Set<Id> opptyIds = new Set<Id>();
        for (OpportunityLineItem oli : opptyLIToProcess) {
            if (oli.OpportunityId != null) {
                opptyIds.add(oli.OpportunityId);
            }
        }
        if (opptyIds.isEmpty()) {
            return;
        }
        List<Opportunity> opptyToProcess = [
            SELECT Id, Opportunity_Source__c, AccountId, RecordTypeId
            FROM Opportunity
            WHERE Id IN :opptyIds
            WITH USER_MODE
        ];
        if (!opptyToProcess.isEmpty()) {
            processInsuletOpportunitiesOnInsert(opptyToProcess);
        }
    }
}