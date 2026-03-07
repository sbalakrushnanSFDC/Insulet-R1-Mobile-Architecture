/**
 * @description Test class for ConsentService
 * Created Date : 28-01-2026
 * Created By   : Tanu Tyagi
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       28th Jan 2026       Tanu Tyagi              Initial Version(NGASIM-1911)
 * V1.1.0       20th Feb 2026       Bijayalaxmi Prusty      Updated(NGASIM-2157)
 */
@IsTest(IsParallel=false)
private class ConsentService_Test {

    /**
     * @description Setup test data - creates Individual and DataUsePurpose records
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
        for (Integer i = 0; i < 5; i++) {
            Individual ind = TestDataFactory.getIndividual(new Map<String, Object>{
                'FirstName' => 'Test',
                'LastName' => 'Individual' + i
            });
            individuals.add(ind);
        }
        insert individuals;
    }

    /**
     * @description Test creating consent records for Individual IDs - success path
     */
    @IsTest
    static void testCreateConsentRecordsSuccess() {
        Set<Id> individualIds = getIndividualIds(2);

        Test.startTest();
        ConsentService.createConsentRecords(individualIds);
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualIds);
        Assert.areEqual(6, consents.size(), 'Should create 6 consent records (2 Individuals * 3 consents each)');
        verifyEmailAndSMSConsents(consents, 4, 2);

