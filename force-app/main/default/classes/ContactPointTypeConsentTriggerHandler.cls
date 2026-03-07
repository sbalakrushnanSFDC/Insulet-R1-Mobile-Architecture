/**
 * @description Trigger handler for ContactPointTypeConsent.
 * Updates CaptureDate to current datetime when PrivacyConsentStatus is changed.
 * @createdDate 27th Jan 2026
 * @CreatedBy Bijayalaxmi Prusty
 * * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.1.0       20th Feb 2026       Bijayalaxmi Prusty      Initial Version(NGASIM-2157)
 */
public inherited sharing class ContactPointTypeConsentTriggerHandler extends TriggerHandler {

    /**
     * @description When PrivacyConsentStatus is updated, set CaptureDate to current datetime
     * @param newRecords List of new records
     */
    public override void beforeInsert(List<SObject> newRecords) {
        ConsentService.updateCaptureDateOnConsentStatusChange(newRecords);
    }

    /**
     * @description When PrivacyConsentStatus is updated, set CaptureDate to current datetime
     * @param updatedRecordsMap Map of updated records by Id
     * @param oldRecordsMap Map of old record values by Id
     */
    public override void beforeUpdate(Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        ConsentService.updateCaptureDateOnConsentStatusChange(updatedRecordsMap, oldRecordsMap);
    }
}