/**
 * @description This class handles common functionalities related to Training__c records,
 * including retrieving Record Type Ids and other related operations.
 * Jira Story Number: NGOMCT-645 AND NGOMCT-646
 * Developer: Srinivas
 * Date: 31/10/2025
 * Note: Without Sharing: CPT/CC users do not have access to training records prior to acceptance. To display all trainings pending acceptance in the Available Trainings list view within the portal—allowing 
 *                        users to accept or decline trainings—this class is implemented using without sharing.
 *       System Mode    : DML operations are executed for Portal/Community users who lack access to certain fields (for example, External_Trainer__c). Since updating these fields is required to accept, decline, 
 *                        or reassign training records, the operations must run in system context.
 *       Logging        : Logging is implemented for all @AuraEnabled(cacheable=false) methods and Parent methods. It is intentionally omitted for @AuraEnabled(cacheable=true) methods, as these are read-only.
 * 
 * V1.0.0       31st Oct 2025       Srinivas                Initial Version(NGOMCT-645 AND NGOMCT-646)
 * V1.0.1       19th Nov 2025       Srinivas                Modified Version(NGOMCT-787)
 * v1.0.2       10th Dec 2025       Shashank Nigam          Modified Version (NGOMCT-1049)
 * v1.0.3       10th FEB 2026       Shashank Nigam          Modified Version (NGOMCT-2094)
 * v1.0.4       23rd Feb 2026       Ankur Chauhan           NGOMCT-2305(Added logic to retrieve indirect trainings from MLC)
 */
