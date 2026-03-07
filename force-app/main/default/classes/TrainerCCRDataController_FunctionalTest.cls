/**
 * @author      : Ayush Sharma
 * @created Date: 1st Dec 2025
 * @description : Test class for TrainerCCRDataController 
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       1st Dec 2025        Ayush Sharma            Initial Version
 */
@IsTest
private class TrainerCCRDataController_FunctionalTest {
    
    /**
     * @description Setup method to create common test data
     */
    @TestSetup
    static void setupTestData() {
        
        // Create External Trainer User
        User trainerUser = TestDataFactory.getTestUser('External Trainers', 
            new Map<String, Object>{
                'FirstName' => 'External',
                'LastName' => 'Trainer'
            }
        );
        insert trainerUser;
        
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
        
        System.runAs(testUser){
            
            // Create Patient Account
            Account patientAccount = TestDataFactory.getAccountofPatientRecordType(
                new Map<String, Object>{
                    'FirstName' => 'John',
                    'LastName' => 'Patient',
                    'PersonEmail' => 'john.patient@test.com'
                }
            );
            insert patientAccount;
            
            // Query to get the PersonContactId
            patientAccount = [SELECT Id, PersonContactId FROM Account WHERE Id = :patientAccount.Id];
            
            // Create Related Contacts (Legal Guardians and Authorized Callers)
            List<Contact> relatedContacts = new List<Contact>();
            
            // Create 1 Legal Guardian contacts
            relatedContacts.add(TestDataFactory.getContact(
                new Map<String, Object>{
                    'FirstName' => 'Guardian',
                    'LastName' => 'Contact1',
                    'Email' => 'guardian1' + '@test.com',
                    'Phone' => '555-000-' + String.valueOf(1).leftPad(4, '0')
                }
            ));
            
            // Create 1 Authorized Caller contacts
            relatedContacts.add(TestDataFactory.getContact(
                new Map<String, Object>{
                    'FirstName' => 'Caller',
                    'LastName' => 'Contact2',
                    'Email' => 'caller2' + '@test.com',
                    'Phone' => '555-000-' + String.valueOf(2).leftPad(4, '0')
                }
            ));
            
            insert relatedContacts;
            
            // Create Party Role Relations
            List<PartyRoleRelation> partyRoles = new List<PartyRoleRelation>();
            
            // Legal Guardian roles
            partyRoles.add(new PartyRoleRelation(
                RoleName = ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME,
                RelatedRoleName = 'Test 1',
                RelationshipObjectName = ConstantsUtil.CONTACT_CONTACT_RELATION
            ));
            
            // Authorized Caller roles
            partyRoles.add(new PartyRoleRelation(
                RoleName = ConstantsUtil.AUTHORIZED_CALLER_RELATIONSHIP_NAME,
                RelatedRoleName = 'Test 2',
                RelationshipObjectName = ConstantsUtil.CONTACT_CONTACT_RELATION
            ));
            
            insert partyRoles;
            
            // Create ContactContactRelations
            List<ContactContactRelation> ccrs = new List<ContactContactRelation>();
            for (Integer i = 0; i < 2; i++) {
                ccrs.add(new ContactContactRelation(
                    ContactId = patientAccount.PersonContactId,
                    RelatedContactId = relatedContacts[i].Id,
                    PartyRoleRelationId = partyRoles[i].Id
                ));
            }
            
            insert ccrs;
        }
    }
    
    /**
     * @description Helper method to get External Trainer user for System.runAs() in tests
     * @return User External Trainer user from test setup
     */
    private static User getTrainerUser() {
        return [SELECT Id FROM User WHERE LastName = 'Trainer' AND FirstName = 'External' LIMIT 1];
    }
    
