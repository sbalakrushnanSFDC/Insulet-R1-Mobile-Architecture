import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import LAST_MODIFIED_DATE from '@salesforce/schema/Lead.LastModifiedDate';
import getDuplicateMatches from '@salesforce/apex/LeadDuplicateController.getDuplicateMatches';
import closeLeadsAsDuplicate from '@salesforce/apex/LeadService.closeLeadsAsDuplicate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LDW_AccountDuplicates from "@salesforce/label/c.LDW_AccountDuplicates";
import LDW_AllDuplicates from "@salesforce/label/c.LDW_AllDuplicates";
import LDW_DuplicateLeads from "@salesforce/label/c.LDW_DuplicateLeads";
import LDW_ErrorClosingLead from "@salesforce/label/c.LDW_ErrorClosingLead";
import LDW_ErrorLoadingDuplicates from "@salesforce/label/c.LDW_ErrorLoadingDuplicates";
import LDW_ErrorUnexpected from "@salesforce/label/c.LDW_ErrorUnexpected";
import LDW_LeadsClonedSuccess from "@salesforce/label/c.LDW_LeadsClonedSuccess";
import LDW_NoDuplicates from "@salesforce/label/c.LDW_NoDuplicates";
import LDW_NoPotentialDuplicates from "@salesforce/label/c.LDW_NoPotentialDuplicates";
import LDW_PotentialMatch from "@salesforce/label/c.LDW_PotentialMatch";
import LDW_ReviewPotentialDuplicates from "@salesforce/label/c.LDW_ReviewPotentialDuplicates";

export default class LeadDuplicateViewer extends NavigationMixin(LightningElement) {
    @api recordId; // Lead ID from record page
    duplicateData = [];
    leadDuplicates = [];
    accountDuplicates = [];
    isModalOpen = false;
    isLoading = true; // initialize true for first load
    error = null;
    firstDuplicate = null;
    totalDuplicatesCount = 0;
    selectedLeadRows = [];
    isClosingLeads = false;
    lastModifiedDate = null; // Track last modified date to detect saves

    wiredResult; // store wire result for refreshApex
    recordWireResult; // store record wire result

    label = {
        LDW_AccountDuplicates,
        LDW_AllDuplicates,
        LDW_DuplicateLeads,
        LDW_ErrorClosingLead,
        LDW_ErrorLoadingDuplicates,
        LDW_ErrorUnexpected,
        LDW_LeadsClonedSuccess,
        LDW_NoDuplicates,
        LDW_NoPotentialDuplicates,
        LDW_PotentialMatch,
        LDW_ReviewPotentialDuplicates
    }

    // Wire adapter to watch for record changes (detects saves)
    @wire(getRecord, { recordId: '$recordId', fields: [LAST_MODIFIED_DATE] })
    wiredRecord(result) {
        this.recordWireResult = result;
        const { data, error } = result;
        
        if (data) {
            const currentLastModified = getFieldValue(data, LAST_MODIFIED_DATE);
            
            // If lastModifiedDate changed and it's not the initial load, refresh duplicates
            if (this.lastModifiedDate && this.lastModifiedDate !== currentLastModified) {
                this.refreshDuplicateData();
            }
            
            this.lastModifiedDate = currentLastModified;
        } else if (error) {
            console.error('Error watching record:', error);
        }
    }

