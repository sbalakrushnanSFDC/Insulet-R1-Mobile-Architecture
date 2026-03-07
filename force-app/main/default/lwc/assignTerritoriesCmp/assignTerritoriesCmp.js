/**
 * Jira Story   : NGOMCT-235
 * Developer    : Srinivas Shanigarapu
 * Date         : 6th Jan 2026
 * Description  : Lightning Web Component that enables users to manually assign one or more
 *                territories to a record. The component provides a typeahead-based territory 
 *                search, supports selection and removal of territories, and invokes Apex
 *                services to create manual ObjectTerritory2Association records. It manages
 *                loading state to prevent duplicate submissions, displays success and error
 *                notifications, and closes the Quick Action upon completion. 
 * 
 */

import { LightningElement, api, track } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import getTerritories from "@salesforce/apex/ObjectTerritory2AService.getLowestLevelTerritories";
import createAssociations from "@salesforce/apex/ObjectTerritory2AService.createAssociations";
import Territories_Label from "@salesforce/label/c.Territories_Label";
import Assign_Territories_Title from "@salesforce/label/c.Assign_Territories_Title";
import Territories_Assigned_Success from "@salesforce/label/c.Territories_Assigned_Success";
import LightningToast from "lightning/toast";
import Error_Message from "@salesforce/label/c.Error_Message";
import Cancel_Label from "@salesforce/label/c.Cancel";
import Save_Label from "@salesforce/label/c.Save";



export default class TerritoryAssigner extends LightningElement {

    @api recordId;
    searchTerm = '';
    searchResults;
    @track selectedTerritories = [];
    isLoading = false;

    /**
     * @description
     * Collection of custom labels used in the component UI.
     */
    labels = {
        territoriesLabel: Territories_Label,
        assignTerritories: Assign_Territories_Title,
        save : Save_Label,
        cancel : Cancel_Label
    };

    /**
     * @description
     * Converts selected territories into a format compatible with
     * lightning-pill-container.
     *
     * @returns {Array}
     *          List of pill objects with label and name properties.
     */
    get selectedPills() {
        return this.selectedTerritories.map(territory => ({
            label: territory.Name,
            name: territory.Id
        }));
    }

    /**
     * @description
     * Determines whether the Save button should be disabled.
     * Disabled when no territories are selected or when a save
     * operation is currently in progress.
     *
     * @returns {Boolean}
     */
    get isSaveDisabled() {
        return this.selectedTerritories.length === 0 || this.isLoading;
    }

    /**
     * @description
     * Handles user input in the territory search field.
     * Calls Apex to fetch matching lowest-level territories
     * when the search term meets the minimum length.
     *
     * @param {Event} event
     *        Input change event from the search field.
     */
    handleSearch(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length >= 2) {
            getTerritories({ searchTerm: this.searchTerm })
                .then(result => {
                    this.searchResults = result;
                })
                .catch(() => {
                    this.showToast("Error", Error_Message, "error");
                });
        } else {
            this.searchResults = null;
        }
    }

    /**
     * @description
     * Handles selection of a territory from the search results.
     * Adds the territory to the selected list if it is not already present.
     *
     * @param {Event} event
     *        Click event from the selected dropdown item.
     */
    handleSelect(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        if (!this.selectedTerritories.find(territory => territory.Id === id)) {
            this.selectedTerritories = [
                ...this.selectedTerritories,
                { Id: id, Name: name }
            ];
        }
        this.searchResults = null;
        this.searchTerm = '';
    }

    /**
     * @description
     * Handles removal of a selected territory pill.
     * Updates the selected territory list accordingly.
     *
     * @param {Event} event
     *        Event fired by lightning-pill-container on removal.
     */
    handleRemove(event) {
        const id = event.detail.item.name;
        this.selectedTerritories =
            this.selectedTerritories.filter(territory => territory.Id !== id);
    }

    /**
     * @description
     * Initiates creation of manual territory associations for the record.
     * Displays a success toast on completion and closes the action modal.
     * A page refresh is triggered to reflect updated data.
     */
    handleSave() {
        this.isLoading = true;
        const ids = this.selectedTerritories.map(territory => territory.Id);
        createAssociations({ recordId: this.recordId, territoryIds: ids })
            .then(async () => {
                this.showToast(
                    "Success",
                    Territories_Assigned_Success,
                    "success"
                );
                this.dispatchEvent(new CloseActionScreenEvent());
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            })
            .catch(() => {
                this.showToast("Error", Error_Message, "error");
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * @description
     * Handles the cancel action by closing the current Quick Action
     * without performing any updates.
     */
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    /**
     * @description
     * The showToast method displays a Lightning toast notification to the user. It accepts a title, message, variant, and mode as parameters.
     */

    showToast(title, message, variant) {
        LightningToast.show({
            label: title,
            message: message,
            variant: variant
        });
    }
}