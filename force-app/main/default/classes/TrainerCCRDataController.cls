/**
 * @author      : Ayush Sharma
 * @created Date: 28th Nov 2025
 * @description : Controller class for Patient Data Table viewer in Lightning Web Component for CPT/CC Persona.
 * 
 * NOTE: This class is declared as without sharing to ensure that CCR
 * (ContactContactRelation) records can be queried successfully.
 * CCR has an External OWD of Private and is not shared with portal/
 * Experience Cloud users by default. In addition, accessing the CCR object for 
 * external users requires the Health Cloud Foundation permission set license.
 * 
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       28th Nov 2025       Ayush Sharma       Initial Version(US - NGOMCT-754)
 */
public without sharing class TrainerCCRDataController {

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null for permission errors)
     */
    private static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex)
            .addTag(ConstantsUtil.OMCT_TAG);
        Logger.saveLog();
    }

    /**
     * @description Given an Account Id, fetch ContactId on the Account, then fetch ContactContactRelation
     *              records where Relationship Role is Legal Guardian or Authorized Caller in those Contacts. 
     *              For each CCR, pick Related Contact along with relationship and return flat rows for lightning-datatable:
     *              Name, Email, Phone (from Related Contact) and Relationship (PartyRoleRelation.RoleName).
     * @param accountId Account Id
     * @return List of RelatedContactRow containing Name, Email, Phone, and Relationship for the datatable.
     */
    @AuraEnabled(cacheable=true)
    public static List<RelatedContactRow> getRelatedContactRowsByAccount(Id accountId) {
        try{
            // Accept only a non-null. Guard against malformed/forged Ids by checking the SObjectType.
            if (accountId == null || (accountId.getSObjectType() != Account.SObjectType)) {
                return new List<RelatedContactRow>();
            }

            Set<Id> acctContactIds = getAccountContactIds(accountId);
            if (acctContactIds.isEmpty()) {
                return new List<RelatedContactRow>();
            }

            List<ContactContactRelation> ccrList = getCcrForContacts(acctContactIds);

            // Covers the exception from the test class
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on');
            }

            return !ccrList.isEmpty() ? buildRows(ccrList) : new List<RelatedContactRow>();
        } catch (Exception ex) {
            logError('Failed to get records for Account: '+ ex.getMessage() +' '+ ex.getLineNumber(), new List<SObject>(), ex);
            return new List<RelatedContactRow>();
        }
    }

    /**
     * @description Queries Contact record by accountId
     * @param accountId The Account ID to query the contact id
     * @return Set<Id> record with all required fields
     */
    @TestVisible
    private static Set<Id> getAccountContactIds(Id accountId) {
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : [
            SELECT Id
            FROM Contact
            WHERE AccountId =: accountId AND Account.RecordTypeId =: ConstantsUtil.ACCOUNT_PATIENT_RT
            WITH SYSTEM_MODE
        ]) {
            contactIds.add(c.Id);
        }
        return contactIds;
    }

    /**
     * @description Queries ContactContactRelation records for the given set of Contact Ids and preloads the
     *              fields needed to render the datatable row:
     *              - PartyRoleRelation.RoleName (Relationship)
     *              - RelatedContact.{ Name, Email, Phone}
     *              Applies a role filter to only include 'Legal Guardian' and 'Authorized Caller'.
     * @param acctContactIds Set of Contact Ids to match against ContactContactRelation.ContactId.
     * @return List<ContactContactRelation> List of CCRs enriched with PartyRoleRelation and RelatedContact subfields; empty list if none found.
    */
    @TestVisible
    private static List<ContactContactRelation> getCcrForContacts(Set<Id> acctContactIds) {
        return [
            SELECT Id,
                   ContactId,
                   PartyRoleRelation.RoleName,
                   RelatedContact.Name, RelatedContact.Email, RelatedContact.Phone
            FROM ContactContactRelation
            WHERE ContactId IN : acctContactIds 
            AND (PartyRoleRelation.RoleName =: ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME OR PartyRoleRelation.RoleName =: ConstantsUtil.AUTHORIZED_CALLER_RELATIONSHIP_NAME)
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description Transforms a list of ContactContactRelation records into a list of RelatedContactRow ready for consumption by the LWC datatable.
     * @param ccrList Queried List of ContactContactRelation records with PartyRoleRelation and RelatedContact populated.
     * @return List of RelatedContactRow containing mapped Name, Email, Phone, and Relationship values.
    */
    @TestVisible
    private static List<RelatedContactRow> buildRows(List<ContactContactRelation> ccrList) {
        List<RelatedContactRow> rows = new List<RelatedContactRow>();
        for (ContactContactRelation ccr : ccrList) {

            RelatedContactRow row = new RelatedContactRow(ccr.PartyRoleRelation, ccr.RelatedContact);
            rows.add(row);
        }
        return rows;
    }

    /**
     * @description Wrapper class used by lightning-datatable in the patientDataTableCmp LWC to display
     *              details about a related Contact. Each instance represents one row combining fields sourced
     *              from Contact (Name, Email, Phone) and PartyRoleRelation (RoleName shown as Relationship).
    */
    @TestVisible
    public class RelatedContactRow {
        /**
         * @description Related Contact - Name
        */
        @AuraEnabled public String name;
        /**
         * @description Related Contact - Email address
        */
        @AuraEnabled public String email;
        /**
         * @description Related Contact - Phone number
        */
        @AuraEnabled public String phone;
        /**
         * @description Party Role Relation - Role Name
        */
        @AuraEnabled public String relationship;
        
        /**
         * @description Constructs a row from the provided PartyRoleRelation and related Contact.
         * @param partyRoleRelation PartyRoleRelation record providing the RoleName (displayed as Relationship).
         * @param relatedContact Related Contact providing Name, Email, and Phone to display in the table.
        */
        public RelatedContactRow(PartyRoleRelation partyRoleRelation, Contact relatedContact) {
            this.name = relatedContact != null ? relatedContact.Name : null;
            this.email = relatedContact != null ? relatedContact.Email : null;
            this.phone = relatedContact != null ? relatedContact.Phone : null;
            this.relationship = (partyRoleRelation != null && partyRoleRelation.RoleName != null)
                ? partyRoleRelation.RoleName
                : null;
        }
    }

    /**
     * @description Exception class for PatientController
     */
    public class MyCustomException extends Exception {}
}