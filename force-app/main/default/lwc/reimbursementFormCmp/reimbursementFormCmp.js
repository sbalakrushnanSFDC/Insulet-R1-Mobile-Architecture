import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import initializeReimbursementForm from '@salesforce/apex/ReimbursementController.initializeReimbursementForm';
import getTrainings from '@salesforce/apex/ReimbursementController.getTrainings';
import getObservations from '@salesforce/apex/ReimbursementController.getObservations';
import getRate from '@salesforce/apex/ReimbursementController.getRate';
import saveReimbursement from '@salesforce/apex/ReimbursementController.saveReimbursement';
import submitForApproval from '@salesforce/apex/ReimbursementController.submitForApproval';
import getReimbursement from '@salesforce/apex/ReimbursementController.getReimbursement';
import { log, showToast } from 'c/utilityComponent';
import { columns, LABELS, OPTIONS } from './reimbursementUtil.js';
import { NavigationMixin } from 'lightning/navigation';
import { RefreshEvent } from 'lightning/refresh';

const guardRailMessage = {
    Contract: {
        [OPTIONS.Patient_Training]: LABELS.Training_Contract_Error_Message,
        [OPTIONS.Observation]: LABELS.Observation_Contract_Error_Message
    },
    Certificate: {
        [OPTIONS.Patient_Training]: LABELS.Training_Certificate_Error_Message,
        [OPTIONS.Observation]: LABELS.Observation_Certificate_Error_Message
    }
}

export default class ReimbursementFormCmp extends NavigationMixin(LightningElement) {
    @api trainerId;
    picklistLabels = [];
    practiceIds = [];
    selectedOption;
    _selectedRows = [];
    recordSelected
    showOnlyOneRecordSelectedMessage = false;
    isFormOpen = false;
    trainings;
    observations;
    maxRecords = 5;
    showNextButton = true;
    reimbursementId;
    isLoading = true;
    errorMessage = { noRecords: this.labels.No_Records }
    trainingEducatorType;
    trainingContractType;

    @track wrapper = {};

    // Label getters for HTML template
    get labels() {
        return LABELS;
    }

    get isPatientTraining() {
        return this.selectedOption === OPTIONS.Patient_Training;
    }

    get isObservation() {
        return this.selectedOption === OPTIONS.Observation;
    }

    get columns() {
        return this.isPatientTraining ? columns.training : columns.observation;
    }

    get rowData() {
        return this.isPatientTraining ? this.trainings : this.observations;
    }

    get typeLabel() {
        return this.isPatientTraining ? LABELS.Select_Training : LABELS.Select_Observation;
    }

    get tableTitle() {
        return this.isPatientTraining ? LABELS.Available_Trainings : LABELS.Available_Observations;
    }

