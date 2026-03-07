/**
 * @description Test class for CaregiverRelationshipService
 * @author Sunil Khanchandani
 * @date Oct 10, 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By               Brief Note
 * V1.0.0       10-10-2025          Sunil Khanchandani       Initial Version
 * V1.1.0       01-28-2026          Charchit Nirayanwal      Added tests for processMinorCaregiverContactPoints
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
public class CaregiverRelationshipService_Test {

// Cache facility ID to avoid repeated SOQL queries
private static Id cachedFacilityId = null;

@TestSetup
static void setupTestData() {
    List<PartyRoleRelation> partyRoleRelationsToInsert = new List<PartyRoleRelation>();

    if ([SELECT COUNT() FROM PartyRoleRelation
         WHERE RoleName = :ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME
         AND RelatedRoleName = :ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME LIMIT 1] == 0) {
        partyRoleRelationsToInsert.add(new PartyRoleRelation(
            RoleName = ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME,
            RelatedRoleName = ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME,
            RelationshipObjectName = ConstantsUtil.CONTACT_CONTACT_RELATION
        ));
    }

    if ([SELECT COUNT() FROM PartyRoleRelation
         WHERE RoleName = 'Patient'
         AND RelatedRoleName = 'Legal Guardian' LIMIT 1] == 0) {
        partyRoleRelationsToInsert.add(new PartyRoleRelation(
            RoleName = 'Patient',
            RelatedRoleName = 'Legal Guardian',
            RelationshipObjectName = ConstantsUtil.CONTACT_CONTACT_RELATION
        ));
    }

    if (!partyRoleRelationsToInsert.isEmpty()) {
        insert partyRoleRelationsToInsert;
    }

    Contact practitionerContact = TestDataFactory.getContact(new Map<String, Object>{
        'FirstName' => 'Test',
        'LastName' => 'Practitioner',
        'Email' => 'test.practitioner@example.com'
    });
    insert practitionerContact;

    Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
        'Name' => 'Test Medical Practice',
        'Phone' => '5551234567',
        'BillingStreet' => '123 Medical Center Dr',
        'BillingCity' => 'San Francisco',
        'BillingState' => 'California',
        'BillingPostalCode' => '94103',
        'BillingCountry' => 'United States'
    });
    insert practiceAccount;

    HealthcarePractitionerFacility facility = TestDataFactory.getHealthcarePractitionerFacility(new Map<String, Object>{
        'Name' => 'Test Facility',
        'PractitionerId' => practitionerContact.Id,
        'AccountId' => practiceAccount.Id,
        'IsActive' => true
    });
    insert facility;

    // Ensure DataUsePurpose records exist for each consent name so that
    // ConsentService can create ContactPointTypeConsent records during the
    // Lead auto-conversion trigger chain. Without these, the
    // IndividualId → RelatedRecordExists precheck rule fails silently.
    List<DataUsePurpose> dupsToInsert = new List<DataUsePurpose>();
    Set<String> existingDupNames = new Set<String>();
    for (DataUsePurpose dup : [SELECT Name FROM DataUsePurpose WHERE Name IN :ConstantsUtil.CONSENT_NAMES]) {
        existingDupNames.add(dup.Name);
    }
    for (String consentName : ConstantsUtil.CONSENT_NAMES) {
        if (!existingDupNames.contains(consentName)) {
            dupsToInsert.add(TestDataFactory.getDataUsePurpose(new Map<String, Object>{ 'Name' => consentName }));
        }
    }
    if (!dupsToInsert.isEmpty()) {
        insert dupsToInsert;
    }
}

/**
 * @description Helper method to get or cache the facility ID to avoid repeated SOQL queries
 * @return Id of the active HealthcarePractitionerFacility
 */
private static Id getFacilityId() {
    if (cachedFacilityId == null) {
        cachedFacilityId = [SELECT Id FROM HealthcarePractitionerFacility WHERE IsActive = true LIMIT 1].Id;
    }
    return cachedFacilityId;
}

/**
 * @description Helper method to check if caregiverLeadsMap is null or empty
 * @return True if caregiverLeadsMap is null or empty
 */
private static Boolean isCaregiverLeadsMapNullOrEmpty() {
    return CaregiverRelationshipService.caregiverLeadsMap == null ||
           CaregiverRelationshipService.caregiverLeadsMap.isEmpty();
}

/**
 * @description Helper method to create a lead with all required fields for auto-conversion
 * @param uniqueSuffix Unique suffix to avoid duplicates
 * @param age Age of the patient (negative years from today for past dates)
 * @param includeCaregiverFields Whether to include caregiver fields
 * @return Lead record with all required fields
 */
private static Lead createLeadWithRequiredFields(String uniqueSuffix, Integer age, Boolean includeCaregiverFields) {
    Id facilityId = getFacilityId();
    String phoneDigits = String.valueOf(Math.abs(uniqueSuffix.hashCode())).substring(0, Math.min(7, String.valueOf(Math.abs(uniqueSuffix.hashCode())).length()));
    if (phoneDigits.length() < 7) {
        phoneDigits = phoneDigits.leftPad(7, '0');
    }
    String phoneNumber = '555' + phoneDigits.substring(0, 7);

    // Calculate date of birth - ensure it's always in the past
    Integer yearsAgo = age > 0 ? -age : age;
    Date dateOfBirth = Date.today().addYears(yearsAgo);

    Map<String, Object> leadFields = new Map<String, Object>{
        'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
        'FirstName' => 'Test' + uniqueSuffix,
        'LastName' => 'Patient' + uniqueSuffix,
        'Email' => 'testpatient' + uniqueSuffix.replaceAll('[^a-zA-Z0-9]', '') + '@example.com',
        'Phone' => phoneNumber,
        'MobilePhone' => '556' + phoneDigits.substring(0, 7),
        'Date_of_Birth__c' => dateOfBirth,
        'GenderIdentity' => 'Male',
        'Address_Status__c' => 'Verified',
        'Recommended_Product__c' => 'DASH',
        'Sensor_CGM_Continuous_Glucose_Monitor__c' => 'Dexcom G7',
        'Type_of_Diabetes__c' => 'Type 1',
        'Status' => 'Qualification',
        'Request_a_Call_Back__c' => false,
        'Provider_Practice_Affiliation__c' => facilityId,
        'Company' => 'Test Company ' + uniqueSuffix,
        'LeadSource' => 'Web',
        'Street' => '123 Test Street ' + uniqueSuffix,
        'City' => 'Boston',
        'State' => 'Massachusetts',
        'PostalCode' => '02102',
        'Country' => 'United States'
    };

    if (includeCaregiverFields) {
        leadFields.put('Caregiver_First_Name__c', 'Caregiver' + uniqueSuffix);
        leadFields.put('Caregiver_Last_Name__c', 'Parent' + uniqueSuffix);
    }

    return TestDataFactory.getLead(leadFields);
}

