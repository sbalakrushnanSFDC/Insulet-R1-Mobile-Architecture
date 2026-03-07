import { LightningElement, api } from 'lwc';

/**
 * Jira Story   : NGOMCT-475
 * Developer    : Yogesh Rana
 * Date         : 2026-01-08
 * Description  : The FileUploadCmp component is used to upload files to a Salesforce record.
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       08th Jan 2026       Yogesh Rana             Initial (NGOMCT-475)
 */
export default class FileUploadCmp extends LightningElement {
    @api showFileUpload = false;
    @api recordId;
    @api label; 
    @api acceptedFormats = ".pdf,.png,.jpg,.jpeg,.doc,.docx,.xlsx,.xls,.csv,.txt,.ppt,.pptx";
    @api multiple = false;
    @api disabled = false;
    @api required = false;
    
    // Convert the accepted formats string to an array of strings
    get acceptedFormatsArray() {
        return this.acceptedFormats?.split(',')?.map(f => f.trim()) || [];
    }

    // If label is empty, add the file-upload-cmp class to the component
    get fileUploadClass() {
        return this.label ? '' : 'file-upload-cmp';
    }

    /**
     * Handles the successful upload of files by the lightning-file-upload component.
     * @param {Event} event - The uploadfinished event.
     */
    handleUploadFinished(event) {
        // Dispatch a custom event to the parent component to refresh the files list.
        this.dispatchEvent(new CustomEvent('filesuploaded'));
    }
}