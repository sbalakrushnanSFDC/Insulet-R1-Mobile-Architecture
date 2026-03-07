/**
 * @description Service class responsible for creating/updating Patient Delegate Person Account records,
 *              Contact Point Email/Phone, and Contact Contact Relationships based on guardian information
 *              from Patient Stage. Bulk-safe, governor limit-aware.
 * Created Date : Dec 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 2025            Ramesh Dhaka            Initial Version
 * V1.1.0       Feb 2026            Ramesh Kumar            Refactored: SoqlUtility, Contact Points, GuardianCCRService
 */
@SuppressWarnings('PMD.StdCyclomaticComplexity,PMD.CyclomaticComplexity,PMD.NcssMethodCount')
public inherited sharing class OrgSync_PatientDelegateService {

    /**
     * @description DelegateContext class.
     */
    private class DelegateContext {
        public Map<String, Account> criteriaToDelegateMap;
        public Map<String, ContactContactRelation> existingCCRsByExtId;
        public Map<String, List<ContactContactRelation>> existingCCRsByPatientAndSequence;
        public Map<String, ContactContactRelation> existingRelationshipMap;
        public List<ContactContactRelation> ccrUpsertList;
        public List<ContactContactRelation> ccrNullifyList;
        public Set<Id> ccrNullifyIds;
        public List<Account> newDelegates;
        public List<ContactPointEmail> emailsToUpsert;
        public List<ContactPointPhone> phonesToUpsert;
        public Id guardianRoleId;

        /**
         * @description Constructor initializing the context object.
         */
        public DelegateContext() {
            criteriaToDelegateMap = new Map<String, Account>();
            existingCCRsByExtId = new Map<String, ContactContactRelation>();
            existingCCRsByPatientAndSequence = new Map<String, List<ContactContactRelation>>();
            existingRelationshipMap = new Map<String, ContactContactRelation>();
            ccrUpsertList = new List<ContactContactRelation>();
            ccrNullifyList = new List<ContactContactRelation>();
            ccrNullifyIds = new Set<Id>();
            newDelegates = new List<Account>();
            emailsToUpsert = new List<ContactPointEmail>();
            phonesToUpsert = new List<ContactPointPhone>();
        }
    }

    /**
     * @description CCRRequest class.
     */
    private class CCRRequest {
        public OrgSync_Patient_Staging__c stagingRecord;
        public Integer guardianIndex;
        public Id patientContactId;

        /**
         * @description Constructor initializing the request object.
         * @param stagingRecord Staging record
         * @param guardianIndex Guardian index (1 or 2)
         * @param patientContactId Patient contact ID
         */
        public CCRRequest(OrgSync_Patient_Staging__c stagingRecord, Integer guardianIndex, Id patientContactId) {
            this.stagingRecord = stagingRecord;
            this.guardianIndex = guardianIndex;
            this.patientContactId = patientContactId;
        }
    }

    /**
     * @description GuardianCriteriaSets class.
     */
    private class GuardianCriteriaSets {
        public Set<String> firstNames = new Set<String>();
        public Set<String> lastNames = new Set<String>();
        public Set<String> emails = new Set<String>();
        public Set<String> mobiles = new Set<String>();
        public Set<String> homePhones = new Set<String>();
        public Set<String> workPhones = new Set<String>();
    }

    /**
     * @description Process Patient Delegates, Contact Points, and CCRs.
     * @param records List of staging records
     * @param oldMap Map of old staging records (null for insert)
     */
    public void processDelegates(List<OrgSync_Patient_Staging__c> records, Map<Id, OrgSync_Patient_Staging__c> oldMap) {
        try {
            DelegateContext ctx = new DelegateContext();
            ctx.guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();

            if (ctx.guardianRoleId == null) {
                logError('processDelegates', 'Guardian Role ID not found', null);
                return;
            }

            Map<String, Id> patientExtIdToContactId = getPatientContactMap(records);
            loadExistingDelegates(records, ctx);
            upsertNewDelegates(records, ctx);
            loadExistingCCRs(records, patientExtIdToContactId, ctx);
            processDelegateContactPoints(records, oldMap, ctx);
            prepareCCRs(records, patientExtIdToContactId, ctx);

            executeChanges(ctx);
        } catch (Exception e) {
            logError('processDelegates', 'Error processing delegates', e);
        }
    }

    /**
     * @description Gets the patient contact map from the records.
     * @param records List of staging records
     * @return Map<String, Id> Map of patient external ID to contact ID
     */
    private Map<String, Id> getPatientContactMap(List<OrgSync_Patient_Staging__c> records) {
        Map<String, Id> patientExtIdToContactId = new Map<String, Id>();
        Set<String> externalIds = new Set<String>();
        Set<Id> accountIds = new Set<Id>();
        Set<String> remainingExternalIds = new Set<String>();

        for (OrgSync_Patient_Staging__c reg : records) {
            if (String.isNotBlank(reg.XCDC_ExternalId__c)) {
                externalIds.add(reg.XCDC_ExternalId__c);
            }
        }

        for (String extId : externalIds) {
            Id accId = (OrgSync_PatientService.processedAccountIds != null) ? OrgSync_PatientService.processedAccountIds.get(extId) : null;
            if (accId != null) {
                accountIds.add(accId);
            } else {
                remainingExternalIds.add(extId);
            }
        }

        if (!accountIds.isEmpty()) {
            for (Account acc : OrgSync_SoqlUtility.getAccountsByIdsWithExtId(accountIds)) {
                if (acc.XCDC_ExternalId__c != null && acc.PersonContactId != null) {
                    patientExtIdToContactId.put(acc.XCDC_ExternalId__c, acc.PersonContactId);
                }
            }
        }
        if (!remainingExternalIds.isEmpty()) {
            for (Account acc : OrgSync_SoqlUtility.getAccountsByExternalIdsWithContact(remainingExternalIds)) {
                patientExtIdToContactId.put(acc.XCDC_ExternalId__c, acc.PersonContactId);
            }
        }
        return patientExtIdToContactId;
    }

    /**
     * @description Loads existing delegates from the database.
     * @param records List of staging records
     * @param ctx Delegate context
     */
    private void loadExistingDelegates(List<OrgSync_Patient_Staging__c> records, DelegateContext ctx) {
        GuardianCriteriaSets criteria = new GuardianCriteriaSets();
        for (OrgSync_Patient_Staging__c reg : records) {
            collectGuardianCriteria(reg, 1, criteria);
            collectGuardianCriteria(reg, 2, criteria);
        }

        if (criteria.firstNames.isEmpty() || criteria.lastNames.isEmpty()) {
            return;
        }

        List<Account> accounts = OrgSync_SoqlUtility.getPatientDelegateAccounts(criteria.firstNames, criteria.lastNames);
        for (Account acc : accounts) {
            String fn = normalize(acc.FirstName);
            String ln = normalize(acc.LastName);
            addDelegateToMap(ctx, acc, fn, ln, acc.PersonEmail);
            addDelegateToMap(ctx, acc, fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(acc.PersonMobilePhone));
            addDelegateToMap(ctx, acc, fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(acc.PersonHomePhone));
            addDelegateToMap(ctx, acc, fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(acc.Phone));
            if (String.isBlank(acc.PersonEmail) && String.isBlank(acc.PersonMobilePhone) && String.isBlank(acc.PersonHomePhone) && String.isBlank(acc.Phone)) {
                addDelegateToMap(ctx, acc, fn, ln, '');
            }
        }
    }

    /**
     * @description Adds a delegate to the map. Always overwrites so that after insert we replace
     *              pre-insert Account (no PersonContactId) with queried Account (has PersonContactId).
     * @param ctx Delegate context
     * @param acc Account
     * @param fn First name
     * @param ln Last name
     * @param contactVal Contact value
     */
    private void addDelegateToMap(DelegateContext ctx, Account acc, String fn, String ln, String contactVal) { //NOPMD (Reason : Breaking it into multiple params or getting id one through wrapper is making code more complex and less readable)
        if (contactVal != null) {
            String key = buildKey(fn, ln, contactVal);
            ctx.criteriaToDelegateMap.put(key, acc);
        }
    }

    /**
     * @description Upserts new delegates.
     * @param records List of staging records
     * @param ctx Delegate context
     */
    private void upsertNewDelegates(List<OrgSync_Patient_Staging__c> records, DelegateContext ctx) {
        for (OrgSync_Patient_Staging__c reg : records) {
            processGuardianDelegate(reg, 1, ctx);
            processGuardianDelegate(reg, 2, ctx);
        }

        if (ctx.newDelegates.isEmpty()) {
            return;
        }

        List<Database.SaveResult> results = Database.insert(ctx.newDelegates, false, AccessLevel.SYSTEM_MODE);
        OrgSync_LoggingUtility.handleDatabaseResults(results, ctx.newDelegates, new Map<String, String>{
            'className' => 'OrgSync_PatientDelegateService',
            'methodName' => 'upsertNewDelegates',
            'operationDescription' => 'inserting delegate'
        });

        Set<Id> newIds = new Set<Id>();
        for (Account acc : ctx.newDelegates) {
            if (acc.Id != null) {
                newIds.add(acc.Id);
            }
        }
        if (!newIds.isEmpty()) {
            for (Account acc : OrgSync_SoqlUtility.getAccountsByIdsWithContact(newIds)) {
                String fn = normalize(acc.FirstName);
                String ln = normalize(acc.LastName);
                addDelegateToMap(ctx, acc, fn, ln, acc.PersonEmail);
                addDelegateToMap(ctx, acc, fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(acc.PersonMobilePhone));
                addDelegateToMap(ctx, acc, fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(acc.PersonHomePhone));
                addDelegateToMap(ctx, acc, fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(acc.Phone));
                if (String.isBlank(acc.PersonEmail) && String.isBlank(acc.PersonMobilePhone) && String.isBlank(acc.PersonHomePhone) && String.isBlank(acc.Phone)) {
                    addDelegateToMap(ctx, acc, fn, ln, '');
                }
            }
        }
    }

    /**
     * @description Loads existing CCRs from the database.
     * @param records List of staging records
     * @param patientExtIdToContactId Map of patient external ID to contact ID
     * @param ctx Delegate context
     */
    private void loadExistingCCRs(List<OrgSync_Patient_Staging__c> records, Map<String, Id> patientExtIdToContactId, DelegateContext ctx) {
        Set<String> ccrExternalIds = new Set<String>();
        Set<Id> patientContactIds = new Set<Id>();
        if (patientExtIdToContactId != null) {
            patientContactIds.addAll(patientExtIdToContactId.values());
        }
        for (OrgSync_Patient_Staging__c reg : records) {
            if (String.isNotBlank(reg.XCDC_ExternalId__c)) {
                ccrExternalIds.add(reg.XCDC_ExternalId__c + '_1');
                ccrExternalIds.add(reg.XCDC_ExternalId__c + '_2');
            }
        }

        List<ContactContactRelation> ccrs = OrgSync_SoqlUtility.getContactContactRelations(ccrExternalIds, patientContactIds);
        for (ContactContactRelation ccr : ccrs) {
            if (String.isNotBlank(ccr.XCDC_ExternalId__c)) {
                ctx.existingCCRsByExtId.put(ccr.XCDC_ExternalId__c, ccr);
            }
            if (ccr.OrgSync_Guardian_Sequence__c != null && ccr.ContactId != null) {
                String slotKey = String.valueOf(ccr.ContactId) + '_' + ccr.OrgSync_Guardian_Sequence__c;
                if (!ctx.existingCCRsByPatientAndSequence.containsKey(slotKey)) {
                    ctx.existingCCRsByPatientAndSequence.put(slotKey, new List<ContactContactRelation>());
                }
                ctx.existingCCRsByPatientAndSequence.get(slotKey).add(ccr);
            }
            if (ccr.ContactId != null && ccr.RelatedContactId != null) {
                ctx.existingRelationshipMap.put(String.valueOf(ccr.ContactId) + String.valueOf(ccr.RelatedContactId), ccr);
            }
        }
    }

    /**
     * @description Processes delegate contact points. On update, only processes contact points for the guardian(s) whose fields changed.
     * @param records List of staging records
     * @param oldMap Map of old staging records (null for insert)
     * @param ctx Delegate context
     */
    private void processDelegateContactPoints(List<OrgSync_Patient_Staging__c> records, Map<Id, OrgSync_Patient_Staging__c> oldMap, DelegateContext ctx) {
        Set<Id> delegateAccountIds = new Set<Id>();
        for (Account acc : ctx.criteriaToDelegateMap.values()) {
            if (acc.Id != null) {
                delegateAccountIds.add(acc.Id);
            }
        }
        if (delegateAccountIds.isEmpty()) {
            return;
        }

        Map<Id, ContactPointEmail> emailsByParent = new Map<Id, ContactPointEmail>();
        Map<Id, Map<String, ContactPointPhone>> phonesByParentAndType = new Map<Id, Map<String, ContactPointPhone>>();
        for (ContactPointEmail cpe : OrgSync_SoqlUtility.getContactPointEmailsByParentIds(delegateAccountIds)) {
            if (!emailsByParent.containsKey(cpe.ParentId)) { emailsByParent.put(cpe.ParentId, cpe); }
        }
        for (ContactPointPhone cpp : OrgSync_SoqlUtility.getContactPointPhonesByParentIds(delegateAccountIds)) {
            if (String.isBlank(cpp.UsageType)) { continue; }
            if (!phonesByParentAndType.containsKey(cpp.ParentId)) { phonesByParentAndType.put(cpp.ParentId, new Map<String, ContactPointPhone>()); }
            Map<String, ContactPointPhone> byType = phonesByParentAndType.get(cpp.ParentId);
            if (!byType.containsKey(cpp.UsageType)) { byType.put(cpp.UsageType, cpp); }
        }

        for (OrgSync_Patient_Staging__c reg : records) {
            for (Integer g : new List<Integer>{ 1, 2 }) {
                if (!OrgSync_UtilityService.hasGuardianNDemographicFieldsChanged(reg, oldMap != null ? oldMap.get(reg.Id) : null, g)) {
                    continue;
                }
                Account delegate = findMatchingDelegate(reg, g, ctx);
                if (delegate != null && delegate.Id != null) {
                    processDelegateEmail(reg, g, delegate.Id, emailsByParent, ctx);
                    processDelegatePhones(reg, g, delegate.Id, phonesByParentAndType, ctx);
                }
            }
        }
    }

    /**
     * @description Finds a matching delegate.
     * @param reg Staging record
     * @param g Guardian index (1 or 2)
     * @param ctx Delegate context
     * @return Account Matching delegate
     */
    private Account findMatchingDelegate(OrgSync_Patient_Staging__c reg, Integer g, DelegateContext ctx) {
        String fn = normalize((String)reg.get('OrgSync_Guardian_' + g + '_First_Name__c'));
        String ln = normalize((String)reg.get('OrgSync_Guardian_' + g + '_Last_Name__c'));
        if (String.isBlank(fn) || String.isBlank(ln)) {
            return null;
        }
        String email = (String)reg.get('OrgSync_Guardian_' + g + '_Email__c');
        String mobile = (String)reg.get('OrgSync_Guardian_' + g + '_Mobile_Phone__c');
        String home = (String)reg.get('OrgSync_Guardian_' + g + '_Home_Phone__c');
        String work = (String)reg.get('OrgSync_Guardian_' + g + '_Work_Phone__c');

        if (String.isNotBlank(email) && ctx.criteriaToDelegateMap.containsKey(buildKey(fn, ln, email))) {
            return ctx.criteriaToDelegateMap.get(buildKey(fn, ln, email));
        }
        if (String.isNotBlank(mobile) && ctx.criteriaToDelegateMap.containsKey(buildKey(fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(mobile)))) {
            return ctx.criteriaToDelegateMap.get(buildKey(fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(mobile)));
        }
        if (String.isNotBlank(home) && ctx.criteriaToDelegateMap.containsKey(buildKey(fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(home)))) {
            return ctx.criteriaToDelegateMap.get(buildKey(fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(home)));
        }
        if (String.isNotBlank(work) && ctx.criteriaToDelegateMap.containsKey(buildKey(fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(work)))) {
            return ctx.criteriaToDelegateMap.get(buildKey(fn, ln, OrgSync_UtilityService.sanitizePhoneNumber(work)));
        }
        if (ctx.criteriaToDelegateMap.containsKey(buildKey(fn, ln, ''))) {
            return ctx.criteriaToDelegateMap.get(buildKey(fn, ln, ''));
        }
        return null;
    }

    /**
     * @description Processes delegate email per Contact Point Management rules:
     *              - Blank: no action on existing Contact Point
     *              - Single existing: update that record with new value
     *              - Multiple existing: update latest by IsPrimary, PreferenceRank/CreatedDate
     *              - None: create new Contact Point Email
     * @param reg Staging record
     * @param g Guardian index (1 or 2)
     * @param accId Account ID
     * @param emailsByParent Map of parent ID to list of contact point emails
     * @param ctx Delegate context
     */
    private void processDelegateEmail(OrgSync_Patient_Staging__c reg, Integer g, Id accId, Map<Id, ContactPointEmail> emailsByParent, DelegateContext ctx) {//NOPMD Reason : Breaking it into multiple params or getting id one through wrapper is making code more complex and less readable
        String email = (String)reg.get('OrgSync_Guardian_' + g + '_Email__c');
        if (String.isBlank(email)) { return; }
        ContactPointEmail cpe = emailsByParent.get(accId);
        if (cpe == null) { cpe = new ContactPointEmail(ParentId = accId); }
        cpe.EmailAddress = email;
        cpe.IsPrimary = true;
        cpe.PreferenceRank = 1;
        ctx.emailsToUpsert.add(cpe);
    }

    /**
     * @description Processes delegate phones per Contact Point Management rules:
     *              - Blank: no action on existing Contact Point for that UsageType
     *              - Single existing: update that record with new value
     *              - Multiple existing: update latest by IsPrimary, PreferenceRank/CreatedDate
     *              - None: create new Contact Point Phone with appropriate UsageType
     * @param reg Staging record
     * @param g Guardian index (1 or 2)
     * @param accId Account ID
     * @param phonesByParent Map of parent ID to list of contact point phones
     * @param ctx Delegate context
     */
    private void processDelegatePhones(OrgSync_Patient_Staging__c reg, Integer g, Id accId, Map<Id, Map<String, ContactPointPhone>> phonesByParentAndType, DelegateContext ctx) {//NOPMD Reason : Breaking it into multiple params or getting id one through wrapper is making code more complex and less readable
        Map<String, String> typeToVal = new Map<String, String>{
            ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME => (String)reg.get('OrgSync_Guardian_' + g + '_Home_Phone__c'),
            ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE => (String)reg.get('OrgSync_Guardian_' + g + '_Mobile_Phone__c'),
            'Work' => (String)reg.get('OrgSync_Guardian_' + g + '_Work_Phone__c')
        };
        Map<String, ContactPointPhone> byType = phonesByParentAndType.get(accId);
        List<ContactPointPhone> toUpsert = new List<ContactPointPhone>();
        for (String usageType : new List<String>{ ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE, ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME, 'Work' }) {
            String val = typeToVal.get(usageType);
            if (String.isBlank(val)) { continue; }
            ContactPointPhone cpp = (byType != null) ? byType.get(usageType) : null;
            if (cpp == null) { cpp = new ContactPointPhone(ParentId = accId); }
            cpp.TelephoneNumber = OrgSync_UtilityService.sanitizePhoneNumber(val);
            cpp.UsageType = usageType;
            cpp.IsPrimary = false;
            toUpsert.add(cpp);
        }
        Boolean hasMobile = String.isNotBlank(typeToVal.get(ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE));
        Boolean hasHome = String.isNotBlank(typeToVal.get(ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME));
        Boolean hasWork = String.isNotBlank(typeToVal.get('Work'));
        for (ContactPointPhone cpp : toUpsert) {
            cpp.IsPrimary = (hasMobile && cpp.UsageType == ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE)
                || (!hasMobile && hasHome && cpp.UsageType == ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME)
                || (!hasMobile && !hasHome && hasWork && cpp.UsageType == 'Work');
        }
        ctx.phonesToUpsert.addAll(toUpsert);
    }

    /**
     * @description Prepares CCRs.
     * @param records List of staging records
     * @param patientExtIdToContactId Map of patient external ID to contact ID
     * @param ctx Delegate context
     */
    private void prepareCCRs(List<OrgSync_Patient_Staging__c> records, Map<String, Id> patientExtIdToContactId, DelegateContext ctx) {
        for (OrgSync_Patient_Staging__c reg : records) {
            Id patientContactId = patientExtIdToContactId.get(reg.XCDC_ExternalId__c);
            if (patientContactId != null) {
                processCCR(new CCRRequest(reg, 1, patientContactId), ctx);
                processCCR(new CCRRequest(reg, 2, patientContactId), ctx);
            }
        }
    }

    /**
     * @description Processes a CCR. When guardian slot changes to a different delegate:
     *              nullifies existing CCRs for that slot, creates new CCR (never overwrites RelatedContactId).
     * @param req CCR request
     * @param ctx Delegate context
     */
    private void processCCR(CCRRequest req, DelegateContext ctx) {
        String firstName = (String)req.stagingRecord.get('OrgSync_Guardian_' + req.guardianIndex + '_First_Name__c');
        String lastName = (String)req.stagingRecord.get('OrgSync_Guardian_' + req.guardianIndex + '_Last_Name__c');
        String slotKey = String.valueOf(req.patientContactId) + '_' + req.guardianIndex;
        List<ContactContactRelation> existingCCRsForSlot = ctx.existingCCRsByPatientAndSequence.get(slotKey);
        ContactContactRelation existingCCRByExtId = ctx.existingCCRsByExtId.get(req.stagingRecord.XCDC_ExternalId__c + '_' + req.guardianIndex);

        if (String.isBlank(firstName) && String.isBlank(lastName)) {
            nullifyCCRsForSlot(existingCCRsForSlot, null, ctx);
            if (existingCCRByExtId != null && !ctx.ccrNullifyIds.contains(existingCCRByExtId.Id)) {
                ctx.ccrNullifyIds.add(existingCCRByExtId.Id);
                ctx.ccrNullifyList.add(OrgSync_GuardianCCRService.buildCCRForNullifyGuardian(existingCCRByExtId));
            }
            return;
        }

        Account delegate = findMatchingDelegate(req.stagingRecord, req.guardianIndex, ctx);
        if (delegate == null || delegate.PersonContactId == null) {
            return;
        }

        nullifyCCRsForSlot(existingCCRsForSlot, delegate.PersonContactId, ctx);
        if (existingCCRByExtId != null && existingCCRByExtId.RelatedContactId != delegate.PersonContactId && !ctx.ccrNullifyIds.contains(existingCCRByExtId.Id)) {
            ctx.ccrNullifyIds.add(existingCCRByExtId.Id);
            ctx.ccrNullifyList.add(OrgSync_GuardianCCRService.buildCCRForNullifyGuardian(existingCCRByExtId));
        }

        String relKey = String.valueOf(req.patientContactId) + String.valueOf(delegate.PersonContactId);
        ContactContactRelation existingRel = ctx.existingRelationshipMap.get(relKey);
        ContactContactRelation ccrToUse = existingRel;
        if (existingCCRsForSlot != null) {
            for (ContactContactRelation c : existingCCRsForSlot) {
                if (c.RelatedContactId == delegate.PersonContactId) {
                    ccrToUse = c;
                    break;
                }
            }
        }
        if (ccrToUse == null && existingCCRByExtId != null && existingCCRByExtId.RelatedContactId == delegate.PersonContactId) {
            ccrToUse = existingCCRByExtId;
        }

        ContactContactRelation ccr = OrgSync_GuardianCCRService.buildCCRForUpsert(
            req.patientContactId,
            delegate.PersonContactId,
            req.guardianIndex,
            ctx.guardianRoleId,
            null,
            ccrToUse
        );
        ctx.ccrUpsertList.add(ccr);
    }

    /**
     * @description Nullifies CCRs for a slot that have a different delegate (never overwrite RelatedContactId).
     * @param ccrsForSlot CCRs for this patient+sequence
     * @param delegateContactId Current delegate contact ID (null = nullify all)
     * @param ctx Delegate context
     */
    private void nullifyCCRsForSlot(List<ContactContactRelation> ccrsForSlot, Id delegateContactId, DelegateContext ctx) {
        if (ccrsForSlot == null) {
            return;
        }
        for (ContactContactRelation c : ccrsForSlot) {
            if ((delegateContactId == null || c.RelatedContactId != delegateContactId) && !ctx.ccrNullifyIds.contains(c.Id)) {
                ctx.ccrNullifyIds.add(c.Id);
                ctx.ccrNullifyList.add(OrgSync_GuardianCCRService.buildCCRForNullifyGuardian(c));
            }
        }
    }

    /**
     * @description Processes a guardian delegate.
     * @param reg Staging record
     * @param num Guardian index (1 or 2)
     * @param ctx Delegate context
     */
    private void processGuardianDelegate(OrgSync_Patient_Staging__c reg, Integer num, DelegateContext ctx) {
        String firstName = (String)reg.get('OrgSync_Guardian_' + num + '_First_Name__c');
        String lastName = (String)reg.get('OrgSync_Guardian_' + num + '_Last_Name__c');
        String email = (String)reg.get('OrgSync_Guardian_' + num + '_Email__c');
        String homePhone = (String)reg.get('OrgSync_Guardian_' + num + '_Home_Phone__c');
        String workPhone = (String)reg.get('OrgSync_Guardian_' + num + '_Work_Phone__c');
        String mobilePhone = (String)reg.get('OrgSync_Guardian_' + num + '_Mobile_Phone__c');

        if (String.isBlank(firstName) || String.isBlank(lastName)) {
            return;
        }

        if (findMatchingDelegate(reg, num, ctx) != null) {
            return;
        }

        String key = buildKey(normalize(firstName), normalize(lastName), String.isNotBlank(email) ? email : (String.isNotBlank(mobilePhone) ? OrgSync_UtilityService.sanitizePhoneNumber(mobilePhone) : (String.isNotBlank(homePhone) ? OrgSync_UtilityService.sanitizePhoneNumber(homePhone) : OrgSync_UtilityService.sanitizePhoneNumber(workPhone))));
        if (ctx.criteriaToDelegateMap.containsKey(key)) {
            return;
        }

        Account acc = new Account(
            RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT,
            FirstName = firstName,
            LastName = lastName,
            PersonEmail = email,
            PersonHomePhone = homePhone,
            Phone = workPhone,
            PersonMobilePhone = mobilePhone
        );
        ctx.newDelegates.add(acc);
        ctx.criteriaToDelegateMap.put(key, acc);
    }

    /**
     * @description Collects guardian criteria.
     * @param reg Staging record
     * @param num Guardian index (1 or 2)
     * @param criteria Guardian criteria sets
     */
    private void collectGuardianCriteria(OrgSync_Patient_Staging__c reg, Integer num, GuardianCriteriaSets criteria) {
        String firstName = (String)reg.get('OrgSync_Guardian_' + num + '_First_Name__c');
        String lastName = (String)reg.get('OrgSync_Guardian_' + num + '_Last_Name__c');
        String email = (String)reg.get('OrgSync_Guardian_' + num + '_Email__c');
        String mobile = (String)reg.get('OrgSync_Guardian_' + num + '_Mobile_Phone__c');
        String home = (String)reg.get('OrgSync_Guardian_' + num + '_Home_Phone__c');
        String work = (String)reg.get('OrgSync_Guardian_' + num + '_Work_Phone__c');

        if (String.isNotBlank(firstName)) { criteria.firstNames.add(firstName); }
        if (String.isNotBlank(lastName)) { criteria.lastNames.add(lastName); }
        if (String.isNotBlank(email)) { criteria.emails.add(email); }
        if (String.isNotBlank(mobile)) { criteria.mobiles.add(OrgSync_UtilityService.sanitizePhoneNumber(mobile)); }
        if (String.isNotBlank(home)) { criteria.homePhones.add(OrgSync_UtilityService.sanitizePhoneNumber(home)); }
        if (String.isNotBlank(work)) { criteria.workPhones.add(OrgSync_UtilityService.sanitizePhoneNumber(work)); }
    }

    /**
     * @description Executes changes.
     * @param ctx Delegate context
     */
    private void executeChanges(DelegateContext ctx) {
        OrgSync_GuardianCCRService.executeCCRNullifyUpdates(ctx.ccrNullifyList);
        OrgSync_GuardianCCRService.executeCCRUpserts(ctx.ccrUpsertList);
        if (!ctx.emailsToUpsert.isEmpty()) {
            List<Database.UpsertResult> results = Database.upsert(ctx.emailsToUpsert, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(results, ctx.emailsToUpsert, new Map<String, String>{
                'className' => 'OrgSync_PatientDelegateService',
                'methodName' => 'executeChanges',
                'operationDescription' => 'upserting ContactPointEmail'
            });
        }
        if (!ctx.phonesToUpsert.isEmpty()) {
            ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone = true;
            try {
                List<Database.UpsertResult> results = Database.upsert(ctx.phonesToUpsert, false, AccessLevel.SYSTEM_MODE);
                OrgSync_LoggingUtility.handleDatabaseResults(results, ctx.phonesToUpsert, new Map<String, String>{
                    'className' => 'OrgSync_PatientDelegateService',
                    'methodName' => 'executeChanges',
                    'operationDescription' => 'upserting ContactPointPhone'
                });
            } finally {
                ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone = false;
            }
        }
    }

    /**
     * @description Builds a key.
     * @param fn First name
     * @param ln Last name
     * @param contactVal Contact value
     * @return String Key
     */
    private String buildKey(String fn, String ln, String contactVal) {
        return (fn + '|' + ln + '|' + (contactVal == null ? '' : contactVal)).toLowerCase();
    }

    /**
     * @description Normalizes a string.
     * @param s String
     * @return String Normalized string
     */
    private String normalize(String s) {
        return s == null ? '' : s.trim();
    }

    /**
     * @description Logs an error.
     * @param method Method name
     * @param message Message
     * @param e Exception
     */
    private void logError(String method, String message, Exception e) {
        String details = (e != null) ? '. Details: ' + e.getMessage() : '';
        Logger.error('OrgSync_PatientDelegateService: ' + method + ': ' + message + details).addTag('OrgSync');
    }
}