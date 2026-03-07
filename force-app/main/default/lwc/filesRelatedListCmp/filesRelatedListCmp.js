/**
 * Jira Story   : NGOMCT-724
 * Developer    : Srinivas Shanigarapu
 * Date         : 2025-11-28
 * Description  : The FilesRelatedList component retrieves, formats, and displays all files
 * associated with a given Salesforce record. It uses an Apex controller to load
 * ContentVersion data, decorates the results with additional UI-friendly fields
 * (icons, formatted sizes, formatted dates), and renders them in a sortable
 * datatable-style layout.
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       28th Nov 2025       Srinivas                Initial (NGOMCT-724)
 */
import { LightningElement, api, wire, track } from 'lwc';
import LightningToast from 'lightning/toast';
import getFilesForRecord from '@salesforce/apex/FilesRelatedListController.getFilesForRecord';
import { refreshApex } from '@salesforce/apex';
import Files_Title from '@salesforce/label/c.Files_Title';
import Files_Owner from '@salesforce/label/c.Files_Owner';
import Files_LastModified from '@salesforce/label/c.Files_LastModified';
import Files_Size from '@salesforce/label/c.Files_Size';
import Files_Actions from '@salesforce/label/c.Files_Actions';
import File_Download from '@salesforce/label/c.File_Download';
import No_Files from '@salesforce/label/c.No_Files';
import Total_Items from '@salesforce/label/c.Total_Items';
import Files from '@salesforce/label/c.Files';
import Refresh from '@salesforce/label/c.Refresh';
import Loading from '@salesforce/label/c.Loading';
import Sort_By from '@salesforce/label/c.Sort_By';
import No_Files_Message from '@salesforce/label/c.No_Files_Message';
import Error_Message from '@salesforce/label/c.Error_Message'
import Files_Refresh_Message from '@salesforce/label/c.Files_Refresh_Message'
import basePath from "@salesforce/community/basePath";
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import STATUS_FIELD from '@salesforce/schema/Reimbursement__c.Status__c';



const DEFAULT_SORT = 'modifiedDesc';
const IMAGE_EXTENSIONS = ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'svg', 'webp'];
const EXCEL_EXTENSIONS = ['xls', 'xlsx', 'xlsm', 'csv'];
const PPT_EXTENSIONS = ['ppt', 'pptx'];
const WORD_EXTENSIONS = ['doc', 'docx', 'rtf', 'txt', 'md'];
const ZIP_EXTENSIONS = ['zip', 'rar', '7z', 'gz', 'tar'];
const REIMBURSEMENT_OBJECT_API = 'Reimbursement__c';
const REIMBURSEMENT_HIDDEN_STATUSES = ['Approved', 'Paid', 'Submitted'];

export default class FilesRelatedListCmp extends LightningElement {

  @api recordId;
  @api objectApiName;
  @track files = [];
  error;
  sortBy = DEFAULT_SORT;
  isLoading = false;
  wiredFilesResult;
  toshow = false;
  recordFields;
  labels = {
        title: Files_Title,
        owner: Files_Owner,
        lastModified: Files_LastModified,
        size: Files_Size,
        actions: Files_Actions,
        download: File_Download,
        noFiles: No_Files,
        noFilesMessage: No_Files_Message,
        totalItems: Total_Items,
        files: Files,
        refresh : Refresh,
        loading: Loading,
        sortBy: Sort_By
    };

  /**
   * Returns sorting options for the combobox.
   */
  get sortOptions() {
    return [
      { label: 'Last Modified (new → old)', value: 'modifiedDesc' },
      { label: 'Last Modified (old → new)', value: 'modifiedAsc' },
      { label: 'Title (A → Z)', value: 'titleAsc' },
      { label: 'Title (Z → A)', value: 'titleDesc' },
      { label: 'Size (large → small)', value: 'sizeDesc' },
      { label: 'Size (small → large)', value: 'sizeAsc' }
    ];
  }

  /**
   * Indicates whether the record has files.
   */
  get hasFiles() {
    return this.files && this.files.length > 0;
  }

  /**
   * Indicates UI state when loading is complete.
   */
  get notLoading() {
    return !this.isLoading;
  }

  /**
   * Indicates that no files exist.
   */
  get noFiles() {
    return !this.hasFiles;
  }
connectedCallback() {
  if(this.objectApiName === REIMBURSEMENT_OBJECT_API){
    this.recordFields = [STATUS_FIELD];
    this.toshow = false;
  } else {
    this.toshow = true;
  }
}
/**
   * Wire adapter to get Reimburement Status for the given record.
   */
@wire(getRecord, { recordId: '$recordId', fields: '$recordFields' })
  handleReimbursementStatus({ data, error }) {
    
    if (data) {
      const status = getFieldValue(data, STATUS_FIELD);
      this.toshow = !REIMBURSEMENT_HIDDEN_STATUSES.includes(status);
    } else if (error) {
      this.toshow = true;
    }
  }
  /**
   * Wire adapter to load files for the given record.
   * Decorates data, sorts it, and handles error state.
   */
  @wire(getFilesForRecord, { recordId: '$recordId' })
  wiredFiles(result) {
    this.wiredFilesResult = result;
    const { data, error } = result;
    this.isLoading = true;

    if (data) {
      if (!data) {
        this.files = [];
        this.isLoading = false;
        return;
      }
      const decoratedFiles = data.map((file) => this.decorateFile(file));
      this.files = this.sortList(decoratedFiles, this.sortBy);
    } else if (error) {
      this.files = [];
      this.error = this.normalizeError(error);
      this.showToast('Error loading files', this.error, 'error');
    }
    this.isLoading = false;
  }

