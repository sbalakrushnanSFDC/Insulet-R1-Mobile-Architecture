/**
 * @description Generic service class for AccountContactRelation (ACR) record management.
 * Created Date : Dec 02, 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 02, 2025        Ramesh Dhaka            Initial Version
 * V1.1.0       Dec 02, 2025        Ramesh Dhaka            Added isActive and is_Primary__c handling, ACR to Staging sync
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount')
public inherited sharing class OrgSync_Patient_ACRService {

    /**
     * @description Context class for ACR processing.
     */
    private class ACRProcessingContext {
        public Map<String, Id> extIdToContactId;
        public Map<Id, List<AccountContactRelation>> contactToACRs;
        public Map<Id, OrgSync_Patient_Staging__c> oldMap;
        public Map<String, AccountContactRelation> upsertMap; // Key: ContactId + AccountId
        public Set<String> processedKeys; // Used to track created keys in current context if needed

        /**
         * @description Constructor initializing the context object.
         * @param extIdToContactId Map of External ID to Contact ID.
         * @param contactToACRs Map of Contact ID to List of existing ACRs.
         * @param oldMap Map of old staging records.
         */
        public ACRProcessingContext(Map<String, Id> extIdToContactId, Map<Id, List<AccountContactRelation>> contactToACRs, Map<Id, OrgSync_Patient_Staging__c> oldMap) {
            this.extIdToContactId = extIdToContactId;
            this.contactToACRs = contactToACRs;
            this.oldMap = oldMap;
            this.upsertMap = new Map<String, AccountContactRelation>();
            this.processedKeys = new Set<String>();
        }
    }

    /**
     * @description Manages AccountContactRelation records based on staging records.
     * @param records List of new staging records.
     * @param oldMap Map of old staging records.
     * @param extIdToAccountId Map of external ID to account ID for resolving contact IDs.
     */
    public void manageACRsFromStaging(List<OrgSync_Patient_Staging__c> records, Map<Id, OrgSync_Patient_Staging__c> oldMap, Map<String, Id> extIdToAccountId) {
        List<OrgSync_Patient_Staging__c> actionableRecords = filterActionableRecords(records, oldMap);

        if (actionableRecords.isEmpty()) {
            return;
        }

        Map<String, Id> extIdToContactId = getPatientContactIds(actionableRecords, extIdToAccountId);
        if (extIdToContactId.isEmpty()) {
            return;
        }

        // Query ALL practice ACRs for these contacts (active or inactive)
        Map<Id, List<AccountContactRelation>> existingACRsByContact = getExistingACRsByContact(extIdToContactId.values());

        ACRProcessingContext ctx = new ACRProcessingContext(extIdToContactId, existingACRsByContact, oldMap);

        for (OrgSync_Patient_Staging__c newRecord : actionableRecords) {
            Id patientContactId = ctx.extIdToContactId.get(newRecord.XCDC_ExternalId__c);
            if (patientContactId == null) {
                continue;
            }

            updatePracticeAssociation(patientContactId, newRecord.OrgSync_Practice__c, ctx);
        }

        upsertACRs(ctx.upsertMap.values());
    }

    /**
     * @description Upserts AccountContactRelation records (consolidated method for insert and update).
     *              This is the single method for all ACR database operations.
     * @param acrsToUpsert List of ACR records to upsert.
     */
    public void upsertACRs(List<AccountContactRelation> acrsToUpsert) {
        if (acrsToUpsert != null && !acrsToUpsert.isEmpty()) {
            performACRUpsert(acrsToUpsert);
        }
    }

    /**
     * @description Syncs ACR changes to Patient Staging when user is NOT OrgSync User.
     *              Handles insert, update, and delete scenarios.
     * @param newRecords List of new ACR records.
     * @param oldMap Map of old ACR records.
     */
    public void syncACRsToStaging(List<AccountContactRelation> newRecords, Map<Id, AccountContactRelation> oldMap) {
        Set<Id> affectedContactIds = new Set<Id>();
        Set<Id> accountIdsToCheck = new Set<Id>();

        // Collect relevant contacts and accounts from new records (Insert/Update)
        for (AccountContactRelation acr : newRecords) {
            if (acr.ContactId != null && acr.AccountId != null) {
                affectedContactIds.add(acr.ContactId);
                accountIdsToCheck.add(acr.AccountId);
            }
        }

        // Collect relevant contacts and accounts from old records (Update/Delete)
        if (oldMap != null) {
            for (AccountContactRelation oldACR : oldMap.values()) {
                if (oldACR.ContactId != null && oldACR.AccountId != null) {
                    affectedContactIds.add(oldACR.ContactId);
                    accountIdsToCheck.add(oldACR.AccountId);
                }
            }
        }

        if (affectedContactIds.isEmpty()) {
            return;
        }

        // Filter for Practice Accounts only (cached per transaction)
        Set<Id> practiceAccountIds = getPracticeAccountIds(accountIdsToCheck);

        // Re-filter affected contacts to ensure we only process if a Practice ACR was involved
        Set<Id> finalContactIds = new Set<Id>();
        // Check new records
        for (AccountContactRelation acr : newRecords) {
            if (practiceAccountIds.contains(acr.AccountId)) {
                finalContactIds.add(acr.ContactId);
            }
        }
        // Check old records
        if (oldMap != null) {
            for (AccountContactRelation oldACR : oldMap.values()) {
                if (practiceAccountIds.contains(oldACR.AccountId)) {
                    finalContactIds.add(oldACR.ContactId);
                }
            }
        }

        if (finalContactIds.isEmpty()) {
            return;
        }

        // Get patient accounts for these contacts
        Map<Id, Id> contactIdToAccountId = getContactToAccountMap(finalContactIds);
        if (contactIdToAccountId.isEmpty()) {
            return;
        }

        // Get external IDs for these accounts
        Map<Id, String> accountIdToExtId = getAccountToExternalIdMap(contactIdToAccountId.values());

        // Find latest active primary practice for each contact
        Map<Id, Id> latestPracticeMap = findLatestPractices(finalContactIds);
        Map<String, Id> extIdToPracticeId = new Map<String, Id>();

        for (Id contactId : finalContactIds) {
            Id accountId = contactIdToAccountId.get(contactId);
            if (accountId != null) {
                String extId = accountIdToExtId.get(accountId);
                if (String.isNotBlank(extId)) {
                    // Get latest practice ID (can be null if none found/active)
                    Id practiceId = latestPracticeMap.get(contactId);
                    extIdToPracticeId.put(extId, practiceId);
                }
            }
        }

        // Update staging records
        if (!extIdToPracticeId.isEmpty()) {
            updateStagingPracticeFields(extIdToPracticeId);
        }
    }

    /********** Private Methods **********/

    /**
     * @description Filters actionable records based on the old and new practice IDs.
     * @param records List of staging records.
     * @param oldMap Map of old staging records.
     * @return List<OrgSync_Patient_Staging__c> List of actionable staging records.
     */
    private List<OrgSync_Patient_Staging__c> filterActionableRecords(List<OrgSync_Patient_Staging__c> records, Map<Id, OrgSync_Patient_Staging__c> oldMap) {
        List<OrgSync_Patient_Staging__c> actionableRecords = new List<OrgSync_Patient_Staging__c>();
        for (OrgSync_Patient_Staging__c newRecord : records) {
            OrgSync_Patient_Staging__c oldRecord = (oldMap != null) ? oldMap.get(newRecord.Id) : null;
            Id newPracticeId = newRecord.OrgSync_Practice__c;
            Id oldPracticeId = (oldRecord != null) ? oldRecord.OrgSync_Practice__c : null;

            boolean isInsertWithValue = (oldRecord == null && newPracticeId != null);
            boolean isUpdateChange = (oldRecord != null && newPracticeId != oldPracticeId);

            if ((isInsertWithValue || isUpdateChange) && String.isNotBlank(newRecord.XCDC_ExternalId__c)) {
                actionableRecords.add(newRecord);
            }
        }
        return actionableRecords;
    }

    /**
     * @description Gets the patient contact IDs based on the actionable records.
     * @param actionableRecords List of actionable staging records.
     * @param extIdToAccountId Map of external ID to account ID.
     * @return Map<String, Id> Map of External ID to Contact ID.
     */
    private Map<String, Id> getPatientContactIds(List<OrgSync_Patient_Staging__c> actionableRecords, Map<String, Id> extIdToAccountId) {
        Map<String, Id> extIdToContactId = new Map<String, Id>();
        if (extIdToAccountId == null || extIdToAccountId.isEmpty()) {
            return extIdToContactId;
        }

        for (Account acc : [SELECT Id, PersonContactId, XCDC_ExternalId__c
                            FROM Account
                            WHERE Id IN :extIdToAccountId.values()
                            WITH SYSTEM_MODE]) {
            if (acc.PersonContactId != null && String.isNotBlank(acc.XCDC_ExternalId__c)) {
                extIdToContactId.put(acc.XCDC_ExternalId__c, acc.PersonContactId);
            }
        }
        return extIdToContactId;
    }

    /**
     * @description Gets existing Account Contact Relations for given contacts and Practice record type.
     * @param contactIds List of contact IDs.
     * @return Map<Id, List<AccountContactRelation>> Map of Contact ID to List of ACRs.
     */
    private Map<Id, List<AccountContactRelation>> getExistingACRsByContact(List<Id> contactIds) {
        Map<Id, List<AccountContactRelation>> resultMap = new Map<Id, List<AccountContactRelation>>();
        String roleValue = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE;
        for (AccountContactRelation acr : [SELECT Id, AccountId, ContactId, Roles, IsActive, Is_Primary__c
                                            FROM AccountContactRelation
                                            WHERE ContactId IN :contactIds
                                            AND Roles INCLUDES (:roleValue)
                                            WITH SYSTEM_MODE]) {
            if (!resultMap.containsKey(acr.ContactId)) {
                resultMap.put(acr.ContactId, new List<AccountContactRelation>());
            }
            resultMap.get(acr.ContactId).add(acr);
        }
        return resultMap;
    }

    /**
     * @description Updates the practice association for a contact.
     *              Deactivates existing/other practice ACRs and activates/creates the new one.
     * @param contactId Contact ID.
     * @param newPracticeId New Practice Account ID (can be null).
     * @param ctx ACRProcessingContext object.
     */
    private void updatePracticeAssociation(Id contactId, Id newPracticeId, ACRProcessingContext ctx) {
        List<AccountContactRelation> acrList = ctx.contactToACRs.get(contactId);
        if (acrList == null) {
            acrList = new List<AccountContactRelation>();
            ctx.contactToACRs.put(contactId, acrList);
        }

        boolean newPracticeFound = false;

        // 1. Deactivate others (or all if newPracticeId is null) and activate target if exists
        for (AccountContactRelation acr : acrList) {
            // Check Role
            if (String.isNotBlank(acr.Roles) && acr.Roles.contains(ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE)) {
                if (newPracticeId != null && acr.AccountId == newPracticeId) {
                    newPracticeFound = true;
                    // Activate if needed
                    if (!acr.IsActive || !acr.Is_Primary__c) {
                        acr.IsActive = true;
                        acr.Is_Primary__c = true;
                        addToUpsertMap(acr, ctx);
                    }
                } else {
                    // Only mark as non-primary, do NOT deactivate
                    if (acr.Is_Primary__c) {
                        acr.Is_Primary__c = false;
                        addToUpsertMap(acr, ctx);
                    }
                }
            }
        }

        // 2. If newPracticeId is not null and not found in existing list, create it
        if (newPracticeId != null && !newPracticeFound) {
            // Double check if we created it in this batch but not in list?
            // The list is updated below, so if it's not in list, it's not created yet.
            // Create new
            AccountContactRelation newACR = createACR(contactId, newPracticeId, ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE, true, true);
            addToUpsertMap(newACR, ctx);
            // Add to in-memory list for subsequent processing in same batch
            acrList.add(newACR);
        }
    }

    /**
     * @description Adds an ACR to the upsert map.
     * @param acr AccountContactRelation record.
     * @param ctx ACRProcessingContext object.
     */
    private void addToUpsertMap(AccountContactRelation acr, ACRProcessingContext ctx) {
        String key = buildACRKey(acr.ContactId, acr.AccountId);
        ctx.upsertMap.put(key, acr);
    }

    /**
     * @description Performs Account Contact Relation upsert.
     * @param acrsToUpsert List of Account Contact Relations to upsert.
     */
    private void performACRUpsert(List<AccountContactRelation> acrsToUpsert) {
        if (!acrsToUpsert.isEmpty()) {
            List<Database.UpsertResult> results = Database.upsert(acrsToUpsert, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(results, acrsToUpsert, new Map<String, String>{
                'className' => 'OrgSync_Patient_ACRService',
                'methodName' => 'manageACRsFromStaging',
                'operationDescription' => 'upserting AccountContactRelation'
            });
        }
    }

    /**
     * @description Builds ACR key from Contact and Account IDs.
     * @param contactId Contact ID.
     * @param accountId Account ID.
     * @return String ACR key.
     */
    private String buildACRKey(Id contactId, Id accountId) {
        return contactId + '' + accountId;
    }

    /**
     * @description Creates a new AccountContactRelation record.
     * @param contactId Contact ID.
     * @param accountId Account ID.
     * @param role Role to assign.
     * @param isActive Whether the ACR is active.
     * @param isPrimary Whether the ACR is primary.
     * @return AccountContactRelation New ACR record.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private AccountContactRelation createACR(Id contactId, Id accountId, String role, Boolean isActive, Boolean isPrimary) {
        AccountContactRelation acr = new AccountContactRelation();
        acr.ContactId = contactId;
        acr.AccountId = accountId;
        if (String.isNotBlank(role)) {
            acr.Roles = role;
        }
        acr.IsActive = isActive != null ? isActive : false;
        acr.Is_Primary__c = isPrimary != null ? isPrimary : false;
        return acr;
    }

    /**
     * @description Updates ACR Roles field to include Patient - Practice Affiliation role.
     * @param acr AccountContactRelation record to update.
     */
    private void updateACRRoles(AccountContactRelation acr) {
        if (String.isBlank(acr.Roles)) {
            acr.Roles = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE;
        } else if (!acr.Roles.contains(ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE)) {
            acr.Roles = acr.Roles + ';' + ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE;
        }
    }

    /**
     * @description Gets Contact to Account ID mapping for person accounts.
     *              Uses OrgSync_SoqlUtility shared cache.
     * @param contactIds Set of contact IDs.
     * @return Map<Id, Id> Map of Contact ID to Account ID.
     */
    private Map<Id, Id> getContactToAccountMap(Set<Id> contactIds) {
        return OrgSync_SoqlUtility.getContactToAccountMapForPatientContacts(contactIds);
    }

    /**
     * @description Gets Account ID to External ID mapping.
     *              Uses OrgSync_SoqlUtility shared cache.
     * @param accountIds List of account IDs.
     * @return Map<Id, String> Map of Account ID to External ID.
     */
    private Map<Id, String> getAccountToExternalIdMap(List<Id> accountIds) {
        Map<Id, String> accountToExtId = new Map<Id, String>();
        if (accountIds == null || accountIds.isEmpty()) {
            return accountToExtId;
        }
        Map<Id, Account> accMap = OrgSync_SoqlUtility.getAccountsByIdsWithExtIdAndRecordType(new Set<Id>(accountIds));
        for (Id accId : accountIds) {
            Account acc = accMap.get(accId);
            if (acc != null && String.isNotBlank(acc.XCDC_ExternalId__c)) {
                accountToExtId.put(accId, acc.XCDC_ExternalId__c);
            }
        }
        return accountToExtId;
    }

    /**
     * @description Filters Account IDs to include only Practice record types.
     *              Uses OrgSync_SoqlUtility shared cache.
     * @param accountIds Set of Account IDs to filter.
     * @return Set<Id> Practice Account IDs.
     */
    private Set<Id> getPracticeAccountIds(Set<Id> accountIds) {
        Set<Id> practiceAccountIds = new Set<Id>();
        if (accountIds == null || accountIds.isEmpty()) {
            return practiceAccountIds;
        }
        Map<Id, Account> accMap = OrgSync_SoqlUtility.getAccountsByIdsWithExtIdAndRecordType(accountIds);
        for (Id accountId : accountIds) {
            Account acc = accMap.get(accountId);
            if (acc != null && acc.RecordTypeId == ConstantsUtil.ACCOUNT_PRACTICE_RT) {
                practiceAccountIds.add(accountId);
            }
        }
        return practiceAccountIds;
    }

    /**
     * @description Finds the latest active primary practice for each contact.
     * @param contactIds Set of Contact IDs.
     * @return Map<Id, Id> Map of Contact ID to Practice Account ID.
     */
    private Map<Id, Id> findLatestPractices(Set<Id> contactIds) {
        Map<Id, Id> latestMap = new Map<Id, Id>();
        String roleValue = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE;
        // Query ordered by LastModifiedDate ASC.
        // When iterating, we put into map. The last one processed (newest) overwrites previous ones.
        // This gives us the "most recent" record.
        for (AccountContactRelation acr : [SELECT ContactId, AccountId
                                            FROM AccountContactRelation
                                            WHERE ContactId IN :contactIds
                                            AND Is_Primary__c = true
                                            AND IsActive = true
                                            AND Roles INCLUDES (:roleValue)
                                            WITH SYSTEM_MODE
                                            ORDER BY LastModifiedDate ASC]) {
            latestMap.put(acr.ContactId, acr.AccountId);
        }
        return latestMap;
    }

    /**
     * @description Updates Practice field on Patient Staging records.
     *              Uses OrgSync_SoqlUtility cache - fetches from cache or queries only for missing external IDs.
     * @param extIdToPracticeId Map of External ID to Practice Account ID.
     */
    private void updateStagingPracticeFields(Map<String, Id> extIdToPracticeId) {
        if (extIdToPracticeId == null || extIdToPracticeId.isEmpty()) {
            return;
        }

        Map<String, OrgSync_Patient_Staging__c> stagingByExtId = OrgSync_SoqlUtility.getPatientStagingByExternalIds(extIdToPracticeId.keySet());
        List<OrgSync_Patient_Staging__c> stagingToUpdate = new List<OrgSync_Patient_Staging__c>();

        for (String extId : extIdToPracticeId.keySet()) {
            OrgSync_Patient_Staging__c staging = stagingByExtId.get(extId);
            if (staging == null) {
                continue;
            }
            Id newPracticeId = extIdToPracticeId.get(extId);
            if (staging.OrgSync_Practice__c != newPracticeId) {
                staging.OrgSync_Practice__c = newPracticeId;
                stagingToUpdate.add(staging);
            }
        }

        if (!stagingToUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(stagingToUpdate, false, AccessLevel.SYSTEM_MODE);
            OrgSync_LoggingUtility.handleDatabaseResults(results, stagingToUpdate, new Map<String, String>{
                'className' => 'OrgSync_Patient_ACRService',
                'methodName' => 'syncACRsToStaging',
                'operationDescription' => 'updating Patient Staging Practice field'
            });
        }
    }
}