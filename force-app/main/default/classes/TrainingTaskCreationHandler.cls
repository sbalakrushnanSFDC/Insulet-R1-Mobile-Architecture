/**
 * @author      : Bhavya Chanan
 * @created Date: 5th Jan 2026
 * @description : Handler Class to Create Training Activities Tasks
 * ============================ Logs =============================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       12th Jan 2026       Bhavya Chanan                 Initial Version NGOMCT-583
 * V1.0.1       23rd Jan 2026       Bhavya Chanan                 NGOMCT-1213
 */
public inherited sharing class TrainingTaskCreationHandler 
{
    public static final String FORCE_EXCEPTION= 'FORCE_EXCEPTION';
    
    /**
    * @description Create Training Activities tasks
    * @param newTrainings The param context containing newTraining records
    * @param oldTrainings The param containing oldTraining records
    */
    public static void createTasks(
        Map<Id, Training__c> newTrainings,
        Map<Id, Training__c> oldTrainings
    ) 
    {
        try
        {
            Map<Id, Id> accountToContactMap = getAccountToPersonContactMap(newTrainings.values());              
            Id taskRecordTypeId = getTaskRecordTypeId(ConstantsUtil.TASK_TRAINING_ACTIVITIES_RT);
        	if (taskRecordTypeId == null) {
                return;
            }
            
        	List<Task> tasksToInsert = new List<Task>();
            for (Training__c trainingRec : newTrainings.values()) {
                
            Training__c oldRec = oldTrainings != null ? oldTrainings.get(trainingRec.Id) : null;
                
            Id contactId = accountToContactMap.get(trainingRec.Account__c);
         
            Boolean validType = trainingRec.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_IT || trainingRec.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_CTS;

            Boolean trainingConductedDatePresent = trainingRec.Training_Conducted_Date__c != null;

            Boolean trainingConductedDateJustSet = oldRec == null || oldRec.Training_Conducted_Date__c == null;                  
            if (validType && trainingConductedDatePresent && trainingConductedDateJustSet) {                
                     
                Task task = new Task();
                task.Subject = ConstantsUtil.TASK_SUBJECT_PATIENT_7_DAY_FOLLOWUP;
                task.ActivityDate = trainingRec.Training_Conducted_Date__c.addDays(7);
                task.WhatId = trainingRec.Id;
                task.WhoId = contactId;
                task.RecordTypeId = taskRecordTypeId;

                // Owner assignment
                if (trainingRec.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_IT) {
                    task.OwnerId = trainingRec.CSM__c;
                } else if (trainingRec.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_CTS) {
                    task.OwnerId = trainingRec.Internal_Trainer__c;
                }
                

                if (task.OwnerId != null) {
                    
                    tasksToInsert.add(task);
                }
            }
        }

        if (!tasksToInsert.isEmpty()) {
            Database.insert(
                tasksToInsert,
                false,
                AccessLevel.SYSTEM_MODE
            );            
          
        }
                            
        }
        
        catch (Exception ex) {
            Logger.error('TrainingTaskCreationHandler.createTasks', ex);
            Logger.saveLog();
            
        }                
    }
    
    
    /**
    * @description Returns Dynamic Task Record Type lookup
    * @param recordTypeName The param containing recordypeName
    * @return Id is returned
    */
    public static Id getTaskRecordTypeId(String recordTypeName) {
        try{
            if (Test.isRunningTest() && recordTypeName == FORCE_EXCEPTION) {
            throw new IllegalArgumentException('Forced for test');
            }
            Map<String, Schema.RecordTypeInfo> recordtypeMap =
            Schema.SObjectType.Task.getRecordTypeInfosByName();

        return recordtypeMap.containsKey(recordTypeName)
            ? recordtypeMap.get(recordTypeName).getRecordTypeId()
            : null;
            
        }
        
        catch (Exception ex) {
            Logger.error('TrainingTaskCreationHandler.getTaskRecordTypeId', ex);
            Logger.saveLog();
            return null;
        }        
    }
    
    /**
    * @description Returns a map of AccountId -> PersonContactId
    * @param trainings The param containing training records
    * @return Map<Id, Id> is returned
    */
    public static Map<Id, Id> getAccountToPersonContactMap(
        List<Training__c> trainings
    ) {
        Set<Id> accountIds = new Set<Id>();
        try{
            for (Training__c tr : trainings) {
            if (tr.Account__c != null) {
                accountIds.add(tr.Account__c);
            }
        }

        Map<Id, Id> accountToContactMap = new Map<Id, Id>();

        if (accountIds.isEmpty()) {
            return accountToContactMap;
        }

        for (Account acc : [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id IN :accountIds
            AND PersonContactId != null
            WITH SYSTEM_MODE
        ]) {
            accountToContactMap.put(acc.Id, acc.PersonContactId);
        }

        return accountToContactMap;
            
        }
        
        catch (Exception ex) {
            Logger.error('TrainingTaskCreationHandler.getAccountToPersonContactMap', ex);
            Logger.saveLog();
            return null;
        }                        
    }
}