/**
 * @description Test class for OrgSync_TrainingStagingTrigger.
 *              Extends the standard TriggerHandler framework.
 * Created Date : Feb 16, 2026
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Feb 16, 2026        Neeraj Kumar            Initial Version
 */
@IsTest
private class OrgSync_TrainingStagingTriggerTest {

    @IsTest
    static void testInsertAndUpdate() {
        OrgSync_Training_Staging__c staging = new OrgSync_Training_Staging__c();
        String extId = OrgSync_UtilityService.generateUniqueExtId('DELSUC');
        Account acc = new Account(
            LastName = 'To Delete',
            RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT,
            XCDC_ExternalId__c = extId,
            BillingPostalCode = '89765'
        );
        insert acc;
        staging.OrgSync_Account__c = acc.Id;
        Test.startTest();
        insert staging;
        Test.stopTest();

        System.assertNotEquals(null, staging.Id, 'Record should be inserted.');
    }
}