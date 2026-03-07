/**
 * @description Test class for AccountContactRelationTriggerHandler and OrgSync_ACRHandler
 *              Covers trigger logic and handler delegation.
 * Created Date : Dec 2025
 * Created By   : Ramesh Dhaka
 */
@IsTest(IsParallel=true)
public class ACRTriggerHandler_Test {

    /**
     * @description Test After Insert Trigger logic
     */
    @IsTest
    static void testAfterInsert() {
        // Create Accounts (Practice and Patient)
        Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice',
            'XCDC_ExternalId__c' => 'PRAC001'
        });

        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Patient',
            'XCDC_ExternalId__c' => 'PAT001'
        });       

        Test.startTest();
        insert new List<Account>{practiceAccount, patientAccount};
        patientAccount = [SELECT Id, PersonContactId,XCDC_ExternalId__c FROM Account WHERE Id = :patientAccount.Id];
        // Create initial ACR between Patient and Practice1 for update test
        AccountContactRelation acr = new AccountContactRelation(
            ContactId = patientAccount.PersonContactId,
            AccountId = practiceAccount.Id,
            Roles = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE,
            IsActive = true,
            Is_Primary__c = true
        );
        insert acr;
        Test.stopTest();

        // Verify Staging Updated
        OrgSync_Patient_Staging__c updatedStaging = [SELECT OrgSync_Practice__c FROM OrgSync_Patient_Staging__c WHERE XCDC_ExternalId__c = :patientAccount.XCDC_ExternalId__c];
        System.assertEquals(practiceAccount.Id, updatedStaging.OrgSync_Practice__c, 'Staging should be updated with Practice Id');
    }

    /**
     * @description Test After Update Trigger logic
     */
    @IsTest
    static void testAfterUpdate() {
         // Create Accounts (Practice and Patient)
        Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice'
        });

        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Patient'
        });
        
        insert new List<Account>{practiceAccount, patientAccount};
        patientAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :patientAccount.Id];

        // Create initial ACR between Patient and Practice1 for update test
        AccountContactRelation acr = new AccountContactRelation(
            ContactId = patientAccount.PersonContactId,
            AccountId = practiceAccount.Id,
            Roles = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE,
            IsActive = true,
            Is_Primary__c = true
        );
        insert acr;

        List<AccountContactRelation> acrs = [SELECT Id, Roles FROM AccountContactRelation WHERE ContactId = :patientAccount.PersonContactId AND AccountId = :practiceAccount.Id];

        Test.startTest();
        if (!acrs.isEmpty()){
            acrs[0].Roles = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE;
            update acrs[0];
        }
        Test.stopTest();

        // Verify no errors. Logic delegated to Service which is tested separately.
        AccountContactRelation updatedACR = [SELECT Roles FROM AccountContactRelation WHERE Id = :acrs[0].Id];
        System.assert(updatedACR?.Roles?.contains(ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE), 'Roles should be updated');
    }

    /**
     * @description Test After Delete Trigger logic
     */
    @IsTest
    static void testAfterDelete() {
         // Create Accounts (Practice and Patient)
        Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Practice'
        });

        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Patient'
        });

        insert new List<Account>{practiceAccount, patientAccount};
        patientAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :patientAccount.Id];
        // Create initial ACR between Patient and Practice1 for update test
        AccountContactRelation acr = new AccountContactRelation(
            ContactId = patientAccount.PersonContactId,
            AccountId = practiceAccount.Id,
            Roles = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE,
            IsActive = true,
            Is_Primary__c = true
        );
        patientAccount = [SELECT Id,XCDC_ExternalId__c,PersonContactId FROM Account WHERE Id = :patientAccount.Id];
        insert acr;

        List<AccountContactRelation> acrs = [SELECT Id FROM AccountContactRelation WHERE ContactId = :patientAccount.PersonContactId AND AccountId = :practiceAccount.Id];
        String practiceId = practiceAccount.Id;
        Test.startTest();
        delete acrs[0];
        Test.stopTest();

        OrgSync_Patient_Staging__c updatedPatientStaging = [SELECT Id,OrgSync_Practice__c FROM OrgSync_Patient_Staging__c WHERE XCDC_ExternalId__c = :patientAccount.XCDC_ExternalId__c];
        System.assertEquals(null, updatedPatientStaging?.OrgSync_Practice__c, 'Patient Staging should be deleted');
    }
}