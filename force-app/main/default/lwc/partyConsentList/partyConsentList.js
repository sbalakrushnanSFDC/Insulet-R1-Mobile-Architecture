import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { subscribe,unsubscribe, MessageContext } from 'lightning/messageService';
import RECORD_CHANGE_CHANNEL from '@salesforce/messageChannel/RECORD_CHANGE__c';

import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import RECORD_TYPE_ID_FIELD from '@salesforce/schema/Account.RecordTypeId';

import getRelatedRecordsWithTypes from '@salesforce/apex/PartyConsentListController.getRelatedRecordsWithTypes';
import getUserTimeZoneAndLocale from '@salesforce/apex/Utility.getUserTimeZoneAndLocale';
import { formatDate, formatDateTime } from 'c/utilityComponent';

import RELATED_RECORDS_NOT_FOUND_TEXT from '@salesforce/label/c.Related_Records_Not_Found_Text';
import PATIENT_RECORD_TYPE_LABEL from '@salesforce/label/c.Patient_Record_Type_Label';

const ACTION = 'create';
const SOURCE = 'screenflow';
/**
 * @author      : Yogesh Rana
 * @created Date: 26th December 2025
 * @description : Party Consents Related List Component
 *                This component is used to display the Party Consents related list for the Individual record.
 * =========================== Logs ======================================
 * Version      Modified Date            Modified By             Brief Note
 * V1.0.0       26th December 2025       Yogesh Rana            Initial Version (NGOMCT-1278, NGOMCT-1280)
 */
export default class PartyConsentList extends LightningElement{

    /* -------------------- Configurable Properties -------------------- */
    _recordId;
    @api 
    set recordId(value) {
        this._recordId = value;
        this.runFetchRelatedRecords();
    }
    get recordId() {
        return this._recordId;
    }
    _iconName;
    @api 
    set iconName(value) {
        this._iconName = value ?? 'standard:individual';
        this.runFetchRelatedRecords();
    }
    get iconName() {
        return this._iconName;
    }
    
    
    _relatedListTitle;
    @api 
    set relatedListTitle(value) {
        this._relatedListTitle = value ?? 'Party Consents';
        this.runFetchRelatedRecords();
    }
    get relatedListTitle() {
        return this._relatedListTitle;
    }
    
    /**
     * @description Child object API name for the related records.
     */
    _childObjectApiName;
    @api 
    set childObjectApiName(value) {
        this._childObjectApiName = value ?? 'PartyConsent';
        this.runFetchRelatedRecords();
    }
    get childObjectApiName() {
        return this._childObjectApiName;
    }
    
    /**
     * @description Relationship field for the related records.
     */
    _relationshipField;
    @api 
    set relationshipField(value) {
        this._relationshipField = value ?? 'Individual__c';
        this.runFetchRelatedRecords();
    }
    get relationshipField() {
        return this._relationshipField;
    }
    
    /**
     * @description Field names for the related records.
     */
    _fieldNames;
    @api 
    set fieldNames(value) {
        this._fieldNames = value ?? 'Name, DataUsePurpose.Name, CaptureDate, EffectiveFrom, EffectiveTo';
        this.runFetchRelatedRecords();
    }
    get fieldNames() {
        return this._fieldNames;
    }
    
    /**
     * @description Column labels for the related records.
     */
    _columnLabels;
    @api 
    set columnLabels(value) {
        this._columnLabels = value ?? 'Name, Data Use Purpose, Consent Capture Date Time, Effective From, Effective To';
        this.runFetchRelatedRecords();
    }
    get columnLabels() {
        return this._columnLabels;
    }
    
    /**
     * @description Sort field for the related records.
     */
    _sortedBy;
    @api 
    set sortedBy(value) {
        this._sortedBy = value ?? 'LastModifiedDate';
        this.runFetchRelatedRecords();
    }
    get sortedBy() {
        return this._sortedBy;
    }
    
