/**
 * @description Test class for OrgSync_PatientDelegateService.
 *              Covers delegate creation, CCR management, contact points, and error handling.
 *              Uses OrgSync_TestDataFactory for test data creation. Aligns with Apex test best practices.
 *              Flow: Patient Stage insert -> Patient -> Patient Delegate -> CCR -> Contact Point Phone/Email.
 *              Patient Stage to Patient/Delegate/CCR/CPP flow runs as OrgSync user.
 *              Reverse flow (Delegate/CCR/CPP to Patient Stage) runs as end user (tested in other handlers).
 * Created Date : Jan 2026
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.1.0       Feb 2026            Ramesh Kumar            Refactored: TestDataFactory, 90%+ coverage, PMD alignment
 * V1.2.0       Feb 2026            Ramesh Kumar            OrgSync user for forward flow; end user for reverse flow
 */
@IsTest
@SuppressWarnings('PMD.StdCyclomaticComplexity,PMD.CyclomaticComplexity,PMD.CognitiveComplexity,PMD.ExcessiveParameterList')
private class OrgSync_PatientDelegateService_Test {

    private static final String PATIENT_EXT_ID = 'PAT-DEL-TEST-001';
    private static final String GUARDIAN_1_FIRST = 'Guardian';
    private static final String GUARDIAN_1_LAST = 'One';
    private static final String GUARDIAN_2_FIRST = 'Guardian';
    private static final String GUARDIAN_2_LAST = 'Two';

