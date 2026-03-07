/**
 * @description : Handles Individual records operations
 * Created Date : 03-10-2025
 * Created By   : Bijayalaxmi Prusty
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       1st Oct 2025        Bijayalaxmi Prusty      Initial Version(US - NGASIM-376 & NGASIM-379)
 * V1.1.0       15th Oct 2025       Bijayalaxmi Prusty      Modifed(US - NGASIM-377 & NGASIM-380)
 * V1.2.0       28th Jan 2026       Tanu Tyagi              Modified(NGASIM-1911)
 * V1.3.0       2nd Feb 2026        Tanu Tyagi              Refactored for reduced cyclomatic complexity
 */
public with sharing  class IndividualHandler{
    // Prevent repeated Individual creation attempts for the same records within a single transaction.
    @TestVisible
    private static final Set<Id> PROCESSED_LEAD_IDS_FOR_INDIVIDUAL_CREATE = new Set<Id>();
    @TestVisible
    private static final Set<Id> PROCESSED_ACCOUNT_IDS_FOR_INDIVIDUAL_CREATE = new Set<Id>();

    /**
     * @description managing individual records
     * @param records list of SObject records to process
     */
    public static void manageIndividuals(List<SObject> records){
        if(records == null || records.isEmpty()){
            return;
        }
        List<SObject> recordsToProcessForInsert = collectRecordsForInsert(records, false);
        if (!recordsToProcessForInsert.isEmpty()) {
            IndividualService.createIndividuals(recordsToProcessForInsert);
        }
    }

    /**
     * @description managing the update individual records
     * @param newRecords list of new SObject records to process
     * @param oldRecords map of old SObject records to process
     */
    public static void manageUpdateIndividuals(List<SObject> newRecords, Map<Id,SObject> oldRecords){
        if(newRecords == null || newRecords.isEmpty()){
            return;
        }

        // Check for Leads that still need Individual records created
        List<SObject> recordsToProcessForInsert = collectRecordsForInsert(newRecords, true);
        if (!recordsToProcessForInsert.isEmpty()) {
            IndividualService.createIndividuals(recordsToProcessForInsert);
        }

        //to update individual records
        List<SObject> recordsToProcessForUpdate = collectRecordsForUpdate(newRecords, oldRecords);
        if (!recordsToProcessForUpdate.isEmpty()) {
            IndividualService.updateIndividuals(recordsToProcessForUpdate);
        }

        // Check and create missing consent records for all Leads with IndividualIds
        ConsentService.createConsentRecordsForLeads(newRecords);
    }

    /**
     * @description Collects records that need Individual records created
     * @param records list of SObject records to process
     * @param requireIndividualIdNull true if IndividualId must be null (for updates), false otherwise
     * @return list of records to process for insert
     */
    private static List<SObject> collectRecordsForInsert(List<SObject> records, Boolean requireIndividualIdNull){
        List<SObject> recordsToProcessForInsert = new List<SObject>();
        for (SObject record : records) {
            if (record instanceof Lead) {
                Lead leadRecord = (Lead) record;
                if (shouldProcessLeadForInsert(leadRecord, requireIndividualIdNull)) {
                    PROCESSED_LEAD_IDS_FOR_INDIVIDUAL_CREATE.add(leadRecord.Id);
                    recordsToProcessForInsert.add(leadRecord);
                }
            } else if (record instanceof Account) {
                Account accountRecord = (Account) record;
                if (shouldProcessAccountForInsert(accountRecord, requireIndividualIdNull)) {
                    PROCESSED_ACCOUNT_IDS_FOR_INDIVIDUAL_CREATE.add(accountRecord.Id);
                    recordsToProcessForInsert.add(accountRecord);
                }
            }
        }
        return recordsToProcessForInsert;
    }

    /**
     * @description Collects records that need Individual records updated
     * @param newRecords list of new SObject records
     * @param oldRecords map of old SObject records
     * @return list of records to process for update
     */
    private static List<SObject> collectRecordsForUpdate(List<SObject> newRecords, Map<Id,SObject> oldRecords){
        List<SObject> recordsToProcessForUpdate = new List<SObject>();
        for (SObject record : newRecords) {
            if (record instanceof Lead) {
                processLeadForUpdate((Lead) record, oldRecords, recordsToProcessForUpdate);
            } else if (record instanceof Account) {
                processAccountForUpdate((Account) record, oldRecords, recordsToProcessForUpdate);
            }
        }
        return recordsToProcessForUpdate;
    }

    /**
     * @description Checks if a Lead should be processed for Individual insert
     * @param leadRecord Lead record to check
     * @param requireIndividualIdNull true if IndividualId must be null
     * @return true if Lead should be processed
     */
    private static Boolean shouldProcessLeadForInsert(Lead leadRecord, Boolean requireIndividualIdNull){
        if (leadRecord == null || leadRecord.Id == null || leadRecord.IsConverted == true) {
            return false;
        }
        if (PROCESSED_LEAD_IDS_FOR_INDIVIDUAL_CREATE.contains(leadRecord.Id)) {
            return false;
        }
        if (requireIndividualIdNull && leadRecord.IndividualId != null) {
            return false;
        }
        return true;
    }

    /**
     * @description Checks if an Account should be processed for Individual insert
     * @param accountRecord Account record to check
     * @param requireIndividualIdNull true if PersonIndividualId must be null
     * @return true if Account should be processed
     */
    private static Boolean shouldProcessAccountForInsert(Account accountRecord, Boolean requireIndividualIdNull){
        if (accountRecord == null || accountRecord.Id == null) {
            return false;
        }
        if (PROCESSED_ACCOUNT_IDS_FOR_INDIVIDUAL_CREATE.contains(accountRecord.Id)) {
            return false;
        }
        if (!accountRecord.IsPersonAccount) {
            return false;
        }
        if (requireIndividualIdNull && accountRecord.PersonIndividualId != null) {
            return false;
        }
        return true;
    }

    /**
     * @description processes Lead records for Individual update
     * @param leadRecord Lead record to process
     * @param oldRecords map of old records
     * @param recordsToProcess list to add qualifying records
     */
    private static void processLeadForUpdate(Lead leadRecord, Map<Id,SObject> oldRecords, List<SObject> recordsToProcess){
        if (leadRecord.IndividualId == null) {
            return;
        }
        Lead oldLeadRecord = (Lead) oldRecords.get(leadRecord.Id);
        if (oldLeadRecord == null) {
            return;
        }
        if (hasNameFieldsChanged(leadRecord, oldLeadRecord)) {
            recordsToProcess.add(leadRecord);
        }
    }

    /**
     * @description processes Account records for Individual update
     * @param accountRecord Account record to process
     * @param oldRecords map of old records
     * @param recordsToProcess list to add qualifying records
     */
    private static void processAccountForUpdate(Account accountRecord, Map<Id,SObject> oldRecords, List<SObject> recordsToProcess){
        if (!accountRecord.IsPersonAccount || accountRecord.PersonIndividualId == null) {
            return;
        }
        Account oldAccountRecord = (Account) oldRecords.get(accountRecord.Id);
        if (oldAccountRecord == null) {
            return;
        }
        if (hasNameFieldsChanged(accountRecord, oldAccountRecord)) {
            recordsToProcess.add(accountRecord);
        }
    }

    /**
     * @description Checks if name fields have changed between two Lead records
     * @param newRecord new Lead record
     * @param oldRecord old Lead record
     * @return true if any name field has changed
     */
    private static Boolean hasNameFieldsChanged(Lead newRecord, Lead oldRecord){
        return newRecord.FirstName != oldRecord.FirstName ||
               newRecord.LastName != oldRecord.LastName ||
               newRecord.MiddleName != oldRecord.MiddleName ||
               newRecord.Salutation != oldRecord.Salutation ||
               newRecord.Suffix != oldRecord.Suffix;
    }

    /**
     * @description Checks if name fields have changed between two Account records
     * @param newRecord new Account record
     * @param oldRecord old Account record
     * @return true if any name field has changed
     */
    private static Boolean hasNameFieldsChanged(Account newRecord, Account oldRecord){
        return newRecord.FirstName != oldRecord.FirstName ||
               newRecord.LastName != oldRecord.LastName ||
               newRecord.MiddleName != oldRecord.MiddleName ||
               newRecord.Salutation != oldRecord.Salutation ||
               newRecord.Suffix != oldRecord.Suffix;
    }
}