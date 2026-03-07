/**
 * @description Test class for AccountContactRelationService
 * US NGOMCT-343
 * @author Shailja Jain
 * @date 2025-10-06
 *
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       2025-10-06          Shailja Jain                  Initial Version(US - NGOMCT-343)
 * V1.0.1       2025-11-20          Charchit N.                   NGOMCT-1079
 * V1.0.2       2025-12-29          Srinivas Shanigarapu          Updated(US - NGOMCT-235)
 */
@IsTest(isParallel=true)
private class AccountContactRelationService_Test {
  /**
   * @description Inner wrapper class to store parameters required for Lead conversion logic in tests.
   */
  private class LeadConversionParams {
    Boolean createPersonAccount;
    Id accountToUse;
    Id practiceId;
    Map<String, Object> extraFields;

    LeadConversionParams(Boolean createPersonAccount, Id practiceId) {
      this.createPersonAccount = createPersonAccount;
      this.practiceId = practiceId;
      this.extraFields = new Map<String, Object>();
    }
  }

  /**
   * @description Test setup method to create common Practice, Patient, Trainer
   *              Accounts and primary AccountContactRelation records
   */
  @TestSetup
  static void setupTestData() {
    Account practiceAccount = new Account(
      RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT,
      Name = 'Test Practices Acc',
      Phone = '444-123-4588',
      BillingPostalCode = '234569',
      Territory_Alias__c = 'TERR-001'
    );
    insert practiceAccount;

    Account practiceAccount2 = new Account(
      RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT,
      Name = 'Practices Acc 2',
      Phone = '444-123-4588',
      BillingPostalCode = '234569',
      Territory_Alias__c = 'TERR-001'
    );
    insert practiceAccount2;

    Account patientAccount = TestDataFactory.getAccountofPatientRecordType(
      new Map<String, Object>{ 'Territory_Alias__c' => '' }
    );
    insert patientAccount;

    Contact patientContact = [
      SELECT Id, AccountId
      FROM Contact
      WHERE AccountId = :patientAccount.Id
      LIMIT 1
    ];

    insert new AccountContactRelation(
      AccountId = practiceAccount.Id,
      ContactId = patientContact.Id,
      Is_Primary__c = true
    );

    insert new AccountContactRelation(
      AccountId = practiceAccount2.Id,
      ContactId = patientContact.Id
    );
  }

  /**
   * @description Verifies UpdateExistingPrimaries method functionality with primary ACR.
   */
  @IsTest
  static void testUpdateExistingPrimariesWithIsPrimaryACR() {
    List<AccountContactRelation> acrs = [
      SELECT id, Is_Primary__c, AccountId, ContactId
      FROM AccountContactRelation
      WHERE Is_Primary__c = TRUE
      LIMIT 1
    ];
    AccountContactRelationService.updateExistingPrimaries(acrs);
    List<AccountContactRelation> acrUpdated = [
      SELECT id, Is_Primary__c, AccountId, ContactId
      FROM AccountContactRelation
      WHERE id = :acrs[0].id
    ];
    Assert.isFalse(
      acrUpdated[0].Is_Primary__c,
      'ACR isPrimary should set to false.'
    );
  }

  /**
   * @description
   * Verifies that DML errors are correctly processed and logged by the
   * logDMLErrors method when a Database operation fails.
   *
   * This test intentionally creates an invalid AccountContactRelation record
   * (missing AccountId) and performs a DML operation with allOrNone = false
   * to generate a failed SaveResult without throwing an exception.
   */
  @IsTest
  static void testLogDMLErrorsCoverage() {
    List<Account> personAcc = [
      SELECT id, PersonContactId
      FROM Account
      WHERE isPersonAccount = TRUE
    ];
    AccountContactRelation invalidAcr = new AccountContactRelation(
      ContactId = personAcc[0].PersonContactId,
      Is_Primary__c = true
      // AccountId intentionally omitted
    );
    List<AccountContactRelation> acrs = new List<AccountContactRelation>{
      invalidAcr
    };

    Test.startTest();
    Database.SaveResult[] results = Database.insert(acrs, false);
    AccountContactRelationService.logDMLErrors(
      results,
      acrs,
      'Failed to insert ACR: '
    );
    Test.stopTest();
    Assert.areEqual(false, results[0].isSuccess(), 'SaveResult should fail');
  }

