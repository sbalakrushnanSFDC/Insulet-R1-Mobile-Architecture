/**
 * @description Test class for OrgSync_GuardianCCRService.
 */
@IsTest
private class OrgSync_GuardianCCRService_Test {
    /**
     * @description Creates patient, delegate, staging, and CCR. All data created in-test.
     *              Resets OrgSync_SoqlUtility cache first so getguardianRoleId populates it for service calls.
     */
    @testSetup
    static void createTestData() {
        List<PartyRoleRelation> partyRoleRelations = new List<PartyRoleRelation>();
        partyRoleRelations.add(new PartyRoleRelation(
            Name = ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE,
            RoleName = 'Patient',
            RelatedRoleName = ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME,
            RelationshipObjectName = ConstantsUtil.CONTACT_CONTACT_RELATION
        ));
        partyRoleRelations.add(new PartyRoleRelation(
            Name = ConstantsUtil.AUTHORIZED_CALLER_CCR_ROLE,
            RoleName = ConstantsUtil.AUTHORIZED_CALLER_RELATIONSHIP_NAME,
            RelatedRoleName = 'Authorized Caller',
            RelationshipObjectName = ConstantsUtil.CONTACT_CONTACT_RELATION
        ));
        insert partyRoleRelations;
        String extId = OrgSync_UtilityService.generateUniqueExtId('OrgSyncPatient');
        String suffix = String.valueOf(DateTime.now().getTime()).right(8);
        Account patientAcc = OrgSync_TestDataFactory.createPatientAccount(
            'Patient', 'Test', 'patient' + suffix + '@test.com', extId, '12345', null
        );
        Database.insert(patientAcc, OrgSync_TestDataFactory.getDMLOptions());
        patientAcc = [SELECT Id, PersonContactId, XCDC_ExternalId__c FROM Account WHERE Id = :patientAcc.Id];
        List<Account> delegateAccounts = new List<Account>();
        delegateAccounts.add(OrgSync_TestDataFactory.createDelegateAccount(
            'Guardian', 'One', 'g1' + suffix + '@test.com'
        ));
        delegateAccounts.add(OrgSync_TestDataFactory.createDelegateAccount(
            'Guardian', 'two', 'g2' + suffix + '@test.com'
        ));
        Database.insert(delegateAccounts, OrgSync_TestDataFactory.getDMLOptions());
        List<Account> delegateAccountOne = [SELECT Id, PersonContactId FROM Account WHERE recordtypeid = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT and LastName = 'One' LIMIT 1];

        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAcc.PersonContactId,
            RelatedContactId = delegateAccountOne[0]?.PersonContactId,
            PartyRoleRelationId = partyRoleRelations[0]?.Id,
            OrgSync_Guardian_Sequence__c = 1
        );
        insert ccr;
    }

    @isTest
    static void testBuildCCRForUpsertNewRecord() {
        Account patientAcc = [SELECT Id, PersonContactId FROM Account WHERE  recordtypeid = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Account delegateAcc = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT and LastName = 'two' LIMIT 1];
        Id guardianRoleId = [Select Id FROM PartyRoleRelation WHERE Name =: ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE LIMIT 1]?.Id;
        System.assertNotEquals(null, guardianRoleId, 'Guardian role must exist. Ensure PartyRoleRelation with Name=' + ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE + ' exists.');
        System.assertNotEquals(null, patientAcc, 'Patient account should not be null');
        System.assertNotEquals(null, delegateAcc, 'Delegate account should not be null');
        Test.startTest();
        ContactContactRelation ccr = OrgSync_GuardianCCRService.buildCCRForUpsert(
            patientAcc.PersonContactId,
            delegateAcc.PersonContactId,
            2,
            guardianRoleId,
            null,
            null
        );
        System.assertNotEquals(null, ccr, 'CCR should not be null');
        OrgSync_GuardianCCRService.executeCCRUpserts(new List<ContactContactRelation>{ ccr });
        ContactContactRelation ccrQueried = [SELECT Id, OrgSync_Guardian_Sequence__c FROM ContactContactRelation WHERE Id = :ccr.Id];
        Test.stopTest();
    }

    @isTest
    static void testBuildCCRforNullifyGuardian() {
        ContactContactRelation ccr = [SELECT Id FROM ContactContactRelation WHERE OrgSync_Guardian_Sequence__c != null limit 1];
        Test.startTest();
        ContactContactRelation returnedCCR = OrgSync_GuardianCCRService.buildCCRForNullifyGuardian(ccr);
        System.assertEquals(null, returnedCCR.OrgSync_Guardian_Sequence__c, 'Sequence should be null');
        OrgSync_GuardianCCRService.executeCCRNullifyUpdates(new List<ContactContactRelation>{ returnedCCR });
        Test.stopTest();
    }

    @isTest
    static void testProcessNewGuardianCCRsSetSequenceAndSyncToPatientStage() {
        Account patientAcc = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Account delegateAcc = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT and LastName = 'two' LIMIT 1];
        Id guardianRoleId = [Select Id FROM PartyRoleRelation WHERE Name =: ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE LIMIT 1]?.Id;
        System.assertNotEquals(null, guardianRoleId, 'Guardian role must exist. Ensure PartyRoleRelation with RelatedRoleName = \'Patient\' exists.');
        System.assertNotEquals(null, patientAcc, 'Patient account should not be null');
        System.assertNotEquals(null, delegateAcc, 'Delegate account should not be null');
        ContactContactRelation ccr = OrgSync_GuardianCCRService.buildCCRForUpsert(
            patientAcc.PersonContactId,
            delegateAcc.PersonContactId,
            null,
            guardianRoleId,
            null,
            null
        );
        Test.startTest();
            OrgSync_GuardianCCRService.processNewGuardianCCRsSetSequenceAndSyncToPatientStage(new List<ContactContactRelation>{ ccr });
        Test.stopTest();
    }

    @isTest
    static void testSyncAuthorizedCallersOnPatientStage() {
        Account patientAcc = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Account delegateAcc = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT and LastName = 'two' LIMIT 1];
        Id authorizedCallerRoleId = [Select Id FROM PartyRoleRelation WHERE RelatedRoleName = 'Authorized Caller' LIMIT 1]?.Id;
        System.assertNotEquals(null, authorizedCallerRoleId, 'Authorized Caller role must exist. Ensure PartyRoleRelation with Name=' + ConstantsUtil.AUTHORIZED_CALLER_CCR_ROLE + ' exists.');
        System.assertNotEquals(null, patientAcc, 'Patient account should not be null');
        System.assertNotEquals(null, delegateAcc, 'Delegate account should not be null');
        ContactContactRelation ccr = OrgSync_GuardianCCRService.buildCCRForUpsert(
            patientAcc.PersonContactId,
            delegateAcc.PersonContactId,
            null,
            authorizedCallerRoleId,
            null,
            null
        );
        Test.startTest();
        insert ccr;
        Test.stopTest();
    }

    @isTest
    static void testRoleSwapToGuardian() {
        Account patientAcc = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Account delegateAcc = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT and LastName = 'two' LIMIT 1];
        Id guardianRoleId = [Select Id FROM PartyRoleRelation WHERE Name =: ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE LIMIT 1]?.Id;
        Id authorizedCallerRoleId = [Select Id FROM PartyRoleRelation WHERE RelatedRoleName = 'Authorized Caller' LIMIT 1]?.Id;
        System.assertNotEquals(null, guardianRoleId, 'Guardian role must exist. Ensure PartyRoleRelation with Name=' + ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE + ' exists.');
        System.assertNotEquals(null, patientAcc, 'Patient account should not be null');
        System.assertNotEquals(null, delegateAcc, 'Delegate account should not be null');
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAcc.PersonContactId,
            RelatedContactId = delegateAcc.PersonContactId,
            PartyRoleRelationId = authorizedCallerRoleId,
            OrgSync_Guardian_Sequence__c = 1
        );
        insert ccr;

        ccr.PartyRoleRelationId = guardianRoleId;
        Test.startTest();
        OrgSync_GuardianCCRService.processRoleSwapToGuardian(new List<ContactContactRelation>{ ccr });
        Test.stopTest();
    }
    @isTest
    static void testRoleSwapFromGuardian() {
        Account patientAcc = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
        Account delegateAcc = [SELECT Id, PersonContactId FROM Account WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT and LastName = 'two' LIMIT 1];
        Id guardianRoleId = [Select Id FROM PartyRoleRelation WHERE Name =: ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE LIMIT 1]?.Id;
        Id authorizedCallerRoleId = [Select Id FROM PartyRoleRelation WHERE RelatedRoleName = 'Authorized Caller' LIMIT 1]?.Id;
        System.assertNotEquals(null, guardianRoleId, 'Guardian role must exist. Ensure PartyRoleRelation with Name=' + ConstantsUtil.PATIENT_LEGAL_GUARDIAN_CCR_ROLE + ' exists.');
        System.assertNotEquals(null, patientAcc, 'Patient account should not be null');
        System.assertNotEquals(null, delegateAcc, 'Delegate account should not be null');
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAcc.PersonContactId,
            RelatedContactId = delegateAcc.PersonContactId,
            PartyRoleRelationId = guardianRoleId,
            OrgSync_Guardian_Sequence__c = 1
        );
        insert ccr;

        ccr.PartyRoleRelationId = authorizedCallerRoleId;
        Test.startTest();
        update ccr;
        //OrgSync_GuardianCCRService.processRoleSwapFromGuardian(new List<ContactContactRelation>{ ccr });
        Test.stopTest();
    }
}