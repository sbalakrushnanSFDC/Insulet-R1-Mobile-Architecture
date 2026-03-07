/**
 * @author      : Ankur Chauhan
 * @created Date: 23rd Oct 2025
 * @description : Training Assignment Controller Class
 * Determines who will be the CSM of the Training
 * @story Number: NGOMCT-337
 * Version      Modified Date       Modified By         Brief Note
 * V1.0.0       23rd Oct 2025       Ankur Chauhan       Initial Version
 * V1.0.1       3rd Nov 2025        Ankur Chauhan       NGOMCT-689
 * V1.0.2       19th Nov 2025       Srinivas            NGOMCT-787
 * V1.0.3       11th Dec 2025       Ankur Chauhan       Enhancements
 * v1.0.4       18th Dec 2025       Shashank            NGOMCT-1049
 * V1.0.5       23rd Dec 2025       Ankur Chauhan       NGOMCT-1516
 * V1.0.6       23rd Jan 2026       Bhavya Chanan       NGOMCT-1213
 * V1.0.7       12th Feb 2026       Yogesh Rana            (NGOMCT-2099)
 * V1.0.8		20th Feb 2026		Shashank Nigam		NGOMCT-2102
 *
 * NOTE: Suppressing CyclomaticComplexity temporarily - will be refactored.
 */
