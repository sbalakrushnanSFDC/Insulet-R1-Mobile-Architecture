/**
 * 
 * Jira Story   : NGOMCT-645 and NGOMCT 646
 * Developer    : Srinivas Shanigarapu
 * Description  : Controller for the Training List View Lightning Web Component (LWC). 
 *                This class handles the retrieval, filtering, sorting, and display of Training__c records, 
 *                adapting column actions based on the user's 'Trainer Type' and the practice's associated status.
 *                It manages state for pagination, search, and error handling, including toast notifications for Apex errors.
 */
import { LightningElement, track, api, wire } from 'lwc';
import LightningToast from 'lightning/toast';
import FORM_FACTOR from '@salesforce/client/formFactor';
import loadConfigs from '@salesforce/apex/TrainingController.loadData'
import getCCTrainings from '@salesforce/apex/TrainingController.getCCTrainings'
import getCPTTrainings from '@salesforce/apex/TrainingController.getCPTTrainings'
import Page_Info from '@salesforce/label/c.Page_Info';
import { log, showToast, getErrorMessage, error } from 'c/utilityComponent';
import Portal_Available_Training_For_Clinics from '@salesforce/label/c.Portal_Available_Training_For_Clinics'
import Portal_Available_Training from '@salesforce/label/c.Portal_Available_Training'
import Portal_Available_Training_No_Records from '@salesforce/label/c.Portal_Available_Training_No_Records'
import Portal_Available_Training_For_Clinics_No_Records from '@salesforce/label/c.Portal_Available_Training_For_Clinics_No_Records'
import Trainer_Type_CC from '@salesforce/label/c.Trainer_Type_CC'
import Trainer_Type_CPT from '@salesforce/label/c.Trainer_Type_CPT'
import Trainer_Type_CPT_CC from '@salesforce/label/c.Trainer_Type_CPT_CC'
import PREVIOUS from '@salesforce/label/c.Previous'
import NEXT from '@salesforce/label/c.Next'
import SEARCH_THIS_LIST from '@salesforce/label/c.Search_this_list'
import Account_Name from '@salesforce/label/c.Account_Name'
import Ship_Date from '@salesforce/label/c.Ship_Date'
import Training_Record_Creation_Date from '@salesforce/label/c.Training_Record_Creation_Date'
import Physician from '@salesforce/label/c.Physician'
import Practice from '@salesforce/label/c.Practice'
import CSM_Name from '@salesforce/label/c.CSM_Name'
import Accept_Training from '@salesforce/label/c.Accept_Training'
import Decline_Training from '@salesforce/label/c.Decline_Training'


const check = ['', null, undefined, ' ']


/**
 * @description Main component class for training list view
 */
export default class TrainingListViewCmp extends LightningElement {
    /**
 * @description Array of all training records retrieved from Apex
 */
    @track trainingRecords = [];
    /**
 * @description Array of training records currently displayed (filtered/paginated)
 */
    @track displayedRecords = [];
    /**
 * @description Error object for displaying error messages
 */
    error;
    /**
 * @description Array of selected training records
 */
    @track selectedRecords = [];
    /**
 * @description Current page number for pagination
 */
    currentPage = 1;
    /**
 * @description Number of records to display per page
 */
    pageSize = 5;
    /**
 * @description Total number of records matching current filter
 */
    totalRecords = 0;
    /**
 * @description Total number of pages based on pageSize and totalRecords
 */
    totalPages = 0;
    /**
 * @description Search term used for filtering records
 */
    searchTerm = '';
    /**
 * @description Field name currently used for sorting
 */
    sortedBy;
    /**
 * @description Training type for filtering
 */
    trainingType;
    /**
 * @description Flag indicating if user is associated with a practice
 */
    isPractice = false;
    /**
 * @description Sorting direction ('asc' or 'desc')
 */
    sortedDirection = 'asc';
    /**
 * @description ID of training record being operated on
 */
    trainingRecordId;
    /**
 * @description Contact ID passed as API parameter
 */
    @api contactId
    /**
 * @description Configuration data loaded from Apex
 */
    @track configs = {}
    /**
 * @description Loading state flags for configuration and data
 */
    @track loading = {
        configLoading: true,
        dataLoading: true
    }
    /**
 * @description Currently selected tab
 */
    currentTab
    label = {
        Page_Info,
        Portal_Available_Training_For_Clinics,
        Portal_Available_Training,
        Portal_Available_Training_No_Records,
        Portal_Available_Training_For_Clinics_No_Records,
        Trainer_Type_CC,
        Trainer_Type_CPT,
        Trainer_Type_CPT_CC,
        PREVIOUS,
        NEXT,
        SEARCH_THIS_LIST
    }

