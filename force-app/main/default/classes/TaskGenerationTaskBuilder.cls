/**
 * @description Constructs Task records based on rules and parent records.
 *              Sets Task fields from rule metadata (Category, Sub-Category, Subject, Due Date, Owner).
 *              Handles WhoId for Lead/Contact, WhatId for other objects.
 *              Due dates are calculated from Due_Date_Offset__c and pushed to the next business day if they land on a weekend.
 *              Part of TaskGenerationService refactoring (NGASIM-1273).
 * @author Jatin Butta
 * @created Date 11th Dec 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Dec 2025       Jatin Butta             Initial Version(US - NGASIM-1273)
 * =======================================================================
 */
public inherited sharing class TaskGenerationTaskBuilder {
    /**
     * @description Constructs a Task record based on the rule and parent record.
     * @param record Parent record for the task
     * @param rule Task Generation Rule metadata
     * @param parentRecordId ID of the parent record
     * @return Constructed Task record ready for insertion
     */
    public static Task constructTask(SObject record, Task_Generation_Rule__mdt rule, Id parentRecordId) {
        Task newTask = createBaseTask(rule);
        setTaskParentRelationship(newTask, record, parentRecordId);
        setTaskDueDate(newTask, rule);
        setTaskOwner(newTask, rule);
        return newTask;
    }

    private static Task createBaseTask(Task_Generation_Rule__mdt rule) {
        Task newTask = new Task();
        newTask.Category__c = rule.Category__c;
        newTask.Sub_Category__c = rule.Sub_Category__c;
        newTask.Status = ConstantsUtil.TASK_STATUS_DEFAULT;
        newTask.Priority = ConstantsUtil.TASK_PRIORITY_DEFAULT;
        if (String.isNotBlank(rule.Subject__c)) {
            newTask.Subject = rule.Subject__c;
        }
        return newTask;
    }

    private static void setTaskParentRelationship(Task newTask, SObject record, Id parentRecordId) {
        String objectType = record.getSObjectType().getDescribe().getName();
        if (objectType == 'Lead' || objectType == 'Contact') {
            newTask.WhoId = parentRecordId;
        } else {
            newTask.WhatId = parentRecordId;
        }
    }

    private static void setTaskDueDate(Task newTask, Task_Generation_Rule__mdt rule) {
        if (rule.Due_Date_Offset__c != null) {
            Date calculatedDate = Date.today().addDays(Integer.valueOf(rule.Due_Date_Offset__c));
            newTask.ActivityDate = TaskGenerationCore.getNextBusinessDate(calculatedDate);
        }
    }

    private static void setTaskOwner(Task newTask, Task_Generation_Rule__mdt rule) {
        Id assignedOwnerId = TaskGenerationCore.resolveOwner(rule.Owner_Type__c);
        if (assignedOwnerId != null) {
            newTask.OwnerId = assignedOwnerId;
        }
    }
}