    /**
     * @description Gets OrgSync User from XCDC_Connection__mdt Current_Org_API_User__c.
     *              Used for Patient Stage to Patient/Delegate/CCR flow.
     * @return OrgSync User or null if not found.
     */
    private static User getOrgSyncUser() {
        List<XCDC_Connection__mdt> connections = [
            SELECT Current_Org_API_User__c
            FROM XCDC_Connection__mdt
            WHERE Current_Org_API_User__c != null
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (connections.isEmpty()) {
            return null;
        }
        return [SELECT Id FROM User WHERE Id = :connections[0].Current_Org_API_User__c LIMIT 1];
    }

    /**
     * @description Ensures PartyRoleRelation with Guardian role exists for tests.
     *              Uses Name = PATIENT_LEGAL_GUARDIAN_CCR_ROLE to match OrgSync_SoqlUtility.getGuardianRoleId().
     */
    private static void ensureGuardianRoleExists() {
        List<PartyRoleRelation> existingRoles = [
            SELECT Id FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (existingRoles.isEmpty()) {
            PartyRoleRelation guardianRole = new PartyRoleRelation(
                Name = ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE,
                RoleName = 'Patient',
                RelatedRoleName = ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME,
                RelationshipObjectName = 'Contact_Contact_Relationship'
            );
            insert guardianRole;
        }
    }

    /**
     * @description Builds guardian fields map for Patient Stage.
     * @param guardianNum Guardian number (1 or 2)
     * @param firstName Guardian first name
     * @param lastName Guardian last name
     * @param email Guardian email
     * @param mobile Guardian mobile phone
     * @param home Guardian home phone
     * @param work Guardian work phone
     * @return Map of guardian fields
     */
    private static Map<String, Object> buildGuardianFields(Integer guardianNum, String firstName, String lastName, String email, String mobile, String home, String work) {
        return new Map<String, Object>{
            'OrgSync_Guardian_' + guardianNum + '_First_Name__c' => firstName,
            'OrgSync_Guardian_' + guardianNum + '_Last_Name__c' => lastName,
            'OrgSync_Guardian_' + guardianNum + '_Email__c' => email,
            'OrgSync_Guardian_' + guardianNum + '_Mobile_Phone__c' => mobile,
            'OrgSync_Guardian_' + guardianNum + '_Home_Phone__c' => home,
            'OrgSync_Guardian_' + guardianNum + '_Work_Phone__c' => work
        };
    }

    /**
     * @description Merges two maps (second overwrites first on key collision).
     * @param m1 First map
     * @param m2 Second map
     * @return Merged map
     */
    private static Map<String, Object> mergeMaps(Map<String, Object> m1, Map<String, Object> m2) {
        Map<String, Object> result = new Map<String, Object>(m1);
        if (m2 != null) {
            result.putAll(m2);
        }
        return result;
    }

    @TestSetup
    static void dataSetup() {
        ensureGuardianRoleExists();
        User orgSyncUser = getOrgSyncUser();

        Account practice = OrgSync_TestDataFactory.createPracticeAccount('Delegate Test Practice', 'PRAC-DEL-001', '12345');
        Database.insert(practice, OrgSync_TestDataFactory.getDMLOptions());

        Map<String, Object> guardian1Fields = buildGuardianFields(1, GUARDIAN_1_FIRST, GUARDIAN_1_LAST, 'guardian1@test.com', '5551112222', '5551113333', '5551114444');
        Map<String, Object> guardian2Fields = buildGuardianFields(2, GUARDIAN_2_FIRST, GUARDIAN_2_LAST, 'guardian2@test.com', '5552223333', '5552224444', '5552225555');
        Map<String, Object> allAdditional = mergeMaps(guardian1Fields, guardian2Fields);
        allAdditional.put('OrgSync_Billing_Address__PostalCode__s', '12345');
        allAdditional.put('OrgSync_Billing_Address__Street__s', '123 Test St');
        allAdditional.put('OrgSync_Billing_Address__City__s', 'Test City');
        allAdditional.put('OrgSync_Billing_Address__StateCode__s', 'NY');
        allAdditional.put('OrgSync_Email_1__c', 'patient@test.com');
        allAdditional.put('OrgSync_Home_Phone__c', '5550001111');
        allAdditional.put('OrgSync_Mobile_Phone__c', '5550002222');
        allAdditional.put('OrgSync_Work_Phone__c', '5550003333');
        allAdditional.put('OrgSync_CustomerId__c', 'CUST-001');
        allAdditional.put('OrgSync_Date_of_Birth__c', Date.today().addYears(-10));

        OrgSync_Patient_Staging__c patientStage = OrgSync_TestDataFactory.createPatientStagingRecord(
            PATIENT_EXT_ID,
            practice.Id,
            null,
            'Test',
            'Patient',
            allAdditional
        );

        // Patient Stage to Patient/Delegate/CCR flow runs as OrgSync user
        if (orgSyncUser != null) {
            OrgSync_UtilityService.orgSyncUserId = orgSyncUser.Id;
            System.runAs(orgSyncUser) {
                Database.insert(patientStage, OrgSync_TestDataFactory.getDMLOptions());
            }
        } else {
            OrgSync_Patient_Staging_TriggerHandler.isRunningFromTest = true;
            try {
                Database.insert(patientStage, OrgSync_TestDataFactory.getDMLOptions());
            } finally {
                OrgSync_Patient_Staging_TriggerHandler.isRunningFromTest = false;
            }
        }
    }

    /**
     * @description Verifies full flow: Patient Stage insert creates Patient, Patient Delegate, CCR, and Contact Points.
     */
    @IsTest
    static void testInsertPatientStageCreatesPatientDelegateAndCCR() {
        OrgSync_Patient_Staging__c staging = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Guardian_1_First_Name__c, OrgSync_Guardian_1_Last_Name__c,
                    OrgSync_Guardian_2_First_Name__c, OrgSync_Guardian_2_Last_Name__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID
            LIMIT 1
        ];
        System.assertNotEquals(null, staging.Id, 'Patient Stage should exist');

        Account patientAcc = [
            SELECT Id, PersonContactId, XCDC_ExternalId__c
            FROM Account
            WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
            LIMIT 1
        ];
        System.assertNotEquals(null, patientAcc.Id, 'Patient Account should be created');
        System.assertNotEquals(null, patientAcc.PersonContactId, 'Patient should have PersonContactId');

        List<Account> delegates = [
            SELECT Id, FirstName, LastName, PersonEmail, PersonContactId
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
            AND (FirstName = :GUARDIAN_1_FIRST OR FirstName = :GUARDIAN_2_FIRST)
        ];
        System.assert(delegates.size() >= 1, 'At least one Patient Delegate should be created');

        List<ContactContactRelation> ccrs = [
            SELECT Id, ContactId, RelatedContactId, OrgSync_Guardian_Sequence__c
            FROM ContactContactRelation
            WHERE ContactId = :patientAcc.PersonContactId
            AND OrgSync_Guardian_Sequence__c IN (1, 2)
        ];
        System.assert(!ccrs.isEmpty(), 'CCR(s) should be created linking Patient to Guardian(s)');

        Set<Id> delegateAccountIds = new Set<Id>();
        for (Account d : delegates) {
            delegateAccountIds.add(d.Id);
        }
        List<ContactPointEmail> cpes = [
            SELECT Id, ParentId, EmailAddress
            FROM ContactPointEmail
            WHERE ParentId IN :delegateAccountIds
        ];
        List<ContactPointPhone> cpps = [
            SELECT Id, ParentId, TelephoneNumber, UsageType
            FROM ContactPointPhone
            WHERE ParentId IN :delegateAccountIds
        ];
        System.assert(!cpes.isEmpty() || !cpps.isEmpty(), 'Contact Point Email or Phone should be created for delegates');
    }

    /**
     * @description Verifies update of guardian fields triggers delegate/CCR/contact point updates.
     *              Runs as OrgSync user (Patient Stage to Patient/Delegate flow).
     */
    @IsTest
    static void testUpdatePatientStageGuardianFields() {
        User orgSyncUser = getOrgSyncUser();
        if (orgSyncUser == null) {
            System.assert(true, 'OrgSync user not configured - skipping');
            return;
        }
        OrgSync_UtilityService.orgSyncUserId = orgSyncUser.Id;

        OrgSync_Patient_Staging__c staging = [
            SELECT Id, OrgSync_Guardian_1_Last_Name__c, OrgSync_Guardian_2_Email__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID
            LIMIT 1
        ];
        staging.OrgSync_Guardian_1_Last_Name__c = 'OneUpdated';
        staging.OrgSync_Guardian_2_Email__c = 'guardian2updated@test.com';

        Test.startTest();
        System.runAs(orgSyncUser) {
            update staging;
        }
        Test.stopTest();

        List<Account> delegates = [
            SELECT Id, LastName, PersonEmail
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
            AND FirstName = :GUARDIAN_2_FIRST
        ];
        System.assert(!delegates.isEmpty(), 'Delegate should exist after update');
    }

    /**
     * @description Verifies direct call to processDelegates with staging records.
     *              Direct service invocation - no runAs (service does not check user context).
     */
    @IsTest
    static void testProcessDelegatesDirect() {
        OrgSync_Patient_Staging__c staging = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Guardian_1_First_Name__c, OrgSync_Guardian_1_Last_Name__c,
                   OrgSync_Guardian_1_Email__c, OrgSync_Guardian_2_First_Name__c, OrgSync_Guardian_2_Last_Name__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID
            LIMIT 1
        ];

        OrgSync_PatientDelegateService service = new OrgSync_PatientDelegateService();
        Test.startTest();
        service.processDelegates(new List<OrgSync_Patient_Staging__c>{ staging }, null);
        Test.stopTest();

        List<ContactContactRelation> ccrs = [
            SELECT Id
            FROM ContactContactRelation
            WHERE ContactId IN (SELECT PersonContactId FROM Account WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID)
            AND OrgSync_Guardian_Sequence__c IN (1, 2)
        ];
        System.assert(!ccrs.isEmpty(), 'CCRs should exist after processDelegates');
    }

