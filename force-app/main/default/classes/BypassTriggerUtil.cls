/**
 * @Author      : Shailja Jain
 * @Created Date: 2nd September 2025
 * @description : Utility class to determine if trigger logic should be bypassed
 * for the current user based on a custom permission.
 * Custom Permission: Bypass_Apex_Trigger
 * @Story Number: NGONDL-97
 */
public with sharing class BypassTriggerUtil {
    /**
     * @description Inner class that performs the custom permission check.
     */
    public virtual class PermissionChecker{
        /**
         * @description Returns true if the current user has the specified custom permission.
         * @param customPermissionName The API name of the custom permission to check.
         * @return Boolean True if the user has the permission, otherwise false.
         */
        public virtual Boolean hasPermission(String customPermissionName){
            return FeatureManagement.checkPermission(customPermissionName);
        }
    }

    /**
     * @description Checks if the trigger bypass is enabled using the default PermissionChecker.
     * @return Boolean True if the user can bypass triggers, otherwise false.
     */
    public static Boolean isTriggerBypassEnabled(){
        PermissionChecker checker = new PermissionChecker();
        return isTriggerBypassEnabled(ConstantsUtil.BYPASS_APEX_TRIGGER, checker);
    }

    /**
     * @description Checks if the trigger bypass is enabled using the provided PermissionChecker.
     * @param customPermissionName The API name of the custom permission to check.
     * @param checker A custom PermissionChecker instance for testing or alternate logic.
     * @return Boolean True if the user can bypass triggers, otherwise false.
     */
    public static Boolean isTriggerBypassEnabled(String customPermissionName, PermissionChecker checker){
        try {
            return checker.hasPermission(customPermissionName);
        } catch (Exception ex){
            return false;
        }
    }
}