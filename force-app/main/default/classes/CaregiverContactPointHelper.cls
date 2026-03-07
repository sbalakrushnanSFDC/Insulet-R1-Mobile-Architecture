/**
 * @description Helper class for ContactPoint operations in CaregiverRelationshipService
 * Contains methods for creating, fetching, and inserting ContactPoint records
 * Created Date : Jan 29, 2026
 * Created By   : Charchit Nirayanwal
  * V1.0.0    2nd Mar 2026        Chitresh Vijayvargiya     Removed IsPrimary from ContactPointPhone record as this is handled by ContactPointPhoneHandler.

 */
public inherited sharing class CaregiverContactPointHelper {
    /** ContactPoint Usage Type constants */
    public static final String USAGE_TYPE_HOME = 'Home';
    public static final String USAGE_TYPE_MOBILE = 'Mobile';

    // ---------------------------- TRANSACTION CACHES ----------------------------
    // Cache existing ContactPointPhone records per transaction to avoid repeat SOQL.
    private static final Map<String, ContactPointPhone> EXISTING_CPP_BY_KEY_CACHE = new Map<String, ContactPointPhone>();
    private static final Set<Id> CPP_PARENT_IDS_QUERIED = new Set<Id>();
    // Cache existing ContactPointEmail records per transaction to avoid repeat SOQL.
    private static final Map<String, ContactPointEmail> EXISTING_CPE_BY_KEY_CACHE = new Map<String, ContactPointEmail>();
    private static final Set<Id> CPE_PARENT_IDS_QUERIED = new Set<Id>();

    /**
     * @description Helper class to reduce parameter count for ContactPoint insertion methods
     */
    public class ContactPointInsertContext {
        public Map<String, ContactPointPhone> existingPhoneMap;
        public List<ContactPointPhone> phonesToInsert;
        public Map<String, ContactPointEmail> existingEmailMap;
        public List<ContactPointEmail> emailsToInsert;
        public Id parentId;
        public Lead lead;

        /**
         * @description Constructor for ContactPointInsertContext
         * @param existingPhoneMap Map of existing ContactPointPhone records
         * @param phonesToInsert List of ContactPointPhone records to insert
         * @param existingEmailMap Map of existing ContactPointEmail records
         * @param emailsToInsert List of ContactPointEmail records to insert
         * @param parentId The Account Id (ParentId for ContactPoint)
         * @param lead The Lead record
         */
        public ContactPointInsertContext( // NOPMD ExcessiveParameterList - Constructor for context object, all parameters required
            Map<String, ContactPointPhone> existingPhoneMap,
            List<ContactPointPhone> phonesToInsert,
            Map<String, ContactPointEmail> existingEmailMap,
            List<ContactPointEmail> emailsToInsert,
            Id parentId,
            Lead lead
        ) {
            this.existingPhoneMap = existingPhoneMap;
            this.phonesToInsert = phonesToInsert;
            this.existingEmailMap = existingEmailMap;
            this.emailsToInsert = emailsToInsert;
            this.parentId = parentId;
            this.lead = lead;
        }
    }

    /**
     * @description Helper class to reduce parameter count for error logging methods
     */
    private class LogInsertErrorsContext {
        public Database.SaveResult[] results;
        public List<SObject> recordsToInsert;
        public String errorTagName;
        public String objectType;

        /**
         * @description Constructor for LogInsertErrorsContext
         * @param results Database save results
         * @param recordsToInsert List of records that were inserted
         * @param errorTagName Tag name for error logging
         * @param objectType Type of object being inserted
         */
        public LogInsertErrorsContext( // NOPMD ExcessiveParameterList - Constructor for context object, all parameters required
            Database.SaveResult[] results,
            List<SObject> recordsToInsert,
            String errorTagName,
            String objectType
        ) {
            this.results = results;
            this.recordsToInsert = recordsToInsert;
            this.errorTagName = errorTagName;
            this.objectType = objectType;
        }
    }

    /**
     * @description Creates ContactPointPhone and ContactPointEmail records for Caregiver accounts
     *              Checks for existing records to avoid duplicates
     * @param leadToAccountMap Map of Lead Id to Caregiver Account
     * @param minorLeads Original list of minor leads (to access Phone, MobilePhone, Email fields)
     * @param errorTagName Tag name for error logging
     */
    public static void createContactPointsForCaregiver(Map<Id, Account> leadToAccountMap, List<Lead> minorLeads, String errorTagName) {
        if (leadToAccountMap == null || leadToAccountMap.isEmpty()) {
            return;
        }

        Set<Id> accountIds = collectAccountIds(leadToAccountMap);
        if (accountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> accountMapWithDetails = AccountService.getConvertedAccounts(accountIds);
        Map<String, ContactPointPhone> existingPhoneMap = fetchExistingContactPointPhones(accountIds);
        Map<String, ContactPointEmail> existingEmailMap = fetchExistingContactPointEmails(accountIds);

        List<ContactPointPhone> phonesToInsert = new List<ContactPointPhone>();
        List<ContactPointEmail> emailsToInsert = new List<ContactPointEmail>();

        for (Lead ld : minorLeads) {
            Id parentId = getParentIdForLead(ld, leadToAccountMap, accountMapWithDetails);
            if (parentId == null) {
                continue;
            }

            ContactPointInsertContext context = new ContactPointInsertContext(
                existingPhoneMap,
                phonesToInsert,
                existingEmailMap,
                emailsToInsert,
                parentId,
                ld
            );
            addPhoneContactPoints(context);
            addEmailContactPoints(context);
        }

        insertContactPointRecords(phonesToInsert, emailsToInsert, errorTagName);
    }

    /**
     * @description Collects Account Ids from the lead to account map
     * @param leadToAccountMap Map of Lead Id to Account
     * @return Set of Account Ids
     */
    public static Set<Id> collectAccountIds(Map<Id, Account> leadToAccountMap) {
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : leadToAccountMap.values()) {
            if (acc != null && acc.Id != null) {
                accountIds.add(acc.Id);
            }
        }
        return accountIds;
    }

    /**
     * @description Gets the parent Account Id for a lead, validating account existence
     * @param ld The Lead record
     * @param leadToAccountMap Map of Lead Id to Account
     * @param accountMapWithDetails Map of Account Id to Account with details
     * @return Account Id if valid, null otherwise
     */
    @TestVisible
    public static Id getParentIdForLead(Lead ld, Map<Id, Account> leadToAccountMap, Map<Id, Account> accountMapWithDetails) {
        Account caregiverAccount = leadToAccountMap.get(ld.Id);
        if (caregiverAccount == null) {
            return null;
        }

        Account accountWithDetails = accountMapWithDetails.get(caregiverAccount.Id);
        if (accountWithDetails == null) {
            return null;
        }

        return accountWithDetails.Id;
    }

    /**
     * @description Adds ContactPointPhone records for a lead's phone numbers
     * @param context ContactPoint insertion context containing all necessary data
     */
    private static void addPhoneContactPoints(ContactPointInsertContext context) {
        if (String.isNotBlank(context.lead.Phone)) {
            addHomePhoneContactPoint(context.lead.Phone, context);
        }

        if (String.isNotBlank(context.lead.MobilePhone)) {
            addMobilePhoneContactPoint(context.lead.MobilePhone, String.isBlank(context.lead.Phone), context);
        }
    }

    /**
     * @description Adds a home phone ContactPointPhone record if it doesn't exist in static cache
     *              Updates static cache immediately to prevent duplicates within same batch and across re-entries
     * @param phoneNumber The phone number
     * @param context ContactPoint insertion context containing existing phone map and list to insert
     */
    private static void addHomePhoneContactPoint(String phoneNumber, ContactPointInsertContext context) {
        String phoneKey = buildContactPointPhoneKey(context.parentId, phoneNumber);
        if (!EXISTING_CPP_BY_KEY_CACHE.containsKey(phoneKey)) {
            ContactPointPhone newPhone = new ContactPointPhone(
                ParentId = context.parentId,
                TelephoneNumber = phoneNumber,
                UsageType = USAGE_TYPE_HOME
            );
            context.phonesToInsert.add(newPhone);
            EXISTING_CPP_BY_KEY_CACHE.put(phoneKey, newPhone);
        }
    }

    /**
     * @description Adds a mobile phone ContactPointPhone record if it doesn't exist in static cache
     *              Updates static cache immediately to prevent duplicates within same batch and across re-entries
     * @param mobileNumber The mobile phone number
     * @param isPrimary Whether this mobile phone should be marked as primary (true if no home phone exists)
     * @param context ContactPoint insertion context containing existing phone map and list to insert
     */
    private static void addMobilePhoneContactPoint(String mobileNumber, Boolean isPrimary, ContactPointInsertContext context) {
        String mobileKey = buildContactPointPhoneKey(context.parentId, mobileNumber);
        if (!EXISTING_CPP_BY_KEY_CACHE.containsKey(mobileKey)) {
            ContactPointPhone newPhone = new ContactPointPhone(
                ParentId = context.parentId,
                TelephoneNumber = mobileNumber,
                UsageType = USAGE_TYPE_MOBILE
            );
            context.phonesToInsert.add(newPhone);
            EXISTING_CPP_BY_KEY_CACHE.put(mobileKey, newPhone);
        }
    }

    /**
     * @description Adds ContactPointEmail records for a lead's email if it doesn't exist in static cache
     *              Updates static cache immediately to prevent duplicates within same batch and across re-entries
     * @param context ContactPoint insertion context containing all necessary data
     */
    private static void addEmailContactPoints(ContactPointInsertContext context) {
        if (String.isNotBlank(context.lead.Email)) {
            String emailKey = buildContactPointEmailKey(context.parentId, context.lead.Email);
            if (!EXISTING_CPE_BY_KEY_CACHE.containsKey(emailKey)) {
                ContactPointEmail newEmail = new ContactPointEmail(
                    ParentId = context.parentId,
                    EmailAddress = context.lead.Email,
                    UsageType = USAGE_TYPE_HOME,
                    IsPrimary = true
                );
                context.emailsToInsert.add(newEmail);
                EXISTING_CPE_BY_KEY_CACHE.put(emailKey, newEmail);
            }
        }
    }

    /**
     * @description Inserts ContactPoint records with error handling
     * @param phonesToInsert List of ContactPointPhone records to insert
     * @param emailsToInsert List of ContactPointEmail records to insert
     * @param errorTagName Tag name for error logging
     */
    private static void insertContactPointRecords(List<ContactPointPhone> phonesToInsert, List<ContactPointEmail> emailsToInsert, String errorTagName) {
        if (!phonesToInsert.isEmpty()) {
            insertContactPointPhones(phonesToInsert, errorTagName);
        }
        if (!emailsToInsert.isEmpty()) {
            insertContactPointEmails(emailsToInsert, errorTagName);
        }
    }

    /**
     * @description Returns existing ContactPointPhone records from cache for given account Ids.
     *              Cache is pre-populated via populateCacheFromAccounts() from findMatchingAccounts subquery data.
     *              New accounts won't have any existing ContactPoints, so cache will be empty for them.
     * @param accountIds Set of Account Ids to check
     * @return Map with key = ParentId + TelephoneNumber, value = ContactPointPhone record
     */
    @TestVisible
    public static Map<String, ContactPointPhone> fetchExistingContactPointPhones(Set<Id> accountIds) {
        Map<String, ContactPointPhone> phoneMap = new Map<String, ContactPointPhone>();
        if (accountIds == null || accountIds.isEmpty()) {
            return phoneMap;
        }
        // Mark these account IDs as processed
        phoneMap.putAll(EXISTING_CPP_BY_KEY_CACHE);
        return phoneMap;
    }

    /**
     * @description Returns existing ContactPointEmail records from cache for given account Ids.
     *              Cache is pre-populated via populateCacheFromAccounts() from findMatchingAccounts subquery data.
     *              New accounts won't have any existing ContactPoints, so cache will be empty for them.
     * @param accountIds Set of Account Ids to check
     * @return Map with key = ParentId + EmailAddress, value = ContactPointEmail record
     */
    @TestVisible
    public static Map<String, ContactPointEmail> fetchExistingContactPointEmails(Set<Id> accountIds) {
        Map<String, ContactPointEmail> emailMap = new Map<String, ContactPointEmail>();
        if (accountIds == null || accountIds.isEmpty()) {
            return emailMap;
        }
        // Mark these account IDs as processed
        CPE_PARENT_IDS_QUERIED.addAll(accountIds);
        emailMap.putAll(EXISTING_CPE_BY_KEY_CACHE);
        return emailMap;
    }

    /**
     * @description Pre-populates the ContactPoint caches from Account records that already have
     *              ContactPointPhones and ContactPointEmails subquery data loaded.
     *              This avoids duplicate SOQL queries when the data was already fetched in findMatchingAccounts.
     * @param accounts List of Account records with ContactPointPhones and ContactPointEmails subqueries
     */
    public static void populateCacheFromAccounts(List<Account> accounts) {
        if (accounts == null || accounts.isEmpty()) {
            return;
        }
        for (Account acc : accounts) {
            if (acc.Id == null) {
                continue;
            }
            populatePhoneCacheFromAccount(acc);
            populateEmailCacheFromAccount(acc);
        }
    }

    /**
     * @description Populates the ContactPointPhone cache from an Account's subquery data
     * @param acc Account record with ContactPointPhones subquery
     */
    @TestVisible
    private static void populatePhoneCacheFromAccount(Account acc) {
        if (acc.ContactPointPhones == null) {
            return;
        }
        for (ContactPointPhone cpp : acc.ContactPointPhones) {
            String key = buildContactPointPhoneKey(cpp.ParentId, cpp.TelephoneNumber);
            EXISTING_CPP_BY_KEY_CACHE.put(key, cpp);
        }
        // Mark this account as already queried to prevent duplicate SOQL
        CPP_PARENT_IDS_QUERIED.add(acc.Id);
    }

    /**
     * @description Populates the ContactPointEmail cache from an Account's subquery data
     * @param acc Account record with ContactPointEmails subquery
     */
    @TestVisible
    private static void populateEmailCacheFromAccount(Account acc) {
        if (acc.ContactPointEmails == null) {
            return;
        }
        for (ContactPointEmail cpe : acc.ContactPointEmails) {
            String key = buildContactPointEmailKey(cpe.ParentId, cpe.EmailAddress);
            EXISTING_CPE_BY_KEY_CACHE.put(key, cpe);
        }
        // Mark this account as already queried to prevent duplicate SOQL
        CPE_PARENT_IDS_QUERIED.add(acc.Id);
    }

    /**
     * @description Builds a unique key for ContactPointPhone duplicate detection
     * @param parentId The ParentId (Account Id)
     * @param telephoneNumber The phone number
     * @return Composite key string
     */
    public static String buildContactPointPhoneKey(Id parentId, String telephoneNumber) {
        return String.valueOf(parentId) + '|' + (telephoneNumber != null ? telephoneNumber.toLowerCase().trim() : '');
    }

    /**
     * @description Builds a unique key for ContactPointEmail duplicate detection
     * @param parentId The ParentId (Account Id)
     * @param emailAddress The email address
     * @return Composite key string
     */
    public static String buildContactPointEmailKey(Id parentId, String emailAddress) {
        return String.valueOf(parentId) + '|' + (emailAddress != null ? emailAddress.toLowerCase().trim() : '');
    }

    /**
     * @description Inserts ContactPointPhone records with bulk-safe DML and error logging
     *              Updates the transaction cache with successfully inserted records to prevent duplicates on re-entry
     * @param phonesToInsert List of ContactPointPhone records to insert
     * @param errorTagName Tag name for error logging
     */
    @TestVisible
    public static void insertContactPointPhones(List<ContactPointPhone> phonesToInsert, String errorTagName) {
        if (phonesToInsert.isEmpty() || !Schema.SObjectType.ContactPointPhone.isCreateable()) {
            return;
        }
        Database.SaveResult[] results = Database.insert(phonesToInsert, false, AccessLevel.SYSTEM_MODE);
        LogInsertErrorsContext context = new LogInsertErrorsContext(results, phonesToInsert, errorTagName, 'ContactPointPhone');
        logInsertErrors(context);
        // Update cache with successfully inserted records to prevent duplicates on re-entry
        updatePhoneCache(results, phonesToInsert);
    }

    /**
     * @description Updates the ContactPointPhone cache with successfully inserted records
     * @param results Database save results from the insert operation
     * @param phonesToInsert List of ContactPointPhone records that were inserted
     */
    private static void updatePhoneCache(Database.SaveResult[] results, List<ContactPointPhone> phonesToInsert) {
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                ContactPointPhone cpp = phonesToInsert[i];
                String key = buildContactPointPhoneKey(cpp.ParentId, cpp.TelephoneNumber);
                EXISTING_CPP_BY_KEY_CACHE.put(key, cpp);
            }
        }
    }

    /**
     * @description Inserts ContactPointEmail records with bulk-safe DML and error logging
     *              Updates the transaction cache with successfully inserted records to prevent duplicates on re-entry
     * @param emailsToInsert List of ContactPointEmail records to insert
     * @param errorTagName Tag name for error logging
     */
    @TestVisible
    public static void insertContactPointEmails(List<ContactPointEmail> emailsToInsert, String errorTagName) {
        if (emailsToInsert.isEmpty() || !Schema.SObjectType.ContactPointEmail.isCreateable()) {
            return;
        }
        contactPointEmailHandler.skipSetPrimaryOnNewContactPointEmail = true;
        Database.SaveResult[] results = Database.insert(emailsToInsert, false, AccessLevel.SYSTEM_MODE);
        LogInsertErrorsContext context = new LogInsertErrorsContext(results, emailsToInsert, errorTagName, 'ContactPointEmail');
        logInsertErrors(context);
        // Update cache with successfully inserted records to prevent duplicates on re-entry
        updateEmailCache(results, emailsToInsert);
    }

    /**
     * @description Updates the ContactPointEmail cache with successfully inserted records
     * @param results Database save results from the insert operation
     * @param emailsToInsert List of ContactPointEmail records that were inserted
     */
    private static void updateEmailCache(Database.SaveResult[] results, List<ContactPointEmail> emailsToInsert) {
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                ContactPointEmail cpe = emailsToInsert[i];
                String key = buildContactPointEmailKey(cpe.ParentId, cpe.EmailAddress);
                EXISTING_CPE_BY_KEY_CACHE.put(key, cpe);
            }
        }
    }

    /**
     * @description Logs errors from failed ContactPoint inserts
     * @param context LogInsertErrorsContext containing all necessary data for error logging
     */
    private static void logInsertErrors(LogInsertErrorsContext context) {
        for (Integer i = 0; i < context.results.size(); i++) {
            if (!context.results[i].isSuccess()) {
                Logger.error('Error inserting ' + context.objectType + ' for Caregiver', context.results[i])
                    .setRecord(context.recordsToInsert[i])
                    .addTag(context.errorTagName);
            }
        }
    }
}