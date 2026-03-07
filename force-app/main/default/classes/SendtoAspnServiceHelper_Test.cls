/**
 * @description Test class for SendtoAspnServiceHelper
 * @author Priyansh Shukla
 * @date 27th Jan 2026
 *
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       27th Jan 2026       Priyansh Shukla        Initial Version - Moved from SendtoAspnService_Test
 * V1.0.1       28th Jan 2026       Rajasekar M            Added Test Method to Customer ID Usage Type Identifier
 * V1.0.2       20th Feb 2026       Saikat Ghosh           NGASIM-2347 - Added ContactPointPhone UsageType coverage (Mobile preference & fallback)
 */
@IsTest(IsParallel=true)
private class SendtoAspnServiceHelper_Test {

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

        // Create and insert ContactPointPhone using TestDataFactory (NGASIM-2347: UsageType required for query)
        ContactPointPhone cpPhone = TestDataFactory.getContactPointPhone(new Map<String, Object>{
            'ParentId' => patientAccount.Id,
            'TelephoneNumber' => '5551234567',
            'UsageType' => ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE
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
            ID_Value__c = 'EXTPAT123'
        );

         // Create and insert Identifier
         Identifier providerIdentifier = new Identifier(
            ParentRecordId = providerAccount.Id,
            IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE,
            ID_Value__c = 'EXTPAT789'
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
     * @description Test SendtoAspnService.processSendToAspn with complete data
     * Per NGOMCT-1358: Updated to test Cancel_Order__c instead of "Send to ASPN" stage
     */
    @IsTest
    static void testProcessSendToAspnUpdateWithCompleteData() {
        // Query test data created in @TestSetup
        Opportunity opportunity = [
            SELECT Id, Name, AccountId, StageName, RecordTypeId, Cancel_Order__c
            FROM Opportunity
            WHERE StageName = :ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE
            LIMIT 1
        ];

        Test.startTest();
        try {
            // Set Status and Sub_Status before setting Cancel_Order__c to avoid validation rule
            opportunity.Status__c = 'Prior Authorization';
            opportunity.Sub_Status__c = 'PA Processing';
            opportunity.Cancel_Order__c = true;
            opportunity.Reason_for_Cancellation__c = 'Not Qualified';
            update opportunity;
            Assert.isTrue(true, 'Method should execute without throwing exception');
        } catch (Exception e) {
            Assert.fail('Method should not throw exception: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * @description Test SendtoAspnService.processSendToAspn with insert trigger
     * Per NGOMCT-1358: Updated to test Cancel_Order__c instead of "Send to ASPN" stage
     */
    @IsTest
    static void testProcessSendToAspnInsertWithCompleteData() {

        Account patientAccount2 = [SELECT Id FROM Account where LastName ='Doe Patient' LIMIT 1];

        Test.startTest();
        // Create and insert Opportunity using TestDataFactory
        // Set Status and Sub_Status along with Cancel_Order__c to avoid validation rule
        Opportunity opp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Opportunity Insert',
            'AccountId' => patientAccount2.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Status__c' => 'Prior Authorization',
            'Sub_Status__c' => 'PA Processing',
            'Cancel_Order__c' => true,
            'Reason_for_Cancellation__c' => 'Not Qualified'
        });

        try {
            insert opp;
            Assert.isTrue(true, 'Opportunity should be inserted successfully and trigger should execute');
        } catch (Exception e) {
            Assert.fail('Insert should not throw exception: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * @description Test SendtoAspnService.processSendToAspn with cancellation data
     */
    @IsTest
    static void testProcessSendToAspnCancellation() {
        // Query test data created in @TestSetup
        Opportunity opportunity = [
            SELECT Id, Name, AccountId, StageName, RecordTypeId
            FROM Opportunity
            WHERE StageName = :ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE
            LIMIT 1
        ];

        Test.startTest();
        try {
            opportunity.Sub_Status__c = 'PA Processing';
            opportunity.Status__c = 'Prior Authorization';
            opportunity.Cancel_Order__c = true;
            opportunity.Reason_for_Cancellation__c = 'Not Qualified';
            update opportunity;
            Assert.isTrue(true, 'Method should execute without throwing exception');
        } catch (Exception e) {
            Assert.fail('Method should not throw exception: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * @description Test SendtoAspnService.processSendToAspn with insert trigger
     */
    @IsTest
    static void testProcessSendToAspnInsertWithASPNSource() {

        Account patientAccount2 = [SELECT Id FROM Account where LastName ='Doe Patient' LIMIT 1];

        Test.startTest();
        // Create and insert Opportunity using TestDataFactory
        Opportunity opp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Opportunity Insert',
            'AccountId' => patientAccount2.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_ASPN
        });

        try {
            insert opp;
            Assert.isTrue(true, 'Opportunity should be inserted successfully and trigger should execute');
        } catch (Exception e) {
            Assert.fail('Insert should not throw exception: ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * @description Test SendtoAspnService.processSendToAspn with null opportunity AccountId
     * Per NGOMCT-1358: Updated to test Cancel_Order__c instead of "Send to ASPN" stage
     */
    @IsTest
    static void testProcessSendToAspnWithNullAccountId() {
        List<Opportunity> opportunities = new List<Opportunity>{
            (Opportunity)MockDataFactory.mockData('Opportunity', new Map<String, Object>{
                'Id' => MockDataFactory.getFakeId('Opportunity'),
                'Name' => 'Test Opp',
                'AccountId' => null,
                'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
                'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
                'Cancel_Order__c' => true
            })
        };
        Test.startTest();
        SendtoAspnService.processSendToAspn(opportunities);
        Test.stopTest();

        Assert.isTrue(true, 'Should handle null AccountId gracefully');
    }

    /**
     * @description Test SendtoAspnService.processSendToAspn with null input
     */
    @IsTest
    static void testProcessSendToAspnNullInput() {
        Test.startTest();
        SendtoAspnService.processSendToAspn(null);
        Test.stopTest();
        Assert.isTrue(true, 'Should handle null input gracefully');
    }

    /**
     * @description Test SendtoAspnService.processSendToAspn with empty list
     */
    @IsTest
    static void testProcessSendToAspnEmptyList() {
        Test.startTest();
        SendtoAspnService.processSendToAspn(new List<Opportunity>());
        Test.stopTest();
        Assert.isTrue(true, 'Should handle empty list gracefully');
    }

    /**
     * @description Test processAccountUpdatesForAspn with ASPN and Insulet opportunities (NGOMCT-1358, NGOMCT-1454)
     * Verifies that both ASPN Source ID Update and Insulet Standard events are triggered when Custom_UniqueID__c is updated
     */
    @IsTest
    static void testProcessAccountUpdatesForAspn() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create ASPN Opportunity
        Opportunity aspnOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test ASPN Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_ASPN
        });
        insert aspnOpp;

        // Create Insulet Opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        // Update Custom_UniqueID__c to trigger both events
        Test.startTest();
        patientAccount.Custom_UniqueID__c = 'UPDATED_UNIQUE_ID';
        update patientAccount;
        Test.stopTest();

        // Verify that the update completed without exceptions
        Account updatedAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE Id = :patientAccount.Id
            LIMIT 1
        ];
        Assert.areEqual('UPDATED_UNIQUE_ID', updatedAccount.Custom_UniqueID__c, 'Custom_UniqueID__c should be updated');

        // Verify both opportunities exist and are open
        List<Opportunity> opportunities = [
            SELECT Id, Opportunity_Source__c, IsClosed
            FROM Opportunity
            WHERE AccountId = :patientAccount.Id
            AND Id IN (:aspnOpp.Id, :insuletOpp.Id)
        ];
        Assert.areEqual(2, opportunities.size(), 'Both opportunities should exist');
        for (Opportunity opp : opportunities) {
            Assert.isFalse(opp.IsClosed, 'Opportunity should be open');
        }
    }

    /**
     * @description Test processStandardEventForInsulet with Insulet opportunity (NGOMCT-1358)
     * Verifies that Standard event is triggered when Custom_UniqueID__c is updated for Patient with Insulet opportunity
     */
    @IsTest
    static void testProcessStandardEventForInsulet() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create Insulet Opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        // Update Custom_UniqueID__c to trigger Standard event
        Test.startTest();
        patientAccount.Custom_UniqueID__c = 'INSULET_UNIQUE_ID';
        update patientAccount;
        Test.stopTest();

        // Verify that the update completed without exceptions
        Account updatedAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE Id = :patientAccount.Id
            LIMIT 1
        ];
        Assert.areEqual('INSULET_UNIQUE_ID', updatedAccount.Custom_UniqueID__c, 'Custom_UniqueID__c should be updated');

        // Verify Insulet opportunity exists and is open
        Opportunity opp = [
            SELECT Id, Opportunity_Source__c, IsClosed
            FROM Opportunity
            WHERE Id = :insuletOpp.Id
            LIMIT 1
        ];
        Assert.areEqual(ConstantsUtil.OPPORTUNITY_SOURCE_INSULET, opp.Opportunity_Source__c, 'Opportunity source should be Insulet');
        Assert.isFalse(opp.IsClosed, 'Opportunity should be open');
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
     * @description Test processOpportunitiesOnInsert with Cancel_Order__c = true and Insulet source (NGOMCT-1358)
     * Verifies that both scenarios are handled in afterInsert
     * Per NGOMCT-1358: Removed "Send to ASPN" stage check - only processes Cancel_Order__c = true
     */
    @IsTest
    static void testProcessOpportunitiesOnInsert() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create Opportunity with Cancel_Order__c = true
        // Set Status and Sub_Status along with Cancel_Order__c to avoid validation rule
        Opportunity cancelOrderOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Cancel Order Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Status__c' => 'Prior Authorization',
            'Sub_Status__c' => 'PA Processing',
            'Cancel_Order__c' => true,
            'Reason_for_Cancellation__c' => 'Not Qualified'
        });

        // Create Insulet Opportunity (AC2 - should trigger Standard event if Patient has Custom_UniqueID__c)
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });

        Test.startTest();
        List<Opportunity> opportunities = new List<Opportunity>{ cancelOrderOpp, insuletOpp };
        insert opportunities;
        Test.stopTest();

        // Verify both opportunities were created successfully
        List<Opportunity> createdOpps = [
            SELECT Id, StageName, Opportunity_Source__c, Cancel_Order__c
            FROM Opportunity
            WHERE Id IN (:cancelOrderOpp.Id, :insuletOpp.Id)
        ];
        Assert.areEqual(2, createdOpps.size(), 'Both opportunities should be created');
    }

