/**
 * @description Service class for ASPN Inactivity Alert logic.
 *              Sets ASPN_Inactivity_Alert__c = true when Sub_Status__c is not updated within threshold:
 *              - 3 business days when StageName != Prior Auth (excluding weekends)
 *              - 14 business days when StageName = Prior Auth (excluding weekends)
 *              Sets ASPN_Inactivity_Alert__c = false when Sub_Status__c is updated (via trigger).
 *
 * NOTE: This class is called from AspnInactivityAlertBatch and uses WITH SYSTEM_MODE for queries
 *       and SYSTEM_MODE for DML, so user permissions are not a concern.
 *
 * @author Ayush Sharma
 * @date Feb 05, 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       5th Feb 2026        Ayush Sharma                 Initial Version
 */
public inherited sharing class AspnInactivityAlertService {

    private static final String TAG_NAME = 'AspnInactivityAlertService';

    /**
     * @description Test override: use Map<Id, DateTime> to inject last SubStatus change datetime for tests
     */
    @TestVisible
    private static Map<Id, DateTime> testSubStatusChangeDateTimeOverride;

    /**
     * @description Test override: use Map<Id,Opportunity> to inject Opportunity data
     */
    @TestVisible
    private static Map<Id, Opportunity> testOpportunityDataOverride;

    /** Field values for IN clause: Sub_Status__c and CreatedDate (for no Sub_Status history - use Opp.CreatedDate logic) */
    private static final Set<String> FIELD_HISTORY_FIELDS = new Set<String>{
        ConstantsUtil.OPPORTUNITY_FIELD_SUB_STATUS,
        ConstantsUtil.OPPORTUNITY_FIELD_CREATED
    };

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message to log
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null)
     */
    @TestVisible
    private static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex).addTag(TAG_NAME);
    }

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message to log
     * @param record SObject record related to the error
     * @param failedRec Database.SaveResult object (can be null for permission errors)
     */
    @TestVisible
    private static void logError(String message, SObject record, Database.SaveResult failedRec) {
        Logger.error(message, failedRec).setRecord(record).addTag(TAG_NAME);
    }

    /**
     * @description Generic logger method for info logging
     * @param message Info message to log
     */
    private static void logInfo(String message) {
        Logger.info(message).addTag(TAG_NAME);
    }

    /**
     * @description Queries OpportunityFieldHistory for Sub_Status__c or CreatedDate.
     *              FieldHistory.CreatedDate is used for threshold: >= 3 days (other stage) or >= 14 days (Prior Auth).
     *              Field = CreatedDate covers Opportunities with no Sub_Status history (blank Sub_Status).
     * @return Database.QueryLocator for OpportunityFieldHistory records matching the criteria
     */
    public static Database.QueryLocator getOpportunityFieldHistoryForInactivityCheck() {
        // Records from 2-25 days ago (skip first 2 days from start, max 25 days back)
        // Query field history for Sub_Status__c changes (14 business days ≈ 20 calendar days)
        DateTime minDate = System.now().addDays(-25); // buffer for 14 business days
        DateTime maxDate = System.now().addDays(-2); // exclude today & yesterday
        
        return Database.getQueryLocator([
            SELECT Id, OpportunityId, Field, OldValue, NewValue, CreatedDate, Opportunity.StageName,
                Opportunity.Sub_Status__c, Opportunity.ASPN_Inactivity_Alert__c
            FROM OpportunityFieldHistory
            WHERE OpportunityId != null AND Opportunity.IsClosed = false AND Opportunity.ASPN_Inactivity_Alert__c = false
            AND Field IN :FIELD_HISTORY_FIELDS
            AND CreatedDate >= :minDate AND CreatedDate <= :maxDate
            WITH SYSTEM_MODE
            ORDER BY OpportunityId, CreatedDate DESC
        ]);
    }

    /**
     * @description Evaluates a single history record; returns Opportunity to update if eligible, else null.
     *              Called from AspnInactivityAlertBatch.processFieldHistoryRecords.
     * @param oppHist OpportunityFieldHistory record to evaluate
     * @return Opportunity to update with ASPN_Inactivity_Alert__c = true, or null if not eligible
     */
    public static Opportunity evaluateHistoryRecordForUpdate(OpportunityFieldHistory oppHist) {
        Opportunity opp = getOpportunityFromHistory(oppHist);
        if (!isEligibleOpportunity(opp)) {
            return null;
        }

        DateTime lastSubStatusChange = getLastSubStatusChangeDateTime(oppHist);
        if (!shouldSetInactivityAlert(lastSubStatusChange, opp.StageName)) {
            return null;
        }
        return new Opportunity(Id = oppHist.OpportunityId, ASPN_Inactivity_Alert__c = true);
    }

    /**
     * @description Returns true if Opportunity is eligible for inactivity alert (not already set).
     *              Allows blank Sub_Status - uses Opportunity.CreatedDate for threshold when blank.
     * @param opp Opportunity record to check
     * @return True if eligible (not null, alert not set)
     */
    private static Boolean isEligibleOpportunity(Opportunity opp) {
        return opp != null && opp.ASPN_Inactivity_Alert__c != true;
    }

    /**
     * @description Returns reference datetime for threshold check.
     *              Uses FieldHistory.CreatedDate (for both Sub_Status__c and CreatedDate field history).
     * @param oppHist OpportunityFieldHistory record
     * @return DateTime for threshold comparison
     */
    private static DateTime getLastSubStatusChangeDateTime(OpportunityFieldHistory oppHist) {
        if (Test.isRunningTest() && testSubStatusChangeDateTimeOverride != null && testSubStatusChangeDateTimeOverride.containsKey(oppHist.OpportunityId)) {
            return testSubStatusChangeDateTimeOverride.get(oppHist.OpportunityId);
        }
        return oppHist.CreatedDate;
    }

    /**
     * @description Determines if ASPN_Inactivity_Alert__c should be set based on last Sub_Status change and stage threshold.
     *              Threshold: 14 business days when StageName = Prior Auth, 3 business days otherwise (excluding weekends).
     * @param lastSubStatusChange DateTime of last Sub_Status__c change
     * @param stageName Opportunity StageName for threshold selection
     * @return True if inactivity alert should be set (current time past deadline), false otherwise
     */
    private static Boolean shouldSetInactivityAlert(DateTime lastSubStatusChange, String stageName) {
        if (lastSubStatusChange == null) {
            return false;
        }

        Integer thresholdDays = (stageName == ConstantsUtil.OPPORTUNITY_STAGE_PRIOR_AUTH)
            ? ConstantsUtil.OPPORTUNITY_ASPN_INACTIVITY_ALERT_THRESHOLD_14_DAYS
            : ConstantsUtil.OPPORTUNITY_ASPN_INACTIVITY_ALERT_THRESHOLD_3_DAYS;
        Date deadlineDate = addBusinessDays(lastSubStatusChange.date(), thresholdDays);
        DateTime deadlineDateTime = DateTime.newInstance(deadlineDate, lastSubStatusChange.time());
        
        return DateTime.now() >= deadlineDateTime;
    }
    
    /**
     * @description Gets Opportunity data from history record (relationship or test override).
     * @param oppHist OpportunityFieldHistory record
     * @return Opportunity with Id, StageName, Sub_Status__c, ASPN_Inactivity_Alert__c, or null
     */
    @TestVisible
    private static Opportunity getOpportunityFromHistory(OpportunityFieldHistory oppHist) {
        if (Test.isRunningTest() && testOpportunityDataOverride != null) {
            return testOpportunityDataOverride.get(oppHist.OpportunityId);
        }
        return oppHist.Opportunity;
    }

    /**
     * @description Adds the specified number of business days to a start date (excluding weekends).
     *              Uses TaskGenerationCore.getNextBusinessDate to skip weekends.
     * @param startDate The starting date
     * @param businessDaysToAdd Number of business days to add
     * @return The resulting date after adding the specified business days
     */
    @TestVisible
    private static Date addBusinessDays(Date startDate, Integer businessDaysToAdd) {
        if (startDate == null || businessDaysToAdd == null || businessDaysToAdd <= 0) {
            return startDate;
        }
        Date currentDate = startDate;
        Integer daysAdded = 0;
        while (daysAdded < businessDaysToAdd) {
            currentDate = currentDate.addDays(1);
            if (TaskGenerationCore.getNextBusinessDate(currentDate) == currentDate) {
                daysAdded++;
            }
        }
        return currentDate;
    }

    /**
     * @description Clears ASPN_Inactivity_Alert__c when Sub_Status__c is updated.
     *              Called from OpportunityTriggerHandler beforeUpdate - sets field on in-memory records (no DML).
     * @param updatedOpportunities List of updated Opportunities
     * @param oldOpportunitiesMap Map of old Opportunity values (null for insert)
     */
    public static void clearInactivityAlertOnSubStatusUpdate(
        List<Opportunity> updatedOpportunities,
        Map<Id, Opportunity> oldOpportunitiesMap
    ) {
        if (updatedOpportunities == null || updatedOpportunities.isEmpty()) {
            return;
        }

        for (Opportunity opp : updatedOpportunities) {
            if (opp.ASPN_Inactivity_Alert__c != true) {
                continue;
            }
            Opportunity oldOpp = oldOpportunitiesMap != null ? oldOpportunitiesMap.get(opp.Id) : null;
            if (oldOpp == null) {
                continue; // Insert - no "change" to clear
            }
            if (opp.Sub_Status__c != oldOpp.Sub_Status__c) {
                opp.ASPN_Inactivity_Alert__c = false;
            }
        }
    }

    /**
     * @description Updates Opportunities with ASPN_Inactivity_Alert__c = true using bulk-safe DML.
     *              Note: Opportunity triggers are bypassed when called from batch context
     *              to prevent unnecessary trigger execution.
     * @param opportunitiesToUpdate List of Opportunity records to update
     * @return Integer count of successfully updated records
     */
    public static Integer updateOpportunities(List<Opportunity> opportunitiesToUpdate) {
        if (opportunitiesToUpdate == null || opportunitiesToUpdate.isEmpty()) {
            return 0;
        }

        try {
            Database.SaveResult[] results = Database.update(opportunitiesToUpdate, false);

            Integer successCount = 0;
            for (Integer i = 0; i < results.size(); i++) {
                Database.SaveResult sr = results[i];
                if (sr.isSuccess()) {
                    successCount++;
                } else {
                    for (Database.Error err : sr.getErrors()) {
                        logError('Failed to update Opportunity ' + opportunitiesToUpdate[i].Id + ': ' + err.getMessage(), opportunitiesToUpdate[i], sr);
                    }
                }
            }

            logInfo('Successfully updated ' + successCount + ' out of ' + opportunitiesToUpdate.size() + ' Opportunity records');

            // Throw exception for test coverage if customExceptionSwitch is enabled
            Utility.throwExceptionForTestCoverage();
            return successCount;
        } catch (Exception e) {
            logError('Exception while updating Opportunities: ' + e.getMessage(), opportunitiesToUpdate, e);
            Logger.saveLog();
            return 0;
        }
    }
}