/**
 * @description Service class for Contact Point Objects (Email, Phone, Address).
 * Created Date : Nov 17, 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 02, 2025        Ramesh Dhaka            Initial Version
 * V1.0.1       Jan 23, 2026        Neeraj Kumar            Added Sanitize Phone Number method
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount')
public inherited sharing class OrgSync_ContactPointObjectService {
    // Cache consent lookups across multiple method calls in the same transaction.
    private static Set<Id> consentCheckedContactPointIds = new Set<Id>();
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
         * @description Constructor initializing the processing context object.
         */
        public ProcessingContext() {
            upsertList = new List<SObject>();
            deleteList = new List<SObject>();
            existingEmails = new Map<Id, List<ContactPointEmail>>();
            existingPhones = new Map<Id, List<ContactPointPhone>>();
            existingAddresses = new Map<Id, List<ContactPointAddress>>();
        }
    }

    /**
     * @description CPRequest class.
     */
    private class CPRequest {
        public String value;
        public String type; // For Phone/Address
        public Integer rank; // For Email
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
    }

    /**
     * @description Process Contact Points from Staging records.
     * @param records List of staging records
     * @param oldMap Map of old staging records (trigger.oldMap)
     */
    public void processContactPoints(List<OrgSync_Patient_Staging__c> records, Map<Id, OrgSync_Patient_Staging__c> oldMap) {//NOPMD
        try {
            Set<String> externalIds = new Set<String>();
            for (OrgSync_Patient_Staging__c reg : records) {
                if (String.isNotBlank(reg.XCDC_ExternalId__c)) {
                    externalIds.add(reg.XCDC_ExternalId__c);
                }
            }

            Map<String, Id> extIdToAccountId = new Map<String, Id>();
            Set<String> remainingExternalIds = new Set<String>();

            for (String extId : externalIds) {
                if (OrgSync_PatientService.processedAccountIds.containsKey(extId)) {
                    extIdToAccountId.put(extId, OrgSync_PatientService.processedAccountIds.get(extId));
                } else {
                    remainingExternalIds.add(extId);
                }
            }

            if (!remainingExternalIds.isEmpty()) {
                for (Account acc : [SELECT Id, XCDC_ExternalId__c FROM Account WHERE XCDC_ExternalId__c IN :remainingExternalIds WITH SYSTEM_MODE]) {
                    extIdToAccountId.put(acc.XCDC_ExternalId__c, acc.Id);
                }
            }

            ProcessingContext ctx = new ProcessingContext();

            if (!extIdToAccountId.isEmpty()) {
                loadExistingData(ctx, extIdToAccountId.values());
            }

            for (OrgSync_Patient_Staging__c reg : records) {
                Id accId = extIdToAccountId.get(reg.XCDC_ExternalId__c);
                if (accId == null){
                    continue;
                }
                processEmails(reg, accId, ctx);
                processPhones(reg, accId, ctx);
                processAddresses(reg, accId, ctx);
            }

            if (!ctx.deleteList.isEmpty()) {
                deleteRelatedConsents(ctx.deleteList);
                List<Database.DeleteResult> deleteResults = Database.delete(ctx.deleteList, false, AccessLevel.SYSTEM_MODE);
                OrgSync_LoggingUtility.handleDatabaseResults(deleteResults, ctx.deleteList, new Map<String, String>{
                    'className' => 'OrgSync_ContactPointObjectService',
                    'methodName' => 'processContactPoints',
                    'operationDescription' => 'deleting Contact Point'
                });
            }
            if (!ctx.upsertList.isEmpty()) {
                // Separate records by SObject type to avoid chunking limit
                // Salesforce limits DML operations to 10 chunks when mixing SObject types
                List<ContactPointEmail> emailsToUpsert = new List<ContactPointEmail>();
                List<ContactPointPhone> phonesToUpsert = new List<ContactPointPhone>();
                List<ContactPointAddress> addressesToUpsert = new List<ContactPointAddress>();

                for (SObject record : ctx.upsertList) {
                    if (record instanceof ContactPointEmail) {
                        emailsToUpsert.add((ContactPointEmail)record);
                    } else if (record instanceof ContactPointPhone) {
                        phonesToUpsert.add((ContactPointPhone)record);
                    } else if (record instanceof ContactPointAddress) {
                        addressesToUpsert.add((ContactPointAddress)record);
                    }
                }

                // Upsert each type separately to avoid chunking limit
                if (!emailsToUpsert.isEmpty()) {
                    List<Database.UpsertResult> upsertResults = Database.upsert(emailsToUpsert, false, AccessLevel.SYSTEM_MODE);
                    OrgSync_LoggingUtility.handleDatabaseResults(upsertResults, emailsToUpsert, new Map<String, String>{
                        'className' => 'OrgSync_ContactPointObjectService',
                        'methodName' => 'processContactPoints',
                        'operationDescription' => 'upserting Contact Point Email'
                    });
                }
                if (!phonesToUpsert.isEmpty()) {
                    ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone = true;
                    try {
                        List<Database.UpsertResult> upsertResults = Database.upsert(phonesToUpsert, false, AccessLevel.SYSTEM_MODE);
                        OrgSync_LoggingUtility.handleDatabaseResults(upsertResults, phonesToUpsert, new Map<String, String>{
                            'className' => 'OrgSync_ContactPointObjectService',
                            'methodName' => 'processContactPoints',
                            'operationDescription' => 'upserting Contact Point Phone'
                        });
                    } finally {
                        ContactPointPhoneHandler.skipSetPrimaryOnNewContactPointPhone = false;
                    }
                }
                if (!addressesToUpsert.isEmpty()) {
                    List<Database.UpsertResult> upsertResults = Database.upsert(addressesToUpsert, false, AccessLevel.SYSTEM_MODE);
                    OrgSync_LoggingUtility.handleDatabaseResults(upsertResults, addressesToUpsert, new Map<String, String>{
                        'className' => 'OrgSync_ContactPointObjectService',
                        'methodName' => 'processContactPoints',
                        'operationDescription' => 'upserting Contact Point Address'
                    });
                }
            }
        } catch (Exception e) {
            Logger.error('OrgSync_ContactPointObjectService: processContactPoints: Error processing contact points. Details: ' + e.getMessage()).addTag('OrgSync');
        }
    }

    /**
     * @description Load Existing Data.
     * @param ctx ProcessingContext object
     * @param accountIds List of account IDs
     */
    private void loadExistingData(ProcessingContext ctx, List<Id> accountIds) {
        for (ContactPointEmail cpe : [SELECT Id, ParentId, PreferenceRank, EmailAddress FROM ContactPointEmail WHERE ParentId IN :accountIds WITH SYSTEM_MODE]) {
            if (!ctx.existingEmails.containsKey(cpe.ParentId)){
                ctx.existingEmails.put(cpe.ParentId, new List<ContactPointEmail>());
            }
            ctx.existingEmails.get(cpe.ParentId).add(cpe);
        }
        for (ContactPointPhone cpp : [SELECT Id, ParentId, TelephoneNumber, UsageType, IsSmsCapable, IsPersonalPhone, IsFaxCapable, IsBusinessPhone FROM ContactPointPhone WHERE ParentId IN :accountIds WITH SYSTEM_MODE]) {
            if (!ctx.existingPhones.containsKey(cpp.ParentId)){
                ctx.existingPhones.put(cpp.ParentId, new List<ContactPointPhone>());
            }
            ctx.existingPhones.get(cpp.ParentId).add(cpp);
        }
        for (ContactPointAddress cpa : [SELECT Id, ParentId, AddressType, Street FROM ContactPointAddress WHERE ParentId IN :accountIds WITH SYSTEM_MODE]) {
            if (!ctx.existingAddresses.containsKey(cpa.ParentId)){
                ctx.existingAddresses.put(cpa.ParentId, new List<ContactPointAddress>());
            }
            ctx.existingAddresses.get(cpa.ParentId).add(cpa);
        }
    }

    /**
     * @description Process Emails.
     * @param reg OrgSync_Patient_Staging__c record
     * @param accId Account ID
     * @param ctx ProcessingContext object
     */
    private void processEmails(OrgSync_Patient_Staging__c reg, Id accId, ProcessingContext ctx) {
        addEmail(new CPRequest(reg.OrgSync_Email_1__c, 1, accId), ctx);
        addEmail(new CPRequest(reg.OrgSync_Email_2__c, 2, accId), ctx);
    }

    /**
     * @description Add Email.
     * @param req CPRequest object
     * @param ctx ProcessingContext object
     */
    private void addEmail(CPRequest req, ProcessingContext ctx) {
        List<ContactPointEmail> existing = ctx.existingEmails.get(req.accId);
        ContactPointEmail matchByRank = null;
        ContactPointEmail matchByValue = null;
        if (existing != null) {
            for (ContactPointEmail cpe : existing) {
                if (cpe.PreferenceRank == req.rank) {
                    matchByRank = cpe;
                }
                if (String.isNotBlank(req.value)
                    && String.isNotBlank(cpe.EmailAddress)
                    && cpe.EmailAddress.equalsIgnoreCase(req.value)) {
                    matchByValue = cpe;
                }
            }
        }

        if (String.isNotBlank(req.value)) {
            if (matchByValue != null && matchByRank != null && matchByRank.Id != matchByValue.Id) {
                // Same email already exists on a different record; do not create another.
                return;
            }
            ContactPointEmail cpe;
            if (matchByRank != null) {
                cpe = matchByRank;
            } else if (matchByValue != null) {
                cpe = matchByValue;
                if (cpe.PreferenceRank == null) {
                    cpe.PreferenceRank = req.rank;
                }
            } else {
                cpe = new ContactPointEmail(ParentId = req.accId, PreferenceRank = req.rank);
            }
            cpe.ParentId = req.accId;
            cpe.EmailAddress = req.value;
            cpe.IsPrimary = (req.rank == 1);
            ctx.upsertList.add(cpe);
        } else if (matchByRank != null) {
            ctx.deleteList.add(matchByRank);
        }
    }

    /**
     * @description Process Phones.
     * @param reg OrgSync_Patient_Staging__c record
     * @param accId Account ID
     * @param ctx ProcessingContext object
     */
    private void processPhones(OrgSync_Patient_Staging__c reg, Id accId, ProcessingContext ctx) {
        addPhone(new CPRequest(reg.OrgSync_Home_Phone__c, 'Home', accId), reg, ctx);
        addPhone(new CPRequest(reg.OrgSync_Work_Phone__c, 'Work', accId), reg, ctx);
        addPhone(new CPRequest(reg.OrgSync_Mobile_Phone__c, 'Mobile', accId), reg, ctx);
        addPhone(new CPRequest(reg.OrgSync_Fax__c, 'Fax', accId), reg, ctx);
        addPhone(new CPRequest(reg.OrgSync_Phone__c, 'Other', accId), reg, ctx);
    }

    /**
     * @description Add Phone.
     * @param req CPRequest object
     * @param reg OrgSync_Patient_Staging__c record
     * @param ctx ProcessingContext object
     */
    private void addPhone(CPRequest req, OrgSync_Patient_Staging__c reg, ProcessingContext ctx) {
        List<ContactPointPhone> existing = ctx.existingPhones.get(req.accId);
        ContactPointPhone matchByUsageType = null;
        ContactPointPhone matchByPhoneNumber = null;
        ContactPointPhone existingMobilePhone = null;
        String preferredPhoneType = reg.OrgSync_Preferred_Phone_Number__c;
        String smsCapablePhoneNumber = reg.OrgSync_Mobile_Phone__c !=null ? reg.OrgSync_Mobile_Phone__c : reg.OrgSync_Home_Phone__c;
        if (existing != null) {
            for (ContactPointPhone cpp : existing) {
                // Match by UsageType
                if (cpp.UsageType == req.type && matchByUsageType == null) {
                    matchByUsageType = cpp;
                }
                // Match by TelephoneNumber (different UsageType)
                if (String.isNotBlank(req.value) && cpp.TelephoneNumber == OrgSync_UtilityService.sanitizePhoneNumber(req.value) && cpp.UsageType != req.type && matchByPhoneNumber == null) {
                    matchByPhoneNumber = cpp;
                }
                // Track existing Mobile phone for preferred phone logic
                if (cpp.UsageType == 'Mobile') {
                    existingMobilePhone = cpp;
                }
            }
        }

        if (String.isNotBlank(req.value)) {
            ContactPointPhone cpp;

            // Determine which record to update or create
            if (matchByUsageType != null) {
                // Found by UsageType - update existing
                cpp = matchByUsageType;
            } else if (matchByPhoneNumber != null) {
                // Found same phone number with different UsageType - update that record
                cpp = matchByPhoneNumber;
            } else if (preferredPhoneType == req.type && existingMobilePhone != null) {
                // Preferred phone type matches current type, and mobile phone exists - update mobile
                cpp = existingMobilePhone;
            } else {
                // No match - create new
                cpp = new ContactPointPhone(ParentId = req.accId);
            }

            cpp.ParentId = req.accId;
            cpp.TelephoneNumber = OrgSync_UtilityService.sanitizePhoneNumber(req.value);
            cpp.UsageType = req.type;
            // Mark as primary only if this type matches the preferred phone type
            cpp.IsPrimary = (req.type == preferredPhoneType);
            cpp.IsPersonalPhone = (req.type == 'Mobile' || req.type == 'Home');
            cpp.IsFaxCapable = (req.type == 'Fax');
            cpp.IsBusinessPhone = (req.type == 'Work');
            cpp.PreferenceRank = cpp.IsPrimary ? 1 : 2;
            cpp.IsSmsCapable = (req.value == smsCapablePhoneNumber);
            ctx.upsertList.add(cpp);
        } else if (matchByUsageType != null) {
            ctx.deleteList.add(matchByUsageType);
        }
    }

    private void processAddresses(OrgSync_Patient_Staging__c reg, Id accId, ProcessingContext ctx) {
        final String shipping = 'Shipping';
        final String billing = 'Billing';

        // Address Field API Name Maps (Address Type -> Component Field API Name)
        Map<String, Map<String, String>> addressFieldMap = new Map<String, Map<String, String>>{
            shipping => new Map<String, String>{
                'Street' => 'OrgSync_Shipping_Address__Street__s',
                'City' => 'OrgSync_Shipping_Address__City__s',
                'StateCode' => 'OrgSync_Shipping_Address__StateCode__s',
                'PostalCode' => 'OrgSync_Shipping_Address__PostalCode__s'
            },
            billing => new Map<String, String>{
                'Street' => 'OrgSync_Billing_Address__Street__s',
                'City' => 'OrgSync_Billing_Address__City__s',
                'StateCode' => 'OrgSync_Billing_Address__StateCode__s',
                'PostalCode' => 'OrgSync_Billing_Address__PostalCode__s'
            }
        };
        // Get existing addresses for the current Account
        List<ContactPointAddress> existing = ctx.existingAddresses.get(accId);

        // Iterate and process each address type (Mailing, Billing)
        for (String addrType : addressFieldMap.keySet()) {
            Map<String, String> fieldNames = addressFieldMap.get(addrType);

            // Extract data directly from the staging record using the specific field API names
            String newStreetValue = (String)reg.get(fieldNames.get('Street'));
            String newCityValue = (String)reg.get(fieldNames.get('City'));
            String newStateValue = (String)reg.get(fieldNames.get('StateCode'));
            String newPostalCodeValue = (String)reg.get(fieldNames.get('PostalCode'));

            ContactPointAddress match = null;

            // Find existing match by AddressType
            if (existing != null) {
                for (ContactPointAddress cpa : existing) {
                    if (cpa.AddressType == addrType) {
                        match = cpa;
                        break;
                    }
                }
            }

            // Determine action (Upsert or Delete)
            // Use the Street value (or City/State/Zip if Street is empty) to determine if an address is present.
            // We'll primarily check for Street for simplicity, as it's the anchor of a physical address.
            if (String.isNotBlank(newStreetValue)) {
                // New value exists: Upsert (Create or Update)
                ContactPointAddress cpa = match != null ? match : new ContactPointAddress(ParentId = accId);

                // Map individual address components
                cpa.Name=newStreetValue;
                cpa.ParentId = accId;
                cpa.Street = newStreetValue; // Map Street
                cpa.City = newCityValue;     // Map City
                cpa.StateCode = newStateValue;   // Map State
                cpa.PostalCode = newPostalCodeValue; // Map Zip Code

                // Set required fields
                cpa.AddressType = addrType;
                cpa.IsPrimary = true;
                cpa.PreferenceRank = 1;

                ctx.upsertList.add(cpa);
            } else if (match != null) {
                // New value is blank, but an existing record was found: Delete
                ctx.deleteList.add(match);
            }
        }
    }

    /**
     * @description Deletes Contact Point consent records before deleting Contact Points.
     * @param contactPoints List of ContactPointEmail/Phone/Address records to be deleted.
     */
    private void deleteRelatedConsents(List<SObject> contactPoints) {
        if (contactPoints == null || contactPoints.isEmpty()) {
            return;
        }

        Set<Id> contactPointIds = new Set<Id>();
        for (SObject record : contactPoints) {
            if (record != null && record.Id != null) {
                contactPointIds.add(record.Id);
            }
        }

        if (contactPointIds.isEmpty()) {
            return;
        }

        // Avoid re-querying consent records for the same ContactPointIds in the same transaction.
        contactPointIds.removeAll(consentCheckedContactPointIds);
        if (contactPointIds.isEmpty()) {
            return;
        }
        consentCheckedContactPointIds.addAll(contactPointIds);

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        if (globalDescribe.containsKey('ContactPointConsent')) {
            List<SObject> consents = Database.query(
                'SELECT Id FROM ContactPointConsent WHERE ContactPointId IN :contactPointIds WITH SYSTEM_MODE'
            );
            if (!consents.isEmpty()) {
                Database.delete(consents, false, AccessLevel.SYSTEM_MODE);
            }
        }

    }
}