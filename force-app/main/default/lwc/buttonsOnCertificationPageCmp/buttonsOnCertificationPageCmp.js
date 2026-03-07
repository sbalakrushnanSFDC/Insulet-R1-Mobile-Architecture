import { api, LightningElement } from 'lwc';
import getCertification from '@salesforce/apex/TakeExamCmpController.getCertification';

/**
 * Jira Story   : NGOMCT-847
 * Developer    : Ankur Chauhan
 * Date         : 2025-12-08
 * Description  : LWC component to call the buttons available on certification page.
 */

export default class ButtonsOnCertificationPageCmp extends LightningElement {
    @api recordId;
    certification;
    
    connectedCallback() {
        this.loadCertification();
    }
    
    loadCertification() {
        getCertification({ certificationId: this.recordId }).then(result => {
            if(result){
                this.certification = result;
            }
        });
    }
}