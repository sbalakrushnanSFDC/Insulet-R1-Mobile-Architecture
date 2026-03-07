/**
 * @description Handles cascading deactivation of related Healthcare records when Accounts are made inactive.
 *              Invoked from the Account trigger handler after Account updates.
 *
 * Scenarios:
 *  - Practice Account deactivation => deactivate related HealthcarePractitionerFacility records (AccountId relationship).
 *  - Provider Account deactivation => deactivate related HealthcareProvider records (Practitioner relationship).
 *
 * Logging follows the Nebula Logger standard used across the project.
 * * =========================== Logs ======================================
 * v1.1.3       2nd Dec 2025        Niranjan Elangovan      Created(US - NGASIM-1389)
 * v1.1.4       23rd Jan 2026       Jatin Butta             Updated - fix test class SOQL 101 error
 * =======================================================================
 */
public inherited sharing class AccountDeactivationService {
    private static final String TAG_NAME = 'AccountDeactivationService';
    /**
     * @description Entry point called by the Account trigger handler.
     * @param updatedAccounts List of updated Account records from Trigger.new.
     * @param oldAccountMap   Map of old Account records from Trigger.oldMap.
     */
    public static void processAccountDeactivation(List<Account> updatedAccounts, Map<Id, Account> oldAccountMap) {
        if (updatedAccounts == null || updatedAccounts.isEmpty()) {
            return;
        }
        Map<Id, Account> previousAccounts = oldAccountMap != null ? oldAccountMap : new Map<Id, Account>();
        AccountDeactivationHelper.DeactivationTargets targets = AccountDeactivationHelper.collectTargets(updatedAccounts, previousAccounts);
        // IMPORTANT: Avoid consuming SOQL when there are no deactivation targets.
        // This service is invoked on every Account afterInsert/afterUpdate; during Lead conversion and other
        // cascades it can run many times in a single transaction. If there are no accounts transitioning
        // to inactive, we must exit early to prevent unnecessary SOQL usage.
        if ((targets.practiceAccountIds == null || targets.practiceAccountIds.isEmpty()) &&
            (targets.practitionerContactIds == null || targets.practitionerContactIds.isEmpty())) {
            return;
        }

        deactivatePracticeFacilities(targets.practiceAccountIds, targets.practitionerContactIds);
        deactivateHealthcareProviders(targets.practitionerContactIds, targets.practiceAccountIds);
    }
    /**
     * @description Deactivates HealthcarePractitionerFacility records linked to Practice Accounts.
     * @param practiceAccountIds Account Ids whose facilities must be set inactive
     * @param practitionerContactIds Contact Ids (PersonContactId) of deactivated provider accounts
     */
    @TestVisible
    static void deactivatePracticeFacilities(Set<Id> practiceAccountIds,Set<Id> practitionerContactIds) {
        List<HealthcarePractitionerFacility> facilitiesToUpdate = fetchActiveFacilities(practiceAccountIds,practitionerContactIds);
        if (facilitiesToUpdate.isEmpty()) {
            Logger.info('No active HealthcarePractitionerFacility records found for deactivated practice accounts')
                .addTag(TAG_NAME);
            return;
        }
        for (HealthcarePractitionerFacility facility : facilitiesToUpdate) {
            facility.IsActive = false;
        }
        if(AccountDeactivationHelper.canUpdateRecords(HealthcarePractitionerFacility.SObjectType, ConstantsUtil.HEALTHCARE_PRACTITIONER_FACILITY_OBJECT)) {
            saveRecords(facilitiesToUpdate, ConstantsUtil.HEALTHCARE_PRACTITIONER_FACILITY_OBJECT);
        }
    }
    /**
     * @description Deactivates HealthcareProvider records linked to Provider Accounts via PractitionerId.
     * @param practitionerContactIds Contact Ids (PersonContactId) of deactivated provider accounts
     * @param practiceAccountIds Account Ids whose providers must be set inactive
     */
    @TestVisible
    static void deactivateHealthcareProviders(Set<Id> practitionerContactIds,Set<Id> practiceAccountIds) {
        List<HealthcareProvider> providersToUpdate = fetchActiveHealthcareProviders(practitionerContactIds,practiceAccountIds);
        if (providersToUpdate.isEmpty()) {
            Logger.info('No active HealthcareProvider records found for deactivated provider accounts')
                .addTag(TAG_NAME);
            return;
        }
        for (HealthcareProvider provider : providersToUpdate) {
            provider.IsActive = false;
        }
        if(AccountDeactivationHelper.canUpdateRecords(HealthcareProvider.SObjectType, ConstantsUtil.HEALTHCARE_PROVIDER_OBJECT)) {
            saveRecords(providersToUpdate, ConstantsUtil.HEALTHCARE_PROVIDER_OBJECT);
        }
    }
    /**
     * @description Performs DML updates and logs successes/failures using Nebula Logger.
     * @param recordsToUpdate List of populated SObject records to update
     * @param objectLabel     Friendly object label for log context
     */
    @TestVisible
    static void saveRecords(List<SObject> recordsToUpdate, String objectLabel) {
        try {
            Database.SaveResult[] results = Database.update(recordsToUpdate, false);
            Integer successCount = 0;
            Integer errorCount = 0;
            for (Integer i = 0; i < results.size(); i++) {
                Database.SaveResult sr = results[i];
                if (sr.isSuccess()) {
                    successCount++;
                } else {
                    errorCount++;
                    for (Database.Error err : sr.getErrors()) {
                        Logger.error('Failed to update ' + objectLabel + ': ' + err.getMessage(), sr)
                            .setRecord(recordsToUpdate[i])
                            .addTag(TAG_NAME);
                    }
                }
            }
            Logger.info(objectLabel + ' deactivation summary - Success: ' + successCount + ', Errors: ' + errorCount)
                .addTag(TAG_NAME);
        } catch (Exception e) {
            Logger.error('DML exception while updating ' + objectLabel + ' records: ' + e.getMessage(), e)
                .addTag(TAG_NAME);
        }
    }
    @TestVisible
    static List<HealthcarePractitionerFacility> fetchActiveFacilities(Set<Id> practiceAccountIds,Set<Id> practitionerContactIds) {
        List<HealthcarePractitionerFacility> facilities = new List<HealthcarePractitionerFacility>();
        try {
            if ((practiceAccountIds == null || practiceAccountIds.isEmpty()) && (practitionerContactIds == null || practitionerContactIds.isEmpty())) {
                return facilities;
            }
            facilities = [
                SELECT Id, IsActive
                FROM HealthcarePractitionerFacility
                WHERE (AccountId IN :practiceAccountIds OR PractitionerId IN: practitionerContactIds) AND IsActive = true WITH SYSTEM_MODE
            ];
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new QueryException('customExceptionSwitch is turned on');
            }
        } catch (Exception e) {
            Logger.error('Exception while querying HealthcarePractitionerFacility records: ' + e.getMessage(), e)
                .addTag(TAG_NAME);
        }
        return facilities;
    }
    @TestVisible
    static List<HealthcareProvider> fetchActiveHealthcareProviders(Set<Id> practitionerContactIds,Set<Id>practiceAccountIds) {
        List<HealthcareProvider> providers = new List<HealthcareProvider>();
        try {
            if ((practitionerContactIds == null || practitionerContactIds.isEmpty()) &&
                (practiceAccountIds == null || practiceAccountIds.isEmpty())) {
                return providers;
            }
            providers = [
                SELECT Id, IsActive
                FROM HealthcareProvider
                WHERE (PractitionerId IN :practitionerContactIds OR AccountId IN: practiceAccountIds) AND IsActive = true WITH SYSTEM_MODE
            ];
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new QueryException('customExceptionSwitch is turned on');
            }
        } catch (Exception e) {
            Logger.error('Exception while querying HealthcareProvider records: ' + e.getMessage(), e)
                .addTag(TAG_NAME);
        }
        return providers;
    }
}