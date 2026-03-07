/**
 * @author      : Salesforce
 * @created Date: 
 * @description : Provider/Practice Lead Conversion Component
 *                Validates and converts Provider/Practice leads to accounts
 * @story Number: 
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * v1.0.0       [Original Date]     [Original Author]       Initial Version
 * v1.0.1       11th Feb,2026       Sushanth Shetty         Refactored to use single Apex call, removed wire adapter, 
 *                                                          added Full Match error messages (US - 2252)
 * v1.0.2       4th Mar,2026       Bijayalaxmi Prusty       Updated (US -NGASIM- 2343)
 */
import { api, track } from 'lwc';
import fetchLeadRecord from '@salesforce/apex/ProviderPracticeLeadService.fetchLeadRecord';
import processLead from '@salesforce/apex/ProviderPracticeLeadService.processLead';
import { NavigationMixin } from 'lightning/navigation';
import LightningModal from 'lightning/modal';
import { CloseActionScreenEvent } from 'lightning/actions';

import CONVERSION_FAILED from "@salesforce/label/c.LCE_Failed";
import MISSING_REQUIRED_DATA from "@salesforce/label/c.LCE_MIssingData";
import POSTALCODE_REQUIRED from "@salesforce/label/c.LCE_RequiredPostalcode";
import PRACTICE_NAME_REQUIRED from "@salesforce/label/c.LCE_PracticeNameRequired";
import NO_LEAD_RECORD from "@salesforce/label/c.LCE_NoLeadRecord";
import LEAD_ALREADY_CONVERTED from "@salesforce/label/c.LCE_AlreadyConverted";
import INSUFFICIENT_PRIVILEGE from "@salesforce/label/c.LCE_InsufficientAccess";
import PROVIDER_ALREADY_EXISTS from "@salesforce/label/c.LCE_ProviderAlreadyExists";
import PRACTICE_ALREADY_EXISTS from "@salesforce/label/c.LCE_PracticeAlreadyExists";
import PROVIDER_PRACTICE_ALREADY_EXIST from "@salesforce/label/c.LCE_ProviderPracticeAlreadyExist";
import PREREQUISITE_VALIDATION_HEADER from "@salesforce/label/c.LCE_Header";

//Centralized constants for error messages
const ERROR_MESSAGES = {
    CONVERSION_FAILED,
    MISSING_REQUIRED_DATA,
    POSTALCODE_REQUIRED,
    PRACTICE_NAME_REQUIRED,
    NO_LEAD_RECORD,
    LEAD_ALREADY_CONVERTED,
    INSUFFICIENT_PRIVILEGE,
    PROVIDER_ALREADY_EXISTS,
    PRACTICE_ALREADY_EXISTS,
    PROVIDER_PRACTICE_ALREADY_EXIST
};

// Matching status values
const MATCHING_STATUS = {
    FULL_MATCH: 'Full Match',
    NO_MATCH: 'No Match'
};



export default class ProviderPracticeLeadConvert extends NavigationMixin(LightningModal) {
    @track providerName;
    @track practiceName;
    @track isLoading = false;
    @track showAccountDetails = false;
    @track errorMessages = [];
    leadRecord;
    isLeadConverted = false;
    _recordId;
    accountsList = [];

    /**
     * @description When recordId is available, automatically fetch and process lead.
     */
    @api
    set recordId(value) {
        if (value && value !== this._recordId) {
            this._recordId = value;
            this.fetchAndProcessLead();
        }
    }
    get recordId() {
        return this._recordId;
    }

    get hasErrors() {
        return this.errorMessages && this.errorMessages.length > 0;
    }

    get lceHeader() {
        return PREREQUISITE_VALIDATION_HEADER;
    }

