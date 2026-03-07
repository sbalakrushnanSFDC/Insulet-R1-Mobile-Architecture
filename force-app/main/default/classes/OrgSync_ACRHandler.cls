/**
 * @description Handler class for AccountContactRelation logic.
 *              Filters records by Role and delegates to OrgSync_Patient_ACRService.
 * Created Date : Dec 2025
 * Created By   : Ramesh Dhaka
 */
public inherited sharing class OrgSync_ACRHandler {

    /**
     * @description Handles After Insert logic.
     * @param newRecords List of new ACR records.
     */
    public void handleAfterInsert(List<AccountContactRelation> newRecords) {
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            return;
        }

        List<AccountContactRelation> eligibleRecords = filterRecordsByRole(newRecords);
        if (!eligibleRecords.isEmpty()) {
            new OrgSync_Patient_ACRService().syncACRsToStaging(eligibleRecords, null);
        }
    }

    /**
     * @description Handles After Update logic.
     * @param newRecords List of updated ACR records.
     * @param oldMap Map of old ACR records.
     */
    public void handleAfterUpdate(List<AccountContactRelation> newRecords, Map<Id, AccountContactRelation> oldMap) {
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            return;
        }

        List<AccountContactRelation> eligibleNew = new List<AccountContactRelation>();
        for (AccountContactRelation acr : newRecords) {
            AccountContactRelation oldAcr = oldMap.get(acr.Id);
            // Process if Role is relevant in New OR Old (transition case)
            if (hasRole(acr) || hasRole(oldAcr)) {
                eligibleNew.add(acr);
            }
        }

        if (!eligibleNew.isEmpty()) {
            new OrgSync_Patient_ACRService().syncACRsToStaging(eligibleNew, oldMap);
        }
    }

    /**
     * @description Handles After Delete logic.
     * @param oldMap Map of deleted ACR records.
     */
    public void handleAfterDelete(Map<Id, AccountContactRelation> oldMap) {
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            return;
        }

        Map<Id, AccountContactRelation> eligibleOld = new Map<Id, AccountContactRelation>();
        for (AccountContactRelation acr : oldMap.values()) {
            if (hasRole(acr)) {
                eligibleOld.put(acr.Id, acr);
            }
        }

        if (!eligibleOld.isEmpty()) {
            // Pass empty list for newRecords, and filtered oldMap
            new OrgSync_Patient_ACRService().syncACRsToStaging(new List<AccountContactRelation>(), eligibleOld);
        }
    }

    /**
     * @description Filters records by Patient Practice Role.
     * @param records List of ACR records.
     * @return List<AccountContactRelation> Filtered list.
     */
    private List<AccountContactRelation> filterRecordsByRole(List<AccountContactRelation> records) {
        List<AccountContactRelation> filtered = new List<AccountContactRelation>();
        for (AccountContactRelation acr : records) {
            if (hasRole(acr)) {
                filtered.add(acr);
            }
        }
        return filtered;
    }

    /**
     * @description Checks if ACR has the relevant role.
     * @param acr AccountContactRelation record.
     * @return Boolean True if role matches.
     */
    private Boolean hasRole(AccountContactRelation acr) {
        if (acr == null || String.isBlank(acr.Roles)){
            return false;
        }
        for (String role : acr.Roles.split(';')) {
            if (role.trim() == ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE) {
                return true;
            }
        }
        return false;
    }
}