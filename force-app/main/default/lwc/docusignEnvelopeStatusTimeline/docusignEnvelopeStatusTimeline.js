import { LightningElement, api, wire, track } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import { loadStyle } from "lightning/platformResourceLoader";
import TRAINER_PORTAL_RESOURCE from "@salesforce/resourceUrl/TrainerPortalResource";
import getEvents from "@salesforce/apex/DocusignEnvelopeStatusTimelineController.getEvents";

// Custom Labels
import REASON from '@salesforce/label/c.Reason';
import SENTFORSIGNATURE from '@salesforce/label/c.SentForSignature';
import LASTSTATUSUPDATE from '@salesforce/label/c.LastStatusUpdate';
import EXPIRES from '@salesforce/label/c.Expires';
import ENVELOPESENT from '@salesforce/label/c.EnvelopeSent';
import ENVELOPEDECLINED from '@salesforce/label/c.EnvelopeDeclined';
import ENVELOPECOMPLETED from '@salesforce/label/c.EnvelopeCompleted';
import ENVELOPE_VOIDED from '@salesforce/label/c.Envelope_Voided';
import DOCUSIGNTIMELINEERROR from '@salesforce/label/c.DocuSignTimelineError';
import DOCUSIGNENVELOPESTATUS from '@salesforce/label/c.DocusignEnvelopeStatus';
import DELIVERED from '@salesforce/label/c.Delivered';
import DECLINEDSIGN from '@salesforce/label/c.DeclinedSign';
import COMPLETED from '@salesforce/label/c.Completed';
import STATUS from '@salesforce/label/c.Status';
import SENT from '@salesforce/label/c.Sent';
import SIGNED from '@salesforce/label/c.Signed';
import ENVELOPEVIEWED from '@salesforce/label/c.Envelope_Viewed';

// CSS Classes Constants
const STAGE_CLASS_BASE =
  "slds-timeline__item slds-timeline__item_expandable slds-media";

const STAGE_CLASS_DECLINED = `declined-stage ${STAGE_CLASS_BASE}`;
const STAGE_CLASS_SIGNED = `signed-stage ${STAGE_CLASS_BASE}`;
const STAGE_CLASS_SENT = `sent-stage ${STAGE_CLASS_BASE}`;
const STAGE_CLASS_VOID = `void-stage ${STAGE_CLASS_BASE}`;

// Icon Name Constants
const ICON_INFO = "utility:info";
const ICON_CLOSE = "utility:close";
const ICON_PREVIEW = "utility:preview";
const ICON_SIGNED = "standard:task2";
const ICON_SENT = "standard:email_chatter";
const ACCORDION_ICON_EXPANDED = "utility:chevronleft";
const ACCORDION_ICON_COLLAPSED = "utility:chevrondown";

// Status Check Constants (includes checks)
const STATUS_DECLINED = "declined";
const STATUS_COMPLETE = "complete";
const STATUS_SIGNED = "signed";
const STATUS_SENT = "sent";
const STATUS_DELIVERED = "delivered";
const STATUS_VOID = "void";


/**
 * @author      : Lokesh P
 * @created Date: 14th January 2026
 * @description : LWC to show DocuSign Envelope Status Timeline
 * =========================== Logs ======================================
 * Version      Modified Date            Modified By             Brief Note
 * V1.0.0       14th January 2026       Lokesh P               Initial Version (NGOMCT-475)
 */

export default class DocusignEnvelopeStatusTimeline extends LightningElement {
  _recordId;
  _recordIdFromUrl;
  _cssInjected = false;

  label = {
    REASON,
    SENTFORSIGNATURE,
    LASTSTATUSUPDATE,
    EXPIRES,
    ENVELOPESENT,
    ENVELOPEDECLINED,
    ENVELOPECOMPLETED,
    ENVELOPE_VOIDED,
    DOCUSIGNTIMELINEERROR,
    DOCUSIGNENVELOPESTATUS,
    DELIVERED,
    DECLINEDSIGN,
    COMPLETED,
    STATUS,
    SENT,
    SIGNED,
    ENVELOPEVIEWED
  };

