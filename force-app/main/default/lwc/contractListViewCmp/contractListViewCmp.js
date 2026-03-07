/**
 * ContractListViewCmp
 * 
 * Lightning Web Component that displays a paginated, sortable list of Contract records
 * for the logged-in user's context. Supports two tabs:
 * - "My Contracts" (CPT/Trainer contracts)
 * - "My Clinic Contracts" (CC/Practice contracts)
 * 
 * @author: Shashank Nigam
 * Date: 8/1/2026
 * Version      Modified Date       Modified By             Brief Note
 * v1.0.0       8th JAN 2026        Shashank Nigam          Initial (NGOMCT-1353)
 */

import { api, LightningElement, wire, track } from 'lwc';
import { log, startVersionDownload } from 'c/utilityComponent';
import ToastContainer from 'lightning/toastContainer';
import FORM_FACTOR from '@salesforce/client/formFactor';

// Imports for Custom Label
import Trainer_Type_CC from '@salesforce/label/c.Trainer_Type_CC'
import Trainer_Type_CPT from '@salesforce/label/c.Trainer_Type_CPT'
import Trainer_Type_CPT_CC from '@salesforce/label/c.Trainer_Type_CPT_CC'
import MyContracts from '@salesforce/label/c.My_Contracts'
import MyClinicContracts from '@salesforce/label/c.My_Clinic_Contracts'
import NoActiveContracts from '@salesforce/label/c.My_Contracts_Not_Found'
import NoActiveClinicContracts from '@salesforce/label/c.Clinic_Contracts_Not_Found'
import Contract_Status from '@salesforce/label/c.Contract_Status'
import Contract_Start_Date from '@salesforce/label/c.Contract_Start_Date'
import Contract_End_Date from '@salesforce/label/c.Contract_End_Date'
import Contract_Type from '@salesforce/label/c.Contract_Type'
import Company_Signed_Date from '@salesforce/label/c.Company_Signed_Date'
import Customer_Signed_Date from '@salesforce/label/c.Customer_Signed_Date'
import Contract_Name from '@salesforce/label/c.Contract_Name'
import Clinic_Name from '@salesforce/label/c.Clinic_Name'

// Imports for Apex Callouts
import loadData from '@salesforce/apex/ContractListViewController.loadData'
import getCCContracts from '@salesforce/apex/ContractListViewController.getCCContracts'
import getCPTContracts from '@salesforce/apex/ContractListViewController.getCPTContracts'

/**
 * Utility sentinel values considered "empty" for tab-based branching.
 * @type {Array<any>}
 */
const check = ['', null, undefined, ' ']

/**
 * Component controller for Contract list view.
 */
export default class ContractListViewCmp extends LightningElement {
    /**
     * Logged-in user's Contact Id provided by the hosting Experience site.
     * Used to derive trainer/practice configuration and permissions.
     * @type {string}
     */
    @api contactId // To get Logged In User's ContactId directly from Experience Site
    /** Full dataset returned from server after formatting. */
    @track contractRecords = [];
    /** Records currently visible after filtering, sorting, and paging. */
    @track displayedRecords = [];
    /** Reserved for future multi-select actions. Not currently used. */
    @track selectedRecords = [];
    /** One-based page index. */
    currentPage = 1;
    /** Page size for pagination. Consider externalizing to design config. */
    @api pageSize;
    /** Count of records after filtering. */
    totalRecords = 0;
    /** Number of pages after filtering. */
    totalPages = 0;
    /** Current free-text search term (case-insensitive). */
    searchTerm = '';
    /** Last sorted field name. */
    sortedBy;
    /** Future use: identifies training type context. */
    trainingType;
    /** Sort direction for last sort. */
    sortedDirection = 'asc';
    /** Future use: currently unused row identifier. */
    trainingRecordId
    /** User/trainer/practice config loaded from server. */
    @track configs = {}
    /** Reserved for future download link composition. */
    downloadHref = ''
    /** Flag to avoid loading contracts before first tab selection. */
    dataLoaded = false
    /** Current selected tab label. */
    currentTab
    /** Track loading behaviour and show Spinner accordingly */
    @track loading = {
        configLoading: true,
        dataLoading: true,
    }

