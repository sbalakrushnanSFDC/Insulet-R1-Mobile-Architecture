/**
 * @author      : Ayush Sharma
 * @created Date: 28th Nov 2025
 * @description : Lightning Web Component that renders a read-only list of related Contact "patient" rows
 *                for the current Account using lightning-datatable. Data is retrieved via the Apex method
 *                TrainerCCRDataController.getRelatedContactRowsByAccount and includes Name, Email, Phone, and
 *                Relationship values derived from Contact-Contact Relationship (CCR).
 * 
 * NOTE: This LWC component is used instead of a Flow or FlexCard due to current technical limitations.
 * Flow: The standard data table in Flow cannot combine or display collections from multiple
 * objects (e.g., Related Contact + Party Role Relation fields), which is required for this use case.
 * FlexCard: FlexCards are still in the beta phase for LWR sites, and therefore not stable or fully supported.
 * Given these constraints, an LWC provides the most reliable and flexible solution for querying data
 * from multiple objects and rendering it in a data table for external users.
 * 
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       28th Nov 2025       Ayush Sharma       Initial Version(US - NGOMCT-754)
 */
import { LightningElement, api, wire } from 'lwc';
import getData from '@salesforce/apex/TrainerCCRDataController.getRelatedContactRowsByAccount';
import RELATED_CONTACT_LABEL from "@salesforce/label/c.Related_Contact_Label";
import RELATED_CONTACT_NAME from "@salesforce/label/c.Related_Contact_Name";
import RELATED_CONTACT_EMAIL from "@salesforce/label/c.Related_Contact_Email";
import RELATED_CONTACT_PHONE from "@salesforce/label/c.Related_Contact_Phone";
import RELATED_CONTACT_RELATIONSHIP from "@salesforce/label/c.Related_Contact_Relationship";

// Column definitions for Account Patient table
const COLUMNS = [
    { label: RELATED_CONTACT_NAME, fieldName: 'name', type: 'text' },
    { label: RELATED_CONTACT_EMAIL, fieldName: 'email', type: 'email' },
    { label: RELATED_CONTACT_PHONE, fieldName: 'phone', type: 'phone' },
    { label: RELATED_CONTACT_RELATIONSHIP, fieldName: 'relationship', type: 'text' }
];

export default class PatientDataTableCmp extends LightningElement {
    // Account ID from community detail page
    @api recordId;

    columns = COLUMNS;
    data = [];
    label = {
        RELATED_CONTACT_LABEL
    }

    /**
     * Wires the Related Contact record data, fetching the CCR related contact Name, Email, Phone and Relationship fields.
     * This data is used to display the lightning-datatable.
     */
    @wire(getData, { accountId: '$recordId' })
    wiredData({ error, data }) {
        if (data && data.length > 0) {
            this.data = data;
        } else if (error) {
            this.data = undefined;
        }
    }
}