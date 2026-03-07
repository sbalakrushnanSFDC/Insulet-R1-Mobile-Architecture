/**
 * @author      : Gunjan Kubde & Yogesh Rana
 * @created Date: 7 Nov 2025
 * @description : Utility Class
 * Used to perform common utility methods
 * @story Number:
 * =========================== Logs ==============================
 * Version      Modified Date     Modified By                    Brief Note
 * V1.0.0       07 Nov 2025       Gunjan Kubde & Yogesh Rana     Initial Version
 * V1.0.1       04 Dec 2025       Yogesh Rana                   Added method to throw exception for test coverage(US - NGOMCT-752)
 * V1.0.2       30 Dec 2025       Yogesh Rana                   Added method to get user timezone and locale(US - NGOMCT-1278, NGOMCT-1280)
 */
public without sharing class Utility {

    /**
     * @description Custom exception class for Utility operations
     */
    public class UtilityException extends Exception {}

    /**
   * @description Wrapper class used to store the context of the share record
   */
    @TestVisible
    private class ShareContext {
        Id recordId;
        Schema.SObjectType parentType;
        Schema.SObjectType shareType;
        String shareTypeName;
        String parentField;
        List<String> accessField;
        Map<String, Schema.SObjectField> shareFields;
    }

    /**
   * @description Wrapper class used to store the details to resolve the parent field
   */
    @TestVisible
    private class ResolveParentFieldWrapper {
       @TestVisible Schema.SObjectType parentType;
       @TestVisible Map<String, Schema.SObjectField> fieldMap;
       @TestVisible String objectName;
       @TestVisible Boolean isCustom ;
    }

     /**
   * @description Wrapper class used to store the parameters for the create share record.
   */
    public class CreateShareRecordParameterDetailWrap {
       public String recordId;
       public String userOrGroupId;
       public String accessLevel;
       public String rowCause;
    }

    /**
   * @description Method to initialize the share context for a given record.
   * @param recordId The Id of the record to share.
   * @return The ShareContext object.
   */
    @TestVisible
    private static ShareContext initShareContext(Id recordId) {
        if (recordId == null){
            return null;
        }

        ShareContext ctx = new ShareContext();
        ctx.recordId = recordId;
        String shareTypeName = '';

        try {
            ctx.parentType = recordId.getSObjectType();
            Schema.DescribeSObjectResult parentDescribe = ctx.parentType.getDescribe();

            String objName = parentDescribe.getName();
            Boolean isCustom = parentDescribe.isCustom();

            shareTypeName = isCustom ? objName.replace('__c', '__Share') : objName + 'Share';

            Schema.SObjectType shareType = Schema.getGlobalDescribe().get(shareTypeName);

            if (shareType == null){
                throw new UtilityException('Share object ' + shareTypeName + ' does not exist. This object may not support sharing.');
            }

            ctx.shareType = shareType;
            ctx.shareTypeName = shareTypeName;
            ctx.shareFields = shareType.getDescribe().fields.getMap();

        ResolveParentFieldWrapper parameterDetailRecord = new ResolveParentFieldWrapper();
        parameterDetailRecord.parentType = ctx.parentType;
        parameterDetailRecord.fieldMap = ctx.shareFields;
        parameterDetailRecord.objectName = objName;
        parameterDetailRecord.isCustom = isCustom;

            ctx.parentField = resolveParentField(parameterDetailRecord);
            ctx.accessField = resolveAccessField(ctx.shareFields, objName);

            return ctx;
        } catch (Exception e) {
            String errorMsg = 'Method: initShareContext() | '
                            + 'Operation: Schema operations for share object initialization | '
                            + 'RecordId: ' + recordId + ' | '
                            + 'Error: ' + e.getMessage() + ' | '
                            + 'Line: ' + e.getLineNumber() + ' | ';
            throw new UtilityException(errorMsg);
        }
    }

   /**
   * @description Method use to get editable fields
   * @param shareFields The map of share fields to their values.
   * @return The list of editable fields.
   */
    @TestVisible
    private static List<String> getEditableFields(Map<String, Schema.SObjectField> shareFields) {
        List<String> editableFields = new List<String>();

        for(Schema.SObjectField field : shareFields.values()) {
            Schema.DescribeFieldResult dfr = field.getDescribe();
            if (dfr.isUpdateable()) { // Check for update permission.
                editableFields.add(dfr.getName());
            }
        }
        return editableFields;
    }

   /**
   * @description Method use to resolve the parent field
   * @param parameterDetailWrap The wrapper class used to store the details to resolve the parent field
   * @return The parent field.
   */
    @TestVisible
    private static String resolveParentField(ResolveParentFieldWrapper parameterDetailWrap) {
        Schema.SObjectType parentType = (Schema.SObjectType)parameterDetailWrap.parentType;
        Map<String, Schema.SObjectField> fMap =  (Map<String, Schema.SObjectField>)parameterDetailWrap.fieldMap;
        String objName = (String)parameterDetailWrap.objectName;
        Boolean isCustom = (Boolean)parameterDetailWrap.isCustom;


        for (String fName : fMap.keySet()) {
            Schema.DescribeFieldResult fd = fMap.get(fName).getDescribe();
            if (fd.getType() == Schema.DisplayType.REFERENCE) {
                for (Schema.SObjectType rt : fd.getReferenceTo()) {
                    if (rt == parentType) {
                        return fName;
                    }
                }
            }
        }

        if (isCustom){
            return 'ParentId';
        }
        return objName + 'Id';
    }

    /**
   * @description Method use to resolve the access field
   * @param fMap The map of fields to their values.
   * @param objName The object name.
   * @return list of access fields.
   */
    private static List<String> resolveAccessField(Map<String, Schema.SObjectField> fMap, String objName) {
        List<String> editableFields = getEditableFields(fMap);
        if (fMap.containsKey('AccessLevel')){
            return new List<String>{'AccessLevel'};
        }
        List<String> fNameList = new List<String>();
        if(!editableFields.isEmpty()){
            for (String fName : editableFields) {
                if (fName.toLowerCase().endsWith('accesslevel')){
                    fNameList.add(fName);
                }
            }
        }
        return fNameList;
    }

    /**
   * @description Method use to create share record
   * @param parameterWrapper The wrapper of parameters(recordId, userOrGroupId, accessLevel, rowCause) for the share record.
   * @return The share record.
   */
    public static SObject createShare(CreateShareRecordParameterDetailWrap parameterWrapper) {
        if (parameterWrapper == null || (String)parameterWrapper.userOrGroupId == null){
            return null;
        }

        ShareContext ctx = initShareContext((String)parameterWrapper.recordId);
        if (ctx == null){
            return null;
        }
        
        SObject share = ctx.shareType.newSObject();
        share.put(ctx.parentField, (String)parameterWrapper.recordId);
        share.put('UserOrGroupId', (String)parameterWrapper.userOrGroupId);

        if(!ctx.accessField.isEmpty()){
            for(String acField : ctx.accessField){
                share.put(acField, (String)parameterWrapper.accessLevel);
            }
        }
        if ((String)parameterWrapper.rowCause != null && ctx.shareFields.containsKey('RowCause')) {
            share.put('RowCause', (String)parameterWrapper.rowCause);
        }

        return share;
    }

    /**
   * @description Method use to delete share record.
   * @param recordIds The List of Ids of the record to delete.
   * @param userOrGroupIds The List of Ids of the user or group to delete the record with.
   * @return The number of deleted share records.
   */
    public static List<SObject> deleteShares(List<Id> recordIds, List<Id> userOrGroupIds) {
        if(recordIds == null || recordIds.isEmpty() || userOrGroupIds == null || userOrGroupIds.isEmpty()){
            return null;
        }

        ShareContext ctx = initShareContext(recordIds[0]); // We will be handling only one type of records.
        if (ctx == null){
            return null;
        }

        String soql = 'SELECT Id FROM ' + ctx.shareTypeName +
                      ' WHERE ' + ctx.parentField + ' IN :recordIds' +
                      ' AND UserOrGroupId IN :userOrGroupIds';

        try {
            if (ConstantsUtil.customExceptionSwitch && Test.isRunningTest()) {
                throw new QueryException('customExceptionSwitch is turned on for test coverage');
            }

            List<SObject> shares = Database.query(String.escapeSingleQuotes(soql));
            if (shares.isEmpty()){
                return null;
            }
            return shares;
        }catch (QueryException e) {
            String errorMsg = 'Method: deleteShares() | '
                            + 'Operation: Unexpected error during share deletion | '
                            + 'Error: ' + e.getMessage() + ' | '
                            + 'Line: ' + e.getLineNumber() + ' | ';
            throw new UtilityException(errorMsg);
        }
    }

    /**
     * @description Method to get Map of RecordType Info by Id
     * @param objectName The name of the object to get the RecordType Info for.
     * @return Map of RecordType Info by Id
    */
    public static Map<Id, Schema.RecordTypeInfo> getRecordTypeInfoMap(String objectName){
        return Schema.getGlobalDescribe()
                .get(objectName)
                .getDescribe()
                .getRecordTypeInfosById();
    }

    /**
     * @description Throws exception for test coverage when test switch is enabled
     * This generic method allows test classes to verify exception handling paths by enabling
     * the ConstantsUtil.customExceptionSwitch flag during test execution
     * Can be reused across multiple handler classes for consistent test coverage
     * @throws UtilityException when customExceptionSwitch is true in test context
     */
    @TestVisible
    public static void throwExceptionForTestCoverage() {
        if (ConstantsUtil.customExceptionSwitch && Test.isRunningTest()) {
            throw new UtilityException('customExceptionSwitch is turned on for test coverage');
        }
    }

 /**
     * @description Get current user's timezone and locale
     * Works for internal, partner, and community users
     * @return Map with keys: timeZone, locale
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getUserTimeZoneAndLocale() {
        Map<String, String> result = new Map<String, String>();
        try {
            if (ConstantsUtil.customExceptionSwitch && Test.isRunningTest()) {
                throw new UtilityException('customExceptionSwitch is turned on for test coverage');
            }
            result.put('timeZone', UserInfo.getTimeZone().getID());
            result.put('locale', UserInfo.getLocale());
        } catch (Exception e) {
            String errorMsg = 'Method: getUserTimeZoneAndLocale() | '
                            + 'Operation: Error getting user preferences | '
                            + 'Error: ' + e.getMessage() + ' | '
                            + 'Line: ' + e.getLineNumber() + ' | ';
            throw new UtilityException(errorMsg);
        }
        return result;
    }
}