    /**
     * @description Test positive scenario - valid account with related contacts
     * Verifies that related contact rows are returned correctly with all fields populated
     */
    @IsTest
    static void testGetRelatedContactRowsPositiveScenario() {
        // Given: Patient Account with related contacts
        Account patientAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Given: External Trainer user
        User trainerUser = getTrainerUser();
        
        System.runAs(trainerUser){
            // When: Retrieve related contact rows
            Test.startTest();
            List<TrainerCCRDataController.RelatedContactRow> results = 
                TrainerCCRDataController.getRelatedContactRowsByAccount(patientAccount.Id);
            Test.stopTest();
            
            // Then: Verify results
            Assert.isNotNull(results, 'Results should not be null');
            Assert.areEqual(2, results.size(), 'Should return 2 related contacts (1 guardians + 1 callers)');
            
            // Verify Legal Guardian relationships
            Integer guardianCount = 0;
            Integer callerCount = 0;
            
            for (TrainerCCRDataController.RelatedContactRow row : results) {
                Assert.isNotNull(row.name, 'Name should not be null');
                Assert.isNotNull(row.email, 'Email should not be null');
                Assert.isNotNull(row.phone, 'Phone should not be null');
                Assert.isNotNull(row.relationship, 'Relationship should not be null');
                
                if (row.relationship == ConstantsUtil.GUARDIAN_RELATIONSHIP_NAME) {
                    guardianCount++;
                    Assert.isTrue(row.name.contains('Guardian'), 'Guardian contact name should contain "Guardian"');
                } else if (row.relationship == ConstantsUtil.AUTHORIZED_CALLER_RELATIONSHIP_NAME) {
                    callerCount++;
                    Assert.isTrue(row.name.contains('Caller'), 'Caller contact name should contain "Caller"');
                }
            }
            
            Assert.areEqual(1, guardianCount, 'Should have 1 Legal Guardian relationships');
            Assert.areEqual(1, callerCount, 'Should have 1 Authorized Caller relationships');
        }
    }
    
    /**
     * @description Test negative scenario - null account id
     * Verifies that empty list is returned when accountId is null
     */
    @IsTest
    static void testGetRelatedContactRowsNullAccountId() {
        // Given: External Trainer user
        User trainerUser = getTrainerUser();
        
        System.runAs(trainerUser){
            // When: Pass null accountId
            Test.startTest();
            List<TrainerCCRDataController.RelatedContactRow> results = 
                TrainerCCRDataController.getRelatedContactRowsByAccount(null);
            Test.stopTest();
            
            // Then: Verify empty list is returned
            Assert.isNotNull(results, 'Results should not be null');
            Assert.isTrue(results.isEmpty(), 'Should return empty list for null accountId');
        }
    }
    
    /**
     * @description Test negative scenario - invalid SObject type
     * Verifies that empty list is returned when id is not an Account id
     */
    @IsTest
    static void testGetRelatedContactRowsInvalidSObjectType() {
        // Given: Create a Contact to get a Contact Id
        Contact testContact = TestDataFactory.getContact();
        insert testContact;
        
        // Given: External Trainer user
        User trainerUser = getTrainerUser();
        
        System.runAs(trainerUser){
            // When: Pass Contact Id instead of Account Id
            Test.startTest();
            List<TrainerCCRDataController.RelatedContactRow> results = 
                TrainerCCRDataController.getRelatedContactRowsByAccount(testContact.Id);
            Test.stopTest();
            
            // Then: Verify empty list is returned
            Assert.isNotNull(results, 'Results should not be null');
            Assert.isTrue(results.isEmpty(), 'Should return empty list for invalid SObject type');
        }
    }
    

    /**
     * @description Test negative scenario - account with contacts but no CCRs
     * Verifies that empty list is returned when contacts exist but no CCRs
     */
    @IsTest
    static void testGetRelatedContactRowsAccountWithContactsButNoCCRs() {
        // Given: Create Patient Account and delete all CCRs
        Account patientAccount = [SELECT Id FROM Account LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact WHERE AccountId = :patientAccount.Id];
        List<ContactContactRelation> ccrs = [SELECT Id FROM ContactContactRelation WHERE ContactId IN :contacts];
        delete ccrs;
        
        // Given: External Trainer user
        User trainerUser = getTrainerUser();
        
        System.runAs(trainerUser){
            // When: Retrieve related contacts
            Test.startTest();
            List<TrainerCCRDataController.RelatedContactRow> results = 
                TrainerCCRDataController.getRelatedContactRowsByAccount(patientAccount.Id);
            Test.stopTest();
            
            // Then: Verify empty list is returned
            Assert.isNotNull(results, 'Results should not be null');
            Assert.isTrue(results.isEmpty(), 'Should return empty list when no CCRs exist');
        }
    }
    
