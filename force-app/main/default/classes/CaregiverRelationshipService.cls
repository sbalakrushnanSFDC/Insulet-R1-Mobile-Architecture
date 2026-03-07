/**
 * @description Service class responsible to manage CaregiverRelationships
 * Created Date : Oct 10, 2025
 * Created By   : Sunil Khanchandani
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Oct 10, 2025       Sunil Khanchandani       Initial Version
 * V1.0.1       Jan 21, 2026       Charchit Nirayanwal      Added processMinorCaregiverContactPoints for NGASIM-1147
 * V1.0.2       Jan 21, 2026       Charchit Nirayanwal      Updated findMatchingAccounts to use ContactPointPhone and ContactPointEmail for matching
*/
public inherited sharing class CaregiverRelationshipService {
    /** Tag name used for structured logging of errors during DML operations */
    public static String errorTagName;
     /** Map used to contains the leads where caregiver value on lead not null */
    public static Map<Id,Lead> caregiverLeadsMap;
    /** Cache to track Lead-to-Caregiver Account mappings created within the same transaction.
     *  This prevents duplicate caregiver account creation when both processMinorCaregiverContactPoints 
     *  and createRelationshipsForCaregiver run for the same leads. */
    private static Map<Id, Account> leadToCaregiverAccountCache = new Map<Id, Account>();
    

    /**
    * @description Inserts ContactContactRelation records using bulk-safe partial DML and logs failures
    * @param convertedLeads List of converted lead records
    * @param tagName Tag name used for structured logging of errors during DML operations
    */
    public static void processCaregiverRelations(List<Lead> convertedLeads, String tagName) {
        errorTagName = tagName;
        if (convertedLeads == null || convertedLeads.isEmpty()) {
            caregiverLeadsMap = null;
            return;
        }
        prepareCaregiverLeadsMap(convertedLeads);
    }
    /**
    * @description Creates ContactPoint records (Phone, Email) for the Caregiver (Patient Delegate)
    *              when the patient is a minor (Age < 18). NGASIM-1147
    * @param minorLeads List of converted minor patient leads
    * @param tagName Error logging tag
    */
    public static void processMinorCaregiverContactPoints(List<Lead> minorLeads, String tagName) {
        errorTagName = tagName;
        if (minorLeads == null || minorLeads.isEmpty()) {
            caregiverLeadsMap = null;
            return;
        }
        // Prepare caregiver leads map (only leads with caregiver info)
        caregiverLeadsMap = new Map<Id, Lead>();
        for (Lead ld : minorLeads) {
            if (isCaregiverLead(ld)) {
                caregiverLeadsMap.put(ld.Id, ld);
            }
        }
        if (caregiverLeadsMap.isEmpty()) {
            return;
        }
        Map<String, Set<String>> caregiverData = collectCaregiverDetails();
        List<Account> existingAccounts = findMatchingAccounts(caregiverData);
        Map<Id, Account> leadToAccountMap = buildFinalLeadToAccountMap(existingAccounts);
        // Cache the leadToAccountMap so createRelationshipsForCaregiver can reuse it
        leadToCaregiverAccountCache.putAll(leadToAccountMap);
        // Create ContactPoint records for Caregiver accounts
        CaregiverContactPointHelper.createContactPointsForCaregiver(leadToAccountMap, minorLeads, errorTagName);
    }
    @TestVisible
    private static void prepareCaregiverLeadsMap(List<Lead> convertedLeads){
        caregiverLeadsMap = new Map<Id,Lead>();
        if (convertedLeads == null || convertedLeads.isEmpty()) {
            return;
        }
        for(Lead ld:convertedLeads){
            if(isCaregiverLead(ld)){
                caregiverLeadsMap.put(ld.Id,ld);
            }
        }
        if(!caregiverLeadsMap.isEmpty()){
            createRelationshipsForCaregiver();
        }
    }
    /**
     * @description Checks if Lead has caregiver information
     *              Returns true if any caregiver field is populated (FirstName, LastName, Phone, MobilePhone, or Email)
     *              Note: Either Phone OR MobilePhone can be filled (not requiring both)
     * @param ld Lead record to check
     * @return True if Lead has any caregiver details
     */
    private static Boolean isCaregiverLead(Lead ld){
        if (ld == null) { return false; }

        // Require caregiver name to be present; otherwise we'd treat any Lead with Phone/Email as a caregiver
        // and incorrectly create extra "Patient Delegate" Accounts.
        Boolean hasCaregiverName = (ld.Caregiver_First_Name__c != null || ld.Caregiver_Last_Name__c != null);
        if (!hasCaregiverName || ld.Age__c >= ConstantsUtil.MINOR_AGE_THRESHOLD) { return false; }

        // Caregiver contact details are sourced from Lead's contact fields.
        return (ld.Phone != null || ld.MobilePhone != null || ld.Email != null);
    }
    /**
    * @description Creates ContactContactRelation records for caregiver Leads after Lead conversion.
    *              Identifies caregiver Leads, finds or creates corresponding caregiver Accounts,
    *              creates ContactPoint records for the accounts, and establishes relationships
    *              between patient and caregiver Contacts
    */
    private static void createRelationshipsForCaregiver() {
        Map<Id, Account> leadToAccountMap = new Map<Id, Account>();
        // First, use any accounts already created in processMinorCaregiverContactPoints
        if (!leadToCaregiverAccountCache.isEmpty()) {
            leadToAccountMap.putAll(leadToCaregiverAccountCache);
        }
        // Only process leads that don't already have an account in the cache
        Set<Id> leadsNeedingAccounts = new Set<Id>();
        for (Id leadId : caregiverLeadsMap.keySet()) {
            if (!leadToAccountMap.containsKey(leadId)) {
                leadsNeedingAccounts.add(leadId);
            }
        }
        // If there are leads without accounts, find or create accounts for them
        if (!leadsNeedingAccounts.isEmpty()) {
            Map<String, Set<String>> caregiverData = collectCaregiverDetails();
            List<Account> existingAccounts = findMatchingAccounts(caregiverData);
            Map<Id, Account> newLeadToAccountMap = buildFinalLeadToAccountMap(existingAccounts);
            leadToAccountMap.putAll(newLeadToAccountMap);
        }
        List<ContactContactRelation> ccrRecordsList = createCaregiverContactRelations(leadToAccountMap);
        List<ContactContactRelation> ccrRecordsToInsert = ContactContactRelationDuplicateFilter.filterDuplicateCCRs(ccrRecordsList);
        if (!ccrRecordsToInsert.isEmpty()) {
            // Use existing method to insert CCR records
            ContactContactRelationService.insertContactContactRelationships(ccrRecordsToInsert,errorTagName);
        }
    }
    /**
    * @description Collects caregiver details from Lead records for bulk Account matching
    *              Collects both phone and mobile phone to create combinations for matching
    * @return Map with keys: 'emails', 'phones', 'mobilePhones', 'firstNames', 'lastNames'
    */
    @TestVisible
    private static Map<String, Set<String>> collectCaregiverDetails() {
        Map<String, Set<String>> caregiverData = new Map<String, Set<String>>{
            'emails' => new Set<String>(),
                'phones' => new Set<String>(),
                'mobilePhones' => new Set<String>(),
                'firstNames' => new Set<String>(),
                'lastNames' => new Set<String>()
                };
                    if (caregiverLeadsMap == null || caregiverLeadsMap.isEmpty()) {
                        return caregiverData;
                    }
                    for (Lead ld : caregiverLeadsMap.values()) {
                        addValueIfNotNull(caregiverData, 'emails', ld.Email);
                        // Collect both phone and mobile phone for combination matching
                        addValueIfNotNull(caregiverData, 'phones', ld.Phone);
                        addValueIfNotNull(caregiverData, 'mobilePhones', ld.MobilePhone);
                        addValueIfNotNull(caregiverData, 'firstNames', ld.Caregiver_First_Name__c);
                        addValueIfNotNull(caregiverData, 'lastNames', ld.Caregiver_Last_Name__c);
                    }
	    return caregiverData;
    }
    // Helper to safely add a non-null value to the target map's set
    private static void addValueIfNotNull(Map<String, Set<String>> dataMap, String key, String value) {
        if (value != null && dataMap != null && dataMap.containsKey(key)) {
            dataMap.get(key).add(value);
        }
    }
    /**
    * @description Builds Lead to Account mapping using composite matching key from caregiver details
    * @param existingAccounts List of existing Account records to match
    * @return Map of Lead Ids to matching Account records
    */
    @TestVisible
    private static Map<Id, Account> buildLeadToAccountMap(List<Account> existingAccounts) {
        Map<Id, Account> leadToAccountMap = new Map<Id, Account>();
        if (CaregiverRelationshipHelper.isNullOrEmpty(existingAccounts)) {
            return leadToAccountMap;
        }
        if (caregiverLeadsMap == null || caregiverLeadsMap.isEmpty()) {
            return leadToAccountMap;
        }
        Map<String, Account> accountKeyMap = CaregiverAccountMatchingHelper.buildAccountKeyMap(existingAccounts);
        for (Lead ld : caregiverLeadsMap.values()) {
            Account matchedAccount = findMatchingAccountForLead(ld, accountKeyMap);
            if (matchedAccount != null) {
                leadToAccountMap.put(ld.Id, matchedAccount);
            }
        }
        return leadToAccountMap;
    }

    /**
     * @description Finds a matching account for a lead by trying multiple key combinations
     * @param ld Lead record to match
     * @param accountKeyMap Map of composite keys to Account records
     * @return Matching Account if found, null otherwise
     */
    private static Account findMatchingAccountForLead(Lead ld, Map<String, Account> accountKeyMap) {
        List<String> possibleKeys = generatePossibleKeysForLead(ld);
        for (String key : possibleKeys) {
            if (accountKeyMap.containsKey(key)) {
                return accountKeyMap.get(key);
            }
        }
        return null;
    }

    /**
     * @description Generates all possible composite keys for a lead to match against accounts
     * @param ld Lead record
     * @return List of possible composite keys
     */
    private static List<String> generatePossibleKeysForLead(Lead ld) {
        List<String> possibleKeys = new List<String>();
        Set<String> leadPhoneNumbers = collectLeadPhoneNumbers(ld);
        String normalizedLeadEmail = normalizeLeadEmail(ld.Email);

        // Generate keys for phone + email combinations
        for (String phoneNum : leadPhoneNumbers) {
            if (String.isNotBlank(normalizedLeadEmail)) {
                possibleKeys.add(createPersonKey(ld, normalizedLeadEmail, phoneNum));
            }
            // Key with phone only (no email)
            possibleKeys.add(createPersonKey(ld, null, phoneNum));
        }

        // Key with email only (no phone)
        if (String.isNotBlank(normalizedLeadEmail)) {
            possibleKeys.add(createPersonKey(ld, normalizedLeadEmail, null));
        }

        return possibleKeys;
    }

    /**
     * @description Collects and normalizes all phone numbers from a lead
     * @param ld Lead record
     * @return Set of normalized phone numbers
     */
    private static Set<String> collectLeadPhoneNumbers(Lead ld) {
        Set<String> leadPhoneNumbers = new Set<String>();
        String normalizedLeadPhone = CaregiverRelationshipHelper.normalizePhoneNumber(ld.Phone);
        String normalizedLeadMobilePhone = CaregiverRelationshipHelper.normalizePhoneNumber(ld.MobilePhone);

        if (String.isNotBlank(normalizedLeadPhone)) {
            leadPhoneNumbers.add(normalizedLeadPhone);
        }
        if (String.isNotBlank(normalizedLeadMobilePhone)) {
            leadPhoneNumbers.add(normalizedLeadMobilePhone);
        }
        return leadPhoneNumbers;
    }

    /**
     * @description Normalizes lead email address
     * @param email Email address from lead
     * @return Normalized email or null
     */
    private static String normalizeLeadEmail(String email) {
        return email != null ? email.toLowerCase().trim() : null;
    }

    /**
     * @description Creates a composite person key for matching
     * @param ld Lead record
     * @param email Email address (can be null)
     * @param phone Phone number (can be null)
     * @return Composite key string
     */
    private static String createPersonKey(Lead ld, String email, String phone) {
        Map<String, String> leadFields = new Map<String, String>{
            'firstName' => ld.Caregiver_First_Name__c,
            'lastName'  => ld.Caregiver_Last_Name__c,
            'email'     => email,
            'phone'     => phone
        };
        return CaregiverRelationshipHelper.generatePersonKey(leadFields);
    }
    /**
    * @description Builds final Lead to Account mapping by matching existing Accounts or creating new ones
    * @param existingAccounts List of existing Account records that may match the Leads
    * @return Map of Lead Ids to associated Account records
    */
    public static Map<Id, Account> buildFinalLeadToAccountMap(List<Account> existingAccounts) {
        Map<Id, Account> leadToAccountMap = new Map<Id, Account>();
        Id recordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT;
        if (existingAccounts != null && !existingAccounts.isEmpty()) {
            leadToAccountMap.putAll(buildLeadToAccountMap(existingAccounts));
        }
        if (caregiverLeadsMap == null || caregiverLeadsMap.isEmpty()) {
            return leadToAccountMap;
        }
        List<Account> accountsToInsert = new List<Account>();
        List<Lead> leadsToInsert = new List<Lead>();
        for (Lead ld : caregiverLeadsMap.values()) {
            if (!leadToAccountMap.containsKey(ld.Id)) {
                Account newAcc = CaregiverRelationshipHelper.createAccountFromLead(ld, recordTypeId);
                if (newAcc != null) {
                    accountsToInsert.add(newAcc);
                    leadsToInsert.add(ld);
                }
            }
        }
        if (!accountsToInsert.isEmpty()) {
            Map<Id, Account> newAccountsMap = CaregiverRelationshipHelper.insertAccountsAndBuildMap(leadsToInsert, accountsToInsert, errorTagName);
            leadToAccountMap.putAll(newAccountsMap);
        }
        return leadToAccountMap;
    }
    /**
    * @description Creates ContactContactRelation records linking patient Contacts with caregiver Contacts
    * @param leadToAccountMap Map of Lead Id to caregiver Account records
    * @return List of ContactContactRelation records ready to insert
    */
    public static List<ContactContactRelation> createCaregiverContactRelations(Map<Id, Account> leadToAccountMap) {
        List<ContactContactRelation> ccrList = new List<ContactContactRelation>();
        if (isNullOrEmptyMap(leadToAccountMap)) {
            return ccrList;
        }
        List<PartyRoleRelation> partyRoleRelationRecords = fetchRoleRelationRecord(ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE);
        if (partyRoleRelationRecords.isEmpty()) {
            return ccrList;
        }
        Id partyRoleRelationId = partyRoleRelationRecords[0].Id;
        Set<Id> accountIds = CaregiverContactPointHelper.collectAccountIds(leadToAccountMap);
        if (!accountIds.isEmpty()) {
            Map<Id, Account> accountMapWithPersonContact = AccountService.getConvertedAccounts(accountIds);
            for (Id leadId : leadToAccountMap.keySet()) {
                Lead ld = caregiverLeadsMap.get(leadId);
                Account caregiverAccount = accountMapWithPersonContact.get(leadToAccountMap.get(leadId).Id);
                if (ld?.ConvertedContactId != null && caregiverAccount != null && caregiverAccount.PersonContactId != null) {
                    ContactContactRelation ccr = new ContactContactRelation();
                    ccr.ContactId = ld.ConvertedContactId;
                    ccr.RelatedContactId = caregiverAccount.PersonContactId;
                    ccr.PartyRoleRelationId = partyRoleRelationId;
                    ccrList.add(ccr);
                }
            }
        }
        return ccrList;
    }

    // Helper to check null or empty map
    private static Boolean isNullOrEmptyMap(Map<Id, Object> mapData) {
        return CaregiverRelationshipHelper.isNullOrEmptyMap(mapData);
    }

    // ==================== ACCOUNT MATCHING METHODS ====================

    /**
     * @description Finds existing Account records matching caregiver details using ContactPointPhone and ContactPointEmail
     *              Bulkified to handle multiple leads efficiently with a single SOQL query.
     *              Pre-populates Account and ContactPoint caches to avoid duplicate queries downstream.
     * @param caregiverData Map containing caregiver information with keys: 'emails', 'phones', 'mobilePhones', 'firstNames', 'lastNames'
     * @return List of matching Account records
     */
    @TestVisible
    public static List<Account> findMatchingAccounts(Map<String, Set<String>> caregiverData) {
        List<Account> matchingAccounts = new List<Account>();
        if (CaregiverRelationshipHelper.isCaregiverDataEmpty(caregiverData)) {
            return matchingAccounts;
        }
        List<String> nameConditions = CaregiverAccountMatchingHelper.buildNameConditions(caregiverData);
        if (nameConditions.isEmpty()) {
            return matchingAccounts;
        }
        Id patientDeligateRecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT;
        List<Account> candidateAccounts = CaregiverAccountMatchingHelper.queryAccountsByName(patientDeligateRecordTypeId, nameConditions);
        if (candidateAccounts.isEmpty()) {
            return matchingAccounts;
        }
        
        CaregiverContactPointHelper.populateCacheFromAccounts(candidateAccounts);
        Map<Id, CaregiverAccountMatchingHelper.AccountContactPointData> accountContactPointMap = CaregiverAccountMatchingHelper.buildAccountContactPointMap(candidateAccounts);
        matchingAccounts = CaregiverAccountMatchingHelper.filterAccountsByContactPoints(accountContactPointMap, caregiverData);
        return matchingAccounts;
    }

    public static List<PartyRoleRelation> fetchRoleRelationRecord(String relatedRoleName) {
        return [ SELECT Id FROM PartyRoleRelation WHERE Name = :relatedRoleName WITH SYSTEM_MODE];
    }

}