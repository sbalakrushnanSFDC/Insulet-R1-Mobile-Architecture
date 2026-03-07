/**
* @description Handler class responsible for filtering eligible Patient Account records
*              and invoking the service class to manage ContactPoint objects
*              (ContactPointEmail, ContactPointPhone, ContactPointAddress).
*              This handler filters records based on Patient record type and Person Account type.
* Created Date : Dec 2025
* Created By   : Ramesh Kumar
* =========================== Logs ======================================
* Version      Modified Date       Modified By             Brief Note
* V1.0.0       Dec 2025            Ramesh Kumar            Initial Version
* V1.0.1	   Feb 25, 2026		   Neeraj Kumar			   Added code for Physician Staging CP Records Sync
* V1.0.2	   Feb 2026			   Ramesh Kumar			   Added Guardian CPE/CPP sync to Patient Stage
*/
@SuppressWarnings('PMD.StdCyclomaticComplexity,PMD.NcssMethodCount,PMD.CyclomaticComplexity')
public with sharing class OrgSync_ContactPointHandler {

    private OrgSync_ContactPointObjectService service;
    private OrgSync_PhysicianContactPointService physicianService;

    /**
    * @description Constructor initializing the service
    */
    public OrgSync_ContactPointHandler() {
        this.service = new OrgSync_ContactPointObjectService();
        this.physicianService = new OrgSync_PhysicianContactPointService();
    }

    /**
    * @description Handles after insert logic
    * @param newRecords List of new staging records
    */
    public void handleInsert(List<OrgSync_Patient_Staging__c> newRecords) {
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            service.processContactPoints(newRecords, null);
        }
    }

    /**
    * @description Handles after update logic
    * @param newRecords List of new staging records
    * @param oldMap Map of old staging records
    */
    public void handleUpdate(List<OrgSync_Patient_Staging__c> newRecords, Map<Id, OrgSync_Patient_Staging__c> oldMap) {
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            service.processContactPoints(newRecords, oldMap);
        }
    }

    /**
    * @description Handles after insert/update logic for Physician Staging (upsert)
    * @param newRecords List of new Physician staging records
    * @param oldMap Map of old Physician staging records (null for insert)
    */
    public void handlePhysicianUpsert(List<OrgSync_Physician_Staging__c> newRecords, Map<Id, OrgSync_Physician_Staging__c> oldMap) {
        physicianService.processContactPoints(newRecords, oldMap);
    }

    /**
    * @description Checks the SObject type and sorts records into dedicated lists for further processing.
    * @param updatedRecordsMap Map of new SObjects (Id to SObject)
    * @param oldRecordsMap Map of old SObjects (Id to SObject)
    * @param isDeleteContext Boolean indicating if the context is delete
    */
    public void sortRecordsBySObjectType(Map<Id, SObject> updatedRecordsMap,Map<Id, SObject> oldRecordsMap,Boolean isDeleteContext){
        OrgSync_DemographicsSyncToStaging demographicsSync = new OrgSync_DemographicsSyncToStaging();
        OrgSync_ProviderDemographicsSync providerDemographicsSync = new OrgSync_ProviderDemographicsSync();
        // Define the lists
        List<ContactPointPhone> listContactPointPhones = new List<ContactPointPhone>();
        List<ContactPointEmail> listContactPointEmail = new List<ContactPointEmail>();
        List<ContactPointAddress> listContactPointAddress = new List<ContactPointAddress>();
        Map<Id, SObject> recordsToProcessMap;
        if (isDeleteContext) {
            // For delete, use oldRecordsMap. If it's null, set to an empty map.
            recordsToProcessMap = oldRecordsMap != null ? oldRecordsMap : new Map<Id, SObject>();
        } else {
            // For upsert, use newRecordsMap. If it's null, set to an empty map.
            recordsToProcessMap = updatedRecordsMap != null ? updatedRecordsMap : new Map<Id, SObject>();
        }

        if (recordsToProcessMap.isEmpty()) {
            return;
        }

        // Get the list of new records to process
        List<SObject> allNewRecords = updatedRecordsMap != null ? updatedRecordsMap.values() : oldRecordsMap.values();

        // Iterate and check SObject Type (use OrgSync_UtilityService for safe empty-query handling)
        for (SObject record : allNewRecords) {
            if (!OrgSync_UtilityService.isOrgSyncUser()) {
                String objectApiName = record.getSObjectType().getDescribe().getName();
                if (objectApiName == 'ContactPointPhone') {
                    listContactPointPhones.add((ContactPointPhone)record);
                }
                else if (objectApiName == 'ContactPointEmail') {
                    listContactPointEmail.add((ContactPointEmail)record);
                }
                else if (objectApiName == 'ContactPointAddress') {
                    listContactPointAddress.add((ContactPointAddress)record);
                }
            }
        }
        // Check if respective contactpoint lists are non empty, call the respective service method
        if (isDeleteContext) {
            // CALL DELETE/CLEAR METHODS (Using the records from Trigger.oldMap)
            if (!listContactPointAddress.isEmpty()) {
                demographicsSync.clearStagingAddressOnDelete(listContactPointAddress);
            }
            if (!listContactPointPhones.isEmpty()) {
                demographicsSync.clearStagingPhoneOnDelete(listContactPointPhones);
            }
            if (!listContactPointEmail.isEmpty()) {
                demographicsSync.clearStagingEmailOnDelete(listContactPointEmail);
            }
            // Provider: bulk clear (1 HPF + 1 Account + 1 Staging query instead of 9)
            providerDemographicsSync.clearStagingOnDeleteBulk(
                listContactPointPhones, listContactPointEmail, listContactPointAddress);
        } else {
            // Mark provider reverse sync in progress to prevent Account→Staging from overwriting
            if (!listContactPointPhones.isEmpty() || !listContactPointEmail.isEmpty() || !listContactPointAddress.isEmpty()) {
                OrgSync_UtilityService.isProviderContactPointReverseSyncInProgress = true;
            }
            // Patient Staging sync
            if (!listContactPointPhones.isEmpty()) {
                if (!OrgSync_UtilityService.isPatientCPPRecsCreated) {
                    demographicsSync.syncContactPointPhoneToStaging(listContactPointPhones);
                    OrgSync_UtilityService.isPatientCPPRecsCreated = true;
                }
                demographicsSync.syncGuardianContactPointPhoneToPatientStage(listContactPointPhones, (Map<Id, ContactPointPhone>)oldRecordsMap);
            }
            if (!listContactPointEmail.isEmpty()) {
                if (!OrgSync_UtilityService.isPatientCPERecsCreated) {
                    demographicsSync.syncContactPointEmailToStaging(listContactPointEmail);
                    OrgSync_UtilityService.isPatientCPERecsCreated = true;
                }
                demographicsSync.syncGuardianContactPointEmailToPatientStage(listContactPointEmail, (Map<Id, ContactPointEmail>)oldRecordsMap);
            }
            if (!listContactPointAddress.isEmpty()) {
                if (!OrgSync_UtilityService.isPatientCPARecsCreated) {
                    demographicsSync.syncContactPointAddressToStaging(listContactPointAddress);
                    OrgSync_UtilityService.isPatientCPARecsCreated = true;
                }
            }

            // Physician Staging sync: bulk call (1 HPF + 1 Account + 1 Staging query instead of 9)
            Boolean providerNeedsSync = (!listContactPointPhones.isEmpty() && !OrgSync_UtilityService.isProviderCPPRecsCreated)
                || (!listContactPointEmail.isEmpty() && !OrgSync_UtilityService.isProviderCPERecsCreated)
                || (!listContactPointAddress.isEmpty() && !OrgSync_UtilityService.isProviderCPARecsCreated);
            if (providerNeedsSync) {
                providerDemographicsSync.syncContactPointsToStagingBulk(
                    listContactPointPhones, listContactPointEmail, listContactPointAddress);
                OrgSync_UtilityService.isProviderCPPRecsCreated = true;
                OrgSync_UtilityService.isProviderCPERecsCreated = true;
                OrgSync_UtilityService.isProviderCPARecsCreated = true;
            }
        }
    }
}