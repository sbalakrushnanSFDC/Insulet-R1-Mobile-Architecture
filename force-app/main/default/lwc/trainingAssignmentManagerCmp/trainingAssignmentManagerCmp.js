/**
 * Jira Story   : NGOMCT-645 and NGOMCT 646
 * Developer    : Srinivas Shanigarapu
 * Date         : 2025-11-10
 * Description  : This component serves as a manager for trainer assignment actions, specifically handling the logic 
 * for accepting and declining and reassining Training record.
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       10th Nov 2025       Srinivas                Modified (NGOMCT-724)
 * v2.0.0       18th Dec 2025       Shashank                Modified (NGOMCT-1049)
 */
import { LightningElement, api, wire } from 'lwc';
import getTrainingDetails from '@salesforce/apex/TrainingController.getTrainingDetails';
import { refreshApex } from '@salesforce/apex';
import { log, showErrorToast } from 'c/utilityComponent';
import Trainer_Type_CC from '@salesforce/label/c.Trainer_Type_CC'
import Trainer_Type_CPT from '@salesforce/label/c.Trainer_Type_CPT'
import Trainer_Type_CPT_CC from '@salesforce/label/c.Trainer_Type_CPT_CC'
import Training_Stage_Accepted from '@salesforce/label/c.Training_Stage_Accepted'
import Training_Stage_Pending_Acceptance from '@salesforce/label/c.Training_Stage_Pending_Acceptance'
import Decline_Training from '@salesforce/label/c.Decline_Training'

export default class TrainingAssignmentManagerCmp extends LightningElement {
    @api recordId;
    @api contactId
    @api buttonName;
    @api flowAPIName;
    wiredTrainingDetails

    labels = {
        declineTraining: Decline_Training
    }

    /**
     * @description Wired method to fetch the Training Details.
     * @param {Object} result 
     */
    @wire(getTrainingDetails, { contactId: '$contactId', trainingId: '$recordId' })
    trainingDetails(result) {
        this.wiredTrainingDetails = result
    }

    /**
     * @description Getter for Training Stage
     * 
     */
    get trainingStage() {
        return this.wiredTrainingDetails?.data?.training?.Training_Stage__c
    }

    /**
     * @description Getter for Trainer Type
     * 
     */
    get trainingType() {
        return this.wiredTrainingDetails?.data?.trainerType
    }

    /**
     * @description Getter for knowing isPractice
     * 
     */
    get isPractice() {
        return this.wiredTrainingDetails?.data?.isPractice || false
    }

    /**
     * @description Getter for knowing isLiveTraining
     * 
     */
    get isLiveTraining() {
        return this.wiredTrainingDetails?.data?.isLiveTraining || false
    }

    /**
     * @description Getter for options (picklist options)
     * 
     */
    get options() {
        return this.wiredTrainingDetails?.data?.options || []
    }

    /**
   * Determines if the internal decline button should be displayed based on the Training Stage.
   * 
   */
    get showDeclineButton() {
        const isAccepted = this.trainingStage === Training_Stage_Accepted;
        const isPending = this.trainingStage === Training_Stage_Pending_Acceptance;
        const isClinicContractTrainer = this.trainingType === Trainer_Type_CC;
        const isCertifiedPodTrainer = this.trainingType === Trainer_Type_CPT;
        const isCCACPT = this.trainingType === Trainer_Type_CPT_CC;
        if (isAccepted && isClinicContractTrainer && isCCACPT) {
            return true;
        }
        else if ((isCertifiedPodTrainer || isClinicContractTrainer || isCCACPT) && (isPending || isAccepted)) {
            return true;
        }
        else {
            return false;
        }
    }
   
    /**
   * Determines if the reassign button should be displayed If CC more than 1 in a practice.
   * 
   */
    get showReassignButton() {
        const isAccepted = this.trainingStage === Training_Stage_Accepted;

        if (isAccepted && this.isPractice) {
            return true;
        }
        else {
            return false;
        }
    }
   
    /**
     * Handles the click event for the Decline button and invokes the child component's initialization/modal opening method.
     * Assumes the child component has a public method called handleDeclineTrainingClickFromParent(trainingRecordId, isCallFromParent).
     */
    handleDeclineClick() {
        if (this.refs.declineModal && this.recordId) {
            this.refs.declineModal.handleDeclineTrainingClickFromParent(this.recordId, true);
        } else {
            log('Decline component not ready or Record ID missing.');
            showErrorToast()
        }
    }

    /**
     * Handle Refresh of the Training Assignment Manager Component.
     * 
     */
    handleRefresh() {
        refreshApex(this.wiredTrainingDetails)
    }

}