/**
 * @description Handler class for ContactPointPhone triggers.
 *              Handles Insert, Update, and Delete events for ContactPointPhone.
 *              Converts flow logic from Contact_Point_Phone_After_Insert_After_Update flow.
 * Created Date : Dec 2025
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Feb 2026       Charchit N.           Initial Version (NGASIM-2207)
 * V2.1.0       23rd Feb 2026       Chitresh V.           (NGASIM-2354)
 */

public with sharing class ContactPointPhoneHandler {
    /**
     * @description Static variable to control behavior when newly created ContactPointPhone records
     *              have IsPrimary = true. When true, the new phone remains primary (IsPrimary = true)
     *              and Account.Phone is updated. Existing same-type primary ContactPointPhone records
     *              will be set to IsPrimary = false (allows one Mobile + one non-Mobile primary per account).
     *              When false (default), normal behavior: new primary demotes same UsageType primaries.
     */
    public static Boolean skipSetPrimaryOnNewContactPointPhone = false;

    /**
     * @description Handles primary ContactPointPhone logic before insert.
     *              Allows up to two primaries per account: one Mobile and one non-Mobile.
     *              - Single record: that record is primary.
     *              - Mobile + non-Mobile: both are primary.
     *              - Multiple non-Mobile: prioritize UsageType = 'Phone' over others, then 'Home', then last in list.
     * @param phoneRecords List of ContactPointPhone records being inserted
     */
    public static void handleBeforeInsert(List<ContactPointPhone> phoneRecords) {
        if (phoneRecords == null || phoneRecords.isEmpty()) {
            return;
        }

        if (skipSetPrimaryOnNewContactPointPhone) {
            return; // Skip setting primary in before insert when flag is true
        }

        processPrimaryContactPointPhoneBeforeInsert(phoneRecords);
    }

    /**
     * @description Processes primary ContactPointPhone logic before insert.
     *              Allows up to two primaries per account: one Mobile and one non-Mobile.
     *              When a ContactPointPhone is marked Primary with UsageType = Mobile,
     *              the after insert handler updates ContactPointTypeConsent (Transactional SMS)
     *              to PrivacyConsentStatus = Pending Opt In for PartyId = Account.PersonIndividualId.
     *              Modifies the original phoneRecords list directly.
     * @param phoneRecords List of ContactPointPhone records being inserted (modified in place)
     */
    private static void processPrimaryContactPointPhoneBeforeInsert(List<ContactPointPhone> phoneRecords) {
        Map<Id, List<ContactPointPhone>> accountToPhonesMap = buildAccountToPhonesMap(phoneRecords);
        for (Id accountId : accountToPhonesMap.keySet()) {
            assignPrimaryForAccountPhones(accountToPhonesMap.get(accountId));
        }
    }

    /**
     * @description Groups ContactPointPhone records by their parent Account Id.
     *              Skips records with null ParentId.
     * @param phoneRecords List of ContactPointPhone records to group
     * @return Map of Account Id to list of ContactPointPhone records
     */
    private static Map<Id, List<ContactPointPhone>> buildAccountToPhonesMap(List<ContactPointPhone> phoneRecords) {
        Map<Id, List<ContactPointPhone>> accountToPhonesMap = new Map<Id, List<ContactPointPhone>>();
        for (ContactPointPhone phone : phoneRecords) {
            if (phone.ParentId == null) {
                continue;
            }
            if (!accountToPhonesMap.containsKey(phone.ParentId)) {
                accountToPhonesMap.put(phone.ParentId, new List<ContactPointPhone>());
            }
            accountToPhonesMap.get(phone.ParentId).add(phone);
        }
        return accountToPhonesMap;
    }

    /**
     * @description Assigns IsPrimary for phones belonging to a single account.
     *              Single record becomes primary; multiple records use assignPrimariesForMultiplePhones.
     * @param phonesForAccount List of ContactPointPhone records for one account
     */
    private static void assignPrimaryForAccountPhones(List<ContactPointPhone> phonesForAccount) {
        if (phonesForAccount.isEmpty()) {
            return;
        }
        if (phonesForAccount.size() == 1) {
            phonesForAccount[0].IsPrimary = true;
            return;
        }
        assignPrimariesForMultiplePhones(phonesForAccount);
    }

    /**
     * @description Assigns primary flags for multiple phones: last Mobile phones in the list sets IsPrimary=true,
     *              and one non-Mobile is selected as primary (prefers Home UsageType, else last in list).
     * @param phonesForAccount List of ContactPointPhone records for one account
     */
    private static void assignPrimariesForMultiplePhones(List<ContactPointPhone> phonesForAccount) {
        List<ContactPointPhone> mobilePhones = new List<ContactPointPhone>();
        List<ContactPointPhone> nonMobilePhones = new List<ContactPointPhone>();
        for (ContactPointPhone phone : phonesForAccount) {
            if (phone.UsageType == ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE) {
                mobilePhones.add(phone);
            } else {
                nonMobilePhones.add(phone);
            }
        }

        ContactPointPhone primaryMobile = null;
        if (!mobilePhones.isEmpty()) {
            primaryMobile = mobilePhones[mobilePhones.size() - 1];
            for (ContactPointPhone phone : mobilePhones) {
                phone.IsPrimary = (phone == primaryMobile);
            }
        }

        ContactPointPhone primaryNonMobile = selectPrimaryNonMobile(nonMobilePhones);
        for (ContactPointPhone phone : nonMobilePhones) {
            phone.IsPrimary = (phone == primaryNonMobile);
        }
    }

    /**
     * @description Selects one non-Mobile phone as primary. Prefers UsageType = Home, otherwise last in list.
     * @param nonMobilePhones List of non-Mobile ContactPointPhone records
     * @return The ContactPointPhone selected as primary, or null if list is empty
     */
    private static ContactPointPhone selectPrimaryNonMobile(List<ContactPointPhone> nonMobilePhones) {
        if (nonMobilePhones.isEmpty()) {
            return null;
        }
        List<ContactPointPhone> phonesWithHomeUsageType = new List<ContactPointPhone>();
        for (ContactPointPhone phone : nonMobilePhones) {
            if (phone.UsageType == ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME) {
                phonesWithHomeUsageType.add(phone);
            }
        }
        if (!phonesWithHomeUsageType.isEmpty()) {
            return phonesWithHomeUsageType[phonesWithHomeUsageType.size() - 1];
        }
        return nonMobilePhones[nonMobilePhones.size() - 1];
    }

    /**
     * @description Handles primary ContactPointPhone logic after insert.
     *              Allows two primaries per account: one Mobile and one non-Mobile.
     *              Demotes only same UsageType primaries (Mobile demotes other Mobiles; non-Mobile demotes other non-Mobiles).
     *              Updates Account with the current primary phone (prefers Mobile, else non-Mobile).
     * @param phoneRecords List of ContactPointPhone records that were inserted
     * @param newRecordsMap Map of new records
     */
    public static void handleAfterInsert(List<ContactPointPhone> phoneRecords, Map<Id, SObject> newRecordsMap) {
        if (phoneRecords == null || phoneRecords.isEmpty()) {
            return;
        }

        try {
            handlePrimaryContactPointPhoneAfterInsert(phoneRecords, newRecordsMap);
        } catch (Exception e) {
            Logger.error('ContactPointPhoneHandler: Error processing contact point phones after insert. Details: ' + e.getMessage())
                .addTag(ConstantsUtil.ASIM_TAG);
        }
    }

    /**
     * @description Handles primary ContactPointPhone logic after update.
     *              Allows two primaries per account: one Mobile and one non-Mobile.
     *              Demotes only same UsageType primaries (Mobile demotes other Mobiles; non-Mobile demotes other non-Mobiles).
     *              Updates Account with the current primary phone (prefers Mobile, else non-Mobile).
     * @param phoneRecords List of ContactPointPhone records that were updated
     * @param updatedRecordsMap Map of updated records
     * @param oldRecordsMap Map of old records
     */
    public static void handleAfterUpdate(List<ContactPointPhone> phoneRecords, Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        if (phoneRecords == null || phoneRecords.isEmpty()) {
            return;
        }

        try {
            handlePrimaryContactPointPhoneAfterUpdate(phoneRecords, updatedRecordsMap, oldRecordsMap);
        } catch (Exception e) {
            Logger.error('ContactPointPhoneHandler: Error processing contact point phones after update. Details: ' + e.getMessage())
                .addTag(ConstantsUtil.ASIM_TAG);
        }
    }

    /**
     * @description Handles primary ContactPointPhone logic after insert implementation.
     *              Allows two primaries per account: one Mobile and one non-Mobile.
     *              Demotes only same UsageType primaries when a new primary is inserted.
     * @param phoneRecords List of ContactPointPhone records that were inserted
     * @param newRecordsMap Map of new records
     */
    private static void handlePrimaryContactPointPhoneAfterInsert(List<ContactPointPhone> phoneRecords, Map<Id, SObject> newRecordsMap) {
        Map<Id, ContactPointPhone> primaryMobileByAccount = new Map<Id, ContactPointPhone>();
        Map<Id, ContactPointPhone> primaryNonMobileByAccount = new Map<Id, ContactPointPhone>();
        buildPrimaryMapsFromPhones(phoneRecords, primaryMobileByAccount, primaryNonMobileByAccount);

        Set<Id> accountsWithPrimary = getAccountsWithPrimary(primaryMobileByAccount, primaryNonMobileByAccount);
        if (accountsWithPrimary.isEmpty()) {
            return;
        }

        Map<Id, Account> parentAccountsMap = queryParentAccounts(accountsWithPrimary);
        applyPrimaryPhoneUpdates(primaryMobileByAccount, primaryNonMobileByAccount, parentAccountsMap);
    }
    /**
     * @description Handles primary ContactPointPhone logic after update implementation.
     *              Allows two primaries per account: one Mobile and one non-Mobile.
     *              Demotes only same UsageType primaries when a phone is updated to primary.
     * @param phoneRecords List of ContactPointPhone records that were updated
     * @param updatedRecordsMap Map of updated records
     * @param oldRecordsMap Map of old records
     */
    private static void handlePrimaryContactPointPhoneAfterUpdate(List<ContactPointPhone> phoneRecords, Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        Map<Id, ContactPointPhone> primaryMobileByAccount = new Map<Id, ContactPointPhone>();
        Map<Id, ContactPointPhone> primaryNonMobileByAccount = new Map<Id, ContactPointPhone>();
        buildPrimaryMapsFromPhones(phoneRecords, primaryMobileByAccount, primaryNonMobileByAccount);

        Set<Id> accountsWithPrimary = getAccountsWithPrimary(primaryMobileByAccount, primaryNonMobileByAccount);
        if (accountsWithPrimary.isEmpty()) {
            return;
        }

        Map<Id, Account> parentAccountsMap = queryParentAccounts(accountsWithPrimary);
        applyPrimaryPhoneUpdates(primaryMobileByAccount, primaryNonMobileByAccount, parentAccountsMap);
    }

    /**
     * @description Populates maps of primary Mobile and primary non-Mobile ContactPointPhones by Account Id.
     *              Skips records with null ParentId or IsPrimary != true.
     * @param phoneRecords List of ContactPointPhone records to process
     * @param primaryMobileByAccount Output map of Account Id to primary Mobile ContactPointPhone
     * @param primaryNonMobileByAccount Output map of Account Id to primary non-Mobile ContactPointPhone
     */
    private static void buildPrimaryMapsFromPhones(List<ContactPointPhone> phoneRecords,
            Map<Id, ContactPointPhone> primaryMobileByAccount,
            Map<Id, ContactPointPhone> primaryNonMobileByAccount) {
        for (ContactPointPhone phone : phoneRecords) {
            if (phone.ParentId == null || phone.IsPrimary != true) {
                continue;
            }
            if (phone.UsageType == ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE) {
                primaryMobileByAccount.put(phone.ParentId, phone);
            } else {
                primaryNonMobileByAccount.put(phone.ParentId, phone);
            }
        }
    }

    /**
     * @description Collects all Account Ids that have at least one primary phone (Mobile or non-Mobile).
     * @param primaryMobileByAccount Map of Account Id to primary Mobile ContactPointPhone
     * @param primaryNonMobileByAccount Map of Account Id to primary non-Mobile ContactPointPhone
     * @return Set of Account Ids with at least one primary phone
     */
    private static Set<Id> getAccountsWithPrimary(Map<Id, ContactPointPhone> primaryMobileByAccount,
            Map<Id, ContactPointPhone> primaryNonMobileByAccount) {
        Set<Id> accountsWithPrimary = new Set<Id>();
        accountsWithPrimary.addAll(primaryMobileByAccount.keySet());
        accountsWithPrimary.addAll(primaryNonMobileByAccount.keySet());
        return accountsWithPrimary;
    }

    /**
     * @description Queries parent Account records for Id, Phone, and PersonIndividualId.
     * @param accountIds Set of Account Ids to query
     * @return Map of Account Id to Account record
     */
    private static Map<Id, Account> queryParentAccounts(Set<Id> accountIds) {
        Map<Id, Account> parentAccountsMap = new Map<Id, Account>();
        for (Account acc : [
            SELECT Id, Phone, PersonIndividualId
            FROM Account
            WHERE Id IN :accountIds
            WITH SYSTEM_MODE
        ]) {
            parentAccountsMap.put(acc.Id, acc);
        }
        return parentAccountsMap;
    }

    /**
     * @description Applies primary phone updates: builds Account updates, demotes existing primaries,
     *              updates Accounts, and updates Transactional SMS consent to Pending Opt In where applicable.
     * @param primaryMobileByAccount Map of Account Id to primary Mobile ContactPointPhone
     * @param primaryNonMobileByAccount Map of Account Id to primary non-Mobile ContactPointPhone
     * @param parentAccountsMap Map of Account records
     */
    private static void applyPrimaryPhoneUpdates(Map<Id, ContactPointPhone> primaryMobileByAccount,
            Map<Id, ContactPointPhone> primaryNonMobileByAccount,
            Map<Id, Account> parentAccountsMap) {
        List<Account> accountsToUpdate = buildAccountsToUpdate(
                primaryMobileByAccount, primaryNonMobileByAccount, parentAccountsMap);
        demoteExistingPrimaryPhones(primaryMobileByAccount, primaryNonMobileByAccount);

        if (!accountsToUpdate.isEmpty()) {
            Database.update(accountsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
        updateTransactionalSMSConsentToPendingOptIn(primaryMobileByAccount.keySet(), parentAccountsMap);
    }

    /**
     * @description Builds list of Account records to update with primary phone (prefers Mobile over non-Mobile).
     *              Only includes Accounts where Phone differs from the primary ContactPointPhone number.
     * @param primaryMobileByAccount Map of Account Id to primary Mobile ContactPointPhone
     * @param primaryNonMobileByAccount Map of Account Id to primary non-Mobile ContactPointPhone
     * @param parentAccountsMap Map of Account records
     * @return List of Account records with updated Phone values
     */
    private static List<Account> buildAccountsToUpdate(Map<Id, ContactPointPhone> primaryMobileByAccount,
            Map<Id, ContactPointPhone> primaryNonMobileByAccount,
            Map<Id, Account> parentAccountsMap) {
        List<Account> accountsToUpdate = new List<Account>();
        for (Id accountId : parentAccountsMap.keySet()) {
            Account parentAccount = parentAccountsMap.get(accountId);
            ContactPointPhone primaryPhone = primaryMobileByAccount.get(accountId);
            if (primaryPhone == null) {
                primaryPhone = primaryNonMobileByAccount.get(accountId);
            }
            if (primaryPhone != null && parentAccount.Phone != primaryPhone.TelephoneNumber) {
                parentAccount.Phone = primaryPhone.TelephoneNumber;
                accountsToUpdate.add(parentAccount);
            }
        }
        return accountsToUpdate;
    }

    /**
     * @description Demotes existing primary phones of the same UsageType. Mobile primaries demote other Mobiles;
     *              non-Mobile primaries demote other non-Mobiles. Excludes the new primary from demotion.
     * @param primaryMobileByAccount Map of Account Id to primary Mobile ContactPointPhone
     * @param primaryNonMobileByAccount Map of Account Id to primary non-Mobile ContactPointPhone
     */
    private static void demoteExistingPrimaryPhones(Map<Id, ContactPointPhone> primaryMobileByAccount,
            Map<Id, ContactPointPhone> primaryNonMobileByAccount) {
        Set<Id> excludeMobileIds = getPhoneIdsFromMap(primaryMobileByAccount);
        Set<Id> excludeNonMobileIds = getPhoneIdsFromMap(primaryNonMobileByAccount);
        if (!primaryMobileByAccount.isEmpty()) {
            updateExistingPrimaryPhonesToNonPrimary(primaryMobileByAccount.keySet(), excludeMobileIds, true);
        }
        if (!primaryNonMobileByAccount.isEmpty()) {
            updateExistingPrimaryPhonesToNonPrimary(primaryNonMobileByAccount.keySet(), excludeNonMobileIds, false);
        }
    }

    /**
     * @description Extracts ContactPointPhone Ids from a map of Account Id to ContactPointPhone.
     * @param primaryByAccount Map of Account Id to primary ContactPointPhone
     * @return Set of ContactPointPhone Ids
     */
    private static Set<Id> getPhoneIdsFromMap(Map<Id, ContactPointPhone> primaryByAccount) {
        Set<Id> phoneIds = new Set<Id>();
        for (ContactPointPhone p : primaryByAccount.values()) {
            phoneIds.add(p.Id);
        }
        return phoneIds;
    }

    /**
     * @description Updates existing primary phones to non-primary, scoped by UsageType.
     *              When isMobileType=true, demotes only Mobile primaries. When false, demotes only non-Mobile primaries.
     *              Enables two primaries per account: one Mobile and one non-Mobile.
     * @param parentAccountIds Set of parent account IDs
     * @param excludePhoneIds Set of phone IDs to keep as primary (exclude from demotion)
     * @param isMobileType When true, demotes Mobile UsageType only; when false, demotes non-Mobile only
     */
    private static void updateExistingPrimaryPhonesToNonPrimary(Set<Id> parentAccountIds, Set<Id> excludePhoneIds, Boolean isMobileType) {
        if (parentAccountIds == null || parentAccountIds.isEmpty()) {
            return;
        }

        List<ContactPointPhone> phonesToUpdate = new List<ContactPointPhone>();
        if (isMobileType) {
            for (ContactPointPhone phone : [
                SELECT Id, IsPrimary, ParentId
                FROM ContactPointPhone
                WHERE ParentId IN :parentAccountIds
                AND Id NOT IN :excludePhoneIds
                AND IsPrimary = true
                AND UsageType = :ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE
                WITH SYSTEM_MODE
            ]) {
                phonesToUpdate.add(new ContactPointPhone(Id = phone.Id, IsPrimary = false));
            }
        } else {
            for (ContactPointPhone phone : [
                SELECT Id, IsPrimary, ParentId
                FROM ContactPointPhone
                WHERE ParentId IN :parentAccountIds
                AND Id NOT IN :excludePhoneIds
                AND IsPrimary = true
                AND (UsageType != :ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE OR UsageType = NULL)
                WITH SYSTEM_MODE
            ]) {
                phonesToUpdate.add(new ContactPointPhone(Id = phone.Id, IsPrimary = false));
            }
        }

        if (!phonesToUpdate.isEmpty()) {
            Database.update(phonesToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description When a ContactPointPhone is marked Primary with UsageType = Mobile,
     *              updates ContactPointTypeConsent where PartyId = Account.PersonIndividualId
     *              and DataUsePurpose/Name = Transactional SMS to PrivacyConsentStatus = Pending Opt In.
     * @param primaryMobileAccountIds Set of Account IDs that have primary Mobile ContactPointPhones
     * @param parentAccountsMap Map of Account records (must include PersonIndividualId)
     */
    private static void updateTransactionalSMSConsentToPendingOptIn(Set<Id> primaryMobileAccountIds, Map<Id, Account> parentAccountsMap) {
        if (primaryMobileAccountIds == null || parentAccountsMap == null) {
            return;
        }

        Set<Id> individualIds = new Set<Id>();
        for (Id accountId : primaryMobileAccountIds) {
            Account acc = parentAccountsMap.get(accountId);
            if (acc != null && acc.PersonIndividualId != null) {
                individualIds.add(acc.PersonIndividualId);
            }
        }

        if (individualIds.isEmpty()) {
            return;
        }

        List<ContactPointTypeConsent> consentsToUpdate = new List<ContactPointTypeConsent>();
        for (ContactPointTypeConsent consent : [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId IN :individualIds
            AND (DataUsePurpose.Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS)
            WITH SYSTEM_MODE
        ]) {
            if (consent.PrivacyConsentStatus != ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING) {
                consentsToUpdate.add(new ContactPointTypeConsent(
                    Id = consent.Id,
                    PrivacyConsentStatus = ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING
                ));
            }
        }

        if (!consentsToUpdate.isEmpty()) {
            Database.update(consentsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }

}