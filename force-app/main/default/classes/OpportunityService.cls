/**
* @description Service class to handle Opportunity updates that are
            required after Lead conversion. This class builds the
            Opportunity name from Lead fields and performs bulk-safe
            updates with partial-failure handling.
* Created Date : Oct 02, 2025
* Created By   : Sunil Khanchandani
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Oct 02, 2025       Sunil Khanchandani       Initial Version
 * V1.0.1       Dec 01, 2025       Bijayalaxmi Prusty       Modified(US - NGASIM - 1050)
 * V1.0.2       Dec 02, 2025       Rajasekar M              Added cancellation validation (US - NGOMCT-839)
 * V1.0.3       Dec 03, 2025       Rajasekar M              Refactored cancellation helper (US - NGOMCT-839)
 * V1.0.4       Dec 15, 2025       Anup Bandawar            Added setDefaultOpportunitySource method (US - NGOMCT-1202)
 * V1.0.5       Jan 09, 2026       Charchit Nirayanwal      Added updateStageFromSubStatus method (US - NGASIM-1660)
 * V1.0.6       Jan 22, 2026       Sushanth Shetty          Added generateTasksForOpportunities method (US - NGASIM-1274)
 * V1.0.7       Feb 16, 2026       Sushanth Shetty          Added hasLogs flag to save log only if there are any logs (US - NGASIM-1274)
 * V1.0.8       Feb 23, 2026       Lokesh P                 Added setPrimaryCampaign method (US - NGASIM-2061)
 * V1.0.9       Feb 23, 2026       Ayushi Gaikwad           Updated Opp Name update to follow naming convention (US - NGOMCT-2366)
 */

 public inherited sharing class OpportunityService {

    public static String errorTagName;
    public static Map<Id,Lead> opportunityIdLeadMap;

    /**
     * @description Update Opportunity names for Leads that were converted.
     * @param convertedLeads list of leads that have been converted
     * @param tagName        tag name for logging context
     */
    public static void updateConvertedOpportunities(List<Lead> convertedLeads, String tagName) {
        if (convertedLeads == null || convertedLeads.isEmpty()) {
            return;
        }

        errorTagName = tagName;

        List<Opportunity> opportunitiesToUpdate = buildOpportunitiesFromLeads(convertedLeads);

        if (!opportunitiesToUpdate.isEmpty()) {
            updateOpportunities(opportunitiesToUpdate);
        }
    }

/**
 * @description Returns a map of existing Opportunity records queried using the provided Opportunity Ids.
 * @param oppIds Set of Opportunity Ids to query
 * @return Map of Id and corresponding Opportunity record
 */

    private static Map<Id, Opportunity> getExistingOpportunities(Set<Id> oppIds){
        // Fetch existing Opportunity records to compare timestamps
        Map<Id, Opportunity> existingOppsMap = new Map<Id, Opportunity>(
            [SELECT Id, Name, CreatedDate FROM Opportunity WHERE Id IN :oppIds WITH USER_MODE]
        );
        return existingOppsMap;
    }

    private static List<Opportunity> checkExistingOpportunity(Set<Id> convertedOpportunityIdSet, List<Lead> convertedLeads){
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        Map<Id,Opportunity> existingOpportunities = getExistingOpportunities(convertedOpportunityIdSet);
        for(Lead convertedLead:convertedLeads){

            Opportunity opp = existingOpportunities.get(convertedLead.ConvertedOpportunityId);

            // Check if Opportunity is newly created (within 5 seconds of Lead modification)
            if(opp != null){
                if (opp.CreatedDate == convertedLead.LastModifiedDate ||
                    Math.abs(opp.CreatedDate.getTime() - convertedLead.LastModifiedDate.getTime()) < 5000) {
                    // Build updated Opportunity record
                    Opportunity oppToUpdate = prepareOpportunityFromLead(convertedLead);
                    opportunitiesToUpdate.add(oppToUpdate);
                    // Build updated Opportunity record
                }
            }
    }
        return opportunitiesToUpdate;
    }
    /**
     * @description Build a list of Opportunity sObjects from converted Leads.
     *              Extracted to reduce cyclomatic complexity in public method.
     *
     * @param convertedLeads list of converted leads
     * @return list of Opportunity records (only Id + Name set)
     */
    private static List<Opportunity> buildOpportunitiesFromLeads(List<Lead> convertedLeads) {
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        Set<Id> convertedOpportunityId = new Set<Id>();
       //  opportunityIdLeadMap =  new Map<Id,Lead>();
        for (Lead leadRecord : convertedLeads) {
            if (leadRecord.ConvertedOpportunityId != null) {
                convertedOpportunityId.add(leadRecord.ConvertedOpportunityId);
            }
        }
        opportunitiesToUpdate = checkExistingOpportunity(convertedOpportunityId, convertedLeads);
        return opportunitiesToUpdate;
    }

     /**
     * @description Method to get Opportunity Name following the Naming Convention
     * @return String representing updated Opportunity Name
     */
    public static String getBenefitsInvestigationOpportunityName() {
        return System.Label.Opportunity_Name_Prefix + '-' + Datetime.now().format('MM/dd/yyyy');
    }

    @TestVisible
    private static Opportunity prepareOpportunityFromLead(Lead leadRecord) {
        //Update Opportunity name to follow the naming convention
        String oppNewName = getBenefitsInvestigationOpportunityName();

        // Update Opportunity record
        Opportunity oppRecord = new Opportunity(
            Id = leadRecord.ConvertedOpportunityId,
            Name = oppNewName,
            OwnerId = UserInfo.getUserId()
        );
        return oppRecord;
    }

// ========== TASK GENERATION METHODS ==========

/**
 * @description Generates automated tasks for opportunities based on Task Generation Rules.
 *              This method is called from trigger handler to ensure tasks are created
 *              when opportunities meet the rule criteria defined in Custom Metadata.
 *              Uses TaskGenerationService with FormulaEval for dynamic condition evaluation.
 *              Filters rules by trigger event to reduce the number of rules evaluated.
 * @param opportunities List of Opportunity records to process for task generation
 * @param triggerEvent Event type: ConstantsUtil.INSERT_OPERATION
 */
public static void generateTasksForOpportunities(List<Opportunity> opportunities, String triggerEvent) {
    if (opportunities == null || opportunities.isEmpty()) {
        return;
    }

    try {
        // Build task generation requests for all opportunities
        List<TaskGenerationService.TaskRequest> requests = new List<TaskGenerationService.TaskRequest>();

        for (Opportunity opp : opportunities) {
            TaskGenerationService.TaskRequest request = new TaskGenerationService.TaskRequest();
            request.recordId = opp.Id;
            request.objectApiName = ConstantsUtil.OPPORTUNITY_OBJECT;
            request.triggerEvent = triggerEvent;
            requests.add(request);
        }

        // Call the task generation service
        List<TaskGenerationService.TaskResult> results = TaskGenerationService.createTasks(requests);
        Boolean hasLogs = false;

        // Log results for monitoring and debugging
        for (TaskGenerationService.TaskResult result : results) {
            if (result.success && result.tasksCreated > 0) {
                Logger.info('Created ' + result.tasksCreated + ' task(s) for opportunities. Message: ' + result.message)
                    .addTag(ConstantsUtil.OPPORTUNITY_SERVICE_CLASS);
                hasLogs = true;
            } else if (!result.success) {
                Logger.warn('Task generation warning: ' + result.message)
                    .addTag(ConstantsUtil.OPPORTUNITY_SERVICE_CLASS);
                hasLogs = true;
            }
        }
        if (hasLogs) {
            Logger.saveLog();
        }

        /**
         * when customExceptionSwitch static variable is turned on
         * it covers exceptions in test coverage
         */
        if (ConstantsUtil.customExceptionSwitch && Test.isRunningTest()) {
            throw new CustomException('customExceptionSwitch is turned on');
        }

    } catch (Exception e) {
        // Log error but don't throw to avoid blocking the entire transaction
        Logger.error('Error in generateTasksForOpportunities: ' + e.getMessage(), e)
            .addTag(ConstantsUtil.OPPORTUNITY_SERVICE_CLASS);
        Logger.saveLog();
    }
}
    /**
     * @description Performs a bulk update of Opportunities using Database.update(..., false)
     *              to avoid full transaction rollback on partial failures.
     *              Logs per-record failures via Nebula Logger.
     *
     * @param opportunitiesToUpdate list of Opportunity records to update
     */
    @TestVisible
    private static void updateOpportunities(List<Opportunity> opportunitiesToUpdate) {
        if(opportunitiesToUpdate.isEmpty() || !Schema.SObjectType.Opportunity.isUpdateable()){
            logDebug('Records list is empty or User does not have permission to update opportunity record');
            return;
        }

        Database.SaveResult[] results = Database.update(opportunitiesToUpdate, false);
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult sr = results[i];
            if (!sr.isSuccess()) {
                // Log each error with record context for easier debugging.
                for (Database.Error err : sr.getErrors()) {
                    Logger.error('Failed to update Opportunity record: ' + err.getMessage(), sr)
                        .setRecord(opportunitiesToUpdate[i])
                        .addTag(errorTagName);
                }
            }
        }
    }

    /**
     * @description Logs debug messages using Logger framework
     * @param message The debug message
     */
    private static void logDebug(String message) {
        Logger.debug(message);
        Logger.saveLog();
    }

    /**
     * @description Validates and applies cancellation rules for Opportunity updates.
     *              Filters opportunities where Cancel_Order__c changed from FALSE to TRUE
     *              and validates if cancellation is allowed based on Status/SubStatus combination.
     *              Adds validation error to records that cannot be cancelled.
     * @param updatedOpportunities List of updated Opportunity records
     * @param oldOpportunitiesMap Map of old Opportunity records before update
     */
    public static void validateAndApplyCancellationRules(List<Opportunity> updatedOpportunities, Map<Id, Opportunity> oldOpportunitiesMap) {
        OpportunityServiceHelper.validateAndApplyCancellationRules(updatedOpportunities, oldOpportunitiesMap);
    }

    /**
     * @description Sets Opportunity_Source__c to 'Insulet' if it is blank.
     *              This method is called from beforeInsert trigger to ensure all opportunities
     *              have a default source value when created.
     * @param newOpportunities List of new Opportunity records
     */
    public static void setDefaultOpportunitySource(List<Opportunity> newOpportunities) {
        if (newOpportunities == null || newOpportunities.isEmpty()) {
            return;
        }

        for (Opportunity opp : newOpportunities) {
            // Set Opportunity_Source__c to 'Insulet' if it's blank
            if (String.isBlank(opp.Opportunity_Source__c) && opp.RecordTypeId != null && opp.RecordTypeId == ConstantsUtil.OPPORTUNITY_NCS_RT) {
                opp.Opportunity_Source__c = ConstantsUtil.OPPORTUNITY_SOURCE_INSULET;
            }
        }
    }

    /**
     * @description Updates Opportunity StageName based on Sub_Status__c value using
     *              ASPN_SubStatus_to_OppStage__mdt custom metadata mapping.
     *              Only updates when Sub_Status__c has changed and a mapping exists.
     * @param updatedOpportunities List of updated Opportunity records
     * @param oldOpportunitiesMap Map of old Opportunity records before update (null for insert)
     */
    public static void updateStageFromSubStatus(List<Opportunity> updatedOpportunities, Map<Id, Opportunity> oldOpportunitiesMap) {
        if (updatedOpportunities == null || updatedOpportunities.isEmpty()) {
            return;
        }

        Map<String, List<Opportunity>> subStatusToOppsMap = collectOpportunitiesWithChangedSubStatus(updatedOpportunities, oldOpportunitiesMap);

        if (subStatusToOppsMap.isEmpty()) {
            return;
        }

        applyStageFromSubStatusMappings(subStatusToOppsMap);
    }

    /**
     * @description Collects opportunities where Sub_Status__c has changed into a map grouped by Sub_Status value.
     * @param opportunities List of Opportunity records to process
     * @param oldOpportunitiesMap Map of old Opportunity records (null for insert scenario)
     * @return Map of Sub_Status values to their corresponding Opportunities
     */
    private static Map<String, List<Opportunity>> collectOpportunitiesWithChangedSubStatus(
        List<Opportunity> opportunities,
        Map<Id, Opportunity> oldOpportunitiesMap
    ) {
        Map<String, List<Opportunity>> subStatusToOppsMap = new Map<String, List<Opportunity>>();

        for (Opportunity opp : opportunities) {
            if (String.isBlank(opp.Sub_Status__c)) {
                continue;
            }

            if (hasSubStatusChanged(opp, oldOpportunitiesMap)) {
                addOpportunityToSubStatusMap(subStatusToOppsMap, opp);
            }
        }
        return subStatusToOppsMap;
    }

    /**
     * @description Checks if Sub_Status__c has changed for the given opportunity.
     * @param opp Current Opportunity record
     * @param oldOpportunitiesMap Map of old Opportunity records (null for insert scenario)
     * @return True if Sub_Status changed or if it's an insert with Sub_Status value
     */
    private static Boolean hasSubStatusChanged(Opportunity opp, Map<Id, Opportunity> oldOpportunitiesMap) {
        if (oldOpportunitiesMap == null) {
            return true; // Insert scenario - Sub_Status__c has a value
        }
        Opportunity oldOpp = oldOpportunitiesMap.get(opp.Id);
        return oldOpp != null && opp.Sub_Status__c != oldOpp.Sub_Status__c;
    }

    /**
     * @description Adds an opportunity to the Sub_Status map, creating the list if needed.
     * @param subStatusMap Map to add the opportunity to
     * @param opp Opportunity to add
     */
    private static void addOpportunityToSubStatusMap(Map<String, List<Opportunity>> subStatusMap, Opportunity opp) {
        if (!subStatusMap.containsKey(opp.Sub_Status__c)) {
            subStatusMap.put(opp.Sub_Status__c, new List<Opportunity>());
        }
        subStatusMap.get(opp.Sub_Status__c).add(opp);
    }

    /**
     * @description Queries custom metadata mappings and applies stage values to opportunities.
     * @param subStatusToOppsMap Map of Sub_Status values to their corresponding Opportunities
     */
    private static void applyStageFromSubStatusMappings(Map<String, List<Opportunity>> subStatusToOppsMap) {
        List<ASPN_SubStatus_to_OppStage__mdt> mappings = [
            SELECT ASPN_Sub_Status__c, Opportunity_Stage__c
            FROM ASPN_SubStatus_to_OppStage__mdt
            WHERE ASPN_Sub_Status__c IN :subStatusToOppsMap.keySet()
            AND Opportunity_Stage__c != NULL
            WITH SYSTEM_MODE
        ];

        for (ASPN_SubStatus_to_OppStage__mdt mapping : mappings) {
            List<Opportunity> oppsForSubStatus = subStatusToOppsMap.get(mapping.ASPN_Sub_Status__c);
            for (Opportunity opp : oppsForSubStatus) {
                opp.StageName = mapping.Opportunity_Stage__c;
            }
        }
    }

    /**
     * @description Sets the Primary Campaign for Opportunities.
     * @param newOpportunities List of new Opportunity records
     */
    public static void setPrimaryCampaign(List<Opportunity> newOpportunities) {
        if (newOpportunities == null || newOpportunities.isEmpty()) {
            return;
        }

        Set<Id> accIds = new Set<Id>();
        for (Opportunity opp : newOpportunities) {
            if (opp.AccountId != null && opp.CampaignId == null) {
                accIds.add(opp.AccountId);
            }
        }

        if (accIds.isEmpty()) {
            return;
        }

        Map<Id, Account> accIdToAccMap = new Map<Id, Account>(
            [SELECT Id, PersonContactId 
            FROM Account 
            WHERE Id IN :accIds 
            AND PersonContactId != NULL
            WITH USER_MODE]
        );

        Map<Id, Id> contactToCampaignMap = getLatestCampaignMap(accIdToAccMap);

        for (Opportunity opp : newOpportunities) {
            if (opp.AccountId == null || opp.CampaignId != null) {
                continue;
            }

            Account acc = accIdToAccMap.get(opp.AccountId);
            if (acc == null || acc.PersonContactId == null) {
                continue;
            }

            Id campaignId = contactToCampaignMap.get(acc.PersonContactId);
            if (campaignId != null) {
                opp.CampaignId = campaignId;
            }
        }
    }


    /**
     * @description Fetches latest CampaignId for each Contact
     * @param accIdToAccMap Map of Account Ids to Account records
     * @return Map of Contact Ids to latest Campaign Id
     */
    private static Map<Id, Id> getLatestCampaignMap(Map<Id, Account> accIdToAccMap) {

        Set<Id> contactIds = new Set<Id>();
        for (Account acc : accIdToAccMap.values()) {
            if (acc.PersonContactId != null) {
                contactIds.add(acc.PersonContactId);
            }
        }

        if (contactIds.isEmpty()) {
            return new Map<Id, Id>();
        }

        Map<Id, Id> contactToCampaignMap = new Map<Id, Id>();

        for (Contact con : [
            SELECT Id,
                (SELECT CampaignId 
                    FROM CampaignMembers 
                    ORDER BY CreatedDate DESC 
                    LIMIT 1)
            FROM Contact
            WHERE Id IN :contactIds
            WITH USER_MODE
        ]) {
            if (!con.CampaignMembers.isEmpty()) {
                contactToCampaignMap.put(
                    con.Id,
                    con.CampaignMembers[0].CampaignId
                );
            }
        }

        return contactToCampaignMap;
    }
    /**
     * @description Custom checked exception type for OpportunityService
     */
    public class CustomException extends Exception {}
}