    /**
     * @description Test exception handling scenario
     * Verifies that custom exception is caught and empty list is returned
     */
    @IsTest
    static void testGetRelatedContactRowsCustomException() {
        // Given: Patient Account with related contacts
        Account patientAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Given: External Trainer user
        User trainerUser = getTrainerUser();
        ConstantsUtil.customExceptionSwitch = true;
        
        System.runAs(trainerUser){
            // When: Enable custom exception switch and call method
            Test.startTest();
            
            List<TrainerCCRDataController.RelatedContactRow> results = 
                TrainerCCRDataController.getRelatedContactRowsByAccount(patientAccount.Id);
            Test.stopTest();
            
            // Then: Verify empty list is returned on exception
            Assert.isNotNull(results, 'Results should not be null');
            Assert.isTrue(results.isEmpty(), 'Should return empty list when exception occurs');
        }
               
        // Reset the switch
        ConstantsUtil.customExceptionSwitch = false;
    }
    
    /**
     * @description Test getAccountContactIds private method
     * Verifies that contact ids are correctly retrieved for an account
     */
    @IsTest
    static void testGetAccountContactIdsSuccess() {
        // Given: Patient Account
        Account patientAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Given: External Trainer user
        User trainerUser = getTrainerUser();
        
        System.runAs(trainerUser){
            // When: Call private method via reflection/test context
            Test.startTest();
            Set<Id> contactIds = TrainerCCRDataController.getAccountContactIds(patientAccount.Id);
            Test.stopTest();
            
            // Then: Verify contact ids are returned
            Assert.isNotNull(contactIds, 'Contact Ids should not be null');
            Assert.isFalse(contactIds.isEmpty(), 'Should return at least one contact id');
        }
    }
    
    /**
     * @description Test getCcrForContacts private method
     * Verifies that CCRs are correctly retrieved for contact ids
     */
    @IsTest
    static void testGetCcrForContactsSuccess() {
        // Given: Patient Account and Contact Ids
        Account patientAccount = [SELECT Id, PersonContactId FROM Account LIMIT 1];
        Set<Id> contactIds = new Set<Id>{patientAccount.PersonContactId};
        // Given: External Trainer user
        User trainerUser = getTrainerUser();
        
        System.runAs(trainerUser){
            // When: Call private method
            Test.startTest();
            List<ContactContactRelation> ccrs = TrainerCCRDataController.getCcrForContacts(contactIds);
            Test.stopTest();
            
            
            
            // Then: Verify CCRs are returned
            Assert.isNotNull(ccrs, 'CCRs should not be null');
            Assert.areEqual(2, ccrs.size(), 'Should return 2 CCRs from test setup');
            
            // Verify CCR fields are populated
            for (ContactContactRelation ccr : ccrs) {
                Assert.isNotNull(ccr.PartyRoleRelation, 'PartyRoleRelation should be populated');
                Assert.isNotNull(ccr.RelatedContact, 'RelatedContact should be populated');
                Assert.isNotNull(ccr.PartyRoleRelation.RoleName, 'RoleName should not be null');
            }
        }
    }
    
