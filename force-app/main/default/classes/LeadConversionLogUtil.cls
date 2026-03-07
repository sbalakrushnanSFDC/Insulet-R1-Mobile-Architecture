/**
 * Utility class for Lead conversion logging and DML error message formatting.
 * Centralizes Logger usage so helper classes can share consistent behavior.
 *
 * @author      : Jatin Butta
 * @created Date: 16th January 2026
 * @description : Utility methods for Lead conversion logging and DML error message formatting
 * @story Number: NGASIM-1901
 * =========================== Logs ======================================
 * Version      Modified Date           Modified By                 Brief Note
 * V1.0.0       16th January 2026      Jatin Butta                 Initial Version(US - NGASIM-1901)
 */
public inherited sharing class LeadConversionLogUtil {
    /**
     * @description Logs error messages using Logger framework.
     * @param message The error message
     */
    public static void logError(String message) {
        Logger.error(message)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    /**
     * @description Logs debug messages using Logger framework.
     * @param message The debug message
     */
    public static void logDebug(String message) {
        Logger.debug(message);
        Logger.saveLog();
    }

    /**
     * @description Builds a single error message from Database.Error list.
     * @param errors List of Database.Error objects
     * @return Concatenated error message string
     */
    public static String buildErrorMessage(List<Database.Error> errors) {
        String errorMsg = '';
        for (Database.Error err : errors) {
            errorMsg += err.getMessage() + '; ';
        }
        return errorMsg;
    }
}