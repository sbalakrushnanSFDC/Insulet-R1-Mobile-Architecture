/**
 * @description Helper class to reduce cyclomatic complexity in LeadConversionConsentMappingQueueable.
 *              Contains query methods, utility methods, and consent processing logic for mapping
 *              ContactPointTypeConsent records from Lead to Patient after lead conversion.
 *
 * @author      Bijayalaxmi Prusty
 * @createdDate 27th Jan 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       27th Jan 2026       Bijayalaxmi Prusty      Initial Version(NGASIM-1905)
 * V1.1.0       20th Feb 2026       Bijayalaxmi Prusty      Updated(NGASIM-2157)
 */
public with sharing class LeadConversionConsentMappingHelper {

    /**
     * @description Wrapper class to hold phone matching context
     */
    public class PhoneMatchContext {
        public String leadMobile;
        public String leadPhone;
    }

    /**
     * @description Queries Lead Individual ContactPointTypeConsent records
     * @param leadIndividualIds Set of Lead Individual Ids
     * @return Map of Individual Id to List of ContactPointTypeConsent records
     */
    public static Map<Id, List<ContactPointTypeConsent>> queryLeadConsents(Set<Id> leadIndividualIds) {
        return queryConsentsByPartyIds(leadIndividualIds, false);
    }

    /**
     * @description Queries Patient Individual ContactPointTypeConsent records
     * @param patientIndividualIds Set of Patient Individual Ids
     * @return Map of Individual Id to List of ContactPointTypeConsent records
     */
    public static Map<Id, List<ContactPointTypeConsent>> queryPatientConsents(Set<Id> patientIndividualIds) {
        return queryConsentsByPartyIds(patientIndividualIds, true);
    }

    /**
     * @description Queries ContactPointTypeConsent records by Party IDs
     * @param partyIds Set of Party Individual Ids
     * @param includeLegalGuardian Whether to include Legal_Guardian__c field
     * @return Map of Individual Id to List of ContactPointTypeConsent records
     */
    private static Map<Id, List<ContactPointTypeConsent>> queryConsentsByPartyIds(Set<Id> partyIds, Boolean includeLegalGuardian) {
        if (partyIds.isEmpty()) {
            return new Map<Id, List<ContactPointTypeConsent>>();
        }

        List<ContactPointTypeConsent> consents = getConsentsByType(partyIds, includeLegalGuardian);
        return buildConsentMap(consents);
    }

    /**
     * @description Gets consents based on type
     * @param partyIds Set of Party Individual Ids
     * @param includeLegalGuardian Whether to include Legal_Guardian__c field
     * @return List of ContactPointTypeConsent records
     */
    private static List<ContactPointTypeConsent> getConsentsByType(Set<Id> partyIds, Boolean includeLegalGuardian) {
        if (includeLegalGuardian) {
            return queryConsentsWithLegalGuardian(partyIds);
        }
        return queryConsentsWithoutLegalGuardian(partyIds);
    }

    /**
     * @description Builds consent map from list
     * @param consents List of ContactPointTypeConsent records
     * @return Map of Individual Id to List of ContactPointTypeConsent records
     */
    private static Map<Id, List<ContactPointTypeConsent>> buildConsentMap(List<ContactPointTypeConsent> consents) {
        Map<Id, List<ContactPointTypeConsent>> consentMap = new Map<Id, List<ContactPointTypeConsent>>();
        for (ContactPointTypeConsent consent : consents) {
            addConsentToMap(consentMap, consent);
        }
        return consentMap;
    }

    /**
     * @description Queries ContactPointTypeConsent records without Legal_Guardian field
     * @param partyIds Set of Party Individual Ids
     * @return List of ContactPointTypeConsent records
     */
    private static List<ContactPointTypeConsent> queryConsentsWithoutLegalGuardian(Set<Id> partyIds) {
        return [
            SELECT Id, Name, PartyId, PrivacyConsentStatus, CaptureDate,
                   DataUsePurposeId, CaptureSource, LastModifiedDate
            FROM ContactPointTypeConsent
            WHERE PartyId IN :partyIds
            AND Name IN :ConstantsUtil.CONSENT_NAMES
            WITH USER_MODE
        ];
    }

    /**
     * @description Queries ContactPointTypeConsent records with Legal_Guardian field
     * @param partyIds Set of Party Individual Ids
     * @return List of ContactPointTypeConsent records
     */
    private static List<ContactPointTypeConsent> queryConsentsWithLegalGuardian(Set<Id> partyIds) {
        return [
            SELECT Id, Name, PartyId, PrivacyConsentStatus, CaptureDate,
                   DataUsePurposeId, CaptureSource, LastModifiedDate, Legal_Guardian__c
            FROM ContactPointTypeConsent
            WHERE PartyId IN :partyIds
            AND Name IN :ConstantsUtil.CONSENT_NAMES
            WITH USER_MODE
        ];
    }

    /**
     * @description Adds consent to the map grouped by PartyId
     * @param consentMap Map to add consent to
     * @param consent ContactPointTypeConsent to add
     */
    private static void addConsentToMap(Map<Id, List<ContactPointTypeConsent>> consentMap, ContactPointTypeConsent consent) {
        if (!consentMap.containsKey(consent.PartyId)) {
            consentMap.put(consent.PartyId, new List<ContactPointTypeConsent>());
        }
        consentMap.get(consent.PartyId).add(consent);
    }

    /**
     * @description Queries Patient ContactPointPhone records
     * @param accountIds Set of Account Ids
     * @return Map of Account Id to List of ContactPointPhone records
     */
    public static Map<Id, List<ContactPointPhone>> queryPatientPhones(Set<Id> accountIds) {
        if (accountIds.isEmpty()) {
            return new Map<Id, List<ContactPointPhone>>();
        }

        List<ContactPointPhone> phones = [
            SELECT Id, ParentId, TelephoneNumber
            FROM ContactPointPhone
            WHERE ParentId IN :accountIds
            WITH USER_MODE
        ];

        return buildPhoneMap(phones);
    }

    /**
     * @description Builds phone map from list
     * @param phones List of ContactPointPhone records
     * @return Map of Account Id to List of ContactPointPhone records
     */
    private static Map<Id, List<ContactPointPhone>> buildPhoneMap(List<ContactPointPhone> phones) {
        Map<Id, List<ContactPointPhone>> phoneMap = new Map<Id, List<ContactPointPhone>>();
        for (ContactPointPhone phone : phones) {
            addPhoneToMap(phoneMap, phone);
        }
        return phoneMap;
    }

    /**
     * @description Adds phone to the map grouped by ParentId
     * @param phoneMap Map to add phone to
     * @param phone ContactPointPhone to add
     */
    private static void addPhoneToMap(Map<Id, List<ContactPointPhone>> phoneMap, ContactPointPhone phone) {
        if (!phoneMap.containsKey(phone.ParentId)) {
            phoneMap.put(phone.ParentId, new List<ContactPointPhone>());
        }
        phoneMap.get(phone.ParentId).add(phone);
    }

    /**
     * @description Queries Lead records for Mobile and Phone fields
     * @param leadIds Set of Lead Ids
     * @return Map of Lead Id to Lead record
     */
    public static Map<Id, Lead> queryLeads(Set<Id> leadIds) {
        if (leadIds.isEmpty()) {
            return new Map<Id, Lead>();
        }

        List<Lead> leads = [
            SELECT Id, MobilePhone, Phone
            FROM Lead
            WHERE Id IN :leadIds
            WITH USER_MODE
        ];

        return buildLeadMap(leads);
    }

    /**
     * @description Builds Lead map from list
     * @param leads List of Lead records
     * @return Map of Lead Id to Lead record
     */
    private static Map<Id, Lead> buildLeadMap(List<Lead> leads) {
        Map<Id, Lead> leadMap = new Map<Id, Lead>();
        for (Lead ld : leads) {
            leadMap.put(ld.Id, ld);
        }
        return leadMap;
    }

    /**
     * @description Queries PatientDelegate Accounts linked to Patient Accounts via ContactContactRelation with GUARDIAN relationship.
     * Only processes Patient RecordType accounts; Provider and other account types return empty map (no Legal Guardian).
     * @param accountIds Set of Account Ids (Patient and/or Provider from lead conversion)
     * @return Map of Patient Account Id to PatientDelegate Account Id
     */
    public static Map<Id, Id> queryPatientDelegateAccounts(Set<Id> accountIds) {
        if (isEmptySet(accountIds)) {
            return new Map<Id, Id>();
        }

        Set<Id> patientAccountIds = filterPatientAccountIds(accountIds);
        if (patientAccountIds.isEmpty()) {
            return new Map<Id, Id>();
        }

        return buildPatientDelegateAccountMap(patientAccountIds);
    }

    /**
     * @description Filters to only Patient RecordType account IDs (excludes Provider, Practice, etc.)
     * @param accountIds Set of Account Ids
     * @return Set of Patient Account Ids only
     */
    private static Set<Id> filterPatientAccountIds(Set<Id> accountIds) {
        List<Account> patientAccounts = [
            SELECT Id
            FROM Account
            WHERE Id IN :accountIds
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
            WITH USER_MODE
        ];
        Set<Id> patientIds = new Set<Id>();
        for (Account acc : patientAccounts) {
            patientIds.add(acc.Id);
        }
        return patientIds;
    }

    /**
     * @description Checks if set is null or empty
     * @param idSet Set to check
     * @return True if null or empty
     */
    private static Boolean isEmptySet(Set<Id> idSet) {
        return idSet == null || idSet.isEmpty();
    }

    /**
     * @description Builds Patient Account to Delegate Account map through Contact relationships
     * @param patientAccountIds Set of Patient Account Ids
     * @return Map of Patient Account Id to PatientDelegate Account Id
     */
    private static Map<Id, Id> buildPatientDelegateAccountMap(Set<Id> patientAccountIds) {
        Map<Id, Id> accountToContactMap = buildAccountToContactMap(patientAccountIds);
        if (accountToContactMap.isEmpty()) {
            return new Map<Id, Id>();
        }

        Id guardianRoleRelationId = getGuardianRoleRelationId();
        if (guardianRoleRelationId == null) {
            return new Map<Id, Id>();
        }

        Map<Id, Id> contactToDelegateAccountMap = queryContactToDelegateAccountMap(
            new Set<Id>(accountToContactMap.values()),
            guardianRoleRelationId
        );

        if (contactToDelegateAccountMap.isEmpty()) {
            return new Map<Id, Id>();
        }

        return buildPatientAccountToDelegateMap(accountToContactMap, contactToDelegateAccountMap);
    }

    /**
     * @description Builds map of Account Id to PersonContactId
     * @param patientAccountIds Set of Patient Account Ids
     * @return Map of Account Id to PersonContactId
     */
    private static Map<Id, Id> buildAccountToContactMap(Set<Id> patientAccountIds) {
        List<Account> patientAccounts = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id IN :patientAccountIds
            AND PersonContactId != null
            WITH USER_MODE
        ];

        return buildAccountContactMap(patientAccounts);
    }

    /**
     * @description Builds Account to Contact map from Account list
     * @param patientAccounts List of Account records
     * @return Map of Account Id to PersonContactId
     */
    private static Map<Id, Id> buildAccountContactMap(List<Account> patientAccounts) {
        Map<Id, Id> accountToContactMap = new Map<Id, Id>();
        for (Account acc : patientAccounts) {
            accountToContactMap.put(acc.Id, acc.PersonContactId);
        }
        return accountToContactMap;
    }

    /**
     * @description Gets Guardian Role Relation Id
     * @return Guardian Role Relation Id or null if not found
     */
    private static Id getGuardianRoleRelationId() {
        List<PartyRoleRelation> guardianRoleRelations = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE
            WITH USER_MODE
            LIMIT 1
        ];
        return extractGuardianRoleRelationId(guardianRoleRelations);
    }

    /**
     * @description Extracts Guardian Role Relation Id from list
     * @param guardianRoleRelations List of PartyRoleRelation records
     * @return Guardian Role Relation Id or null if not found
     */
    private static Id extractGuardianRoleRelationId(List<PartyRoleRelation> guardianRoleRelations) {
        if (guardianRoleRelations.isEmpty()) {
            return null;
        }
        return guardianRoleRelations[0].Id;
    }

    /**
     * @description Queries ContactContactRelation to build Contact to Delegate Account map
     * @param patientContactIds Set of Patient Contact Ids
     * @param guardianRoleRelationId Guardian Role Relation Id
     * @return Map of Contact Id to Delegate Account Id
     */
    private static Map<Id, Id> queryContactToDelegateAccountMap(Set<Id> patientContactIds, Id guardianRoleRelationId) {
        List<ContactContactRelation> ccrList = [
            SELECT Id, ContactId, RelatedContactId, RelatedContact.AccountId
            FROM ContactContactRelation
            WHERE ContactId IN :patientContactIds
            AND PartyRoleRelationId = :guardianRoleRelationId
            AND RelatedContact.AccountId != null
            WITH USER_MODE
        ];

        return buildContactToDelegateAccountMap(ccrList);
    }

    /**
     * @description Builds Contact to Delegate Account map from ContactContactRelation list
     * @param ccrList List of ContactContactRelation records
     * @return Map of Contact Id to Delegate Account Id
     */
    private static Map<Id, Id> buildContactToDelegateAccountMap(List<ContactContactRelation> ccrList) {
        Map<Id, Id> contactToDelegateAccountMap = new Map<Id, Id>();
        for (ContactContactRelation ccr : ccrList) {
            contactToDelegateAccountMap.put(ccr.ContactId, ccr.RelatedContact.AccountId);
        }
        return contactToDelegateAccountMap;
    }

    /**
     * @description Builds Patient Account to Delegate Account map
     * @param accountToContactMap Map of Account Id to Contact Id
     * @param contactToDelegateAccountMap Map of Contact Id to Delegate Account Id
     * @return Map of Patient Account Id to Delegate Account Id
     */
    private static Map<Id, Id> buildPatientAccountToDelegateMap(Map<Id, Id> accountToContactMap, Map<Id, Id> contactToDelegateAccountMap) {
        Map<Id, Id> patientAccountToDelegateAccountMap = new Map<Id, Id>();
        for (Id accountId : accountToContactMap.keySet()) {
            Id patientContactId = accountToContactMap.get(accountId);
            Id delegateAccountId = contactToDelegateAccountMap.get(patientContactId);
            if (delegateAccountId != null) {
                patientAccountToDelegateAccountMap.put(accountId, delegateAccountId);
            }
        }
        return patientAccountToDelegateAccountMap;
    }

    /**
     * @description Finds a ContactPointTypeConsent record by Name
     * @param consents List of ContactPointTypeConsent records
     * @param consentName Name to search for
     * @return ContactPointTypeConsent record or null if not found
     */
    public static ContactPointTypeConsent findConsentByName(List<ContactPointTypeConsent> consents, String consentName) {
        if (consents == null || consents.isEmpty()) {
            return null;
        }
        return findConsentInList(consents, consentName);
    }

    /**
     * @description Finds consent by name in the list
     * @param consents List of ContactPointTypeConsent records
     * @param consentName Name to search for
     * @return ContactPointTypeConsent record or null if not found
     */
    private static ContactPointTypeConsent findConsentInList(List<ContactPointTypeConsent> consents, String consentName) {
        for (ContactPointTypeConsent consent : consents) {
            if (consent.Name == consentName) {
                return consent;
            }
        }
        return null;
    }

    /**
     * @description Checks if Lead phone (Mobile or Phone) exists in Patient ContactPointPhone records
     * @param patientPhones List of Patient ContactPointPhone records
     * @param leadRecord Lead record
     * @return True if Lead phone exists in Patient phones, false otherwise
     */
    public static Boolean checkLeadPhoneInPatientPhones(List<ContactPointPhone> patientPhones, Lead leadRecord) {
        if (!isValidPhoneCheckInput(patientPhones, leadRecord)) {
            return false;
        }

        PhoneMatchContext matchContext = buildPhoneMatchContext(leadRecord);
        return findMatchingPhone(patientPhones, matchContext);
    }

    /**
     * @description Validates input for phone check
     * @param patientPhones List of Patient ContactPointPhone records
     * @param leadRecord Lead record
     * @return True if input is valid for phone check
     */
    private static Boolean isValidPhoneCheckInput(List<ContactPointPhone> patientPhones, Lead leadRecord) {
        return isValidPhoneInput(patientPhones, leadRecord) && hasPhoneNumber(leadRecord);
    }

    /**
     * @description Checks if phone input is valid
     * @param patientPhones List of Patient ContactPointPhone records
     * @param leadRecord Lead record
     * @return True if input is valid
     */
    private static Boolean isValidPhoneInput(List<ContactPointPhone> patientPhones, Lead leadRecord) {
        return patientPhones != null && !patientPhones.isEmpty() && leadRecord != null;
    }

    /**
     * @description Checks if Lead has at least one phone number
     * @param leadRecord Lead record
     * @return True if MobilePhone or Phone is populated
     */
    private static Boolean hasPhoneNumber(Lead leadRecord) {
        return !String.isBlank(leadRecord.MobilePhone) || !String.isBlank(leadRecord.Phone);
    }

    /**
     * @description Builds phone match context from Lead record
     * @param leadRecord Lead record
     * @return PhoneMatchContext with normalized phone numbers
     */
    private static PhoneMatchContext buildPhoneMatchContext(Lead leadRecord) {
        PhoneMatchContext context = new PhoneMatchContext();
        context.leadMobile = normalizePhone(leadRecord.MobilePhone);
        context.leadPhone = normalizePhone(leadRecord.Phone);
        return context;
    }

    /**
     * @description Finds matching phone in Patient phones
     * @param patientPhones List of Patient ContactPointPhone records
     * @param matchContext PhoneMatchContext with Lead phone numbers
     * @return True if match found
     */
    private static Boolean findMatchingPhone(List<ContactPointPhone> patientPhones, PhoneMatchContext matchContext) {
        for (ContactPointPhone phone : patientPhones) {
            if (isMatchingPhone(phone, matchContext)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @description Checks if phone matches Lead phone
     * @param phone ContactPointPhone to check
     * @param matchContext PhoneMatchContext with Lead phone numbers
     * @return True if match found
     */
    private static Boolean isMatchingPhone(ContactPointPhone phone, PhoneMatchContext matchContext) {
        String patientPhone = normalizePhone(phone.TelephoneNumber);
        return patientPhone != null && isPhoneMatch(matchContext, patientPhone);
    }

    /**
     * @description Checks if patient phone matches Lead phone
     * @param matchContext PhoneMatchContext with Lead phone numbers
     * @param patientPhone Normalized patient phone number
     * @return True if match found
     */
    private static Boolean isPhoneMatch(PhoneMatchContext matchContext, String patientPhone) {
        return matchesPhone(matchContext.leadMobile, patientPhone) ||
               matchesPhone(matchContext.leadPhone, patientPhone);
    }

    /**
     * @description Checks if a phone number matches patient phone
     * @param leadPhone Lead phone number
     * @param patientPhone Patient phone number
     * @return True if match found
     */
    private static Boolean matchesPhone(String leadPhone, String patientPhone) {
        return leadPhone != null && leadPhone == patientPhone;
    }

    /**
     * @description Normalizes phone number for comparison (removes non-digit characters)
     * @param phoneNumber Phone number to normalize
     * @return Normalized phone number or null if input is null/empty
     */
    private static String normalizePhone(String phoneNumber) {
        if (String.isBlank(phoneNumber)) {
            return null;
        }

        return phoneNumber.replaceAll('[^0-9]', '');
    }

    /**
     * @description Determines if SMS consent update should be skipped.
     * Skip only when: Patient SMS consent is Opt In AND Lead phone exists in existing Patient ContactPointPhone records.
     * @param existingPhones Patient ContactPointPhone records (excluding newly upserted)
     * @param leadRecord Lead record
     * @param patientSMSConsent Patient SMS consent
     * @return True if update should be skipped
     */
    public static Boolean shouldSkipSMSUpdate(
        List<ContactPointPhone> existingPhones,
        Lead leadRecord,
        ContactPointTypeConsent patientSMSConsent
    ) {
        if (patientSMSConsent == null || patientSMSConsent.PrivacyConsentStatus != ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN) {
            return false;
        }
        return checkLeadPhoneInPatientPhones(existingPhones, leadRecord);
    }

    /**
     * @description Checks if Lead has at least one phone number (MobilePhone or Phone)
     * @param leadRecord Lead record
     * @return True if Lead has phone number
     */
    public static Boolean hasLeadPhone(Lead leadRecord) {
        return leadRecord != null && hasPhoneNumber(leadRecord);
    }

    /**
     * @description Updates consent fields from Lead consent to Patient consent
     * @param patientConsent Patient consent to update
     * @param leadConsent Lead consent source
     */
    public static void updateConsentFields(ContactPointTypeConsent patientConsent, ContactPointTypeConsent leadConsent) {
        patientConsent.PrivacyConsentStatus = leadConsent.PrivacyConsentStatus;
        patientConsent.CaptureDate = leadConsent.CaptureDate;
        patientConsent.DataUsePurposeId = leadConsent.DataUsePurposeId;
        patientConsent.CaptureSource = leadConsent.CaptureSource;
    }

    /**
     * @description Updates consent fields if Lead consent is newer than Patient consent
     * @param patientConsent Patient consent to update
     * @param leadConsent Lead consent source
     * @return True if fields were updated
     */
    public static Boolean updateConsentFieldsIfNeeded(ContactPointTypeConsent patientConsent, ContactPointTypeConsent leadConsent) {
        if (!shouldUpdateConsent(patientConsent, leadConsent)) {
            return false;
        }
        updateConsentFields(patientConsent, leadConsent);
        return true;
    }

    /**
     * @description Updates Legal_Guardian if PatientDelegate exists and not already set
     * @param patientDelegateAccountId PatientDelegate Account Id
     * @param consent Consent record to update
     * @return True if Legal_Guardian was updated
     */
    public static Boolean updateLegalGuardianIfNeeded(Id patientDelegateAccountId, ContactPointTypeConsent consent) {
        if (patientDelegateAccountId != null && consent.Legal_Guardian__c == null) {
            consent.Legal_Guardian__c = patientDelegateAccountId;
            return true;
        }
        return false;
    }

    /**
     * @description Determines if Patient consent should be updated based on CaptureDate
     * @param patientConsent Patient ContactPointTypeConsent record
     * @param leadConsent Lead ContactPointTypeConsent record
     * @return True if Lead consent is newer than Patient consent, false otherwise
     */
    public static Boolean shouldUpdateConsent(ContactPointTypeConsent patientConsent, ContactPointTypeConsent leadConsent) {
        if (patientConsent == null || leadConsent == null) {
            return false;
        }

        return isLeadConsentNewer(patientConsent.CaptureDate, leadConsent.CaptureDate);
    }

    /**
     * @description Checks if Lead consent CaptureDate is newer than Patient consent CaptureDate
     * @param patientCaptureDate Patient consent CaptureDate
     * @param leadCaptureDate Lead consent CaptureDate
     * @return True if Lead date is newer
     */
    private static Boolean isLeadConsentNewer(Datetime patientCaptureDate, Datetime leadCaptureDate) {
        if (patientCaptureDate == null) {
            return leadCaptureDate != null;
        }
        return leadCaptureDate != null && leadCaptureDate > patientCaptureDate;
    }

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null for permission errors)
     */
    private static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }
}