    /**
     * @description Fetch the lead, validate fields, and process conversion if valid.
     */
    async fetchAndProcessLead() {
        this.isLoading = true;
        this.errorMessages = [];
    
        try {
            this.leadRecord = await fetchLeadRecord({ leadId: this.recordId });
            if (!this.leadRecord) {
                this.showError([ERROR_MESSAGES.NO_LEAD_RECORD]);
                return;
            }
    
            const validationError = this.validateLeadRecord(this.leadRecord);
            if (validationError) {
                this.showError(validationError);
                return;
            }
            
            // Pre-conversion validation per NGASIM-375
            const preCheckValidationError = this.validateConversionCriteria(this.leadRecord);
            if (preCheckValidationError) {
                this.showError(preCheckValidationError);
                return;
            }
            
            // If all validations pass → process conversion
            await this.convertLead();
    
        } catch (error) {
            this.handleException(error);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Validate the fetched lead record and return error message (if any)
     * @param {Object} lead - The fetched lead record from Apex
     * @returns {String|null} Error message if validation fails, otherwise null
     */
    validateLeadRecord(lead) {
        const errors = [];
        const { IsConverted, Practice__c, Practice_Name__c, PostalCode } = lead;

        //Check if lead is already converted
        if (IsConverted) {
            return [ERROR_MESSAGES.LEAD_ALREADY_CONVERTED];

        }

        //Require Billing Postal Code when Practice is missing
        if (!Practice__c && !PostalCode) {
            errors.push(ERROR_MESSAGES.POSTALCODE_REQUIRED);
        }

        //Require Practice Name when Practice record is missing
        if (!Practice__c && !Practice_Name__c) {
            errors.push(ERROR_MESSAGES.PRACTICE_NAME_REQUIRED);
        }

        //Return null if all validations pass
        return errors.length > 0 ? errors : null;
    }

    
    /**
     * @description Pre-conversion validation per NGASIM-375
     * @param {Object} lead - The fetched lead record from Apex
     * @returns {Array|null} Array of error messages if validation fails, otherwise null
     */
    validateConversionCriteria(lead) {
        const providerError = this.validateProvider(lead);
        const practiceError = this.validatePractice(lead);
        
        // Special case: Both Provider AND Practice have Full Match
        if (providerError === ERROR_MESSAGES.PROVIDER_ALREADY_EXISTS && 
            practiceError === ERROR_MESSAGES.PRACTICE_ALREADY_EXISTS) {
            return [ERROR_MESSAGES.PROVIDER_PRACTICE_ALREADY_EXIST];
        }
        
        // Otherwise, collect individual errors
        const errors = [];
        if (providerError) {
            errors.push(providerError);
        }
        if (practiceError) {
            errors.push(practiceError);
        }
        
        // Remove duplicates (e.g., both inactive → single MISSING_REQUIRED_DATA)
        const uniqueErrors = [...new Set(errors)];
        
        return uniqueErrors.length > 0 ? uniqueErrors : null;
    }

    
    /**
     * @description Validate Provider: Checks assignment, Full Match, or required fields
     * @param {Object} lead - The fetched lead record from Apex
     * @returns {String|null} Error message if validation fails, otherwise null
     */
    validateProvider(lead) {
        const { Related_Provider__c, FirstName, LastName, NPI__c, Provider_Matching_Status__c } = lead;
        
        // If Provider is assigned and active, validation passes (ignore Full Match)
        if (Related_Provider__c) {
            const relatedProviderActive = lead.Related_Provider__r?.IsActive;
            if (relatedProviderActive === true) {
                return null; // Valid - has active provider
            }
            return ERROR_MESSAGES.MISSING_REQUIRED_DATA; // Inactive provider
        }
        
        // If Provider not assigned, check for Full Match first
        if (Provider_Matching_Status__c === MATCHING_STATUS.FULL_MATCH) {
            return ERROR_MESSAGES.PROVIDER_ALREADY_EXISTS;
        }
        
        // Check required fields and No Match status
        const hasRequiredFields = FirstName && LastName && NPI__c;
        const isNoMatch = Provider_Matching_Status__c === MATCHING_STATUS.NO_MATCH;
        
        if (hasRequiredFields && isNoMatch) {
            return null; // Valid - ready to create new provider
        }
        
        return ERROR_MESSAGES.MISSING_REQUIRED_DATA;
    }

    
    /**
     * @description Validate Practice: Checks assignment, Full Match, or required fields
     * @param {Object} lead - The fetched lead record from Apex
     * @returns {String|null} Error message if validation fails, otherwise null
     */
    validatePractice(lead) {
        const { Practice__c, Practice_Name__c, Street, City, PostalCode, Country, Practice_Matching_Status__c } = lead;
        
        // If Practice is assigned and active, validation passes (ignore Full Match)
        if (Practice__c) {
            const practiceActive = lead.Practice__r?.IsActive;
            if (practiceActive === true) {
                return null; // Valid - has active practice
            }
            return ERROR_MESSAGES.MISSING_REQUIRED_DATA; // Inactive practice
        }
        
        // If Practice not assigned, check for Full Match first
        if (Practice_Matching_Status__c === MATCHING_STATUS.FULL_MATCH) {
            return ERROR_MESSAGES.PRACTICE_ALREADY_EXISTS;
        }
        
        // Check required fields and No Match status
        const hasRequiredFields = Practice_Name__c && Street && City && PostalCode && Country;
        const isNoMatch = Practice_Matching_Status__c === MATCHING_STATUS.NO_MATCH;
        
        if (hasRequiredFields && isNoMatch) {
            return null; // Valid - ready to create new practice
        }
        
        return ERROR_MESSAGES.MISSING_REQUIRED_DATA;
    }

    /**
     * @description Perform the actual lead conversion via Apex.
     */
    async convertLead() {
        try {
            const result = await processLead({ leadId: this.recordId });
            if (result && Object.keys(result).length > 0) {
                const hasProvider = Object.prototype.hasOwnProperty.call(result, 'Provider') && result.Provider;
                const hasPractice = Object.prototype.hasOwnProperty.call(result, 'Practice') && result.Practice;

                // Only proceed if both Provider and Practice exist
                if (hasProvider && hasPractice) {                
                    const recordsArray = [];
                    for (const [key, record] of Object.entries(result)) {
                        if (!record) continue;
                        const displayName =
                            record.FirstName || record.LastName
                                ? `${record.FirstName || ''} ${record.LastName || ''}`.trim()
                                : record.Name || 'N/A';

                        const recordUrl = await this[NavigationMixin.GenerateUrl]({
                            type: 'standard__recordPage',
                            attributes: {
                                recordId: record.Id,
                                objectApiName: 'Account',
                                actionName: 'view'
                            }
                        });
                        recordsArray.push({
                            keyLabel: key, // "Provider" / "Practice"
                            name: displayName,
                            url: recordUrl
                        });
                    }
                    this.accountsList = recordsArray;
                    this.showAccountDetails = true;
                    this.isLeadConverted = true;
                }else{
                    this.showError([ERROR_MESSAGES.CONVERSION_FAILED]);
                }   
            }else {
                this.showError([ERROR_MESSAGES.CONVERSION_FAILED]);
            }    
        } catch (error) {
            this.handleException(error);
        } finally {
          //  this.closeActionEvent();
        }
    }
    /**
     * @description handle expection messages
     */
    handleException(error){
        const messages = Array.isArray(error) ? error : [error.body?.message || error.message];
        this.showError(messages);
    }

    /**
     * @description Show an error message in the UI.
     */
    showError(messages) {
        if (messages && Array.isArray(messages)) {
            this.errorMessages = messages.map(msg => {
                return msg && msg.includes("You do not have access")
                    ? ERROR_MESSAGES.INSUFFICIENT_PRIVILEGE
                    : msg;
            });
        } else {
            this.errorMessages = messages;
        }
    }

    /**
     * @description Close the quick action modal.
     */
    closeActionEvent() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    /**
     * @description Optional navigation to Lead list view.
     */
    closeModal() {
        this.isModalOpen = false;
        if(this.isLeadConverted){
                this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: { objectApiName: 'Lead', actionName: 'list' },
                state: { filterName: 'Recent' }
            });
        }else{
            this.closeActionEvent();
        }       
    }
}