    get isNew() {
        return this.actionName === 'new';
    }

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (pageRef && pageRef.state) {
            this.actionName = pageRef.state.actionName;
            this.reimbursementId = pageRef.state.recordId;
            log('My Parameter Value:', this.actionName, this.reimbursementId);
            if (this.reimbursementId) {
                this.loadReimbursement();
            }
        }
    }

    handleModalOpen() {
        this.isModalOpen = true;
        this.isLoading = true;
        setTimeout(() => {
            this.isLoading = false;
        }, 2000);
    }

    handleModalClose() {
        this.isModalOpen = false;
    }
    isModalOpen = false;

    @wire(initializeReimbursementForm, { trainerId: '$trainerId' })
    wiredInitializeReimbursementForm({ error, data }) {
        if (error) {
            log('Error: ' + error);
        } else if (data) {
            this.picklistLabels = data.picklistLabels;
            this.practiceIds = data.practiceIds;
            log('picklistLabels', this.picklistLabels);
            log('practiceIds', this.practiceIds);
            this.isLoading = false;
        }
    }

    handleTypeSelect(event) {
        const selectedOption = event.detail.value;
        this.selectedOption = selectedOption;
        log('selectedOption: ' + selectedOption);
        this.refreshPage();
        if (selectedOption === OPTIONS.Patient_Training) {
            if (!this.trainings) getTrainings({ trainerId: this.trainerId }).then(data => this.trainings = data);
        } else if (selectedOption === OPTIONS.Observation) {
            if (!this.observations) getObservations({ trainerId: this.trainerId }).then(data => this.observations = data);
        } else {
            log('No option selected');
        }
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRowId;
        log('selectedRows: ' + JSON.stringify(selectedRows));
        if (selectedRows) {
            this.isFormOpen = false
            const record = this.rowData.find(row => row.Id === selectedRows[0])
            this.recordSelected = record.name
            this.trainingContractType = record.contractType;
            this.trainingEducatorType = record.educatorType;
            if (record && !record?.isContractValid) {
                showToast('Error', guardRailMessage['Contract'][this.selectedOption], 'error')
                return
            }
            if (record && !record?.isCertificationValid) {
                showToast('Error', guardRailMessage['Certificate'][this.selectedOption], 'error')
                return
            }
            this.isLoading = true;
            getRate({ rec: JSON.stringify(this.rowData.find(row => row.Id === selectedRows[0])) }).then(data => { this.wrapper = data; this.getRate(); this.isLoading = false });
        }
        else {
            this.recordSelected = '';
            this.isFormOpen = false;
        }
    }

    handleDoneClick() {
        this.handleModalClose();
        this.getRate();
    }

    getRate() {
        log('API Call to get Rate');
        this.isFormOpen = true;
    }

    handleInput(event) {
        const amountType = event.target.dataset.amountType;
        const amount = event.target.value;
        log('amountType: ' + amountType + ' amount: ' + amount);
        this.wrapper[`${amountType}Amount`] = Math.round((Number(amount) || 0) * 100) / 100;
    }

    handleMinutesSelect(event) {
        this.wrapper['numberOfMinutes'] = event.detail.value;
    }


    get grandTotal() {
        if (this.isPatientTraining) {
            return this.parkingTollsOtherTotal + this.preApprovedItemsTotal + this.mileageSubtotal + (this.wrapper.rateApplied || 0);
        } else {
            return this.parkingTollsOtherTotal + this.preApprovedItemsTotal + this.mileageSubtotal + (this.hourlyRateSubtotal || 0);
        }
    }

    get parkingTollsOtherTotal() {
        return (this.wrapper.parkingAmount || 0) + (this.wrapper.othersAmount || 0) + (this.wrapper.tollsAmount || 0);
    }

    get preApprovedItemsTotal() {
        return (this.wrapper.mealAmount || 0) + (this.wrapper.hotelAmount || 0) + (this.wrapper.carRentalAmount || 0) + (this.wrapper.trainBusAirfareAmount || 0);
    }

    get mileageSubtotal() {
        let mileage = (this.wrapper.milesTravelledAmount || 0) * (this.wrapper.mileageRate || 0)
        return Math.round(mileage * 100) / 100;
    }

    get hourlyRateSubtotal() {
        return Math.round((this.wrapper.numberOfMinutes || 0) * ((this.wrapper.hourlyRate || 0) / 60) * 100) / 100;
    }

    get checkCCTLevel1Level2() {
        return ((this.isNew) && (this.trainingEducatorType === this.labels.Reimbursement_Educator_Type_CCT) && (this.trainingContractType === this.labels.Reimbursement_Contract_Level_1 || this.trainingContractType === this.labels.Reimbursement_Contract_Level_2)) || ((this.wrapper.educatorType === this.labels.Reimbursement_Educator_Type_CCT) && (this.wrapper.contractLevel === this.labels.Reimbursement_Contract_Level_1 || this.wrapper.contractLevel === this.labels.Reimbursement_Contract_Level_2))

    }

    get checkIsNewOrCPTLevel3() {
        return ((this.isNew) && (this.trainingEducatorType === this.labels.Reimbursement_Educator_Type_CPT && this.trainingContractType === this.labels.Reimbursement_Contract_Level_3)) || (this.wrapper.educatorType === this.labels.Reimbursement_Educator_Type_CPT && this.wrapper.contractLevel === this.labels.Reimbursement_Contract_Level_3)

    }

    get checkCPTLevel2() {
        return ((this.isNew) && (this.trainingEducatorType === this.labels.Reimbursement_Educator_Type_CPT && this.trainingContractType === this.labels.Reimbursement_Contract_Level_2)) || (this.wrapper.educatorType === this.labels.Reimbursement_Educator_Type_CPT && this.wrapper.contractLevel === this.labels.Reimbursement_Contract_Level_2)

    }

    handleCancel() {
        // Refresh Page State Variables
        this.dispatchEvent(new RefreshEvent());
        history.back();
    }

    handleSaveAsDraft() {
        this.isFormOpen = false;
        this.saveReimbursement(() => { this.navigateToDetailPage() })
    }

    handleNext() {
        this.saveReimbursement(() => {
            this.showNextButton = false;
        })
    }

    handleSubmit() {
        this.isFormOpen = false;
        this.isLoading = true;
        submitForApproval({ reimbursementId: this.reimbursementId }).then(data => {
            log('submitForApproval', data);
            this.navigateToDetailPage();
            this.isLoading = false;
        });
    }

    saveReimbursement(callback) {
        this.wrapper.trainerId = this.trainerId;
        this.wrapper.type = this.selectedOption;
        this.wrapper.Id = this.reimbursementId;
        this.wrapper.hourlyRateTotal = this.hourlyRateSubtotal
        this.isLoading = true;
        saveReimbursement({ wrapper: JSON.stringify(this.wrapper) }).then(data => {
            log('saveReimbursement', data);
            this.reimbursementId = data.Id;
            this.isLoading = false;
            callback && callback(data)
        })
    }

    navigateToDetailPage() {
        this[NavigationMixin.Navigate](
            {
                type: 'standard__webPage',
                attributes: {
                    url: `/reimbursement/${this.reimbursementId}`
                }
            }
        );
    }

    refreshPage() {
        this.dispatchEvent(new RefreshEvent());
        this.recordSelected = '';
        this.isFormOpen = false;
        Object.keys(this.wrapper).forEach(key => {
            if (key.includes('Amount')) {
                this.wrapper[key] = 0;
            }
        });
    }

    loadReimbursement() {
        this.isLoading = true;
        getReimbursement({ reimbursementId: this.reimbursementId }).then(data => {
            log('loadReimbursement' + JSON.stringify(data));
            this.wrapper = data;
            this.isFormOpen = true;
            this.selectedOption = data.type;
            this.isLoading = false;
        });
    }

    handleCommentsChange(event) {
        this.wrapper.comments = event.target.value;
    }
}