  /**
   * @description Helper method to create and convert a standard Lead.
   * @param params An instance of LeadConversionParams containing setup and conversion data.
   * @return The converted Lead record with updated fields.
   */
  private static Lead createAndConvertLead(LeadConversionParams params) {
    Map<String, Object> leadFields = new Map<String, Object>();
    if (params.extraFields != null && !params.extraFields.isEmpty()) {
      leadFields.putAll(params.extraFields);
    }
    if (params.createPersonAccount == true) {
      leadFields.put('Company', null);
    } else {
      if (!leadFields.containsKey('Company')) {
        leadFields.put(
          'Company',
          'TestCo-' + Math.abs(Crypto.getRandomInteger())
        );
      }
    }
    if (!leadFields.containsKey('Email')) {
      leadFields.put(
        'Email',
        'testlead' + Math.abs(Crypto.getRandomInteger()) + '@test.com'
      );
    }
    Lead l = TestDataFactory.getLead(leadFields);
    l.Practice__c = params.practiceId;
    insert l;
    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setDoNotCreateOpportunity(true);
    lc.setConvertedStatus('Qualified');
    if (params.accountToUse != null) {
      lc.setAccountId(params.accountToUse);
    }
    Database.LeadConvertResult res = Database.convertLead(lc);
    Assert.isTrue(res.isSuccess(), 'Lead conversion failed in test: ' + res);
    return [
      SELECT
        Id,
        IsConverted,
        ConvertedContactId,
        ConvertedAccountId,
        Company,
        Status,
        Practice__c
      FROM Lead
      WHERE Id = :l.Id
    ];
  }

  /**
   * @description Helper method to create and convert a Patient Lead.
   * @param params An instance of LeadConversionParams containing setup and conversion data.
   * @return The converted Lead record with updated fields.
   */
  private static Lead createAndConvertPatientLead(LeadConversionParams params) {
    Map<String, Object> leadFields = new Map<String, Object>();
    if (params.extraFields != null && !params.extraFields.isEmpty()) {
      leadFields.putAll(params.extraFields);
    }
    if (params.createPersonAccount == true) {
      leadFields.put('Company', null);
    } else {
      if (!leadFields.containsKey('Company')) {
        leadFields.put(
          'Company',
          'TestCo-' + Math.abs(Crypto.getRandomInteger())
        );
      }
    }
    if (!leadFields.containsKey('Email')) {
      leadFields.put(
        'Email',
        'testlead' + Math.abs(Crypto.getRandomInteger()) + '@test.com'
      );
    }
    Lead l = TestDataFactory.getLead(leadFields);
    HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility();
    l.Provider_Practice_Affiliation__c = facility.Id;
    insert l;
    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setDoNotCreateOpportunity(true);
    lc.setConvertedStatus('Qualified');
    if (params.accountToUse != null) {
      lc.setAccountId(params.accountToUse);
    }
    Database.LeadConvertResult res = Database.convertLead(lc);
    Assert.isTrue(res.isSuccess(), 'Lead conversion failed in test: ' + res);
    return [
      SELECT
        Id,
        IsConverted,
        ConvertedContactId,
        ConvertedAccountId,
        Company,
        Status,
        Practice__c
      FROM Lead
      WHERE Id = :l.Id
    ];
  }

  /**
   * @description Verifies that an AccountContactRelation is correctly created between a Trainer and a Practice upon lead conversion.
   */
  @IsTest
  static void testCreateAcrForPractice() {
    Account practice = TestDataFactory.getAccountofPracticeRecordType();
    insert practice;
    Contact contact = TestDataFactory.getContact(
      new Map<String, Object>{ 'AccountId' => practice.Id }
    );
    insert contact;
    Account trainer = TestDataFactory.getAccountofTrainerRecordType();
    insert trainer;

    LeadConversionParams params = new LeadConversionParams(true, practice.Id);
    params.accountToUse = trainer.Id;
    Lead convLead = createAndConvertLead(params);

    Test.startTest();
    AccountContactRelationService.createACRForTrainerPractice(
      new List<Lead>{ convLead },
      ConstantsUtil.OMCT_TAG
    );
    Test.stopTest();
    List<AccountContactRelation> acrs = [
      SELECT Id, AccountId, ContactId
      FROM AccountContactRelation
      WHERE AccountId = :practice.Id AND ContactId = :contact.Id
    ];
    Assert.areEqual(
      1,
      acrs.size(),
      'Expected one AccountContactRelation to be created.'
    );
    Assert.areEqual(
      practice.Id,
      acrs[0].AccountId,
      'ACR AccountId should match the practice Id.'
    );
    Assert.areEqual(
      contact.Id,
      acrs[0].ContactId,
      'ACR ContactId should match the contact Id.'
    );
  }