  /**
   * Enhances each file record with derived display properties.
   */
  decorateFile(file) {
    return {
      ...file,
      titleSafe: file.title || '(untitled)',
      sizeLabel: this.formatSize(file.contentSize),
      modifiedLabel: this.formatDateTime(file.lastModifiedDate),
      fileDownloadUrl: (typeof window !== 'undefined' ? window.location.origin : '') + basePath + file.downloadUrl,
      iconName: this.iconFor(file.fileExtension, file.fileType)
    };
  }

  /**
   * Handles user selection of sorting criteria.
   */
  handleSortChange(event) {
    this.sortBy = event.detail.value;
    this.files = this.sortList([...this.files], this.sortBy);
  }

  /**
   * Refreshes files list by calling refreshApex.
   */
  handleRefresh() {
    if (!this.wiredFilesResult) {
      return;
    }

    this.isLoading = true;
    this.error = undefined;

    refreshApex(this.wiredFilesResult)
      .then(() => {
        this.showToast('Success',Files_Refresh_Message, 'success');
      })
      .catch((err) => {
        this.error = this.normalizeError(err);
        this.showToast('Error refreshing files', this.error, 'error');
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  /**
   * Sorts the provided file list based on the selected sort option.
   */
  sortList(list, sortBy) {
    const cloned = [...list];
    const compare = (sortField, sortDirection = 'asc') => {
      return (recordA, recordB) => {
        const fieldValueA = recordA[sortField] ?? '';
        const fieldValueB = recordB[sortField] ?? '';
        let comparisonResult = 0;

        if (typeof fieldValueA === 'number' && typeof fieldValueB === 'number') {
          comparisonResult = fieldValueA - fieldValueB;
        }
        else if (fieldValueA > fieldValueB) {
          comparisonResult = 1;
        } else if (fieldValueA < fieldValueB) {
          comparisonResult = -1;
        }

        return sortDirection === 'asc'
          ? comparisonResult
          : -comparisonResult;
      };
    };

    switch (sortBy) {
      case 'modifiedAsc':
        return cloned.sort(compare('lastModifiedDate', 'asc'));
      case 'titleAsc':
        return cloned.sort(compare('titleSafe', 'asc'));
      case 'titleDesc':
        return cloned.sort(compare('titleSafe', 'desc'));
      case 'sizeAsc':
        return cloned.sort(compare('contentSize', 'asc'));
      case 'sizeDesc':
        return cloned.sort(compare('contentSize', 'desc'));
      case 'modifiedDesc':
      default:
        return cloned.sort(compare('lastModifiedDate', 'desc'));
    }
  }

  /**
   * Determines an icon name based on file extension/type.
   */
  iconFor(ext, type) {
    const extension = (ext || '').toLowerCase();
    const fileType = (type || '').toLowerCase();

    if (IMAGE_EXTENSIONS.includes(extension)) {
      return 'doctype:image';
    }
    if (extension === 'pdf' || fileType === 'pdf') {
      return 'doctype:pdf';
    }
    if (EXCEL_EXTENSIONS.includes(extension)) {
      return 'doctype:excel';
    }
    if (PPT_EXTENSIONS.includes(extension)) {
      return 'doctype:ppt';
    }
    if (WORD_EXTENSIONS.includes(extension)) {
      return 'doctype:word';
    }
    if (ZIP_EXTENSIONS.includes(extension)) {
      return 'doctype:zip';
    }
    return 'doctype:unknown';
  }

  /**
   * Converts bytes into human-readable size format.
   */
  formatSize(bytes) {
    if (bytes === null || bytes === undefined) {
      return '';
    }
    if (bytes < 1024) {
      return `${bytes} B`;
    }

    const units = ['KB', 'MB', 'GB', 'TB'];
    let value = bytes / 1024;
    let index = 0;

    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index += 1;
    }

    return `${value.toFixed(1)} ${units[index]}`;
  }

  /**
   * Converts a datetime string into local display format.
   */
  formatDateTime(dateTimeValue) {
    if (!dateTimeValue) {
      return '';
    }
    try {
      return new Date(dateTimeValue).toLocaleString();
    } catch (error) {
      return dateTimeValue;
    }
  }

  /**
   * Normalizes Apex and JS errors into readable text.
   */
  normalizeError(error) {
    if (!error) {
      return Error_Message;
    }
    if (Array.isArray(error.body)) {
      return error.body.map((e) => e.message).join(', ');
    }
    if (error.body && typeof error.body.message === 'string') {
      return error.body.message;
    }

    return typeof error === 'string' ? error : JSON.stringify(error);
  }

  /**
   * Displays a Lightning Toast notification.
   */
  showToast(title, message, variant = 'info') {
    LightningToast.show({
      label: title,
      message: message,
      variant: variant,
      mode: 'dismissible'
    });
  }

  // Handles the event from the file-upload-cmp component when files are uploaded to refresh the files list.
  handleFilesUploaded() {
    this.handleRefresh();
  }
}