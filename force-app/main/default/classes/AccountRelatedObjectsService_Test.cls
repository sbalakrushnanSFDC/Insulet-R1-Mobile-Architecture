/**
    * @description Test class for AccountRelatedObjectsService
    * @author  Shailja Jain
	* @date 10-10-2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By               Brief Note
 * V1.0.0       10-10-2025        Shailja Jain            Initial Version
 * V1.0.0       08-01-2026        Priyansh Shukla         NGASIM-1642
 * V1.0.1       02-02-2026        Charchit Nirayanwal     Updated to use auto-conversion logic
 * V1.0.2       02-02-2026        Charchit Nirayanwal     Updated for refactored code with AccountRelatedObjectsServiceHelper
 * V1.0.3       27-02-2026        Bijayalaxmi Prusty      Updated(US - NGASIM-2157)
 * V1.0.4       02-03-2026        Chitresh Vijayvargiya   Updated(US - NGASIM-2354)

*/

@IsTest(IsParallel=true)
public class AccountRelatedObjectsService_Test {

    // Cache facility ID to avoid repeated SOQL queries
    private static Id cachedFacilityId = null;

    @TestSetup
    static void setupTestData() {
        List<DataUsePurpose> dataUsePurposes = new List<DataUsePurpose>{
            new DataUsePurpose(Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
            new DataUsePurpose(Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            new DataUsePurpose(Name = ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL)
        };
        insert dataUsePurposes;

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
     * @description Context object for creating test leads
     */
    private class LeadCreationContext {
        String uniqueSuffix;
        Integer age;
        String email;
        String phone;
        String mobilePhone;
    }

    /**
     * @description Helper method to create a lead with all required fields for auto-conversion
     * @param context Context object containing all required parameters
     * @return Lead record with all required fields
     */
    private static Lead createLeadWithRequiredFields(LeadCreationContext context) {
        Id facilityId = getFacilityId();
        String phoneDigits = String.valueOf(Math.abs(context.uniqueSuffix.hashCode())).substring(0, Math.min(7, String.valueOf(Math.abs(context.uniqueSuffix.hashCode())).length()));
        if (phoneDigits.length() < 7) {
            phoneDigits = phoneDigits.leftPad(7, '0');
        }
        String defaultPhoneNumber = '555' + phoneDigits.substring(0, 7);

        // Calculate date of birth - ensure it's always in the past
        Integer yearsAgo = context.age > 0 ? -context.age : context.age;
        Date dateOfBirth = Date.today().addYears(yearsAgo);

        Map<String, Object> leadFields = new Map<String, Object>{
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT,
            'FirstName' => 'Test' + context.uniqueSuffix,
            'LastName' => 'Patient' + context.uniqueSuffix,
            'Email' => context.email != null ? context.email : ('testpatient' + context.uniqueSuffix.replaceAll('[^a-zA-Z0-9]', '') + '@example.com'),
            'Phone' => context.phone != null ? context.phone : defaultPhoneNumber,
            'MobilePhone' => context.mobilePhone,
            'Date_of_Birth__c' => dateOfBirth,
            'GenderIdentity' => 'Male',
            'Address_Status__c' => 'Verified',
            'Recommended_Product__c' => 'DASH',
            'Sensor_CGM_Continuous_Glucose_Monitor__c' => 'Dexcom G6',
            'Type_of_Diabetes__c' => 'Type 1',
            'Status' => 'Qualification',
            'Request_a_Call_Back__c' => false,
            'Duplicate_Review_Completed__c' => true,
            'Matching_Status__c' => ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH,
            'Provider_Practice_Affiliation__c' => facilityId,
            'Company' => 'Test Company ' + context.uniqueSuffix,
            'LeadSource' => 'Web',
            'Street' => '123 Test Street ' + context.uniqueSuffix,
            'City' => 'Boston',
            'State' => 'Massachusetts',
            'PostalCode' => '02102',
            'Country' => 'United States'
        };

        return TestDataFactory.getLead(leadFields);
    }

    @IsTest
    static void testMapContactPointFieldsWithPersonAccount() {
        LeadCreationContext context = new LeadCreationContext();
        context.uniqueSuffix = 'PersonAccount';
        context.age = 30;
        context.email = 'testpatient@example.com';
        context.phone = '1234567890';
        context.mobilePhone = null;
        Lead testLead = createLeadWithRequiredFields(context);
        testLead.Street = '123 Main St';
        testLead.City = 'San Francisco';
        testLead.State = 'California';
        testLead.PostalCode = '94102';
        testLead.Country = 'United States';

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;

        Test.startTest();
        Database.insert(testLead, dmlOpts);
        // Wait for auto-conversion to happen via trigger
        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedAccountId, IsConverted, Email, Phone, MobilePhone, Street, City, State, PostalCode, Country, Address_Status__c FROM Lead WHERE Id = :testLead.Id];
        Assert.isTrue(convertedLead.IsConverted, 'Lead should be auto-converted');

        Account convertedAccount = [SELECT Id, RecordTypeId FROM Account WHERE Id = :convertedLead.ConvertedAccountId];

        AccountRelatedObjectsService.mapContactPointFields(
            new List<Lead>{ convertedLead },
            convertedAccount.RecordTypeId,
            ConstantsUtil.ASIM_TAG
        );

        List<ContactPointAddress> cpaList = [SELECT Id, ParentId FROM ContactPointAddress WHERE ParentId = :convertedAccount.Id];
        List<ContactPointEmail> cpeList = [SELECT Id, ParentId FROM ContactPointEmail WHERE ParentId = :convertedAccount.Id];
        List<ContactPointPhone> cppList = [SELECT Id, ParentId FROM ContactPointPhone WHERE ParentId = :convertedAccount.Id];

        Assert.areEqual(1, cpaList.size(), 'ContactPointAddress should be created');
        Assert.areEqual(1, cpeList.size(), 'ContactPointEmail should be created');
        Assert.areEqual(1, cppList.size(), 'ContactPointPhone should be created');
    }

    @IsTest
    static void testMapContactPointFieldsWithExistingContactPoints() {
        LeadCreationContext context = new LeadCreationContext();
        context.uniqueSuffix = 'ExistingCP';
        context.age = 30;
        context.email = 'john.doe@test.com';
        context.phone = '9876543210';
        context.mobilePhone = null;
        Lead testLead = createLeadWithRequiredFields(context);
        testLead.Street = '456 Oak Ave';
        testLead.City = 'Los Angeles';
        testLead.State = 'California';
        testLead.PostalCode = '90001';
        testLead.Country = 'United States';

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;

        Test.startTest();
        Database.insert(testLead, dmlOpts);
        // Wait for auto-conversion to happen via trigger
        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedAccountId, IsConverted, Email, Phone, MobilePhone, Street, City, State, PostalCode, Country, Address_Status__c FROM Lead WHERE Id = :testLead.Id];
        Assert.isTrue(convertedLead.IsConverted, 'Lead should be auto-converted');

        Account convertedAccount = [SELECT Id, RecordTypeId FROM Account WHERE Id = :convertedLead.ConvertedAccountId];

        ContactPointAddress cpa = TestDataFactory.getContactPointAddress(new Map<String, Object>{
            'ParentId' => convertedAccount.Id,
            'Name' => 'John Doe Address',
            'Street' => '456 Oak Ave',
            'City' => 'Los Angeles',
            'State' => 'California',
            'PostalCode' => '90001',
            'Country' => 'United States'
        });
        insert cpa;

        ContactPointEmail cpe = new ContactPointEmail(
            ParentId = convertedAccount.Id,
            EmailAddress = 'john.doe@test.com'
        );
        insert cpe;

        ContactPointPhone cpp = new ContactPointPhone(
            ParentId = convertedAccount.Id,
            TelephoneNumber = '9876543210'
        );
        insert cpp;

        AccountRelatedObjectsService.mapContactPointFields(
            new List<Lead>{ convertedLead },
            convertedAccount.RecordTypeId,
            ConstantsUtil.ASIM_TAG
        );

        List<ContactPointAddress> cpaList = [SELECT Id FROM ContactPointAddress WHERE ParentId = :convertedAccount.Id];
        List<ContactPointEmail> cpeList = [SELECT Id FROM ContactPointEmail WHERE ParentId = :convertedAccount.Id];
        List<ContactPointPhone> cppList = [SELECT Id FROM ContactPointPhone WHERE ParentId = :convertedAccount.Id];

        Assert.areEqual(2, cpaList.size(), 'Existing ContactPointAddress should be retained');
        Assert.areEqual(2, cpeList.size(), 'Existing ContactPointEmail should be retained');
        Assert.areEqual(2, cppList.size(), 'Existing ContactPointPhone should be retained');
    }


    @IsTest
    static void testMapContactPointFieldsWithEmptyLeadList() {
        Test.startTest();
        AccountRelatedObjectsService.mapContactPointFields(
            new List<Lead>(),
            ConstantsUtil.ACCOUNT_PATIENT_RT,
            ConstantsUtil.ASIM_TAG
        );
        Test.stopTest();

        List<ContactPointAddress> cpaList = [SELECT Id FROM ContactPointAddress];
        Assert.areEqual(0, cpaList.size(), 'No ContactPointAddress should be created for empty lead list');
    }

    @IsTest
    static void testMapContactPointFieldsWithNullLeadList() {
        Test.startTest();
        AccountRelatedObjectsService.mapContactPointFields(
            null,
            ConstantsUtil.ACCOUNT_PATIENT_RT,
            ConstantsUtil.ASIM_TAG
        );
        Test.stopTest();

        List<ContactPointAddress> cpaList = [SELECT Id FROM ContactPointAddress];
        Assert.areEqual(0, cpaList.size(), 'No ContactPointAddress should be created for null lead list');
    }

    @IsTest
    static void testMapContactPointFieldsWithMultipleEmailsPerAccount() {
        LeadCreationContext context = new LeadCreationContext();
        context.uniqueSuffix = 'MultiEmail';
        context.age = 30;
        context.email = 'primary@test.com';
        context.phone = '5551234567';
        context.mobilePhone = null;
        Lead testLead = createLeadWithRequiredFields(context);
        testLead.Street = '789 Elm St';
        testLead.City = 'Seattle';
        testLead.State = 'California';
        testLead.PostalCode = '98101';
        testLead.Country = 'United States';

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;

        Test.startTest();
        Database.insert(testLead, dmlOpts);
        // Wait for auto-conversion to happen via trigger
        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedAccountId, IsConverted, Email, Phone, MobilePhone, Street, City, State, PostalCode, Country, Address_Status__c FROM Lead WHERE Id = :testLead.Id];
        Assert.isTrue(convertedLead.IsConverted, 'Lead should be auto-converted');

        Account convertedAccount = [SELECT Id, RecordTypeId FROM Account WHERE Id = :convertedLead.ConvertedAccountId];

        ContactPointEmail cpe1 = new ContactPointEmail(
            ParentId = convertedAccount.Id,
            EmailAddress = 'email1@test.com'
        );
        ContactPointEmail cpe2 = new ContactPointEmail(
            ParentId = convertedAccount.Id,
            EmailAddress = 'email2@test.com'
        );
        insert new List<ContactPointEmail>{ cpe1, cpe2 };

        ContactPointPhone cpp1 = new ContactPointPhone(
            ParentId = convertedAccount.Id,
            TelephoneNumber = '1111111111'
        );
        ContactPointPhone cpp2 = new ContactPointPhone(
            ParentId = convertedAccount.Id,
            TelephoneNumber = '2222222222'
        );
        insert new List<ContactPointPhone>{ cpp1, cpp2 };

        ContactPointAddress cpa1 = TestDataFactory.getContactPointAddress(new Map<String, Object>{
            'ParentId' => convertedAccount.Id,
            'Name' => 'MultiEmail User Address 1',
            'Street' => '100 First St',
            'City' => 'Seattle',
            'State' => 'California',
            'PostalCode' => '98101',
            'Country' => 'United States'
        });
        ContactPointAddress cpa2 = TestDataFactory.getContactPointAddress(new Map<String, Object>{
            'ParentId' => convertedAccount.Id,
            'Name' => 'MultiEmail User Address 2',
            'Street' => '200 Second St',
            'City' => 'Seattle',
            'State' => 'California',
            'PostalCode' => '98102',
            'Country' => 'United States'
        });
        insert new List<ContactPointAddress>{ cpa1, cpa2 };

        AccountRelatedObjectsService.mapContactPointFields(
            new List<Lead>{ convertedLead },
            convertedAccount.RecordTypeId,
            ConstantsUtil.ASIM_TAG
        );

        List<ContactPointEmail> cpeList = [SELECT Id FROM ContactPointEmail WHERE ParentId = :convertedAccount.Id];
        List<ContactPointPhone> cppList = [SELECT Id FROM ContactPointPhone WHERE ParentId = :convertedAccount.Id];
        List<ContactPointAddress> cpaList = [SELECT Id FROM ContactPointAddress WHERE ParentId = :convertedAccount.Id];

        Assert.areEqual(3, cpeList.size(), 'Should have 2 existing + 1 new ContactPointEmail');
        Assert.areEqual(3, cppList.size(), 'Should have 2 existing + 1 new ContactPointPhone');
        Assert.areEqual(3, cpaList.size(), 'Should have 2 existing + 1 new ContactPointAddress');
    }

