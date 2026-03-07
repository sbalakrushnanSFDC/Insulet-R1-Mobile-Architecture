/**
 * @description Handler for CCR Guardian and Authorized Caller scenarios.
 *              Filters eligible records and delegates to OrgSync_GuardianCCRService.
 *              Handles Guardian CCR sequence sync, Authorized Callers sync, and role swapping.
 * Created Date : Feb 2026
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Feb 2026            Ramesh Kumar            Initial Version
 * V1.0.1       Feb 2026            Ramesh Kumar            Added handleCCRInsertForGuardianAndAuthorizedCaller, handleCCRUpdateForGuardianAndAuthorizedCaller
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount,PMD.CognitiveComplexity')
public inherited sharing class OrgSync_GuardianCCRHandler {

    /**
     * @description Handles after insert of CCRs: Guardian sequence sync and Authorized Callers sync on Patient Stage.
     * @param newRecords Newly inserted CCRs
     */
    public static void handleCCRInsertForGuardianAndAuthorizedCaller(List<ContactContactRelation> newRecords) {
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            return;
        }
        List<ContactContactRelation> eligibleForAuthCallerSync = filterEligibleCCRsForAuthorizedCallerSync(newRecords);
        Set<Id> patientIds = collectPatientIdsFromCCRs(eligibleForAuthCallerSync);
        handleNewGuardianCCRInsert(newRecords);
        OrgSync_SoqlUtility.clearCCRsByPatientCache(patientIds);
        OrgSync_GuardianCCRService.syncAuthorizedCallersOnPatientStage(patientIds);
    }

    /**
     * @description Handles after update of CCRs: Role swap (Guardian ↔ Authorized Caller) and Authorized Callers sync on Patient Stage.
     *              Syncs OrgSync_Authorized_Callers__c for any CCR with Guardian or Authorized Caller role.
     * @param newRecords Updated CCRs
     * @param oldMap Old CCR records
     */
    public static void handleCCRUpdateForGuardianAndAuthorizedCaller(List<ContactContactRelation> newRecords, Map<Id, ContactContactRelation> oldMap) {
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            return;
        }
        Set<Id> ccrIds = new Set<Id>();
        for (ContactContactRelation c : newRecords) {
            if (c.Id != null) { ccrIds.add(c.Id); }
        }
        if (!ccrIds.isEmpty() && OrgSync_GuardianCCRService.isRecursiveCallFromOwnUpdate(ccrIds)) {
            return;
        }
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        Id authCallerRoleId = OrgSync_SoqlUtility.getAuthorizedCallerRoleId();
        if (guardianRoleId == null && authCallerRoleId == null) {
            return;
        }

        Set<Id> patientIds = new Set<Id>();
        List<ContactContactRelation> swappedToGuardian = new List<ContactContactRelation>();
        List<ContactContactRelation> swappedFromGuardian = new List<ContactContactRelation>();

        for (ContactContactRelation ccr : newRecords) {
            if (ccr.ContactId == null) {
                continue;
            }
            Boolean isRelevant = isRelevantRole(ccr.PartyRoleRelationId, guardianRoleId, authCallerRoleId);
            if (isRelevant) {
                patientIds.add(ccr.ContactId);
            }

            ContactContactRelation oldCcr = oldMap != null ? oldMap.get(ccr.Id) : null;
            Boolean roleChanged = oldCcr != null && ccr.PartyRoleRelationId != oldCcr.PartyRoleRelationId;

            if (roleChanged) {
                Boolean wasGuardian = guardianRoleId != null && oldCcr.PartyRoleRelationId == guardianRoleId;
                Boolean wasAuthCaller = authCallerRoleId != null && oldCcr.PartyRoleRelationId == authCallerRoleId;
                Boolean isGuardian = guardianRoleId != null && ccr.PartyRoleRelationId == guardianRoleId;
                Boolean isAuthCaller = authCallerRoleId != null && ccr.PartyRoleRelationId == authCallerRoleId;

                if (wasAuthCaller && isGuardian) {
                    swappedToGuardian.add(ccr);
                } else if (wasGuardian && isAuthCaller) {
                    swappedFromGuardian.add(new ContactContactRelation(
                        Id = ccr.Id,
                        ContactId = ccr.ContactId,
                        OrgSync_Guardian_Sequence__c = oldCcr.OrgSync_Guardian_Sequence__c
                    ));
                }
            }
        }
        if(swappedToGuardian != null && !swappedToGuardian.isEmpty()){
            OrgSync_GuardianCCRService.processRoleSwapToGuardian(swappedToGuardian);
        }
        if(swappedFromGuardian != null && !swappedFromGuardian.isEmpty()){
            OrgSync_GuardianCCRService.processRoleSwapFromGuardian(swappedFromGuardian);
        }
        if(patientIds != null){
            OrgSync_SoqlUtility.clearCCRsByPatientCache(patientIds);
            OrgSync_GuardianCCRService.syncAuthorizedCallersOnPatientStage(patientIds);
        }
    }

    /**
     * @description Filters new CCRs for Patient-Legal Guardian-CCR role and delegates to service.
     * @param newRecords List of newly inserted CCRs
     */
    public static void handleNewGuardianCCRInsert(List<ContactContactRelation> newRecords) {
        if (OrgSync_UtilityService.isOrgSyncUser()) {
            return;
        }
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        if (guardianRoleId == null) {
            return;
        }

        List<ContactContactRelation> eligibleCCRs = filterEligibleGuardianCCRs(newRecords, guardianRoleId);
        if (eligibleCCRs.isEmpty()) {
            return;
        }

        OrgSync_GuardianCCRService.processNewGuardianCCRsSetSequenceAndSyncToPatientStage(eligibleCCRs);
    }

    /**
     * @description Filters CCRs eligible for Authorized Caller sync: Guardian or Authorized Caller role, active, with ContactId.
     * @param records List of CCR records
     * @return List of eligible CCRs
     */
    private static List<ContactContactRelation> filterEligibleCCRsForAuthorizedCallerSync(List<ContactContactRelation> records) {
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        Id authCallerRoleId = OrgSync_SoqlUtility.getAuthorizedCallerRoleId();
        List<ContactContactRelation> eligible = new List<ContactContactRelation>();
        for (ContactContactRelation ccr : records) {
            if (ccr.ContactId != null && isRelevantRole(ccr.PartyRoleRelationId, guardianRoleId, authCallerRoleId)) {
                eligible.add(ccr);
            }
        }
        return eligible;
    }

    /**
     * @description Filters CCRs that are Patient-Legal Guardian-CCR role, active, with ContactId.
     * @param records List of CCR records
     * @param guardianRoleId PartyRoleRelation Id for Patient-Legal Guardian-CCR
     * @return List of eligible CCRs to process
     */
    private static List<ContactContactRelation> filterEligibleGuardianCCRs(List<ContactContactRelation> records, Id guardianRoleId) {
        List<ContactContactRelation> eligible = new List<ContactContactRelation>();
        for (ContactContactRelation ccr : records) {
            if (ccr.PartyRoleRelationId == guardianRoleId && ccr.ContactId != null) {
                eligible.add(ccr);
            }
        }
        return eligible;
    }

    private static Set<Id> collectPatientIdsFromCCRs(List<ContactContactRelation> records) {
        Set<Id> patientIds = new Set<Id>();
        for (ContactContactRelation ccr : records) {
            if (ccr.ContactId != null) {
                patientIds.add(ccr.ContactId);
            }
        }
        return patientIds;
    }

    private static Boolean isRelevantRole(Id partyRoleRelationId, Id guardianRoleId, Id authCallerRoleId) {
        return (guardianRoleId != null && partyRoleRelationId == guardianRoleId)
            || (authCallerRoleId != null && partyRoleRelationId == authCallerRoleId);
    }
}