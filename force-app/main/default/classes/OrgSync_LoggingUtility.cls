/**
 * @description : this class is for logging database results(success/failure)
 * Created Date : 17 Dec 2025
 * Created By   : Neeraj Kumar
 */
public class OrgSync_LoggingUtility {
    
    /**
     * @description Handles database results and logs errors with record context
     * @param results List of Database.SaveResult, Database.UpsertResult, or Database.DeleteResult
     * @param records List of SObjects corresponding to the results
     * @param params Map containing className, methodName, and operationDescription
     */
    public static void handleDatabaseResults(List<Object> results, List<SObject> records, Map<String, String> params) {
        Boolean hasErrors = false;
        for (Integer i = 0; i < results.size(); i++) {
            Database.Error[] errors = getErrorsFromResult(results[i]);
            if (errors != null && !errors.isEmpty()) {
                SObject failedRecord = (records != null && i < records.size()) ? records[i] : null;
                logErrorsWithRecord(errors, failedRecord, params);
                hasErrors = true;
            }
        }
        if (hasErrors) {
            Logger.saveLog();
        }
    }
    
    /**
     * @description Extracts errors from various Database result types
     * @param result Database.SaveResult, Database.UpsertResult, or Database.DeleteResult
     * @return Array of Database.Error objects
     */
    public static Database.Error[] getErrorsFromResult(Object result) {
        if (result instanceof Database.SaveResult) {
            Database.SaveResult sr = (Database.SaveResult)result;
            return sr.isSuccess() ? new Database.Error[0] : sr.getErrors();
        } else if (result instanceof Database.DeleteResult) {
            Database.DeleteResult dr = (Database.DeleteResult)result;
            return dr.isSuccess() ? new Database.Error[0] : dr.getErrors();
        } else if (result instanceof Database.UpsertResult) {
            Database.UpsertResult ur = (Database.UpsertResult)result;
            return ur.isSuccess() ? new Database.Error[0] : ur.getErrors();
        }
        return new Database.Error[0];
    }
    
    /**
     * @description Logs errors with record context including status code and fields
     * @param errors Array of Database.Error objects
     * @param failedRecord The SObject record that failed (can be null)
     * @param params Map containing className, methodName, and operationDescription
     */
    public static void logErrorsWithRecord(Database.Error[] errors, SObject failedRecord, Map<String, String> params) {
        String className = params.get('className');
        String methodName = params.get('methodName');
        String context = params.get('operationDescription');
        
        for (Database.Error err : errors) {
            String errorMessage = className + ': ' + methodName + ': Error ' + context + '.';
            if (failedRecord != null) {
                errorMessage += ' Record: ' + failedRecord + '.';
            }
            errorMessage += ' Status: ' + err.getStatusCode() + ', Message: ' + err.getMessage() + ', Fields: ' + err.getFields();
            Logger.error(errorMessage).addTag('OrgSync');
        }
    }
    
    /**
     * @description Simple error logging without record context (backwards compatible)
     * @param errors Array of Database.Error objects
     * @param params Map containing className, methodName, and operationDescription
     */
    public static void logErrors(Database.Error[] errors, Map<String, String> params) {
        logErrorsWithRecord(errors, null, params);
    }
}