@SuppressWarnings('PMD.CyclomaticComplexity')
public inherited sharing class TrainingAssignmentHandler {
    private static Map<Id, Training__c> accVsTrainingMap;
  /**
   * @description Method to implement Training Assignment logic
   * @param trainingsToProcess The list of Training records to process.
   * @param oldTrainingsMap The map of old Training records.
   */
  public static void manageTrainingAssignments(
    List<Training__c> trainingsToProcess,
    Map<Id, Training__c> oldTrainingsMap
  ) {
    try {
      User currentUser = getCurrentUser();
      if(!currentUser.IsPortalEnabled){
        Map<String, Object> returnedMaps = getUserOfAccountTerritories(trainingsToProcess, oldTrainingsMap);
        if(returnedMaps == null){
          return;
        }

        Map<Id, Id> accountContactMap = (Map<Id, Id>)returnedMaps.get('accountContactMap');
        Map<Id, Id> contactAccountMap = (Map<Id, Id>)returnedMaps.get('contactAccountMap');
        Set<Id> ccAccountIds = (Set<Id>)returnedMaps.get('ccAccountIds');

        List<Map<Id, Id>> listOfMaps = new List<Map<Id, Id>>();
        listOfMaps.add((Map<Id, Id>)returnedMaps.get('accountTerritoryMap'));
        listOfMaps.add((Map<Id, Id>)returnedMaps.get('territoryUserMap'));

        Map<String, Object> parametersForPracticeCC = new Map<String, Object>();

        Map<Id, Schema.RecordTypeInfo> recordTypeInfoMap = Utility.getRecordTypeInfoMap('Training__c');

        for (Training__c training : trainingsToProcess) {
          String recordType = recordTypeInfoMap.get(training.RecordTypeId).getDeveloperName();

          parametersForPracticeCC.put('accountContactMap', accountContactMap);
          parametersForPracticeCC.put('contactAccountMap', contactAccountMap);
          parametersForPracticeCC.put('recordType', recordType);
          parametersForPracticeCC.put('training', training);
          parametersForPracticeCC.put('oldTrainingsMap', oldTrainingsMap);

          training.Practice__c = getPracticeForCC(parametersForPracticeCC);

          Id csmId = findCSM(listOfMaps, training.Account__c);
          if(csmId == null){
              continue;
          }

          if (isNewLiveTraining(training.Training_Stage__c, recordType) && isEducatorTypeItOtCc(training.Educator_Type__c)
          ) {
            training.CSM__c = csmId;
            if (training.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_IT) {
              training.Training_Stage__c = ConstantsUtil.STAGE_ACCEPTED;
            } else if(training.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_OT) {
              training.Training_Stage__c = ConstantsUtil.STAGE_COMPLETED;
              training.Completion_Date__c = System.today();
	      training.Training_Conducted_Date__c = Date.today();
            }
            else{
              training.Training_Stage__c = !ccAccountIds.contains(training.Practice__c) ? ConstantsUtil.STAGE_PENDING_ASSIGNMENT : ConstantsUtil.STAGE_PENDING_ACCEPTANCE;
            }
          } else if (
            training.Training_Stage__c == ConstantsUtil.STAGE_NEW &&
            recordType == ConstantsUtil.E_LEARNING_RECORD_TYPE &&
            training.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_SG
          ) {
            training.CSM__c = csmId;
            training.Training_Stage__c = ConstantsUtil.STAGE_IN_PROGRESS;
          }
        }
      }
    } catch (Exception e) {
      Logger.error('Error while Training Assignment', trainingsToProcess, e)
        .addTag(ConstantsUtil.OMCT_TAG);
      Logger.saveLog();
    }
  }

  /**
   * @description Method to get list of Account Ids with their associated Territory Ids AND Territories with their associated User Ids
   * @param trainingsToProcess The list of Training records to process.
   * @param oldTrainingsMap The map of old Training records.
   * @return The list of maps containing the Account Ids and their associated Territory Ids, and the Territory Ids and their associated User Ids.
   */
  public static Map<String, Object> getUserOfAccountTerritories(
    List<Training__c> trainingsToProcess,
    Map<Id, Training__c> oldTrainingsMap
  ) {
    if (trainingsToProcess == null || trainingsToProcess.isEmpty()) {
      return null;
    }

    Set<Id> accountIds = new Set<Id>();
    Set<Id> ccAccountIds = new Set<Id>();

    for (Training__c training : trainingsToProcess) {
      Training__c oldTraining = oldTrainingsMap != null && !oldTrainingsMap.isEmpty() ? oldTrainingsMap.get(training.Id) : null;
      if (isTrainingEligible(training, oldTraining)) {
        accountIds.add(training.Account__c);
      }
    }

    List<AccountContactRelation> accountRelationRecords = [SELECT Id, AccountId, ContactId FROM AccountContactRelation WHERE Roles = 'Trainer' WITH SYSTEM_MODE LIMIT 50000];
    for(AccountContactRelation accRelation: accountRelationRecords){
        ccAccountIds.add(accRelation.AccountId);
    }


    Map<Id, Id> accountContactMap = new Map<Id, Id>();
    List<Account> associatedAccountRecords = [SELECT Id, PersonContactId FROM Account WHERE Id =: accountIds WITH SYSTEM_MODE LIMIT 50000];
    for(Account associatedAccount: associatedAccountRecords){
        accountContactMap.put(associatedAccount.Id, associatedAccount.PersonContactId);
    }

    List<AccountContactRelation> relationRecords = [SELECT Id, AccountId, ContactId FROM AccountContactRelation WHERE ContactId = :accountContactMap.values() AND Roles = :ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE AND isActive = True AND Is_Primary__c = True WITH SYSTEM_MODE LIMIT 50000];
    Map<Id, Id> contactAccountMap = new Map<Id, Id>();
    for(AccountContactRelation relation: relationRecords){
        contactAccountMap.put(relation.ContactId, relation.AccountId);
    }

    if (accountIds == null || accountIds.isEmpty()) {
      return null;
    }


    List<ObjectTerritory2Association> territoryAssociatedRecords = [
      SELECT Territory2Id, objectId
      FROM ObjectTerritory2Association
      WHERE ObjectId = :accountIds
      WITH SYSTEM_MODE LIMIT 50000
    ];

    Map<Id, Id> accountTerritoryMap = new Map<Id, Id>();
    for (ObjectTerritory2Association territory : territoryAssociatedRecords) {
      accountTerritoryMap.put(territory.objectId, territory.Territory2Id);
    }

    List<UserTerritory2Association> territoryAssociatedUsers = [
      SELECT UserId, Territory2Id
      FROM UserTerritory2Association
      WHERE
        Territory2Id IN :accountTerritoryMap.values()
        AND RoleInTerritory2 = :ConstantsUtil.USER_PERSONA_CSM
      WITH SYSTEM_MODE LIMIT 50000
    ];

    Map<Id, Id> territoryUserMap = new Map<Id, Id>();

    for (UserTerritory2Association user : territoryAssociatedUsers) {
      if (!territoryUserMap.containsKey(user.Territory2Id)) {
        territoryUserMap.put(user.Territory2Id, user.UserId);
      }
    }
    Map<String, Object> returnMaps = new Map<String, Object>();
    returnMaps.put('accountTerritoryMap', accountTerritoryMap);
    returnMaps.put('territoryUserMap', territoryUserMap);
    returnMaps.put('accountContactMap', accountContactMap);
    returnMaps.put('contactAccountMap', contactAccountMap);
    returnMaps.put('ccAccountIds', ccAccountIds);
    return returnMaps;
  }

  /**
   * @description Method to find the CSM for the Account associated with the Training record
   * @param returnMaps The list of maps containing the Account Ids and their associated Territory Ids, and the Territory Ids and their associated User Ids.
   * @param trainingAccountId The Account Id associated with the Training record.
   * @return The User Id of the CSM associated with the Account.
   */
  public static Id findCSM(List<Map<Id, Id>> returnMaps, Id trainingAccountId) {
    if (returnMaps == null || returnMaps.isEmpty() || returnMaps.size() < 2) {
      return null;
    }
    Map<Id, Id> accountTerritoryMap = returnMaps[0];
    Map<Id, Id> territoryUserMap = returnMaps[1];
    Id csmId = territoryUserMap?.get(accountTerritoryMap?.get(trainingAccountId));
    return csmId;
  }

  /**
   * @description Method to check the eligibility of the Training record
   * @param training The Training record to check.
   * @param oldTraining The old Training record to compare with.
   * @return Boolean True if the Training record is eligible, false otherwise.
   */
  private static Boolean isTrainingEligible(
    Training__c training,
    Training__c oldTraining
  ) {
    Boolean isEligible =
      oldTraining == null ||
      (oldTraining.Training_Stage__c != training.Training_Stage__c ||
      oldTraining.RecordTypeId != training.RecordTypeId ||
      oldTraining.Educator_Type__c != training.Educator_Type__c);
    return isEligible;
  }

  /**
   * @description Method to check if the Training record's Stage is New and Record Type is Live Training
   * @param trainingStage The Training Stage field on the Training record.
   * @param recordType The Record Type field on the Training record.
   * @return Boolean True if the Training record's Stage is New and Record Type is Live Training, false otherwise.
   */
  private static Boolean isNewLiveTraining(String trainingStage, String recordType){
    return trainingStage == ConstantsUtil.STAGE_NEW && recordType == ConstantsUtil.LIVE_TRAINING_RECORD_TYPE;
  }

  /**
   * @description Method to check if the Educator type is IT or OT or CC
   * @param educatorType The Educator Type field on the Training record.
   * @return Boolean True if the Educator type is IT or OT or CC, false otherwise.
   */
  private static Boolean isEducatorTypeItOtCc(String educatorType){
    return educatorType == ConstantsUtil.EDUCATOR_TYPE_IT || educatorType == ConstantsUtil.EDUCATOR_TYPE_OT || educatorType == ConstantsUtil.EDUCATOR_TYPE_CC;
  }

  /**
   * @description Method to get the Practice for the CC Training record
   * @param parametersForPracticeCC Map of parameters(oldTrainingsMap, training, recordType, accountContactMap, contactAccountMap) for the CC Training record
   * @return Id of the Practice for the CC Training record
   */
  private static Id getPracticeForCC(Map<String, Object> parametersForPracticeCC){
    if (parametersForPracticeCC == null) {
        return null;
    }

    Map<Id, Training__c> oldTrainingsMap = (Map<Id, Training__c>)parametersForPracticeCC.get('oldTrainingsMap');
    Training__c training = (Training__c)parametersForPracticeCC.get('training');
    String recordType = (String)parametersForPracticeCC.get('recordType');
    Map<Id, Id> accountContactMap = (Map<Id, Id>)parametersForPracticeCC.get('accountContactMap');
    Map<Id, Id> contactAccountMap = (Map<Id, Id>)parametersForPracticeCC.get('contactAccountMap');
    Id practiceId;

    if(oldTrainingsMap != null && !oldTrainingsMap.containsKey(training.Id)){
        if(recordType == ConstantsUtil.LIVE_TRAINING_RECORD_TYPE){
            if(accountContactMap.containsKey(training.Account__c) && contactAccountMap.containsKey(accountContactMap.get(training.Account__c))){
              practiceId = contactAccountMap.get(accountContactMap.get(training.Account__c));
            }
        }
    }
    else {
      return (oldTrainingsMap != null && oldTrainingsMap.containsKey(training.Id)) ? oldTrainingsMap.get(training.Id).Practice__c : null;
    }
    return practiceId;
  }

  /**
   * @description Method to get the current User
   * @return User record of the current User
  */
  public static User getCurrentUser(){
    return [SELECT Id, IsPortalEnabled FROM User WHERE Id = :UserInfo.getUserId() WITH SYSTEM_MODE LIMIT 1];
  }

  /**
   * @description Method to set field values for Manual Assignment
   * @param newTrainingsMap Map of new Training__c records from Trigger.newMap.
   * @param oldTrainingsMap Map of old Training__c records from Trigger.oldMap.
  */
  public static void manageManualAssignments(Map<Id, Training__c> newTrainingsMap, Map<Id, Training__c> oldTrainingsMap){
    try{
      User currentUser = getCurrentUser();
      if(!currentUser.IsPortalEnabled){
        if(isMapNull(newTrainingsMap, oldTrainingsMap)){
          return;
        }
        List<Id> externalTrainerIds = new List<Id>();
        for(Training__c training : newTrainingsMap.values()){
          Training__c oldTraining = oldTrainingsMap.get(training.Id);
          if(training.External_Trainer__c != null && oldTraining.External_Trainer__c != training.External_Trainer__c){
            externalTrainerIds.add(training.External_Trainer__c);
          }
        }
        List<Account> relatedExternalTrainers = [SELECT Id, Trainer_Type__c FROM Account WHERE Id = :externalTrainerIds WITH SYSTEM_MODE];
        Map<Id, String> trainerAndTypeMap = new Map<Id, String>();
        for(Account trainer: relatedExternalTrainers){
          if(trainer.Trainer_Type__c == ConstantsUtil.CLINIC_CONTRACT_TRAINER){
            trainerAndTypeMap.put(trainer.Id, ConstantsUtil.EDUCATOR_TYPE_CC);
          }
          else if(trainer.Trainer_Type__c == ConstantsUtil.CERTIFIED_POD_TRAINER){
            trainerAndTypeMap.put(trainer.Id, ConstantsUtil.EDUCATOR_TYPE_CPT);
          }
        }
        // Iterate through updated Training records and apply manual assignment rules
        for(Training__c newTraining : newTrainingsMap.values()){
          Training__c oldTraining = oldTrainingsMap.get(newTraining.Id);
          // If Practice manually assigned/changed to a non-null value
          if(newTraining.Practice__c != null && oldTraining.Practice__c != newTraining.Practice__c){
            newTraining.Training_Stage__c = ConstantsUtil.STAGE_PENDING_ACCEPTANCE;
            newTraining.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CC;
            newTraining.Internal_Trainer__c = null;
          }
          // If External Trainer manually assigned/changed to a non-null value
          if(newTraining.External_Trainer__c != null && oldTraining.External_Trainer__c != newTraining.External_Trainer__c){
            newTraining.Training_Stage__c = ConstantsUtil.STAGE_PENDING_ACCEPTANCE;
            newTraining.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CPT;
            newTraining.Internal_Trainer__c = null;
          }
        }
      }
      // Covers the exception from the test class
      Utility.throwExceptionForTestCoverage();
    }
    catch (Exception e) {
      Logger.error('Error while Manual Training Assignment', newTrainingsMap.values(), e).addTag(ConstantsUtil.OMCT_TAG);
      Logger.saveLog();
    }
  }

  /**
   * @description Method to check if the Map is null or empty
   * @param newTrainingsMap Map of new Training__c records from Trigger.newMap.
   * @param oldTrainingsMap Map of old Training__c records from Trigger.oldMap.
   * @return Boolean True if the Maps are null or empty, false otherwise.
  */
  public static Boolean isMapNull(Map<Id, Training__c> newTrainingsMap, Map<Id, Training__c> oldTrainingsMap){
    return newTrainingsMap == null || newTrainingsMap.isEmpty() || oldTrainingsMap == null;
  }

  /**
   * @description method updates the Training stage.
   * @param newTrainings List of new Training__c records from Trigger.new.
   * @param oldTrainings Map of old Training__c records from Trigger.oldMap.
   * @param operation String representing the operation (insert or update).
   */
  public static void updateTrainingStage(List<Training__c> newTrainings, Map<Id, Training__c> oldTrainings,String operation) {
    try{
      for (Training__c newRec : newTrainings) {
        if (operation == ConstantsUtil.INSERT_OPERATION) {
            setTrainingStage(newRec);
        }else if (operation == ConstantsUtil.UPDATE_OPERATION) {
          Training__c oldRec = oldTrainings.get(newRec.Id);
          if (oldRec != null && !(oldRec.Training_Stage__c == ConstantsUtil.STAGE_ACCEPTED && newRec.Training_Stage__c == ConstantsUtil.STAGE_DECLINED)) {
            if ( (oldRec.Educator_Type__c != newRec.Educator_Type__c) || (oldRec.Internal_Trainer__c != newRec.Internal_Trainer__c) ) {
                setTrainingStage(newRec);
            }
          }
        }
      }

       // Step 1: Find records that need processing
       Map<Id, Training__c> recordsToProcess = getEligibleTrainingRecords(newTrainings, oldTrainings, operation);

       if (recordsToProcess != null && !recordsToProcess.isEmpty()){
          // Step 2: Query required parents
          Map<Id, Account> practiceAccountMap = getPracticeAccountMap(recordsToProcess.values());

          // Step 3: Validate practice accounts & update trainings
          updateTrainingRecords(recordsToProcess, practiceAccountMap);
       }

      // Covers the exception from the test class
      Utility.throwExceptionForTestCoverage();
    }
    catch (Exception e) {
      Logger.error('Error while updating training stage', newTrainings, e).addTag(ConstantsUtil.OMCT_TAG);
      Logger.saveLog();
    }
  }

  /**
   * @description method updates the Training stage.
   * @param newRec Training__c record from Trigger.new.
   */
  private static void setTrainingStage(Training__c newRec) {
    if (newRec.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_CTS) {
        newRec.Training_Stage__c = newRec.Internal_Trainer__c != null ? ConstantsUtil.STAGE_ACCEPTED : ConstantsUtil.STAGE_PENDING_ACCEPTANCE;
    }
  }

  /**
   * @description method updates the Training conducted date.
   * @param newTrainings List of new Training__c records from Trigger.new.
   * @param oldTrainingsMap Map of old Training__c records from Trigger.oldMap.
   */
  public static void updateTrainingConductedDate( List<Training__c> newTrainings,Map<Id, Training__c> oldTrainingsMap) 
  {
            Id  eLearningRtId = Schema.SObjectType.Training__c
            .getRecordTypeInfosByDeveloperName()
            .get(ConstantsUtil.E_LEARNING_RECORD_TYPE)
            .getRecordTypeId();
        
            for (Training__c newTraining : newTrainings) {
            try {
              Training__c oldTraining = oldTrainingsMap.get(newTraining.Id);

                if (
                    newTraining.RecordTypeId == eLearningRtId &&
                    oldTraining != null &&
                    oldTraining.Training_Stage__c != newTraining.Training_Stage__c &&
                    newTraining.Training_Stage__c == ConstantsUtil.STAGE_COMPLETED
                   ) 
                   {
                    newTraining.Training_Conducted_Date__c = Date.today();
                   }
            }
            catch (Exception e) {
              Logger.error('TrainingAssignmentHandler.updateTrainingConductedDate - RecordType lookup failed', e);
              Logger.saveLog();
              return ;
            }               
  }


  }
  /**
   * @description method updates the Internal Trainer field.
   * @param newTrainings List of new Training__c records from Trigger.new.
   * @param oldTrainings Map of old Training__c records from Trigger.oldMap.
   * @param operation String representing the operation (insert or update).
   */
  public static void updateTrainingInternalTrainer(List<Training__c> newTrainings, Map<Id, Training__c> oldTrainings, String operation) {
    try{
      for (Training__c newRec : newTrainings) {
        if (operation == ConstantsUtil.INSERT_OPERATION) {
          if(newRec.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_IT && newRec.CSM__c != null){
            newRec.Internal_Trainer__c = newRec.CSM__c;
            newRec.Training_Stage__c = ConstantsUtil.STAGE_ACCEPTED;
          }
        }
        else if (operation == ConstantsUtil.UPDATE_OPERATION) {
          Training__c oldRec = oldTrainings.get(newRec.Id);
          if(newRec.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_IT 
            && newRec.CSM__c != null 
            && newRec.Educator_Type__c != oldRec.Educator_Type__c){
            newRec.Internal_Trainer__c = newRec.CSM__c;
            newRec.Training_Stage__c = ConstantsUtil.STAGE_ACCEPTED;
          }
        }
      }
      // Covers the exception from the test class
      Utility.throwExceptionForTestCoverage();
    }
    catch (Exception e) {
      Logger.error('Error while updating training internal trainer', newTrainings, e).addTag('TrainingAssignmentHandler');
      Logger.saveLog();
    }
  }

  /**
    * @description Method to get the eligible Training records
    * @param newList List of new Training__c records from Trigger.new.
    * @param oldMap Map of old Training__c records from Trigger.oldMap.
    * @param operation String representing the operation (insert or update).
    * @return Map<Id, Training__c> Map of eligible Training records.
  */
  @TestVisible
  private static Map<Id, Training__c> getEligibleTrainingRecords(List<Training__c> newList, Map<Id, Training__c> oldMap, String operation) {
    Map<Id, Training__c> eligibleTrainingRecords = new Map<Id, Training__c>();

    for (Training__c newRec : newList) {
        if (!isTrainingEligible(newRec)){
          continue;
        }

        if (operation == ConstantsUtil.INSERT_OPERATION) {
            eligibleTrainingRecords.put(newRec.Id, newRec);
        }
        else if (operation == ConstantsUtil.UPDATE_OPERATION && isTrainingEligible(newRec, oldMap)) {
            eligibleTrainingRecords.put(newRec.Id, newRec);
        }
    }
    return eligibleTrainingRecords; 
  }

  /**
      * @description Method to check if the Training record is eligible
      * @param training Training__c record from Trigger.new.
      * @return Boolean True if the Training record is eligible, false otherwise.
  */
  @TestVisible
  private static Boolean isTrainingEligible(Training__c training) {
    return training.Training_Stage__c == ConstantsUtil.STAGE_NEW &&
           training.Educator_Type__c  == ConstantsUtil.EDUCATOR_TYPE_CC &&
           training.Practice__c != null;
  }

  /**
     * @description Method to check if the Training record is eligible
     * @param newRec Training__c record from Trigger.new.
     * @param oldMap Map of old Training__c records from Trigger.oldMap.
     * @return Boolean True if the Training record is eligible, false otherwise.
  */
  @TestVisible
  private static Boolean isTrainingEligible(Training__c newRec, Map<Id, Training__c> oldMap) {
     Training__c oldTraining = oldMap.get(newRec.Id);
     return newRec.Training_Stage__c != oldTraining.Training_Stage__c ||
            newRec.Educator_Type__c != oldTraining.Educator_Type__c ||
            newRec.Practice__c != oldTraining.Practice__c;
  }

  /**
     * @description Method to get the Practice account map
     * @param trainings List of Training__c records from Trigger.new.
     * @return Map<Id, Account> Map of Practice accounts.
  */
  @TestVisible
  private static Map<Id, Account> getPracticeAccountMap(
      List<Training__c> trainings
  ) {
      Set<Id> practiceIds = new Set<Id>();
      for (Training__c training : trainings) {
          practiceIds.add(training.Practice__c);
      }
      return new Map<Id, Account>([SELECT Id, Do_Not_Use_For_Training__c FROM Account WHERE Id IN :practiceIds WITH SYSTEM_MODE]);
  }

  /**
      * @description Method to update the Training records
      * @param trainingMap Map of Training__c records from Trigger.new.
      * @param practiceAccountMap Map of Practice__c records from Trigger.new.
  */
    
  @TestVisible
  private static void updateTrainingRecords(
    Map<Id, Training__c> trainingMap,
    Map<Id, Account> practiceAccountMap
  ) {
      for (Training__c training : trainingMap.values()) {
        Account practiceAccount = practiceAccountMap.get(training.Practice__c);
        // Update the Training record if the Practice account is marked as Do Not Use for Training
        if (practiceAccount != null && practiceAccount.Do_Not_Use_For_Training__c) {
            training.Training_Stage__c = ConstantsUtil.STAGE_ACCEPTED;
            training.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_IT;
            training.Practice__c = null;
            training.External_Trainer__c = null;
        }
      }
  }
  /**
   * @description Initializes in-memory lookup state for downstream updates by building a map of Account Id to its associated Training record.
   * This method must be invoked prior to physician and ship date updates that rely on accVsTrainingMap.
   * @param trainings List of Training__c records being processed from the trigger context.
   */
  public static void populateClassVariables(List<Training__c> trainings) {
    accVsTrainingMap = new Map<Id, Training__c>();
    Map<Id, Schema.RecordTypeInfo> recordTypeInfoMap = Utility.getRecordTypeInfoMap(
      ConstantsUtil.TRAINING_OBJECT_NAME
    );
    for (Training__c t : trainings) {
      if (
        recordTypeInfoMap.get(t.RecordTypeId).getDeveloperName() ==
        ConstantsUtil.LIVE_TRAINING_RECORD_TYPE
      ) {
        accVsTrainingMap.put(t.Account__c, t);
      }
    }
  }

  /**
   * @description Derives and sets Physician__c on each Training__c based on the primary Patient Provider relationship of the Account's PersonContact.
   * Leverages ContactContactRelation (PartyRoleRelation = Patient Provider) to map patient Account to related provider Account.
   * @param trainings List of Training__c records that need Physician__c populated.
   */
  public static void updatePhysician(List<Training__c> trainings) {
    Map<Id, Id> accVsPhysicianMap = new Map<Id, Id>();
    for (ContactContactRelation ccr : [
      SELECT PartyRoleRelation.Name, RelatedContact.AccountId, Contact.AccountId
      FROM ContactContactRelation
      WHERE
        Contact.AccountId IN :accVsTrainingMap.keySet()
        AND PartyRoleRelation.Name = :ConstantsUtil.PARTY_ROLE_RELATION_TYPE_PATIENT_PROVIDER
        AND Is_Primary__c = TRUE
        AND IsActive = TRUE
      WITH SYSTEM_MODE
      ORDER BY CreatedDate ASC
    ]) {
      accVsPhysicianMap.put(ccr.Contact.AccountId,ccr.RelatedContact.AccountId);
    }

    for (Training__c t : trainings) {
      if (accVsPhysicianMap.containsKey(t.Account__c)) {
        t.Physician__c = accVsPhysicianMap.get(t.Account__c);
      }
    }
  }

  /**
   * @description Populates Ship_Date__c on each Training__c using the earliest MedicationDispense Ship_Date__c for the patient Account.
   * Builds a patient Account to Ship Date map from MedicationDispense and assigns it to matching Training records.
   * @param trainings List of Training__c records that need Ship_Date__c populated.
   */
  public static void updateShipDate(List<Training__c> trainings) {
    Map<Id, Date> accVsShipDateMap = new Map<Id, Date>();
    for (MedicationDispense md : [
      SELECT Ship_Date__c, PatientId
      FROM MedicationDispense
      WHERE PatientId IN :accVsTrainingMap.keySet()
      WITH SYSTEM_MODE
      ORDER BY CreatedDate ASC
    ]) {
      accVsShipDateMap.put(md.PatientId, md.Ship_Date__c);
    }

    for (Training__c t : trainings) {
      if (accVsShipDateMap.containsKey(t.Account__c)) {
        t.Ship_Date__c = accVsShipDateMap.get(t.Account__c);
      }
    }
  }

}