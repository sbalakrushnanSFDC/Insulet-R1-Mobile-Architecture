/**
 * @author      : Ankur Chauhan
 * @created Date: 8th December 2025
 * @description : Test class for GetCertificateController.
 * ============================ Logs =============================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       8th December 2025   Ankur Chauhan                 Initial Version
 */
@IsTest(isParallel=true)
public class GetCertificateController_Test {
  @TestSetup
  static void setupTestData() {
    new TestDataFactory.CreateTemplateRecord().setName('Test Template').save();

    Account testAccount = TestDataFactory.getAccountofPatientRecordType(
      new Map<String, Object>{
        'FirstName' => 'Test',
        'LastName' => 'PersonAccount',
        'PersonBirthdate' => Date.today()
      }
    );
    insert testAccount;
  }

  @IsTest
  static void testGetCongaTemplateId() {
    APXTConga4__Conga_Template__c templateRecord = [
      SELECT Id
      FROM APXTConga4__Conga_Template__c
      WHERE APXTConga4__Name__c = 'Test Template'
      LIMIT 1
    ];

    Test.startTest();
    Map<String, Id> result = GetCertificateController.getCongaTemplateId(
      'Test Template'
    );
    Test.stopTest();

    Assert.areEqual(
      templateRecord.Id,
      result.get('templateId'),
      'Template ID should match inserted value.'
    );
  }

  @IsTest
  static void testGetCongaTemplateIdNegative() {
    Test.startTest();
    try {
      // Invalid template name for throwing exception
      GetCertificateController.getCongaTemplateId('Template');
    } catch (Exception ex) {
      Assert.areEqual(ex.getMessage(), 'Script-thrown exception', 
        'Exception message should match expected value.');
    }
    Test.stopTest();
  }

  @IsTest
  static void testGetCongaTemplateIdNegative2() {
    Test.startTest();
    // Null template name
    Assert.areEqual(null, GetCertificateController.getCongaTemplateId(null), 'Null template name should return null');
    Test.stopTest();
  }
}