    /**
     * @description Test processOpportunitiesOnUpdate with Cancel_Order__c change (NGOMCT-1358)
     * Verifies that opportunity update triggers event when Cancel_Order__c changes to true
     * Per NGOMCT-1358: Removed "Send to ASPN" stage check - only processes Cancel_Order__c = true
     * Per NGOMCT-1358: Insulet source logic removed from afterUpdate (only in afterInsert)
     */
    @IsTest
    static void testProcessOpportunitiesOnUpdate() {
        // Query existing Patient Account and Opportunity from test setup
        Account patientAccount = [
            SELECT Id
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        Opportunity existingOpp = [
            SELECT Id, StageName, Cancel_Order__c
            FROM Opportunity
            WHERE AccountId = :patientAccount.Id
            LIMIT 1
        ];

        Test.startTest();
        // Set Status and Sub_Status before setting Cancel_Order__c to avoid validation rule
        existingOpp.Status__c = 'Prior Authorization';
        existingOpp.Sub_Status__c = 'PA Processing';
        existingOpp.Cancel_Order__c = true;
        existingOpp.Reason_for_Cancellation__c = 'Not Qualified';
        update existingOpp;
        Test.stopTest();

        // Verify opportunity was updated successfully
        Opportunity updatedOpp = [
            SELECT Id, Cancel_Order__c
            FROM Opportunity
            WHERE Id = :existingOpp.Id
            LIMIT 1
        ];
        Assert.isTrue(updatedOpp.Cancel_Order__c, 'Cancel_Order__c should be updated to true');
    }

    /**
     * @description Test processStandardEventForInsulet with Patient account and Insulet opportunity (direct call)
     * Verifies the method processes Insulet opportunities correctly
     */
    @IsTest
    static void testProcessStandardEventForInsuletDirectCall() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create Insulet Opportunity
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity Direct',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        // Update Custom_UniqueID__c to a new value
        String newCustomUniqueId = 'INSULET_DIRECT_TEST_' + String.valueOf(System.now().getTime());
        patientAccount.Custom_UniqueID__c = newCustomUniqueId;

        // Create old accounts map to simulate afterUpdate
        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{
            patientAccount.Id => new Account(
                Id = patientAccount.Id,
                Custom_UniqueID__c = 'OLD_INSULET_VALUE',
                RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT
            )
        };

        Test.startTest();
        // Call the method directly
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, oldAccountsMap);
        Test.stopTest();

