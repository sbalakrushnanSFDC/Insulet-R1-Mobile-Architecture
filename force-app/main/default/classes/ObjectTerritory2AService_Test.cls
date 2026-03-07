/**
 * @author      : Charchit Nirayanwal
 * @created Date: 13 NOV 2025
 * @description : Test Class for ObjectTerritory2AService.
 * 
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       13 NOV 2025         Charchit Nirayanwal     Initial Version (US-1223)
 * V1.0.1       6  JAN 2026         Srinivas Shanigarapu    Modified Version (NGOMCT-235)
 *
 */

@IsTest
private class ObjectTerritory2AService_Test {
  private static final String TERR_01_DEV = 'TestTerritory01';
  private static final String TERR_02_DEV = 'TestTerritory02';
  private static final String TERR_01_NAME = 'Test Territory 01';
  private static final String TERR_02_NAME = 'Test Territory 02';

  /**
   * @description Create Data for testing
   */
  @TestSetup
  public static void createData() {
    Territory2Model model = new TestDataFactory.CreateTerritory2ModelRecord()
      .setName('Test TM')
      .setDeveloperName('TestTM')
      .save()
      .getRecord();

    Territory2Type territoryType = [SELECT Id FROM Territory2Type LIMIT 1];
    // Build a hierarchy so parent is excluded and children are "leaf"
    Territory2 parentT2 = new TestDataFactory.CreateTerritory2Record()
      .setName('Parent Territory')
      .setTerritory2ModelId(model.Id)
      .setTerritory2TypeId(territoryType.Id)
      .setDescription('Parent')
      .setDeveloperName('ParentTerritory')
      .save()
      .getRecord();

    new TestDataFactory.CreateTerritory2Record()
      .setName(TERR_01_NAME)
      .setTerritory2ModelId(model.Id)
      .setParentTerritory2Id(parentT2.Id)
      .setTerritory2TypeId(territoryType.Id)
      .setDescription('Child A')
      .setDeveloperName(TERR_01_DEV)
      .save()
      .getRecord();

    new TestDataFactory.CreateTerritory2Record()
      .setName(TERR_02_NAME)
      .setTerritory2ModelId(model.Id)
      .setParentTerritory2Id(parentT2.Id)
      .setTerritory2TypeId(territoryType.Id)
      .setDescription('Child B')
      .setDeveloperName(TERR_02_DEV)
      .save()
      .getRecord();

    Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'Sales' LIMIT 1];
    String uniqueUserName = 'testuser' + '@testdomain.com';
    User testUser = new TestDataFactory.CreateUserRecord()
      .setEmail(uniqueUserName)
      .setFirstName('Training Assignment')
      .setLastName('User')
      .setProfileId(testProfile.Id)
      .setUserName(uniqueUserName)
      .save()
      .getRecord();

