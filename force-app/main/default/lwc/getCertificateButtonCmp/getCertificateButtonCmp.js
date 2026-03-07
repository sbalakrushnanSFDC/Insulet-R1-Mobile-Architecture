import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import LightningToast from "lightning/toast";
import getCongaTemplateId from "@salesforce/apex/GetCertificateController.getCongaTemplateId";
import OMNIPOD_CERTIFICATE_TEMPLATE_NAME from "@salesforce/label/c.Omnipod_5_Certificate_Template";
import DASH_CERTIFICATE_TEMPLATE_NAME from "@salesforce/label/c.Dash_Certificate_Template";
import CONGA_CERTIFICATE_GENERATION_URL from "@salesforce/label/c.Conga_Certificate_Generation_Url";
import GET_CERTIFICATE_BUTTON from "@salesforce/label/c.Get_Certificate_Button";
import OMNIPOD_PRODUCT from "@salesforce/label/c.Omnipod_5_Product_Certification";
import DASH_PRODUCT from "@salesforce/label/c.Dash_Product_Certification";
import TEMPLATE_NOT_FOUND_ERROR from "@salesforce/label/c.Template_Not_Found_Error";
import UNKNOWN_ERROR from "@salesforce/label/c.Unknown_Error_Message";
import CERTIFICATION_RESULT_PASSED from "@salesforce/label/c.Certification_Result_Passed";

/**
 * Jira Story   : NGOMCT-847
 * Developer    : Ankur Chauhan
 * Date         : 2025-12-08
 * Description  : LWC component to get the certificate for the certification.
 */

export default class GetCertificateButtonCmp extends NavigationMixin(LightningElement) {
  @api certificationRecord;
  isPassed = false;
  getCertificateButtonLabel = GET_CERTIFICATE_BUTTON;

  connectedCallback() {
    if (this.certificationRecord?.Certification_Results__c == CERTIFICATION_RESULT_PASSED) {
      this.isPassed = true;
    }
  }

  handleGetCertificateButtonClick() {
    let recordId = this.certificationRecord?.Id;
    let templateName;

    switch (this.certificationRecord?.Product__c) {
      case OMNIPOD_PRODUCT:
        templateName = OMNIPOD_CERTIFICATE_TEMPLATE_NAME;
        break;
      case DASH_PRODUCT:
        templateName = DASH_CERTIFICATE_TEMPLATE_NAME;
        break;
      default:
        break;
    }
    
    this.getCongaCertificate(templateName, recordId);
  }

  getCongaCertificate(templateName, recordId) {
    getCongaTemplateId({ templateName: templateName })
      .then((result) => {
        if (!result) {
          this.showToast("Error", TEMPLATE_NOT_FOUND_ERROR, "error");
          return;
        }
        let templateId = result.templateId;

        if(templateId && recordId && this.certificationRecord?.Product__c){
            let currentUrl = document.URL || '';
            let baseUrl = currentUrl.substring(
              0,
              currentUrl.indexOf("/certification")
            );
            let congaUrl = baseUrl + CONGA_CERTIFICATE_GENERATION_URL;
            congaUrl = congaUrl
              .replaceAll("{recordId}", recordId)
              .replace("{templateId}", templateId)
              .replace("{redirectPath}", currentUrl)
              .replace("{product}", this.certificationRecord?.Product__c);
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: congaUrl
                }
            });
        }
        else{
            this.showToast("Error", TEMPLATE_NOT_FOUND_ERROR, "error");
            return;
        }
      })
      .catch((error) => {
        let errorMessage = this.getErrorMessage(error);
        this.showToast("Error", errorMessage, "error");
      });
  }

  showToast(title, message, variant) {
    LightningToast.show({
      label: title,
      message: message,
      variant: variant,
      mode: 'dismissible'
    });
  }

  getErrorMessage(error) {
    if (error && error.body && error.body.message) {
      return error.body.message;
    }
    if (
      error &&
      error.body &&
      error.body.pageErrors &&
      error.body.pageErrors.length > 0
    ) {
      return error.body.pageErrors[0].message;
    }
    if (typeof error === 'string') {
        return error;
    }
    return UNKNOWN_ERROR;
  }
}