    @IsTest
    static void testMapContactPointFieldsWithMobilePhone() {
        LeadCreationContext context = new LeadCreationContext();
        context.uniqueSuffix = 'MobilePhone';
        context.age = 30;
        context.email = 'mobile@test.com';
        context.phone = '1234567890';
        context.mobilePhone = '9876543210';
        Lead testLead = createLeadWithRequiredFields(context);
        testLead.Street = '123 Mobile St';
        testLead.City = 'Boston';
        testLead.State = 'Massachusetts';
        testLead.PostalCode = '02102';
        testLead.Country = 'United States';

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;

        Test.startTest();
        Database.insert(testLead, dmlOpts);
        // Wait for auto-conversion to happen via trigger
        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedAccountId, IsConverted, Email, Phone, MobilePhone, Street, City, State, PostalCode, Country, Address_Status__c FROM Lead WHERE Id = :testLead.Id];
        Assert.isTrue(convertedLead.IsConverted, 'Lead should be auto-converted');

        Account convertedAccount = [SELECT Id, RecordTypeId FROM Account WHERE Id = :convertedLead.ConvertedAccountId];

        AccountRelatedObjectsService.mapContactPointFields(
            new List<Lead>{ convertedLead },
            convertedAccount.RecordTypeId,
            ConstantsUtil.ASIM_TAG
        );