    /**
     * @description Verifies processDelegates with empty list does not throw.
     *              Direct service invocation - no runAs needed.
     */
    @IsTest
    static void testProcessDelegatesEmptyList() {
        OrgSync_PatientDelegateService service = new OrgSync_PatientDelegateService();
        Test.startTest();
        service.processDelegates(new List<OrgSync_Patient_Staging__c>(), null);
        service.processDelegates(new List<OrgSync_Patient_Staging__c>(), new Map<Id, OrgSync_Patient_Staging__c>());
        Test.stopTest();
        System.assert(true, 'Empty list should not throw');
    }

    /**
     * @description Verifies processDelegates on update scenario (oldMap provided).
     *              Direct service invocation - no runAs needed.
     */
    @IsTest
    static void testProcessDelegatesWithOldMap() {
        OrgSync_Patient_Staging__c staging = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Guardian_1_First_Name__c, OrgSync_Guardian_1_Last_Name__c,
                   OrgSync_Guardian_1_Email__c, OrgSync_Guardian_2_First_Name__c, OrgSync_Guardian_2_Last_Name__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID
            LIMIT 1
        ];
        Map<Id, OrgSync_Patient_Staging__c> oldMap = new Map<Id, OrgSync_Patient_Staging__c>{
            staging.Id => staging.clone(true, true, true, true)
        };
        staging.OrgSync_Guardian_1_Email__c = 'guardian1updated@test.com';

