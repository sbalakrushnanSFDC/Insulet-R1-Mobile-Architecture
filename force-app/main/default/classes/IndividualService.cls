/**
 * @description Creates Individual records of Lead or Account,
 * and sets the IndividualId field on the source records.
 * Created Date : 01-10-2025
 * Created By   : Bijayalaxmi Prusty
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       1st Oct 2025        Bijayalaxmi Prusty      Initial Version(US - NGASIM-376 & NGASIM-379)
 * V1.1.0       15th Oct 2025       Bijayalaxmi Prusty      Modifed(US - NGASIM-377 & NGASIM-380)
 * V1.2.0       28th Jan 2026       Tanu Tyagi              Modified(NGASIM-1911)

 */
public inherited sharing class IndividualService {

    // Static map to track Lead ID to IndividualId mappings for cross-class reference
    public static Map<Id, Id> leadIdToIndividualIdMap = new Map<Id, Id>();

    /**
     * @description Creates individual records for Lead or Account records
     * @param records List of SObject records to process
     */
    public static void createIndividuals(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        ProcessingContext context = new ProcessingContext();
        // Process each record to build individuals
        for (SObject record : records) {
            processRecord(record, context);
        }
        if (context.individualsToInsert.isEmpty()) {
            return;
        }

        // Insert individuals and u
        // pdate source records
        insertIndividualRecords(context);
        updateSourceRecords(context);

        // Create consent records for Leads with Patient or Provider record types
        // Build Lead records with IndividualIds from context
        List<Lead> leadsForConsent = new List<Lead>();
        for (Id sourceId : context.sourceToIndividualIdMap.keySet()) {
            SObject sourceRecord = context.sourceRecordMap.get(sourceId);
            Id individualId = context.sourceToIndividualIdMap.get(sourceId);
            if (sourceRecord instanceof Lead && individualId != null) {
                Lead leadRecord = (Lead) sourceRecord;
                // Create a new Lead instance with IndividualId set
                Lead leadWithIndividualId = new Lead(Id = leadRecord.Id, IndividualId = individualId);
                leadsForConsent.add(leadWithIndividualId);
            }
        }
        if (!leadsForConsent.isEmpty()) {
            ConsentService.createConsentRecordsForLeads(leadsForConsent);
        }
    }

    /**
     * @description Updates individual records based on Lead or Account record changes
     * @param records List of SObject records to process for Individual updates
     */
    public static void updateIndividuals(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        UpdateContext updateContext = new UpdateContext();
        // Process each record to build individual updates
        for (SObject record : records) {
            processRecordForUpdate(record, updateContext);
        }

        // Update individual records if there are any to update
        if (!updateContext.individualsToUpdate.isEmpty()) {
            updateIndividualRecords(updateContext);
        }

        // Always check and create consent records for Leads with Patient or Provider record types
        // This ensures consent records are created even when Individual records don't need updates
        ConsentService.createConsentRecordsForLeads(records);
    }

    /**
     * @description Processes a single record (Lead or Account) to create individual
     * @param record The SObject record to process
     * @param context The processing context containing maps and lists
     */
    private static void processRecord(SObject record, ProcessingContext context) {
        if (record instanceof Lead) {
            processLeadRecordForInsert((Lead) record, context);
        } else if (record instanceof Account) {
            processAccountRecordForInsert((Account) record, context);
        }
    }

    /**
     * @description Processes a single record (Lead or Account) for Individual update
     * @param record The SObject record to process
     * @param updateContext The update context containing maps and lists
     */
    private static void processRecordForUpdate(SObject record, UpdateContext updateContext) {
        if (record instanceof Lead) {
            processLeadRecordForUpdate((Lead) record, updateContext);
        } else if (record instanceof Account) {
            processAccountRecordForUpdate((Account) record, updateContext);
        }
    }

    /**
     * @description Processes a Lead record for Individual update
     * @param leadRecord The Lead record to process
     * @param updateContext The update context containing maps and lists
     */
    private static void processLeadRecordForUpdate(Lead leadRecord, UpdateContext updateContext) {
        if (leadRecord.IndividualId == null) {
            return;
        }

        IndividualName nameData = new IndividualName(leadRecord);
        Individual individualUpdate = buildIndividual(leadRecord.IndividualId, nameData);
        updateContext.individualsToUpdate.add(individualUpdate);
    }

    /**
     * @description Processes an Account record for Individual update
     * @param accountRecord The Account record to process
     * @param updateContext The update context containing maps and lists
     */
    private static void processAccountRecordForUpdate(Account accountRecord, UpdateContext updateContext) {
        if (!accountRecord.IsPersonAccount || accountRecord.PersonIndividualId == null) {
            return;
        }

        IndividualName nameData = new IndividualName(accountRecord);
        Individual individualUpdate = buildIndividual(accountRecord.PersonIndividualId, nameData);
        updateContext.individualsToUpdate.add(individualUpdate);
    }

    /**
     * @description Processes a Lead record to create individual
     * @param leadRecord The Lead record to process
     * @param context The processing context containing maps and lists
     */
    private static void processLeadRecordForInsert(Lead leadRecord, ProcessingContext context) {
        if (leadRecord.IndividualId != null) {
            return;
        }

        IndividualName nameData = new IndividualName(leadRecord);

        Individual individual = buildIndividual(null,nameData);
        context.individualsToInsert.add(individual);
        context.sourceRecordMap.put(leadRecord.Id, leadRecord);
        context.sourceToIndividualIdMap.put(leadRecord.Id, null);
    }

    /**
     * @description Processes an Account record to create individual
     * @param accountRecord The Account record to process
     * @param context The processing context containing maps and lists
     */
    private static void processAccountRecordForInsert(Account accountRecord, ProcessingContext context) {
        if (!accountRecord.IsPersonAccount || accountRecord.PersonIndividualId != null) {
            return;
        }

        IndividualName nameData = new IndividualName(accountRecord);

        Individual individual = buildIndividual(null,nameData);
        context.individualsToInsert.add(individual);
        context.sourceRecordMap.put(accountRecord.Id, accountRecord);
        context.sourceToIndividualIdMap.put(accountRecord.Id, null);
    }

    /**
     * @description Inserts individual records with proper CRUD checks
     * @param context The processing context containing individuals to insert
     */
    private static void insertIndividualRecords(ProcessingContext context) {
        // Check CRUD permissions before insert
        if (!Schema.SObjectType.Individual.isCreateable()) { return; }

        if (context.individualsToInsert.isEmpty()) { return; }

        try {
            insert context.individualsToInsert;
            // Map the newly created Individual IDs back to source records
            mapIndividualIds(context);
        } catch (DmlException ex) { return; }
    }

    /**
     * @description Maps newly created Individual IDs to source record IDs
     * @param context The processing context containing the mapping data
     */
    private static void mapIndividualIds(ProcessingContext context) {
        Integer index = 0;
        for (Id sourceId : context.sourceToIndividualIdMap.keySet()) {
            Id newIndividualId = context.individualsToInsert[index++].Id;
            context.sourceToIndividualIdMap.put(sourceId, newIndividualId);
        }
    }

    /**
     * @description Updates source records with Individual IDs
     * @param context The processing context containing source records and Individual IDs
     */
    private static void updateSourceRecords(ProcessingContext context) {
        List<SObject> recordsToUpdate = buildUpdateRecords(context);
        if (recordsToUpdate.isEmpty()) { return; }

        // Populate static map of Lead ID to IndividualId for cross-class reference
        for (SObject record : recordsToUpdate) {
            if (record instanceof Lead) {
                Lead leadRecord = (Lead) record;
                if (leadRecord.Id != null && leadRecord.IndividualId != null) {
                    leadIdToIndividualIdMap.put(leadRecord.Id, leadRecord.IndividualId);
                }
            }
        }

        // Separate records by type and update each type
        updateLeadRecords(recordsToUpdate);
        updateAccountRecords(recordsToUpdate);
    }

    /**
     * @description Updates Lead records with proper CRUD validation
     * @param recordsToUpdate List of all records to update
     */
    private static void updateLeadRecords(List<SObject> recordsToUpdate) {
        List<Lead> leadsToUpdate = new List<Lead>();
        for (SObject record : recordsToUpdate) {
            if (record instanceof Lead) {
                leadsToUpdate.add((Lead) record);
            }
        }
        if (!leadsToUpdate.isEmpty()) {
            performLeadUpdate(leadsToUpdate);
        }
    }

    /**
     * @description Performs the actual Lead update with CRUD validation
     * @param leadsToUpdate List of Lead records to update
     */
    @TestVisible
    private static void performLeadUpdate(List<Lead> leadsToUpdate) {

        if (!Schema.SObjectType.Lead.isUpdateable() ||
            !Schema.SObjectType.Lead.fields.IndividualId.isUpdateable()) { return; }
        // Avoid recursively invoking Lead trigger processing when we only need to persist IndividualId.
        // This bypass applies only for this internal update and is cleared in finally.
        TriggerHandler.bypass('LeadTriggerHandler');
        try {
            Database.update(leadsToUpdate, AccessLevel.SYSTEM_MODE);
            //update leadsToUpdate;
        } catch (DmlException ex) {
            return;
        } finally {
            TriggerHandler.clearBypass('LeadTriggerHandler');
        }
    }

    /**
     * @description Updates Account records with proper CRUD validation
     * @param recordsToUpdate List of all records to update
     */
    private static void updateAccountRecords(List<SObject> recordsToUpdate) {
        List<Account> accountsToUpdate = new List<Account>();
        for (SObject record : recordsToUpdate) {
            if (record instanceof Account) {
                accountsToUpdate.add((Account) record);
            }
        }
        if (!accountsToUpdate.isEmpty()) {
            performAccountUpdate(accountsToUpdate);
        }
    }

    /**
     * @description Performs the actual Account update with CRUD validation
     * @param accountsToUpdate List of Account records to update
     */
    @TestVisible
    private static void performAccountUpdate(List<Account> accountsToUpdate) {
        if (!Schema.SObjectType.Account.isUpdateable() ||
            !Schema.SObjectType.Account.fields.PersonIndividualId.isUpdateable()) { return;}
        // Avoid recursively invoking Account trigger processing when we only need to persist IndividualId.
        // This bypass applies only for this internal update and is cleared in finally.
        TriggerHandler.bypass('AccountTriggerHandler');
        try {
            Database.update(accountsToUpdate, AccessLevel.SYSTEM_MODE);
        } catch (DmlException ex) {
            return;
        }finally {
            TriggerHandler.clearBypass('AccountTriggerHandler');
        }
    }

    /**
     * @description Builds list of records to update with Individual IDs
     * @param context The processing context containing source records and Individual IDs
     * @return List of SObject records ready for update
     */
    private static List<SObject> buildUpdateRecords(ProcessingContext context) {
        List<SObject> recordsToUpdate = new List<SObject>();

        for (Id sourceId : context.sourceToIndividualIdMap.keySet()) {
            Id individualId = context.sourceToIndividualIdMap.get(sourceId);
            SObject sourceRecord = context.sourceRecordMap.get(sourceId);

            if (sourceRecord == null || individualId == null) { continue; }

            SObject updateRecord = createUpdateRecord(sourceRecord, sourceId, individualId);
            if (updateRecord != null) {
                recordsToUpdate.add(updateRecord);
            }
        }

        return recordsToUpdate;
    }

    /**
     * @description Creates an update record for Lead or Account with Individual ID
     * @param sourceRecord The original source record
     * @param sourceId The ID of the source record
     * @param individualId The ID of the Individual record
     * @return SObject record ready for update or null if no permission
     */
    @TestVisible
    private static SObject createUpdateRecord(SObject sourceRecord, Id sourceId, Id individualId) {
        if (sourceRecord instanceof Lead) {
            return createLeadUpdateRecord(sourceId, individualId);
        } else if (sourceRecord instanceof Account) {
            return createAccountUpdateRecord(sourceId, individualId);
        }
        return null;
    }

    /**
     * @description Creates Lead update record with proper CRUD checks
     * @param sourceId The Lead record ID
     * @param individualId The Individual record ID
     * @return Lead record for update or null if no permission
     */
    @TestVisible
    private static Lead createLeadUpdateRecord(Id sourceId, Id individualId) {
        if (!Schema.SObjectType.Lead.isUpdateable() ||
            !Schema.SObjectType.Lead.fields.IndividualId.isUpdateable()) {
            return null;
        }

        Lead leadUpdate = new Lead(Id = sourceId);
        leadUpdate.IndividualId = individualId;
        return leadUpdate;
    }

    /**
     * @description Creates Account update record with proper CRUD checks
     * @param sourceId The Account record ID
     * @param individualId The Individual record ID
     * @return Account record for update or null if no permission
     */
    @TestVisible
    private static Account createAccountUpdateRecord(Id sourceId, Id individualId) {
        if (!Schema.SObjectType.Account.isUpdateable() ||
            !Schema.SObjectType.Account.fields.PersonIndividualId.isUpdateable()) {
            return null;
        }

        Account accountUpdate = new Account(Id = sourceId);
        accountUpdate.PersonIndividualId = individualId;
        return accountUpdate;
    }

    /**
     * @description Builds individual record from Individual ID and name data
     * @param individualId The ID of the Individual record to update
     * @param nameData The IndividualName containing name components
     * @return Individual record ready for update/insert
     */
    @TestVisible
    private static Individual buildIndividual(Id individualId, IndividualName nameData) {
        Individual individual = new Individual(Id = individualId);
        individual.Salutation = nameData.salutation;
        individual.FirstName = nameData.firstName;
        individual.MiddleName = nameData.middleName;
        individual.LastName = nameData.lastName;
        individual.Suffix = nameData.suffix;
        return individual;
    }

    /**
     * @description Updates individual records with proper CRUD checks
     * @param updateContext The update context containing individuals to update
     */
    private static void updateIndividualRecords(UpdateContext updateContext) {
        // Check CRUD permissions before update
        if (!Schema.SObjectType.Individual.isUpdateable()) { return; }

        if (updateContext.individualsToUpdate.isEmpty()) { return; }

        try {
            Database.update(updateContext.individualsToUpdate, AccessLevel.SYSTEM_MODE);
        } catch (DmlException ex) {
            return;
        }
    }


    /**
     * @description Inner class to hold processing context and reduce parameter passing
     */
    @TestVisible
    private class ProcessingContext {
        /**
         * @description List of Individual records to be inserted
         */
        public List<Individual> individualsToInsert { get; set; }
        /**
         * @description Map of source record IDs to their SObject records
         */
        public Map<Id, SObject> sourceRecordMap { get; set; }
        /**
         * @description Map of source record IDs to their corresponding Individual IDs
         */
        public Map<Id, Id> sourceToIndividualIdMap { get; set; }

        /**
         * @description Constructor to initialize processing context collections
         */
        public ProcessingContext() {
            this.individualsToInsert = new List<Individual>();
            this.sourceRecordMap = new Map<Id, SObject>();
            this.sourceToIndividualIdMap = new Map<Id, Id>();
        }
    }

    /**
     * @description Inner class to hold update context for Individual record updates
     */
    @TestVisible
    private class UpdateContext {
        /**
         * @description List of Individual records to be updated
         */
        public List<Individual> individualsToUpdate { get; set; }

        /**
         * @description Constructor to initialize update context collections
         */
        public UpdateContext() {
            this.individualsToUpdate = new List<Individual>();
        }
    }

    /**
     * @description Inner class to encapsulate individual name data
     */
    public class IndividualName {
        /**
         * @description Salutation of the individual (Mr., Ms., Dr., etc.)
         */
        public String salutation { get; set; }
        /**
         * @description First name of the individual
         */
        public String firstName { get; set; }
        /**
         * @description Middle name of the individual
         */
        public String middleName { get; set; }
        /**
         * @description Last name of the individual
         */
        public String lastName { get; set; }
        /**
         * @description Suffix of the individual (Jr., Sr., III, etc.)
         */
        public String suffix { get; set; }

        /**
         * @description Constructor for IndividualName using SObject record
         * @param record The Lead or Account record containing name fields
         */
        public IndividualName(SObject record) {
            if (record instanceof Lead) {
                Lead leadRecord = (Lead) record;
                this.salutation = leadRecord.Salutation;
                this.firstName = leadRecord.FirstName;
                this.middleName = leadRecord.MiddleName;
                this.lastName = leadRecord.LastName;
                this.suffix = leadRecord.Suffix;
            } else if (record instanceof Account) {
                Account accountRecord = (Account) record;
                this.salutation = accountRecord.Salutation;
                this.firstName = accountRecord.FirstName;
                this.middleName = accountRecord.MiddleName;
                this.lastName = accountRecord.LastName;
                this.suffix = accountRecord.Suffix;
            }
        }
    }
}