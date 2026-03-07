import { LightningElement, api } from 'lwc';
import { showToast } from 'c/utilityComponent';
import getCertification from '@salesforce/apex/TakeExamCmpController.getCertification';
import getCertificationRelatedOmniscript from '@salesforce/apex/TakeExamCmpController.getCertificationRelatedOmniscript';
import createAssessment from '@salesforce/apex/TrainerAssessmentHandler.createAssessment';
import ERROR_TITLE_LABEL from '@salesforce/label/c.Error_Title_Label';
import ERROR_MESSAGE_LABEL from '@salesforce/label/c.Error_Message_Label';
import TAKE_EXAM_LABEL from '@salesforce/label/c.Take_Exam_Label';
import { NavigationMixin } from 'lightning/navigation';
const FAILED = 'Failed';
const PENDING = 'Pending';
const ERROR='error';
const STICKY='sticky'

/**
 * Jira Story   : NGOMCT-755
 * Developer    : Rohan Saxena
 * Date         : 2025-11-17
 * Description  : This component allows a user to take exam for a certification.
 *
 */
export default class TakeExamCmp extends NavigationMixin(LightningElement) {
    isDisabled = false;
    @api recordId;
    certification;
    error;
    subtype;
    showExamLogic=false;
    omniLoaded=false;
    get showTakeExamButton() {
        return this.omniLoaded && this.showExamLogic;
    }

    labels = {
        takeExam : TAKE_EXAM_LABEL,
    }
    connectedCallback() {
        this.loadCertification();
        this.loadOmniData();
    }

    loadOmniData() {
        getCertificationRelatedOmniscript({ certificationId: this.recordId })
            .then((data) => {
                if (data) {
                    this.subtype= data?.Certification_Assessment__r?.OmniProcess.SubType; 
                    this.omniLoaded = true;
                } else {
                    this.omniLoaded = false;
                }
            })
            .catch((e) => {
                this.error = e;
                this.certification = undefined;
                this.omniLoaded = false;
            });
    }

    loadCertification() {
        getCertification({ certificationId: this.recordId })
            .then((data) => {
                this.certification = data;
                this.error = undefined;

                if (data) {
                    const retake = data?.Retake_Exam__c; 
                    const completionStatus = data?.Completion_Status__c; 
                    const results = data?.Certification_Results__c; 
                    const isYes = (retake === true);
                    const resultsBlank = (results === null || results === undefined || results === '');
                    const cond1 = !isYes && completionStatus === PENDING && resultsBlank;
                    const cond2 = isYes && completionStatus === PENDING && results === FAILED;
                    this.showExamLogic = cond1 || cond2;
                } else {
                    this.showExamLogic = false;
                }
            })
            .catch((e) => {
                this.error = e;
                this.certification = undefined;
                this.showExamLogic = false;
            });
    }

    handleExam() {
        this.isDisabled = true;
        this.createAssessmentWrapper();
    }

    createAssessmentWrapper() {
    createAssessment({ certificationId: this.recordId })
        .then((assessmentId) => {
            this.assessmentId = assessmentId;

            // Only navigate if assessmentId is available
            if (assessmentId) {
                // Navigate to community page
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: {
                        name: 'exam__c'
                    },
                    state: {
                        certificationid: this.recordId,
                        c__ContextId: this.assessmentId,
                        type: this.subtype
                    }
                });
            } else {
                // Handle case where Apex returns null/undefined without throwing an error
                showToast(ERROR_TITLE_LABEL, ERROR_MESSAGE_LABEL, ERROR, STICKY);
                this.isDisabled = false;
            }
        })
        .catch((error) => {
            showToast(ERROR_TITLE_LABEL, ERROR_MESSAGE_LABEL, ERROR, STICKY);
            this.isDisabled = false;
        });
}
}