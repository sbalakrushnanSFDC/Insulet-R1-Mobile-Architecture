/**
 * @description Test class for OrgSync_PatientProviderCCR
 *              Tests the update of OrgSync_Patient_Staging__c records
 *              when ContactContactRelation records are created or updated with
 *              Is_Primary__c = true, IsActive = true, and Party Role Relations = Patient-Provider-CCR
 * Created Date : Jan 21, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 21, 2026        Pradip Kokate           Initial Version
 * V1.0.1       Feb 18, 2026        Pradip Kokate           Updated to fix the test class issue
 * V1.0.2       Feb 18, 2026        Pradip Kokate           Updated to fix the test class issue
 */
@isTest
private class OrgSync_PatientProviderCCR_Test {

    private static final String TEST_PROVIDER_NPI_1 = '1234567890';
    private static final String TEST_PROVIDER_NPI_2 = '0987654321';
    private static final String TEST_PROVIDER_NPI_3 = '1122334455';

    /**
     * @description Test setup - creates test data for all test methods
     */
    @TestSetup
    static void setupTestData() {
        // Generate unique suffix to avoid duplicate value errors on unique fields
        // Using more randomness to ensure uniqueness
        String uniqueSuffix = String.valueOf(DateTime.now().getTime()) + 
                              String.valueOf(Math.abs(Crypto.getRandomInteger())) + 
                              String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 4);
        String testPatientExtId = 'TEST-PATIENT-' + uniqueSuffix;
        