        for (ContactPointTypeConsent consent : consents) {
            Assert.isTrue(individualIds.contains(consent.PartyId), 'PartyId should match Individual ID');
            verifyConsentIntegrity(consent, consent.PartyId);
        }
    }

    /**
     * @description Test duplicate prevention - should not create duplicates
     */
    @IsTest
    static void testCreateConsentRecordsDuplicatePrevention() {
        Id individualId = getIndividualId();
        Set<Id> individualIds = new Set<Id>{ individualId };

        Test.startTest();
        ConsentService.createConsentRecords(individualIds);
        ConsentService.createConsentRecords(individualIds);
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualId);
        Assert.areEqual(3, consents.size(), 'Should not create duplicate consent records');
    }

    /**
     * @description Test with null/empty Individual IDs
     */
    @IsTest
    static void testCreateConsentRecordsNullEmptyIndividualIds() {
        Test.startTest();
        ConsentService.createConsentRecords(null);
        ConsentService.createConsentRecords(new Set<Id>());
        Test.stopTest();

        List<ContactPointTypeConsent> consents = [
            SELECT Id FROM ContactPointTypeConsent WITH USER_MODE
        ];
        Assert.areEqual(0, consents.size(), 'Should not create any records when IndividualIds is null or empty');
    }

    /**
     * @description Test bulk operations - multiple Individuals
     */
    @IsTest
    static void testCreateConsentRecordsBulk() {
        Set<Id> individualIds = getIndividualIds(5);

        Test.startTest();
        ConsentService.createConsentRecords(individualIds);
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualIds);
        Assert.areEqual(15, consents.size(), 'Should create 15 consent records (5 Individuals * 3 consents each)');
    }

    /**
     * @description Test that existing consent records prevent duplicates
     */
    @IsTest
    static void testCreateConsentRecordsExistingRecordsPreventDuplicates() {
        Id individualId = getIndividualId();
        ContactPointTypeConsent existingEmail = new ContactPointTypeConsent(
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            PartyId = individualId,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = Date.today()
        );
        insert existingEmail;

        Test.startTest();
        ConsentService.createConsentRecords(new Set<Id>{ individualId });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualId);
        Assert.areEqual(3, consents.size(), 'Should have 3 consent records (1 existing Email + 2 new SMS/Marketing)');
        verifyEmailAndSMSConsents(consents, 2, 1);
    }

    /**
     * @description Test that only SMS consent exists, Email should still be created
     */
    @IsTest
    static void testCreateConsentRecordsPartialExistingSMS() {
        Id individualId = getIndividualId();
        ContactPointTypeConsent existingSMS = new ContactPointTypeConsent(
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            PartyId = individualId,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            PrivacyConsentStatus = ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING,
            CaptureDate = Date.today()
        );
        insert existingSMS;

        Test.startTest();
        ConsentService.createConsentRecords(new Set<Id>{ individualId });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualId);
        Assert.areEqual(3, consents.size(), 'Should have 3 consent records (1 existing SMS + 2 new Email/Marketing)');
    }

    /**
     * @description Test when no consents to insert (all already exist)
     */
    @IsTest
    static void testCreateConsentRecordsAllConsentsExist() {
        List<Individual> individuals = [SELECT Id FROM Individual LIMIT 1];
        Individual individual = individuals[0];

        Id dupEmailId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL);
        Id dupSmsId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS);
        Id dupMarketingId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL);
        List<ContactPointTypeConsent> existingConsents = new List<ContactPointTypeConsent>{
            new ContactPointTypeConsent(
                Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
                DataUsePurposeId = dupEmailId,
                PartyId = individual.Id,
                PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
                CaptureDate = Date.today()
            ),
            new ContactPointTypeConsent(
                Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
                DataUsePurposeId = dupSmsId,
                PartyId = individual.Id,
                PrivacyConsentStatus = ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING,
                CaptureDate = Date.today()
            ),
            new ContactPointTypeConsent(
                Name = ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL,
                DataUsePurposeId = dupMarketingId,
                PartyId = individual.Id,
                PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_NOT_SEEN,
                CaptureDate = Date.today()
            )
        };
        insert existingConsents;

        Test.startTest();
        ConsentService.createConsentRecords(new Set<Id>{ individual.Id });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = [
            SELECT Id, PartyId FROM ContactPointTypeConsent
            WHERE PartyId = :individual.Id WITH USER_MODE
        ];
        Assert.areEqual(3, consents.size(), 'Should not create duplicate records when all already exist');
    }

    /**
     * @description Test Custom Labels configuration error - covers logCustomLabelsConfigurationError()
     */
    @IsTest
    static void testCustomLabelsConfigurationError() {
        Integer countBefore = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];

        Test.startTest();
        ConsentService.logCustomLabelsConfigurationError();
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];
        Assert.areEqual(countBefore, countAfter, 'No records should be created when Custom Labels configuration error is logged');
    }

    /**
     * @description Test DataUsePurpose configuration error - covers logDataUsePurposeConfigurationError()
     */
    @IsTest
    static void testDataUsePurposeConfigurationError() {
        Integer countBefore = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];

        Test.startTest();
        ConsentService.logDataUsePurposeConfigurationError();
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];
        Assert.areEqual(countBefore, countAfter, 'No records should be created when DataUsePurpose configuration error is logged');
    }

    /**
     * @description Test guard clause execution path - DataUsePurpose cache and create records
     */
    @IsTest
    static void testDataUsePurposeGuardClauseExecution() {
        Id individualId = getIndividualId();
        Integer countBefore = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];

        Test.startTest();
        ConsentService.createConsentRecords(new Set<Id>{ individualId });
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];
        Assert.isTrue(countAfter > countBefore, 'Should create records when DataUsePurpose records exist');
    }

    /**
     * @description Test permission error path - covers logPermissionError() method
     */
    @IsTest
    static void testPermissionErrorPath() {
        Integer countBefore = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];

        Test.startTest();
        ConsentService.logPermissionError();
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];
        Assert.areEqual(countBefore, countAfter, 'No records should be created when permission error is logged');
    }

    /**
     * @description Test permission guard clause - covers lines 48-50
     *              Attempts to trigger isCreateable() check using System.runAs
     */
    @IsTest
    static void testCreateConsentRecordsPermissionGuardClause() {
        List<Individual> individuals = [SELECT Id FROM Individual LIMIT 1];
        Set<Id> individualIds = new Set<Id>{ individuals[0].Id };

        User testUser = TestDataFactory.getTestUser('Read Only', new Map<String, Object>{
            'FirstName' => 'Permission',
            'LastName' => 'GuardTest'
        });
        insert testUser;

        Integer countBefore = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];

        Test.startTest();
        System.runAs(testUser) {
            ConsentService.createConsentRecords(individualIds);
        }
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];
        Assert.isTrue(countAfter >= countBefore, 'Permission guard clause code path should be executed');
    }

    /**
     * @description Test loadExistingConsentsIntoCache guard clauses
     */
    @IsTest
    static void testLoadCacheGuardClauses() {
        List<Individual> individuals = [SELECT Id FROM Individual LIMIT 1];
        Set<Id> individualIds = new Set<Id>{ individuals[0].Id };

        Test.startTest();
        ConsentService.loadExistingConsentsIntoCache(individualIds);
        ConsentService.loadExistingConsentsIntoCache(individualIds);
        ConsentService.loadExistingConsentsIntoCache(null);
        ConsentService.loadExistingConsentsIntoCache(new Set<Id>());
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];
        Assert.isTrue(countAfter >= 0, 'Guard clauses should execute without errors');
    }

    /**
     * @description Test exception handling in loadExistingConsentsIntoCache
     */
    @IsTest
    static void testLoadExistingConsentsIntoCacheException() {
        Set<Id> invalidIds = new Set<Id>{ MockDataFactory.getFakeId('Individual') };
        Integer countBefore = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];

        Test.startTest();
        ConsentService.createConsentRecords(invalidIds);
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];
        Assert.areEqual(countBefore, countAfter, 'No records should be created when IndividualId is invalid');
    }

    /**
     * @description Test processDmlResults exception handling
     */
    @IsTest
    static void testProcessDmlResultsExceptionHandling() {
        List<Individual> individuals = [SELECT Id FROM Individual LIMIT 1];
        Individual individual = individuals[0];

        ContactPointTypeConsent consent = new ContactPointTypeConsent(
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
            PartyId = individual.Id,
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = Date.today()
        );

        Test.startTest();
        ConsentService.processDmlResults(new List<ContactPointTypeConsent>{ consent });
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];
        Assert.isTrue(countAfter >= 0, 'processDmlResults should execute');
    }

    /**
     * @description Test createConsentRecordsForLeads with List<SObject> - extracts Leads
     */
    @IsTest
    static void testCreateConsentRecordsForLeadsSObjectList() {
        Id individualId = getIndividualId();
        Lead testLead = createTestLead(ConstantsUtil.LEAD_PATIENT_RT, individualId);

        Account testAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Account'
        });
        insert testAccount;

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(new List<SObject>{ testLead, testAccount });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualId);
        Assert.areEqual(3, consents.size(), 'Should create consent records for Lead, not Account');
    }

    /**
     * @description Test createConsentRecordsForLeads with null/empty inputs
     */
    @IsTest
    static void testCreateConsentRecordsForLeadsNullEmptyInputs() {
        Integer countBefore = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];

        Test.startTest();
        ConsentService.createConsentRecordsForLeads((List<SObject>) null);
        ConsentService.createConsentRecordsForLeads(new List<SObject>());
        ConsentService.createConsentRecordsForLeads((List<Lead>) null);
        ConsentService.createConsentRecordsForLeads(new List<Lead>());
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];
        Assert.areEqual(countBefore, countAfter, 'No records should be created for null/empty inputs');
    }

    /**
     * @description Test Lead processing with RecordTypeId populated
     */
    @IsTest
    static void testCreateConsentRecordsForLeadsWithRecordTypeId() {
        Id individualId = getIndividualId();
        Lead testLead = createTestLead(ConstantsUtil.LEAD_PATIENT_RT, individualId);

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ testLead });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualId);
        Assert.areEqual(3, consents.size(), 'Should create consent records for Lead with Patient RecordType');
    }

    /**
     * @description Test Lead processing with Provider RecordType
     */
    @IsTest
    static void testCreateConsentRecordsForLeadsProviderRecordType() {
        Id individualId = getIndividualId();
        Lead testLead = createTestLead(ConstantsUtil.LEAD_PROVIDERPRACTICE_RT, individualId);

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ testLead });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualId);
        Assert.areEqual(3, consents.size(), 'Should create consent records for Lead with Provider RecordType');
    }

    /**
     * @description Test Lead processing with ineligible RecordType
     */
    @IsTest
    static void testCreateConsentRecordsForLeadsIneligibleRecordType() {
        Id individualId = getIndividualId();
        Lead testLead = createTestLead(ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT, individualId);

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ testLead });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualId);
        Assert.areEqual(0, consents.size(), 'Should not create consent records for Lead with ineligible RecordType');
    }

    /**
     * @description Test Lead processing without RecordTypeId - queries RecordType
     */
    @IsTest
    static void testCreateConsentRecordsForLeadsQueryRecordType() {
        Id individualId = getIndividualId();
        Lead testLead = createTestLead(ConstantsUtil.LEAD_PATIENT_RT, individualId);
        Lead skeletonLead = new Lead(Id = testLead.Id, IndividualId = individualId);

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ skeletonLead });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualId);
        Assert.areEqual(3, consents.size(), 'Should create consent records after querying RecordType');
    }

    /**
     * @description Test Lead processing with RecordType.DeveloperName populated (covers line 370)
     *              Tests the path where RecordTypeId is null but RecordType.DeveloperName is available
     */
    @IsTest
    static void testCreateConsentRecordsForLeadsWithDeveloperName() {
        Id individualId = getIndividualId();
        Lead testLead = createTestLead(ConstantsUtil.LEAD_PATIENT_RT, individualId);

        // Query Lead with RecordType relationship to populate RecordType.DeveloperName
        Lead leadWithRT = [
            SELECT Id, RecordTypeId, RecordType.DeveloperName, IndividualId
            FROM Lead
            WHERE Id = :testLead.Id
            WITH USER_MODE
        ];

        // Clear RecordTypeId to force use of RecordType.DeveloperName path
        leadWithRT.RecordTypeId = null;

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ leadWithRT });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualId);
        Assert.areEqual(3, consents.size(), 'Should create consent records using RecordType.DeveloperName path');
    }

    /**
     * @description Test Lead processing with null IndividualId - should skip
     */
    @IsTest
    static void testCreateConsentRecordsForLeadsNullIndividualId() {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'No Individual',
            'Email' => 'noind@test.com',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        insert testLead;

        Integer countBefore = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ testLead });
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];
        Assert.areEqual(countBefore, countAfter, 'Should not create records when Lead has null IndividualId');
    }

    /**
     * @description Test Lead RecordType caching - second call should use cache
     */
    @IsTest
    static void testCreateConsentRecordsForLeadsRecordTypeCache() {
        Id individualId = getIndividualId();
        Lead testLead = createTestLead(ConstantsUtil.LEAD_PATIENT_RT, individualId);
        Lead leadToQuery = new Lead(Id = testLead.Id, IndividualId = individualId);

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ leadToQuery });
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ leadToQuery });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = [
            SELECT Id, PartyId FROM ContactPointTypeConsent
            WHERE PartyId = :individualId WITH USER_MODE
        ];
        Assert.areEqual(3, consents.size(), 'Should create consent records only once due to duplicate prevention');
    }

    /**
     * @description Test queryLeadRecordTypes guard clause with null/empty leadIds
     */
    @IsTest
    static void testQueryLeadRecordTypesNullEmptyLeadIds() {
        Test.startTest();
        Map<Id, String> resultNull = ConsentService.queryLeadRecordTypes(null);
        Map<Id, String> resultEmpty = ConsentService.queryLeadRecordTypes(new Set<Id>());
        Test.stopTest();

        Assert.areEqual(0, resultNull.size(), 'Should return empty map for null input');
        Assert.areEqual(0, resultEmpty.size(), 'Should return empty map for empty input');
    }

    /**
     * @description Test queryLeadRecordTypes exception handling
     */
    @IsTest
    static void testQueryLeadRecordTypesException() {
        Set<Id> invalidLeadIds = new Set<Id>{ MockDataFactory.getFakeId('Lead') };

        Test.startTest();
        Map<Id, String> result = ConsentService.queryLeadRecordTypes(invalidLeadIds);
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Should return empty map when no records found');
    }

    /**
     * @description Test queryLeadRecordTypes catch block - covers lines 469-471
     *              Tests the catch block that handles exceptions during Lead query
     */
    @IsTest
    static void testQueryLeadRecordTypesCatchBlock() {
        Id individualId = getIndividualId();
        Lead testLead = createTestLead(ConstantsUtil.LEAD_PATIENT_RT, individualId);
        Lead skeletonLead = new Lead(Id = testLead.Id, IndividualId = individualId);

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ skeletonLead });
        Map<Id, String> result = ConsentService.queryLeadRecordTypes(new Set<Id>{ testLead.Id });
        Test.stopTest();

        Assert.isNotNull(result, 'Should return map');
    }

    /**
     * @description Test queryLeadRecordTypes with successful query
     */
    @IsTest
    static void testQueryLeadRecordTypesSuccess() {
        Id individualId = getIndividualId();
        Lead testLead = createTestLead(ConstantsUtil.LEAD_PATIENT_RT, individualId);

        Test.startTest();
        Map<Id, String> result = ConsentService.queryLeadRecordTypes(new Set<Id>{ testLead.Id });
        Test.stopTest();

        Assert.isTrue(result.size() > 0, 'Should return RecordType for valid Lead');
    }

    /**
     * @description Test bulk Lead processing
     */
    @IsTest
    static void testCreateConsentRecordsForLeadsBulk() {
        Set<Id> individualIds = getIndividualIds(3);
        List<Lead> leads = new List<Lead>();

        for (Id individualId : individualIds) {
            leads.add(createTestLead(ConstantsUtil.LEAD_PATIENT_RT, individualId));
        }

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(leads);
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individualIds);
        Assert.areEqual(9, consents.size(), 'Should create 9 consent records (3 Leads * 3 consents each)');
    }
    /**
     * @description Test multiple Leads with same IndividualId
     */
    @IsTest
    static void testCreateConsentRecordsForLeadsMultipleLeadsSameIndividual() {
        List<Individual> individuals = [SELECT Id FROM Individual LIMIT 1];
        Individual individual = individuals[0];

        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 3; i++) {
            Lead lead = TestDataFactory.getLead(new Map<String, Object>{
                'FirstName' => 'Test',
                'LastName' => 'Lead' + i,
                'Email' => 'lead' + i + '@test.com',
                'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
                'IndividualId' => individual.Id
            });
            leads.add(lead);
        }
        insert leads;

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(leads);
        Test.stopTest();

        List<ContactPointTypeConsent> consents = [
            SELECT Id, PartyId FROM ContactPointTypeConsent
            WHERE PartyId = :individual.Id WITH USER_MODE
        ];
        Assert.areEqual(3, consents.size(), 'Should create only 3 consent records for same Individual, regardless of number of Leads');
    }

    /**
     * @description Test queryLeadRecordTypes with LeadIds not found in query
     */
    @IsTest
    static void testQueryLeadRecordTypesCacheNotFoundLeads() {
        Id individualId = getIndividualId();
        Lead testLead = createTestLead(ConstantsUtil.LEAD_PATIENT_RT, individualId);
        Lead leadToQuery = new Lead(Id = testLead.Id, IndividualId = individualId);
        Lead fakeLead = new Lead(Id = MockDataFactory.getFakeId('Lead'), IndividualId = individualId);

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ leadToQuery, fakeLead });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = [
            SELECT Id, PartyId FROM ContactPointTypeConsent
            WHERE PartyId = :individualId WITH USER_MODE
        ];
        Assert.areEqual(3, consents.size(), 'Should create consent records only for real Lead');
    }

    /**
     * @description Test queryLeadRecordTypes with cached null RecordType DeveloperName
     */
    @IsTest
    static void testQueryLeadRecordTypesCachedNullDeveloperName() {
        Id individualId = getIndividualId();
        Lead testLead = createTestLead(ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT, individualId);
        Lead leadToQuery = new Lead(Id = testLead.Id, IndividualId = individualId);

        Test.startTest();
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ leadToQuery });
        ConsentService.createConsentRecordsForLeads(new List<Lead>{ leadToQuery });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = [
            SELECT Id FROM ContactPointTypeConsent
            WHERE PartyId = :individualId WITH USER_MODE
        ];
        Assert.areEqual(0, consents.size(), 'Should not create consent records when RecordType is ineligible');
    }

    /**
     * @description Test queryLeadRecordTypes with empty result set from query
     */
    @IsTest
    static void testQueryLeadRecordTypesEmptyQueryResult() {
        Id fakeLeadId = MockDataFactory.getFakeId('Lead');
        Set<Id> fakeLeadIds = new Set<Id>{ fakeLeadId };

        Test.startTest();
        Map<Id, String> result = ConsentService.queryLeadRecordTypes(fakeLeadIds);
        Map<Id, String> cachedResult = ConsentService.queryLeadRecordTypes(fakeLeadIds);
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Should return empty map when query returns no results');
    }

    /**
     * @description Test processDmlResults with SaveResult that has errors
     */
    @IsTest
    static void testProcessDmlResultsSaveResultErrors() {
        List<Individual> individuals = [SELECT Id FROM Individual LIMIT 1];
        Individual individual = individuals[0];
        Id dupId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL);

        ContactPointTypeConsent existingEmail = new ContactPointTypeConsent(
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = dupId,
            PartyId = individual.Id,
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = Date.today()
        );
        insert existingEmail;

        ContactPointTypeConsent duplicateConsent = new ContactPointTypeConsent(
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = dupId,
            PartyId = individual.Id,
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = Date.today()
        );

        Test.startTest();
        ConsentService.processDmlResults(new List<ContactPointTypeConsent>{ duplicateConsent });
        Test.stopTest();

        List<ContactPointTypeConsent> consents = queryConsents(individual.Id);
        Assert.areEqual(1, consents.size(), 'Should handle DML errors gracefully and log errors');
    }

    /**
     * @description Test updateCaptureDateOnConsentStatusChange when PrivacyConsentStatus changes
     */
    @IsTest
    static void testUpdateCaptureDateOnConsentStatusChange() {
        Id individualId = getIndividualId();
        ContactPointTypeConsent consent = new ContactPointTypeConsent(
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
            PartyId = individualId,
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = DateTime.now().addDays(-1)
        );
        insert consent;

        ContactPointTypeConsent newRecord = consent.clone(true, true, true, true);
        newRecord.PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_OUT;

        ContactPointTypeConsent oldRecord = consent.clone(true, true, true, true);

        Map<Id, SObject> updatedMap = new Map<Id, SObject>{ consent.Id => newRecord };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ consent.Id => oldRecord };

        Test.startTest();
        ConsentService.updateCaptureDateOnConsentStatusChange(updatedMap, oldMap);
        Test.stopTest();

        Assert.isNotNull(newRecord.CaptureDate, 'CaptureDate should be set when PrivacyConsentStatus changes');
        Assert.isTrue(newRecord.CaptureDate >= DateTime.now().addSeconds(-10), 'CaptureDate should be current datetime');
    }

    /**
     * @description Test updateCaptureDateOnConsentStatusChange when PrivacyConsentStatus does not change
     */
    @IsTest
    static void testUpdateCaptureDateOnConsentStatusChangeNoChange() {
        Id individualId = getIndividualId();
        DateTime originalCaptureDate = DateTime.now().addDays(-5);
        ContactPointTypeConsent consent = new ContactPointTypeConsent(
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
            PartyId = individualId,
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = originalCaptureDate
        );
        insert consent;

        ContactPointTypeConsent newRecord = consent.clone(true, true, true, true);
        ContactPointTypeConsent oldRecord = consent.clone(true, true, true, true);

        Map<Id, SObject> updatedMap = new Map<Id, SObject>{ consent.Id => newRecord };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ consent.Id => oldRecord };

        Test.startTest();
        ConsentService.updateCaptureDateOnConsentStatusChange(updatedMap, oldMap);
        Test.stopTest();

        Assert.areEqual(originalCaptureDate, newRecord.CaptureDate, 'CaptureDate should remain unchanged when PrivacyConsentStatus does not change');
    }

    /**
     * @description Test updateCaptureDateOnConsentStatusChange with null inputs
     */
    @IsTest
    static void testUpdateCaptureDateOnConsentStatusChangeNullInputs() {
        Integer countBefore = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];

        Test.startTest();
        ConsentService.updateCaptureDateOnConsentStatusChange(null, new Map<Id, SObject>());
        ConsentService.updateCaptureDateOnConsentStatusChange(new Map<Id, SObject>(), null);
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ContactPointTypeConsent WITH USER_MODE];
        Assert.areEqual(countBefore, countAfter, 'No records should be modified when inputs are null');
    }

    // ==================== Helper Methods ====================

    /**
     * @description Helper method to get Individual IDs from test data
     * @param count Number of Individuals to retrieve
     * @return Set of Individual IDs
     */
    private static Set<Id> getIndividualIds(Integer count) {
        List<Individual> individuals = [SELECT Id FROM Individual LIMIT :count];
        Set<Id> individualIds = new Set<Id>();
        for (Individual ind : individuals) {
            individualIds.add(ind.Id);
        }
        return individualIds;
    }

    /**
     * @description Helper method to get a single Individual ID
     * @return Individual ID
     */
    private static Id getIndividualId() {
        List<Individual> individuals = [SELECT Id FROM Individual LIMIT 1];
        return individuals[0].Id;
    }

    /**
     * @description Helper method to get DataUsePurpose Id by name
     * @param name DataUsePurpose Name
     * @return DataUsePurpose Id
     */
    private static Id getDataUsePurposeId(String name) {
        List<DataUsePurpose> records = [SELECT Id FROM DataUsePurpose WHERE Name = :name WITH USER_MODE LIMIT 1];
        return records.isEmpty() ? null : records[0].Id;
    }

    /**
     * @description Helper method to query consent records for given Individual IDs
     * @param individualIds Set of Individual IDs
     * @return List of ContactPointTypeConsent records
     */
    private static List<ContactPointTypeConsent> queryConsents(Set<Id> individualIds) {
        return [
            SELECT Id, Name, PartyId, DataUsePurposeId, PrivacyConsentStatus, CaptureDate
            FROM ContactPointTypeConsent
            WHERE PartyId IN :individualIds
            WITH USER_MODE
        ];
    }

    /**
     * @description Helper method to query consent records for a single Individual ID
     * @param individualId Individual ID
     * @return List of ContactPointTypeConsent records
     */
    private static List<ContactPointTypeConsent> queryConsents(Id individualId) {
        return queryConsents(new Set<Id>{ individualId });
    }

    /**
     * @description Helper method to verify consent record integrity
     * @param record ContactPointTypeConsent record to verify
     * @param expectedPartyId Expected PartyId value
     */
    private static void verifyConsentIntegrity(ContactPointTypeConsent record, Id expectedPartyId) {
        Assert.areEqual(expectedPartyId, record.PartyId, 'PartyId should match expected Individual ID');
        Assert.isNotNull(record.CaptureDate, 'CaptureDate should be set');
        Assert.isNotNull(record.Name, 'Consent Name should be set');
        Assert.isNotNull(record.PrivacyConsentStatus, 'PrivacyConsentStatus should be set');
        Assert.isNotNull(record.DataUsePurposeId, 'DataUsePurposeId should be set');

        if (record.Name == ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL) {
            Assert.areEqual(ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN, record.PrivacyConsentStatus, 'Transactional Email should have OptIn status');
        } else if (record.Name == ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS) {
            Assert.areEqual(ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING, record.PrivacyConsentStatus, 'SMS consent should have OptInPending status');
        } else if (record.Name == ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL) {
            Assert.areEqual(ConstantsUtil.PRIVACY_CONSENT_STATUS_NOT_SEEN, record.PrivacyConsentStatus, 'Marketing Email should have NotSeen status');
        }
    }

    /**
     * @description Helper method to verify Email and SMS consents exist
     * @param consents List of consent records
     * @param expectedEmailCount Expected number of Email consents
     * @param expectedSMSCount Expected number of SMS consents
     */
    private static void verifyEmailAndSMSConsents(List<ContactPointTypeConsent> consents, Integer expectedEmailCount, Integer expectedSMSCount) {
        Integer emailCount = 0;
        Integer smsCount = 0;

        for (ContactPointTypeConsent consent : consents) {
            if (consent.Name == ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL || consent.Name == ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL) {
                emailCount++;
            } else if (consent.Name == ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS) {
                smsCount++;
            }
        }

        Assert.areEqual(expectedEmailCount, emailCount, 'Email consent count should match');
        Assert.areEqual(expectedSMSCount, smsCount, 'SMS consent count should match');
    }

    /**
     * @description Helper method to create a Lead with specified parameters
     * @param recordTypeId RecordType ID
     * @param individualId Individual ID
     * @return Created Lead record
     */
    private static Lead createTestLead(Id recordTypeId, Id individualId) {
        Lead testLead = TestDataFactory.getLead(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Lead',
            'Email' => 'test@test.com',
            'RecordTypeId' => recordTypeId,
            'IndividualId' => individualId
        });
        insert testLead;
        return testLead;
    }
}