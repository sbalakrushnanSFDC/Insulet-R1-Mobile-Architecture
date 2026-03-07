/**
 * @description Utility class for creating mock SObject records for testing purposes
 * Provides methods to generate fake data without DML operations
 * @author Noah Ross
 * @date 10/15/2024
 */
@IsTest(IsParallel=true)
public class MockDataFactory {
    public static Integer iter = 1;

    // Start example usage
    // More info at the following link:
    // https://confluence.insulet.com/display/NASFL/Using+Mock+Data+Examples

    /**
     * @description Creates mock Account records for testing
     * @param amount Number of accounts to create
     * @param fieldMap Optional field values to set
     * @return List of Account records
     */
    public static List<Account> createAccounts(Integer amount, Map<String, Object> fieldMap) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < amount; i++) {
            Account acc = (Account)mockData('Account', fieldMap);
            acc.Id = getFakeId('Account');
            if(acc.Name == null) {
                acc.Name = 'Test Account ' + iter++;
            }
            accounts.add(acc);
        }
        return accounts;
    }

    /**
     * @description Creates mock Contact records for testing
     * @param amount Number of contacts to create
     * @param fieldMap Optional field values to set
     * @return List of Contact records
     */
    public static List<Contact> createContacts(Integer amount, Map<String, Object> fieldMap) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < amount; i++) {
            Contact con = (Contact)mockData('Contact', fieldMap);
            con.Id = getFakeId('Contact');
            if(con.LastName == null) {
                con.LastName = 'Test Contact ' + iter++;
            }
            contacts.add(con);
        }
        return contacts;
    }

    /**
     * @description Creates mock Lead records for testing
     * @param amount Number of leads to create
     * @param fieldMap Optional field values to set
     * @return List of Lead records
     */
    public static List<Lead> createLeads(Integer amount, Map<String, Object> fieldMap) {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < amount; i++) {
            Lead lead = (Lead)mockData('Lead', fieldMap);
            lead.Id = getFakeId('Lead');
            if(lead.LastName == null) {
                lead.LastName = 'Test Lead ' + iter++;
            }
            if(lead.Company == null) {
                lead.Company = 'Test Company ' + iter;
            }
            leads.add(lead);
        }
        return leads;
    }

    /**
     * @description Creates mock Individual records for testing
     * @param amount Number of individuals to create
     * @param fieldMap Optional field values to set
     * @return List of Individual records
     */
    public static List<Individual> createIndividuals(Integer amount, Map<String, Object> fieldMap) {
        List<Individual> individuals = new List<Individual>();
        for (Integer i = 0; i < amount; i++) {
            Individual ind = (Individual)mockData('Individual', fieldMap);
            ind.Id = getFakeId('Individual');
            if(ind.LastName == null) {
                ind.LastName = 'Test Individual ' + iter++;
            }
            individuals.add(ind);
        }
        return individuals;
    }

    /**
     * @description Creates mock HealthcarePractitionerFacility records for testing
     * @param amount Number of HealthcarePractitionerFacility records to create
     * @param fieldMap Optional field values to set
     * @return List of HealthcarePractitionerFacility records
     */
    public static List<HealthcarePractitionerFacility> createHealthcarePractitionerFacilities(Integer amount, Map<String, Object> fieldMap) {
        List<HealthcarePractitionerFacility> facilities = new List<HealthcarePractitionerFacility>();
        for (Integer i = 0; i < amount; i++) {
            // Handle null fieldMap by creating an empty map
            Map<String, Object> fields = fieldMap != null ? fieldMap : new Map<String, Object>();
            HealthcarePractitionerFacility facility = (HealthcarePractitionerFacility)mockData('HealthcarePractitionerFacility', fields);
            facility.Id = getFakeId('HealthcarePractitionerFacility');
            if(facility.Name == null) {
                facility.Name = 'Test Healthcare Facility ' + iter++;
            }
            facilities.add(facility);
        }
        return facilities;
    }

    /**
     * @description Creates mock TerritoryAlias__c records for testing
     * @param amount Number of territory alias records to create
     * @param fieldMap Optional field values to set
     * @return List of TerritoryAlias__c records
     */
    public static List<TerritoryAlias__c> createTerritoryAliases(Integer amount, Map<String, Object> fieldMap) {
        List<TerritoryAlias__c> territories = new List<TerritoryAlias__c>();
        for (Integer i = 0; i < amount; i++) {
            TerritoryAlias__c territory = (TerritoryAlias__c)mockData('TerritoryAlias__c', fieldMap);
            territory.Id = getFakeId('TerritoryAlias__c');
            if(territory.Name == null) {
                territory.Name = 'Test Territory ' + iter++;
            }
            territories.add(territory);
        }
        return territories;
    }

    /**
     * @description Creates mock ZipCode__c records for testing
     * @param amount Number of zip code records to create
     * @param fieldMap Optional field values to set
     * @return List of ZipCode__c records
     */
    public static List<ZipCode__c> createZipCodes(Integer amount, Map<String, Object> fieldMap) {
        List<ZipCode__c> zipCodes = new List<ZipCode__c>();
        for (Integer i = 0; i < amount; i++) {
            ZipCode__c zipCode = (ZipCode__c)mockData('ZipCode__c', fieldMap);
            zipCode.Id = getFakeId('ZipCode__c');
            if(zipCode.Name == null) {
                zipCode.Name = String.valueOf(10000 + iter++);
            }
            zipCodes.add(zipCode);
        }
        return zipCodes;
    }

    /**
     * @description Creates a mock PartyRoleRelation record for Patient-Legal Guardian-CCR.
     * No DML - returns in-memory record with fake Id for use in tests that mock or stub.
     * @return PartyRoleRelation with fake Id and standard guardian role fields
     */
    public static PartyRoleRelation createPartyRoleRelation() {
        return createPartyRoleRelation(ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE);
    }

    /**
     * @description Creates a mock PartyRoleRelation record with optional custom name.
     * No DML - returns in-memory record with fake Id.
     * @param name PartyRoleRelation Name (defaults to PATIENT_LEGAL_GUARDIAN_CCR_ROLE if null)
     * @return PartyRoleRelation with fake Id
     */
    public static PartyRoleRelation createPartyRoleRelation(String name) {
        PartyRoleRelation prr = new PartyRoleRelation(
            Name = String.isNotBlank(name) ? name : ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE,
            RoleName = 'Legal Guardian',
            RelatedRoleName = ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME,
            RelationshipObjectName = ConstantsUtil.CONTACT_CONTACT_RELATION
        );
        prr.Id = getFakeId('PartyRoleRelation');
        return prr;
    }

    // End example usage
    
    /**
     * @description Creates a mock SOQL query result structure for testing
     * @param records List of SObject records to include in the mock result
     * @return Map<String, Object> representing a mock SOQL query result with totalSize, done, and records properties
     */
    public static Map<String, Object> mockInnerQuery(List<SObject> records) {
        Map<String, Object> fieldMap = new Map<String, Object>{
            'totalSize' => records.size(),
            'done' => true,
            'records' => records
        };
        return fieldMap;
    }

    /**
     * @description Creates a mock SObject instance with specified field values
     * @param sObjName String name of the SObject type to create
     * @param fieldMap Map of field names to values to set on the mock SObject
     * @return SObject instance of the specified type with the provided field values
     */
    public static SObject mockData(String sObjName, Map<String, Object> fieldMap) {
        return (SObject)JSON.deserialize(JSON.serialize(fieldMap), Type.forName(sObjName));
    }

    /**
     * @description Generates a fake Id for the specified SObject type name
     * @param sObjName String name of the SObject type
     * @return Id fake Id for the specified SObject type
     */
    public static Id getFakeId(String sObjName) {
        return getFakeId(Schema.getGlobalDescribe().get(sObjName));
    }

    /**
     * @description Generates a fake Id for the specified SObject type
     * @param objType Schema.SObjectType representing the SObject type
     * @return Id fake Id for the specified SObject type
     */
    public static Id getFakeId(Schema.SObjectType objType) {
        String result = String.valueOf(iter++);
        return objType.getDescribe().getKeyPrefix() + '0'.repeat(12-result.length()) + result;
    }


}