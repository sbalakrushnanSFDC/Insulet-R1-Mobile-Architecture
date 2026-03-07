/**
 * @description Service class for handling ContactContactRelation logic.
 * Created Date : Dec 10, 2025
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 10, 2025       Ramesh Kumar            Initial Version
 */
@SuppressWarnings('PMD.StdCyclomaticComplexity,PMD.cyclomaticComplexity')
public inherited sharing class OrgSync_CCRService {

    private static Id cachedGuardianRoleId;
    private static Id cachedAuthCallerRoleId;
    private static Id orgSyncUserId;
    // Test-visible variables for mocking role IDs in tests
    @TestVisible
    private static Id testGuardianRoleId;
    @TestVisible
    private static Id testAuthCallerRoleId;

    /**
     * @description Handles changes to ContactContactRelation records (Update).
     * @param records List of CCRs.
     * @param oldMap Map of old CCRs.
     */
    public static void handleCCRChange(List<ContactContactRelation> records, Map<Id, ContactContactRelation> oldMap) {
        // If current user is Org Sync User, do not process
        if (isOrgSyncUser()) {
            return;
        }
        try {
            Id guardianRoleId = getGuardianRoleId();
            Id authCallerRoleId = getAuthCallerRoleId();

            if (guardianRoleId == null && authCallerRoleId == null){
                return;
            }

            Set<Id> patientIdsToSync = getPatientsWithChangedCCR(records, oldMap);

            if (!patientIdsToSync.isEmpty()) {
                syncGuardians(patientIdsToSync);
            }
        } catch (Exception e) {
            logError('handleCCRChange', e);
        }
    }

    /**
     * @description Handles new ContactContactRelation records (Insert).
     * @param records List of new CCRs.
     */
    public static void handleNewCCR(List<ContactContactRelation> records) {
        // If current user is Org Sync User, do not process
        if (isOrgSyncUser()) {
            return;
        }
        try {
            Id guardianRoleId = getGuardianRoleId();
            Id authCallerRoleId = getAuthCallerRoleId();

            if (guardianRoleId == null && authCallerRoleId == null){
                return;
            }

            Set<Id> patientIds = new Set<Id>();
            for (ContactContactRelation ccr : records) {
                if (isRelevantRole(ccr, guardianRoleId, authCallerRoleId) && ccr.ContactId != null && ccr.IsActive) {
                    patientIds.add(ccr.ContactId);
                }
            }

            if (!patientIds.isEmpty()) {
                syncGuardians(patientIds);
            }
        } catch (Exception e) {
            logError('handleNewCCR', e);
        }
    }

    private static Set<Id> getPatientsWithChangedCCR(List<ContactContactRelation> records, Map<Id, ContactContactRelation> oldMap) {
        Id guardianRoleId = getGuardianRoleId();
        Id authCallerRoleId = getAuthCallerRoleId();
        Set<Id> patientIdsToSync = new Set<Id>();
        for (ContactContactRelation ccr : records) {
            if (isRelevantRole(ccr, guardianRoleId, authCallerRoleId) && isStatusChanged(ccr, oldMap)) {
                patientIdsToSync.add(ccr.ContactId);
            }
        }
        return patientIdsToSync;
    }

    private static Boolean isRelevantRole(ContactContactRelation ccr, Id guardianRoleId, Id authCallerRoleId) {
        return (guardianRoleId != null && ccr.PartyRoleRelationId == guardianRoleId) ||
                (authCallerRoleId != null && ccr.PartyRoleRelationId == authCallerRoleId);
    }

    private static Boolean isStatusChanged(ContactContactRelation ccr, Map<Id, ContactContactRelation> oldMap) {
        ContactContactRelation oldCcr = oldMap != null ? oldMap.get(ccr.Id) : null;
        // Check if IsActive changed (Deactivation or Reactivation)
        return oldCcr != null && ccr.IsActive != oldCcr.IsActive && ccr.ContactId != null;
    }

    /**
     * @description Syncs active guardians and authorized callers for the given patients to the Staging object.
     *              Updates CCR External IDs and Staging fields.
     * @param patientIds Set of Patient Contact IDs.
     */
    private static void syncGuardians(Set<Id> patientIds) {
        Id guardianRoleId = getGuardianRoleId();
        Id authCallerRoleId = getAuthCallerRoleId();

        Set<Id> roleIds = new Set<Id>();
        if (guardianRoleId != null) {
            roleIds.add(guardianRoleId);
        }
        if (authCallerRoleId != null) {
            roleIds.add(authCallerRoleId);
        }

        List<ContactContactRelation> allCCRs = getContactContactRelations(patientIds, roleIds);

        Map<Id, List<ContactContactRelation>> patientCCRMap = new Map<Id, List<ContactContactRelation>>();
        for (Id pid : patientIds) {
            patientCCRMap.put(pid, new List<ContactContactRelation>());
        }
        for (ContactContactRelation ccr : allCCRs) {
            patientCCRMap.get(ccr.ContactId).add(ccr);
        }

        Map<Id, String> patientExternalIdMap = getPatientExternalIds(patientIds, patientCCRMap);

        GuardianSyncContext context = new GuardianSyncContext(guardianRoleId);

        for (Id patientId : patientIds) {
            processPatient(patientExternalIdMap.get(patientId), patientCCRMap.get(patientId), context);
        }

        executeUpdates(context.ccrsToUpdate, context.stagingToUpsert);
    }

    private static void processPatient(String patientExtId, List<ContactContactRelation> ccrs, GuardianSyncContext context) {
        if (String.isBlank(patientExtId)) {
            return;
        }

        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = patientExtId
        );

        List<ContactContactRelation> guardianCCRs = new List<ContactContactRelation>();
        Set<String> authCallerNames = new Set<String>();

        for (ContactContactRelation ccr : ccrs) {
            if (ccr.IsActive) {
                String fName = ccr.RelatedContact.FirstName;
                String lName = ccr.RelatedContact.LastName;
                String fullName = (String.isNotBlank(fName) ? fName + ' ' : '') + lName;
                authCallerNames.add(fullName);
            }

            if (context.guardianRoleId != null && ccr.PartyRoleRelationId == context.guardianRoleId) {
                if (ccr.IsActive) {
                    guardianCCRs.add(ccr);
                } else if (String.isNotBlank(ccr.XCDC_ExternalId__c)) {
                    context.ccrsToUpdate.add(new ContactContactRelation(
                        Id = ccr.Id,
                        XCDC_ExternalId__c = null
                    ));
                }
            }
        }

        if (!authCallerNames.isEmpty()) {
            staging.OrgSync_Authorized_Callers__c = String.join(new List<String>(authCallerNames), ',');
        } else {
            staging.OrgSync_Authorized_Callers__c = null;
        }

        context.processGuardianSlots(staging, guardianCCRs, patientExtId);
        context.stagingToUpsert.add(staging);
    }

    private static List<ContactContactRelation> getContactContactRelations(Set<Id> patientIds, Set<Id> roleIds) {
        return [
            SELECT Id, CreatedDate, ContactId, XCDC_ExternalId__c, PartyRoleRelationId, IsActive,
                Contact.Account.XCDC_ExternalId__c,
                RelatedContact.Name, RelatedContact.FirstName, RelatedContact.LastName,
                RelatedContact.Email, RelatedContact.HomePhone, RelatedContact.Phone, RelatedContact.MobilePhone
            FROM ContactContactRelation
            WHERE ContactId IN :patientIds
                AND PartyRoleRelationId IN :roleIds
            WITH SYSTEM_MODE
            ORDER BY CreatedDate
        ];
    }

    /**
     * @description Updates guardian fields on the staging record.
     * @param staging The staging record to update.
     * @param guardianNum The guardian number (1 or 2).
     * @param con The contact record (can be null).
     */
    private static void updateGuardianFields(OrgSync_Patient_Staging__c staging, Integer guardianNum, Contact con) {
        String prefix = 'OrgSync_Guardian_' + guardianNum + '_';
        staging.put(prefix + 'Name__c', con?.Name);
        staging.put(prefix + 'First_Name__c', con?.FirstName);
        staging.put(prefix + 'Last_Name__c', con?.LastName);
        staging.put(prefix + 'Email__c', con?.Email);
        staging.put(prefix + 'Home_Phone__c', con?.HomePhone);
        staging.put(prefix + 'Work_Phone__c', con?.Phone);
        staging.put(prefix + 'Mobile_Phone__c', con?.MobilePhone);
    }

    private static Map<Id, String> getPatientExternalIds(Set<Id> patientIds, Map<Id, List<ContactContactRelation>> patientCCRMap) {
        Map<Id, String> resultMap = new Map<Id, String>();
        Set<Id> idsToQuery = new Set<Id>();

        for (Id pid : patientIds) {
            List<ContactContactRelation> ccrs = patientCCRMap.get(pid);
            if (ccrs != null && !ccrs.isEmpty() && String.isNotBlank(ccrs[0].Contact.Account.XCDC_ExternalId__c)) {
                resultMap.put(pid, ccrs[0].Contact.Account.XCDC_ExternalId__c);
            } else {
                idsToQuery.add(pid);
            }
        }

        if (!idsToQuery.isEmpty()) {
            for (Contact con : [SELECT Id, Account.XCDC_ExternalId__c FROM Contact WHERE Id IN :idsToQuery WITH SYSTEM_MODE]) {
                resultMap.put(con.Id, con.Account.XCDC_ExternalId__c);
            }
        }
        return resultMap;
    }

    private static void executeUpdates(List<ContactContactRelation> ccrsToUpdate, List<OrgSync_Patient_Staging__c> stagingToUpsert) {
        if (!ccrsToUpdate.isEmpty()) {
            List<Database.SaveResult> updateResults = Database.update(ccrsToUpdate, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(updateResults, ccrsToUpdate, new Map<String, String>{
                'className' => 'OrgSync_CCRService',
                'methodName' => 'executeUpdates',
                'operationDescription' => 'updating ContactContactRelation'
            });
        }

        if (!stagingToUpsert.isEmpty()) {
            Schema.SObjectField externalIdField = OrgSync_Patient_Staging__c.Fields.XCDC_ExternalId__c;
            List<Database.UpsertResult> upsertResults = Database.upsert(stagingToUpsert, externalIdField, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(upsertResults, stagingToUpsert, new Map<String, String>{
                'className' => 'OrgSync_CCRService',
                'methodName' => 'executeUpdates',
                'operationDescription' => 'upserting Staging Record'
            });
        }
    }

    private static Id getGuardianRoleId() {
        // Use test variable if set (for unit tests)
        if (testGuardianRoleId != null) {
            return testGuardianRoleId;
        }
        if (cachedGuardianRoleId != null){
            return cachedGuardianRoleId;
        }
        List<PartyRoleRelation> roles = [SELECT Id FROM PartyRoleRelation WHERE RoleName = :ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME WITH SYSTEM_MODE LIMIT 1];
        cachedGuardianRoleId = !roles.isEmpty() ? roles[0].Id : null;
        return cachedGuardianRoleId;
    }

    private static Id getAuthCallerRoleId() {
        // Use test variable if set (for unit tests)
        if (testAuthCallerRoleId != null) {
            return testAuthCallerRoleId;
        }
        if (cachedAuthCallerRoleId != null){
            return cachedAuthCallerRoleId;
        }
        List<PartyRoleRelation> roles = [SELECT Id FROM PartyRoleRelation WHERE RoleName = :ConstantsUtil.AUTHORIZED_CALLER_RELATIONSHIP_NAME WITH SYSTEM_MODE LIMIT 1];
        cachedAuthCallerRoleId = !roles.isEmpty() ? roles[0].Id : null;
        return cachedAuthCallerRoleId;
    }

    private static void logError(String method, Exception e) {
        Logger.error('OrgSync_CCRService: ' + method + ': ' + e.getMessage()).addTag('OrgSync');
        Logger.saveLog();
    }

    /**
     * @description Checks if the current user is the OrgSync User.
     * @return Boolean True if current user is OrgSync User, else false.
     */
    private static boolean isOrgSyncUser() {
        if(orgSyncUserId == null){
            XCDC_Connection__mdt connection = [SELECT Id,Current_Org_API_User__c FROM XCDC_Connection__mdt WHERE Current_Org_API_User__c != null  WITH SYSTEM_MODE LIMIT 1 ];
            orgSyncUserId = connection?.Current_Org_API_User__c;
        }
        return orgSyncUserId == UserInfo.getUserId();
    }

    private class GuardianSyncContext {
        public Id guardianRoleId;
        public List<ContactContactRelation> ccrsToUpdate;
        public List<OrgSync_Patient_Staging__c> stagingToUpsert;

        /**
         * @description Constructor initializing the context object.
         * @param guardianRoleId Guardian Role ID.
         */
        public GuardianSyncContext(Id guardianRoleId) {
            this.guardianRoleId = guardianRoleId;
            this.ccrsToUpdate = new List<ContactContactRelation>();
            this.stagingToUpsert = new List<OrgSync_Patient_Staging__c>();
        }

        /**
         * @description Processes the guardian slots.
         * @param staging Staging record.
         * @param guardianCCRs List of guardian CCRs.
         * @param patientExtId Patient External ID.
         */
        public void processGuardianSlots(OrgSync_Patient_Staging__c staging, List<ContactContactRelation> guardianCCRs, String patientExtId) {
            for (Integer i = 0; i < 2; i++) {
                Integer suffix = i + 1;
                if (i < guardianCCRs.size()) {
                    ContactContactRelation ccr = guardianCCRs[i];
                    String expectedExtId = patientExtId + '_' + suffix;

                    if (ccr.XCDC_ExternalId__c != expectedExtId) {
                        this.ccrsToUpdate.add(new ContactContactRelation(
                            Id = ccr.Id,
                            XCDC_ExternalId__c = expectedExtId
                        ));
                    }
                    OrgSync_CCRService.updateGuardianFields(staging, suffix, ccr.RelatedContact);
                } else {
                    OrgSync_CCRService.updateGuardianFields(staging, suffix, null);
                }
            }
        }
    }
}