  @track events = [];

  docuSingLogo = TRAINER_PORTAL_RESOURCE + "/images/DocusignAssets.png";

  loading = true;
  errorMessage = "";

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    this._recordId = value;

    if (value) {
      this.loading = true;
      this.errorMessage = "";
    } else if (!this._recordIdFromUrl) {
      this.loading = false;
      this.events = [];
      this.errorMessage = this.label.DOCUSIGNTIMELINEERROR;
    }
  }

  connectedCallback() {
    if (!this.resolvedRecordId) {
      this.loading = false;
      this.events = [];
      this.errorMessage = this.label.DOCUSIGNTIMELINEERROR;
    }
  }

  /**
     * @description Injects the CSS styles into the component
     */
  renderedCallback() {
    if (this._cssInjected) {
      return;
    }
    this._cssInjected = true;

    Promise.all([
      loadStyle(this, TRAINER_PORTAL_RESOURCE + "/css/style.css")
    ]).then(() => {
    }).catch((error) => {
      console.error("[TrainerPortalResource] Failed to load CSS", error);
    });
     
  }

  @wire(CurrentPageReference)
  wiredPageRef(pageRef) {
    if (!pageRef) return;

    const recordIdFromUrl =
      pageRef?.attributes?.recordId ||
      pageRef?.state?.recordId ||
      pageRef?.state?.c__recordId ||
      pageRef?.state?.c__id;

    if (recordIdFromUrl && recordIdFromUrl !== this._recordIdFromUrl) {
      this._recordIdFromUrl = recordIdFromUrl;

      if (!this._recordId) {
        this.loading = true;
        this.errorMessage = "";
      }
    }
  }

  /**
     * @description Wires the getEvents Apex method to fetch DocuSign events
     */
  @wire(getEvents, { recordId: "$resolvedRecordId" })
  wiredEvents({ data, error }) {
    if (this.resolvedRecordId == null) {
      this.loading = false;
      return;
    }

    this.loading = false;

    if (data) {
      this.errorMessage = "";
      this.events = this.mapGroupedDataToAccordion(data);
      return;
    } else if (error) {
      this.events = [];
      this.errorMessage = this.normalizeError(error);
      console.error("[DocuSignTimeline] Apex error:", error);
    }
  }

  get hasEvents() {
    return Array.isArray(this.events) && this.events.length > 0;
  }

  get hasError() {
    return !!this.errorMessage;
  }

  get resolvedRecordId() {
    return this._recordId || this._recordIdFromUrl;
  }

  normalizeError(error) {
    try {
      return (
        error?.body?.message ||
        error?.body?.pageErrors?.[0]?.message ||
        error?.message ||
        JSON.stringify(error)
      );
    } catch {
      return error;
    }
  }

  /**
     * @description Toggles the details view for a specific event in the timeline
     */
  toggleDetails(event) {
    const id = event.currentTarget.dataset.id;

    const tempEvents = this.events.map((group) => {
      return {
        ...group,
        statuses: group.statuses.map((e) => {
          const isCurrent = e.id === id;
          const newShowDetails = isCurrent ? !e.showDetails : e.showDetails;

          return {
            ...e,
            showDetails: newShowDetails,
            accordionIcon: newShowDetails
              ? ACCORDION_ICON_EXPANDED
              : ACCORDION_ICON_COLLAPSED
          };
        })
      };
    });

    this.events = tempEvents;
  }

  /**
     * @description Maps the grouped data from Apex to the accordion structure
  */
  mapGroupedDataToAccordion(groups) {
    const list = Array.isArray(groups) ? groups : [];

    return list.map((g, idx) => {
      return {
        key: g.docusignId || `group-${idx}`,
        envelopeConfigName: g.envelopeConfigName,
        docusignId: g.docusignId,
        statuses: this.mapStatusRowsToEvents(g.statuses || [])
      };
    });
  }

  mapStatusRowsToEvents(rows) {
    const list = Array.isArray(rows) ? rows : [];
    return list.map((row) => this.mapStatusRowToEvent(row)).filter(Boolean);
  }

  /**
     * @description Maps a single status row to an event object for the timeline
     */
  mapStatusRowToEvent(row) {
    if (!row) return null;

    const status = (row.dfsle__Status__c || row.Status__c || row.status || "")
      .toString()
      .trim();

    const statusLower = status.toLowerCase();

    const event = {
      id: row.Id,
      createdDate: row.CreatedDate,
      sent: row.dfsle__Sent__c ? new Date(row.dfsle__Sent__c) : null,
      status,
      title: status,
      subtitle: "",
      iconName: ICON_INFO,
      iconCssClass: "ds-icon ds-icon--info",
      showDetails: false,
      accordionIcon: ACCORDION_ICON_COLLAPSED,
      lastStatusUpdate: row.dfsle__Sent__c ? new Date(row.dfsle__Sent__c) : null,
      completedOn: row.dfsle__Completed__c || null,
      reason: row.dfsle__Reason__c || null,
      expiresOn: row.dfsle__Expires__c || null,
      stageClass: STAGE_CLASS_BASE
    };

    if (statusLower.includes(STATUS_DECLINED)) {
      event.title = this.label.ENVELOPEDECLINED;
      event.subtitle = this.label.DECLINEDSIGN;;
      event.iconName = ICON_CLOSE;
      event.iconCssClass = "ds-icon ds-icon--declined";
      event.iconContainerClass =
        "slds-icon_container slds-icon-utility-utility-close slds-timeline__icon ds-icon--declined ds-svg";
      event.stageClass = STAGE_CLASS_DECLINED;
      return event;
    } else if (
      statusLower.includes(STATUS_COMPLETE) ||
      statusLower.includes(STATUS_SIGNED)
    ) {
      event.title = this.label.SIGNED;
      event.subtitle = this.label.ENVELOPECOMPLETED;
      event.iconName = ICON_SIGNED;
      event.iconCssClass = "ds-icon ds-icon--signed";
      event.iconContainerClass =
        "slds-icon_container slds-icon-utility-email slds-timeline__icon ds-icon--signed ds-svg";
      event.stageClass = STAGE_CLASS_SIGNED;
      return event;
    } else if (statusLower.includes(STATUS_SENT)) {
      event.title = this.label.SENTFORSIGNATURE;
      event.subtitle = this.label.ENVELOPESENT;;
      event.iconName = ICON_SENT;
      event.iconCssClass = "ds-icon ds-icon--sent";
      event.iconContainerClass =
        "slds-icon_container slds-icon-utility-email slds-timeline__icon ds-icon--sent ds-svg";
      event.stageClass = STAGE_CLASS_SENT;
      return event;
    } else if (statusLower.includes(STATUS_DELIVERED)) {
      event.title = this.label.DELIVERED;
      event.subtitle = this.label.ENVELOPEVIEWED;
      event.iconName = ICON_PREVIEW;
      event.iconCssClass = "ds-icon ds-icon--sent";
      event.iconContainerClass =
        "slds-icon_container slds-icon-utility-utility:email_open slds-timeline__icon ds-icon--sent ds-svg";
      event.stageClass = STAGE_CLASS_SENT;
      return event;
    } else if (statusLower.includes(STATUS_VOID)) {
      event.title = this.label.ENVELOPE_VOIDED;
      event.subtitle = this.label.ENVELOPE_VOIDED;
      event.iconName = ICON_CLOSE;
      event.iconCssClass = "ds-icon ds-icon--declined";
      event.iconContainerClass =
        "slds-icon_container slds-icon-utility-utility-close slds-timeline__icon ds-icon--declined ds-svg";
      event.stageClass = STAGE_CLASS_VOID;
      return event;
    }
    return event;
  }
}