    PermissionSet ps = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Inside_Sales_Core_Access'
    ];
    insert new PermissionSetAssignment(
      AssigneeId = testUser.Id,
      PermissionSetId = ps.Id
    );
    System.runAs(testUser) {
      List<TerritoryAlias__c> territoryAliasList = new List<TerritoryAlias__c>();
      territoryAliasList.add(
        new TerritoryAlias__c(
          Name = TERR_01_NAME,
          Territory_Developer_Name__c = TERR_01_DEV
        )
      );
      territoryAliasList.add(
        new TerritoryAlias__c(
          Name = TERR_02_NAME,
          Territory_Developer_Name__c = TERR_02_DEV
        )
      );
      insert territoryAliasList;

      List<ZipCode__c> zipCodes = new List<ZipCode__c>();
      zipCodes.add(
        new ZipCode__c(
          Name = '12345',
          Territory_Name__c = territoryAliasList[0].Id
        )
      );

      zipCodes.add(
        new ZipCode__c(
          Name = '67890',
          Territory_Name__c = territoryAliasList[1].Id
        )
      );
      insert zipCodes;

      // insert Lead
      List<Lead> leads = new List<Lead>();
      leads.add(
        new Lead(
          RecordTypeId = ConstantsUtil.LEAD_PATIENT_RT,
          PostalCode = '12345',
          LastName = 'Test1'
        )
      );

      insert leads;
    }
  }
  /**
   * @description Test method for creating OT2A records on Lead insert
   */
  @IsTest
  static void testUpdatingLeadPostalCode() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Profile.Name = 'Sales' AND IsActive = TRUE
      LIMIT 1
    ];
    // Create mock leads with Patient record type and valid postal codes
    List<Lead> leads = [SELECT id, Territory_Alias__c FROM lead LIMIT 1];
    list<ObjectTerritory2Association> ot2aList = [
      SELECT id, Territory2Id
      FROM ObjectTerritory2Association
      WHERE ObjectId = :leads[0].Id
    ];
    Assert.areEqual(
      'TestTerritory01',
      leads[0].Territory_Alias__c,
      'Territory should be set to TestTerritory01'
    );
    Assert.areEqual(
      1,
      ot2aList.size(),
      'ObjectTerritory2Association should be created for the lead'
    );
    leads[0].PostalCode = '67890';
    Test.startTest();

    System.runAs(testUser) {
      Database.update(testUser, AccessLevel.SYSTEM_MODE);
    }
    ot2aList = [
      SELECT id, Territory2Id
      FROM ObjectTerritory2Association
      WHERE ObjectId = :leads[0].Id
    ];
    leads = [SELECT id, Territory_Alias__c FROM lead LIMIT 1];
    Assert.areEqual(
      1,
      ot2aList.size(),
      'New ObjectTerritory2Association should be created for the lead'
    );
    Assert.isTrue(
      leads[0].Territory_Alias__c != null,
      'Territory alias should not be null'
    );
    Test.stopTest();
  }

  @IsTest
  static void testUpdatingLeadTerritory() {
    List<Lead> leads = [SELECT id, Territory_Alias__c FROM lead LIMIT 1];
    Leads[0].Territory_Alias__c = null;
    list<ObjectTerritory2Association> ot2aList = [
      SELECT id, Territory2Id
      FROM ObjectTerritory2Association
      WHERE ObjectId = :leads[0].Id
    ];
    Assert.areEqual(
      1,
      ot2aList.size(),
      'ObjectTerritory2Association should be created for the lead'
    );
    Test.startTest();
    Database.update(leads, AccessLevel.SYSTEM_MODE);
    Test.stopTest();
    ot2aList = [
      SELECT id, Territory2Id
      FROM ObjectTerritory2Association
      WHERE ObjectId = :leads[0].Id
    ];
    leads = [SELECT id, Territory_Alias__c FROM lead LIMIT 1];
    Assert.areEqual(
      null,
      leads[0].Territory_Alias__c,
      'Territory should be set to null'
    );
    Assert.areEqual(
      0,
      ot2aList.size(),
      'ObjectTerritory2Association should be deleted for the lead'
    );
  }
  /**
   * @description Test method for passing wrong object type
   */
  @IsTest
  static void passingWrongObjecttType() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Profile.Name = 'Sales' AND IsActive = TRUE
      LIMIT 1
    ];
    List<Lead> leads = [SELECT id, Territory_Alias__c FROM lead LIMIT 1];
    list<ObjectTerritory2Association> ot2aList = [
      SELECT id, Territory2Id
      FROM ObjectTerritory2Association
      WHERE ObjectId = :leads[0].Id
    ];
    Assert.areEqual(
      1,
      ot2aList.size(),
      'ObjectTerritory2Association should be created for the lead'
    );

    Test.startTest();
    System.runAs(testUser) {
      ObjectTerritory2AService.createOT2ARecords(
        (list<sObject>) leads,
        new Map<Id, sObject>(),
        Contact.sObjectType
      );
    }
    Test.stopTest();
    ot2aList = [
      SELECT id, Territory2Id
      FROM ObjectTerritory2Association
      WHERE ObjectId = :leads[0].Id
    ];
    Assert.areEqual(
      ot2aList.size(),
      1,
      'ObjectTerritory2Association should be created for the lead'
    );
  }

  /**
   * @description Tests getLowestLevelTerritories() returns only leaf territories and honors searchTerm
   */
  @IsTest
  static void testGetLowestLevelTerritoriesFiltersToLeavesAndSearches() {
    Test.startTest();
    List<Map<String, String>> resultsAll = ObjectTerritory2AService.getLowestLevelTerritories(
      null
    );
    Assert.isNotNull(resultsAll, 'Results should not be null');
    Assert.isTrue(
      resultsAll.size() >= 2,
      'Should return at least two leaf territories'
    );

    Set<String> names = new Set<String>();
    for (Map<String, String> row : resultsAll) {
      Assert.isNotNull(
        row.get(ObjectTerritory2AService.VALUE),
        'Each row must include value (Id)'
      );
      Assert.isNotNull(
        row.get(ObjectTerritory2AService.LABEL),
        'Each row must include label (Name)'
      );
      names.add(row.get(ObjectTerritory2AService.LABEL));
    }
    Test.stopTest();
  }

  /**
   * @description Tests createAssociations() inserts only new associations, skips existing, and handles guards
   */
  @IsTest
  static void testCreateAssociationsInsertsOnlyNewAndSkipsExisting() {
    // Arrange: Retrieve seeded lead and territory ids
    Lead l = [SELECT Id FROM Lead LIMIT 1];
    Assert.isNotNull(l, 'Lead must exist from @TestSetup');

    List<Territory2> t2s = [
      SELECT Id, DeveloperName
      FROM Territory2
      WHERE DeveloperName IN :new Set<String>{ TERR_01_DEV, TERR_02_DEV }
      ORDER BY DeveloperName
    ];
    Assert.areEqual(
      2,
      t2s.size(),
      'Expected two child territories for association'
    );

    Integer beforeCount = [
      SELECT COUNT()
      FROM ObjectTerritory2Association
      WHERE ObjectId = :l.Id
    ];

    List<Id> targetIds = new List<Id>{ t2s[0].Id, t2s[1].Id };
    Test.startTest();
    ObjectTerritory2AService.createAssociations(l.Id, targetIds);

    Integer afterCount = [
      SELECT COUNT()
      FROM ObjectTerritory2Association
      WHERE ObjectId = :l.Id
    ];
    Assert.areEqual(
      beforeCount + 1,
      afterCount,
      'Should insert only non-duplicate association'
    );
    ObjectTerritory2AService.createAssociations(null, targetIds);
    ObjectTerritory2AService.createAssociations(l.Id, null);
    ObjectTerritory2AService.createAssociations(l.Id, new List<Id>());
    Test.stopTest();

    Integer finalCount = [
      SELECT COUNT()
      FROM ObjectTerritory2Association
      WHERE ObjectId = :l.Id
    ];
    Assert.areEqual(
      afterCount,
      finalCount,
      'No additional inserts expected for guarded calls'
    );
  }

  /**
   * @description Tests createAssociations() with Exception Data
   */
  @IsTest
  static void testCreateAssociationsWithExceptionData() {
    try {
      Lead l = [SELECT Id FROM Lead LIMIT 1];
      List<Territory2> t2s = [
        SELECT Id, DeveloperName
        FROM Territory2
        WHERE DeveloperName IN :new Set<String>{ TERR_01_DEV, TERR_02_DEV }
        ORDER BY DeveloperName
      ];

      List<Id> targetIds = new List<Id>{ t2s[0].Id, t2s[1].Id };
      Test.startTest();
      ConstantsUtil.customExceptionSwitch = true;
      ObjectTerritory2AService.createAssociations(l.Id, targetIds);
      ConstantsUtil.customExceptionSwitch = false;

      Test.stopTest();
    } catch (Exception ex) {
      Assert.isTrue(
        ex.getMessage() != null,
        'Exception messsage should not be null'
      );
    }
  }

  /**
   * @description Tests getLowestLevelTerritories() with Exception data
   */
  @IsTest
  static void testGetLowestLevelTerritoriesFiltersToLeavesAndSearchesWithExceptionData() {
    List<Map<String, String>> resultsAll = new List<Map<String, String>>();
    try {
      Test.startTest();
      ConstantsUtil.customExceptionSwitch = true;
      resultsAll = ObjectTerritory2AService.getLowestLevelTerritories(null);
      ConstantsUtil.customExceptionSwitch = false;
      Test.stopTest();
    } catch (Exception ex) {
      Assert.isTrue(resultsAll.size() == 0, 'Should return zero territories');
    }
  }

  /**
   * @description Test method for passing wrong object type
   */
  @IsTest
  static void passingNullData() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Profile.Name = 'Sales' AND IsActive = TRUE
      LIMIT 1
    ];
    List<Lead> leads = [SELECT id, Territory_Alias__c FROM lead LIMIT 1];
    list<ObjectTerritory2Association> ot2aList = [
      SELECT id, Territory2Id
      FROM ObjectTerritory2Association
      WHERE ObjectId = :leads[0].Id
    ];
    Assert.areEqual(
      ot2aList.size(),
      1,
      'ObjectTerritory2Association should be created for the lead'
    );
    leads[0].Id = null;

    Test.startTest();
    System.runAs(testUser) {
      ObjectTerritory2AService.createOT2ARecords(
        (list<sObject>) leads,
        new Map<Id, sObject>(),
        Lead.sObjectType
      );
    }
    Test.stopTest();
  }
}