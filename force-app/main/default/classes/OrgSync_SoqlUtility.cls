/**
 * @description Centralized SOQL utility for OrgSync. Ensures each query runs once per transaction
 *              to minimize SOQL count and avoid hitting governor limits.
 * Created Date : Feb 2026
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Feb 2026            Ramesh Kumar            Initial Version
 * V1.0.1       Feb 2026            Ramesh Kumar            CPE/CPP ordering: IsPrimary, CreatedDate (fix demotion sync)
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount,PMD.CognitiveComplexity')
public inherited sharing class OrgSync_SoqlUtility {

    private static Id cachedGuardianRoleId;
    private static Id cachedAuthorizedCallerRoleId;
    private static Boolean guardianAuthCallerRolesLoaded = false;
    private static Map<String, List<Account>> cachedPatientDelegateByCriteria = new Map<String, List<Account>>();
    private static Map<String, List<Account>> cachedAccountsByIds = new Map<String, List<Account>>();
    private static Map<String, List<Account>> cachedAccountsByExtIds = new Map<String, List<Account>>();
    private static Map<Id, Account> cachedAccountsByIdWithExtIdAndRT = new Map<Id, Account>();
    private static Map<String, List<ContactContactRelation>> cachedCCRs = new Map<String, List<ContactContactRelation>>();
    private static Map<String, List<ContactContactRelation>> cachedCCRsByPatientForGuardianAuthCaller = new Map<String, List<ContactContactRelation>>();
    private static Map<String, List<ContactContactRelation>> cachedCCRsByIdsWithDetails = new Map<String, List<ContactContactRelation>>();
    private static Map<String, List<ContactPointEmail>> cachedContactPointEmails = new Map<String, List<ContactPointEmail>>();
    private static Map<String, List<ContactPointPhone>> cachedContactPointPhones = new Map<String, List<ContactPointPhone>>();
    private static Map<String, OrgSync_Patient_Staging__c> cachedPatientStagingByExtId = new Map<String, OrgSync_Patient_Staging__c>();
    private static Map<Id, String> cachedContactIdToAccountExtId = new Map<Id, String>();
    private static Map<Id, Id> cachedContactToAccountForPatient = new Map<Id, Id>();
    private static Set<Id> cachedMissingContactIdsForPatient = new Set<Id>();

    private static String toCacheKey(Set<String> strSet) {
        if (strSet == null || strSet.isEmpty()) { return ''; }
        List<String> sorted = new List<String>(strSet);
        sorted.sort();
        return String.join(sorted, ',');
    }
    private static String toCacheKeyIds(Set<Id> idSet) {
        if (idSet == null || idSet.isEmpty()) { return ''; }
        List<String> strIds = new List<String>();
        for (Id i : idSet) { strIds.add(String.valueOf(i)); }
        strIds.sort();
        return String.join(strIds, ',');
    }

    /**
     * @description Gets Guardian Role ID (cached per transaction).
     * @return Id Guardian PartyRoleRelation Id or null
     */
    public static Id getGuardianRoleId() {
        loadGuardianAndAuthCallerRoleIds();
        return cachedGuardianRoleId;
    }

    /**
     * @description Gets Authorized Caller Role ID (cached per transaction).
     * @return Id Authorized Caller PartyRoleRelation Id or null
     */
    public static Id getAuthorizedCallerRoleId() {
        loadGuardianAndAuthCallerRoleIds();
        return cachedAuthorizedCallerRoleId;
    }

    /**
     * @description Loads Guardian and Authorized Caller role IDs in a single query (cached per transaction).
     *              One PartyRoleRelation per type: Patient-Legal Guardian-CCR, Authorized Caller-Authorized Caller-CCR.
     */
    private static void loadGuardianAndAuthCallerRoleIds() {
        if (guardianAuthCallerRolesLoaded) {
            return;
        }
        List<PartyRoleRelation> roles = [
            SELECT Id, Name
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE
                OR Name = :ConstantsUtil.AUTHORIZED_CALLER_CCR_ROLE
            WITH SYSTEM_MODE
        ];
        for (PartyRoleRelation r : roles) {
            if (r.Name == ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE) {
                cachedGuardianRoleId = r.Id;
            } else if (r.Name == ConstantsUtil.AUTHORIZED_CALLER_CCR_ROLE) {
                cachedAuthorizedCallerRoleId = r.Id;
            }
        }
        guardianAuthCallerRolesLoaded = true;
    }

    /**
     * @description Gets Patient Delegate accounts by FirstName and LastName (cached).
     * @param firstNames Set of first names
     * @param lastNames Set of last names
     * @return List<Account> Patient Delegate accounts
     */
    public static List<Account> getPatientDelegateAccounts(Set<String> firstNames, Set<String> lastNames) {
        if (firstNames == null || lastNames == null || firstNames.isEmpty() || lastNames.isEmpty()) {
            return new List<Account>();
        }
        String cacheKey = String.join(new List<String>(firstNames), ',') + '|' + String.join(new List<String>(lastNames), ',');
        if (cachedPatientDelegateByCriteria.containsKey(cacheKey)) {
            return cachedPatientDelegateByCriteria.get(cacheKey);
        }
        List<Account> accounts = [
            SELECT Id, FirstName, LastName, PersonEmail, PersonHomePhone, Phone, PersonMobilePhone, PersonContactId
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
                AND FirstName IN :firstNames
                AND LastName IN :lastNames
            WITH SYSTEM_MODE
        ];
        cachedPatientDelegateByCriteria.put(cacheKey, accounts);
        return accounts;
    }

    /**
     * @description Gets Accounts by External IDs with PersonContactId (cached).
     * @param externalIds Set of external IDs
     * @return List<Account> Accounts with PersonContactId
     */
    public static List<Account> getAccountsByExternalIdsWithContact(Set<String> externalIds) {
        if (externalIds == null || externalIds.isEmpty()) {
            return new List<Account>();
        }
        String cacheKey = toCacheKey(externalIds);
        if (cachedAccountsByExtIds.containsKey(cacheKey)) {
            return cachedAccountsByExtIds.get(cacheKey);
        }
        List<Account> accounts = [
            SELECT Id, PersonContactId, XCDC_ExternalId__c
            FROM Account
            WHERE XCDC_ExternalId__c IN :externalIds
            WITH SYSTEM_MODE
        ];
        cachedAccountsByExtIds.put(cacheKey, accounts);
        return accounts;
    }

    /**
     * @description Gets Accounts by IDs with PersonContactId and XCDC_ExternalId__c (for patient contact map) (cached).
     * @param accountIds Set of account IDs
     * @return List<Account> Accounts
     */
    public static List<Account> getAccountsByIdsWithExtId(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return new List<Account>();
        }
        String cacheKey = 'extId_' + toCacheKeyIds(accountIds);
        if (cachedAccountsByExtIds.containsKey(cacheKey)) {
            return cachedAccountsByExtIds.get(cacheKey);
        }
        List<Account> accounts = [
            SELECT Id, PersonContactId, XCDC_ExternalId__c, RecordTypeId
            FROM Account
            WHERE Id IN :accountIds
            WITH SYSTEM_MODE
        ];
        cachedAccountsByExtIds.put(cacheKey, accounts);
        return accounts;
    }

    /**
     * @description Gets Accounts by IDs as Map with RecordType (accumulative cache).
     * @param accountIds Set of Account IDs
     * @return Map<Id, Account> Keyed by Account Id
     */
    public static Map<Id, Account> getAccountsByIdsWithExtIdAndRecordType(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return new Map<Id, Account>();
        }
        Set<Id> idsToQuery = new Set<Id>(accountIds);
        idsToQuery.removeAll(cachedAccountsByIdWithExtIdAndRT.keySet());
        if (!idsToQuery.isEmpty()) {
            for (Account acc : [
                SELECT Id, PersonContactId, XCDC_ExternalId__c, RecordTypeId
                FROM Account
                WHERE Id IN :idsToQuery
                WITH SYSTEM_MODE
            ]) {
                cachedAccountsByIdWithExtIdAndRT.put(acc.Id, acc);
            }
        }
        Map<Id, Account> result = new Map<Id, Account>();
        for (Id accId : accountIds) {
            if (cachedAccountsByIdWithExtIdAndRT.containsKey(accId)) {
                result.put(accId, cachedAccountsByIdWithExtIdAndRT.get(accId));
            }
        }
        return result;
    }

    /**
     * @description Gets Contact to Patient Account ID mapping (accumulative cache).
     *              Only queries for contact IDs not already cached. Used by OrgSync_Patient_ACRService.
     * @param contactIds Set of Contact (PersonContactId) IDs
     * @return Map<Id, Id> Contact Id to Patient Account Id
     */
    public static Map<Id, Id> getContactToAccountMapForPatientContacts(Set<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) {
            return new Map<Id, Id>();
        }
        Set<Id> idsToQuery = new Set<Id>(contactIds);
        idsToQuery.removeAll(cachedContactToAccountForPatient.keySet());
        idsToQuery.removeAll(cachedMissingContactIdsForPatient);
        if (!idsToQuery.isEmpty()) {
            Set<Id> foundContactIds = new Set<Id>();
            for (Account acc : [
                SELECT Id, PersonContactId
                FROM Account
                WHERE PersonContactId IN :idsToQuery
                AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
                WITH SYSTEM_MODE
            ]) {
                if (acc.PersonContactId != null) {
                    cachedContactToAccountForPatient.put(acc.PersonContactId, acc.Id);
                    foundContactIds.add(acc.PersonContactId);
                }
            }
            idsToQuery.removeAll(foundContactIds);
            cachedMissingContactIdsForPatient.addAll(idsToQuery);
        }
        Map<Id, Id> result = new Map<Id, Id>();
        for (Id contactId : contactIds) {
            if (cachedContactToAccountForPatient.containsKey(contactId)) {
                result.put(contactId, cachedContactToAccountForPatient.get(contactId));
            }
        }
        return result;
    }

    /**
     * @description Gets Accounts by IDs with full delegate fields (cached).
     * @param accountIds Set of account IDs
     * @return List<Account> Accounts
     */
    public static List<Account> getAccountsByIdsWithContact(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return new List<Account>();
        }
        String cacheKey = toCacheKeyIds(accountIds);
        if (cachedAccountsByIds.containsKey(cacheKey)) {
            return cachedAccountsByIds.get(cacheKey);
        }
        List<Account> accounts = [
            SELECT Id, FirstName, LastName, PersonEmail, PersonHomePhone, Phone, PersonMobilePhone, PersonContactId
            FROM Account
            WHERE Id IN :accountIds
            WITH SYSTEM_MODE
        ];
        cachedAccountsByIds.put(cacheKey, accounts);
        return accounts;
    }

    /**
     * @description Gets ContactContactRelations by external IDs or patient contact IDs (cached).
     *              Single query when both criteria provided to reduce SOQL.
     * @param ccrExternalIds Set of CCR external IDs (e.g. patientExtId_1)
     * @param patientContactIds Set of patient contact IDs
     * @return List<ContactContactRelation> CCR records
     */
    public static List<ContactContactRelation> getContactContactRelations(Set<String> ccrExternalIds, Set<Id> patientContactIds) {
        if ((ccrExternalIds == null || ccrExternalIds.isEmpty()) && (patientContactIds == null || patientContactIds.isEmpty())) {
            return new List<ContactContactRelation>();
        }
        String cacheKey = toCacheKey(ccrExternalIds) + '_' + toCacheKeyIds(patientContactIds);
        if (cachedCCRs.containsKey(cacheKey)) {
            return cachedCCRs.get(cacheKey);
        }
        List<ContactContactRelation> ccrs;
        if (ccrExternalIds != null && !ccrExternalIds.isEmpty() && patientContactIds != null && !patientContactIds.isEmpty()) {
            ccrs = [
                SELECT Id, XCDC_ExternalId__c, ContactId, RelatedContactId, IsActive, OrgSync_Guardian_Sequence__c
                FROM ContactContactRelation
                WHERE XCDC_ExternalId__c IN :ccrExternalIds
                    OR ContactId IN :patientContactIds
                WITH SYSTEM_MODE
            ];
        } else if (ccrExternalIds != null && !ccrExternalIds.isEmpty()) {
            ccrs = [
                SELECT Id, XCDC_ExternalId__c, ContactId, RelatedContactId, IsActive, OrgSync_Guardian_Sequence__c
                FROM ContactContactRelation
                WHERE XCDC_ExternalId__c IN :ccrExternalIds
                WITH SYSTEM_MODE
            ];
        } else {
            ccrs = [
                SELECT Id, XCDC_ExternalId__c, ContactId, RelatedContactId, IsActive, OrgSync_Guardian_Sequence__c
                FROM ContactContactRelation
                WHERE ContactId IN :patientContactIds
                WITH SYSTEM_MODE
            ];
        }
        cachedCCRs.put(cacheKey, ccrs);
        return ccrs;
    }

    /**
     * @description Gets ContactContactRelations by IDs with RelatedContact and Contact.Account for sync (cached).
     * @param ccrIds Set of CCR record IDs
     * @return List<ContactContactRelation> CCR records with RelatedContact and Contact.Account.XCDC_ExternalId__c
     */
    public static List<ContactContactRelation> getContactContactRelationsByIdsWithDetails(Set<Id> ccrIds) {
        if (ccrIds == null || ccrIds.isEmpty()) {
            return new List<ContactContactRelation>();
        }
        String cacheKey = 'byId_' + toCacheKeyIds(ccrIds);
        if (cachedCCRsByIdsWithDetails.containsKey(cacheKey)) {
            return cachedCCRsByIdsWithDetails.get(cacheKey);
        }
        List<ContactContactRelation> ccrs = [
            SELECT Id, ContactId, RelatedContactId, OrgSync_Guardian_Sequence__c,
                Contact.Account.XCDC_ExternalId__c,
                RelatedContact.Name, RelatedContact.FirstName, RelatedContact.LastName,
                RelatedContact.Email, RelatedContact.HomePhone, RelatedContact.Phone, RelatedContact.MobilePhone
            FROM ContactContactRelation
            WHERE Id IN :ccrIds
            WITH SYSTEM_MODE
        ];
        cachedCCRsByIdsWithDetails.put(cacheKey, ccrs);
        return ccrs;
    }

    /**
     * @description Gets Guardian CCRs with OrgSync_Guardian_Sequence__c 1 or 2 for given patient contact IDs (cached).
     *              Uses shared CCR cache with getCCRsForAuthorizedCallersSync to reduce SOQL.
     * @param patientContactIds Set of patient Contact IDs
     * @param guardianRoleId PartyRoleRelation Id for Patient-Legal Guardian-CCR
     * @return List<ContactContactRelation> CCR records with RelatedContact fields
     */
    public static List<ContactContactRelation> getGuardianCCRsWithSequence(Set<Id> patientContactIds, Id guardianRoleId) {
        if (patientContactIds == null || patientContactIds.isEmpty() || guardianRoleId == null) {
            return new List<ContactContactRelation>();
        }
        List<ContactContactRelation> allCCRs = loadCCRsByPatientForGuardianAuthCaller(patientContactIds);
        List<ContactContactRelation> filtered = new List<ContactContactRelation>();
        for (ContactContactRelation ccr : allCCRs) {
            if (ccr.PartyRoleRelationId == guardianRoleId
                && ccr.OrgSync_Guardian_Sequence__c != null
                && (ccr.OrgSync_Guardian_Sequence__c == 1 || ccr.OrgSync_Guardian_Sequence__c == 2)) {
                filtered.add(ccr);
            }
        }
        return filtered;
    }

    /**
     * @description Gets active CCRs with Guardian or Authorized Caller role for building OrgSync_Authorized_Callers__c (cached).
     *              Uses shared CCR cache with getGuardianCCRsWithSequence to reduce SOQL.
     * @param patientContactIds Set of patient Contact IDs
     * @param roleIds Set of PartyRoleRelation IDs (Guardian + Authorized Caller)
     * @return List<ContactContactRelation> CCR records with RelatedContact.FirstName, RelatedContact.LastName
     */
    public static List<ContactContactRelation> getCCRsForAuthorizedCallersSync(Set<Id> patientContactIds, Set<Id> roleIds) {
        if (patientContactIds == null || patientContactIds.isEmpty() || roleIds == null || roleIds.isEmpty()) {
            return new List<ContactContactRelation>();
        }
        List<ContactContactRelation> allCCRs = loadCCRsByPatientForGuardianAuthCaller(patientContactIds);
        List<ContactContactRelation> filtered = new List<ContactContactRelation>();
        for (ContactContactRelation ccr : allCCRs) {
            if (roleIds.contains(ccr.PartyRoleRelationId)) {
                filtered.add(ccr);
            }
        }
        return filtered;
    }

    /**
     * @description Loads CCRs for patientContactIds with Guardian or Authorized Caller role (single query, cached).
     *              Superset of fields used by getGuardianCCRsWithSequence and getCCRsForAuthorizedCallersSync.
     * @param patientContactIds Set of patient Contact IDs
     * @return List<ContactContactRelation> CCR records with Guardian or Authorized Caller role
     */
    private static List<ContactContactRelation> loadCCRsByPatientForGuardianAuthCaller(Set<Id> patientContactIds) {
        if (patientContactIds == null || patientContactIds.isEmpty()) {
            return new List<ContactContactRelation>();
        }
        String cacheKey = toCacheKeyIds(patientContactIds);
        if (cachedCCRsByPatientForGuardianAuthCaller.containsKey(cacheKey)) {
            return cachedCCRsByPatientForGuardianAuthCaller.get(cacheKey);
        }
        Id guardianId = getGuardianRoleId();
        Id authCallerId = getAuthorizedCallerRoleId();
        Set<Id> roleIds = new Set<Id>();
        if (guardianId != null) { roleIds.add(guardianId); }
        if (authCallerId != null) { roleIds.add(authCallerId); }
        if (roleIds.isEmpty()) {
            cachedCCRsByPatientForGuardianAuthCaller.put(cacheKey, new List<ContactContactRelation>());
            return cachedCCRsByPatientForGuardianAuthCaller.get(cacheKey);
        }
        List<ContactContactRelation> ccrs = [
            SELECT Id, ContactId, RelatedContactId, PartyRoleRelationId, OrgSync_Guardian_Sequence__c, XCDC_ExternalId__c,
                Contact.Account.XCDC_ExternalId__c,
                RelatedContact.Name, RelatedContact.FirstName, RelatedContact.LastName,
                RelatedContact.Email, RelatedContact.HomePhone, RelatedContact.Phone, RelatedContact.MobilePhone
            FROM ContactContactRelation
            WHERE ContactId IN :patientContactIds
                AND PartyRoleRelationId IN :roleIds
            WITH SYSTEM_MODE
        ];
        cachedCCRsByPatientForGuardianAuthCaller.put(cacheKey, ccrs);
        return ccrs;
    }

    /**
     * @description Gets Guardian CCRs where RelatedContact.AccountId (Patient Delegate) is in the given set.
     *              Returns CCRs with Contact.Account.XCDC_ExternalId__c and OrgSync_Guardian_Sequence__c for Patient Stage sync.
     * @param delegateAccountIds Set of Patient Delegate Account IDs (CPE/CPP ParentId)
     * @return List<ContactContactRelation> CCRs with Contact.Account.XCDC_ExternalId__c, OrgSync_Guardian_Sequence__c
     */
    public static List<ContactContactRelation> getGuardianCCRsByDelegateAccountIds(Set<Id> delegateAccountIds) {
        if (delegateAccountIds == null || delegateAccountIds.isEmpty()) {
            return new List<ContactContactRelation>();
        }
        Id guardianRoleId = getGuardianRoleId();
        if (guardianRoleId == null) {
            return new List<ContactContactRelation>();
        }
        return [
            SELECT Id, ContactId, RelatedContact.AccountId, OrgSync_Guardian_Sequence__c, Contact.Account.XCDC_ExternalId__c
            FROM ContactContactRelation
            WHERE RelatedContact.AccountId IN :delegateAccountIds
                AND PartyRoleRelationId = :guardianRoleId
                AND OrgSync_Guardian_Sequence__c IN (1, 2)
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description Gets ContactPointEmail records by parent account IDs (cached).
     *              Ordered by IsPrimary, PreferenceRank, CreatedDate to identify the "latest" record
     *              (avoids LastModifiedDate which is skewed by system demotion updates).
     * @param parentIds Set of parent (Account) IDs
     * @return List<ContactPointEmail> Contact point emails
     */
    public static List<ContactPointEmail> getContactPointEmailsByParentIds(Set<Id> parentIds) {
        if (parentIds == null || parentIds.isEmpty()) {
            return new List<ContactPointEmail>();
        }
        String cacheKey = toCacheKeyIds(parentIds);
        if (cachedContactPointEmails.containsKey(cacheKey)) {
            return cachedContactPointEmails.get(cacheKey);
        }
        List<ContactPointEmail> emails = [
            SELECT Id, ParentId, PreferenceRank, EmailAddress, IsPrimary
            FROM ContactPointEmail
            WHERE ParentId IN :parentIds
            WITH SYSTEM_MODE
            ORDER BY IsPrimary DESC NULLS LAST, PreferenceRank ASC NULLS LAST, CreatedDate DESC
        ];
        cachedContactPointEmails.put(cacheKey, emails);
        return emails;
    }

    /**
     * @description Gets ContactPointPhone records by parent account IDs (cached).
     *              Ordered by IsPrimary, CreatedDate to identify the "latest" record
     *              (avoids LastModifiedDate which is skewed by system demotion updates).
     * @param parentIds Set of parent (Account) IDs
     * @return List<ContactPointPhone> Contact point phones
     */
    public static List<ContactPointPhone> getContactPointPhonesByParentIds(Set<Id> parentIds) {
        if (parentIds == null || parentIds.isEmpty()) {
            return new List<ContactPointPhone>();
        }
        String cacheKey = toCacheKeyIds(parentIds);
        if (cachedContactPointPhones.containsKey(cacheKey)) {
            return cachedContactPointPhones.get(cacheKey);
        }
        List<ContactPointPhone> phones = [
            SELECT Id, ParentId, TelephoneNumber, UsageType, IsPrimary
            FROM ContactPointPhone
            WHERE ParentId IN :parentIds
            WITH SYSTEM_MODE
            ORDER BY IsPrimary DESC NULLS LAST, CreatedDate DESC
        ];
        cachedContactPointPhones.put(cacheKey, phones);
        return phones;
    }

    /**
     * @description Gets OrgSync_Patient_Staging__c records by external IDs (cached per transaction).
     *              Only queries for external IDs not already in cache to avoid redundant SOQL.
     * @param accountExternalIds Set of XCDC_ExternalId__c values
     * @return Map<String, OrgSync_Patient_Staging__c> Keyed by XCDC_ExternalId__c
     */
    public static Map<String, OrgSync_Patient_Staging__c> getPatientStagingByExternalIds(Set<String> accountExternalIds) {
        if (accountExternalIds == null || accountExternalIds.isEmpty()) {
            return new Map<String, OrgSync_Patient_Staging__c>();
        }
        Set<String> idsToQuery = new Set<String>(accountExternalIds);
        idsToQuery.removeAll(cachedPatientStagingByExtId.keySet());
        if (!idsToQuery.isEmpty()) {
            List<OrgSync_Patient_Staging__c> stagingList = [
                SELECT Id, XCDC_ExternalId__c, OrgSync_Email_1__c, OrgSync_Home_Phone__c,
                    OrgSync_Work_Phone__c, OrgSync_Mobile_Phone__c, OrgSync_Preferred_Phone_Number__c,
                    OrgSync_Shipping_Address__Street__s, OrgSync_Shipping_Address__City__s,
                    OrgSync_Shipping_Address__StateCode__s, OrgSync_Shipping_Address__PostalCode__s,
                    OrgSync_Billing_Address__Street__s, OrgSync_Billing_Address__City__s,
                    OrgSync_Billing_Address__StateCode__s, OrgSync_Billing_Address__PostalCode__s,
                    OrgSync_Fax__c, OrgSync_Phone__c, OrgSync_Practice__c
                FROM OrgSync_Patient_Staging__c
                WHERE XCDC_ExternalId__c IN :idsToQuery
                WITH SYSTEM_MODE
            ];
            for (OrgSync_Patient_Staging__c staging : stagingList) {
                if (String.isNotBlank(staging.XCDC_ExternalId__c)) {
                    cachedPatientStagingByExtId.put(staging.XCDC_ExternalId__c, staging);
                }
            }
        }
        Map<String, OrgSync_Patient_Staging__c> result = new Map<String, OrgSync_Patient_Staging__c>();
        for (String extId : accountExternalIds) {
            if (cachedPatientStagingByExtId.containsKey(extId)) {
                result.put(extId, cachedPatientStagingByExtId.get(extId));
            }
        }
        return result;
    }

    /**
     * @description Gets Contact Id to Account XCDC_ExternalId__c mapping (cached per transaction).
     *              Only queries for contact IDs not already in cache. Used by syncAuthorizedCallersOnPatientStage
     *              and processRoleSwapFromGuardian to avoid redundant Contact queries.
     * @param contactIds Set of Contact (patient) IDs
     * @return Map<Id, String> Contact Id to Account XCDC_ExternalId__c (empty string if no Account/extId)
     */
    public static Map<Id, String> getContactIdToAccountExternalIdMap(Set<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) {
            return new Map<Id, String>();
        }
        Set<Id> idsToQuery = new Set<Id>(contactIds);
        idsToQuery.removeAll(cachedContactIdToAccountExtId.keySet());
        if (!idsToQuery.isEmpty()) {
            for (Contact c : [
                SELECT Id, Account.XCDC_ExternalId__c
                FROM Contact
                WHERE Id IN :idsToQuery
                AND AccountId != null
                WITH SYSTEM_MODE
            ]) {
                String extId = (c.Account != null && String.isNotBlank(c.Account.XCDC_ExternalId__c))
                    ? c.Account.XCDC_ExternalId__c : '';
                cachedContactIdToAccountExtId.put(c.Id, extId);
            }
            for (Id cid : idsToQuery) {
                if (!cachedContactIdToAccountExtId.containsKey(cid)) {
                    cachedContactIdToAccountExtId.put(cid, '');
                }
            }
        }
        Map<Id, String> result = new Map<Id, String>();
        for (Id cid : contactIds) {
            if (cachedContactIdToAccountExtId.containsKey(cid)) {
                String extId = cachedContactIdToAccountExtId.get(cid);
                if (String.isNotBlank(extId)) {
                    result.put(cid, extId);
                }
            }
        }
        return result;
    }

    /**
     * @description Clears CCR cache for given patient contact IDs. Call after CCR sequence updates
     *              so subsequent queries return fresh data including updated sequences.
     *              Removes only cache entries that contain any of the given IDs (not the whole map).
     * @param patientContactIds Patient Contact IDs whose CCR cache should be cleared
     */
    public static void clearCCRsByPatientCache(Set<Id> patientContactIds) {
        if (patientContactIds == null || patientContactIds.isEmpty()) {
            return;
        }
        List<String> keysToRemove = new List<String>();
        for (String cacheKey : cachedCCRsByPatientForGuardianAuthCaller.keySet()) {
            if (String.isBlank(cacheKey)) {
                continue;
            }
            Set<Id> keyIds = new Set<Id>();
            for (String s : cacheKey.split(',')) {
                if (String.isNotBlank(s)) {
                    keyIds.add((Id) s.trim());
                }
            }
            for (Id pid : patientContactIds) {
                if (keyIds.contains(pid)) {
                    keysToRemove.add(cacheKey);
                    break;
                }
            }
        }
        for (String k : keysToRemove) {
            cachedCCRsByPatientForGuardianAuthCaller.remove(k);
        }
    }

    /**
     * @description Resets cache (call at start of new processing batch if needed).
     */
    public static void resetCache() {
        cachedGuardianRoleId = null;
        cachedAuthorizedCallerRoleId = null;
        guardianAuthCallerRolesLoaded = false;
        cachedPatientDelegateByCriteria.clear();
        cachedAccountsByExtIds.clear();
        cachedAccountsByIds.clear();
        cachedAccountsByIdWithExtIdAndRT.clear();
        cachedCCRs.clear();
        cachedCCRsByPatientForGuardianAuthCaller.clear();
        cachedCCRsByIdsWithDetails.clear();
        cachedContactPointEmails.clear();
        cachedContactPointPhones.clear();
        cachedPatientStagingByExtId.clear();
        cachedContactIdToAccountExtId.clear();
        cachedContactToAccountForPatient.clear();
        cachedMissingContactIdsForPatient.clear();
    }
}