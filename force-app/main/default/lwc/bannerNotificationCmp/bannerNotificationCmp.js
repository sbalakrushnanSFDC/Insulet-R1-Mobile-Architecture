import { LightningElement, api, wire, track } from 'lwc';
import getNotification from '@salesforce/apex/BannerNotificationController.getNotification';
import { log, base } from 'c/utilityComponent';
import { NavigationMixin } from 'lightning/navigation';

export default class BannerNotificationCmp extends NavigationMixin(LightningElement) {
    @api trainerId;
    @track notification;
    wiredNotification;

    @wire(getNotification, { trainerId: '$trainerId' })
    wiredNotification({ error, data }) {
        if (data) {
            this.notification = data.map((notification) => {
                return {
                    ...notification,
                    isError: notification.type === 'error',
                    isWarning: notification.type === 'warning',
                    show: true
                }
            });
            log('notification' + JSON.stringify(this.notification))
        } else if (error) {
            log(error.message);
        }
    }

    get hasNotification() {
        return this.notification;
    }

    closeNotification(event) {
        const index = event.target.dataset.index;
        this.notification[index].show = false;
    }

    openURL(event) {
        event.preventDefault();
        const listViewApiName = event.target.dataset.link;
        const pageName = event.target.dataset.page;

        log('Navigating to listview: ' + listViewApiName + ' ' + pageName);
        if (pageName == null)
        this[NavigationMixin.Navigate](
            {
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Certification__c',
                    actionName: 'list'
                },
                state: {
                    filterName: listViewApiName
                }
            }
        );
        else
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Contract',
                    actionName: 'list'
                }
            });
    }
}