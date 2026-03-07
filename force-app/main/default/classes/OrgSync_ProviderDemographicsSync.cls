/**
 * @description Service class for syncing primary Contact Point Objects (Email, Phone, Address)
 *              back to OrgSync_Physician_Staging__c. Only primary contact points LINKED TO HPF
 *              (HealthcarePractitionerFacility) are synced - Phone->OrgSync_Phone__c,
 *              Email->OrgSync_PersonEmail__c, Address->OrgSync_Mailing_Address__*.
 * Created Date : Jan 12, 2026
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 12, 2026        Neeraj Kumar            Initial Version
 * V1.1.0       Feb 24, 2026        Neeraj Kumar            Primary-only reverse sync to staging
 * V1.2.0       Feb 24, 2026        Neeraj Kumar            HPF-linked only: Phone->OrgSync_Phone__c, Email->PersonEmail, Address->Mailing
 * V1.3.0       Feb 26, 2026        Neeraj Kumar            Bulk sync/clear methods to reduce SOQL; removed dead code
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount,PMD.CognitiveComplexity,PMD.ApexDoc')
public inherited sharing class OrgSync_ProviderDemographicsSync {

    /**
     * @description Bulk sync: Phone, Email, and Address to staging in one pass. Uses 1 HPF + 1 Account + 1 Staging query
     * instead of 9 queries when all three run separately. Call this from ContactPoint trigger when all three types may change.
     * @param phoneRecords ContactPointPhone list (primary, HPF-linked only)
     * @param emailRecords ContactPointEmail list (primary, HPF-linked only)
     * @param addressRecords ContactPointAddress list (primary, HPF-linked only)
     */
    public void syncContactPointsToStagingBulk(
        List<ContactPointPhone> phoneRecords,
        List<ContactPointEmail> emailRecords,
        List<ContactPointAddress> addressRecords
    ) {
        Set<Id> cppIds = new Set<Id>();
        Set<Id> cpeIds = new Set<Id>();
        Set<Id> cpaIds = new Set<Id>();
        for (ContactPointPhone cpp : phoneRecords != null ? phoneRecords : new List<ContactPointPhone>()) {
            if (cpp.Id != null && cpp.IsPrimary == true) { cppIds.add(cpp.Id); }
        }
        for (ContactPointEmail cpe : emailRecords != null ? emailRecords : new List<ContactPointEmail>()) {
            if (cpe.Id != null && cpe.IsPrimary == true) { cpeIds.add(cpe.Id); }
        }
        for (ContactPointAddress cpa : addressRecords != null ? addressRecords : new List<ContactPointAddress>()) {
            if (cpa.Id != null && cpa.IsPrimary == true) { cpaIds.add(cpa.Id); }
        }
        if (cppIds.isEmpty() && cpeIds.isEmpty() && cpaIds.isEmpty()) {
            return;
        }
        List<HealthcarePractitionerFacility> hpfs = queryHpfsByContactPointIds(cppIds, cpeIds, cpaIds);
        if (hpfs.isEmpty()) {
            return;
        }
        Map<Id, Id> practitionerIdToAccountId = getPractitionerIdToProviderAccountId(hpfs);
        Set<String> compositeExtIds = collectCompositeExtIdsFromHpfs(practitionerIdToAccountId, hpfs);
        if (compositeExtIds.isEmpty()) {
            return;
        }
        Map<String, OrgSync_Physician_Staging__c> stagingByExtId = queryStagingByExternalIds(compositeExtIds);
        Map<Id, String> cppIdToPhone = new Map<Id, String>();
        for (ContactPointPhone cpp : phoneRecords != null ? phoneRecords : new List<ContactPointPhone>()) {
            if (cppIds.contains(cpp.Id)) { cppIdToPhone.put(cpp.Id, cpp.TelephoneNumber); }
        }
        Map<Id, String> cpeIdToEmail = new Map<Id, String>();
        for (ContactPointEmail cpe : emailRecords != null ? emailRecords : new List<ContactPointEmail>()) {
            if (cpeIds.contains(cpe.Id)) { cpeIdToEmail.put(cpe.Id, cpe.EmailAddress); }
        }
        Map<Id, ContactPointAddress> cpaById = new Map<Id, ContactPointAddress>();
        for (ContactPointAddress cpa : addressRecords != null ? addressRecords : new List<ContactPointAddress>()) {
            if (cpaIds.contains(cpa.Id)) { cpaById.put(cpa.Id, cpa); }
        }
        List<OrgSync_Physician_Staging__c> toUpdate = new List<OrgSync_Physician_Staging__c>();
        Set<Id> seenStagingIds = new Set<Id>();
        for (HealthcarePractitionerFacility hpf : hpfs) {
            Id providerAccountId = practitionerIdToAccountId.get(hpf.PractitionerId);
            if (providerAccountId == null) { continue; }
            String compId = buildCompositeExternalId(providerAccountId, hpf.AccountId);
            OrgSync_Physician_Staging__c staging = stagingByExtId.get(compId);
            if (staging == null || seenStagingIds.contains(staging.Id)) { continue; }
            Boolean changed = false;
            if (hpf.Phone__c != null && cppIdToPhone.containsKey(hpf.Phone__c)) {
                String phoneVal = cppIdToPhone.get(hpf.Phone__c);
                if (staging.OrgSync_Phone__c != phoneVal) { staging.OrgSync_Phone__c = phoneVal; changed = true; }
            }
            if (hpf.Email__c != null && cpeIdToEmail.containsKey(hpf.Email__c)) {
                String emailVal = cpeIdToEmail.get(hpf.Email__c);
                if (staging.OrgSync_PersonEmail__c != emailVal) { staging.OrgSync_PersonEmail__c = emailVal; changed = true; }
            }
            if (hpf.Address__c != null && cpaById.containsKey(hpf.Address__c)) {
                ContactPointAddress cpa = cpaById.get(hpf.Address__c);
                if (staging.OrgSync_Mailing_Address__Street__s != cpa.Street) { staging.OrgSync_Mailing_Address__Street__s = cpa.Street; changed = true; }
                if (staging.OrgSync_Mailing_Address__City__s != cpa.City) { staging.OrgSync_Mailing_Address__City__s = cpa.City; changed = true; }
                if (staging.OrgSync_Mailing_Address__StateCode__s != cpa.StateCode) { staging.OrgSync_Mailing_Address__StateCode__s = cpa.StateCode; changed = true; }
                if (staging.OrgSync_Mailing_Address__PostalCode__s != cpa.PostalCode) { staging.OrgSync_Mailing_Address__PostalCode__s = cpa.PostalCode; changed = true; }
            }
            if (changed) {
                seenStagingIds.add(staging.Id);
                toUpdate.add(staging);
            }
        }
        upsertStagingWithReverseSyncFlag(toUpdate, 'syncContactPointsToStagingBulk');
    }

    /**
     * @description Bulk clear: removes Phone, Email, Address from staging when primary HPF-linked contact points are deleted.
     * Uses 1 HPF + 1 Account + 1 Staging query instead of 9 when all three clear methods run separately.
     * @param phoneRecords Deleted ContactPointPhone list
     * @param emailRecords Deleted ContactPointEmail list
     * @param addressRecords Deleted ContactPointAddress list
     */
    public void clearStagingOnDeleteBulk(
        List<ContactPointPhone> phoneRecords,
        List<ContactPointEmail> emailRecords,
        List<ContactPointAddress> addressRecords
    ) {
        Set<Id> cppIds = new Set<Id>();
        Set<Id> cpeIds = new Set<Id>();
        Set<Id> cpaIds = new Set<Id>();
        for (ContactPointPhone cpp : phoneRecords != null ? phoneRecords : new List<ContactPointPhone>()) {
            if (cpp.Id != null && cpp.IsPrimary == true) { cppIds.add(cpp.Id); }
        }
        for (ContactPointEmail cpe : emailRecords != null ? emailRecords : new List<ContactPointEmail>()) {
            if (cpe.Id != null && cpe.IsPrimary == true) { cpeIds.add(cpe.Id); }
        }
        for (ContactPointAddress cpa : addressRecords != null ? addressRecords : new List<ContactPointAddress>()) {
            if (cpa.Id != null && cpa.IsPrimary == true) { cpaIds.add(cpa.Id); }
        }
        if (cppIds.isEmpty() && cpeIds.isEmpty() && cpaIds.isEmpty()) {
            return;
        }
        List<HealthcarePractitionerFacility> hpfs = queryHpfsByContactPointIds(cppIds, cpeIds, cpaIds);
        if (hpfs.isEmpty()) {
            return;
        }
        Map<Id, Id> practitionerIdToAccountId = getPractitionerIdToProviderAccountId(hpfs);
        Set<String> compositeExtIds = collectCompositeExtIdsFromHpfs(practitionerIdToAccountId, hpfs);
        if (compositeExtIds.isEmpty()) {
            return;
        }
        Map<String, OrgSync_Physician_Staging__c> stagingByExtId = queryStagingByExternalIds(compositeExtIds);
        List<OrgSync_Physician_Staging__c> toUpdate = new List<OrgSync_Physician_Staging__c>();
        Set<Id> seenStagingIds = new Set<Id>();
        for (HealthcarePractitionerFacility hpf : hpfs) {
            Id providerAccountId = practitionerIdToAccountId.get(hpf.PractitionerId);
            if (providerAccountId == null) { continue; }
            String compId = buildCompositeExternalId(providerAccountId, hpf.AccountId);
            OrgSync_Physician_Staging__c staging = stagingByExtId.get(compId);
            if (staging == null || seenStagingIds.contains(staging.Id)) { continue; }
            Boolean changed = false;
            if (hpf.Phone__c != null && cppIds.contains(hpf.Phone__c) && staging.OrgSync_Phone__c != null) {
                staging.OrgSync_Phone__c = null;
                changed = true;
            }
            if (hpf.Email__c != null && cpeIds.contains(hpf.Email__c) && staging.OrgSync_PersonEmail__c != null) {
                staging.OrgSync_PersonEmail__c = null;
                changed = true;
            }
            if (hpf.Address__c != null && cpaIds.contains(hpf.Address__c) && hasMailingAddress(staging)) {
                staging.OrgSync_Mailing_Address__Street__s = null;
                staging.OrgSync_Mailing_Address__City__s = null;
                staging.OrgSync_Mailing_Address__StateCode__s = null;
                staging.OrgSync_Mailing_Address__PostalCode__s = null;
                changed = true;
            }
            if (changed) {
                seenStagingIds.add(staging.Id);
                toUpdate.add(staging);
            }
        }
        upsertStagingWithReverseSyncFlag(toUpdate, 'clearStagingOnDeleteBulk');
    }

    private List<HealthcarePractitionerFacility> queryHpfsByContactPointIds(Set<Id> cppIds, Set<Id> cpeIds, Set<Id> cpaIds) {
        return [
            SELECT Id, Phone__c, Email__c, Address__c, PractitionerId, AccountId
            FROM HealthcarePractitionerFacility
            WHERE (Phone__c IN :cppIds OR Email__c IN :cpeIds OR Address__c IN :cpaIds)
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description Sync primary ContactPointEmail linked to HPF to Physician Staging (OrgSync_PersonEmail__c).
     * Only CPE that is primary AND linked via HPF.Email__c is synced.
     * @param emailRecords ContactPointEmail List
     */
    public void syncContactPointEmailToStaging(List<ContactPointEmail> emailRecords) {
        if (emailRecords.isEmpty()) {
            return;
        }
        Set<Id> cpeIds = new Set<Id>();
        for (ContactPointEmail cpe : emailRecords) {
            if (cpe.Id != null && cpe.IsPrimary == true) {
                cpeIds.add(cpe.Id);
            }
        }
        if (cpeIds.isEmpty()) {
            return;
        }
        syncEmailViaHPF(cpeIds, emailRecords);
    }

    /**
     * @description Sync CPE to staging via HPF.Email__c lookup.
     */
    private void syncEmailViaHPF(Set<Id> cpeIds, List<ContactPointEmail> emailRecords) {
        Map<Id, String> cpeIdToEmail = new Map<Id, String>();
        for (ContactPointEmail cpe : emailRecords) {
            if (cpeIds.contains(cpe.Id)) {
                cpeIdToEmail.put(cpe.Id, cpe.EmailAddress);
            }
        }
        List<HealthcarePractitionerFacility> hpfs = [
            SELECT Id, Email__c, PractitionerId, AccountId
            FROM HealthcarePractitionerFacility
            WHERE Email__c IN :cpeIds
            WITH SYSTEM_MODE
        ];
        if (hpfs.isEmpty()) {
            return;
        }
        Map<Id, Id> practitionerIdToAccountId = getPractitionerIdToProviderAccountId(hpfs);
        Set<String> compositeExtIds = collectCompositeExtIdsFromHpfs(practitionerIdToAccountId, hpfs);
        if (compositeExtIds.isEmpty()) {
            return;
        }
        Map<String, OrgSync_Physician_Staging__c> stagingByExtId = queryStagingByExternalIds(compositeExtIds);
        List<OrgSync_Physician_Staging__c> toUpdate = new List<OrgSync_Physician_Staging__c>();
        for (HealthcarePractitionerFacility hpf : hpfs) {
            Id providerAccountId = practitionerIdToAccountId.get(hpf.PractitionerId);
            if (providerAccountId == null) { continue; }
            String compId = buildCompositeExternalId(providerAccountId, hpf.AccountId);
            OrgSync_Physician_Staging__c staging = stagingByExtId.get(compId);
            if (staging == null) { continue; }
            String newEmail = cpeIdToEmail.get(hpf.Email__c);
            if (newEmail != null && staging.OrgSync_PersonEmail__c != newEmail) {
                staging.OrgSync_PersonEmail__c = newEmail;
                toUpdate.add(staging);
            }
        }
        upsertStagingWithReverseSyncFlag(toUpdate, 'syncContactPointEmailToStaging');
    }

    /** @TestVisible For test injection of org prefix when Custom Setting is unavailable. */
    @TestVisible
    private static String testOrgPrefixOverride;

    private String buildCompositeExternalId(Id providerAccountId, Id practiceAccountId) {
        String prefix = getOrgPrefix();
        if (prefix == null || providerAccountId == null || practiceAccountId == null) {
            return null;
        }
        return prefix + XCDC_Constants.HYPHEN + providerAccountId + XCDC_Constants.HYPHEN + practiceAccountId;
    }

    private String getOrgPrefix() {
        if (Test.isRunningTest() && String.isNotBlank(testOrgPrefixOverride)) {
            return testOrgPrefixOverride;
        }
        XCDC_OrgSettings__c orgSettings = XCDC_OrgSettings__c.getInstance();
        if (orgSettings == null || String.isBlank(orgSettings.ExternalIdOrgprefix__c)) {
            orgSettings = XCDC_OrgSettings__c.getOrgDefaults();
        }
        return (orgSettings != null && String.isNotBlank(orgSettings.ExternalIdOrgprefix__c))
            ? orgSettings.ExternalIdOrgprefix__c
            : null;
    }

    private Set<String> collectCompositeExtIdsFromHpfs(
        Map<Id, Id> practitionerIdToAccountId,
        List<HealthcarePractitionerFacility> hpfs
    ) {
        Set<String> compositeExtIds = new Set<String>();
        for (HealthcarePractitionerFacility hpf : hpfs) {
            Id providerAccountId = practitionerIdToAccountId.get(hpf.PractitionerId);
            if (providerAccountId != null) {
                String compId = buildCompositeExternalId(providerAccountId, hpf.AccountId);
                if (String.isNotBlank(compId)) {
                    compositeExtIds.add(compId);
                }
            }
        }
        return compositeExtIds;
    }

    private Map<Id, Id> getPractitionerIdToProviderAccountId(List<HealthcarePractitionerFacility> hpfs) {
        Set<Id> practitionerIds = new Set<Id>();
        for (HealthcarePractitionerFacility hpf : hpfs) {
            if (hpf.PractitionerId != null) {
                practitionerIds.add(hpf.PractitionerId);
            }
        }
        Map<Id, Id> practitionerIdToAccountId = new Map<Id, Id>();
        for (Account acc : [
            SELECT Id, PersonContactId
            FROM Account
            WHERE PersonContactId IN :practitionerIds
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            WITH SYSTEM_MODE
        ]) {
            practitionerIdToAccountId.put(acc.PersonContactId, acc.Id);
        }
        return practitionerIdToAccountId;
    }

    /**
     * @description Queries Physician Staging by composite External IDs.
     */
    private Map<String, OrgSync_Physician_Staging__c> queryStagingByExternalIds(Set<String> externalIds) {
        if (externalIds == null || externalIds.isEmpty()) {
            return new Map<String, OrgSync_Physician_Staging__c>();
        }
        Map<String, OrgSync_Physician_Staging__c> result = new Map<String, OrgSync_Physician_Staging__c>();
        for (OrgSync_Physician_Staging__c s : [
            SELECT Id, XCDC_ExternalId__c, OrgSync_PersonEmail__c, OrgSync_Phone__c,
                OrgSync_Mailing_Address__Street__s, OrgSync_Mailing_Address__City__s,
                OrgSync_Mailing_Address__StateCode__s, OrgSync_Mailing_Address__PostalCode__s
            FROM OrgSync_Physician_Staging__c
            WHERE XCDC_ExternalId__c IN :externalIds
            WITH SYSTEM_MODE
        ]) {
            result.put(s.XCDC_ExternalId__c, s);
        }
        return result;
    }

    private void performStagingUpsert(List<OrgSync_Physician_Staging__c> records, String methodName) {
        List<OrgSync_Physician_Staging__c> deduped = dedupeStagingById(records);
        if (deduped.isEmpty()) {
            return;
        }
        List<Database.UpsertResult> results = Database.upsert(deduped, false, AccessLevel.SYSTEM_MODE);
        OrgSync_LoggingUtility.handleDatabaseResults(results, deduped, new Map<String, String>{
            'className' => 'OrgSync_PhysicianDemographicsSync',
            'methodName' => methodName,
            'operationDescription' => 'updating Physician Staging Record'
        });
    }

    private List<OrgSync_Physician_Staging__c> dedupeStagingById(List<OrgSync_Physician_Staging__c> records) {
        if (records == null || records.isEmpty()) {
            return new List<OrgSync_Physician_Staging__c>();
        }
        Set<Id> seenIds = new Set<Id>();
        List<OrgSync_Physician_Staging__c> deduped = new List<OrgSync_Physician_Staging__c>();
        for (OrgSync_Physician_Staging__c r : records) {
            if (r.Id != null && !seenIds.contains(r.Id)) {
                seenIds.add(r.Id);
                deduped.add(r);
            }
        }
        return deduped;
    }

    private void upsertStagingWithReverseSyncFlag(List<OrgSync_Physician_Staging__c> toUpdate, String methodName) {
        if (toUpdate.isEmpty()) {
            return;
        }
        OrgSync_UtilityService.isProviderContactPointReverseSyncInProgress = true;
        try {
            performStagingUpsert(toUpdate, methodName);
        } finally {
            OrgSync_UtilityService.isProviderContactPointReverseSyncInProgress = false;
        }
    }

    /**
     * @description Sync primary ContactPointAddress linked to HPF to Physician Staging (OrgSync_Mailing_Address__*).
     * Only CPA that is IsPrimary AND linked via HPF.Address__c is synced (no AddressType filter).
     * @param addressRecords ContactPointAddress List
     */
    public void syncContactPointAddressToStaging(List<ContactPointAddress> addressRecords) {
        if (addressRecords.isEmpty()) {
            return;
        }
        Set<Id> cpaIds = new Set<Id>();
        for (ContactPointAddress cpa : addressRecords) {
            if (cpa.Id != null && cpa.IsPrimary == true) {
                cpaIds.add(cpa.Id);
            }
        }
        if (cpaIds.isEmpty()) {
            return;
        }
        List<HealthcarePractitionerFacility> hpfs = [
            SELECT Id, Address__c, PractitionerId, AccountId
            FROM HealthcarePractitionerFacility
            WHERE Address__c IN :cpaIds
            WITH SYSTEM_MODE
        ];
        if (hpfs.isEmpty()) {
            return;
        }
        Map<Id, Id> practitionerIdToAccountId = getPractitionerIdToProviderAccountId(hpfs);
        Set<String> compositeExtIds = collectCompositeExtIdsFromHpfs(practitionerIdToAccountId, hpfs);
        if (compositeExtIds.isEmpty()) {
            return;
        }
        Map<String, OrgSync_Physician_Staging__c> stagingByExtId = queryStagingByExternalIds(compositeExtIds);
        Map<Id, ContactPointAddress> cpaById = new Map<Id, ContactPointAddress>();
        for (ContactPointAddress cpa : addressRecords) {
            if (cpaIds.contains(cpa.Id)) {
                cpaById.put(cpa.Id, cpa);
            }
        }
        List<OrgSync_Physician_Staging__c> toUpdate = new List<OrgSync_Physician_Staging__c>();
        for (HealthcarePractitionerFacility hpf : hpfs) {
            Id providerAccountId = practitionerIdToAccountId.get(hpf.PractitionerId);
            if (providerAccountId == null) { continue; }
            String compId = buildCompositeExternalId(providerAccountId, hpf.AccountId);
            OrgSync_Physician_Staging__c staging = stagingByExtId.get(compId);
            if (staging == null) { continue; }
            ContactPointAddress cpa = cpaById.get(hpf.Address__c);
            if (cpa == null) { continue; }
            Boolean updateNeeded = false;
            if (staging.OrgSync_Mailing_Address__Street__s != cpa.Street) { staging.OrgSync_Mailing_Address__Street__s = cpa.Street; updateNeeded = true; }
            if (staging.OrgSync_Mailing_Address__City__s != cpa.City) { staging.OrgSync_Mailing_Address__City__s = cpa.City; updateNeeded = true; }
            if (staging.OrgSync_Mailing_Address__StateCode__s != cpa.StateCode) { staging.OrgSync_Mailing_Address__StateCode__s = cpa.StateCode; updateNeeded = true; }
            if (staging.OrgSync_Mailing_Address__PostalCode__s != cpa.PostalCode) { staging.OrgSync_Mailing_Address__PostalCode__s = cpa.PostalCode; updateNeeded = true; }
            if (updateNeeded) {
                toUpdate.add(staging);
            }
        }
        upsertStagingWithReverseSyncFlag(toUpdate, 'syncContactPointAddressToStaging');
    }

    /**
     * @description Sync primary ContactPointPhone linked to HPF to Physician Staging (OrgSync_Phone__c).
     * Only CPP that is primary AND linked via HPF.Phone__c is synced to OrgSync_Phone__c.
     * @param phoneRecords ContactPointPhone List
     */
    public void syncContactPointPhoneToStaging(List<ContactPointPhone> phoneRecords) {
        if (phoneRecords.isEmpty()) {
            return;
        }
        Set<Id> cppIds = new Set<Id>();
        for (ContactPointPhone cpp : phoneRecords) {
            if (cpp.Id != null && cpp.IsPrimary == true) {
                cppIds.add(cpp.Id);
            }
        }
        if (cppIds.isEmpty()) {
            return;
        }
        List<HealthcarePractitionerFacility> hpfs = [
            SELECT Id, Phone__c, PractitionerId, AccountId
            FROM HealthcarePractitionerFacility
            WHERE Phone__c IN :cppIds
            WITH SYSTEM_MODE
        ];
        if (hpfs.isEmpty()) {
            return;
        }
        Map<Id, Id> practitionerIdToAccountId = getPractitionerIdToProviderAccountId(hpfs);
        Set<String> compositeExtIds = collectCompositeExtIdsFromHpfs(practitionerIdToAccountId, hpfs);
        if (compositeExtIds.isEmpty()) {
            return;
        }
        Map<String, OrgSync_Physician_Staging__c> stagingByExtId = queryStagingByExternalIds(compositeExtIds);
        Map<Id, String> cppIdToPhone = new Map<Id, String>();
        for (ContactPointPhone cpp : phoneRecords) {
            if (cppIds.contains(cpp.Id)) {
                cppIdToPhone.put(cpp.Id, cpp.TelephoneNumber);
            }
        }
        List<OrgSync_Physician_Staging__c> toUpdate = new List<OrgSync_Physician_Staging__c>();
        for (HealthcarePractitionerFacility hpf : hpfs) {
            Id providerAccountId = practitionerIdToAccountId.get(hpf.PractitionerId);
            if (providerAccountId == null) { continue; }
            String compId = buildCompositeExternalId(providerAccountId, hpf.AccountId);
            OrgSync_Physician_Staging__c staging = stagingByExtId.get(compId);
            if (staging == null) { continue; }
            String newPhone = cppIdToPhone.get(hpf.Phone__c);
            if (newPhone != null && staging.OrgSync_Phone__c != newPhone) {
                staging.OrgSync_Phone__c = newPhone;
                toUpdate.add(staging);
            }
        }
        upsertStagingWithReverseSyncFlag(toUpdate, 'syncContactPointPhoneToStaging');
    }

    /**
     * @description Clears OrgSync_Mailing_Address__* when a primary ContactPointAddress linked to HPF is deleted.
     * @param deletedAddressRecords List of ContactPointAddress records from Trigger.old
     */
    public void clearStagingAddressOnDelete(List<ContactPointAddress> deletedAddressRecords) {
        Set<Id> cpaIds = new Set<Id>();
        for (ContactPointAddress cpa : deletedAddressRecords) {
            if (cpa.Id != null && cpa.IsPrimary == true) {
                cpaIds.add(cpa.Id);
            }
        }
        if (cpaIds.isEmpty()) {
            return;
        }
        clearStagingAddressViaHPF(cpaIds);
    }

    /**
     * @description Clears mailing address on staging for HPFs that had Address__c pointing to deleted CPAs.
     */
    private void clearStagingAddressViaHPF(Set<Id> deletedCpaIds) {
        List<HealthcarePractitionerFacility> hpfs = [
            SELECT Id, Address__c, PractitionerId, AccountId
            FROM HealthcarePractitionerFacility
            WHERE Address__c IN :deletedCpaIds
            WITH SYSTEM_MODE
        ];
        if (hpfs.isEmpty()) {
            return;
        }
        Map<Id, Id> practitionerIdToAccountId = getPractitionerIdToProviderAccountId(hpfs);
        Set<String> compositeExtIds = collectCompositeExtIdsFromHpfs(practitionerIdToAccountId, hpfs);
        Map<String, OrgSync_Physician_Staging__c> stagingByExtId = queryStagingByExternalIds(compositeExtIds);
        List<OrgSync_Physician_Staging__c> toUpdate = new List<OrgSync_Physician_Staging__c>();
        for (HealthcarePractitionerFacility hpf : hpfs) {
            Id providerAccountId = practitionerIdToAccountId.get(hpf.PractitionerId);
            if (providerAccountId == null) { continue; }
            String compId = buildCompositeExternalId(providerAccountId, hpf.AccountId);
            OrgSync_Physician_Staging__c staging = stagingByExtId.get(compId);
            if (staging == null) { continue; }
            if (hasMailingAddress(staging)) {
                staging.OrgSync_Mailing_Address__Street__s = null;
                staging.OrgSync_Mailing_Address__City__s = null;
                staging.OrgSync_Mailing_Address__StateCode__s = null;
                staging.OrgSync_Mailing_Address__PostalCode__s = null;
                toUpdate.add(staging);
            }
        }
        upsertStagingWithReverseSyncFlag(toUpdate, 'clearStagingAddressOnDelete');
    }

    private Boolean hasMailingAddress(OrgSync_Physician_Staging__c s) {
        return s.OrgSync_Mailing_Address__Street__s != null || s.OrgSync_Mailing_Address__City__s != null
            || s.OrgSync_Mailing_Address__StateCode__s != null || s.OrgSync_Mailing_Address__PostalCode__s != null;
    }

    /**
     * @description Clears OrgSync_PersonEmail__c when a ContactPointEmail linked to HPF is deleted.
     * @param deletedEmailRecords List of ContactPointEmail records from Trigger.old
     */
    public void clearStagingEmailOnDelete(List<ContactPointEmail> deletedEmailRecords) {
        Set<Id> cpeIds = new Set<Id>();
        for (ContactPointEmail cpe : deletedEmailRecords) {
            if (cpe.Id != null && cpe.IsPrimary == true) {
                cpeIds.add(cpe.Id);
            }
        }
        if (cpeIds.isEmpty()) {
            return;
        }
        List<HealthcarePractitionerFacility> hpfs = [
            SELECT Id, Email__c, PractitionerId, AccountId
            FROM HealthcarePractitionerFacility
            WHERE Email__c IN :cpeIds
            WITH SYSTEM_MODE
        ];
        if (hpfs.isEmpty()) {
            return;
        }
        Map<Id, Id> practitionerIdToAccountId = getPractitionerIdToProviderAccountId(hpfs);
        Set<String> compositeExtIds = collectCompositeExtIdsFromHpfs(practitionerIdToAccountId, hpfs);
        Map<String, OrgSync_Physician_Staging__c> stagingByExtId = queryStagingByExternalIds(compositeExtIds);
        List<OrgSync_Physician_Staging__c> toUpdate = new List<OrgSync_Physician_Staging__c>();
        for (HealthcarePractitionerFacility hpf : hpfs) {
            Id providerAccountId = practitionerIdToAccountId.get(hpf.PractitionerId);
            if (providerAccountId == null) { continue; }
            String compId = buildCompositeExternalId(providerAccountId, hpf.AccountId);
            OrgSync_Physician_Staging__c staging = stagingByExtId.get(compId);
            if (staging != null && staging.OrgSync_PersonEmail__c != null) {
                staging.OrgSync_PersonEmail__c = null;
                toUpdate.add(staging);
            }
        }
        upsertStagingWithReverseSyncFlag(toUpdate, 'clearStagingEmailOnDelete');
    }

    /**
     * @description Clears OrgSync_Phone__c when a ContactPointPhone linked to HPF is deleted.
     * @param deletedPhoneRecords List of ContactPointPhone records from Trigger.old
     */
    public void clearStagingPhoneOnDelete(List<ContactPointPhone> deletedPhoneRecords) {
        Set<Id> cppIds = new Set<Id>();
        for (ContactPointPhone cpp : deletedPhoneRecords) {
            if (cpp.Id != null && cpp.IsPrimary == true) {
                cppIds.add(cpp.Id);
            }
        }
        if (cppIds.isEmpty()) {
            return;
        }
        List<HealthcarePractitionerFacility> hpfs = [
            SELECT Id, Phone__c, PractitionerId, AccountId
            FROM HealthcarePractitionerFacility
            WHERE Phone__c IN :cppIds
            WITH SYSTEM_MODE
        ];
        if (hpfs.isEmpty()) {
            return;
        }
        Map<Id, Id> practitionerIdToAccountId = getPractitionerIdToProviderAccountId(hpfs);
        Set<String> compositeExtIds = collectCompositeExtIdsFromHpfs(practitionerIdToAccountId, hpfs);
        Map<String, OrgSync_Physician_Staging__c> stagingByExtId = queryStagingByExternalIds(compositeExtIds);
        List<OrgSync_Physician_Staging__c> toUpdate = new List<OrgSync_Physician_Staging__c>();
        for (HealthcarePractitionerFacility hpf : hpfs) {
            Id providerAccountId = practitionerIdToAccountId.get(hpf.PractitionerId);
            if (providerAccountId == null) { continue; }
            String compId = buildCompositeExternalId(providerAccountId, hpf.AccountId);
            OrgSync_Physician_Staging__c staging = stagingByExtId.get(compId);
            if (staging != null && staging.OrgSync_Phone__c != null) {
                staging.OrgSync_Phone__c = null;
                toUpdate.add(staging);
            }
        }
        upsertStagingWithReverseSyncFlag(toUpdate, 'clearStagingPhoneOnDelete');
    }

    /**
     * @description Syncs Physician Staging Phone, Email, and Mailing Address when HPF contact point
     * lookups (Phone__c, Email__c, Address__c) are updated. Called from HPF trigger on update.
     * @param newRecords List of updated HPF records
     * @param oldRecords Map of old HPF records
     */
    public void syncStagingFromHPFContactPointLookupChange(
        List<HealthcarePractitionerFacility> newRecords,
        Map<Id, HealthcarePractitionerFacility> oldRecords
    ) {
        if (newRecords == null || newRecords.isEmpty() || oldRecords == null || oldRecords.isEmpty()) {
            return;
        }
        List<HealthcarePractitionerFacility> hpfsWithChange = new List<HealthcarePractitionerFacility>();
        Set<Id> cppIds = new Set<Id>();
        Set<Id> cpeIds = new Set<Id>();
        Set<Id> cpaIds = new Set<Id>();
        for (HealthcarePractitionerFacility hpf : newRecords) {
            HealthcarePractitionerFacility oldHpf = oldRecords.get(hpf.Id);
            if (oldHpf == null) { continue; }
            Boolean phoneChanged = hpf.Phone__c != oldHpf.Phone__c;
            Boolean emailChanged = hpf.Email__c != oldHpf.Email__c;
            Boolean addressChanged = hpf.Address__c != oldHpf.Address__c;
            if (phoneChanged || emailChanged || addressChanged) {
                hpfsWithChange.add(hpf);
                if (hpf.Phone__c != null) { cppIds.add(hpf.Phone__c); }
                if (hpf.Email__c != null) { cpeIds.add(hpf.Email__c); }
                if (hpf.Address__c != null) { cpaIds.add(hpf.Address__c); }
            }
        }
        if (hpfsWithChange.isEmpty()) {
            return;
        }
        Map<Id, String> cppIdToPhone = new Map<Id, String>();
        if (!cppIds.isEmpty()) {
            for (ContactPointPhone cpp : [SELECT Id, TelephoneNumber FROM ContactPointPhone WHERE Id IN :cppIds WITH SYSTEM_MODE]) {
                cppIdToPhone.put(cpp.Id, cpp.TelephoneNumber);
            }
        }
        Map<Id, String> cpeIdToEmail = new Map<Id, String>();
        if (!cpeIds.isEmpty()) {
            for (ContactPointEmail cpe : [SELECT Id, EmailAddress FROM ContactPointEmail WHERE Id IN :cpeIds WITH SYSTEM_MODE]) {
                cpeIdToEmail.put(cpe.Id, cpe.EmailAddress);
            }
        }
        Map<Id, ContactPointAddress> cpaById = new Map<Id, ContactPointAddress>();
        if (!cpaIds.isEmpty()) {
            for (ContactPointAddress cpa : [SELECT Id, Street, City, StateCode, PostalCode FROM ContactPointAddress WHERE Id IN :cpaIds WITH SYSTEM_MODE]) {
                cpaById.put(cpa.Id, cpa);
            }
        }
        Map<Id, Id> practitionerIdToAccountId = getPractitionerIdToProviderAccountId(hpfsWithChange);
        Set<String> compositeExtIds = collectCompositeExtIdsFromHpfs(practitionerIdToAccountId, hpfsWithChange);
        if (compositeExtIds.isEmpty()) {
            return;
        }
        Map<String, OrgSync_Physician_Staging__c> stagingByExtId = queryStagingByExternalIds(compositeExtIds);
        List<OrgSync_Physician_Staging__c> toUpdate = new List<OrgSync_Physician_Staging__c>();
        Set<Id> seenStagingIds = new Set<Id>();
        for (HealthcarePractitionerFacility hpf : hpfsWithChange) {
            Id providerAccountId = practitionerIdToAccountId.get(hpf.PractitionerId);
            if (providerAccountId == null) { continue; }
            String compId = buildCompositeExternalId(providerAccountId, hpf.AccountId);
            OrgSync_Physician_Staging__c staging = stagingByExtId.get(compId);
            if (staging == null || seenStagingIds.contains(staging.Id)) { continue; }
            Boolean changed = false;
            if (hpf.Phone__c != null) {
                String phoneVal = cppIdToPhone.get(hpf.Phone__c);
                if (staging.OrgSync_Phone__c != phoneVal) {
                    staging.OrgSync_Phone__c = phoneVal;
                    changed = true;
                }
            } else if (staging.OrgSync_Phone__c != null) {
                staging.OrgSync_Phone__c = null;
                changed = true;
            }
            if (hpf.Email__c != null) {
                String emailVal = cpeIdToEmail.get(hpf.Email__c);
                if (staging.OrgSync_PersonEmail__c != emailVal) {
                    staging.OrgSync_PersonEmail__c = emailVal;
                    changed = true;
                }
            } else if (staging.OrgSync_PersonEmail__c != null) {
                staging.OrgSync_PersonEmail__c = null;
                changed = true;
            }
            if (hpf.Address__c != null) {
                ContactPointAddress cpa = cpaById.get(hpf.Address__c);
                if (cpa != null) {
                    if (staging.OrgSync_Mailing_Address__Street__s != cpa.Street) { staging.OrgSync_Mailing_Address__Street__s = cpa.Street; changed = true; }
                    if (staging.OrgSync_Mailing_Address__City__s != cpa.City) { staging.OrgSync_Mailing_Address__City__s = cpa.City; changed = true; }
                    if (staging.OrgSync_Mailing_Address__StateCode__s != cpa.StateCode) { staging.OrgSync_Mailing_Address__StateCode__s = cpa.StateCode; changed = true; }
                    if (staging.OrgSync_Mailing_Address__PostalCode__s != cpa.PostalCode) { staging.OrgSync_Mailing_Address__PostalCode__s = cpa.PostalCode; changed = true; }
                }
            } else if (staging.OrgSync_Mailing_Address__Street__s != null || staging.OrgSync_Mailing_Address__City__s != null
                    || staging.OrgSync_Mailing_Address__StateCode__s != null || staging.OrgSync_Mailing_Address__PostalCode__s != null) {
                staging.OrgSync_Mailing_Address__Street__s = null;
                staging.OrgSync_Mailing_Address__City__s = null;
                staging.OrgSync_Mailing_Address__StateCode__s = null;
                staging.OrgSync_Mailing_Address__PostalCode__s = null;
                changed = true;
            }
            if (changed) {
                seenStagingIds.add(staging.Id);
                toUpdate.add(staging);
            }
        }
        upsertStagingWithReverseSyncFlag(toUpdate, 'syncStagingFromHPFContactPointLookupChange');
    }
}