    /**
 * @description Computed property to determine if component is loading
 * @returns {boolean} True if either config or data is loading
 */
    get isLoading() {
        return this.loading.configLoading || this.loading.dataLoading
    }
    /**
 * Getter property to get the Page Info Message.
 * @returns {string} Formatted page info message
     */
    get pageInfoMessage() {
        return Page_Info
            .replace('{currentPage}', this.currentPage)
            .replace('{totalPages}', this.totalPages)
            .replace('{totalRecords}', this.totalRecords);
    }
    /**
     * Getter property to define the data table columns dynamically based on the current user's training type and practice status.
 * @returns {Array} Array of column definitions for the data table
     */
    get isMobile() {
        return FORM_FACTOR === 'Small';
    }

    get columns() {
        const acceptCol = {
            type: 'button',
            label: Accept_Training,
            typeAttributes: {
                label: 'Accept',
                title: 'Accept',
                value: 'accept',
                name: 'accept',
                variant: 'success'
            }
        };

        const showDecline = (this.currentTab === this.label.Portal_Available_Training)
            || (this.currentTab === this.label.Portal_Available_Training_For_Clinics && !this.configs?.isPractice);

        const declineCol = {
            type: 'button',
            label: Decline_Training,
            typeAttributes: {
                label: 'Decline',
                title: 'Decline',
                value: 'decline',
                name: 'decline',
                variant: 'destructive'
            }
        };

        if (this.isMobile) {
            return [
                { label: Account_Name, fieldName: 'accountName', sortable: true },
                { label: Ship_Date, fieldName: 'Ship_Date__c', sortable: true },
                { label: Practice, fieldName: 'practiceName', sortable: true },
                acceptCol,
                ...(showDecline ? [declineCol] : [])
            ];
        }

        return [
            { label: Account_Name, fieldName: 'accountName', sortable: true },
            { label: Ship_Date, fieldName: 'Ship_Date__c', sortable: true },
            { label: Training_Record_Creation_Date, fieldName: 'CreatedDate', sortable: true },
            { label: Physician, fieldName: 'physicianName', sortable: true },
            { label: Practice, fieldName: 'practiceName', sortable: true },
            { label: CSM_Name, fieldName: 'csmName', sortable: true },
            acceptCol,
            ...(showDecline ? [declineCol] : [])
        ];
    }

