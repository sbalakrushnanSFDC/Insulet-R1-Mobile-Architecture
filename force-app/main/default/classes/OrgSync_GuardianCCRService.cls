/**
 * @description Service class for CCR (ContactContactRelation) creation and update
 *              corresponding to guardian field changes on Patient Stage.
 *              When guardian 1 or 2 section fields are nullified, updates CCR to clear OrgSync_Guardian_Sequence__c.
 *              Processes new Guardian CCR inserts: sets sequence and syncs to Patient Stage.
 * Created Date : Feb 2026
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Feb 2026            Ramesh Kumar            Initial Version
 * V1.0.1       Feb 2026            Ramesh Kumar            Added processNewGuardianCCRsSetSequenceAndSyncToPatientStage
 * V1.0.2       Feb 2026            Ramesh Kumar            Added syncAuthorizedCallersOnPatientStage
 * V1.0.3       Feb 2026            Ramesh Kumar            Added processRoleSwapToGuardian, processRoleSwapFromGuardian
 */
@SuppressWarnings('PMD.StdCyclomaticComplexity,PMD.CyclomaticComplexity,PMD.NcssMethodCount')
public inherited sharing class OrgSync_GuardianCCRService {

    /** ==================== Public Static Variables ==================== */
    /** CCR IDs updated by this service in current transaction. Used for recursion guard. */
    @TestVisible
    private static Set<Id> ccrIdsUpdatedInTx = new Set<Id>();
    /** Count of updates per CCR Id in current transaction (for debugging). */
    @TestVisible
    private static Map<Id, Integer> ccrUpdateCountById = new Map<Id, Integer>();

    /**
     * @description Returns true if all given CCRs were updated by this service in this transaction (recursive trigger).
     * @param ccrIds Set of CCR IDs in current trigger context
     * @return Boolean True if we should skip processing (recursive call from our own update)
     */
    public static Boolean isRecursiveCallFromOwnUpdate(Set<Id> ccrIds) {
        if (ccrIds == null || ccrIds.isEmpty()) {
            return false;
        }
        return ccrIdsUpdatedInTx.containsAll(ccrIds);
    }

    /**
     * @description Registers CCR IDs before update. Call before Database.update to enable recursion guard.
     * @param ccrs List of CCRs to register
     */
    private static void registerCCRsBeforeUpdate(List<ContactContactRelation> ccrs) {
        if (ccrs != null) {
            for (ContactContactRelation c : ccrs) {
                if (c.Id != null) {
                    ccrIdsUpdatedInTx.add(c.Id);
                    Integer cnt = ccrUpdateCountById.get(c.Id);
                    ccrUpdateCountById.put(c.Id, cnt == null ? 1 : cnt + 1);
                }
            }
        }
    }

    /**
     * @description Returns update count per CCR Id in current transaction. For debugging duplicate updates.
     * @return Map<Id, Integer> CCR Id to number of times it was updated
     */
    public static Map<Id, Integer> getCCRUpdateCountsInTx() {
        return new Map<Id, Integer>(ccrUpdateCountById);
    }

    /** ==================== Public Methods - Stage to CCR ==================== */
    /**
     * @description Creates or updates a CCR for Patient-Delegate relationship.
     * @param patientContactId Patient Contact Id
     * @param delegateContactId Delegate (Guardian) Person Contact Id
     * @param guardianSequence 1 or 2
     * @param guardianRoleId PartyRoleRelation Id for Guardian
     * @param existingCCR Existing CCR if any (for update)
     * @param existingRelByPatientDelegate Existing CCR by patient+delegate key
     * @return ContactContactRelation CCR to upsert
     */
    public static ContactContactRelation buildCCRForUpsert(//NOPMD Reason :Breaking it into multiple params or getting it done through wrapper is making code more complex and less readable
        Id patientContactId,
        Id delegateContactId,
        Integer guardianSequence,
        Id guardianRoleId,
        ContactContactRelation existingCCR,
        ContactContactRelation existingRelByPatientDelegate
    ) {
        ContactContactRelation ccr = existingRelByPatientDelegate != null
            ? new ContactContactRelation(Id = existingRelByPatientDelegate.Id)
            : (existingCCR != null ? new ContactContactRelation(Id = existingCCR.Id) : new ContactContactRelation());

        ccr.ContactId = patientContactId;
        ccr.RelatedContactId = delegateContactId;
        ccr.PartyRoleRelationId = guardianRoleId;
        ccr.OrgSync_Guardian_Sequence__c = guardianSequence;
        return ccr;
    }

    /**
     * @description Builds CCR for update when guardian 1 or 2 fields are nullified. Clears OrgSync_Guardian_Sequence__c only (CCR is retained).
     * @param existingCCR Existing CCR to update
     * @return ContactContactRelation CCR with OrgSync_Guardian_Sequence__c nullified
     */
    public static ContactContactRelation buildCCRForNullifyGuardian(ContactContactRelation existingCCR) {
        ContactContactRelation ccr = new ContactContactRelation(Id = existingCCR.Id);
        ccr.OrgSync_Guardian_Sequence__c = null;
        return ccr;
    }

    /**
     * @description Executes CCR updates to nullify OrgSync_Guardian_Sequence__c when guardian 1 or 2 fields are nullified.
     * @param ccrsToUpdate List of CCRs to update
     */
    public static void executeCCRNullifyUpdates(List<ContactContactRelation> ccrsToUpdate) {
        if (ccrsToUpdate == null || ccrsToUpdate.isEmpty()) {
            return;
        }
        registerCCRsBeforeUpdate(ccrsToUpdate);
        List<Database.SaveResult> results = Database.update(ccrsToUpdate, false, AccessLevel.SYSTEM_MODE);
        OrgSync_LoggingUtility.handleDatabaseResults(results, ccrsToUpdate, new Map<String, String>{
            'className' => 'OrgSync_GuardianCCRService',
            'methodName' => 'executeCCRNullifyUpdates',
            'operationDescription' => 'updating CCR to nullify guardian sequence'
        });
    }

    /**
     * @description Executes CCR upserts and logs results.
     * @param ccrsToUpsert List of CCRs to upsert
     */
    public static void executeCCRUpserts(List<ContactContactRelation> ccrsToUpsert) {
        if (ccrsToUpsert == null || ccrsToUpsert.isEmpty()) {
            return;
        }
        registerCCRsBeforeUpdate(ccrsToUpsert);
        List<Database.UpsertResult> results = Database.upsert(ccrsToUpsert, false, AccessLevel.SYSTEM_MODE);
        OrgSync_LoggingUtility.handleDatabaseResults(results, ccrsToUpsert, new Map<String, String>{
            'className' => 'OrgSync_GuardianCCRService',
            'methodName' => 'executeCCRUpserts',
            'operationDescription' => 'upserting CCR'
        });
    }

    /** ==================== Public Methods - CCR to Stage ==================== */
    /**
     * @description Processes eligible new Guardian CCRs: resolves OrgSync_Guardian_Sequence__c per business rules,
     *              updates CCRs, and syncs guardian details to corresponding Patient Stage sections.
     *              Case 1: Both 1 and 2 exist -> no action. Case 2: One exists -> set missing sequence, sync.
     *              Case 3: None exist -> set 1 if blank, sync.
     * @param eligibleCCRs List of CCRs already filtered for Patient-Legal Guardian-CCR role
     */
    public static void processNewGuardianCCRsSetSequenceAndSyncToPatientStage(List<ContactContactRelation> eligibleCCRs) {
        if (eligibleCCRs == null || eligibleCCRs.isEmpty()) {
            return;
        }
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        if (guardianRoleId == null) {
            return;
        }

        Set<Id> newCCRIds = new Set<Id>();
        Set<Id> patientIds = new Set<Id>();
        for (ContactContactRelation c : eligibleCCRs) {
            newCCRIds.add(c.Id);
            patientIds.add(c.ContactId);
        }

        List<ContactContactRelation> ccrsWithDetails = OrgSync_SoqlUtility.getContactContactRelationsByIdsWithDetails(newCCRIds);
        Map<Id, ContactContactRelation> newCCRById = new Map<Id, ContactContactRelation>();
        for (ContactContactRelation c : ccrsWithDetails) {
            newCCRById.put(c.Id, c);
        }
        Map<Id, String> contactIdToExtId = OrgSync_SoqlUtility.getContactIdToAccountExternalIdMap(patientIds);

        List<ContactContactRelation> guardianCCRs = OrgSync_SoqlUtility.getGuardianCCRsWithSequence(patientIds, guardianRoleId);
        Map<Id, Set<Integer>> patientToSequences = new Map<Id, Set<Integer>>();
        for (Id pid : patientIds) {
            patientToSequences.put(pid, new Set<Integer>());
        }
        for (ContactContactRelation ccr : guardianCCRs) {
            if (ccr.OrgSync_Guardian_Sequence__c != null) {
                patientToSequences.get(ccr.ContactId).add(ccr.OrgSync_Guardian_Sequence__c.intValue());
            }
        }

        List<ContactContactRelation> ccrsToUpdate = new List<ContactContactRelation>();
        Map<String, OrgSync_Patient_Staging__c> stagingByExtId = new Map<String, OrgSync_Patient_Staging__c>();
        Map<Id, Set<Integer>> assignedInTx = new Map<Id, Set<Integer>>();
        for (Id pid : patientIds) {
            assignedInTx.put(pid, new Set<Integer>());
        }

        for (ContactContactRelation newCCR : eligibleCCRs) {
            ContactContactRelation ccrWithDetails = newCCRById.get(newCCR.Id);
            if (ccrWithDetails == null) {
                continue;
            }
            Set<Integer> existingSeqs = patientToSequences.get(newCCR.ContactId);
            Set<Integer> assignedForPatient = assignedInTx.get(newCCR.ContactId);
            Integer seqToUse = resolveSequenceForNewCCR(newCCR, existingSeqs, assignedForPatient, ccrsToUpdate);
            if (seqToUse != null) {
                assignedForPatient.add(seqToUse);
            }

            if (seqToUse != null) {
                String patientExtId = ccrWithDetails != null ? extractPatientExternalIdFromCCR(ccrWithDetails) : null;
                if (String.isBlank(patientExtId)) {
                    patientExtId = contactIdToExtId.get(newCCR.ContactId);
                }
                if (String.isNotBlank(patientExtId)) {
                    OrgSync_Patient_Staging__c staging = stagingByExtId.get(patientExtId);
                    if (staging == null) {
                        staging = new OrgSync_Patient_Staging__c(XCDC_ExternalId__c = patientExtId);
                        stagingByExtId.put(patientExtId, staging);
                    }
                    Contact relatedCon = ccrWithDetails != null ? ccrWithDetails.RelatedContact : null;
                    OrgSync_UtilityService.updateGuardianFieldsOnStaging(staging, seqToUse, relatedCon);
                }
            }
        }

        executeCCRSequenceUpdates(ccrsToUpdate);
        executePatientStageGuardianUpserts(stagingByExtId.values());
    }

    /**
     * @description Syncs OrgSync_Authorized_Callers__c on Patient Stage for affected patients.
     *              Invoked when CCRs with Guardian or Authorized Caller role are created/updated.
     *              Retrieves all CCRs with those roles, concatenates delegate FirstName + LastName (comma-separated).
     * @param patientContactIds Set of patient Contact IDs from eligible CCRs
     */
    public static void syncAuthorizedCallersOnPatientStage(Set<Id> patientContactIds) {
        if (patientContactIds == null || patientContactIds.isEmpty()) {
            return;
        }
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        Id authCallerRoleId = OrgSync_SoqlUtility.getAuthorizedCallerRoleId();
        Set<Id> roleIds = new Set<Id>();
        if (guardianRoleId != null) { roleIds.add(guardianRoleId); }
        if (authCallerRoleId != null) { roleIds.add(authCallerRoleId); }
        if (roleIds.isEmpty()) {
            return;
        }

        List<ContactContactRelation> ccrs = OrgSync_SoqlUtility.getCCRsForAuthorizedCallersSync(patientContactIds, roleIds);
        Map<Id, List<ContactContactRelation>> patientToCCRs = new Map<Id, List<ContactContactRelation>>();
        for (Id pid : patientContactIds) {
            patientToCCRs.put(pid, new List<ContactContactRelation>());
        }
        for (ContactContactRelation ccr : ccrs) {
            patientToCCRs.get(ccr.ContactId).add(ccr);
        }

        Map<Id, String> contactIdToExtId = OrgSync_SoqlUtility.getContactIdToAccountExternalIdMap(patientContactIds);

        Map<String, OrgSync_Patient_Staging__c> stagingByExtId = new Map<String, OrgSync_Patient_Staging__c>();
        for (Id patientContactId : patientContactIds) {
            String patientExtId = contactIdToExtId.get(patientContactId);
            if (String.isBlank(patientExtId)) {
                continue;
            }
            Set<String> names = new Set<String>();
            List<ContactContactRelation> patientCCRs = patientToCCRs.get(patientContactId);
            if (patientCCRs != null) {
                for (ContactContactRelation p : patientCCRs) {
                    String fn = p.RelatedContact?.FirstName;
                    String ln = p.RelatedContact?.LastName;
                    String full = (String.isNotBlank(fn) ? fn + ' ' : '') + (String.isNotBlank(ln) ? ln : '');
                    if (String.isNotBlank(full.trim())) {
                        names.add(full.trim());
                    }
                }
            }
            stagingByExtId.put(patientExtId, new OrgSync_Patient_Staging__c(
                XCDC_ExternalId__c = patientExtId,
                OrgSync_Authorized_Callers__c = names.isEmpty() ? null : String.join(new List<String>(names), ',')
            ));
        }

        if (!stagingByExtId.isEmpty()) {
            Database.upsert(stagingByExtId.values(), OrgSync_Patient_Staging__c.Fields.XCDC_ExternalId__c, false, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Role changed TO Legal Guardian. Assigns missing sequence (1 or 2), syncs to Patient Stage.
     *              Receives eligible CCRs from handler (AuthCaller -> Guardian).
     * @param eligibleCCRs CCRs that changed from Authorized Caller to Guardian
     */
    public static void processRoleSwapToGuardian(List<ContactContactRelation> eligibleCCRs) {
        if (eligibleCCRs == null || eligibleCCRs.isEmpty()) {
            return;
        }
        processNewGuardianCCRsSetSequenceAndSyncToPatientStage(eligibleCCRs);
    }

    /**
     * @description Role changed FROM Legal Guardian. Nullifies sequence and corresponding guardian section on Patient Stage.
     *              Receives eligible CCRs from handler (Guardian -> AuthCaller, with Id, ContactId, OrgSync_Guardian_Sequence__c).
     * @param eligibleCCRs CCRs that changed from Guardian to Authorized Caller
     */
    public static void processRoleSwapFromGuardian(List<ContactContactRelation> eligibleCCRs) {
        List<ContactContactRelation> ccrsToNullify = new List<ContactContactRelation>();
        Set<Id> patientContactIds = new Set<Id>();
        Map<Id, Integer> patientContactIdToSequence = new Map<Id, Integer>();

        for (ContactContactRelation ccr : eligibleCCRs) {
            if (ccr.OrgSync_Guardian_Sequence__c != null) {
                ccrsToNullify.add(buildCCRForNullifyGuardian(ccr));
                patientContactIds.add(ccr.ContactId);
                patientContactIdToSequence.put(ccr.ContactId, ccr.OrgSync_Guardian_Sequence__c.intValue());
            }
        }

        if (!ccrsToNullify.isEmpty()) {
            registerCCRsBeforeUpdate(ccrsToNullify);
            Database.update(ccrsToNullify, false, AccessLevel.SYSTEM_MODE);
        }

        if (patientContactIds.isEmpty()) {
            return;
        }

        Map<Id, String> contactIdToExtId = OrgSync_SoqlUtility.getContactIdToAccountExternalIdMap(patientContactIds);

        List<OrgSync_Patient_Staging__c> stagingToUpdate = new List<OrgSync_Patient_Staging__c>();
        for (Id contactId : patientContactIds) {
            String extId = contactIdToExtId.get(contactId);
            Integer seq = patientContactIdToSequence.get(contactId);
            if (String.isNotBlank(extId) && seq != null && (seq == 1 || seq == 2)) {
                OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(XCDC_ExternalId__c = extId);
                OrgSync_UtilityService.updateGuardianFieldsOnStaging(staging, seq, null);
                stagingToUpdate.add(staging);
            }
        }

        if (!stagingToUpdate.isEmpty()) {
            Database.upsert(stagingToUpdate, OrgSync_Patient_Staging__c.Fields.XCDC_ExternalId__c, false, AccessLevel.SYSTEM_MODE);
        }
    }

    /** ==================== Private Methods ==================== */
    /**
     * @description Resolves the sequence for a new CCR.
     * @param newCCR New CCR
     * @param existingSeqs Existing sequences
     * @param assignedInTx Sequences assigned in the transaction
     * @param ccrsToUpdate List of CCRs to update
     * @return Integer Sequence to use
     */
    private static Integer resolveSequenceForNewCCR(ContactContactRelation newCCR, Set<Integer> existingSeqs, Set<Integer> assignedInTx, List<ContactContactRelation> ccrsToUpdate) {//NOPMD Reason : Breaking it into multiple lines is making code more complex and less readable
        Integer currentSeq = newCCR.OrgSync_Guardian_Sequence__c != null ? newCCR.OrgSync_Guardian_Sequence__c.intValue() : null;
        Set<Integer> allSeqs = new Set<Integer>(existingSeqs);
        allSeqs.addAll(assignedInTx);

        if (allSeqs.contains(1) && allSeqs.contains(2)) {
            return null;
        }
        if (allSeqs.contains(1) || allSeqs.contains(2)) {
            Integer missingSeq = allSeqs.contains(1) ? 2 : 1;
            ccrsToUpdate.add(new ContactContactRelation(Id = newCCR.Id, OrgSync_Guardian_Sequence__c = missingSeq));
            return missingSeq;
        }
        if (currentSeq != null && (currentSeq == 1 || currentSeq == 2)) {
            return currentSeq;
        }
        ccrsToUpdate.add(new ContactContactRelation(Id = newCCR.Id, OrgSync_Guardian_Sequence__c = 1));
        return 1;
    }
    /**
     * @description Extracts the patient external ID from the CCR.
     * @param ccr CCR
     * @return String Patient external ID
     */
    private static String extractPatientExternalIdFromCCR(ContactContactRelation ccr) {
        if (ccr.Contact?.Account != null && String.isNotBlank(ccr.Contact.Account.XCDC_ExternalId__c)) {
            return ccr.Contact.Account.XCDC_ExternalId__c;
        }
        return null;
    }

    /**
     * @description Executes the CCR sequence updates.
     * @param ccrsToUpdate List of CCRs to update
     */
    private static void executeCCRSequenceUpdates(List<ContactContactRelation> ccrsToUpdate) {
        if (ccrsToUpdate == null || ccrsToUpdate.isEmpty()) {
            return;
        }
        registerCCRsBeforeUpdate(ccrsToUpdate);
        List<Database.SaveResult> results = Database.update(ccrsToUpdate, false, AccessLevel.SYSTEM_MODE);
        OrgSync_LoggingUtility.handleDatabaseResults(results, ccrsToUpdate, new Map<String, String>{
            'className' => 'OrgSync_GuardianCCRService',
            'methodName' => 'executeCCRSequenceUpdates',
            'operationDescription' => 'updating CCR guardian sequence'
        });
    }

    /**
     * @description Executes the Patient Stage guardian upserts.
     * @param stagingToUpsert List of Patient Stage records to upsert
     */
    private static void executePatientStageGuardianUpserts(List<OrgSync_Patient_Staging__c> stagingToUpsert) {
        if (stagingToUpsert == null || stagingToUpsert.isEmpty()) {
            return;
        }
        List<Database.UpsertResult> results = Database.upsert(stagingToUpsert, OrgSync_Patient_Staging__c.Fields.XCDC_ExternalId__c, false, AccessLevel.SYSTEM_MODE);
        OrgSync_LoggingUtility.handleDatabaseResults(results, stagingToUpsert, new Map<String, String>{
            'className' => 'OrgSync_GuardianCCRService',
            'methodName' => 'executePatientStageGuardianUpserts',
            'operationDescription' => 'upserting Patient Stage guardian fields'
        });
    }
}