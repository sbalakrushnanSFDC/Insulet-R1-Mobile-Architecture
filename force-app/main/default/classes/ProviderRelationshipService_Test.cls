/**
 * @description Test class for ProviderRelationshipService
 * @author Sunil Khanchandani
 * @date Oct 10, 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By               Brief Note
 * V1.0.0       10-10-2025          Sunil Khanchandani       Initial Version
 */
@IsTest(IsParallel=true)
public class ProviderRelationshipService_Test {

    @testSetup
    static void setupTestData() {

        PartyRoleRelation partyRoleRelation = new PartyRoleRelation(
            RoleName = 'Patient',
            RelatedRoleName = 'Provider',
            RelationshipObjectName = 'Contact_Contact_Relationship'
        );
        insert partyRoleRelation;

        Account providerAccount = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Provider',
            'LastName' => 'Account'
        });
        insert providerAccount;

        Lead patientLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Related_Provider__c' => providerAccount.Id
        });
        insert patientLead;
    }

    @IsTest
    static void testProcessProviderRelationsWithValidProvider() {
        Lead patientLead = [SELECT Id, Related_Provider__c FROM Lead LIMIT 1];

        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(patientLead.Id);
        lc.setDoNotCreateOpportunity(false);
        lc.setConvertedStatus(convertStatus.MasterLabel);

        Test.startTest();
        Database.convertLead(lc);
        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedContactId, Related_Provider__c FROM Lead WHERE Id = :patientLead.Id];

        ProviderRelationshipService.processProviderRelations(new List<Lead>{ convertedLead }, ConstantsUtil.ASIM_TAG);

        Assert.isNotNull(ProviderRelationshipService.providerLeadsMap, 'Provider leads map should be initialized');
        Assert.areEqual(1, ProviderRelationshipService.providerLeadsMap.size(), 'Should have 1 provider lead');
    }

    @IsTest
    static void testProcessProviderRelationsWithoutProvider() {
        Lead patientLead = TestDataFactory.getLead(new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'LastName' => 'TestLeadWithoutProvider',
            'Email' => 'testleadwithoutprovider@example.com'
        });
        insert patientLead;

        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted=true LIMIT 1];
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(patientLead.Id);
        lc.setDoNotCreateOpportunity(false);
        lc.setConvertedStatus(convertStatus.MasterLabel);

        Test.startTest();
        Database.convertLead(lc);
        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedContactId, Related_Provider__c FROM Lead WHERE Id = :patientLead.Id];

        ProviderRelationshipService.processProviderRelations(new List<Lead>{ convertedLead }, ConstantsUtil.ASIM_TAG);

        Assert.isNotNull(ProviderRelationshipService.providerLeadsMap, 'Provider leads map should be initialized');
        Assert.areEqual(0, ProviderRelationshipService.providerLeadsMap.size(), 'Should have no provider leads');
    }

    @IsTest
    static void testProcessProviderRelationsWithEmptyList() {
        Test.startTest();
        ProviderRelationshipService.processProviderRelations(new List<Lead>(), ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        Assert.isNotNull(ProviderRelationshipService.providerLeadsMap, 'Provider leads map should be initialized');
        Assert.areEqual(0, ProviderRelationshipService.providerLeadsMap.size(), 'Should have no provider leads');
    }
}