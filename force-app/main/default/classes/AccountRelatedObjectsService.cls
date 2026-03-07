/**
 * @description Service class for mapping Lead fields (Address, Email, Phone) to ContactPoint records
 *              on the related Account after Lead conversion.
 * @author Sunil Khanchandani
 * @date Oct 02, 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       02-10-2025         Sunil Khanchandani            Initial Version
 * V1.0.0       08-01-2026         Priyansh Shukla               NGASIM-1642
 * V1.0.1       02-02-2026         Charchit Nirayanwal           US - NGASIM-1147
 * V1.0.2       09-02-2026         Neeraj Kumar                  NGCRMI-2467
 * V1.0.3       24-02-2026         Bijayalaxmi Prusty           NGASIM-2157
 */
public inherited sharing class AccountRelatedObjectsService {
    /**
     * @description Error tag name used in logging failed DML operations
     */
    public static String errorTagName;
    /**
     * @description Maps ContactPoint fields (Address, Email, Phone) from converted Leads to their Accounts
     * @param convertedLeads List of converted Lead records
     * @param accountRecordTypeId RecordTypeId of the Account
     * @param tagName Error logging tag
     */
    public static void mapContactPointFields(List<Lead> convertedLeads, Id accountRecordTypeId, String tagName) {
        if (convertedLeads == null || convertedLeads.isEmpty()) {
            return;
        }
        errorTagName = tagName;
        Map<Id, Lead> convertedLeadMap = buildConvertedLeadMap(convertedLeads);
        if (!convertedLeadMap.isEmpty()) {
            AccountService.getConvertedAccounts(convertedLeadMap.keySet());
            if(accountRecordTypeId != ConstantsUtil.ACCOUNT_PROVIDER_RT) {
                mapContactPointAddressField(convertedLeadMap);
            }
            mapContactPointEmailField(convertedLeadMap);
            mapContactPointPhoneField(convertedLeadMap);
        }
    }

    /**
     * @description Builds a map of Account Id to Lead from converted leads
     * @param convertedLeads List of converted Lead records
     * @return Map of Account Id to Lead records
     */
    private static Map<Id, Lead> buildConvertedLeadMap(List<Lead> convertedLeads) {
        Map<Id, Lead> convertedLeadMap = new Map<Id, Lead>();
        for (Lead ld : convertedLeads) {
            if (ld.ConvertedAccountId != null) {
                convertedLeadMap.put(ld.ConvertedAccountId, ld);
            }
        }
        return convertedLeadMap;
    }
    /* ========================== FETCH METHODS ========================== */
    /**
     * @description Fetches ContactPointAddress records grouped by ParentId
     * @param accountIds Set of Account Ids
     * @return Map of Account Id to list of ContactPointAddress records
     */
    private static Map<Id, List<ContactPointAddress>> fetchContactPointAddressRecords(Set<Id> accountIds) {
        return AccountRelatedObjectsServiceHelper.fetchContactPointAddressRecords(accountIds);
    }
    /**
     * @description Fetches ContactPointEmail records grouped by ParentId
     * @param accountIds Set of Account Ids
     * @return Map of Account Id to list of ContactPointEmail records
     */
    private static Map<Id, List<ContactPointEmail>> fetchContactPointEmailRecords(Set<Id> accountIds) {
        return AccountRelatedObjectsServiceHelper.fetchContactPointEmailRecords(accountIds);
    }
    /**
     * @description Fetches ContactPointPhone records grouped by ParentId
     * @param accountIds Set of Account Ids
     * @return Map of Account Id to list of ContactPointPhone records
     */
    private static Map<Id, List<ContactPointPhone>> fetchContactPointPhoneRecords(Set<Id> accountIds) {
        return AccountRelatedObjectsServiceHelper.fetchContactPointPhoneRecords(accountIds);
    }
    /* ========================== MAPPING METHODS ========================== */
    /**
     * @description Maps Address fields from converted Leads to ContactPointAddress records
     * @param convertedLeadMap Map of Account Id to converted Lead records
     */
    private static void mapContactPointAddressField(Map<Id, Lead> convertedLeadMap) {
        Map<Id, List<ContactPointAddress>> parentAddressMap = fetchContactPointAddressRecords(convertedLeadMap.keySet());
        List<ContactPointAddress> cpaRecordsToUpsert = new List<ContactPointAddress>();
        Map<Id, Account> accountMap = AccountService.getConvertedAccounts(convertedLeadMap.keySet());
		    //OrgSync Start - leveraging AccountIds for Orgsync Purpose
		    OrgSync_UtilityService.parentIds = convertedLeadMap.keySet();
        //OrgSync End - leveraging AccountIds for Orgsync Purpose
        for (Id parentId : convertedLeadMap.keySet()) {
            Lead convertedLead = convertedLeadMap.get(parentId);
            AddressRecordContext context = new AddressRecordContext();
            context.parentId = parentId;
            context.convertedLead = convertedLead;
            context.parentAddressMap = parentAddressMap;
            context.accountMap = accountMap;
            List<ContactPointAddress> addressRecords = getAddressRecordsForLead(context);
            cpaRecordsToUpsert.addAll(addressRecords);
        }
        AccountRelatedObjectsServiceHelper.upsertContactPointAddressRecord(cpaRecordsToUpsert, errorTagName);
    }

    /**
     * @description Context object for address record processing
     */
    private class AddressRecordContext {
        Id parentId;
        Lead convertedLead;
        Map<Id, List<ContactPointAddress>> parentAddressMap;
        Map<Id, Account> accountMap;
    }

    /**
     * @description Gets ContactPointAddress records for a lead (existing filtered or new)
     * @param context Context object containing all required parameters
     * @return List of ContactPointAddress records to upsert
     */
    // NOPMD ExcessiveParameterList - Uses context object to reduce parameters
    private static List<ContactPointAddress> getAddressRecordsForLead(AddressRecordContext context) {
        List<ContactPointAddress> filteredAddressRecords = getFilteredAddressRecords(context.parentId, context.convertedLead, context.parentAddressMap);
        if (!filteredAddressRecords.isEmpty()) {
            return filteredAddressRecords;
        }
        return new List<ContactPointAddress>{ setFieldsForAddressRecord(context.parentId, context.accountMap, context.convertedLead) };
    }

    /**
     * @description Gets filtered ContactPointAddress records for a lead
     * @param parentId Account Id
     * @param convertedLead Lead record
     * @param parentAddressMap Map of existing ContactPointAddress records
     * @return List of filtered ContactPointAddress records (empty if none match)
     */
    // NOPMD ExcessiveParameterList - 3 parameters is acceptable for this utility method
    private static List<ContactPointAddress> getFilteredAddressRecords(Id parentId, Lead convertedLead, Map<Id, List<ContactPointAddress>> parentAddressMap) {
        if (parentAddressMap.containsKey(parentId)) {
            return AccountRelatedObjectsServiceHelper.filterAddressRecords(parentAddressMap.get(parentId), convertedLead, parentId);
        }
        return new List<ContactPointAddress>();
    }
    /**
     * @description Creates new ContactPointAddress record from Lead data
     * @param parentId Account Id
     * @param accountMap Map of Account records
     * @param convertedLead Lead record with address data
     * @return ContactPointAddress record ready for upsert
     */
    // NOPMD ExcessiveParameterList - 3 parameters is acceptable for this utility method
    private static ContactPointAddress setFieldsForAddressRecord(Id parentId, Map<Id, Account> accountMap, Lead convertedLead) {
        ContactPointAddress newCpa = new ContactPointAddress();
        newCpa.Name = setAddressRecordName(accountMap.get(parentId));
        newCpa.IsPrimary = true;
        newCpa.IsDefault = true;
        newCpa.AddressType = 'Billing';
        newCpa.IsActive = true;
        newCpa = setContactAddressFromLead(newCpa, parentId, convertedLead);
        return newCpa;
    }
    /**
     * @description Maps Email fields from converted Leads to ContactPointEmail records
     * @param convertedLeadMap Map of Account Id to converted Lead records
     */
    private static void mapContactPointEmailField(Map<Id, Lead> convertedLeadMap) {
        Map<Id, List<ContactPointEmail>> parentEmailMap = fetchContactPointEmailRecords(convertedLeadMap.keySet());
        List<ContactPointEmail> cpeRecordsToUpsert = new List<ContactPointEmail>();

        for (Id parentId : convertedLeadMap.keySet()) {
            Lead convertedLead = convertedLeadMap.get(parentId);
            if (convertedLead.Email != null) {
                List<ContactPointEmail> emailRecords = getEmailRecordsForLead(parentId, convertedLead, parentEmailMap);
                cpeRecordsToUpsert.addAll(emailRecords);
            }
        }
        AccountRelatedObjectsServiceHelper.upsertContactPointEmailRecords(cpeRecordsToUpsert, errorTagName);
    }

    /**
     * @description Gets ContactPointEmail records for a lead (existing filtered or new)
     * @param parentId Account Id
     * @param convertedLead Lead record
     * @param parentEmailMap Map of existing ContactPointEmail records
     * @return List of ContactPointEmail records to upsert
     */
    // NOPMD ExcessiveParameterList - 3 parameters is acceptable for this utility method
    private static List<ContactPointEmail> getEmailRecordsForLead(Id parentId, Lead convertedLead, Map<Id, List<ContactPointEmail>> parentEmailMap) {
        List<ContactPointEmail> filteredEmailRecords = getFilteredEmailRecords(parentId, convertedLead, parentEmailMap);
        if (!filteredEmailRecords.isEmpty()) {
            return filteredEmailRecords;
        }
        return new List<ContactPointEmail>{ setFieldsForEmailRecord(parentId, convertedLead) };
    }

    /**
     * @description Gets filtered ContactPointEmail records for a lead
     * @param parentId Account Id
     * @param convertedLead Lead record
     * @param parentEmailMap Map of existing ContactPointEmail records
     * @return List of filtered ContactPointEmail records (empty if none match)
     */
    // NOPMD ExcessiveParameterList - 3 parameters is acceptable for this utility method
    private static List<ContactPointEmail> getFilteredEmailRecords(Id parentId, Lead convertedLead, Map<Id, List<ContactPointEmail>> parentEmailMap) {
        if (parentEmailMap.containsKey(parentId)) {
            return AccountRelatedObjectsServiceHelper.filterEmailRecords(parentEmailMap.get(parentId), convertedLead, parentId);
        }
        return new List<ContactPointEmail>();
    }
    /**
     * @description Creates new ContactPointEmail record from Lead data
     * @param parentId Account Id (Patient Person Account)
     * @param convertedLead Lead record with email data
     * @return ContactPointEmail record ready for upsert
     */
    private static ContactPointEmail setFieldsForEmailRecord(Id parentId, Lead convertedLead) {
        ContactPointEmail newCpe = new ContactPointEmail(
            ParentId = parentId,
            IsPrimary = true,
            EmailAddress = convertedLead.Email,
            UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME
        );
        return newCpe;
    }
    /**
     * @description Maps Phone and MobilePhone fields from converted Leads to ContactPointPhone records
     *              Phone field creates ContactPointPhone with UsageType = 'Home'
     *              MobilePhone field creates ContactPointPhone with UsageType = 'Mobile'
     * @param convertedLeadMap Map of Account Id to converted Lead records
     */
    private static void mapContactPointPhoneField(Map<Id, Lead> convertedLeadMap) {
        Map<Id, List<ContactPointPhone>> parentPhoneMap = fetchContactPointPhoneRecords(convertedLeadMap.keySet());
        List<ContactPointPhone> cppRecordsToUpsert = new List<ContactPointPhone>();

        for (Id parentId : convertedLeadMap.keySet()) {
            Lead convertedLead = convertedLeadMap.get(parentId);
            List<ContactPointPhone> existingPhones = parentPhoneMap.get(parentId);
            List<ContactPointPhone> phoneRecords = AccountRelatedObjectsServiceHelper.processLeadPhoneFields(convertedLead, existingPhones, parentId);
            cppRecordsToUpsert.addAll(phoneRecords);
        }
        AccountRelatedObjectsServiceHelper.upsertContactPointPhoneRecords(cppRecordsToUpsert, errorTagName);
    }
    /**
     * @description Constructs ContactPointAddress name from Account name
     * Handles FirstName, MiddleName, and LastName combinations
     * @param convertedAccount Account record
     * @return Address name (max 255 characters)
     */
    private static String setAddressRecordName(Account convertedAccount) {
        String baseName = buildAccountBaseName(convertedAccount);
        String addressName = baseName + ' Address';
        return truncateToMaxLength(addressName, 255);
    }

    /**
     * @description Builds base name from Account FirstName, MiddleName, and LastName
     * @param convertedAccount Account record
     * @return Base name string
     */
    private static String buildAccountBaseName(Account convertedAccount) {
        Boolean hasFirstName = String.isNotBlank(convertedAccount.FirstName);
        Boolean hasMiddleName = String.isNotBlank(convertedAccount.MiddleName);

        if (hasFirstName && hasMiddleName) {
            return convertedAccount.FirstName + ' ' + convertedAccount.MiddleName + ' ' + convertedAccount.LastName;
        } else if (hasFirstName) {
            return convertedAccount.FirstName + ' ' + convertedAccount.LastName;
        } else if (hasMiddleName) {
            return convertedAccount.MiddleName + ' ' + convertedAccount.LastName;
        } else {
            return convertedAccount.LastName;
        }
    }

    /**
     * @description Truncates string to maximum length
     * @param input String to truncate
     * @param maxLength Maximum length
     * @return Truncated string
     */
    private static String truncateToMaxLength(String input, Integer maxLength) {
        if (input.length() > maxLength) {
            return input.substring(0, maxLength);
        }
        return input;
    }
    /**
     * @description Populates ContactPointAddress record from Lead fields
     * @param cpaRecord ContactPointAddress record to populate
     * @param accountId Account Id
     * @param convertedLead Lead record with address data
     * @return Populated ContactPointAddress record
     */
    // NOPMD ExcessiveParameterList - 3 parameters is acceptable for this utility method
    public static ContactPointAddress setContactAddressFromLead(ContactPointAddress cpaRecord, String accountId, Lead convertedLead) {
        cpaRecord.ParentId = accountId;
        cpaRecord.Street = convertedLead.Street;
        cpaRecord.City = convertedLead.City;
        cpaRecord.State = convertedLead.State;
        cpaRecord.Country = convertedLead.Country;
        cpaRecord.PostalCode = convertedLead.PostalCode;
        cpaRecord.Address_Status__c = convertedLead.Address_Status__c;
        return cpaRecord;
    }
    /**
     * @description Populates ContactPointEmail record from Lead fields
     * @param cpeRecord ContactPointEmail record to populate
     * @param accountId Account Id (Patient Person Account)
     * @param convertedLead Lead record with email data
     * @return Populated ContactPointEmail record
     */
    public static ContactPointEmail setContactEmailFromLead(ContactPointEmail cpeRecord, String accountId, Lead convertedLead) {
        cpeRecord.EmailAddress = convertedLead.Email;
        cpeRecord.ParentId = accountId;
        cpeRecord.UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME;
        return cpeRecord;
    }
    /* ========================== UPSERT HELPERS ========================== */
    /**
     * @description Performs bulk-safe upsert of ContactPointAddress records with error logging
     * @param cpaRecordsToUpsert List of ContactPointAddress records to upsert
     */
    @TestVisible
    private static void upsertContactPointAddressRecord(List<ContactPointAddress> cpaRecordsToUpsert){
        AccountRelatedObjectsServiceHelper.upsertContactPointAddressRecord(cpaRecordsToUpsert, errorTagName);
    }
    /**
     * @description Performs bulk-safe upsert of ContactPointEmail records with error logging
     * @param cpeRecordsToUpsert List of ContactPointEmail records to upsert
     */
    @TestVisible
    private static void upsertContactPointEmailRecords(List<ContactPointEmail> cpeRecordsToUpsert){
        AccountRelatedObjectsServiceHelper.upsertContactPointEmailRecords(cpeRecordsToUpsert, errorTagName);
    }
}