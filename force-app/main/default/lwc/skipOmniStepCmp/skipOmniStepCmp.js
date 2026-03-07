import { LightningElement, wire } from 'lwc';
import { OmniscriptBaseMixin } from 'omnistudio/omniscriptBaseMixin';
import getCertification from '@salesforce/apex/TakeExamCmpController.getCertification';
import { CurrentPageReference } from 'lightning/navigation';
import PENDING from '@salesforce/label/c.Pending';
import FAILED from '@salesforce/label/c.Failed';
export default class SkipOmniStepCmp extends OmniscriptBaseMixin(LightningElement) {
    _pageRef;
    @wire(CurrentPageReference)
    setPageReference(pageRef) {
        this._pageRef = pageRef;
    }

    connectedCallback() {
        let certificateId;
        if (this._pageRef && this._pageRef.state) {
            certificateId = this._pageRef.state.certificationid;
        } else {
            const urlParams = new URLSearchParams(window.location.search);
            certificateId = urlParams.get('certificationid');
        }
     
        if (certificateId) {
           this.loadCertification(certificateId);
        }
        
    }

    loadCertification(certificateId) {
        getCertification({ certificationId: certificateId })
            .then((data) => {
                this.error = undefined;
                var showexam = false;
                const isloaded = true;
                if (data) {
                    const retake = data?.Retake_Exam__c;
                    const completionStatus = data?.Completion_Status__c;
                    const results = data?.Certification_Results__c;
                    const isYes = (retake == true);
                    const resultsBlank = (results === null || results === undefined || results === '');
                    const cond1 = !isYes && completionStatus === PENDING && resultsBlank;
                    const cond2 = isYes && completionStatus === PENDING && results === FAILED;

                    showexam = cond1 || cond2;
                } else {
                    showexam = false;
                }
                this.omniApplyCallResp({
                    ...(showexam ? { showexam } : {}),
                    ...(isloaded ? { isloaded } : {})
            });
            this.omniNextStep();
            })
            .catch((e) => {
                this.error = e;
                this.certification = undefined;
                this.showTakeExamButton = false;
            });
    }
}