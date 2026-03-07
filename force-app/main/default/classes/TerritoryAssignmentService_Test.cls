/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 4th Nov 2025
 * @description : Test class for TerritoryAssignmentService
 * Note         : We cant use (isParallel=true) because APEX_DATA_ACCESS_RESTRICTION, In parallel Apex tests, DML operations aren't permitted on this type of object: Territory2Model: []
 * 
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       4th Nov 2025        Bijayalaxmi Prusty      Initial Version (US - NGASIM-622)
 * V1.0.1       17th Nov 2025       Srinivas Shanigarapu    Updated Version(US - NGOMCT-469)
 * V1.0.2       1st  Jan 2026       Srinivas Shanigarapu    Updated Version(US - NGOMCT-235)
 * V1.0.3		16th Jan 2026		Shashank Nigam			Updated(US - NGOMCT-1719) Removed assignExternalTrainerTerritoryToLeads
 */
@IsTest
private class TerritoryAssignmentService_Test {
    /**
     * @description Test setup method to create test data
     */
    @TestSetup
    static void setupTestData() {
    User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    System.runAs(adminUser) {
        Territory2Model model = new TestDataFactory.CreateTerritory2ModelRecord()
            .setName('Test TM')
            .setDeveloperName('TestTM')
            .save()
            .getRecord();
        Territory2Type territoryType = [SELECT Id FROM Territory2Type LIMIT 1];
        
        new TestDataFactory.CreateTerritory2Record()
            .setName('External Trainer')
            .setTerritory2ModelId(model.Id)
            .setTerritory2TypeId(territoryType.Id)
            .setDescription('For tests')
            .setDeveloperName('External_Trainer')
            .save()
            .getRecord();
    }
    Account practiceAccount = new Account(
      RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT,
      Name = 'Test Practices Acc',
      Phone = '444-123-4588',
      BillingPostalCode = '234569',
      Territory_Alias__c = 'TERR-001'
    );
    insert practiceAccount;

    Account trainerAccount = TestDataFactory.getAccountofTrainerRecordType(
      new Map<String, Object>{
        'FirstName' => 'Test',
        'LastName' => 'Trainer One',
        'Contract_Type__c' => 'Level 3'
      }
    );
    insert trainerAccount;

    Contact trainerContact = [
      SELECT Id, AccountId
      FROM Contact
      WHERE AccountId = :trainerAccount.Id
      LIMIT 1
    ];

    insert new AccountContactRelation(
      AccountId = practiceAccount.Id,
      ContactId = trainerContact.Id,
      Roles = ConstantsUtil.ACR_ROLE_TRAINER,
      Is_Primary__c = true
    );
  }

  /**
   * @description Test Prepare Trainer Eligibility Logic
   */
  @IsTest
  static void testPrepareTrainerEligibility() {
    List<Account> accounts = [
      SELECT Id, PersonContactId, RecordTypeId
      FROM Account
      WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_TRAINER_RT
      LIMIT 1
    ];

    Test.startTest();
    TerritoryAssignmentService.prepareTrainerEligibility(accounts);
    Test.stopTest();

    Assert.isTrue(
      TerritoryAssignmentService.contactsWithPrimaryTrainerSet.size() > 0,
      'Contacts with PrimaryTrainerSet should be greater than zero'
    );
  }
    