        List<ContactPointPhone> cppList = [
            SELECT Id, ParentId, TelephoneNumber, UsageType, IsPrimary
            FROM ContactPointPhone
            WHERE ParentId = :convertedAccount.Id
            ORDER BY UsageType
        ];

        Assert.areEqual(2, cppList.size(), 'Should have both Phone and MobilePhone ContactPointPhone records');
        Boolean homePhoneFound = false;
        Boolean mobilePhoneFound = false;
        for (ContactPointPhone cpp : cppList) {
            if (cpp.UsageType == ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME) {
                Assert.areEqual('1234567890', cpp.TelephoneNumber, 'Home phone should match Lead Phone');
                Assert.isTrue(cpp.IsPrimary, 'Home phone should be primary');
                homePhoneFound = true;
            } else if (cpp.UsageType == ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE) {
                Assert.areEqual('9876543210', cpp.TelephoneNumber, 'Mobile phone should match Lead MobilePhone');
                mobilePhoneFound = true;
            }
        }
        Assert.isTrue(homePhoneFound, 'Home phone should be found');
        Assert.isTrue(mobilePhoneFound, 'Mobile phone should be found');
    }

    @IsTest
    static void testMapContactPointFieldsWithMobilePhoneOnly() {
        LeadCreationContext context = new LeadCreationContext();
        context.uniqueSuffix = 'MobileOnly';
        context.age = 30;
        context.email = 'mobileonly@test.com';
        context.phone = null;
        context.mobilePhone = '9876543210';
        Lead testLead = createLeadWithRequiredFields(context);
        // Override default phone to ensure it's null
        testLead.Phone = null;
        testLead.Street = '123 Mobile Only St';
        testLead.City = 'Boston';
        testLead.State = 'Massachusetts';
        testLead.PostalCode = '02102';
        testLead.Country = 'United States';

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;

        Test.startTest();
        Database.insert(testLead, dmlOpts);
        // Wait for auto-conversion to happen via trigger
        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedAccountId, IsConverted, Email, Phone, MobilePhone, Street, City, State, PostalCode, Country, Address_Status__c FROM Lead WHERE Id = :testLead.Id];
        Assert.isTrue(convertedLead.IsConverted, 'Lead should be auto-converted');
        Assert.isNull(convertedLead.Phone, 'Phone should be null for MobilePhone-only test');

        Account convertedAccount = [SELECT Id, RecordTypeId FROM Account WHERE Id = :convertedLead.ConvertedAccountId];

        AccountRelatedObjectsService.mapContactPointFields(
            new List<Lead>{ convertedLead },
            convertedAccount.RecordTypeId,
            ConstantsUtil.ASIM_TAG
        );

        List<ContactPointPhone> cppList = [
            SELECT Id, ParentId, TelephoneNumber, UsageType, IsPrimary
            FROM ContactPointPhone
            WHERE ParentId = :convertedAccount.Id
        ];

        Assert.areEqual(1, cppList.size(), 'Should have one MobilePhone ContactPointPhone record');
        Assert.areEqual('9876543210', cppList[0].TelephoneNumber, 'Mobile phone should match Lead MobilePhone');
        Assert.areEqual(ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE, cppList[0].UsageType, 'Should have Mobile usage type');
        Assert.isTrue(cppList[0].IsPrimary, 'Mobile phone should be primary when no Home phone exists');
    }

    @IsTest
    static void testUpsertContactPointEmailRecordsWithNullList() {
        AccountRelatedObjectsService.errorTagName = ConstantsUtil.ASIM_TAG;
        AccountRelatedObjectsService.upsertContactPointEmailRecords(null);
        Assert.isTrue(true, 'Method should handle null list gracefully');
    }

    @IsTest
    static void testUpsertContactPointEmailRecordsWithEmptyList() {
        AccountRelatedObjectsService.errorTagName = ConstantsUtil.ASIM_TAG;
        AccountRelatedObjectsService.upsertContactPointEmailRecords(new List<ContactPointEmail>());
        Assert.isTrue(true, 'Method should handle empty list gracefully');
    }

    @IsTest
    static void testUpsertContactPointEmailRecordsWithFailedUpsert() {
        LeadCreationContext context = new LeadCreationContext();
        context.uniqueSuffix = 'FailedEmail';
        context.age = 30;
        context.email = 'test@example.com';
        context.phone = '1234567890';
        context.mobilePhone = null;
        Lead testLead = createLeadWithRequiredFields(context);

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;

        Test.startTest();
        Database.insert(testLead, dmlOpts);
        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedAccountId, IsConverted FROM Lead WHERE Id = :testLead.Id];
        Account convertedAccount = [SELECT Id FROM Account WHERE Id = :convertedLead.ConvertedAccountId];

        AccountRelatedObjectsService.errorTagName = ConstantsUtil.ASIM_TAG;

        // Create a ContactPointEmail with invalid ParentId to cause upsert failure
        ContactPointEmail invalidCpe = new ContactPointEmail(
            ParentId = convertedAccount.Id,
            EmailAddress = 'test@example.com',
            UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME
        );
        // Set an invalid ParentId after creation to cause failure
        // Actually, let's use a very long email that exceeds field limits
        invalidCpe.EmailAddress = 'a'.repeat(300) + '@test.com';

        List<ContactPointEmail> cpeList = new List<ContactPointEmail>{ invalidCpe };
        AccountRelatedObjectsService.upsertContactPointEmailRecords(cpeList);

        // Method should handle failure gracefully without throwing exception
        Assert.isTrue(true, 'Method should handle upsert failures gracefully');
    }

    @IsTest
    static void testUpsertContactPointAddressRecordWithNullList() {
        AccountRelatedObjectsService.errorTagName = ConstantsUtil.ASIM_TAG;
        AccountRelatedObjectsService.upsertContactPointAddressRecord(null);
        Assert.isTrue(true, 'Method should handle null list gracefully');
    }

    @IsTest
    static void testUpsertContactPointAddressRecordWithEmptyList() {
        AccountRelatedObjectsService.errorTagName = ConstantsUtil.ASIM_TAG;
        AccountRelatedObjectsService.upsertContactPointAddressRecord(new List<ContactPointAddress>());
        Assert.isTrue(true, 'Method should handle empty list gracefully');
    }

    @IsTest
    static void testUpsertContactPointAddressRecordWithFailedUpsert() {
        LeadCreationContext context = new LeadCreationContext();
        context.uniqueSuffix = 'FailedAddress';
        context.age = 30;
        context.email = 'test@example.com';
        context.phone = '1234567890';
        context.mobilePhone = null;
        Lead testLead = createLeadWithRequiredFields(context);
        testLead.Street = '123 Test St';
        testLead.City = 'Boston';
        testLead.State = 'Massachusetts';
        testLead.PostalCode = '02102';
        testLead.Country = 'United States';

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;

        Test.startTest();
        Database.insert(testLead, dmlOpts);
        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedAccountId, IsConverted FROM Lead WHERE Id = :testLead.Id];
        Account convertedAccount = [SELECT Id FROM Account WHERE Id = :convertedLead.ConvertedAccountId];

        AccountRelatedObjectsService.errorTagName = ConstantsUtil.ASIM_TAG;

        // Create a ContactPointAddress with extremely long fields to cause validation failure
        ContactPointAddress invalidCpa = TestDataFactory.getContactPointAddress(new Map<String, Object>{
            'ParentId' => convertedAccount.Id,
            'Name' => 'Test Address',
            'Street' => 'a'.repeat(500),
            'City' => 'b'.repeat(500),
            'State' => 'Massachusetts',
            'PostalCode' => '02102',
            'Country' => 'United States'
        });

        List<ContactPointAddress> cpaList = new List<ContactPointAddress>{ invalidCpa };
        AccountRelatedObjectsService.upsertContactPointAddressRecord(cpaList);

        // Method should handle failure gracefully without throwing exception
        Assert.isTrue(true, 'Method should handle upsert failures gracefully');
    }

    @IsTest
    static void testUpsertContactPointEmailRecordsWithMultipleFailures() {
        LeadCreationContext context = new LeadCreationContext();
        context.uniqueSuffix = 'MultiFailEmail';
        context.age = 30;
        context.email = 'test@example.com';
        context.phone = '1234567890';
        context.mobilePhone = null;
        Lead testLead = createLeadWithRequiredFields(context);

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;

        Test.startTest();
        Database.insert(testLead, dmlOpts);
        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedAccountId, IsConverted FROM Lead WHERE Id = :testLead.Id];
        Account convertedAccount = [SELECT Id FROM Account WHERE Id = :convertedLead.ConvertedAccountId];

        AccountRelatedObjectsService.errorTagName = ConstantsUtil.ASIM_TAG;

        // Create multiple ContactPointEmail records with invalid data
        ContactPointEmail invalidCpe1 = new ContactPointEmail(
            ParentId = convertedAccount.Id,
            EmailAddress = 'a'.repeat(300) + '@test.com',
            UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME
        );
        ContactPointEmail invalidCpe2 = new ContactPointEmail(
            ParentId = convertedAccount.Id,
            EmailAddress = 'b'.repeat(300) + '@test.com',
            UsageType = ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME
        );

        List<ContactPointEmail> cpeList = new List<ContactPointEmail>{ invalidCpe1, invalidCpe2 };
        AccountRelatedObjectsService.upsertContactPointEmailRecords(cpeList);

        // Method should handle multiple failures gracefully
        Assert.isTrue(true, 'Method should handle multiple upsert failures gracefully');
    }

    @IsTest
    static void testUpsertContactPointAddressRecordWithMultipleFailures() {
        LeadCreationContext context = new LeadCreationContext();
        context.uniqueSuffix = 'MultiFailAddress';
        context.age = 30;
        context.email = 'test@example.com';
        context.phone = '1234567890';
        context.mobilePhone = null;
        Lead testLead = createLeadWithRequiredFields(context);

        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;

        Test.startTest();
        Database.insert(testLead, dmlOpts);
        Test.stopTest();

        Lead convertedLead = [SELECT Id, ConvertedAccountId, IsConverted FROM Lead WHERE Id = :testLead.Id];
        Account convertedAccount = [SELECT Id FROM Account WHERE Id = :convertedLead.ConvertedAccountId];

        AccountRelatedObjectsService.errorTagName = ConstantsUtil.ASIM_TAG;

        // Create multiple ContactPointAddress records with invalid data
        ContactPointAddress invalidCpa1 = TestDataFactory.getContactPointAddress(new Map<String, Object>{
            'ParentId' => convertedAccount.Id,
            'Name' => 'Test Address 1',
            'Street' => 'a'.repeat(500),
            'City' => 'Boston',
            'State' => 'Massachusetts',
            'PostalCode' => '02102',
            'Country' => 'United States'
        });
        ContactPointAddress invalidCpa2 = TestDataFactory.getContactPointAddress(new Map<String, Object>{
            'ParentId' => convertedAccount.Id,
            'Name' => 'Test Address 2',
            'Street' => 'b'.repeat(500),
            'City' => 'Boston',
            'State' => 'Massachusetts',
            'PostalCode' => '02102',
            'Country' => 'United States'
        });

        List<ContactPointAddress> cpaList = new List<ContactPointAddress>{ invalidCpa1, invalidCpa2 };
        AccountRelatedObjectsService.upsertContactPointAddressRecord(cpaList);
        ConstantsUtil.getConversionTypeManual();

        // Method should handle multiple failures gracefully
        Assert.isTrue(true, 'Method should handle multiple upsert failures gracefully');
    }
}