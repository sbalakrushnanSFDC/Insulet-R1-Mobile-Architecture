/**
 * @description Controller class for handling Reimbursement-related operations in Lightning Web Components.
 *              Provides methods for initializing reimbursement forms, retrieving trainings and observations,
 *              calculating rates, and managing reimbursement records.
 * @author Shashank Nigam
 * @group Reimbursement
 * Note:- Marking Class as without sharing as External User is not having Training_Rate__c records shared with them. As Per User Story:- NGOMCT-1206  * Changes made by Bhavya Chanan for User Story:- NGOMCT-2085
 */
public without sharing class ReimbursementController {
    
    public static final String REIMBURSEMENT_APPROVERS_QUEUE = 'Reimbursement_Approvers_Queue';

    /**
     * @description Determines whether the reimbursement form should be displayed based on the trainer's contract type.
     *              Level 1 contract type trainers are not eligible to see the reimbursement form.
     * @param trainerId The Id of the trainer (Account) record
     * @param recordId The Id of Reimbursement Record
     * @return Boolean True if the form should be shown (non-Level 1 contract), False otherwise
     */
    @AuraEnabled(cacheable = true)
    public static Boolean showReimbursementForm(String trainerId, String recordId) {
        List<Account> trainer = [
            SELECT Id, Name, Contract_Type__c 
            FROM Account 
            WHERE Id = :trainerId
            WITH SYSTEM_MODE
        ];
        if(recordId!='null'){
            Reimbursement__c rem = [Select id,Status__c from Reimbursement__c where Id =:recordId WITH USER_MODE];
             if (rem.Status__c != null && 
                (rem.Status__c == ConstantsUtil.STATUS_SUBMITTED || 
                 rem.Status__c == ConstantsUtil.STATUS_APPROVED || 
                 rem.Status__c == ConstantsUtil.STATUS_PAID)) {
                return false;
            }
        }
        return trainer.isEmpty() ? false : trainer[0].Contract_Type__c != ConstantsUtil.CONTRACT_TYPE_1;
    }

    /**
     * @description Initializes the reimbursement form by fetching picklist values based on the trainer's contract type.
     *              Level 3 contract type trainers have access to additional picklist options (e.g., Observation).
     * @param trainerId The Id of the trainer (Account) record
     * @return ReimbursementFormWrapper Wrapper containing picklist options for the form
     */
    @AuraEnabled(cacheable = true)
    public static ReimbursementFormWrapper initializeReimbursementForm(String trainerId) {
        Account trainer = [
            SELECT Id, Name, Contract_Type__c 
            FROM Account 
            WHERE Id = :trainerId
            WITH SYSTEM_MODE
        ];
        ReimbursementFormWrapper wrapper = new ReimbursementFormWrapper();
        wrapper.picklistLabels = getPicklistValues(
            ConstantsUtil.REIMBURSEMENT_API_NAME, 
            ConstantsUtil.REIMBURSEMENT_TYPE_API_NAME, 
            trainer.Contract_Type__c == ConstantsUtil.CONTRACT_TYPE_3
        );
        return wrapper;
    }

    /**
     * @description Retrieves picklist values for a specified field on a given object.
     *              Filters out 'Observation' option for non-superCPT users.
     * @param objectName The API name of the SObject
     * @param fieldName The API name of the picklist field
     * @param superCPT Boolean flag indicating if user is a super CPT (Level 3 contract type)
     * @return List<PicklistOption> List of picklist options with label and value
     */
    @testVisible
    private static List<PicklistOption> getPicklistValues(String objectName, String fieldName, Boolean superCPT) {
        Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
        Schema.DescribeFieldResult fieldResult = describeResult.fields.getMap().get(fieldName).getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        List<PicklistOption> picklistValuesList = new List<PicklistOption>();
        
        for (Schema.PicklistEntry picklistValue : picklistValues) {
            if (!superCPT && picklistValue.getValue() == ConstantsUtil.REIMBURSEMENT_TYPE_OBSERVATION) {
                continue;
            }
            picklistValuesList.add(new PicklistOption(picklistValue.getLabel(), picklistValue.getValue()));
        }
        return picklistValuesList;
    }

    /**
     * @description Retrieves completed trainings for a specific trainer that are eligible for reimbursement.
     *              Only returns trainings that are completed, not part of a group training, and completed
     *              more than 6 months ago.
     * @param trainerId The Id of the external trainer (Account) record
     * @return List<RecordWrapper> List of training records wrapped in RecordWrapper objects
     */
    @AuraEnabled
    public static List<RecordWrapper> getTrainings(String trainerId) {
    Map<String, Date> certificationMap = getCertification(trainerId);
    List<RecordWrapper> records = new List<RecordWrapper>(); // Helps to get Product Vs Certification Expiration Date
    RecordWrapper wrap;
    for (Training__c training : [
      SELECT
        Id,
        Name,
        Account__r.Name,
        Training_Type__c,
        Training_Method__c,
        Training_Conducted_Date__c,
        Completion_Date__c,
        CSM__r.Name,
        Educator_Type__c,
        External_Trainer__r.Contract_Type__c,
        Practice__r.Contract_Type__c,
        Current_Therapy__c,
        Product__c,
        External_Trainer__r.Contract_Expiration_Date__c,
        External_Trainer__c,
        Practice__r.Contract_Expiration_Date__c
      FROM Training__c
      WHERE
        Training_Stage__c = :ConstantsUtil.STAGE_COMPLETED
        AND Part_of_Group_Training__c = FALSE
                AND Completion_Date__c = LAST_N_DAYS:180
                AND External_Trainer__c = :trainerId
                WITH SYSTEM_MODE
        ]) {
      wrap = new RecordWrapper(training);
      wrap.isCertificationValid =
        certificationMap.get(training.Product__c) >=
        training.Training_Conducted_Date__c;
      wrap.isContractValid =
        ((training.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_CPT)
          ? training.External_Trainer__r.Contract_Expiration_Date__c
          : training.Practice__r.Contract_Expiration_Date__c) >=
        training.Training_Conducted_Date__c;
      records.add(wrap);
        }
        return records;
    }

    /**
     * @description Retrieves observations for a specific delegate observer that are eligible for reimbursement.
     *              Only returns observations with an observation date before today.
     * @param trainerId The Id of the delegate observer (Account) record
     * @return List<RecordWrapper> List of observation records wrapped in RecordWrapper objects
     */
    @AuraEnabled
    public static List<RecordWrapper> getObservations(String trainerId) {
    Map<String, Date> certificationMap = getCertification(trainerId);
    List<RecordWrapper> records = new List<RecordWrapper>();
    RecordWrapper wrap;
    for (Observation__c observation : [
      SELECT
        Id,
        Name,
        Observation_Date__c,
        Observation_Type__c,
        Trainer_Name__r.Name,
        Delegate_Observer__r.Contract_Expiration_Date__c,
        Delegate_Observer__c,
        Training_Observed__r.Product__c
      FROM Observation__c
      WHERE Observation_Date__c < TODAY AND Delegate_Observer__c = :trainerId
      WITH SYSTEM_MODE
    ]) {
      wrap = new RecordWrapper(observation);
      wrap.isCertificationValid =
        certificationMap.get(observation.Training_Observed__r.Product__c) >=
        observation.Observation_Date__c;
      wrap.isContractValid =
        observation.Delegate_Observer__r.Contract_Expiration_Date__c >=
        observation.Observation_Date__c;
      records.add(wrap);
        }
        return records;
    }

	private static Map<String, Date> getCertification(String trainerId) {
	    Map<String, Date> certificationMap = new Map<String, Date>();
	    for (Certification__c c : [
	      SELECT id, Product__c, Certification_Expiration_Date__c
	      FROM Certification__c
	      WHERE Trainer_Name__c = :trainerId
	      WITH SYSTEM_MODE
	      ORDER BY Certification_Expiration_Date__c ASC
	    ]) {
	      // Ensures that the map  will have latest expiration date
	      certificationMap.put(c.Product__c, c.Certification_Expiration_Date__c);
	    }
    	return certificationMap;
  	}

    /**
     * @description Submits a reimbursement record for approval by updating its status to 'Submitted'
     *              and setting the submission date to the current timestamp.
     * @param reimbursementId The Id of the Reimbursement__c record to submit
     * @throws AuraHandledException If an error occurs during the update
     */
    @AuraEnabled
    public static void submitForApproval(String reimbursementId) {
        try {
            Group targetQueue = [
                SELECT Id
                FROM Group
                WHERE
                    Type = :ConstantsUtil.GROUP_TYPE_QUEUE
                    AND DeveloperName = :REIMBURSEMENT_APPROVERS_QUEUE
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            Reimbursement__c reimbursement = new Reimbursement__c();
            reimbursement.Id = reimbursementId;
            reimbursement.Status__c = ConstantsUtil.STATUS_SUBMITTED;
            reimbursement.Submission_Date__c = System.now();
            reimbursement.OwnerId = targetQueue.Id;

            Database.update(reimbursement, AccessLevel.SYSTEM_MODE);
            system.debug('reimbursement updated successfully');
        } catch (Exception e) {
             system.debug(e.getMessage() + e.getLineNumber());
            throw new AuraHandledException(e.getMessage() + e.getLineNumber());
        }
    }

    /**
     * @description Calculates and retrieves the applicable rate for a training or observation record.
     *              Routes to appropriate rate calculation method based on educator type (CPT, CC, or Observation).
     * @param rec JSON string representation of a RecordWrapper object
     * @return ReimbursementWrapper Wrapper containing calculated rates and associated record Ids
     * @throws AuraHandledException If an error occurs during rate calculation
     */
    @AuraEnabled
    public static ReimbursementWrapper getRate(String rec) {
        RecordWrapper record = (RecordWrapper) JSON.deserialize(rec, RecordWrapper.class);
        ReimbursementWrapper wrapper;
        try {
            if (record.educatorType == ConstantsUtil.EDUCATOR_TYPE_CPT) {
                wrapper = getCPTTrainingRate(record);
            } else if (record.educatorType == ConstantsUtil.EDUCATOR_TYPE_CC) {
                wrapper = getCCTrainingRate(record);
            } else {
                wrapper = getObservationRate(record);
            }
            wrapper.numberOfMinutesOptions = getPicklistValues(ConstantsUtil.REIMBURSEMENT_API_NAME,ConstantsUtil.REIMBURSEMENT_NUMBER_OF_MINUTES_API_NAME,false);
            return wrapper;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage() + e.getLineNumber());
        }
    }

    /**
     * @description Calculates the training rate for CPT (Certified Product Trainer) educators.
     *              Queries Training_Rate__c based on educator type, training type, contract type, and date.
     * @param record RecordWrapper containing training details
     * @return ReimbursementWrapper Wrapper containing the training rate and mileage rate
     */
    private static ReimbursementWrapper getCPTTrainingRate(RecordWrapper record) {
        ReimbursementWrapper wrapper = new ReimbursementWrapper();
        wrapper.trainingId = record.Id;
        List<Training_Rate__c> rates = [
            SELECT Id, Rate__c 
            FROM Training_Rate__c 
            WHERE Rate_Type__c = :ConstantsUtil.RATE_TYPE_TRAINING 
                AND Educator_Type__c INCLUDES (:record.educatorType) 
                AND Training_Type__c INCLUDES (:record.type)
                AND Contract_Type__c INCLUDES (:record.contractType)
                AND Start_Date__c <= :record.trainingConductedDate
                AND (End_Date__c >= :record.trainingConductedDate OR End_Date__c = null)
                WITH SYSTEM_MODE
        ];
        
        if (!rates.isEmpty()) {
            wrapper.rateApplied = rates[0].Rate__c;
        }
        
        wrapper.mileageRate = getMileageRate(record.trainingConductedDate);
        return wrapper;
    }

    /**
     * @description Calculates the training rate for CC (Clinical Coordinator) educators.
     *              Queries Training_Rate__c based on educator type, training type, contract type, 
     *              training method, current therapy, product, and date.
     * @param record RecordWrapper containing training details
     * @return ReimbursementWrapper Wrapper containing the training rate and mileage rate
     */
    private static ReimbursementWrapper getCCTrainingRate(RecordWrapper record) {
        ReimbursementWrapper wrapper = new ReimbursementWrapper();
        wrapper.trainingId = record.Id;
        
        List<Training_Rate__c> rates = [
            SELECT Rate__c 
            FROM Training_Rate__c 
            WHERE Rate_Type__c = :ConstantsUtil.RATE_TYPE_TRAINING 
                AND Educator_Type__c INCLUDES (:record.educatorType) 
                AND Training_Type__c INCLUDES (:record.type) 
                AND Contract_Type__c INCLUDES (:record.contractType) 
                AND Start_Date__c <= :record.trainingConductedDate 
                AND (End_Date__c >= :record.trainingConductedDate OR End_Date__c = null)
                AND Training_Method__c INCLUDES (:record.trainingMethod) 
                AND Current_Therapy__c INCLUDES (:record.currentTherapy) 
                AND Product__c INCLUDES (:record.product)
                WITH SYSTEM_MODE
        ];
        
        if (!rates.isEmpty()) {
            wrapper.rateApplied = rates[0].Rate__c;
        }
        
        wrapper.mileageRate = getMileageRate(record.trainingConductedDate);
        
        return wrapper;
    }

    /**
     * @description Retrieves the applicable mileage rate for a given date.
     *              Queries Training_Rate__c for mileage type rates based on the date range.
     * @param startDate The date to check for applicable mileage rate
     * @return Decimal The mileage rate per mile, or null if no rate found
     */
    private static Decimal getMileageRate(Date startDate) {
        List<Training_Rate__c> rates = [
            SELECT Id, Rate__c 
            FROM Training_Rate__c 
            WHERE Rate_Type__c = :ConstantsUtil.RATE_TYPE_MILEAGE 
                AND Start_Date__c <= :startDate 
                AND (End_Date__c >= :startDate OR End_Date__c = null)
                WITH SYSTEM_MODE
        ];
        return rates.isEmpty() ? null : rates[0].Rate__c;
    }

    /**
     * @description Calculates the rate for observation records.
     *              Queries the hourly rate from Training_Rate__c based on observation date.
     * @param record RecordWrapper containing observation details
     * @return ReimbursementWrapper Wrapper containing the observation rates
     */
    private static ReimbursementWrapper getObservationRate(RecordWrapper record) {
        ReimbursementWrapper wrapper = new ReimbursementWrapper();
        wrapper.observationId = record.Id;
        
        List<Training_Rate__c> rates = [
            SELECT Rate__c 
            FROM Training_Rate__c 
            WHERE Rate_Type__c = :ConstantsUtil.RATE_TYPE_OBSERVATION 
                AND Start_Date__c <= :record.completionDate 
                AND (End_Date__c >= :record.completionDate OR End_Date__c = null)
                WITH SYSTEM_MODE
        ];
        
        if (!rates.isEmpty()) {
            wrapper.hourlyRate = rates[0].Rate__c;
        }
        
        wrapper.mileageRate = getMileageRate(record.completionDate);
        return wrapper;
    }


    /**
     * @description Retrieves the applicable training record.
     *              Queries Training__c for educator type and contract type
     * @param trainingId To retrieve training details
     * @return Training Record
     */
    private static Training__c getTrainingDetails(Id trainingId)  {
        Training__c trainingRec = [select id , name , Practice__r.Contract_Type__c, External_Trainer__r.Contract_Type__c , Educator_Type__c from Training__c where id = :trainingId WITH SYSTEM_MODE];
        return trainingRec;

    }


    /**
     * @description Retrieves a reimbursement record by its Id and returns it as a wrapper object.
     * @param reimbursementId The Id of the Reimbursement__c record to retrieve
     * @return ReimbursementWrapper Wrapper containing reimbursement details
     */
    @AuraEnabled
    public static ReimbursementWrapper getReimbursement(String reimbursementId) {
        Reimbursement__c reimbursement = [
            SELECT Id, Name, Type__c, Meals__c, Hotels__c, Car_Rental__c, Train_Bus_Airfare__c, 
                   Tolls__c, Parking__c, Other__c, Rate_Applied__c, Hourly_Rate_Subtotal__c, 
                   Number_Of_Minutes__c, Mileage_Subtotal__c, Training_Subtotal__c, 
                   Pre_Approved_Items_Subtotal__c, Parking_Tolls_Other_Subtotal__c, Grand_Total__c, 
                   Comments__c, Status__c, Submission_Date__c, Observation__c, Trainer__c, Total_Miles_Travelled__c, Educator_Type__c , Contract_Level__c
            FROM Reimbursement__c 
            WHERE Id = :reimbursementId
            WITH SYSTEM_MODE
        ];
        RecordWrapper record;
        ReimbursementWrapper wrapper = new ReimbursementWrapper(reimbursement);
        ReimbursementWrapper rates = new ReimbursementWrapper();
        if(reimbursement != null && reimbursement.Observation__c != null){
            List<RecordWrapper> records = getObservations(reimbursement.Trainer__c);
            for(RecordWrapper r : records){
                if(r.Id == reimbursement.Observation__c){
                    record = r;
                    break;
                }
            }
        }
        else{
            Reimbursement_Association__c ra = [Select id,Training__c from Reimbursement_Association__c where Reimbursement__c = :reimbursement.Id with SYSTEM_MODE];
            List<RecordWrapper> records = getTrainings(reimbursement.Trainer__c);
            for(RecordWrapper r : records){
                if(r.Id == ra.Training__c){
                    record = r;
                    break;
                }
            }
        }
        if(record != null){
            rates = getRate(JSON.serialize(record));
        }
        wrapper.hourlyRate = rates.hourlyRate;
        wrapper.mileageRate = rates.mileageRate;
        wrapper.rateApplied = rates.rateApplied;
        wrapper.numberOfMinutesOptions = rates.numberOfMinutesOptions;
        return wrapper;
    }

    /**
     * @description Saves or updates a reimbursement record based on the provided wrapper data.
     *              Creates a new record if Id is null, otherwise updates the existing record.
     *              Also creates a Reimbursement_Association__c record to link the reimbursement to a training.
     * @param wrapper JSON string representation of a ReimbursementWrapper object
     * @return Reimbursement__c The saved or updated reimbursement record
     * @throws AuraHandledException If an error occurs during save/update
     */
    @AuraEnabled
    public static Reimbursement__c saveReimbursement(String wrapper) {
        ReimbursementWrapper wrapperObj = (ReimbursementWrapper) JSON.deserialize(wrapper, ReimbursementWrapper.class);
        
        try {
            Reimbursement__c reimbursement = new Reimbursement__c();
            reimbursement.Trainer__c = wrapperObj.trainerId;
            reimbursement.Type__c = wrapperObj.type;
            reimbursement.Meals__c = wrapperObj.mealAmount;
            reimbursement.Hotels__c = wrapperObj.hotelAmount;
            reimbursement.Car_Rental__c = wrapperObj.carRentalAmount;
            reimbursement.Train_Bus_Airfare__c = wrapperObj.trainBusAirfareAmount;
            reimbursement.Tolls__c = wrapperObj.tollsAmount;
            reimbursement.Parking__c = wrapperObj.parkingAmount;
            reimbursement.Other__c = wrapperObj.othersAmount;
            reimbursement.Rate_Applied__c = wrapperObj.rateApplied;
            reimbursement.Hourly_Rate_Subtotal__c = wrapperObj.hourlyRateTotal;
            reimbursement.Comments__c = wrapperObj.comments;
            reimbursement.Status__c = ConstantsUtil.STATUS_DRAFT;
            reimbursement.Observation__c = wrapperObj.observationId;
            if(wrapperObj.mileageRate != null && wrapperObj.milesTravelledAmount != null){
                reimbursement.Mileage_Subtotal__c =  wrapperObj.mileageRate * wrapperObj.milesTravelledAmount;
            }
            reimbursement.Number_Of_Minutes__c = wrapperObj.numberOfMinutes;
            reimbursement.Total_Miles_Travelled__c = wrapperObj.milesTravelledAmount;
            reimbursement.Training_Subtotal__c = wrapperObj.rateApplied;

	    if (wrapperObj.trainingId != null) {
                Training__c trainingRec = getTrainingDetails(wrapperObj.trainingId);
              
                reimbursement.Educator_Type__c = trainingRec.educator_type__c;
                if(trainingRec.Educator_Type__c==ConstantsUtil.EDUCATOR_TYPE_CPT) {
                    reimbursement.Contract_Level__c = trainingRec.External_Trainer__r.Contract_Type__c;
                }
                else if(trainingRec.Educator_Type__c==ConstantsUtil.EDUCATOR_TYPE_CC) {
                    reimbursement.Contract_Level__c = trainingRec.Practice__r.Contract_Type__c;
                }
                
            }
            else{
                reimbursement.Educator_Type__c = ConstantsUtil.EDUCATOR_TYPE_CPT;
            }

            
            if (String.isBlank(wrapperObj.Id)) {
                Database.insert(reimbursement, AccessLevel.SYSTEM_MODE);
            } else {
                reimbursement.Id = wrapperObj.Id;
                Database.update(reimbursement, AccessLevel.SYSTEM_MODE);
            }
            
            if (wrapperObj.trainingId != null && String.isBlank(wrapperObj.Id)) {
                Reimbursement_Association__c reimbursementAssociation = new Reimbursement_Association__c();
                reimbursementAssociation.Reimbursement__c = reimbursement.Id;
                reimbursementAssociation.Training__c = wrapperObj.trainingId;
                Database.insert(reimbursementAssociation, AccessLevel.SYSTEM_MODE);
            }
            
            return reimbursement;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage() + e.getLineNumber());
        }
    }

    /**
     * @description Retrieves trainings associated with a reimbursement record through the junction object.
     * @param recordId The Id of the Reimbursement__c record
     * @return List<Training__c> List of associated training records
     */
    @AuraEnabled
    public static List<Training__c> getTrainingRelatedList(String recordId) {
        List<Training__c> trainings = [
            SELECT Id, Name, Account__r.Name, Training_Type__c, Training_Method__c, 
                   Training_Conducted_Date__c, Completion_Date__c, CSM__r.Name, Educator_Type__c, 
                   External_Trainer__r.Contract_Type__c, Practice__r.Contract_Type__c, 
                   Current_Therapy__c, Product__c 
            FROM Training__c 
            WHERE Id IN (
                SELECT Training__c 
                FROM Reimbursement_Association__c 
                WHERE Reimbursement__c = :recordId
            )
            WITH SYSTEM_MODE
        ];
        return trainings;
    }

    /**
     * @description Wrapper class for initializing the reimbursement form with necessary picklist data.
     */
    public class ReimbursementFormWrapper {
        /** @description List of picklist options for reimbursement type selection */
        @AuraEnabled
        public List<PicklistOption> picklistLabels;
        
        /** @description List of practice Id options (reserved for future use) */
        @AuraEnabled
        public List<PicklistOption> practiceIds;
    }

    /**
     * @description Wrapper class representing a picklist option with label and value.
     */
    public class PicklistOption {
        /** @description Display label for the picklist option */
        @AuraEnabled
        public String label;
        
        /** @description API value for the picklist option */
        @AuraEnabled
        public String value;

        /**
         * @description Constructor to initialize a picklist option.
         * @param label The display label
         * @param value The API value
         */
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * @description Wrapper class containing all reimbursement-related data for LWC communication.
     *              Used for both creating new reimbursements and retrieving existing ones.
     * Suppressed Too Many Fields Warning, as this is the wrapper which is in sync with LWC and there is only 1 additional field which is required
     * in order to share consistent data accross multiple flows on UI.
     */
    @SuppressWarnings('PMD.TooManyFields')
    public class ReimbursementWrapper {
        /** @description Id of the trainer (Account) associated with the reimbursement */
        @AuraEnabled
        public String trainerId;
        
        /** @description Id of the Training__c record associated with the reimbursement */
        @AuraEnabled
        public String trainingId;
        
        /** @description Id of the Observation__c record associated with the reimbursement */
        @AuraEnabled
        public String observationId;
        
        /** @description Type of reimbursement (Training, Observation, etc.) */
        @AuraEnabled
        public String type;
        
        /** @description Amount for meals expense */
        @AuraEnabled
        public Decimal mealAmount;
        
        /** @description Amount for hotel expense */
        @AuraEnabled
        public Decimal hotelAmount;
        
        /** @description Amount for car rental expense */
        @AuraEnabled
        public Decimal carRentalAmount;
        
        /** @description Amount for train/bus/airfare expense */
        @AuraEnabled
        public Decimal trainBusAirfareAmount;
        
        /** @description Miles travelled for mileage calculation */
        @AuraEnabled
        public Decimal milesTravelledAmount;
        
        /** @description Amount for parking expense */
        @AuraEnabled
        public Decimal parkingAmount;
        
        /** @description Amount for other miscellaneous expenses */
        @AuraEnabled
        public Decimal othersAmount;
        
        /** @description Total amount of all expenses */
        @AuraEnabled
        public Decimal totalAmount;
        
        /** @description Additional comments or notes for the reimbursement */
        @AuraEnabled
        public String comments;
        
        /** @description Total amount based on hourly rate calculation */
        @AuraEnabled
        public Decimal hourlyRateTotal;
        
        /** @description Number of minutes for hourly rate calculation */
        @AuraEnabled
        public String numberOfMinutes;
        
        /** @description Rate applied for the training/observation */
        @AuraEnabled
        public Decimal rateApplied;
        
        /** @description Mileage rate per mile */
        @AuraEnabled
        public Decimal mileageRate;
        
        /** @description Amount for tolls expense */
        @AuraEnabled
        public Decimal tollsAmount;
        
        /** @description Hourly rate for observation calculations */
        @AuraEnabled
        public Decimal hourlyRate;

        /** @description Educator type */
        @AuraEnabled
        public String educatorType;

        /** @description contract level */
        @AuraEnabled
        public String contractLevel;

        
        /** @description Id of the Reimbursement__c record (null for new records) 
         * Suppressing Warning due to requirment of wrapper in sync with LWC*/ 
        @SuppressWarnings('PMD.FieldNamingConventions')
        @AuraEnabled
        public String Id;

        @AuraEnabled
        public List<PicklistOption> numberOfMinutesOptions;

        /**
         * @description Default constructor for creating an empty wrapper.
         */
         @SuppressWarnings('PMD.EmptyStatementBlock')
        public ReimbursementWrapper() {
        }

        /**
         * @description Constructor to populate wrapper from an existing Reimbursement__c record.
         * @param reimbursement The Reimbursement__c record to populate from
         */
        public ReimbursementWrapper(Reimbursement__c reimbursement) {
            this.trainerId = reimbursement.Trainer__c;
            this.observationId = reimbursement.Observation__c;
            this.type = reimbursement.Type__c;
            this.mealAmount = reimbursement.Meals__c;
            this.hotelAmount = reimbursement.Hotels__c;
            this.carRentalAmount = reimbursement.Car_Rental__c;
            this.trainBusAirfareAmount = reimbursement.Train_Bus_Airfare__c;
            this.tollsAmount = reimbursement.Tolls__c;
            this.parkingAmount = reimbursement.Parking__c;
            this.othersAmount = reimbursement.Other__c;
            this.rateApplied = reimbursement.Rate_Applied__c;
            this.hourlyRateTotal = reimbursement.Hourly_Rate_Subtotal__c;
            this.comments = reimbursement.Comments__c;
            this.Id = reimbursement.Id;
            this.numberOfMinutes = reimbursement.Number_Of_Minutes__c;
            this.milesTravelledAmount = reimbursement.Total_Miles_Travelled__c;
	    this.educatorType = reimbursement.Educator_Type__c;
            this.contractLevel = reimbursement.Contract_Level__c;

        }
    }

    /**
     * @description Wrapper class for Training__c and Observation__c records.
     *              Provides a unified structure for displaying trainings and observations in LWC.
     */
    public class RecordWrapper {
        /** @description Record Id of the Training__c or Observation__c 
         * Suppressing PMD due to utilization and dependency in reusableDatatTable LWC
        */
        @SuppressWarnings('PMD.FieldNamingConventions')
        @AuraEnabled
        public String Id;
        
        /** @description Name of the record */
        @AuraEnabled
        public String name;
        
        /** @description Name of the associated Account (for trainings) */
        @AuraEnabled
        public String accountName;
        
        /** @description Date when the training was conducted */
        @AuraEnabled
        public Date trainingConductedDate;
        
        /** @description Completion date of the training or observation */
        @AuraEnabled
        public Date completionDate;
        
        /** @description Type of training or observation */
        @AuraEnabled
        public String type;
        
        /** @description Method used for the training (In-Person, Virtual, etc.) */
        @AuraEnabled
        public String trainingMethod;
        
        /** @description Name of the CSM (Customer Success Manager) */
        @AuraEnabled
        public String csmName;
        
        /** @description Name of the trainer being observed (for observations) */
        @AuraEnabled
        public String trainerName;
        
        /** @description Type of educator (CPT, CC, etc.) */
        @AuraEnabled
        public String educatorType;
        
        /** @description Contract type of the external trainer (Level 1, Level 2, Level 3) */
        @AuraEnabled
        public String contractType;
        
        /** @description Current therapy type of the patient */
        @AuraEnabled
        public String currentTherapy;
        
        /** @description Product being trained on */
        @AuraEnabled
        public String product;
		@AuraEnabled
    public Boolean isCertificationValid;

    @AuraEnabled
    public Boolean isContractValid;
        /**
         * @description Default constructor for JSON deserialization.
         */
         @SuppressWarnings('PMD.EmptyStatementBlock')
        public RecordWrapper() {
        }

        /**
         * @description Constructor to populate wrapper from a Training__c record.
         * @param training The Training__c record to populate from
         */
        public RecordWrapper(Training__c training) {
            this.Id = training.Id;
            this.name = training.Name;
            this.accountName = training.Account__r.Name;
            this.trainingConductedDate = training.Training_Conducted_Date__c;
            this.completionDate = training.Completion_Date__c;
            this.type = training.Training_Type__c;
            this.trainingMethod = training.Training_Method__c;
            this.csmName = training.CSM__r.Name;
            this.educatorType = training.Educator_Type__c;
            this.contractType = (training.Educator_Type__c == ConstantsUtil.EDUCATOR_TYPE_CPT) ? training.External_Trainer__r.Contract_Type__c : training.Practice__r.Contract_Type__c;
            this.currentTherapy = training.Current_Therapy__c;
            this.product = training.Product__c;
        }

        /**
         * @description Constructor to populate wrapper from an Observation__c record.
         * @param observation The Observation__c record to populate from
         */
        public RecordWrapper(Observation__c observation) {
            this.Id = observation.Id;
            this.name = observation.Name;
            this.trainerName = observation.Trainer_Name__r.Name;
            this.completionDate = observation.Observation_Date__c;
            this.type = observation.Observation_Type__c;
        }
    }
}