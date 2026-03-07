/**
 * @description Queueable class to map ContactPointTypeConsent records from Lead.Individual
 *              to Patient.Individual after lead conversion.
 *              Handles Transactional Email, Transactional SMS, and Marketing Email consent records
 *              with specific business rules for creation and updates.
 *
 * @author      Bijayalaxmi Prusty
 * @createdDate 27th Jan 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       27th Jan 2026       Bijayalaxmi Prusty      Initial Version
 * V1.0.1       11th Feb 2026       Bijayalaxmi Prusty      Updated(US - NGASIM-2341/ NGASIM-1905)
 * V1.0.2       20th Feb 2026       Bijayalaxmi Prusty      Updated(US - NGASIM-2157)
 *
 */
public with sharing class LeadConversionConsentMappingQueueable implements Queueable {

    /**
     * @description Wrapper class to hold Account and Lead data for consent mapping
     */
    public class LeadConversionConsentData {
        public Id accountId;
        public Id leadId;
        public Id contactId; // Contact ID from lead conversion result
        public Id patientIndividualId;
        public Id leadIndividualId;
        public Set<Id> newlyUpsertedPhoneIds; // ContactPointPhone IDs created during conversion
    }

    /**
     * @description Wrapper class to hold consent processing context during mapping operations
     */
    @TestVisible
    private class ConsentProcessingContext {
        public List<ContactPointTypeConsent> leadConsents;
        public List<ContactPointTypeConsent> patientConsents;
        public List<ContactPointPhone> patientPhones;
        public Lead leadRecord;
        public Id patientIndividualId;
        public Id patientDelegateAccountId;
        public List<ContactPointTypeConsent> consentsToInsert;
        public List<ContactPointTypeConsent> consentsToUpdate;
        public Set<Id> newlyUpsertedPhoneIds; // ContactPointPhone IDs created during conversion
    }

    /**
     * @description Wrapper class to hold consent creation parameters
     */
    private class ConsentCreationContext {
        public ContactPointTypeConsent leadConsent;
        public Id patientIndividualId;
        public String consentName;
        public Id patientDelegateAccountId;
    }

    /**
     * @description Wrapper class to hold query data collection context
     */
    private class QueryDataContext {
        public Set<Id> leadIndividualIds;
        public Set<Id> patientIndividualIds;
        public Set<Id> accountIds;
        public Map<Id, LeadConversionConsentData> accountToDataMap;
    }

    /**
     * @description Wrapper class to hold query results context
     */
    private class QueryResultsContext {
        public Map<Id, List<ContactPointTypeConsent>> leadConsentMap;
        public Map<Id, List<ContactPointTypeConsent>> patientConsentMap;
        public Map<Id, List<ContactPointPhone>> patientPhoneMap;
        public Map<Id, Lead> leadMap;
        public Map<Id, Id> patientAccountToDelegateAccountMap;
    }

    /**
     * @description Wrapper class to hold context for building processing context
     */
    private class ProcessingContextBuildContext {
        public LeadConversionConsentData data;
        public QueryDataContext queryContext;
        public QueryResultsContext resultsContext;
        public List<ContactPointTypeConsent> consentsToInsert;
        public List<ContactPointTypeConsent> consentsToUpdate;
    }

    /**
     * @description Wrapper class to hold consent mapping processing context
     */
    private class ConsentMappingContext {
        public QueryDataContext queryContext;
        public QueryResultsContext resultsContext;
        public List<ContactPointTypeConsent> consentsToInsert;
        public List<ContactPointTypeConsent> consentsToUpdate;
    }

    /**
     * @description Wrapper class to hold consent update parameters
     */
    private class ConsentUpdateContext {
        public ContactPointTypeConsent patientConsent;
        public ContactPointTypeConsent leadConsent;
        public Boolean isSMS;
    }

    private List<LeadConversionConsentData> mappingDataList;

    /**
     * @description Constructor
     * @param dataList List of LeadConversionConsentData containing Account and Lead information
     */
    public LeadConversionConsentMappingQueueable(List<LeadConversionConsentData> dataList) {
        this.mappingDataList = dataList != null ? dataList : new List<LeadConversionConsentData>();
    }

    /**
     * @description Execute method called by the Queueable framework
     * @param context QueueableContext
     */
    public void execute(QueueableContext context) {
        // Attach Finalizer to handle cleanup and error scenarios
        if (!Test.isRunningTest()) {
            System.attachFinalizer(new ConsentMappingFinalizer(mappingDataList));
        }

        if (mappingDataList.isEmpty()) {
            return;
        }

        try {
            processConsentMapping();
        } catch (Exception ex) {
            logError('Error processing ContactPointTypeConsent mapping: ' + ex.getMessage(), null, ex);
        }
    }

    /**
     * @description Main processing method that handles consent mapping for all records
     */
    private void processConsentMapping() {
        QueryDataContext queryContext = collectQueryData();

        if (queryContext.leadIndividualIds.isEmpty() && queryContext.patientIndividualIds.isEmpty()) {
            return;
        }

        QueryResultsContext resultsContext = queryAllRequiredData(queryContext);

        List<ContactPointTypeConsent> consentsToInsert = new List<ContactPointTypeConsent>();
        List<ContactPointTypeConsent> consentsToUpdate = new List<ContactPointTypeConsent>();

        ConsentMappingContext mappingContext = new ConsentMappingContext();
        mappingContext.queryContext = queryContext;
        mappingContext.resultsContext = resultsContext;
        mappingContext.consentsToInsert = consentsToInsert;
        mappingContext.consentsToUpdate = consentsToUpdate;

        processAllConsentMappings(mappingContext);

        performDMLOperations(consentsToInsert, consentsToUpdate);
    }

    /**
     * @description Collects all Individual IDs and Account IDs for querying
     * @return QueryDataContext with collected IDs
     */
    private QueryDataContext collectQueryData() {
        QueryDataContext context = new QueryDataContext();
        context.leadIndividualIds = new Set<Id>();
        context.patientIndividualIds = new Set<Id>();
        context.accountIds = new Set<Id>();
        context.accountToDataMap = new Map<Id, LeadConversionConsentData>();

        for (LeadConversionConsentData data : mappingDataList) {
            if (data.accountId != null) {
                context.accountIds.add(data.accountId);
                context.accountToDataMap.put(data.accountId, data);
            }
            if (data.leadIndividualId != null) {
                context.leadIndividualIds.add(data.leadIndividualId);
            }
            if (data.patientIndividualId != null) {
                context.patientIndividualIds.add(data.patientIndividualId);
            }
        }

        return context;
    }

    /**
     * @description Queries all required data for consent mapping
     * @param queryContext QueryDataContext with IDs to query
     * @return QueryResultsContext with all query results
     */
    private QueryResultsContext queryAllRequiredData(QueryDataContext queryContext) {
        QueryResultsContext results = new QueryResultsContext();
        results.leadConsentMap = LeadConversionConsentMappingHelper.queryLeadConsents(queryContext.leadIndividualIds);
        results.patientConsentMap = LeadConversionConsentMappingHelper.queryPatientConsents(queryContext.patientIndividualIds);
        results.patientPhoneMap = LeadConversionConsentMappingHelper.queryPatientPhones(queryContext.accountIds);

        Set<Id> leadIds = new Set<Id>();
        for (LeadConversionConsentData data : queryContext.accountToDataMap.values()) {
            if (data.leadId != null) {
                leadIds.add(data.leadId);
            }
        }
        results.leadMap = LeadConversionConsentMappingHelper.queryLeads(leadIds);
        results.patientAccountToDelegateAccountMap = LeadConversionConsentMappingHelper.queryPatientDelegateAccounts(queryContext.accountIds);
        return results;
    }

    /**
     * @description Processes all consent mappings for each data record
     * @param mappingContext ConsentMappingContext containing all necessary data
     */
    private void processAllConsentMappings(ConsentMappingContext mappingContext) {
        for (LeadConversionConsentData data : mappingDataList) {
            if (!isValidData(data)) {
                continue;
            }

            if (!hasLeadConsents(mappingContext, data)) {
                continue;
            }

            processConsentMappingForData(data, mappingContext);
        }
    }

    /**
     * @description Checks if Lead consents exist for the data record
     * @param mappingContext ConsentMappingContext
     * @param data LeadConversionConsentData
     * @return True if Lead consents exist, false otherwise
     */
    private Boolean hasLeadConsents(ConsentMappingContext mappingContext, LeadConversionConsentData data) {
        List<ContactPointTypeConsent> leadConsents = mappingContext.resultsContext.leadConsentMap.get(data.leadIndividualId);
        return leadConsents != null && !leadConsents.isEmpty();
    }

    /**
     * @description Processes consent mapping for a single data record
     * @param data LeadConversionConsentData
     * @param mappingContext ConsentMappingContext
     */
    private void processConsentMappingForData(LeadConversionConsentData data, ConsentMappingContext mappingContext) {
        ProcessingContextBuildContext buildContext = buildProcessingContextBuildContext(data, mappingContext);
        ConsentProcessingContext context = buildProcessingContext(buildContext);
        processTransactionalEmail(context);
        processTransactionalSMS(context);
        processMarketingEmail(context);
    }

    /**
     * @description Builds ProcessingContextBuildContext from data and mapping context
     * @param data LeadConversionConsentData
     * @param mappingContext ConsentMappingContext
     * @return ProcessingContextBuildContext
     */
    private ProcessingContextBuildContext buildProcessingContextBuildContext(LeadConversionConsentData data, ConsentMappingContext mappingContext) {
        ProcessingContextBuildContext buildContext = new ProcessingContextBuildContext();
        buildContext.data = data;
        buildContext.queryContext = mappingContext.queryContext;
        buildContext.resultsContext = mappingContext.resultsContext;
        buildContext.consentsToInsert = mappingContext.consentsToInsert;
        buildContext.consentsToUpdate = mappingContext.consentsToUpdate;
        return buildContext;
    }

    /**
     * @description Validates data record has required IndividualIds
     * @param data LeadConversionConsentData to validate
     * @return True if valid, false otherwise
     */
    private Boolean isValidData(LeadConversionConsentData data) {
        return data.patientIndividualId != null && data.leadIndividualId != null;
    }

    /**
     * @description Builds ConsentProcessingContext from build context wrapper
     * @param buildContext ProcessingContextBuildContext containing all necessary data
     * @return ConsentProcessingContext
     */
    private ConsentProcessingContext buildProcessingContext(ProcessingContextBuildContext buildContext) {
        ConsentProcessingContext context = new ConsentProcessingContext();
        context.leadConsents = buildContext.resultsContext.leadConsentMap.get(buildContext.data.leadIndividualId);
        context.patientConsents = buildContext.resultsContext.patientConsentMap.get(buildContext.data.patientIndividualId);
        context.patientPhones = buildContext.resultsContext.patientPhoneMap.get(buildContext.data.accountId);
        context.leadRecord = buildContext.resultsContext.leadMap.get(buildContext.data.leadId);
        context.patientIndividualId = buildContext.data.patientIndividualId;
        context.patientDelegateAccountId = buildContext.resultsContext.patientAccountToDelegateAccountMap.get(buildContext.data.accountId);
        context.consentsToInsert = buildContext.consentsToInsert;
        context.consentsToUpdate = buildContext.consentsToUpdate;
        context.newlyUpsertedPhoneIds = buildContext.data.newlyUpsertedPhoneIds != null ?
            buildContext.data.newlyUpsertedPhoneIds : new Set<Id>();
        return context;
    }

    /**
     * @description Processes Transactional Email consent mapping
     * @param context ConsentProcessingContext containing all necessary data
     */
    private void processTransactionalEmail(ConsentProcessingContext context) {
        processConsentMapping(context, ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL, false);
    }

    /**
     * @description Processes Transactional SMS consent mapping
     * @param context ConsentProcessingContext containing all necessary data
     */
    private void processTransactionalSMS(ConsentProcessingContext context) {
        processConsentMapping(context, ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS, true);
    }

    /**
     * @description Processes Marketing Email consent mapping.
     * @param context ConsentProcessingContext containing all necessary data
     */
    private void processMarketingEmail(ConsentProcessingContext context) {
        processConsentMapping(context, ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL, false);
    }

    /**
     * @description Processes consent mapping for Email or SMS
     * @param context ConsentProcessingContext
     * @param consentName Consent name (Email or SMS)
     * @param isSMS Whether this is SMS consent (for special handling)
     */
    private void processConsentMapping(ConsentProcessingContext context, String consentName, Boolean isSMS) {
        ContactPointTypeConsent leadConsent = LeadConversionConsentMappingHelper.findConsentByName(context.leadConsents, consentName);
        if (leadConsent == null) {
            return;
        }

        ContactPointTypeConsent patientConsent = LeadConversionConsentMappingHelper.findConsentByName(context.patientConsents, consentName);
        if (patientConsent == null) {
            createNewConsent(context, leadConsent, consentName);
        } else {
            ConsentUpdateContext updateContext = buildConsentUpdateContext(patientConsent, leadConsent, isSMS);
            updateExistingConsent(context, updateContext);
        }
    }

    /**
     * @description Creates a new consent record
     * @param context ConsentProcessingContext
     * @param leadConsent Lead consent
     * @param consentName Consent name
     */
    private void createNewConsent(ConsentProcessingContext context, ContactPointTypeConsent leadConsent, String consentName) {
        ConsentCreationContext creationContext = buildConsentCreationContext(context, leadConsent, consentName);
        ContactPointTypeConsent newConsent = createConsentFromLead(creationContext);
        context.consentsToInsert.add(newConsent);
    }

    /**
     * @description Builds ConsentCreationContext from context
     * @param context ConsentProcessingContext
     * @param leadConsent Lead consent
     * @param consentName Consent name
     * @return ConsentCreationContext
     */
    private ConsentCreationContext buildConsentCreationContext(ConsentProcessingContext context, ContactPointTypeConsent leadConsent, String consentName) {
        ConsentCreationContext creationContext = new ConsentCreationContext();
        creationContext.leadConsent = leadConsent;
        creationContext.patientIndividualId = context.patientIndividualId;
        creationContext.consentName = consentName;
        creationContext.patientDelegateAccountId = context.patientDelegateAccountId;
        return creationContext;
    }

    /**
     * @description Builds ConsentUpdateContext from parameters
     * @param patientConsent Patient consent
     * @param leadConsent Lead consent
     * @param isSMS Whether this is SMS consent
     * @return ConsentUpdateContext
     */
    private ConsentUpdateContext buildConsentUpdateContext(ContactPointTypeConsent patientConsent, ContactPointTypeConsent leadConsent, Boolean isSMS) {
        ConsentUpdateContext updateContext = new ConsentUpdateContext();
        updateContext.patientConsent = patientConsent;
        updateContext.leadConsent = leadConsent;
        updateContext.isSMS = isSMS;
        return updateContext;
    }

    /**
     * @description Updates existing consent record
     * @param context ConsentProcessingContext
     * @param updateContext ConsentUpdateContext containing update parameters
     */
    private void updateExistingConsent(ConsentProcessingContext context, ConsentUpdateContext updateContext) {
        if (shouldSkipUpdate(context, updateContext)) {
            updateLegalGuardianOnly(context, updateContext.patientConsent);
            return;
        }

        updateConsentIfNeeded(context, updateContext);
    }

    /**
     * @description Checks if consent update should be skipped
     * @param context ConsentProcessingContext
     * @param updateContext ConsentUpdateContext
     * @return True if update should be skipped
     */
    private Boolean shouldSkipUpdate(ConsentProcessingContext context, ConsentUpdateContext updateContext) {
        if (updateContext.isSMS && shouldSkipSMSUpdate(context, updateContext.patientConsent)) {
            return true;
        }
        if (updateContext.patientConsent.Name == ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL
            && updateContext.leadConsent.PrivacyConsentStatus == ConstantsUtil.PRIVACY_CONSENT_STATUS_NOT_SEEN) {
            return true;
        }
        return false;
    }

    /**
     * @description Checks if SMS consent update should be skipped due to Opt In status
     * All conditions must be met (AND): Patient SMS consent exists, Lead phone in EXISTING Patient phones, Status = Opt In
     * Excludes newly upserted phones to ensure new phones trigger SMS consent override
     * @param context ConsentProcessingContext
     * @param patientSMSConsent Patient SMS consent
     * @return True if update should be skipped
     */
    private Boolean shouldSkipSMSUpdate(ConsentProcessingContext context, ContactPointTypeConsent patientSMSConsent) {
        List<ContactPointPhone> existingPhones = filterExistingPhones(context.patientPhones, context.newlyUpsertedPhoneIds);
        return LeadConversionConsentMappingHelper.shouldSkipSMSUpdate(existingPhones, context.leadRecord, patientSMSConsent);
    }

    /**
     * @description Filters out newly upserted ContactPointPhone records
     * @param patientPhones All Patient ContactPointPhone records
     * @param newlyUpsertedPhoneIds Set of newly upserted ContactPointPhone IDs
     * @return List of existing phones (excluding newly upserted)
     */
    @TestVisible
    private List<ContactPointPhone> filterExistingPhones(List<ContactPointPhone> patientPhones, Set<Id> newlyUpsertedPhoneIds) {
        if (patientPhones == null || patientPhones.isEmpty()) {
            return new List<ContactPointPhone>();
        }

        // If no newly upserted phones tracked, return all phones
        if (newlyUpsertedPhoneIds == null || newlyUpsertedPhoneIds.isEmpty()) {
            return patientPhones;
        }

        // Filter out phones that were just upserted
        List<ContactPointPhone> existingPhones = new List<ContactPointPhone>();
        for (ContactPointPhone phone : patientPhones) {
            if (!newlyUpsertedPhoneIds.contains(phone.Id)) {
                existingPhones.add(phone);
            }
        }

        return existingPhones;
    }

    /**
     * @description Updates only Legal_Guardian for SMS consent when Opt In prevents other updates
     * @param context ConsentProcessingContext
     * @param patientSMSConsent Patient SMS consent
     */
    @TestVisible
    private void updateLegalGuardianOnly(ConsentProcessingContext context, ContactPointTypeConsent patientSMSConsent) {
        if (LeadConversionConsentMappingHelper.updateLegalGuardianIfNeeded(context.patientDelegateAccountId, patientSMSConsent)) {
            context.consentsToUpdate.add(patientSMSConsent);
        }
    }

    /**
     * @description Updates consent if needed and adds to update list
     * For SMS consent, NO CaptureDate check - always override if Lead has phone (unless skipped by shouldSkipUpdate)
     * For Email consent, check CaptureDate before updating
     * @param context ConsentProcessingContext
     * @param updateContext ConsentUpdateContext
     */
    private void updateConsentIfNeeded(ConsentProcessingContext context, ConsentUpdateContext updateContext) {
        Boolean needsUpdate;

        // For SMS consent, check if Lead has a phone number before updating (no CaptureDate check needed)
        if (updateContext.isSMS) {
            needsUpdate = LeadConversionConsentMappingHelper.hasLeadPhone(context.leadRecord);
            if (needsUpdate) {
                LeadConversionConsentMappingHelper.updateConsentFields(updateContext.patientConsent, updateContext.leadConsent);
            }
        } else {
            // For Email consent, check if Lead consent is newer before updating
            needsUpdate = LeadConversionConsentMappingHelper.updateConsentFieldsIfNeeded(
                updateContext.patientConsent, updateContext.leadConsent);
        }

        Boolean legalGuardianUpdated = LeadConversionConsentMappingHelper.updateLegalGuardianIfNeeded(
            context.patientDelegateAccountId, updateContext.patientConsent);

        if (needsUpdate || legalGuardianUpdated) {
            context.consentsToUpdate.add(updateContext.patientConsent);
        }
    }

    /**
     * @description Creates a new ContactPointTypeConsent record from Lead consent
     * @param context ConsentCreationContext containing consent creation parameters
     * @return New ContactPointTypeConsent record
     */
    private ContactPointTypeConsent createConsentFromLead(ConsentCreationContext context) {
        ContactPointTypeConsent newConsent = new ContactPointTypeConsent();
        newConsent.PartyId = context.patientIndividualId;
        newConsent.Name = context.consentName;
        newConsent.PrivacyConsentStatus = context.leadConsent.PrivacyConsentStatus;
        newConsent.CaptureDate = context.leadConsent.CaptureDate;
        newConsent.DataUsePurposeId = context.leadConsent.DataUsePurposeId;
        newConsent.CaptureSource = context.leadConsent.CaptureSource;

        if (context.patientDelegateAccountId != null) {
            newConsent.Legal_Guardian__c = context.patientDelegateAccountId;
        }

        return newConsent;
    }

    /**
     * @description Performs DML operations for insert and update
     * @param consentsToInsert List of consents to insert
     * @param consentsToUpdate List of consents to update
     */
    private void performDMLOperations(List<ContactPointTypeConsent> consentsToInsert, List<ContactPointTypeConsent> consentsToUpdate) {
        if (!consentsToInsert.isEmpty() && Schema.SObjectType.ContactPointTypeConsent.isCreateable()) {
            List<Database.SaveResult> insertResults = Database.insert(consentsToInsert, false, AccessLevel.USER_MODE);
            logDMLErrors(insertResults, consentsToInsert);
        }

        if (!consentsToUpdate.isEmpty() && Schema.SObjectType.ContactPointTypeConsent.isUpdateable()) {
            TriggerHandler.bypass('ContactPointTypeConsentTriggerHandler');
            try {
            List<Database.SaveResult> updateResults = Database.update(consentsToUpdate, false, AccessLevel.USER_MODE);
            logDMLErrors(updateResults, consentsToUpdate);
            } catch (Exception ex) {
                logError('Error in performDMLOperations: ' + ex.getMessage(), consentsToUpdate, ex);
            } finally {
                TriggerHandler.clearBypass('ContactPointTypeConsentTriggerHandler');
            }
        }
    }

    /**
     * @description Logs DML operation errors
     * @param results List of Database.SaveResult
     * @param records List of records that were processed
     */
    private void logDMLErrors(List<Database.SaveResult> results, List<SObject> records) {
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult result = results[i];
            if (result.isSuccess()) {
                continue;
            }
            logDMLResultErrors(result, records[i]);
        }
    }

    /**
     * @description Logs errors for a single DML result
     * @param result Database.SaveResult
     * @param record SObject record that was processed
     */
    @TestVisible
    private void logDMLResultErrors(Database.SaveResult result, SObject record) {
        for (Database.Error err : result.getErrors()) {
            if (err.getStatusCode() != StatusCode.INSUFFICIENT_ACCESS_OR_READONLY) {
                logError('Failed to process ContactPointTypeConsent record: ' + err.getMessage(), new List<SObject>{record}, null);
            }
        }
    }
    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null for permission errors)
     */
    static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    /**
     * @description Finalizer class to handle cleanup and error scenarios for consent mapping job
     */
    @TestVisible
    public class ConsentMappingFinalizer implements System.Finalizer {
        private List<LeadConversionConsentData> mappingDataList;

        /**
         * @description Constructor
         * @param dataList List of LeadConversionConsentData that were being processed
         */
        public ConsentMappingFinalizer(List<LeadConversionConsentData> dataList) {
            this.mappingDataList = dataList != null ? dataList : new List<LeadConversionConsentData>();
        }

        /**
         * @description Execute method called when Queueable job completes or fails
         * @param context FinalizerContext containing job status and exception information
         */
        public void execute(System.FinalizerContext context) {
            if (context.getResult() != ParentJobResult.UNHANDLED_EXCEPTION) {
                return;
            }

            List<SObject> consentRecords = buildConsentRecords();
            String errorMessage = 'Consent mapping job failed with unhandled exception: ' +
                    (context.getException() != null ? context.getException().getMessage() : 'Unknown error');
            logError(errorMessage, consentRecords, context.getException());
        }

        /**
         * @description Builds list of Account records from mapping data
         * @return List of Account records
         */
        private List<SObject> buildConsentRecords() {
            List<SObject> consentRecords = new List<SObject>();
            for (LeadConversionConsentData data : mappingDataList) {
                if (data.accountId != null) {
                    consentRecords.add(new Account(Id = data.accountId));
                }
            }
            return consentRecords;
        }
    }
}