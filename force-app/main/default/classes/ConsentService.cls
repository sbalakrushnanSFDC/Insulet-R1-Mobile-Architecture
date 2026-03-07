/**
 * @description Creates ContactPointTypeConsent records for Individual records
 *              Single Responsibility: Only handles ContactPointTypeConsent creation based on IndividualIds
 *              Assumes calling class handles Lead RecordType filtering
 * Created Date : 28-01-2026
 * Created By   : Tanu Tyagi
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       28th Jan 2026       Tanu Tyagi              Initial Version(NGASIM-1911)
 * V1.1.0       20th Feb 2026       Bijayalaxmi Prusty      Updated(NGASIM-2157)

 */
public inherited sharing class ConsentService {
    /**
     * @description Static Map to cache DataUsePurpose records by Name (Name -> DataUsePurpose)
     */
    private static Map<String, DataUsePurpose> dataUsePurposeByNameCache;

    /**
     * @description Static Set to track processed consent keys within the transaction
     *              Key format: PartyId + '|' + Name
     *              Prevents duplicate creation across multiple method calls in the same transaction
     */
    private static Set<String> processedConsentKeys = new Set<String>();

    /**
     * @description Static Set to track IndividualIds that have been queried
     *              Prevents repeated queries for the same IndividualIds in the same transaction
     */
    private static Set<Id> queriedIndividualIds = new Set<Id>();

    /**
     * @description Returns true if the Set is null or empty
     * @param ids Set to check
     * @return true if null or empty
     */
    private static Boolean isEmpty(Set<Id> ids) {
        return ids == null || ids.isEmpty();
    }

    /**
     * @description Returns true if the List is null or empty
     * @param records List to check
     * @return true if null or empty
     */
    private static Boolean isEmpty(List<SObject> records) {
        return records == null || records.isEmpty();
    }

    /**
     * @description Returns true if the List is null or empty
     * @param leads List to check
     * @return true if null or empty
     */
    private static Boolean isEmpty(List<Lead> leads) {
        return leads == null || leads.isEmpty();
    }

    /**
     * @description Creates consent records for Individual records
     *              Prevents duplicates by checking existing records and transaction cache
     *              Single DML operation with bulkification support
     * @param individualIds Set of Individual record IDs
     */
    public static void createConsentRecords(Set<Id> individualIds) {
        if (isEmpty(individualIds)) {
            return;
        }

        // Guard clause: Check CRUD permissions
        if (!Schema.SObjectType.ContactPointTypeConsent.isCreateable()) {
            logPermissionError();
            return;
        }

        loadDataUsePurposeCache();
        if (!isDataUsePurposeCacheComplete()) {
            logDataUsePurposeConfigurationError();
            return;
        }

        loadExistingConsentsIntoCache(individualIds);
        List<ContactPointTypeConsent> consentsToInsert = buildConsentRecords(individualIds);
        if (consentsToInsert.isEmpty()) {
            return;
        }

        processDmlResults(consentsToInsert);
        Logger.saveLog();
    }

    /**
     * @description Bulk-queries existing consent records and adds them to processedConsentKeys cache
     *              No SOQL queries inside loops - single bulk query
     * @param individualIds Set of Individual record IDs to query
     * @TestVisible to allow test coverage of guard clause at line 87
     */
    @TestVisible
    private static void loadExistingConsentsIntoCache(Set<Id> individualIds) {
        if (isEmpty(individualIds)) {
            return;
        }
        Set<Id> idsToQuery = new Set<Id>(individualIds);
        idsToQuery.removeAll(queriedIndividualIds);
        if (idsToQuery.isEmpty()) {
            return;
        }

        List<ContactPointTypeConsent> existingConsents = [
            SELECT Id, PartyId, Name
            FROM ContactPointTypeConsent
            WHERE PartyId IN :idsToQuery
            AND Name IN :ConstantsUtil.CONSENT_NAMES
            WITH USER_MODE
        ];

        for (ContactPointTypeConsent consent : existingConsents) {
            String key = buildConsentKey(consent.PartyId, consent.Name);
            processedConsentKeys.add(key);
        }

        queriedIndividualIds.addAll(idsToQuery);
    }

    /**
     * @description Builds consent records for Individual IDs, skipping existing ones
     *              Uses processedConsentKeys to prevent duplicates
     *              No DML operations in loops
     * @param individualIds Set of Individual record IDs
     * @return List of ContactPointTypeConsent records ready for insert
     */
    private static List<ContactPointTypeConsent> buildConsentRecords(Set<Id> individualIds) {
        List<ContactPointTypeConsent> consentsToInsert = new List<ContactPointTypeConsent>();

        for (Id individualId : individualIds) {
            for (String consentName : ConstantsUtil.CONSENT_NAMES) {
                String key = buildConsentKey(individualId, consentName);
                if (!processedConsentKeys.contains(key)) {
                    consentsToInsert.add(buildConsentByType(individualId, consentName));
                    processedConsentKeys.add(key);
                }
            }
        }

        return consentsToInsert;
    }

    /**
     * @description Builds consent record by type name using status map
     * @param individualId Individual record ID
     * @param consentName Consent name (Transactional Email, SMS, or Marketing Email)
     * @return ContactPointTypeConsent record
     */
    private static ContactPointTypeConsent buildConsentByType(Id individualId, String consentName) {
        DataUsePurpose dup = dataUsePurposeByNameCache.get(consentName);
        if (dup == null) {
            return null;
        }
        String status = getConsentStatusByName().get(consentName);
        ContactPointTypeConsent consent = new ContactPointTypeConsent();
        consent.Name = dup.Name;
        consent.DataUsePurposeId = dup.Id;
        consent.PrivacyConsentStatus = status;
        consent.PartyId = individualId;
        consent.CaptureDate = DateTime.now();
        return consent;
    }

    /**
     * @description Returns map of consent name to PrivacyConsentStatus
     * @return Map of consent name (key) to PrivacyConsentStatus value (Transactional Email: Opt-In, SMS: Opt-In Pending, Marketing Email: Not Seen)
     */
    private static Map<String, String> getConsentStatusByName() {
        return new Map<String, String>{
            ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL => ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS => ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING,
            ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL => ConstantsUtil.PRIVACY_CONSENT_STATUS_NOT_SEEN
        };
    }

    /**
     * @description Processes DML results and handles errors
     *              Updates processedConsentKeys cache with successfully inserted records
     *              No DML operations - only processes results
     * @param consentsToInsert List of ContactPointTypeConsent records that were inserted
     * @TestVisible to allow test coverage of exception handling at lines 215-217
     */
    @TestVisible
    private static void processDmlResults(List<ContactPointTypeConsent> consentsToInsert) {
        try {
            Database.SaveResult[] saveResults = Database.insert(consentsToInsert, false, AccessLevel.USER_MODE);
            for (Integer i = 0; i < saveResults.size(); i++) {
                if (saveResults[i].isSuccess()) {
                    continue;
                }
                logError(buildDmlErrorMessage(consentsToInsert[i], saveResults[i].getErrors()),
                    new List<SObject>{consentsToInsert[i]}, new System.DmlException('Insert failed'));
            }
        } catch (Exception ex) {
            logError(ex.getMessage(), consentsToInsert, ex);
        }
    }

    /**
     * @description Builds error message from DML failure
     * @param consent The record that failed
     * @param errors List of Database.Error
     * @return Formatted error message
     */
    private static String buildDmlErrorMessage(ContactPointTypeConsent consent, List<Database.Error> errors) {
        String msg = 'Failed to insert ContactPointTypeConsent record (Name: ' + consent.Name + ', PartyId: ' + consent.PartyId + ')';
        for (Database.Error err : errors) {
            msg += ' ' + err.getMessage() + ' (' + err.getStatusCode() + ') Fields: ' + err.getFields();
        }
        return msg;
    }

    /**
     * @description Logs Custom Labels configuration error
     * @TestVisible for test coverage
     */
    @TestVisible
    private static void logCustomLabelsConfigurationError() {
        logError(null, new List<SObject>(), new System.IllegalArgumentException('Consent Name labels are not configured'));
    }

    /**
     * @description Logs DataUsePurpose configuration error
     * @TestVisible for test coverage
     */
    @TestVisible
    private static void logDataUsePurposeConfigurationError() {
        logError(null, new List<SObject>(), new System.IllegalArgumentException('DataUsePurpose records not found for required consent names'));
    }

    /**
     * @description Logs permission error
     * @TestVisible for test coverage
     */
    @TestVisible
    private static void logPermissionError() {
        logError('User does not have permission to create ContactPointTypeConsent records', new List<SObject>(), null);
    }

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message (or null to use exception message)
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null for permission/config errors)
     */
    private static void logError(String message, List<SObject> records, Exception ex) {
        String logMessage = String.isNotBlank(message) ? message : (ex != null ? ex.getMessage() : '');
        Logger.error(logMessage, records, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    /**
     * @description Queries DataUsePurpose records by name and caches them for the transaction
     */
    private static void loadDataUsePurposeCache() {
        if (dataUsePurposeByNameCache != null) {
            return;
        }
        List<DataUsePurpose> dataUsePurposes = [
            SELECT Id, Name
            FROM DataUsePurpose
            WHERE Name IN :ConstantsUtil.CONSENT_NAMES
            WITH USER_MODE
        ];
        dataUsePurposeByNameCache = new Map<String, DataUsePurpose>();
        for (DataUsePurpose dup : dataUsePurposes) {
            dataUsePurposeByNameCache.put(dup.Name, dup);
        }
    }

    /**
     * @description Checks if all required DataUsePurpose records are in cache
     * @return true if cache contains all required consent names, false otherwise
     */
    private static Boolean isDataUsePurposeCacheComplete() {
        return dataUsePurposeByNameCache != null
            && dataUsePurposeByNameCache.keySet().containsAll(ConstantsUtil.CONSENT_NAMES);
    }

    /**
     * @description Builds a unique key for consent records (PartyId + '|' + Name)
     * @param partyId The PartyId (Individual ID)
     * @param name The consent Name
     * @return Unique key string
     */
    private static String buildConsentKey(Id partyId, String name) {
        return String.valueOf(partyId) + '|' + name;
    }

    /**
     * @description Updates CaptureDate to current datetime when PrivacyConsentStatus is changed on ContactPointTypeConsent records.
     *              Called from ContactPointTypeConsentTriggerHandler beforeUpdate.
     * @param updatedRecordsMap Map of updated records by Id
     * @param oldRecordsMap Map of old record values by Id
     */
    public static void updateCaptureDateOnConsentStatusChange(
        Map<Id, SObject> updatedRecordsMap,
        Map<Id, SObject> oldRecordsMap
    ) {
        if (updatedRecordsMap == null || oldRecordsMap == null) {
            return;
        }
        for (Id recordId : updatedRecordsMap.keySet()) {
            ContactPointTypeConsent newRecord = (ContactPointTypeConsent) updatedRecordsMap.get(recordId);
            ContactPointTypeConsent oldRecord = (ContactPointTypeConsent) oldRecordsMap.get(recordId);
            if (hasConsentStatusChanged(newRecord, oldRecord)) {
                newRecord.CaptureDate = DateTime.now();
            }
        }
    }
    /**
     * @description Updates CaptureDate to current datetime when ContactPointTypeConsent records are created.
     *              Called from ContactPointTypeConsentTriggerHandler beforeInsert.
     * @param newRecords List of new records
     */
    public static void updateCaptureDateOnConsentStatusChange(List<SObject> newRecords) {
        if (isEmpty(newRecords)) {
            return;
        }
        for (SObject newRecord : newRecords) {
            if (newRecord instanceof ContactPointTypeConsent) {
                ContactPointTypeConsent consent = (ContactPointTypeConsent) newRecord;
                if (consent.PrivacyConsentStatus != null) {
                    consent.CaptureDate = DateTime.now();
                }
            }
        }
    }

    /**
     * @description Checks if PrivacyConsentStatus changed between old and new record
     * @param newRecord Updated record
     * @param oldRecord Previous record
     * @return true if status changed
     */
    private static Boolean hasConsentStatusChanged(ContactPointTypeConsent newRecord, ContactPointTypeConsent oldRecord) {
        return oldRecord != null && newRecord.PrivacyConsentStatus != oldRecord.PrivacyConsentStatus;
    }

    /**
     * @description Creates consent records for Leads with Patient or Provider_Practice_Lead record types
     *              Accepts List<SObject> and extracts Leads internally
     *              Filters by RecordType and calls createConsentRecords with IndividualIds
     * @param records List of SObject records (typically from trigger context)
     */
    public static void createConsentRecordsForLeads(List<SObject> records) {
        if (isEmpty(records)) {
            return;
        }
        List<Lead> leads = extractLeadsWithIndividualId(records);
        if (leads.isEmpty()) {
            return;
        }
        createConsentRecordsForLeads(leads);
    }

    /**
     * @description Extracts Lead records with IndividualId from SObject list
     * @param records List of SObject (typically from trigger context)
     * @return List of Lead records with non-null IndividualId
     */
    private static List<Lead> extractLeadsWithIndividualId(List<SObject> records) {
        List<Lead> leads = new List<Lead>();
        for (SObject record : records) {
            if (record instanceof Lead) {
                Lead leadRecord = (Lead) record;
                if (leadRecord.IndividualId != null) {
                    leads.add(leadRecord);
                }
            }
        }
        return leads;
    }

    /**
     * @description Creates consent records for Leads with Patient or Provider_Practice_Lead record types
     *              Filters Leads by RecordType and extracts IndividualIds
     *              Uses RecordTypeId comparison when available (no query needed)
     *              Queries RecordType only when necessary (with caching)
     * @param leads List of Lead records to process
     */
    public static void createConsentRecordsForLeads(List<Lead> leads) {
        if (isEmpty(leads)) {
            return;
        }

        LeadProcessingResult result = processLeadsForConsent(leads);

        // Query RecordType only for Leads that don't have it populated (with caching)
        if (!result.leadIdsToQuery.isEmpty()) {
            addEligibleIndividualIdsFromQuery(result);
        }

        // Create consent records for eligible IndividualIds
        if (!result.individualIds.isEmpty()) {
            createConsentRecords(result.individualIds);
        }
    }

    /**
     * @description Result container for Lead processing
     */
    private class LeadProcessingResult {
        Set<Id> individualIds = new Set<Id>();
        Set<Id> leadIdsToQuery = new Set<Id>();
        Map<Id, Id> leadIdToIndividualIdMap = new Map<Id, Id>();
    }

    /**
     * @description Processes Leads and extracts IndividualIds based on RecordType
     *              Reduces complexity by extracting logic from main method
     * @param leads List of Lead records to process
     * @return LeadProcessingResult with IndividualIds and LeadIds to query
     */
    private static LeadProcessingResult processLeadsForConsent(List<Lead> leads) {
        LeadProcessingResult result = new LeadProcessingResult();
        for (Lead lead : leads) {
            if (lead.IndividualId == null) {
                continue;
            }
            result.leadIdToIndividualIdMap.put(lead.Id, lead.IndividualId);
            addLeadToResult(lead, result);
        }
        return result;
    }

    /**
     * @description Adds Lead's IndividualId to result based on RecordType eligibility
     * @param lead Lead to process
     * @param result Result to update
     */
    private static void addLeadToResult(Lead lead, LeadProcessingResult result) {
        if (hasEligibleRecordType(lead)) {
            result.individualIds.add(lead.IndividualId);
        } else if (needsRecordTypeQuery(lead)) {
            result.leadIdsToQuery.add(lead.Id);
        }
    }

    /**
     * @description Eligible Lead RecordType IDs and DeveloperNames for consent creation
     */
    private static final Set<Id> ELIGIBLE_LEAD_RECORD_TYPE_IDS = new Set<Id>{
        ConstantsUtil.LEAD_PATIENT_RT,
        ConstantsUtil.LEAD_PROVIDERPRACTICE_RT
    };
    private static final Set<String> ELIGIBLE_LEAD_RECORD_TYPE_NAMES = new Set<String>{
        'Patient',
        'Provider_Practice_Lead'
    };

    /**
     * @description Checks if Lead has eligible RecordType (Patient or Provider_Practice_Lead)
     * @param lead Lead record to check
     * @return true if Lead has eligible RecordType, false otherwise
     */
    private static Boolean hasEligibleRecordType(Lead lead) {
        Boolean hasEligibleId = lead.RecordTypeId != null && ELIGIBLE_LEAD_RECORD_TYPE_IDS.contains(lead.RecordTypeId);
        Boolean hasEligibleName = String.isNotBlank(lead.RecordType?.DeveloperName)
            && ELIGIBLE_LEAD_RECORD_TYPE_NAMES.contains(lead.RecordType.DeveloperName);
        return hasEligibleId || hasEligibleName;
    }

    /**
     * @description Checks if RecordType DeveloperName matches Patient or Provider_Practice_Lead
     * @param developerName RecordType DeveloperName to check (can be null/blank)
     * @return true if DeveloperName matches eligible types
     */
    private static Boolean isEligibleRecordTypeName(String developerName) {
        return String.isNotBlank(developerName) && ELIGIBLE_LEAD_RECORD_TYPE_NAMES.contains(developerName);
    }

    /**
     * @description Checks if Lead needs RecordType query (no RecordTypeId or DeveloperName)
     * @param lead Lead record to check
     * @return true if RecordType needs to be queried
     */
    private static Boolean needsRecordTypeQuery(Lead lead) {
        return lead.RecordTypeId == null && String.isBlank(lead.RecordType?.DeveloperName);
    }

    /**
     * @description Processes queried RecordTypes and adds eligible IndividualIds
     *              Reduces complexity by extracting logic from main method
     * @param result LeadProcessingResult containing LeadIds to query and IndividualId map
     */
    private static void addEligibleIndividualIdsFromQuery(LeadProcessingResult result) {
        Map<Id, String> queriedRecordTypes = queryLeadRecordTypes(result.leadIdsToQuery);
        for (Id leadId : result.leadIdsToQuery) {
            if (isEligibleRecordTypeName(queriedRecordTypes.get(leadId))) {
                result.individualIds.add(result.leadIdToIndividualIdMap.get(leadId));
            }
        }
    }

    /**
     * @description Queries Lead records with RecordType DeveloperName
     *              Uses static cache to avoid repeated queries for the same LeadIds in the same transaction
     *              Single bulk SOQL query - no queries in loops
     * @param leadIds Set of Lead IDs to query
     * @return Map of Lead ID to RecordType DeveloperName
     * @TestVisible to allow test coverage of guard clause and exception handling
     */
    @TestVisible
    private static Map<Id, String> queryLeadRecordTypes(Set<Id> leadIds) {
        Map<Id, String> leadIdToRecordTypeMap = new Map<Id, String>();
        if (isEmpty(leadIds)) {
            return leadIdToRecordTypeMap;
        }
        if (leadRecordTypeCache == null) {
            leadRecordTypeCache = new Map<Id, String>();
        }
        Set<Id> idsToQuery = getIdsFromCache(leadIds, leadIdToRecordTypeMap);
        if (idsToQuery.isEmpty()) {
            return leadIdToRecordTypeMap;
        }

        try {
            List<Lead> leads = [
                SELECT Id, RecordType.DeveloperName
                FROM Lead
                WHERE Id IN :idsToQuery
                WITH USER_MODE
            ];

            // Extract result processing to reduce complexity
            populateCacheFromResult(leads, idsToQuery, leadIdToRecordTypeMap);

        } catch (Exception ex) {
            logError(ex.getMessage(), new List<SObject>(), ex);
        }

        return leadIdToRecordTypeMap;
    }

    /**
     * @description Extracts cache check logic to reduce cyclomatic complexity
     *              Checks cache for LeadIds and populates result map with cached values
     * @param leadIds Set of Lead IDs to check
     * @param leadIdToRecordTypeMap Map to populate with cached values
     * @return Set of Lead IDs that need to be queried (not in cache)
     */
    private static Set<Id> getIdsFromCache(Set<Id> leadIds, Map<Id, String> leadIdToRecordTypeMap) {
        Set<Id> idsToQuery = new Set<Id>();

        for (Id leadId : leadIds) {
            if (leadRecordTypeCache.containsKey(leadId)) {
                leadIdToRecordTypeMap.put(leadId, leadRecordTypeCache.get(leadId));
            } else {
                idsToQuery.add(leadId);
            }
        }

        return idsToQuery;
    }

    /**
     * @description Extracts result processing logic to reduce cyclomatic complexity
     *              Processes query results and updates cache
     * @param leads List of Lead records from query
     * @param idsToQuery Set of Lead IDs that were queried
     * @param leadIdToRecordTypeMap Map to populate with query results
     */
    private static void populateCacheFromResult(List<Lead> leads, Set<Id> idsToQuery, Map<Id, String> leadIdToRecordTypeMap) {
        for (Lead lead : leads) {
            String devName = lead.RecordType?.DeveloperName;
            leadIdToRecordTypeMap.put(lead.Id, devName);
            leadRecordTypeCache.put(lead.Id, devName);
        }
        for (Id leadId : idsToQuery) {
            leadRecordTypeCache.put(leadId, leadIdToRecordTypeMap.get(leadId));
        }
    }

    /**
     * @description Static map to cache Lead RecordType DeveloperNames by LeadId
     *              Key: LeadId
     *              Value: RecordType DeveloperName
     *              This prevents repeated queries for the same LeadIds in the same transaction
     */
    private static Map<Id, String> leadRecordTypeCache;
}