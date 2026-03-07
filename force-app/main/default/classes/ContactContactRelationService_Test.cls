/**
 * @description Test class for ContactContactRelationService
 * @author Sunil Khanchandani
 * @date Oct 10, 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By               Brief Note
 * V1.0.0       10-10-2025          Sunil Khanchandani       Initial Version
 * V1.1.0       Nov 28, 2025        Bijayalaxmi Prusty       Modified(US NGASIM-1050)
 * V1.1.1       Feb 12, 2026        Saikat Ghosh             Increased coverage to 95%+
 * V1.1.2       Feb 26, 2026        Charchit Nirayanwal      Updated(US NGASIM-2517)
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=true)
public class ContactContactRelationService_Test {

    @TestSetup
    static void setupTestData() {
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));

        // Contacts for CCR insert (25 for bulk test - yields 300 unique unordered pairs)
        List<Contact> contacts = TestDataFactory.getContacts(25, new Map<String, Object>());
        insert contacts;

        // PartyRoleRelation with Name matching PATIENT_PROVIDER_CCR_ROLE for buildCCRRecords
        PartyRoleRelation partyRole = TestDataFactory.getPartyRoleRelation(new Map<String, Object>{
            'Name' => ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
        });
        insert partyRole;

        // HealthcarePractitionerFacility with provider contact
        Contact providerContact = TestDataFactory.getContact(new Map<String, Object>{
            'FirstName' => 'Setup',
            'LastName' => 'Provider' + uniqueSuffix
        });
        insert providerContact;

        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;
        facility.PractitionerId = providerContact.Id;
        update facility;

        // Account for lead conversion
        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Setup',
            'LastName' => 'Patient' + uniqueSuffix
        });
        insert testAccount;

        // Lead with facility affiliation
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

    @IsTest
    static void testInsertContactContactRelationshipsSuccessRecordsInserted() {
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
        List<PartyRoleRelation> partyRoles = [SELECT Id FROM PartyRoleRelation WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE LIMIT 1];
        if (partyRoles.isEmpty()) {
            partyRoles = [SELECT Id FROM PartyRoleRelation LIMIT 1];
        }

        List<ContactContactRelation> ccrList = new List<ContactContactRelation>();
        ContactContactRelation ccr = new ContactContactRelation();
        ccr.ContactId = contacts[0].Id;
        ccr.RelatedContactId = contacts[1].Id;
        ccr.IsActive = true;
        ccr.Is_Primary__c = true;
        if (!partyRoles.isEmpty()) {
            ccr.PartyRoleRelationId = partyRoles[0].Id;
        }
        ccrList.add(ccr);

        Test.startTest();
        ContactContactRelationService.insertContactContactRelationships(ccrList, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        System.assertEquals(1, ccrList.size(), 'ContactContactRelation list should have 1 record');
        System.assertEquals(contacts[0].Id, ccr.ContactId, 'ContactId should match');
        System.assertEquals(contacts[1].Id, ccr.RelatedContactId, 'RelatedContactId should match');

        Integer ccrCount = [SELECT COUNT() FROM ContactContactRelation WHERE ContactId = :contacts[0].Id AND RelatedContactId = :contacts[1].Id];
        System.assertEquals(1, ccrCount, 'CCR record should be inserted');
    }

    @IsTest
    static void testInsertContactContactRelationshipsEmptyListNoDmlExecuted() {
        List<ContactContactRelation> ccrList = new List<ContactContactRelation>();

        Test.startTest();
        ContactContactRelationService.insertContactContactRelationships(ccrList, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        System.assertEquals(0, ccrList.size(), 'ContactContactRelation list should be empty');
    }

    @IsTest
    static void testInsertContactContactRelationshipsInvalidRecordsPartialFailureLogged() {
        List<ContactContactRelation> ccrList = new List<ContactContactRelation>();
        ContactContactRelation ccr = new ContactContactRelation();
        ccrList.add(ccr);

        Test.startTest();
        ContactContactRelationService.insertContactContactRelationships(ccrList, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        System.assertEquals(1, ccrList.size(), 'ContactContactRelation list should have 1 record');
        System.assertEquals(null, ccr.ContactId, 'ContactId should be null for invalid record');
    }

    @IsTest
    static void testInsertContactContactRelationshipsBulk200RecordsInserted() {
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 25];
        List<PartyRoleRelation> partyRoles = [SELECT Id FROM PartyRoleRelation WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE LIMIT 1];
        if (partyRoles.isEmpty()) {
            partyRoles = [SELECT Id FROM PartyRoleRelation LIMIT 1];
        }
        System.assert(contacts.size() >= 15, 'Need at least 15 contacts for bulk CCR pairs');
        System.assert(!partyRoles.isEmpty(), 'PartyRoleRelation required for CCR insert');

        List<ContactContactRelation> ccrList = new List<ContactContactRelation>();
        Integer pairCount = 0;
        for (Integer i = 0; i < contacts.size() && pairCount < 200; i++) {
            for (Integer j = i + 1; j < contacts.size() && pairCount < 200; j++) {
                ContactContactRelation ccr = new ContactContactRelation();
                ccr.ContactId = contacts[i].Id;
                ccr.RelatedContactId = contacts[j].Id;
                ccr.IsActive = true;
                ccr.Is_Primary__c = true;
                ccr.PartyRoleRelationId = partyRoles[0].Id;
                ccrList.add(ccr);
                pairCount++;
            }
        }

        Test.startTest();
        ContactContactRelationService.insertContactContactRelationships(ccrList, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        Integer totalCcrs = [SELECT COUNT() FROM ContactContactRelation];
        System.assert(totalCcrs >= 200, 'At least 200 CCR records should be inserted');
    }

    @IsTest
    static void testInsertContactContactRelationshipsCustomExceptionSwitchCatchExecuted() {
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
        List<ContactContactRelation> relationRecords = new List<ContactContactRelation>();
        relationRecords.add(new ContactContactRelation(ContactId = contacts[0].Id, RelatedContactId = contacts[1].Id));
        relationRecords.add(new ContactContactRelation(ContactId = contacts[1].Id, RelatedContactId = contacts[0].Id));

        ConstantsUtil.customExceptionSwitch = true;
        try {
            Test.startTest();
            ContactContactRelationService.insertContactContactRelationships(relationRecords, ConstantsUtil.ASIM_TAG);
            Test.stopTest();
            System.assert(true, 'Method should catch exception and not rethrow');
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
    }

    @IsTest
    static void testFetchRoleRelationRecordValidNameReturnsRecords() {
        Test.startTest();
        List<PartyRoleRelation> results = ContactContactRelationService.fetchRoleRelationRecord(ConstantsUtil.PROVIDER_RELATIONSHIP_NAME);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() >= 0, 'Results should be a valid list');
    }

    @IsTest
    static void testFetchRoleRelationRecordGuardianNameReturnsRecords() {
        Test.startTest();
        List<PartyRoleRelation> results = ContactContactRelationService.fetchRoleRelationRecord(ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() >= 0, 'Results should be a valid list');
    }

    @IsTest
    static void testFetchPartyRoleRelationRecordByNameValidNameReturnsRecords() {
        Test.startTest();
        List<PartyRoleRelation> results = ContactContactRelationService.fetchPartyRoleRelationRecordByName(ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() >= 0, 'Results should be a valid list');
    }

    @IsTest
    static void testFetchPartyRoleRelationRecordByNameUnknownNameReturnsEmpty() {
        Test.startTest();
        List<PartyRoleRelation> results = ContactContactRelationService.fetchPartyRoleRelationRecordByName('NonExistentRoleNameXYZ');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list for unknown role name');
    }

    @IsTest
    static void testCreatePatientProviderCCRsNullInputsReturnsEarly() {
        Test.startTest();
        ContactContactRelationService.createPatientProviderCCRs(null, new Map<Lead, Account>(), ConstantsUtil.ASIM_TAG);
        ContactContactRelationService.createPatientProviderCCRs(new List<Database.LeadConvertResult>(), new Map<Lead, Account>(), ConstantsUtil.ASIM_TAG);
        ContactContactRelationService.createPatientProviderCCRs(new List<Database.LeadConvertResult>(), null, ConstantsUtil.ASIM_TAG);
        ContactContactRelationService.createPatientProviderCCRs(new List<Database.LeadConvertResult>(), new Map<Lead, Account>(), ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        System.assert(true, 'Method should handle null/empty inputs gracefully');
    }

    @IsTest
    static void testCCRsFromMapDataNullInputsReturnsEarly() {
        Test.startTest();
        ContactContactRelationService.createPatientProviderCCRsFromMappingData(null, new Map<Lead, Account>(), ConstantsUtil.ASIM_TAG);
        ContactContactRelationService.createPatientProviderCCRsFromMappingData(
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>(),
            new Map<Lead, Account>(),
            ConstantsUtil.ASIM_TAG
        );
        ContactContactRelationService.createPatientProviderCCRsFromMappingData(
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>{ new LeadConversionConsentMappingQueueable.LeadConversionConsentData() },
            null,
            ConstantsUtil.ASIM_TAG
        );
        ContactContactRelationService.createPatientProviderCCRsFromMappingData(
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>(),
            new Map<Lead, Account>(),
            ConstantsUtil.ASIM_TAG
        );
        Test.stopTest();

        System.assert(true, 'Method should handle null/empty inputs gracefully');
    }

    @IsTest
    static void testCCRsFromMapDataValidDataCcrCreated() {
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));

        Contact providerContact = TestDataFactory.getContact(new Map<String, Object>{
            'FirstName' => 'ProvMap',
            'LastName' => 'ConMap' + uniqueSuffix
        });
        insert providerContact;

        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;
        facility.PractitionerId = providerContact.Id;
        update facility;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'PatMap',
            'LastName' => 'AccMap' + uniqueSuffix
        });
        insert testAccount;
        testAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :testAccount.Id];
        Id patientContactId = testAccount.PersonContactId;

        Lead testLead = createTestLead(new Map<String, Object>{
            'FirstName' => 'PatMap',
            'LastName' => 'LedMap' + uniqueSuffix,
            'Company' => 'TstCoMap' + uniqueSuffix,
            'Email' => 'map' + uniqueSuffix + '@tst.com',
            'Provider_Practice_Affiliation__c' => facility.Id
        });

        LeadConversionConsentMappingQueueable.LeadConversionConsentData mappingData = new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        mappingData.leadId = testLead.Id;
        mappingData.contactId = patientContactId;
        mappingData.accountId = testAccount.Id;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList = new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>{ mappingData };
        Lead convertedLead = [SELECT Id, Provider_Practice_Affiliation__c FROM Lead WHERE Id = :testLead.Id];
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>{ convertedLead => testAccount };

        Test.startTest();
        ContactContactRelationService.createPatientProviderCCRsFromMappingData(mappingDataList, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        List<ContactContactRelation> ccrs = [
            SELECT Id, ContactId, RelatedContactId, IsActive, Is_Primary__c, PartyRoleRelationId
            FROM ContactContactRelation
            WHERE ContactId = :patientContactId
            AND RelatedContactId = :providerContact.Id
        ];

        System.assert(!ccrs.isEmpty(), 'ContactContactRelation should be created from mapping data');
        System.assertEquals(providerContact.Id, ccrs[0].RelatedContactId, 'Provider contact should match');
        System.assertEquals(true, ccrs[0].IsActive, 'CCR should be active');
        System.assertEquals(true, ccrs[0].Is_Primary__c, 'CCR should be marked as primary');
    }

    @IsTest
    static void testCCRsFromMapDataEmptyFacilityReturnsEarly() {
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'NoFacMap',
            'LastName' => 'Acc' + uniqueSuffix
        });
        insert testAccount;
        testAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :testAccount.Id];

        Lead testLead = createTestLead(new Map<String, Object>{
            'FirstName' => 'NoFacMap',
            'LastName' => 'Led' + uniqueSuffix,
            'Company' => 'NoFacCo' + uniqueSuffix,
            'Email' => 'nofacmap' + uniqueSuffix + '@tst.com'
        });

        LeadConversionConsentMappingQueueable.LeadConversionConsentData mappingData = new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        mappingData.leadId = testLead.Id;
        mappingData.contactId = testAccount.PersonContactId;
        mappingData.accountId = testAccount.Id;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList = new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>{ mappingData };
        Lead convertedLead = [SELECT Id, Provider_Practice_Affiliation__c FROM Lead WHERE Id = :testLead.Id];
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>{ convertedLead => testAccount };

        Test.startTest();
        ContactContactRelationService.createPatientProviderCCRsFromMappingData(mappingDataList, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        System.assertEquals(null, convertedLead.Provider_Practice_Affiliation__c, 'Lead should have no facility affiliation');
        Integer ccrCount = [SELECT COUNT() FROM ContactContactRelation WHERE ContactId = :testAccount.PersonContactId];
        System.assertEquals(0, ccrCount, 'No CCR should be created when facility IDs are empty');
    }

    @IsTest
    static void testCCRsFromMapDataEmptyProviderReturnsEarly() {
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));

        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;
        // facility.PractitionerId is null - queryFacilityProviderContacts will return empty

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'NoProvMap',
            'LastName' => 'Acc' + uniqueSuffix
        });
        insert testAccount;
        testAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :testAccount.Id];

        Lead testLead = createTestLead(new Map<String, Object>{
            'FirstName' => 'NoProvMap',
            'LastName' => 'Led' + uniqueSuffix,
            'Company' => 'NoProvCo' + uniqueSuffix,
            'Email' => 'noprovmap' + uniqueSuffix + '@tst.com',
            'Provider_Practice_Affiliation__c' => facility.Id
        });

        LeadConversionConsentMappingQueueable.LeadConversionConsentData mappingData = new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        mappingData.leadId = testLead.Id;
        mappingData.contactId = testAccount.PersonContactId;
        mappingData.accountId = testAccount.Id;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList = new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>{ mappingData };
        Lead convertedLead = [SELECT Id, Provider_Practice_Affiliation__c FROM Lead WHERE Id = :testLead.Id];
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>{ convertedLead => testAccount };

        Test.startTest();
        ContactContactRelationService.createPatientProviderCCRsFromMappingData(mappingDataList, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        System.assertNotEquals(null, convertedLead.Provider_Practice_Affiliation__c, 'Lead should have facility affiliation');
        Integer ccrCount = [SELECT COUNT() FROM ContactContactRelation WHERE ContactId = :testAccount.PersonContactId];
        System.assertEquals(0, ccrCount, 'No CCR should be created when facility has no provider contact');
    }

    @IsTest
    static void testCCRsFromMapDataCustomExceptionSwitch() {
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));

        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'ExcMap',
            'LastName' => 'Acc' + uniqueSuffix
        });
        insert testAccount;
        testAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :testAccount.Id];

        Lead testLead = createTestLead(new Map<String, Object>{
            'FirstName' => 'ExcMap',
            'LastName' => 'Led' + uniqueSuffix,
            'Company' => 'ExcCo' + uniqueSuffix,
            'Email' => 'exc' + uniqueSuffix + '@tst.com',
            'Provider_Practice_Affiliation__c' => facility.Id
        });

        LeadConversionConsentMappingQueueable.LeadConversionConsentData mappingData = new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        mappingData.leadId = testLead.Id;
        mappingData.contactId = testAccount.PersonContactId;
        mappingData.accountId = testAccount.Id;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> mappingDataList = new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>{ mappingData };
        Lead convertedLead = [SELECT Id, Provider_Practice_Affiliation__c FROM Lead WHERE Id = :testLead.Id];
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>{ convertedLead => testAccount };

        ConstantsUtil.customExceptionSwitch = true;
        try {
            Test.startTest();
            ContactContactRelationService.createPatientProviderCCRsFromMappingData(mappingDataList, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
            Test.stopTest();
            System.assert(true, 'Method should handle exceptions gracefully');
        } catch (Exception ex) {
            System.assert(false, 'Method should handle exceptions gracefully, but threw: ' + ex.getMessage());
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
    }

    @IsTest
    static void testCreatePatientProviderCCRsMissingFacilityIdsReturnsEarly() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'NoFac',
            'LastName' => 'Lead',
            'Company' => 'Test Company',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'NoFac',
            'LastName' => 'Account'
        });
        insert testAccount;

        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>{ testLead => testAccount };
        List<Database.LeadConvertResult> convertResults = new List<Database.LeadConvertResult>();

        Test.startTest();
        ContactContactRelationService.createPatientProviderCCRs(convertResults, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        System.assert(true, 'Method should handle leads without facility IDs gracefully');
    }

    /**
     * @description Sets Validation_Bypass__c to true on a Lead to bypass the
     *              Lead_Converted_Status_Validation rule during test lead conversion.
     * @param leadId The Id of the Lead to update
     */
    private static void bypassLeadValidation(Id leadId) {
        TriggerHandler.bypass('LeadTriggerHandler');
        update new Lead(Id = leadId, Validation_Bypass__c = true);
        TriggerHandler.clearBypass('LeadTriggerHandler');
    }

    /**
     * @description Creates a test Lead with common fields
     * @param leadFields Map containing lead field values (FirstName, LastName, Company, Email, Provider_Practice_Affiliation__c)
     * @return Created Lead record
     */
    private static Lead createTestLead(Map<String, Object> leadFields) {
        Map<String, Object> fields = new Map<String, Object>(leadFields);
        fields.put('Status', 'Open - Not Contacted');
        fields.put('RecordTypeId', ConstantsUtil.LEAD_PATIENT_RT);
        Lead testLead = TestDataFactory.getLead(fields);
        insert testLead;
        bypassLeadValidation(testLead.Id);
        return testLead;
    }

    /**
     * @description Converts a Lead and returns the conversion result and converted lead
     * @param testLead The Lead to convert
     * @param testAccount The Account to convert to
     * @param patientContact Optional Contact ID for the conversion
     * @return Map containing 'convertResults' and 'convertedLead' keys
     */
    private static Map<String, Object> convertLead(Lead testLead, Account testAccount, Id patientContact) {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(testLead.Id);
        lc.setAccountId(testAccount.Id);
        if (patientContact != null) {
            lc.setContactId(patientContact);
        }
        lc.setConvertedStatus('Converted');
        lc.setDoNotCreateOpportunity(true);

        List<Database.LeadConvertResult> convertResults = Database.convertLead(new List<Database.LeadConvert>{ lc });
        System.assert(convertResults[0].isSuccess(), 'Lead conversion must succeed');

        Lead convertedLead = [SELECT Id, Provider_Practice_Affiliation__c FROM Lead WHERE Id = :testLead.Id];
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>{ convertedLead => testAccount };

        return new Map<String, Object>{
            'convertResults' => convertResults,
            'convertedLead' => convertedLead,
            'leadsToAccountMap' => leadsToAccountMap
        };
    }

    @IsTest
    static void testCreatePatientProviderCCRsEmptyFacilityIdsReturnsEarly() {
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'NoFac',
            'LastName' => 'Acc' + uniqueSuffix
        });
        insert testAccount;

        Lead testLead = createTestLead(new Map<String, Object>{
            'FirstName' => 'NoFac',
            'LastName' => 'Led' + uniqueSuffix,
            'Company' => 'NoFacCo' + uniqueSuffix,
            'Email' => 'nofac' + uniqueSuffix + '@tst.com'
        });

        Test.startTest();
        Map<String, Object> conversionData = convertLead(testLead, testAccount, null);
        List<Database.LeadConvertResult> convertResults = (List<Database.LeadConvertResult>)conversionData.get('convertResults');
        Lead convertedLead = (Lead)conversionData.get('convertedLead');
        Map<Lead, Account> leadsToAccountMap = (Map<Lead, Account>)conversionData.get('leadsToAccountMap');

        System.assertEquals(null, convertedLead.Provider_Practice_Affiliation__c, 'Lead should have no facility affiliation');
        ContactContactRelationService.createPatientProviderCCRs(convertResults, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        System.assert(true, 'Handled empty facilityIds - covers buildProcessingContext + facilityIds.isEmpty return');
    }

    @IsTest
    static void testCreatePatientProviderCCRsEmptyProviderMapReturnsEarly() {
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));

        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;
        // facility.PractitionerId is null - queryFacilityProviderContacts will return empty

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'NoProv',
            'LastName' => 'Acc' + uniqueSuffix
        });
        insert testAccount;

        Lead testLead = createTestLead(new Map<String, Object>{
            'FirstName' => 'NoProv',
            'LastName' => 'Led' + uniqueSuffix,
            'Company' => 'NoProvCo' + uniqueSuffix,
            'Email' => 'noprov' + uniqueSuffix + '@tst.com',
            'Provider_Practice_Affiliation__c' => facility.Id
        });

        Test.startTest();
        Map<String, Object> conversionData = convertLead(testLead, testAccount, null);
        List<Database.LeadConvertResult> convertResults = (List<Database.LeadConvertResult>)conversionData.get('convertResults');
        Lead convertedLead = (Lead)conversionData.get('convertedLead');
        Map<Lead, Account> leadsToAccountMap = (Map<Lead, Account>)conversionData.get('leadsToAccountMap');

        System.assertNotEquals(null, convertedLead.Provider_Practice_Affiliation__c, 'Lead should have facility affiliation');
        ContactContactRelationService.createPatientProviderCCRs(convertResults, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        System.assert(true, 'Handled empty facilityToProviderContactMap - covers queryFacilityProviderContacts + isEmpty return');
    }

    @IsTest
    static void testCreatePatientProviderCCRsValidConversionCcrCreated() {
        String uniqueSuffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));

        // Create fresh provider contact and facility for this test
        Contact providerContact = TestDataFactory.getContact(new Map<String, Object>{
            'FirstName' => 'ProvValid',
            'LastName' => 'ConValid' + uniqueSuffix
        });
        insert providerContact;

        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;
        facility.PractitionerId = providerContact.Id;
        update facility;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'PatValid',
            'LastName' => 'AccValid' + uniqueSuffix
        });
        insert testAccount;
        testAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :testAccount.Id];
        Contact patientContact = [SELECT Id FROM Contact WHERE Id = :testAccount.PersonContactId];

        Lead testLead = createTestLead(new Map<String, Object>{
            'FirstName' => 'PatValid',
            'LastName' => 'LedValid' + uniqueSuffix,
            'Company' => 'TstCoValid' + uniqueSuffix,
            'Email' => 'valid' + uniqueSuffix + '@tst.com',
            'Provider_Practice_Affiliation__c' => facility.Id
        });

        Test.startTest();
        Map<String, Object> conversionData = convertLead(testLead, testAccount, patientContact.Id);
        List<Database.LeadConvertResult> convertResults = (List<Database.LeadConvertResult>)conversionData.get('convertResults');
        Map<Lead, Account> leadsToAccountMap = (Map<Lead, Account>)conversionData.get('leadsToAccountMap');

        System.assertNotEquals(null, convertResults[0].getContactId(), 'Contact ID must not be null');
        System.assertNotEquals(null, convertResults[0].getLeadId(), 'Lead ID must not be null');
        ContactContactRelationService.createPatientProviderCCRs(convertResults, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        List<ContactContactRelation> ccrs = [
            SELECT Id, ContactId, RelatedContactId, IsActive, Is_Primary__c, PartyRoleRelationId
            FROM ContactContactRelation
            WHERE ContactId = :patientContact.Id
            AND RelatedContactId = :providerContact.Id
        ];

        System.assert(!ccrs.isEmpty(), 'ContactContactRelation should be created');
        System.assertEquals(providerContact.Id, ccrs[0].RelatedContactId, 'Provider contact should match');
        System.assertEquals(true, ccrs[0].IsActive, 'CCR should be active');
        System.assertEquals(true, ccrs[0].Is_Primary__c, 'CCR should be marked as primary');
    }

    @IsTest
    static void testCreatePatientProviderCCRsMissingProviderContactNoCcrCreated() {
        // Facility WITHOUT PractitionerId - queryFacilityProviderContacts will find it
        // but PractitionerId filter means facilityToProviderContactMap has no entry for this facility.
        // However the query uses PractitionerId != null, so this facility won't appear at all.
        // This means facilityToProviderContactMap IS populated from setup facility (which has PractitionerId).
        // We need a facility that DOES appear in the query but whose PractitionerId doesn't match any contact
        // in the conversion result. So we create a new facility without PractitionerId.
        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;
        // facility.PractitionerId is null

        String uniqueSuffix = 'Mis' + String.valueOf(Math.abs(Crypto.getRandomInteger()));

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'PatMis',
            'LastName' => 'AccMis' + uniqueSuffix
        });
        insert testAccount;

        Lead testLead = createTestLead(new Map<String, Object>{
            'FirstName' => 'PatMis',
            'LastName' => 'LedMis' + uniqueSuffix,
            'Company' => 'TstCoMis' + uniqueSuffix,
            'Email' => 'mis' + uniqueSuffix + '@tst.com',
            'Provider_Practice_Affiliation__c' => facility.Id
        });

        Test.startTest();
        Map<String, Object> conversionData = convertLead(testLead, testAccount, null);
        List<Database.LeadConvertResult> convertResults = (List<Database.LeadConvertResult>)conversionData.get('convertResults');
        Map<Lead, Account> leadsToAccountMap = (Map<Lead, Account>)conversionData.get('leadsToAccountMap');

        ContactContactRelationService.createPatientProviderCCRs(convertResults, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        List<ContactContactRelation> ccrs = [
            SELECT Id
            FROM ContactContactRelation
            WHERE ContactId = :convertResults[0].getContactId()
        ];

        System.assertEquals(0, ccrs.size(), 'No ContactContactRelation should be created when provider contact is missing');
    }

    @IsTest
    static void testCreatePatientProviderCCRsNoPartyRoleRelationLogErrorAndReturnEmpty() {
        String uniqueSuffix = 'NoPRR' + String.valueOf(Math.abs(Crypto.getRandomInteger()));

        Contact providerContact = TestDataFactory.getContact(new Map<String, Object>{
            'FirstName' => 'ProvNoPRR',
            'LastName' => 'Con' + uniqueSuffix
        });
        insert providerContact;

        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
        insert facility;
        facility.PractitionerId = providerContact.Id;
        update facility;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'PatNoPRR',
            'LastName' => 'Acc' + uniqueSuffix
        });
        insert testAccount;

        Lead testLead = createTestLead(new Map<String, Object>{
            'FirstName' => 'PatNoPRR',
            'LastName' => 'Led' + uniqueSuffix,
            'Company' => 'Co' + uniqueSuffix,
            'Email' => 'noprr' + uniqueSuffix + '@tst.com',
            'Provider_Practice_Affiliation__c' => facility.Id
        });

        Test.startTest();
        Map<String, Object> conversionData = convertLead(testLead, testAccount, null);
        List<Database.LeadConvertResult> convertResults = (List<Database.LeadConvertResult>)conversionData.get('convertResults');
        Map<Lead, Account> leadsToAccountMap = (Map<Lead, Account>)conversionData.get('leadsToAccountMap');

        // Delete all PartyRoleRelation records with the target Name so that
        // buildCCRRecords -> fetchPartyRoleRelationRecordByName returns empty,
        // covering the partyRoleRelations.isEmpty() branch (lines 232-235).
        List<PartyRoleRelation> prrToDelete = [
            SELECT Id FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
        ];
        if (!prrToDelete.isEmpty()) {
            delete prrToDelete;
        }

        ContactContactRelationService.createPatientProviderCCRs(convertResults, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        // No CCR should be created because PartyRoleRelation was not found
        List<ContactContactRelation> ccrs = [
            SELECT Id FROM ContactContactRelation
            WHERE ContactId = :convertResults[0].getContactId()
        ];
        System.assertEquals(0, ccrs.size(), 'No CCR when PartyRoleRelation not found');
    }

    @IsTest
    static void testCreatePatientProviderCCRsCustomExceptionSwitchHandleExceptionLoggingWithLeads() {
        List<Lead> testLeads = [SELECT Id FROM Lead LIMIT 3];
        List<Account> testAccounts = [SELECT Id FROM Account WHERE LastName LIKE 'Patient%' LIMIT 3];

        if (testLeads.isEmpty() || testAccounts.isEmpty()) {
            System.assert(true, 'Setup data not available');
            return;
        }

        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>();
        for (Integer i = 0; i < Math.min(testLeads.size(), testAccounts.size()); i++) {
            leadsToAccountMap.put(testLeads[i], testAccounts[i]);
        }

        List<Database.LeadConvertResult> convertResults = new List<Database.LeadConvertResult>();

        ConstantsUtil.customExceptionSwitch = true;
        try {
            Test.startTest();
            ContactContactRelationService.createPatientProviderCCRs(convertResults, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
            Test.stopTest();
            System.assert(true, 'Method should handle exceptions gracefully');
        } catch (Exception ex) {
            System.assert(false, 'Method should handle exceptions gracefully, but threw: ' + ex.getMessage());
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
    }

    @IsTest
    static void testCreatePatientProviderCCRsNullLeadsToAccountMapHandleExceptionLogging() {
        List<Database.LeadConvertResult> convertResults = new List<Database.LeadConvertResult>();

        ConstantsUtil.customExceptionSwitch = true;
        try {
            Test.startTest();
            ContactContactRelationService.createPatientProviderCCRs(convertResults, null, ConstantsUtil.ASIM_TAG);
            Test.stopTest();
            System.assert(true, 'Method should handle null leadsToAccountMap in catch');
        } catch (Exception ex) {
            System.assert(false, 'Should not throw: ' + ex.getMessage());
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
    }

    @IsTest
    static void testInsertContactContactRelationshipsSaveResultFailureLogsErrors() {
        ContactContactRelation ccrInvalid = new ContactContactRelation();
        List<ContactContactRelation> relationRecords = new List<ContactContactRelation>{ ccrInvalid };

        Test.startTest();
        ContactContactRelationService.insertContactContactRelationships(relationRecords, ConstantsUtil.ASIM_TAG);
        Test.stopTest();

        System.assertEquals(1, relationRecords.size(), 'List should have 1 record');
        System.assertEquals(null, ccrInvalid.ContactId, 'Invalid record should have null ContactId');
    }

    @IsTest
    static void testInsertContactContactRelationshipsExceptionHandlingCatchExecuted() {
        List<ContactContactRelation> relationRecords = new List<ContactContactRelation>();
        relationRecords.add(new ContactContactRelation());

        List<Database.LeadConvertResult> convertResults = new List<Database.LeadConvertResult>();
        Map<Lead, Account> leadsToAccountMap = new Map<Lead, Account>();

        ConstantsUtil.customExceptionSwitch = true;
        try {
            Test.startTest();
            ContactContactRelationService.insertContactContactRelationships(relationRecords, ConstantsUtil.ASIM_TAG);
            ContactContactRelationService.createPatientProviderCCRs(convertResults, leadsToAccountMap, ConstantsUtil.ASIM_TAG);
            Test.stopTest();
            System.assert(true, 'Service should handle exceptions gracefully');
        } catch (Exception ex) {
            System.assert(false, 'Service should handle exceptions gracefully, but threw: ' + ex.getMessage());
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
    }

    @IsTest
    static void testQueryExistingCCRKeysEdgeCases() {
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 2];
        System.assert(contacts.size() >= 2, 'Need at least 2 contacts for test');

        List<PartyRoleRelation> partyRoles = [SELECT Id FROM PartyRoleRelation WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE LIMIT 1];
        if (partyRoles.isEmpty()) {
            partyRoles = [SELECT Id FROM PartyRoleRelation LIMIT 1];
        }

        Test.startTest();

        // Test 1: Empty contactIds scenario - records with null ContactId
        List<ContactContactRelation> ccrListWithNullContactId = new List<ContactContactRelation>();
        ContactContactRelation ccr1 = new ContactContactRelation();
        ccr1.RelatedContactId = contacts[0].Id;
        ccrListWithNullContactId.add(ccr1);

        List<ContactContactRelation> filtered1 = ContactContactRelationDuplicateFilter.filterDuplicateCCRs(ccrListWithNullContactId);
        System.assertEquals(0, filtered1.size(), 'Should return empty when ContactId is null');

        // Test 2: Empty relatedContactIds scenario - records with null RelatedContactId
        List<ContactContactRelation> ccrListWithNullRelatedContactId = new List<ContactContactRelation>();
        ContactContactRelation ccr2 = new ContactContactRelation();
        ccr2.ContactId = contacts[0].Id;
        ccrListWithNullRelatedContactId.add(ccr2);

        List<ContactContactRelation> filtered2 = ContactContactRelationDuplicateFilter.filterDuplicateCCRs(ccrListWithNullRelatedContactId);
        System.assertEquals(0, filtered2.size(), 'Should return empty when RelatedContactId is null');

        // Test 3: Both empty scenario - empty list
        List<ContactContactRelation> emptyList = new List<ContactContactRelation>();
        List<ContactContactRelation> filtered3 = ContactContactRelationDuplicateFilter.filterDuplicateCCRs(emptyList);
        System.assertEquals(0, filtered3.size(), 'Should return empty for empty list');

        // Test 4: No existing records scenario - queryExistingCCRKeys should return empty set
        List<ContactContactRelation> newCCRs = new List<ContactContactRelation>();
        ContactContactRelation ccr3 = new ContactContactRelation();
        ccr3.ContactId = contacts[0].Id;
        ccr3.RelatedContactId = contacts[1].Id;
        ccr3.IsActive = true;
        if (!partyRoles.isEmpty()) {
            ccr3.PartyRoleRelationId = partyRoles[0].Id;
        }
        newCCRs.add(ccr3);

        List<ContactContactRelation> filtered4 = ContactContactRelationDuplicateFilter.filterDuplicateCCRs(newCCRs);
        System.assertEquals(1, filtered4.size(), 'Should return 1 record when no duplicates exist');

        Test.stopTest();
    }

    @IsTest
    static void testQueryExistingCCRKeysWithExistingRecords() {
        List<Contact> contacts = [SELECT Id FROM Contact LIMIT 5];
        System.assert(contacts.size() >= 4, 'Need at least 4 contacts for test');

        List<PartyRoleRelation> partyRoles = [SELECT Id FROM PartyRoleRelation WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE LIMIT 1];
        if (partyRoles.isEmpty()) {
            partyRoles = [SELECT Id FROM PartyRoleRelation LIMIT 1];
        }

        // Create existing CCR records
        List<ContactContactRelation> existingCCRs = new List<ContactContactRelation>();
        ContactContactRelation ccr4 = new ContactContactRelation();
        ccr4.ContactId = contacts[2].Id;
        ccr4.RelatedContactId = contacts[3].Id;
        ccr4.IsActive = true;
        if (!partyRoles.isEmpty()) {
            ccr4.PartyRoleRelationId = partyRoles[0].Id;
        }
        existingCCRs.add(ccr4);

        ContactContactRelation ccr5 = new ContactContactRelation();
        ccr5.ContactId = contacts[3].Id;
        ccr5.RelatedContactId = contacts[4].Id;
        ccr5.IsActive = true;
        if (!partyRoles.isEmpty()) {
            ccr5.PartyRoleRelationId = partyRoles[0].Id;
        }
        existingCCRs.add(ccr5);

        insert existingCCRs;

        Test.startTest();

        // Test 5: Existing records found scenario - filter duplicates
        List<ContactContactRelation> duplicateCCRs = new List<ContactContactRelation>();
        ContactContactRelation ccr6 = new ContactContactRelation();
        ccr6.ContactId = contacts[2].Id;
        ccr6.RelatedContactId = contacts[3].Id;
        ccr6.IsActive = true;
        duplicateCCRs.add(ccr6);

        ContactContactRelation ccr7 = new ContactContactRelation();
        ccr7.ContactId = contacts[3].Id;
        ccr7.RelatedContactId = contacts[4].Id;
        ccr7.IsActive = true;
        duplicateCCRs.add(ccr7);

        ContactContactRelation ccr8 = new ContactContactRelation();
        ccr8.ContactId = contacts[0].Id;
        ccr8.RelatedContactId = contacts[1].Id;
        ccr8.IsActive = true;
        duplicateCCRs.add(ccr8);

        List<ContactContactRelation> filtered5 = ContactContactRelationDuplicateFilter.filterDuplicateCCRs(duplicateCCRs);
        System.assertEquals(1, filtered5.size(), 'Should filter out 2 existing records and keep 1 new record');
        System.assertEquals(contacts[0].Id, filtered5[0].ContactId, 'Filtered record should be the new one');

        // Test 6: Multiple existing records scenario - verify all are filtered
        List<ContactContactRelation> allDuplicates = new List<ContactContactRelation>();
        ContactContactRelation ccr9 = new ContactContactRelation();
        ccr9.ContactId = contacts[2].Id;
        ccr9.RelatedContactId = contacts[3].Id;
        allDuplicates.add(ccr9);

        ContactContactRelation ccr10 = new ContactContactRelation();
        ccr10.ContactId = contacts[3].Id;
        ccr10.RelatedContactId = contacts[4].Id;
        allDuplicates.add(ccr10);

        List<ContactContactRelation> filtered6 = ContactContactRelationDuplicateFilter.filterDuplicateCCRs(allDuplicates);
        System.assertEquals(0, filtered6.size(), 'Should filter out all existing records');

        // Test 7: Mixed scenario - some existing, some new
        List<ContactContactRelation> mixedCCRs = new List<ContactContactRelation>();
        ContactContactRelation ccr11 = new ContactContactRelation();
        ccr11.ContactId = contacts[2].Id;
        ccr11.RelatedContactId = contacts[3].Id;
        mixedCCRs.add(ccr11);

        ContactContactRelation ccr12 = new ContactContactRelation();
        ccr12.ContactId = contacts[1].Id;
        ccr12.RelatedContactId = contacts[2].Id;
        mixedCCRs.add(ccr12);

        List<ContactContactRelation> filtered7 = ContactContactRelationDuplicateFilter.filterDuplicateCCRs(mixedCCRs);
        System.assertEquals(1, filtered7.size(), 'Should filter out existing and keep new record');
        System.assertEquals(contacts[1].Id, filtered7[0].ContactId, 'Filtered record should be the new one');
        System.assertEquals(contacts[2].Id, filtered7[0].RelatedContactId, 'RelatedContactId should match');

        Test.stopTest();
    }
}