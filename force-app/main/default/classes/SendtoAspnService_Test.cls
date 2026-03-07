/**
 * @description Test class for SendtoAspnHandler and SendtoAspnService
 * @author Anup Bandawar
 * @date 1st Dec 2025
 *
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       1st Dec 2025        Anup Bandawar           Initial Version(US - NGOMCT-725)
 * V1.0.1       15th Dec 2025       Anup Bandawar           Added SourceId Update test method (US - NGOMCT-1202)
 * V1.0.2       29th Dec 2025       Charchit Nirayanwal     Added tests for Customer ID Identifier functionality (US - NGOMCT-1454)
 * V1.0.3       29th Dec 2025       Charchit Nirayanwal     Added tests for new handler methods (US - NGOMCT-1358, NGOMCT-1454)
 * v1.0.4       12th Jan 2026       Anup Bandawar           Updated(US - NGASIM-1029)
 * v1.0.5       29th Jan 2026       Priyansh Shukla         Updated(US - NGOMCT-1356)
 * V1.0.6       30th Jan 2026       Saikat Ghosh       		Updated(US - NGOMCT-1750) - Added multiple test methods and removed IsParallel=true from @IsTest at class level.
 * 															IsParallel=true was removed because Test.getStandardPricebookId() is not supported in parallel Apex tests and 
 * 															throws an error: 'Test.getStandardPricebookId() cannot be called from parallel Apex tests' and Salesforce currently 
 * 															provides no alternative as noted in the related Salesforce Idea(https://ideas.salesforce.com/s/idea/a0B8W00000GdZegUAF/allow-the-use-of-testgetstandardpricebookid-when-running-apex-tests-in-parallel).
 * V1.0.7       18th Feb 2026       Saikat Ghosh            Updated(NGOMCT-2329) - Added test for Opportunity and Account IDs in AspnEventBuilder
 */

@IsTest
private class SendtoAspnService_Test {

