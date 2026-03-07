/**
 * @description Handler class for ContactPointAddress triggers.
 *              Handles Insert, Update, and Delete events for ContactPointAddress.
 *              Converts flow logic from Contact_Point_Address_After_Insert_After_Update flow.
 * Created Date : Dec 2025
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Feb 2026       Charchit N.           Initial Version (NGASIM-2207)
 */
public with sharing class ContactPointAddressHandler {
    /**
     * @description Static variable to control behavior when newly created ContactPointAddress records
     *              have IsPrimary = true. When true, the new address remains primary (IsPrimary = true)
     *              and Account Billing Address fields are updated. Existing primary ContactPointAddress records will
     *              still be set to IsPrimary = false to maintain single primary address per account.
     *              When false (default), normal behavior: new primary address sets others to non-primary.
     */
    public static Boolean skipSetPrimaryOnNewContactPointAddress = false;

    /**
     * @description Handles primary ContactPointAddress logic before insert.
     *              Sets IsPrimary = true to the latest created ContactPointAddress for each account.
     *              If multiple records are being inserted for the same account and multiple have IsPrimary = true,
     *              only one will remain primary (the last one in the list).
     * @param addressRecords List of ContactPointAddress records being inserted
     */
    public static void handleBeforeInsert(List<ContactPointAddress> addressRecords) {
        if (addressRecords == null || addressRecords.isEmpty()) {
            return;
        }

        if (skipSetPrimaryOnNewContactPointAddress) {
            return; // Skip setting primary in before insert when flag is true
        }

        processPrimaryContactPointAddressBeforeInsert(addressRecords);
    }

    /**
     * @description Processes primary ContactPointAddress logic before insert.
     *              Groups addresses by account and sets primary based on multiple insert logic.
     *              Modifies the original addressRecords list directly.
     * @param addressRecords List of ContactPointAddress records being inserted (modified in place)
     */
    private static void processPrimaryContactPointAddressBeforeInsert(List<ContactPointAddress> addressRecords) {
        Map<Id, List<ContactPointAddress>> accountToAddressesMap = groupAddressesByAccount(addressRecords);

        for (Id accountId : accountToAddressesMap.keySet()) {
            List<ContactPointAddress> addressesForAccount = accountToAddressesMap.get(accountId);
            if (!addressesForAccount.isEmpty()) {
                processAddressesForAccount(addressesForAccount);
            }
        }
    }

    /**
     * @description Groups addresses by their ParentId (Account)
     * @param addressRecords List of ContactPointAddress records
     * @return Map of Account ID to List of ContactPointAddress records
     */
    private static Map<Id, List<ContactPointAddress>> groupAddressesByAccount(List<ContactPointAddress> addressRecords) {
        Map<Id, List<ContactPointAddress>> accountToAddressesMap = new Map<Id, List<ContactPointAddress>>();

        for (ContactPointAddress address : addressRecords) {
            if (address.ParentId != null) {
                if (!accountToAddressesMap.containsKey(address.ParentId)) {
                    accountToAddressesMap.put(address.ParentId, new List<ContactPointAddress>());
                }
                accountToAddressesMap.get(address.ParentId).add(address);
            }
        }

        return accountToAddressesMap;
    }

    /**
     * @description Processes addresses for a single account to set primary status
     * @param addressesForAccount List of ContactPointAddress records for the account
     */
    private static void processAddressesForAccount(List<ContactPointAddress> addressesForAccount) {
        if (addressesForAccount.size() == 1) {
            setSingleAddressAsPrimary(addressesForAccount[0]);
        } else {
            processMultipleAddresses(addressesForAccount);
        }
    }

    /**
     * @description Sets a single address as primary
     * @param address ContactPointAddress record to set as primary
     */
    private static void setSingleAddressAsPrimary(ContactPointAddress address) {
        address.IsPrimary = true;
    }

    /**
     * @description Processes multiple addresses to ensure only one is primary
     * @param addressesForAccount List of ContactPointAddress records for the account
     */
    private static void processMultipleAddresses(List<ContactPointAddress> addressesForAccount) {
        List<ContactPointAddress> primaryAddresses = getPrimaryAddresses(addressesForAccount);

        if (primaryAddresses.size() > 1) {
            keepOnlyLastPrimaryAddress(addressesForAccount, primaryAddresses);
        } else if (primaryAddresses.isEmpty()) {
            setLastAddressAsPrimary(addressesForAccount);
        }
        // If exactly one primary address, keep it as is (no change needed)
    }

    /**
     * @description Gets list of addresses that are currently marked as primary
     * @param addressesForAccount List of ContactPointAddress records
     * @return List of primary ContactPointAddress records
     */
    private static List<ContactPointAddress> getPrimaryAddresses(List<ContactPointAddress> addressesForAccount) {
        List<ContactPointAddress> primaryAddresses = new List<ContactPointAddress>();
        for (ContactPointAddress address : addressesForAccount) {
            if (address.IsPrimary == true) {
                primaryAddresses.add(address);
            }
        }
        return primaryAddresses;
    }

    /**
     * @description Keeps only the last primary address as primary, sets others to false
     * @param addressesForAccount List of ContactPointAddress records
     * @param primaryAddresses List of currently primary addresses
     */
    private static void keepOnlyLastPrimaryAddress(List<ContactPointAddress> addressesForAccount, List<ContactPointAddress> primaryAddresses) {
        ContactPointAddress lastPrimaryAddress = primaryAddresses[primaryAddresses.size() - 1];
        for (ContactPointAddress address : addressesForAccount) {
            address.IsPrimary = (address == lastPrimaryAddress);
        }
    }

    /**
     * @description Sets the last address in the list as primary
     * @param addressesForAccount List of ContactPointAddress records
     */
    private static void setLastAddressAsPrimary(List<ContactPointAddress> addressesForAccount) {
        addressesForAccount[addressesForAccount.size() - 1].IsPrimary = true;
    }

    /**
     * @description Handles primary ContactPointAddress logic after insert.
     *              Makes all other ContactPointAddress records non-primary except the recently inserted primary one.
     *              Updates Account Billing Address fields with the current primary address.
     * @param addressRecords List of ContactPointAddress records that were inserted
     * @param newRecordsMap Map of new records
     */
    public static void handleAfterInsert(List<ContactPointAddress> addressRecords, Map<Id, SObject> newRecordsMap) {
        if (addressRecords == null || addressRecords.isEmpty()) {
            return;
        }

        try {
            ContactPointAddressService.handlePrimaryContactPointAddress(addressRecords, newRecordsMap, null);
        } catch (Exception e) {
            Logger.error('ContactPointAddressHandler: Error processing contact point addresses after insert. Details: ' + e.getMessage())
                .addTag(ConstantsUtil.ASIM_TAG);
        }
    }

    /**
     * @description Handles primary ContactPointAddress logic after update.
     *              Makes all other ContactPointAddress records non-primary except the recently updated primary one.
     *              Updates Account Billing Address fields with the latest address.
     * @param addressRecords List of ContactPointAddress records that were updated
     * @param updatedRecordsMap Map of updated records
     * @param oldRecordsMap Map of old records
     */
    public static void handleAfterUpdate(List<ContactPointAddress> addressRecords, Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        if (addressRecords == null || addressRecords.isEmpty()) {
            return;
        }

        try {
            ContactPointAddressService.handlePrimaryContactPointAddress(addressRecords, updatedRecordsMap, oldRecordsMap);
        } catch (Exception e) {
            Logger.error('ContactPointAddressHandler: Error processing contact point addresses after update. Details: ' + e.getMessage())
                .addTag(ConstantsUtil.ASIM_TAG);
        }
    }

}