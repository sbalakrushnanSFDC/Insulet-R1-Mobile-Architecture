/**
 * @author      : anelluri
 * @created Date: 23rd Oct 2024
 * @description : Schedulable job that enqueues a queueable process to assign FieldPermissions on newly created fields to a specified Permission Set.
 * @story Number: NGASIM-2101
 * =========================== Logs ==============================
 * Version      Modified Date       Modified By         Brief Note
 * V1.0.0       23rd Oct 2024       Avinash Nelluri     Initial Version
 */
@SuppressWarnings('PMD.ApexDoc')
public with sharing class ScheduledPermissionAssigner implements Schedulable {

    private String permissionSetApiName;
    private String dateFilter;
    private static final String ACTIVITY_OBJECT = 'Activity';
    private static final String TASK_OBJECT = 'Task';

    /**
     * @description Constructor to initialize the permission set API name and date filter for the scheduled job.
     * @param permissionSetApiName
     * @param dateFilter 
     */
    public ScheduledPermissionAssigner(String permissionSetApiName, String dateFilter) {
        this.permissionSetApiName = permissionSetApiName;
        this.dateFilter = dateFilter;
    }

    /**
     * @description Method to execute the scheduled job.
     * @param sc SchedulableContext
     */
    public void execute(SchedulableContext sc) {
        System.enqueueJob(new PermissionAssignerQueueable(permissionSetApiName, dateFilter));
    }

    /**
     * @description Assigns FieldPermissions for newly created fields to the specified Permission Set.
     * @param permSetId  The Id of the target Permission Set receiving FieldPermissions.
     * @param dateFilter A SOQL WHERE clause fragment applied to the Tooling API query
     *                   (e.g., 'CreatedDate >= YESTERDAY' or an absolute timestamp range).
     */
    public static void assignPermissionsToNewFields(Id permSetId, String dateFilter) {
        Map<String, String> customObjectMap = getCustomObjectMap();

        String query = 'SELECT Id, NamespacePrefix, TableEnumOrId, DeveloperName FROM CustomField WHERE '+dateFilter;
        HttpResponse res = sendHttpRequest(query);

        if (res.getStatusCode() == 200) {
            List<FieldPermissions> lstFieldPermissions = new List<FieldPermissions>();
            List<Object> records = (List<Object>) ((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('records');

            for (Object recordObj : records) {
                Map<String, Object> record = (Map<String, Object>) recordObj;
                String tableEnumOrId = (String) record.get('TableEnumOrId');
                String fieldName = (String) record.get('DeveloperName');
                String namespacePrefix = (String) record.get('NamespacePrefix');
                String fieldType = (String) ((Map<String, Object>) record.get('attributes')).get('type');
                String customFieldName = fieldName + '__c';

                //Handling Packaged objects
                if(String.isNotBlank(namespacePrefix)){
                    customFieldName = namespacePrefix +'__'+ customFieldName;
                }

                String objectName = tableEnumOrId.startsWith('01I') ? customObjectMap.get(tableEnumOrId) : tableEnumOrId;
                fieldName = (fieldType == 'CustomField') ? customFieldName : fieldName;

                FieldPermissions fieldPerm = assignFieldPermissions(objectName, fieldName, permSetId);
                if (fieldPerm != null) {
                    lstFieldPermissions.add(fieldPerm);
                }
            }
            Database.insert(lstFieldPermissions, false, AccessLevel.USER_MODE);
        }
    }

    /**
     * @description Returns a map of CustomObject Ids to their corresponding DeveloperNames.
     * @return Map<String, String>
     */
    public static Map<String, String> getCustomObjectMap() {
        String query = 'SELECT Id, DeveloperName, NamespacePrefix FROM CustomObject';
        HttpResponse res = sendHttpRequest(query);
        Map<String, String> customObjectMap = new Map<String, String>();

        if (res.getStatusCode() == 200) {
            List<Object> records = (List<Object>) ((Map<String, Object>) JSON.deserializeUntyped(res.getBody())).get('records');

            for (Object recordObj : records) {
                Map<String, Object> record = (Map<String, Object>) recordObj;
                String id = (String) record.get('Id');
                String developerName = (String) record.get('DeveloperName');
                String namespacePrefix = (String) record.get('NamespacePrefix');
                String customObjectName = developerName + '__c';

                //Handling Packaged objects
                if(String.isNotBlank(namespacePrefix)){
                    customObjectName = namespacePrefix +'__'+ customObjectName;
                }

                customObjectMap.put(id, customObjectName);
            }
        }
        return customObjectMap;
    }

    private static FieldPermissions assignFieldPermissions(String objectName, String fieldName, Id permSetId) {
        if(objectName == ACTIVITY_OBJECT){
            objectName = TASK_OBJECT;
        }
        String fullFieldName = objectName + '.' + fieldName;
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
        Boolean editAccess = false;

        if(sObjectType == null){//Added check if the field is added on custom metadata. sObject will be null and no need to assign permissions.
            return null;
        }
        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();

        if (fieldMap.containsKey(fieldName)) {
            //Checking the field type is Formula field or not to remove the Edit permission.
            if(!fieldMap.get(fieldName).getDescribe().isCalculated()) {
                editAccess = true;
            }
            return new FieldPermissions(
                SObjectType = objectName,
                Field = fullFieldName,
                PermissionsRead = true,
                PermissionsEdit = editAccess,
                ParentId = permSetId
            );
        }
        return null;
    }

    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    private static HttpResponse sendHttpRequest(String query) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/query?q=' + EncodingUtil.urlEncode(query, 'UTF-8'));
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        request.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        return http.send(request);
    }
}
/*
Example of how to invoke this class:
String cronExp = '0 11 10 * * ?'; // Cron expression for 3:30 PM every day
String permissionSetApiName = 'Odaseva_Service_User'; //Update the permission set API name that you want to assign
//for daily run
String dateString = 'CreatedDate >= YESTERDAY';
//for running retroactively for large time period
String dateString = 'CreatedDate > 2024-10-01T00:00:00Z'; //ensure to update the date
ScheduledPermissionAssigner job = new ScheduledPermissionAssigner(permissionSetApiName, dateString);
System.schedule('Permission Assignment Job', cronExp, job);
*/