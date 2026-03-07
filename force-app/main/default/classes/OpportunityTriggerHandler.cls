/**
 * @author      : Anup Bandawar
 * @created Date: 26th Nov 2025
 * @description : Handles all trigger logic for the Opportunity object
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       26th Nov 2025       Anup Bandawar      Initial Version(US - NGOMCT-725)
 * V1.0.1       02nd Dec 2025       Rajasekar M        Added beforeUpdate validation for cancellation (US - NGOMCT-839)
 * V1.0.2       15th Dec 2025       Anup Bandawar      Added default Opportunity Source logic (US - NGOMCT-1202)
 * V1.0.3       29th Dec 2025       Charchit Nirayanwal Updated(US - NGOMCT-1358) - Added Insulet source logic in afterInsert only
 * V1.0.4       09th Jan 2026       Charchit Nirayanwal Added ASPN Sub-Status to Opportunity Stage mapping (US - NGASIM-1660)
 * V1.0.5       22nd Jan 2026       Sushanth Shetty     Added generateTasksForOpportunities method in afterInsert (US - NGASIM-1274)
 * V1.0.6       20th Feb 2026       Ayush Sharma        Added clearInactivityAlertOnSubStatusUpdate method in beforeupdate (US - NGOMCT-482)
 * V1.0.7       23rd Feb 2026       Lokesh P            Added setPrimaryCampaign method in beforeInsert (NGASIM-2061)
 */

/**
 * @description Trigger handler class for Opportunity object that extends TriggerHandler framework.
 *              Implements trigger logic for before/after insert/update operations including:
 *              - Setting default Opportunity Source
 *              - Validating and applying cancellation rules
 *              - Updating Stage based on ASPN Sub-Status mapping
 *              - Generating automated tasks based on Task Generation Rules
 *              - Processing opportunities for ASPN integration
 * @see TriggerHandler
 * @see OpportunityService
 */
public with sharing class OpportunityTriggerHandler extends TriggerHandler {

    /**
     * @description Handles the before insert trigger logic for the Opportunity object
     *              Sets default Opportunity_Source__c, validates cancellation rules,
     *              and updates Stage based on Sub_Status__c
     * @param newRecords The list of new Opportunity records
     */
    public override void beforeInsert(List<SObject> newRecords) {
        List<Opportunity> newOpportunities = (List<Opportunity>) newRecords;

        // Set default Opportunity Source to 'Insulet' if blank
        OpportunityService.setDefaultOpportunitySource(newOpportunities);

        // Validate cancellation rules
        OpportunityService.validateAndApplyCancellationRules(
            newOpportunities,
            null
        );

        // Update Opportunity Stage based on ASPN Sub-Status mapping (NGASIM-1660)
        OpportunityService.updateStageFromSubStatus(newOpportunities, null);
        // Set Primary Campaign for Opportunities (NGASIM-2061)
        OpportunityService.setPrimaryCampaign(newOpportunities);
    }

    /**
     * @description Handles the before update trigger logic for the Opportunity object
     *              Delegates to OpportunityService for cancellation validation and
     *              updates Stage based on Sub_Status__c
     * @param updatedRecordsMap The map of updated Opportunity records
     * @param oldRecordsMap The map of old Opportunity records
     */
    public override void beforeUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<Opportunity> updatedOpportunities = (List<Opportunity>) updatedRecordsMap?.values();
        Map<Id, Opportunity> oldOpportunitiesMap = (Map<Id, Opportunity>) oldRecordsMap;

        // Validate cancellation rules
        OpportunityService.validateAndApplyCancellationRules(
            (List<Opportunity>) updatedRecordsMap?.values(),
            (Map<Id, Opportunity>) oldRecordsMap
        );

        // Update Opportunity Stage based on ASPN Sub-Status mapping (NGASIM-1660)
        OpportunityService.updateStageFromSubStatus(updatedOpportunities, oldOpportunitiesMap);

        // Clear ASPN_Inactivity_Alert__c when Sub_Status__c is updated (NGOMCT-482)
        AspnInactivityAlertService.clearInactivityAlertOnSubStatusUpdate(updatedOpportunities, oldOpportunitiesMap);
    }

    /**
     * @description Handles the after insert trigger logic for the Opportunity object
     * Per NGOMCT-1358: Handles Insulet source opportunities when Patient has existing Custom_UniqueID__c
     * @param newRecordsMap The map of new Opportunity records
     */
    public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        List<Opportunity> opptyToProcess = (List<Opportunity>) newRecordsMap?.values();

        // Generate automated tasks based on Task Generation Rules
        OpportunityService.generateTasksForOpportunities(opptyToProcess,ConstantsUtil.INSERT_OPERATION);

        SendtoAspnHandler.processOpportunitiesOnInsert(opptyToProcess);
    }

    /**
     * @description Handles the after update trigger logic for the Opportunity object
     * Per NGOMCT-1358: Removed Insulet source logic from afterUpdate (only in afterInsert)
     * Per NGOMCT-1358: Removed 'Send to ASPN' stage check - only processes Cancel_Order__c changes
     * Per NGOMCT-484: Added logic to create asset when opportunity with Dash product and APSN source is closed won.
     * @param updatedRecordsMap The map of new Opportunity records
     * @param oldRecordsMap The map of old Opportunity records
     */
    public override void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        List<Opportunity> updatedOpportunities = (List<Opportunity>) updatedRecordsMap?.values();
        Map<Id, Opportunity> oldOpportunitiesMap = (Map<Id, Opportunity>) oldRecordsMap;
        SendtoAspnHandler.processOpportunitiesOnUpdate(updatedOpportunities, oldOpportunitiesMap);
        AssetProcessingHandler.processOpportunitiesOnUpdate(updatedOpportunities,oldOpportunitiesMap);
        
   
    }
}