    /**
     * @description Sort direction for the related records.
     */
    _sortDirection;
    @api 
    set sortDirection(value) {
        this._sortDirection = value ?? 'desc';
        this.runFetchRelatedRecords();
    }
    get sortDirection() {
        return this._sortDirection;
    }
   
    /**
     * @description Record limit for the related records.
     */
    _recordLimit;
    @api 
    set recordLimit(value) {
        this._recordLimit = value ?? 5;
        this.runFetchRelatedRecords();
    }
    get recordLimit() {
        return this._recordLimit;
    }

    /**
     * @description Type filter for the related records.
     */
    _typeFilter;
    @api 
    set typeFilter(value) {
        this._typeFilter = value ?? 'Virtual Training, Group Training';
        this.runFetchRelatedRecords();
    }
    get typeFilter() {
        return this._typeFilter;
    }

    /**
     * @description Checks if all properties are ready.
     */
    get allPropsReady() {
        return (
            this._recordId !== undefined &&
            this._iconName !== undefined &&
            this._relatedListTitle !== undefined &&
            this._childObjectApiName !== undefined &&
            this._relationshipField !== undefined &&
            this._fieldNames !== undefined &&
            this._columnLabels !== undefined &&
            this._sortedBy !== undefined &&
            this._sortDirection !== undefined &&
            this._recordLimit !== undefined &&
            this._typeFilter !== undefined
        );
    }

    /* -------------------- Internal State -------------------- */
    subscription;
    records = [];
    columns = [];
    objectInfo;
    isLoading = true;
    error;
    userTimeZone;
    userLocale;

    recordTypeName;
    recordTypeId;
    showRelatedList = false;
    hasExecuted = false; // To avoid duplicate calls to the Apex method

    labels = {
        relatedRecordsNotFoundText: RELATED_RECORDS_NOT_FOUND_TEXT
    };

    get hasRecords() {
        return this.records && this.records.length > 0;
    }

    /* -------------------- Wire Message Context -------------------- */
    @wire(MessageContext)
    messageContext;

    /* -------------------- Wire Account Record -------------------- */
    @wire(getRecord, {
        recordId: '$recordId',
        fields: [RECORD_TYPE_ID_FIELD]
    })
    wiredAccount({ data, error }) {
        if (data && data.fields.RecordTypeId) {
            this.recordTypeId = data.fields.RecordTypeId.value;
            this.runResolveRecordTypeName();
        } else if (error) {
            console.error('Error fetching account record:', error);
            this.showRelatedList = false;
            this.isLoading = false;
        }
    }

    /* -------------------- Wire Object Info -------------------- */
    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    wiredObjectInfo({ data, error }) {
        if (data) {
            this.objectInfo = data;
            this.runResolveRecordTypeName();
        }else if (error) {
            console.error('Error fetching object info:', error);
        }
    }

    /**
     * @description Runs the resolve record type name method.
     */
    runResolveRecordTypeName() {
        if (this.recordTypeId && this.objectInfo) {
            this.resolveRecordTypeName();
        }
    }

    /**
     * @description Resolves the record type name for the account record.
     */
    resolveRecordTypeName() {
        const recordTypeInfo = this.objectInfo.recordTypeInfos;
        if (recordTypeInfo && Object.hasOwn(recordTypeInfo, this.recordTypeId)) {
            this.recordTypeName = recordTypeInfo[this.recordTypeId].name;

            // Only fetch related records if record type is "Patient"
            this.showRelatedList = this.recordTypeName && this.recordTypeName == PATIENT_RECORD_TYPE_LABEL ? true : false;
            this.runFetchRelatedRecords();
            this.isLoading = false;
        }
    }

    /**
     * @description Runs the fetch related records method.
     */
    runFetchRelatedRecords() {
        if (!this.hasExecuted && this.showRelatedList && this.allPropsReady) {
            this.hasExecuted = true;
            this.fetchRelatedRecords('');
        }
    }

