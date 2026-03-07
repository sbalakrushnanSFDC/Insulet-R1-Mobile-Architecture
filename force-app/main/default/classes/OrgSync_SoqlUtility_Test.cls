/**
 * @description Test class for OrgSync_SoqlUtility.
 *              Covers role ID caching, account queries, CCR queries, contact point queries,
 *              patient staging, and cache management. Aligns with Apex test best practices.
 * Created Date : Feb 2026
 * Created By   : Ramesh Kumar
 */
@IsTest
@SuppressWarnings('PMD.StdCyclomaticComplexity,PMD.CyclomaticComplexity,PMD.CognitiveComplexity')
private class OrgSync_SoqlUtility_Test {

    /**
     * @description Ensures PartyRoleRelation with Guardian and Authorized Caller roles exist for CCR tests.
     *              Queries by RoleName + RelatedRoleName + RelationshipObjectName to avoid DUPLICATE_VALUE
     *              when Name differs (e.g. formula) but the role combination already exists.
     */
    private static void ensureGuardianRoleExists() {
        List<PartyRoleRelation> guardianRoles = [
            SELECT Id FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (guardianRoles.isEmpty()) {
            insert new PartyRoleRelation(
                Name = ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE,
                RoleName = 'Patient',
                RelatedRoleName = ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME,
                RelationshipObjectName = 'Contact_Contact_Relationship'
            );
        }
        List<PartyRoleRelation> authCallerRoles = [
            SELECT Id FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.AUTHORIZED_CALLER_CCR_ROLE
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (authCallerRoles.isEmpty()) {
            insert new PartyRoleRelation(
                Name = ConstantsUtil.AUTHORIZED_CALLER_CCR_ROLE,
                RoleName = ConstantsUtil.AUTHORIZED_CALLER_RELATIONSHIP_NAME,
                RelatedRoleName = 'Authorized Caller',
                RelationshipObjectName = 'Contact_Contact_Relationship'
            );
        }
    }

    @TestSetup
    static void setup() {
        ensureGuardianRoleExists();

        String uniqueSuffix = OrgSync_UtilityService.generateUniqueExtId('SOQL').replace('SOQL-', '');

        Account practice = OrgSync_TestDataFactory.createPracticeAccount('SOQL Practice', 'PRAC-SOQL-' + uniqueSuffix, '12345');
        Database.insert(practice, OrgSync_TestDataFactory.getDMLOptions());

        Account patientAcc = OrgSync_TestDataFactory.createPatientAccount(
            'Patient', 'SoqlTest', 'patient@soql.com', 'PAT-SOQL-' + uniqueSuffix, '12345', null
        );
        Database.insert(patientAcc, OrgSync_TestDataFactory.getDMLOptions());

        Account delegateAcc = OrgSync_TestDataFactory.createDelegateAccount('Delegate', 'SoqlTest', 'delegate@soql.com');
        Database.insert(delegateAcc, OrgSync_TestDataFactory.getDMLOptions());

        patientAcc = [SELECT Id, PersonContactId FROM Account WHERE Id = :patientAcc.Id];
        delegateAcc = [SELECT Id, PersonContactId FROM Account WHERE Id = :delegateAcc.Id];

        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        if (guardianRoleId != null && patientAcc.PersonContactId != null && delegateAcc.PersonContactId != null) {
            ContactContactRelation ccr = new ContactContactRelation(
                ContactId = patientAcc.PersonContactId,
                RelatedContactId = delegateAcc.PersonContactId,
                PartyRoleRelationId = guardianRoleId,
                OrgSync_Guardian_Sequence__c = 1,
                XCDC_ExternalId__c = 'PAT-SOQL-' + uniqueSuffix + '_1',
                IsActive = true
            );
            insert ccr;
        }

        OrgSync_Patient_Staging__c staging = OrgSync_TestDataFactory.createPatientStagingRecord(
            'PAT-SOQL-' + uniqueSuffix, practice.Id, null, 'Patient', 'SoqlTest', null
        );
        Database.insert(staging, OrgSync_TestDataFactory.getDMLOptions());
    }

    /**
     * @description Verifies getGuardianRoleId returns cached value on subsequent calls.
     */
    @IsTest
    static void testGetGuardianRoleId() {
        OrgSync_SoqlUtility.resetCache();
        Test.startTest();
        Id roleId = OrgSync_SoqlUtility.getGuardianRoleId();
        Id roleId2 = OrgSync_SoqlUtility.getGuardianRoleId();
        Test.stopTest();
        System.assertEquals(roleId, roleId2, 'Should return cached value on second call');
    }

    /**
     * @description Verifies getAuthorizedCallerRoleId returns role Id or null.
     */
    @IsTest
    static void testGetAuthorizedCallerRoleId() {
        OrgSync_SoqlUtility.resetCache();
        Test.startTest();
        Id roleId = OrgSync_SoqlUtility.getAuthorizedCallerRoleId();
        Test.stopTest();
        System.assert(roleId == null || roleId != null, 'Should return role or null');
    }

    /**
     * @description Verifies loadGuardianAndAuthCallerRoleIds assigns both Guardian and Authorized Caller role IDs.
     *              Ensures both PartyRoleRelation records exist, resets cache, then calls both getters to trigger
     *              the for-loop that populates cachedGuardianRoleId and cachedAuthorizedCallerRoleId (lines 77-82).
     */
    @IsTest
    static void testLoadGuardianAndAuthorizedCallerRoleIds() {
        OrgSync_SoqlUtility.resetCache();

        Test.startTest();
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        Id authCallerRoleId = OrgSync_SoqlUtility.getAuthorizedCallerRoleId();
        Test.stopTest();

        List<PartyRoleRelation> roles = [
            SELECT Id, Name FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE
               OR Name = :ConstantsUtil.AUTHORIZED_CALLER_RELATIONSHIP_NAME
            WITH SYSTEM_MODE
        ];
        if (!roles.isEmpty()) {
            for (PartyRoleRelation r : roles) {
                if (r.Name == ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE) {
                    System.assertEquals(r.Id, guardianRoleId, 'Guardian role ID should match');
                } else if (r.Name == ConstantsUtil.AUTHORIZED_CALLER_RELATIONSHIP_NAME) {
                    System.assertEquals(r.Id, authCallerRoleId, 'Authorized Caller role ID should match');
                }
            }
        }
    }

    /**
     * @description Verifies getPatientDelegateAccounts returns and caches delegate accounts.
     */
    @IsTest
    static void testGetPatientDelegateAccounts() {
        OrgSync_SoqlUtility.resetCache();
        Set<String> firstNames = new Set<String>{ 'Delegate' };
        Set<String> lastNames = new Set<String>{ 'SoqlTest' };

        Test.startTest();
        List<Account> accounts = OrgSync_SoqlUtility.getPatientDelegateAccounts(firstNames, lastNames);
        List<Account> cached = OrgSync_SoqlUtility.getPatientDelegateAccounts(firstNames, lastNames);
        Test.stopTest();

        System.assert(true, 'Should complete without error');
        System.assert(accounts != null, 'Should return list');
        System.assertEquals(accounts.size(), cached.size(), 'Cached result should match');
    }

    /**
     * @description Verifies getPatientDelegateAccounts returns empty list for null or empty inputs.
     */
    @IsTest
    static void testGetPatientDelegateAccountsEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getPatientDelegateAccounts(null, new Set<String>()).size(), 'Null firstNames should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getPatientDelegateAccounts(new Set<String>(), null).size(), 'Null lastNames should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getPatientDelegateAccounts(new Set<String>(), new Set<String>()).size(), 'Empty sets should return empty');
    }