    /**
 * Updates the search term and refreshes the displayed records based on the new filter.
 * @param {Event} event - Change event from search input
     */
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.updateDisplayedRecords();
    }

    /**
 * Handles click events from buttons within the data table rows (Accept/Decline).
 * @param {Event} event - Row action event from data table
    */
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'accept':
                const modalCmp = this.refs.acceptModal;
                if (modalCmp) {
                    modalCmp.openModal(row.Id);
                }
                break;
            case 'decline':
                const modalCmpDecline = this.refs.declineModal;
                if (modalCmpDecline) {
                    modalCmpDecline.handleDeclineTrainingClickFromParent(row.Id, 'Yes');
                }
                break;
            default:
        }
    }

    /**
 * Handles sorting when a column header is clicked.
 * @param {Event} event - Sort event from data table
     */
    handleSort(event) {
        const fieldName = event.detail.fieldName;
        const sortDirection = event.detail.sortDirection;
        this.sortData(fieldName, sortDirection);
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
    }

    /**
     * Sorts the training records array based on the specified field and direction.
 * @param {string} fieldName - Field name to sort by
 * @param {string} direction - Sort direction ('asc' or 'desc')
     */
    sortData(fieldName, direction) {
        let parseData = JSON.parse(JSON.stringify(this.trainingRecords));
        let isReverse = direction === 'asc' ? 1 : -1;

        parseData.sort((x, y) => {
            let xValue = x[fieldName] === null || x[fieldName] === undefined ? '' : x[fieldName];
            let yValue = y[fieldName] === null || y[fieldName] === undefined ? '' : y[fieldName];
            let xString = typeof xValue === 'string' ? xValue.toLowerCase() : xValue;
            let yString = typeof yValue === 'string' ? yValue.toLowerCase() : yValue;

            return isReverse * ((xString > yString) - (yString > xString));
        });

        this.trainingRecords = parseData;
        this.updateDisplayedRecords();
    }

    /**
 * Filters the training records based on the search term and paginates the results for display.
     */
    updateDisplayedRecords() {
        const filteredRecords = this.trainingRecords.filter(record => {
            const accountName = record.accountName ? record.accountName.toLowerCase() : '';
            const csmName = record.csmName ? record.csmName.toLowerCase() : '';
            const trainingType = record.Training_Type__c ? record.Training_Type__c.toLowerCase() : '';
            return accountName.includes(this.searchTerm.toLowerCase()) ||
                trainingType.includes(this.searchTerm.toLowerCase()) ||
                csmName.includes(this.searchTerm.toLowerCase());
        });

        this.totalRecords = filteredRecords.length;
        this.totalPages = Math.ceil(this.totalRecords / this.pageSize);
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.displayedRecords = filteredRecords.slice(start, end);
        this.loading.dataLoading = false
    }

    /**
     * Decrements the current page and updates the displayed records.
     */
    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateDisplayedRecords();
        }
    }

    /**
 * Increments the current page and updates the displayed records.
     */
    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateDisplayedRecords();
        }
    }

    /**
     * Getter to determine if the 'Previous' pagination button should be disabled.
 * @returns {boolean} True if on first page
     */
    get isPreviousDisabled() {
        return this.currentPage === 1;
    }

    /**
     * Getter to determine if the 'Next' pagination button should be disabled.
 * @returns {boolean} True if on last page
     */
    get isNextDisabled() {
        return this.currentPage === this.totalPages;
    }

    /**
     * Forces a refresh of the training records data.
     */
    refreshData() {
        this.loadTrainingRecords();
    }

    /**
     * Event handler that is executed when the child modal component dispatches a 'refresh' custom event, 
     * typically after the modal is closed. This method resets the modal's state and triggers 
     * a data refresh in the parent component to reflect any changes made.
     */
    handleRefresh() {
        //this.refreshData();
        this.loadTrainings()
    }

    /**
 * Displays a Lightning Toast notification.
 * @param {string} title - Toast title
 * @param {string} message - Toast message
 * @param {string} variant - Toast variant ('success', 'error', 'warning', 'info')
     */
    showToast(title, message, variant) {
        LightningToast.show({
            label: title,
            message: message,
            variant: variant
        });
    }

    /**
 * Getter to determine if training records for CC should be shown
 * @returns {boolean} True if trainer type is CC or CPT_CC
 */
    get showTrainingsForCC() {
        return this.configs.trainerType == this.label.Trainer_Type_CC || this.configs.trainerType == this.label.Trainer_Type_CPT_CC
    }

    /**
 * Getter to determine if training records for CPT should be shown
 * @returns {boolean} True if trainer type is CPT or CPT_CC
 */
    get showTrainingsForCPT() {
        return this.configs.trainerType == this.label.Trainer_Type_CPT || this.configs.trainerType == this.label.Trainer_Type_CPT_CC
    }

    /**
 * Handles tab change events
 * @param {Event} event - Tab change event
 */
    handleTabChange(event) {
        this.currentTab = event.target.value
        this.loadTrainings()
    }

    /**
 * Loads training records based on current tab selection
 */
    loadTrainings() {
        if (this.currentTab === this.label.Portal_Available_Training && !check.includes(this.configs.trainerId)) {
            getCPTTrainings({ trainerId: this.configs.trainerId }).then(data => this.formatData(data, true))
        }
        else if (this.currentTab === this.label.Portal_Available_Training_For_Clinics && !check.includes(this.configs.practiceId)) {
            getCCTrainings({ practiceId: this.configs.practiceId }).then(data => this.formatData(data, false))
        }
        else {
            log('No trainer or practice ID found')
        }
    }

    /**
 * Wire adapter to load configuration data
 * @param {Object} data - Loaded data from Apex
 * @param {Object} err - Error object if any
 */
    @wire(loadConfigs, { contactId: '$contactId' })
    loadData({ err, data }) {
        if (data) {
            log(`Logging from wire, ${JSON.stringify(data)}`)
            this.configs = data
            this.loading.configLoading = false
            this.loading.dataLoading = false
        }
        else if (err) {
            error(err)
        }
    }

    /**
 * Formats training data for display
 * @param {Array} data - Raw training data from Apex
 */
    formatData(data) {
        
        this.trainingRecords = data.map(record => ({
            ...record,
            accountName: record.Account__r ? record.Account__r.Name : '',
            csmName: record.CSM__r ? `${record.CSM__r.FirstName || ''} ${record.CSM__r.LastName || ''}` : '',
            physicianName: record?.Physician__r?.Name || '',
            practiceName: record?.Practice__r?.Name || '',
        }));

        if (this.sortedBy) {
            this.sortData(this.sortedBy, this.sortedDirection);
        }

        this.totalRecords = this.trainingRecords.length;
        this.totalPages = Math.ceil(this.totalRecords / this.pageSize);
        this.currentPage = 1;
        this.updateDisplayedRecords();
        this.error = undefined;
    }
}