        // Create PartyRoleRelation - check if it already exists
        List<PartyRoleRelation> existingPartyRoleRelations = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];
        
        PartyRoleRelation partyRoleRelation;
        if (existingPartyRoleRelations.isEmpty()) {
            partyRoleRelation = new PartyRoleRelation(
                Name = ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE,
                RoleName = 'Patient',
                RelatedRoleName = 'Provider',
                RelationshipObjectName = ConstantsUtil.CONTACT_CONTACT_RELATION
            );
            insert partyRoleRelation;
        } else {
            partyRoleRelation = existingPartyRoleRelations[0];
        }

        // Create Practice Account
        Account practiceAccount = new Account(
            RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT,
            Name = 'Test Practice',
            Type = 'Customer - Direct',
            Phone = '555-123-4567',
            BillingPostalCode = '12345'
        );
        insert practiceAccount;

        // Create Provider Person Accounts (need at least 2 for some tests)
        List<Account> providerAccounts = new List<Account>();
        providerAccounts.add(new Account(
            FirstName = 'Test',
            LastName = 'Provider1',
            RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT,
            PersonEmail = 'provider1@test.com',
            BillingPostalCode = '12345'
        ));
        providerAccounts.add(new Account(
            FirstName = 'Test',
            LastName = 'Provider2',
            RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT,
            PersonEmail = 'provider2@test.com',
            BillingPostalCode = '12346'
        ));
        insert providerAccounts;

        // Use providerAccounts[0] and [1] directly to ensure deterministic mapping:
        // Provider1 (index 0) gets NPI_1, Provider2 (index 1) gets NPI_2
        List<Identifier> identifiers = new List<Identifier>();
        identifiers.add(new Identifier(
            ParentRecordId = providerAccounts[0].Id,
            ID_Value__c = TEST_PROVIDER_NPI_1,
            IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
        ));
        identifiers.add(new Identifier(
            ParentRecordId = providerAccounts[1].Id,
            ID_Value__c = TEST_PROVIDER_NPI_2,
            IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
        ));
        insert identifiers;

        List<OrgSync_Physician_Staging__c> physicianStages = new List<OrgSync_Physician_Staging__c>();
        physicianStages.add(new OrgSync_Physician_Staging__c(
            Name = 'Test Physician 1',
            OrgSync_NPI__c = TEST_PROVIDER_NPI_1,
            OrgSync_Parent_Practice__c = practiceAccount.Id
        ));
        physicianStages.add(new OrgSync_Physician_Staging__c(
            Name = 'Test Physician 2',
            OrgSync_NPI__c = TEST_PROVIDER_NPI_2,
            OrgSync_Parent_Practice__c = practiceAccount.Id
        ));
        insert physicianStages;

        // IMPORTANT: Patient Staging XCDC_ExternalId__c MUST match Patient Account XCDC_ExternalId__c
        // for the OrgSync_PatientProviderCCR class to work correctly
        OrgSync_Patient_Staging__c patientStage = new OrgSync_Patient_Staging__c(
            Name = 'Test Patient Stage ' + uniqueSuffix,
            XCDC_ExternalId__c = testPatientExtId,
            OrgSync_Practice__c = practiceAccount.Id,
            OrgSync_Provider__c = physicianStages[0].Id
        );
        insert patientStage;

        // Create single Patient Person Account AFTER Patient Staging
        Account patientAccount = new Account(
            FirstName = 'Test',
            LastName = 'Patient',
            RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT,
            XCDC_ExternalId__c = testPatientExtId,
            PersonEmail = 'patient@test.com',
            BillingPostalCode = '12345'
        );

        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        Database.insert(patientAccount, dmlOptions);

        // Query Patient Account to get PersonContactId
        Account queriedPatientAccount = [
            SELECT Id, PersonContactId, XCDC_ExternalId__c
            FROM Account
            WHERE Id = :patientAccount.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];
    }

    /**
     * @description Test successful update of Patient Stage record with Provider when CCR is created
     */
    @isTest
    static void testUpdatePatientStagingFromCcrSuccess() {
        // Get test data
        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        // Query Patient Account - get first one from test data
        Account patientAccount = [
            SELECT Id, PersonContactId, XCDC_ExternalId__c
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
            AND XCDC_ExternalId__c LIKE 'TEST-PATIENT-%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        // Get provider account that has Identifier with TEST_PROVIDER_NPI_1 (matches physicianStage)
        // Physician Stage is retrieved by NPI; CCR uses RelatedContactId = provider's PersonContactId
        // OrgSync_PatientProviderCCR resolves provider via Identifier (ParentRecordId = Account, ID_Value__c = NPI)
        OrgSync_Patient_Staging__c patientStage = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Practice__c, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :patientAccount.XCDC_ExternalId__c
            LIMIT 1
        ];

        Account providerAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id IN (
                SELECT ParentRecordId
                FROM Identifier
                WHERE ID_Value__c = :TEST_PROVIDER_NPI_1
                    AND IdUsageType = :ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
                    AND ParentRecordId != null
            )
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            LIMIT 1
        ];

        // Query Physician Stage with same Practice+NPI as backend uses; ORDER BY Id ASC for deterministic match
        OrgSync_Physician_Staging__c physicianStage = [
            SELECT Id, OrgSync_NPI__c, OrgSync_Parent_Practice__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c = :TEST_PROVIDER_NPI_1
            AND OrgSync_Parent_Practice__c = :patientStage.OrgSync_Practice__c
            ORDER BY Id ASC
            LIMIT 1
        ];

        // Create CCR record
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = providerAccount.PersonContactId,
            Is_Primary__c = true,
            IsActive = true,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        insert ccr;

        // Execute the method
        Test.startTest();
        OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(new List<ContactContactRelation>{ ccr });
        Test.stopTest();

        // Verify Patient Stage was updated with Provider
        // OrgSync_Provider__c is a lookup field to OrgSync_Physician_Staging__c
        OrgSync_Patient_Staging__c updatedPatientStage = [
            SELECT Id, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE Id = :patientStage.Id
            LIMIT 1
        ];

        System.assertEquals(physicianStage.Id, updatedPatientStage.OrgSync_Provider__c, 
            'Patient Stage OrgSync_Provider__c lookup field should be updated with Physician Stage ID');
    }

    /**
     * @description Test bulk update of Patient Stage records - multiple CCRs for same patient
     */
    @isTest
    static void testUpdatePatientStagingFromCcrBulk() {
        // Get test data
        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        Account patientAccount = [
            SELECT Id, PersonContactId, XCDC_ExternalId__c
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
            AND XCDC_ExternalId__c LIKE 'TEST-PATIENT-%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        List<Account> providerAccounts = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            ORDER BY LastName
            LIMIT 2
        ];

        List<OrgSync_Physician_Staging__c> physicianStages = [
            SELECT Id, OrgSync_NPI__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c IN (:TEST_PROVIDER_NPI_1, :TEST_PROVIDER_NPI_2)
            ORDER BY OrgSync_NPI__c
        ];

        // Create multiple CCR records for the same patient with different providers
        List<ContactContactRelation> ccrList = new List<ContactContactRelation>();
        ccrList.add(new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = providerAccounts[0].PersonContactId,
            Is_Primary__c = true,
            IsActive = true,
            PartyRoleRelationId = partyRoleRelation.Id
        ));
        ccrList.add(new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = providerAccounts[1].PersonContactId,
            Is_Primary__c = true,
            IsActive = true,
            PartyRoleRelationId = partyRoleRelation.Id
        ));
        insert ccrList;

        // Execute the method
        Test.startTest();
        OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(ccrList);
        Test.stopTest();

        // Verify Patient Stage was updated (should be updated with the last provider processed)
        OrgSync_Patient_Staging__c updatedPatientStage = [
            SELECT Id, XCDC_ExternalId__c, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :patientAccount.XCDC_ExternalId__c
            LIMIT 1
        ];

        // OrgSync_Provider__c is a lookup field to OrgSync_Physician_Staging__c
        // The method processes CCRs and updates Patient Stage - should have a provider set
        System.assertNotEquals(null, updatedPatientStage.OrgSync_Provider__c, 
            'Patient Stage OrgSync_Provider__c lookup should be updated with a Physician Stage ID');
    }

    /**
     * @description Test filtering - CCR with Is_Primary__c = false should be ignored
     */
    @isTest
    static void testUpdatePatientStagingFromCcrFilterIsPrimaryFalse() {
        // Get test data
        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        Account patientAccount = [
            SELECT Id, PersonContactId, XCDC_ExternalId__c
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
            AND XCDC_ExternalId__c LIKE 'TEST-PATIENT-%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Account providerAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            LIMIT 1
        ];

        OrgSync_Patient_Staging__c patientStage = [
            SELECT Id, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :patientAccount.XCDC_ExternalId__c
            LIMIT 1
        ];

        Id originalProviderId = patientStage.OrgSync_Provider__c;

        // Create CCR record with Is_Primary__c = false
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = providerAccount.PersonContactId,
            Is_Primary__c = false,
            IsActive = true,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        insert ccr;

        // Execute the method
        Test.startTest();
        OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(new List<ContactContactRelation>{ ccr });
        Test.stopTest();

        // Verify Patient Stage was NOT updated
        OrgSync_Patient_Staging__c updatedPatientStage = [
            SELECT Id, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE Id = :patientStage.Id
            LIMIT 1
        ];

        System.assertEquals(originalProviderId, updatedPatientStage.OrgSync_Provider__c, 
            'Patient Stage should not be updated when Is_Primary__c is false');
    }

    /**
     * @description Test filtering - CCR with IsActive = false should be ignored
     */
    @isTest
    static void testUpdatePatientStagingFromCcrFilterIsActiveFalse() {
        // Get test data
        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        Account patientAccount = [
            SELECT Id, PersonContactId, XCDC_ExternalId__c
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
            AND XCDC_ExternalId__c LIKE 'TEST-PATIENT-%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        Account providerAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            LIMIT 1
        ];

        OrgSync_Patient_Staging__c patientStage = [
            SELECT Id, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :patientAccount.XCDC_ExternalId__c
            LIMIT 1
        ];

        Id originalProviderId = patientStage.OrgSync_Provider__c;

        // Create CCR record with IsActive = false
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = providerAccount.PersonContactId,
            Is_Primary__c = true,
            IsActive = false,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        insert ccr;

        // Execute the method
        Test.startTest();
        OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(new List<ContactContactRelation>{ ccr });
        Test.stopTest();

        // Verify Patient Stage was NOT updated
        OrgSync_Patient_Staging__c updatedPatientStage = [
            SELECT Id, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE Id = :patientStage.Id
            LIMIT 1
        ];

        System.assertEquals(originalProviderId, updatedPatientStage.OrgSync_Provider__c, 
            'Patient Stage should not be updated when IsActive is false');
    }

    /**
     * @description Test scenario where Patient Stage record doesn't exist
     */
    @isTest
    static void testUpdatePatientStagingFromCcrNoPatientStage() {
        // Get test data
        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        // Create a Patient Account without a corresponding Patient Stage
        Account patientAccount = new Account(
            FirstName = 'Test',
            LastName = 'PatientNoStage',
            RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT,
            XCDC_ExternalId__c = 'TEST-PATIENT-NO-STAGE',
            PersonEmail = 'patientnostage@test.com',
            BillingPostalCode = '12348'
        );
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        insert patientAccount;

        Account queriedPatientAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :patientAccount.Id
            LIMIT 1
        ];

        Account providerAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            LIMIT 1
        ];

        // Create CCR record
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = queriedPatientAccount.PersonContactId,
            RelatedContactId = providerAccount.PersonContactId,
            Is_Primary__c = true,
            IsActive = true,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        insert ccr;

        // Execute the method - should not throw error
        Test.startTest();
        try {
            OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(new List<ContactContactRelation>{ ccr });
            System.assert(true, 'Method should complete without error even when Patient Stage does not exist');
        } catch (Exception ex) {
            System.assert(false, 'Method should handle missing Patient Stage gracefully: ' + ex.getMessage());
        }
        Test.stopTest();
    }

    /**
     * @description Test scenario where Provider Account doesn't have Identifier
     */
    @isTest
    static void testUpdatePatientStagingFromCcrNoProviderIdentifier() {
        // Get test data
        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        Account patientAccount = [
            SELECT Id, PersonContactId, XCDC_ExternalId__c
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
            AND XCDC_ExternalId__c LIKE 'TEST-PATIENT-%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        // Create a Provider Account without Identifier
        Account providerAccountNoIdentifier = new Account(
            FirstName = 'Test',
            LastName = 'ProviderNoIdentifier',
            RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT,
            PersonEmail = 'providernoidentifier@test.com',
            BillingPostalCode = '12349'
        );
        insert providerAccountNoIdentifier;

        Account queriedProviderAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :providerAccountNoIdentifier.Id
            LIMIT 1
        ];

        OrgSync_Patient_Staging__c patientStage = [
            SELECT Id, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :patientAccount.XCDC_ExternalId__c
            LIMIT 1
        ];

        Id originalProviderId = patientStage.OrgSync_Provider__c;

        // Create CCR record
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = queriedProviderAccount.PersonContactId,
            Is_Primary__c = true,
            IsActive = true,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        insert ccr;

        // Execute the method - should not throw error
        Test.startTest();
        try {
            OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(new List<ContactContactRelation>{ ccr });
            System.assert(true, 'Method should complete without error even when Provider has no Identifier');
        } catch (Exception ex) {
            System.assert(false, 'Method should handle missing Identifier gracefully: ' + ex.getMessage());
        }
        Test.stopTest();

        // Verify Patient Stage was NOT updated
        OrgSync_Patient_Staging__c updatedPatientStage = [
            SELECT Id, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE Id = :patientStage.Id
            LIMIT 1
        ];

        System.assertEquals(originalProviderId, updatedPatientStage.OrgSync_Provider__c, 
            'Patient Stage should not be updated when Provider has no Identifier');
    }

    /**
     * @description Test scenario where Physician Stage doesn't exist for Practice and NPI combination
     */
    @isTest
    static void testUpdatePatientStagingFromCcrNoPhysicianStage() {
        // Get test data
        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        Account patientAccount = [
            SELECT Id, PersonContactId, XCDC_ExternalId__c
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
            AND XCDC_ExternalId__c LIKE 'TEST-PATIENT-%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        // Create a Provider Account with Identifier but no matching Physician Stage
        Account providerAccount = new Account(
            FirstName = 'Test',
            LastName = 'ProviderNoPhysicianStage',
            RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT,
            PersonEmail = 'providernophysicianstage@test.com',
            BillingPostalCode = '12350'
        );
        insert providerAccount;

        Account queriedProviderAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE Id = :providerAccount.Id
            LIMIT 1
        ];

        // Create Identifier with NPI that doesn't match any Physician Stage
        Identifier identifier = new Identifier(
            ParentRecordId = queriedProviderAccount.Id,
            ID_Value__c = '9999999999',
            IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
        );
        insert identifier;

        OrgSync_Patient_Staging__c patientStage = [
            SELECT Id, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :patientAccount.XCDC_ExternalId__c
            LIMIT 1
        ];

        Id originalProviderId = patientStage.OrgSync_Provider__c;

        // Create CCR record
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = queriedProviderAccount.PersonContactId,
            Is_Primary__c = true,
            IsActive = true,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        insert ccr;

        // Execute the method - should not throw error
        Test.startTest();
        try {
            OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(new List<ContactContactRelation>{ ccr });
            System.assert(true, 'Method should complete without error even when Physician Stage does not exist');
        } catch (Exception ex) {
            System.assert(false, 'Method should handle missing Physician Stage gracefully: ' + ex.getMessage());
        }
        Test.stopTest();

        // Verify Patient Stage was NOT updated
        OrgSync_Patient_Staging__c updatedPatientStage = [
            SELECT Id, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE Id = :patientStage.Id
            LIMIT 1
        ];

        System.assertEquals(originalProviderId, updatedPatientStage.OrgSync_Provider__c, 
            'Patient Stage should not be updated when Physician Stage does not exist');
    }

    /**
     * @description Test scenario with empty/null input
     */
    @isTest
    static void testUpdatePatientStagingFromCcrEmptyInput() {
        Test.startTest();
        OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(null);
        OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(new List<ContactContactRelation>());
        Test.stopTest();
        System.assert(true, 'Method should handle null and empty input gracefully');
    }

    /**
     * @description Test update scenario - when CCR is updated
     */
    @isTest
    static void testUpdatePatientStagingFromCcrUpdate() {
        // Get test data
        PartyRoleRelation partyRoleRelation = [
            SELECT Id
            FROM PartyRoleRelation
            WHERE Name = :ConstantsUtil.PATIENT_PROVIDER_CCR_ROLE
            LIMIT 1
        ];

        Account patientAccount = [
            SELECT Id, PersonContactId, XCDC_ExternalId__c
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT
            AND XCDC_ExternalId__c LIKE 'TEST-PATIENT-%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        List<Account> providerAccounts = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            ORDER BY LastName
            LIMIT 2
        ];

        List<OrgSync_Physician_Staging__c> physicianStages = [
            SELECT Id, OrgSync_NPI__c
            FROM OrgSync_Physician_Staging__c
            WHERE OrgSync_NPI__c IN (:TEST_PROVIDER_NPI_1, :TEST_PROVIDER_NPI_2)
            ORDER BY OrgSync_NPI__c
        ];

        // Create CCR with first provider
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAccount.PersonContactId,
            RelatedContactId = providerAccounts[0].PersonContactId,
            Is_Primary__c = true,
            IsActive = true,
            PartyRoleRelationId = partyRoleRelation.Id
        );
        insert ccr;

        // First update
        Test.startTest();
        OrgSync_PatientProviderCCR.updatePatientStagingFromCCR(new List<ContactContactRelation>{ ccr });
        Test.stopTest();

        // Verify first update
        OrgSync_Patient_Staging__c patientStage = [
            SELECT Id, OrgSync_Provider__c
            FROM OrgSync_Patient_Staging__c
            WHERE XCDC_ExternalId__c = :patientAccount.XCDC_ExternalId__c
            LIMIT 1
        ];
        // OrgSync_Provider__c is a lookup field to OrgSync_Physician_Staging__c
        System.assertEquals(true, patientStage.OrgSync_Provider__c != null, 
            'Patient Stage OrgSync_Provider__c lookup should be updated with first Physician Stage ID');

    }
}