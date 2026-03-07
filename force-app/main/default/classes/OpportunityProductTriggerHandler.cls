/**
 * @author      : Saikat Ghosh
 * @created Date: 30th Jan 2026
 * @description : Handler class that contains all business logic for Opportunity Product triggers.
 *                This class extends TriggerHandler and provides after-insert logic for OpportunityLineItem records.
 *
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       30th Jan 2026       Saikat Ghosh       (US - NGOMCT-1750)Initial version – Opportunity Product trigger handler setup
 */

public with sharing class OpportunityProductTriggerHandler extends TriggerHandler {

	/**
     * @description Handles after-insert logic for Opportunity Products.
     *              All processing is delegated to SendtoAspnHandler
     *              to keep trigger handler lightweight.
     * @param newRecordsMap Map of newly inserted Opportunity Product records keyed by their IDs
     */
    public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        SendtoAspnHandler.handleOpportunityProductAfterInsert(newRecordsMap);
    }
    
}