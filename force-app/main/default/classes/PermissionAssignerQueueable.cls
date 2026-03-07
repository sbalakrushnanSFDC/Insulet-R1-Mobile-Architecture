/**
 * @author      : anelluri
 * @created Date: 27th Feb 2026
 * @description : Queueable job that looks up a Permission Set by API name and delegates to ScheduledPermissionAssigner
 *                to create FieldPermissions for newly created fields filtered by a provided date condition.
 * @story Number: NGASIM-2101
 * =========================== Logs ==============================
 * Version      Modified Date       Modified By         Brief Note
 * V1.0.0       27th Feb 2026       Avinash Nelluri     Initial Version
 */
@SuppressWarnings('PMD.ApexDoc')
public with sharing class PermissionAssignerQueueable implements Queueable, Database.AllowsCallouts {
    
    private String permissionSetApiName;
    private String dateFilter;
    
    /**
     * @description Initializes the queueable with the target Permission Set API name and a date filter used by the assignment process.
     * @param permissionSetApiName The API/DeveloperName of the Permission Set that should receive FieldPermissions.
     * @param dateFilter           A WHERE-clause fragment applied to Tooling API queries (e.g., 'CreatedDate >= YESTERDAY').
     */
    public PermissionAssignerQueueable(String permissionSetApiName, String dateFilter) {
        this.permissionSetApiName = permissionSetApiName;
        this.dateFilter = dateFilter;
    }
    
    /**
     * @description Executes the queueable context: resolves the Permission Set Id by API name and invokes
     *              ScheduledPermissionAssigner.assignPermissionsToNewFields to create FieldPermissions.
     * @param context QueueableContext provided by the platform when the job runs.
     */
    public void execute(QueueableContext context) {
        Id permSetId = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetApiName LIMIT 1]?.Id;
        ScheduledPermissionAssigner.assignPermissionsToNewFields(permSetId, dateFilter);
    }
}