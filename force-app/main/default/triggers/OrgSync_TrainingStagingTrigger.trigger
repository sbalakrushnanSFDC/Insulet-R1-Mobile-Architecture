trigger OrgSync_TrainingStagingTrigger on OrgSync_Training_Staging__c (before insert, after insert, before update, after update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        XCDC_sObjectPublishHandler xcdcPublishHandler = new XCDC_sObjectPublishHandler();
        xcdcPublishHandler.processRecordsForPublisher(
            Trigger.new, 
            Trigger.oldMap, 
            'TrainingStage_NG_TO_CL', // The exact Label of your XCDC Publish Setting
            Trigger.isInsert ? 'INSERT' : 'UPDATE', // Operation Type
            false // Race condition applicable (usually false for simple setups)
        );
    }
}