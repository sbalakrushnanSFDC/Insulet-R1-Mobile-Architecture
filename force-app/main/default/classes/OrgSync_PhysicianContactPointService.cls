/**
 * @description Service class for Contact Point Objects (Email, Phone, Address) for Physicians.
 * ContactPointPhone IsPrimary (exactly one per Account): OrgSync_Phone__c (Work) > OrgSync_PersonHomePhone__c (Home) > OrgSync_MobilePhone__c (Mobile).
 * ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone and ContactPointEmailHandler.skipSetPrimaryOnNewContactPointEmail
 * are set during upsert so the triggers do not overwrite IsPrimary.
 * Created Date : Jan 12, 2026
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 12, 2026        Neeraj Kumar            Initial Version
 * V1.0.1		March 5, 2026		Neeraj Kumar			Added usage type as 'Work' for emails
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount')
public inherited sharing class OrgSync_PhysicianContactPointService {
    /**
     * @description Primary ContactPointPhone per Account (populated after processContactPoints upsert).
     * Use getPrimaryContactPointPhone(accountId) to retrieve for use in other classes.
     */
    public static Map<Id, ContactPointPhone> primaryContactPointPhoneByAccountId = new Map<Id, ContactPointPhone>();

    /** Account IDs processed in the last processContactPoints run (for HPF email/address mapping). */
    private static Set<Id> processedAccountIdsInLastRun = new Set<Id>();

    /**
     * @description ProcessingContext class.
     */
    private class ProcessingContext {
        /**
         * @description Upsert List.
         */
        public List<SObject> upsertList {get; set;}
        /**
         * @description Delete List.
         */
        public List<SObject> deleteList {get; set;}
        /**
         * @description Existing Emails.
         */
        public Map<Id, List<ContactPointEmail>> existingEmails {get; set;}
        /**
         * @description Existing Phones.
         */
        public Map<Id, List<ContactPointPhone>> existingPhones {get; set;}
        /**
         * @description Existing Addresses.
         */
        public Map<Id, List<ContactPointAddress>> existingAddresses {get; set;}
        /**
         * @description Account Id to PersonContactId cache (from Account query; avoids redundant SOQL in HPF update).
         */
        public Map<Id, Id> accountIdToPersonContactIdCache {get; set;}

        /**
         * @description Constructor initializing the processing context object.
         */
        public ProcessingContext() {
            upsertList = new List<SObject>();
            deleteList = new List<SObject>();
            existingEmails = new Map<Id, List<ContactPointEmail>>();
            existingPhones = new Map<Id, List<ContactPointPhone>>();
            existingAddresses = new Map<Id, List<ContactPointAddress>>();
            accountIdToPersonContactIdCache = new Map<Id, Id>();
        }
    }

    /**
     * @description CPRequest class.
     */
    private class CPRequest {
        public String value;
        public String type; // For Phone/Address
        public Integer rank; // For Email / display order
        /** Fixed slot (1-4) for matching CPP to source field: Home=1, Mobile=2, Work=3, Fax=4 */
        public Integer fixedSlot;
        public String preferredKey; // For Phone (preferred match key)
        public Id accId;
        /**
         * @description Constructor initializing the request object.
         * @param v Value
         * @param r Rank
         * @param a Account ID
         */
        public CPRequest(String v, Integer r, Id a) {
            this.value = v;
            this.rank = r;
            this.accId = a;
        }
        /**
         * @description Constructor initializing the request object.
         * @param v Value
         * @param t Type
         * @param a Account ID
         */
        public CPRequest(String v, String t, Id a) {
            this.value = v;
            this.type = t;
            this.accId = a;
        }
        /**
         * @description Constructor for phone with fixed slot (ensures same CPP is updated for same source field).
         * Uses parameter object to avoid ExcessiveParameterList.
         * @param params Phone request parameters
         */
        public CPRequest(PhoneRequestParams params) {
            this.value = params.value;
            this.type = params.type;
            this.preferredKey = params.preferredKey;
            this.accId = params.accId;
            this.fixedSlot = params.slot;
        }
    }

    /**
     * @description Parameter object for phone CPRequest to avoid ExcessiveParameterList.
     */
    private class PhoneRequestParams {
        public String value;
        public String type;
        public String preferredKey;
        public Id accId;
        public Integer slot;
    }

    private static CPRequest createPhoneRequest(PhoneRequestBundle bundle, Id accId, Integer slot) {
        PhoneRequestParams p = new PhoneRequestParams();
        p.value = bundle.value;
        p.type = bundle.type;
        p.preferredKey = bundle.preferredKey;
        p.accId = accId;
        p.slot = slot;
        return new CPRequest(p);
    }

    private static PhoneRequestBundle phoneBundle(String value, String type, String preferredKey) {
        PhoneRequestBundle b = new PhoneRequestBundle();
        b.value = value;
        b.type = type;
        b.preferredKey = preferredKey;
        return b;
    }

    private class PhoneRequestBundle {
        public String value;
        public String type;
        public String preferredKey;
    }

    /**
     * @description Holds phone matching results to reduce nesting in addPhone.
     */
    private class PhoneMatches {
        ContactPointPhone matchBySlot;
        ContactPointPhone matchByRank;
        ContactPointPhone matchByUsageType;
        ContactPointPhone matchByPhoneNumber;
        ContactPointPhone matchByUsageTypeAndPrimary;
    }

    /**
     * @description Process Contact Points from Physician Staging records.
     * @param records List of physician staging records
     * @param oldMap Map of old physician staging records (trigger.oldMap)
     */
    public void processContactPoints(List<OrgSync_Physician_Staging__c> records, Map<Id, OrgSync_Physician_Staging__c> oldMap) {//NOPMD
        try {
            Map<String, Id> extIdToAccountId = new Map<String, Id>();
            Set<String> remainingExternalIds = new Set<String>();
            Set<String> seenExtIds = new Set<String>();

            for (OrgSync_Physician_Staging__c reg : records) {
                String extId = reg.XCDC_ExternalId__c;
                if (String.isBlank(extId) || seenExtIds.contains(extId)) {
                    continue;
                }
                seenExtIds.add(extId);
                if (OrgSync_ProviderService.processedAccountIds.containsKey(extId)) {
                    extIdToAccountId.put(extId, OrgSync_ProviderService.processedAccountIds.get(extId));
                } else {
                    remainingExternalIds.add(extId);
                }
            }

            ProcessingContext ctx = new ProcessingContext();
            if (!remainingExternalIds.isEmpty()) {
                for (Account acc : [SELECT Id, XCDC_ExternalId__c, PersonContactId FROM Account WHERE XCDC_ExternalId__c IN :remainingExternalIds WITH SYSTEM_MODE]) {
                    extIdToAccountId.put(acc.XCDC_ExternalId__c, acc.Id);
                    if (acc.PersonContactId != null) {
                        ctx.accountIdToPersonContactIdCache.put(acc.Id, acc.PersonContactId);
                    }
                }
            }

            if (oldMap != null && !extIdToAccountId.isEmpty()) {
                loadExistingData(ctx, extIdToAccountId.values());
            }

            processedAccountIdsInLastRun.clear();
            for (OrgSync_Physician_Staging__c reg : records) {
                Id accId = extIdToAccountId.get(reg.XCDC_ExternalId__c);
                if (accId == null){
                    continue;
                }
                processedAccountIdsInLastRun.add(accId);
                processEmails(reg, accId, ctx);
                processPhones(reg, accId, ctx);
                processAddresses(reg, accId, ctx);
            }

            if (!ctx.deleteList.isEmpty()) {
                List<Database.DeleteResult> deleteResults = Database.delete(ctx.deleteList, false, AccessLevel.SYSTEM_MODE);
                OrgSync_LoggingUtility.handleDatabaseResults(deleteResults, ctx.deleteList, new Map<String, String>{
                    'className' => 'OrgSync_PhysicianContactPointService',
                    'methodName' => 'processContactPoints',
                    'operationDescription' => 'deleting Contact Point'
                });
            }
            if (!ctx.upsertList.isEmpty()) {
                // Prevent ContactPointPhoneHandler and ContactPointEmailHandler from overwriting IsPrimary (rules applied above)
                Boolean previousSkipPhone = ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone;
                Boolean previousSkipEmail = ContactPointEmailHandler.skipSetPrimaryOnNewContactPointEmail;
                try {
                    ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone = true;
                    ContactPointEmailHandler.skipSetPrimaryOnNewContactPointEmail = true;
                    List<Database.UpsertResult> upsertResults = Database.upsert(ctx.upsertList, false, AccessLevel.SYSTEM_MODE);
                    OrgSync_LoggingUtility.handleDatabaseResults(upsertResults, ctx.upsertList, new Map<String, String>{
                        'className' => 'OrgSync_PhysicianContactPointService',
                        'methodName' => 'processContactPoints',
                        'operationDescription' => 'upserting Contact Point'
                    });
                    populatePrimaryContactPointPhones(ctx.upsertList);
                    updateHealthcarePractitionerFacilities(ctx);
                } finally {
                    ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone = previousSkipPhone;
                    ContactPointEmailHandler.skipSetPrimaryOnNewContactPointEmail = previousSkipEmail;
                }
            }
        } catch (Exception e) {
            Logger.error('OrgSync_PhysicianContactPointService: processContactPoints: Error processing contact points. Details: ' + e.getMessage()).addTag('OrgSync');
        }
    }

    /**
     * @description Load Existing Data.
     * @param ctx ProcessingContext object
     * @param accountIds List of account IDs
     */
    private void loadExistingData(ProcessingContext ctx, List<Id> accountIds) {
        for (ContactPointEmail cpe : [SELECT Id, ParentId, PreferenceRank, EmailAddress, IsPrimary FROM ContactPointEmail WHERE ParentId IN :accountIds WITH SYSTEM_MODE]) {
            if (!ctx.existingEmails.containsKey(cpe.ParentId)){
                ctx.existingEmails.put(cpe.ParentId, new List<ContactPointEmail>());
            }
            ctx.existingEmails.get(cpe.ParentId).add(cpe);
        }
        for (ContactPointPhone cpp : [SELECT Id, ParentId, TelephoneNumber, PreferenceRank, UsageType, IsSmsCapable, IsPrimary FROM ContactPointPhone WHERE ParentId IN :accountIds WITH SYSTEM_MODE]) {
            if (!ctx.existingPhones.containsKey(cpp.ParentId)){
                ctx.existingPhones.put(cpp.ParentId, new List<ContactPointPhone>());
            }
            ctx.existingPhones.get(cpp.ParentId).add(cpp);
        }
        for (ContactPointAddress cpa : [SELECT Id, ParentId, AddressType, Street, IsPrimary FROM ContactPointAddress WHERE ParentId IN :accountIds WITH SYSTEM_MODE]) {
            if (!ctx.existingAddresses.containsKey(cpa.ParentId)){
                ctx.existingAddresses.put(cpa.ParentId, new List<ContactPointAddress>());
            }
            ctx.existingAddresses.get(cpa.ParentId).add(cpa);
        }
    }

    /**
     * @description Process Emails. Primary email is OrgSync_PersonEmail__c (PreferenceRank 1, IsPrimary); mapped to HPF.
     * @param reg OrgSync_Physician_Staging__c record
     * @param accId Account ID
     * @param ctx ProcessingContext object
     */
    private void processEmails(OrgSync_Physician_Staging__c reg, Id accId, ProcessingContext ctx) {
        addEmail(new CPRequest(reg.OrgSync_PersonEmail__c, 1, accId), ctx);
        addEmail(new CPRequest(reg.OrgSync_Email_2__c, 2, accId), ctx);
        addEmail(new CPRequest(reg.OrgSync_Work_Email__c, 3, accId), ctx);
        addEmail(new CPRequest(reg.OrgSync_Backup_Email__c, 4, accId), ctx);
        addEmail(new CPRequest(reg.OrgSync_Secondary_Backup_Email__c, 5, accId), ctx);
    }

    /**
     * @description Add Email.
     * @param req CPRequest object
     * @param ctx ProcessingContext object
     */
    private void addEmail(CPRequest req, ProcessingContext ctx) {
        List<ContactPointEmail> existing = ctx.existingEmails.get(req.accId);
        ContactPointEmail match = null;
        if (existing != null) {
            for (ContactPointEmail cpe : existing) {
                if (cpe.PreferenceRank == req.rank) {
                    match = cpe;
                    break;
                }
            }
        }

        if (String.isNotBlank(req.value)) {
            Boolean isNewEmail = (match == null);
            ContactPointEmail cpe = isNewEmail ? new ContactPointEmail(ParentId = req.accId, PreferenceRank = req.rank) : match;
            cpe.ParentId = req.accId;
            cpe.EmailAddress = req.value;
            cpe.IsPrimary = (req.rank == 1);
            // OrgSync_PersonEmail__c (rank 1) and OrgSync_Email_2__c (rank 2)
            // should default to Work only on create.
            if (isNewEmail && (req.rank == 1 || req.rank == 2)) {
                cpe.UsageType = 'Work';
            }
            addToUpsertList(ctx, cpe);
        } else if (match != null) {
            ctx.deleteList.add(match);
        }
    }

    // Fixed slots for 4 CPPs: Home, Mobile, Work (OrgSync_Phone__c), Fax.
    private static final Integer SLOT_HOME = 1;
    private static final Integer SLOT_MOBILE = 2;
    private static final Integer SLOT_WORK = 3;
    private static final Integer SLOT_FAX = 4;

    /**
     * @description Process Phones. Exactly 4 CPP records: Home, Mobile, Work, Fax.
     * Primary and UsageType: OrgSync_Phone__c (Work) > OrgSync_PersonHomePhone__c (Home) > OrgSync_MobilePhone__c (Mobile).
     * - If OrgSync_Phone__c is present: that CPP gets UsageType 'Work' and IsPrimary true.
     * - Else if OrgSync_PersonHomePhone__c is present: that CPP gets UsageType 'Home' and IsPrimary true.
     * - Else if OrgSync_MobilePhone__c is present: that CPP gets UsageType 'Mobile' and IsPrimary true.
     * Fax is never primary.
     * @param reg OrgSync_Physician_Staging__c record
     * @param accId Account ID
     * @param ctx ProcessingContext object
     */
    private void processPhones(OrgSync_Physician_Staging__c reg, Id accId, ProcessingContext ctx) {
        String preferredKey = normalizePreferredPhoneKey(reg.OrgSync_Preferred_Phone_Number__c);
        String primaryPreferredKey = computePrimaryPreferredKey(reg);

        List<CPRequest> baseRequests = new List<CPRequest>{
            createPhoneRequest(phoneBundle(reg.OrgSync_PersonHomePhone__c, 'Home', 'Home'), accId, SLOT_HOME),
            createPhoneRequest(phoneBundle(reg.OrgSync_MobilePhone__c, 'Mobile', 'Mobile'), accId, SLOT_MOBILE),
            createPhoneRequest(phoneBundle(reg.OrgSync_Phone__c, 'Work', 'Business'), accId, SLOT_WORK),
            createPhoneRequest(phoneBundle(reg.OrgSync_Fax__c, 'Fax', 'Fax'), accId, SLOT_FAX)
        };

        List<CPRequest> orderedRequests = new List<CPRequest>();
        if (String.isNotBlank(preferredKey)) {
            for (CPRequest req : baseRequests) {
                if (req.preferredKey == preferredKey) {
                    orderedRequests.add(req);
                    break;
                }
            }
            for (CPRequest req : baseRequests) {
                if (req.preferredKey != preferredKey) {
                    orderedRequests.add(req);
                }
            }
        } else {
            orderedRequests.addAll(baseRequests);
        }

        AddPhoneParams addPhoneParams = new AddPhoneParams();
        addPhoneParams.preferredKey = primaryPreferredKey;
        addPhoneParams.smsCapablePhoneNumber = '';
        addPhoneParams.ctx = ctx;

        Integer rank = 1;
        for (CPRequest req : orderedRequests) {
            req.rank = rank;
            rank++;
            addPhone(req, addPhoneParams);
        }
    }

    /**
     * @description Determines which staging phone field's CPP gets IsPrimary (and HPF mapping).
     * Order: OrgSync_Phone__c (Work) > OrgSync_PersonHomePhone__c (Home) > OrgSync_MobilePhone__c (Mobile).
     * @param reg OrgSync_Physician_Staging__c record
     * @return 'Business' for Phone (Work), 'Home', or 'Mobile'; null if none of the three are present
     */
    private String computePrimaryPreferredKey(OrgSync_Physician_Staging__c reg) {
        if (String.isNotBlank(reg.OrgSync_Phone__c)) {
            return 'Business';  // OrgSync_Phone__c -> UsageType 'Work', IsPrimary true
        }
        if (String.isNotBlank(reg.OrgSync_PersonHomePhone__c)) {
            return 'Home';      // UsageType 'Home', IsPrimary true
        }
        if (String.isNotBlank(reg.OrgSync_MobilePhone__c)) {
            return 'Mobile';    // UsageType 'Mobile', IsPrimary true
        }
        return null;
    }

    /**
     * @description Add Phone. Matches existing CPP by fixedSlot (PreferenceRank) so the same source field
     * (e.g. OrgSync_Phone__c) always updates the same CPP; primary then stays on the correct record.
     * @param req CPRequest object (preferredKey is primaryPreferredKey when passed from processPhones)
     * @param params AddPhoneParams with preferredKey, smsCapablePhoneNumber, ctx
     */
    private void addPhone(CPRequest req, AddPhoneParams params) {
        String sanitizedRequestValue = sanitizePhoneNumber(req.value);
        PhoneMatches matches = findPhoneMatches(params.ctx.existingPhones.get(req.accId), req, sanitizedRequestValue);

        if (String.isNotBlank(req.value)) {
            ContactPointPhone cpp = resolveContactPointPhone(matches, req, params.preferredKey);

            cpp.ParentId = req.accId;
            cpp.TelephoneNumber = sanitizedRequestValue;
            cpp.UsageType = req.type;
            // IsPrimary true only for the one chosen by staging: Phone (Work) > Home > Mobile
            cpp.IsPrimary = (String.isNotBlank(params.preferredKey) && req.preferredKey == params.preferredKey);
            // Persist fixed slot so next run matches this CPP to the same source field
            cpp.PreferenceRank = (req.fixedSlot != null) ? req.fixedSlot : req.rank;
            cpp.IsSmsCapable = (sanitizedRequestValue == sanitizePhoneNumber(params.smsCapablePhoneNumber));
            addToUpsertList(params.ctx, cpp);
        } else if (matches != null && matches.matchByUsageType != null) {
            params.ctx.deleteList.add(matches.matchByUsageType);
        }
    }

    private class AddPhoneParams {
        public String preferredKey;
        public String smsCapablePhoneNumber;
        public ProcessingContext ctx;
    }

    private PhoneMatches findPhoneMatches(List<ContactPointPhone> existing, CPRequest req, String sanitizedRequestValue) {
        PhoneMatches m = new PhoneMatches();
        if (existing == null) {
            return m;
        }
        for (ContactPointPhone cpp : existing) {
            assignMatchBySlot(m, cpp, req);
            assignMatchByRank(m, cpp, req);
            assignUsageTypeMatches(m, cpp, req);
            assignMatchByPhoneNumber(m, cpp, req, sanitizedRequestValue);
        }
        return m;
    }

    private void assignMatchBySlot(PhoneMatches m, ContactPointPhone cpp, CPRequest req) {
        if (req.fixedSlot == null || cpp.PreferenceRank != req.fixedSlot || m.matchBySlot != null) {
            return;
        }
        m.matchBySlot = cpp;
    }

    private void assignMatchByRank(PhoneMatches m, ContactPointPhone cpp, CPRequest req) {
        if (req.rank == null || cpp.PreferenceRank != req.rank || m.matchByRank != null) {
            return;
        }
        m.matchByRank = cpp;
    }

    private void assignUsageTypeMatches(PhoneMatches m, ContactPointPhone cpp, CPRequest req) {
        if (cpp.UsageType != req.type) {
            return;
        }
        if (m.matchByUsageType == null) {
            m.matchByUsageType = cpp;
        }
        if (cpp.IsPrimary == true && m.matchByUsageTypeAndPrimary == null) {
            m.matchByUsageTypeAndPrimary = cpp;
        }
    }

    private void assignMatchByPhoneNumber(PhoneMatches m, ContactPointPhone cpp, CPRequest req, String sanitizedRequestValue) {
        if (String.isBlank(sanitizedRequestValue) || String.isBlank(cpp.TelephoneNumber)) {
            return;
        }
        if (cpp.TelephoneNumber != sanitizedRequestValue || cpp.UsageType == req.type || m.matchByPhoneNumber != null) {
            return;
        }
        m.matchByPhoneNumber = cpp;
    }

    private ContactPointPhone resolveContactPointPhone(PhoneMatches matches, CPRequest req, String preferredKey) {
        if (matches.matchBySlot != null) {
            return matches.matchBySlot;
        }
        if (matches.matchByRank != null) {
            return matches.matchByRank;
        }
        if (req.preferredKey != null && req.preferredKey == preferredKey && matches.matchByUsageTypeAndPrimary != null) {
            return matches.matchByUsageTypeAndPrimary;
        }
        if (matches.matchByUsageType != null) {
            return matches.matchByUsageType;
        }
        if (matches.matchByPhoneNumber != null) {
            return matches.matchByPhoneNumber;
        }
        return new ContactPointPhone(ParentId = req.accId);
    }

    /**
     * @description Normalizes preferred phone value to the internal key used for ranking.
     * @param preferredValue Preferred phone value from staging
     * @return Normalized preferred key
     */
    private String normalizePreferredPhoneKey(String preferredValue) {
        if (String.isBlank(preferredValue)) {
            return null;
        }
        if (preferredValue == 'Main') {
            return 'Business';
        }
        return preferredValue;
    }

    /**
     * @description Sanitize phone number to contain only digits (matching regex ^[0-9]+$).
     * @param phoneNumber The phone number to sanitize
     * @return Sanitized phone number containing only digits, or original value if blank
     */
    private String sanitizePhoneNumber(String phoneNumber) {
        if (String.isBlank(phoneNumber)) {
            return phoneNumber;
        }
        return phoneNumber.replaceAll('[^0-9]', '');
    }

    /**
     * @description Process Addresses for Physician Staging. Mailing (primary) and Shipping. Mailing is mapped to HealthcarePractitionerFacility.
     * @param reg OrgSync_Physician_Staging__c record
     * @param accId Account ID
     * @param ctx ProcessingContext object
     */
    private void processAddresses(OrgSync_Physician_Staging__c reg, Id accId, ProcessingContext ctx) {
        final String mailing = 'Mailing';
        final String shipping = 'Shipping';

        // Address Field API Name Maps (Address Type -> Component Field API Name)
        Map<String, Map<String, String>> addressFieldMap = new Map<String, Map<String, String>>{
            mailing => new Map<String, String>{
                'Street' => 'OrgSync_Mailing_Address__Street__s',
                'City' => 'OrgSync_Mailing_Address__City__s',
                'StateCode' => 'OrgSync_Mailing_Address__StateCode__s',
                'PostalCode' => 'OrgSync_Mailing_Address__PostalCode__s'
            },
            shipping => new Map<String, String>{
                'Street' => 'OrgSync_Other_Address__Street__s',
                'City' => 'OrgSync_Other_Address__City__s',
                'StateCode' => 'OrgSync_Other_Address__StateCode__s',
                'PostalCode' => 'OrgSync_Other_Address__PostalCode__s'
            }
        };

        // Get existing addresses for the current Account
        List<ContactPointAddress> existing = ctx.existingAddresses.get(accId);

        // Iterate and process each address type (Mailing, Shipping)
        for (String addrType : addressFieldMap.keySet()) {
            Map<String, String> fieldNames = addressFieldMap.get(addrType);

            // Extract data directly from the staging record using the specific field API names
            String newStreetValue = (String)reg.get(fieldNames.get('Street'));
            String newCityValue = (String)reg.get(fieldNames.get('City'));
            String newStateValue = (String)reg.get(fieldNames.get('StateCode'));
            String newPostalCodeValue = (String)reg.get(fieldNames.get('PostalCode'));

            ContactPointAddress match = null;

            // Find existing match by AddressType; for Shipping also match legacy 'Other' so we update to Shipping
            if (existing != null) {
                for (ContactPointAddress cpa : existing) {
                    if (cpa.AddressType == addrType) {
                        match = cpa;
                        break;
                    }
                    if (addrType == shipping && cpa.AddressType == 'Other') {
                        match = cpa;
                        break;
                    }
                }
            }

            // Determine action (Upsert or Delete)
            // Use the Street value to determine if an address is present.
            if (String.isNotBlank(newStreetValue)) {
                // New value exists: Upsert (Create or Update)
                ContactPointAddress cpa = match != null ? match : new ContactPointAddress(ParentId = accId);

                // Map individual address components
                cpa.Name = newStreetValue;
                cpa.ParentId = accId;
                cpa.Street = newStreetValue;
                cpa.City = newCityValue;
                cpa.StateCode = newStateValue;
                cpa.PostalCode = newPostalCodeValue;

                // Set required fields
                cpa.AddressType = addrType;
                cpa.IsPrimary = (addrType == mailing);
                cpa.PreferenceRank = (addrType == mailing) ? 1 : 2;

                addToUpsertList(ctx, cpa);
            } else if (match != null) {
                // New value is blank, but an existing record was found: Delete
                ctx.deleteList.add(match);
            }
        }
    }

    /**
     * @description Populates primaryContactPointPhoneByAccountId from upserted ContactPointPhone records with IsPrimary=true.
     * @param upsertList List of records that was upserted (may contain ContactPointPhone and other types)
     */
    private void populatePrimaryContactPointPhones(List<SObject> upsertList) {
        primaryContactPointPhoneByAccountId.clear();
        for (SObject rec : upsertList) {
            if (rec instanceof ContactPointPhone) {
                ContactPointPhone cpp = (ContactPointPhone) rec;
                if (cpp.IsPrimary == true && cpp.ParentId != null) {
                    primaryContactPointPhoneByAccountId.put(cpp.ParentId, cpp);
                }
            }
        }
    }

    /**
     * @description Returns the primary ContactPointPhone for the given Account (set during last processContactPoints run).
     * Use this from another class after processContactPoints has been invoked for the relevant staging records.
     * @param accountId Account Id (ParentId of ContactPointPhone)
     * @return Primary ContactPointPhone for the account, or null if none
     */
    public static ContactPointPhone getPrimaryContactPointPhone(Id accountId) {
        return primaryContactPointPhoneByAccountId.get(accountId);
    }

    /**
     * @description Returns the map of Account Id to primary ContactPointPhone from the last processContactPoints run.
     * @return Map of Account Id to primary ContactPointPhone
     */
    public static Map<Id, ContactPointPhone> getPrimaryContactPointPhones() {
        return primaryContactPointPhoneByAccountId.clone();
    }

    /**
     * @description Builds map of Account Id to primary ContactPointEmail (PreferenceRank 1) from ctx.
     * Overlays upsertList (takes precedence) then fills gaps from existingEmails.
     * @param ctx ProcessingContext with existing emails and upserted records
     * @param providerAccountIds Set of provider account IDs
     * @return Map of Account Id to primary ContactPointEmail
     */
    private Map<Id, ContactPointEmail> buildPrimaryCpeByAccountId(ProcessingContext ctx, Set<Id> providerAccountIds) {
        Map<Id, ContactPointEmail> result = new Map<Id, ContactPointEmail>();
        fillPrimaryCpeFromUpsertList(result, ctx.upsertList, providerAccountIds);
        fillPrimaryCpeFromExisting(result, ctx, providerAccountIds);
        return result;
    }

    private void fillPrimaryCpeFromUpsertList(Map<Id, ContactPointEmail> result, List<SObject> upsertList, Set<Id> providerAccountIds) {
        for (SObject rec : upsertList) {
            if (!(rec instanceof ContactPointEmail)) {
                continue;
            }
            ContactPointEmail cpe = (ContactPointEmail) rec;
            if (cpe.PreferenceRank != 1 || cpe.ParentId == null || !providerAccountIds.contains(cpe.ParentId)) {
                continue;
            }
            result.put(cpe.ParentId, cpe);
        }
    }

    private void fillPrimaryCpeFromExisting(Map<Id, ContactPointEmail> result, ProcessingContext ctx, Set<Id> providerAccountIds) {
        if (ctx.existingEmails == null) {
            return;
        }
        for (Id accId : providerAccountIds) {
            if (result.containsKey(accId)) {
                continue;
            }
            ContactPointEmail primary = findPrimaryEmailForAccount(ctx.existingEmails.get(accId), ctx.deleteList);
            if (primary != null) {
                result.put(accId, primary);
            }
        }
    }

    private ContactPointEmail findPrimaryEmailForAccount(List<ContactPointEmail> emails, List<SObject> deleteList) {
        if (emails == null) {
            return null;
        }
        for (ContactPointEmail cpe : emails) {
            if (cpe.PreferenceRank == 1 && !deleteList.contains(cpe)) {
                return cpe;
            }
        }
        return null;
    }

    /**
     * @description Builds map of Account Id to Mailing ContactPointAddress from ctx.
     * Overlays upsertList (takes precedence) then fills gaps from existingAddresses.
     * @param ctx ProcessingContext with existing addresses and upserted records
     * @param providerAccountIds Set of provider account IDs
     * @return Map of Account Id to Mailing ContactPointAddress
     */
    private Map<Id, ContactPointAddress> buildMailingCpaByAccountId(ProcessingContext ctx, Set<Id> providerAccountIds) {
        Map<Id, ContactPointAddress> result = new Map<Id, ContactPointAddress>();
        fillMailingCpaFromUpsertList(result, ctx.upsertList, providerAccountIds);
        fillMailingCpaFromExisting(result, ctx, providerAccountIds);
        return result;
    }

    private void fillMailingCpaFromUpsertList(Map<Id, ContactPointAddress> result, List<SObject> upsertList, Set<Id> providerAccountIds) {
        for (SObject rec : upsertList) {
            if (!(rec instanceof ContactPointAddress)) {
                continue;
            }
            ContactPointAddress cpa = (ContactPointAddress) rec;
            if (cpa.AddressType != 'Mailing' || cpa.ParentId == null || !providerAccountIds.contains(cpa.ParentId)) {
                continue;
            }
            result.put(cpa.ParentId, cpa);
        }
    }

    private void fillMailingCpaFromExisting(Map<Id, ContactPointAddress> result, ProcessingContext ctx, Set<Id> providerAccountIds) {
        if (ctx.existingAddresses == null) {
            return;
        }
        for (Id accId : providerAccountIds) {
            if (result.containsKey(accId)) {
                continue;
            }
            ContactPointAddress mailing = findMailingAddressForAccount(ctx.existingAddresses.get(accId), ctx.deleteList);
            if (mailing != null) {
                result.put(accId, mailing);
            }
        }
    }

    private ContactPointAddress findMailingAddressForAccount(List<ContactPointAddress> addrs, List<SObject> deleteList) {
        if (addrs == null) {
            return null;
        }
        for (ContactPointAddress cpa : addrs) {
            if (cpa.AddressType == 'Mailing' && !deleteList.contains(cpa)) {
                return cpa;
            }
        }
        return null;
    }

    /**
     * @description Updates HealthcarePractitionerFacility for processed providers: sets Phone__c to primary
     * ContactPointPhone, Email__c to primary ContactPointEmail (OrgSync_PersonEmail__c), and Mailing_Address__c
     * to the Mailing ContactPointAddress. Builds primary ContactPoint maps from context and upsertList to avoid SOQL.
     * @param ctx ProcessingContext with existing data and upserted records
     */
    private void updateHealthcarePractitionerFacilities(ProcessingContext ctx) {
        if (processedAccountIdsInLastRun.isEmpty()) {
            return;
        }
        Set<Id> providerAccountIds = new Set<Id>(processedAccountIdsInLastRun);
        // HPF links to provider via PractitionerId = Account.PersonContactId
        Map<Id, Id> practitionerIdToProviderAccountId = new Map<Id, Id>();
        Set<Id> accountIdsNeedingQuery = new Set<Id>();
        for (Id accId : providerAccountIds) {
            Id personContactId = ctx.accountIdToPersonContactIdCache != null ? ctx.accountIdToPersonContactIdCache.get(accId) : null;
            if (personContactId != null) {
                practitionerIdToProviderAccountId.put(personContactId, accId);
            } else {
                accountIdsNeedingQuery.add(accId);
            }
        }
        if (!accountIdsNeedingQuery.isEmpty()) {
            for (Account acc : [
                SELECT Id, PersonContactId
                FROM Account
                WHERE Id IN :accountIdsNeedingQuery
                    AND PersonContactId != null
                WITH SYSTEM_MODE
            ]) {
                practitionerIdToProviderAccountId.put(acc.PersonContactId, acc.Id);
            }
        }
        if (practitionerIdToProviderAccountId.isEmpty()) {
            return;
        }

        // Build primary ContactPoint maps from ctx + upsertList (avoids 3 SOQL queries)
        Map<Id, ContactPointPhone> primaryCppByAccountId = primaryContactPointPhoneByAccountId.clone();
        Map<Id, ContactPointEmail> primaryCpeByAccountId = buildPrimaryCpeByAccountId(ctx, providerAccountIds);
        Map<Id, ContactPointAddress> mailingCpaByAccountId = buildMailingCpaByAccountId(ctx, providerAccountIds);

        List<HealthcarePractitionerFacility> hpfToUpdate = new List<HealthcarePractitionerFacility>();
        for (HealthcarePractitionerFacility hpf : [
            SELECT Id, PractitionerId
            FROM HealthcarePractitionerFacility
            WHERE PractitionerId IN :practitionerIdToProviderAccountId.keySet()
            WITH SYSTEM_MODE
        ]) {
            Id providerAccountId = practitionerIdToProviderAccountId.get(hpf.PractitionerId);
            Boolean changed = false;
            ContactPointPhone primaryCpp = primaryCppByAccountId.get(providerAccountId);
            if (primaryCpp != null && primaryCpp.Id != null) {
                hpf.Phone__c = primaryCpp.Id;
                changed = true;
            }
            ContactPointEmail primaryCpe = primaryCpeByAccountId.get(providerAccountId);
            if (primaryCpe != null && primaryCpe.Id != null) {
                hpf.Email__c = primaryCpe.Id;
                changed = true;
            }
            ContactPointAddress mailingCpa = mailingCpaByAccountId.get(providerAccountId);
            if (mailingCpa != null && mailingCpa.Id != null) {
                hpf.Address__c = mailingCpa.Id;
                changed = true;
            }
            if (changed) {
                hpfToUpdate.add(hpf);
            }
        }
        if (!hpfToUpdate.isEmpty()) {
            List<Database.SaveResult> updateResults = Database.update(hpfToUpdate, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(updateResults, hpfToUpdate, new Map<String, String>{
                'className' => 'OrgSync_PhysicianContactPointService',
                'methodName' => 'updateHealthcarePractitionerFacilities',
                'operationDescription' => 'updating HealthcarePractitionerFacility Phone__c, Email__c, Address__c'
            });
        }
    }

    /**
     * @description Adds a record to the upsert list if it's not already present.
     * @param ctx ProcessingContext object
     * @param record SObject to upsert
     */
    private void addToUpsertList(ProcessingContext ctx, SObject record) {
        if (record == null) {
            return;
        }
        if (!ctx.upsertList.contains(record)) {
            ctx.upsertList.add(record);
        }
    }
}