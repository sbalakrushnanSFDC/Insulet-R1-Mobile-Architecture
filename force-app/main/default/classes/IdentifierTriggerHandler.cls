/**
 * Handler class that contains all business logic for Identifier triggers.
 * Extends TriggerHandler to provide structured trigger context handling.
 * 
 * @author      Saikat Ghosh
 * @created     30th Jan 2026
 *
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       30th Jan 2026       Saikat Ghosh       (US - NGOMCT-1750) Initial version – Identifier trigger handler setup
 */
public with sharing class IdentifierTriggerHandler extends TriggerHandler {

    /**
     * @description Handles before insert trigger context for Identifier
     *              and delegates processing to the service class.
     * @param newRecords List of new Identifier records
     */
    public override void beforeInsert(List<SObject> newRecords) {
        IdentifierService.populateIdValueWithUUID((List<Identifier>) newRecords);
    }
}