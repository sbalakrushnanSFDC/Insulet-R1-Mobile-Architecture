/**
 * @description Service class responsible to manage ProviderRelationships
 * Created Date : Oct 10, 2025
 * Created By   : Sunil Khanchandani
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Oct 10, 2025       Sunil Khanchandani       Initial Version
*/


public inherited sharing class ProviderRelationshipService {

    /** Tag name used for structured logging of errors during DML operations */
    public static String errorTagName;

    /** Map used to contains the leads where provider value on lead not null */
    public static Map<Id,Lead> providerLeadsMap;
     /**Set contains id of providers on the converted leads */
    public static Set<Id> providerIdSet;

    /**
    * @description Inserts ContactContactRelation records using bulk-safe partial DML and logs failures
    * @param convertedLeads List of converted lead records
    * @param tagName Tag name used for structured logging of errors during DML operations
    */
    public static void processProviderRelations(List<Lead> convertedLeads, String tagName) {
        errorTagName = tagName;
        prepareProviderLeadsMap(convertedLeads);
    }

    private static void prepareProviderLeadsMap(List<Lead> convertedLeads){
        providerLeadsMap = new Map<Id,Lead>();
        providerIdSet = new Set<Id>();
        for(Lead ld:convertedLeads){
            if(isProviderLead(ld)){
                providerIdSet.add(ld.Related_Provider__c);
                providerLeadsMap.put(ld.Id,ld);
            }
        }

        if(!providerLeadsMap.isEmpty()){
            createRelationshipsForProviders();
        }
    }

    /**
     * @description Checks if Lead has provider relationship
     * @param ld Lead record to check
     * @return True if Lead has provider relationship
     */
    private static Boolean isProviderLead(Lead ld){
        return ld.ConvertedContactId != null && ld.Related_Provider__c != null;
    }

    /**
    * @description Creates ContactContactRelation records between converted patient contacts
    *              and their related provider contacts post Lead conversion
    */
    private static void createRelationshipsForProviders() {
        List<ContactContactRelation> relationships = prepareProvideRelationshipRecords();
        ContactContactRelationService.insertContactContactRelationships(relationships,errorTagName);
    }

    /**
    * @description Prepares ContactContactRelation records between patient contacts and Provider contacts.
    *              Fetches Provider PartyRoleRelation records and builds relationship records
    * @return List of ContactContactRelation records ready for insertion
    */
    private static List<ContactContactRelation> prepareProvideRelationshipRecords() {
        List<ContactContactRelation> relationships = new List<ContactContactRelation>();

        List<PartyRoleRelation> partyRoleRelationRecords = ContactContactRelationService.fetchRoleRelationRecord(ConstantsUtil.PROVIDER_RELATIONSHIP_NAME);

        Id roleRelationId = partyRoleRelationRecords[0]?.Id;
        Map<Id, Account> providerAccounts = AccountService.getConvertedAccounts(providerIdSet);
        for (Lead ld : providerLeadsMap.values()) {
            Account providerAccount = providerAccounts.get(ld.Related_Provider__c);
            if (providerAccount == null) {
                continue;
            }
            ContactContactRelation ccr = new ContactContactRelation();
            ccr.ContactId = ld.ConvertedContactId;
            ccr.RelatedContactId = providerAccount.PersonContactId;
            ccr.PartyRoleRelationId = roleRelationId;
            relationships.add(ccr);
        }
        return relationships;
    }
}