import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class LeadActionsMobileCmp extends NavigationMixin(LightningElement) {
    @api recordId;

    handleSendEmail() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: 'SendEmail'
            },
            state: {
                recordId: this.recordId
            }
        });
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleAddToCampaign() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: 'Lead.AddToCampaign'
            },
            state: {
                recordId: this.recordId
            }
        });
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleLogACall() {
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: 'LogACall'
            },
            state: {
                recordId: this.recordId
            }
        });
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