    /**
     * Exposed Custom Labels bundled for easy reference in template and code.
     */
    label = {
        Trainer_Type_CC,
        Trainer_Type_CPT,
        Trainer_Type_CPT_CC,
        MyContracts,
        MyClinicContracts,
        NoActiveContracts,
        NoActiveClinicContracts,
        Contract_Status,
        Contract_Start_Date,
        Contract_End_Date,
        Contract_Type,
        Company_Signed_Date,
        Customer_Signed_Date,
        Contract_Name,
        Clinic_Name
    }

    connectedCallback() {
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = 'top-center';
    }

    /**
     * Data table column definitions, responsive to the active tab label.
     * @returns {import('lightning/datatable').Column[]}
     */
    get isMobile() {
        return FORM_FACTOR === 'Small';
    }

    get columns() {
        const nameCol = this.currentTab === this.label.MyContracts
            ? { label: this.label.Contract_Name, fieldName: 'accountName', sortable: true }
            : { label: this.label.Clinic_Name, fieldName: 'accountName', sortable: true };

        const actionCol = {
            type: 'button',
            label: 'Action',
            fieldName: 'contractURL',
            sortable: false,
            typeAttributes: {
                label: 'Download',
                title: 'Download',
                value: 'Download',
                name: 'Download',
                variant: 'success',
            }
        };

        if (this.isMobile) {
            return [
                nameCol,
                { label: this.label.Contract_Status, fieldName: 'status', sortable: true },
                { label: this.label.Contract_End_Date, fieldName: 'endDate', sortable: true },
                actionCol
            ];
        }

        return [
            {
                label: '',
                fixedWidth: 36,
                hideDefaultActions: true,
                cellAttributes: {
                    iconName: { fieldName: 'statusIcon' },
                    alignment: 'center',
                    class: { fieldName: 'statusClass' }
                }
            },
            nameCol,
            { label: this.label.Contract_Status, fieldName: 'status', sortable: true },
            { label: this.label.Contract_Start_Date, fieldName: 'startDate', sortable: true },
            { label: this.label.Contract_End_Date, fieldName: 'endDate', sortable: true },
            { label: this.label.Contract_Type, fieldName: 'type', sortable: true },
            { label: this.label.Company_Signed_Date, fieldName: 'companySignedDate', sortable: true },
            { label: this.label.Customer_Signed_Date, fieldName: 'customerSignedDate', sortable: true },
            actionCol
        ];
    }

    /**
     * Getter to determine if contract records for CC should be shown
     * @returns {boolean} True if trainer type is CC or CPT_CC
     */
    get showContractsForCC() {
        return this.configs.trainerType == this.label.Trainer_Type_CC || this.configs.trainerType == this.label.Trainer_Type_CPT_CC
    }

    /**
     * Whether CPT contracts should be shown for current user configuration.
     * @returns {boolean}
     */
    get showContractsForCPT() {
        return this.configs.trainerType == this.label.Trainer_Type_CPT || this.configs.trainerType == this.label.Trainer_Type_CPT_CC
    }

    /**
     * Loads user configuration and seed contracts on component init.
     * @wire Apex ContractListViewController.loadData
     * @param {{ err: any, data: any }} param0
     */
    @wire(loadData, { contactId: '$contactId' })
    LoadUserDetails({ err, data }) {
        if (data) {
            this.configs = data
            this.loading.configLoading = false
            this.loading.dataLoading = false
            this.formatData(data?.contracts)
        }
        else {
            log(err)
        }
    }

    /**
     * Normalize incoming contract data and initialize paging/sort state.
     * @param {Array<Record<string, any>>} data
     */
    formatData(data) {

        this.contractRecords = data

        if (this.sortedBy) {
            this.sortData(this.sortedBy, this.sortedDirection);
        }

        this.totalRecords = this.contractRecords.length;
        this.totalPages = Math.ceil(this.totalRecords / this.pageSize);
        this.currentPage = 1;
        this.updateDisplayedRecords();
        this.error = undefined;
    }

