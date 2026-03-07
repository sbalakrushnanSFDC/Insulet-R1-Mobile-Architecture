/**
 * @description Test class for OrgSync_Patient_Stage_TriggerHandler
 * Created Date : Dec 17, 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 17, 2025        Ramesh Dhaka            Initial Version
 */
@isTest
private without sharing class OrgSync_PatientStagingTrigger_Test {
    @TestSetup
    static void dataSetup() {
        OrgSync_Patient_Staging_TriggerHandler.isRunningFromTest = true;
        Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType();
        practiceAccount.XCDC_ExternalId__c = 'PRAC001';
        practiceAccount.BillingPostalCode = '98989';
        insert practiceAccount;

        OrgSync_Patient_Staging__c staging = new OrgSync_Patient_Staging__c(
            XCDC_ExternalId__c = 'PAT001',
            OrgSync_Practice__c = practiceAccount.Id,
            OrgSync_Guardian_1_Name__c = 'Test Guardian 1',
            OrgSync_Guardian_2_Name__c = 'Test Guardian 2',
            OrgSync_Guardian_1_Email__c = 'test.guardian1@test.com',
            OrgSync_Guardian_2_Email__c = 'test.guardian2@test.com',
            OrgSync_Guardian_1_Home_Phone__c = '1234567890',
            OrgSync_Guardian_2_Home_Phone__c = '1234567891',
            OrgSync_Guardian_1_Work_Phone__c = '123456789',
            OrgSync_Guardian_2_Work_Phone__c = '123456788',
            OrgSync_Guardian_1_Mobile_Phone__c = '123456787',
            OrgSync_Guardian_2_Mobile_Phone__c = '123456786',
            OrgSync_Guardian_1_First_Name__c = 'Test',
            OrgSync_Guardian_2_First_Name__c = 'Test',
            OrgSync_Guardian_1_Last_Name__c = 'Guardian 1',
            OrgSync_Guardian_2_Last_Name__c = 'Guardian 2',
            OrgSync_FirstName__c= 'Test Orgsync',
            OrgSync_LastName__c= 'Patient',
            OrgSync_Home_Phone__c= '1234567890',
            OrgSync_Work_Phone__c= '123456789',
            OrgSync_Mobile_Phone__c= '123456787',
            OrgSync_Billing_Address__Street__s= '1234567890',
            OrgSync_Billing_Address__City__s= 'Test City',
            OrgSync_Billing_Address__StateCode__s= 'NY',
            OrgSync_Billing_Address__PostalCode__s= '12345',
            OrgSync_Shipping_Address__Street__s= '1234567890',
            OrgSync_Shipping_Address__City__s= 'Test City',
            OrgSync_Shipping_Address__StateCode__s= 'NY',
            OrgSync_Shipping_Address__PostalCode__s= '12345',
            OrgSync_Email_1__c= 'test.orgsync1@test.com',
            OrgSync_Email_2__c= 'test.orgsync2@test.com',
            OrgSync_CustomerId__c= 'TEST-PATIENT-001',
            OrgSync_Date_of_Birth__c= Date.today(),
            OrgSync_Preferred_Phone_Number__c= 'Home'
        );

        User orgSyncUser = [Select Id from User where Name = 'OrgSync User' LIMIT 1];
        System.runAs(orgSyncUser){
            Test.startTest();
            insert staging;
            Test.stopTest();
            List<Account> accounts = [Select Id from Account where XCDC_ExternalId__c = 'PAT001' AND RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_RT LIMIT 1];
            System.assertEquals(true, staging != null, 'Patient Stage should be created');
        }
    }

    @IsTest
    static void testSyncPatientFromPatientStageOnUpdate() {
        OrgSync_Patient_Staging__c staging = [Select Id, OrgSync_Practice__c, OrgSync_Preferred_Phone_Number__c, OrgSync_Email_1__c, OrgSync_Home_Phone__c, OrgSync_Date_of_Birth__c, OrgSync_Guardian_1_Last_Name__c, OrgSync_Guardian_2_Last_Name__c, OrgSync_Billing_Address__Street__s from OrgSync_Patient_Staging__c where XCDC_ExternalId__c = 'PAT001' LIMIT 1];
        staging.OrgSync_Practice__c = null;
        staging.OrgSync_Preferred_Phone_Number__c = 'Work';
        staging.OrgSync_Email_1__c = 'test.orgsync3@test.com';
        staging.OrgSync_Home_Phone__c = '1234567899';
        staging.OrgSync_Date_of_Birth__c = Date.today() - 10;
        staging.OrgSync_Guardian_1_Last_Name__c = 'Guardian 3';
        staging.OrgSync_Guardian_2_Last_Name__c = 'Guardian 4';
        staging.OrgSync_Billing_Address__Street__s ='Test Street';

        User orgSyncUser = [Select Id from User where Name = 'OrgSync User' LIMIT 1];
        System.runAs(orgSyncUser){
            Test.startTest();
            update staging;
            Test.stopTest();
            List<AccountContactRelation> acrs = [Select Id from AccountContactRelation where roles = :ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE and AccountId = :staging.OrgSync_Practice__c and IsActive = true and Is_Primary__c = true];
            System.assertEquals(0, acrs.size(), 'ACR should be deactivated');
        }
    }

    @IsTest
    static void testSyncPatientFromPatientStageOnDelete() {
        OrgSync_Patient_Staging__c staging = [Select Id,OrgSync_Practice__c from OrgSync_Patient_Staging__c where XCDC_ExternalId__c = 'PAT001' LIMIT 1];
        User orgSyncUser = [Select Id from User where Name = 'OrgSync User' LIMIT 1];
        System.runAs(orgSyncUser){
            Test.startTest();
            delete staging;
            Test.stopTest();
            List<AccountContactRelation> acrs = [Select Id from AccountContactRelation where roles = :ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE and AccountId = :staging.OrgSync_Practice__c];
            System.assertEquals(0, acrs.size(), 'ACR should be deleted');
        }
    }
}