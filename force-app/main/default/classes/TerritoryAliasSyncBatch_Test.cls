/**
 * @description Test class for TerritoryAliasSyncBatch
 *              Uses TestDataFactory for consistent test data creation
 *              
 * Note:        AccountHistory records are automatically created when Territory_Alias__c
 *              is updated on an Account (requires field history tracking to be enabled),
 *              Is parallel is not allowed on the current method
 *
 * @author      Niranjan Elangovan
 * @createdDate November 16, 2025
 * 
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Nov 16, 2025        Niranjan Elangovan      Initial Version
 * V1.0.1       29th Dec 2025       Srinivas Shanigarapu    Updated(US - NGOMCT-235)
 */
@isTest
private class TerritoryAliasSyncBatch_Test {

  /**
   * @description Helper method to create an admin user with Bypass_Automations permission set
   * @return User Admin user with bypass permissions
   */
  private static User createAdminUserWithBypassPermissions() {
    User adminUser = TestDataFactory.getTestUser(
      'System Administrator',
      new Map<String, Object>{
        'FirstName' => 'Admin',
        'LastName' => 'TestUser'
      }
    );
    insert adminUser;

    PermissionSet ps = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Bypass_Automations'
      LIMIT 1
    ];

    insert new PermissionSetAssignment(
      AssigneeId = adminUser.Id,
      PermissionSetId = ps.Id
    );
    return adminUser;
  }

  /**
   * @description Test setup method to create common Practice, Patient, Trainer
   *              Accounts and primary AccountContactRelation records
   */
  @TestSetup
  static void setupTestData() {
    Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType(
      new Map<String, Object>{ 'Territory_Alias__c' => 'TERR-001' }
    );
    insert practiceAccount;

    Account practiceAccount2 = new Account(
      RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT,
      Name = 'Test Practices Acc 2',
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

    Account ccTrainerAccount = TestDataFactory.getAccountofTrainerRecordType(
      new Map<String, Object>{
        'Territory_Alias__c' => '',
        'Trainer_Type__c' => ConstantsUtil.CLINIC_CONTRACT_TRAINER
      }
    );
    insert ccTrainerAccount;

    Contact ccTrainerContact = [
      SELECT Id, AccountId
      FROM Contact
      WHERE AccountId = :ccTrainerAccount.Id
      LIMIT 1
    ];

    insert new AccountContactRelation(
      AccountId = practiceAccount.Id,
      ContactId = ccTrainerContact.Id,
      Is_Primary__c = true
    );

    Account cptandccTrainerAccount =
      TestDataFactory.getAccountofTrainerRecordType(
        new Map<String, Object>{
          'Territory_Alias__c' => '',
          'Trainer_Type__c' =>
            ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER,
          'FirstName' => 'CPT and CC',
          'LastName' => 'Account'
        }
      );
    insert cptandccTrainerAccount;

    Contact cptandccTrainerContact = [
      SELECT Id, AccountId
      FROM Contact
      WHERE AccountId = :cptandccTrainerAccount.Id
      LIMIT 1
    ];

    insert new AccountContactRelation(
      AccountId = practiceAccount.Id,
      ContactId = cptandccTrainerContact.Id,
      Is_Primary__c = true,
      Roles = ConstantsUtil.ACR_ROLE_TRAINER
    );
  }

  /**
   * @description Verifies CC Trainer territory is synced when Practice territory changes
   */
  @IsTest
  static void testBatchUpdatesCCTrainerTerritorySuccess() {
    Id batchId;
    User testUser = TestDataFactory.getTestUser();
    insert testUser;

    TerritoryAliasSyncBatch.isTestMode = true;

    Account practice = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Name = 'Test Practice Account'
      LIMIT 1
    ];

    Account patient = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Trainer_Type__c = :ConstantsUtil.CLINIC_CONTRACT_TRAINER
      LIMIT 1
    ];

    practice.Territory_Alias__c = 'TERR_NEW';
    update practice;

    Test.startTest();
    System.runAs(testUser) {
      batchId = Database.executeBatch(new TerritoryAliasSyncBatch(), 50);
    }
    Test.stopTest();

    Account updated = [
      SELECT Territory_Alias__c
      FROM Account
      WHERE Id = :patient.Id
    ];

    Assert.areEqual(
      'TERR_NEW',
      updated.Territory_Alias__c,
      'CC territory should sync with practice'
    );
  }

  /**
   * @description Verifies CPT & CC Trainer territory is synced when Practice territory changes
   */
  @IsTest
  static void testBatchUpdatesCPTAndCCTrainerTerritorySuccess() {
    Id batchId;
    User testUser = TestDataFactory.getTestUser();
    insert testUser;

    TerritoryAliasSyncBatch.isTestMode = true;

    Account practice = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Name = 'Test Practice Account'
      LIMIT 1
    ];

    Account patient = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Trainer_Type__c =
        :ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER
      LIMIT 1
    ];

    practice.Territory_Alias__c = 'TERR_NEW';
    update practice;

    Test.startTest();
    System.runAs(testUser) {
      batchId = Database.executeBatch(new TerritoryAliasSyncBatch(), 50);
    }
    Test.stopTest();

    Account updated = [
      SELECT Territory_Alias__c
      FROM Account
      WHERE Id = :patient.Id
    ];

    Assert.areEqual(
      'TERR_NEW',
      updated.Territory_Alias__c,
      'CPT and CC territory should sync with practice'
    );
  }

  /**
   * @description Verifies Patient territory is updated successfully from Practice
   */
  @IsTest
  static void testBatchUpdatesPatientTerritorySuccess() {
    Id batchId;
    User testUser = TestDataFactory.getTestUser();
    insert testUser;

    TerritoryAliasSyncBatch.isTestMode = true;

    Account practice = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Name = 'Test Practice Account'
      LIMIT 1
    ];

    Account patient = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE FirstName = 'Test' AND LastName = 'Patient'
      LIMIT 1
    ];

    practice.Territory_Alias__c = 'TERR_NEW';
    update practice;

    Test.startTest();
    System.runAs(testUser) {
      batchId = Database.executeBatch(new TerritoryAliasSyncBatch(), 50);
    }
    Test.stopTest();

    Account updated = [
      SELECT Territory_Alias__c
      FROM Account
      WHERE Id = :patient.Id
    ];

    Assert.areEqual(
      'TERR_NEW',
      updated.Territory_Alias__c,
      'Patient territory should sync with practice'
    );
  }

  /**
   * @description Verifies Patient territory is NOT updated when validation fails
   */
  @IsTest
  static void testBatchUpdatesPatientTerritoryFailure() {
    Id batchId;
    User testUser = TestDataFactory.getTestUser();
    insert testUser;

    User adminUser = createAdminUserWithBypassPermissions();
    TerritoryAliasSyncBatch.isTestMode = true;

    Account practice = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Name = 'Test Practice Account'
      LIMIT 1
    ];

    Account patient = [
      SELECT Id, Territory_Alias__c, Date_Of_Birth__c
      FROM Account
      WHERE FirstName = 'Test' AND LastName = 'Patient'
      LIMIT 1
    ];

    System.runAs(adminUser) {
      patient.Date_Of_Birth__c = Date.today().addDays(2);
      update patient;

      practice.Territory_Alias__c = 'TERR_NEW';
      update practice;
    }

    Test.startTest();
    System.runAs(testUser) {
      batchId = Database.executeBatch(new TerritoryAliasSyncBatch(), 50);
    }
    Test.stopTest();

    Account updated = [
      SELECT Territory_Alias__c
      FROM Account
      WHERE Id = :patient.Id
    ];

    Assert.areEqual(
      null,
      updated.Territory_Alias__c,
      'Patient territory should not sync when validation fails'
    );

    AsyncApexJob job = [
      SELECT Id
      FROM AsyncApexJob
      WHERE Id = :batchId
    ];
    System.assertNotEquals(null, job, 'Batch job should exist');
  }

  /**
   * @description Verifies batch execution when no AccountHistory records exist
   */
  @IsTest
  static void testBatchWithNoHistoryRecords() {
    User testUser = TestDataFactory.getTestUser();
    insert testUser;

    TerritoryAliasSyncBatch.isTestMode = false;

    Test.startTest();
    System.runAs(testUser) {
      Id batchId = Database.executeBatch(new TerritoryAliasSyncBatch(), 200);
      System.assertNotEquals(null, batchId, 'Batch should execute successfully');
    }
    Test.stopTest();
  }

  /**
   * @description Verifies non-primary ACR records are ignored
   */
  @IsTest
  static void testBatchWithNonPrimaryAccountContactRelation() {
    User testUser = TestDataFactory.getTestUser();
    insert testUser;

    TerritoryAliasSyncBatch.isTestMode = true;

    Account practice = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Name = 'Test Practice Account'
      LIMIT 1
    ];

    Account patient = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE FirstName = 'Test' AND LastName = 'Patient'
      LIMIT 1
    ];

    String originalPatientTerritory = patient.Territory_Alias__c;

    AccountContactRelation acr = [
      SELECT Id, Is_Primary__c
      FROM AccountContactRelation
      WHERE AccountId = :practice.Id
      LIMIT 1
    ];
    acr.Is_Primary__c = false;
    update acr;

    practice.Territory_Alias__c = 'TERR_UPDATED';
    update practice;

    Test.startTest();
    System.runAs(testUser) {
      Database.executeBatch(new TerritoryAliasSyncBatch(), 200);
    }
    Test.stopTest();

    Account updatedPatient = [
      SELECT Territory_Alias__c
      FROM Account
      WHERE Id = :patient.Id
    ];

    Assert.areEqual(
      originalPatientTerritory,
      updatedPatient.Territory_Alias__c,
      'Patient territory should NOT be updated when ACR is not primary'
    );
  }

  /**
   * @description Verifies no update occurs when Practice and Patient territories already match
   */
  @IsTest
  static void testBatchWithMatchingTerritory() {
    User testUser = TestDataFactory.getTestUser();
    insert testUser;

    User adminUser = createAdminUserWithBypassPermissions();
    TerritoryAliasSyncBatch.isTestMode = true;

    Account practice = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Name = 'Test Practice Account'
      LIMIT 1
    ];

    Account patient = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE FirstName = 'Test' AND LastName = 'Patient'
      LIMIT 1
    ];

    System.runAs(adminUser) {
      patient.Territory_Alias__c = 'TERR_MATCH';
      update patient;

      practice.Territory_Alias__c = 'TERR_MATCH';
      update practice;
    }

    Test.startTest();
    System.runAs(testUser) {
      Database.executeBatch(new TerritoryAliasSyncBatch(), 200);
    }
    Test.stopTest();

    Account updated = [
      SELECT Territory_Alias__c
      FROM Account
      WHERE Id = :patient.Id
    ];

    Assert.areEqual(
      'TERR_MATCH',
      updated.Territory_Alias__c,
      'Territory should remain unchanged'
    );
  }

  /**
   * @description Verifies bulk processing of multiple Patient records
   */
  @IsTest
  static void testBatchWithMultiplePatients() {
    User testUser = TestDataFactory.getTestUser();
    insert testUser;

    TerritoryAliasSyncBatch.isTestMode = true;

    Account practice = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Name = 'Test Practice Account'
      LIMIT 1
    ];

    List<Account> patients = TestDataFactory.getAccounts(
      5,
      new Map<String, Object>{ 'Territory_Alias__c' => 'OLD_TERR' },
      ConstantsUtil.ACCOUNT_PATIENT_RT
    );
    insert patients;

    List<Contact> contacts = [
      SELECT Id, AccountId
      FROM Contact
      WHERE AccountId IN :patients
    ];

    List<AccountContactRelation> acrList = new List<AccountContactRelation>();
    for (Contact con : contacts) {
      acrList.add(
        new AccountContactRelation(
          AccountId = practice.Id,
          ContactId = con.Id,
          Is_Primary__c = true
        )
      );
    }
    insert acrList;

    practice.Territory_Alias__c = 'BULK_TERR_NEW';
    update practice;

    Test.startTest();
    System.runAs(testUser) {
      Database.executeBatch(new TerritoryAliasSyncBatch(), 200);
    }
    Test.stopTest();

    List<Account> updatedPatients = [
      SELECT Territory_Alias__c
      FROM Account
      WHERE Id IN :patients
    ];

    for (Account patient : updatedPatients) {
      Assert.areEqual(
        'BULK_TERR_NEW',
        patient.Territory_Alias__c,
        'All patients should be updated'
      );
    }
  }

  /**
   * @description Verifies finish() method executes without error
   */
  @IsTest
  static void testBatchFinishMethodLogging() {
    User testUser = TestDataFactory.getTestUser();
    insert testUser;

    TerritoryAliasSyncBatch.isTestMode = true;

    Account practice = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Name = 'Test Practice Account'
      LIMIT 1
    ];

    practice.Territory_Alias__c = 'TERR_FINISH';
    update practice;

    Test.startTest();
    System.runAs(testUser) {
      Id batchId = Database.executeBatch(new TerritoryAliasSyncBatch(), 200);
      System.assertNotEquals(null, batchId, 'Batch should start successfully');
    }
    Test.stopTest();
  }

  /**
   * @description Verifies invalid ACR or null Practice territory is safely ignored
   */
  @IsTest
  static void testBatchWithInvalidAccountContactRelation() {
    User testUser = TestDataFactory.getTestUser();
    insert testUser;

    TerritoryAliasSyncBatch.isTestMode = true;

    Account practice = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Name = 'Test Practice Account'
      LIMIT 1
    ];

    Account patient = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE FirstName = 'Test' AND LastName = 'Patient'
      LIMIT 1
    ];

    String originalPatientTerritory = patient.Territory_Alias__c;

    practice.Territory_Alias__c = null;
    update practice;

    Test.startTest();
    System.runAs(testUser) {
      Database.executeBatch(new TerritoryAliasSyncBatch(), 200);
    }
    Test.stopTest();

    Account updatedPatient = [
      SELECT Territory_Alias__c
      FROM Account
      WHERE Id = :patient.Id
    ];

    Assert.areEqual(
      originalPatientTerritory,
      updatedPatient.Territory_Alias__c,
      'Patient territory should NOT be updated when Practice territory is null'
    );

    List<AccountContactRelation> acrList = [
      SELECT Id
      FROM AccountContactRelation
      WHERE AccountId = :practice.Id
    ];
    Assert.areEqual(3, acrList.size(), 'Should have 3 ACR record');
  }

  /**
   * @description Verifies Patient territory syncs correctly when linked to multiple Practices
   */
  @IsTest
  static void testBatchUpdatesPatientTerritorySuccessAccount() {
    Id batchId;
    User testUser = TestDataFactory.getTestUser();
    insert testUser;

    TerritoryAliasSyncBatch.isTestMode = true;

    Account practice = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Name = 'Test Practice Account'
      LIMIT 1
    ];

    Account practice1 = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE Name = 'Test Practices Acc 2'
      LIMIT 1
    ];

    Account patient = [
      SELECT Id, Territory_Alias__c
      FROM Account
      WHERE FirstName = 'Test' AND LastName = 'Patient'
      LIMIT 1
    ];

    contact patientContact = [
      SELECT Id
      FROM contact
      WHERE AccountId = :patient.Id
    ];

    practice.Territory_Alias__c = 'TERR_NEW';
    update practice;

    practice1.Territory_Alias__c = 'TERR_NEW';
    update practice1;

    insert new AccountContactRelation(
      AccountId = practice1.Id,
      ContactId = patientContact.Id,
      Is_Primary__c = true
    );

    patient.Territory_Alias__c = '';
    update patient;

    Test.startTest();
    System.runAs(testUser) {
      batchId = Database.executeBatch(new TerritoryAliasSyncBatch(), 50);
    }
    Test.stopTest();

    Account updated = [
      SELECT Territory_Alias__c
      FROM Account
      WHERE Id = :patient.Id
    ];

    Assert.areEqual(
      'TERR_NEW',
      updated.Territory_Alias__c,
      'Patient territory should sync with practice'
    );
  }
}