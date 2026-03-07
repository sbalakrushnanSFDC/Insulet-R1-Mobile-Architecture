import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import showReimbursementForm from '@salesforce/apex/ReimbursementController.showReimbursementForm';
import { log, showToast } from 'c/utilityComponent';
import submitForApproval from '@salesforce/apex/ReimbursementController.submitForApproval';
import { RefreshEvent } from 'lightning/refresh';

// Custom Labels
import Reimbursement_Submit_For_Approval from '@salesforce/label/c.Reimbursement_Submit_For_Approval';
import Toast_Success from '@salesforce/label/c.Toast_Success';
import Reimbursement_Submit_Success_Message from '@salesforce/label/c.Reimbursement_Submit_Success_Message';
import Button_Edit from '@salesforce/label/c.Button_Edit';

const LABELS = {
    Submit_For_Approval: 'Submit For Approval',
    Toast_Success: Toast_Success,
    Submit_Success_Message: Reimbursement_Submit_Success_Message,
    Edit: Button_Edit
};

export default class NewReimbursementCmp extends NavigationMixin(LightningElement) {
    @api trainerId;
    @api label;
    @api recordId;
    @api reimbursementId;
    showButton = false;

    @wire(showReimbursementForm, { trainerId: '$trainerId', recordId: '$reimbursementId' })
    wiredShowReimbursementForm({ error, data }) {
        if (data) {
            this.showButton = data;
            log('showButton' + data + ' ' + this.label);
        } else if (error) {
            log('Error: ' + error);
        }
        else {
            log(error)
        }
    }

    handleNewReimbursement() {
        if (this.label === LABELS.Submit_For_Approval) {
            // Submit for Approval call to Apex class
            submitForApproval({ reimbursementId: this.recordId })
                .then((result) => {
                    showToast(LABELS.Toast_Success, LABELS.Submit_Success_Message, 'success');
                    this.dispatchEvent(new RefreshEvent());
                })
                .catch((error) => {
                    log('Error ' + error);
                });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: {
                    name: 'Reimbursement_Form__c'
                },
                state: {
                    recordId: this.recordId,
                    actionName: this.label === LABELS.Edit ? 'edit' : 'new'
                }
            });
        }
    }
}