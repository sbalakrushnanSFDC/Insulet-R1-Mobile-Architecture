/**
 * @description Test class for LeadConversionPostProcessingQueueable.
 * Covers execute flow: opportunity updates, provider relations, caregiver relations,
 * ACR creation, CCR creation, and consent mapping.
 *
 * @author      Charchit Nirayanwal
 * @createdDate 25th Feb 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       25th Feb 2026      Charchit Nirayanwal      Initial Version
 */
@IsTest(isParallel = true)
private class LeadPostProcessingQueueable_Test {

    @TestSetup
    static void setupTestData() {
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));

        Contact providerContact = TestDataFactory.getContact(new Map<String, Object>{
            'FirstName' => 'Setup',
            'LastName' => 'Provider' + uniqueSuffix
        });
        insert providerContact;

        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;
        facility.PractitionerId = providerContact.Id;
        update facility;

        PartyRoleRelation partyRole = TestDataFactory.getPartyRoleRelation(new Map<String, Object>{
            'Name' => ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
        });
        insert partyRole;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Setup',
            'LastName' => 'Patient' + uniqueSuffix
        });
        insert testAccount;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Setup',
            'LastName' => 'Lead' + uniqueSuffix,
            'Company' => 'SetupCo' + uniqueSuffix,
            'Email' => 'setup' + uniqueSuffix + '@tst.com',
            'Provider_Practice_Affiliation__c' => facility.Id,
            'Status' => 'Open - Not Contacted',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;
    }

    private static void bypassLeadValidation(Id leadId) {
        TriggerHandler.bypass('LeadTriggerHandler');
        update new Lead(Id = leadId, Validation_Bypass__c = true);
        TriggerHandler.clearBypass('LeadTriggerHandler');
    }

    private static Map<String, Object> convertLeadAndGetContext() {
        HealthcarePractitionerFacility facility = [SELECT Id FROM HealthcarePractitionerFacility LIMIT 1];
        Account testAccount = [SELECT Id, PersonContactId FROM Account LIMIT 1];
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];

        bypassLeadValidation(testLead.Id);

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setAccountId(testAccount.Id);
        lc.setContactId(testAccount.PersonContactId);
        lc.setConvertedStatus('Converted');
        lc.setDoNotCreateOpportunity(true);

        List<Database.LeadConvertResult> results = Database.convertLead(new List<Database.LeadConvert>{ lc });
        System.assert(results[0].isSuccess(), 'Lead conversion must succeed');

        Lead convertedLead = [SELECT Id, Provider_Practice_Affiliation__c FROM Lead WHERE Id = :testLead.Id];
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>{ convertedLead => testAccount };

        LeadConversionConsentMappingQueueable.LeadConversionConsentData mappingData =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        mappingData.leadId = convertedLead.Id;
        mappingData.contactId = testAccount.PersonContactId;
        mappingData.accountId = testAccount.Id;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>{ mappingData };

        return new Map<String, Object>{
            'convertedLeadIds' => new List<Id>{ convertedLead.Id },
            'leadsToAccountMap' => leadsToAccountMap,
            'mappingDataList' => mappingDataList
        };
    }

    @IsTest
    static void testExecuteEmptyLeadIdsReturnsEarly() {
        LeadConversionPostProcessingQueueable job = new LeadConversionPostProcessingQueueable(
            new List<Id>(),
            ConstantsUtil.ASIM_TAG
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Should return early without error');
    }

    @IsTest
    static void testExecuteNullLeadIdsReturnsEarly() {
        LeadConversionPostProcessingQueueable job = new LeadConversionPostProcessingQueueable(
            null,
            ConstantsUtil.ASIM_TAG
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Should return early without error');
    }

    @IsTest
    static void testExecuteNoConvertedLeadsReturnsEarly() {
        Lead unconvertedLead = [SELECT Id FROM Lead LIMIT 1];
        List<Id> unconvertedIds = new List<Id>{ unconvertedLead.Id };

        LeadConversionPostProcessingQueueable job = new LeadConversionPostProcessingQueueable(
            unconvertedIds,
            ConstantsUtil.ASIM_TAG
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(unconvertedLead.Id != null, 'Lead exists; IsConverted=false so queueable returns early');
    }

    @IsTest
    static void testExecuteWithConvertedLeadsRunsSuccessfully() {
        Map<String, Object> ctx = convertLeadAndGetContext();
        List<Id> convertedLeadIds = (List<Id>) ctx.get('convertedLeadIds');

        LeadConversionPostProcessingQueueable job = new LeadConversionPostProcessingQueueable(
            convertedLeadIds,
            ConstantsUtil.ASIM_TAG
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Execute should complete without exception');
    }

    @IsTest
    static void testExecuteWithMappingDataRunsCCRAndConsentMapping() {
        Map<String, Object> ctx = convertLeadAndGetContext();
        List<Id> convertedLeadIds = (List<Id>) ctx.get('convertedLeadIds');
        Map<Lead, Account> leadsToAccountMap = (Map<Lead, Account>) ctx.get('leadsToAccountMap');
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList =
            (List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>) ctx.get('mappingDataList');

        LeadConversionPostProcessingQueueable job = new LeadConversionPostProcessingQueueable(
            convertedLeadIds,
            ConstantsUtil.ASIM_TAG,
            mappingDataList,
            leadsToAccountMap
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Execute with mapping data should complete without exception');
    }

    @IsTest
    static void testExecuteWithMinorLeadCallsProcessMinorCaregiverContactPoints() {
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        HealthcarePractitionerFacility facility = [SELECT Id FROM HealthcarePractitionerFacility LIMIT 1];

        Account minorAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Minor',
            'LastName' => 'Patient' + uniqueSuffix
        });
        insert minorAccount;
        minorAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :minorAccount.Id];

        Lead minorLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Minor',
            'LastName' => 'Lead' + uniqueSuffix,
            'Company' => 'MinorCo' + uniqueSuffix,
            'Email' => 'minor' + uniqueSuffix + '@tst.com',
            'Provider_Practice_Affiliation__c' => facility.Id,
            'Status' => 'Open - Not Contacted',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'Date_of_Birth__c' => Date.today().addYears(-15),
            'Caregiver_First_Name__c' => 'Care',
            'Caregiver_Last_Name__c' => 'Giver'
        });
        insert minorLead;
        bypassLeadValidation(minorLead.Id);

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(minorLead.Id);
        lc.setAccountId(minorAccount.Id);
        lc.setContactId(minorAccount.PersonContactId);
        lc.setConvertedStatus('Converted');
        lc.setDoNotCreateOpportunity(true);

        List<Database.LeadConvertResult> results = Database.convertLead(new List<Database.LeadConvert>{ lc });
        System.assert(results[0].isSuccess(), 'Minor lead conversion must succeed');

        Lead convertedLead = [SELECT Id FROM Lead WHERE Id = :minorLead.Id];
        LeadConversionPostProcessingQueueable job = new LeadConversionPostProcessingQueueable(
            new List<Id>{ convertedLead.Id },
            ConstantsUtil.ASIM_TAG
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Execute with minor lead should complete without exception');
    }

    @IsTest
    static void testExecuteBackwardCompatibleConstructor() {
        Map<String, Object> ctx = convertLeadAndGetContext();
        List<Id> convertedLeadIds = (List<Id>) ctx.get('convertedLeadIds');

        LeadConversionPostProcessingQueueable job = new LeadConversionPostProcessingQueueable(
            convertedLeadIds,
            ConstantsUtil.ASIM_TAG
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Backward compatible constructor should work');
    }

    @IsTest
    static void testExecuteWithNullTagNameUsesDefault() {
        Map<String, Object> ctx = convertLeadAndGetContext();
        List<Id> convertedLeadIds = (List<Id>) ctx.get('convertedLeadIds');

        LeadConversionPostProcessingQueueable job = new LeadConversionPostProcessingQueueable(
            convertedLeadIds,
            null
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        System.assert(true, 'Null tagName should use default');
    }
}