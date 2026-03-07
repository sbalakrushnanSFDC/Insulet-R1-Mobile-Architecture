import { LightningElement, api, track } from 'lwc';
import getTrainingRelatedList from '@salesforce/apex/ReimbursementController.getTrainingRelatedList';

// Custom Labels
import Training_Name from '@salesforce/label/c.Training_Name';
import Reimbursement_Training_Method from '@salesforce/label/c.Reimbursement_Training_Method';
import Training_Product from '@salesforce/label/c.Training_Product';
import Reimbursement_Training_Type from '@salesforce/label/c.Reimbursement_Training_Type';
import Reimbursement_Training_Conducted_Date from '@salesforce/label/c.Reimbursement_Training_Conducted_Date';
import Training_Title from '@salesforce/label/c.Training_Title';

const LABELS = {
    Training_Name: Training_Name,
    Training_Method: Reimbursement_Training_Method,
    Product: Training_Product,
    Training_Type: Reimbursement_Training_Type,
    Training_Conducted_Date: Reimbursement_Training_Conducted_Date,
    Training_Title: Training_Title
};

export default class TrainingRelatedList extends LightningElement {
    @api recordId;

    @track trainings = [];
    @track columns = [
        { label: LABELS.Training_Name, fieldName: 'Name' },
        { label: LABELS.Training_Method, fieldName: 'Training_Method__c' },
        { label: LABELS.Product, fieldName: 'Product__c' },
        { label: LABELS.Training_Type, fieldName: 'Training_Type__c' },
        { label: LABELS.Training_Conducted_Date, fieldName: 'Training_Conducted_Date__c' },
    ];

    // Expose labels to template
    labels = LABELS;

    connectedCallback() {
        this.loadTrainings();
    }

    loadTrainings() {
        getTrainingRelatedList({ recordId: this.recordId })
            .then(result => {
                this.trainings = result;
            });
    }

    get showTable() {
        return this.trainings.length > 0;
    }
}