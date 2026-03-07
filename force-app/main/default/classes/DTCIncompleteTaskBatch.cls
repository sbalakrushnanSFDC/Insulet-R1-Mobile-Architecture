/**
 * @description Batch class to generate DTC Incomplete tasks for Leads that meet the criteria:
 *              LeadSource = 'Get Started', Provider_Practice_Affiliation__c is null,
 *              and Matching_Status__c is ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH or ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH.
 *
 *              Time window behavior:
 *              - Default mode (production): Processes Leads that became eligible after Wait Time After Creation
 *                using a Processing Window (values from Batch_Configuration__mdt Custom Metadata).
 *                Example: If Wait Time = 1440 min (24 hrs) and Window = 60 min, processes Leads created 25-24 hours ago.
 *              - Lookback mode (testing/ops): new DTCIncompleteTaskBatch(minutesBack) processes Leads created
 *                between (now - minutesBack) and now.
 *              Replaces the time-based flow Lead_After_Insert (NGASIM-1273).
 * @author Jatin Butta
 * @created Date 11th Dec 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Dec 2025       Jatin Butta             Initial Version(US - NGASIM-1273)
 * V1.1.0       Dec 19, 2025        Anup Bandawar           Added parameterized constructor for metadata-driven time windows
 * =======================================================================
 */
public class DTCIncompleteTaskBatch implements Database.Batchable<SObject> {

    private static final String TAG_NAME = 'DTCIncompleteTaskBatch';

    // ---------------------------- TIME WINDOW CONFIG ----------------------------
    // Default behavior: pick Leads that became eligible ~24 hours after creation.
    private static final Integer DEFAULT_MINUTES_AFTER_CREATION = 24 * 60;
    // Default window assumes an hourly run (±30 minutes around the 24-hour mark).
    private static final Integer DEFAULT_WINDOW_MINUTES = 60;

    @TestVisible private Integer minutesAfterCreation;
    @TestVisible private Integer windowMinutes;
    private Integer lookbackMinutes;

    /**
     * @description Default constructor for production/scheduler usage with default time windows.
     *              Uses hardcoded defaults (24 hours wait time, 60 minutes window).
     */
    public DTCIncompleteTaskBatch() {
        this(DEFAULT_MINUTES_AFTER_CREATION, DEFAULT_WINDOW_MINUTES);
    }

    /**
     * @description Constructor with configurable time windows (called from scheduler with metadata values).
     * @param waitTimeMinutes Wait time after Lead creation before processing (e.g., 1440 for 24 hours)
     * @param processingWindowMinutes Processing window size (e.g., 60 for 1 hour window)
     */
    public DTCIncompleteTaskBatch(Integer waitTimeMinutes, Integer processingWindowMinutes) {
        this.minutesAfterCreation = (waitTimeMinutes != null && waitTimeMinutes > 0)
            ? waitTimeMinutes
            : DEFAULT_MINUTES_AFTER_CREATION;
        this.windowMinutes = (processingWindowMinutes != null && processingWindowMinutes > 0)
            ? processingWindowMinutes
            : DEFAULT_WINDOW_MINUTES;
        this.lookbackMinutes = null;
    }

    /**
     * @description Simple constructor to run the batch for Leads created in the last N minutes (lookback window).
     *              Example: new DTCIncompleteTaskBatch(10) will consider Leads created between now-10 minutes and now.
     * @param minutesBack Number of minutes to look back from "now" for the CreatedDate window
     */
    public DTCIncompleteTaskBatch(Integer minutesBack) {
        this.lookbackMinutes = (minutesBack == null || minutesBack <= 0) ? null : minutesBack;
        this.minutesAfterCreation = DEFAULT_MINUTES_AFTER_CREATION;
        this.windowMinutes = DEFAULT_WINDOW_MINUTES;
    }

