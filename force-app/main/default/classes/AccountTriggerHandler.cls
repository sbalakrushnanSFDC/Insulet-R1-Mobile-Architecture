/**
 * @description : Handles all trigger logic for the Account object
 * Created Date : 01-10-2025
 * Created By   : Bijayalaxmi Prusty
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       1st Oct 2025        Bijayalaxmi Prusty      Initial Version(US - NGASIM-376)
 * V1.1.0       15th Oct 2025       Bijayalaxmi Prusty      Modifed(US - NGASIM-377)
 * V1.1.1       16th Oct 2025       Sunil Khanchandani      Modifed(US - NGASIM-371)
 * V1.1.2       4th Nov 2025        Bijayalaxmi Prusty      Modified(US - NGASIM-622)
 * V1.1.3       2nd Dec 2025        Niranjan Elangovan      Modified(US - NGASIM-1389)
 * V1.1.4       29th Dec 2025       Charchit Nirayanwal     Updated(US - NGOMCT-1358) - Added SendtoAspnHandler logic for Insulet Standard events
 * V1.1.5       2nd Jan 2026        Srinivas Shanigarapu    Modified(US - NGOMCT-235)
 * V1.1.6       12th Jan 2026       Bijayalaxmi Prusty      Updated(US - NGASIM-1643)
 * V1.1.7       26th Jan 2026       Neeraj Kumar            Updated(US - NGCRMI-1743)
 * V1.1.8       12th Feb 2026       Yogesh Rana             (NGOMCT-2099)
 * V1.1.9       23rd Feb 2026       Pradip Kokate           Updated to remove Provider Handler call from after insert
 * V1.1.10      24th Feb 2026       Ayush Sharma            Updated(US - NGASIM-1062) - Added processApplyTerritoryToHierarchy logic
 * V1.1.11      27th Feb 2026       Ayush Sharma            Added validateParentChildHierarchy
 * =======================================================================
 */
public with sharing class AccountTriggerHandler extends TriggerHandler {

    /**
     * @description Handles the before insert trigger logic for the Account object
     * @param newRecords The list of new Account records
     */
    public override void beforeInsert(List<SObject> newRecords) {
        List<Account> accountsToProcess = (List<Account>) newRecords;
        TerritoryAssignmentService.assignTerritoryToAccounts(accountsToProcess, null);
        AccountService.updatePrimaryCsmForAccounts(accountsToProcess, null);
        /** Org sync Methods calls here */
        OrgSync_PatientHandler.handleUpsertPatientToStaging(accountsToProcess, null);
        OrgSync_PracticeHandler.handleBeforeInsert(accountsToProcess);
    }

    /**
     * @description Handles the before update trigger logic for the Account object
     * @param newRecordsMap The map of new Account records
     * @param oldRecordsMap The map of old Account records
     */
    public override void beforeUpdate(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<Account> accountsToProcess = (List<Account>) newRecordsMap?.values();
        Map<Id, Account> oldAccountsMap = (Map<Id, Account>) oldRecordsMap;
        TerritoryHierarchyHandler.validateParentChildHierarchy(accountsToProcess, oldAccountsMap);
        TerritoryAssignmentService.assignTerritoryToAccounts(accountsToProcess, oldAccountsMap);
        AccountService.updatePrimaryCsmForAccounts(accountsToProcess, oldAccountsMap);
        /** Org sync Methods calls here */
        OrgSync_PracticeHandler.handleBeforeUpdate(accountsToProcess, oldAccountsMap);
    }

    /**
     * @description Handles the after insert trigger logic for the Account object
     * @param newRecordsMap The map of new Account records
     */
    public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        List<Account> accountsToProcess = (List<Account>) newRecordsMap?.values();
        IndividualHandler.manageIndividuals(accountsToProcess);
        HealthCareProviderService.processNewHealthCareRecords(accountsToProcess);
        AccountDeactivationService.processAccountDeactivation(accountsToProcess, null);
        SendtoAspnHandler.processAccountUpdatesForAspn(accountsToProcess, null);
        // Use Handler to invoke OrgSync Patient Handler with Filter logic
        OrgSync_PatientHandler.handleUpsertPatientToStaging(accountsToProcess, null);
    }

    /**
     * @description Handles the after update trigger logic for the Account object
     * @param updatedRecordsMap The map of updated Account records
     * @param oldRecordsMap The map of old Account records
     */
    public override void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<Account> accountsToProcess = (List<Account>) updatedRecordsMap?.values();
        Map<Id,Account> oldAccountsMap = (Map<Id,Account>) oldRecordsMap;
        IndividualHandler.manageUpdateIndividuals(accountsToProcess,oldAccountsMap);
        HealthCareProviderService.processHealthcareProvidersOnAccountUpdate(accountsToProcess,oldAccountsMap);
        AccountDeactivationService.processAccountDeactivation(accountsToProcess, oldAccountsMap);
        SendtoAspnHandler.processAccountUpdatesForAspn(accountsToProcess, oldAccountsMap);
        TerritoryRuleServiceHandler.processAccountsForTerritoryRules(accountsToProcess, oldAccountsMap);
        TerritoryHierarchyHandler.processApplyTerritoryToHierarchy(accountsToProcess, oldAccountsMap);
        // Use Handler to invoke OrgSync Patient Handler with Filter logic
        OrgSync_PatientHandler.handleUpsertPatientToStaging(accountsToProcess, oldAccountsMap);
        OrgSync_ProviderHandler.handleUpsertProviderToStaging(accountsToProcess, oldAccountsMap);
        TrainingService.updateTrainingRecords(accountsToProcess, oldAccountsMap);
    }

    /**
     * @description Handles the after delete trigger logic for the Account object
     * @param deletedRecordsMap The map of deleted Account records
     */
    public override void afterDelete(Map<Id, SObject> deletedRecordsMap) {
        List<Account> accountsToProcess = (List<Account>) deletedRecordsMap?.values();
        OrgSync_PatientHandler.handlePatientDeleteToStaging(accountsToProcess);
    }

    /**
     * @description Executes at the end of the trigger execution.
     *              Saves any logs generated during the transaction.
     */
    protected override void andFinally() {
        Logger.saveLog();
    }
}