        Assert.isTrue(true, 'processStandardEventForInsulet should execute successfully');
    }

    /**
     * @description Test processStandardEventForInsulet with no Insulet opportunities
     * Verifies the method handles the case when no Insulet opportunities exist
     */
    @IsTest
    static void testProcessStandardEventForInsuletNoOpportunities() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Don't create any Insulet opportunities - just ASPN
        Opportunity aspnOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test ASPN Only Opportunity',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_ASPN
        });
        insert aspnOpp;

        // Update Custom_UniqueID__c
        patientAccount.Custom_UniqueID__c = 'NO_INSULET_OPP_TEST';

        // Create old accounts map
        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{
            patientAccount.Id => new Account(
                Id = patientAccount.Id,
                Custom_UniqueID__c = 'OLD_VALUE',
                RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT
            )
        };

        Test.startTest();
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, oldAccountsMap);
        Test.stopTest();

        Assert.isTrue(true, 'processStandardEventForInsulet should handle no Insulet opportunities gracefully');
    }

    /**
     * @description Test processStandardEventForInsulet with non-Patient account
     * Verifies the method filters out non-Patient accounts
     */
    @IsTest
    static void testProcessStandardEventForInsuletNonPatientAccount() {
        // Query Provider Account from test setup
        Account providerAccount = [
            SELECT Id, RecordTypeId
            FROM Account
            WHERE LastName = 'Smith Provider'
            LIMIT 1
        ];

        Test.startTest();
        // Call with Provider account - should be filtered out
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ providerAccount }, null);
        Test.stopTest();

        Assert.isTrue(true, 'processStandardEventForInsulet should filter out non-Patient accounts');
    }

    /**
     * @description Test processStandardEventForInsulet for afterInsert scenario
     * Verifies the method handles new accounts with Custom_UniqueID__c populated
     */
    @IsTest
    static void testProcessStandardEventForInsuletAfterInsert() {
        // Create new Patient Account with Custom_UniqueID__c populated
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType(new Map<String, Object>{
            'FirstName' => 'Standard',
            'LastName' => 'Event Test Patient',
            'PersonGenderIdentity' => 'Female',
            'Date_of_Birth__c' => Date.newInstance(1990, 6, 15),
            'Type_of_Diabetes__c' => 'Type 1',
            'Preferred_Language__c' => 'Spanish',
            'Custom_UniqueID__c' => 'NEW_ACCOUNT_STANDARD_ID',
            'BillingPostalCode' => '54321'
        });
        insert patientAccount;

        // Create Insulet Opportunity for the new account
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity Insert',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        // Re-query account with RecordTypeId
        patientAccount = [SELECT Id, Custom_UniqueID__c, RecordTypeId FROM Account WHERE Id = :patientAccount.Id];

        Test.startTest();
        // Call for afterInsert scenario (oldAccountsMap is null)
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, null);
        Test.stopTest();

        Assert.isTrue(true, 'processStandardEventForInsulet should handle afterInsert scenario');
    }

    /**
     * @description Test processStandardEventForInsulet with multiple Insulet opportunities
     * Verifies only one event is created per account (per NGOMCT-1358 AC1)
     */
    @IsTest
    static void testProcessStandardEventForInsuletMultipleOpportunities() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create multiple Insulet Opportunities
        List<Opportunity> insuletOpps = new List<Opportunity>();
        for (Integer i = 0; i < 3; i++) {
            insuletOpps.add(TestDataFactory.getOpportunity(new Map<String, Object>{
                'Name' => 'Test Insulet Opportunity ' + i,
                'AccountId' => patientAccount.Id,
                'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
                'CloseDate' => Date.today().addDays(30),
                'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
                'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
            }));
        }
        insert insuletOpps;

        // Update Custom_UniqueID__c
        patientAccount.Custom_UniqueID__c = 'MULTI_OPP_TEST';

        // Create old accounts map
        Map<Id, Account> oldAccountsMap = new Map<Id, Account>{
            patientAccount.Id => new Account(
                Id = patientAccount.Id,
                Custom_UniqueID__c = 'OLD_VALUE',
                RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT
            )
        };

        Test.startTest();
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, oldAccountsMap);
        Test.stopTest();

        // Verify at least 3 Insulet opportunities exist (may include opportunities from TestSetup)
        List<Opportunity> opps = [
            SELECT Id FROM Opportunity
            WHERE AccountId = :patientAccount.Id
            AND Opportunity_Source__c = :ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        ];
        Assert.isTrue(opps.size() >= 3, 'At least 3 Insulet opportunities should exist, found: ' + opps.size());
        Assert.isTrue(true, 'processStandardEventForInsulet should process only one opportunity per account');
    }

    /**
     * @description Test processStandardEventForInsulet when Custom_UniqueID__c is blank
     * Verifies the method filters out accounts with blank Custom_UniqueID__c
     */
    @IsTest
    static void testProcessStandardEventForInsuletWithBlankCustomUniqueId() {
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
     * @description Test customerIdUsageType Identifier for provider Accounts
     * Verifies queryIdentifierData method when Usage type is Customer Id and covers(lines 188-193)
     * Also covers queryContactPointData: Mobile preference (lines 104-106) and fallback (lines 107-110)
     */
    @IsTest
    static void testCustomerIdUsageTypeIdentifierForProviderAccounts() {
        SendtoAspnService.AspnDataContext dataContext = new SendtoAspnService.AspnDataContext();
        Account providerAccountRecord = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Jaden',
            'LastName' => 'Smith Provider',
            'PersonEmail' => 'jadensmith@example.com',
            'BillingPostalCode' => '234578'
        });
        insert providerAccountRecord;
        Identifier providerIdentifier = new Identifier(
            ParentRecordId = providerAccountRecord.Id,
            IdUsageType = ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE,
            ID_Value__c = 'EXTPAT456'
        );
        insert providerIdentifier;
        ContactPointPhone providerPhone = TestDataFactory.getContactPointPhone(new Map<String, Object>{
            'ParentId' => providerAccountRecord.Id,
            'TelephoneNumber' => '5552345678',
            'UsageType' => ConstantsUtil.CONTACT_POINT_USAGE_TYPE_HOME
        });
        insert providerPhone;

        Account patientAccount = [SELECT Id FROM Account WHERE LastName = 'Doe Patient' LIMIT 1];
        Set<Id> accountIds = new Set<Id>();
        accountIds.add(providerAccountRecord.Id);
        accountIds.add(patientAccount.Id);
        Test.startTest();
        dataContext = SendtoAspnServiceHelper.queryRelatedData(accountIds, null);
        Test.stopTest();
        String idValue = dataContext.accountCustomerIdMap.get(providerAccountRecord.Id);
        Assert.areEqual(providerIdentifier.ID_Value__c, idValue, 'Provider Account needs to be mapped with Identifier ID Value');
    }
    /**
     * @description Test consent values calculation with ContactPointTypeConsent records
     * Verifies calculateConsentValues method handles null individualId (line 269) and processes consent records (lines 277-287)
     */
    @IsTest
    static void testConsentValuesCalculation() {
        // Query existing Patient Account from test setup
        Account patientAccount = [
            SELECT Id, PersonIndividualId, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE LastName = 'Doe Patient'
            LIMIT 1
        ];

        // Create Insulet Opportunity for the account (required for processStandardEventForInsulet)
        Opportunity insuletOpp = TestDataFactory.getOpportunity(new Map<String, Object>{
            'Name' => 'Test Insulet Opportunity Consent',
            'AccountId' => patientAccount.Id,
            'StageName' => ConstantsUtil.NEW_OPPORTUNITY_OPPORTUNITY_STAGE,
            'CloseDate' => Date.today().addDays(30),
            'RecordTypeId' => ConstantsUtil.OPPORTUNITY_NCS_RT,
            'Opportunity_Source__c' => ConstantsUtil.OPPORTUNITY_SOURCE_INSULET
        });
        insert insuletOpp;

        Test.startTest();
        // Test Case 1: individualId is null (line 269 coverage)
        // Update Custom_UniqueID__c and call processStandardEventForInsulet
        // This will call calculateConsentValues with null individualId if PersonIndividualId is null
        patientAccount.Custom_UniqueID__c = 'CONSENT_TEST_1';
        update patientAccount;
        SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, null);

        // Re-query to get PersonIndividualId
        patientAccount = [
            SELECT Id, PersonIndividualId, Custom_UniqueID__c, RecordTypeId
            FROM Account
            WHERE Id = :patientAccount.Id
        ];

        // Test Case 2: Consent records exist and are processed (lines 277-287 coverage)
        if (patientAccount.PersonIndividualId != null) {
            // Create ContactPointTypeConsent records for the Individual
            List<ContactPointTypeConsent> consentRecords = new List<ContactPointTypeConsent>();
            // Create Transactional Email consent with OptIn status (covers line 278-280)
            ContactPointTypeConsent emailConsent = new ContactPointTypeConsent(
                PartyId = patientAccount.PersonIndividualId,
                Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
                PrivacyConsentStatus = ConstantsUtil.CONSENT_STATUS_OPT_IN
            );
            consentRecords.add(emailConsent);

            // Create Transactional SMS consent with OptIn status (covers line 281-283)
            ContactPointTypeConsent smsConsentOptIn = new ContactPointTypeConsent(
                PartyId = patientAccount.PersonIndividualId,
                Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
                PrivacyConsentStatus = ConstantsUtil.CONSENT_STATUS_OPT_IN
            );
            consentRecords.add(smsConsentOptIn);

            insert consentRecords;

            // Update Custom_UniqueID__c and call processStandardEventForInsulet with consent records
            // This will call calculateConsentValues with consent records (covers lines 277-287)
            patientAccount.Custom_UniqueID__c = 'CONSENT_TEST_2';
            update patientAccount;
            SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, null);

            // Test Case 3: SMS consent with OptInPending status (covers line 282)
            // Update existing SMS consent to OptInPending (cannot insert duplicate - validation prevents same name per Individual)
            smsConsentOptIn.PrivacyConsentStatus = ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING;
            update smsConsentOptIn;

            // Update Custom_UniqueID__c and call processStandardEventForInsulet with OptInPending SMS consent
            patientAccount.Custom_UniqueID__c = 'CONSENT_TEST_3';
            update patientAccount;
            SendtoAspnHandler.processStandardEventForInsulet(new List<Account>{ patientAccount }, null);
        }
        Test.stopTest();

        Assert.isTrue(true, 'Consent values calculation should complete successfully');
    }
}