    /**
     * @description Start method to query Leads that meet DTC Incomplete criteria.
     *              Two modes:
     *              - Lookback mode (when lookbackMinutes is set): Queries Leads created between (now - lookbackMinutes) and now.
     *              - Default mode: Queries Leads created between (minutesAfterCreation + windowMinutes) minutes ago
     *                and minutesAfterCreation minutes ago (e.g., 25 hours ago to 24 hours ago if configured as 1440 and 60).
     * @param bc BatchableContext
     * @return Database.QueryLocator for Leads meeting the criteria
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime now = DateTime.now();
        DateTime startTime;
        DateTime endTime;

        if (lookbackMinutes != null) {
            // Lookback mode: CreatedDate in the last N minutes (start = now - N, end = now)
            endTime = now;
            startTime = now.addMinutes(-lookbackMinutes);
        } else {
            // Default mode:
            // - endTime: "minutesAfterCreation" minutes ago
            // - startTime: (minutesAfterCreation + windowMinutes) minutes ago
            endTime = now.addMinutes(-minutesAfterCreation);
            startTime = now.addMinutes(-(minutesAfterCreation + windowMinutes));
        }

        Logger.info('DTCIncompleteTaskBatch started. Querying Leads created between ' +
                    startTime.format('yyyy-MM-dd HH:mm:ss') + ' and ' +
                    endTime.format('yyyy-MM-dd HH:mm:ss'))
            .addTag(TAG_NAME);
        Logger.saveLog();

        return Database.getQueryLocator([
            SELECT Id, LeadSource, Provider_Practice_Affiliation__c, Matching_Status__c
            FROM Lead
            WHERE CreatedDate >= :startTime
            AND CreatedDate <= :endTime
            AND LeadSource = :ConstantsUtil.LEAD_SOURCE_GET_STARTED
            AND Provider_Practice_Affiliation__c = null
            AND Matching_Status__c IN (:ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH, :ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH)
            WITH SYSTEM_MODE
        ]);
    }

    /**
     * @description Execute method to generate tasks for Leads meeting DTC Incomplete criteria
     * @param bc BatchableContext
     * @param scope List of Lead records to process
     */
    public void execute(Database.BatchableContext bc, List<Lead> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        try {
            // Build task generation requests
            List<TaskGenerationService.TaskRequest> requests = new List<TaskGenerationService.TaskRequest>();
            for (Lead lead : scope) {
                // Double-check conditions (in case data changed since query)
                if (meetsDTCIncompleteCriteria(lead)) {
                    TaskGenerationService.TaskRequest request = new TaskGenerationService.TaskRequest();
                    request.recordId = lead.Id;
                    request.objectApiName = ConstantsUtil.LEAD_OBJECT;
                    request.triggerEvent = ConstantsUtil.INSERT_OPERATION;
                    requests.add(request);
                }
            }

            if (!requests.isEmpty()) {
                List<TaskGenerationService.TaskResult> results = TaskGenerationService.createTasks(requests);

                Integer successCount = 0;
                Integer taskCount = 0;
                for (TaskGenerationService.TaskResult result : results) {
                    if (result.success) {
                        successCount++;
                        taskCount += result.tasksCreated;
                    }
                }

                Logger.info('DTCIncompleteTaskBatch processed ' + scope.size() + ' Lead(s). ' +
                           'Successfully generated tasks for ' + successCount + ' Lead(s). ' +
                           'Total tasks created: ' + taskCount)
                    .addTag(TAG_NAME);
                Logger.saveLog();
            } else {
                Logger.info('DTCIncompleteTaskBatch: No Leads in scope met the criteria after re-validation')
                    .addTag(TAG_NAME);
                Logger.saveLog();
            }

            /**
            * when customExceptionSwitch static variable is turned on
            * it covers exceptions in test coverage
            */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on');
            }

        } catch (Exception e) {Logger.error('Error in DTCIncompleteTaskBatch.execute: ' + e.getMessage(), e).addTag(TAG_NAME);
            Logger.saveLog();
        }
    }

    /**
     * @description Finish method called after all batches complete
     * @param bc BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        Logger.info('DTCIncompleteTaskBatch completed successfully')
            .addTag(TAG_NAME);
        Logger.saveLog();
    }

    /**
     * @description Checks if a Lead meets the DTC Incomplete criteria.
     *              Criteria: LeadSource = 'Get Started', Provider_Practice_Affiliation__c is null,
     *              and Matching_Status__c is either 'No Match' or 'Full Match'.
     * @param lead Lead record to evaluate
     * @return Boolean true if the Lead meets all criteria, false otherwise
     */
    private Boolean meetsDTCIncompleteCriteria(Lead lead) {
        return lead.LeadSource == ConstantsUtil.LEAD_SOURCE_GET_STARTED
            && lead.Provider_Practice_Affiliation__c == null
            && (lead.Matching_Status__c == ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH
                || lead.Matching_Status__c == ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH);
    }

    /**
    * @description Exception class for Batch job
    */
    public class MyCustomException extends Exception {}
}