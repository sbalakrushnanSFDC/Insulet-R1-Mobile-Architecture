/**
 * @description Helper class for AccountRelatedObjectsService to reduce cyclomatic complexity.
 *              Contains utility methods for fetching, filtering, and processing ContactPoint records.
 * @author      Charchit Nirayanwal
 * @created Date: 2nd Feb 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       2nd Feb 2026        Charchit Nirayanwal     Initial Version
 * V1.0.1       2nd Mar 2026        Chitresh Vijayvargiya     Removed IsPrimary from ContactPointPhone record as this is handled by ContactPointPhoneHandler.
 */
public inherited sharing class AccountRelatedObjectsServiceHelper {

    // Static set to track ContactPointPhone IDs being upserted
    public static Set<Id> contactPointPhoneIdsToUpsert = new Set<Id>();

    /**
     * @description Context object for mobile phone operations
     */
    public class MobilePhoneContext {
        public Id parentId;
        public Boolean isPrimary;
    }

    /* ========================== FETCH METHODS ========================== */
    /**
     * @description Fetches ContactPointAddress records grouped by ParentId
     * @param accountIds Set of Account Ids
     * @return Map of Account Id to list of ContactPointAddress records
     */
    public static Map<Id, List<ContactPointAddress>> fetchContactPointAddressRecords(Set<Id> accountIds) {
        Map<Id, List<ContactPointAddress>> parentAddressMap = new Map<Id, List<ContactPointAddress>>();
        if (accountIds.isEmpty()){
            return parentAddressMap;
        }
        for (ContactPointAddress addressRecord : [
            SELECT Id, ParentId, Street, City, PostalCode, State, Country, Address_Status__c
            FROM ContactPointAddress
            WHERE ParentId IN :accountIds WITH SYSTEM_MODE
        ]) {
            addToMap(parentAddressMap, addressRecord.ParentId, addressRecord);
        }
        return parentAddressMap;
    }

    /**
     * @description Fetches ContactPointEmail records grouped by ParentId
     * @param accountIds Set of Account Ids
     * @return Map of Account Id to list of ContactPointEmail records
     */
    public static Map<Id, List<ContactPointEmail>> fetchContactPointEmailRecords(Set<Id> accountIds) {
        Map<Id, List<ContactPointEmail>> parentEmailMap = new Map<Id, List<ContactPointEmail>>();
        if (accountIds.isEmpty()){
            return parentEmailMap;
        }
        for (ContactPointEmail cpeRecord : [
            SELECT Id, ParentId, EmailAddress, UsageType
            FROM ContactPointEmail
            WHERE ParentId IN :accountIds WITH SYSTEM_MODE
        ]) {
            addToMap(parentEmailMap, cpeRecord.ParentId, cpeRecord);
        }
        return parentEmailMap;
    }

    /**
     * @description Fetches ContactPointPhone records grouped by ParentId
     * @param accountIds Set of Account Ids
     * @return Map of Account Id to list of ContactPointPhone records
     */
    public static Map<Id, List<ContactPointPhone>> fetchContactPointPhoneRecords(Set<Id> accountIds) {
        Map<Id, List<ContactPointPhone>> parentPhoneMap = new Map<Id, List<ContactPointPhone>>();
        if (accountIds.isEmpty()){
            return parentPhoneMap;
        }
        for (ContactPointPhone cppRecord : [
            SELECT Id, ParentId, TelephoneNumber, UsageType
            FROM ContactPointPhone
            WHERE ParentId IN :accountIds WITH SYSTEM_MODE
        ]) {
            addToMap(parentPhoneMap, cppRecord.ParentId, cppRecord);
        }
        return parentPhoneMap;
    }

    /**
     * @description Generic helper to add records to a map grouped by ParentId
     * @param parentMap Map to add records to
     * @param parentId Parent Id key
     * @param record Record to add
     */
    private static void addToMap(Map<Id, List<ContactPointAddress>> parentMap, Id parentId, ContactPointAddress record) {
        if (!parentMap.containsKey(parentId)) {
            parentMap.put(parentId, new List<ContactPointAddress>());
        }
        parentMap.get(parentId).add(record);
    }

    private static void addToMap(Map<Id, List<ContactPointEmail>> parentMap, Id parentId, ContactPointEmail record) {
        if (!parentMap.containsKey(parentId)) {
            parentMap.put(parentId, new List<ContactPointEmail>());
        }
        parentMap.get(parentId).add(record);
    }

    private static void addToMap(Map<Id, List<ContactPointPhone>> parentMap, Id parentId, ContactPointPhone record) {
        if (!parentMap.containsKey(parentId)) {
            parentMap.put(parentId, new List<ContactPointPhone>());
        }
        parentMap.get(parentId).add(record);
    }

    /* ========================== FILTER METHODS ========================== */
    /**
     * @description Filters ContactPointAddress records matching Lead address fields
     * @param cpaRecordsList List of ContactPointAddress records
     * @param convertedLead Lead record with address data
     * @param accountId Account Id
     * @return List of matching ContactPointAddress records
     */
    public static List<ContactPointAddress> filterAddressRecords(List<ContactPointAddress> cpaRecordsList, Lead convertedLead, Id accountId) {
        List<ContactPointAddress> filteredAddressRecords = new List<ContactPointAddress>();
        for(ContactPointAddress cpaRecord : cpaRecordsList){
            if(matchesAddressFields(cpaRecord, convertedLead)){
                AccountRelatedObjectsService.setContactAddressFromLead(cpaRecord, accountId, convertedLead);
                filteredAddressRecords.add(cpaRecord);
            }
        }
        return filteredAddressRecords;
    }

    /**
     * @description Checks if ContactPointAddress matches Lead address fields
     * @param cpaRecord ContactPointAddress record
     * @param convertedLead Lead record with address data
     * @return True if all address fields match
     */
    private static Boolean matchesAddressFields(ContactPointAddress cpaRecord, Lead convertedLead) {
        return cpaRecord.Street == convertedLead.Street &&
               cpaRecord.City == convertedLead.City &&
               cpaRecord.State == convertedLead.State &&
               cpaRecord.Country == convertedLead.Country &&
               cpaRecord.PostalCode == convertedLead.PostalCode;
    }

    /**
     * @description Filters ContactPointEmail records matching Lead email and UsageType = 'Home'
     * @param cpeRecordsList List of ContactPointEmail records
     * @param convertedLead Lead record with email data
     * @param accountId Account Id (Patient Person Account)
     * @return List of matching ContactPointEmail records
     */
    public static List<ContactPointEmail> filterEmailRecords(List<ContactPointEmail> cpeRecordsList, Lead convertedLead, Id accountId) {
        List<ContactPointEmail> filteredEmailRecords = new List<ContactPointEmail>();
        for(ContactPointEmail cpeRecord : cpeRecordsList){
            if(matchesEmailFields(cpeRecord, convertedLead)){
                AccountRelatedObjectsService.setContactEmailFromLead(cpeRecord, accountId, convertedLead);
                filteredEmailRecords.add(cpeRecord);
            }
        }
        return filteredEmailRecords;
    }

    /**
     * @description Checks if ContactPointEmail matches Lead email and UsageType
     * @param cpeRecord ContactPointEmail record
     * @param convertedLead Lead record with email data
     * @return True if email matches and UsageType is Home
     */
    private static Boolean matchesEmailFields(ContactPointEmail cpeRecord, Lead convertedLead) {
        return cpeRecord.EmailAddress == convertedLead.Email &&
               cpeRecord.UsageType == ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME;
    }

    /* ========================== PHONE PROCESSING METHODS ========================== */
    /**
     * @description Processes Phone and MobilePhone fields for a single Lead
     * @param convertedLead Lead record with phone data
     * @param existingPhones List of existing ContactPointPhone records (can be null)
     * @param parentId Account Id (Patient Person Account)
     * @return List of ContactPointPhone records to upsert
     */
    public static List<ContactPointPhone> processLeadPhoneFields(Lead convertedLead, List<ContactPointPhone> existingPhones, Id parentId) {
        List<ContactPointPhone> phoneRecords = new List<ContactPointPhone>();
        HomePhoneProcessContext homeContext = new HomePhoneProcessContext();
        homeContext.convertedLead = convertedLead;
        homeContext.existingPhones = existingPhones;
        homeContext.parentId = parentId;
        homeContext.phoneRecords = phoneRecords;
        Boolean hasHomePhone = processHomePhone(homeContext);
        MobilePhoneProcessContext mobileContext = new MobilePhoneProcessContext();
        mobileContext.convertedLead = convertedLead;
        mobileContext.existingPhones = existingPhones;
        mobileContext.parentId = parentId;
        mobileContext.hasHomePhone = hasHomePhone;
        mobileContext.phoneRecords = phoneRecords;
        processMobilePhone(mobileContext);
        return phoneRecords;
    }

    /**
     * @description Context object for home phone processing
     */
    private class HomePhoneProcessContext {
        Lead convertedLead;
        List<ContactPointPhone> existingPhones;
        Id parentId;
        List<ContactPointPhone> phoneRecords;
    }

    /**
     * @description Processes Home phone (Phone field) for a lead
     * @param context Context object containing all required parameters
     * @return True if Home phone was found or created
     */
    private static Boolean processHomePhone(HomePhoneProcessContext context) {
        ContactPointPhone foundPhone = findAndUpdateExistingPhone(context.convertedLead, context.existingPhones, context.parentId);
        if (foundPhone != null) {
            context.phoneRecords.add(foundPhone);
            return true;
        }

        ContactPointPhone newPhone = createNewPhoneIfNeeded(context.convertedLead, context.parentId);
        if (newPhone != null) {
            context.phoneRecords.add(newPhone);
            return true;
        }
        return false;
    }

    /**
     * @description Context object for mobile phone processing
     */
    private class MobilePhoneProcessContext {
        Lead convertedLead;
        List<ContactPointPhone> existingPhones;
        Id parentId;
        Boolean hasHomePhone;
        List<ContactPointPhone> phoneRecords;
    }

    /**
     * @description Processes Mobile phone (MobilePhone field) for a lead
     * @param context Context object containing all required parameters
     */
    private static void processMobilePhone(MobilePhoneProcessContext context) {
        MobilePhoneContext mobileContext = new MobilePhoneContext();
        mobileContext.parentId = context.parentId;
        mobileContext.isPrimary = !context.hasHomePhone;

        ContactPointPhone foundMobilePhone = findAndUpdateExistingMobilePhone(context.convertedLead.MobilePhone, context.existingPhones, mobileContext);
        if (foundMobilePhone != null) {
            context.phoneRecords.add(foundMobilePhone);
            return;
        }

        ContactPointPhone newMobilePhone = createNewMobilePhoneIfNeeded(context.convertedLead.MobilePhone, mobileContext);
        if (newMobilePhone != null) {
            context.phoneRecords.add(newMobilePhone);
        }
    }

    /**
     * @description Finds and updates existing Phone (Home) ContactPointPhone record
     * @param convertedLead Lead record with phone data
     * @param existingPhones List of existing ContactPointPhone records
     * @param parentId Account Id
     * @return Updated ContactPointPhone record if found, null otherwise
     */
    private static ContactPointPhone findAndUpdateExistingPhone(Lead convertedLead, List<ContactPointPhone> existingPhones, Id parentId) {
        if (!canProcessPhone(existingPhones, convertedLead.Phone)) {
            return null;
        }
        for (ContactPointPhone existingPhone : existingPhones) {
            if (matchesHomePhone(existingPhone, convertedLead.Phone)) {
                updatePhoneRecord(existingPhone, parentId, true);
                return existingPhone;
            }
        }
        return null;
    }

    /**
     * @description Finds and updates existing MobilePhone (Mobile) ContactPointPhone record
     * @param mobilePhoneNumber Mobile phone number from Lead
     * @param existingPhones List of existing ContactPointPhone records
     * @param context Context object containing parentId and isPrimary flag
     * @return Updated ContactPointPhone record if found, null otherwise
     */
    private static ContactPointPhone findAndUpdateExistingMobilePhone(String mobilePhoneNumber, List<ContactPointPhone> existingPhones, MobilePhoneContext context) {
        if (!canProcessPhone(existingPhones, mobilePhoneNumber)) {
            return null;
        }
        for (ContactPointPhone existingPhone : existingPhones) {
            if (matchesMobilePhone(existingPhone, mobilePhoneNumber)) {
                updateMobilePhoneRecord(existingPhone, mobilePhoneNumber, context);
                return existingPhone;
            }
        }
        return null;
    }

    /**
     * @description Creates new Phone ContactPointPhone if not found
     * @param convertedLead Lead record with phone data
     * @param parentId Account Id
     * @return New ContactPointPhone record if created, null otherwise
     */
    private static ContactPointPhone createNewPhoneIfNeeded(Lead convertedLead, Id parentId) {
        if (convertedLead.Phone != null) {
            return new ContactPointPhone(
                ParentId = parentId,
                IsPrimary = true,
                TelephoneNumber = convertedLead.Phone,
                UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME
            );
        }
        return null;
    }

    /**
     * @description Creates new MobilePhone ContactPointPhone if not found
     * @param mobilePhoneNumber Mobile phone number from Lead
     * @param context Context object containing parentId and isPrimary flag
     * @return New ContactPointPhone record if created, null otherwise
     */
    private static ContactPointPhone createNewMobilePhoneIfNeeded(String mobilePhoneNumber, MobilePhoneContext context) {
        if (mobilePhoneNumber != null) {
            return new ContactPointPhone(
                ParentId = context.parentId,
                TelephoneNumber = mobilePhoneNumber,
                UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE
            );
        }
        return null;
    }

    /**
     * @description Checks if phone processing can proceed
     * @param existingPhones List of existing phones
     * @param phoneNumber Phone number to check
     * @return True if processing can proceed
     */
    private static Boolean canProcessPhone(List<ContactPointPhone> existingPhones, String phoneNumber) {
        return existingPhones != null && !existingPhones.isEmpty() && phoneNumber != null;
    }

    /**
     * @description Checks if phone matches Home phone criteria
     * @param existingPhone Existing phone record
     * @param phoneNumber Phone number to match
     * @return True if matches
     */
    private static Boolean matchesHomePhone(ContactPointPhone existingPhone, String phoneNumber) {
        return existingPhone.TelephoneNumber == phoneNumber &&
               existingPhone.UsageType == ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME;
    }

    /**
     * @description Checks if phone matches Mobile phone criteria
     * @param existingPhone Existing phone record
     * @param mobilePhoneNumber Mobile phone number to match
     * @return True if matches
     */
    private static Boolean matchesMobilePhone(ContactPointPhone existingPhone, String mobilePhoneNumber) {
        return existingPhone.TelephoneNumber == mobilePhoneNumber &&
               existingPhone.UsageType == ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
    }

    /**
     * @description Updates phone record with Home phone settings
     * @param phoneRecord Phone record to update
     * @param parentId Account Id
     * @param isPrimary Whether phone is primary
     */
    private static void updatePhoneRecord(ContactPointPhone phoneRecord, Id parentId, Boolean isPrimary) {
        phoneRecord.ParentId = parentId;
        phoneRecord.IsPrimary = isPrimary;
    }

    /**
     * @description Updates phone record with Mobile phone settings
     * @param phoneRecord Phone record to update
     * @param mobilePhoneNumber Mobile phone number
     * @param context Context object with parentId and isPrimary
     */
    private static void updateMobilePhoneRecord(ContactPointPhone phoneRecord, String mobilePhoneNumber, MobilePhoneContext context) {
        phoneRecord.TelephoneNumber = mobilePhoneNumber;
        phoneRecord.ParentId = context.parentId;
        phoneRecord.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE;
       // phoneRecord.IsPrimary = context.isPrimary;
    }

    /* ========================== UPSERT METHODS ========================== */
    /**
     * @description Performs bulk-safe upsert of ContactPointAddress records with error logging
     * @param cpaRecordsToUpsert List of ContactPointAddress records to upsert
     * @param errorTagName Error tag name for logging
     */
    @TestVisible
    public static void upsertContactPointAddressRecord(List<ContactPointAddress> cpaRecordsToUpsert, String errorTagName){
        if(!canUpsert(cpaRecordsToUpsert, Schema.SObjectType.ContactPointAddress.isAccessible())){
            return;
        }
        Database.UpsertResult[] results = Database.upsert(cpaRecordsToUpsert, false);
        LogUpsertErrorsContext logContext = new LogUpsertErrorsContext();
        logContext.results = results;
        logContext.objectName = 'ContactPointAddress';
        logContext.errorTagName = errorTagName;
        logUpsertErrors(logContext, cpaRecordsToUpsert);
    }

    /**
     * @description Performs bulk-safe upsert of ContactPointEmail records with error logging
     * @param cpeRecordsToUpsert List of ContactPointEmail records to upsert
     * @param errorTagName Error tag name for logging
     */
    @TestVisible
    public static void upsertContactPointEmailRecords(List<ContactPointEmail> cpeRecordsToUpsert, String errorTagName){
        if(!canUpsert(cpeRecordsToUpsert, Schema.SObjectType.ContactPointEmail.isAccessible())){
            return;
        }
        Database.UpsertResult[] results = Database.upsert(cpeRecordsToUpsert, false);
        LogUpsertErrorsContext logContext = new LogUpsertErrorsContext();
        logContext.results = results;
        logContext.objectName = 'ContactPointEmail';
        logContext.errorTagName = errorTagName;
        logUpsertErrors(logContext, cpeRecordsToUpsert);
    }

    /**
     * @description Performs bulk-safe upsert of ContactPointPhone records with error logging
     * @param cppRecordsToUpsert List of ContactPointPhone records to upsert
     * @param errorTagName Error tag name for logging
     */
    public static void upsertContactPointPhoneRecords(List<ContactPointPhone> cppRecordsToUpsert, String errorTagName){
        if(!canUpsert(cppRecordsToUpsert, Schema.SObjectType.ContactPointPhone.isAccessible())){
            return;
        }

        Database.UpsertResult[] results = Database.upsert(cppRecordsToUpsert, false);

        // Add only newly CREATED ContactPointPhone IDs (not updated) for consent mapping skip logic
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess() && results[i].isCreated()) {
                contactPointPhoneIdsToUpsert.add(results[i].getId());
            }
        }

        LogUpsertErrorsContext logContext = new LogUpsertErrorsContext();
        logContext.results = results;
        logContext.objectName = 'ContactPointPhone';
        logContext.errorTagName = errorTagName;
        logUpsertErrors(logContext, cppRecordsToUpsert);
    }

    /**
     * @description Checks if upsert can proceed
     * @param recordsToUpsert List of records to upsert
     * @param isAccessible Whether object is accessible
     * @return True if upsert can proceed
     */
    private static Boolean canUpsert(List<Object> recordsToUpsert, Boolean isAccessible) {
        return recordsToUpsert != null && !recordsToUpsert.isEmpty() && isAccessible;
    }

    /**
     * @description Context object for logging upsert errors
     */
    private class LogUpsertErrorsContext {
        Database.UpsertResult[] results;
        String objectName;
        String errorTagName;
    }

    /**
     * @description Logs upsert errors for ContactPointAddress records
     * @param context Context object containing all required parameters
     * @param records Records that were upserted
     */
    private static void logUpsertErrors(LogUpsertErrorsContext context, List<ContactPointAddress> records) {
        for(Integer i = 0; i < context.results.size(); i++){
            if (!context.results[i].isSuccess()){
                Logger.error('Error upserting ' + context.objectName + ' records', context.results[i])
                    .setRecord(records[i])
                    .addTag(context.errorTagName);
            }
        }
    }

    /**
     * @description Logs upsert errors for ContactPointEmail records
     * @param context Context object containing all required parameters
     * @param records Records that were upserted
     */
    private static void logUpsertErrors(LogUpsertErrorsContext context, List<ContactPointEmail> records) {
        for(Integer i = 0; i < context.results.size(); i++){
            if (!context.results[i].isSuccess()){
                Logger.error('Error upserting ' + context.objectName + ' records', context.results[i])
                    .setRecord(records[i])
                    .addTag(context.errorTagName);
            }
        }
    }

    /**
     * @description Logs upsert errors for ContactPointPhone records
     * @param context Context object containing all required parameters
     * @param records Records that were upserted
     */
    private static void logUpsertErrors(LogUpsertErrorsContext context, List<ContactPointPhone> records) {
        for(Integer i = 0; i < context.results.size(); i++){
            if (!context.results[i].isSuccess()){
                Logger.error('Error upserting ' + context.objectName + ' records', context.results[i])
                    .setRecord(records[i])
                    .addTag(context.errorTagName);
            }
        }
    }
}