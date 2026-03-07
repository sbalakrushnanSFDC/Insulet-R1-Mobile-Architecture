/**
 * Jira Story   : NGOMCT-645 and NGOMCT 646
 * Developer    : Srinivas Shanigarapu
 * Description  : Component for declining a Training record. 
 * It displays a 'Decline Training' button only if the stage is 'Pending Acceptance' or 'Accepted'. 
 * It uses a modal for user input, validates reasons/comments, and updates the Training Stage to 'Declined'
 * via an imperative Apex method, then refreshes the page view.
 */

import { LightningElement, api, wire } from 'lwc';
import updateTrainingDeclineData from '@salesforce/apex/TrainingController.updateTrainingDeclineData';
import getDeclineReasonPicklistValues from '@salesforce/apex/TrainingController.getDeclineReasonPicklistValues';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import Training_Decline_Comment_Label from '@salesforce/label/c.Training_Decline_Comment_Label';
import Training_Decline_Comment_Label_Optional from '@salesforce/label/c.Training_Decline_Comment_Label_Optional';
import Training_Decline_Reason_Error from '@salesforce/label/c.Training_Decline_Reason_Error';
import Training_Decline_Description_Error from '@salesforce/label/c.Training_Decline_Description_Error';
import Training_Decline_Success from '@salesforce/label/c.Training_Decline_Success';
import Training_API_Name from '@salesforce/label/c.Training_API_Name';
import Portal_Training_ListView_Name from '@salesforce/label/c.Portal_Training_ListView_Name';
import Decline_Training from '@salesforce/label/c.Decline_Training';
import Cancel from '@salesforce/label/c.Cancel';
import Decline_Reason from '@salesforce/label/c.Decline_Reason';
import Processing from '@salesforce/label/c.Processing';
import Submit from '@salesforce/label/c.Submit';
import Submit_Decline from '@salesforce/label/c.Submit_Decline';

import LightningToast from 'lightning/toast';
import Error_Message from '@salesforce/label/c.Error_Message'

const REASON_OTHER = 'Other'

export default class DeclineTrainingCmp extends NavigationMixin(LightningElement) {
    declineReason = '';
    declineComments = '';
    errorMessage = '';
    isDeclineVisible = false;
    isDeclined = false;
    @api declineReasonOptions;
    isPractice = false;
    isProcessing = false;
    isLoadingData = false;
    _recordId;
    recordTypeId;
    trainingStage;
    trainingType;
    isCallFromParent = false;
    isClickFromQuickAction = false;
    objectApiName = '';
    listViewApiName = '';
    labels = {
        Decline_Training,
        Cancel,
        Decline_Reason,
        Processing,
        Submit,
        Submit_Decline
    }


    /**
     * API Setter/Getter for recordId to trigger data load when ID is received.
     */
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        if (value) {
            this._recordId = value;
        }
    }

    /**
     *
     * Method invokes if the component was invoked from a quick action.
     */
    @wire(CurrentPageReference)
    parseParam(currentPageReference) {
        if (currentPageReference && currentPageReference.type === "standard__quickAction") {
            this.isClickFromQuickAction = true;
            this._recordId = currentPageReference?.state?.recordId;
            this.handleDeclineTrainingClickFromParent(this._recordId, true);
            this.objectApiName = Training_API_Name;
            this.listViewApiName = Portal_Training_ListView_Name

        }
    }



    /**
     * Fetches Decline Reason Picklist Options. Only in case of quick action this Apex call is made, else it is passed from parent container LWCs
     */
    async fetchDeclineReasonOptions() {
        try {
            this.declineReasonOptions = await getDeclineReasonPicklistValues();
        } catch (error) {
            this.showToast('Error',Error_Message,'error')
        }
    }

    /**
     * Determines if 'Other' is the currently selected decline reason.
     */
    get isOtherSelected() {
        return this.declineReason === REASON_OTHER;
    }

    /**
     * Dynamically sets the label for the comments textarea based on the selected reason.
     */
    get declineCommentsLabel() {
        return this.isOtherSelected ? Training_Decline_Comment_Label : Training_Decline_Comment_Label_Optional;
    }

    /**
     * 
     * Manages isLoadingData flag to show the pre-modal spinner.
     */
    @api
    async handleDeclineTrainingClickFromParent(trainingRecordId, isCallFromParent) {

        this.isDeclined = false;
        this.isDeclineVisible = false;
        this.recordId = trainingRecordId;
        this.isCallFromParent = isCallFromParent;
        this.errorMessage = '';
        this.declineReason = '';
        this.declineComments = '';

        if (!this._recordId) {
            this.showToast('Error',Error_Message,'error')
            return;
        }

        this.isLoadingData = true;

        try {
            //await this.initializeData();
            if (this.isClickFromQuickAction) {
                await this.fetchDeclineReasonOptions();
            }
            this.handleDeclineTrainingClick();

        } catch (error) {
            this.showToast('Error',Error_Message,'error')
        } finally {
            this.isLoadingData = false;
        }
    }
    
    /**
     * Shows the decline modal when the Decline Training button is clicked.
     */
    handleDeclineTrainingClick() {
        if (!this.isDeclined) {
            this.isDeclineVisible = true;
            this.errorMessage = '';
        }
    }

    /**
     * Updates the decline reason and resets comments if 'Other' is deselected.
     */
    handleReasonChange(event) {
        this.declineReason = event.detail.value;
        this.errorMessage = '';

        if (this.declineReason !== REASON_OTHER) {
            this.declineComments = '';
        }
    }

    /**
     * Updates the decline comments field.
     */
    handleDeclineCommentsChange(event) {
        this.declineComments = event.detail.value;
        this.errorMessage = '';
    }

    /**
     * Hides the modal and resets the form fields and error message.
     */
    handleCancel() {
        this.isDeclineVisible = false;
        this.errorMessage = '';
        this.declineReason = '';
        this.declineComments = '';

        if (this.isClickFromQuickAction) {
            this.dispatchEvent(new CloseActionScreenEvent());
        } else {
            this.dispatchEvent(new CustomEvent('refresh'));
        }
    }

    /**
     * Performs input validation, calls Apex to update the record stage, and refreshes the view.
     */
    handleSubmit() {
        if (!this.declineReason) {
            this.errorMessage = Training_Decline_Reason_Error;
            return;
        }
        if (this.isOtherSelected && !this.declineComments) {
            this.errorMessage = Training_Decline_Description_Error;
            return;
        }

        this.errorMessage = '';
        this.isProcessing = true; 
        const declineWrapperObj = {
            trainingId: this._recordId,
            declineReason: this.declineReason,
            declineComments: this.declineComments,
            isClickFromQuickAction: this.isClickFromQuickAction 
        };

        updateTrainingDeclineData({
            declineWrapperRequest: JSON.stringify(declineWrapperObj)
        })
            .then(() => {
                this.showToast('Success', Training_Decline_Success, 'success');
                this.isDeclined = true;
                this.isDeclineVisible = false;

                notifyRecordUpdateAvailable([{ recordId: this._recordId }]);

                if (this.isClickFromQuickAction) {
                    this.dispatchEvent(new CloseActionScreenEvent());
                    this.redirectToListView();
                } else {
                    this.dispatchEvent(new CustomEvent('refresh'));
                }
            })
            .catch(()=> {
                this.showToast('Error',Error_Message,'error')
            })
            .finally(() => {
                this.isProcessing = false; 
            });

    }

    /**
     * Redirects to the  Available Trainings list view of the Training object.
     */
     redirectToListView() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: this.objectApiName,  
                actionName: 'list'
            },
            state: {
                filterName: this.listViewApiName 
            }
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