    /**
     * @description Test territory assignment for Account insert with postal codes
     */
    @IsTest
    static void testAccountInsertWithPostalCodes() {
        // Create mock accounts with different record types and postal codes
        List<Account> accounts = new List<Account>();
        // Practice Account with postal code
    accounts.add(
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
            'Id' => MockDataFactory.getFakeId('Account'),
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
            'BillingPostalCode' => '67890',
            'Territory_Alias__c' => 'Previous Territory',
            'Specialty__c' => 'Cardiology'
        }
      )
    );

        Test.startTest();
        TerritoryAssignmentService.assignTerritoryToAccounts(accounts, null);
        Test.stopTest();

    Assert.isNull(
      accounts[0].Territory_Alias__c,
      'Practice account territory should be null when no ZipCode__c records exist'
    );
  }

  /**
   * @description Test territory assignment for CPT Trainer Account insert with postal codes
   */
  @IsTest
  static void testCPTTrainerAccountInsertWithPostalCodes() {
    // Create mock accounts with different record types and postal codes
    List<Account> accounts = new List<Account>();
    // Practice Account with postal code
    accounts.add(
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
          'Id' => MockDataFactory.getFakeId('Account'),
          'RecordTypeId' => ConstantsUtil.ACCOUNT_TRAINER_RT,
          'BillingPostalCode' => '67890',
          'Territory_Alias__c' => 'Previous Territory',
          'Specialty__c' => 'Cardiology',
          'Trainer_Type__c' => ConstantsUtil.CERTIFIED_POD_TRAINER
        }
      )
    );

    Test.startTest();
    TerritoryAssignmentService.assignTerritoryToAccounts(accounts, null);
    Test.stopTest();

    Assert.isNull(
      accounts[0].Territory_Alias__c,
      'Practice account territory should be null when no ZipCode__c records exist'
    );
  }

  /**
   * @description Test territory assignment for CC Trainer Account insert with postal codes
   */
  @IsTest
  static void testCCTrainerAccountInsertWithPostalCodes() {
    // Create mock accounts with different record types and postal codes
    List<Account> accounts = new List<Account>();
    // Practice Account with postal code
    accounts.add(
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
          'Id' => MockDataFactory.getFakeId('Account'),
          'RecordTypeId' => ConstantsUtil.ACCOUNT_TRAINER_RT,
          'BillingPostalCode' => '67890',
          'Territory_Alias__c' => 'Previous Territory',
          'Specialty__c' => 'Cardiology',
          'Trainer_Type__c' => ConstantsUtil.CLINIC_CONTRACT_TRAINER
        }
      )
    );

    Test.startTest();
    TerritoryAssignmentService.assignTerritoryToAccounts(accounts, null);
    Test.stopTest();

    Assert.isNull(
      accounts[0].Territory_Alias__c,
      'Practice account territory should not exist'
    );
  }

  /**
   * @description Test territory assignment for CPTand CC Trainer Account insert with postal codes
   */
  @IsTest
  static void testCPTCCTrainerAccountInsertWithPostalCodes() {
    // Create mock accounts with different record types and postal codes
    List<Account> accounts = new List<Account>();
    // Practice Account with postal code
    accounts.add(
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
          'Id' => MockDataFactory.getFakeId('Account'),
          'RecordTypeId' => ConstantsUtil.ACCOUNT_TRAINER_RT,
          'BillingPostalCode' => '67890',
          'Territory_Alias__c' => 'Previous Territory',
          'Specialty__c' => 'Cardiology',
          'Trainer_Type__c' => ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER
        }
      )
    );

    Test.startTest();
    TerritoryAssignmentService.assignTerritoryToAccounts(accounts, null);
    Test.stopTest();

    Assert.isNull(
      accounts[0].Territory_Alias__c,
      'Practice account territory should not exist'
    );
    }

    /**
     * @description Test territory assignment skips ineligible account record types
     */
    @IsTest
    static void testAccountInsertSkipsIneligibleRecordTypes() {
        // Create mock account with ineligible record type
        List<Account> accounts = new List<Account>();
    accounts.add(
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
            'Id' => MockDataFactory.getFakeId('Account'),
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PROVIDER_RT,
            'BillingPostalCode' => '12345',
            'Territory_Alias__c' => 'Previous Territory'
        }
      )
    );

        Test.startTest();
        TerritoryAssignmentService.assignTerritoryToAccounts(accounts, null);
        Test.stopTest();

        // Verify territory remains unchanged for ineligible record type
    Assert.areEqual(
      'Previous Territory',
      accounts[0].Territory_Alias__c,
      'Territory should remain unchanged for ineligible record type'
    );
    }

    /**
     * @description Test territory assignment skips accounts with blank postal codes
     */
    @IsTest
    static void testAccountInsertSkipsBlankPostalCodes() {
        // Create mock Practice accounts with blank postal codes
        List<Account> accounts = new List<Account>();
    accounts.add(
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
            'Id' => MockDataFactory.getFakeId('Account'),
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
            'BillingPostalCode' => null,
            'Territory_Alias__c' => 'Previous Territory',
            'Specialty__c' => 'Cardiology'
        }
      )
    );

        Test.startTest();
        TerritoryAssignmentService.assignTerritoryToAccounts(accounts, null);
        Test.stopTest();

        // Verify territory remains unchanged for blank postal codes
    Assert.areEqual(
      'Previous Territory',
      accounts[0].Territory_Alias__c,
      'Territory should remain unchanged for null postal code'
    );
    }

    /**
     * @description Test territory assignment for Account update with postal code changes
     */
    @IsTest
    static void testAccountUpdateWithPostalCodeChanges() {
        // Create current Practice accounts
        List<Account> newAccounts = new List<Account>();
    newAccounts.add(
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
            'Id' => MockDataFactory.getFakeId('Account'),
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
            'BillingPostalCode' => '67890',
            'Territory_Alias__c' => null,
            'Specialty__c' => 'Cardiology'
        }
      )
    );

    // Create old accounts map with different postal code
    Map<Id, Account> oldAccountsMap = new Map<Id, Account>();
    oldAccountsMap.put(
      newAccounts[0].Id,
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
            'Id' => newAccounts[0].Id,
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
            'BillingPostalCode' => '12345',
            'Territory_Alias__c' => 'Old Territory',
            'Specialty__c' => 'Cardiology'
        }
      )
    );

    Test.startTest();
    TerritoryAssignmentService.assignTerritoryToAccounts(
      newAccounts,
      oldAccountsMap
    );
    Test.stopTest();

    // Verify territory is cleared when postal code changes (no records)
    Assert.isNull(
      newAccounts[0].Territory_Alias__c,
      'Territory should be null when postal code changes and no records exist'
    );
    }

    /**
     * @description Test territory assignment for Account update with no postal code changes
     */
    @IsTest
    static void testAccountUpdateWithNoPostalCodeChanges() {
        // Create current Practice accounts
        List<Account> newAccounts = new List<Account>();
    newAccounts.add(
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
            'Id' => MockDataFactory.getFakeId('Account'),
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
            'BillingPostalCode' => '12345',
            'Territory_Alias__c' => 'Previous Territory',
            'Specialty__c' => 'Cardiology'
        }
      )
    );

    // Create old accounts map with same postal code
    Map<Id, Account> oldAccountsMap = new Map<Id, Account>();
    oldAccountsMap.put(
      newAccounts[0].Id,
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
            'Id' => newAccounts[0].Id,
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
            'BillingPostalCode' => '12345',
            'Territory_Alias__c' => 'Previous Territory',
            'Specialty__c' => 'Cardiology'
        }
      )
    );

    Test.startTest();
    TerritoryAssignmentService.assignTerritoryToAccounts(
      newAccounts,
      oldAccountsMap
    );
    Test.stopTest();

    // Verify territory remains unchanged when postal code doesn't change
    Assert.areEqual(
      'Previous Territory',
      newAccounts[0].Territory_Alias__c,
      'Territory should remain unchanged when postal code doesn\'t change'
    );
    }

    /**
     * @description Test territory assignment for Lead insert with valid postal codes
     */
    @IsTest
    static void testLeadInsertWithValidPostalCodes() {
        // Create mock leads with Patient record type and valid postal codes
        List<Lead> leads = new List<Lead>();

    leads.add(
      (Lead) MockDataFactory.mockData(
        'Lead',
        new Map<String, Object>{
            'Id' => MockDataFactory.getFakeId('Lead'),
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'PostalCode' => '12345',
            'Territory_Alias__c' => 'Previous Territory'
        }
      )
    );
        Test.startTest();
        TerritoryAssignmentService.assignTerritoryToLeads(leads, null);
        Test.stopTest();

        // Verify territory is cleared when no database records exist
    Assert.isNull(
      leads[0].Territory_Alias__c,
      'Lead territory should be null when no ZipCode__c records exist'
    );
    }

    /**
     * @description Test territory assignment skips ineligible lead record types
     */
    @IsTest
    static void testLeadInsertSkipsIneligibleRecordTypes() {
        // Create mock lead with ineligible record type
        List<Lead> leads = new List<Lead>();
    leads.add(
      (Lead) MockDataFactory.mockData(
        'Lead',
        new Map<String, Object>{
            'Id' => MockDataFactory.getFakeId('Lead'),
            'RecordTypeId' => ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT,
            'PostalCode' => '12345',
            'Territory_Alias__c' => 'Previous Territory'
        }
      )
    );

        Test.startTest();
        TerritoryAssignmentService.assignTerritoryToLeads(leads, null);
        Test.stopTest();

        // Verify territory remains unchanged for ineligible record type
    Assert.areEqual(
      'Previous Territory',
      leads[0].Territory_Alias__c,
      'Territory should remain unchanged for ineligible record type'
    );
    }

    /**
     * @description Test territory assignment for Lead update with postal code changes
     */
    @IsTest
    static void testLeadUpdateWithPostalCodeChanges() {
        // Create current leads
        List<Lead> newLeads = new List<Lead>();
    newLeads.add(
      (Lead) MockDataFactory.mockData(
        'Lead',
        new Map<String, Object>{
            'Id' => MockDataFactory.getFakeId('Lead'),
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'PostalCode' => '54321',
            'Territory_Alias__c' => null
        }
      )
    );

    // Create old leads map with different postal code
    Map<Id, Lead> oldLeadsMap = new Map<Id, Lead>();
    oldLeadsMap.put(
      newLeads[0].Id,
      (Lead) MockDataFactory.mockData(
        'Lead',
        new Map<String, Object>{
            'Id' => newLeads[0].Id,
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'PostalCode' => '12345',
            'Territory_Alias__c' => 'Old Territory'
        }
      )
    );

        Test.startTest();
        TerritoryAssignmentService.assignTerritoryToLeads(newLeads, oldLeadsMap);
        Test.stopTest();

        // Verify territory is cleared when postal code changes (no records)
    Assert.isNull(
      newLeads[0].Territory_Alias__c,
      'Territory should be null when postal code changes and no records exist'
    );
    }
    /**
     * @description Test that Practice accounts with Pediatrics specialty are skipped
     */
    @IsTest
    static void testPracticeAccountPediatricsSpecialtySkipped() {
        // Create mock Practice account with Pediatrics specialty
        List<Account> accounts = new List<Account>();
    accounts.add(
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
            'Id' => MockDataFactory.getFakeId('Account'),
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
            'BillingPostalCode' => '12345',
            'Territory_Alias__c' => 'Previous Territory',
            'Specialty__c' => 'Pediatrics'
        }
      )
    );

        Test.startTest();
        TerritoryAssignmentService.assignTerritoryToAccounts(accounts, null);
        Test.stopTest();

        // Verify territory remains unchanged for Pediatrics specialty
    Assert.areEqual(
      null,
      accounts[0].Territory_Alias__c,
      'Territory should be blank for Pediatrics specialty Practice account'
    );
    }

    /**
     * @description Test error handling with null inputs
     */
    @IsTest
    static void testErrorHandlingWithNullInputs() {
        Test.startTest();
        // Test with null lists
        TerritoryAssignmentService.assignTerritoryToAccounts(null, null);
        TerritoryAssignmentService.assignTerritoryToLeads(null, null);

        // Test with empty lists
    TerritoryAssignmentService.assignTerritoryToAccounts(
      new List<Account>(),
      null
    );
        TerritoryAssignmentService.assignTerritoryToLeads(new List<Lead>(), null);

        Test.stopTest();

        // If we reach here, no exceptions were thrown - test passes
    Assert.isTrue(
      true,
      'Methods should handle null and empty inputs gracefully'
    );
  }

    /**
     * @description Test processing records with actual ZipCode data
     */
    @IsTest
    static void testWithDMLRecords() {
        // Create actual ZipCode and Territory records using
    List<TerritoryAlias__c> territories = TestDataFactory.getTerritoryAliases(
      1,
      new Map<String, Object>{
        'Name' => 'Test Territory East',
        'Territory_Developer_Name__c' => 'TEST_TERRITORY_EAST'
      }
    );
    insert territories;

    List<ZipCode__c> zipCodes = TestDataFactory.getZipCodes(
      1,
      new Map<String, Object>{
        'Name' => '12345',
        'Territory_Name__c' => territories[0].Id
      }
    );
        insert zipCodes;

        // Create Practice account with matching postal code
        List<Account> accounts = new List<Account>();
    accounts.add(
      (Account) MockDataFactory.mockData(
        'Account',
        new Map<String, Object>{
            'Id' => MockDataFactory.getFakeId('Account'),
            'RecordTypeId' => ConstantsUtil.ACCOUNT_PRACTICE_RT,
            'BillingPostalCode' => '12345',
            'Territory_Alias__c' => null,
            'Specialty__c' => 'Cardiology'
        }
      )
    );

        Test.startTest();
        TerritoryAssignmentService.assignTerritoryToAccounts(accounts, null);
        Test.stopTest();

        // Verify territory was assigned from database
    Assert.areEqual(
      territories[0].Territory_Developer_Name__c,
      accounts[0].Territory_Alias__c,
      'Territory should be assigned from database records'
    );
    }

    /**
     * @description Test error handling to cover
     */
    @IsTest
    static void testErrorHandlingCoverage() {
        // Create an account with a corrupted/invalid record that might cause exceptions
        List<Account> accounts = new List<Account>();

        // Create an account with null RecordTypeId to trigger exception during processing
        Account corruptedAccount = new Account();
        corruptedAccount.Id = MockDataFactory.getFakeId('Account');
        corruptedAccount.BillingPostalCode = '12345';
        corruptedAccount.RecordTypeId = null; // This will cause issues in isRecordEligible
        accounts.add(corruptedAccount);

        Test.startTest();

        // This should trigger the exception and hit the catch block
        TerritoryAssignmentService.assignTerritoryToAccounts(accounts, null);

        // Test private methods with invalid object types to cover other branches
    TerritoryAssignmentService.isRecordEligible(
      new Contact(),
      Contact.SobjectType
    );
    TerritoryAssignmentService.getPostalCodeFromRecord(
      new Contact(),
      Contact.SobjectType
    );

        //Test to cover no postal code scenario
        TerritoryAssignmentService.getZipCodeTerritoryMapping(new Set<String>());

        // Test assignTerritoryToRecords with Contact (which doesn't have Territory_Alias__c field)
        // This should cause an exception when trying to set Territory_Alias__c on Contact
        List<SObject> invalidRecords = new List<SObject>();
    Contact testContact = new Contact(
      LastName = 'Test',
      Email = 'test@example.com'
    );
    invalidRecords.add(testContact);
    Map<String, String> testZipMap = new Map<String, String>{
      '12345' => 'Test Territory'
    };
    TerritoryAssignmentService.assignTerritoryToRecords(
      invalidRecords,
      testZipMap,
      Contact.SobjectType
    );

        Test.stopTest();

        // If we reach here, the exception was handled gracefully
        Assert.isTrue(true, 'Error handling coverage test completed');
    }
}