    /**
     * @description Test buildRows private method
     * Verifies that CCRs are correctly transformed into RelatedContactRow objects
     */
    @IsTest
    static void testBuildRowsSuccess() {
        // Given: Query CCRs from test setup
        Account patientAccount = [SELECT Id, PersonContactId FROM Account LIMIT 1];
        List<ContactContactRelation> ccrs = [
            SELECT Id, PartyRoleRelation.RoleName, 
                   RelatedContact.Name, RelatedContact.Email, RelatedContact.Phone
            FROM ContactContactRelation
            WHERE ContactId = :patientAccount.PersonContactId
        ];
        
        // Given: External Trainer user
        User trainerUser = getTrainerUser();
        
        System.runAs(trainerUser){
            // When: Call buildRows method
            Test.startTest();
            List<TrainerCCRDataController.RelatedContactRow> rows = TrainerCCRDataController.buildRows(ccrs);
            Test.stopTest();
            
            // Then: Verify rows are built correctly
            Assert.isNotNull(rows, 'Rows should not be null');
            Assert.areEqual(ccrs.size(), rows.size(), 'Should return same number of rows as CCRs');
            
            // Verify each row has correct data
            for (Integer i = 0; i < rows.size(); i++) {
                TrainerCCRDataController.RelatedContactRow row = rows[i];
                ContactContactRelation ccr = ccrs[i];
                
                Assert.areEqual(ccr.RelatedContact.Name, row.name, 'Row name should match CCR RelatedContact.Name');
                Assert.areEqual(ccr.RelatedContact.Email, row.email, 'Row email should match CCR RelatedContact.Email');
                Assert.areEqual(ccr.RelatedContact.Phone, row.phone, 'Row phone should match CCR RelatedContact.Phone');
                Assert.areEqual(ccr.PartyRoleRelation.RoleName, row.relationship, 'Row relationship should match CCR RoleName');
            }
        }
    }
    
    /**
     * @description Test RelatedContactRow constructor with null values
     * Verifies that the wrapper class handles null inputs gracefully
     */
    @IsTest
    static void testRelatedContactRowConstructorWithNullValues() {
        
        // Given: External Trainer user
        User trainerUser = getTrainerUser();
        
        System.runAs(trainerUser){
            // When: Create RelatedContactRow with null inputs
            Test.startTest();
            TrainerCCRDataController.RelatedContactRow rowWithNullContact = 
                new TrainerCCRDataController.RelatedContactRow(new PartyRoleRelation(), null);
            TrainerCCRDataController.RelatedContactRow rowWithNullRole = 
                new TrainerCCRDataController.RelatedContactRow(null, new Contact());
            TrainerCCRDataController.RelatedContactRow rowWithBothNull = 
                new TrainerCCRDataController.RelatedContactRow(null, null);
            Test.stopTest();
            
            // Then: Verify null handling
            Assert.isNull(rowWithNullContact.name, 'Name should be null when Contact is null');
            Assert.isNull(rowWithNullContact.email, 'Email should be null when Contact is null');
            Assert.isNull(rowWithNullContact.phone, 'Phone should be null when Contact is null');
            
            Assert.isNull(rowWithNullRole.relationship, 'Relationship should be null when PartyRoleRelation is null');
            
            Assert.isNull(rowWithBothNull.name, 'All fields should be null when both inputs are null');
            Assert.isNull(rowWithBothNull.email, 'All fields should be null when both inputs are null');
            Assert.isNull(rowWithBothNull.phone, 'All fields should be null when both inputs are null');
            Assert.isNull(rowWithBothNull.relationship, 'All fields should be null when both inputs are null');
        }
    }
    
    /**
     * @description Test with account that has wrong record type
     * Verifies that only Patient record type accounts are processed
     */
    @IsTest
    static void testGetRelatedContactRowsWrongRecordType() {
        // Given: Create an Account with Provider record type
        Account providerAccount = TestDataFactory.getAccountofProviderRecordType(
            new Map<String, Object>{
                'FirstName' => 'Provider',
                'LastName' => 'Account',
                'PersonEmail' => 'provider.account@test.com',
                'BillingPostalCode' => '234567'
            }
        );
        insert providerAccount;
        
        // Given: External Trainer user
        User trainerUser = getTrainerUser();
        
        System.runAs(trainerUser){
            // When: Retrieve related contacts for Provider account
            Test.startTest();
            List<TrainerCCRDataController.RelatedContactRow> results = 
                TrainerCCRDataController.getRelatedContactRowsByAccount(providerAccount.Id);
            Test.stopTest();
            
            // Then: Verify empty list is returned (only Patient record type is queried)
            Assert.isNotNull(results, 'Results should not be null');
            Assert.isTrue(results.isEmpty(), 'Should return empty list for non-Patient account');
        }
    }
}