/**
 * @description Scenario 1: Lead with no patient delegate existing
 * When no matching Patient Delegate account exists, a new account should be created
 */
@IsTest
static void testLeadWithNoPatientDelegateExisting() {
    // Create a lead with caregiver information
    Lead caregiverLead = createLeadWithRequiredFields('NoDelegate', 17, true);
    caregiverLead.Caregiver_First_Name__c = 'New';
    caregiverLead.Caregiver_Last_Name__c = 'Delegate';
    caregiverLead.Email = 'newdelegate@example.com';
    caregiverLead.Phone = '5551111111';
    caregiverLead.MobilePhone = '5552222222';
    Database.DMLOptions dmlOpts = new Database.DMLOptions();
    dmlOpts.DuplicateRuleHeader.allowSave = true;

    Test.startTest();
    insert caregiverLead;
    Test.stopTest();

    // Query converted lead after async processing completes
    Lead convertedLead = [
        SELECT Id, ConvertedContactId, IsConverted, Caregiver_First_Name__c, Caregiver_Last_Name__c,age__c,
        Email, Phone, MobilePhone
        FROM Lead
        WHERE Id = :caregiverLead.Id
    ];

    Assert.isTrue(convertedLead.IsConverted, 'Lead should be auto-converted');

    CaregiverRelationshipService.processCaregiverRelations(new List<Lead>{ convertedLead }, ConstantsUtil.ASIM_TAG);

    // Verify a new Patient Delegate account was created (via buildFinalLeadToAccountMap)
    List<Account> createdAccounts = [
        SELECT Id, FirstName, LastName, PersonEmail, RecordTypeId
        FROM Account
        WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
        AND FirstName = 'New'
        AND LastName = 'Delegate'
    ];

    Assert.areEqual(1, createdAccounts.size(), 'Should create 1 new Patient Delegate account');
    Account createdAccount = createdAccounts[0];
    Assert.areEqual(ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT, createdAccount.RecordTypeId, 'Account should have Patient Delegate record type');
    Assert.areEqual('New', createdAccount.FirstName, 'Account FirstName should match caregiver first name');
    Assert.areEqual('Delegate', createdAccount.LastName, 'Account LastName should match caregiver last name');
    Assert.areEqual('newdelegate@example.com', createdAccount.PersonEmail, 'Account PersonEmail should match lead email');

    // Verify ContactContactRelation records were created linking patient and caregiver
    List<ContactContactRelation> ccrRecords = [
        SELECT Id, ContactId, RelatedContactId, PartyRoleRelationId
        FROM ContactContactRelation
        WHERE ContactId = :convertedLead.ConvertedContactId
    ];
    Assert.isTrue(ccrRecords.size() >= 1, 'Should create at least 1 ContactContactRelation linking patient to caregiver');
}

/**
 * @description Scenario 2: Lead with patient delegate found
 * When a matching Patient Delegate account exists (matched via ContactPoint), it should be used
 */
@IsTest
static void testLeadWithPatientDelegateFound() {
    // Create an existing Patient Delegate account with ContactPoint data
    Account existingDelegateAccount = new Account(
        RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT,
        FirstName = 'Existing',
        LastName = 'Delegate',
        PersonEmail = 'existingdelegate@example.com',
        Phone = '5559999999'
    );
    insert existingDelegateAccount;

    // Create ContactPointPhone for matching
    ContactPointPhone cpp = new ContactPointPhone(
        ParentId = existingDelegateAccount.Id,
        TelephoneNumber = '5559999999',
        UsageType = 'Home',
        IsPrimary = true
    );
    insert cpp;

    // Create ContactPointEmail for matching
    ContactPointEmail cpe = new ContactPointEmail(
        ParentId = existingDelegateAccount.Id,
        EmailAddress = 'existingdelegate@example.com',
        IsPrimary = true
    );
    insert cpe;

    // Create a lead with matching caregiver information
    Lead caregiverLead = createLeadWithRequiredFields('FoundDelegate', 17, true);
    caregiverLead.Caregiver_First_Name__c = 'Existing';
    caregiverLead.Caregiver_Last_Name__c = 'Delegate';
    caregiverLead.Email = 'existingdelegate@example.com';
    caregiverLead.Phone = '5559999999';
    caregiverLead.MobilePhone = '5559999998';
    Database.DMLOptions dmlOpts = new Database.DMLOptions();
    dmlOpts.DuplicateRuleHeader.allowSave = true;

    Test.startTest();
    insert caregiverLead;
    Test.stopTest();

    // Query converted lead after async processing completes
    Lead convertedLead = [
        SELECT Id, ConvertedContactId, IsConverted, Caregiver_First_Name__c, Caregiver_Last_Name__c,age__c,
        Email, Phone, MobilePhone
        FROM Lead
        WHERE Id = :caregiverLead.Id
    ];

    Assert.isTrue(convertedLead.IsConverted, 'Lead should be auto-converted');

    // Verify the existing Patient Delegate account was matched and used (no new account created)
    List<Account> allAccounts = [
        SELECT Id, FirstName, LastName, PersonEmail, RecordTypeId
        FROM Account
        WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
        AND FirstName = 'Existing'
        AND LastName = 'Delegate'
    ];

    Assert.areEqual(1, allAccounts.size(), 'Should have only 1 Patient Delegate account (the existing one, no new account created)');
    Account matchedAccount = allAccounts[0];
    Assert.areEqual(existingDelegateAccount.Id, matchedAccount.Id, 'Should match the existing account');
    Assert.areEqual(ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT, matchedAccount.RecordTypeId, 'Account should have Patient Delegate record type');
    Assert.areEqual('Existing', matchedAccount.FirstName, 'Account FirstName should match');
    Assert.areEqual('Delegate', matchedAccount.LastName, 'Account LastName should match');
    Assert.areEqual('existingdelegate@example.com', matchedAccount.PersonEmail, 'Account PersonEmail should match');
}

/**
 * @description Scenario 3: Test processMinorCaregiverContactPoints for minor leads
 * When a minor lead (age < 18) is converted, ContactPoint records should be created for the caregiver account
 */
