import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { publish, MessageContext } from 'lightning/messageService';
import RECORD_CHANGE_CHANNEL from '@salesforce/messageChannel/RECORD_CHANGE__c';

import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import RECORD_TYPE_ID_FIELD from '@salesforce/schema/Account.RecordTypeId';

import PATIENT_RECORD_TYPE_LABEL from '@salesforce/label/c.Patient_Record_Type_Label';

const OBJECT_NAME = 'PartyConsent';
const ACTION = 'create';
const SOURCE = 'screenflow';

/**
 * @author      : Yogesh Rana
 * @created Date: 26th December 2025
 * @description : Create Party Consent Component
 *                This component is used to create a Party Consent for the Individual record.
 * =========================== Logs ======================================
 * Version      Modified Date            Modified By             Brief Note
 * V1.0.0       26th December 2025       Yogesh Rana            Initial Version
 */
export default class CreatePartyConsent extends LightningElement {
    @api recordId;
    @api buttonName = 'Create Party Consent';
    @api flowAPIName = 'Create_Party_Consent';

    recordTypeName;
    recordTypeId;
    objectInfo;
    showButton = false;

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
            this.showButton = false;
        }
    }

    /* -------------------- Wire Object Info -------------------- */
    @wire(getObjectInfo, { objectApiName: ACCOUNT_OBJECT })
    wiredObjectInfo({ data, error }) {
        if (data) {
            this.objectInfo = data;
            this.runResolveRecordTypeName();
        } else if (error) {
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

            // Only show button if record type is "Patient"
            this.showButton = this.recordTypeName && this.recordTypeName == PATIENT_RECORD_TYPE_LABEL ? true : false;
        }
    }

    /**
     * @description Handles the status of the flow.
     */
    handleStatus(event) {
        if (event && event.detail.status === 'FINISHED') {
            publish(this.messageContext, RECORD_CHANGE_CHANNEL, {
                action: ACTION,
                recordId: this.recordId,
                objectName: OBJECT_NAME,
                source: SOURCE
            });
        }
    }
}