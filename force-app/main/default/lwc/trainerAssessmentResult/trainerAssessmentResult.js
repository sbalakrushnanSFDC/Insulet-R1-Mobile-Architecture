/**
 * 
 * Jira Story: NGOMCT - 789
 * Developer    : Shashank Nigam
 * Date         : 2025 - 11-06
 * Description  : LWC to calculate post processing of Assessment and display result. 
 */
import { LightningElement, api, wire } from 'lwc';
import getResult from '@salesforce/apex/TrainerAssessmentHandler.postSaveAsmtProcessing';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import PortalTrainingFailureSubHeader from '@salesforce/label/c.Portal_Training_Failure_Sub_Header'
import PortalTrainingOnLoad from '@salesforce/label/c.Portal_Training_On_Load'
import PortalTrainingSuccessMessage from '@salesforce/label/c.Portal_Training_Success_Message'
import PortalTrainingSuccessSubHeader from '@salesforce/label/c.Portal_Training_Success_Sub_Header'
import PortalTrainingLoadingSubHeader from '@salesforce/label/c.Portal_Training_Loading_SubHeader'
import PortalTrainingAttemptSummary from '@salesforce/label/c.Portal_Training_Attempt_Summary'
import PortalTrainingCurrentScore from '@salesforce/label/c.Portal_Training_Current_Score'
import PortalTrainingQuestionsAnswered from '@salesforce/label/c.Portal_Training_Questions_Answered'
import ContinueLabel from '@salesforce/label/c.Continue'
import LoadingLabel from '@salesforce/label/c.Loading'

const log = (msg) => {
    // console.log(msg)
}

export default class TrainerAssessmentResult extends NavigationMixin(LightningElement) {
    result = {}
    isLoading = true
    @api assessmentId
    certificationId
    label = {
        PortalTrainingFailureSubHeader,
        PortalTrainingOnLoad,
        PortalTrainingSuccessMessage,
        PortalTrainingSuccessSubHeader,
        PortalTrainingLoadingSubHeader,
        PortalTrainingAttemptSummary,
        PortalTrainingCurrentScore,
        PortalTrainingQuestionsAnswered,
        ContinueLabel,
        LoadingLabel
    }

    /**
     * Getter to check if Result is Pass.
     */
    get isSuccess() {
        return this.result.status == true
    }

    /**
     * Getter to check if Result is Fail.
     */
    get isNotSuccess() {
        return this.result.status == false
    }

    /**
     * Getter to check if loading is completed.
     */
    get resultFetched() {
        return !this.isLoading
    }

    get headerMessage(){
        return this.label.PortalTrainingSuccessMessage.replace('{result.certificationName}',this.result.certificationName)
    }

    /**
     * LifeCycle Hook called during DOM insertion.
     */
    connectedCallback() {
        this.postProcessing()
    }

    /**
     * Method to get the assessmentId from URL.
     */
    _pageRef;
    @wire(CurrentPageReference)
    setPageReference(pageRef) {
        this._pageRef = pageRef;
    }

    getIdFromURL() {
        if (this._pageRef && this._pageRef.state) {
            this.assessmentId = this._pageRef.state.examId;
        } else {
            const urlParams = new URLSearchParams(window.location.search);
            this.assessmentId = urlParams.get('examId');
        }
    }

    /**
     * Method to calculate post processing from Apex callout and populate variables on LWC with data JSON from Apex.
     * 
     */
    postProcessing() {
        var assessmentId
        if (this.omniJsonData) {
            assessmentId = JSON.parse(JSON.stringify(this.omniJsonData))?.assessmentId || this.assessmentId
        }
        else if (this._pageRef && this._pageRef.state) {
            assessmentId = this._pageRef.state.c__ContextId || this.assessmentId;
            this.certificationId = this._pageRef.state.certificationid;
        }
        else {
            const urlParams = new URLSearchParams(window.location.search);
            assessmentId = urlParams.get('c__ContextId') || this.assessmentId;
            this.certificationId = urlParams.get('certificationid');
        }
        getResult({ assessmentId: assessmentId }).then(data => {
            this.result = data
        })
            .catch(error => {
                log(error)
            })
            .finally(() => {
                this.isLoading = false
            })
    }

    /**
     *  Navigate using NavigationMixin instead of manipulating window.location
     *  When certificationId is available, navigate to the same relative route using a webPage reference.
     */
    handleClose() {
        this[NavigationMixin.Navigate](
            {
                type: 'standard__webPage',
                attributes: {
                    url: `/certification/${this.certificationId}`
                }
            }
        );

    }
}