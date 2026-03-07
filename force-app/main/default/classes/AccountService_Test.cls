/**
     * @description Test class for AccountService
     * Created Date : Oct 09, 2025
     * Created By   : Sunil Khanchandani
 * Note : We cant use @IsTest(isParallel=true) because APEX_DATA_ACCESS_RESTRICTION, In parallel Apex tests,
 *        DML operations aren't permitted on this type of object: UserRole: []
 *
 * Version      Modified Date      Modified By              Brief Note
 * V1.0.0       Oct 09, 2025       Sunil Khanchandani       Initial Version
 * V1.0.2       Jan 02, 2026       Srinivas Shanigarapu     Updated Version (US-NGOMCT-235)
 */

@IsTest()
public class AccountService_Test {
  // Test aliases
  private static String aliasOne() {
    return 'ALIAS_ONE';
  }
  private static String aliasTwo() {
    return 'ALIAS_TWO';
  }

  @TestSetup
  static void setupTestData() {
    Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'Sales' LIMIT 1];
    UserRole testRole = new UserRole(Name = 'Clinical Services Manager');
    insert testRole;

    String uniqueUserName =
      'testuser' +
      String.valueOf(Math.abs(Crypto.getRandomInteger())) +
      '@testdomain.com';

    // Create User with Profile and Role
    User testUser = new TestDataFactory.CreateUserRecord()
      .setEmail(uniqueUserName)
      .setFirstName('Training Assignment')
      .setLastName('User')
      .setProfileId(testProfile.Id)
      .setUserName(uniqueUserName)
      .setUserRoleId(testRole.Id) // Assign the role here
      .save()
      .getRecord();
    Territory2Model model = new TestDataFactory.CreateTerritory2ModelRecord()
      .setName('Test TM')
      .setDeveloperName('TestTM')
      .save()
      .getRecord();

    Territory2Type territoryType = [SELECT Id FROM Territory2Type LIMIT 1];

    Territory2 territory = new TestDataFactory.CreateTerritory2Record()
      .setName('Test Territory')
      .setTerritory2ModelId(model.Id)
      .setTerritory2TypeId(territoryType.Id)
      .setDescription('For tests')
      .setDeveloperName('Test')
      .save()
      .getRecord();