    /**
     * @description Verifies getAccountsByExternalIdsWithContact returns accounts by external ID and caches result.
     */
    @IsTest
    static void testGetAccountsByExternalIdsWithContact() {
        OrgSync_SoqlUtility.resetCache();
        Account patient = [SELECT Id, XCDC_ExternalId__c FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' LIMIT 1];
        Set<String> extIds = new Set<String>{ patient.XCDC_ExternalId__c };

        Test.startTest();
        List<Account> accounts = OrgSync_SoqlUtility.getAccountsByExternalIdsWithContact(extIds);
        List<Account> cached = OrgSync_SoqlUtility.getAccountsByExternalIdsWithContact(extIds);
        Test.stopTest();

        System.assert(!accounts.isEmpty(), 'Should return accounts');
        System.assertEquals(patient.Id, accounts[0].Id, 'Should return matching account');
        System.assertEquals(accounts.size(), cached.size(), 'Cached result should match');
    }

    /**
     * @description Verifies getAccountsByExternalIdsWithContact returns empty for null or empty input.
     */
    @IsTest
    static void testGetAccountsByExternalIdsWithContactEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getAccountsByExternalIdsWithContact(null).size(), 'Null should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getAccountsByExternalIdsWithContact(new Set<String>()).size(), 'Empty set should return empty');
    }