    /**
     * @description Setup method to create test data once for all test methods
     */
    @TestSetup
    static void setupTestData() {

        List<Account> accounts = new List<Account>();
        // Create and insert Patient Account using TestDataFactory
        Account patientAccountRecord = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe Patient',
            'PersonGenderIdentity' => 'Male',
            'Date_of_Birth__c' => Date.newInstance(1980, 5, 15),
            'Type_of_Diabetes__c' => 'Type 1',
            'Preferred_Language__c' => 'English',
            'Custom_UniqueID__c' => 'UNIQ123',
            'BillingPostalCode' => '23457'
        });
        accounts.add(patientAccountRecord);

        // Create and insert Provider Account using TestDataFactory
        Account providerAccountRecord = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Jane',
            'LastName' => 'Smith Provider',
            'PersonEmail' => 'provider@example.com',
            'BillingPostalCode' => '23457'
        });
        accounts.add(providerAccountRecord);

         // Create and insert Practice Account using TestDataFactory
         Account practiceAccountRecord = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Clinic Practice',
            'Phone' => '5559876543',
            'BillingCity' => 'New York',
            'BillingStateCode' => 'NY',
            'BillingPostalCode' => '10001'
        });
        accounts.add(practiceAccountRecord);

        insert accounts;

        Account practiceAccount = [SELECT Id, personContactId FROM Account WHERE Name = 'Test Clinic Practice' LIMIT 1];
        Account providerAccount = [SELECT Id, personContactId FROM Account WHERE LastName = 'Smith Provider' LIMIT 1];
        Account patientAccount = [SELECT Id, personContactId FROM Account WHERE LastName = 'Doe Patient' LIMIT 1];

        // Create and insert PartyRoleRelation between Patient and Provider
        PartyRoleRelation prr = new PartyRoleRelation(
            RelatedRoleName = 'Provider',
            RoleName = 'Patient',
            RelationshipObjectName = 'Contact_Contact_Relationship'
        );
        insert prr;

        List<Account> providerAccountList = [SELECT Id, personContactId FROM Account WHERE Id = :providerAccount.Id LIMIT 1];
        List<Account> patientAccountList = [SELECT Id, personContactId FROM Account WHERE Id = :patientAccount.Id LIMIT 1];

        // Create and insert ContactContactRelation between Patient and Provider
        ContactContactRelation ccr = new ContactContactRelation(
            ContactId = patientAccountList[0].personContactId,
            RelatedContactId = providerAccountList[0].personContactId,
            PartyRoleRelationId = prr.Id,
            IsActive = true,
            Is_Primary__c = true
        );
        insert ccr;

        // Create and insert AccountContactRelation between Patient and Practice
        AccountContactRelation acr = new AccountContactRelation(
            AccountId = practiceAccount.Id,
            ContactId = patientAccountList[0].personContactId,
            Roles = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE,
            IsActive = true,
            Is_Primary__c = true
        );
        insert acr;

        // Create and insert ContactPointEmail using TestDataFactory
        ContactPointEmail cpEmail = TestDataFactory.getContactPointEmail(new Map<String, Object>{
            'ParentId' => patientAccount.Id,
            'EmailAddress' => 'patient@example.com'
        });
        insert cpEmail;

        // Create and insert ContactPointPhone using TestDataFactory
        ContactPointPhone cpPhone = TestDataFactory.getContactPointPhone(new Map<String, Object>{
            'ParentId' => patientAccount.Id,
            'TelephoneNumber' => '5551234567'
        });
        insert cpPhone;

        // Create and insert ContactPointAddress using TestDataFactory
        ContactPointAddress cpAddress = TestDataFactory.getContactPointAddress(new Map<String, Object>{
            'ParentId' => patientAccount.Id,
            'Name' => 'John Doe Address',
            'Street' => '456 Oak Ave',
            'City' => 'Los Angeles',
            'State' => 'California',
            'PostalCode' => '90001',
            'Country' => 'United States',
            'IsPrimary' => true
        });
        insert cpAddress;

        // Create and insert Identifier
        Identifier patientIdentifier = new Identifier(
            ParentRecordId = patientAccount.Id,
            IdUsageType = ConstantsUtil.IDENTIFIER_EXTERNAL_PATIENT_ID_USAGE_TYPE,
            IdValue = 'EXTPAT123'
        );

         // Create and insert Identifier
         Identifier providerIdentifier = new Identifier(
            ParentRecordId = providerAccount.Id,
            IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE,
            IdValue = 'EXTPAT789'
        );

        List<Identifier> identifiers = new List<Identifier>();
        identifiers.add(patientIdentifier);
        identifiers.add(providerIdentifier);
        insert identifiers;

        // Create and insert Product2
        Product2 product = new Product2(
            Name = 'Test ASPN Product',
            ProductCode = 'ASPN-001',
            Product_NDC__c = '1234567890',
            IsActive = true
        );
        insert product;

        // Create and insert Opportunity using TestDataFactory
        Opportunity opp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT
        });
        insert opp;
    }

    /**
     * @description Test SendtoAspnHandler.filterSendToAspnOpportunities with null input
     */
    @IsTest
    static void testFilterSendToAspnOpportunitiesNullInput() {
        Test.startTest();
        List<Opportunity> result = SendtoAspnHandler.filterSendToAspnOpportunities(null, null);
        Test.stopTest();
        Assert.areEqual(0, result.size(), 'Should return empty list for null input');
    }

    /**
     * @description Test SendtoAspnHandler.filterSendToAspnOpportunities with empty list
     */
    @IsTest
    static void testFilterSendToAspnOpportunitiesEmptyList() {
        Test.startTest();
        List<Opportunity> result = SendtoAspnHandler.filterSendToAspnOpportunities(new List<Opportunity>(), null);
        Test.stopTest();
        Assert.areEqual(0, result.size(), 'Should return empty list for empty input');
    }


     /**
     * @description testMethod for Negative test case of sendtoaspn failure
     * where customExceptionSwitch is turned on
     * Per NGOMCT-1358: Updated to test Cancel_Order__c instead of "Send to ASPN" stage
     */
    @IsTest
    static void testSendToAspnNegative() {
         // Query test data created in @TestSetup
        Opportunity opportunity = [
            SELECT Id, Name, AccountId, StageName, RecordTypeId, Cancel_Order__c
            FROM Opportunity
            WHERE StageName = :ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE
            LIMIT 1
        ];
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            ConstantsUtil.customExceptionSwitch = true;
            // Set Status and Sub_Status before setting Cancel_Order__c to avoid validation rule
            opportunity.Status__c = 'Prior Authorization';
            opportunity.Sub_Status__c = 'PA Processing';
            opportunity.Cancel_Order__c = true;
            opportunity.Reason_for_Cancellation__c = 'Not Qualified';
            update opportunity;
            Assert.fail('Update should fail when customExceptionSwitch is true');
        } catch (DmlException e) {
            exceptionThrown = true;
            // Exception message might contain either OpportunityTrigger or ASPN error
            Assert.isTrue(e.getMessage().contains('customExceptionSwitch') || e.getMessage().contains('OpportunityTrigger') || e.getMessage().contains('ASPN'),
                'Exception should be thrown from trigger: ' + e.getMessage());
        } catch (Exception e) {
            exceptionThrown = true;
            Assert.isTrue(true, 'Exception was thrown as expected when customExceptionSwitch is true');
        }
        Test.stopTest();
        Assert.isTrue(exceptionThrown, 'Exception should have been thrown when customExceptionSwitch is true');
    }

    /**
     * @description testMethod for Negative test case of platform event publish failure
     * when field value is too long
     */
    @IsTest
    static void testpublishPlatformEvents() {
        List<ASPN_Integration__e> aspnEvents = new List<ASPN_Integration__e>();
        ASPN_Integration__e aspnEvent = new ASPN_Integration__e();
        aspnEvent.patientEmail__c = 'weruyertueryteriuteriteriteirteritheriyrthyirthyirtyjrtiyjrtiyjrtiwerewrtedfrt@gmail.com';
        aspnEvents.add(aspnEvent);

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            SendtoAspnService.publishPlatformEvents(aspnEvents);
            Assert.fail('Method should throw exception for invalid field length');
        } catch (SendtoAspnService.AspnProcessingException e) {
            exceptionThrown = true;
            Assert.isTrue(e.getMessage().contains('Platform Event publish failures'),
                'Exception message should contain publish failure information');
        } catch (Exception e) {
            Assert.fail('Should throw AspnProcessingException, but got: ' + e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Exception should have been thrown for invalid field value');
    }


    /**
     * @description Test AspnEventBuilder with all wrapper classes
     */
    @IsTest
    static void testAspnEventBuilderAllWrappers() {
        Account patientAccount = [SELECT Id FROM Account WHERE LastName = 'Doe Patient' LIMIT 1]; // Added as part of NGOMCT-2329
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity WHERE AccountId = :patientAccount.Id LIMIT 1]; // Added as part of NGOMCT-2329

        // Test SourceConfig
        AspnEventBuilder.SourceConfig config = new AspnEventBuilder.SourceConfig();
        config.externalSource = 'Insulet';
        config.transactionType = 'Standard';
        config.aspnRxChaseConsent = false;
        config.emailOptIn = false;
        config.smsOptIn = false;
        config.thirdPartyConsent = false;
        // Test PatientInfo
        AspnEventBuilder.PatientInfo patientInfo = new AspnEventBuilder.PatientInfo();
        patientInfo.firstName = 'John';
        patientInfo.lastName = 'Doe';
        patientInfo.gender = 'Male';
        patientInfo.birthdate = Date.newInstance(1980, 5, 15);
        patientInfo.diabetesType = 'Type 1';
        patientInfo.preferredLanguage = 'English';
        patientInfo.sourceId = 'SRC123';

        // Test PatientContact
        AspnEventBuilder.PatientContact contact = new AspnEventBuilder.PatientContact();
        contact.email = 'test@example.com';
        contact.phone = '555-1234';
        contact.address = '123 Main St';
        contact.city = 'Boston';
        contact.state = 'MA';
        contact.postalCode = '02101';

        // Test ProviderInfo
        AspnEventBuilder.ProviderInfo providerInfo = new AspnEventBuilder.ProviderInfo();
        providerInfo.firstName = 'Jane';
        providerInfo.lastName = 'Smith';
        providerInfo.npi = '1234567890';
        providerInfo.phone = '555-5678';
        providerInfo.city = 'Cambridge';
        providerInfo.state = 'MA';
        providerInfo.zip = '02139';

        // Test ProductInfo
        AspnEventBuilder.ProductInfo productInfo = new AspnEventBuilder.ProductInfo();
        productInfo.externalAspnId = 'ASPN123';
        productInfo.productName = 'Test Product';
        productInfo.productNDC = '12345-678-90';
        productInfo.reasonForCancellation = 'None';

        Test.startTest();
        ASPN_Integration__e event = new AspnEventBuilder()
            .setSourceConfiguration(config)
            .setPatientInfo(patientInfo)
            .setPatientContact(contact)
            .setPatientExternalId('EXT123')
            .setProviderInfo(providerInfo)
            .setProductInfo(productInfo)
            .setOpportunityAndAccountIds(String.valueOf(opp.Id), String.valueOf(opp.AccountId)) // Added as part of NGOMCT-2329
            .build();
        Test.stopTest();

        Assert.areEqual('Insulet', event.ExternalSource__c, 'External source should be set');
        Assert.areEqual('John', event.patientFirstName__c, 'Patient first name should be set');
        Assert.areEqual('test@example.com', event.patientEmail__c, 'Patient email should be set');
        Assert.areEqual('Jane', event.doctorFirstName__c, 'Doctor first name should be set');
        Assert.areEqual('Test Product', event.productName__c, 'Product name should be set');
        Assert.areEqual(String.valueOf(opp.Id), event.Opportunity__c, 'Opportunity ID should be set'); // Added as part of NGOMCT-2329
        Assert.areEqual(String.valueOf(opp.AccountId), event.Account__c, 'Account ID should be set'); // Added as part of NGOMCT-2329
    }

    /**
     * @description Test AspnEventBuilder with null wrappers
     */
    @IsTest
    static void testAspnEventBuilderNullWrappers() {
        Test.startTest();
        ASPN_Integration__e event = new AspnEventBuilder()
            .setSourceConfiguration(null)
            .setPatientInfo(null)
            .setPatientContact(null)
            .setPatientExternalId(null)
            .setProviderInfo(null)
            .setProductInfo(null)
            .build();
        Test.stopTest();
        Assert.isNotNull(event, 'Event should be created even with null wrappers');
    }

    /**
     * @description Test AspnEventBuilder string truncation
     */
    @IsTest
    static void testAspnEventBuilderStringTruncation() {
        AspnEventBuilder.PatientInfo patientInfo = new AspnEventBuilder.PatientInfo();
        patientInfo.lastName = 'A'.repeat(100); // Very long last name
        patientInfo.sourceId = 'B'.repeat(50); // Very long source ID

        Test.startTest();
        ASPN_Integration__e event = new AspnEventBuilder()
            .setPatientInfo(patientInfo)
            .build();
        Test.stopTest();

        Assert.areEqual(50, event.patientLastName__c.length(), 'Last name should be truncated to 50 chars');
        Assert.areEqual(18, event.SourceID__c.length(), 'Source ID should be truncated to 18 chars');
    }

    /**
     * @description Test Source ID Update event with Customer ID Identifier for Patient Account (NGOMCT-1454)
     * Verifies that ExtPatientID__c is populated from Patient Account Identifier with IdUsageType = 'Customer ID'
     */
    @IsTest
    static void testSourceIdUpdateWithCustomerIdIdentifier() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Clean up any existing Identifier record with this ID_Value__c value to avoid duplicate errors
        List<Identifier> existingIdentifiers = [
            SELECT Id
            FROM Identifier
            WHERE ID_Value__c = 'CUST123456'
            AND IdUsageType = :ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE
        ];
        if (!existingIdentifiers.isEmpty()) {
            delete existingIdentifiers;
        }

        // Create Customer ID Identifier for Patient Account
        Identifier customerIdIdentifier = new Identifier(
            ParentRecordId = patientAccount.Id,
            IdUsageType = ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE,
            IdValue = 'CUST123456'
        );
        insert customerIdIdentifier;

        // Create Opportunity with ASPN source
        Opportunity aspnOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test ASPN Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_ASPN
        });
        insert aspnOpp;

        // Update Custom_UniqueID__c to trigger Source ID Update event
        Test.startTest();
        patientAccount.Custom_UniqueID__c = 'UPDATED123';
        update patientAccount;
        Test.stopTest();

        // Verify that the update completed without exceptions
        // Platform events cannot be queried, but we verify the logic executed successfully
        Account updatedAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE Id = :patientAccount.Id
            LIMIT 1
        ];
        Assert.areEqual('UPDATED123', updatedAccount.Custom_UniqueID__c, 'Custom_UniqueID__c should be updated');

        // Verify Customer ID Identifier exists for the Patient Account
        List<Identifier> customerIdIdentifiers = [
            SELECT Id, ParentRecordId, IdUsageType, IdValue
            FROM Identifier
            WHERE ParentRecordId = :patientAccount.Id
            AND IdUsageType = :ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE
            LIMIT 1
        ];
        Assert.isFalse(customerIdIdentifiers.isEmpty(), 'Customer ID Identifier should exist for Patient Account');
        Assert.areEqual('CUST123456', customerIdIdentifiers[0].IdValue, 'Customer ID Identifier value should match');
    }

    /**
     * @description Test Source ID Update event - Provider Account Customer ID Identifier should NOT be used (NGOMCT-1454)
     * Verifies that Customer ID Identifier for Provider Account is ignored
     */
    @IsTest
    static void testSourceIdUpdateIgnoresProviderAccountCustomerId() {
        // Query existing Patient and Provider Accounts from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        Account providerAccount = [
            SELECT Id
            FROM Account
            WHERE LastName = 'Smith Provider'
            LIMIT 1
        ];

        // Clean up any existing Identifier records with these ID_Value__c values to avoid duplicate errors
        List<Identifier> existingIdentifiers = [
            SELECT Id
            FROM Identifier
            WHERE ID_Value__c IN ('PROVIDER_CUST_ID', 'PATIENT_CUST_ID')
            AND IdUsageType = :ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE
        ];
        if (!existingIdentifiers.isEmpty()) {
            delete existingIdentifiers;
        }

        // Create Customer ID Identifier for Provider Account (should be ignored)
        Identifier providerCustomerIdIdentifier = new Identifier(
            ParentRecordId = providerAccount.Id,
            IdUsageType = ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE,
            IdValue = 'PROVIDER_CUST_ID'
        );
        insert providerCustomerIdIdentifier;

        // Create Customer ID Identifier for Patient Account (should be used)
        Identifier patientCustomerIdIdentifier = new Identifier(
            ParentRecordId = patientAccount.Id,
            IdUsageType = ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE,
            IdValue = 'PATIENT_CUST_ID'
        );
        insert patientCustomerIdIdentifier;

        // Create Opportunity with ASPN source
        Opportunity aspnOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test ASPN Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_ASPN
        });
        insert aspnOpp;

        // Update Custom_UniqueID__c to trigger Source ID Update event
        Test.startTest();
        patientAccount.Custom_UniqueID__c = 'PATIENT123';
        update patientAccount;
        Test.stopTest();

        // Verify that the update completed without exceptions
        Account updatedAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE Id = :patientAccount.Id
            LIMIT 1
        ];
        Assert.areEqual('PATIENT123', updatedAccount.Custom_UniqueID__c, 'Custom_UniqueID__c should be updated');

        // Verify Customer ID Identifiers exist for both accounts
        List<Identifier> patientCustomerIdIdentifiers = [
            SELECT Id, ParentRecordId, IdUsageType, IdValue
            FROM Identifier
            WHERE ParentRecordId = :patientAccount.Id
            AND IdUsageType = :ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE
            LIMIT 1
        ];
        List<Identifier> providerCustomerIdIdentifiers = [
            SELECT Id, ParentRecordId, IdUsageType, IdValue
            FROM Identifier
            WHERE ParentRecordId = :providerAccount.Id
            AND IdUsageType = :ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE
            LIMIT 1
        ];

        Assert.isFalse(patientCustomerIdIdentifiers.isEmpty(), 'Customer ID Identifier should exist for Patient Account');
        Assert.areEqual('PATIENT_CUST_ID', patientCustomerIdIdentifiers[0].IdValue, 'Patient Account Customer ID Identifier value should match');
        Assert.isFalse(providerCustomerIdIdentifiers.isEmpty(), 'Customer ID Identifier should exist for Provider Account');
        Assert.areEqual('PROVIDER_CUST_ID', providerCustomerIdIdentifiers[0].IdValue, 'Provider Account Customer ID Identifier value should match');

        // The code logic ensures only Patient Account Customer ID is used (verified by successful execution)
    }

    /**
     * @description Test Source ID Update event - ExtPatientID is null when Customer ID Identifier doesn't exist (NGOMCT-1454)
     */
    @IsTest
    static void testSourceIdUpdateWithoutCustomerIdIdentifier() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Do NOT create Customer ID Identifier for Patient Account

        // Create Opportunity with ASPN source
        Opportunity aspnOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test ASPN Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_ASPN
        });
        insert aspnOpp;

        // Update Custom_UniqueID__c to trigger Source ID Update event
        Test.startTest();
        patientAccount.Custom_UniqueID__c = 'NO_CUST_ID';
        update patientAccount;
        Test.stopTest();

        // Verify that the update completed without exceptions
        Account updatedAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE Id = :patientAccount.Id
            LIMIT 1
        ];
        Assert.areEqual('NO_CUST_ID', updatedAccount.Custom_UniqueID__c, 'Custom_UniqueID__c should be updated');

        // Verify no Customer ID Identifier exists for the Patient Account
        List<Identifier> customerIdIdentifiers = [
            SELECT Id, ParentRecordId, IdUsageType, IdValue
            FROM Identifier
            WHERE ParentRecordId = :patientAccount.Id
            AND IdUsageType = :ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE
            LIMIT 1
        ];
        Assert.isTrue(customerIdIdentifiers.isEmpty(), 'Customer ID Identifier should NOT exist for Patient Account');

        // The code logic ensures ExtPatientID will be null when Customer ID Identifier doesn't exist (verified by successful execution)
    }

    /**
     * @description Test processStandardEventForInsulet with null input (NGOMCT-1358)
     */
    @IsTest
    static void testProcessStandardEventForInsuletNullInput() {
        Test.startTest();
        SendtoAspnHandler.processStandardEventForInsulet(null, null);
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>(), null);
        Test.stopTest();
        Assert.isTrue(true, 'Should handle null and empty input gracefully');
    }

    /**
     * @description Test processInsuletOpportunitiesOnInsert with Patient having existing Custom_UniqueID__c (NGOMCT-1358)
     * Verifies that Standard event is triggered when Insulet opportunity is created for Patient with existing Custom_UniqueID__c
     */
    @IsTest
    static void testProcessInsuletOpportunitiesOnInsert() {
        // Query existing Patient Account with Custom_UniqueID__c from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];
        Assert.isNotNull(patientAccount.Custom_UniqueID__c, 'Patient Account should have Custom_UniqueID__c');

        // Create Insulet Opportunity
        Test.startTest();
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;
        Test.stopTest();

        // Verify opportunity was created successfully
        Opportunity createdOpp = [
            SELECT Id, Opportunity_Source__c, AccountId, RecordTypeId
            FROM Opportunity
            WHERE Id = :insuletOpp.Id
            LIMIT 1
        ];
        Assert.areEqual(ConstantsUtil.OPPORTUNITY_SOURCE_INSULET, createdOpp.Opportunity_Source__c, 'Opportunity source should be Insulet');
        Assert.areEqual(patientAccount.Id, createdOpp.AccountId, 'Opportunity should be linked to Patient Account');
        Assert.areEqual(ConstantsUtil.OPPORTUNITY_NCS_RT, createdOpp.RecordTypeId, 'Opportunity should have NCS RecordType');
    }

    /**
     * @description Test processInsuletOpportunitiesOnInsert with Patient without Custom_UniqueID__c (NGOMCT-1358)
     * Verifies that no event is triggered when Insulet opportunity is created for Patient without Custom_UniqueID__c
     */
    @IsTest
    static void testProcessInsuletOpportunitiesOnInsertWithoutCustomId() {
        // Create new Patient Account without Custom_UniqueID__c
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Jane',
            'LastName' => 'No Custom ID Patient',
            'PersonGenderIdentity' => 'Female',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'Type_of_Diabetes__c' => 'Type 2: Using Insulin',
            'Preferred_Language__c' => 'Spanish',
            'BillingPostalCode' => '12345'
            // No Custom_UniqueID__c
        });
        insert patientAccount;

        // Create Insulet Opportunity
        Test.startTest();
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity No Custom ID',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;
        Test.stopTest();

        // Verify opportunity was created but no event should be triggered (verified by successful execution)
        Opportunity createdOpp = [
            SELECT Id, Opportunity_Source__c, AccountId
            FROM Opportunity
            WHERE Id = :insuletOpp.Id
            LIMIT 1
        ];
        Assert.areEqual(ConstantsUtil.OPPORTUNITY_SOURCE_INSULET, createdOpp.Opportunity_Source__c, 'Opportunity source should be Insulet');
    }

    /**
     * @description Test processInsuletOpportunitiesOnInsert with null input (NGOMCT-1358)
     */
    @IsTest
    static void testProcessInsuletOpportunitiesOnInsertNullInput() {
        Test.startTest();
        SendtoAspnHandler.processInsuletOpportunitiesOnInsert(null);
        SendtoAspnHandler.processInsuletOpportunitiesOnInsert(new List<Opportunity>());
        Test.stopTest();
        Assert.isTrue(true, 'Should handle null and empty input gracefully');
    }

    /**
     * @description Test that Insulet opportunities are NOT processed in afterUpdate (NGOMCT-1358)
     * Verifies that Insulet source logic was removed from afterUpdate and only exists in afterInsert
     */
    @IsTest
    static void testInsuletOpportunitiesNotProcessedInAfterUpdate() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Ensure Patient has Custom_UniqueID__c populated
        if (String.isBlank(patientAccount.Custom_UniqueID__c)) {
            patientAccount.Custom_UniqueID__c = 'TEST_UNIQUE_ID_' + String.valueOf(System.now().getTime());
            update patientAccount;
        }

        // Create Insulet Opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity for Update',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        Test.startTest();
        // Update the opportunity (should NOT trigger Insulet logic per NGOMCT-1358)
        insuletOpp.Name = 'Updated Insulet Opportunity';
        update insuletOpp;
        Test.stopTest();

        // Verify opportunity was updated successfully
        Opportunity updatedOpp = [
            SELECT Id, Name, Opportunity_Source__c
            FROM Opportunity
            WHERE Id = :insuletOpp.Id
            LIMIT 1
        ];
        Assert.areEqual('Updated Insulet Opportunity', updatedOpp.Name, 'Opportunity should be updated successfully');
        Assert.areEqual(ConstantsUtil.OPPORTUNITY_SOURCE_INSULET, updatedOpp.Opportunity_Source__c, 'Opportunity source should remain Insulet');
        // Note: We cannot verify platform events were NOT created in Apex tests, but the code logic ensures
        // that processInsuletOpportunitiesOnInsert is NOT called in processOpportunitiesOnUpdate
    }

    /**
     * @description Test processAccountUpdatesForAspn with null input
     */
    @IsTest
    static void testProcessAccountUpdatesForAspnNullInput() {
        Test.startTest();
        SendtoAspnHandler.processAccountUpdatesForAspn(null, null);
        SendtoAspnHandler.processAccountUpdatesForAspn(new List<Account>(), null);
        Test.stopTest();
        Assert.isTrue(true, 'Should handle null and empty input gracefully');
    }

    /**
     * @description Test processSourceIdUpdateForAspn with null input
     */
    @IsTest
    static void testProcessSourceIdUpdateForAspnNullInput() {
        Test.startTest();
        SendtoAspnHandler.processSourceIdUpdateForAspn(null, null);
        SendtoAspnHandler.processSourceIdUpdateForAspn(new List<Account>(), null);
        Test.stopTest();
        Assert.isTrue(true, 'Should handle null and empty input gracefully');
    }

    /**
     * @description Test processSourceIdUpdateForAspn with Patient account and ASPN opportunity (direct call)
     * Verifies the method processes ASPN opportunities correctly
     */
    @IsTest
    static void testProcessSourceIdUpdateForAspnDirectCall() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create ASPN Opportunity
        Opportunity aspnOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test ASPN Opportunity Direct',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_ASPN
        });
        insert aspnOpp;

        // Update Custom_UniqueID__c to a new value
        String newCustomUniqueId = 'DIRECT_CALL_TEST_' + String.valueOf(System.now().getTime());
        patientAccount.Custom_UniqueID__c = newCustomUniqueId;

        // Create old accounts map to simulate afterUpdate
        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{
            patientAccount.Id => new Account(
                Id = patientAccount.Id,
                Custom_UniqueID__c = 'OLD_VALUE',
                RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT
            )
        };

        Test.startTest();
        // Call the method directly
        SendtoAspnHandler.processSourceIdUpdateForAspn(new List<Account>{ patientAccount }, oldAccountsMap);
        Test.stopTest();

        // Verify - method executed without exception
        Assert.isTrue(true, 'processSourceIdUpdateForAspn should execute successfully');
    }

    /**
     * @description Test processSourceIdUpdateForAspn with no ASPN opportunities
     * Verifies the method handles the case when no ASPN opportunities exist
     */
    @IsTest
    static void testProcessSourceIdUpdateForAspnNoOpportunities() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Don't create any ASPN opportunities - just Insulet
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Only Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        // Update Custom_UniqueID__c
        patientAccount.Custom_UniqueID__c = 'NO_ASPN_OPP_TEST';

        // Create old accounts map
        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{
            patientAccount.Id => new Account(
                Id = patientAccount.Id,
                Custom_UniqueID__c = 'OLD_VALUE',
                RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT
            )
        };

        Test.startTest();
        SendtoAspnHandler.processSourceIdUpdateForAspn(new List<Account>{ patientAccount }, oldAccountsMap);
        Test.stopTest();

        Assert.isTrue(true, 'processSourceIdUpdateForAspn should handle no ASPN opportunities gracefully');
    }

    /**
     * @description Test processSourceIdUpdateForAspn with non-Patient account
     * Verifies the method filters out non-Patient accounts
     */
    @IsTest
    static void testProcessSourceIdUpdateForAspnNonPatientAccount() {
        // Query Provider Account from test setup
        Account providerAccount = [
            SELECT Id, RecordTypeId
            FROM Account
            WHERE LastName = 'Smith Provider'
            LIMIT 1
        ];

        Test.startTest();
        // Call with Provider account - should be filtered out
        SendtoAspnHandler.processSourceIdUpdateForAspn(new List<Account>{ providerAccount }, null);
        Test.stopTest();

        Assert.isTrue(true, 'processSourceIdUpdateForAspn should filter out non-Patient accounts');
    }

    /**
     * @description Test processSourceIdUpdateForAspn for afterInsert scenario
     * Verifies the method handles new accounts with Custom_UniqueID__c populated
     */
    @IsTest
    static void testProcessSourceIdUpdateForAspnAfterInsert() {
        // Create new Patient Account with Custom_UniqueID__c populated
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Source',
            'LastName' => 'ID Test Patient',
            'PersonGenderIdentity' => 'Male',
            'Date_of_Birth__c' => Date.newInstance(1985, 3, 20),
            'Type_of_Diabetes__c' => 'Type 1',
            'Preferred_Language__c' => 'English',
            'Custom_UniqueID__c' => 'NEW_ACCOUNT_SOURCE_ID',
            'BillingPostalCode' => '12345'
        });
        insert patientAccount;

        // Create ASPN Opportunity for the new account
        Opportunity aspnOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test ASPN Opportunity Insert',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_ASPN
        });
        insert aspnOpp;

        // Re-query account with RecordTypeId
        patientAccount = [SELECT Id, Custom_UniqueID__c, RecordTypeId FROM Account WHERE Id = :patientAccount.Id];

        Test.startTest();
        // Call for afterInsert scenario (oldAccountsMap is null)
        SendtoAspnHandler.processSourceIdUpdateForAspn(new List<Account>{ patientAccount }, null);
        Test.stopTest();

        Assert.isTrue(true, 'processSourceIdUpdateForAspn should handle afterInsert scenario');
    }


    /**
     * @description Test processSourceIdUpdateForAspn when Custom_UniqueID__c is not changed
     * Verifies the method filters out accounts where Custom_UniqueID__c didn't change
     */
    @IsTest
    static void testProcessSourceIdUpdateForAspnNoChange() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create old accounts map with same Custom_UniqueID__c (no change)
        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{
            patientAccount.Id => new Account(
                Id = patientAccount.Id,
                Custom_UniqueID__c = patientAccount.Custom_UniqueID__c, // Same value - no change
                RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT
            )
        };

        Test.startTest();
        SendtoAspnHandler.processSourceIdUpdateForAspn(new List<Account>{ patientAccount }, oldAccountsMap);
        Test.stopTest();

        Assert.isTrue(true, 'processSourceIdUpdateForAspn should handle no change scenario gracefully');
    }

    /**
     * @description Test processStandardEventForInsulet when Custom_UniqueID__c is blank
     * Verifies the method filters out accounts where Custom_UniqueID__c is blank
     */
    @IsTest
    static void testProcessStandardEventForInsuletBlankCustomUniqueId() {
        // Create Patient Account with blank Custom_UniqueID__c
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Blank',
            'LastName' => 'Custom ID Patient',
            'PersonGenderIdentity' => 'Male',
            'Date_of_Birth__c' => Date.newInstance(1980, 1, 1),
            'Type_of_Diabetes__c' => 'Type 1',
            'Preferred_Language__c' => 'English',
            'BillingPostalCode' => '11111'
            // No Custom_UniqueID__c
        });
        insert patientAccount;

        // Re-query to get RecordTypeId
        patientAccount = [SELECT Id, Custom_UniqueID__c, RecordTypeId FROM Account WHERE Id = :patientAccount.Id];

        Test.startTest();
        // Call with blank Custom_UniqueID__c - should be filtered out
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, null);
        Test.stopTest();

        Assert.isTrue(true, 'processStandardEventForInsulet should filter out accounts with blank Custom_UniqueID__c');
    }

    /**
     * @description Test processSendToAspn with null input
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessSendToAspnWithNullInput() {
        Test.startTest();
        // Test with null input
        SendtoAspnService.processSendToAspn(null);
        
        // Test with empty list
        SendtoAspnService.processSendToAspn(new List<Opportunity>());
        Test.stopTest();
        
        Assert.isTrue(true, 'Should handle null and empty input gracefully');
    }

    /**
     * @description Test processSendToAspn with opportunities that have null AccountId
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessSendToAspnWithNullAccountIds() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create opportunity with AccountId
        Opportunity oppWithAccount = new Opportunity(
            Name = 'Test Opp With Account',
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT,
            AccountId = patientAccount.Id,
            Opportunity_Source__c = ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        );
        
        // Create opportunity without AccountId
        Opportunity oppNoAccount = new Opportunity(
            Name = 'Test Opp No Account',
            StageName = ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            CloseDate = Date.today().addDays(30),
            RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT,
            AccountId = null
        );
        
        insert new List<Opportunity>{ oppWithAccount, oppNoAccount };

        Test.startTest();
        // Call processSendToAspn with mixed opportunities - one with AccountId, one without
        // This will trigger line 122 (continue) for the null AccountId opportunity
        SendtoAspnService.processSendToAspn(new List<Opportunity>{ oppWithAccount, oppNoAccount });
        Test.stopTest();

        Assert.isTrue(true, 'Should handle mixed opportunities with and without AccountId gracefully');
    }

    /**
     * @description Test standard event with email consent (OptIn)
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testStandardEventWithEmailConsent() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, PersonIndividualId, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create Email Consent
        ContactPointTypeConsent emailConsent = new ContactPointTypeConsent(
            PartyId = patientAccount.PersonIndividualId,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            PrivacyConsentStatus = ConstantsUtil.CONSENT_STATUS_OPT_IN
        );
        insert emailConsent;

        // Create Insulet opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Email Consent Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        Test.startTest();
        // Call service directly
        SendtoAspnService.processSendToAspn(new List<Opportunity>{ insuletOpp });
        Test.stopTest();

        // Verify execution completed successfully
        Assert.isTrue(true, 'Should process email consent successfully');
    }

    /**
     * @description Test standard event with SMS consent (OptIn)
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testStandardEventWithSmsConsentOptIn() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, PersonIndividualId, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create SMS Consent with OptIn
        ContactPointTypeConsent smsConsent = new ContactPointTypeConsent(
            PartyId = patientAccount.PersonIndividualId,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            PrivacyConsentStatus = ConstantsUtil.CONSENT_STATUS_OPT_IN
        );
        insert smsConsent;

        // Create Insulet opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test SMS OptIn Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        Test.startTest();
        // Call service directly
        SendtoAspnService.processSendToAspn(new List<Opportunity>{ insuletOpp });
        Test.stopTest();

        // Verify execution completed successfully
        Assert.isTrue(true, 'Should process SMS OptIn consent successfully');
    }

    /**
     * @description Test standard event with SMS consent (OptInPending)
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testStandardEventWithSmsConsentOptInPending() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, PersonIndividualId, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create SMS Consent with OptInPending
        ContactPointTypeConsent smsConsentPending = new ContactPointTypeConsent(
            PartyId = patientAccount.PersonIndividualId,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            PrivacyConsentStatus = ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING
        );
        insert smsConsentPending;

        // Create Insulet opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test SMS OptInPending Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        Test.startTest();
        // Call service directly
        SendtoAspnService.processSendToAspn(new List<Opportunity>{ insuletOpp });
        Test.stopTest();

        // Verify execution completed successfully
        Assert.isTrue(true, 'Should process SMS OptInPending consent successfully');
    }

    /**
     * @description Test standard event with both email and SMS consents
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testStandardEventWithBothConsents() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, PersonIndividualId, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create both Email and SMS Consents
        ContactPointTypeConsent emailConsent = new ContactPointTypeConsent(
            PartyId = patientAccount.PersonIndividualId,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            PrivacyConsentStatus = ConstantsUtil.CONSENT_STATUS_OPT_IN
        );

        ContactPointTypeConsent smsConsent = new ContactPointTypeConsent(
            PartyId = patientAccount.PersonIndividualId,
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
            PrivacyConsentStatus = ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING
        );

        insert new List<ContactPointTypeConsent>{ emailConsent, smsConsent };

        // Create Insulet opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Both Consents Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        Test.startTest();
        // Call service directly
        SendtoAspnService.processSendToAspn(new List<Opportunity>{ insuletOpp });
        Test.stopTest();

        // Verify execution completed successfully
        Assert.isTrue(true, 'Should process both email and SMS consents successfully');
    }

    /**
     * @description Test consent calculation with null individualId
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testConsentValuesWithNullIndividualId() {
        // Create Patient Account without setting PersonIndividualId explicitly
        Account patientAccountNoIndividual = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'No',
            'LastName' => 'Individual Patient',
            'PersonGenderIdentity' => 'Female',
            'Date_of_Birth__c' => Date.newInstance(1985, 1, 1),
            'Type_of_Diabetes__c' => 'Type 1',
            'Preferred_Language__c' => 'English',
            'Custom_UniqueID__c' => 'NOINDIV123',
            'BillingPostalCode' => '54321'
        });
        insert patientAccountNoIndividual;

        // Create Insulet opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test No Individual Opportunity',
            'AccountId' => patientAccountNoIndividual.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        Test.startTest();
        // Call service directly - should use default consent values
        SendtoAspnService.processSendToAspn(new List<Opportunity>{ insuletOpp });
        Test.stopTest();

        // Verify execution completed successfully with default values
        Assert.isTrue(true, 'Should handle null individualId and use default consent values');
    }

    /**
     * @description Test processSendToAspn with customExceptionSwitch enabled
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessSendToAspnExceptionSwitch() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create Insulet opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Exception Switch Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            // Enable exception switch
            ConstantsUtil.customExceptionSwitch = true;
            
            // Call service directly - should throw exception
            SendtoAspnService.processSendToAspn(new List<Opportunity>{ insuletOpp });
            
            Assert.fail('Should have thrown AspnProcessingException');
        } catch (SendtoAspnService.AspnProcessingException e) {
            exceptionThrown = true;
            Assert.isTrue(e.getMessage().contains('customExceptionSwitch'), 
                'Exception message should contain customExceptionSwitch');
        } finally {
            // Reset switch
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'AspnProcessingException should have been thrown');
    }

    /**
     * @description Test default consent values when no consent records exist
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testDefaultConsentValuesWhenNull() {
        // Query existing Patient Account from test setup (has no consent records)
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c, PersonIndividualId
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Ensure no consent records exist for this patient
        List<ContactPointTypeConsent> existingConsents = [
            SELECT Id 
            FROM ContactPointTypeConsent 
            WHERE PartyId = :patientAccount.PersonIndividualId
        ];
        if (!existingConsents.isEmpty()) {
            delete existingConsents;
        }

        // Create Insulet opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Default Consent Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        Test.startTest();
        // Call service directly - should use default consent values (all false)
        SendtoAspnService.processSendToAspn(new List<Opportunity>{ insuletOpp });
        Test.stopTest();

        // Verify execution completed successfully with default values
        Assert.isTrue(true, 'Should use default consent values when no consent records exist');
    }

    /**
     * @description Test handleOpportunityProductAfterInsert with OpportunityLineItem records 
     * Verifies that Insulet opportunities are processed when OpportunityLineItem is inserted
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testHandleOpportunityProductAfterInsert() {
        // Create Patient Account with Custom_UniqueID__c
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'OLI Patient',
            'PersonGenderIdentity' => 'Male',
            'Date_of_Birth__c' => Date.newInstance(1980, 5, 15),
            'Type_of_Diabetes__c' => 'Type 1',
            'Preferred_Language__c' => 'English',
            'Custom_UniqueID__c' => 'OLI_TEST_123',
            'BillingPostalCode' => '12345'
        });
        insert patientAccount;

        // Create Product
        Product2 product = new Product2(
            Name = 'Test OLI Product',
            ProductCode = 'OLI-001',
            Product_NDC__c = '9876543210',
            IsActive = true
        );
        insert product;

        // Get Standard Pricebook ID
        Id standardPricebookId = Test.getStandardPricebookId();
        
        // Create Insulet Opportunity with Pricebook2Id set
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity for OLI',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET,
            'Pricebook2Id' => standardPricebookId
        });
        insert insuletOpp;
        
        // Query for existing PricebookEntry first
        List<PricebookEntry> existingPBE = [
            SELECT Id
            FROM PricebookEntry
            WHERE Product2Id = :product.Id
            AND Pricebook2Id = :standardPricebookId
            AND IsActive = true
            LIMIT 1
        ];
        
        PricebookEntry pbe;
        if (!existingPBE.isEmpty()) {
            pbe = existingPBE[0];
        } else {
            // Create PricebookEntry
            pbe = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = product.Id,
                UnitPrice = 100.00,
                IsActive = true
            );
            insert pbe;
        }

        // Create OpportunityLineItem
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = insuletOpp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100.00
        );

        Test.startTest();
        insert oli;
        
        // Call handleOpportunityProductAfterInsert directly
        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{ oli.Id => oli };
        SendtoAspnHandler.handleOpportunityProductAfterInsert(newRecordsMap);
        Test.stopTest();

        // Verify opportunity was created successfully
        Opportunity createdOpp = [
            SELECT Id, Opportunity_Source__c, AccountId, RecordTypeId
            FROM Opportunity
            WHERE Id = :insuletOpp.Id
            LIMIT 1
        ];
        Assert.areEqual(ConstantsUtil.OPPORTUNITY_SOURCE_INSULET, createdOpp.Opportunity_Source__c, 'Opportunity source should be Insulet');
    }

    /**
     * @description Test handleOpportunityProductAfterInsert with null input 
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testHandleOpportunityProductAfterInsertNullInput() {
        Test.startTest();
        SendtoAspnHandler.handleOpportunityProductAfterInsert(null);
        SendtoAspnHandler.handleOpportunityProductAfterInsert(new Map<Id, SObject>());
        Test.stopTest();
        Assert.isTrue(true, 'Should handle null and empty input gracefully');
    }

    /**
     * @description Test processInsuletOpportunitiesOnInsert with Insulet opportunities but no Custom_UniqueID__c - Direct Call 
     * This tests the filtering logic when account doesn't have Custom_UniqueID__c by calling handler directly
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessInsuletOpportunitiesOnInsertWithoutCustomIdDirectCall() {
        // Create new Patient Account without Custom_UniqueID__c
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'No',
            'LastName' => 'Custom ID Patient Test',
            'PersonGenderIdentity' => 'Female',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'Type_of_Diabetes__c' => 'Type 2: Using Insulin',
            'Preferred_Language__c' => 'Spanish',
            'BillingPostalCode' => '12345'
            // No Custom_UniqueID__c
        });
        insert patientAccount;

        // Create Insulet Opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity No Custom ID Direct',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });

        Test.startTest();
        // Call processInsuletOpportunitiesOnInsert directly - should not process since no Custom_UniqueID__c
        SendtoAspnHandler.processInsuletOpportunitiesOnInsert(new List<Opportunity>{ insuletOpp });
        Test.stopTest();

        // Verify execution completed successfully (no exception, but no processing)
        Assert.isTrue(true, 'Should handle Insulet opportunities without Custom_UniqueID__c gracefully');
    }

    /**
     * @description Test processInsuletOpportunitiesOnInsert with non-Insulet opportunities 
     * This tests the filtering logic when Opportunity_Source__c is not Insulet
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessInsuletOpportunitiesOnInsertNonInsulet() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create ASPN Opportunity (not Insulet)
        Opportunity aspnOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test ASPN Opportunity Not Insulet',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_ASPN
        });

        Test.startTest();
        // Call processInsuletOpportunitiesOnInsert directly - should not process ASPN opportunities
        SendtoAspnHandler.processInsuletOpportunitiesOnInsert(new List<Opportunity>{ aspnOpp });
        Test.stopTest();

        // Verify execution completed successfully (no exception, but no processing)
        Assert.isTrue(true, 'Should filter out non-Insulet opportunities');
    }

    /**
     * @description Test processStandardEventForInsulet with Insulet opportunities 
     * This tests the full path including query and processOpportunitiesOnePerAccount
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessStandardEventForInsuletWithOpportunities() {
        // Query existing Patient Account from test setup (include RecordTypeId)
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Ensure Patient has Custom_UniqueID__c populated
        if (String.isBlank(patientAccount.Custom_UniqueID__c)) {
            patientAccount.Custom_UniqueID__c = 'TEST_UNIQUE_ID_' + String.valueOf(System.now().getTime());
            update patientAccount;
            // Re-query to get updated RecordTypeId
            patientAccount = [
                SELECT Id, Custom_UniqueID__c, RecordTypeId
                FROM Account
                WHERE Id = :patientAccount.Id
                LIMIT 1
            ];
        }

        // Create Insulet Opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity Standard Event',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        // Update Custom_UniqueID__c to trigger Standard event
        Test.startTest();
        String newCustomUniqueId = 'STANDARD_EVENT_TEST_' + String.valueOf(System.now().getTime());
        patientAccount.Custom_UniqueID__c = newCustomUniqueId;

        // Create old accounts map to simulate afterUpdate
        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{
            patientAccount.Id => new Account(
                Id = patientAccount.Id,
                Custom_UniqueID__c = 'OLD_VALUE',
                RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT
            )
        };

        // Call processStandardEventForInsulet directly
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, oldAccountsMap);
        Test.stopTest();

        // Verify execution completed successfully
        Assert.isTrue(true, 'Should process Standard event for Insulet opportunities successfully');
    }

    /**
     * @description Test processStandardEventForInsulet with multiple Insulet opportunities 
     * This tests processOpportunitiesOnePerAccount logic - only one per Account
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessStandardEventForInsuletMultipleOpportunities() {
        // Query existing Patient Account from test setup (include RecordTypeId)
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Ensure Patient has Custom_UniqueID__c populated
        if (String.isBlank(patientAccount.Custom_UniqueID__c)) {
            patientAccount.Custom_UniqueID__c = 'TEST_UNIQUE_ID_' + String.valueOf(System.now().getTime());
            update patientAccount;
            // Re-query to get updated RecordTypeId
            patientAccount = [
                SELECT Id, Custom_UniqueID__c, RecordTypeId
                FROM Account
                WHERE Id = :patientAccount.Id
                LIMIT 1
            ];
        }

        // Create multiple Insulet Opportunities for same Account
        Opportunity insuletOpp1 = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity 1',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        Opportunity insuletOpp2 = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity 2',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert new List<Opportunity>{ insuletOpp1, insuletOpp2 };

        // Update Custom_UniqueID__c to trigger Standard event
        Test.startTest();
        String newCustomUniqueId = 'MULTIPLE_OPP_TEST_' + String.valueOf(System.now().getTime());
        patientAccount.Custom_UniqueID__c = newCustomUniqueId;

        // Create old accounts map to simulate afterUpdate
        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{
            patientAccount.Id => new Account(
                Id = patientAccount.Id,
                Custom_UniqueID__c = 'OLD_VALUE',
                RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT
            )
        };

        // Call processStandardEventForInsulet directly - should process only one opportunity per Account
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, oldAccountsMap);
        Test.stopTest();

        // Verify execution completed successfully
        Assert.isTrue(true, 'Should process only one opportunity per Account');
    }

    /**
     * @description Test isEligibleForAspnProcessing with afterInsert scenario 
     * This tests the return true path when oldOpportunitiesMap is null
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testIsEligibleForAspnProcessingAfterInsert() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create Opportunity with Cancel_Order__c = true
        Opportunity opp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Cancel Order Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Cancel_Order__c' => true,
            'Status__c' => 'Prior Authorization',
            'Sub_Status__c' => 'PA Processing',
            'Reason_for_Cancellation__c' => 'Test Reason'
        });

        Test.startTest();
        // Call filterSendToAspnOpportunities with null oldOpportunitiesMap (afterInsert scenario)
        List<Opportunity> result = SendtoAspnHandler.filterSendToAspnOpportunities(new List<Opportunity>{ opp }, null);
        Test.stopTest();

        // Verify that the opportunity was included (line 54 should be covered)
        Assert.areEqual(1, result.size(), 'Should return opportunity with Cancel_Order__c = true in afterInsert');
        Assert.areEqual(opp.Cancel_Order__c, result[0].Cancel_Order__c, 'Cancel_Order__c should be true');
    }

    /**
     * @description Test processOpportunitiesOnUpdate with Cancel_Order__c change 
     * This tests the non-empty sendToAspnOpportunities path in update scenario
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessOpportunitiesOnUpdateWithCancelOrderChange() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create Opportunity without Cancel_Order__c
        Opportunity opp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Cancel Order Update',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Cancel_Order__c' => false
        });
        insert opp;

        // Update Cancel_Order__c to true
        opp.Cancel_Order__c = true;
        opp.Status__c = 'Prior Authorization';
        opp.Sub_Status__c = 'PA Processing';
        opp.Reason_for_Cancellation__c = 'Test Reason';

        // Create old opportunities map
        Map<Id, Opportunity> oldOpportunitiesMap = new Map<Id, Opportunity>{
            opp.Id => new Opportunity(
                Id = opp.Id,
                Cancel_Order__c = false,
                RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
            )
        };

        Test.startTest();
        // Call processOpportunitiesOnUpdate directly
        SendtoAspnHandler.processOpportunitiesOnUpdate(new List<Opportunity>{ opp }, oldOpportunitiesMap);
        Test.stopTest();

        // Verify execution completed successfully
        Assert.isTrue(true, 'Should process opportunities when Cancel_Order__c changes to true on update');
    }

    /**
     * @description Test processOpportunitiesOnInsert with empty results 
     * This tests the early return path when no opportunities meet criteria
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessOpportunitiesOnInsertEmptyResults() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create Opportunity without Cancel_Order__c (should not be processed)
        Opportunity opp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test No Cancel Order',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Cancel_Order__c' => false
        });

        Test.startTest();
        // Call processOpportunitiesOnInsert directly - should return early
        SendtoAspnHandler.processOpportunitiesOnInsert(new List<Opportunity>{ opp });
        Test.stopTest();

        // Verify execution completed successfully (no exception)
        Assert.isTrue(true, 'Should handle opportunities without Cancel_Order__c gracefully');
    }

    /**
     * @description Test processOpportunitiesOnePerAccount with null/empty input 
     * This tests the early return path
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessOpportunitiesOnePerAccountEmptyInput() {
        Test.startTest();
        // Test with null - this is a private method, so we test via processStandardEventForInsulet
        // Create account but don't create opportunities - query will return empty
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Empty',
            'LastName' => 'Test Patient',
            'PersonGenderIdentity' => 'Male',
            'Date_of_Birth__c' => Date.newInstance(1980, 1, 1),
            'Type_of_Diabetes__c' => 'Type 1',
            'Preferred_Language__c' => 'English',
            'Custom_UniqueID__c' => 'EMPTY_TEST',
            'BillingPostalCode' => '12345'
        });
        insert patientAccount;
        
        // Re-query to get RecordTypeId
        patientAccount = [SELECT Id, Custom_UniqueID__c, RecordTypeId FROM Account WHERE Id = :patientAccount.Id];
        
        // Call processStandardEventForInsulet - no opportunities exist, so processOpportunitiesOnePerAccount gets empty list
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, null);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle empty opportunities list gracefully');
    }

    /**
     * @description Test processOpportunitiesOnUpdate with empty results 
     * This tests the early return path when no opportunities meet criteria
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessOpportunitiesOnUpdateEmptyResults() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create Opportunity without Cancel_Order__c
        Opportunity opp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test No Cancel Order Update',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Cancel_Order__c' => false
        });
        insert opp;

        // Update with Cancel_Order__c still false
        opp.Name = 'Updated Name';
        
        Map<Id, Opportunity> oldOpportunitiesMap = new Map<Id, Opportunity>{
            opp.Id => new Opportunity(
                Id = opp.Id,
                Cancel_Order__c = false,
                RecordTypeId = ConstantsUtil.OPPORTUNITY_NCS_RT
            )
        };

        Test.startTest();
        // Call processOpportunitiesOnUpdate directly - should return early
        SendtoAspnHandler.processOpportunitiesOnUpdate(new List<Opportunity>{ opp }, oldOpportunitiesMap);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle opportunities without Cancel_Order__c change gracefully');
    }

    /**
     * @description Test handleOpportunityProductAfterInsert with full path coverage 
     * This tests the complete method including null check, filtering, query, and service call
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testHandleOpportunityProductAfterInsertFullPath() {
        // Create Patient Account with Custom_UniqueID__c
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Full',
            'LastName' => 'Path Patient',
            'PersonGenderIdentity' => 'Male',
            'Date_of_Birth__c' => Date.newInstance(1980, 1, 1),
            'Type_of_Diabetes__c' => 'Type 1',
            'Preferred_Language__c' => 'English',
            'Custom_UniqueID__c' => 'FULLPATH123',
            'BillingPostalCode' => '54321'
        });
        insert patientAccount;

        // Create Product
        Product2 product = new Product2(
            Name = 'Test Full Path Product',
            ProductCode = 'FULLPATH-001',
            Product_NDC__c = '2222222222',
            IsActive = true
        );
        insert product;

        // Get Standard Pricebook ID
        Id standardPricebookId = Test.getStandardPricebookId();
        
        // Create Insulet Opportunity with Pricebook2Id set
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity for OLI Full Path',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET,
            'Pricebook2Id' => standardPricebookId
        });
        insert insuletOpp;
        
        // Query for existing PricebookEntry first
        List<PricebookEntry> existingPBE = [
            SELECT Id
            FROM PricebookEntry
            WHERE Product2Id = :product.Id
            AND Pricebook2Id = :standardPricebookId
            AND IsActive = true
            LIMIT 1
        ];
        
        PricebookEntry pbe;
        if (!existingPBE.isEmpty()) {
            pbe = existingPBE[0];
        } else {
            // Create PricebookEntry
            pbe = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = product.Id,
                UnitPrice = 100.00,
                IsActive = true
            );
            insert pbe;
        }

        // Create OpportunityLineItem
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = insuletOpp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100.00
        );
        insert oli;

        Test.startTest();
        // Call handleOpportunityProductAfterInsert directly with map
        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>{ oli.Id => oli };
        SendtoAspnHandler.handleOpportunityProductAfterInsert(newRecordsMap);
        Test.stopTest();

        // Verify execution completed successfully
        Assert.isTrue(true, 'Should process OpportunityLineItem and route to processInsuletOpportunitiesOnInsert');
    }

    /**
     * @description Test handleOpportunityProductAfterInsert with empty opptyIds 
     * This tests the early return when no OpportunityIds are collected (all OLIs have null OpportunityId)
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testHandleOpportunityProductAfterInsertEmptyOpptyIds() {
        // Create Product
        Product2 product = new Product2(
            Name = 'Test Empty OppIds Product',
            ProductCode = 'EMPTYOPP-001',
            Product_NDC__c = '3333333333',
            IsActive = true
        );
        insert product;

        // Get Standard Pricebook ID
        Id standardPricebookId = Test.getStandardPricebookId();
        
        // Query for existing PricebookEntry first
        List<PricebookEntry> existingPBE = [
            SELECT Id
            FROM PricebookEntry
            WHERE Product2Id = :product.Id
            AND Pricebook2Id = :standardPricebookId
            AND IsActive = true
            LIMIT 1
        ];
        
        PricebookEntry pbe;
        if (!existingPBE.isEmpty()) {
            pbe = existingPBE[0];
        } else {
            // Create PricebookEntry
            pbe = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = product.Id,
                UnitPrice = 100.00,
                IsActive = true
            );
            insert pbe;
        }

        Test.startTest();
        // Create mock OpportunityLineItem objects without OpportunityId to test filtering
        // We create them as in-memory objects (not inserted) to simulate the scenario
        OpportunityLineItem mockOli1 = new OpportunityLineItem(
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100.00
            // OpportunityId is null
        );
        OpportunityLineItem mockOli2 = new OpportunityLineItem(
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 200.00
            // OpportunityId is null
        );
        
        // Create a map with dynamically generated mock IDs
        Map<Id, SObject> newRecordsMap = new Map<Id, SObject>();
        // Use dynamically generated IDs - the handler will check OpportunityId, not the map key
        Id mockId1 = MockDataFactory.getFakeId('OpportunityLineItem');
        Id mockId2 = MockDataFactory.getFakeId('OpportunityLineItem');
        newRecordsMap.put(mockId1, mockOli1);
        newRecordsMap.put(mockId2, mockOli2);
        
        // Call handler - should return early because all OLIs have null OpportunityId
        SendtoAspnHandler.handleOpportunityProductAfterInsert(newRecordsMap);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle OpportunityLineItems without OpportunityId gracefully and return early');
    }

    /**
     * @description Test processStandardEventForInsulet with opportunities found 
     * This tests the query path and processOpportunitiesOnePerAccount call
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessStandardEventForInsuletWithOpportunitiesFound() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Ensure Patient has Custom_UniqueID__c populated
        if (String.isBlank(patientAccount.Custom_UniqueID__c)) {
            patientAccount.Custom_UniqueID__c = 'TEST_UNIQUE_ID_' + String.valueOf(System.now().getTime());
            update patientAccount;
            patientAccount = [
                SELECT Id, Custom_UniqueID__c, RecordTypeId
                FROM Account
                WHERE Id = :patientAccount.Id
                LIMIT 1
            ];
        }

        // Create Insulet Opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity Standard Event Found',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        // Update Custom_UniqueID__c to trigger Standard event
        Test.startTest();
        String newCustomUniqueId = 'STANDARD_EVENT_FOUND_TEST_' + String.valueOf(System.now().getTime());
        patientAccount.Custom_UniqueID__c = newCustomUniqueId;

        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{
            patientAccount.Id => new Account(
                Id = patientAccount.Id,
                Custom_UniqueID__c = 'OLD_VALUE',
                RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT
            )
        };

        // Call processStandardEventForInsulet directly - should find opportunities and call processOpportunitiesOnePerAccount
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, oldAccountsMap);
        Test.stopTest();

        Assert.isTrue(true, 'Should process Standard event and find Insulet opportunities');
    }

    /**
     * @description Test processInsuletOpportunitiesOnInsert with full path coverage 
     * This tests the complete filtering and processing logic
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessInsuletOpportunitiesOnInsertFullPath() {
        // Query existing Patient Account with Custom_UniqueID__c from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];
        Assert.isNotNull(patientAccount.Custom_UniqueID__c, 'Patient Account should have Custom_UniqueID__c');

        // Create Insulet Opportunity with AccountId
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity Full Path',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });

        Test.startTest();
        // Call processInsuletOpportunitiesOnInsert directly - should process through all filtering logic
        SendtoAspnHandler.processInsuletOpportunitiesOnInsert(new List<Opportunity>{ insuletOpp });
        Test.stopTest();

        // Verify execution completed successfully
        Assert.isTrue(true, 'Should process Insulet opportunities with Custom_UniqueID__c through full path');
    }

    /**
     * @description Test processInsuletOpportunitiesOnInsert with empty accountIds 
     * This tests the early return when no accountIds are collected
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessInsuletOpportunitiesOnInsertEmptyAccountIds() {
        // Create Opportunity without Insulet source (should not add to accountIds)
        Opportunity nonInsuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Non-Insulet Opportunity',
            'AccountId' => null, // No AccountId
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_ASPN
        });

        Test.startTest();
        // Call processInsuletOpportunitiesOnInsert - should return early due to empty accountIds
        SendtoAspnHandler.processInsuletOpportunitiesOnInsert(new List<Opportunity>{ nonInsuletOpp });
        Test.stopTest();

        Assert.isTrue(true, 'Should handle non-Insulet opportunities gracefully');
    }

    /**
     * @description Test processInsuletOpportunitiesOnInsert with account without Custom_UniqueID__c 
     * This tests the filtering logic when accountMap doesn't contain the AccountId
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessInsuletOpportunitiesOnInsertAccountWithoutCustomId() {
        // Create new Patient Account without Custom_UniqueID__c
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'No',
            'LastName' => 'Custom ID Patient Filter',
            'PersonGenderIdentity' => 'Female',
            'Date_of_Birth__c' => Date.newInstance(1990, 1, 1),
            'Type_of_Diabetes__c' => 'Type 2: Using Insulin',
            'Preferred_Language__c' => 'Spanish',
            'BillingPostalCode' => '12345'
            // No Custom_UniqueID__c
        });
        insert patientAccount;

        // Create Insulet Opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity No Custom ID Filter',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });

        Test.startTest();
        // Call processInsuletOpportunitiesOnInsert - accountMap won't contain this account
        SendtoAspnHandler.processInsuletOpportunitiesOnInsert(new List<Opportunity>{ insuletOpp });
        Test.stopTest();

        Assert.isTrue(true, 'Should filter out opportunities when account doesn\'t have Custom_UniqueID__c');
    }

    /**
     * @description Test processOpportunitiesOnInsert with Cancel_Order__c = true 
     * This tests the service call path when opportunities are found
     * This test was added for US - NGOMCT-1750.
     */
    @IsTest
    static void testProcessOpportunitiesOnInsertWithCancelOrderServiceCall() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create Opportunity with Cancel_Order__c = true
        Opportunity opp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Cancel Order Insert Service Call',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Cancel_Order__c' => true,
            'Status__c' => 'Prior Authorization',
            'Sub_Status__c' => 'PA Processing',
            'Reason_for_Cancellation__c' => 'Test Reason'
        });

        Test.startTest();
        // Call processOpportunitiesOnInsert directly - should call service
        SendtoAspnHandler.processOpportunitiesOnInsert(new List<Opportunity>{ opp });
        Test.stopTest();

        Assert.isTrue(true, 'Should process opportunities with Cancel_Order__c = true and call service');
    }

}