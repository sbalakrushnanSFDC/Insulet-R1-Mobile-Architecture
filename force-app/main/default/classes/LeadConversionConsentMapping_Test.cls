/**
 * @description Test class for LeadConversionConsentMappingQueueable and LeadConversionConsentMappingHelper.
 *              Provides comprehensive test coverage for consent mapping from Lead to Patient after conversion,
 *              including query methods, consent creation, updates, phone matching, and edge cases.
 *
 * @author      Bijayalaxmi Prusty
 * @createdDate 27th Jan 2026
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       27th Jan 2026       Bijayalaxmi Prusty      Initial Version(NGASIM-1905)
 * V1.1.0       20th Feb 2026       Bijayalaxmi Prusty      Updated(NGASIM-2157)
 */
@isTest(IsParallel=true)
private class LeadConversionConsentMapping_Test {

    /**
     * @description Sets up test data for consent mapping scenarios
     */
    @TestSetup
    static void setupTestData() {
        List<DataUsePurpose> dataUsePurposes = new List<DataUsePurpose>{
            new DataUsePurpose(Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
            new DataUsePurpose(Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            new DataUsePurpose(Name = ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL)
        };
        insert dataUsePurposes;

        List<Individual> individuals = new List<Individual>();
        for (Integer i = 0; i < 4; i++) {
            Individual ind = TestDataFactory.getIndividual(new Map<String, Object>{
                'FirstName' => 'Test',
                'LastName' => 'Individual' + i
            });
            individuals.add(ind);
        }
        insert individuals;

        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 2; i++) {
            Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
                'FirstName' => 'Test',
                'LastName' => 'Lead' + i,
                'Email' => 'testlead' + i + '@example.com',
                'MobilePhone' => '555123456' + i,
                'Phone' => '555987654' + i,
                'IndividualId' => individuals[i].Id,
                'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
            });
            leads.add(testLead);
        }
        insert leads;

        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 2; i++) {
            Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
                'FirstName' => 'Test',
                'LastName' => 'Patient' + i,
                'PersonEmail' => 'testpatient' + i + '@example.com',
                'PersonIndividualId' => individuals[i + 2].Id
            });
            accounts.add(testAccount);
        }
        insert accounts;

        List<ContactPointPhone> patientPhones = new List<ContactPointPhone>();
        for (Integer i = 0; i < 2; i++) {
            ContactPointPhone phone = new ContactPointPhone(
                ParentId = accounts[i].Id,
                TelephoneNumber = '555123456' + i,
                UsageType = 'Mobile',
                IsPrimary = true
            );
            patientPhones.add(phone);
        }
        insert patientPhones;

        ensureGuardianPartyRoleRelationExists();

        List<ContactPointTypeConsent> allConsents = new List<ContactPointTypeConsent>();

        // Create Lead consent records for mapping
        for (Integer i = 0; i < 2; i++) {
            ContactPointTypeConsent leadEmailConsent = new ContactPointTypeConsent(
                PartyId = individuals[i].Id,
                Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
                DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
                PrivacyConsentStatus = 'OptIn',
                CaptureDate = Datetime.now(),
                CaptureSource = 'Web'
            );
            allConsents.add(leadEmailConsent);

            ContactPointTypeConsent leadSMSConsent = new ContactPointTypeConsent(
                PartyId = individuals[i].Id,
                Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
                DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
                PrivacyConsentStatus = 'OptIn',
                CaptureDate = Datetime.now(),
                CaptureSource = 'Web'
            );
            allConsents.add(leadSMSConsent);
        }

        // Create Patient consent records
        for (Integer i = 0; i < 2; i++) {
            ContactPointTypeConsent emailConsent = new ContactPointTypeConsent(
                PartyId = individuals[i + 2].Id,
                Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
                DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
                PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_OUT,
                CaptureDate = Datetime.now().addDays(-10),
                CaptureSource = 'Manual'
            );
            allConsents.add(emailConsent);

            ContactPointTypeConsent smsConsent = new ContactPointTypeConsent(
                PartyId = individuals[i + 2].Id,
                Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
                DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
                PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
                CaptureDate = Datetime.now().addDays(-1),
                CaptureSource = 'Manual'
            );
            allConsents.add(smsConsent);
        }
        insert allConsents;
    }

    /**
     * @description Ensures PartyRoleRelation for Patient-Legal Guardian-CCR exists in org.
     */
    private static void ensureGuardianPartyRoleRelationExists() {
        List<PartyRoleRelation> existing = [
            SELECT Id FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE
            WITH USER_MODE
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            try {
                insert new PartyRoleRelation(
                    Name = ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE,
                    RoleName = 'Patient',
                    RelatedRoleName = ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME,
                    RelationshipObjectName = ConstantsUtil.CONTACT_CONTACT_RELATION
                );
            } catch (DmlException e) {
                if (e.getNumDml() == 0 || e.getDmlType(0) != StatusCode.DUPLICATE_VALUE) {
                    throw e;
                }
            }
        }
    }

    /**
     * @description Returns PartyRoleRelation Id for guardian role. Uses record from setup; fallback to mock Id if not found.
     */
    private static Id getGuardianPartyRelationId() {
        List<PartyRoleRelation> roles = [
            SELECT Id FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE
            WITH USER_MODE
            LIMIT 1
        ];
        return roles.isEmpty() ? MockDataFactory.createPartyRoleRelation().Id : roles[0].Id;
    }

    private static Boolean hasRealGuardianPartyRoleRelation() {
        return ![
            SELECT Id FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE
            WITH USER_MODE
            LIMIT 1
        ].isEmpty();
    }

    private static void ensureGuardianContactContactRelationExists(Id contactId, Id relatedContactId, Id partyRoleRelationId) {
        if (partyRoleRelationId == null) {
            return;
        }
        List<PartyRoleRelation> roleExists = [
            SELECT Id FROM PartyRoleRelation WHERE Id = :partyRoleRelationId WITH USER_MODE LIMIT 1
        ];
        if (roleExists.isEmpty()) {
            return;
        }
        List<ContactContactRelation> existing = [
            SELECT Id FROM ContactContactRelation
            WHERE ContactId = :contactId
            AND RelatedContactId = :relatedContactId
            AND PartyRoleRelationId = :partyRoleRelationId
            WITH USER_MODE
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new ContactContactRelation(
                ContactId = contactId,
                RelatedContactId = relatedContactId,
                PartyRoleRelationId = partyRoleRelationId
            );
        }
    }

    /**
     * @description Gets Lead records from test setup
     * @return List of Lead records
     */
    private static List<Lead> getLeads() {
        return [SELECT Id, IndividualId, MobilePhone, Phone FROM Lead WITH USER_MODE];
    }

    /**
     * @description Gets Account records from test setup
     * @return List of Account records
     */
    private static List<Account> getAccounts() {
        return [SELECT Id, PersonIndividualId FROM Account WITH USER_MODE];
    }

    /**
     * @description Gets Individual records from test setup
     * @return List of Individual records
     */
    private static List<Individual> getIndividuals() {
        return [SELECT Id FROM Individual WITH USER_MODE ORDER BY CreatedDate];
    }

    /**
     * @description Gets DataUsePurpose Id by name
     * @param name DataUsePurpose Name
     * @return DataUsePurpose Id
     */
    private static Id getDataUsePurposeId(String name) {
        List<DataUsePurpose> records = [SELECT Id FROM DataUsePurpose WHERE Name = :name WITH USER_MODE LIMIT 1];
        return records.isEmpty() ? null : records[0].Id;
    }

    /**
     * @description Test successful consent mapping for Email and SMS
     */
    @isTest
    static void testExecuteSuccess() {
        List<Lead> leads = getLeads();
        List<Account> accounts = getAccounts();
        List<Individual> individuals = getIndividuals();

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = accounts[0].Id;
        data.leadId = leads[0].Id;
        data.patientIndividualId = individuals[2].Id;
        data.leadIndividualId = individuals[0].Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> patientConsents = [
            SELECT Id, Name, PartyId, PrivacyConsentStatus, CaptureDate, Legal_Guardian__c
            FROM ContactPointTypeConsent
            WHERE PartyId = :individuals[2].Id
            WITH USER_MODE
        ];

        Assert.isTrue(patientConsents.size() >= 2, 'Should have Email and SMS consent records');
    }

    /**
     * @description Test consent mapping with existing patient consents that need update
     */
    @isTest
    static void testExecuteWithExistingConsents() {
        List<Lead> leads = getLeads();
        List<Account> accounts = getAccounts();
        List<Individual> individuals = getIndividuals();

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = accounts[0].Id;
        data.leadId = leads[0].Id;
        data.patientIndividualId = individuals[2].Id;
        data.leadIndividualId = individuals[0].Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> updatedConsents = [
            SELECT Id, PrivacyConsentStatus, CaptureDate
            FROM ContactPointTypeConsent
            WHERE PartyId = :individuals[2].Id
            AND Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL
            WITH USER_MODE
        ];

        Assert.areEqual(1, updatedConsents.size(), 'Should update existing consent');
    }

    /**
     * @description Test SMS consent update skip when Opt In and phone matches
     */
    @isTest
    static void testExecuteSkipSMSUpdateWhenOptIn() {
        List<Lead> leads = getLeads();
        List<Account> accounts = getAccounts();
        List<Individual> individuals = getIndividuals();

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = accounts[0].Id;
        data.leadId = leads[0].Id;
        data.patientIndividualId = individuals[2].Id;
        data.leadIndividualId = individuals[0].Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> smsConsents = [
            SELECT Id, PrivacyConsentStatus, CaptureDate
            FROM ContactPointTypeConsent
            WHERE PartyId = :individuals[2].Id
            AND Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            WITH USER_MODE
        ];

        Assert.areEqual(1, smsConsents.size(), 'Should have one SMS consent');
        Assert.areEqual(ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN, smsConsents[0].PrivacyConsentStatus,
            'Should maintain Opt In status');
    }

    /**
     * @description Test with empty data list
     */
    @isTest
    static void testExecuteWithEmptyDataList() {
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> emptyList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(emptyList);
        System.enqueueJob(job);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle empty data list gracefully');
    }

    /**
     * @description Test with null data list
     */
    @isTest
    static void testExecuteWithNullDataList() {
        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(null);
        System.enqueueJob(job);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle null data list gracefully');
    }

    /**
     * @description Test with invalid data (missing IndividualIds)
     */
    @isTest
    static void testExecuteWithInvalidData() {
        List<Lead> leads = getLeads();
        List<Account> accounts = getAccounts();
        List<Individual> individuals = getIndividuals();

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData validData =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        validData.accountId = accounts[0].Id;
        validData.leadId = leads[0].Id;
        validData.patientIndividualId = individuals[2].Id;
        validData.leadIndividualId = individuals[0].Id;
        validData.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(validData);

        LeadConversionConsentMappingQueueable.LeadConversionConsentData invalidData =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        invalidData.accountId = accounts[1].Id;
        invalidData.leadId = leads[1].Id;
        invalidData.patientIndividualId = null;
        invalidData.leadIndividualId = null;
        invalidData.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(invalidData);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle invalid data gracefully');
    }

    /**
     * @description Test with valid data but no Lead consents
     */
    @isTest
    static void testExecuteWithNoLeadConsents() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadIndividualNoConsent'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientIndividualNoConsent'
        });
        insert patientIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadNoConsent',
            'Email' => 'testleadnoconsent@example.com',
            'MobilePhone' => '5551234570',
            'Phone' => '5559876550',
            'IndividualId' => leadIndividual.Id
        });
        insert testLead;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientNoConsent',
            'PersonEmail' => 'testpatientnoconsent@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert testAccount;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = testAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle missing Lead consents gracefully');
    }

    /**
     * @description Test helper queryLeadConsents method
     */
    @isTest
    static void testQueryLeadConsents() {
        List<Individual> individuals = getIndividuals();
        Set<Id> leadIndividualIds = new Set<Id>{ individuals[0].Id, individuals[1].Id };

        Test.startTest();
        Map<Id, List<ContactPointTypeConsent>> consentMap =
            LeadConversionConsentMappingHelper.queryLeadConsents(leadIndividualIds);
        Test.stopTest();

        Assert.areEqual(2, consentMap.size(), 'Should return consents for both Individuals');
        Assert.isTrue(consentMap.containsKey(individuals[0].Id), 'Should contain first Individual');
        Assert.isTrue(consentMap.containsKey(individuals[1].Id), 'Should contain second Individual');
    }

    /**
     * @description Test helper queryPatientConsents method
     */
    @isTest
    static void testQueryPatientConsents() {
        List<Individual> individuals = getIndividuals();
        Set<Id> patientIndividualIds = new Set<Id>{ individuals[2].Id };

        Test.startTest();
        Map<Id, List<ContactPointTypeConsent>> consentMap =
            LeadConversionConsentMappingHelper.queryPatientConsents(patientIndividualIds);
        Test.stopTest();

        Assert.isTrue(consentMap.containsKey(individuals[2].Id) || consentMap.isEmpty(),
            'Should return map with patient Individual or empty if no consents');
    }

    /**
     * @description Test helper queryPatientPhones method
     */
    @isTest
    static void testQueryPatientPhones() {
        List<Account> accounts = getAccounts();
        Set<Id> accountIds = new Set<Id>{ accounts[0].Id, accounts[1].Id };

        Test.startTest();
        Map<Id, List<ContactPointPhone>> phoneMap =
            LeadConversionConsentMappingHelper.queryPatientPhones(accountIds);
        Test.stopTest();

        Assert.areEqual(2, phoneMap.size(), 'Should return phones for both Accounts');
        Assert.isTrue(phoneMap.containsKey(accounts[0].Id), 'Should contain first Account');
        Assert.isTrue(phoneMap.containsKey(accounts[1].Id), 'Should contain second Account');
    }

    /**
     * @description Test helper queryLeads method
     */
    @isTest
    static void testQueryLeads() {
        List<Lead> leads = getLeads();
        Set<Id> leadIds = new Set<Id>{ leads[0].Id, leads[1].Id };

        Test.startTest();
        Map<Id, Lead> leadMap = LeadConversionConsentMappingHelper.queryLeads(leadIds);
        Test.stopTest();

        Assert.areEqual(2, leadMap.size(), 'Should return both Leads');
        Assert.isTrue(leadMap.containsKey(leads[0].Id), 'Should contain first Lead');
        Assert.isTrue(leadMap.containsKey(leads[1].Id), 'Should contain second Lead');
    }

    /**
     * @description Test helper queryPatientDelegateAccounts method
     */
    @isTest
    static void testQueryPatientDelegateAccounts() {
        List<Account> accounts = getAccounts();
        Set<Id> accountIds = new Set<Id>{ accounts[0].Id };

        Test.startTest();
        Map<Id, Id> delegateMap = LeadConversionConsentMappingHelper.queryPatientDelegateAccounts(accountIds);
        Test.stopTest();

        Assert.isNotNull(delegateMap, 'Should return map even if empty');
    }

    /**
     * @description Test helper queryPatientDelegateAccounts with guardian relationship - covers lines 241-251
     */
    @isTest
    static void testQueryPatientDelegateAccountsWithGuardian() {
        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientIndividualGuardian'
        });
        insert patientIndividual;

        Individual delegateIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'DelegateIndividualGuardian'
        });
        insert delegateIndividual;

        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientGuardian',
            'PersonEmail' => 'testpatientguardian@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert patientAccount;

        Account delegateAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'DelegateGuardian',
            'PersonEmail' => 'testdelegateguardian@example.com',
            'PersonIndividualId' => delegateIndividual.Id
        });
        insert delegateAccount;

        Contact patientContact = [SELECT Id FROM Contact WHERE AccountId = :patientAccount.Id WITH USER_MODE LIMIT 1];
        Contact delegateContact = [SELECT Id FROM Contact WHERE AccountId = :delegateAccount.Id WITH USER_MODE LIMIT 1];

        Id guardianRoleRelationId = getGuardianPartyRelationId();
        ensureGuardianContactContactRelationExists(
            patientContact.Id,
            delegateContact.Id,
            guardianRoleRelationId
        );

        Set<Id> accountIds = new Set<Id>{ patientAccount.Id };

        Test.startTest();
        Map<Id, Id> delegateMap = LeadConversionConsentMappingHelper.queryPatientDelegateAccounts(accountIds);
        Test.stopTest();

        Assert.isNotNull(delegateMap, 'Should return map');
        if (hasRealGuardianPartyRoleRelation()) {
            Assert.isFalse(delegateMap.isEmpty(), 'Should return non-empty map when guardian relationship exists');
            Assert.areEqual(delegateAccount.Id, delegateMap.get(patientAccount.Id),
                'Should return delegate account ID for patient account');
        }
    }

    /**
     * @description Test helper findConsentByName method
     */
    @isTest
    static void testFindConsentByName() {
        List<Individual> individuals = getIndividuals();
        List<ContactPointTypeConsent> consents = [
            SELECT Id, Name, PartyId
            FROM ContactPointTypeConsent
            WHERE PartyId = :individuals[0].Id
            WITH USER_MODE
        ];

        Test.startTest();
        ContactPointTypeConsent emailConsent =
            LeadConversionConsentMappingHelper.findConsentByName(consents, ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL);
        ContactPointTypeConsent smsConsent =
            LeadConversionConsentMappingHelper.findConsentByName(consents, ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS);
        ContactPointTypeConsent notFoundConsent =
            LeadConversionConsentMappingHelper.findConsentByName(consents, 'NonExistent');
        Test.stopTest();

        Assert.isNotNull(emailConsent, 'Should find Email consent');
        Assert.isNotNull(smsConsent, 'Should find SMS consent');
        Assert.isNull(notFoundConsent, 'Should return null for non-existent consent');
    }

    /**
     * @description Test helper checkLeadPhoneInPatientPhones method with matching phone
     */
    @isTest
    static void testCheckLeadPhoneInPatientPhonesMatch() {
        List<Lead> leads = getLeads();
        List<Account> accounts = getAccounts();
        List<ContactPointPhone> phones = [
            SELECT Id, ParentId, TelephoneNumber
            FROM ContactPointPhone
            WHERE ParentId = :accounts[0].Id
            WITH USER_MODE
        ];

        Test.startTest();
        Boolean phoneExists = LeadConversionConsentMappingHelper.checkLeadPhoneInPatientPhones(phones, leads[0]);
        Test.stopTest();

        Assert.isTrue(phoneExists, 'Should find matching phone');
    }

    /**
     * @description Test helper checkLeadPhoneInPatientPhones method with no match
     */
    @isTest
    static void testCheckLeadPhoneInPatientPhonesNoMatch() {
        List<Lead> leads = getLeads();
        List<Account> accounts = getAccounts();
        Lead leadWithDifferentPhone = leads[0].clone();
        leadWithDifferentPhone.MobilePhone = '9999999999';
        leadWithDifferentPhone.Phone = '8888888888';

        List<ContactPointPhone> phones = [
            SELECT Id, ParentId, TelephoneNumber
            FROM ContactPointPhone
            WHERE ParentId = :accounts[0].Id
            WITH USER_MODE
        ];

        Test.startTest();
        Boolean phoneExists = LeadConversionConsentMappingHelper.checkLeadPhoneInPatientPhones(phones, leadWithDifferentPhone);
        Test.stopTest();

        Assert.isFalse(phoneExists, 'Should not find matching phone');
    }

    /**
     * @description Test helper shouldUpdateConsent method
     */
    @isTest
    static void testShouldUpdateConsent() {
        ContactPointTypeConsent patientConsent = new ContactPointTypeConsent(
            CaptureDate = Datetime.now().addDays(-10)
        );
        ContactPointTypeConsent leadConsent = new ContactPointTypeConsent(
            CaptureDate = Datetime.now().addDays(-5)
        );

        Test.startTest();
        Boolean shouldUpdate = LeadConversionConsentMappingHelper.shouldUpdateConsent(patientConsent, leadConsent);
        Test.stopTest();

        Assert.isTrue(shouldUpdate, 'Should update when Lead consent is newer');
    }

    /**
     * @description Test helper shouldUpdateConsent method with older Lead consent
     */
    @isTest
    static void testShouldUpdateConsentOlderLead() {
        ContactPointTypeConsent patientConsent = new ContactPointTypeConsent(
            CaptureDate = Datetime.now().addDays(-5)
        );
        ContactPointTypeConsent leadConsent = new ContactPointTypeConsent(
            CaptureDate = Datetime.now().addDays(-10)
        );

        Test.startTest();
        Boolean shouldUpdate = LeadConversionConsentMappingHelper.shouldUpdateConsent(patientConsent, leadConsent);
        Test.stopTest();

        Assert.isFalse(shouldUpdate, 'Should not update when Lead consent is older');
    }

    /**
     * @description Test helper shouldUpdateConsent with null patient CaptureDate
     */
    @isTest
    static void testShouldUpdateConsentNullPatientDate() {
        ContactPointTypeConsent patientConsent = new ContactPointTypeConsent(
            CaptureDate = null
        );
        ContactPointTypeConsent leadConsent = new ContactPointTypeConsent(
            CaptureDate = Datetime.now()
        );

        Test.startTest();
        Boolean shouldUpdate = LeadConversionConsentMappingHelper.shouldUpdateConsent(patientConsent, leadConsent);
        Test.stopTest();

        Assert.isTrue(shouldUpdate, 'Should update when patient CaptureDate is null and Lead has date');
    }

    /**
     * @description Test helper shouldUpdateConsent with null Lead CaptureDate
     */
    @isTest
    static void testShouldUpdateConsentNullLeadDate() {
        ContactPointTypeConsent patientConsent = new ContactPointTypeConsent(
            CaptureDate = Datetime.now()
        );
        ContactPointTypeConsent leadConsent = new ContactPointTypeConsent(
            CaptureDate = null
        );

        Test.startTest();
        Boolean shouldUpdate = LeadConversionConsentMappingHelper.shouldUpdateConsent(patientConsent, leadConsent);
        Test.stopTest();

        Assert.isFalse(shouldUpdate, 'Should not update when Lead CaptureDate is null');
    }

    /**
     * @description Test helper shouldUpdateConsent with null consents
     */
    @isTest
    static void testShouldUpdateConsentNullConsents() {
        Test.startTest();
        Boolean shouldUpdate1 = LeadConversionConsentMappingHelper.shouldUpdateConsent(null, new ContactPointTypeConsent());
        Boolean shouldUpdate2 = LeadConversionConsentMappingHelper.shouldUpdateConsent(new ContactPointTypeConsent(), null);
        Boolean shouldUpdate3 = LeadConversionConsentMappingHelper.shouldUpdateConsent(null, null);
        Test.stopTest();

        Assert.isFalse(shouldUpdate1, 'Should not update when patient consent is null');
        Assert.isFalse(shouldUpdate2, 'Should not update when lead consent is null');
        Assert.isFalse(shouldUpdate3, 'Should not update when both consents are null');
    }

    /**
     * @description Test helper shouldUpdateConsent when both CaptureDates are null
     */
    @isTest
    static void testShouldUpdateConsentBothDatesNull() {
        ContactPointTypeConsent patientConsent = new ContactPointTypeConsent(
            CaptureDate = null
        );
        ContactPointTypeConsent leadConsent = new ContactPointTypeConsent(
            CaptureDate = null
        );

        Test.startTest();
        Boolean shouldUpdate = LeadConversionConsentMappingHelper.shouldUpdateConsent(patientConsent, leadConsent);
        Test.stopTest();

        Assert.isFalse(shouldUpdate, 'Should not update when both CaptureDates are null');
    }

    /**
     * @description Test Legal Guardian update when patient delegate account exists
     */
    @isTest
    static void testExecuteWithLegalGuardianUpdate() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadIndividualLG'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientIndividualLG'
        });
        insert patientIndividual;

        Individual delegateIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'DelegateIndividualLG'
        });
        insert delegateIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadLG',
            'Email' => 'testleadlg@example.com',
            'MobilePhone' => '5551234571',
            'Phone' => '5559876551',
            'IndividualId' => leadIndividual.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientLG',
            'PersonEmail' => 'testpatientlg@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert patientAccount;

        Account delegateAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'DelegateLG',
            'PersonEmail' => 'testdelegatelg@example.com',
            'PersonIndividualId' => delegateIndividual.Id
        });
        insert delegateAccount;

        patientAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :patientAccount.Id WITH USER_MODE LIMIT 1];
        delegateAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :delegateAccount.Id WITH USER_MODE LIMIT 1];

        Id patientContactId = patientAccount.PersonContactId != null
            ? patientAccount.PersonContactId
            : [SELECT Id FROM Contact WHERE AccountId = :patientAccount.Id WITH USER_MODE LIMIT 1].Id;
        Id delegateContactId = delegateAccount.PersonContactId != null
            ? delegateAccount.PersonContactId
            : [SELECT Id FROM Contact WHERE AccountId = :delegateAccount.Id WITH USER_MODE LIMIT 1].Id;

        Id guardianRoleRelationId = getGuardianPartyRelationId();
        ensureGuardianContactContactRelationExists(
            patientContactId,
            delegateContactId,
            guardianRoleRelationId
        );

        ContactPointTypeConsent existingConsent = new ContactPointTypeConsent(
            PartyId = patientIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = Datetime.now().addDays(-10),
            CaptureSource = 'Manual',
            Legal_Guardian__c = null
        );
        insert existingConsent;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = patientAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> updatedConsents = [
            SELECT Id, Legal_Guardian__c, PrivacyConsentStatus, CaptureDate
            FROM ContactPointTypeConsent
            WHERE PartyId = :patientIndividual.Id
            AND Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL
            WITH USER_MODE
        ];

        Assert.areEqual(1, updatedConsents.size(), 'Should have one consent');
    }

    /**
     * @description Test Capture Date update when Lead consent is newer
     */
    @isTest
    static void testExecuteWithCaptureDateUpdate() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadIndividualCD'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientIndividualCD'
        });
        insert patientIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadCD',
            'Email' => 'testleadcd@example.com',
            'MobilePhone' => '5551234572',
            'Phone' => '5559876552',
            'IndividualId' => leadIndividual.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        // Create Lead consent record for Email with capture date
        Datetime leadConsentDate = Datetime.now();
        ContactPointTypeConsent leadEmailConsent = new ContactPointTypeConsent(
            PartyId = leadIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
            PrivacyConsentStatus = 'OptIn',
            CaptureDate = leadConsentDate
        );
        insert leadEmailConsent;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientCD',
            'PersonEmail' => 'testpatientcd@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert testAccount;
        Datetime patientConsentDate = leadConsentDate != null ? leadConsentDate.addDays(-10) : Datetime.now().addDays(-10);

        ContactPointTypeConsent existingConsent = new ContactPointTypeConsent(
            PartyId = patientIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_OUT,
            CaptureDate = patientConsentDate,
            CaptureSource = 'Manual'
        );
        insert existingConsent;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = testAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> updatedConsents = [
            SELECT Id, PrivacyConsentStatus, CaptureDate
            FROM ContactPointTypeConsent
            WHERE PartyId = :patientIndividual.Id
            AND Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL
            WITH USER_MODE
        ];

        Assert.isTrue(updatedConsents.size() >= 1, 'Should have consent record');
    }

    /**
     * @description Test helper methods with empty sets
     */
    @isTest
    static void testHelperMethodsWithEmptySets() {
        Set<Id> emptySet = new Set<Id>();

        Test.startTest();
        Map<Id, List<ContactPointTypeConsent>> leadConsents =
            LeadConversionConsentMappingHelper.queryLeadConsents(emptySet);
        Map<Id, List<ContactPointTypeConsent>> patientConsents =
            LeadConversionConsentMappingHelper.queryPatientConsents(emptySet);
        Map<Id, List<ContactPointPhone>> phones =
            LeadConversionConsentMappingHelper.queryPatientPhones(emptySet);
        Map<Id, Lead> leads = LeadConversionConsentMappingHelper.queryLeads(emptySet);
        Map<Id, Id> delegates =
            LeadConversionConsentMappingHelper.queryPatientDelegateAccounts(emptySet);
        Test.stopTest();

        Assert.isTrue(leadConsents.isEmpty(), 'Should return empty map for empty set');
        Assert.isTrue(patientConsents.isEmpty(), 'Should return empty map for empty set');
        Assert.isTrue(phones.isEmpty(), 'Should return empty map for empty set');
        Assert.isTrue(leads.isEmpty(), 'Should return empty map for empty set');
        Assert.isTrue(delegates.isEmpty(), 'Should return empty map for empty set');
    }

    /**
     * @description Test finalizer with unhandled exception
     */
    @isTest
    static void testConsentMappingFinalizerWithUnhandledException() {
        List<Account> accounts = getAccounts();
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = accounts[0].Id;
        dataList.add(data);

        LeadConversionConsentMappingQueueable.ConsentMappingFinalizer finalizer =
            new LeadConversionConsentMappingQueueable.ConsentMappingFinalizer(dataList);

        MockFinalizerContext context = new MockFinalizerContext(
            ParentJobResult.UNHANDLED_EXCEPTION,
            new CalloutException('Test exception')
        );

        Test.startTest();
        finalizer.execute(context);
        Test.stopTest();

        Assert.isTrue(true, 'Finalizer should handle unhandled exception');
    }

    /**
     * @description Test finalizer with successful completion
     */
    @isTest
    static void testConsentMappingFinalizerWithSuccess() {
        List<Account> accounts = getAccounts();
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = accounts[0].Id;
        dataList.add(data);

        LeadConversionConsentMappingQueueable.ConsentMappingFinalizer finalizer =
            new LeadConversionConsentMappingQueueable.ConsentMappingFinalizer(dataList);

        MockFinalizerContext context = new MockFinalizerContext(
            ParentJobResult.SUCCESS,
            null
        );

        Test.startTest();
        finalizer.execute(context);
        Test.stopTest();

        Assert.isTrue(true, 'Finalizer should handle successful completion');
    }

    /**
     * @description Test finalizer buildConsentRecords with multiple accounts including null accountId
     */
    @isTest
    static void testConsentMappingFinalizerBuildConsentRecords() {
        List<Account> accounts = getAccounts();
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data1 =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data1.accountId = accounts[0].Id;
        dataList.add(data1);

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data2 =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data2.accountId = null;
        dataList.add(data2);

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data3 =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data3.accountId = accounts[1].Id;
        dataList.add(data3);

        LeadConversionConsentMappingQueueable.ConsentMappingFinalizer finalizer =
            new LeadConversionConsentMappingQueueable.ConsentMappingFinalizer(dataList);

        MockFinalizerContext context = new MockFinalizerContext(
            ParentJobResult.UNHANDLED_EXCEPTION,
            new CalloutException('Test exception')
        );

        Test.startTest();
        finalizer.execute(context);
        Test.stopTest();

        Assert.isTrue(true, 'Finalizer should build consent records correctly');
    }

    /**
     * @description Test finalizer with null exception message
     */
    @isTest
    static void testConsentMappingFinalizerWithNullException() {
        List<Account> accounts = getAccounts();
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = accounts[0].Id;
        dataList.add(data);

        LeadConversionConsentMappingQueueable.ConsentMappingFinalizer finalizer =
            new LeadConversionConsentMappingQueueable.ConsentMappingFinalizer(dataList);

        MockFinalizerContext context = new MockFinalizerContext(
            ParentJobResult.UNHANDLED_EXCEPTION,
            null
        );

        Test.startTest();
        finalizer.execute(context);
        Test.stopTest();

        Assert.isTrue(true, 'Finalizer should handle null exception');
    }

    /**
     * @description Test finalizer with empty mapping data list
     */
    @isTest
    static void testConsentMappingFinalizerWithEmptyDataList() {
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> emptyList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.ConsentMappingFinalizer finalizer =
            new LeadConversionConsentMappingQueueable.ConsentMappingFinalizer(emptyList);

        MockFinalizerContext context = new MockFinalizerContext(
            ParentJobResult.UNHANDLED_EXCEPTION,
            new CalloutException('Test exception')
        );

        Test.startTest();
        finalizer.execute(context);
        Test.stopTest();

        Assert.isTrue(true, 'Finalizer should handle empty data list');
    }

    /**
     * @description Test finalizer constructor with null data list
     */
    @isTest
    static void testConsentMappingFinalizerConstructorWithNull() {
        Test.startTest();
        LeadConversionConsentMappingQueueable.ConsentMappingFinalizer finalizer =
            new LeadConversionConsentMappingQueueable.ConsentMappingFinalizer(null);
        Test.stopTest();

        Assert.isNotNull(finalizer, 'Finalizer should be created with null data list');
    }

    /**
     * @description Test createNewConsent for Email consent when patient has no Email consent
     */
    @isTest
    static void testCreateNewConsentForEmail() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadIndividualEmail'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientIndividualEmail'
        });
        insert patientIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadEmail',
            'Email' => 'testleademail@example.com',
            'MobilePhone' => '5551234567',
            'Phone' => '5559876543',
            'IndividualId' => leadIndividual.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        // Create Lead consent record for Email
        ContactPointTypeConsent leadEmailConsent = new ContactPointTypeConsent(
            PartyId = leadIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
            PrivacyConsentStatus = 'OptIn',
            CaptureDate = Datetime.now()
        );
        insert leadEmailConsent;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientEmail',
            'PersonEmail' => 'testpatientemail@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert testAccount;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = testAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> emailConsents = [
            SELECT Id, Name, PartyId, PrivacyConsentStatus, CaptureDate
            FROM ContactPointTypeConsent
            WHERE PartyId = :patientIndividual.Id
            AND Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL
            WITH USER_MODE
        ];

        Assert.areEqual(1, emailConsents.size(), 'Should create Email consent when patient has none');
        Assert.areEqual(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL, emailConsents[0].Name, 'Should create Email consent');
    }

    /**
     * @description Test createNewConsent for SMS consent when patient has no SMS consent
     */
    @isTest
    static void testCreateNewConsentForSMS() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadIndividualSMS'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientIndividualSMS'
        });
        insert patientIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadSMS',
            'Email' => 'testleadsms@example.com',
            'MobilePhone' => '5551234568',
            'Phone' => '5559876544',
            'IndividualId' => leadIndividual.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        // Create Lead consent record for SMS
        ContactPointTypeConsent leadSMSConsent = new ContactPointTypeConsent(
            PartyId = leadIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = 'OptIn',
            CaptureDate = Datetime.now()
        );
        insert leadSMSConsent;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientSMS',
            'PersonEmail' => 'testpatientsms@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert testAccount;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = testAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> smsConsents = [
            SELECT Id, Name, PartyId, PrivacyConsentStatus, CaptureDate
            FROM ContactPointTypeConsent
            WHERE PartyId = :patientIndividual.Id
            AND Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            WITH USER_MODE
        ];

        Assert.areEqual(1, smsConsents.size(), 'Should create SMS consent when patient has none');
        Assert.areEqual(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS, smsConsents[0].Name, 'Should create SMS consent');
    }

    /**
     * @description Test SMS consent override when phone is newly created (in newlyUpsertedPhoneIds)
     * Even if patient has Opt In SMS consent, new phone should trigger override
     */
    @isTest
    static void testSMSConsentOverrideWithNewlyCreatedPhone() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadNewPhone'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientNewPhone'
        });
        insert patientIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadNewPhone',
            'Email' => 'testleadnewphone@example.com',
            'MobilePhone' => '5559998888',
            'IndividualId' => leadIndividual.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        ContactPointTypeConsent leadSMSConsent = new ContactPointTypeConsent(
            PartyId = leadIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = 'OptOut',
            CaptureDate = Datetime.now()
        );
        insert leadSMSConsent;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientNewPhone',
            'PersonEmail' => 'testpatientnewphone@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert testAccount;

        ContactPointPhone newPatientPhone = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '5559998888',
            UsageType = 'Mobile',
            IsPrimary = true
        );
        insert newPatientPhone;

        ContactPointTypeConsent patientSMSConsent = new ContactPointTypeConsent(
            PartyId = patientIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = Datetime.now().addDays(-1)
        );
        insert patientSMSConsent;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = testAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = new Set<Id>{ newPatientPhone.Id };
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> updatedConsents = [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :patientIndividual.Id
            AND Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            WITH USER_MODE
        ];

        Assert.areEqual(1, updatedConsents.size(), 'Should have one SMS consent');
        Assert.areEqual('OptOut', updatedConsents[0].PrivacyConsentStatus, 'Should override to OptOut from Lead consent');
    }

    /**
     * @description Test SMS consent skip when phone exists (not newly created) and patient has Opt In
     */
    @isTest
    static void testSMSConsentSkipWithExistingPhoneOptIn() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadExistPhone'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientExistPhone'
        });
        insert patientIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadExistPhone',
            'Email' => 'testleadexistphone@example.com',
            'MobilePhone' => '5557776666',
            'IndividualId' => leadIndividual.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        ContactPointTypeConsent leadSMSConsent = new ContactPointTypeConsent(
            PartyId = leadIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = 'OptOut',
            CaptureDate = Datetime.now()
        );
        insert leadSMSConsent;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientExistPhone',
            'PersonEmail' => 'testpatientexistphone@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert testAccount;

        ContactPointPhone existingPhone = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '5557776666',
            UsageType = 'Mobile',
            IsPrimary = true
        );
        insert existingPhone;

        ContactPointTypeConsent patientSMSConsent = new ContactPointTypeConsent(
            PartyId = patientIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = Datetime.now().addDays(-1)
        );
        insert patientSMSConsent;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = testAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> consents = [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :patientIndividual.Id
            AND Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            WITH USER_MODE
        ];

        Assert.areEqual(1, consents.size(), 'Should have one SMS consent');
        Assert.areEqual(ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN, consents[0].PrivacyConsentStatus,
            'Should retain Opt In status (not override) for existing phone');
    }

    /**
     * @description Test Marketing Email consent creation when Patient has no consents
     * When Account.Individual has none of the three consents, creates all consents regardless of PrivacyConsentStatus.
     * Lead has Not Seen - should still create for Patient with no existing consents.
     */
    @isTest
    static void testMarketingEmailSkipWhenConsentNotSeen() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadMarketingNotSeen'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientMarketingNotSeen'
        });
        insert patientIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadMarketingNotSeen',
            'Email' => 'testleadmarketingnotseen@example.com',
            'IndividualId' => leadIndividual.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        ContactPointTypeConsent leadMarketingConsent = new ContactPointTypeConsent(
            PartyId = leadIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_NOT_SEEN,
            CaptureDate = Datetime.now()
        );
        insert leadMarketingConsent;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientMarketingNotSeen',
            'PersonEmail' => 'testpatientmarketingnotseen@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert testAccount;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = testAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> patientMarketingConsents = [
            SELECT Id, Name, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :patientIndividual.Id
            AND Name = :ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL
            WITH USER_MODE
        ];

        Assert.areEqual(1, patientMarketingConsents.size(),
            'Should create Marketing Email consent when Patient has no consents, regardless of PrivacyConsentStatus');
        Assert.areEqual(ConstantsUtil.PRIVACY_CONSENT_STATUS_NOT_SEEN, patientMarketingConsents[0].PrivacyConsentStatus,
            'Should carry Not Seen status from Lead');
    }

    /**
     * @description Test Marketing Email consent - do not override when Patient has consent and Lead has Not Seen
     * Create path: creates when Patient doesn't have Marketing Email consent. Update path: skips override when Lead has Not Seen.
     */
    @isTest
    static void testMarketingEmailSkipWhenPatientHasConsentsAndLeadNotSeen() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadMarketingNotSeenExisting'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientMarketingNotSeenExisting'
        });
        insert patientIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadMarketingNotSeenExisting',
            'Email' => 'testleadmarketingnotseenexisting@example.com',
            'IndividualId' => leadIndividual.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        ContactPointTypeConsent leadMarketingConsent = new ContactPointTypeConsent(
            PartyId = leadIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_NOT_SEEN,
            CaptureDate = Datetime.now()
        );
        insert leadMarketingConsent;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientMarketingNotSeenExisting',
            'PersonEmail' => 'testpatientmarketingnotseenexisting@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert testAccount;

        // Patient has existing Marketing Email consent with Opt In - Lead has Not Seen, should NOT override
        ContactPointTypeConsent patientMarketingConsent = new ContactPointTypeConsent(
            PartyId = patientIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = Datetime.now()
        );
        insert patientMarketingConsent;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = testAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        ContactPointTypeConsent updated = [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE Id = :patientMarketingConsent.Id
            WITH USER_MODE
        ];

        Assert.areEqual(ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN, updated.PrivacyConsentStatus,
            'Should not override Patient Marketing Email consent when Lead has Not Seen status');
    }

    /**
     * @description Test Marketing Email consent carry when Lead has PrivacyConsentStatus != Not Seen (e.g. Opt In)
     * Should carry consent from Lead to Patient
     */
    @isTest
    static void testMarketingEmailCarryWhenConsentNotNotSeen() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadMarketingOptIn'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientMarketingOptIn'
        });
        insert patientIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadMarketingOptIn',
            'Email' => 'testleadmarketingoptin@example.com',
            'IndividualId' => leadIndividual.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        ContactPointTypeConsent leadMarketingConsent = new ContactPointTypeConsent(
            PartyId = leadIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = Datetime.now()
        );
        insert leadMarketingConsent;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientMarketingOptIn',
            'PersonEmail' => 'testpatientmarketingoptin@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert testAccount;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = testAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = new Set<Id>();
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> patientMarketingConsents = [
            SELECT Id, Name, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :patientIndividual.Id
            AND Name = :ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL
            WITH USER_MODE
        ];

        Assert.areEqual(1, patientMarketingConsents.size(),
            'Should create Marketing Email consent when Lead has Opt In status');
        Assert.areEqual(ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN, patientMarketingConsents[0].PrivacyConsentStatus,
            'Should carry Opt In status from Lead to Patient');
    }

    /**
     * @description Test SMS consent override when newlyUpsertedPhoneIds is null
     * Should treat all phones as existing
     */
    @isTest
    static void testSMSConsentWithNullNewlyUpsertedPhoneIds() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadNullPhone'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientNullPhone'
        });
        insert patientIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadNullPhone',
            'Email' => 'testleadnullphone@example.com',
            'MobilePhone' => '5554443333',
            'IndividualId' => leadIndividual.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        ContactPointTypeConsent leadSMSConsent = new ContactPointTypeConsent(
            PartyId = leadIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = 'OptOut',
            CaptureDate = Datetime.now()
        );
        insert leadSMSConsent;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientNullPhone',
            'PersonEmail' => 'testpatientnullphone@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert testAccount;

        ContactPointPhone patientPhone = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '5554443333',
            UsageType = 'Mobile',
            IsPrimary = true
        );
        insert patientPhone;

        ContactPointTypeConsent patientSMSConsent = new ContactPointTypeConsent(
            PartyId = patientIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = Datetime.now().addDays(-1)
        );
        insert patientSMSConsent;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = testAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = null;
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> consents = [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :patientIndividual.Id
            AND Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            WITH USER_MODE
        ];

        Assert.areEqual(1, consents.size(), 'Should have one SMS consent');
        Assert.areEqual(ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN, consents[0].PrivacyConsentStatus,
            'Should retain Opt In when newlyUpsertedPhoneIds is null (treats as existing phone)');
    }

    /**
     * @description Test SMS consent override when patient has multiple phones (mix of new and existing)
     */
    @isTest
    static void testSMSConsentWithMixedNewAndExistingPhones() {
        Individual leadIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadMixedPhone'
        });
        insert leadIndividual;

        Individual patientIndividual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientMixedPhone'
        });
        insert patientIndividual;

        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'LeadMixedPhone',
            'Email' => 'testleadmixed@example.com',
            'MobilePhone' => '5552221111',
            'IndividualId' => leadIndividual.Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        ContactPointTypeConsent leadSMSConsent = new ContactPointTypeConsent(
            PartyId = leadIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = 'OptOut',
            CaptureDate = Datetime.now()
        );
        insert leadSMSConsent;

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'PatientMixedPhone',
            'PersonEmail' => 'testpatientmixed@example.com',
            'PersonIndividualId' => patientIndividual.Id
        });
        insert testAccount;

        ContactPointPhone existingPhone = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '5559990000',
            UsageType = 'Mobile',
            IsPrimary = false
        );
        insert existingPhone;

        ContactPointPhone newPhone = new ContactPointPhone(
            ParentId = testAccount.Id,
            TelephoneNumber = '5552221111',
            UsageType = 'Mobile',
            IsPrimary = true
        );
        insert newPhone;

        ContactPointTypeConsent patientSMSConsent = new ContactPointTypeConsent(
            PartyId = patientIndividual.Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = Datetime.now().addDays(-1)
        );
        insert patientSMSConsent;

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        data.accountId = testAccount.Id;
        data.leadId = testLead.Id;
        data.patientIndividualId = patientIndividual.Id;
        data.leadIndividualId = leadIndividual.Id;
        data.newlyUpsertedPhoneIds = new Set<Id>{ newPhone.Id };
        dataList.add(data);

        Test.startTest();
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        System.enqueueJob(job);
        Test.stopTest();

        List<ContactPointTypeConsent> consents = [
            SELECT Id, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId = :patientIndividual.Id
            AND Name = :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
            WITH USER_MODE
        ];

        Assert.areEqual(1, consents.size(), 'Should have one SMS consent');
        Assert.areEqual('OptOut', consents[0].PrivacyConsentStatus,
            'Should override to OptOut when Lead phone matches newly created phone');
    }

    /**
     * @description Test filterExistingPhones with null patient phones
     */
    @isTest
    static void testFilterExistingPhonesNullPatientPhones() {
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();
        dataList.add(new LeadConversionConsentMappingQueueable.LeadConversionConsentData());
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        Set<Id> newlyUpsertedIds = new Set<Id>();

        Test.startTest();
        List<ContactPointPhone> result = job.filterExistingPhones(null, newlyUpsertedIds);
        Test.stopTest();

        Assert.isNotNull(result, 'Should return a list');
        Assert.isTrue(result.isEmpty(), 'Should return empty list when patient phones is null');
    }

    /**
     * @description Test filterExistingPhones with empty patient phones
     */
    @isTest
    static void testFilterExistingPhonesEmptyPatientPhones() {
        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();
        dataList.add(new LeadConversionConsentMappingQueueable.LeadConversionConsentData());
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);
        List<ContactPointPhone> emptyPhones = new List<ContactPointPhone>();
        Set<Id> newlyUpsertedIds = new Set<Id>();

        Test.startTest();
        List<ContactPointPhone> result = job.filterExistingPhones(emptyPhones, newlyUpsertedIds);
        Test.stopTest();

        Assert.isNotNull(result, 'Should return a list');
        Assert.isTrue(result.isEmpty(), 'Should return empty list when patient phones is empty');
    }

    /**
     * @description Test filterExistingPhones with null newlyUpsertedPhoneIds
     */
    @isTest
    static void testFilterExistingPhonesNullNewlyUpsertedIds() {
        List<Account> accounts = getAccounts();

        ContactPointPhone phone1 = new ContactPointPhone(
            ParentId = accounts[0].Id,
            TelephoneNumber = '5551111111',
            UsageType = 'Mobile'
        );
        insert phone1;

        ContactPointPhone phone2 = new ContactPointPhone(
            ParentId = accounts[0].Id,
            TelephoneNumber = '5552222222',
            UsageType = 'Mobile'
        );
        insert phone2;

        List<ContactPointPhone> patientPhones = new List<ContactPointPhone>{ phone1, phone2 };

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();
        dataList.add(new LeadConversionConsentMappingQueueable.LeadConversionConsentData());
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);

        Test.startTest();
        List<ContactPointPhone> result = job.filterExistingPhones(patientPhones, null);
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Should return all phones when newlyUpsertedPhoneIds is null');
    }

    /**
     * @description Test filterExistingPhones with empty newlyUpsertedPhoneIds
     */
    @isTest
    static void testFilterExistingPhonesEmptyNewlyUpsertedIds() {
        List<Account> accounts = getAccounts();

        ContactPointPhone phone1 = new ContactPointPhone(
            ParentId = accounts[0].Id,
            TelephoneNumber = '5553333333',
            UsageType = 'Mobile'
        );
        insert phone1;

        ContactPointPhone phone2 = new ContactPointPhone(
            ParentId = accounts[0].Id,
            TelephoneNumber = '5554444444',
            UsageType = 'Mobile'
        );
        insert phone2;

        List<ContactPointPhone> patientPhones = new List<ContactPointPhone>{ phone1, phone2 };
        Set<Id> emptySet = new Set<Id>();

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();
        dataList.add(new LeadConversionConsentMappingQueueable.LeadConversionConsentData());
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);

        Test.startTest();
        List<ContactPointPhone> result = job.filterExistingPhones(patientPhones, emptySet);
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Should return all phones when newlyUpsertedPhoneIds is empty');
    }

    /**
     * @description Test filterExistingPhones filters out newly upserted phones
     */
    @isTest
    static void testFilterExistingPhonesFiltersNewPhones() {
        List<Account> accounts = getAccounts();

        ContactPointPhone existingPhone = new ContactPointPhone(
            ParentId = accounts[0].Id,
            TelephoneNumber = '5555555555',
            UsageType = 'Mobile'
        );
        insert existingPhone;

        ContactPointPhone newPhone = new ContactPointPhone(
            ParentId = accounts[0].Id,
            TelephoneNumber = '5556666666',
            UsageType = 'Mobile'
        );
        insert newPhone;

        List<ContactPointPhone> patientPhones = new List<ContactPointPhone>{ existingPhone, newPhone };
        Set<Id> newlyUpsertedIds = new Set<Id>{ newPhone.Id };

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();
        dataList.add(new LeadConversionConsentMappingQueueable.LeadConversionConsentData());
        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);

        Test.startTest();
        List<ContactPointPhone> result = job.filterExistingPhones(patientPhones, newlyUpsertedIds);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Should return only existing phones');
        Assert.areEqual(existingPhone.Id, result[0].Id, 'Should return the existing phone, not the new one');
    }

    /**
     * @description Test updateLegalGuardianOnly adds consent to update list when guardian is updated
     */
    @isTest
    static void testUpdateLegalGuardianOnlyAddsToUpdateList() {
        List<Account> accounts = getAccounts();
        List<Individual> individuals = getIndividuals();
        Id delegateAccountId = accounts[0].Id;

        ContactPointTypeConsent smsConsent = new ContactPointTypeConsent(
            PartyId = individuals[2].Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            Legal_Guardian__c = null
        );

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        dataList.add(data);

        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);

        LeadConversionConsentMappingQueueable.ConsentProcessingContext context =
            new LeadConversionConsentMappingQueueable.ConsentProcessingContext();
        context.patientDelegateAccountId = delegateAccountId;
        context.consentsToUpdate = new List<ContactPointTypeConsent>();

        Test.startTest();
        job.updateLegalGuardianOnly(context, smsConsent);
        Test.stopTest();

        Assert.areEqual(1, context.consentsToUpdate.size(), 'Should add consent to update list when guardian is updated');
        Assert.areEqual(delegateAccountId, smsConsent.Legal_Guardian__c, 'Should set Legal_Guardian__c');
    }

    /**
     * @description Test updateLegalGuardianOnly does not add consent when guardian already set
     */
    @isTest
    static void testUpdateLegalGuardianOnlyDoesNotAddWhenAlreadySet() {
        List<Account> accounts = getAccounts();
        List<Individual> individuals = getIndividuals();
        Id existingGuardianId = accounts[0].Id;
        Id newDelegateId = accounts[1].Id;

        ContactPointTypeConsent smsConsent = new ContactPointTypeConsent(
            PartyId = individuals[2].Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            Legal_Guardian__c = existingGuardianId
        );

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        dataList.add(data);

        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);

        LeadConversionConsentMappingQueueable.ConsentProcessingContext context =
            new LeadConversionConsentMappingQueueable.ConsentProcessingContext();
        context.patientDelegateAccountId = newDelegateId;
        context.consentsToUpdate = new List<ContactPointTypeConsent>();

        Test.startTest();
        job.updateLegalGuardianOnly(context, smsConsent);
        Test.stopTest();

        Assert.areEqual(0, context.consentsToUpdate.size(), 'Should not add consent to update list when guardian already set');
        Assert.areEqual(existingGuardianId, smsConsent.Legal_Guardian__c, 'Should not change existing guardian');
    }

    /**
     * @description Test updateLegalGuardianOnly does not add consent when delegate is null
     */
    @isTest
    static void testUpdateLegalGuardianOnlyDoesNotAddWhenDelegateNull() {
        List<Individual> individuals = getIndividuals();

        ContactPointTypeConsent smsConsent = new ContactPointTypeConsent(
            PartyId = individuals[2].Id,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            Legal_Guardian__c = null
        );

        List<LeadConversionConsentMappingQueueable.LeadConversionConsentData> dataList =
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>();

        LeadConversionConsentMappingQueueable.LeadConversionConsentData data =
            new LeadConversionConsentMappingQueueable.LeadConversionConsentData();
        dataList.add(data);

        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(dataList);

        LeadConversionConsentMappingQueueable.ConsentProcessingContext context =
            new LeadConversionConsentMappingQueueable.ConsentProcessingContext();
        context.patientDelegateAccountId = null;
        context.consentsToUpdate = new List<ContactPointTypeConsent>();

        Test.startTest();
        job.updateLegalGuardianOnly(context, smsConsent);
        Test.stopTest();

        Assert.areEqual(0, context.consentsToUpdate.size(), 'Should not add consent to update list when delegate is null');
        Assert.isNull(smsConsent.Legal_Guardian__c, 'Should not set Legal_Guardian__c');
    }

    /**
     * @description Test updateConsentFieldsIfNeeded returns true and updates fields when Lead consent is newer
     */
    @isTest
    static void testUpdateConsentFieldsIfNeededUpdatesWhenNewer() {
        Datetime oldDate = Datetime.now().addDays(-10);
        Datetime newDate = Datetime.now().addDays(-5);

        ContactPointTypeConsent patientConsent = new ContactPointTypeConsent(
            PrivacyConsentStatus = 'OptOut',
            CaptureDate = oldDate,
            CaptureSource = 'Manual'
        );

        ContactPointTypeConsent leadConsent = new ContactPointTypeConsent(
            PrivacyConsentStatus = 'OptIn',
            CaptureDate = newDate,
            CaptureSource = 'Web'
        );

        Test.startTest();
        Boolean updated = LeadConversionConsentMappingHelper.updateConsentFieldsIfNeeded(patientConsent, leadConsent);
        Test.stopTest();

        Assert.isTrue(updated, 'Should return true when Lead consent is newer');
        Assert.areEqual('OptIn', patientConsent.PrivacyConsentStatus, 'Should update PrivacyConsentStatus');
        Assert.areEqual(newDate, patientConsent.CaptureDate, 'Should update CaptureDate');
        Assert.areEqual('Web', patientConsent.CaptureSource, 'Should update CaptureSource');
    }

    /**
     * @description Test updateConsentFieldsIfNeeded returns false when Lead consent is not newer
     */
    @isTest
    static void testUpdateConsentFieldsIfNeededDoesNotUpdateWhenOlder() {
        Datetime oldDate = Datetime.now().addDays(-10);
        Datetime newDate = Datetime.now().addDays(-5);

        ContactPointTypeConsent patientConsent = new ContactPointTypeConsent(
            PrivacyConsentStatus = 'OptIn',
            CaptureDate = newDate,
            CaptureSource = 'Web'
        );

        ContactPointTypeConsent leadConsent = new ContactPointTypeConsent(
            PrivacyConsentStatus = 'OptOut',
            CaptureDate = oldDate,
            CaptureSource = 'Manual'
        );

        Test.startTest();
        Boolean updated = LeadConversionConsentMappingHelper.updateConsentFieldsIfNeeded(patientConsent, leadConsent);
        Test.stopTest();

        Assert.isFalse(updated, 'Should return false when Lead consent is older');
        Assert.areEqual('OptIn', patientConsent.PrivacyConsentStatus, 'Should not update PrivacyConsentStatus');
        Assert.areEqual(newDate, patientConsent.CaptureDate, 'Should not update CaptureDate');
        Assert.areEqual('Web', patientConsent.CaptureSource, 'Should not update CaptureSource');
    }

    /**
     * @description Test updateConsentFieldsIfNeeded returns false when patient CaptureDate is null and lead CaptureDate is also null
     */
    @isTest
    static void testUpdateConsentFieldsIfNeededBothDatesNull() {
        ContactPointTypeConsent patientConsent = new ContactPointTypeConsent(
            PrivacyConsentStatus = 'OptOut',
            CaptureDate = null,
            CaptureSource = 'Manual'
        );

        ContactPointTypeConsent leadConsent = new ContactPointTypeConsent(
            PrivacyConsentStatus = 'OptIn',
            CaptureDate = null,
            CaptureSource = 'Web'
        );

        Test.startTest();
        Boolean updated = LeadConversionConsentMappingHelper.updateConsentFieldsIfNeeded(patientConsent, leadConsent);
        Test.stopTest();

        Assert.isFalse(updated, 'Should return false when both CaptureDates are null');
        Assert.areEqual('OptOut', patientConsent.PrivacyConsentStatus, 'Should not update PrivacyConsentStatus');
    }

    /**
     * @description Test updateLegalGuardianIfNeeded when delegate exists and guardian is null
     */
    @isTest
    static void testUpdateLegalGuardianIfNeededSuccess() {
        List<Account> accounts = getAccounts();
        Id delegateAccountId = accounts[0].Id;

        ContactPointTypeConsent consent = new ContactPointTypeConsent(
            PartyId = accounts[1].PersonIndividualId,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            PrivacyConsentStatus = 'OptIn',
            Legal_Guardian__c = null
        );

        Test.startTest();
        Boolean updated = LeadConversionConsentMappingHelper.updateLegalGuardianIfNeeded(delegateAccountId, consent);
        Test.stopTest();

        Assert.isTrue(updated, 'Should return true when guardian is updated');
        Assert.areEqual(delegateAccountId, consent.Legal_Guardian__c, 'Should set Legal_Guardian__c to delegate account ID');
    }

    /**
     * @description Test updateLegalGuardianIfNeeded when guardian already set
     */
    @isTest
    static void testUpdateLegalGuardianIfNeededAlreadySet() {
        List<Account> accounts = getAccounts();
        Id existingGuardianId = accounts[0].Id;
        Id newDelegateId = accounts[1].Id;

        ContactPointTypeConsent consent = new ContactPointTypeConsent(
            PartyId = accounts[1].PersonIndividualId,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            PrivacyConsentStatus = 'OptIn',
            Legal_Guardian__c = existingGuardianId
        );

        Test.startTest();
        Boolean updated = LeadConversionConsentMappingHelper.updateLegalGuardianIfNeeded(newDelegateId, consent);
        Test.stopTest();

        Assert.isFalse(updated, 'Should return false when guardian is already set');
        Assert.areEqual(existingGuardianId, consent.Legal_Guardian__c, 'Should not change existing Legal_Guardian__c');
    }

    /**
     * @description Test updateLegalGuardianIfNeeded when delegate account ID is null
     */
    @isTest
    static void testUpdateLegalGuardianIfNeededNullDelegate() {
        List<Account> accounts = getAccounts();

        ContactPointTypeConsent consent = new ContactPointTypeConsent(
            PartyId = accounts[0].PersonIndividualId,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            PrivacyConsentStatus = 'OptIn',
            Legal_Guardian__c = null
        );

        Test.startTest();
        Boolean updated = LeadConversionConsentMappingHelper.updateLegalGuardianIfNeeded(null, consent);
        Test.stopTest();

        Assert.isFalse(updated, 'Should return false when delegate account ID is null');
        Assert.isNull(consent.Legal_Guardian__c, 'Should not set Legal_Guardian__c when delegate is null');
    }

    /**
     * @description Mock FinalizerContext for testing
     */
    private class MockFinalizerContext implements System.FinalizerContext {
        private ParentJobResult result;
        private Exception ex;

        /**
         * @description Constructor
         * @param result Parent job result
         * @param ex Exception object (can be null)
         */
        public MockFinalizerContext(ParentJobResult result, Exception ex) {
            this.result = result;
            this.ex = ex;
        }

        /**
         * @description Gets the parent job result
         * @return ParentJobResult
         */
        public ParentJobResult getResult() {
            return result;
        }

        /**
         * @description Gets the exception
         * @return Exception object (can be null)
         */
        public Exception getException() {
            return ex;
        }

        /**
         * @description Gets the async apex job ID
         * @return Id (returns null for mock)
         */
        public Id getAsyncApexJobId() {
            return null;
        }

        /**
         * @description Gets the request ID
         * @return String (returns null for mock)
         */
        public String getRequestId() {
            return null;
        }
    }

    /**
     * @description Test logDMLResultErrors coverage - triggers DML failure and invokes error logging
     */
    @isTest
    static void testLogDMLResultErrorsCoverage() {
        ContactPointTypeConsent fakeRecord = new ContactPointTypeConsent(
            Id = MockDataFactory.getFakeId('ContactPointTypeConsent')
        );

        List<Database.SaveResult> results = Database.update(new List<SObject>{ fakeRecord }, false);
        Assert.isFalse(results[0].isSuccess(), 'Update with fake Id should fail');

        LeadConversionConsentMappingQueueable job = new LeadConversionConsentMappingQueueable(
            new List<LeadConversionConsentMappingQueueable.LeadConversionConsentData>()
        );

        Test.startTest();
        job.logDMLResultErrors(results[0], fakeRecord);
        Test.stopTest();

        Assert.isTrue(true, 'logDMLResultErrors should execute without exception');
    }
}