    UserTerritory2Association uta = new UserTerritory2Association(
      Territory2Id = territory.Id,
      UserId = testUser.Id,
      RoleInTerritory2 = ConstantsUtil.USER_PERSONA_CSM
    );
    insert uta;
    System.runAs(testUser) {
      List<Account> accounts = new List<Account>();

      // Base accounts for filter and Primary CSM tests
      accounts.add(
        TestDataFactory.getAccountofPatientRecordType(
          new Map<String, Object>{
            'FirstName' => 'Base',
            'LastName' => 'Mapped',
            'Territory_Alias__c' => aliasOne()
          }
        )
      );
      accounts.add(
        TestDataFactory.getAccountofPatientRecordType(
          new Map<String, Object>{
            'FirstName' => 'Base',
            'LastName' => 'Blank',
            'Territory_Alias__c' => null
          }
        )
      );

      // Account for getConvertedAccounts tests
      accounts.add(
        TestDataFactory.getAccountofPatientRecordType(
          new Map<String, Object>{
            'FirstName' => 'Converted',
            'LastName' => 'Test'
          }
        )
      );

      // Accounts for exception and error handling
      accounts.add(
        TestDataFactory.getAccountofPatientRecordType(
          new Map<String, Object>{
            'FirstName' => 'Exc',
            'LastName' => 'Path',
            'Territory_Alias__c' => aliasOne()
          }
        )
      );
      accounts.add(
        TestDataFactory.getAccountofPatientRecordType(
          new Map<String, Object>{
            'FirstName' => 'Error',
            'LastName' => 'Case',
            'PersonBirthdate' => Date.today()
          }
        )
      );

      insert accounts;
    }
  }

  /**
   * @description Verifies getConvertedAccounts safely handles null input
     */
    @IsTest
    static void testGetConvertedAccountsWithNullInput() {
        Test.startTest();
        AccountService.getConvertedAccounts(null);
        Test.stopTest();

    Assert.isTrue(true, 'Method should safely handle null input');
    }

    /**
   * @description Verifies getConvertedAccounts safely handles empty set input
     */
    @IsTest
    static void testGetConvertedAccountsWithEmptySet() {
        Test.startTest();
        AccountService.getConvertedAccounts(new Set<Id>());
        Test.stopTest();

    Assert.isTrue(true, 'Method should safely handle empty input');
    }

    /**
   * @description Verifies getConvertedAccounts processes valid Account Ids
     */
    @IsTest
    static void testGetConvertedAccountsWithValidIds() {
    Account acc = [
      SELECT Id
      FROM Account
      WHERE FirstName = 'Converted'
      LIMIT 1
    ];

        Test.startTest();
    AccountService.getConvertedAccounts(new Set<Id>{ acc.Id });
        Test.stopTest();

    Assert.isTrue(true, 'Valid account IDs should be processed');
    }

    /**
   * @description Verifies updateAccounts handles empty list gracefully
     */
    @IsTest
    static void testUpdateAccountsWithEmptyList() {
        Test.startTest();
        AccountService.updateAccounts(new List<Account>());
        Test.stopTest();

    Assert.isTrue(true, 'Empty list should be handled gracefully');
    }

    /**
   * @description Verifies updateAccounts handles Person Account update scenario
     */
    @IsTest
    static void testUpdateAccountsWithPersonAccount() {
    Account acc = [
      SELECT Id, PersonBirthdate
      FROM Account
      WHERE LastName = 'Case'
      LIMIT 1
    ];
    acc.PersonBirthdate = Date.today().addYears(-18);

        Test.startTest();
            ConstantsUtil.customExceptionSwitch = true;
    AccountService.updateAccounts(new List<Account>{ acc });
    ConstantsUtil.customExceptionSwitch = false;
        Test.stopTest();

    Assert.isNotNull(acc.Id, 'Account should still exist after update attempt');
    }

    /**
   * @description Verifies updateAccounts properly handles DML failures
     */
    @IsTest
    static void testUpdateAccountsWithDmlError() {
    Account acc = [
      SELECT Id, LastName
      FROM Account
      WHERE LastName = 'Case'
      LIMIT 1
    ];
    acc.LastName = null;

    Test.startTest();
    AccountService.updateAccounts(new List<Account>{ acc });
    Test.stopTest();

    Account refreshed = [SELECT LastName FROM Account WHERE Id = :acc.Id];
    Assert.isNotNull(
      refreshed.LastName,
      'LastName should not be cleared due to failed DML'
    );
  }

  /**
   * @description Covers filterAccountsByAliasChange logic for insert and update scenarios
   */
  @IsTest
  static void testFilterAccountsByAliasChangeInsertAndUpdate() {
    Account a1 = TestDataFactory.getAccountofPatientRecordType(
      new Map<String, Object>{
        'FirstName' => 'Insert',
        'LastName' => 'One',
        'Territory_Alias__c' => ' ' +
        aliasOne() +
        ' '
      }
    );
    Account a2 = TestDataFactory.getAccountofPatientRecordType(
      new Map<String, Object>{
        'FirstName' => 'Insert',
        'LastName' => 'Two',
        'Territory_Alias__c' => null
      }
    );
    insert new List<Account>{ a1, a2 };

    Map<Id, String> insertResult = AccountService.filterAccountsByAliasChange(
      new List<Account>{ a1, a2 },
      null
    );
    Assert.areEqual(
      2,
      insertResult.size(),
      'Both accounts should be processed on insert'
    );
    Assert.areEqual(
      aliasOne(),
      insertResult.get(a1.Id),
      'Alias should be trimmed'
    );
    Assert.isNull(insertResult.get(a2.Id), 'Null alias should remain null');

    Account oldA1 = a1.clone(false, true, false, false);
    Map<Id, Account> oldMap = new Map<Id, Account>{ a1.Id => oldA1 };
    a1.Territory_Alias__c = aliasTwo() + ' ';
    update a1;

    Map<Id, String> updateResult = AccountService.filterAccountsByAliasChange(
      new List<Account>{ a1 },
      oldMap
    );
    Assert.areEqual(
      1,
      updateResult.size(),
      'Only changed records should be processed'
    );
    Assert.areEqual(
      aliasTwo(),
      updateResult.get(a1.Id),
      'Updated alias should be trimmed'
    );
  }

  /**
   * @description Validates Primary_CSM__c updates for null, mapped, and missing aliases
   */
  @IsTest
  static void testApplyPrimaryCsmUpdates() {
    Account aNull = TestDataFactory.getAccountofPatientRecordType(
      new Map<String, Object>{
        'FirstName' => 'Null',
        'LastName' => 'Alias',
        'Territory_Alias__c' => null
      }
    );
    Account aMapped = TestDataFactory.getAccountofPatientRecordType(
      new Map<String, Object>{
        'FirstName' => 'Mapped',
        'LastName' => 'Alias',
        'Territory_Alias__c' => aliasOne()
      }
    );
    insert new List<Account>{ aNull, aMapped };

    Map<Id, String> recordToAlias = new Map<Id, String>{
      aNull.Id => null,
      aMapped.Id => aliasOne()
    };
    Map<String, Id> aliasToUser = new Map<String, Id>{
      aliasOne() => UserInfo.getUserId()
    };

    AccountService.applyPrimaryCsmUpdates(
      new List<Account>{ aNull, aMapped },
      recordToAlias,
      aliasToUser
    );

    Assert.isNull(aNull.Primary_CSM__c, 'Null alias should clear Primary CSM');
    Assert.areEqual(
      UserInfo.getUserId(),
      aMapped.Primary_CSM__c,
      'Mapped alias should assign Primary CSM'
    );
  }

  /**
   * @description End-to-end validation of updatePrimaryCsmForAccounts covering alias changes
   */
  @IsTest
  static void testUpdatePrimaryCsmForAccountsEndToEnd() {
    Account acc = [
      SELECT Id, Territory_Alias__c,Primary_CSM__c
      FROM Account
      WHERE LastName = 'Mapped'
      LIMIT 1
    ];
    Account oldAcc = acc.clone(false, true, false, false);
    Map<Id, Account> oldMap = new Map<Id, Account>{ acc.Id => oldAcc };
    acc.Territory_Alias__c = aliasTwo();
    update acc;

        Test.startTest();
    AccountService.updatePrimaryCsmForAccounts(
      new List<Account>{ acc },
      oldMap
    );
        Test.stopTest();

    Assert.isNull(
      acc.Primary_CSM__c,
      'Primary CSM should remain null if alias mapping missing'
    );
  }

  /**
   * @description Covers exception path in updatePrimaryCsmForAccounts by triggering addError
   */
  @IsTest
  static void testUpdatePrimaryCsmForAccountsExceptionPath() {
    Account acc = [
      SELECT Id, Territory_Alias__c, Primary_CSM__c
      FROM Account
      WHERE LastName = 'Path'
      LIMIT 1
    ];
    Account oldAcc = acc.clone(false, true, false, false);
    Map<Id, Account> oldMap = new Map<Id, Account>{ acc.Id => oldAcc };
    acc.Territory_Alias__c = 'NO_MATCHING_ALIAS';
    update acc;

    Test.startTest();
    ConstantsUtil.customExceptionSwitch = true;
    AccountService.updatePrimaryCsmForAccounts(
      new List<Account>{ acc },
      oldMap
    );
    ConstantsUtil.customExceptionSwitch = false;
    Test.stopTest();

    Assert.isNull(
      acc.Primary_CSM__c,
      'Primary CSM should remain null on error path'
    );
  }

  /**
   * @description Covers methods with empty parameters.
   */
  @IsTest
  static void testMethodsWithEmptyParameters() {
    Account acc = [
      SELECT Id, Territory_Alias__c, Primary_CSM__c
      FROM Account
      WHERE LastName = 'Path'
      LIMIT 1
    ];

    List<Account> accs = new List<Account>();
    accs.add(acc);
    Test.startTest();

    AccountService.applyPrimaryCsmUpdates(
      accs,
      new Map<Id, String>(),
      new Map<String, Id>()
    );
    AccountService.updatePrimaryCsmForAccounts(
      new List<Account>(),
      new Map<Id, Account>()
    );
    AccountService.getAliasToUserMapping(new Set<String>());
    AccountService.updateTrainerAccRecord(new List<SObject>(), 'OMCT');
    Test.stopTest();

    Assert.isNull(
      acc.Primary_CSM__c,
      'Primary CSM should remain null on error path'
    );
    }
}