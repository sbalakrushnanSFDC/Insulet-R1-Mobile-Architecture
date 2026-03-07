/**
 * Handler class that contains all business logic for Case triggers.
 * Extends TriggerHandler to provide structured trigger context handling.
 * 
 * @author      Saikat Ghosh
 * @created     25th Feb 2026
 *
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       25th Feb 2026       Saikat Ghosh       (US - NGASIM-2045) Initial version – Case trigger handler setup
 */
public with sharing class CaseTriggerHandler extends TriggerHandler {

    /**
     * @description Handles the after insert trigger logic for the Case object
     * @param newRecordsMap The map of new Case records
     * @param oldRecordsMap The map of old Case records which is null for insert operations
     */
    public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        List<Case> casesToProcess = (List<Case>) newRecordsMap?.values();
        CaseService.processCaseNotifications(casesToProcess, null);
    }

    /**
     * @description Handles the after update trigger logic for the Case object
     * @param updatedRecordsMap The map of updated Case records
     * @param oldRecordsMap The map of old Case records
     */
    public override void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<Case> casesToProcess = (List<Case>) updatedRecordsMap?.values();
        Map<Id, Case> oldCasesMap = oldRecordsMap != null ? (Map<Id, Case>) oldRecordsMap : new Map<Id, Case>();
        CaseService.processCaseNotifications(casesToProcess, oldCasesMap);
    }
}