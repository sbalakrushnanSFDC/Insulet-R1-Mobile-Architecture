/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 1st Oct 2025
 * @description : Handles all trigger logic for the Lead object
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       1st Oct 2025        Bijayalaxmi Prusty      Initial Version(US - NGASIM-379)
 * V1.0.1       6th Oct 2025        Shailja Jain            US NGOMCT- 343
 * V1.0.2       9th Oct 2025        Ramesh Dhaka            US NGOMCT- 202
 * V1.1.0       15th Oct 2025       Bijayalaxmi Prusty      Modifed(US - NGASIM-380)
 * V1.1.1       16th Oct 2025       Ramesh Dhaka            Modified(NGOMCT- 508)
 * V1.1.2       30th Oct 2025       Bijayalaxmi Prusty      Modified(US - NGASIM-219)
 * V1.1.3       6th Nov 2025        Bijayalaxmi Prusty      Modified(US - NGASIM-622)
 * V1.1.4       14th Nov 2025       Charchit N.             Modified(US - NGASIM-1223)
 * V1.1.5       17th Nov 2025.      Srinivas Shanigarapu    Modified(US - NGOMCT-469)
 * V1.1.6       26th Nov 2025       Bijayalaxmi Prusty      Modified(US - NGASIM-1050)
 * V1.2.0       11th Dec 2025       Bijayalaxmi Prusty      Modified(US - NGASIM-368)
 * V1.2.1       11th Dec 2025       Jatin Butta             Modified(US - NGASIM-1273) - Added Task Generation and Spanish Language
 * V1.2.2		16th JAN 2026		Shashank Nigam			Updated(US - NGOMCT-1719) Removed assignExternalTrainerTerritoryToLeads
 * V1.2.2		29th JAN 2026		Priyansh Shukla			Updated(US - NGASIM-2120)
 * V1.2.3		26th Feb 2026		Saikat Ghosh			Updated(US - NGASIM-1722) - Provider Practice Lead Territory Assignment
 */
public with sharing class LeadTriggerHandler extends TriggerHandler {


    /**
     * @description Handles the before insert trigger logic for the Lead object
     * @param newRecords The list of new Lead records
     */
    public override void beforeInsert(List<SObject> newRecords){
        List<Lead> leadsToProcess = (List<Lead>) newRecords;

        // Set Spanish Primary Language for Empezar leads (NGASIM-1273)
        LeadService.setSpanishPrimaryLanguage(leadsToProcess);

        ProductRecommendationHandler.processProductRecommendations(leadsToProcess,null);
        LeadDuplicateMatchingService.processLeadDuplicateMatching(leadsToProcess, null);
        TerritoryAssignmentService.assignTerritoryToLeads(leadsToProcess, null);
        ProviderPracticeLeadMatchingService.processProviderPracticeMatching(leadsToProcess, null);
    }

    /**
     * @description Handles the after insert trigger logic for the Lead object
     * @param newRecordsMap The map of new Lead records
     */
    public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        List<Lead> leadsToProcess = (List<Lead>) newRecordsMap?.values();
        IndividualHandler.manageIndividuals(leadsToProcess);

        // Process duplicate lead conversion after matching has been completed
        LeadDuplicateMatchingService.processDuplicateLeadConversion(leadsToProcess);

        // Filter and process automatic Patient lead conversion
        ObjectTerritory2AService.createOT2ARecords(leadsToProcess,null,Lead.SobjectType);

        LeadService.assignProviderPracticeLeadTerritory(leadsToProcess, null);// Added as part of NGASIM-1722 to Assign territory for Provider_Practice_Lead

        // Generate automated tasks based on Task Generation Rules (NGASIM-1273)
        LeadService.generateTasksForLeads(leadsToProcess, ConstantsUtil.INSERT_OPERATION);
    }

    /**
     * @description Handles the before update trigger logic for the Lead object
     * @param newRecordsMap The map of new Lead records
     * @param oldRecordsMap The map of old Lead records
     */
    public override void beforeUpdate(Map<Id,SObject> newRecordsMap,Map<Id,SObject> oldRecordsMap){
        List<Lead> leadsToProcess = (List<Lead>) newRecordsMap?.values();
        Map<Id,Lead> oldLeadsMap = (Map<Id,Lead>) oldRecordsMap;

        // Set Spanish Primary Language for Empezar leads (NGASIM-1273)
        LeadService.setSpanishPrimaryLanguage(leadsToProcess);

        ProductRecommendationHandler.processProductRecommendations(leadsToProcess,oldLeadsMap);
        LeadDuplicateMatchingService.processLeadDuplicateMatching(leadsToProcess, oldLeadsMap);
        TerritoryAssignmentService.assignTerritoryToLeads(leadsToProcess, oldLeadsMap);
        ProviderPracticeLeadMatchingService.processProviderPracticeMatching(leadsToProcess, oldLeadsMap);
    }

    /**
     * @description Handles the after update trigger logic for the Lead object
     * @param updatedRecordsMap The map of new Lead records
     * @param oldRecordsMap The map of old Lead records
     */
    public override void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<Lead> updatedleadsMap = (List<Lead>) updatedRecordsMap?.values();
        Map<Id,Lead> oldLeadsMap = (Map<Id,Lead>) oldRecordsMap;
	
        IndividualHandler.manageUpdateIndividuals(updatedleadsMap, oldLeadsMap);

        // Process duplicate lead conversion after matching has been completed
        LeadDuplicateMatchingService.processDuplicateLeadConversion(updatedleadsMap);

        LeadConversionHandler.processLeadConversion(updatedleadsMap,oldLeadsMap);
        // Filter and process automatic Patient lead conversion
        ObjectTerritory2AService.createOT2ARecords(updatedleadsMap,oldRecordsMap,Lead.SobjectType);

        LeadService.assignProviderPracticeLeadTerritory(updatedleadsMap, oldLeadsMap);// Added as part of NGASIM-1722 to Assign territory for Provider_Practice_Lead

        // Generate automated tasks based on Task Generation Rules (NGASIM-1273)
        LeadService.generateTasksForLeads(updatedleadsMap, ConstantsUtil.UPDATE_OPERATION);
    }
}