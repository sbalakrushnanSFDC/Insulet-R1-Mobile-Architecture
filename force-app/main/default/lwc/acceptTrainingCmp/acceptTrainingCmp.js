/**
 * Jira Story   : NGOMCT-645 and NGOMCT 646
 * Developer    : Srinivas Shanigarapu
 * Description  : This component handles the confirmation and processing of 'Accept Training' actions 
 * initiated from the parent list view. It provides a modal interface for user confirmation, 
 * performs the status update on the Training__c record via Apex (setting the stage to 'Accepted'), 
 * and dispatches a 'refresh' event to the parent component upon successful completion or failure.
 */

import { LightningElement, api, wire } from 'lwc';
import updateTrainingStage from '@salesforce/apex/TrainingController.updateTrainingStage';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import Training_Accept_Success from '@salesforce/label/c.Training_Accept_Success';
import Training_Accepted_Message from '@salesforce/label/c.Training_Accepted_Message';
import Accept_Training_Confirmation from '@salesforce/label/c.Accept_Training_Confirmation';
import Close_Label from '@salesforce/label/c.Close_Label';
import Confirm_Accept_Training from '@salesforce/label/c.Confirm_Accept_Training';
import LightningToast from 'lightning/toast';
import Error_Message from '@salesforce/label/c.Error_Message'
import Yes from '@salesforce/label/c.Yes'
import No from '@salesforce/label/c.No'
import Close from '@salesforce/label/c.Close'
import Loading from '@salesforce/label/c.Loading'

export default class AcceptTrainingCmp extends LightningElement {
    @api recordId;
    isModalOpen = false;
    isLoading = false;
    isClickFromQuickAction = false;
    labels = {
        acceptTrainingConfirmation: Accept_Training_Confirmation,
        closeLabel: Close_Label,
        confirmAcceptTraining: Confirm_Accept_Training,
        Yes: Yes,
        No: No,
        Close: Close,
        Loading: Loading
    };


    /**
     * Method invokes if the component was invoked from a quick action.
     */
    @wire(CurrentPageReference)
    parseParam(currentPageReference) {
        if (currentPageReference && currentPageReference.type === "standard__quickAction") {
            this.isClickFromQuickAction = true;
            this.openModal(this.recordId);
        }
    }

    /**
     * Public method to open the modal and set the training record ID.
     */
    @api
    openModal(trainingId) {
        this.recordId = trainingId;
        this.isModalOpen = true;
    }

    /**
     * Closes the modal and triggers a refresh event for the parent component.
     */
    closeModal() {
        this.isModalOpen = false;
        if (this.isClickFromQuickAction) {
            this.dispatchEvent(new CloseActionScreenEvent());
        } else {
            this.dispatchEvent(new CustomEvent('refresh'));
        }
    }

    /**
     * Calls the Apex method to update the training stage to 'Accepted' and handles success/error notifications.
     */
    handleAccept() {

        if (!this.recordId) {
            if (this.isClickFromQuickAction) {
                this.dispatchEvent(new CloseActionScreenEvent());
            } else {
                this.dispatchEvent(new CustomEvent('refresh'));
            } return;
        }
        this.isLoading = true;

        updateTrainingStage({ trainingId: this.recordId, isClickFromQuickAction: this.isClickFromQuickAction })
            .then((result) => {
                if (result === 'SUCCESS') {
                    this.showToast('Success', Training_Accept_Success, 'success');
                } else if (result === 'ALREADY_ACCEPTED') {
                    this.showToast('Info', Training_Accepted_Message, 'info');
                }
                else {
                    // Removed Standard Error Message to be sent from Apex rather than handling exception on LWC.
                    this.showToast('Error', result, 'error');
                }
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            })
            .catch(error => {
                this.showToast('Error',Error_Message,'error')

            }).finally(() => {
                this.isLoading = false;
                this.closeModal();
        });
    }

    showToast(title, message, variant, mode){
        LightningToast.show({
            label: title,
            message: message,
            variant: variant,
            mode: mode
        })
    }
}