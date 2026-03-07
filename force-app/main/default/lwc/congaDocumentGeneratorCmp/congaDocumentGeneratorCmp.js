/**
 * Jira Story   : NGOMCT-339
 * Developer    : Srinivas Shanigarapu
 * Date         : 2025-10-23
 * Description  : This Lightning Web Component (LWC) serves as a launcher,
 *                dynamically constructing the Conga Composer URL with required parameters
 *                and invoking it to initiate document generation.
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       2025-10-23          Srinivas Shanigarapu     Initial (NGOMCT-339)
 * V1.0.1       2026-02-02          Yogesh Rana              Updated filename & query parameter in the Conga Composer URL (NGOMCT-1265)
 */

import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import congaComposerDocumentGeneratorURL from '@salesforce/label/c.Conga_Composer_Document_Generator_URL';

export default class CongaDocumentGeneratorCmp extends NavigationMixin(LightningElement) {
    @api recordId;
    @api outputMessage;
    @api congaTemplateIdList;
    @api partnerServerURL;
    @api congaQueryId;
    @api congaQueryAlias;
    @api filename;
    /**
     * The connectedCallback lifecycle hook is where the automatic navigation is triggered
     */ 
    connectedCallback() {
      let congaUrlUpdated = congaComposerDocumentGeneratorURL;
        congaUrlUpdated = congaUrlUpdated
            .replace('{partnerServerURL}', this.partnerServerURL)
            .replace('{recordId}', this.recordId)
            .replace('{congaTemplateIdList}', this.congaTemplateIdList)
            .replace('{filename}',  this.filename)

          congaUrlUpdated = this.congaQueryId != undefined && this.congaQueryId != null ? 
                                              congaUrlUpdated+`&QueryId=[${this.congaQueryAlias}]` + this.congaQueryId + '?pv0=' + this.recordId
                                              : congaUrlUpdated;
       this.navigateToWebPage(congaUrlUpdated);
    }

    /**
     * Function to handle the navigation
     */
    navigateToWebPage(congaUrl) {
       this[NavigationMixin.Navigate]({
           type: 'standard__webPage',
           attributes: {
               url: congaUrl
           }
       });
    }
}