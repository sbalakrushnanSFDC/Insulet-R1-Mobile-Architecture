/**
 * ReusableDatatable
 * 
 * A reusable Lightning Web Component that wraps lightning-datatable with
 * built-in search, pagination, and sorting capabilities. Fully client-side
 * with no Apex dependencies - just pass data and columns.
 * 
 * @author      Shashank Nigam
 * @created     28th January 2026
 * @description Reusable datatable with search, pagination, and sorting
 * 
 * @example
 * <c-reusable-datatable
 *     title="My Records"
 *     columns={columns}
 *     records={records}
 *     key-field="Id"
 *     page-size="10"
 *     enable-search
 *     onrowselection={handleSelection}>
 * </c-reusable-datatable>
 */

import { log } from 'c/utilityComponent';
import { LightningElement, api, track } from 'lwc';
import PREVIOUS from '@salesforce/label/c.Previous'
import NEXT from '@salesforce/label/c.Next'
import SEARCH_THIS_LIST from '@salesforce/label/c.Search_this_list'
import LOADING from '@salesforce/label/c.Loading'
export default class ReusableDatatable extends LightningElement {
    @api multiSelect = false
    @api showRowNumber = false
    @api hideCheckboxColumn = false
    @api maxRecords = 5
    @api enableSearch = false
    @api columns = []
    _records = [];
    @api get records() {
        return this._records;
    }
    set records(value) {
        this._records = value;
        setTimeout(() => this.updateDisplayedRecords(), 100);
    }
    @api keyField = 'Id'
    @api errorMessage = {}
    @api loading
    @api title = ''
    @api iconName = ''

    // Internal state variables
    @track displayedRecords = [];
    totalRecords = 0;
    totalPages = 1;
    currentPage = 1;
    searchTerm = '';
    sortedBy = '';
    sortedDirection = 'asc';
    selectedRows = [];

    label = {
        PREVIOUS,
        NEXT,
        SEARCH_THIS_LIST,
        LOADING
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
        let parseData = JSON.parse(JSON.stringify(this.records));
        let isReverse = direction === 'asc' ? 1 : -1;

        parseData.sort((x, y) => {
            let xValue = x[fieldName] === null || x[fieldName] === undefined ? '' : x[fieldName];
            let yValue = y[fieldName] === null || y[fieldName] === undefined ? '' : y[fieldName];
            let xString = typeof xValue === 'string' ? xValue.toLowerCase() : xValue;
            let yString = typeof yValue === 'string' ? yValue.toLowerCase() : yValue;

            return isReverse * ((xString > yString) - (yString > xString));
        });

        this.records = parseData;
        this.updateDisplayedRecords();
    }

    /**
 * Filters the training records based on the search term and paginates the results for display.
 */
    updateDisplayedRecords() {
        if (!this.records || this.records.length == 0) {
            this.displayedRecords = [];
            this.loading = false; return;
        }
        const filteredRecords = this.records.filter(record => {
            const { Id, ...r } = record
            const values = Object.values(r)
            return values.some(v => v !== null && v !== undefined && typeof v === 'string' && v.toLowerCase().includes(this.searchTerm.toLowerCase()))
        });

        this.totalRecords = filteredRecords.length;
        this.totalPages = Math.ceil(this.totalRecords / this.maxRecords);
        const start = (this.currentPage - 1) * this.maxRecords;
        const end = start + this.maxRecords;
        this.displayedRecords = filteredRecords.slice(start, end);
        this.loading = false
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
 * Handles row selection events
 * @param {Event} event - Row selection event
 */
    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        log('selectedRows: ' + JSON.stringify(selectedRows));
        if (this.multiSelect) {
            this.selectedRows = selectedRows.map(row => row.Id);
            log('inside multi select' + this.multiSelect);
        } else {
            this.selectedRows = [selectedRows[selectedRows?.length - 1]?.Id];
            log('inside single select');
        }
        this.dispatchEvent(new CustomEvent('rowselection', {
            detail: { selectedRowId: this.selectedRows }
        }));
    }

    /**
 * Handles row action events
 * @param {Event} event - Row action event
 */
    handleRowAction(event) {
        const action = event.detail.action;
        this.dispatchEvent(new CustomEvent('rowaction', {
            detail: { action }
        }));
    }
}