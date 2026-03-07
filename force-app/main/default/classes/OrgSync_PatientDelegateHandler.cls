/**
 * @description Handler class responsible for filtering eligible Patient Stage records
 *              and invoking the service for Patient Delegate creation/update and CCR.
 *              Filters: need to update, create new delegate, drop (guardian cleared), nothing to do.
 * Created Date : Dec 2025
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 2025            Ramesh Kumar            Initial Version
 * V1.1.0       Feb 2026            Ramesh Kumar            Added record filtering for update scenario
 */
public with sharing class OrgSync_PatientDelegateHandler {

    /** ==================== Class Variables ==================== */
    private OrgSync_PatientDelegateService service;

    /** ==================== Public Methods ==================== */
    /**
     * @description Constructor initializing the service
     */
    public OrgSync_PatientDelegateHandler() {
        this.service = new OrgSync_PatientDelegateService();
    }

    /**
     * @description Handles after insert logic. Processes all records with patient external ID.
     * @param newRecords List of new staging records
     */
    public void handleInsert(List<OrgSync_Patient_Staging__c> newRecords) {
        List<OrgSync_Patient_Staging__c> toProcess = filterRecordsForInsert(newRecords);
        if (!toProcess.isEmpty()) {
            service.processDelegates(toProcess, null);
        }
    }

    /**
     * @description Handles after update logic. Filters records: guardian changed (update/create) or cleared (drop).
     * @param newRecords List of new staging records
     * @param oldMap Map of old staging records
     */
    public void handleUpdate(List<OrgSync_Patient_Staging__c> newRecords, Map<Id, OrgSync_Patient_Staging__c> oldMap) {
        List<OrgSync_Patient_Staging__c> toProcess = filterRecordsForUpdate(newRecords, oldMap);
        if (!toProcess.isEmpty()) {
            service.processDelegates(toProcess, oldMap);
        }
    }

    /** ==================== Private Methods ==================== */
    /**
     * @description Filters records for insert: must have patient external ID and guardian section populated (first/last name for guardian 1 or 2).
     * @param records List of OrgSync_Patient_Staging__c records
     * @return List<OrgSync_Patient_Staging__c> List of filtered records
     */
    private List<OrgSync_Patient_Staging__c> filterRecordsForInsert(List<OrgSync_Patient_Staging__c> records) {
        List<OrgSync_Patient_Staging__c> result = new List<OrgSync_Patient_Staging__c>();
        for (OrgSync_Patient_Staging__c r : records) {
            if (String.isBlank(r.XCDC_ExternalId__c)) {
                continue;
            }
            Boolean hasGuardian1 = String.isNotBlank(r.OrgSync_Guardian_1_First_Name__c) && String.isNotBlank(r.OrgSync_Guardian_1_Last_Name__c);
            Boolean hasGuardian2 = String.isNotBlank(r.OrgSync_Guardian_2_First_Name__c) && String.isNotBlank(r.OrgSync_Guardian_2_Last_Name__c);
            if (hasGuardian1 || hasGuardian2) {
                result.add(r);
            }
        }
        return result;
    }

    /**
     * @description Filters records for update: only those where guardian demographic fields changed.
     *              Nothing to do = guardian not changed (skip).
     * @param records List of new OrgSync_Patient_Staging__c records
     * @param oldMap Map of old OrgSync_Patient_Staging__c records
     * @return List<OrgSync_Patient_Staging__c> List of filtered records
     */
    private List<OrgSync_Patient_Staging__c> filterRecordsForUpdate(List<OrgSync_Patient_Staging__c> records, Map<Id, OrgSync_Patient_Staging__c> oldMap) {
        List<OrgSync_Patient_Staging__c> result = new List<OrgSync_Patient_Staging__c>();
        for (OrgSync_Patient_Staging__c newRecord : records) {
            if (String.isBlank(newRecord.XCDC_ExternalId__c)) {
                continue;
            }
            if (OrgSync_UtilityService.hasGuardianDemographicFieldsChanged(newRecord, oldMap != null ? oldMap.get(newRecord.Id) : null)) {
                result.add(newRecord);
            }
        }
        return result;
    }
}