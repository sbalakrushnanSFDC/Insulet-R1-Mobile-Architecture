/**
 * @description Utility class to run Enterprise Territory Management Assignment rules
 *              Uses Named Credential and Composite API to trigger territory assignment
 * @author      Bijayalaxmi Prusty
 * @created     Jan 12, 2026
 *  * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.1       12th Jan 2026       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1643)
 */
public with sharing class RunTerritoryRules implements Queueable, Database.AllowsCallouts {
    private Set<Id> accountIds;
    private static final Integer BATCH_SIZE = 200; // Salesforce Composite API limit

    /**
     * @description Constructor
     * @param accIds Set of Account IDs to process
     */
    public RunTerritoryRules(Set<Id> accIds) {
        this.accountIds = accIds;
    }

    /**
     * @description Execute method to process territory assignment
     * @param context QueueableContext
     */
    public void execute(QueueableContext context) {
        // Attach Finalizer to handle cleanup and error scenarios
        if (!Test.isRunningTest()) {
            System.attachFinalizer(new TerritoryRulesFinalizer(accountIds));
        }

        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        // Convert Set to List for processing
        List<Id> accountIdList = new List<Id>(accountIds);

        // Process in batches of 200
        for (Integer i = 0; i < accountIdList.size(); i += BATCH_SIZE) {
            Integer endIndex = Math.min(i + BATCH_SIZE, accountIdList.size());
            List<Id> batch = new List<Id>();

            for (Integer j = i; j < endIndex; j++) {
                batch.add(accountIdList[j]);
            }

            if (!batch.isEmpty()) {
                processBatch(batch);
            }
        }
    }

    /**
     * @description Process a single batch of Account IDs
     * @param batchIds List of Account IDs to process (max 200)
     */
    private void processBatch(List<Id> batchIds) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Self_Callout_Named_Credential/services/data/v60.0/composite/sobjects');
        req.setMethod('PATCH');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000); // 120 second timeout

        // This header triggers Enterprise Territory Management assignment rules
        req.setHeader('Sforce-Auto-Assign', 'TRUE');

        // Build the JSON payload
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('allOrNone', false);

        List<Map<String, Object>> recordsList = new List<Map<String, Object>>();
        for (Id accId : batchIds) {
            Map<String, Object> recordData = new Map<String, Object>();
            recordData.put('attributes', new Map<String, String>{'type' => 'Account'});
            recordData.put('Id', accId);
            recordsList.add(recordData);
        }
        payload.put('records', recordsList);

        req.setBody(JSON.serialize(payload));

        // Prepare account records for error logging
        List<SObject> accountRecords = new List<SObject>();
        for (Id accId : batchIds) {
            accountRecords.add(new Account(Id = accId));
        }

        Http http = new Http();
        try {
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                // Optionally parse response to check individual record results
                parseResponse(res.getBody(), accountRecords);
            } else {
                logError('Territory assignment API call failed with status code: ' + res.getStatusCode() + '. Response: ' + res.getBody(),
                        accountRecords, null);
            }

        } catch (Exception e) {
            logError('Failed to process territory assignment batch. Error: ' + e.getMessage(),
                    accountRecords, e);
        }
    }

    /**
     * @description Parse the response to check for any errors
     * @param responseBody JSON response body
     * @param accountRecords List of Account records for error logging
     */
    private void parseResponse(String responseBody, List<SObject> accountRecords) {
        try {
            List<Object> results = (List<Object>) JSON.deserializeUntyped(responseBody);
            List<String> errorMessages = new List<String>();

            for (Integer i = 0; i < results.size(); i++) {
                Map<String, Object> resultMap = (Map<String, Object>) results[i];
                Boolean success = (Boolean) resultMap.get('success');

                if (!success) {
                    List<Object> errors = (List<Object>) resultMap.get('errors');
                    errorMessages.add('Record ' + i + ': ' + JSON.serialize(errors));
                }
            }

            if (!errorMessages.isEmpty()) {
                logError('Territory assignment failed for ' + errorMessages.size() + ' record(s). Errors: ' + String.join(errorMessages, '; '),
                        accountRecords, null);
            }

        } catch (Exception e) {
            logError('Failed to parse territory assignment response. Error: ' + e.getMessage(),
                    accountRecords, e);
        }
    }
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
     * @description Finalizer class to handle cleanup and error scenarios for territory assignment job
     */
    @TestVisible
    public class TerritoryRulesFinalizer implements System.Finalizer {
        private Set<Id> accountIds;

        /**
         * @description Constructor
         * @param accIds Set of Account IDs that were being processed
         */
        public TerritoryRulesFinalizer(Set<Id> accIds) {
            this.accountIds = accIds;
        }

        /**
         * @description Execute method called when Queueable job completes or fails
         * @param context FinalizerContext containing job status and exception information
         */
        public void execute(System.FinalizerContext context) {
            if (context.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
                List<SObject> accountRecords = new List<SObject>();
                if (accountIds != null) {
                    for (Id accId : accountIds) {
                        accountRecords.add(new Account(Id = accId));
                    }
                }
                logError('Territory assignment job failed with unhandled exception: ' +
                        (context.getException() != null ? context.getException().getMessage() : 'Unknown error'),
                        accountRecords, context.getException());
            }
        }
    }
}