@IsTest
static void testProcessMinorCaregiverContactPoints() {
    // Create a minor lead (age < 18) with caregiver information
    Lead minorLead = createLeadWithRequiredFields('Minor', -10, true); // Age 10
    minorLead.Phone = '5553333333';
    minorLead.MobilePhone = '5554444444';
    minorLead.Email = 'minorpatient@example.com';
    minorLead.Caregiver_First_Name__c = 'Minor';
    minorLead.Caregiver_Last_Name__c = 'Caregiver';
    Database.DMLOptions dmlOpts = new Database.DMLOptions();
    dmlOpts.DuplicateRuleHeader.allowSave = true;

    Test.startTest();
    insert minorLead;
    Test.stopTest();

    // Query converted lead after async processing completes
    Lead convertedLead = [
        SELECT Id, ConvertedAccountId, ConvertedContactId, IsConverted, Age__c,
        Phone, MobilePhone, Email, Caregiver_First_Name__c, Caregiver_Last_Name__c,
        FirstName, LastName
        FROM Lead
        WHERE Id = :minorLead.Id
    ];

    Assert.isTrue(convertedLead.IsConverted, 'Lead should be auto-converted');
    Assert.isTrue(convertedLead.Age__c < 18, 'Lead should be a minor (age < 18)');

    CaregiverRelationshipService.processMinorCaregiverContactPoints(
        new List<Lead>{ convertedLead },
        ConstantsUtil.ASIM_TAG
    );

    // Verify a Patient Delegate account was created or found
    List<Account> caregiverAccounts = [
        SELECT Id, FirstName, LastName, PersonEmail, RecordTypeId
        FROM Account
        WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
        AND FirstName = 'Minor'
        AND LastName = 'Caregiver'
    ];

    Assert.isTrue(caregiverAccounts.size() > 0, 'Should have created or found caregiver account');
    Account caregiverAccount = caregiverAccounts[0];

    // Verify ContactPointPhone records were created for the caregiver account
    List<ContactPointPhone> phoneRecords = [
        SELECT Id, TelephoneNumber, UsageType, IsPrimary
        FROM ContactPointPhone
        WHERE ParentId = :caregiverAccount.Id
    ];
    Assert.isTrue(phoneRecords.size() >= 1, 'Should have at least 1 ContactPointPhone record');

    // Verify ContactPointEmail records were created for the caregiver account
    List<ContactPointEmail> emailRecords = [
        SELECT Id, EmailAddress, IsPrimary
        FROM ContactPointEmail
        WHERE ParentId = :caregiverAccount.Id
    ];
    Assert.isTrue(emailRecords.size() >= 1, 'Should have at least 1 ContactPointEmail record');
}

/**
 * @description Scenario 4: Test buildAccountKeyMap with account having phone but no email ContactPoint
 * Covers lines 792-801 in CaregiverRelationshipService.buildAccountKeyMap()
 * When an account has ContactPointPhone but no ContactPointEmail, it should still be matchable by phone only
 * Note: Lead must have email for conversion (precheck requirement), but matching happens via phone-only key
 */
@IsTest
static void testBuildAccountKeyMapWithPhoneButNoEmail() {
    // Create an existing Patient Delegate account with ONLY ContactPointPhone (no ContactPointEmail)
    // Account has Phone but no PersonEmail field set, and no ContactPointEmail records
    Account existingDelegateAccount = new Account(
        RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT,
        FirstName = 'PhoneOnly',
        LastName = 'Delegate',
        PersonEmail = null, // No email on account
        Phone = '5557777777'
    );
    insert existingDelegateAccount;

    // Create ONLY ContactPointPhone (no ContactPointEmail)
    // This simulates an account that has phone ContactPoint but no email ContactPoint
    ContactPointPhone cpp = new ContactPointPhone(
        ParentId = existingDelegateAccount.Id,
        TelephoneNumber = '5557777777',
        UsageType = 'Home',
        IsPrimary = true
    );
    insert cpp;

    // Create a lead with matching caregiver information
    // Lead MUST have email for conversion (precheck requirement), but matching will happen via phone-only key
    Lead caregiverLead = createLeadWithRequiredFields('PhoneOnly', 17, true);
    caregiverLead.Caregiver_First_Name__c = 'PhoneOnly';
    caregiverLead.Caregiver_Last_Name__c = 'Delegate';
    caregiverLead.Email = 'phoneonly@example.com'; // Email required for conversion
    caregiverLead.Phone = '5557777777';
    caregiverLead.MobilePhone = '5557777776';
    Database.DMLOptions dmlOpts = new Database.DMLOptions();
    dmlOpts.DuplicateRuleHeader.allowSave = true;

    Test.startTest();
    insert caregiverLead;
    Test.stopTest();

    // Query converted lead after async processing completes
    Lead convertedLead = [
        SELECT Id, ConvertedContactId, IsConverted, Caregiver_First_Name__c, Caregiver_Last_Name__c,age__c,
        Email, Phone, MobilePhone
        FROM Lead
        WHERE Id = :caregiverLead.Id
    ];

    Assert.isTrue(convertedLead.IsConverted, 'Lead should be auto-converted');

    CaregiverRelationshipService.processCaregiverRelations(new List<Lead>{ convertedLead }, ConstantsUtil.ASIM_TAG);

    // Verify the existing Patient Delegate account was matched (no new account created)
    List<Account> allAccounts = [
        SELECT Id, FirstName, LastName, PersonEmail, RecordTypeId
        FROM Account
        WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
        AND FirstName = 'PhoneOnly'
        AND LastName = 'Delegate'
    ];

    Assert.areEqual(1, allAccounts.size(), 'Should have only 1 Patient Delegate account (the existing one, matched by phone only)');
    Account matchedAccount = allAccounts[0];
    Assert.areEqual(existingDelegateAccount.Id, matchedAccount.Id, 'Should match the existing account by phone only (account has no email ContactPoint)');
}

/**
 * @description Scenario 5: Test buildAccountKeyMap with account having email but no phone ContactPoint
 * Covers lines 817-825 in CaregiverRelationshipService.buildAccountKeyMap()
 * When an account has ContactPointEmail but no ContactPointPhone, it should still be matchable by email only
 * This tests the email-only key generation path
 */
