/**
 * Service class for Case business logic.
 * Contains methods to process Case records and handle notifications.
 * 
 * @author      Saikat Ghosh
 * @created     25th Feb 2026
 *
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       25th Feb 2026       Saikat Ghosh       (US - NGASIM-2045) Initial version – Case service class
 */
public inherited sharing class CaseService {
    
    /**
     * @description Processes Case notifications for insert and update operations
     * @param newCases List of new Case records
     * @param oldCasesMap Map of old Case records (null for insert operations)
     */
    public static void processCaseNotifications(List<Case> newCases, Map<Id, Case> oldCasesMap) {
        if (newCases == null || newCases.isEmpty()) {
            return;
        }
    
        // Filter cases that qualify for notification
        List<Case> casesToProcess = filterCasesForNotification(newCases, oldCasesMap);

        if (casesToProcess.isEmpty()) {
            return;
        }
        
        // Get parent record names in bulk
        Map<Id, String> parentRecordNamesMap = getCaseParentNames(casesToProcess);
        // Process notifications for each qualifying case
        for (Case caseRecord : casesToProcess) {
            String parentRecordName = parentRecordNamesMap.get(caseRecord.Id);
            if (String.isNotBlank(parentRecordName) && String.isNotBlank(caseRecord.Approval_Status__c)) {
                SendNotificationsService.sendCaseClosureNotification(
                    caseRecord, 
                    parentRecordName
                );
            }
        }
    }
    
    /**
     * @description Filters cases that qualify for notification processing
     * @param newCases List of new Case records
     * @param oldCasesMap Map of old Case records (null for insert operations)
     * @return List of Case records that qualify for notification
     */
    @TestVisible
    private static List<Case> filterCasesForNotification(List<Case> newCases, Map<Id, Case> oldCasesMap) {
        List<Case> qualifyingCases = new List<Case>();

        // Get RecordType information using Schema
        Map<Id, Schema.RecordTypeInfo> rtMap = Case.SObjectType.getDescribe().getRecordTypeInfosById();
        
        for (Case newCase : newCases) {
            Case oldCase = (oldCasesMap != null) ? oldCasesMap.get(newCase.Id) : null;
            // Common: HCP Update Request with approved/rejected status and Status Closed
            Boolean isHcpUpdateRequest = newCase.RecordTypeId != null &&
                rtMap.get(newCase.RecordTypeId)?.getDeveloperName() == ConstantsUtil.CASE_RECORD_TYPE_HCP_UPDATE_REQUEST &&
                (
                    newCase.Approval_Status__c == ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE ||
                    newCase.Approval_Status__c == ConstantsUtil.CASE_APPROVAL_STATUS_REJECT
                ) &&
                newCase.Status == ConstantsUtil.CASE_STATUS_CLOSED;
            // Insert: Case created with Status Closed
            Boolean insertQualifies = (oldCase == null);
            // Update: Status was changed to Closed
            Boolean updateQualifies = (oldCase != null && oldCase.Status != newCase.Status);
            if (isHcpUpdateRequest && (insertQualifies || updateQualifies)) {
                qualifyingCases.add(newCase);
            }
        }
        
        return qualifyingCases;
    }

    /**
     * @description Gets parent name for each case. Uses Account first, then HCP Affiliation.
     * @param cases List of cases
     * @return Map of case Id to parent name
     */
    @TestVisible
    private static Map<Id, String> getCaseParentNames(List<Case> cases) {
        Map<Id, String> result = new Map<Id, String>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> hcpfIds = new Set<Id>();

        // Gather all Account and HCP Affiliation IDs from cases.
        for (Case c : cases) {
            if (c.AccountId != null) {
                accountIds.add(c.AccountId);
            }
            if (c.HCP_Affiliation__c != null) {
                hcpfIds.add(c.HCP_Affiliation__c);
            }
        }

        // Fetch Account names.
        Map<Id, Account> accountMap = accountIds.isEmpty()
            ? new Map<Id, Account>()
            : new Map<Id, Account>(
                [SELECT Id, Name FROM Account WHERE Id IN :accountIds WITH USER_MODE]
            );

        // Fetch HCP Facility names.
        Map<Id, HealthcarePractitionerFacility> hcpfMap = hcpfIds.isEmpty()
            ? new Map<Id, HealthcarePractitionerFacility>()
            : new Map<Id, HealthcarePractitionerFacility>(
                [SELECT Id, Name FROM HealthcarePractitionerFacility WHERE Id IN :hcpfIds WITH USER_MODE]
            );

        // Put parent name for each case. Account wins when both exist.
        for (Case c : cases) {
            if (c.AccountId != null && accountMap.containsKey(c.AccountId)) {
                result.put(c.Id, accountMap.get(c.AccountId).Name);
            } else if (c.HCP_Affiliation__c != null && hcpfMap.containsKey(c.HCP_Affiliation__c)) {
                result.put(c.Id, hcpfMap.get(c.HCP_Affiliation__c).Name);
            }
        }

        return result;
    }
}