/**
 * @description Class to sync demographics to staging.
 * Created Date : Dec 2026
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 2,2025          Neeraj Kumar            Initial Version
 * V1.0.1       Feb 19, 2026        Pradip Kokate           Updated to handle Blank UsageType as 'Home'
 * V1.0.2       Feb 2026            Ramesh Kumar            Added Guardian CPE/CPP sync to Patient Stage
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount,PMD.CognitiveComplexity')
public inherited sharing class OrgSync_DemographicsSyncToStaging {
    // Cache Account lookups across multiple method calls in the same transaction.
    private static Map<Id, Account> cachedAccountsById = new Map<Id, Account>();
    // Cache consent lookups across multiple method calls in the same transaction.
    private static Set<Id> consentCheckedContactPointIds = new Set<Id>();
    /**
     * @description sync ContactPointEmail to Patient Staging.
     * Syncs the latest ContactPointEmail record (by LastModifiedDate) to the staging email field.
     * @param emailRecords ContactPointEmail List
     */
    public void syncContactPointEmailToStaging(List<ContactPointEmail> emailRecords){
        if (emailRecords.isEmpty()) {
            return;
        }
        Map<Id, Account> accountMap = getParentAccountMap(emailRecords);
        if (accountMap.isEmpty()) {
            return;
        }

        Map<String, OrgSync_Patient_Staging__c> externalIdToStagingMap = getStagingRecords(accountMap);
        if (externalIdToStagingMap.isEmpty()) {
            return;
        }

        // Collect parent account IDs
        Set<Id> parentAccountIds = accountMap.keySet();

        // Query all ContactPointEmail records for these parent accounts, ordered by LastModifiedDate DESC
        List<ContactPointEmail> allEmailRecords = [
            SELECT Id, ParentId, EmailAddress, LastModifiedDate
            FROM ContactPointEmail
            WHERE ParentId IN :parentAccountIds
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
        ];

        // Map: ParentId -> Latest ContactPointEmail (first one encountered due to DESC ordering)
        Map<Id, ContactPointEmail> parentIdToLatestEmail = new Map<Id, ContactPointEmail>();
        for (ContactPointEmail cpe : allEmailRecords) {
            if (!parentIdToLatestEmail.containsKey(cpe.ParentId)) {
                parentIdToLatestEmail.put(cpe.ParentId, cpe);
            }
        }

        List<OrgSync_Patient_Staging__c> stagingRecordsToUpdate = new List<OrgSync_Patient_Staging__c>();

        // Match and Update Staging Records
        for (Id accId : parentIdToLatestEmail.keySet()) {
            Account parentAccount = accountMap.get(accId);
            ContactPointEmail latestEmail = parentIdToLatestEmail.get(accId);
            String externalId = parentAccount?.XCDC_ExternalId__c;

            if (String.isNotBlank(externalId) && externalIdToStagingMap.containsKey(externalId)) {
                OrgSync_Patient_Staging__c stagingRecord = externalIdToStagingMap.get(externalId);
                String newEmailValue = latestEmail.EmailAddress;

                if (stagingRecord.OrgSync_Email_1__c != newEmailValue) {
                    stagingRecord.OrgSync_Email_1__c = newEmailValue;
                    stagingRecordsToUpdate.add(stagingRecord);
                }
            }
        }

        // Perform DML
        if (!stagingRecordsToUpdate.isEmpty()) {
            List<Database.UpsertResult> upsertResults = Database.upsert(stagingRecordsToUpdate, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(upsertResults, stagingRecordsToUpdate, new Map<String, String>{
                'className' => 'OrgSync_DemographicsSyncToStaging',
                'methodName' => 'syncContactPointEmailToStaging',
                'operationDescription' => 'updating Staging Record'
            });
        }
    }

    /**
     * @description Retrieves a map of Account records containing the XCDC_ExternalId__c for a list of Contact Point records.
     * @param contactPointRecords List of SObjects (ContactPointEmail/Phone/Address).
     * @return Map<Id, Account> where Key is ParentId (Account ID).
     */
    private Map<Id, Account> getParentAccountMap(List<SObject> contactPointRecords) {
        Set<Id> parentAccountIds = new Set<Id>();

        // 1. Collect Parent IDs
        for (SObject cpRecord : contactPointRecords) {
            Id parentId = (Id)cpRecord.get('ParentId');
            if (parentId != null) {
                parentAccountIds.add(parentId);
            }
        }

        if (parentAccountIds.isEmpty()) {
            return new Map<Id, Account>();
        }

        // 2. Query Accounts only for missing ids and merge into cache
        Set<Id> idsToQuery = new Set<Id>(parentAccountIds);
        idsToQuery.removeAll(cachedAccountsById.keySet());
        if (!idsToQuery.isEmpty()) {
            for (Account acc : [
                SELECT Id, XCDC_ExternalId__c, RecordTypeId
                FROM Account
                WHERE Id IN :idsToQuery
                WITH SYSTEM_MODE
            ]) {
                cachedAccountsById.put(acc.Id, acc);
            }
        }

        // 3. Build result map from cache for requested ids
        Map<Id, Account> result = new Map<Id, Account>();
        for (Id accId : parentAccountIds) {
            if (cachedAccountsById.containsKey(accId)) {
                result.put(accId, cachedAccountsById.get(accId));
            }
        }
        return result;
    }

    /**
     * @description Queries the Staging records based on the External IDs found on the Accounts.
     *              Uses OrgSync_SoqlUtility cache - only queries for external IDs not already fetched.
     * @param accountMap Map of Account IDs to Account records (must include XCDC_ExternalId__c).
     * @return Map<String, OrgSync_Patient_Staging__c> where Key is the External ID.
     */
    private Map<String, OrgSync_Patient_Staging__c> getStagingRecords(Map<Id, Account> accountMap) {
        Set<String> accountExternalIds = new Set<String>();

        for (Account acc : accountMap.values()) {
            if (String.isNotBlank(acc.XCDC_ExternalId__c)) {
                accountExternalIds.add(acc.XCDC_ExternalId__c);
            }
        }

        if (accountExternalIds.isEmpty()) {
            return new Map<String, OrgSync_Patient_Staging__c>();
        }

        return OrgSync_SoqlUtility.getPatientStagingByExternalIds(accountExternalIds);
    }

    /**
     * @description sync ContactPointAddress to Patient Staging.
     * @param addressRecords ContactPointAddress List
     */
    public void syncContactPointAddressToStaging(List<ContactPointAddress> addressRecords){
        if (addressRecords.isEmpty()){
            return;
        }
        // 1. Initial ID Collection
        Set<Id> parentAccountIds = new Set<Id>();
        for (ContactPointAddress cpa : addressRecords) {
            if (cpa.ParentId != null) {
                parentAccountIds.add(cpa.ParentId);
            }
        }
        if (parentAccountIds.isEmpty()){
            return;
        }
        // 2. QUERY TO FIND THE MOST RECENT ADDRESS PER ADDRESSTYPE
        // We query all relevant addresses, ensuring they are ordered by LastModifiedDate DESC.
        List<ContactPointAddress> relevantCPAs = [
            SELECT Id, ParentId, AddressType, Street, City, StateCode, PostalCode, LastModifiedDate
            FROM ContactPointAddress
            WHERE ParentId IN :parentAccountIds
            AND AddressType IN ('Billing', 'Shipping')
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC // Order by newest first
        ];
        // Map: ParentId -> Map<AddressType, MostRecentCPA>
        Map<Id, Map<String, ContactPointAddress>> parentIdToTypeMap = new Map<Id, Map<String, ContactPointAddress>>();
        for (ContactPointAddress cpa : relevantCPAs) {
            if (!parentIdToTypeMap.containsKey(cpa.ParentId)) {
                parentIdToTypeMap.put(cpa.ParentId, new Map<String, ContactPointAddress>());
            }
            Map<String, ContactPointAddress> typeMap = parentIdToTypeMap.get(cpa.ParentId);
            // Because the list is ordered DESC, the first record encountered for a given AddressType
            // is guaranteed to be the most recent one.
            if (!typeMap.containsKey(cpa.AddressType)) {
                typeMap.put(cpa.AddressType, cpa);
            }
        }
        if (parentIdToTypeMap.isEmpty()){
            return;
        }
        // 3. Get Account and Staging Maps (Optimization helpers)
        Map<Id, Account> accountMap = getParentAccountMap(addressRecords);
        if (accountMap.isEmpty()){
            return;
        }
        Map<String, OrgSync_Patient_Staging__c> externalIdToStagingMap = getStagingRecords(accountMap);
        if (externalIdToStagingMap.isEmpty()){
            return;
        }
        List<OrgSync_Patient_Staging__c> stagingRecordsToUpdate = new List<OrgSync_Patient_Staging__c>();
        // 4. Match and Update Staging Records (Using the prioritized map)
        for (Id accId : parentIdToTypeMap.keySet()) {
            Account parentAccount = accountMap.get(accId);
            Map<String, ContactPointAddress> typeMap = parentIdToTypeMap.get(accId);
            String externalId = parentAccount?.XCDC_ExternalId__c;
            if (String.isNotBlank(externalId) && externalIdToStagingMap.containsKey(externalId)) {
                OrgSync_Patient_Staging__c stagingRecord = externalIdToStagingMap.get(externalId);
                Boolean updateNeeded = false;
                // Iterate through the prioritized Billing and Shipping addresses found
                for (String addressType : typeMap.keySet()) {
                    ContactPointAddress cpaToUse = typeMap.get(addressType);
                    if (addressType == 'Billing') {
                        if (stagingRecord.OrgSync_Billing_Address__Street__s != cpaToUse.Street) { stagingRecord.OrgSync_Billing_Address__Street__s = cpaToUse.Street; updateNeeded = true; }
                        if (stagingRecord.OrgSync_Billing_Address__City__s != cpaToUse.City) { stagingRecord.OrgSync_Billing_Address__City__s = cpaToUse.City; updateNeeded = true; }
                        if (stagingRecord.OrgSync_Billing_Address__StateCode__s != cpaToUse.StateCode) { stagingRecord.OrgSync_Billing_Address__StateCode__s = cpaToUse.StateCode; updateNeeded = true; }
                        if (stagingRecord.OrgSync_Billing_Address__PostalCode__s != cpaToUse.PostalCode) { stagingRecord.OrgSync_Billing_Address__PostalCode__s = cpaToUse.PostalCode; updateNeeded = true; }
                    } else if (addressType == 'Shipping') {
                        if (stagingRecord.OrgSync_Shipping_Address__Street__s != cpaToUse.Street) { stagingRecord.OrgSync_Shipping_Address__Street__s = cpaToUse.Street; updateNeeded = true; }
                        if (stagingRecord.OrgSync_Shipping_Address__City__s != cpaToUse.City) { stagingRecord.OrgSync_Shipping_Address__City__s = cpaToUse.City; updateNeeded = true; }
                        if (stagingRecord.OrgSync_Shipping_Address__StateCode__s != cpaToUse.StateCode) { stagingRecord.OrgSync_Shipping_Address__StateCode__s = cpaToUse.StateCode; updateNeeded = true; }
                        if (stagingRecord.OrgSync_Shipping_Address__PostalCode__s != cpaToUse.PostalCode) { stagingRecord.OrgSync_Shipping_Address__PostalCode__s = cpaToUse.PostalCode; updateNeeded = true; }
                    }
                }
                if (updateNeeded) {
                    stagingRecordsToUpdate.add(stagingRecord);
                }
            }
        }
        // 5. Perform DML
        if (!stagingRecordsToUpdate.isEmpty()) {
            List<Database.UpsertResult> upsertResults = Database.upsert(stagingRecordsToUpdate, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(upsertResults, stagingRecordsToUpdate, new Map<String, String>{
                'className' => 'OrgSync_DemographicsSyncToStaging',
                'methodName' => 'syncContactPointAddressToStaging',
                'operationDescription' => 'updating Staging Record'
            });
        }
    }

    /**
     * @description sync ContactPointPhone to Patient Staging.
     * Maps phone numbers to staging fields based on UsageType (Home, Work, Mobile).
     * Sets OrgSync_Preferred_Phone_Number__c to the UsageType of the primary phone record.
     * @param phoneRecords ContactPointPhone List
     */
    public void syncContactPointPhoneToStaging(List<ContactPointPhone> phoneRecords){
        if (phoneRecords.isEmpty()) {
            return;
        }

        Map<Id, Account> accountMap = getParentAccountMap(phoneRecords);
        if (accountMap.isEmpty()) {
            return;
        }

        Map<String, OrgSync_Patient_Staging__c> externalIdToStagingMap = getStagingRecords(accountMap);
        if (externalIdToStagingMap.isEmpty()) {
            return;
        }

        // Collect parent account IDs
        Set<Id> parentAccountIds = accountMap.keySet();

        // Query all ContactPointPhone records for these parent accounts to get complete picture
        // Include records with blank UsageType which should be treated as 'Home'
        // Order by LastModifiedDate DESC so we pick the latest-updated record when multiple have IsPrimary = true
        List<ContactPointPhone> allPhoneRecords = [
            SELECT Id, ParentId, TelephoneNumber, UsageType, IsPrimary, IsSmsCapable, IsPersonalPhone, IsFaxCapable, IsBusinessPhone, LastModifiedDate
            FROM ContactPointPhone
            WHERE ParentId IN :parentAccountIds
            AND (UsageType IN ('Home', 'Work', 'Mobile' ,'Fax', 'Other') OR UsageType = null)
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
        ];

        // Group phone records by ParentId and identify primary record
        // Map: ParentId -> Map<UsageType, ContactPointPhone>
        Map<Id, Map<String, ContactPointPhone>> parentIdToPhonesByType = new Map<Id, Map<String, ContactPointPhone>>();
        // Map: ParentId -> Primary ContactPointPhone (latest updated among those with IsPrimary = true)
        Map<Id, ContactPointPhone> parentIdToPrimaryPhone = new Map<Id, ContactPointPhone>();

        for (ContactPointPhone cpp : allPhoneRecords) {
            // Build usage type map for each parent
            // Treat blank UsageType as 'Home'
            // Keep only the first (most recently updated/created) per UsageType when multiple exist
            String normalizedUsageType = String.isBlank(cpp.UsageType) ? 'Home' : cpp.UsageType;

            if (!parentIdToPhonesByType.containsKey(cpp.ParentId)) {
                parentIdToPhonesByType.put(cpp.ParentId, new Map<String, ContactPointPhone>());
            }
            Map<String, ContactPointPhone> phonesByType = parentIdToPhonesByType.get(cpp.ParentId);
            if (!phonesByType.containsKey(normalizedUsageType)) {
                phonesByType.put(normalizedUsageType, cpp);
            }

            // Track primary phone record - use the first (most recently updated) when multiple have IsPrimary = true
            if (cpp.IsPrimary == true && !parentIdToPrimaryPhone.containsKey(cpp.ParentId)) {
                parentIdToPrimaryPhone.put(cpp.ParentId, cpp);
            }
        }

        List<OrgSync_Patient_Staging__c> stagingRecordsToUpdate = new List<OrgSync_Patient_Staging__c>();

        // Match and Update Staging Records
        for (Id accId : parentIdToPhonesByType.keySet()) {
            Account parentAccount = accountMap.get(accId);
            String externalId = parentAccount?.XCDC_ExternalId__c;

            if (String.isNotBlank(externalId) && externalIdToStagingMap.containsKey(externalId)) {
                OrgSync_Patient_Staging__c stagingRecord = externalIdToStagingMap.get(externalId);
                Map<String, ContactPointPhone> phonesByType = parentIdToPhonesByType.get(accId);
                ContactPointPhone primaryPhone = parentIdToPrimaryPhone.get(accId);

                Boolean updateNeeded = false;

                // Map Home phone
                if (phonesByType.containsKey('Home')) {
                    String homePhoneValue = phonesByType.get('Home').TelephoneNumber;
                    if (stagingRecord.OrgSync_Home_Phone__c != homePhoneValue) {
                        stagingRecord.OrgSync_Home_Phone__c = homePhoneValue;
                        updateNeeded = true;
                    }
                }

                // Map Work phone
                if (phonesByType.containsKey('Work')) {
                    String workPhoneValue = phonesByType.get('Work').TelephoneNumber;
                    if (stagingRecord.OrgSync_Work_Phone__c != workPhoneValue) {
                        stagingRecord.OrgSync_Work_Phone__c = workPhoneValue;
                        updateNeeded = true;
                    }
                }

                // Map Mobile phone
                if (phonesByType.containsKey('Mobile')) {
                    String mobilePhoneValue = phonesByType.get('Mobile').TelephoneNumber;
                    if (stagingRecord.OrgSync_Mobile_Phone__c != mobilePhoneValue) {
                        stagingRecord.OrgSync_Mobile_Phone__c = mobilePhoneValue;
                        updateNeeded = true;
                    }
                }

                // Other Phone
                if (phonesByType.containsKey('Other')) {
                    String otherPhoneValue = phonesByType.get('Other').TelephoneNumber;
                    if (stagingRecord.OrgSync_Phone__c != otherPhoneValue) {
                        stagingRecord.OrgSync_Phone__c = otherPhoneValue;
                        updateNeeded = true;
                    }
                }

                // Map Fax
                if (phonesByType.containsKey('Fax')) {
                    String faxPhoneValue = phonesByType.get('Fax').TelephoneNumber;
                    if (stagingRecord.OrgSync_Fax__c != faxPhoneValue) {
                        stagingRecord.OrgSync_Fax__c = faxPhoneValue;
                        updateNeeded = true;
                    }
                }

                // Set OrgSync_Preferred_Phone_Number__c based on the primary record's UsageType
                // Treat blank UsageType as 'Home'
                if (primaryPhone != null) {
                    String preferredUsageType = String.isBlank(primaryPhone.UsageType) ? 'Home' : primaryPhone.UsageType;
                    if (stagingRecord.OrgSync_Preferred_Phone_Number__c != preferredUsageType) {
                        stagingRecord.OrgSync_Preferred_Phone_Number__c = preferredUsageType;
                        updateNeeded = true;
                    }
                }

                if (updateNeeded) {
                    stagingRecordsToUpdate.add(stagingRecord);
                }
            }
        }

        // Perform DML
        if (!stagingRecordsToUpdate.isEmpty()) {
            List<Database.UpsertResult> upsertResults = Database.upsert(stagingRecordsToUpdate, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(upsertResults, stagingRecordsToUpdate, new Map<String, String>{
                'className' => 'OrgSync_DemographicsSyncToStaging',
                'methodName' => 'syncContactPointPhoneToStaging',
                'operationDescription' => 'updating Staging Record'
            });
        }
    }

    /**
     * @description Clears the corresponding address fields on the Patient Staging object
     * when a ContactPointAddress record is deleted.
     * @param deletedAddressRecords List of ContactPointAddress records from Trigger.old
     */
    public void clearStagingAddressOnDelete(List<ContactPointAddress> deletedAddressRecords) {
        deleteRelatedConsents(deletedAddressRecords);

        Set<Id> parentAccountIds = new Set<Id>();

        // Map: Account ID -> Deleted ContactPointAddress (to get the AddressType for matching)
        Map<Id, ContactPointAddress> deletedCPAByParentId = new Map<Id, ContactPointAddress>();

        // 1. Collect Parent IDs and map the deleted records by ParentId
        for (ContactPointAddress cpa : deletedAddressRecords) {
            if (cpa.ParentId != null) {
                parentAccountIds.add(cpa.ParentId);
                // Since an Account might have multiple addresses, we assume the trigger is only
                // concerned with the one being deleted now.
                deletedCPAByParentId.put(cpa.ParentId, cpa);
            }
        }

        if (parentAccountIds.isEmpty()) {
            return;
        }
        // 2. Query Accounts to get the External ID (using the reliable approach)
        Map<Id, Account> accountMap = getParentAccountMap(deletedAddressRecords);

        // 3. Collect External IDs and query Staging Records
        Set<String> accountExternalIds = new Set<String>();
        for (Account acc : accountMap.values()) {
            if (String.isNotBlank(acc.XCDC_ExternalId__c)) {
                accountExternalIds.add(acc.XCDC_ExternalId__c);
            }
        }

        if (accountExternalIds.isEmpty()) {
            return;
        }

        // 4. Query Staging Records (using the helper method, which must select all address component fields)
        Map<String, OrgSync_Patient_Staging__c> externalIdToStagingMap = getStagingRecords(accountMap);

        List<OrgSync_Patient_Staging__c> stagingRecordsToUpdate = new List<OrgSync_Patient_Staging__c>();

        // 5. Match and Nullify Staging Fields
        for (Id accId : deletedCPAByParentId.keySet()) {
            Account parentAccount = accountMap.get(accId);
            ContactPointAddress deletedCPA = deletedCPAByParentId.get(accId);
            String externalId = parentAccount?.XCDC_ExternalId__c;

            if (String.isNotBlank(externalId) && externalIdToStagingMap.containsKey(externalId)) {
                OrgSync_Patient_Staging__c stagingRecord = externalIdToStagingMap.get(externalId);
                String deletedAddressType = deletedCPA.AddressType;

                Boolean updateNeeded = false;

                if (deletedAddressType == 'Billing') {
                    // Clear all Billing fields regardless of current value
                    stagingRecord.OrgSync_Billing_Address__Street__s = null;
                    stagingRecord.OrgSync_Billing_Address__City__s = null;
                    stagingRecord.OrgSync_Billing_Address__StateCode__s = null;
                    stagingRecord.OrgSync_Billing_Address__PostalCode__s = null;
                    stagingRecord.OrgSync_Billing_Address__CountryCode__s = null;
                    updateNeeded = true;

                } else if (deletedAddressType == 'Shipping') {
                    // Clear all Shipping fields regardless of current value
                    stagingRecord.OrgSync_Shipping_Address__Street__s = null;
                    stagingRecord.OrgSync_Shipping_Address__City__s = null;
                    stagingRecord.OrgSync_Shipping_Address__StateCode__s = null;
                    stagingRecord.OrgSync_Shipping_Address__PostalCode__s = null;
                    stagingRecord.OrgSync_Shipping_Address__CountryCode__s = null;
                    updateNeeded = true;
                }

                if (updateNeeded) {
                    stagingRecordsToUpdate.add(stagingRecord);
                }
            }
        }

        // 6. Perform DML
        if (!stagingRecordsToUpdate.isEmpty()) {
            List<Database.UpsertResult> upsertResults = Database.upsert(stagingRecordsToUpdate, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(upsertResults, stagingRecordsToUpdate, new Map<String, String>{
                'className' => 'OrgSync_DemographicsSyncToStaging',
                'methodName' => 'clearStagingAddressOnDelete',
                'operationDescription' => 'updating Staging Record'
            });
        }
    }

    /**
     * @description Clears the email field on the Patient Staging object
     * when a ContactPointEmail record is deleted.
     * @param deletedEmailRecords List of ContactPointEmail records from Trigger.old
     */
    public void clearStagingEmailOnDelete(List<ContactPointEmail> deletedEmailRecords) {
        deleteRelatedConsents(deletedEmailRecords);

        // Use the reliable two-query approach for deleted records
        Set<Id> parentAccountIds = new Set<Id>();

        // 1. Collect Parent IDs (using data passed from trigger.old)
        for (ContactPointEmail cpe : deletedEmailRecords) {
            if (cpe.ParentId != null) {
                parentAccountIds.add(cpe.ParentId);
            }
        }

        if (parentAccountIds.isEmpty()) {
            return;
        }

        // 2. Query Accounts and Staging Records (using generic helper methods)
        Map<Id, Account> accountMap = getParentAccountMap(deletedEmailRecords);
        Map<String, OrgSync_Patient_Staging__c> externalIdToStagingMap = getStagingRecords(accountMap);

        if (externalIdToStagingMap.isEmpty()) {
            return;
        }

        List<OrgSync_Patient_Staging__c> stagingRecordsToUpdate = new List<OrgSync_Patient_Staging__c>();

        // 3. Match and Nullify Staging Fields
        for (Id accId : parentAccountIds) {
            Account parentAccount = accountMap.get(accId);
            String externalId = parentAccount?.XCDC_ExternalId__c;

            if (String.isNotBlank(externalId) && externalIdToStagingMap.containsKey(externalId)) {
                OrgSync_Patient_Staging__c stagingRecord = externalIdToStagingMap.get(externalId);

                // Assuming OrgSync_Email_1__c is the field corresponding to the deleted email.
                // In complex setups, you'd need logic to ensure this was the primary/synced email.
                if (stagingRecord.OrgSync_Email_1__c != null) {
                    stagingRecord.OrgSync_Email_1__c = null; // Clear the field
                    stagingRecordsToUpdate.add(stagingRecord);
                }
            }
        }

        // 4. Perform DML
        if (!stagingRecordsToUpdate.isEmpty()) {
            List<Database.UpsertResult> upsertResults = Database.upsert(stagingRecordsToUpdate, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(upsertResults, stagingRecordsToUpdate, new Map<String, String>{
                'className' => 'OrgSync_DemographicsSyncToStaging',
                'methodName' => 'clearStagingEmailOnDelete',
                'operationDescription' => 'updating Staging Record'
            });
        }
    }

    /**
     * @description Clears the corresponding phone fields on the Patient Staging object
     * when a ContactPointPhone record is deleted.
     * @param deletedPhoneRecords List of ContactPointPhone records from Trigger.old
     */
    public void clearStagingPhoneOnDelete(List<ContactPointPhone> deletedPhoneRecords) {
        deleteRelatedConsents(deletedPhoneRecords);

        // Use the reliable two-query approach for deleted records
        Set<Id> parentAccountIds = new Set<Id>();

        // 1. Collect Parent IDs
        for (ContactPointPhone cpp : deletedPhoneRecords) {
            if (cpp.ParentId != null) {
                parentAccountIds.add(cpp.ParentId);
            }
        }

        if (parentAccountIds.isEmpty()) {
            return;
        }

        // 2. Query Accounts and Staging Records (using generic helper methods)
        Map<Id, Account> accountMap = getParentAccountMap(deletedPhoneRecords);
        Map<String, OrgSync_Patient_Staging__c> externalIdToStagingMap = getStagingRecords(accountMap);

        if (externalIdToStagingMap.isEmpty()) {
            return;
        }

        List<OrgSync_Patient_Staging__c> stagingRecordsToUpdate = new List<OrgSync_Patient_Staging__c>();

        // 3. Match and Nullify Staging Fields
        for (Id accId : parentAccountIds) {
            Account parentAccount = accountMap.get(accId);
            String externalId = parentAccount?.XCDC_ExternalId__c;
            if (String.isNotBlank(externalId) && externalIdToStagingMap.containsKey(externalId)) {
                OrgSync_Patient_Staging__c stagingRecord = externalIdToStagingMap.get(externalId);
                // We need to iterate over the deleted phone records associated with this Account.
                // We use the original deleted list and filter by ParentId.
                for (ContactPointPhone deletedCPP : deletedPhoneRecords) {
                    if (deletedCPP.ParentId == accId) {
                        String deletedUsageType = deletedCPP.UsageType;
                        Boolean updateNeeded = false;
                        if (deletedUsageType == 'Home' && stagingRecord.OrgSync_Home_Phone__c != null) {
                            stagingRecord.OrgSync_Home_Phone__c = null;
                            updateNeeded = true;
                        } else if (deletedUsageType == 'Work' && stagingRecord.OrgSync_Work_Phone__c != null) {
                            stagingRecord.OrgSync_Work_Phone__c = null;
                            updateNeeded = true;
                        } else if (deletedUsageType == 'Mobile' && stagingRecord.OrgSync_Mobile_Phone__c != null) {
                            stagingRecord.OrgSync_Mobile_Phone__c = null;
                            updateNeeded = true;
                        } else if (deletedUsageType == 'Fax' && stagingRecord.OrgSync_Fax__c != null) {
                            stagingRecord.OrgSync_Fax__c = null;
                            updateNeeded = true;
                        } else if (deletedUsageType == 'Other' && stagingRecord.OrgSync_Phone__c != null) {
                            stagingRecord.OrgSync_Phone__c = null;
                            updateNeeded = true;
                        }
                        if (updateNeeded) {
                            stagingRecordsToUpdate.add(stagingRecord);
                            // Once one field is updated on the staging record, we can break the inner loop
                            // for this account's deleted phones (assuming only one phone of each type exists).
                            break;
                        }
                    }
                }
            }
        }
        // 4. Perform DML
        if (!stagingRecordsToUpdate.isEmpty()) {
            List<Database.UpsertResult> upsertResults = Database.upsert(stagingRecordsToUpdate, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(upsertResults, stagingRecordsToUpdate, new Map<String, String>{
                'className' => 'OrgSync_DemographicsSyncToStaging',
                'methodName' => 'clearStagingPhoneOnDelete',
                'operationDescription' => 'updating Staging Record'
            });
        }
    }

    /**
     * @description Syncs CPE changes on Patient Delegate to Guardian 1/2 sections on Patient Stage records.
     *              Update: only if modified CPE is the latest among all CPEs for that delegate. Insert: always sync.
     * @param emailRecords ContactPointEmail records from trigger
     * @param oldMap Trigger.oldMap (null for insert)
     */
    public void syncGuardianContactPointEmailToPatientStage(List<ContactPointEmail> emailRecords, Map<Id, ContactPointEmail> oldMap) {
        if (emailRecords == null || emailRecords.isEmpty()) {
            return;
        }
        Map<Id, Account> accountMap = getParentAccountMap(emailRecords);
        Set<Id> delegateAccountIds = new Set<Id>();
        for (ContactPointEmail cpe : emailRecords) {
            Account acc = accountMap.get(cpe.ParentId);
            if (acc != null && acc.RecordTypeId == ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT) {
                delegateAccountIds.add(cpe.ParentId);
            }
        }
        if (delegateAccountIds.isEmpty()) {
            return;
        }
        Map<Id, Id> parentIdToLatestCpeId = new Map<Id, Id>();
        if (oldMap != null) {
            for (ContactPointEmail cpe : OrgSync_SoqlUtility.getContactPointEmailsByParentIds(delegateAccountIds)) {
                if (!parentIdToLatestCpeId.containsKey(cpe.ParentId)) {
                    parentIdToLatestCpeId.put(cpe.ParentId, cpe.Id);
                }
            }
        }
        List<ContactContactRelation> allCCRs = OrgSync_SoqlUtility.getGuardianCCRsByDelegateAccountIds(delegateAccountIds);
        Map<Id, List<ContactContactRelation>> ccrsByDelegateAccId = new Map<Id, List<ContactContactRelation>>();
        for (ContactContactRelation ccr : allCCRs) {
            Id delegateAccId = ccr.RelatedContact?.AccountId;
            if (delegateAccId == null) {
                continue;
            }
            if (!ccrsByDelegateAccId.containsKey(delegateAccId)) {
                ccrsByDelegateAccId.put(delegateAccId, new List<ContactContactRelation>());
            }
            ccrsByDelegateAccId.get(delegateAccId).add(ccr);
        }
        Map<String, OrgSync_Patient_Staging__c> stagingByExtId = new Map<String, OrgSync_Patient_Staging__c>();
        for (ContactPointEmail cpe : emailRecords) {
            if (accountMap.get(cpe.ParentId)?.RecordTypeId != ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT) {
                continue;
            }
            if (oldMap != null && parentIdToLatestCpeId.get(cpe.ParentId) != cpe.Id) {
                continue;
            }
            List<ContactContactRelation> ccrs = ccrsByDelegateAccId.get(cpe.ParentId);
            if (ccrs == null) {
                continue;
            }
            for (ContactContactRelation ccr : ccrs) {
                String patientExtId = ccr.Contact?.Account != null ? ccr.Contact.Account.XCDC_ExternalId__c : null;
                if (String.isBlank(patientExtId)) {
                    continue;
                }
                Integer seq = ccr.OrgSync_Guardian_Sequence__c != null ? ccr.OrgSync_Guardian_Sequence__c.intValue() : null;
                if (seq == null || (seq != 1 && seq != 2)) {
                    continue;
                }
                OrgSync_Patient_Staging__c staging = stagingByExtId.get(patientExtId);
                if (staging == null) {
                    staging = new OrgSync_Patient_Staging__c(XCDC_ExternalId__c = patientExtId);
                    stagingByExtId.put(patientExtId, staging);
                }
                OrgSync_UtilityService.updateGuardianEmailOnStaging(staging, seq, cpe.EmailAddress);
            }
        }
        if (!stagingByExtId.isEmpty()) {
            List<Database.UpsertResult> results = Database.upsert(stagingByExtId.values(), OrgSync_Patient_Staging__c.Fields.XCDC_ExternalId__c, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(results, stagingByExtId.values(), new Map<String, String>{
                'className' => 'OrgSync_DemographicsSyncToStaging',
                'methodName' => 'syncGuardianContactPointEmailToPatientStage',
                'operationDescription' => 'updating Guardian email on Patient Stage'
            });
        }
    }

    /**
     * @description Syncs CPP changes on Patient Delegate to Guardian 1/2 phone fields on Patient Stage records.
     *              Update: only if modified CPP is the latest for that UsageType. Insert: always sync.
     *              Maps UsageType (Home/Work/Mobile) to Guardian phone fields.
     * @param phoneRecords ContactPointPhone records from trigger
     * @param oldMap Trigger.oldMap (null for insert)
     */
    public void syncGuardianContactPointPhoneToPatientStage(List<ContactPointPhone> phoneRecords, Map<Id, ContactPointPhone> oldMap) {
        if (phoneRecords == null || phoneRecords.isEmpty()) {
            return;
        }
        Map<Id, Account> accountMap = getParentAccountMap(phoneRecords);
        Set<Id> delegateAccountIds = new Set<Id>();
        for (ContactPointPhone cpp : phoneRecords) {
            Account acc = accountMap.get(cpp.ParentId);
            if (acc != null && acc.RecordTypeId == ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT) {
                delegateAccountIds.add(cpp.ParentId);
            }
        }
        if (delegateAccountIds.isEmpty()) {
            return;
        }
        Map<String, Id> parentAndUsageToLatestCppId = new Map<String, Id>();
        if (oldMap != null) {
            for (ContactPointPhone cpp : OrgSync_SoqlUtility.getContactPointPhonesByParentIds(delegateAccountIds)) {
                String usageType = String.isBlank(cpp.UsageType) ? 'Home' : cpp.UsageType;
                if (!('Home'.equals(usageType) || 'Work'.equals(usageType) || 'Mobile'.equals(usageType))) {
                    continue;
                }
                String key = String.valueOf(cpp.ParentId) + '_' + usageType;
                if (!parentAndUsageToLatestCppId.containsKey(key)) {
                    parentAndUsageToLatestCppId.put(key, cpp.Id);
                }
            }
        }
        List<ContactContactRelation> allCCRs = OrgSync_SoqlUtility.getGuardianCCRsByDelegateAccountIds(delegateAccountIds);
        Map<Id, List<ContactContactRelation>> ccrsByDelegateAccId = new Map<Id, List<ContactContactRelation>>();
        for (ContactContactRelation ccr : allCCRs) {
            Id delegateAccId = ccr.RelatedContact?.AccountId;
            if (delegateAccId == null) {
                continue;
            }
            if (!ccrsByDelegateAccId.containsKey(delegateAccId)) {
                ccrsByDelegateAccId.put(delegateAccId, new List<ContactContactRelation>());
            }
            ccrsByDelegateAccId.get(delegateAccId).add(ccr);
        }
        Map<String, OrgSync_Patient_Staging__c> stagingByExtId = new Map<String, OrgSync_Patient_Staging__c>();
        for (ContactPointPhone cpp : phoneRecords) {
            if (accountMap.get(cpp.ParentId)?.RecordTypeId != ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT) {
                continue;
            }
            String usageType = String.isBlank(cpp.UsageType) ? 'Home' : cpp.UsageType;
            if (!('Home'.equals(usageType) || 'Work'.equals(usageType) || 'Mobile'.equals(usageType))) {
                continue;
            }
            if (oldMap != null) {
                String key = String.valueOf(cpp.ParentId) + '_' + usageType;
                if (parentAndUsageToLatestCppId.get(key) != cpp.Id) {
                    continue;
                }
            }
            List<ContactContactRelation> ccrs = ccrsByDelegateAccId.get(cpp.ParentId);
            if (ccrs == null) {
                continue;
            }
            String phoneValue = cpp.TelephoneNumber;
            if (String.isBlank(phoneValue)) {
                continue;
            }
            for (ContactContactRelation ccr : ccrs) {
                String patientExtId = ccr.Contact?.Account != null ? ccr.Contact.Account.XCDC_ExternalId__c : null;
                if (String.isBlank(patientExtId)) {
                    continue;
                }
                Integer seq = ccr.OrgSync_Guardian_Sequence__c != null ? ccr.OrgSync_Guardian_Sequence__c.intValue() : null;
                if (seq == null || (seq != 1 && seq != 2)) {
                    continue;
                }
                OrgSync_Patient_Staging__c staging = stagingByExtId.get(patientExtId);
                if (staging == null) {
                    staging = new OrgSync_Patient_Staging__c(XCDC_ExternalId__c = patientExtId);
                    stagingByExtId.put(patientExtId, staging);
                }
                OrgSync_UtilityService.updateGuardianPhoneOnStaging(staging, seq, usageType, phoneValue);
            }
        }
        if (!stagingByExtId.isEmpty()) {
            List<Database.UpsertResult> results = Database.upsert(stagingByExtId.values(), OrgSync_Patient_Staging__c.Fields.XCDC_ExternalId__c, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(results, stagingByExtId.values(), new Map<String, String>{
                'className' => 'OrgSync_DemographicsSyncToStaging',
                'methodName' => 'syncGuardianContactPointPhoneToPatientStage',
                'operationDescription' => 'updating Guardian phone on Patient Stage'
            });
        }
    }

    /**
     * @description Deletes Contact Point consent records if they exist for the given Contact Points.
     * @param contactPoints List of ContactPointEmail/Phone/Address records.
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
                'SELECT Id FROM ContactPointConsent WHERE ContactPointId IN :contactPointIds'
            );
            if (!consents.isEmpty()) {
                Database.delete(consents, false, AccessLevel.SYSTEM_MODE);
            }
        }
    }
}