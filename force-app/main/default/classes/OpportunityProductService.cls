/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 15th Dec 2025
 * @description : Service class to handle mapping recommended product from Lead to Opportunity Line Items.
 *                Creates OpportunityLineItem records with Product2 matching the Recommended Product
 *                from Lead using US Standard price book.
 *  * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       15th Dec 2025       Bijayalaxmi Prusty      Initial Version(US - NGOMCT-824)
 * V1.0.1       11th Feb 2026       Saikat Ghosh      		Replaced US_STANDARD_PRICEBOOK_NAME with PRIMARY_PRICEBOOK
 */
public inherited sharing class OpportunityProductService {

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null for permission errors)
     */
    private static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    /**
     * @description Logs debug messages using Logger framework
     * @param message The debug message
     */
    @TestVisible
    private static void logDebug(String message) {
        Logger.debug(message);
        Logger.saveLog();
    }

    /**
     * @description Creates Opportunity Line Items based on OpportunityId to Product mapping
     * @param opportunityToProductMap Map of Opportunity Id to Recommended Product name
     * @param opportunities List of Opportunity records to update with pricebook
     */
    public static void createOpportunityLineItems(Map<Id, String> opportunityToProductMap, List<Opportunity> opportunities) {
        if (!isValidInput(opportunityToProductMap, opportunities)) {
            return;
        }

        try {
            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new OpportunityProductServiceException('customExceptionSwitch is turned on');
            }
            processOpportunityLineItemsCreation(opportunityToProductMap, opportunities);
        } catch (Exception ex) {
            for (Integer i = 0; i < opportunities.size(); i++) {
                logError('Failed to create OpportunityLineItem at index ' + i + '. Error: ' + ex.getMessage(),
                        new List<SObject>{opportunities[i]}, ex);
            }
        }
    }

    /**
     * @description Validates input parameters for createOpportunityLineItems
     * @param opportunityToProductMap Map of Opportunity Id to Recommended Product name
     * @param opportunities List of Opportunity records
     * @return Boolean indicating if input is valid
     */
    private static Boolean isValidInput(Map<Id, String> opportunityToProductMap, List<Opportunity> opportunities) {
        return opportunityToProductMap != null && !opportunityToProductMap.isEmpty() &&
               opportunities != null && !opportunities.isEmpty();
    }

    /**
     * @description Processes the creation of Opportunity Line Items
     * @param opportunityToProductMap Map of Opportunity Id to Recommended Product name
     * @param opportunities List of Opportunity records
     */
    @TestVisible
    private static void processOpportunityLineItemsCreation(Map<Id, String> opportunityToProductMap, List<Opportunity> opportunities) {
        Set<String> recommendedProducts = new Set<String>(opportunityToProductMap.values());

        Map<String, Product2> productMap = getProductsByName(recommendedProducts);
        if (productMap.isEmpty()) {
            return;
        }

        Pricebook2 standardPricebook = getStandardPricebook();
        if (standardPricebook == null) {
            return;
        }

        Map<Id, PricebookEntry> pricebookEntryMap = getPricebookEntries(productMap.values(), standardPricebook.Id);
        if (pricebookEntryMap.isEmpty()) {
            return;
        }

        updateOpportunitiesWithStandardPricebook(opportunities, standardPricebook.Id);

        List<OpportunityLineItem> lineItemsToInsert = buildOpportunityLineItemsWithMapping(
            opportunityToProductMap, productMap, pricebookEntryMap
        );

        if (!lineItemsToInsert.isEmpty()) {
            insertOpportunityLineItems(lineItemsToInsert);
        }
    }

    /**
     * @description Queries Product2 records by product names
     * @param productNames Set of product names to query
     * @return Map of product name to Product2 record
     */
    private static Map<String, Product2> getProductsByName(Set<String> productNames) {
        Map<String, Product2> productMap = new Map<String, Product2>();

        List<Product2> products = [
            SELECT Id, Name, ProductCode, IsActive
            FROM Product2
            WHERE Name IN :productNames
            AND IsActive = true
            WITH SYSTEM_MODE
        ];

        for (Product2 product : products) {
            productMap.put(product.Name, product);
        }

        return productMap;
    }

    /**
     * @description Gets the Standard Price Book record
     * @return Standard Price Book record or null if not found
     */
    private static Pricebook2 getStandardPricebook() {
        // Query for standard price book by name or IsStandard flag
        List<Pricebook2> pricebooks = [
            SELECT Id, Name, IsStandard
            FROM Pricebook2
            WHERE (Name = :ConstantsUtil.PRIMARY_PRICEBOOK)
            AND IsActive = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        return pricebooks.isEmpty() ? null : pricebooks[0];
    }
    /**
     * @description Gets Price Book Entries for given products and price book
     * @param products List of Product2 records
     * @param pricebookId Id of the price book
     * @return Map of Product2 Id to PricebookEntry record
     */
    @TestVisible
    private static Map<Id, PricebookEntry> getPricebookEntries(List<Product2> products, Id pricebookId) {
        Map<Id, PricebookEntry> pricebookEntryMap = new Map<Id, PricebookEntry>();

        if (products.isEmpty() || pricebookId == null) {
            return pricebookEntryMap;
        }

        Set<Id> productIds = new Set<Id>();
        for (Product2 product : products) {
            productIds.add(product.Id);
        }
        List<PricebookEntry> pricebookEntries = [
            SELECT Id, Product2Id, Pricebook2Id, UnitPrice, IsActive
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
            AND Pricebook2Id = :pricebookId
            AND IsActive = true
            WITH SYSTEM_MODE
        ];

        for (PricebookEntry entry : pricebookEntries) {
            pricebookEntryMap.put(entry.Product2Id, entry);
        }
        return pricebookEntryMap;
    }

    /**
     * @description Builds Opportunity Line Items using direct OpportunityId to Product mapping
     * @param opportunityToProductMap Map of Opportunity Id to Recommended Product name
     * @param productMap Map of product name to Product2 record
     * @param pricebookEntryMap Map of Product2 Id to PricebookEntry
     * @return List of OpportunityLineItem records to insert
     */
    private static List<OpportunityLineItem> buildOpportunityLineItemsWithMapping(
        Map<Id, String> opportunityToProductMap,
        Map<String, Product2> productMap,
        Map<Id, PricebookEntry> pricebookEntryMap
    ) {
        List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();

        // Get existing OpportunityLineItems to prevent duplicates
        Set<Id> opportunityIds = new Set<Id>(opportunityToProductMap.keySet());
        Set<Id> productIds = new Set<Id>();
        for (Product2 product : productMap.values()) {
            productIds.add(product.Id);
        }

        Map<String, OpportunityLineItem> existingLineItemsMap = new Map<String, OpportunityLineItem>();
        if (!opportunityIds.isEmpty() && !productIds.isEmpty()) {
            List<OpportunityLineItem> existingLineItems = [
                SELECT Id, OpportunityId, PricebookEntry.Product2Id
                FROM OpportunityLineItem
                WHERE OpportunityId IN :opportunityIds
                AND PricebookEntry.Product2Id IN :productIds
                WITH SYSTEM_MODE
            ];

            for (OpportunityLineItem item : existingLineItems) {
                String key = String.valueOf(item.OpportunityId) + '_' + String.valueOf(item.PricebookEntry.Product2Id);
                existingLineItemsMap.put(key, item);
            }
        }

        for (Id opportunityId : opportunityToProductMap.keySet()) {
            String recommendedProduct = opportunityToProductMap.get(opportunityId);

            // Get the product matching the recommended product
            Product2 product = productMap.get(recommendedProduct);
            if (product == null) {
                continue;
            }

            // Check if OpportunityLineItem already exists for this Opportunity and Product
            String duplicateKey = String.valueOf(opportunityId) + '_' + String.valueOf(product.Id);
            if (existingLineItemsMap.containsKey(duplicateKey)) {
                continue;
            }

            // Get the price book entry
            PricebookEntry pricebookEntry = pricebookEntryMap.get(product.Id);
            if (pricebookEntry == null) {
                continue;
            }

            // Create Opportunity Line Item
            OpportunityLineItem lineItem = new OpportunityLineItem(
                OpportunityId = opportunityId,
                PricebookEntryId = pricebookEntry.Id,
                Quantity = ConstantsUtil.DEFAULT_OPPORTUNITY_QUANTITY,
                UnitPrice = pricebookEntry.UnitPrice
            );

            lineItems.add(lineItem);
        }

        return lineItems;
    }

    /**
     * @description Inserts Opportunity Line Items with error handling
     * @param lineItems List of OpportunityLineItem records to insert
     */
    private static void insertOpportunityLineItems(List<OpportunityLineItem> lineItems) {
        // Check CRUD permissions before insert
        if (!Schema.SObjectType.OpportunityLineItem.isCreateable()) {
            logDebug('User does not have permission to create OpportunityLineItem records');
            return;
        }

        if (!lineItems.isEmpty()) {
            Database.insert(lineItems, false, AccessLevel.USER_MODE);
        }
    }
    /**
     * @description Updates Opportunities with standard pricebook if not already set
     * @param opportunities List of Opportunity records
     * @param standardPricebookId Id of the standard price book
     */
    private static void updateOpportunitiesWithStandardPricebook(List<Opportunity> opportunities, Id standardPricebookId) {
        // Check CRUD permissions before update
        if (!Schema.SObjectType.Opportunity.isUpdateable()) {
            logDebug('User does not have permission to update Opportunity records');
            return;
        }

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        // Check which opportunities need pricebook set
        for (Opportunity opp : opportunities) {
            if (opp.Pricebook2Id == null) {
                opportunitiesToUpdate.add(new Opportunity(
                    Id = opp.Id,
                    Pricebook2Id = standardPricebookId
                ));
            }
        }

        if (opportunitiesToUpdate.isEmpty()) {
            return;
        }

        Database.update(opportunitiesToUpdate, AccessLevel.USER_MODE);
    }

    /**
     * @description Custom exception class for OpportunityProductService
     */
    public class OpportunityProductServiceException extends Exception {}
}