/**
 * Utility component for common helper functions used across training components
 * @author Shashank Nigam
 * @Jira: NGOMCT-1049
 */
import LightningToast from 'lightning/toast';
import writeOnConsole from '@salesforce/label/c.Write_On_Console'
import Error_Message from '@salesforce/label/c.Error_Message'
import basePath from '@salesforce/community/basePath';
import downloadURL from '@salesforce/label/c.File_Download_URL'
import { ShowToastEvent } from 'lightning/platformShowToastEvent'


const isExperienceUser = true

/**
 * Displays a Lightning Toast notification with the specified title, message, and variant
 * @param {string} title - The title of the toast notification
 * @param {string} message - The message content of the toast notification
 * @param {string} variant - The variant of the toast ('success', 'error', 'warning', 'info')
 */
export function showToast(title, message, variant, mode) {
    log('Toast is called for message: ' + message)
    if (isExperienceUser) {
        LightningToast.show({
            label: title,
            message: message,
            variant: variant,
            mode: mode
        })
    }
    else {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: mode
        }))
    }
}

export function showCustomToast(label) {
    showToast(...label.split(';'))
}

/**
 * Displays an error toast notification with a predefined error message
 */
export function showErrorToast() {
    showToast('Error', Error_Message, 'error')
}

/**
 * Logs a message to the console if writeOnConsole is set to 'TRUE'
 * @param {string} msg - The message to log to the console
 */
export function log(msg) {
    writeOnConsole === 'TRUE' && console.log(msg)
}

/**
 * Logs an error message to the console if writeOnConsole is set to 'TRUE'
 * @param {string} msg - The error message to log to the console
 */
export function error(msg) {
    writeOnConsole === 'TRUE' && console.error(msg)
}

/**
 * Logs a warning message to the console if writeOnConsole is set to 'TRUE'
 * @param {string} msg - The warning message to log to the console
 */
export function warn(msg) {
    writeOnConsole === 'TRUE' && console.warn(msg)
}

/**
 * Extracts and returns an error message from an error object or string
 * @param {object|string} error - The error object or string to extract message from
 * @returns {string} The extracted error message or a default message
 */
export function getErrorMessage(error) {
    if (error.body && error.body.message) {
        return error.body.message;
    }
    if (typeof error === 'string') {
        return error;
    }
    return 'Unknown error occurred.';
}

/**
 * Normalizes Salesforce locale format (en_US) to browser locale format (en-US)
 * @param {string} userLocale - Salesforce locale string (e.g., "en_US", "fr_FR")
 * @returns {string} Normalized locale string (e.g., "en-US", "fr-FR") or "en-US" as default
 */
export function normalizeLocale(userLocale) {
    return userLocale ? userLocale.replace('_', '-') : 'en-US';
}

/**
 * Formats DATE field values according to user's locale
 * @param {string|Date} value - Date value to format (ISO string or Date object)
 * @param {string} userLocale - User's locale (e.g., "en-US", "fr-FR")
 * @returns {string} Formatted date string (e.g., "12/23/2025") or empty string if invalid
 */
export function formatDate(value, userLocale) {
    if (!value || value === '') {
        return '';
    }

    const date = new Date(value);
    
    // Validate date is valid
    if (isNaN(date.getTime())) {
        return String(value);
    }

    try {
        return date.toLocaleDateString(normalizeLocale(userLocale), {
            year: 'numeric',
            month: 'numeric',
            day: 'numeric'
        });
    } catch (error) {
        return `Invalid date value: ${value} - Error: ${error.message}`;
    }
}

/**
 * Formats DATETIME field values according to user's locale and timezone
 * Converts UTC datetime to user's timezone and formats with AM/PM
 * @param {string|Date} value - DateTime value to format (ISO string or Date object)
 * @param {string} userLocale - User's locale (e.g., "en-US", "fr-FR")
 * @param {string} userTimeZone - User's timezone (e.g., "America/New_York")
 * @returns {string} Formatted datetime string (e.g., "12/23/2025, 5:30 PM") or empty string if invalid
 */
export function formatDateTime(value, userLocale, userTimeZone) {
    if (!value || value === '') {
        return '';
    }

    const date = new Date(value);
    
    // Validate date is valid
    if (isNaN(date.getTime())) {
        return String(value);
    }

    try {
        return date.toLocaleString(normalizeLocale(userLocale), {
            year: 'numeric',
            month: 'numeric',
            day: 'numeric',
            hour: 'numeric',
            minute: 'numeric',
            hour12: true,
            timeZone: userTimeZone ? userTimeZone : 'UTC'
        });
    } catch (error) {
        return `Invalid datetime value: ${value} - Error: ${error.message}`;
    }
}

export function getVersionDownloadBaseUrl() {
    const origin = typeof window !== 'undefined' ? window.location.origin : '';
    return origin + basePath + downloadURL;
}

/**
 * Download a file from Salesforce using published ContentDocumentVersionId.
 * This methods removes exact link from UI and formulates on the go.
 * @param {String} versionId 
 * @returns 
 */
export function startVersionDownload(versionId, target = '_self', toast = true) {
    if (!versionId || versionId === '') {
        toast && showToast('Error', 'No file available to download', 'error');
        return;
    }
    try {
        const url = getVersionDownloadBaseUrl() + versionId;
        const anchor = document.createElement('a');
        anchor.href = url;
        anchor.target = target;
        anchor.click();
        toast && showToast('Success', 'File download started.', 'success');
    }
    catch (ex) {
        error('Download failed: ' + getErrorMessage(ex));
        toast && showToast('Error', 'Unable to start file download.', 'error');
    }
}

/**
 * Download a file from Salesforce using published ContentDocumentId.
 * This methods removes exact link from UI and formulates on the go.
 * @param {String} documentId
 * @returns 
 */
export function startDocumentDownload(documentId, target = '_self') {
    if (!documentId || documentId === '') {
        showToast('Error', 'No file available to download', 'error');
        return;
    }
    try {
        const url = getVersionDownloadBaseUrl().replace('version', 'document') + documentId;
        const anchor = document.createElement('a');
        anchor.href = url;
        anchor.target = target;
        anchor.click();
        showToast('Success', 'File download started.', 'success');
    }
    catch (ex) {
        error('Download failed: ' + getErrorMessage(ex));
        showToast('Error', 'Unable to start file download.', 'error');
    }
}