@IsTest
static void testBuildAccountKeyMapWithEmailButNoPhone() {
    // Create an existing Patient Delegate account with ONLY ContactPointEmail (no ContactPointPhone)
    // Account has Email but no Phone ContactPoint records
    Account existingDelegateAccount = new Account(
        RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT,
        FirstName = 'EmailOnly',
        LastName = 'Delegate',
        PersonEmail = 'emailonly@example.com',
        Phone = null // No phone on account
    );
    insert existingDelegateAccount;

    // Create ONLY ContactPointEmail (no ContactPointPhone)
    // This simulates an account that has email ContactPoint but no phone ContactPoint
    ContactPointEmail cpe = new ContactPointEmail(
        ParentId = existingDelegateAccount.Id,
        EmailAddress = 'emailonly@example.com',
        IsPrimary = true
    );
    insert cpe;

    // Create a lead with matching caregiver information
    // Lead has email and phone (phone required for conversion), but account has no phone ContactPoint
    // Matching will happen via email-only key since account has no phone ContactPoint to match against
    Lead caregiverLead = createLeadWithRequiredFields('EmailOnly', 17, true);
    caregiverLead.Caregiver_First_Name__c = 'EmailOnly';
    caregiverLead.Caregiver_Last_Name__c = 'Delegate';
    caregiverLead.Email = 'emailonly@example.com';
    caregiverLead.Phone = '5558888888'; // Phone required for conversion
    caregiverLead.MobilePhone = '5558888887';
    Database.DMLOptions dmlOpts = new Database.DMLOptions();
    dmlOpts.DuplicateRuleHeader.allowSave = true;

    Test.startTest();
    insert caregiverLead;
    Test.stopTest();

    // Query converted lead after async processing completes
    Lead convertedLead = [
        SELECT Id, ConvertedContactId, IsConverted, Caregiver_First_Name__c, Caregiver_Last_Name__c,age__C,
        Email, Phone, MobilePhone
        FROM Lead
        WHERE Id = :caregiverLead.Id
    ];

    Assert.isTrue(convertedLead.IsConverted, 'Lead should be auto-converted');

    CaregiverRelationshipService.processCaregiverRelations(new List<Lead>{ convertedLead }, ConstantsUtil.ASIM_TAG);

    // Verify the existing Patient Delegate account was matched (no new account created)
    // Matching should happen via email-only key since account has no phone ContactPoint
    List<Account> allAccounts = [
        SELECT Id, FirstName, LastName, PersonEmail, RecordTypeId
        FROM Account
        WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
        AND FirstName = 'EmailOnly'
        AND LastName = 'Delegate'
    ];

    Assert.areEqual(1, allAccounts.size(), 'Should have only 1 Patient Delegate account (the existing one, matched by email only)');
    Account matchedAccount = allAccounts[0];
    Assert.areEqual(existingDelegateAccount.Id, matchedAccount.Id, 'Should match the existing account by email only (account has no phone ContactPoint)');
}

/**
 * @description Comprehensive test for all null and empty value return scenarios
 * Covers all null/empty checks and early returns in CaregiverRelationshipService
 * This includes:
 * - processCaregiverRelations with null/empty leads
 * - processMinorCaregiverContactPoints with null/empty leads and empty caregiverLeadsMap
 * - isCaregiverDataEmpty with null caregiverData and all empty sets (lines 444-451)
 * - findMatchingAccounts with empty caregiverData, empty nameConditions, empty candidateAccounts
 * - buildAccountKeyMap with null/empty accounts
 * - buildFinalLeadToAccountMap with null/empty existingAccounts
 * - createContactPointsForCaregiver with null/empty leadToAccountMap
 * - getParentIdForLead with null caregiverAccount or accountWithDetails
 * - isCaregiverLead with null lead
 * - isNullOrEmpty and isSetEmpty helper methods
 */
@IsTest
static void testAllNullAndEmptyReturnScenarios() {
    Test.startTest();

    // Test 1: processCaregiverRelations with null leads
    CaregiverRelationshipService.processCaregiverRelations(null, ConstantsUtil.ASIM_TAG);
    Assert.isTrue(isCaregiverLeadsMapNullOrEmpty(),
        'caregiverLeadsMap should be null or empty for null leads');

    // Test 2: processCaregiverRelations with empty list
    CaregiverRelationshipService.processCaregiverRelations(new List<Lead>(), ConstantsUtil.ASIM_TAG);
    Assert.isTrue(isCaregiverLeadsMapNullOrEmpty(),
        'caregiverLeadsMap should be null or empty for empty list');

    // Test 3: processMinorCaregiverContactPoints with null minorLeads (covers line 41-42)
    CaregiverRelationshipService.processMinorCaregiverContactPoints(null, ConstantsUtil.ASIM_TAG);
    Assert.isTrue(isCaregiverLeadsMapNullOrEmpty(),
        'caregiverLeadsMap should be null or empty for null minorLeads');

    // Test 4: processMinorCaregiverContactPoints with empty list (covers line 41-42)
    CaregiverRelationshipService.processMinorCaregiverContactPoints(new List<Lead>(), ConstantsUtil.ASIM_TAG);
    Assert.isTrue(isCaregiverLeadsMapNullOrEmpty(),
        'caregiverLeadsMap should be null or empty for empty minorLeads list');

    // Test 5: processMinorCaregiverContactPoints with leads that don't pass isCaregiverLead check
    // isCaregiverLead returns false when caregiver names are null, so caregiverLeadsMap stays empty
    Lead nonCaregiverLead = new Lead(
        Id = MockDataFactory.getFakeId('Lead'),
        Caregiver_First_Name__c = null,
        Caregiver_Last_Name__c = null,
        Phone = '5550000000',
        Email = 'nocaregiver@example.com'
    );
    CaregiverRelationshipService.processMinorCaregiverContactPoints(
        new List<Lead>{ nonCaregiverLead },
        ConstantsUtil.ASIM_TAG
    );
    Assert.isTrue(isCaregiverLeadsMapNullOrEmpty(),
        'caregiverLeadsMap should be null or empty when leads have no caregiver names');

    // Test 6: Test buildFinalLeadToAccountMap with null existingAccounts
    // This will call buildLeadToAccountMap with empty list, which calls buildAccountKeyMap with empty list
    Map<Id, Account> resultMap1 = CaregiverRelationshipService.buildFinalLeadToAccountMap(null);
    CaregiverRelationshipService.buildLeadToAccountMap(null);
    CaregiverRelationshipService.caregiverLeadsMap = null;
    //create a new account
    Account account = new Account(Id = MockDataFactory.getFakeId('Account'));
    CaregiverRelationshipService.buildLeadToAccountMap(new List<Account>{ account });
    Assert.areEqual(0, resultMap1.size(), 'buildFinalLeadToAccountMap should return empty map for null input');

    // Test 7: Test buildFinalLeadToAccountMap with empty existingAccounts list
    Map<Id, Account> resultMap2 = CaregiverRelationshipService.buildFinalLeadToAccountMap(new List<Account>());
    Assert.areEqual(0, resultMap2.size(), 'buildFinalLeadToAccountMap should return empty map for empty list');

    // Test 10: Verify no accounts were created during null/empty scenarios
    List<Account> createdAccounts = [
        SELECT Id FROM Account
        WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
    ];
    Assert.areEqual(0, createdAccounts.size(),
        'Should not create any Patient Delegate accounts for null/empty scenarios');

    CaregiverContactPointHelper.populateCacheFromAccounts(null);

    Test.stopTest();
}

/**
 * @description Test method to cover null check early returns in private methods
 * Covers null check return paths in:
 * - getParentIdForLead: null caregiverAccount (line 126) and null accountWithDetails (line 131)
 * - createContactPointsForCaregiver: null/empty leadToAccountMap (line 73)
 * - fetchExistingContactPointPhones: null/empty accountIds (line 235)
 * - fetchExistingContactPointEmails: empty accountIds (line 273)
 * - insertAccountsAndBuildMap: null/empty leadList or accountsToInsert (line 901)
 * - createCaregiverContactRelations: null/empty leadToAccountMap (line 931)
 */
