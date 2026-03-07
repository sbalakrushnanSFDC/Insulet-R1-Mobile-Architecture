/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 12th November 2025
 * @description : Service class to handle operations on leads
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       12th Nov 2025       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1065)
 * V1.1.0       11th Dec 2025       Jatin Butta             Updated(US - NGASIM-1273) - Added Task Generation
 * V1.2.0		12nd Feb 2026		Bijayalaxmi Prusty		Modified(US - NGASIM-2065)
 * V1.3.0		16th Feb 2026		Charchit Nirayanwal		Modified(US - NGASIM-2207)
 * V1.4.0		26th Feb 2026		Saikat Ghosh			Modified(US - NGASIM-1722) - Provider Practice Lead Territory Assignment
 */
 public with sharing class LeadService {
    // Cache for queue lookups to avoid repeated SOQL queries
    private static Map<String, Id> queueCache = new Map<String, Id>();

    @TestVisible
    private static Boolean simulateLeadStatusNotUpdateable = false;

    /**
     * @description Closes leads as duplicates with specified status
     * @param leadIds List of Lead Ids to close
     */
    @AuraEnabled
    public static void closeLeadsAsDuplicate(List<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        // Convert to Set to avoid duplicate processing
        Set<Id> uniqueLeadIds = new Set<Id>(leadIds);

        if (!Schema.SObjectType.Lead.fields.Status.isUpdateable()
            || (Test.isRunningTest() && simulateLeadStatusNotUpdateable)) {
            logError('User does not have permission to update Lead Status', new List<SObject>(), null);
            return;
        }

        List<Lead> leadsToUpdate = new List<Lead>();

        for (Id leadId : uniqueLeadIds) {
            Lead updateLead = new Lead(
                Id = leadId,
                Status = ConstantsUtil.LEAD_CLOSED_DUPLICATE_STATUS
            );
            leadsToUpdate.add(updateLead);
        }
        if (!leadsToUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(leadsToUpdate, false, AccessLevel.USER_MODE);

            Boolean hasErrors = false;
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    String errors = buildErrorMessage(results[i].getErrors());
                    Logger.error('Failed to close Lead as duplicate at index ' + i + '. Errors: ' + errors, new List<SObject>{leadsToUpdate[i]}, null).addTag(ConstantsUtil.ASIM_TAG);
                    hasErrors = true;
                }
            }
            if (hasErrors) { Logger.saveLog(); }
        }
    }

    /**
     * @description Builds error message from Database.Error list
     * @param errors List of Database.Error objects
     * @return Concatenated error message
     */
    private static String buildErrorMessage(List<Database.Error> errors) {
        String errorMsg = '';
        for (Database.Error err : errors) {
            errorMsg += err.getMessage() + '; ';
        }
        return errorMsg;
    }

    /**
     * @description Logs error messages using Logger framework
     * @param message Error message
     * @param records Related records
     * @param ex Exception (can be null)
     */
    private static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    // ========== TASK GENERATION METHODS (NGASIM-1273) ==========

    /**
     * @description Sets preferred language based on LeadSource (NGASIM-1273).
     *              - If LeadSource is 'Empezar', sets Preferred_Language__c to Spanish
     *              Executes in before insert/update so the value is saved on the Lead and retained on conversion.
     * @param leads List of Lead records to process
     */
    public static void setSpanishPrimaryLanguage(List<Lead> leads) {
        if (leads == null || leads.isEmpty()) {
            return;
        }

        for (Lead lead : leads) {
            // If LeadSource is Empezar - set preferred language to Spanish
            if (lead.LeadSource == ConstantsUtil.LEAD_SOURCE_EMPEZAR
                && lead.Preferred_Language__c != ConstantsUtil.LANGUAGE_SPANISH) {
                lead.Preferred_Language__c = ConstantsUtil.LANGUAGE_SPANISH;
            }
        }
    }

    /**
     * @description Generates automated tasks for leads based on Task Generation Rules.
     *              This method is called from trigger handler to ensure tasks are created
     *              when leads meet the rule criteria defined in Custom Metadata.
     *              Uses TaskGenerationService with FormulaEval for dynamic condition evaluation.
     *              Filters rules by trigger event to reduce the number of rules evaluated.
     * @param leads List of Lead records to process for task generation
     * @param triggerEvent Event type: ConstantsUtil.INSERT_OPERATION or ConstantsUtil.UPDATE_OPERATION
     */
    public static void generateTasksForLeads(List<Lead> leads, String triggerEvent) {
        if (leads == null || leads.isEmpty()) {
            return;
        }

        try {
            // Build task generation requests for all leads
            List<TaskGenerationService.TaskRequest> requests = new List<TaskGenerationService.TaskRequest>();

            for (Lead lead : leads) {
                TaskGenerationService.TaskRequest request = new TaskGenerationService.TaskRequest();
                request.recordId = lead.Id;
                request.objectApiName = ConstantsUtil.LEAD_OBJECT;
                request.triggerEvent = triggerEvent;
                requests.add(request);
            }

            // Call the task generation service
            List<TaskGenerationService.TaskResult> results = TaskGenerationService.createTasks(requests);

            // Log results for monitoring and debugging
            Boolean hasLogEntries = false;
            for (TaskGenerationService.TaskResult result : results) {
                if (result.success && result.tasksCreated > 0) {
                    Logger.info('Created ' + result.tasksCreated + ' task(s) for leads. Message: ' + result.message)
                        .addTag(ConstantsUtil.ASIM_TAG);
                    hasLogEntries = true;
                } else if (!result.success) {
                    Logger.warn('Task generation warning: ' + result.message)
                        .addTag(ConstantsUtil.ASIM_TAG);
                    hasLogEntries = true;
                }
            }
            if (hasLogEntries) {
                Logger.saveLog();
            }

            /**
            * when customExceptionSwitch static variable is turned on
            * it covers exceptions in test coverage
            */
            if (ConstantsUtil.customExceptionSwitch && Test.isRunningTest()) {
                throw new MyCustomException('customExceptionSwitch is turned on');
            }

        } catch (Exception e) {

            // Log error but don't throw to avoid blocking the entire transaction
            Logger.error('Error in generateTasksForLeads: ' + e.getMessage(), e)
                .addTag(ConstantsUtil.ASIM_TAG);
            Logger.saveLog();
        }
    }

    /**
     * @description Assigns failed leads to DTC_Open queue (no status change)
     *              This is used for auto conversion failures to route leads for manual review
     * @param leadIds List of Lead IDs that failed conversion
     */
    public static void updateFailedLeadsToNew(List<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        Id queueId = findQueueByName(ConstantsUtil.DTC_OPEN_QUEUE);

        List<Lead> leadsToUpdate = buildLeadsForUpdate(leadIds, queueId);
        if (leadsToUpdate.isEmpty()) {
            return;
        }
        try {
            TriggerHandler.bypass('LeadTriggerHandler');
        Database.update(leadsToUpdate, false, AccessLevel.USER_MODE);
        } catch (Exception e) {
            Logger.error('Error in updateFailedLeadsToNew: ' + e.getMessage(), e)
                .addTag(ConstantsUtil.ASIM_TAG);
            Logger.saveLog();
        } finally {
            TriggerHandler.clearBypass('LeadTriggerHandler');
        }
    }

    /**
     * @description Builds list of leads to update with owner assignment only
     * Only includes leads that are NOT already converted
     * @param leadIds List of lead IDs to update
     * @param queueId Queue ID to assign (can be null)
     * @return List of Lead records ready for update
     */
    private static List<Lead> buildLeadsForUpdate(List<Id> leadIds, Id queueId) {
        // Query leads to check if they're already converted
        List<Lead> existingLeads = [
            SELECT Id, IsConverted, Status, OwnerId, LeadSource
            FROM Lead
            WHERE Id IN :leadIds
            WITH USER_MODE
        ];

        Map<Id, Lead> leadMap = new Map<Id, Lead>(existingLeads);

        List<Lead> leadsToUpdate = new List<Lead>();
        for (Id leadId : leadIds) {
            Lead leadToUpdate = buildSingleLeadForUpdate(leadId, leadMap.get(leadId), queueId);
            if (leadToUpdate != null) {
                leadsToUpdate.add(leadToUpdate);
            }
        }
        return leadsToUpdate;
    }

    /**
     * @description Builds a single lead for update if needed
     * Only assigns to queue if Lead Source = 'Get Started' AND Status is 'New' OR 'Qualification'
     * @param leadId ID of the lead to update
     * @param existingLead Existing lead record from database (can be null)
     * @param queueId Queue ID to assign (can be null)
     * @return Lead record ready for update, or null if no update needed
     */
    private static Lead buildSingleLeadForUpdate(Id leadId, Lead existingLead, Id queueId) {
        if (existingLead == null || existingLead.IsConverted) {
            return null;
        }

        // Check if lead meets criteria for queue assignment
        Boolean meetsQueueCriteria = existingLead.LeadSource == ConstantsUtil.LEAD_SOURCE_GET_STARTED &&
            (existingLead.Status == ConstantsUtil.LEAD_STATUS_NEW || existingLead.Status == ConstantsUtil.LEAD_STATUS_QUALIFICATION);

        if (!meetsQueueCriteria) {
            return null;
        }

        Boolean needsOwnerUpdate = queueId != null && existingLead.OwnerId != queueId;

        if (!needsOwnerUpdate) {
            return null;
        }

        Lead leadToUpdate = new Lead(Id = leadId);
        leadToUpdate.OwnerId = queueId;
        return leadToUpdate;
    }

    /**
     * @description Finds a queue by its DeveloperName
     * @param queueDeveloperName Developer name of the queue
     * @return Queue ID if found, null otherwise
     */
    @TestVisible
    private static Id findQueueByName(String queueDeveloperName) {
        if (String.isBlank(queueDeveloperName)) {
            return null;
        }

        // Check cache first
        if (queueCache.containsKey(queueDeveloperName)) {
            return queueCache.get(queueDeveloperName);
        }

        // Query if not in cache
        List<Group> queues = [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE DeveloperName = :queueDeveloperName AND Type = 'Queue'
            WITH USER_MODE
            LIMIT 1
        ];

        Id queueId = queues.isEmpty() ? null : queues[0].Id;

        // Store in cache (even if null, to avoid repeated queries for non-existent queues)
        queueCache.put(queueDeveloperName, queueId);

        return queueId;
    }

    /**
     * @description Assigns territory to Provider Practice Leads via ObjectTerritory2Association (NGASIM-1722).
     *              Territory source: Practice__c (from Practice's OT2A) or PostalCode (from ZipCode__c lookup).
     *              On update, removes old OT2A before inserting new one.
     * @param leads New/updated Lead records
     * @param oldLeadsMap Old Lead records (null on insert)
     */
    public static void assignProviderPracticeLeadTerritory(
        List<Lead> leads,
        Map<Id, Lead> oldLeadsMap
    ) {
        if (leads == null || leads.isEmpty()) {
            return;
        }

        EligibleLeadsData data = collectEligibleLeadsData(leads, oldLeadsMap);
        if (data.eligibleLeads.isEmpty()) {
            return;
        }

        try {
            deleteExistingOt2aForLeads(data.leadIdsToDeleteOt2a);
            Map<Id, Id> practiceToTerritory = buildPracticeToTerritoryMap(data.practiceIds);
            Map<String, Id> postalToTerritory = buildPostalToTerritoryMap(data.postalCodes);
            List<ObjectTerritory2Association> ot2aToInsert = buildOt2aRecordsForLeads(
                data.eligibleLeads,
                practiceToTerritory,
                postalToTerritory
            );

            if (ot2aToInsert.isEmpty()) {
                return;
            }

            Database.insert(ot2aToInsert, false, AccessLevel.SYSTEM_MODE);

            if (ConstantsUtil.customExceptionSwitch && Test.isRunningTest()) {
                throw new MyCustomException('customExceptionSwitch is turned on');
            }
        } catch (Exception e) {
            Logger.error(
                'Error in assignProviderPracticeLeadTerritory: ' + e.getMessage(),
                data.eligibleLeads,
                e
            )
                .addTag(ConstantsUtil.ASIM_TAG);
            Logger.saveLog();
        }
    }

    /**
     * @description Holds collected data for eligible Provider Practice Leads
     */
    private class EligibleLeadsData {
        /** Eligible leads for territory assignment */
        List<Lead> eligibleLeads;
        /** Practice IDs for territory lookup (Path 1) */
        Set<Id> practiceIds;
        /** Postal codes for territory lookup (Path 2) */
        Set<String> postalCodes;
        /** Lead IDs whose existing OT2A must be removed on update */
        Set<Id> leadIdsToDeleteOt2a;

        EligibleLeadsData() {
            this.eligibleLeads = new List<Lead>();
            this.practiceIds = new Set<Id>();
            this.postalCodes = new Set<String>();
            this.leadIdsToDeleteOt2a = new Set<Id>();
        }
    }

    /**
     * @description Collects eligible Provider Practice Leads and IDs for territory lookup
     * @param leads New/updated Lead records to evaluate
     * @param oldLeadsMap Old Lead records (null on insert)
     * @return EligibleLeadsData containing eligibleLeads, practiceIds, postalCodes, leadIdsToDeleteOt2a
     */
    private static EligibleLeadsData collectEligibleLeadsData(List<Lead> leads, Map<Id, Lead> oldLeadsMap) {
        EligibleLeadsData data = new EligibleLeadsData();
        for (Lead lead : leads) {
            Lead oldLead = oldLeadsMap != null ? oldLeadsMap.get(lead.Id) : null;
            if (!isLeadEligibleForTerritoryAssignment(lead, oldLead)) {
                continue;
            }
            data.eligibleLeads.add(lead);
            if (lead.Practice__c != null) {
                data.practiceIds.add(lead.Practice__c);
            } else if (String.isNotBlank(lead.PostalCode)) {
                data.postalCodes.add(lead.PostalCode);
            }
            if (oldLead != null) {
                data.leadIdsToDeleteOt2a.add(lead.Id);
            }
        }
        return data;
    }

    /**
     * @description Determines if a lead is eligible for territory assignment
     * @param lead Current Lead record
     * @param oldLead Previous Lead record (null on insert)
     * @return true if Provider_Practice_Lead RT with Practice or PostalCode, and insert or Practice/PostalCode changed
     */
    private static Boolean isLeadEligibleForTerritoryAssignment(Lead lead, Lead oldLead) {
        if (lead.RecordTypeId != ConstantsUtil.LEAD_PROVIDERPRACTICE_RT) {
            return false;
        }
        if (lead.Practice__c == null && String.isBlank(lead.PostalCode)) {
            return false;
        }
        if (oldLead == null) {
            return true;
        }
        return lead.Practice__c != oldLead.Practice__c || lead.PostalCode != oldLead.PostalCode;
    }

    /**
     * @description Deletes existing manual OT2A records for updated leads
     * @param leadIds Set of Lead IDs whose OT2A records should be removed
     */
    private static void deleteExistingOt2aForLeads(Set<Id> leadIds) {
        if (leadIds.isEmpty()) {
            return;
        }
        List<ObjectTerritory2Association> ot2aToDelete = [
            SELECT Id
            FROM ObjectTerritory2Association
            WHERE ObjectId IN :leadIds
            AND AssociationCause = :ConstantsUtil.TERRITORY2_MANUAL_AC
            WITH SYSTEM_MODE
        ];
        if (!ot2aToDelete.isEmpty()) {
            Database.delete(ot2aToDelete, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Builds Practice Id to Territory2 Id map from Practice OT2A (Territory2AssignmentRule)
     * @param practiceIds Set of Practice IDs to look up
     * @return Map of Practice Id to Territory2 Id
     */
    private static Map<Id, Id> buildPracticeToTerritoryMap(Set<Id> practiceIds) {
        Map<Id, Id> practiceToTerritory = new Map<Id, Id>();
        if (practiceIds.isEmpty()) {
            return practiceToTerritory;
        }
        for (ObjectTerritory2Association ot2a : [
            SELECT ObjectId, Territory2Id
            FROM ObjectTerritory2Association
            WHERE AssociationCause = :ConstantsUtil.TERRITORY2_ASSIGNMENT_RULE_AC
            AND Territory2.Territory2Model.State = 'Active'
            AND ObjectId IN :practiceIds
            WITH SYSTEM_MODE
        ]) {
            practiceToTerritory.put(ot2a.ObjectId, ot2a.Territory2Id);
        }
        return practiceToTerritory;
    }

    /**
     * @description Builds PostalCode to Territory2 Id map via ZipCode__c and Territory_Name__c lookup
     * @param postalCodes Set of postal codes to look up
     * @return Map of PostalCode to Territory2 Id
     */
    private static Map<String, Id> buildPostalToTerritoryMap(Set<String> postalCodes) {
        Map<String, Id> postalToTerritory = new Map<String, Id>();
        if (postalCodes.isEmpty()) {
            return postalToTerritory;
        }
        List<ZipCode__c> zipCodes = [
            SELECT Name, Territory_Name__r.Territory_Developer_Name__c
            FROM ZipCode__c
            WHERE Name IN :postalCodes
            AND Territory_Name__r.Territory_Developer_Name__c != null
            WITH SYSTEM_MODE
        ];
        if (zipCodes.isEmpty()) {
            return postalToTerritory;
        }
        Set<String> devNames = new Set<String>();
        for (ZipCode__c zc : zipCodes) {
            devNames.add(zc.Territory_Name__r.Territory_Developer_Name__c);
        }
        Map<String, Territory2> territoryByDevName = new Map<String, Territory2>();
        for (Territory2 t2 : [
            SELECT Id, DeveloperName
            FROM Territory2
            WHERE DeveloperName IN :devNames
            AND Territory2Model.State = 'Active'
            WITH SYSTEM_MODE
        ]) {
            territoryByDevName.put(t2.DeveloperName, t2);
        }
        for (ZipCode__c zc : zipCodes) {
            Territory2 t2 = territoryByDevName.get(zc.Territory_Name__r.Territory_Developer_Name__c);
            if (t2 != null) {
                postalToTerritory.put(zc.Name, t2.Id);
            }
        }
        return postalToTerritory;
    }

    /**
     * @description Builds OT2A records for eligible leads (Practice territory takes precedence over PostalCode)
     * @param eligibleLeads List of eligible Lead records
     * @param practiceToTerritory Map of Practice Id to Territory2 Id
     * @param postalToTerritory Map of PostalCode to Territory2 Id
     * @return List of ObjectTerritory2Association records ready for insert
     */
    private static List<ObjectTerritory2Association> buildOt2aRecordsForLeads(
        List<Lead> eligibleLeads,
        Map<Id, Id> practiceToTerritory,
        Map<String, Id> postalToTerritory
    ) {
        List<ObjectTerritory2Association> ot2aToInsert = new List<ObjectTerritory2Association>();
        for (Lead lead : eligibleLeads) {
            Id territoryId = lead.Practice__c != null
                ? practiceToTerritory.get(lead.Practice__c)
                : postalToTerritory.get(lead.PostalCode);
            if (territoryId != null) {
                ot2aToInsert.add(
                    new ObjectTerritory2Association(
                        ObjectId = lead.Id,
                        Territory2Id = territoryId,
                        AssociationCause = ConstantsUtil.TERRITORY2_MANUAL_AC
                    )
                );
            }
        }
        return ot2aToInsert;
    }

    /**
     * @description Exception class for Lead Service
     */
    public class MyCustomException extends Exception {}
}