    /* -------------------- Component Lifecycle -------------------- */
    async connectedCallback() {
        this.subscription = subscribe(this.messageContext, RECORD_CHANGE_CHANNEL, (message) => {
            if (message && message.action === ACTION 
                && message.objectName === this._childObjectApiName 
                && message.source === SOURCE) {
                const refreshApex = new Date().toLocaleString();
                this.fetchRelatedRecords(refreshApex);
            }
        });

        const userPrefs = await getUserTimeZoneAndLocale({});
        this.userTimeZone = userPrefs.timeZone;
        this.userLocale = userPrefs.locale;
    }

    /**
     * @description Unsubscribes from the message channel.
     */
    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
        }
    }

    /**
     * @description Fetches related records from Apex controller with field type information.
     *              Validates required configuration properties before making the call.
     *              Processes raw records to flatten nested fields and format dates/datetimes.
     *              Prepares column metadata for lightning-datatable display.
     */
    async fetchRelatedRecords(refreshApex) {
        // Validate required configuration properties
        if (!this._childObjectApiName || !this._relationshipField || !this._fieldNames) {
            this.records = undefined;
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        try {
            // Call Apex method with request wrapper containing all query parameters
            const response = await getRelatedRecordsWithTypes({ 
                request: {
                    accountId: this.recordId,
                    childObjectApi: this._childObjectApiName,
                    relationshipField: this._relationshipField,
                    fields: this._fieldNames,
                    sortedBy: this._sortedBy,
                    sortDirection: this._sortDirection,
                    recordLimit: this._recordLimit,
                    typeFilter: this._typeFilter
                },
                refreshApex: refreshApex
            });
            
            if(response && response.records) {
                this.records = [];
                const rawRecords = response.records;
                const fieldTypes = response.fieldTypes;

                // Process records: flatten nested fields and format date/datetime values
                this.records = this.processRecords(rawRecords, fieldTypes);

            }else{
                this.records = undefined;
                this.isLoading = false;
            }
        } catch (err) {
            this.records = undefined;
            console.error('Error fetching related records:', err);
        } finally {
            this.isLoading = false;
            // Prepare column definitions for datatable after data is loaded
            this.prepareColumns();
        }
    }
    

    /**
     * @description Processes raw records from Apex to prepare them for lightning-datatable display.
     *              Flattens nested lookup fields into top-level properties.
     *              Formats DATE and DATETIME fields based on user locale and timezone.
     */
    processRecords(rawRecords, fieldTypes) {
        // Parse comma-separated field list
        const fieldList = this._fieldNames.split(',').map(f => f.trim());
    
        return rawRecords.map(record => {
            const processedRecord = { Id: record.Id };
    
            fieldList.forEach(fieldName => {
                let value = '';
    
                // Handle nested lookup fields
                if (fieldName.includes('.')) {
                    const [parentField, childField] = fieldName.split('.');
                    value = record[parentField]?.[childField] ?? '';
                } else {
                    // Direct field access
                    value = record[fieldName] ?? '';
                }
    
                // Format date/datetime fields based on field type from Apex
                const type = fieldTypes[fieldName];
                if (value && (type === 'DATE' || type === 'DATETIME')) {
                    value = type === 'DATE' 
                        ? formatDate(value, this.userLocale) 
                        : formatDateTime(value, this.userLocale, this.userTimeZone);
                }
                processedRecord[fieldName] = value;
            });
            return processedRecord;
        });
    }
    

    /**
     * @description Prepares column definitions for lightning-datatable component.
     *              Maps field API names to display labels from columnLabels property.
     *              Falls back to field API name if no custom label is provided.
     *              Column order matches the order of fields in fieldNames property.
     */
    prepareColumns() {
        // Parse comma-separated field and label lists
        const fieldList = this._fieldNames.split(',').map(f => f.trim());
        const labelList = this._columnLabels ? this._columnLabels.split(',').map(l => l.trim()) : [];
    
        // Create column definitions matching field order
        this.columns = fieldList.map((fieldName, index) => ({
            label: labelList[index] !== '' && labelList[index] !== null ? labelList[index] : fieldName,
            fieldName: fieldName,
        }));
    }
}