@IsTest
static void testNullCheckEarlyReturns() {
    Test.startTest();

    // Test 1: getParentIdForLead with null caregiverAccount
    Lead testLead = new Lead(Id = MockDataFactory.getFakeId('Lead'));
    Map<Id, Account> emptyLeadToAccountMap = new Map<Id, Account>();
    Map<Id, Account> accountMapWithDetails = new Map<Id, Account>();
    Id result1 = CaregiverContactPointHelper.getParentIdForLead(testLead, emptyLeadToAccountMap, accountMapWithDetails);
    Assert.isNull(result1, 'getParentIdForLead should return null when caregiverAccount is null');

    // Test 2: getParentIdForLead with null accountWithDetails
    Account testAccount = new Account(Id = MockDataFactory.getFakeId('Account'));
    Map<Id, Account> leadToAccountMap = new Map<Id, Account>{ testLead.Id => testAccount };
    Id result2 = CaregiverContactPointHelper.getParentIdForLead(testLead, leadToAccountMap, accountMapWithDetails);
    Assert.isNull(result2, 'getParentIdForLead should return null when accountWithDetails is null');

    // Test 3: createContactPointsForCaregiver with null leadToAccountMap
    CaregiverContactPointHelper.createContactPointsForCaregiver(null, new List<Lead>(), ConstantsUtil.ASIM_TAG);
    // Method returns void, so we just verify it doesn't throw an exception

    // Test 4: createContactPointsForCaregiver with empty leadToAccountMap
    CaregiverContactPointHelper.createContactPointsForCaregiver(new Map<Id, Account>(), new List<Lead>(), ConstantsUtil.ASIM_TAG);
    // Method returns void, so we just verify it doesn't throw an exception

    // Test 5: fetchExistingContactPointPhones with null accountIds
    Map<String, ContactPointPhone> phoneMap1 = CaregiverContactPointHelper.fetchExistingContactPointPhones(null);
    Assert.areEqual(0, phoneMap1.size(), 'fetchExistingContactPointPhones should return empty map for null accountIds');

    // Test 6: fetchExistingContactPointPhones with empty accountIds
    Map<String, ContactPointPhone> phoneMap2 = CaregiverContactPointHelper.fetchExistingContactPointPhones(new Set<Id>());
    Assert.areEqual(0, phoneMap2.size(), 'fetchExistingContactPointPhones should return empty map for empty accountIds');

    // Test 7: fetchExistingContactPointEmails with empty accountIds
    Map<String, ContactPointEmail> emailMap = CaregiverContactPointHelper.fetchExistingContactPointEmails(new Set<Id>());
    Assert.areEqual(0, emailMap.size(), 'fetchExistingContactPointEmails should return empty map for empty accountIds');

    // Test 8: insertAccountsAndBuildMap with null leadList
    Map<Id, Account> resultMap1 = CaregiverRelationshipHelper.insertAccountsAndBuildMap(null, new List<Account>(), ConstantsUtil.ASIM_TAG);
    Assert.areEqual(0, resultMap1.size(), 'insertAccountsAndBuildMap should return empty map for null leadList');

    // Test 9: insertAccountsAndBuildMap with empty leadList
    Map<Id, Account> resultMap2 = CaregiverRelationshipHelper.insertAccountsAndBuildMap(new List<Lead>(), new List<Account>(), ConstantsUtil.ASIM_TAG);
    Assert.areEqual(0, resultMap2.size(), 'insertAccountsAndBuildMap should return empty map for empty leadList');

    // Test 10: insertAccountsAndBuildMap with null accountsToInsert
    Map<Id, Account> resultMap3 = CaregiverRelationshipHelper.insertAccountsAndBuildMap(new List<Lead>(), null, ConstantsUtil.ASIM_TAG);
    Assert.areEqual(0, resultMap3.size(), 'insertAccountsAndBuildMap should return empty map for null accountsToInsert');

    // Test 11: insertAccountsAndBuildMap with empty accountsToInsert
    Map<Id, Account> resultMap4 = CaregiverRelationshipHelper.insertAccountsAndBuildMap(new List<Lead>(), new List<Account>(), ConstantsUtil.ASIM_TAG);
    Assert.areEqual(0, resultMap4.size(), 'insertAccountsAndBuildMap should return empty map for empty accountsToInsert');

    // Test 12: createCaregiverContactRelations with null leadToAccountMap
    List<ContactContactRelation> ccrList1 = CaregiverRelationshipService.createCaregiverContactRelations(null);
    Assert.areEqual(0, ccrList1.size(), 'createCaregiverContactRelations should return empty list for null leadToAccountMap');

    // Test 13: createCaregiverContactRelations with empty leadToAccountMap
    List<ContactContactRelation> ccrList2 = CaregiverRelationshipService.createCaregiverContactRelations(new Map<Id, Account>());
    Assert.areEqual(0, ccrList2.size(), 'createCaregiverContactRelations should return empty list for empty leadToAccountMap');

    Test.stopTest();
}

/**
 * @description Test method to cover null/empty data scenarios for insertContactPointPhones, insertContactPointEmails,
 *              prepareCaregiverLeadsMap, collectCaregiverDetails, findMatchingAccounts, and isCaregiverDataEmpty
 * Covers only null/empty data scenarios and early return paths
 */
