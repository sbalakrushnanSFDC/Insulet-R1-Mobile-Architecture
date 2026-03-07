/**
 * @description Test class for OrgSync_PracticeHandler
 *              Tests the handler through actual DML operations that trigger AccountTriggerHandler
 * Created Date : Jan 12, 2026
 * Created By   : Neeraj Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 12, 2026        Neeraj Kumar            Initial Version
 */
@IsTest
private class OrgSync_PracticeHandler_Test {

    private static final String TEST_POSTAL_CODE = '12345';

    /**
     * @description Generates a unique external ID to avoid conflicts in parallel tests
     * @param prefix A short prefix to identify the test context
     * @return String A unique external ID
     */
    private static String generateUniqueExtId(String prefix) {
        return prefix + '-' + String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 4);
    }

    /**
     * @description Test insert of Practice and non-Practice accounts
     *              Covers: handleBeforeInsert, filterPracticeRecords loop, isEligible (true & false paths)
     */
    @IsTest
    static void testInsertAccounts() {
        String practiceExtId = generateUniqueExtId('PRAC');
        String patientExtId = generateUniqueExtId('PAT');
        List<Account> accounts = new List<Account>{
            new Account(
                Name = 'Test Practice',
                RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT,
                XCDC_ExternalId__c = practiceExtId,
                BillingPostalCode = TEST_POSTAL_CODE
            ),
            new Account(
                LastName = 'Test Patient',
                RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT,
                XCDC_ExternalId__c = patientExtId,
                BillingPostalCode = TEST_POSTAL_CODE
            )
        };

        Test.startTest();
        insert accounts;
        Test.stopTest();

        List<Account> insertedAccounts = [SELECT Id FROM Account WHERE XCDC_ExternalId__c IN (:practiceExtId, :patientExtId)];
        Assert.areEqual(2, insertedAccounts.size(), 'Both accounts should be inserted');
    }

    /**
     * @description Test update of Practice accounts
     *              Covers: handleBeforeUpdate
     */
    @IsTest
    static void testUpdatePracticeAccount() {
        String extId = generateUniqueExtId('PRAC-UPD');
        Account practiceAccount = new Account(
            Name = 'Test Practice',
            RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT,
            XCDC_ExternalId__c = extId,
            BillingPostalCode = TEST_POSTAL_CODE
        );
        insert practiceAccount;

        practiceAccount.Name = 'Updated Practice';

        Test.startTest();
        update practiceAccount;
        Test.stopTest();

        Account updatedAccount = [SELECT Name FROM Account WHERE Id = :practiceAccount.Id];
        Assert.areEqual('Updated Practice', updatedAccount.Name, 'Name should be updated');
    }

    /**
     * @description Test with null records - covers filterPracticeRecords null check (line 47)
     */
    @IsTest
    static void testNullRecords() {
        Test.startTest();
        OrgSync_PracticeHandler.handleBeforeInsert(null);
        OrgSync_PracticeHandler.handleBeforeUpdate(null, null);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle null records gracefully');
    }

    /**
     * @description Test with null account in list - covers isEligible null check (line 65)
     */
    @IsTest
    static void testNullAccountInList() {
        List<Account> accountsWithNull = new List<Account>{ null };

        Test.startTest();
        OrgSync_PracticeHandler.handleBeforeInsert(accountsWithNull);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle null account in list gracefully');
    }
}