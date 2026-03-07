/**
    * @description : Handles all trigger logic for the Training object
    * Created Date : 16-10-2025
    * Created By   : Ankur Chauhan
    * Version      Modified Date       Modified By             Brief Note
    * V1.0.0       16th Oct 2025       Ankur Chauhan           Initial Version
    * V1.0.1       6th Nov 2025        Ankur Chauhan           NGOMCT- 689
    * V1.0.2       19th Nov 2025       Srinivas                Modified Version(NGOMCT-787)
    * V1.0.4       12th Jan 2026       Bhavya Chanan           Modified Version(NGOMCT-583)
    * V1.0.5       12th Jan 2026       Ayush Sharma            Modified Version(NGOMCT-1055)
    * V1.0.6       23rd Jan 2026       Bhavya Chanan           Modified Version(NGOMCT-1213)
    * V1.0.7       12th Feb 2026       Yogesh Rana            (NGOMCT-2099)
 	* V1.0.8	   20th Feb 2026	   Shashank Nigam		   NGOMCT-2102


 */
public with sharing class TrainingTriggerHandler extends TriggerHandler {

    public override void beforeInsert(List<SObject> newRecords) {
        List<Training__c> newTrainings = (List<Training__c>) newRecords;
        TrainingAssignmentHandler.manageTrainingAssignments(newTrainings, new Map<Id, Training__c>());
        TrainingAssignmentHandler.updateTrainingStage(newTrainings, new Map<Id, Training__c>(), ConstantsUtil.INSERT_OPERATION);
        TrainingService.validateTrainerAssignments(newTrainings, new Map<Id, Training__c>(),ConstantsUtil.OMCT_TAG);
        TrainingAssignmentHandler.updateTrainingInternalTrainer(newTrainings, new Map<Id, Training__c>(), ConstantsUtil.INSERT_OPERATION);
      TrainingAssignmentHandler.populateClassVariables(newTrainings);
    TrainingAssignmentHandler.updatePhysician(newTrainings);
    TrainingAssignmentHandler.updateShipDate(newTrainings);
  }
    public override void beforeUpdate(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        Map<Id, Training__c> newTrainingsMap = (Map<Id, Training__c>) newRecordsMap;
        Map<Id, Training__c> oldTrainingsMap = (Map<Id, Training__c>) oldRecordsMap;
        TrainingAssignmentHandler.manageTrainingAssignments(newTrainingsMap.values(), oldTrainingsMap);
        TrainingAssignmentHandler.manageManualAssignments(newTrainingsMap, oldTrainingsMap);
        TrainingAssignmentHandler.updateTrainingStage(newTrainingsMap.values(), oldTrainingsMap, ConstantsUtil.UPDATE_OPERATION);
        TrainingService.validateTrainerAssignments(newTrainingsMap.values(), oldTrainingsMap,ConstantsUtil.OMCT_TAG);
        TrainingAssignmentHandler.updateTrainingConductedDate(newTrainingsMap.values(), oldTrainingsMap);
        TrainingAssignmentHandler.updateTrainingInternalTrainer(newTrainingsMap.values(), oldTrainingsMap, ConstantsUtil.UPDATE_OPERATION);

    }
    public override void afterUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap){
        Map<Id, Training__c> updatedTrainings = (Map<Id, Training__c>) updatedRecordsMap;
        Map<Id, Training__c> oldTrainingsMap = (Map<Id, Training__c>) oldRecordsMap;
        TrainingSharingHandler.shareTrainingRecords(updatedTrainings, oldTrainingsMap);
	TrainingTaskCreationHandler.createTasks(updatedTrainings,oldTrainingsMap);

    }

     public override void afterInsert(Map<Id, SObject> newRecordsMap) {
        Map<Id, Training__c> newTrainings = (Map<Id, Training__c>) newRecordsMap;
        TrainingTaskCreationHandler.createTasks(newTrainings,null);
}

}