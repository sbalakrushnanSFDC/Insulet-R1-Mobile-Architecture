/**
 * @description Service class responsible for dynamically retrieving OrgSync publish settings
 *              based on sObject type and record type. This class follows the Service Layer pattern
 *              and is designed to be bulk-safe, secure, and governor limit-aware.
 *              This service is GENERIC and works with ANY sObject type.
 * Created Date : Nov 20, 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Nov 20, 2025        Ramesh Dhaka            Initial Version
 */
public with sharing class OrgSync_LoggingService  implements XCDC_PersistentLogHandler {
    /**
     * @description Persists the logs to the database
     * @param errLogs List of error logs
     */
    public void persistLogs(List<XCDC_ErrorLog> errLogs){
        for(XCDC_ErrorLog err : errLogs){
            Logger.error(err.className + ': ' + err.moduleName + ': ' + err.logSummary +': '+ err.logDetail).addTag('OrgSync');
        }
        Logger.saveLog();
    }
}