public without sharing class TrainingController {
  /**
   * @description Updates the Training record stage to 'Pending Acceptance' and clears the Completion Date.
   * @param trainingId The ID of the Training__c record to update.
   */
  @AuraEnabled
  public static void reassignTraining(String trainingId) {
    try {
      // validateString(trainingId, 'Training record ID cannot be null.');
      Training__c trainingRecord = new Training__c(
        Id = trainingId,
        Training_Stage__c = ConstantsUtil.STAGE_PENDING_ACCEPTANCE,
        External_Trainer__c = null,
        Completion_Date__c = null
      );

      Database.update(trainingRecord, AccessLevel.SYSTEM_MODE);
    } catch (Exception e) {
      Logger.error(
          'An error occurred while updating training records: ' + e.getMessage()
        )
        .addTag('TrainingController');
      Logger.saveLog();
      throw new AuraHandledException(
        'An error occurred while updating training records: ' + e.getMessage()
      );
    }
  }


  /**
   * @description Retrieves the picklist values for the 'Decline_Reason__c' field on the Training__c object.
   * @return A list of PicklistOption objects containing the label and value of each picklist value.
   * Comments: Picklist values are fetched through Apex since the portal user lacked the necessary permissions for this field during development.
   */
  @AuraEnabled(cacheable=false)
  public static List<PicklistOption> getDeclineReasonPicklistValues() {
    List<PicklistOption> options = new List<PicklistOption>();
    Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe()
      .get(ConstantsUtil.TRAINING_OBJECT_NAME)
      .getDescribe();

    if (
      objectDescribe.fields.getMap()
        .get(ConstantsUtil.REASON_FIELD)
        .getDescribe()
        .isAccessible()
    ) {
      List<Schema.PicklistEntry> picklistValues = objectDescribe.fields.getMap()
        .get(ConstantsUtil.REASON_FIELD)
        .getDescribe()
        .getPicklistValues();
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.isActive() && entry.getValue() != null) {
          options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
        }
      }
    }
    return options;
  }

  /**
   * @description Updates the training stage to 'Accepted' for the specified training record.
   * @param trainingId The Id of the Training__c record.
   * @param isClickFromQuickAction A boolean indicating if the action was triggered from a quick action.
   * @return The status of the operation.
   */
  @AuraEnabled(cacheable=false)
  public static String updateTrainingStage(
    String trainingId,
    Boolean isClickFromQuickAction
  ) {
    if(String.isBlank(trainingId))  {
        throw new AuraHandledException('Training record ID cannot be null.');
    }
    try {
      // validateString(trainingId, 'Training record ID cannot be null.');
      List<Training__c> trainings = [
        SELECT
          Id,
          Decline_Reason__c,
          Decline_Comments__c,
          Training_Stage__c,
          Internal_Trainer__c,
          External_Trainer__c,
          Product__c,
          Educator_Type__c,
          External_Trainer__r.Contract_Expiration_Date__c,
          Practice__r.Contract_Expiration_Date__c
        FROM Training__c
        WHERE Id = :trainingId
        WITH SYSTEM_MODE
      ];

      if (trainings.isEmpty()) {
        throw new AuraHandledException('Training records not found.');
      }
      if (trainings[0].Training_Stage__c == ConstantsUtil.STAGE_ACCEPTED) {
        return ConstantsUtil.ALREADY_ACCEPTED;
      }
      trainings[0].Training_Stage__c = ConstantsUtil.STAGE_ACCEPTED;
      trainings[0].Decline_Reason__c = '';
      trainings[0].Decline_Comments__c = '';

      if (isClickFromQuickAction == false) {
        if(trainings[0].Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_CPT && trainings[0].External_Trainer__r.Contract_Expiration_Date__c < System.Today()){
          return System.Label.No_Active_Contract_CPT;
        }
        else if(trainings[0].Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_CC && trainings[0].Practice__r.Contract_Expiration_Date__c < System.Today()){
          return System.Label.No_Active_Contract_Practice;
        }
        Account personAcc = getCurrentUserContactId();
        List<Certification__c> certificateList = [Select id from Certification__c where Trainer_Name__c =:personAcc.Id and Product__c = :trainings[0].Product__c and Certification_Expiration_Date__c>=:System.Today() WITH USER_MODE];
        if(certificateList.isEmpty()){
          return System.Label.No_Active_Certification.replace('{product}', trainings[0].Product__c); //'You don\'t have an active ' + trainings[0].Product__c + ' certificate.';
        }
        trainings[0].External_Trainer__c = personAcc.Id;
      } else {
        trainings[0].Internal_Trainer__c = UserInfo.getUserId();
      }

      Database.update(trainings, AccessLevel.SYSTEM_MODE);
      return ConstantsUtil.SUCCESS;
    } catch (Exception e) {
      Logger.error(
          'An error occurred while updating training stage: ' + e.getMessage()
        )
        .addTag('TrainingController');
      Logger.saveLog();
      return System.Label.Error_Message;
      // throw new AuraHandledException(
      //   'An error occurred while updating training records: ' + e.getMessage()
      // );
    }
  }

  /**
   * @description Updates the Decline Reason and Comments on the Training__c record.
   * @param declineWrapperRequest The declineWrapperRequest object containing the trainingId, declineReason, declineComments, and isClickFromQuickAction.
   */
  @AuraEnabled
  public static void updateTrainingDeclineData(String declineWrapperRequest) {
    try {
      TrainingDeclineWrapper request = (TrainingDeclineWrapper) JSON.deserialize(
        declineWrapperRequest,
        TrainingDeclineWrapper.class
      );
      // validateString(request.trainingId, 'Training record ID cannot be null.');
      Training__c trainingRecord = new Training__c(
        Id = request.trainingId,
        Decline_Reason__c = request.declineReason,
        Decline_Comments__c = request.declineComments,
        Training_Stage__c = ConstantsUtil.STAGE_DECLINED,
        Completion_Date__c = null
      );

      if (request.isClickFromQuickAction == true) {
        trainingRecord.Internal_Trainer__c = null;
      } else {
        trainingRecord.External_Trainer__c = null;
      }

      Database.update(trainingRecord, AccessLevel.SYSTEM_MODE);
    } catch (Exception e) {
      Logger.error(
          'An error occurred while updating training record: ' + e.getMessage()
        )
        .addTag('TrainingController');
      Logger.saveLog();
      throw new AuraHandledException(
        'An error occurred while updating training record: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Retrieves the Contact ID of the currently logged-in user.
   * @return The Contact ID of the user.
   */
  public static Account getCurrentUserContactId() {
    // Use sub-query for efficiency and direct result access
    try{

      List<Account> personContacts = [SELECT Id, Trainer_Type__c, PersonContactId FROM Account WHERE PersonContactId IN (SELECT ContactId FROM User WHERE Id =:UserInfo.getUserId()) AND Trainer_Type__c IN (:System.Label.Trainer_Type_CC ,:System.Label.Trainer_Type_CPT ,:System.Label.Trainer_Type_CPT_CC) WITH SYSTEM_MODE];
      if (personContacts.isEmpty()) {
          throw new AuraHandledException(
            'No Person Contact found for the logged-in user or invalid Trainer Type.'
          );
        }
        return personContacts[0];
    }
    catch(Exception e){
      Logger.error(
          'An error occured while getting User person contact Id: ' +
          e.getMessage()
        )
        .addTag('TrainingController');
      Logger.saveLog();
      throw new AuraHandledException(
        'An error occured while getting User person contact Id: ' +
        e.getMessage()
      );
    }
  }

  /**
   * @description Retrieves the trainer data and table info.
   * @param contactId The Id of the PersonContact record.
   * @return The trainer data and table info.
   */

   @AuraEnabled(cacheable = true)
   public static TrainerWrapper loadData(String contactId){
    try {
        if(String.isBlank(contactId))  {
        	throw new AuraHandledException('Contact Id is required');
    	}
        Account trainerAccount = [SELECT Id,Trainer_Type__c,PersonContactId FROM Account WHERE PersonContactId = :contactId WITH SYSTEM_MODE]; // Get Trainer Record
        List<String> practiceAccountIdList = new List<String>();
        for(AccountContactRelation  acr: [Select AccountId from AccountContactRelation where ContactId = :contactId AND Roles =:ConstantsUtil.ACR_ROLE_TRAINER AND IsActive = true WITH SYSTEM_MODE]){
            practiceAccountIdList.add(acr.AccountId);
        }
        Boolean isPractice = [SELECT Id FROM Account WHERE PersonContactId IN (SELECT ContactId FROM AccountContactRelation WHERE AccountId In :practiceAccountIdList AND Roles = :ConstantsUtil.ACR_ROLE_TRAINER AND IsActive = true) WITH SYSTEM_MODE].size() > 1;
        TrainerWrapper trainerWrapper = new TrainerWrapper();
        trainerWrapper.trainerId = trainerAccount.Id;
        trainerWrapper.isPractice = isPractice;
        trainerWrapper.practiceId = String.join(practiceAccountIdList, ',');
        trainerWrapper.trainerType = trainerAccount.Trainer_Type__c;
        trainerWrapper.options = getDeclineReasonPicklistValues();
        
        return trainerWrapper;
    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * @description Gets training details for a given contact and training ID.
   * @param contactId The Id of the PersonContact record.
   * @param trainingId The Id of the Training__c record.
   * @return TrainerWrapper containing training and trainer details.
   */

  @AuraEnabled(cacheable = true)
  public static TrainerWrapper getTrainingDetails(String contactId, String trainingId){
    try {
        if(String.isBlank(contactId) || String.isBlank(trainingId))  {
        	throw new AuraHandledException('Contact Id and Training Id are required');
    	}
      TrainerWrapper wrapper = new TrainerWrapper();
      wrapper.training = [Select id,Training_Stage__c,Practice__c,RecordTypeId from Training__c where Id = :trainingId];
      wrapper.trainerType = [Select id,Trainer_Type__c from Account where personContactId = : contactId].Trainer_Type__c;
      wrapper.isPractice = ((Integer)[Select Count(ContactId) from AccountContactRelation where AccountId =: wrapper.training.Practice__c AND Roles =:ConstantsUtil.ACR_ROLE_TRAINER AND IsActive = true ][0].get('expr0')) > 1;
      wrapper.options = getDeclineReasonPicklistValues();
      
      if(wrapper.training!= null){
        wrapper.isLiveTraining = (wrapper.training.RecordTypeId == ConstantsUtil.TRAINING_LIVE_TRAINING_RT) ? true : false;
      }

      return wrapper;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * @description Gets all pending training records assigned to a CPT trainer.
   * @param trainerId The Id of the trainer account.
   * @return List of Training__c records with pending acceptance stage.
   */

  @AuraEnabled
  public static List<Training__c> getCPTTrainings(String trainerId){
    try {
        if(String.isBlank(trainerId))  {
        	throw new AuraHandledException('Trainer Id is required');
    	}
      return [SELECT
        Id,
        Training_Stage__c,
        Account__r.Name,
        CSM__r.FirstName,
        CSM__r.LastName,
        Training_Type__c,
        CSM__c,
          FORMAT(CreatedDate) CreatedDate,
          Practice__r.Name,
          FORMAT(Ship_Date__c) Ship_Date__c,
          Physician__r.Name
      FROM Training__c
      WHERE
        Educator_Type__c = :ConstantsUtil.EDUCATOR_TYPE_CPT
        AND Training_Stage__c = :ConstantsUtil.STAGE_PENDING_ACCEPTANCE
        AND RecordTypeId = :ConstantsUtil.TRAINING_LIVE_TRAINING_RT
        AND External_Trainer__c = :trainerId
      WITH SYSTEM_MODE
      ORDER BY CreatedDate ASC
    ];
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * @description Gets all pending training records assigned to a CC practice.
   * @param practiceId The Id of the practice account.
   * @return List of Training__c records with pending acceptance stage.
   */
  @AuraEnabled
  public static List<Training__c> getCCTrainings(String practiceId) {
    try {
      if (String.isBlank(practiceId)) {
        throw new AuraHandledException('Practice Id is required');
      }
      List<String> contractIdList = new List<String>();
      for(Multi_Location_Contract__c mlc: [SELECT Id, Contract__c FROM Multi_Location_Contract__c 
                                           WHERE Related_Location__c IN :practiceId.split(',') AND
                                           Contract_Status__c = :ConstantsUtil.CONTRACT_STATUS_ACTIVATED AND
                                           Contract_Expiration_Date__c >= TODAY WITH SYSTEM_MODE]){
        contractIdList.add(mlc.Contract__c);
      }
      for(Multi_Location_Contract__c mlc: [SELECT Id, Related_Location__c FROM Multi_Location_Contract__c 
                                           WHERE Contract__c IN :contractIdList WITH SYSTEM_MODE]){
        practiceId += ',' + mlc.Related_Location__c;
      }
      for(Contract con: [SELECT Id, AccountId FROM Contract WHERE Id IN :contractIdList WITH SYSTEM_MODE]){
        practiceId += ',' + con.AccountId;
      }
      return [
        SELECT
          Id, Training_Stage__c, Account__r.Name, CSM__r.FirstName, CSM__r.LastName, Training_Type__c,
          CSM__c, FORMAT(CreatedDate) CreatedDate, Practice__r.Name, FORMAT(Ship_Date__c) Ship_Date__c, Physician__r.Name
        FROM Training__c
        WHERE
          Educator_Type__c = :ConstantsUtil.EDUCATOR_TYPE_CC
          AND Training_Stage__c = :ConstantsUtil.STAGE_PENDING_ACCEPTANCE
        AND Practice__c IN :practiceId.split(',')
        AND RecordTypeId = :ConstantsUtil.TRAINING_LIVE_TRAINING_RT
      WITH SYSTEM_MODE
      ORDER BY CreatedDate ASC
    ];
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * @description Wrapper class that aggregates trainer context for the UI.
   * Provides identifiers, trainer type, practice flag, and the list of pending Training__c records.
   * Used as the return type of loadData(contactId).
   * Version: v1.0.2
   */
  public class TrainerWrapper{
    @AuraEnabled public string trainerId;
    @AuraEnabled public Boolean isPractice;
    @AuraEnabled public string practiceId;
    @AuraEnabled public string trainerName;
    @AuraEnabled public string trainerType;
    @AuraEnabled public List<PicklistOption> options;
    @AuraEnabled public Training__c training;
    @AuraEnabled public Boolean isLiveTraining;

  }

  /**
   * @description Wrapper class for returning picklist values in a format lightning-combobox expects.
   */
  public class PicklistOption {
    /**
     * @description The user-visible text for the picklist option.
     */
    @AuraEnabled
    public String label { get; set; }
        
        /**
         * @description The developer value for the picklist option.
         */
    @AuraEnabled
    public String value { get; set; }
        
        /**
         * @description Constructor for PicklistOption.
         * @param label The user-visible label.
         * @param value The API value.
         */
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
  /**
   * @description Wrapper class for passing parameters to the declineTraining method.
   */
  public class TrainingDeclineWrapper {
    @AuraEnabled
    public String trainingId;
    @AuraEnabled
    public String declineReason;
    @AuraEnabled
    public String declineComments;
    @AuraEnabled
    public Boolean isClickFromQuickAction;
  }

}