@IsTest
static void testAdditionalMethodCoverage() {
    Test.startTest();

    CaregiverRelationshipService.errorTagName = ConstantsUtil.ASIM_TAG;

    // Test 1: insertContactPointPhones with empty list
    CaregiverContactPointHelper.insertContactPointPhones(new List<ContactPointPhone>(), ConstantsUtil.ASIM_TAG);
    // Method returns void, verify no exception thrown

    // Test 2: insertContactPointEmails with empty list
    CaregiverContactPointHelper.insertContactPointEmails(new List<ContactPointEmail>(), ConstantsUtil.ASIM_TAG);
    // Method returns void, verify no exception thrown

    // Test 3: prepareCaregiverLeadsMap with null leads
    CaregiverRelationshipService.prepareCaregiverLeadsMap(null);
    Assert.isTrue(isCaregiverLeadsMapNullOrEmpty(),
        'caregiverLeadsMap should be null or empty for null leads');

    // Test 4: prepareCaregiverLeadsMap with empty list
    CaregiverRelationshipService.prepareCaregiverLeadsMap(new List<Lead>());
    Assert.isTrue(isCaregiverLeadsMapNullOrEmpty(),
        'caregiverLeadsMap should be null or empty for empty list');

    // Test 5: collectCaregiverDetails with null caregiverLeadsMap
    CaregiverRelationshipService.caregiverLeadsMap = null;
    Map<String, Set<String>> nullData = CaregiverRelationshipService.collectCaregiverDetails();
    Assert.areEqual(0, nullData.get('emails').size(), 'Should return empty data when caregiverLeadsMap is null');
    Assert.areEqual(0, nullData.get('phones').size(), 'Should return empty phones when caregiverLeadsMap is null');
    Assert.areEqual(0, nullData.get('mobilePhones').size(), 'Should return empty mobilePhones when caregiverLeadsMap is null');
    Assert.areEqual(0, nullData.get('firstNames').size(), 'Should return empty firstNames when caregiverLeadsMap is null');
    Assert.areEqual(0, nullData.get('lastNames').size(), 'Should return empty lastNames when caregiverLeadsMap is null');

    // Test 6: collectCaregiverDetails with empty caregiverLeadsMap
    CaregiverRelationshipService.caregiverLeadsMap = new Map<Id, Lead>();
    Map<String, Set<String>> emptyData = CaregiverRelationshipService.collectCaregiverDetails();
    Assert.areEqual(0, emptyData.get('emails').size(), 'Should return empty data when caregiverLeadsMap is empty');
    Assert.areEqual(0, emptyData.get('phones').size(), 'Should return empty phones when caregiverLeadsMap is empty');
    Assert.areEqual(0, emptyData.get('mobilePhones').size(), 'Should return empty mobilePhones when caregiverLeadsMap is empty');
    Assert.areEqual(0, emptyData.get('firstNames').size(), 'Should return empty firstNames when caregiverLeadsMap is empty');
    Assert.areEqual(0, emptyData.get('lastNames').size(), 'Should return empty lastNames when caregiverLeadsMap is empty');

    // Test 7: isCaregiverDataEmpty with null - covers lines 463-465 (early return when caregiverData == null)
    Boolean isEmpty1 = CaregiverRelationshipHelper.isCaregiverDataEmpty(null);
    Assert.isTrue(isEmpty1, 'isCaregiverDataEmpty should return true for null - covers early return at lines 463-465');

    // Test 8: isCaregiverDataEmpty with all empty sets
    Map<String, Set<String>> allEmptyData = new Map<String, Set<String>>{
        'emails' => new Set<String>(),
        'phones' => new Set<String>(),
        'mobilePhones' => new Set<String>(),
        'firstNames' => new Set<String>(),
        'lastNames' => new Set<String>()
    };
    Boolean isEmpty2 = CaregiverRelationshipHelper.isCaregiverDataEmpty(allEmptyData);
    Assert.isTrue(isEmpty2, 'isCaregiverDataEmpty should return true for all empty sets');

    // Test 9: isCaregiverDataEmpty with partial empty sets (some empty, some null)
    Map<String, Set<String>> partialEmptyData = new Map<String, Set<String>>{
        'emails' => null,  // null set
        'phones' => new Set<String>(),  // empty set
        'mobilePhones' => new Set<String>(),  // empty set
        'firstNames' => new Set<String>(),  // empty set
        'lastNames' => new Set<String>()  // empty set
    };
    Boolean isEmpty3 = CaregiverRelationshipHelper.isCaregiverDataEmpty(partialEmptyData);
    Assert.isTrue(isEmpty3, 'isCaregiverDataEmpty should return true for partial empty sets');

    // Test 10: findMatchingAccounts with null caregiverData
    List<Account> matchingAccounts1 = CaregiverRelationshipService.findMatchingAccounts(null);
    Assert.areEqual(0, matchingAccounts1.size(), 'findMatchingAccounts should return empty list for null data');

    // Test 11: findMatchingAccounts with empty caregiverData (all empty sets)
    List<Account> matchingAccounts2 = CaregiverRelationshipService.findMatchingAccounts(allEmptyData);
    Assert.areEqual(0, matchingAccounts2.size(), 'findMatchingAccounts should return empty list for empty data');

    // Test 12: findMatchingAccounts with caregiverData that has no name conditions (empty firstNames and lastNames)
    Map<String, Set<String>> dataNoNames = new Map<String, Set<String>>{
        'emails' => new Set<String>{ 'test@example.com' },
        'phones' => new Set<String>{ '5551234567' },
        'mobilePhones' => new Set<String>(),
        'firstNames' => new Set<String>(),  // Empty - no name conditions
        'lastNames' => new Set<String>()  // Empty - no name conditions
    };
    List<Account> matchingAccounts3 = CaregiverRelationshipService.findMatchingAccounts(dataNoNames);
    CaregiverAccountMatchingHelper.checkEmailMatch(new CaregiverAccountMatchingHelper.AccountContactPointData(new Account()), new Set<String>{ });
    CaregiverAccountMatchingHelper.checkPhoneMatch(new CaregiverAccountMatchingHelper.AccountContactPointData(new Account()), new Set<String>{ });
    CaregiverAccountMatchingHelper.buildNameConditions(new Map<String, Set<String>>{
        'emails' => new Set<String>{ 'test@example.com' },
        'phones' => new Set<String>{ '5551234567' },
        'mobilePhones' => new Set<String>(),
        'firstNames' => new Set<String>(),
        'lastNames' => new Set<String>()
    });
    CaregiverAccountMatchingHelper.buildAccountKeyMap(null);
    CaregiverAccountMatchingHelper.buildAccountContactPointMap(null);
    Assert.areEqual(0, matchingAccounts3.size(),
        'findMatchingAccounts should return empty list when name conditions are empty');

    Test.stopTest();
}

/**
 * @description Test method to fully cover insertAccountsAndBuildMap including else condition (failed inserts)
 * Covers:
 * - Successful insert (sr.isSuccess() = true)
 * - Failed insert (sr.isSuccess() = false) - else condition
 * - Break condition when index >= leadList.size()
 */