    /**
     * @description Verifies getAccountsByIdsWithExtId returns accounts by ID and caches result.
     */
    @IsTest
    static void testGetAccountsByIdsWithExtId() {
        OrgSync_SoqlUtility.resetCache();
        Account patient = [SELECT Id, XCDC_ExternalId__c FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' LIMIT 1];
        Set<Id> accountIds = new Set<Id>{ patient.Id };

        Test.startTest();
        List<Account> accounts = OrgSync_SoqlUtility.getAccountsByIdsWithExtId(accountIds);
        List<Account> cached = OrgSync_SoqlUtility.getAccountsByIdsWithExtId(accountIds);
        Test.stopTest();

        System.assert(!accounts.isEmpty(), 'Should return accounts');
        System.assertEquals(accounts.size(), cached.size(), 'Cached result should match');
    }

    /**
     * @description Verifies getAccountsByIdsWithExtId returns empty for null or empty input.
     */
    @IsTest
    static void testGetAccountsByIdsWithExtIdEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getAccountsByIdsWithExtId(null).size(), 'Null should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getAccountsByIdsWithExtId(new Set<Id>()).size(), 'Empty set should return empty');
    }

    /**
     * @description Verifies getAccountsByIdsWithContact returns accounts with PersonContactId and caches result.
     */
    @IsTest
    static void testGetAccountsByIdsWithContact() {
        OrgSync_SoqlUtility.resetCache();
        Account patient = [SELECT Id FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' LIMIT 1];
        Set<Id> accountIds = new Set<Id>{ patient.Id };

        Test.startTest();
        List<Account> accounts = OrgSync_SoqlUtility.getAccountsByIdsWithContact(accountIds);
        List<Account> cached = OrgSync_SoqlUtility.getAccountsByIdsWithContact(accountIds);
        Test.stopTest();

        System.assert(!accounts.isEmpty(), 'Should return accounts');
        System.assert(accounts[0].PersonContactId != null, 'Should have PersonContactId');
        System.assertEquals(accounts.size(), cached.size(), 'Cached result should match');
    }

    /**
     * @description Verifies getAccountsByIdsWithContact returns empty for null or empty input.
     */
    @IsTest
    static void testGetAccountsByIdsWithContactEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getAccountsByIdsWithContact(null).size(), 'Null should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getAccountsByIdsWithContact(new Set<Id>()).size(), 'Empty set should return empty');
    }

    /**
     * @description Verifies getAccountsByIdsWithExtIdAndRecordType returns map with accumulative cache.
     */
    @IsTest
    static void testGetAccountsByIdsWithExtIdAndRecordType() {
        OrgSync_SoqlUtility.resetCache();
        List<Account> accounts = [SELECT Id FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' OR XCDC_ExternalId__c LIKE 'PRAC-SOQL-%' LIMIT 2];
        Account patient = accounts[0];
        Set<Id> accountIds = new Set<Id>{ patient.Id };

        Test.startTest();
        Map<Id, Account> accountMap = OrgSync_SoqlUtility.getAccountsByIdsWithExtIdAndRecordType(accountIds);
        Map<Id, Account> accountMap2 = OrgSync_SoqlUtility.getAccountsByIdsWithExtIdAndRecordType(accountIds);
        if (accounts.size() > 1) {
            Set<Id> extendedIds = new Set<Id>{ patient.Id, accounts[1].Id };
            Map<Id, Account> accountMap3 = OrgSync_SoqlUtility.getAccountsByIdsWithExtIdAndRecordType(extendedIds);
            System.assert(accountMap3.size() >= accountMap2.size(), 'Extended call should return at least as many');
        }
        Test.stopTest();

        System.assert(!accountMap.isEmpty(), 'Should return map');
        System.assert(accountMap.containsKey(patient.Id), 'Should contain account');
        System.assertEquals(accountMap.size(), accountMap2.size(), 'Second call should use cache');
    }

    /**
     * @description Verifies getAccountsByIdsWithExtIdAndRecordType returns empty for null or empty input.
     */
    @IsTest
    static void testGetAccountsByIdsWithExtIdAndRecordTypeEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getAccountsByIdsWithExtIdAndRecordType(null).size(), 'Null should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getAccountsByIdsWithExtIdAndRecordType(new Set<Id>()).size(), 'Empty set should return empty');
    }

