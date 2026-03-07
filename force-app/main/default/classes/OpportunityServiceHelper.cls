/**
* @description Helper class to encapsulate Opportunity cancellation
*              validation logic invoked from OpportunityService before
*              update trigger execution.
* Created Date : Dec 03, 2025
* Created By   : Rajasekar M
* =========================== Logs ======================================
* Version      Modified Date       Modified By             Brief Note
* V1.0.0       Dec 03, 2025       Rajasekar M              Cancellation helper extraction
*/

public inherited sharing class OpportunityServiceHelper {

    // Cache for Custom Metadata Records to avoid repeated queries
    private static Set<String> allowedStatusSubStatusCombinations = null;

    /**
     * @description Validates and applies cancellation rules for Opportunity updates
     * @param updatedOpportunities List of updated Opportunity records
     * @param oldOpportunitiesMap Map of old Opportunity records before update
     */
    public static void validateAndApplyCancellationRules(List<Opportunity> updatedOpportunities, Map<Id, Opportunity> oldOpportunitiesMap) {
        if (updatedOpportunities == null || updatedOpportunities.isEmpty()) {
            return;
        }
        List<Opportunity> cancellationAttempts = collectCancellationAttempts(updatedOpportunities, oldOpportunitiesMap);
        if (cancellationAttempts.isEmpty()) {
            return;
        }
        loadAllowedCombinationsIfNeeded();
        addErrorsForInvalidCancellations(cancellationAttempts);
    }

    /**
     * @description Loads and caches allowed Status/SubStatus combinations from ASPN_Cancellation_Settings__mdt
     */
    private static void loadAllowedCombinationsIfNeeded() {
        if (allowedStatusSubStatusCombinations != null) {
            return;
        }

        allowedStatusSubStatusCombinations = new Set<String>();

        try {
            List<ASPN_Cancellation_Settings__mdt> cancellationSettings = [
                SELECT Status__c, Substatus__c
                FROM ASPN_Cancellation_Settings__mdt
                WHERE Status__c != null
                AND Substatus__c != null
                WITH USER_MODE
            ];

            for (ASPN_Cancellation_Settings__mdt setting : cancellationSettings) {
                String status = String.isNotBlank(setting.Status__c) ? setting.Status__c.trim() : '';
                String substatus = String.isNotBlank(setting.Substatus__c) ? setting.Substatus__c.trim() : '';

                if (String.isNotBlank(status) && String.isNotBlank(substatus)) {
                    allowedStatusSubStatusCombinations.add(status + '|' + substatus);
                }
            }
        } catch (Exception e) {
            handleCancellationSettingsError(e);
        }
    }

    /**
     * @description Collects opportunities where Cancel_Order__c changed from false to true
     * @param updatedOpportunities List of updated opportunities
     * @param oldOpportunitiesMap Map of old opportunity records
     * @return List of opportunities with new cancellation attempts
     */
    private static List<Opportunity> collectCancellationAttempts(List<Opportunity> updatedOpportunities, Map<Id, Opportunity> oldOpportunitiesMap) {
        List<Opportunity> cancellationAttempts = new List<Opportunity>();
        for (Opportunity updatedOpp : updatedOpportunities) {
            if (updatedOpp != null && updatedOpp.Cancel_Order__c == true && updatedOpp.RecordTypeId == ConstantsUtil.OPPORTUNITY_NCS_RT) {
                Opportunity oldOpp = oldOpportunitiesMap != null ? oldOpportunitiesMap.get(updatedOpp.Id) : null;
                if (oldOpp == null || oldOpp.Cancel_Order__c == false) {
                    cancellationAttempts.add(updatedOpp);
                }
            }
        }

        return cancellationAttempts;
    }

    /**
     * @description Validates cancellation attempts and adds errors for invalid combinations
     * @param cancellationAttempts List of opportunities attempting cancellation
     */
    private static void addErrorsForInvalidCancellations(List<Opportunity> cancellationAttempts) {
        for (Opportunity opp : cancellationAttempts) {
            String status = opp.Status__c;
            String subStatus = opp.Sub_Status__c;
            if (String.isBlank(status) || String.isBlank(subStatus)) {
                opp.addError('You cannot cancel an Opportunity that is in the current ASPN Status and Sub-Status.');
                continue;
            }

            String combinationKey = status.trim() + '|' + subStatus.trim();
            if (!allowedStatusSubStatusCombinations.contains(combinationKey)) {
                opp.addError('You cannot cancel an Opportunity that is in the current ASPN Status and Sub-Status.');
            }
        }
    }

    /**
     * @description Logs and throws exception for cancellation settings loading errors
     * @param e The exception that occurred
     */
    @TestVisible
    public static void handleCancellationSettingsError(Exception e) {
        Logger.error('Error loading ASPN Cancellation Settings Custom Metadata: ' + e.getMessage(), e)
            .addTag('OpportunityService');
        Logger.saveLog();
        throw new OpportunityService.CustomException('Failed to load cancellation settings: ' + e.getMessage());
    }
}