    /**
    * Loads contract records based on current tab selection
    */
    /**
    * Loads contract records based on current tab selection and user config.
    * - "My Contracts": uses trainerId -> getCPTContracts
    * - "My Clinic Contracts": uses practiceAccountIds -> getCCContracts
    */
    loadContracts() {
        if (this.currentTab === this.label.MyContracts && !check.includes(this.configs.trainerId)) {
            this.loading.dataLoading = true
            getCPTContracts({ trainerId: this.configs.trainerId }).then(data => this.formatData(data, true)).catch(err => { log(err) })
        }
        else if (this.currentTab === this.label.MyClinicContracts && !check.includes(this.configs.practiceAccountIds)) {
            this.loading.dataLoading = true
            getCCContracts({ practiceIds: this.configs.practiceAccountIds }).then(data => this.formatData(data, false)).catch(err => { log(err) })
        }
        else {
            this.formatData([])
        }
    }

    /**
    * Handles tab change events
    * @param {Event} event - Tab change event
    */
    handleTabChange(event) {
        this.currentTab = event.target.value
        if (this.dataLoaded) // Ensuring there is 
            this.loadContracts()
        else
            this.dataLoaded = true
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
    * Decrements the current page and updates the displayed records.
    */
    /**
    * Navigate to previous page when available.
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
    /**
    * Navigate to next page when available.
    */
    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateDisplayedRecords();
        }
    }

    /**
    * Filters the training records based on the search term and paginates the results for display.
    */
    /**
    * Filters the training records based on the search term and paginates the results for display.
    * Note: Only string values are considered for case-insensitive search.
    */
    updateDisplayedRecords() {
        const filteredRecords = this.contractRecords.filter(record => {
            //const accountName = record.accountName ? record.accountName.toLowerCase() : '';
            const { contractURL, contractId, statusIcon, statusClass, ...r } = record
            const values = Object.values(r)
            return values.some(v => v !== null && v !== undefined && v.toLowerCase().includes(this.searchTerm.toLowerCase()))
            //return accountName.includes(this.searchTerm.toLowerCase())
        });

        this.totalRecords = filteredRecords.length;
        this.totalPages = Math.ceil(this.totalRecords / this.pageSize);
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.displayedRecords = filteredRecords.slice(start, end);
        this.loading.dataLoading = false
    }

    /**
    * Sorts the training records array based on the specified field and direction.
    * @param {string} fieldName - Field name to sort by
    * @param {string} direction - Sort direction ('asc' or 'desc')
    */
    sortData(fieldName, direction) {
        let parseData = JSON.parse(JSON.stringify(this.contractRecords));
        let isReverse = direction === 'asc' ? 1 : -1;

        parseData.sort((x, y) => {
            let xValue = x[fieldName] === null || x[fieldName] === undefined ? '' : x[fieldName];
            let yValue = y[fieldName] === null || y[fieldName] === undefined ? '' : y[fieldName];
            let xString = typeof xValue === 'string' ? xValue.toLowerCase() : xValue;
            let yString = typeof yValue === 'string' ? yValue.toLowerCase() : yValue;

            return isReverse * ((xString > yString) - (yString > xString));
        });

        this.contractRecords = parseData;
        this.updateDisplayedRecords();
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
    * Updates the search term and refreshes the displayed records based on the new filter.
    * @param {Event} event - Change event from search input
    */
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.updateDisplayedRecords();
    }

    /**
     * Handles row-level action clicks from the data table.
     * Currently supports "download" action which initiates a Version download.
     * @param {CustomEvent} e event.detail.row should contain 'contractURL' relative shepherd path
     */
    handleRowAction(e) {
        const row = e.detail.row;
        log('Row Clicked ' + JSON.stringify(row));
        startVersionDownload(row.contractURL);
    }
}