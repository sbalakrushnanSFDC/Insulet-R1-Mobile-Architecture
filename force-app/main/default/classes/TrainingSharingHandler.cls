/**
 * @author      : Ankur Chauhan
 * @created Date: 23rd Oct 2025
 * @description : Training Records Sharing Controller Class
 * Shares the Training records with the appropriate users
 * @story Number: NGOMCT-689
 * =========================== Logs ==============================
 * Version      Modified Date       Modified By         Brief Note
 * V1.0.0       23rd Oct 2025       Ankur Chauhan       Initial Version
 * V1.0.1       23rd Dec 2025       Ankur Chauhan       NGOMCT-1516
 */
public inherited sharing class TrainingSharingHandler {
  /**
   * @description Method to implement Training Sharing logic
   * @param updatedTrainings The list of Training records to process.
   * @param oldTrainingsMap The map of old Training records.
   */
  public static void shareTrainingRecords(
    Map<Id, Training__c> updatedTrainings,
    Map<Id, Training__c> oldTrainingsMap
  ) {
    try {
      if (updatedTrainings == null || 
          oldTrainingsMap == null) {
        return;
      }
      List<Id> newTrainerIds = new List<Id>();
      for (Training__c training : updatedTrainings.values()) {
          newTrainerIds.add(training.External_Trainer__c);
      }

      List<Id> oldTrainerIds = new List<Id>();
      for (Training__c training : oldTrainingsMap.values()) {
          oldTrainerIds.add(training.External_Trainer__c);
      }

      Set<Id> allTrainerIds = new Set<Id>();
      allTrainerIds.addAll(newTrainerIds);
      allTrainerIds.addAll(oldTrainerIds);

      // Single SOQL query to fetch all relevant Users
      Map<Id, Id> allAccountIdToUserIdMap = new Map<Id, Id>();
      if (!allTrainerIds.isEmpty()) {
        for (User trainerUser : [
          SELECT Id, AccountId
          FROM User
          WHERE AccountId IN :allTrainerIds
          WITH SYSTEM_MODE LIMIT 50000
        ]) {
          allAccountIdToUserIdMap.put(trainerUser.AccountId, trainerUser.Id);
        }
      }

      Map<Id, Id> trainerIdToUserIdMap = new Map<Id, Id>();
      Map<Id, Id> oldTrainerIdToUserIdMap = new Map<Id, Id>();

      for (Id accountId : allAccountIdToUserIdMap.keySet()) {
        Id userId = allAccountIdToUserIdMap.get(accountId);
        if (newTrainerIds.contains(accountId)) {
          trainerIdToUserIdMap.put(accountId, userId);
        }
        if (oldTrainerIds.contains(accountId)) {
          oldTrainerIdToUserIdMap.put(accountId, userId);
        }
      }

      List<SObject> shareRequestList = new List<SObject>();

      Map<Id, Schema.RecordTypeInfo> recordTypeInfoMap = Utility.getRecordTypeInfoMap('Training__c');
      SharingContext sharingContext = new SharingContext();
      SharingContext returnedSharingContext = new SharingContext();

      for (Training__c training : updatedTrainings.values()) {
        Training__c oldTraining = oldTrainingsMap.get(training.Id);

        String recordType = recordTypeInfoMap.get(training.RecordTypeId).getDeveloperName();
        
        sharingContext.recordType = recordType;
        sharingContext.training = training;
        sharingContext.oldTraining = oldTraining;
        sharingContext.oldTrainerIdToUserIdMap = oldTrainerIdToUserIdMap;
        sharingContext.trainerIdToUserIdMap = trainerIdToUserIdMap;

        returnedSharingContext = processTrainingSharing(sharingContext);
      }
      shareRecord(returnedSharingContext.shareRequestList);
      removeRecordSharing(returnedSharingContext.recordIds, returnedSharingContext.userIds);

      // Covers the exception from the test class
      Utility.throwExceptionForTestCoverage();
    } catch (Exception e) {
      Logger.error(
          'Error while Sharing Training Record',
          updatedTrainings?.values(),
          e
        )
        .addTag(ConstantsUtil.OMCT_TAG);
      Logger.saveLog();
    }
  }

  /**
   * @description Wrapper class for SharingContext parameters
   */
  public class SharingContext {
    public String recordType;
    public Training__c training;
    public Training__c oldTraining;
    public Map<Id, Id> oldTrainerIdToUserIdMap;
    public Map<Id, Id> trainerIdToUserIdMap;
    public List<Sobject> shareRequestList;
    public List<Id> recordIds;
    public List<Id> userIds;
  }

  /**
   * @description Method to get Training records to be shared and records whose sharing to be removed
   * @param sharingContext The Sharing Context
   * @return SharingContext ShareRequestList- Records to be shared
   *                        RecordIds- Records whose sharing to be removed
   *                        UserIds- Users whose sharing to be removed
   */
  public static SharingContext processTrainingSharing(SharingContext sharingContext) {
    List<SObject> shareRequestList = new List<SObject>();
    List<Id> recordIds = new List<Id>();
    List<Id> userIds = new List<Id>();

    if (sharingContext.recordType == ConstantsUtil.LIVE_TRAINING_RECORD_TYPE) {
      if (sharingContext.training.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_CC) {
        if (
          isStagePendingAcceptanceOrDeclinedFromAccepted(
            sharingContext.training,
            sharingContext.oldTraining,
            sharingContext.oldTrainerIdToUserIdMap
          )
        ) {
          recordIds.add(sharingContext.training.Account__c);
          userIds.add(
            sharingContext.oldTrainerIdToUserIdMap.get(sharingContext.training.External_Trainer__c)
          );
        } else if (
          isTrainingStageChangedAndAccepted(sharingContext.training, sharingContext.oldTraining)
        ) {
          Sobject shareInstance = shareAssociatedAccount(
            sharingContext.training,
            sharingContext.oldTraining,
            sharingContext.trainerIdToUserIdMap
          );
          shareRequestList.add(shareInstance);
        }
      } else if (sharingContext.training.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_CPT) {
        if (
          isStageDeclinedFromAccepted(
            sharingContext.training,
            sharingContext.oldTraining,
            sharingContext.oldTrainerIdToUserIdMap
          )
        ) {
          recordIds.add(sharingContext.training.Account__c);
          userIds.add(
            sharingContext.oldTrainerIdToUserIdMap.get(sharingContext.training.External_Trainer__c)
          );
        } else if (
          isTrainingStageChangedAndAccepted(sharingContext.training, sharingContext.oldTraining)
        ) {
          Sobject shareInstance = shareAssociatedAccount(
            sharingContext.training,
            sharingContext.oldTraining,
            sharingContext.trainerIdToUserIdMap
          );
          shareRequestList.add(shareInstance);
        }
      }
    }
    SharingContext returnedSharingContext = new SharingContext();
    returnedSharingContext.recordIds = recordIds;
    returnedSharingContext.userIds = userIds;
    returnedSharingContext.shareRequestList = shareRequestList;
    return returnedSharingContext;
  }

  /**
   * @description Method to share records
   * @param shareRequestList List of SObject records to share
   */
  public static void shareRecord(List<SObject> shareRequestList) {
    if(!shareRequestList.isEmpty()){
      TrainingSharingHandlerSystemContext tcst = new TrainingSharingHandlerSystemContext();
      tcst.shareRecordSystemContext(shareRequestList);
    }
  }

  /**
   * @description Method to remove Record Sharing
   * @param recordIds List of Record Ids to remove sharing
   * @param userIds List of User Ids to remove sharing
   */
  public static void removeRecordSharing(List<Id> recordIds, List<Id> userIds) {
    List<Sobject> result = Utility.deleteShares(recordIds, userIds);
    if (result != null) {
      Database.delete(result, AccessLevel.SYSTEM_MODE);
    }
  }

  /**
   * @description Method to check if Training Stage is changed and Accepted
   * @param training The Training record to check.
   * @param oldTraining The old Training record to compare with.
   * @return Boolean True if Training Stage is changed and Accepted, false otherwise.
   */
  public static Boolean isTrainingStageChangedAndAccepted(
    Training__c training,
    Training__c oldTraining
  ) {
    return training.Training_Stage__c == ConstantsUtil.STAGE_ACCEPTED &&
      oldTraining.Training_Stage__c != training.Training_Stage__c;
  }

  /**
   * @description Method to check if Training Stage is Pending Acceptance or Declined and Priorly Accepted
   * @param training The Training record to check.
   * @param oldTraining The old Training record to compare with.
   * @param oldTrainerIdToUserIdMap Map of old Trainer Id to User Id
   * @return Boolean True if Training Stage is Pending Acceptance or Declined and Priorly Accepted, false otherwise.
   */
  public static Boolean isStagePendingAcceptanceOrDeclinedFromAccepted(
    Training__c training,
    Training__c oldTraining,
    Map<Id, Id> oldTrainerIdToUserIdMap
  ) {
    return (training.Training_Stage__c == ConstantsUtil.STAGE_PENDING_ACCEPTANCE ||
      training.Training_Stage__c == ConstantsUtil.STAGE_DECLINED) &&
      oldTraining.Training_Stage__c == ConstantsUtil.STAGE_ACCEPTED &&
      oldTrainerIdToUserIdMap.containsKey(training.External_Trainer__c);
  }

  /**
   * @description Method to check if Training Stage is changed from Accepted to Declined
   * @param training The Training record to check.
   * @param oldTraining The old Training record to compare with.
   * @param oldTrainerIdToUserIdMap Map of old Trainer Id to User Id
   * @return Boolean True if Training Stage is changed from Accepted to Declined, false otherwise.
   */
  public static Boolean isStageDeclinedFromAccepted(
    Training__c training,
    Training__c oldTraining,
    Map<Id, Id> oldTrainerIdToUserIdMap
  ) {
    return training.Training_Stage__c == ConstantsUtil.STAGE_DECLINED &&
      oldTraining.Training_Stage__c == ConstantsUtil.STAGE_ACCEPTED &&
      oldTrainerIdToUserIdMap.containsKey(training.External_Trainer__c);
  }

  /**
   * @description Method to share the associated Account with the External Trainer
   * @param training Training record whose account to be shared
   * @param oldTraining Old Training record
   * @param trainerIdToUserIdMap Map of Trainer Id to User Id
   * @return Sobject Share Instance
   */
  public static Sobject shareAssociatedAccount(
    Training__c training,
    Training__c oldTraining,
    Map<Id, Id> trainerIdToUserIdMap
  ) {
    Utility.CreateShareRecordParameterDetailWrap shareRequest = new Utility.CreateShareRecordParameterDetailWrap();
    shareRequest.recordId = training.Account__c;
    if (trainerIdToUserIdMap.containsKey(training.External_Trainer__c)) {
      shareRequest.userOrGroupId = trainerIdToUserIdMap.get(
        training.External_Trainer__c
      );
    } else {
      return null;
    }
    shareRequest.accessLevel = 'Edit';
    shareRequest.rowCause = '';
    Sobject result = Utility.createShare(shareRequest);
    return result;
  }

  /**
   * @description Exception class for TrainingSharingHandler
   */
  public class MyCustomException extends Exception {
  }
  /**
   * @description Exception class for TrainingSharingHandler
   */
  public without sharing class TrainingSharingHandlerSystemContext{
    /**
    * @description This method will always run 'without sharing',
    * allowing it to query all records.
    * @param shareRequestList List of SObject records to share
    */
    public void shareRecordSystemContext(List<SObject> shareRequestList) {
      Database.insert(shareRequestList, AccessLevel.SYSTEM_MODE);
    }
  }
}