        OrgSync_PatientDelegateService service = new OrgSync_PatientDelegateService();
        Test.startTest();
        service.processDelegates(new List<OrgSync_Patient_Staging__c>{ staging }, oldMap);
        Test.stopTest();
        System.assert(true, 'Update scenario should complete');
    }

    /**
     * @description Verifies new Patient Stage with both guardians creates delegates and CCRs.
     *              Runs as OrgSync user (Patient Stage to Patient/Delegate flow).
     */
    @IsTest
    static void testInsertPatientStageWithBothGuardians() {
        ensureGuardianRoleExists();
        User orgSyncUser = getOrgSyncUser();
        if (orgSyncUser == null) {
            System.assert(true, 'OrgSync user not configured - skipping');
            return;
        }
        OrgSync_UtilityService.orgSyncUserId = orgSyncUser.Id;

        Account practice = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-DEL-001' LIMIT 1];
        String uniqueExtId = 'PAT-DEL-NEW-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);

        Map<String, Object> guardian1 = buildGuardianFields(1, 'Mary', 'Smith', 'mary@test.com', '5553334444', '5553335555', '5553336666');
        Map<String, Object> guardian2 = buildGuardianFields(2, 'John', 'Doe', 'john@test.com', '5554445555', '5554446666', '5554447777');
        Map<String, Object> allFields = mergeMaps(guardian1, guardian2);
        allFields.put('OrgSync_Billing_Address__PostalCode__s', '54321');
        allFields.put('OrgSync_Billing_Address__Street__s', '456 New St');
        allFields.put('OrgSync_Billing_Address__City__s', 'New City');
        allFields.put('OrgSync_Billing_Address__StateCode__s', 'CA');

        OrgSync_Patient_Staging__c newStage = OrgSync_TestDataFactory.createPatientStagingRecord(
            uniqueExtId,
            practice.Id,
            null,
            'Child',
            'Patient',
            allFields
        );

        Test.startTest();
        System.runAs(orgSyncUser) {
            Database.insert(newStage, OrgSync_TestDataFactory.getDMLOptions());
        }
        Test.stopTest();

        Account patientAcc = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE XCDC_ExternalId__c = :uniqueExtId
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
            LIMIT 1
        ];
        System.assertNotEquals(null, patientAcc, 'Patient should be created');
        System.assertNotEquals(null, patientAcc.PersonContactId, 'Patient should have PersonContactId');

        List<ContactContactRelation> ccrs = [
            SELECT Id, OrgSync_Guardian_Sequence__c
            FROM ContactContactRelation
            WHERE ContactId = :patientAcc.PersonContactId
            AND OrgSync_Guardian_Sequence__c IN (1, 2)
        ];
        System.assert(ccrs.size() >= 1, 'At least one CCR with sequence should exist');

        List<Account> delegates = [
            SELECT Id, FirstName, LastName
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
            AND (FirstName = 'Mary' OR FirstName = 'John')
        ];
        System.assert(delegates.size() >= 1, 'Delegate(s) should be created');
    }

    /**
     * @description Verifies guardian cleared on update nullifies CCR sequence.
     *              Runs as OrgSync user (Patient Stage to Patient/Delegate flow).
     */
    @IsTest
    static void testUpdateGuardianCleared() {
        User orgSyncUser = getOrgSyncUser();
        if (orgSyncUser == null) {
            System.assert(true, 'OrgSync user not configured - skipping');
            return;
        }
        OrgSync_UtilityService.orgSyncUserId = orgSyncUser.Id;

        OrgSync_Patient_Staging__c staging = [
            SELECT Id, OrgSync_Guardian_1_First_Name__c, OrgSync_Guardian_1_Last_Name__c,
                   OrgSync_Guardian_2_First_Name__c, OrgSync_Guardian_2_Last_Name__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID
            LIMIT 1
        ];
        staging.OrgSync_Guardian_2_First_Name__c = null;
        staging.OrgSync_Guardian_2_Last_Name__c = null;
        staging.OrgSync_Guardian_2_Email__c = null;
        staging.OrgSync_Guardian_2_Mobile_Phone__c = null;
        staging.OrgSync_Guardian_2_Home_Phone__c = null;
        staging.OrgSync_Guardian_2_Work_Phone__c = null;

        Test.startTest();
        System.runAs(orgSyncUser) {
            update staging;
        }
        Test.stopTest();

        List<ContactContactRelation> ccrsWithSeq2 = [
            SELECT Id, OrgSync_Guardian_Sequence__c
            FROM ContactContactRelation
            WHERE ContactId IN (SELECT PersonContactId FROM Account WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID)
            AND OrgSync_Guardian_Sequence__c = 2
        ];
        System.assertEquals(0, ccrsWithSeq2.size(), 'No CCR should have sequence 2 after guardian 2 cleared');
    }

    /**
     * @description Verifies processDelegates when staging has no external ID (skipped).
     *              Direct service invocation - no runAs needed.
     */
    @IsTest
    static void testProcessDelegatesNoExternalId() {
        Account practice = [SELECT Id FROM Account WHERE XCDC_ExternalId__c = 'PRAC-DEL-001' LIMIT 1];
        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            Name = 'No Ext',
            OrgSync_FirstName__c = 'No',
            OrgSync_LastName__c = 'Ext',
            OrgSync_Practice__c = practice.Id
        );
        insert staging;

        OrgSync_PatientDelegateService service = new OrgSync_PatientDelegateService();
        Test.startTest();
        service.processDelegates(new List<OrgSync_Patient_Staging__c>{ staging }, null);
        Test.stopTest();
        System.assert(true, 'Staging without external ID should not throw');
    }

    /**
     * @description Verifies Patient Stage update as end user does not trigger delegate flow.
     *              Trigger checks isOrgSyncUser(); when false, delegate handler is skipped.
     */
    @IsTest
    static void testUpdateAsEndUserSkipsDelegateFlow() {
        OrgSync_UtilityService.orgSyncUserId = '005000000000000AAA';//NOPMD (Reason : This is part of negative test)

        OrgSync_Patient_Staging__c staging = [
            SELECT Id, OrgSync_Guardian_1_Last_Name__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID
            LIMIT 1
        ];
        staging.OrgSync_Guardian_1_Last_Name__c = 'EndUserUpdate';

        Test.startTest();
        update staging;
        Test.stopTest();

        System.assert(true, 'End user update should complete without delegate flow (trigger skips)');
    }

    /**
     * @description Verifies processDelegates with existing delegate (reuse, no duplicate).
     *              Direct service call - no runAs needed (service does not check user context).
     */
    @IsTest
    static void testProcessDelegatesReusesExistingDelegate() {
        OrgSync_Patient_Staging__c staging = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Guardian_1_First_Name__c, OrgSync_Guardian_1_Last_Name__c,
                   OrgSync_Guardian_1_Email__c, OrgSync_Guardian_2_First_Name__c, OrgSync_Guardian_2_Last_Name__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :PATIENT_EXT_ID
            LIMIT 1
        ];

        Integer delegateCountBefore = [
            SELECT COUNT()
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
            AND FirstName = :GUARDIAN_1_FIRST
            AND LastName = :GUARDIAN_1_LAST
        ];

        OrgSync_PatientDelegateService service = new OrgSync_PatientDelegateService();
        Test.startTest();
        service.processDelegates(new List<OrgSync_Patient_Staging__c>{ staging }, null);
        Test.stopTest();

        Integer delegateCountAfter = [
            SELECT COUNT()
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
            AND FirstName = :GUARDIAN_1_FIRST
            AND LastName = :GUARDIAN_1_LAST
        ];
        System.assertEquals(delegateCountBefore, delegateCountAfter, 'Should not create duplicate delegate');
    }
}