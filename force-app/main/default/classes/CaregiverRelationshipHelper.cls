/**
 * @description Helper class for CaregiverRelationshipService
 * Contains utility methods for ContactPoint management, Account matching, and data processing
 * Created Date : Jan 29, 2026
 * Created By   : Charchit Nirayanwal
 */
public inherited sharing class CaregiverRelationshipHelper {
    // ==================== CONTACTPOINT METHODS (Delegated to CaregiverContactPointHelper) ====================


    // ==================== UTILITY METHODS ====================

    /**
     * @description Normalizes phone number for comparison (removes formatting)
     * @param phoneNumber Phone number string
     * @return Normalized phone number
     */
    public static String normalizePhoneNumber(String phoneNumber) {
        if (String.isBlank(phoneNumber)) {
            return '';
        }
        // Remove all non-digit characters
        return phoneNumber.replaceAll('[^0-9]', '');
    }

    /**
     * @description Normalizes a set of phone numbers
     * @param phones Set of phone number strings
     * @return Set of normalized phone numbers
     */
    public static Set<String> normalizePhoneSet(Set<String> phones) {
        Set<String> normalized = new Set<String>();
        if (phones != null) {
            for (String phone : phones) {
                String normalizedPhone = normalizePhoneNumber(phone);
                if (String.isNotBlank(normalizedPhone)) {
                    normalized.add(normalizedPhone);
                }
            }
        }
        return normalized;
    }

    /**
     * @description Normalizes a set of email addresses
     * @param emails Set of email address strings
     * @return Set of normalized email addresses
     */
    public static Set<String> normalizeEmailSet(Set<String> emails) {
        Set<String> normalized = new Set<String>();
        if (emails != null) {
            for (String email : emails) {
                if (String.isNotBlank(email)) {
                    normalized.add(email.toLowerCase().trim());
                }
            }
        }
        return normalized;
    }

    /**
     * @description Helper method to generate a composite key for matching
     * @param objectFields Map containing firstName, lastName, email, phone
     * @return Composite key string
     */
    public static String generatePersonKey(Map<String,String> objectFields) {
        String f = objectFields.get('firstName')?.trim().toLowerCase();
        String l = objectFields.get('lastName')?.toLowerCase();
        String e = objectFields.get('email')?.trim().toLowerCase();
        String p = objectFields.get('phone')?.trim();
        return generatePersonKey(f, l, e, p);
    }

    /**
     * @description Helper method to generate a composite key for matching
     * @param firstName First name
     * @param lastName Last name
     * @param email Email address
     * @param phone Phone number
     * @return Composite key string
     */
    public static String generatePersonKey(String firstName, String lastName, String email, String phone) { // NOPMD ExcessiveParameterList - Utility method with 4 related parameters
        String f = firstName != null ? firstName.trim().toLowerCase() : null;
        String l = lastName != null ? lastName.toLowerCase() : null;
        String e = email != null ? email.trim().toLowerCase() : null;
        String p = phone != null ? phone.trim() : null;
        // Normalize phone number in key generation
        if (String.isNotBlank(p)) {
            p = normalizePhoneNumber(p);
        }
        return f + '|' + l + '|' + e + '|' + p;
    }

    /**
     * @description Creates new Account record from Lead caregiver fields
     * @param ld Lead record containing caregiver information
     * @param recordTypeId RecordTypeId to assign to the Account
     * @return New Account record populated with caregiver details
     */
    public static Account createAccountFromLead(Lead ld, Id recordTypeId) {
        Account newAcc = new Account();
        newAcc.FirstName = ld.Caregiver_First_Name__c;
        newAcc.LastName = ld.Caregiver_Last_Name__c != null ? ld.Caregiver_Last_Name__c : ld.LastName;
        // Use MobilePhone if available, otherwise use Phone
        newAcc.Phone = String.isNotBlank(ld.MobilePhone) ? ld.MobilePhone : ld.Phone;
        newAcc.PersonEmail = ld.Email;
        newAcc.RecordTypeId = recordTypeId;
        return newAcc;
    }

    /**
     * @description Inserts Account records using bulk-safe DML and builds Lead to Account mapping
     * @param leadList List of Lead records used to create Account records
     * @param accountsToInsert List of Account records to insert
     * @param errorTagName Tag name for error logging
     * @return Map of Lead Ids to successfully inserted Accounts
     */
    @TestVisible
    public static Map<Id, Account> insertAccountsAndBuildMap(List<Lead> leadList, List<Account> accountsToInsert, String errorTagName) {
        Map<Id, Account> leadToAccountMap = new Map<Id, Account>();
        if (leadList == null || leadList.isEmpty() || accountsToInsert == null || accountsToInsert.isEmpty()) {
            return leadToAccountMap;
        }
        //make it insert and bypass duplicate rule
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        dml.optAllOrNone = false;
        Database.SaveResult[] saveResults = Database.insert(accountsToInsert, dml, AccessLevel.SYSTEM_MODE);
        processInsertResults(leadList, accountsToInsert, saveResults, leadToAccountMap, errorTagName);
        return leadToAccountMap;
    }

    /**
     * @description Processes database insert results and builds the lead to account map
     * @param leadList List of Lead records
     * @param accountsToInsert List of Account records that were inserted
     * @param saveResults Database save results
     * @param leadToAccountMap Map to populate with successful inserts
     * @param errorTagName Tag name for error logging
     */
    private static void processInsertResults( // NOPMD ExcessiveParameterList - Helper method requires all parameters for processing insert results
        List<Lead> leadList,
        List<Account> accountsToInsert,
        Database.SaveResult[] saveResults,
        Map<Id, Account> leadToAccountMap,
        String errorTagName
    ) {
        Integer index = 0;
        for (Database.SaveResult sr : saveResults) {
            if (index >= leadList.size()) {
                break;
            }
            Lead ld = leadList[index];
            Account accountToProcess = accountsToInsert[index];
            if (sr.isSuccess()) {
                leadToAccountMap.put(ld.Id, accountToProcess);
            } else {
                logInsertErrors(sr, accountToProcess, errorTagName);
            }
            index++;
        }
    }

    /**
     * @description Logs errors from failed account insert
     * @param sr Database save result
     * @param account Account record that failed to insert
     * @param errorTagName Tag name for error logging
     */
    private static void logInsertErrors(Database.SaveResult sr, Account account, String errorTagName) {
        for (Database.Error err : sr.getErrors()) {
            Logger.error('Failed to insert Account record: ' + err.getMessage(), sr)
                .setRecord(account)
                .addTag(errorTagName);
        }
    }

    // ==================== DATA PROCESSING METHODS ====================

    /**
     * @description Helper to check if caregiverData is null or all sets are empty
     * @param caregiverData Map containing caregiver data sets
     * @return True if data is null or all sets are empty
     */
    @TestVisible
    public static Boolean isCaregiverDataEmpty(Map<String, Set<String>> caregiverData) {
        if (caregiverData == null){
            return true;
        }
        return (isSetEmpty(caregiverData.get('emails')) &&
                isSetEmpty(caregiverData.get('phones')) &&
                isSetEmpty(caregiverData.get('mobilePhones')) &&
                isSetEmpty(caregiverData.get('firstNames')) &&
                isSetEmpty(caregiverData.get('lastNames')));
    }


    /**
     * @description Helper to check if a set is null or empty
     * @param s Set to check
     * @return True if set is null or empty
     */
    public static Boolean isSetEmpty(Set<String> s) {
        return s == null || s.isEmpty();
    }


    /**
     * @description Helper method to check null or empty list
     * @param lst List to check
     * @return True if list is null or empty
     */
    public static Boolean isNullOrEmpty(List<Object> lst) {
        return lst == null || lst.isEmpty();
    }

    /**
     * @description Helper to check null or empty map
     * @param mapData Map to check
     * @return True if map is null or empty
     */
    public static Boolean isNullOrEmptyMap(Map<Id, Object> mapData) {
        return mapData == null || mapData.isEmpty();
    }
}