/**
 * @description Handler class responsible for filtering eligible Patient records
 *              from Staging and invoking the service class to upsert Patient Person Accounts.
 */
public with sharing class OrgSync_PatientHandler {

    private OrgSync_PatientService syncPatientService;
    private OrgSync_IdentifierService identifierService;
    private OrgSync_Patient_ACRService acrService;
    private static Id orgSyncUserId;

    /**
     * @description Constructor initializing the service
     */
    public OrgSync_PatientHandler() {
        this.syncPatientService = new OrgSync_PatientService();
        this.identifierService = new OrgSync_IdentifierService();
        this.acrService = new OrgSync_Patient_ACRService();
    }

    /**
     * @description Handles upsert logic (Insert and Update) from Staging to Patient.
     *              Sequence: 1. Upsert Patients, 2. Create Identifiers, 3. Manage ACRs
     * @param newRecords List of new staging records
     * @param oldMap Map of old staging records (null for insert)
     */
    public void handlePatientUpsertFromStaging(List<OrgSync_Patient_Staging__c> newRecords, Map<Id, OrgSync_Patient_Staging__c> oldMap) {
        if (newRecords != null && !newRecords.isEmpty()) {
            // Step 1: Upsert Patient Accounts first
            syncPatientService.upsertPatients(newRecords);

            // Resolve Account IDs once
            Map<String, Id> extIdToAccountId = syncPatientService.resolveAccountIds(newRecords);

            // Step 2: Create Identifiers (after patients are upserted)
            processIdentifiers(newRecords, oldMap, extIdToAccountId);

            // Step 3: Manage Account Contact Relations (after patients are upserted)
            processACRs(newRecords, oldMap, extIdToAccountId);
        }
    }

    /**
     * @description Handles delete logic from Staging to Patient.
     * @param oldRecords List of deleted staging records.
     */
    public void handlePatientDeleteFromStaging(List<OrgSync_Patient_Staging__c> oldRecords) {
        if (oldRecords != null && !oldRecords.isEmpty()) {
            syncPatientService.deletePatients(oldRecords);
        }
    }

    /**
     * @description Handles the synchronization from Account (Patient) to Staging (Insert/Update).
     *              Filters records based on the User context (Not OrgSync User) to break recursion.
     *              Handles both Before (ID generation) and After (Sync to Staging) logic.
     * @param records List of Account records
     * @param oldMap Map of old Account records
     */
    public static void handleUpsertPatientToStaging(List<Account> records, Map<Id, Account> oldMap) {
        // Condition: "when any user update/Create patient record then check whether current user is not OrgSync User"
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            return;
        }
        List<Account> patientRecords = filterPatientRecords(records);
        if (patientRecords.isEmpty()) {
            return;
        }

        if (Trigger.isBefore) {
            OrgSync_PublishSettingService.generateExternalId(patientRecords);
        }

        if (Trigger.isAfter) {
            OrgSync_SyncPatientStageService syncPatientStageService = new OrgSync_SyncPatientStageService();
            syncPatientStageService.syncToStaging(patientRecords, oldMap);
        }
    }

    /**
     * @description Handles the after delete logic for the Patient record to Staging.
     *              Calls OrgSync_SyncPatientStageService directly as it's a separate transaction.
     * @param deletedRecords List of deleted Account records
     */
    public static void handlePatientDeleteToStaging(List<Account> deletedRecords){
        // Condition: "when any user delete patient record then check whether current user is not OrgSync User"
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            return;
        }
        List<Account> patientRecords = filterPatientRecords(deletedRecords);
        if (!patientRecords.isEmpty()) {
            OrgSync_SyncPatientStageService syncPatientStageService = new OrgSync_SyncPatientStageService();
            syncPatientStageService.deletePatientStaging(patientRecords);
        }
    }

    /**
     * @description Filters the list of Accounts to return only Patient records.
     * @param records List of Account records
     * @return List<Account> List of Patient Account records
     */
    private static List<Account> filterPatientRecords(List<Account> records) {
        List<Account> patientRecords = new List<Account>();
        if (records == null) {
            return patientRecords;
        }

        for (Account acc : records) {
            if (acc.RecordTypeId == ConstantsUtil.ACCOUNT_PATIENT_RT) {
                patientRecords.add(acc);
            }
        }
        return patientRecords;
    }

    /**
     * @description Helper to process Identifier creation.
     * @param records List of staging records.
     * @param oldMap Map of old staging records.
     * @param extIdToAccountId Map of External ID to Account ID.
     */
    private void processIdentifiers(List<OrgSync_Patient_Staging__c> records, Map<Id, OrgSync_Patient_Staging__c> oldMap, Map<String, Id> extIdToAccountId) {
        if (records == null || records.isEmpty() || extIdToAccountId.isEmpty()) {
            return;
        }

        Map<String, String> extIdToIdentifierValue = new Map<String, String>();
        for (OrgSync_Patient_Staging__c reg : records) {
            String newVal = reg.OrgSync_CustomerId__c;
            if (String.isBlank(newVal) || String.isBlank(reg.XCDC_ExternalId__c)) {
                continue;
            }

            // Check if changed from null to non-null
            // If Insert (oldMap is null), previous is considered null.
            String oldVal = (oldMap != null && oldMap.containsKey(reg.Id)) ? oldMap.get(reg.Id).OrgSync_CustomerId__c : null;

            if (oldVal == null && String.isNotBlank(newVal)) {
                extIdToIdentifierValue.put(reg.XCDC_ExternalId__c, newVal);
            }
        }

        if (!extIdToIdentifierValue.isEmpty()) {
            identifierService.createIdentifiers(extIdToAccountId, extIdToIdentifierValue, ConstantsUtil.IDENTIFIER_EXTERNAL_PATIENT_ID_USAGE_TYPE);
        }
    }

    /**
     * @description Helper to process ACR management.
     * @param records List of staging records.
     * @param oldMap Map of old staging records.
     * @param extIdToAccountId Map of External ID to Account ID.
     */
    private void processACRs(List<OrgSync_Patient_Staging__c> records, Map<Id, OrgSync_Patient_Staging__c> oldMap, Map<String, Id> extIdToAccountId) {
        if (records == null || records.isEmpty() || extIdToAccountId.isEmpty()) {
            return;
        }

        List<OrgSync_Patient_Staging__c> eligibleRecords = new List<OrgSync_Patient_Staging__c>();
        for (OrgSync_Patient_Staging__c reg : records) {
            Id newPracticeId = reg.OrgSync_Practice__c;
            if (oldMap == null) {
                // Insert case: check if practice is not null
                if (newPracticeId != null) {
                    eligibleRecords.add(reg);
                }
            } else {
                // Update case: check if practice changed
                OrgSync_Patient_Staging__c oldReg = oldMap.get(reg.Id);
                Id oldPracticeId = (oldReg != null) ? oldReg.OrgSync_Practice__c : null;
                if (newPracticeId != oldPracticeId) {
                    eligibleRecords.add(reg);
                }
            }
        }

        if (!eligibleRecords.isEmpty()) {
            acrService.manageACRsFromStaging(eligibleRecords, oldMap, extIdToAccountId);
        }
    }
}