/**
 * @description Helper class for Account matching logic in CaregiverRelationshipService
 * Contains methods for matching accounts using ContactPoint data
 * Created Date : Jan 29, 2026
 * Created By   : Charchit Nirayanwal
 */
public inherited sharing class CaregiverAccountMatchingHelper {

    // ---------------------------- TRANSACTION CACHE ----------------------------
    // Cache queried accounts to avoid duplicate SOQL queries within same transaction
    private static Map<Id, Account> queriedAccountsCache = new Map<Id, Account>(); 
    // Track which name combinations have been queried
    private static Set<String> queriedNameKeys = new Set<String>();

    /**
     * @description Helper class to hold ContactPoint data for an account
     */
    public class AccountContactPointData {
        public Account account;
        public Set<String> mobilePhones = new Set<String>();
        public Set<String> homePhones = new Set<String>();
        public Set<String> emails = new Set<String>();

        /**
         * @description Constructor for AccountContactPointData
         * @param acc Account record
         */
        public AccountContactPointData(Account acc) {
            this.account = acc;
        }
    }

    /**
     * @description Context class for account key map building operations
     */
    public class AccountKeyMapContext {
        public Map<String, Account> accountKeyMap;
        public Account account;
        public Set<String> allPhones;
        public Set<String> emails;

        /**
         * @description Constructor for AccountKeyMapContext
         * @param accountKeyMap Map of account key to account
         * @param cpData Account ContactPoint data containing account, phones, and emails
         */
        public AccountKeyMapContext(Map<String, Account> accountKeyMap, AccountContactPointData cpData) {
            this.accountKeyMap = accountKeyMap;
            this.account = cpData.account;
            this.allPhones = new Set<String>();
            this.allPhones.addAll(cpData.mobilePhones);
            this.allPhones.addAll(cpData.homePhones);
            this.emails = cpData.emails;
        }
    }

    /**
     * @description Helper method to create account key map using ContactPoint data
     * @param accounts List of Account records
     * @return Map of composite key to Account
     */
    @TestVisible
    public static Map<String, Account> buildAccountKeyMap(List<Account> accounts) {
        Map<String, Account> accountKeyMap = new Map<String, Account>();
        if (CaregiverRelationshipHelper.isNullOrEmpty(accounts)) {
            return accountKeyMap;
        }
        Map<Id, AccountContactPointData> accountContactPointMap = buildAccountContactPointMap(accounts);
        for (AccountContactPointData cpData : accountContactPointMap.values()) {
            if (cpData == null || cpData.account == null) {
                continue;
            }
            Set<String> allPhones = getAllAccountPhones(cpData);
            if (allPhones.isEmpty() && cpData.emails.isEmpty()) {
                continue;
            }
            AccountKeyMapContext context = new AccountKeyMapContext(accountKeyMap, cpData);
            addPhoneEmailCombinationKeys(context);
            addPhoneOnlyKeys(context);
            addEmailOnlyKeys(context);
        }
        return accountKeyMap;
    }

    /**
     * @description Queries Account records by FirstName and LastName with ContactPoint subqueries.
     *              Uses transaction-level caching to avoid duplicate SOQL queries.
     *              Returns cached results merged with new query results.
     * @param recordTypeId Patient Delegate RecordTypeId
     * @param conditions List of condition strings (FirstName IN (...), LastName IN (...))
     * @return List of Account records with ContactPoint data
     */
    public static List<Account> queryAccountsByName(Id recordTypeId, List<String> conditions) {
        // Build cache key from conditions
        String cacheKey = String.valueOf(recordTypeId) + '|' + String.join(conditions, '|');
        
        // Check if we've already queried with these exact conditions
        if (queriedNameKeys.contains(cacheKey)) {
            return queriedAccountsCache.values();
        }
        
        String escapedRecordTypeId = String.escapeSingleQuotes(String.valueOf(recordTypeId));
        String baseQuery = 'SELECT Id, Name, FirstName, LastName, PersonEmail, Phone, PersonContactId, ' +
                        '(SELECT Id, TelephoneNumber, UsageType,ParentId FROM ContactPointPhones WHERE UsageType IN (\'' +
                        CaregiverContactPointHelper.USAGE_TYPE_MOBILE + '\', \'' + CaregiverContactPointHelper.USAGE_TYPE_HOME + '\')), ' +
                        '(SELECT Id, EmailAddress,ParentId FROM ContactPointEmails) ' +
                        'FROM Account WHERE RecordTypeId = \'' + escapedRecordTypeId + '\' AND ';
        String finalQuery = baseQuery + String.join(conditions, ' AND ') +
            ' WITH SYSTEM_MODE ORDER BY LastModifiedDate ASC';
        List<Account> accounts = Database.query(finalQuery); // NOPMD ApexSOQLInjection
        
        // Cache the results
        for (Account acc : accounts) {
            queriedAccountsCache.put(acc.Id, acc);
        }
        queriedNameKeys.add(cacheKey);
        
        // Return all cached accounts (includes results from this query and previous queries)
        // The filtering by ContactPoints happens later in filterAccountsByContactPoints
        return queriedAccountsCache.values();
    }

    /**
     * @description Builds a map of Account Id to AccountContactPointData from Account records
     * @param accounts List of Account records with ContactPoint subqueries
     * @return Map of Account Id to AccountContactPointData
     */
    public static Map<Id, AccountContactPointData> buildAccountContactPointMap(List<Account> accounts) {
        Map<Id, AccountContactPointData> accountContactPointMap = new Map<Id, AccountContactPointData>();
        if (accounts == null || accounts.isEmpty()) {
            return accountContactPointMap;
        }
        for (Account acc : accounts) {
            AccountContactPointData cpData = new AccountContactPointData(acc);
            processContactPointPhones(acc, cpData);
            processContactPointEmails(acc, cpData);
            accountContactPointMap.put(acc.Id, cpData);
        }
        return accountContactPointMap;
    }

    /**
     * @description Processes ContactPointPhone subquery results
     * @param acc Account record with ContactPointPhone subquery
     * @param cpData AccountContactPointData to populate
     */
    private static void processContactPointPhones(Account acc, AccountContactPointData cpData) {
        if (acc.ContactPointPhones == null) {
            return;
        }
        for (ContactPointPhone cpp : acc.ContactPointPhones) {
            String normalizedPhone = CaregiverRelationshipHelper.normalizePhoneNumber(cpp.TelephoneNumber);
            if (cpp.UsageType == CaregiverContactPointHelper.USAGE_TYPE_MOBILE) {
                cpData.mobilePhones.add(normalizedPhone);
            } else if (cpp.UsageType == CaregiverContactPointHelper.USAGE_TYPE_HOME) {
                cpData.homePhones.add(normalizedPhone);
            }
        }
    }

    /**
     * @description Processes ContactPointEmail subquery results
     * @param acc Account record with ContactPointEmail subquery
     * @param cpData AccountContactPointData to populate
     */
    @TestVisible
    private static void processContactPointEmails(Account acc, AccountContactPointData cpData) {
        if (acc.ContactPointEmails == null) {
            return;
        }
        for (ContactPointEmail cpe : acc.ContactPointEmails) {
            if (String.isNotBlank(cpe.EmailAddress)) {
                cpData.emails.add(cpe.EmailAddress.toLowerCase().trim());
            }
        }
    }

    /**
     * @description Filters accounts based on ContactPoint matching logic
     * @param accountContactPointMap Map of Account Id to ContactPoint data
     * @param caregiverData Map containing caregiver information to match against
     * @return List of matching Account records
     */
    public static List<Account> filterAccountsByContactPoints(
        Map<Id, AccountContactPointData> accountContactPointMap,
        Map<String, Set<String>> caregiverData
    ) {
        List<Account> matchingAccounts = new List<Account>();
        Set<String> allLeadPhones = getAllLeadPhones(caregiverData);
        Set<String> leadEmails = CaregiverRelationshipHelper.normalizeEmailSet(caregiverData.get('emails'));
        for (AccountContactPointData cpData : accountContactPointMap.values()) {
            if (cpData == null || cpData.account == null) {
                continue;
            }
            Boolean phoneMatch = checkPhoneMatch(cpData, allLeadPhones);
            Boolean emailMatch = checkEmailMatch(cpData, leadEmails);
            if (phoneMatch || emailMatch) {
                matchingAccounts.add(cpData.account);
            }
        }
        return matchingAccounts;
    }

    /**
     * @description Combines and normalizes all lead phone numbers
     * @param caregiverData Map containing caregiver information
     * @return Set of all normalized lead phone numbers
     */
    private static Set<String> getAllLeadPhones(Map<String, Set<String>> caregiverData) {
        Set<String> leadPhones = CaregiverRelationshipHelper.normalizePhoneSet(caregiverData.get('phones'));
        Set<String> leadMobilePhones = CaregiverRelationshipHelper.normalizePhoneSet(caregiverData.get('mobilePhones'));
        Set<String> allLeadPhones = new Set<String>();
        allLeadPhones.addAll(leadPhones);
        allLeadPhones.addAll(leadMobilePhones);
        return allLeadPhones;
    }

    /**
     * @description Checks if any lead phone matches account ContactPoint phones
     * @param cpData Account ContactPoint data
     * @param allLeadPhones Set of all normalized lead phone numbers
     * @return True if any phone matches
     */
    @TestVisible
    private static Boolean checkPhoneMatch(AccountContactPointData cpData, Set<String> allLeadPhones) {
        if (allLeadPhones.isEmpty()) {
            return false;
        }
        Set<String> allAccountPhones = getAllAccountPhones(cpData);
        Set<String> intersection = new Set<String>(allLeadPhones);
        intersection.retainAll(allAccountPhones);
        return !intersection.isEmpty();
    }

    /**
     * @description Checks if any lead email matches account ContactPoint emails
     * @param cpData Account ContactPoint data
     * @param leadEmails Set of normalized lead email addresses
     * @return True if any email matches
     */
    @TestVisible
    private static Boolean checkEmailMatch(AccountContactPointData cpData, Set<String> leadEmails) {
        if (leadEmails.isEmpty()) {
            return false;
        }
        Set<String> intersection = new Set<String>(leadEmails);
        intersection.retainAll(cpData.emails);
        return !intersection.isEmpty();
    }

    /**
     * @description Gets all phone numbers from account ContactPoint data
     * @param cpData Account ContactPoint data
     * @return Set of all phone numbers (mobile and home)
     */
    private static Set<String> getAllAccountPhones(AccountContactPointData cpData) {
        Set<String> allPhones = new Set<String>();
        allPhones.addAll(cpData.mobilePhones);
        allPhones.addAll(cpData.homePhones);
        return allPhones;
    }

    /**
     * @description Adds keys for phone + email combinations
     * @param context Account key map context containing all necessary data
     */
    private static void addPhoneEmailCombinationKeys(AccountKeyMapContext context) {
        for (String phone : context.allPhones) {
            for (String email : context.emails) {
                String key = generateAccountPersonKey(context.account, email, phone);
                context.accountKeyMap.put(key, context.account);
            }
        }
    }

    /**
     * @description Adds keys for phone only (no email)
     * @param context Account key map context containing all necessary data
     */
    private static void addPhoneOnlyKeys(AccountKeyMapContext context) {
        if (context.emails.isEmpty()) {
            for (String phone : context.allPhones) {
                String key = generateAccountPersonKey(context.account, null, phone);
                context.accountKeyMap.put(key, context.account);
            }
        }
    }

    /**
     * @description Adds keys for email only (no phone)
     * @param context Account key map context containing all necessary data
     */
    private static void addEmailOnlyKeys(AccountKeyMapContext context) {
        if (context.allPhones.isEmpty()) {
            for (String email : context.emails) {
                String key = generateAccountPersonKey(context.account, email, null);
                context.accountKeyMap.put(key, context.account);
            }
        }
    }

    /**
     * @description Generates a person key from Account and contact point data
     * @param acc Account record
     * @param email Email address (can be null)
     * @param phone Phone number (can be null)
     * @return Composite key string
     */
    private static String generateAccountPersonKey(Account acc, String email, String phone) {
        return CaregiverRelationshipHelper.generatePersonKey(acc.FirstName, acc.LastName, email, phone);
    }

    /**
     * @description Builds query conditions for FirstName and LastName only
     * @param data Map containing caregiver information
     * @return List of condition strings
     */
    public static List<String> buildNameConditions(Map<String, Set<String>> data) {
        List<String> conditions = new List<String>();
        addConditionIfNotEmpty(conditions, data.get('firstNames'), 'FirstName');
        addConditionIfNotEmpty(conditions, data.get('lastNames'), 'LastName');
        return conditions;
    }

    /**
     * @description Adds condition to list if set is not empty
     * @param conds List of conditions to add to
     * @param setVals Set of values for the condition
     * @param field Field name for the condition
     */
    private static void addConditionIfNotEmpty(List<String> conds, Set<String> setVals, String field) {
        if (!CaregiverRelationshipHelper.isSetEmpty(setVals)) {
            conds.add(field + ' IN (' + wrapSetValues(setVals) + ')');
        }
    }

    /**
     * @description Helper to wrap string values in single quotes and join with commas
     * @param values Set of string values
     * @return Comma-separated string of quoted values
     */
    private static String wrapSetValues(Set<String> values) {
        List<String> wrapped = new List<String>();
        for (String v : values) {
            wrapped.add('\'' + String.escapeSingleQuotes(v) + '\'');
        }
        return String.join(wrapped, ', ');
    }
}