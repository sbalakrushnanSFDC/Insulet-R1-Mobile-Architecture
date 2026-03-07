/**
 * Jira Story   : NGOMCT-724
 * Developer    : Srinivas Shanigarapu
 * Date         : 2025-11-28
 * Description  : This LWC is used to trigger a Salesforce Flow and then attach the generated document to the corresponding record.
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       28th Nov 2025       Srinivas                Initial (NGOMCT-724)
 */
import { LightningElement, api,track } from 'lwc';
import LightningToast from 'lightning/toast';
import { NavigationMixin } from 'lightning/navigation';
import congaComposerDocumentGeneratorURL from '@salesforce/label/c.Conga_Composer_Document_Generator_Portal_URL';
import CLOSE from '@salesforce/label/c.Close';

export default class ReusableFlowButtonWrapperCmp extends NavigationMixin(LightningElement) {

  @api recordId;
  @api buttonName;
  @api flowApiName;
  congaTemplateIdList;
  partnerServerURL;
  isFlowSuccess;
  queryId;
  @api showFlow = false;
  @track renderFlow = true;
  isReRunFlow='';
  documentDownloadPortal=false;
  fileName;
label = {
    CLOSE
  }
  /**
   * Getter method to provide input variables to the invoked flow component.
   */
  get inputVariables() {
    return [
      {
        name: 'recordId',
        type: 'String',
        value: this.recordId,
      }
    ]
  }

  /**
   * Handler executed when the modal is closed. It hides the flow component.
   */
  handleCloseModal() {
    this.showFlow = false;
  }

  /**
   * Handler executed when the custom button is clicked. It shows the flow component.
   */
  handleButtonClick() {
    this.showFlow = true;
  }

  /**
   * Handler for the flow's status change event (e.g., FINISHED, ERROR).
   * It captures output variables from the finished flow.
   */
  handleFlowStatusChange(event) {
    if (event.detail.status === "FINISHED") {
      const outputVariables = event.detail.outputVariables;
      outputVariables.forEach(variable => {
        if (variable.name === "congaTemplateIdList") {
          this.congaTemplateIdList = variable.value;
        } else if (variable.name === "partnerServerURL") {
          this.partnerServerURL = variable.value;
        } else if (variable.name === "isFlowSuccess") {
          this.isFlowSuccess = variable.value;
        } else if (variable.name === "queryId") {
          this.queryId = variable.value;
        } else if(variable.name === "documentDownloadPortal") {
          this.documentDownloadPortal = variable.value;
        } else if(variable.name === "fileName") {
          this.fileName = variable.value;
        }
  
      });
      if(this.documentDownloadPortal){
      this.renderFlow=false;
      }
      else{
        this.showFlow = false;
      }

      if (this.isFlowSuccess && this.congaTemplateIdList != null) {
        this.generateDocumentAndNavigate();
      }
    } else if (event.detail.status === 'ERROR') {
      this.showFlow = false;
      this.showToast('Error', 'Flow Error: ' + JSON.stringify(event.detail), 'error');

    }
  }

  /**
   * Constructs the Conga URL, navigates the user to the generated URL, 
   * and initiates document generation.
   */
  generateDocumentAndNavigate() {
    const partnerURLSegments = this.partnerServerURL.split('/');
    const partnerURLPathSegments = partnerURLSegments.slice(0, 4);
    const baseUrlWithTrainerPortalvforcesite = partnerURLPathSegments.join('/');
    const lastSlashIndex = baseUrlWithTrainerPortalvforcesite.lastIndexOf('/');

    const congaUrl = congaComposerDocumentGeneratorURL
      .replace('{partnerServerURL}', this.partnerServerURL)
      .replaceAll('{recordId}', this.recordId)
      .replace('{congaTemplateIdList}', this.congaTemplateIdList)
      .replace('{filename}', this.fileName)

    const congaFinalUrl = this.queryId != null && this.queryId != undefined ? baseUrlWithTrainerPortalvforcesite + congaUrl + '&QueryId=[ACC]' + this.queryId + '&pv0=' + this.recordId : baseUrlWithTrainerPortalvforcesite + congaUrl;
     this[NavigationMixin.Navigate]({
         type: 'standard__webPage',
         attributes: {
             url: congaFinalUrl
         }
     });
  }

  /**
    * Displays a Lightning Toast notification.
    */
  showToast(title, message, variant) {
    LightningToast.show({
      label: title,
      message: message,
      variant: variant
    });
  }
handlePortalFlowStatusChange(event){
  if (event.detail.status === "FINISHED") {
    const outputVariables = event.detail.outputVariables;
    outputVariables.forEach(variable => {
        if (variable.name === "isReRun") {
          this.isReRunFlow = variable.value;
          if(this.isReRunFlow == true) {
        this.renderFlow = true; 
    } else {
        this.showFlow = false; 
    }
        } 
      });
  }
  else if (event.detail.status === 'ERROR') {
      this.showFlow = false;
      this.showToast('Error', 'Flow Error: ' + JSON.stringify(event.detail), 'error');

    }
}
}