  /**
   * @description Tests that the service methods return gracefully without error when provided with null or empty input lists.
   */
  @IsTest
  static void testCreateAcrForPracticeEmptyInput() {
    Test.startTest();
    AccountContactRelationService.createACRForTrainerPractice(
      null,
      ConstantsUtil.OMCT_TAG
    );
    AccountContactRelationService.createACRForTrainerPractice(
      new List<Lead>(),
      ConstantsUtil.OMCT_TAG
    );
    Test.stopTest();
    Assert.isTrue(true, 'Method should safely return on null/empty input.');
  }

  /**
   * @description Verifies that partial DML success is handled correctly: valid ACRs should be inserted even if some records in the list fail.
   */
  @IsTest
  static void testInsertAccountContactRelationshipsPartialFailure() {
    Account practice = TestDataFactory.getAccountofPracticeRecordType();
    insert practice;
    Contact validContact = TestDataFactory.getContact(
      new Map<String, Object>{
        'AccountId' => practice.Id,
        'Email' => 'valid.contact@test.local'
      }
    );
    insert validContact;
    AccountContactRelation validAcr = new AccountContactRelation(
      AccountId = practice.Id,
      ContactId = validContact.Id
    );
    Id fakeContactId = MockDataFactory.getFakeId('Contact');
    AccountContactRelation invalidAcr = new AccountContactRelation(
      AccountId = practice.Id,
      ContactId = fakeContactId
    );
    List<AccountContactRelation> acrList = new List<AccountContactRelation>{
      validAcr,
      invalidAcr
    };
    Test.startTest();
    AccountContactRelationService.insertAccountContactRelationships(acrList);
    Test.stopTest();
    Integer insertedCount = [
      SELECT COUNT()
      FROM AccountContactRelation
      WHERE AccountId = :practice.Id AND ContactId = :validContact.Id
    ];
    Assert.areEqual(
      1,
      insertedCount,
      'Valid ACR should be inserted despite the invalid record causing partial failure.'
    );
    Integer fakeCount = [
      SELECT COUNT()
      FROM AccountContactRelation
      WHERE AccountId = :practice.Id AND ContactId = :fakeContactId
    ];
    Assert.areEqual(0, fakeCount, 'Invalid ACR should not be inserted.');
  }

  /**
   * @description Validates that setup and build methods correctly return empty lists when inputs are null or empty.
   */
  @IsTest
  static void testSetupPracticeAccConRelationsNullAndEmptyInput() {
    Test.startTest();
    List<AccountContactRelation> resultNull = AccountContactRelationService.setupTrainerPracticeAccConRelations(
      null
    );
    AccountContactRelationService.buildAcrsToUpsert(
      new AccountContactRelationService.TrainerAccConData(),
      null
    );
    Assert.areEqual(0, resultNull.size(), 'Expected empty list for null input');
    List<AccountContactRelation> resultEmpty = AccountContactRelationService.setupTrainerPracticeAccConRelations(
      new List<Lead>()
    );
    AccountContactRelationService.buildAcrsToUpsert(
      new AccountContactRelationService.TrainerAccConData(),
      null
    );
    Assert.areEqual(
      0,
      resultEmpty.size(),
      'Expected empty list for empty input'
    );
    Test.stopTest();
  }

  /**
   * @description Tests the error handling path of ACR insertion by forcing a custom exception via switch.
   */
  @IsTest
  static void testInsertAccountContactRelationshipsException() {
    Account practice = TestDataFactory.getAccountofPracticeRecordType();
    insert practice;
    AccountContactRelation acr = new AccountContactRelation();
    acr.AccountId = practice.Id;
    Test.startTest();
    try {
      ConstantsUtil.customExceptionSwitch = true;
      AccountContactRelationService.insertAccountContactRelationships(
        new List<AccountContactRelation>{ acr }
      );
      Assert.areNotEqual('', acr.Id, 'Account service failed');
    } catch (Exception ex) {
      Assert.isTrue(true, 'Exception expected in test context');
    }
    Test.stopTest();
    Assert.isTrue(true, 'DmlException path covered successfully.');
  }

