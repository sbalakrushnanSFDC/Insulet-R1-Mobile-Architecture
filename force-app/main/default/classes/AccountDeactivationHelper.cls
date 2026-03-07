/**
 * @description Re-usable helper functions for Account deactivation workflows.
 *              Extracted from AccountDeactivationService to keep the service lean
 *              and to promote reuse across future deactivation-related processors.
 * Logging follows the Nebula Logger standard used across the project.
 * * =========================== Logs ======================================
 * v1.1.0       2nd Dec 2025        Niranjan Elangovan      Created(US - NGASIM-1389)
 */
public without sharing class AccountDeactivationHelper {
    private static final String TAG_NAME = 'AccountDeactivationHelper';
    /**
     * @description Aggregates Account identifiers that require cascading deactivation.
     * @param updatedAccounts Accounts coming from Trigger.new / Trigger.newMap
     * @param previousAccounts Trigger.oldMap (may be null when invoked from insert context)
     * @return DeactivationTargets wrapper containing practice and provider identifiers
     */
    @TestVisible
    public static DeactivationTargets collectTargets(List<Account> updatedAccounts, Map<Id, Account> previousAccounts) {
        DeactivationTargets targets = new DeactivationTargets();
        if (updatedAccounts == null) {
            return targets;
        }
        for (Account updatedAccount : updatedAccounts) {
            Account oldAccount = previousAccounts != null ? previousAccounts.get(updatedAccount.Id) : null;
            if (shouldProcessAccount(updatedAccount, oldAccount)) {
                addAccountToTargets(updatedAccount, targets);
            }
        }
        return targets;
    }
    /**
     * @description Routes Accounts into the proper identifier sets for downstream processing.
     * @param updatedAccount Account under evaluation
     * @param targets        Wrapper object to populate
     */
    @TestVisible
    public static void addAccountToTargets(Account updatedAccount, DeactivationTargets targets) {
        if (isPracticeAccount(updatedAccount)) {
            targets.practiceAccountIds.add(updatedAccount.Id);
            return;
        }
        if (isProviderAccount(updatedAccount)) {
            targets.practitionerContactIds.add(updatedAccount.PersonContactId);
        }
    }
    /**
     * @description Determines whether an Account requires cascading deactivation.
     * @param updatedAccount Account from Trigger.new
     * @param oldAccount     Account from Trigger.oldMap (null during inserts)
     * @return true when IsActive transitions to false/null, or insert arrives inactive
     */
    @TestVisible
    public static Boolean shouldProcessAccount(Account updatedAccount, Account oldAccount) {
        boolean isValid = false;
        if(oldAccount != null){
            if(updatedAccount.IsActive != oldAccount.IsActive && (updatedAccount.IsActive == false || updatedAccount.IsActive == null)){
               isValid = true;
            }
        }
        else{
            if(updatedAccount.IsActive == false || updatedAccount.IsActive == null){
               isValid = true;
            }
        }
        return isValid;
    }
    /**
     * @description Checks if the current user has permission to update records of the specified type.
     * @param objectType  The SObjectType to check permissions for
     * @param objectLabel The label of the object (for logging purposes)
     * @return true if the user has update permission, false otherwise
     */
    @TestVisible
    public static Boolean canUpdateRecords(Schema.SObjectType objectType, String objectLabel) {
        if (objectType == null || !objectType.getDescribe().isUpdateable()) {
            Logger.error('Insufficient permissions to update ' + objectLabel + ' records')
                .addTag(TAG_NAME);
            return false;
        }
        return true;
    }
    /**
     * @description Determines if the given Account is a Practice Account.
     * @param accountRecord Account record to evaluate
     * @return true if the Account is a Practice Account
     */

    @TestVisible
    public static Boolean isPracticeAccount(Account accountRecord) {
        return accountRecord != null && accountRecord.RecordTypeId == ConstantsUtil.ACCOUNT_PRACTICE_RT;
    }
    /**
     * @description Determines if the given Account is a Provider Account.
     * @param accountRecord Account record to evaluate
     * @return true if the Account is a Provider Account
     */
    @TestVisible
    public static Boolean isProviderAccount(Account accountRecord) {
        return accountRecord != null && accountRecord.RecordTypeId == ConstantsUtil.ACCOUNT_PROVIDER_RT;
    }
    /**
     * @description Checks if there are any Ids to process.
     * @param recordIds Set of record Ids to evaluate
     * @return true if the set is not null and contains at least one Id
     */
    @TestVisible
    public static Boolean hasIdsToProcess(Set<Id> recordIds) {
        return recordIds != null && !recordIds.isEmpty();
    }
     /**
     * @description Wrapper that groups practice Account Ids and practitioner Contact Ids
     *              so downstream DML code can operate on well-defined sets.
     */
    public class DeactivationTargets {
        public Set<Id> practiceAccountIds = new Set<Id>();
        public Set<Id> practitionerContactIds = new Set<Id>();
    }
}