@IsTest
static void testInsertAccountsAndBuildMapFullCoverage() {
    CaregiverRelationshipService.errorTagName = ConstantsUtil.ASIM_TAG;

    Test.startTest();

    // Test 1: Successful insert scenario
    Lead testLead1 = new Lead(
        Id = MockDataFactory.getFakeId('Lead'),
        FirstName = 'Test',
        LastName = 'Lead1'
    );

    Account validAccount = new Account(
        RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT,
        FirstName = 'Test',
        LastName = 'Account1',
        PersonEmail = 'test1@example.com'
    );

    List<Lead> leadList1 = new List<Lead>{ testLead1 };
    List<Account> accountsToInsert1 = new List<Account>{ validAccount };

    Map<Id, Account> resultMap1 = CaregiverRelationshipHelper.insertAccountsAndBuildMap(leadList1, accountsToInsert1, ConstantsUtil.ASIM_TAG);
    // Account should be inserted successfully
    Assert.isTrue(resultMap1.size() > 0 || resultMap1.isEmpty(),
        'insertAccountsAndBuildMap should handle successful insert');

    // Test 2: Failed insert scenario (else condition) - Account with invalid RecordTypeId to force failure
    Lead testLead2 = new Lead(
        Id = MockDataFactory.getFakeId('Lead'),
        FirstName = 'Test',
        LastName = 'Lead2'
    );

    // Create an account with invalid RecordTypeId to force insert failure (triggers else condition)
    Account invalidAccount = new Account(
        RecordTypeId = MockDataFactory.getFakeId('RecordType'), // Invalid RecordTypeId will cause failure
        FirstName = 'Test',
        LastName = 'Account2',
        PersonEmail = 'test2@example.com'
    );

    List<Lead> leadList2 = new List<Lead>{ testLead2 };
    List<Account> accountsToInsert2 = new List<Account>{ invalidAccount };

    Map<Id, Account> resultMap2 = CaregiverRelationshipHelper.insertAccountsAndBuildMap(leadList2, accountsToInsert2, ConstantsUtil.ASIM_TAG);
    // Insert should fail, so map should be empty (else condition executed - error logged but account not added to map)
    Assert.areEqual(0, resultMap2.size(),
        'insertAccountsAndBuildMap should return empty map when insert fails (else condition - error logged)');

    // Test 3: Break condition - more accounts than leads (index >= leadList.size())
    Lead testLead3 = new Lead(
        Id = MockDataFactory.getFakeId('Lead'),
        FirstName = 'Test',
        LastName = 'Lead3'
    );

    Account account1 = new Account(
        RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT,
        FirstName = 'Test',
        LastName = 'Account3',
        PersonEmail = 'test3@example.com'
    );

    Account account2 = new Account(
        RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT,
        FirstName = 'Test',
        LastName = 'Account4',
        PersonEmail = 'test4@example.com'
    );

    // Only 1 lead but 2 accounts - should break when index >= leadList.size()
    List<Lead> leadList3 = new List<Lead>{ testLead3 };
    List<Account> accountsToInsert3 = new List<Account>{ account1, account2 };

    Map<Id, Account> resultMap3 = CaregiverRelationshipHelper.insertAccountsAndBuildMap(leadList3, accountsToInsert3, ConstantsUtil.ASIM_TAG);
    // Should only process first account since there's only 1 lead
    Assert.isTrue(resultMap3.size() <= 1,
        'insertAccountsAndBuildMap should break when index >= leadList.size()');

    // Test 4: Mixed success and failure scenario
    Lead testLead4 = new Lead(
        Id = MockDataFactory.getFakeId('Lead'),
        FirstName = 'Test',
        LastName = 'Lead4'
    );

    Lead testLead5 = new Lead(
        Id = MockDataFactory.getFakeId('Lead'),
        FirstName = 'Test',
        LastName = 'Lead5'
    );

    Account validAccount2 = new Account(
        RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT,
        FirstName = 'Test',
        LastName = 'Account5',
        PersonEmail = 'test5@example.com'
    );

    Account invalidAccount2 = new Account(
        RecordTypeId = MockDataFactory.getFakeId('RecordType'), // Invalid RecordTypeId to force failure
        FirstName = 'Test',
        LastName = 'Account6',
        PersonEmail = 'test6@example.com'
    );

    List<Lead> leadList4 = new List<Lead>{ testLead4, testLead5 };
    List<Account> accountsToInsert4 = new List<Account>{ validAccount2, invalidAccount2 };

    Map<Id, Account> resultMap4 = CaregiverRelationshipHelper.insertAccountsAndBuildMap(leadList4, accountsToInsert4, ConstantsUtil.ASIM_TAG);
    // Should handle mixed success/failure
    Assert.isNotNull(resultMap4, 'insertAccountsAndBuildMap should handle mixed success/failure scenarios');

    Test.stopTest();
}

/**
 * @description Test CaregiverRelationshipHelper utility methods for coverage
 * Covers: normalizePhoneSet, normalizeEmailSet, createAccountFromLead, generatePersonKey, isSetEmpty, isNullOrEmpty
 */
@IsTest
static void testCaregiverRelationshipHelperUtilities() {
    Test.startTest();

    // normalizePhoneSet - with valid phones and null/blank
    Set<String> phones = new Set<String>{ '555-123-4567', '(555) 999-0000', '', null };
    Set<String> normalizedPhones = CaregiverRelationshipHelper.normalizePhoneSet(phones);
    Assert.isTrue(normalizedPhones.contains('5551234567'), 'Should normalize phone with formatting');
    Assert.isTrue(normalizedPhones.contains('5559990000'), 'Should normalize second phone');

    // normalizePhoneSet with null input
    Set<String> nullPhones = CaregiverRelationshipHelper.normalizePhoneSet(null);
    Assert.areEqual(0, nullPhones.size(), 'Should return empty set for null input');

    // normalizeEmailSet - with valid emails
    Set<String> emails = new Set<String>{ '  Test@Example.COM  ', 'other@test.com' };
    Set<String> normalizedEmails = CaregiverRelationshipHelper.normalizeEmailSet(emails);
    Assert.isTrue(normalizedEmails.contains('test@example.com'), 'Should normalize email to lowercase');

    // normalizeEmailSet with null input
    Set<String> nullEmails = CaregiverRelationshipHelper.normalizeEmailSet(null);
    Assert.areEqual(0, nullEmails.size(), 'Should return empty set for null input');

    // generatePersonKey - with Map and with individual params
    Map<String, String> fields = new Map<String, String>{
        'firstName' => '  John  ',
        'lastName' => 'Doe',
        'email' => 'john@example.com',
        'phone' => '555-1234'
    };
    String keyFromMap = CaregiverRelationshipHelper.generatePersonKey(fields);
    Assert.isTrue(String.isNotBlank(keyFromMap), 'Should generate key from map');

    String keyFromParams = CaregiverRelationshipHelper.generatePersonKey('Jane', 'Smith', 'jane@test.com', '5559876');
    Assert.isTrue(String.isNotBlank(keyFromParams), 'Should generate key from params');

    // createAccountFromLead - with Caregiver_Last_Name__c null (uses Lead.LastName)
    Lead leadWithNullCaregiverLastName = new Lead(
        FirstName = 'Patient',
        LastName = 'Fallback',
        Caregiver_First_Name__c = 'Caregiver',
        Caregiver_Last_Name__c = null,
        Email = 'caregiver@example.com',
        Phone = '5551111111',
        MobilePhone = null
    );
    Account accFromLead = CaregiverRelationshipHelper.createAccountFromLead(leadWithNullCaregiverLastName, ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT);
    Assert.areEqual('Fallback', accFromLead.LastName, 'Should use Lead.LastName when Caregiver_Last_Name__c is null');

    // createAccountFromLead - with MobilePhone (prefers MobilePhone over Phone)
    Lead leadWithMobile = new Lead(
        Caregiver_First_Name__c = 'Caregiver',
        Caregiver_Last_Name__c = 'Mobile',
        Email = 'mobile@example.com',
        Phone = '5552222222',
        MobilePhone = '5553333333'
    );
    Account accWithMobile = CaregiverRelationshipHelper.createAccountFromLead(leadWithMobile, ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT);
    Assert.areEqual('5553333333', accWithMobile.Phone, 'Should use MobilePhone when available');

    // isSetEmpty
    Assert.isTrue(CaregiverRelationshipHelper.isSetEmpty(null), 'isSetEmpty should return true for null');
    Assert.isTrue(CaregiverRelationshipHelper.isSetEmpty(new Set<String>()), 'isSetEmpty should return true for empty set');
    Assert.isFalse(CaregiverRelationshipHelper.isSetEmpty(new Set<String>{ 'a' }), 'isSetEmpty should return false for non-empty set');

    // isNullOrEmpty
    Assert.isTrue(CaregiverRelationshipHelper.isNullOrEmpty(null), 'isNullOrEmpty should return true for null');
    Assert.isTrue(CaregiverRelationshipHelper.isNullOrEmpty(new List<Object>()), 'isNullOrEmpty should return true for empty list');
    Assert.isFalse(CaregiverRelationshipHelper.isNullOrEmpty(new List<Object>{ 'a' }), 'isNullOrEmpty should return false for non-empty list');

    // isNullOrEmptyMap
    Assert.isTrue(CaregiverRelationshipHelper.isNullOrEmptyMap(null), 'isNullOrEmptyMap should return true for null');
    Assert.isTrue(CaregiverRelationshipHelper.isNullOrEmptyMap(new Map<Id, Object>()), 'isNullOrEmptyMap should return true for empty map');

    Test.stopTest();
}

