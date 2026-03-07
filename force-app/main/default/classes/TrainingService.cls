/**
 * @description : Creates Training records from Lead during conversion
 *                Validates trainer eligibility based on certifications and contract status
 * Created Date : 06-11-2025
 * Created By   : Ayush Sharma
 * NOTE -System Mode  : DML and SOQL operations are executed for non-admin users who do not have access to Sobject fields.
 *                      To allow these operations for non-admin users, they must be executed in system context.
 *
 * Version      Modified Date       Modified By              Brief Note
 * V1.0.0       6th Nov 2025        Ayush Sharma             Initial Version (NGOMCT-657)
 * V1.0.1       1st Jan 2026        Srinivas Shanigarapu     Updated(US - NGOMCT-235)
 * V1.0.2       12th Jan 2026       Ayush Sharma             Added External Trainer validation logic (US-NGOMCT-1055)
 */
// Suppressing CyclomaticComplexity temporarily.
// The increased complexity is known and related to the existing code.
// This will be refactored and the suppression removed once the fix is completed.
 @SuppressWarnings('PMD.CyclomaticComplexity')
 public with sharing class TrainingService {
  // Logger tag for training service
  private static final String LOGGER_TAG = 'TrainingService';

  public static String errorTagName;
  @TestVisible
  private static Boolean isTestMode = false;

  /**
   * @description Logs error messages with context using Logger framework
   * @param message The error message
   * @param records List of SObject records related to the error
   * @param ex Exception object (can be null for permission errors)
   */
  @TestVisible
  private static void logError(
    String message,
    List<SObject> records,
    Exception ex
  ) {
    Logger.error(message, records, ex).addTag(errorTagName);
  }

  /**
   * @description Logs error messages with context using Logger framework
   * @param message The error message
   * @param record of SObject records related to the error
   * @param failedRec Database.SaveResult object (can be null for permission errors)
   */
  @TestVisible
  private static void logError(
    String message,
    SObject record,
    Database.SaveResult failedRec
  ) {
    Logger.error(message, failedRec).setRecord(record).addTag(errorTagName);
  }

  /**
   * @description Creates training records during lead conversion
   * @param records List of Lead records to process
   * @param tagName tag name for stream.
   */
  public static void createTrainings(List<Lead> records, String tagName) {
    if (records == null || records.isEmpty()) {
      return;
    }

    errorTagName = tagName;

    ProcessingContext context = new ProcessingContext();
    // Process each lead record to create CPT Training
    for (Lead record : records) {
      processLeadRecord(record, context);
    }

    if (context.trainingsToInsert.isEmpty()) {
      return;
    }

    // Insert CPT training records
    insertTrainingRecords(context);

    Logger.saveLog();
  }

  /**
   * @description Inserts training records with proper CRUD checks
   * @param context The processing context containing training to insert
   */
  @TestVisible
  private static void insertTrainingRecords(ProcessingContext context) {
    try {
      Database.SaveResult[] results = Database.insert(
        context.trainingsToInsert,
        false,
        AccessLevel.SYSTEM_MODE
      );

      for (Integer i = 0; i < results.size(); i++) {
        Database.SaveResult sr = results[i];
        if (!sr.isSuccess()) {
          logError(
            'Failed to insert CPT Training records ',
            context.trainingsToInsert[i],
            sr
          );
        }
      }

      // Covers the exception from the test class
      Utility.throwExceptionForTestCoverage();
    } catch (Exception ex) {
      logError(
        'Failed to insert CPT Training records ' +
          ex.getMessage() +
          ' ' +
          ex.getLineNumber(),
        context.trainingsToInsert,
        ex
      );
      return;
    }
  }

  /**
   * @description Processes a Lead record to create CPT Training Records
   * @param leadRecord The Lead record to process
   * @param context The processing context containing maps and lists
   */
  @TestVisible
  private static void processLeadRecord(
    Lead leadRecord,
    ProcessingContext context
  ) {
    TrainingName nameData = new TrainingName(leadRecord);

    Training__c trainingObj = buildTraining(
      nameData,
      ConstantsUtil.TRAINING_CPT_TRAINING_RT
    );

    context.trainingsToInsert.add(trainingObj);
  }

  /**
   * @description Builds Training__c record from name data
   * @param nameData The TrainingName containing name components
   * @param recordTypeId The Id containing CPT Training recordTypeId
   * @return Training__c record ready for insert
   */
  public static Training__c buildTraining(
    TrainingName nameData,
    Id recordTypeId
  ) {
    Training__c training = new Training__c();
    training.Account__c = nameData?.accountId;
    if (recordTypeId != null) {
      training.RecordTypeId = recordTypeId;
    }

    if (String.isNotBlank(training.Account__c)) {
      List<Account> accs = [
        SELECT id, Territory_Alias__c
        FROM Account
        WHERE Id = :training.Account__c
        WITH SYSTEM_MODE
      ];

      if (Test.isRunningTest() && isTestMode) {
        accs = new List<Account>();
      }

      if (accs.isEmpty()) {
        return training;
      }
      Map<Id, String> recordToAlias = AccountService.filterAccountsByAliasChange(
        accs,
        null
      );
      Set<String> aliasSet = new Set<String>(recordToAlias.values()); //recordToAlias intialized in the filterAccountsByAliasChange
      aliasSet.remove(null);
      Map<String, Id> aliasToUser = AccountService.getAliasToUserMapping(
        aliasSet
      );

      if (recordToAlias.containsKey(training.Account__c)) {
        String aliasVal = recordToAlias.get(training.Account__c);
        if (String.isBlank(aliasVal)) {
          training.CSM__c = null;
        } else if (aliasToUser.containsKey(aliasVal)) {
          training.CSM__c = aliasToUser.get(aliasVal);
        }
      }
    }
    return training;
  }

  /**
   * @description Inner class to hold processing context and reduce parameter passing
   */
  @TestVisible
  private class ProcessingContext {
    /**
     * @description List of training records to be inserted
     */
    public List<Training__c> trainingsToInsert { get; set; }

    /**
     * @description Constructor to initialize processing context collections
     */
    public ProcessingContext() {
      this.trainingsToInsert = new List<Training__c>();
    }
  }

  /**
   * @description Inner class to encapsulate training name data
   */
  public class TrainingName {
    /**
     * @description account id of the training for master detail field
     */
    public String accountId { get; set; }

    /**
     * @description Constructor for TrainingName using SObject record
     * @param record of the Lead
     */
    public TrainingName(SObject record) {
      if (record instanceof Lead) {
        Lead leadRecord = (Lead) record;
        this.accountId = leadRecord.ConvertedAccountId;
      }
    }
  }

  /**
   * @description Validates trainer assignments for Training records
   * Checks certification and contract expiration requirements
   * @param newTrainings List of new Training records
   * @param oldTrainingsMap Map of old Training records (can be empty for insert)
   * @param tagName tag name for stream.
   */
  public static void validateTrainerAssignments(
    List<Training__c> newTrainings,
    Map<Id, Training__c> oldTrainingsMap,
    String tagName
  ) {
    if (newTrainings == null || newTrainings.isEmpty()) {
      return;
    }

    errorTagName = tagName;

    try {
      // Collect trainers and products that need validation
      Map<Id, Training__c> trainingsToValidate = new Map<Id, Training__c>();
      Set<Id> trainerIds = new Set<Id>();
      Set<String> productNames = new Set<String>();

      for (Training__c training : newTrainings) {
        // Only validate Live Training record type AND CPT Educator Type
        if (shouldSkipValidation(training)) {
          continue;
        }

        Training__c oldTraining = oldTrainingsMap != null
          ? oldTrainingsMap.get(training.Id)
          : null;

        // Only validate if External_Trainer__c is set/changed
        if (training.External_Trainer__c != null) {
          // For insert: validate if trainer is set
          // For update: validate if trainer changed
          if (
            oldTraining == null ||
            oldTraining.External_Trainer__c != training.External_Trainer__c ||
            oldTraining.Product__c != training.Product__c
          ) {
            trainingsToValidate.put(training.Id, training);
            trainerIds.add(training.External_Trainer__c);
            if (String.isNotBlank(training.Product__c)) {
              productNames.add(training.Product__c);
            }
          }
        }
      }

      if (trainingsToValidate.isEmpty()) {
        return;
      }

      // Bulk query certifications
      Map<String, Boolean> certificationMap = buildCertificationMap(
        trainerIds,
        productNames
      );

      // Bulk query trainer contract expiration dates
      Map<Id, Date> trainerContractMap = buildTrainerContractMap(trainerIds);

      // Validate each training record
      for (Training__c training : trainingsToValidate.values()) {
        validateTrainingRecord(training, certificationMap, trainerContractMap);
      }

      // Covers the exception from the test class
      Utility.throwExceptionForTestCoverage();
    } catch (Exception ex) {
      logError(
        'Error validating trainer assignments: ' +
          ex.getMessage() +
          ' ' +
          ex.getLineNumber(),
        newTrainings,
        ex
      );
      Logger.saveLog();
    }
  }

  /**
   * @description Determines if validation should be skipped for a training record
   * Validation should only occur for Live Training record type and CPT Educator Type
   * @param training Training record to check
   * @return Boolean true if validation should be skipped, false otherwise
   */
  @TestVisible
  private static Boolean shouldSkipValidation(Training__c training) {
    return training.RecordTypeId != ConstantsUtil.TRAINING_LIVE_TRAINING_RT || training.Educator_Type__c != ConstantsUtil.EDUCATOR_TYPE_CPT;
  }

  /**
   * @description Builds a map of certification keys to indicate active certifications exist
   * Key format: "TrainerId|ProductName"
   * @param trainerIds Set of trainer Account IDs
   * @param productNames Set of product names
   * @return Map of certification keys to Boolean indicating certification exists
   */
  @TestVisible
  private static Map<String, Boolean> buildCertificationMap(
    Set<Id> trainerIds,
    Set<String> productNames
  ) {
    Map<String, Boolean> certificationMap = new Map<String, Boolean>();

    if (trainerIds.isEmpty() || productNames.isEmpty()) {
      return certificationMap;
    }

    List<Certification__c> certifications = [
      SELECT Id, Trainer_Name__c, Product__c, Certification_Expiration_Date__c
      FROM Certification__c
      WHERE
        Trainer_Name__c IN :trainerIds
        AND Product__c IN :productNames
        AND Certification_Expiration_Date__c >= TODAY
      WITH SYSTEM_MODE
    ];

    for (Certification__c cert : certifications) {
      String key = cert.Trainer_Name__c + '|' + cert.Product__c;
      certificationMap.put(key, true);
    }

    return certificationMap;
  }

  /**
   * @description Builds a map of trainer IDs to contract expiration dates
   * @param trainerIds Set of trainer Account IDs
   * @return Map of trainer ID to contract expiration date
   */
  @TestVisible
  private static Map<Id, Date> buildTrainerContractMap(Set<Id> trainerIds) {
    Map<Id, Date> contractMap = new Map<Id, Date>();

    if (trainerIds.isEmpty()) {
      return contractMap;
    }

    List<Account> trainers = [
      SELECT Id, Contract_Expiration_Date__c
      FROM Account
      WHERE Id IN :trainerIds
      WITH SYSTEM_MODE
    ];

    for (Account trainer : trainers) {
      contractMap.put(trainer.Id, trainer.Contract_Expiration_Date__c);
    }

    return contractMap;
  }

  /**
   * @description Validates a single training record against certification and contract requirements
   * @param training Training record to validate
   * @param certificationMap Map of certification keys to Boolean indicating certification exists
   * @param trainerContractMap Map of trainer IDs to contract expiration dates
   */
  @TestVisible
  private static void validateTrainingRecord(
    Training__c training,
    Map<String, Boolean> certificationMap,
    Map<Id, Date> trainerContractMap
  ) {
    Id trainerId = training.External_Trainer__c;
    String product = training.Product__c;
    String expiredCertificateError = System.Label.Expired_Certification_Error;
    expiredCertificateError = expiredCertificateError.replace('{productName}',product);

    // Validation 1: Check Certification
    if (String.isNotBlank(product)) {
      String certKey = trainerId + '|' + product;
      if (
        !certificationMap.containsKey(certKey) || !certificationMap.get(certKey)
      ) {
        training.addError(expiredCertificateError);
        return;
      }
    }

    // Validation 2: Check Contract Expiration
    Date contractExpiration = !trainerContractMap.isEmpty() && trainerContractMap.containsKey(trainerId) ? trainerContractMap.get(trainerId) : null;
    if (contractExpiration == null || contractExpiration < Date.today()) {
      training.addError(System.Label.Expired_Contract_Error);
      return;
    }
  }

  /**
   * @description Updates the Training records if the Practice account is marked as Do Not Use for Training
   * @param accounts List of Account records to process
   * @param oldAccountsMap Map of old Account records
   */
  public static void updateTrainingRecords(List<Account> accounts, Map<Id, Account> oldAccountsMap) {
    Set<Id> accountIds = new Set<Id>();

    // Get the account ids that are marked as Do Not Use for Training
    for (Account account : accounts) {
        Account oldAccount = oldAccountsMap.get(account.Id);
        if (account.Do_Not_Use_For_Training__c == true && oldAccount.Do_Not_Use_For_Training__c != true
          && account.Do_Not_Use_For_Training_Reason__c == ConstantsUtil.DO_NOT_USE_FOR_TRAINING_REASON_TERMINATED) {
            accountIds.add(account.Id);
        }
    }
    if (accountIds != null && !accountIds.isEmpty()) {
      List<Training__c> trainings = queryAndMergeTrainings(accountIds);

      if (trainings != null && !trainings.isEmpty()) {
        updateTrainings(trainings);
      }
    }
  }


  /**
   * @description Queries and merges Training records from both Practice and External Trainer relationships
   * @param accountIds Set of account ids to query
   * @return List of unique Training records
   */
  @TestVisible
  private static List<Training__c> queryAndMergeTrainings(Set<Id> accountIds) {
    // Query trainings and populate the trainingsMap and externalTrainerIds
    Set<Id> externalTrainerIds = new Set<Id>();
    Set<Id> patientAccountIds = new Set<Id>();
    Map<Id, Training__c> trainingsMap = new Map<Id, Training__c>();

    for (Training__c training : [SELECT Id, Educator_Type__c, Account__c, Training_Stage__c, Practice__c, External_Trainer__c FROM Training__c
                                WHERE Training_Stage__c != :ConstantsUtil.STAGE_COMPLETED
                                AND (Practice__c IN :accountIds OR External_Trainer__c IN :accountIds) WITH SYSTEM_MODE]) {
        trainingsMap.put(training.Id, training);
        if (training.External_Trainer__c != null) {
          externalTrainerIds.add(training.External_Trainer__c);
          patientAccountIds.add(training.Account__c);
        }
    }

    if (externalTrainerIds != null && !externalTrainerIds.isEmpty()) {
      removeAccountSharing(new List<Id>(externalTrainerIds), new List<Id>(patientAccountIds));
    }
    return new List<Training__c>(trainingsMap.values());
  }

  /**
   * @description Applies field updates and performs DML on Training records with error handling
   * @param trainings List of Training records to update
   */
  @TestVisible
  private static void updateTrainings(List<Training__c> trainings) {
    // Apply field updates
    for (Training__c training : trainings) {
      training.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_IT;
      training.Practice__c = null;
      training.External_Trainer__c = null;
      training.Training_Stage__c = ConstantsUtil.STAGE_ACCEPTED;
    }

    try {
      Database.SaveResult[] results = Database.update(
        trainings,
        false,
        AccessLevel.SYSTEM_MODE
      );

      handleUpdateResults(results, trainings);
      Utility.throwExceptionForTestCoverage();
    } catch (Exception ex) {
      Logger.error('DML Exception while updating Trainings: ' + ex.getMessage())
        .addTag(LOGGER_TAG);
      Logger.saveLog();
    }
  }

  /**
   * @description Handles and logs update results
   * @param results Database SaveResults from update operation
   * @param trainings List of Training records that were updated
   */
  @TestVisible
  private static void handleUpdateResults(
    Database.SaveResult[] results,
    List<Training__c> trainings
  ) {
    for (Integer i = 0; i < results.size(); i++) {
      Database.SaveResult sr = results[i];
      if (!sr.isSuccess()) {
        for (Database.Error err : sr.getErrors()) {
          Logger.error('Failed to update Training record: ' + err.getMessage(), sr)
            .setRecord(trainings[i])
            .addTag(LOGGER_TAG);
          Logger.saveLog();
        }
      }
    }
  }

  /**
   * @description Removes account sharing for external trainers
   * @param externalTrainerIds Set of external trainer ids
   * @param patientAccountIds Set of patient account ids
   */
  @TestVisible
  private static void removeAccountSharing(List<Id> externalTrainerIds, List<Id> patientAccountIds) {
    List<Id> trainerUserIds = new List<Id>();
    for (User user : [SELECT Id FROM User WHERE AccountId IN :externalTrainerIds WITH SYSTEM_MODE]) {
      trainerUserIds.add(user.Id);
    }
    List<Sobject> shareRecordsToDelete = new List<Sobject>();
    try {
      shareRecordsToDelete = Utility.deleteShares(patientAccountIds, trainerUserIds);

      if (shareRecordsToDelete != null && !shareRecordsToDelete.isEmpty()) {
          TrainingSharingHandlerSystemContext systemContext = new TrainingSharingHandlerSystemContext();
          Database.DeleteResult[] results = systemContext.deleteTrainingShareRecords(shareRecordsToDelete);
          handleDeleteResults(results, shareRecordsToDelete);
      }

        Utility.throwExceptionForTestCoverage();
    } catch (Exception e) {
          Logger.error('Error deleting AccountShare records for training access', shareRecordsToDelete, e)
              .addTag(LOGGER_TAG);
      Logger.saveLog();
    }
  }

  /**
     * @description Handles DML errors for delete operations (DeleteResult)
     * @param results Database.DeleteResult array from DML operation
     * @param records List of SObject records that failed
    */
    @TestVisible
    private static void handleDeleteResults(Database.DeleteResult[] results, List<SObject> records) {
        for (Integer resultIndex = 0; resultIndex < results.size(); resultIndex++) {
            if (!results[resultIndex].isSuccess()) {
                for (Database.Error err : results[resultIndex].getErrors()) {
                    Logger.error('Failed to delete AccountShare record: ' + err.getMessage(), results[resultIndex])
                        .setRecord(records[resultIndex])
                        .addTag(LOGGER_TAG);
                    Logger.saveLog();
                }
            }
        }
    }

   /**
     * @description Inner class to run AccountShare operations in system context
     * Required to create/delete AccountShare records for training access with elevated privileges
     * Uses 'without sharing' to bypass sharing rules for CSM users and system operations
     */
     public without sharing class TrainingSharingHandlerSystemContext {
      /**
       * @description Deletes AccountShare records with system privileges
       * Uses allOrNone=false to allow partial success and log individual failures
       * Runs in 'without sharing' context to ensure CSM users can delete shares
       * @param shareRecords List of AccountShare records to delete
       * @return Database.DeleteResult[] Results of the delete operation
       */
      public Database.DeleteResult[] deleteTrainingShareRecords(List<SObject> shareRecords) {
          return Database.delete(shareRecords, false, AccessLevel.SYSTEM_MODE);
      }
    }
}