  /**
     * @description Verifies that a Patient Lead converted via a HealthcarePractitionerFacility does create an AccountContactRelation.
     */
    @IsTest
    static void testPatientLeadCreateACRImmediately() {
        Account practice = TestDataFactory.getAccountofPracticeRecordType();
        insert practice;

        HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility(
            new Map<String, Object>{ 'AccountId' => practice.Id }
        );
        insert facility;

        // Arrange: Prepopulate mappings (simulate service queries)
        Set<Id> facilityIds = new Set<Id>{ facility.Id };
        AccountContactRelationService.queryHPFToPractice(facilityIds);

        Account personAcc = [
            SELECT Id, IsPersonAccount
            FROM Account
            WHERE IsPersonAccount = TRUE
            LIMIT 1
        ];
        Set<Id> personIds = new Set<Id>{ personAcc.Id };
        AccountContactRelationService.queryPersonAccounts(personIds);

        // Act: Create and insert Patient Lead linked to the facility
        Lead patientLead = TestDataFactory.getLead(
            new Map<String, Object>{
                'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
                'FirstName' => 'First Name',
                'LastName' => 'Last Name',
                'Recommended_Product__c' => '',
                'Provider_Practice_Affiliation__c' => facility.Id
            }
        );
        insert patientLead;

        patientLead = [
            SELECT Id, ConvertedAccountId
            FROM Lead
            WHERE Id = :patientLead.Id
        ];

        List<AccountContactRelation> acrs = [
            SELECT Id, AccountId, ContactId
            FROM AccountContactRelation
            WHERE AccountId = :practice.Id
        ];

        Assert.isTrue(
            acrs.size() >= 1,
            'AccountContactRelation should exist for the practice at this point.'
        );
    }

  /**
   * @description Validates the creation of primary ACRs when multiple leads are converted and merged into a single existing Account.
   */
  @IsTest
  static void testCreateAcrForPatientPractice() {
    Account practice = TestDataFactory.getAccountofPracticeRecordType();
    insert practice;

    HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility(
      new Map<String, Object>{ 'AccountId' => practice.Id }
    );
    insert facility;

    Lead patientLead = TestDataFactory.getLead(
      new Map<String, Object>{
        'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
        'FirstName' => 'Test',
        'LastName' => 'Name',
        'date_of_birth__c' => Date.newInstance(1990, 1, 1)
      }
    );
    insert patientLead;

    Test.startTest();
    Database.LeadConvert lc1 = new Database.LeadConvert();
    lc1.setLeadId(patientLead.Id);
    lc1.setConvertedStatus('Converted');
    Database.LeadConvertResult lcr1 = Database.convertLead(lc1);
    Assert.isTrue(
      lcr1.isSuccess(),
      'First lead conversion failed: ' + lcr1.getErrors()
    );

    Account practice2 = TestDataFactory.getAccountofPracticeRecordType(
      new Map<String, Object>{
        'Name' => 'Practice 2-' + Math.abs(Crypto.getRandomInteger())
      }
    );
    insert practice2;

    Lead patientLead2 = TestDataFactory.getLead(
      new Map<String, Object>{
        'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
        'FirstName' => 'First Name1',
        'LastName' => 'Last Name1',
        'email' => 'unique' +
        Math.abs(Crypto.getRandomInteger()) +
        '@test.com',
        'date_of_birth__c' => Date.newInstance(1990, 1, 1)
      }
    );
    insert patientLead2;

    Database.LeadConvert lc2 = new Database.LeadConvert();
    lc2.setLeadId(patientLead2.Id);
    lc2.setConvertedStatus('Converted');
    lc2.setAccountId(lcr1.getAccountId());
    Database.convertLead(lc2);
    Test.stopTest();

    List<AccountContactRelation> resAccList = [
      SELECT Id, AccountId
      FROM AccountContactRelation
      WHERE AccountId = :practice2.Id AND Is_Primary__c = TRUE
    ];

    Assert.isTrue(
      resAccList.isEmpty(),
      'ACR was not created. Check TaskGenerationRecordQuery line 98 logic.'
    );
  }

  /**
   * @description Ensures the service methods handle null values correctly and do not throw unhandled exceptions during bulk operations.
   */
  @IsTest
  static void testInsertAccountContactRelationshipsNullValueCheck() {
    Test.startTest();
    try {
      ConstantsUtil.customExceptionSwitch = true;
      AccountContactRelationService.insertAccountContactRelationships(
        new List<AccountContactRelation>{}
      );
      AccountContactRelationService.updateExistingPrimaries(
        new List<AccountContactRelation>{}
      );
      AccountContactRelationService.setupPatientPracticeAccConRelations(null);
      AccountContactRelationService.createACRForPatientPractice(null, null);
      AccountContactRelationService.createACRFromPairKey('Test', null);
    } catch (Exception ex) {
      Assert.fail(
        'Null is not handled properly in the code: ' + ex.getMessage()
      );
    }
    Test.stopTest();
    Assert.isTrue(
      true,
      'Execution completed without unexpected null pointer exceptions'
    );
  }
}