/**
 * @description Handler class responsible for filtering eligible Practice records
 *              and invoking OrgSync_PublishSettingService for Practice Account records.
 * Created Date : Dec 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 17, 2025        Ramesh Dhaka            Initial Version
 */
public with sharing class OrgSync_PracticeHandler {

    /**
     * @description Handles the before insert logic for Practice Account records.
     *              Filters eligible records and invokes OrgSync_PublishSettingService.
     * @param records List of Account records
     */
    public static void handleBeforeInsert(List<Account> records) {
        List<Account> eligibleRecords = filterPracticeRecords(records);
        if (eligibleRecords.size() > 0) {
            OrgSync_PublishSettingService.invokeOrgSync(eligibleRecords, null, XCDC_Constants.OPERATION_INSERT);
        }
    }

    /**
     * @description Handles the before update logic for Practice Account records.
     *              Filters eligible records and invokes OrgSync_PublishSettingService.
     * @param records List of Account records
     * @param oldMap Map of old Account records
     */
    public static void handleBeforeUpdate(List<Account> records, Map<Id, Account> oldMap) {
        List<Account> eligibleRecords = filterPracticeRecords(records);
        if (eligibleRecords.size() > 0) {
            OrgSync_PublishSettingService.invokeOrgSync(eligibleRecords, oldMap, XCDC_Constants.OPERATION_UPDATE);
        }
    }

    /********** Private Methods **********/

    /**
     * @description Filters the list of Accounts to return only Practice records.
     * @param records List of Account records
     * @return List<Account> List of Practice Account records
     */
    private static List<Account> filterPracticeRecords(List<Account> records) {
        List<Account> practiceRecords = new List<Account>();
        if (records == null) {
            return practiceRecords;
        }

        for (Account acc : records) {
            if (isEligible(acc)) {
                practiceRecords.add(acc);
            }
        }
        return practiceRecords;
    }

    /**
     * @description Checks if an Account record is eligible (has Practice record type).
     * @param account Account record to check
     * @return Boolean True if account has Practice record type, false otherwise
     */
    private static Boolean isEligible(Account account) {
        if (account == null) {
            return false;
        }
        return account.RecordTypeId == ConstantsUtil.ACCOUNT_PRACTICE_RT;
    }
}