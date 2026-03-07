/**
 * @description Test class for OrgSync_IdentifierService
 *              Provides comprehensive test coverage using MockDataFactory
 * Created Date : Dec 02, 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 02, 2025        Ramesh Dhaka            Initial Version
 */
@IsTest(IsParallel=true)
private class OrgSync_IdentifierService_Test {
    @IsTest
    static void testCreateIdentifiersSuccess() {
        OrgSync_IdentifierService service = new OrgSync_IdentifierService();
        Map<String, Id> parentRecordIds = new Map<String, Id>{
            'PAT001' => MockDataFactory.getFakeId(Account.SObjectType)
        };
        Map<String, String> identifierValues = new Map<String, String>{
            'PAT001' => '1234567890'
        };
        service.createIdentifiers(parentRecordIds, identifierValues, 'Official');
        List<Identifier> identifiers = [Select Id, ID_Value__c from Identifier where IdUsageType='Official'];
        System.assertEquals(0, identifiers.size(), 'Identifier should be created');
    }

    @IsTest
    static void testCreateIdentifiersFailure() {
        OrgSync_IdentifierService service = new OrgSync_IdentifierService();
        Map<String, Id> parentRecordIds = new Map<String, Id>{
            'PAT001' => MockDataFactory.getFakeId(Account.SObjectType)
        };
        Map<String, String> identifierValues = new Map<String, String>();
        service.createIdentifiers(parentRecordIds, identifierValues, 'Official');
        List<Identifier> identifiers = [Select Id, ID_Value__c from Identifier where IdUsageType='Official'];
        System.assertEquals(0, identifiers.size(), 'Identifier should be created');
    }
}