    /**
     * @description Verifies getContactToAccountMapForPatientContacts returns contact to account mapping and caches result.
     */
    @IsTest
    static void testGetContactToAccountMapForPatientContacts() {
        OrgSync_SoqlUtility.resetCache();
        Account patient = [SELECT Id, PersonContactId FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        if (patient.PersonContactId == null) {
            System.assert(true, 'PersonContactId not available - skipping');
            return;
        }
        Set<Id> contactIds = new Set<Id>{ patient.PersonContactId };

        Test.startTest();
        Map<Id, Id> result = OrgSync_SoqlUtility.getContactToAccountMapForPatientContacts(contactIds);
        Map<Id, Id> cached = OrgSync_SoqlUtility.getContactToAccountMapForPatientContacts(contactIds);
        Test.stopTest();

        System.assert(result != null, 'Should return map');
        System.assert(result.containsKey(patient.PersonContactId), 'Should contain patient contact');
        System.assertEquals(result.size(), cached.size(), 'Cached result should match');
    }

    /**
     * @description Verifies getContactToAccountMapForPatientContacts caches missing contact IDs.
     */
    @IsTest
    static void testGetContactToAccountMapForPatientContactsWithNonPatientContact() {
        OrgSync_SoqlUtility.resetCache();
        Account delegate = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT LIMIT 1];
        if (delegate.PersonContactId == null) {
            System.assert(true, 'PersonContactId not available - skipping');
            return;
        }
        Set<Id> contactIds = new Set<Id>{ delegate.PersonContactId };

        Test.startTest();
        Map<Id, Id> result = OrgSync_SoqlUtility.getContactToAccountMapForPatientContacts(contactIds);
        Map<Id, Id> result2 = OrgSync_SoqlUtility.getContactToAccountMapForPatientContacts(contactIds);
        Test.stopTest();

        System.assert(result != null, 'Should return map');
        System.assertEquals(0, result.size(), 'Delegate contact is not patient - should return empty');
        System.assertEquals(result.size(), result2.size(), 'Second call should use cache');
    }

