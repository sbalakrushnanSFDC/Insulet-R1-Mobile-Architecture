/**
 * @description Handles all trigger logic for the Asset related operations
 * note: This needs to run in without sharing because integration user might not have view all
 * access on Asset
 * @author Ayush Shrivastava
 * @created Date 11th Feb 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Feb 2026       Ayush Shrivastava      Initial Version(US - NGOMCT-484)
 * V2.0.0       24th Feb 2026       Ayush Shrivastava      NGOMCT-2634
 * =======================================================================
 */

public without sharing class AssetProcessingHandler {
    
    /**
     * @description process closed won opportunities to create assets.
     * @param updatedOpportunities The list of updated Opportunity records
     * @param oldOpportunitiesMap The map of old Opportunity records
     */
    public static void processOpportunitiesOnUpdate(List<Opportunity> updatedOpportunities,Map<Id, Opportunity> oldOpportunitiesMap){
        
        Set<Id> opportunityIds = new Set<Id>();
        for(Opportunity opp : updatedOpportunities){
            if(oldOpportunitiesMap.get(opp.Id).Sub_Status__c  != opp.Sub_Status__c  && ConstantsUtil.OPPORTUNITY_SUB_STATUS_CHECK.contains(opp.Sub_Status__c)){
                opportunityIds.add(opp.Id);
            }
        }

        if(!opportunityIds.isEmpty()){
            System.enqueueJob(new AssetProcessingQueueable(opportunityIds));
        }
    }

}