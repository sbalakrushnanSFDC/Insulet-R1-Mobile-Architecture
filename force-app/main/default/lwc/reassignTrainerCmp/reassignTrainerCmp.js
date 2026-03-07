/**
 * Jira Story   : NGOMCT-645 and NGOMCT 646
 * Developer    : Srinivas Shanigarapu
 * Description  : This component allows a user to reassign a trainer for a specific Training__c record.
 * It primarily functions by checking if the current training stage is 'Accepted' and, if so, 
 * updating the record's Training_Stage__c field back to 'Pending Acceptance' and clearing 
 * the Completion_Date__c field using imperative Apex.
 */

import { LightningElement, wire, api } from 'lwc';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import reassignTraining from '@salesforce/apex/TrainingController.reassignTraining';
import { log, showToast, showErrorToast, getErrorMessage } from 'c/utilityComponent';
import Training_ReAssign_Success from '@salesforce/label/c.Training_ReAssign_Success';
import ASSIGN_OTHER_EDUCATOR from '@salesforce/label/c.Assign_Other_Educator'

export default class ReassignTrainerCmp extends LightningElement {
    trainingRecord;
    @api recordId;
    isProcessing = false;
    label = {
        ASSIGN_OTHER_EDUCATOR
    };

    /**
     * Handles the click event for the reassign button.
     * Updates the Training__c record's stage to 'Pending Acceptance' and clears the completion date 
     * using IMPERATIVE APEX.
     */
    handleReassignTrainer() {
        this.isProcessing = true;

        reassignTraining({ trainingId: this.recordId })
            .then(result => {
                showToast('Success', Training_ReAssign_Success, 'success');
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                this.dispatchEvent(new CustomEvent('refresh')); 
            })
            .catch(error => {
                const errorMessage = getErrorMessage(error);
                log('Error while reassigning training: ' + errorMessage);
                showErrorToast();
            }).
            finally(() => {
                this.isProcessing = false;
            });
    }
}