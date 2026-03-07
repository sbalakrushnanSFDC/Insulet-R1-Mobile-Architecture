import { api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';

// Apex methods
import getDuplicateMatches from '@salesforce/apex/LeadDuplicateController.getDuplicateMatches';
import processLeadForConversionFromLWC from '@salesforce/apex/LeadDuplicateConversionService.processLeadForConversionFromLWC';
import runPrechecks from '@salesforce/apex/LeadConversionPrecheckService.runPrechecks';
import getConversionTypeManual from '@salesforce/apex/ConstantsUtil.getConversionTypeManual';

import CONVERSION_FAILED from "@salesforce/label/c.PLC_Failed";
import ALREADY_CONVERTED from "@salesforce/label/c.PLC_AlreadyConverted";
import INSUFFICIENT_PRIVILEGE from "@salesforce/label/c.PLC_InsufficientAccess";
import PLC_MatchCriteriaNotMet from "@salesforce/label/c.PLC_MatchCriteriaNotMet";
import PLC_Success from "@salesforce/label/c.PLC_Success";
import PLC_UnexpectedError from "@salesforce/label/c.PLC_UnexpectedError";



const ERROR_MESSAGES = {
    CONVERSION_FAILED,
    ALREADY_CONVERTED,
    INSUFFICIENT_PRIVILEGE,
    PLC_MatchCriteriaNotMet,
    PLC_UnexpectedError
};

const Label = {
    PLC_Success
}

export default class PatientLeadConversionCmp extends NavigationMixin(LightningModal) {
    @track leadData; 
    @track duplicateData; 
    @track leadDuplicates = [];
    @track accountDuplicates = [];
    @track isLoading = false;
    @track errorMessages = [];
    @track isLeadConverted = false;
    @track accountsList = [];
    @track showOpportunityTable = false;
    @track allOpportunities = [];
    
    _recordId;
    hasLeadNoMatch = false;
    hasAccountFullMatch = false;
    hasAccountNoMatch = false;
    hasPartialMatchOnly = false;
    matchedAccountId = null;
    hasInitialValidationRun = false;
    leadFullMatchCount = 0;
    accountFullMatchCount = 0;

    @api
    set recordId(value) {
        if (value && value !== this._recordId) {
            this._recordId = value;
        }
    }
    get recordId() {
        return this._recordId;
    }

    /**
     * @description Computed property to control Spinner visibility.
     * Shows spinner if we are explicitly loading OR if data dependencies are not yet met.
     */
    get shouldShowSpinner() {
        // If there are errors, hide spinner so user can read them
        if (this.hasErrors) {
            return false;
        }
        // Show spinner if manually loading OR waiting for initial data
        return this.isLoading || !this.leadData || this.duplicateData === undefined;
    }

    /**
     * @description Fields to fetch for lead record
     */
    get leadFields() {
        return ['Lead.IsConverted'];
    }

    /**
     * @description Wire to get Lead record
     */
    @wire(getRecord, { recordId: '$recordId', fields: '$leadFields' })
    wiredLead({ error, data }) {
        if (data) {
            this.leadData = {
                isConverted: data.fields.IsConverted?.value
            };
            // Attempt conversion now that Lead data is ready
            this.attemptAutoConversion();
        } else if (error) {
            this.handleException(error);
        }
    }

    /**
     * @description Wire to get duplicate matches using LeadDuplicateController
     */
    @wire(getDuplicateMatches, { leadId: '$recordId' })
    wiredDuplicates({ error, data }) {
        if (data) {
            this.duplicateData = data;
            // Attempt conversion now that Duplicate data is ready
            this.attemptAutoConversion();
        } else if (error) {
            this.handleException(error);
        }
    }

    /**
     * @description Orchestrator method: Ensures ALL data is present before running logic.
     * Fixes the race condition where duplicate data loaded before lead data.
     */
    async attemptAutoConversion() {
        // 1. DATA READINESS CHECK: Stop if either source is missing
        if (!this.leadData || this.duplicateData === undefined) {
            return;
        }

        // 2. RUN ONCE CHECK: Prevent re-running if logic already executed
        if (this.hasInitialValidationRun) {
            return;
        }

        try {
            // 3. PROCESS: Separate and Analyze
            this.separateDuplicatesByType();
            this.analyzeMatchingStatus();
            
            // 4. VALIDATE: Check criteria
            this.validateConversionCriteria();
            
            // 5. STOP if validation failed
            if (this.errorMessages && this.errorMessages.length > 0) {
                return;
            }
            
            // 6. PREPARE & CONVERT
            await this.prepareDisplayData();
            
            this.hasInitialValidationRun = true;
            await this.convertLead();

        } catch (err) {
            this.handleException(err);
        }
    }

    /**
     * @description Separates duplicates by record type (Lead vs Account)
     */
    separateDuplicatesByType() {
        if (!this.duplicateData) return;
        this.leadDuplicates = this.duplicateData.filter(dup => dup.recordType === 'Lead');
        this.accountDuplicates = this.duplicateData.filter(dup => dup.recordType === 'Account');
    }

    /**
     * @description Analyzes matching status
     * Scenarios:
     * 1. No Match to Lead + Full Match to Account → Convert to existing Account
     * 2. Full Match to Lead + No Match to Account → Create new Account
     * 3. Partial Match ONLY to Lead/Account (no Full Match to either) + Duplicate Review Complete → Convert to new Account, Create Oppty, Create CCR
     * 4. No Match to Lead + No Match to Account → Create new Account
     */
    analyzeMatchingStatus() {
        let leadPartialMatchCount = 0;
        this.leadFullMatchCount = 0;
        
        for (const dup of this.leadDuplicates) {
            if (dup.matchingStatus === 'Full Match') {
                this.leadFullMatchCount++;
            } else if (dup.matchingStatus === 'Partial Match') {
                leadPartialMatchCount++;
            }
        }
        
        let accountPartialMatchCount = 0;
        this.accountFullMatchCount = 0;
        let firstAccountFullMatch = null;
        
        for (const dup of this.accountDuplicates) {
            if (dup.matchingStatus === 'Full Match') {
                this.accountFullMatchCount++;
                if (!firstAccountFullMatch) {
                    firstAccountFullMatch = dup;
                }
            } else if (dup.matchingStatus === 'Partial Match') {
                accountPartialMatchCount++;
            }
        }
        
        const hasAnyLeadMatch = this.leadFullMatchCount > 0 || leadPartialMatchCount > 0;
        const hasAnyAccountMatch = this.accountFullMatchCount > 0 || accountPartialMatchCount > 0;
        
        this.hasLeadNoMatch = !hasAnyLeadMatch;
        this.hasAccountFullMatch = this.accountFullMatchCount > 0;
        this.hasAccountNoMatch = !hasAnyAccountMatch;
        
        this.hasPartialMatchOnly = (this.leadFullMatchCount === 0 && this.accountFullMatchCount === 0) &&
                                   (leadPartialMatchCount > 0 || accountPartialMatchCount > 0);
        
        if (this.hasAccountFullMatch && firstAccountFullMatch) {
            this.matchedAccountId = firstAccountFullMatch.recordId;
        } else {
            this.matchedAccountId = null;
        }
    }

    /**
     * @description Validates all conversion criteria
     * Supports four scenarios:
     * 1. No Match to Lead + Full Match to Account → Convert to existing Account
     * 2. Full Match to Lead + No Match to Account → Create new Account
     * 3. Partial Match ONLY to Lead/Account + Duplicate Review Complete → Convert to new Account, Create Oppty, Create CCR
     * 4. No Match to Lead + No Match to Account → Create new Account
     */
    validateConversionCriteria() {
        const errors = [];
        
        // Don't validate until leadData is loaded
        if (!this.leadData || this.leadData.isConverted === undefined) {
            return;
        }
        
        // Check if lead is already converted
        if (this.leadData.isConverted) {
            errors.push(ERROR_MESSAGES.ALREADY_CONVERTED);
            this.errorMessages = errors;
            return;
        }
        
        const scenario1Valid = this.hasLeadNoMatch && this.accountFullMatchCount === 1;
        const scenario2Valid = this.leadFullMatchCount === 1 && this.hasAccountNoMatch;
        const scenario3Valid = this.hasPartialMatchOnly;
        const scenario4Valid = this.hasLeadNoMatch && this.hasAccountNoMatch;

        if (!scenario1Valid && !scenario2Valid && !scenario3Valid && !scenario4Valid) {
            errors.push(ERROR_MESSAGES.PLC_MatchCriteriaNotMet);
        }
        
        this.errorMessages = errors;
    }

    /**
     * @description Prepares display data for matched account
     */
    async prepareDisplayData() {
        try {
            if (this.hasAccountFullMatch && this.matchedAccountId) {
                const accountMatch = this.accountDuplicates.find(
                    dup => dup.recordId === this.matchedAccountId
                );
                
                if (accountMatch) {
                    const accountUrl = await this[NavigationMixin.GenerateUrl]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: accountMatch.recordId,
                            objectApiName: 'Account',
                            actionName: 'view'
                        }
                    });

                    this.accountsList = [{
                        id: accountMatch.recordId,
                        name: accountMatch.name,
                        url: accountUrl
                    }];
                }
            }
        } catch (error) {
            this.handleException(error);
        }
    }

    /**
     * @description Execute server-side metadata prechecks
     */
    async executePrechecks() {
        try {
            // Get conversion type constant from ConstantsUtil
            const conversionTypeManual = await getConversionTypeManual();
            const result = await runPrechecks({
            leadId: this.recordId,
            conversionType: conversionTypeManual
            });
            if (result?.ok) {
                return [];
            }
            const messages = result?.messages || [];
            return messages;
        } catch (error) {
            this.handleException(error);
            return [ERROR_MESSAGES.PLC_UnexpectedError];
        }
    }

    /**
     * @description Main conversion logic
     */
    async convertLead() {
        this.isLoading = true;
        this.errorMessages = [];

        const precheckErrors = await this.executePrechecks();
        if (precheckErrors.length > 0) {
            this.showError(precheckErrors);
            this.isLoading = false;
            return;
        }
        
        // Reset success state
        this.isLeadConverted = false;
        this.accountsList = [];
        this.allOpportunities = [];

        try {
            const result = await processLeadForConversionFromLWC({
                leadId: this.recordId
            });

            if (result?.success && result?.converted && result?.accountId && !result?.error) {
                await this.handleConversionSuccess(result);
            } else {
                const errorMessage = result?.error || ERROR_MESSAGES.CONVERSION_FAILED;
                this.showError([errorMessage]);
            }
        } catch (error) {
            this.handleException(error);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Handles successful conversion
     * @param result Result from LeadDuplicateConversionService
     */
    async handleConversionSuccess(result) {
        try {
            // Prepare account for display
            const accountUrl = await this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result.accountId,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });

            this.accountsList = [{
                keyLabel: 'Person Account',
                id: result.accountId,
                name: result.accountName || 'Converted Account',
                url: accountUrl
            }];

            // Prepare opportunities for display if created/updated
            if (result.opportunities && result.opportunities.length > 0) {
                // Store all opportunities for table view
                this.allOpportunities = await Promise.all(
                    result.opportunities.map(async (opp) => {
                        const oppUrl = await this[NavigationMixin.GenerateUrl]({
                            type: 'standard__recordPage',
                            attributes: {
                                recordId: opp.id,
                                objectApiName: 'Opportunity',
                                actionName: 'view'
                            }
                        });
                        
                        return {
                            id: opp.id,
                            name: opp.name,
                            url: oppUrl
                        };
                    })
                );
            }

            // Only set isLeadConverted to true after all processing is successful
            this.isLeadConverted = true;
            this.showToast('Success', Label.PLC_Success, 'success');
        } catch (error) {
            // Reset success state if there's an error
            this.isLeadConverted = false;
            this.accountsList = [];
            this.allOpportunities = [];
            this.handleException(error);
        }
    }

    /**
     * @description Handle exception messages
     */
    handleException(error) {
        const messages = Array.isArray(error) 
            ? error 
            : [error.body?.message || error.message || ERROR_MESSAGES.PLC_UnexpectedError];
        this.showError(messages);
    }

    /**
     * @description Show error messages
     */
    showError(messages) {
        if (messages && Array.isArray(messages)) {
            this.errorMessages = messages.map(msg => {
                return msg && msg.includes("You do not have access")
                    ? ERROR_MESSAGES.INSUFFICIENT_PRIVILEGE
                    : msg;
            });
        } else {
            this.errorMessages = [messages];
        }
    }

    /**
     * @description Show toast notification
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    /**
     * @description Close the modal
     */
    closeModal() {
        if (this.isLeadConverted) {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: { objectApiName: 'Lead', actionName: 'list' },
                state: { filterName: 'Recent' }
            });
        }
        // Dispatch event to close the Screen Action modal
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    get showSuccessState() {
        return this.isLeadConverted;
    }

    get hasErrors() {
        return this.errorMessages && this.errorMessages.length > 0;
    }

    get hasOpportunities() {
        return this.allOpportunities && this.allOpportunities.length > 0;
    }

    get firstOpportunity() {
        return this.allOpportunities?.[0] || null;
    }

    get hasMultipleOpportunities() {
        return this.allOpportunities && this.allOpportunities.length > 1;
    }

    get opportunitiesCount() {
        return this.allOpportunities?.length || 0;
    }

    get opportunitiesLabel() {
        return this.opportunitiesCount === 1 ? 'y' : 'ies';
    }

    get opportunityTableColumns() {
        return [
            { label: 'Opportunity Name', fieldName: 'url', type: 'url', typeAttributes: { label: { fieldName: 'name' }, target: '_blank' } }
        ];
    }

    /**
     * @description Toggle opportunity table view
     */
    handleViewAllOpportunities() {
        this.showOpportunityTable = !this.showOpportunityTable;
    }

    get viewAllLabel() {
        return `View All (${this.opportunitiesCount})`;
    }
}