    // Column definitions for Lead duplicates table
    leadColumns = [
        {
            label: 'Name',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'name' },
                target: '_blank'
            }
        },
        { label: 'Date of Birth', fieldName: 'formattedDateOfBirth', type: 'text' },
        { label: 'Email', fieldName: 'email', type: 'email' },
        { label: 'Phone', fieldName: 'phone', type: 'phone' },
        { label: 'Address', fieldName: 'address', type: 'text' },
        { label: 'Status', fieldName: 'status', type: 'text' },
        { label: 'Match Type', fieldName: 'matchingStatus', type: 'text' }
    ];

    // Column definitions for Account duplicates table  
    accountColumns = [
        {
            label: 'Name',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'name' },
                target: '_blank'
            }
        },
        { label: 'Date of Birth', fieldName: 'formattedDateOfBirth', type: 'text' },
        { label: 'Email', fieldName: 'email', type: 'email' },
        { label: 'Phone', fieldName: 'phone', type: 'phone' },
        { label: 'Address', fieldName: 'address', type: 'text' },
        { label: 'Match Type', fieldName: 'matchingStatus', type: 'text' }
    ];

    @wire(getDuplicateMatches, { leadId: '$recordId' })
    async wiredDuplicates(value) {
        this.wiredResult = value;
        const { error, data } = value;

        try {
            if (data) {
                const processed = await this.processDuplicateData(data);
                // Optionally generate record URLs using NavigationMixin.GenerateUrl
                const withUrls = await this.generateRecordUrls(processed);
                this.duplicateData = withUrls;
                this.separateDuplicatesByType();
                this.setFirstDuplicate();
                this.totalDuplicatesCount = this.duplicateData.length;
                this.error = null;
            } else if (error) {
                this.error = error;
                this.duplicateData = [];
                this.leadDuplicates = [];
                this.accountDuplicates = [];
                this.firstDuplicate = null;
                this.totalDuplicatesCount = 0;
                this.showErrorToast(this.label.LDW_ErrorLoadingDuplicates,
                    error.body?.message || this.label.LDW_ErrorUnexpected);
            }
        } finally {
            this.isLoading = false;
        }
    }

    processDuplicateData(data) {
        return data.map(duplicate => {
            return {
                ...duplicate,
                // recordUrl will be generated via NavigationMixin.GenerateUrl
                recordUrl: null,
                emailUrl: duplicate.email ? `mailto:${duplicate.email}` : null,
                phoneUrl: duplicate.phone ? `tel:${duplicate.phone}` : null,
                formattedDateOfBirth: this.formatDateOfBirth(duplicate.dateOfBirth)
            };
        });
    }

    async generateRecordUrls(records) {
        const results = await Promise.all(
            records.map(async rec => {
                try {
                    const url = await this[NavigationMixin.GenerateUrl]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: rec.recordId,
                            actionName: 'view'
                        }
                    });
                    return { ...rec, recordUrl: url };
                } catch{
                    // Fallback to relative URL if GenerateUrl fails
                    return { ...rec, recordUrl: `/${rec.recordId}` };
                }
            })
        );
        return results;
    }

    formatDateOfBirth(dateOfBirth) {
        if (!dateOfBirth) return null;
        // Format date as MM/DD/YYYY
        // Parse date string directly (format: "2022-11-27") to avoid timezone conversion issues
        const [year, month, day] = dateOfBirth.split('-');
        // Convert to numbers and back to strings to remove leading zeros
        return `${parseInt(month, 10)}/${parseInt(day, 10)}/${year}`;
    }

    separateDuplicatesByType() {
        this.leadDuplicates = this.duplicateData.filter(dup => dup.recordType === 'Lead');
        this.accountDuplicates = this.duplicateData.filter(dup => dup.recordType === 'Account');
    }

    setFirstDuplicate() {
        if (this.duplicateData.length > 0) {
            // Prioritize Full Match first, then Partial Match
            const fullMatches = this.duplicateData.filter(dup => dup.matchingStatus === 'Full Match');

            if (fullMatches.length > 0) {
                this.firstDuplicate = fullMatches[0];
            } else {
                // Since Apex filters out "No Match", remaining records are Partial Match
                this.firstDuplicate = this.duplicateData[0];
            }
        } else {
            this.firstDuplicate = null;
        }
    }

    get hasDuplicates() {
        return this.duplicateData && this.duplicateData.length > 0;
    }

    get hasLeadDuplicates() {
        return this.leadDuplicates && this.leadDuplicates.length > 0;
    }

    get hasAccountDuplicates() {
        return this.accountDuplicates && this.accountDuplicates.length > 0;
    }

    get showViewAllButton() {
        return this.totalDuplicatesCount > 0;
    }

    get cardTitle() {
        if (!this.hasDuplicates) return 'No Duplicates Found';
        return `Potential Duplicates (${this.totalDuplicatesCount})`;
    }

    get pluralSuffix() {
        return this.totalDuplicatesCount === 1 ? '' : 'es';
    }

    get isCloseButtonDisabled() {
        return this.selectedLeadRows.length === 0 || this.isClosingLeads;
    }

    get potentialMatchMessage(){

        let message = this.label.LDW_PotentialMatch;
        message = message.replace("<<totalDuplicatesCount>>", this.totalDuplicatesCount);
        message = message.replace("<<pluralSuffix>>", this.pluralSuffix);
        return message;

    }

    get duplicateRecordsMessage(){
        this.label.LDW_AllDuplicates.replace("<<totalDuplicatesCount>>",this.totalDuplicatesCount);
    }

    get duplicateLeadMessage(){
        this.label.LDW_DuplicateLeads.replace("<<leadDuplicateslcount>>",this.leadDuplicates.length);
    }

    get duplicateAccountMessage(){
        this.label.LDW_AccountDuplicates.replace("<<accountDuplicatesCount>>",this.accountDuplicates.length);
    }


    handleViewAll() {
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
        // Reset selected rows when closing modal
        this.selectedLeadRows = [];
    }

    handleLeadRowSelection(event) {
        this.selectedLeadRows = event.detail.selectedRows.map(row => row.recordId);
    }

    async handleCloseAsDuplicate() {
        if (this.selectedLeadRows.length === 0) {
            return;
        }

        this.isClosingLeads = true;

        try {
            await closeLeadsAsDuplicate({ leadIds: this.selectedLeadRows });

            this.showSuccessToast(
                'Success',
                `${this.selectedLeadRows.length} ${this.label.LDW_LeadsClonedSuccess}`
            );

            // Reset selection and close modal
            this.selectedLeadRows = [];
            this.isModalOpen = false;

            // Refresh the duplicate data to reflect changes
            this.refreshDuplicateData();

        } catch (error) {
            this.showErrorToast(
                'Error closing leads',
                error.body?.message || this.label.LDW_ErrorClosingLead
            );
        } finally {
            this.isClosingLeads = false;
        }
    }

    async refreshDuplicateData() {
        if (this.wiredResult) {
            await refreshApex(this.wiredResult);
        }
    }

    navigateToRecord(event) {
        const recordId = event.currentTarget.dataset.recordId;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    showErrorToast(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'error'
            })
        );
    }
    showSuccessToast(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'success'
            })
        );
    }
}