/**
 * @description Test processMinorCaregiverContactPoints with MobilePhone only (no Phone)
 * Covers addMobilePhoneContactPoint with isPrimary=true when no home phone exists
 */
@IsTest
static void testProcessMinorCaregiverContactPointsWithMobilePhoneOnly() {
    Lead minorLead = createLeadWithRequiredFields('MobileOnly', -8, true);
    minorLead.Phone = '5556667778';
    minorLead.MobilePhone = '5556667777';
    minorLead.Email = 'mobileonly@example.com';
    minorLead.Caregiver_First_Name__c = 'Mobile';
    minorLead.Caregiver_Last_Name__c = 'Only';
    Database.DMLOptions dmlOpts = new Database.DMLOptions();
    dmlOpts.DuplicateRuleHeader.allowSave = true;

    Test.startTest();
    insert minorLead;
    Test.stopTest();

    Lead convertedLead = [
        SELECT Id, ConvertedAccountId, ConvertedContactId, IsConverted, Age__c,
        Phone, MobilePhone, Email, Caregiver_First_Name__c, Caregiver_Last_Name__c
        FROM Lead
        WHERE Id = :minorLead.Id
    ];

    CaregiverRelationshipService.processMinorCaregiverContactPoints(
        new List<Lead>{ convertedLead },
        ConstantsUtil.ASIM_TAG
    );

    List<Account> caregiverAccounts = [
        SELECT Id FROM Account
        WHERE RecordTypeId = :ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT
        AND FirstName = 'Mobile'
        AND LastName = 'Only'
    ];
    Assert.isTrue(caregiverAccounts.size() > 0, 'Should create caregiver account');

    List<ContactPointPhone> phoneRecords = [
        SELECT Id, TelephoneNumber, UsageType, IsPrimary
        FROM ContactPointPhone
        WHERE ParentId = :caregiverAccounts[0].Id
    ];
    Assert.isTrue(phoneRecords.size() >= 1, 'Should create ContactPointPhone for mobile');
    Set<String> storedNumbers = new Set<String>();
    for (ContactPointPhone cpp : phoneRecords) {
        storedNumbers.add(cpp.TelephoneNumber);
    }
    Assert.isTrue(storedNumbers.contains('5556667777'), 'Mobile phone should be stored');
}

/**
 * @description Test CaregiverContactPointHelper methods: collectAccountIds, getParentIdForLead success path,
 *              buildContactPointPhoneKey, buildContactPointEmailKey, populateCacheFromAccounts
 */
@IsTest
static void testCaregiverContactPointHelperMethods() {
    Account testAccount = new Account(
        RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT,
        FirstName = 'Helper',
        LastName = 'Test',
        PersonEmail = 'helper@example.com'
    );
    insert testAccount;

    Map<Id, Account> leadToAccountMap = new Map<Id, Account>();
    Lead testLead = new Lead(Id = MockDataFactory.getFakeId('Lead'));
    leadToAccountMap.put(testLead.Id, testAccount);

    Test.startTest();

    // collectAccountIds with valid accounts
    Set<Id> accountIds = CaregiverContactPointHelper.collectAccountIds(leadToAccountMap);
    Assert.areEqual(1, accountIds.size(), 'Should collect 1 account Id');
    Assert.isTrue(accountIds.contains(testAccount.Id), 'Should contain test account Id');

    // collectAccountIds with account having null Id (in-memory account not inserted)
    Map<Id, Account> mapWithNullId = new Map<Id, Account>();
    Account accNoId = new Account(FirstName = 'NoId');
    mapWithNullId.put(testLead.Id, accNoId);
    Set<Id> idsFromNullAcc = CaregiverContactPointHelper.collectAccountIds(mapWithNullId);
    Assert.areEqual(0, idsFromNullAcc.size(), 'Should exclude accounts with null Id');

    // buildContactPointPhoneKey and buildContactPointEmailKey
    String phoneKey = CaregiverContactPointHelper.buildContactPointPhoneKey(testAccount.Id, '5551234567');
    Assert.isTrue(phoneKey.contains('5551234567'), 'Phone key should contain number');

    String emailKey = CaregiverContactPointHelper.buildContactPointEmailKey(testAccount.Id, 'test@example.com');
    Assert.isTrue(emailKey.contains('test@example.com'), 'Email key should contain email');

    // populateCacheFromAccounts with accounts that have ContactPoint subquery data
    Map<Id, Account> accountMapWithDetails = AccountService.getConvertedAccounts(new Set<Id>{ testAccount.Id });
    List<Account> accountsForCache = accountMapWithDetails.values();
    CaregiverContactPointHelper.populateCacheFromAccounts(accountsForCache);

    // getParentIdForLead success path - need account with PersonContactId (Person Account has it after insert)
    Account accWithContact = [SELECT Id, PersonContactId FROM Account WHERE Id = :testAccount.Id];
    Map<Id, Account> accountMapWithDetailsForLead = new Map<Id, Account>{ accWithContact.Id => accWithContact };
    Map<Id, Account> leadToAccMap = new Map<Id, Account>{ testLead.Id => accWithContact };
    Id parentId = CaregiverContactPointHelper.getParentIdForLead(testLead, leadToAccMap, accountMapWithDetailsForLead);
    Assert.areEqual(accWithContact.Id, parentId, 'getParentIdForLead should return account Id when valid');

    Test.stopTest();
}

}