/**
 * @description Helper class for identifying Provider Contact IDs from Patient Staging records
 * Created Date : Jan 19, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 19, 2026        Pradip Kokate      Initial Version
 */
public with sharing class OrgSync_ProviderContactIdHelper {

    /**
     * @description Identifies Provider Person Account Contact IDs via Physician Stage -> NPI -> Identifier
     * @param records List of Patient Staging records
     * @return Map of Provider Staging ID to Provider Contact ID
     */
    public static Map<Id, Id> getProviderContactIds(List<OrgSync_Patient_Staging__c> records) {
        Set<Id> providerStagingIds = collectProviderStagingIds(records);
        if (providerStagingIds.isEmpty()) {
            return new Map<Id, Id>();
        }

        Map<Id, String> providerStagingToNPI = getProviderStagingToNPI(providerStagingIds);
        if (providerStagingToNPI.isEmpty()) {
            return new Map<Id, Id>();
        }

        Set<String> npiValues = new Set<String>(providerStagingToNPI.values());
        Map<String, Id> npiToProviderAccountId = getNpiToProviderAccountIds(npiValues);
        if (npiToProviderAccountId.isEmpty()) {
            return new Map<Id, Id>();
        }

        Map<Id, Id> providerAccountToContactId = getProviderAccountToContactIds(npiToProviderAccountId.values());
        return mapStagingToContactIds(providerStagingToNPI, npiToProviderAccountId, providerAccountToContactId);
    }

    /**
     * @description Collects Provider Staging IDs from Patient Staging records
     * @param records List of Patient Staging records
     * @return Set of Provider Staging IDs
     */
    private static Set<Id> collectProviderStagingIds(List<OrgSync_Patient_Staging__c> records) {
        Set<Id> providerStagingIds = new Set<Id>();
        for (OrgSync_Patient_Staging__c record : records) {
            if (record.OrgSync_Provider__c != null) {
                providerStagingIds.add(record.OrgSync_Provider__c);
            }
        }
        return providerStagingIds;
    }

    /**
     * @description Gets NPIs from Physician Staging records
     * @param providerStagingIds Set of Provider Staging IDs
     * @return Map of Provider Staging ID to NPI
     */
    private static Map<Id, String> getProviderStagingToNPI(Set<Id> providerStagingIds) {
        Map<Id, String> providerStagingToNPI = new Map<Id, String>();

        for (OrgSync_Physician_Staging__c physicianStage : [
            SELECT Id, OrgSync_NPI__c
            FROM OrgSync_Physician_Staging__c
            WHERE Id IN :providerStagingIds
                AND OrgSync_NPI__c != null
            WITH SYSTEM_MODE
        ]) {
            if (String.isNotBlank(physicianStage.OrgSync_NPI__c)) {
                providerStagingToNPI.put(physicianStage.Id, physicianStage.OrgSync_NPI__c);
            }
        }

        return providerStagingToNPI;
    }

    /**
     * @description Gets Provider Account IDs from Identifier records using NPIs
     * @param npiValues Set of NPI values
     * @return Map of NPI to Provider Account ID
     */
    private static Map<String, Id> getNpiToProviderAccountIds(Set<String> npiValues) {
        Map<String, Id> npiToProviderAccountId = new Map<String, Id>();

        for (Identifier identifier : [
            SELECT Id, ParentRecordId, ID_Value__c
            FROM Identifier
            WHERE ID_Value__c IN :npiValues
                AND IdUsageType = :ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
                AND ParentRecordId != null
            WITH SYSTEM_MODE
        ]) {
            if (String.isNotBlank(identifier.ID_Value__c)) {
                String parentIdStr = String.valueOf(identifier.ParentRecordId);
                if (parentIdStr.startsWith('001')) {
                    npiToProviderAccountId.put(identifier.ID_Value__c, identifier.ParentRecordId);
                }
            }
        }

        return npiToProviderAccountId;
    }

    /**
     * @description Gets Provider Contact IDs from Provider Account IDs
     * @param providerAccountIds Set of Provider Account IDs
     * @return Map of Provider Account ID to Provider Contact ID
     */
    private static Map<Id, Id> getProviderAccountToContactIds(List<Id> providerAccountIds) {
        Map<Id, Id> providerAccountToContactId = new Map<Id, Id>();

        for (Account acc : [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id IN :providerAccountIds
                AND PersonContactId != null
                AND RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            WITH SYSTEM_MODE
        ]) {
            if (acc.PersonContactId != null) {
                providerAccountToContactId.put(acc.Id, acc.PersonContactId);
            }
        }

        return providerAccountToContactId;
    }

    /**
     * @description Maps Provider Staging IDs to Provider Contact IDs
     * @param providerStagingToNPI Map of Provider Staging ID to NPI
     * @param npiToProviderAccountId Map of NPI to Provider Account ID
     * @param providerAccountToContactId Map of Provider Account ID to Provider Contact ID
     * @return Map of Provider Staging ID to Provider Contact ID
     */
    private static Map<Id, Id> mapStagingToContactIds(
        Map<Id, String> providerStagingToNPI,
        Map<String, Id> npiToProviderAccountId,
        Map<Id, Id> providerAccountToContactId
    ) {
        Map<Id, Id> providerStagingToContactId = new Map<Id, Id>();

        for (Id providerStagingId : providerStagingToNPI.keySet()) {
            String npi = providerStagingToNPI.get(providerStagingId);
            Id providerAccountId = npiToProviderAccountId.get(npi);
            if (providerAccountId != null) {
                Id providerContactId = providerAccountToContactId.get(providerAccountId);
                if (providerContactId != null) {
                    providerStagingToContactId.put(providerStagingId, providerContactId);
                }
            }
        }

        return providerStagingToContactId;
    }
}