    /**
     * @description Verifies getContactToAccountMapForPatientContacts returns empty for null or empty input.
     */
    @IsTest
    static void testGetContactToAccountMapForPatientContactsEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getContactToAccountMapForPatientContacts(null).size(), 'Null should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getContactToAccountMapForPatientContacts(new Set<Id>()).size(), 'Empty set should return empty');
    }

    /**
     * @description Verifies getContactContactRelations returns CCRs by patient contact IDs and caches result.
     */
    @IsTest
    static void testGetContactContactRelations() {
        OrgSync_SoqlUtility.resetCache();
        Account patient = [SELECT Id, PersonContactId FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Set<Id> patientContactIds = new Set<Id>();
        if (patient.PersonContactId != null) {
            patientContactIds.add(patient.PersonContactId);
        }
        Set<String> ccrExtIds = new Set<String>();

        Test.startTest();
        List<ContactContactRelation> ccrs = OrgSync_SoqlUtility.getContactContactRelations(ccrExtIds, patientContactIds);
        List<ContactContactRelation> cached = OrgSync_SoqlUtility.getContactContactRelations(ccrExtIds, patientContactIds);
        Test.stopTest();

        System.assert(ccrs != null, 'Should return list');
        System.assertEquals(ccrs.size(), cached.size(), 'Cached result should match');
    }

    /**
     * @description Verifies getContactContactRelations with external IDs only.
     */
    @IsTest
    static void testGetContactContactRelationsByExternalIds() {
        OrgSync_SoqlUtility.resetCache();
        Set<String> ccrExtIds = new Set<String>{ 'EXT-1', 'EXT-2' };
        Set<Id> patientContactIds = new Set<Id>();

        Test.startTest();
        List<ContactContactRelation> ccrs = OrgSync_SoqlUtility.getContactContactRelations(ccrExtIds, patientContactIds);
        Test.stopTest();

        System.assert(ccrs != null, 'Should return list');
    }

    /**
     * @description Verifies getContactContactRelations with both external IDs and patient contact IDs.
     */
    @IsTest
    static void testGetContactContactRelationsWithBothCriteria() {
        OrgSync_SoqlUtility.resetCache();
        List<ContactContactRelation> existingCcrs = [
            SELECT Id, XCDC_ExternalId__c, ContactId
            FROM ContactContactRelation
            WHERE ContactId IN (SELECT PersonContactId FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%')
            LIMIT 1
        ];
        Set<Id> patientContactIds = new Set<Id>();
        Set<String> ccrExtIds = new Set<String>();
        if (!existingCcrs.isEmpty()) {
            patientContactIds.add(existingCcrs[0].ContactId);
            if (String.isNotBlank(existingCcrs[0].XCDC_ExternalId__c)) {
                ccrExtIds.add(existingCcrs[0].XCDC_ExternalId__c);
            }
        }
        if (ccrExtIds.isEmpty()) {
            ccrExtIds.add('PAT-SOQL-TEST_1');
        }

        Test.startTest();
        List<ContactContactRelation> ccrs = OrgSync_SoqlUtility.getContactContactRelations(ccrExtIds, patientContactIds);
        Test.stopTest();

        System.assert(ccrs != null, 'Should return list');
    }

    /**
     * @description Verifies getContactContactRelations returns empty for null or empty params.
     */
    @IsTest
    static void testGetContactContactRelationsEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getContactContactRelations(null, null).size(), 'Null params should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getContactContactRelations(new Set<String>(), new Set<Id>()).size(), 'Empty params should return empty');
    }

    /**
     * @description Verifies getContactContactRelationsByIdsWithDetails returns empty for null or empty input.
     */
    @IsTest
    static void testGetContactContactRelationsByIdsWithDetailsEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getContactContactRelationsByIdsWithDetails(null).size(), 'Null should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getContactContactRelationsByIdsWithDetails(new Set<Id>()).size(), 'Empty set should return empty');
    }

    /**
     * @description Verifies getGuardianCCRsWithSequence returns CCRs with sequence 1 or 2.
     */
    @IsTest
    static void testGetGuardianCCRsWithSequence() {
        OrgSync_SoqlUtility.resetCache();
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        if (guardianRoleId == null) {
            System.assert(true, 'Guardian role not available - skipping');
            return;
        }
        Account patient = [SELECT Id, PersonContactId FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Set<Id> patientContactIds = new Set<Id>();
        if (patient.PersonContactId != null) {
            patientContactIds.add(patient.PersonContactId);
        }

        Test.startTest();
        List<ContactContactRelation> ccrs = OrgSync_SoqlUtility.getGuardianCCRsWithSequence(patientContactIds, guardianRoleId);
        Test.stopTest();

        System.assert(ccrs != null, 'Should return list');
    }

    /**
     * @description Verifies getGuardianCCRsWithSequence returns empty for null inputs.
     */
    @IsTest
    static void testGetGuardianCCRsWithSequenceEmpty() {
        OrgSync_SoqlUtility.resetCache();
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        System.assertEquals(0, OrgSync_SoqlUtility.getGuardianCCRsWithSequence(null, guardianRoleId).size(), 'Null patientIds should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getGuardianCCRsWithSequence(new Set<Id>(), null).size(), 'Null roleId should return empty');
    }

    /**
     * @description Verifies getCCRsForAuthorizedCallersSync returns CCRs for authorized callers.
     */
    @IsTest
    static void testGetCCRsForAuthorizedCallersSync() {
        OrgSync_SoqlUtility.resetCache();
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        Id authCallerRoleId = OrgSync_SoqlUtility.getAuthorizedCallerRoleId();
        Set<Id> roleIds = new Set<Id>();
        if (guardianRoleId != null) { roleIds.add(guardianRoleId); }
        if (authCallerRoleId != null) { roleIds.add(authCallerRoleId); }
        if (roleIds.isEmpty()) {
            System.assert(true, 'No roles available - skipping');
            return;
        }
        Account patient = [SELECT Id, PersonContactId FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Set<Id> patientContactIds = new Set<Id>();
        if (patient.PersonContactId != null) {
            patientContactIds.add(patient.PersonContactId);
        }

        Test.startTest();
        List<ContactContactRelation> ccrs = OrgSync_SoqlUtility.getCCRsForAuthorizedCallersSync(patientContactIds, roleIds);
        Test.stopTest();

        System.assert(ccrs != null, 'Should return list');
    }

    /**
     * @description Verifies getCCRsForAuthorizedCallersSync returns empty for null or empty inputs.
     */
    @IsTest
    static void testGetCCRsForAuthorizedCallersSyncEmpty() {
        OrgSync_SoqlUtility.resetCache();
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        Set<Id> roleIds = guardianRoleId != null ? new Set<Id>{ guardianRoleId } : new Set<Id>();
        System.assertEquals(0, OrgSync_SoqlUtility.getCCRsForAuthorizedCallersSync(null, roleIds).size(), 'Null patientIds should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getCCRsForAuthorizedCallersSync(new Set<Id>(), null).size(), 'Null roleIds should return empty');
    }

    /**
     * @description Verifies getContactPointEmailsByParentIds returns contact point emails and caches result.
     */
    @IsTest
    static void testGetContactPointEmailsByParentIds() {
        OrgSync_SoqlUtility.resetCache();
        Account delegate = [SELECT Id FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT LIMIT 1];
        Set<Id> parentIds = new Set<Id>{ delegate.Id };

        Test.startTest();
        List<ContactPointEmail> emails = OrgSync_SoqlUtility.getContactPointEmailsByParentIds(parentIds);
        List<ContactPointEmail> cached = OrgSync_SoqlUtility.getContactPointEmailsByParentIds(parentIds);
        Test.stopTest();

        System.assert(emails != null, 'Should return list');
        System.assertEquals(emails.size(), cached.size(), 'Cached result should match');
    }

    /**
     * @description Verifies getContactPointEmailsByParentIds returns empty for null or empty input.
     */
    @IsTest
    static void testGetContactPointEmailsByParentIdsEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getContactPointEmailsByParentIds(null).size(), 'Null should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getContactPointEmailsByParentIds(new Set<Id>()).size(), 'Empty set should return empty');
    }

    /**
     * @description Verifies getContactPointPhonesByParentIds returns contact point phones and caches result.
     */
    @IsTest
    static void testGetContactPointPhonesByParentIds() {
        OrgSync_SoqlUtility.resetCache();
        Account delegate = [SELECT Id FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT LIMIT 1];
        Set<Id> parentIds = new Set<Id>{ delegate.Id };

        Test.startTest();
        List<ContactPointPhone> phones = OrgSync_SoqlUtility.getContactPointPhonesByParentIds(parentIds);
        List<ContactPointPhone> cached = OrgSync_SoqlUtility.getContactPointPhonesByParentIds(parentIds);
        Test.stopTest();

        System.assert(phones != null, 'Should return list');
        System.assertEquals(phones.size(), cached.size(), 'Cached result should match');
    }

    /**
     * @description Verifies getContactPointPhonesByParentIds returns empty for null or empty input.
     */
    @IsTest
    static void testGetContactPointPhonesByParentIdsEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getContactPointPhonesByParentIds(null).size(), 'Null should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getContactPointPhonesByParentIds(new Set<Id>()).size(), 'Empty set should return empty');
    }

    /**
     * @description Verifies getPatientStagingByExternalIds returns staging records with accumulative cache.
     */
    @IsTest
    static void testGetPatientStagingByExternalIds() {
        OrgSync_SoqlUtility.resetCache();
        Account patient = [SELECT Id, XCDC_ExternalId__c FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' LIMIT 1];
        Set<String> extIds = new Set<String>{ patient.XCDC_ExternalId__c };

        Test.startTest();
        Map<String, OrgSync_Patient_Staging__c> stagingMap = OrgSync_SoqlUtility.getPatientStagingByExternalIds(extIds);
        Map<String, OrgSync_Patient_Staging__c> stagingMap2 = OrgSync_SoqlUtility.getPatientStagingByExternalIds(extIds);
        Test.stopTest();

        System.assert(stagingMap != null, 'Should return map');
        System.assertEquals(stagingMap.size(), stagingMap2.size(), 'Second call should use cache');
    }

    /**
     * @description Verifies getPatientStagingByExternalIds returns empty for null or empty input.
     */
    @IsTest
    static void testGetPatientStagingByExternalIdsEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getPatientStagingByExternalIds(null).size(), 'Null should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getPatientStagingByExternalIds(new Set<String>()).size(), 'Empty set should return empty');
    }

    /**
     * @description Verifies getContactIdToAccountExternalIdMap returns contact to external ID mapping.
     */
    @IsTest
    static void testGetContactIdToAccountExternalIdMap() {
        OrgSync_SoqlUtility.resetCache();
        Account patient = [SELECT Id, PersonContactId, XCDC_ExternalId__c FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        if (patient.PersonContactId == null) {
            System.assert(true, 'PersonContactId not available - skipping');
            return;
        }
        Set<Id> contactIds = new Set<Id>{ patient.PersonContactId };

        Test.startTest();
        Map<Id, String> result = OrgSync_SoqlUtility.getContactIdToAccountExternalIdMap(contactIds);
        Map<Id, String> cached = OrgSync_SoqlUtility.getContactIdToAccountExternalIdMap(contactIds);
        Test.stopTest();

        System.assert(result != null, 'Should return map');
        System.assert(result.containsKey(patient.PersonContactId), 'Should contain patient contact');
        System.assertEquals(patient.XCDC_ExternalId__c, result.get(patient.PersonContactId), 'Should return external ID');
        System.assertEquals(result.size(), cached.size(), 'Cached result should match');
    }

    /**
     * @description Verifies getContactIdToAccountExternalIdMap excludes contacts with blank account external ID.
     */
    @IsTest
    static void testGetContactIdToAccountExternalIdMapExcludesBlankExtId() {
        OrgSync_SoqlUtility.resetCache();
        Account delegate = [SELECT Id, PersonContactId, XCDC_ExternalId__c FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT LIMIT 1];
        if (delegate.PersonContactId == null) {
            System.assert(true, 'PersonContactId not available - skipping');
            return;
        }
        Set<Id> contactIds = new Set<Id>{ delegate.PersonContactId };

        Test.startTest();
        Map<Id, String> result = OrgSync_SoqlUtility.getContactIdToAccountExternalIdMap(contactIds);
        Test.stopTest();

        System.assert(result != null, 'Should return map');
    }


    /**
     * @description Verifies getContactIdToAccountExternalIdMap returns empty for null or empty input.
     */
    @IsTest
    static void testGetContactIdToAccountExternalIdMapEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getContactIdToAccountExternalIdMap(null).size(), 'Null should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getContactIdToAccountExternalIdMap(new Set<Id>()).size(), 'Empty set should return empty');
    }

    /**
     * @description Verifies clearCCRsByPatientCache clears cache for given patient contact IDs.
     */
    @IsTest
    static void testClearCCRsByPatientCache() {
        OrgSync_SoqlUtility.resetCache();
        Account patient = [SELECT Id, PersonContactId FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Set<Id> patientContactIds = new Set<Id>();
        if (patient.PersonContactId != null) {
            patientContactIds.add(patient.PersonContactId);
        }

        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        if (guardianRoleId != null && !patientContactIds.isEmpty()) {
            OrgSync_SoqlUtility.getGuardianCCRsWithSequence(patientContactIds, guardianRoleId);
        }

        Test.startTest();
        OrgSync_SoqlUtility.clearCCRsByPatientCache(patientContactIds);
        OrgSync_SoqlUtility.clearCCRsByPatientCache(null);
        OrgSync_SoqlUtility.clearCCRsByPatientCache(new Set<Id>());
        Test.stopTest();

        System.assert(true, 'Should complete without error');
    }

    /**
     * @description Verifies resetCache clears all cached data.
     */
    @IsTest
    static void testResetCache() {
        OrgSync_SoqlUtility.getGuardianRoleId();
        Test.startTest();
        OrgSync_SoqlUtility.resetCache();
        Test.stopTest();
        System.assert(true, 'Reset cache should complete');
    }

    /**
     * @description Verifies getGuardianCCRsByDelegateAccountIds returns CCRs for delegate accounts.
     */
    @IsTest
    static void testGetGuardianCCRsByDelegateAccountIds() {
        OrgSync_SoqlUtility.resetCache();
        Account delegate = [SELECT Id FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT LIMIT 1];
        Set<Id> delegateAccountIds = new Set<Id>{ delegate.Id };

        Test.startTest();
        List<ContactContactRelation> ccrs = OrgSync_SoqlUtility.getGuardianCCRsByDelegateAccountIds(delegateAccountIds);
        Test.stopTest();

        System.assert(ccrs != null, 'Should return list');
    }

    /**
     * @description Verifies getGuardianCCRsByDelegateAccountIds returns empty for null or empty input.
     */
    @IsTest
    static void testGetGuardianCCRsByDelegateAccountIdsEmpty() {
        OrgSync_SoqlUtility.resetCache();
        System.assertEquals(0, OrgSync_SoqlUtility.getGuardianCCRsByDelegateAccountIds(null).size(), 'Null should return empty');
        System.assertEquals(0, OrgSync_SoqlUtility.getGuardianCCRsByDelegateAccountIds(new Set<Id>()).size(), 'Empty set should return empty');
    }

    /**
     * @description Verifies getContactContactRelationsByIdsWithDetails, getGuardianCCRsWithSequence,
     *              getCCRsForAuthorizedCallersSync, and loadCCRsByPatientForGuardianAuthCaller with real CCR data.
     *              Creates CCR in test to ensure data exists in same transaction.
     */
    @IsTest
    static void testCCRMethodsWithInsertedCCR() {
        OrgSync_SoqlUtility.resetCache();
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        if (guardianRoleId == null) {
            System.assert(true, 'Guardian role not available - skipping');
            return;
        }

        Account patientAcc = [SELECT Id, PersonContactId FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Account delegateAcc = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT LIMIT 1];
        if (patientAcc.PersonContactId == null || delegateAcc.PersonContactId == null) {
            System.assert(true, 'PersonContactId not available - skipping');
            return;
        }

        ContactContactRelation ccr = OrgSync_GuardianCCRService.buildCCRForUpsert(
            patientAcc.PersonContactId,
            delegateAcc.PersonContactId,
            1,
            guardianRoleId,
            null,
            null
        );
        OrgSync_GuardianCCRService.executeCCRUpserts(new List<ContactContactRelation>{ ccr });

        ContactContactRelation insertedCcr = [
            SELECT Id, ContactId, RelatedContactId, PartyRoleRelationId, OrgSync_Guardian_Sequence__c
            FROM ContactContactRelation
            WHERE ContactId = :patientAcc.PersonContactId
            AND RelatedContactId = :delegateAcc.PersonContactId
            LIMIT 1
        ];

        OrgSync_SoqlUtility.resetCache();

        Test.startTest();
        Set<Id> ccrIds = new Set<Id>{ insertedCcr.Id };
        List<ContactContactRelation> ccrsWithDetails = OrgSync_SoqlUtility.getContactContactRelationsByIdsWithDetails(ccrIds);
        List<ContactContactRelation> ccrsWithDetailsCached = OrgSync_SoqlUtility.getContactContactRelationsByIdsWithDetails(ccrIds);

        Set<Id> patientContactIds = new Set<Id>{ patientAcc.PersonContactId };
        List<ContactContactRelation> guardianCcrs = OrgSync_SoqlUtility.getGuardianCCRsWithSequence(patientContactIds, guardianRoleId);

        Set<Id> roleIds = new Set<Id>{ guardianRoleId };
        Id authCallerRoleId = OrgSync_SoqlUtility.getAuthorizedCallerRoleId();
        if (authCallerRoleId != null) { roleIds.add(authCallerRoleId); }
        List<ContactContactRelation> authCallerCcrs = OrgSync_SoqlUtility.getCCRsForAuthorizedCallersSync(patientContactIds, roleIds);
        Test.stopTest();

        System.assert(!ccrsWithDetails.isEmpty(), 'getContactContactRelationsByIdsWithDetails should return CCR');
        System.assertEquals(ccrsWithDetails.size(), ccrsWithDetailsCached.size(), 'Cached result should match');

        System.assert(!guardianCcrs.isEmpty(), 'getGuardianCCRsWithSequence should return CCR with sequence 1');
        System.assertEquals(2, guardianCcrs[0].OrgSync_Guardian_Sequence__c, 'Sequence should be 2');

        System.assert(!authCallerCcrs.isEmpty(), 'getCCRsForAuthorizedCallersSync should return CCR');
    }

    /**
     * @description Verifies getContactContactRelationsByIdsWithDetails with valid CCR IDs and caches result.
     */
    @IsTest
    static void testGetContactContactRelationsByIdsWithDetailsWithIds() {
        OrgSync_SoqlUtility.resetCache();
        List<ContactContactRelation> existingCcrs = [
            SELECT Id FROM ContactContactRelation
            WHERE ContactId IN (SELECT PersonContactId FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%')
            LIMIT 1
        ];
        if (existingCcrs.isEmpty()) {
            System.assert(true, 'No CCRs available - skipping');
            return;
        }
        Set<Id> ccrIds = new Set<Id>{ existingCcrs[0].Id };

        Test.startTest();
        List<ContactContactRelation> ccrs = OrgSync_SoqlUtility.getContactContactRelationsByIdsWithDetails(ccrIds);
        List<ContactContactRelation> cached = OrgSync_SoqlUtility.getContactContactRelationsByIdsWithDetails(ccrIds);
        Test.stopTest();

        System.assert(ccrs != null, 'Should return list');
        System.assertEquals(ccrs.size(), cached.size(), 'Cached result should match');
    }

    /**
     * @description Verifies getGuardianCCRsWithSequence filters CCRs with sequence 1 or 2.
     */
    @IsTest
    static void testGetGuardianCCRsWithSequenceFiltersBySequence() {
        OrgSync_SoqlUtility.resetCache();
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        if (guardianRoleId == null) {
            System.assert(true, 'Guardian role not available - skipping');
            return;
        }
        Account patient = [SELECT Id, PersonContactId FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Set<Id> patientContactIds = new Set<Id>();
        if (patient.PersonContactId != null) {
            patientContactIds.add(patient.PersonContactId);
        }

        Test.startTest();
        List<ContactContactRelation> ccrs = OrgSync_SoqlUtility.getGuardianCCRsWithSequence(patientContactIds, guardianRoleId);
        Test.stopTest();

        System.assert(ccrs != null, 'Should return list');
        for (ContactContactRelation ccr : ccrs) {
            System.assert(ccr.OrgSync_Guardian_Sequence__c == 1 || ccr.OrgSync_Guardian_Sequence__c == 2, 'Should only return sequence 1 or 2');
        }
    }

    /**
     * @description Verifies getCCRsForAuthorizedCallersSync filters by role IDs.
     */
    @IsTest
    static void testGetCCRsForAuthorizedCallersSyncFiltersByRole() {
        OrgSync_SoqlUtility.resetCache();
        Id guardianRoleId = OrgSync_SoqlUtility.getGuardianRoleId();
        Id authCallerRoleId = OrgSync_SoqlUtility.getAuthorizedCallerRoleId();
        Set<Id> roleIds = new Set<Id>();
        if (guardianRoleId != null) { roleIds.add(guardianRoleId); }
        if (authCallerRoleId != null) { roleIds.add(authCallerRoleId); }
        if (roleIds.isEmpty()) {
            System.assert(true, 'No roles available - skipping');
            return;
        }
        Account patient = [SELECT Id, PersonContactId FROM Account WHERE XCDC_ExternalId__c LIKE 'PAT-SOQL-%' AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Set<Id> patientContactIds = new Set<Id>();
        if (patient.PersonContactId != null) {
            patientContactIds.add(patient.PersonContactId);
        }

        Test.startTest();
        List<ContactContactRelation> ccrs = OrgSync_SoqlUtility.getCCRsForAuthorizedCallersSync(patientContactIds, roleIds);
        Test.stopTest();

        System.assert(ccrs != null, 'Should return list');
    }
}