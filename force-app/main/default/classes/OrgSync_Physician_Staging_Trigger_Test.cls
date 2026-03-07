/**
 * @description Tests for OrgSync_Physician_Staging_Trigger and handler.
 * Created Date : Jan 28, 2026
 */
@IsTest
private class OrgSync_Physician_Staging_Trigger_Test {
    private static String uniqueSuffix() {
        return String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 4);
    }

    @IsTest
    static void testInsertAndUpdateAsNonOrgSyncUser() {
        OrgSync_UtilityService.orgSyncUserId = '005000000000000AAA';
        String extId = 'PHYS-STG-' + uniqueSuffix();

        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Physician Staging ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_FirstName__c = 'Trigger',
            OrgSync_LastName__c = 'Physician',
            OrgSync_Mailing_Address__PostalCode__s = '12345'
        );

        Test.startTest();
        insert staging;
        staging.OrgSync_LastName__c = 'Physician Updated';
        update staging;
        Test.stopTest();

        OrgSync_Physician_Staging__c reloaded = [
            SELECT Id, OrgSync_LastName__c
            FROM OrgSync_Physician_Staging__c
            WHERE Id = :staging.Id
        ];
        System.assertEquals('Physician Updated', reloaded.OrgSync_LastName__c, 'Staging should be updated');
    }

    @IsTest
    static void testInsertAndUpdateAsOrgSyncUser() {
        User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        String extId = 'PHYS-STG-ORG-' + uniqueSuffix();

        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c(
            Name = 'Physician Staging ' + extId,
            XCDC_ExternalId__c = extId,
            OrgSync_FirstName__c = 'Org',
            OrgSync_LastName__c = 'SyncUser',
            OrgSync_Mailing_Address__PostalCode__s = '12345'
        );

        System.runAs(runningUser) {
            OrgSync_UtilityService.orgSyncUserId = UserInfo.getUserId();
            Test.startTest();
            insert staging;
            staging.OrgSync_LastName__c = 'SyncUser Updated';
            update staging;
            Test.stopTest();
        }

        OrgSync_Physician_Staging__c reloaded = [
            SELECT Id, OrgSync_LastName__c
            FROM OrgSync_Physician_Staging__c
            WHERE Id = :staging.Id
        ];
        System.assertEquals('SyncUser Updated', reloaded.OrgSync_LastName__c, 'Staging should be updated');
    }
}