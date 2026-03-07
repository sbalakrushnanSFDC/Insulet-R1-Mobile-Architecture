/**
    * @description Test data factory class for creating test records
    * @author Bijayalaxmi Prusty
	* @date 01-10-2025
	*  * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       1st Oct 2025        Bijayalaxmi Prusty            Initial Version
 * V2.0.0       24th Oct 2025       Ankur Chauhan                 Added classes to create Training, Territory,TerritoryModel and User Record
 * V2.0.0       30th Oct 2025       Priyansh Shukla               Added classes to create HealthcarePractitionerFacility record
 * V2.0.1       06th Nov 2025       Bijayalaxmi Prusty            Modified(US - NGASIM-622)
 * V2.0.2       01st Dec 2025       Bijayalaxmi Prusty            Modified(US - NGASIM-1050)
 * V2.0.3       2nd Dec 2025        Yogesh Rana                   Added methods to create Observation records(US - NGOMCT-752)
 * V2.0.4       2nd Dec 2025        Srinivas Shanigarapu          Added methods to create ContentVersion and Content DocumentLink records(US - NGOMCT-724)
 * V2.0.5       8th Dec 2025        Ankur Chauhan                 Added class to create Conga Template Record
 * V2.0.6		14th JAN 2025		Shashank Nigam				  Added Method for AccountContactRelation(ACR) creation (US - NGOMCT-1353)
 */
@SuppressWarnings('PMD.ExcessivePublicCount,PMD.CyclomaticComplexity')
@IsTest
public class TestDataFactory {
    // Counter for generating unique values
    private static Integer counter = 1;
    /**
     * @description Creates a Lead record for testing
     * @param leadFieldMap Additional field values to set on the Lead
     * @return Lead record with test data
     */
    public static Lead getLead(Map<String, Object> leadFieldMap) {
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Email = 'testlead@example.com',
            Status = 'Open',
            LeadSource = 'Web',
            Street = '9th Street',
            City = 'San Francisco',
            State = 'California',
            PostalCode = '94103',
            Country = 'United States'
        );

        // Apply any additional field values
        if (leadFieldMap != null && !leadFieldMap.isEmpty()) {
            for (String fieldName : leadFieldMap.keySet()) {
                testLead.put(fieldName, leadFieldMap.get(fieldName));
            }
        }

        return testLead;
    }


   /**
     * @description Creates and inserts a test Community User.
     * @param acct The Account (Person Account) linked to the user's Contact.
     * @param portalProfile The Profile to assign to the Community User (e.g., 'External Trainer').
     * @param aliasPrefix A prefix used to create unique user names and aliases.
     * @return The newly inserted Community User record.
     */
    public static User getCommunityUser(Account acct, Profile portalProfile, String aliasPrefix) {
        String uniq = String.valueOf(Datetime.now().getTime()); 
        String alias = (aliasPrefix + uniq).left(8);


        User portalUser = new User(
                Email             = 'portal' + uniq + '@test.com',
                ProfileId         = portalProfile.Id,
                UserName          = 'portal' + uniq + '@portal.test',
                Alias             = alias,
                TimeZoneSidKey    = 'America/Los_Angeles',
                EmailEncodingKey  = 'UTF-8',
                LocaleSidKey      = 'en_US',
                LanguageLocaleKey = 'en_US',
                ContactId         = acct.PersonContactId,
                FirstName         = ('Portal' + aliasPrefix).left(40),
                LastName          = ('User' + aliasPrefix).left(40),
                IsActive          = true
            );
            
         
            insert portalUser;
       
        return portalUser;
    }
    /**
     * @description Creates a Lead record for testing with default values
     * @return Lead record with test data
     */
    public static Lead getLead() {
        return getLead(null);
    }

    /**
     * @description Creates an Account record of Patient record type
     * @param accountFieldMap Additional field values to set on the Account
     * @return Account record configured as Patient PersonAccount
     */
    public static Account getAccountofPatientRecordType(Map<String, Object> accountFieldMap) {
        // Use Patient record type from ConstantsUtil for PersonAccount
        Account testAccount = new Account(
            RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_RT,
            FirstName = 'Test',
            LastName = 'Patient',
            PersonEmail = 'testpatient@example.com',
            BillingPostalCode ='23456'
        );

        // Apply any additional field values
        if (accountFieldMap != null && !accountFieldMap.isEmpty()) {
            for (String fieldName : accountFieldMap.keySet()) {
                testAccount.put(fieldName, accountFieldMap.get(fieldName));
            }
        }

        return testAccount;
    }
    /**
     * @description Creates a list of ContentDocument records for testing
     * @param noOfFiles The number of ContentDocument records to create.
     * @return A list of ContentDocument records.
     */
    public static List<ContentVersion> createContentVersions(Integer noOfFiles) {
        List<ContentVersion> contentVersionList = new List<ContentVersion>();
        
        for (Integer contentVerIndex= 0; contentVerIndex < noOfFiles; contentVerIndex++) {
            ContentVersion contVer = new ContentVersion(
                Title = 'Test Document'+contentVerIndex,
                PathOnClient = 'SF_ELO_Code.txt',
                VersionData = Blob.valueOf('Test Content'),
                IsMajorVersion = true
            );
            contentVersionList.add(contVer);
        }
        
        Insert contentVersionList; 
        return contentVersionList;
    }
    
    /**
     * @description Creates ContentDocumentLink records for the given recordId and ContentVersion records
     * @param recordId The ID of the record to link the ContentVersion records to.
     * @param contentVersionList The list of ContentVersion records to link to the record.
     */
    public static void createContentDocumentLinks(String recordId, List<ContentVersion> contentVersionList) {
        
        if (recordId == null || contentVersionList == null || contentVersionList.isEmpty()) {
            return;
        }
        
        Set<Id> contentVersionIds = new Set<Id>();
        for (ContentVersion contentVer : contentVersionList) {
            contentVersionIds.add(contentVer.Id);
        }
        
        List<ContentVersion> contentVersionUpdatedList = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
        ];
        
        List<ContentDocumentLink> contentDocLinkList = new List<ContentDocumentLink>();
        for (contentVersion contentVer : contentVersionUpdatedList) {
            ContentDocumentLink contDoclink = new ContentDocumentLink(
                LinkedEntityId = recordId,
                ContentDocumentId = contentVer.ContentDocumentId
            );
            contentDocLinkList.add(contDoclink);
        }
        
        Insert contentDocLinkList;
        
    }
    
    /**
     * @description Creates an Account record of Patient record type with default values
     * @return Account record configured as Patient PersonAccount
     */
    public static Account getAccountofPatientRecordType() {
        return getAccountofPatientRecordType(null);
    }
    /**
     * @description Creates an Account record of Practice record type
     * @param accountFieldMap Additional field values to set on the Account
     * @return Account record configured as Practice Account
     */
    public static Account getAccountofPracticeRecordType(Map<String, Object> accountFieldMap) {
        // Get Practice record type for Account
        //Id practiceRecordTypeId = getAccountRecordTypeId(ConstantsUtil.ACCOUNT_PRACTICE_RT);
        Account testAccount = new Account(
            RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT,
            Name = 'Test Practice Account',
            Type = 'Customer - Direct',
            Phone = '555-123-4567',
            BillingPostalCode ='23456'
        );

        // Apply any additional field values
        if (accountFieldMap != null && !accountFieldMap.isEmpty()) {
            for (String fieldName : accountFieldMap.keySet()) {
                testAccount.put(fieldName, accountFieldMap.get(fieldName));
            }
        }

        return testAccount;
    }
    /**
     * @description Creates an Account record of Practice record type with default values
     * @return Account record configured as Practice Account
     */
    public static Account getAccountofPracticeRecordType() {
        return getAccountofPracticeRecordType(null);
    }
     /**
     * @description Creates an Account record of Trainer record type
     * @param accountFieldMap Additional field values to set on the Account
     * @return Account record configured as Trainer PersonAccount
     */
    public static Account getAccountofTrainerRecordType(Map<String, Object> accountFieldMap) {
        // Use Patient record type from ConstantsUtil for PersonAccount
        Account testAccount = new Account(
            RecordTypeId = ConstantsUtil.ACCOUNT_TRAINER_RT,
            FirstName = 'Test',
            LastName = 'Trainer',
            PersonEmail = 'testtrainer@example.com'
        );

        // Apply any additional field values
        if (accountFieldMap != null && !accountFieldMap.isEmpty()) {
            for (String fieldName : accountFieldMap.keySet()) {
                testAccount.put(fieldName, accountFieldMap.get(fieldName));
            }
        }

        return testAccount;
    }
     /**
     * @description Creates an Account record of Practice record type with default values
     * @return Account record configured as Practice Account
     */
    public static Account getAccountofTrainerRecordType() {
        return getAccountofTrainerRecordType(null);
    }
    /**
     * @description Creates an Account record of Provider record type
     * @param accountFieldMap Additional field values to set on the Account
     * @return Account record configured as Provider PersonAccount
     */
    public static Account getAccountofProviderRecordType(Map<String, Object> accountFieldMap) {
        Account testAccount = new Account(
            RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT,
            FirstName = 'Test',
            LastName = 'Provider',
            PersonEmail = 'testprovider@example.com'
        );

        // Apply any additional field values
        if (accountFieldMap != null && !accountFieldMap.isEmpty()) {
            for (String fieldName : accountFieldMap.keySet()) {
                testAccount.put(fieldName, accountFieldMap.get(fieldName));
            }
        }

        return testAccount;
    }
    /**
     * @description Creates an Account record of Provider record type with default values
     * @return Account record configured as Provider PersonAccount
     */
    public static Account getAccountofProviderRecordType() {
        return getAccountofProviderRecordType(null);
    }
    /**
     * @description Helper method to get PersonAccount record type Id using schema
     * @param recordTypeName The record type developer name
     * @return Id of the record type or null if not found
     */
    private static Id getPersonAccountRecordTypeId(String recordTypeName) {
        try {
            Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get(recordTypeName)
                .getRecordTypeId();
            return recordTypeId;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Helper method to get regular Account record type Id using schema
     * @param recordTypeName The record type developer name
     * @return Id of the record type or null if not found
     */
    private static Id getAccountRecordTypeId(String recordTypeName) {
        try {
            Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get(recordTypeName)
                .getRecordTypeId();
            return recordTypeId;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Creates an Individual record for testing
     * @param individualFieldMap Additional field values to set on the Individual
     * @return Individual record with test data
     */
    public static Individual getIndividual(Map<String, Object> individualFieldMap) {
        Individual testIndividual = new Individual(
            FirstName = 'Test',
            LastName = 'Individual'
        );

        // Apply any additional field values
        if (individualFieldMap != null && !individualFieldMap.isEmpty()) {
            for (String fieldName : individualFieldMap.keySet()) {
                testIndividual.put(fieldName, individualFieldMap.get(fieldName));
            }
        }

        return testIndividual;
    }

    /**
     * @description Creates an Individual record for testing with default values
     * @return Individual record with test data
     */
    public static Individual getIndividual() {
        return getIndividual(null);
    }

    /**
     * @description Creates multiple PartyConsent records for bulk testing
     * @param count Number of PartyConsent records to create
     * @param partyConsentFieldMap Base field values to apply to all PartyConsent records
     * @param typeValues Optional list of Type__c values to assign to each record (if provided, must match count)
     * @return List of PartyConsent records
     */
    public static List<PartyConsent> getPartyConsents(Integer count, Map<String, Object> partyConsentFieldMap, List<String> typeValues) {
        List<PartyConsent> partyConsents = new List<PartyConsent>();
        for (Integer i = 0; i < count; i++) {
            PartyConsent testPartyConsent = new PartyConsent();

            // Set default Status__c
            testPartyConsent.Status__c = 'Opted-in';

            // Apply base field values
            if (partyConsentFieldMap != null && !partyConsentFieldMap.isEmpty()) {
                for (String fieldName : partyConsentFieldMap.keySet()) {
                    testPartyConsent.put(fieldName, partyConsentFieldMap.get(fieldName));
                }
            }

            // Apply Type__c value if provided
            if (typeValues != null && typeValues.size() > i) {
                testPartyConsent.Type__c = typeValues[i];
            }

            partyConsents.add(testPartyConsent);
        }
        return partyConsents;
    }

    /**
     * @description Creates a DataUsePurpose record for testing
     * @param dataUsePurposeFieldMap Additional field values to set on the DataUsePurpose
     * @return DataUsePurpose record with test data
     */
    public static DataUsePurpose getDataUsePurpose(Map<String, Object> dataUsePurposeFieldMap) {
        DataUsePurpose testDataUsePurpose = new DataUsePurpose(
            Name = 'Test Data Use Purpose ' + counter++
        );

        // Apply any additional field values
        if (dataUsePurposeFieldMap != null && !dataUsePurposeFieldMap.isEmpty()) {
            for (String fieldName : dataUsePurposeFieldMap.keySet()) {
                testDataUsePurpose.put(fieldName, dataUsePurposeFieldMap.get(fieldName));
            }
        }

        return testDataUsePurpose;
    }
    /**
     * @description Creates multiple Lead records for bulk testing
     * @param count Number of leads to create
     * @param leadFieldMap Base field values to apply to all leads
     * @return List of Lead records
     */
    public static List<Lead> getLeads(Integer count, Map<String, Object> leadFieldMap) {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> fieldsForLead = new Map<String, Object>();
            if (leadFieldMap != null) {
                fieldsForLead.putAll(leadFieldMap);
            }
            // Make each lead unique
            fieldsForLead.put('LastName', 'Lead' + i);
            fieldsForLead.put('Email', 'testlead' + i + '@example.com');
            leads.add(getLead(fieldsForLead));
        }
        return leads;
    }

    /**
     * @description Creates multiple Account records for bulk testing
     * @param count Number of accounts to create
     * @param accountFieldMap Base field values to apply to all accounts
     * @param recordType 'Patient' for Patient PersonAccount, 'Practice' for Practice Account
     * @return List of Account records
     */
    public static List<Account> getAccounts(Integer count, Map<String, Object> accountFieldMap, String recordType) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> fieldsForAccount = new Map<String, Object>();
            if (accountFieldMap != null) {
                fieldsForAccount.putAll(accountFieldMap);
            }

            Account acc;
            if (recordType == ConstantsUtil.ACCOUNT_PATIENT_RT) {
                // Make each patient unique
                fieldsForAccount.put('LastName', 'Patient' + i);
                fieldsForAccount.put('PersonEmail', 'testpatient' + i + '@example.com');
                acc = getAccountofPatientRecordType(fieldsForAccount);
            } else if (recordType == ConstantsUtil.ACCOUNT_PRACTICE_RT) {
                // Make each practice unique
                fieldsForAccount.put('Name', 'Test Practice ' + i);
                acc = getAccountofPracticeRecordType(fieldsForAccount);
            }else {
                throw new TestDataFactoryException('Invalid record type: ' + recordType + '. Use "Patient" or "Practice".');
            }
            accounts.add(acc);
        }
        return accounts;
    }

    /**
     * @description Creates a Contact record for testing
     * @param contactFieldMap Additional field values to set on the Contact
     * @return Contact record with test data
     */
    public static Contact getContact(Map<String, Object> contactFieldMap) {
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'testcontact@example.com'
        );

        // Apply any additional field values
        if (contactFieldMap != null && !contactFieldMap.isEmpty()) {
            for (String fieldName : contactFieldMap.keySet()) {
                testContact.put(fieldName, contactFieldMap.get(fieldName));
            }
        }

        return testContact;
    }
    /**
     * @description Creates a Contact record for testing with default values
     * @return Contact record with test data
     */
    public static Contact getContact() {
        return getContact(null);
    }

    /**
     * @description Creates multiple Contact records for bulk testing
     * @param count Number of contacts to create
     * @param contactFieldMap Base field values to apply to all contacts
     * @return List of Contact records
     */
    public static List<Contact> getContacts(Integer count, Map<String, Object> contactFieldMap) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> fieldsForContact = new Map<String, Object>();
            if (contactFieldMap != null) {
                fieldsForContact.putAll(contactFieldMap);
            }
            // Make each contact unique
            fieldsForContact.put('LastName', 'Contact' + i);
            fieldsForContact.put('Email', 'testcontact' + i + '@example.com');
            contacts.add(getContact(fieldsForContact));
        }
        return contacts;
    }
    /**
     * @description Creates a test User for different user context testing
     * @param profileName Profile name for the user
     * @param userFieldMap Additional field values to set on the User
     * @return User record with test data
     */
    public static User getTestUser(String profileName, Map<String, Object> userFieldMap) {
        // Get profile ID
        Profile testProfile;
        try {
            testProfile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        } catch (QueryException e) {
            // Fallback to Standard User profile
            testProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        }

        String uniqueUserName = 'testuser' + counter++ + '@testdomain.com';

        User testUser = new User(
            Alias = 'tuser' + counter,
            Email = uniqueUserName,
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Test',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = testProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = uniqueUserName
        );

        // Apply any additional field values
        if (userFieldMap != null && !userFieldMap.isEmpty()) {
            for (String fieldName : userFieldMap.keySet()) {
                testUser.put(fieldName, userFieldMap.get(fieldName));
            }
        }

        return testUser;
    }

    /**
     * @description Creates a test User with Standard User profile
     * @return User record with test data
     */
    public static User getTestUser() {
        return getTestUser('Standard User', null);
    }

    /**
     * @description Creates a ContactPointAddress record for testing
     * @param addressFieldMap Additional field values to set on the ContactPointAddress
     * @return ContactPointAddress record with test data
     */
    public static ContactPointAddress getContactPointAddress(Map<String, Object> addressFieldMap) {
        ContactPointAddress testAddress = new ContactPointAddress(
            Name = 'Test Address',
            Street = 'Test Street',
            City = 'Test City',
            State = 'California',
            PostalCode = '12345',
            Country = 'United States',
            IsPrimary = true,
            IsDefault = true,
            AddressType = 'Billing',
            IsActive = true
        );

        // Apply any additional field values
        if (addressFieldMap != null && !addressFieldMap.isEmpty()) {
            for (String fieldName : addressFieldMap.keySet()) {
                testAddress.put(fieldName, addressFieldMap.get(fieldName));
            }
        }

        return testAddress;
    }

    /**
     * @description Creates a ContactPointAddress record with default values
     * @return ContactPointAddress record with test data
     */
    public static ContactPointAddress getContactPointAddress() {
        return getContactPointAddress(null);
    }

    /**
     * @description Creates a ContactPointEmail record for testing
     * @param emailFieldMap Additional field values to set on the ContactPointEmail
     * @return ContactPointEmail record with test data
     */
    public static ContactPointEmail getContactPointEmail(Map<String, Object> emailFieldMap) {
        ContactPointEmail testEmail = new ContactPointEmail(
            EmailAddress = 'test' + counter++ + '@example.com',
            IsPrimary = true
        );

        // Apply any additional field values
        if (emailFieldMap != null && !emailFieldMap.isEmpty()) {
            for (String fieldName : emailFieldMap.keySet()) {
                testEmail.put(fieldName, emailFieldMap.get(fieldName));
            }
        }

        return testEmail;
    }

    /**
     * @description Creates a ContactPointEmail record with default values
     * @return ContactPointEmail record with test data
     */
    public static ContactPointEmail getContactPointEmail() {
        return getContactPointEmail(null);
    }

    /**
     * @description Creates a ContactPointPhone record for testing
     * @param phoneFieldMap Additional field values to set on the ContactPointPhone
     * @return ContactPointPhone record with test data
     */
    public static ContactPointPhone getContactPointPhone(Map<String, Object> phoneFieldMap) {
        ContactPointPhone testPhone = new ContactPointPhone(
            TelephoneNumber = '555' + String.valueOf(1000000 + counter++),
            IsPrimary = true
        );

        // Apply any additional field values
        if (phoneFieldMap != null && !phoneFieldMap.isEmpty()) {
            for (String fieldName : phoneFieldMap.keySet()) {
                testPhone.put(fieldName, phoneFieldMap.get(fieldName));
            }
        }

        return testPhone;
    }

    /**
     * @description Creates a ContactPointPhone record with default values
     * @return ContactPointPhone record with test data
     */
    public static ContactPointPhone getContactPointPhone() {
        return getContactPointPhone(null);
    }

    /**
     * @description Creates an Opportunity record for testing
     * @param opportunityFieldMap Additional field values to set on the Opportunity
     * @return Opportunity record with test data
     */
    public static Opportunity getOpportunity(Map<String, Object> opportunityFieldMap) {
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity ' + counter++,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );

        // Apply any additional field values
        if (opportunityFieldMap != null && !opportunityFieldMap.isEmpty()) {
            for (String fieldName : opportunityFieldMap.keySet()) {
                testOpportunity.put(fieldName, opportunityFieldMap.get(fieldName));
            }
        }

        return testOpportunity;
    }

    /**
     * @description Creates an Opportunity record with default values
     * @return Opportunity record with test data
     */
    public static Opportunity getOpportunity() {
        return getOpportunity(null);
    }

    /**
     * @description Creates a HealthcarePractitionerFacility record for testing
     * @param facilityFieldMap Additional field values to set on the HealthcarePractitionerFacility
     * @return HealthcarePractitionerFacility record with test data
     */
    public static HealthcarePractitionerFacility getHealthcarePractitionerFacility(Map<String, Object> facilityFieldMap) {
        HealthcarePractitionerFacility testFacility = new HealthcarePractitionerFacility(
            Name = 'Test Healthcare Facility'
        );

        // Apply any additional field values
        if (facilityFieldMap != null && !facilityFieldMap.isEmpty()) {
            for (String fieldName : facilityFieldMap.keySet()) {
                testFacility.put(fieldName, facilityFieldMap.get(fieldName));
            }
        }

        return testFacility;
    }

    /**
     * @description Creates a HealthcarePractitionerFacility record with default values
     * @return HealthcarePractitionerFacility record with test data
     */
    public static HealthcarePractitionerFacility getHealthcarePractitionerFacility() {
        return getHealthcarePractitionerFacility(null);
    }

    /**
     * @description Creates multiple HealthcarePractitionerFacility records for bulk testing
     * @param count Number of facilities to create
     * @param facilityFieldMap Base field values to apply to all facilities
     * @return List of HealthcarePractitionerFacility records
     */
    public static List<HealthcarePractitionerFacility> getHealthcarePractitionerFacilities(Integer count, Map<String, Object> facilityFieldMap) {
        List<HealthcarePractitionerFacility> facilities = new List<HealthcarePractitionerFacility>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> fieldsForFacility = new Map<String, Object>();
            if (facilityFieldMap != null) {
                fieldsForFacility.putAll(facilityFieldMap);
            }
            // Make each facility unique
            fieldsForFacility.put('Name', 'Test Healthcare Facility ' + i);
            facilities.add(getHealthcarePractitionerFacility(fieldsForFacility));
        }
        return facilities;
    }

    /**
     * @description Creates a Training record with provided values
     * @return Training record with provided data
     */
    public class CreateTrainingRecord {
        private Training__c trainingRecord = new Training__c();

        /**
            * @description Set the Account field on the Training record
            * @param val Account Id
            * @return this
        */
        public CreateTrainingRecord setAccount(Id val) {
            trainingRecord.Account__c = val;
            return this;
        }

        /**
            * @description Set the Record Type field on the Training record
            * @param val Record Type Id
            * @return this
        */
        public CreateTrainingRecord setRecordType(Id val) {
            trainingRecord.RecordTypeId = val;
            return this;
        }

        /**
            * @description Set the Educator Type field on the Training record
            * @param val Educator Type
            * @return this
        */
        public CreateTrainingRecord setEducatorType(String val) {
            trainingRecord.Educator_Type__c = val;
            return this;
        }

        /**
            * @description Set the Training Stage field on the Training record
            * @param val Training Stage
            * @return this
        */
        public CreateTrainingRecord setTrainingStage(String val) {
            trainingRecord.Training_Stage__c = val;
            return this;
        }

        /**
            * @description Save the training record
            * @return this
        */
        public CreateTrainingRecord save() {
            insert trainingRecord;
            return this;
        }

        /**
            * @description Get the training record
            * @return Training record
        */
        public Training__c getRecord() {
            return trainingRecord;
        }
    }

    /**
     * @description Creates a Territory Model record with provided values
     * @return Territory Model record with provided data
     */
    public class CreateTerritory2ModelRecord {
        private Territory2Model territory2ModelRecord = new Territory2Model();

        /**
            * @description Set the Name field on the Territory Model record
            * @param val Name
            * @return this
        */
        public CreateTerritory2ModelRecord setName(String val) {
            territory2ModelRecord.Name = val;
            return this;
        }

        /**
            * @description Set the Developer Name field on the Territory Model record
            * @param val Developer Name
            * @return this
        */
        public CreateTerritory2ModelRecord setDeveloperName(String val) {
            territory2ModelRecord.DeveloperName = val;
            return this;
        }

        /**
            * @description Save the Territory Model record
            * @return this
        */
        public CreateTerritory2ModelRecord save() {
            insert territory2ModelRecord;
            return this;
        }

        /**
            * @description Get the Territory Model record
            * @return Territory Model record
        */
        public Territory2Model getRecord() {
            return territory2ModelRecord;
        }
    }

    /**
     * @description Creates a Territory record with provided values
     * @return Territory record with provided data
     */
    public class CreateTerritory2Record {
        private Territory2 territory2Record = new Territory2();

        /**
            * @description Set the Name field on the Territory record
            * @param val Name
            * @return this
        */
        public CreateTerritory2Record setName(String val) {
            territory2Record.Name = val;
            return this;
        }

        /**
            * @description Set the Territory2ModelId field on the Territory record
            * @param val Territory2ModelId
            * @return this
        */
        public CreateTerritory2Record setTerritory2ModelId(Id val) {
            territory2Record.Territory2ModelId = val;
            return this;
        }

        /**
            * @description Set the Territory2TypeId field on the Territory record
            * @param val Territory2TypeId
            * @return this
        */
        public CreateTerritory2Record setTerritory2TypeId(Id val) {
            territory2Record.Territory2TypeId = val;
            return this;
        }

        /**
            * @description Set the ParentTerritory2TypeId field on the Territory record
            * @param val ParentTerritory2Id
            * @return this
        */
        public CreateTerritory2Record setParentTerritory2Id(Id val) {
            territory2Record.ParentTerritory2Id = val;
            return this;
        }

        /**
            * @description Set the Description field on the Territory record
            * @param val Description
            * @return this
        */
        public CreateTerritory2Record setDescription(String val) {
            territory2Record.Description = val;
            return this;
        }

        /**
            * @description Set the DeveloperName field on the Territory record
            * @param val DeveloperName
            * @return this
        */
        public CreateTerritory2Record setDeveloperName(String val) {
            territory2Record.DeveloperName = val;
            return this;
        }

        /**
            * @description Save the Territory record
            * @return this
        */
        public CreateTerritory2Record save() {
            insert territory2Record;
            return this;
        }

        /**
            * @description Get the Territory record
            * @return Territory record
        */
        public Territory2 getRecord() {
            return territory2Record;
        }
    }

    /**
     * @description Creates a User record with provided values
     * @return User record with provided data
     */
    public class CreateUserRecord {
        private User userRecord = new User(
            Alias = 'tuser',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles'
        );

        /**
            * @description Set the Email field on the User record
            * @param val Email
            * @return this
        */
        public CreateUserRecord setEmail(String val) {
            userRecord.Email = val;
            return this;
        }

        /**
            * @description Set the FirstName field on the User record
            * @param val FirstName
            * @return this
        */
        public CreateUserRecord setFirstName(String val) {
            userRecord.FirstName = val;
            return this;
        }

        /**
            * @description Set the LastName field on the User record
            * @param val LastName
            * @return this
        */
        public CreateUserRecord setLastName(String val) {
            userRecord.LastName = val;
            return this;
        }

        /**
            * @description Set the ProfileId field on the User record
            * @param val ProfileId
            * @return this
        */
        public CreateUserRecord setProfileId(Id val) {
            userRecord.ProfileId = val;
            return this;
        }
         /**
            * @description Set the User role field on the User record
            * @param val RoleId
            * @return this
        */
        public CreateUserRecord setUserRoleId(Id val) {
            userRecord.UserRoleId = val;
            return this;
        }

        /**
            * @description Set the UserName field on the User record
            * @param val UserName
            * @return this
        */
        public CreateUserRecord setUserName(String val) {
            userRecord.UserName = val;
            return this;
        }

        /**
            * @description Save the User record
            * @return this
        */
        public CreateUserRecord save() {
            insert userRecord;
            return this;
        }

        /**
            * @description Get the User record
            * @return User record
        */
        public User getRecord() {
            return userRecord;
        }
    }
    /**
     * @description Creates multiple TerritoryAlias__c records
     * @param count Number of territories to create
     * @param territoryFieldMap Base field values to apply to all territories
     * @return List of TerritoryAlias__c records
     */
    public static List<TerritoryAlias__c> getTerritoryAliases(Integer count, Map<String, Object> territoryFieldMap) {
        List<TerritoryAlias__c> territories = new List<TerritoryAlias__c>();
        for (Integer i = 0; i < count; i++) {
            TerritoryAlias__c testTerritory = new TerritoryAlias__c(
                Name = 'Test Territory ' + counter++
            );

            // Apply any additional field values
            if (territoryFieldMap != null && !territoryFieldMap.isEmpty()) {
                for (String fieldName : territoryFieldMap.keySet()) {
                    testTerritory.put(fieldName, territoryFieldMap.get(fieldName));
                }
            }
            territories.add(testTerritory);
        }
        return territories;
    }

    /**
     * @description Creates multiple ZipCode__c records
     * @param count Number of zip codes to create
     * @param zipCodeFieldMap Base field values to apply to all zip codes
     * @return List of ZipCode__c records
     */
    public static List<ZipCode__c> getZipCodes(Integer count, Map<String, Object> zipCodeFieldMap) {
        List<ZipCode__c> zipCodes = new List<ZipCode__c>();
        for (Integer i = 0; i < count; i++) {
            ZipCode__c testZipCode = new ZipCode__c(
                Name = String.valueOf(10000 + counter++)
            );

            // Apply any additional field values
            if (zipCodeFieldMap != null && !zipCodeFieldMap.isEmpty()) {
                for (String fieldName : zipCodeFieldMap.keySet()) {
                    testZipCode.put(fieldName, zipCodeFieldMap.get(fieldName));
                }
            }

            zipCodes.add(testZipCode);
        }
        return zipCodes;
    }

    /**
     * @description Creates a PartyRoleRelation record for testing
     * @param partyRoleFieldMap Additional field values to set on the PartyRoleRelation
     * @return PartyRoleRelation record with test data
     */
    public static PartyRoleRelation getPartyRoleRelation(Map<String, Object> partyRoleFieldMap) {
        PartyRoleRelation testPartyRole = new PartyRoleRelation(
            RoleName = 'Patient',
            RelatedRoleName = 'Provider',
            RelationshipObjectName = 'Contact_Contact_Relationship'
        );

        // Apply any additional field values
        if (partyRoleFieldMap != null && !partyRoleFieldMap.isEmpty()) {
            for (String fieldName : partyRoleFieldMap.keySet()) {
                testPartyRole.put(fieldName, partyRoleFieldMap.get(fieldName));
            }
        }

        return testPartyRole;
    }

    /**
     * @description Creates a PartyRoleRelation record with default values
     * @return PartyRoleRelation record with test data
     */
    public static PartyRoleRelation getPartyRoleRelation() {
        return getPartyRoleRelation(null);
    }

      /**
     * @description Creates an Observation__c record for testing
     * Note: Trainer_Name__c is a required Master-Detail field and must be provided
     * @param observationFieldMap Field values to set on the Observation
     * @return Observation__c record with test data
     */
    public static Observation__c getObservation(Map<String, Object> observationFieldMap) {
        // Name is auto-number field, don't set it
        Observation__c testObservation = new Observation__c();
        
        // Apply field values
        if (observationFieldMap != null && !observationFieldMap.isEmpty()) {
            for (String fieldName : observationFieldMap.keySet()) {
                testObservation.put(fieldName, observationFieldMap.get(fieldName));
            }
        }
        
        return testObservation;
    }
    
    /**
     * @description Creates multiple Observation__c records for bulk testing
     * @param count Number of observations to create
     * @param observationFieldMap Base field values to apply to all observations
     * @return List of Observation__c records
     */
    public static List<Observation__c> getObservations(Integer count, Map<String, Object> observationFieldMap) {
        List<Observation__c> observations = new List<Observation__c>();
        for (Integer idx = 0; idx < count; idx++) {
            Map<String, Object> fieldsForObservation = new Map<String, Object>();
            if (observationFieldMap != null) {
                fieldsForObservation.putAll(observationFieldMap);
            }
            observations.add(getObservation(fieldsForObservation));
        }
        return observations;
    }

    /**
     * @description Creates a Conga Template record with provided values
     * @return Conga Template record with provided data
     */
    public class CreateTemplateRecord {
        private APXTConga4__Conga_Template__c templateRecord = new APXTConga4__Conga_Template__c();

        /**
            * @description Set the Name field on the Conga Template record
            * @param val Name
            * @return this
        */
        public CreateTemplateRecord setName(String val) {
            templateRecord.APXTConga4__Name__c = val;
            return this;
        }

        /**
            * @description Set the Template Type field on the Conga Template record
            * @param val Template Type
            * @return this
        */
        public CreateTemplateRecord setTemplateType(String val) {
            templateRecord.APXTConga4__Template_Type__c = val;
            return this;
        }

        /**
            * @description Save the Conga Template record
            * @return this
        */
        public CreateTemplateRecord save() {
            insert templateRecord;
            return this;
        }

        /**
            * @description Get the Conga Template record
            * @return Conga Template record
        */
        public APXTConga4__Conga_Template__c getRecord() {
            return templateRecord;
        }
    }

    /**
    * @description Helper method to get Training record type Id using schema
    * @param developerName The record type developer name
    * @return Id of the record type
    */
    public static Id getTrainingRtId(String developerName) {
        return Schema.SObjectType.Training__c.getRecordTypeInfosByDeveloperName().get(developerName).getRecordTypeId();
    }
      

    /**
     * @description Creates a Contract record for testing
     * @param accId Account Id
     * @return Contract record with test data
     */
    public static Contract getContract(Id accId) {
        Contract c = new Contract(
            AccountId = accId,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12
        );
        return c;
    }
	/**
     * @description Creates an AssessmentQuestionSet record for testing
     * @param questionSetFieldMap Additional field values to set on the AssessmentQuestionSet
     * @return AssessmentQuestionSet record with test data
     */
    public static AssessmentQuestionSet getAssessmentQuestionSet(Map<String, Object> questionSetFieldMap) {
        Integer currentCounter = counter++;
        AssessmentQuestionSet testQuestionSet = new AssessmentQuestionSet(
            Name = 'Test Question Set ' + currentCounter,
            DeveloperName = 'Test_Question_Set_Dev_' + currentCounter
        );

        // Apply any additional field values
        if (questionSetFieldMap != null && !questionSetFieldMap.isEmpty()) {
            for (String fieldName : questionSetFieldMap.keySet()) {
                testQuestionSet.put(fieldName, questionSetFieldMap.get(fieldName));
            }
        }

        return testQuestionSet;
    }

    /**
     * @description Creates an AssessmentQuestionSet record with default values
     * @return AssessmentQuestionSet record with test data
     */
    public static AssessmentQuestionSet getAssessmentQuestionSet() {
        return getAssessmentQuestionSet(null);
    }

    /**
     * @description Creates multiple AssessmentQuestionSet records for bulk testing
     * @param count Number of AssessmentQuestionSet records to create
     * @param questionSetFieldMap Base field values to apply to all AssessmentQuestionSet records
     * @return List of AssessmentQuestionSet records
     */
    public static List<AssessmentQuestionSet> getAssessmentQuestionSets(Integer count, Map<String, Object> questionSetFieldMap) {
        List<AssessmentQuestionSet> questionSets = new List<AssessmentQuestionSet>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> fieldsForQuestionSet = new Map<String, Object>();
            if (questionSetFieldMap != null) {
                fieldsForQuestionSet.putAll(questionSetFieldMap);
            }
            // Make each question set unique
            fieldsForQuestionSet.put('Name', 'Test Question Set ' + i);
            fieldsForQuestionSet.put('DeveloperName', 'Test_Question_Set_Dev_' + i);
            questionSets.add(getAssessmentQuestionSet(fieldsForQuestionSet));
        }
        return questionSets;
    }

    /**
     * @description Creates an OmniProcess record for testing (Required for AssessmentDefinition)
     * @param omniProcessFieldMap Additional field values to set on the OmniProcess
     * @return OmniProcess record with test data
     */
    public static OmniProcess getOmniProcess(Map<String, Object> omniProcessFieldMap) {
        OmniProcess testOmni = new OmniProcess(
            Name = 'Test OmniScript ' + counter++,
            Language = 'English',
            IsActive = true,
            OmniProcessType = 'OmniScript'
        );

        // Apply any additional field values
        if (omniProcessFieldMap != null && !omniProcessFieldMap.isEmpty()) {
            for (String fieldName : omniProcessFieldMap.keySet()) {
                testOmni.put(fieldName, omniProcessFieldMap.get(fieldName));
            }
        }

        return testOmni;
    }

    /**
     * @description Creates an OmniProcess record with default values
     * @return OmniProcess record with test data
     */
    public static OmniProcess getOmniProcess() {
        return getOmniProcess(null);
    }

    /**
     * @description Creates multiple OmniProcess records for bulk testing (Required for AssessmentDefinition)
     * @param count Number of OmniProcess records to create
     * @param omniProcessFieldMap Base field values to apply to all OmniProcess records
     * @return List of OmniProcess records
     */
    public static List<OmniProcess> getOmniProcesses(Integer count, Map<String, Object> omniProcessFieldMap) {
        List<OmniProcess> omniProcesses = new List<OmniProcess>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> fieldsForOmni = new Map<String, Object>();
            if (omniProcessFieldMap != null) {
                fieldsForOmni.putAll(omniProcessFieldMap);
            }
            // Make each OmniProcess unique
            fieldsForOmni.put('Name', 'Test OmniScript ' + i);
            omniProcesses.add(getOmniProcess(fieldsForOmni));
        }
        return omniProcesses;
    }

    /**
     * @description Creates an AssessmentDefinition record for testing
     * NOTE: Ensures that every AssessmentDefinition includes OmniProcessId and Assessment_Question_Set__c
     * @param assessmentDefFieldMap Additional field values to set on the AssessmentDefinition
     * @return AssessmentDefinition record with test data
     */
    public static AssessmentDefinition getAssessmentDefinition(Map<String, Object> assessmentDefFieldMap) {
        AssessmentDefinition testAssessmentDef = new AssessmentDefinition(
            Test_Name__c = 'Test Exam ' + counter++
        );

        // Apply any additional field values
        if (assessmentDefFieldMap != null && !assessmentDefFieldMap.isEmpty()) {
            for (String fieldName : assessmentDefFieldMap.keySet()) {
                testAssessmentDef.put(fieldName, assessmentDefFieldMap.get(fieldName));
            }
        }

        return testAssessmentDef;
    }

    /**
     * @description Creates multiple AssessmentDefinition records for bulk testing
     * NOTE: Ensures that every AssessmentDefinition includes OmniProcessId and Assessment_Question_Set__c
     * @param count Number of AssessmentDefinition records to create
     * @param assessmentDefFieldMap Base field values to apply to all AssessmentDefinition records
     * @return List of AssessmentDefinition records
     */
    public static List<AssessmentDefinition> getAssessmentDefinitions(Integer count, Map<String, Object> assessmentDefFieldMap) {
        List<AssessmentDefinition> assessmentDefs = new List<AssessmentDefinition>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> fieldsForAssessmentDef = new Map<String, Object>();
            if (assessmentDefFieldMap != null) {
                fieldsForAssessmentDef.putAll(assessmentDefFieldMap);
            }
            // Make each assessment definition unique
            fieldsForAssessmentDef.put('Test_Name__c', 'Test Exam ' + i);
            assessmentDefs.add(getAssessmentDefinition(fieldsForAssessmentDef));
        }
        return assessmentDefs;
    }

    /**
     * @description Creates a Certification record for testing
     * Note: Ensures that every AssessmentDefinition includes Trainer_Name__c and Certification_Assessment__c
     * @param certificationFieldMap Additional field values to set on the Certification
     * @return Certification__c record with test data
     */
    public static Certification__c getCertification(Map<String, Object> certificationFieldMap) {
        Certification__c testCert = new Certification__c();

        // Apply field values
        if (certificationFieldMap != null && !certificationFieldMap.isEmpty()) {
            for (String fieldName : certificationFieldMap.keySet()) {
                testCert.put(fieldName, certificationFieldMap.get(fieldName));
            }
        }

        return testCert;
    }

    /**
     * @description Creates a Certification record for testing
     * @param accId Account Id
     * @return Certification__c record with test data
     */
    public static Certification__c getCertification(Id accId) {
        AssessmentDefinition ad = [Select id from AssessmentDefinition limit 1];
        Certification__c c = new Certification__c(
            Trainer_Name__c = accId,
    		Certification_Assessment__c = ad.Id
        );
        return c;
    }
    
    /**
     * @description Creates multiple Certification records for bulk testing
     * Note: Trainer_Name__c and Certification_Assessment__c are required
     * @param count Number of Certification records to create
     * @param certificationFieldMap Base field values to apply to all Certification records
     * @return List of Certification__c records
     */
    public static List<Certification__c> getCertifications(Integer count, Map<String, Object> certificationFieldMap) {
        List<Certification__c> certifications = new List<Certification__c>();
        for (Integer i = 0; i < count; i++) {
            Map<String, Object> fieldsForCert = new Map<String, Object>();
            if (certificationFieldMap != null) {
                fieldsForCert.putAll(certificationFieldMap);
            }
            certifications.add(getCertification(fieldsForCert));
        }
        return certifications;
    }
	/**
     * @description Creates Account Contact RelationShip
     * @param accountId String
     * @param contactId String
     * @param type role
     * @return AccountContactRelation record
     */ 
    public static AccountContactRelation getAccountContactRelation(String accountId,String contactId,String role){
        AccountContactRelation acr = new AccountContactRelation();
        acr.ContactId = contactId;
        acr.AccountId = accountId;
        acr.Roles = ConstantsUtil.ACR_ROLE_TRAINER;
        acr.IsActive = true;
        return acr;
    }

    /**
     * @description Assigns a Permission Set to a User by Permission Set Name
     * @param userId The User Id to assign the permission set to
     * @param permissionSetName The Name of the Permission Set to assign
     * @return PermissionSetAssignment The created PermissionSetAssignment record
     */
    public static PermissionSetAssignment assignPermissionSet(Id userId, String permissionSetName) {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1];
        PermissionSetAssignment psAssignment = new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = ps.Id
        );
        insert psAssignment;
        return psAssignment;
    }

    /**
     * @description Assigns a Permission Set License to a User by MasterLabel
     * @param userId The User Id to assign the permission set license to
     * @param masterLabel The MasterLabel of the PermissionSetLicense to assign
     * @return PermissionSetLicenseAssign The created PermissionSetLicenseAssign record
     */
    public static PermissionSetLicenseAssign assignPermissionSetLicense(Id userId, String masterLabel) {
        PermissionSetLicense psl = [SELECT Id FROM PermissionSetLicense WHERE MasterLabel = :masterLabel LIMIT 1];
        PermissionSetLicenseAssign pslAssign = new PermissionSetLicenseAssign(
            PermissionSetLicenseId = psl.Id,
            AssigneeId = userId
        );
        insert pslAssign;
        return pslAssign;
    }

    /**
     * @description Creates a EnvelopeConfiguration record for testing
     * @return dfsle__EnvelopeConfiguration__c record with test data
     */
    public static dfsle__EnvelopeConfiguration__c getEnvelopeConfiguration() {
       dfsle__EnvelopeConfiguration__c cfg = new dfsle__EnvelopeConfiguration__c(
            Name = 'Virtual Consent Form - E-sign - English'
        );
        return cfg;
    }
    
    /**
     * @description Creates a Envelope record for testing
     * @param accId 
     * @param cfgId 
     * @return dfsle__Envelope__c record with test data
     */
    public static dfsle__Envelope__c getEnvelope(Id accId, Id cfgId) {
       dfsle__Envelope__c env = new dfsle__Envelope__c(
            dfsle__SourceId__c = String.valueOf(accId),
            dfsle__DocuSignId__c = 'DOC-123',
            dfsle__EnvelopeConfiguration__c = cfgId
        );
        return env;
    }
    
    /**
     * @description Creates a EnvelopeStatus record for testing
     * @return dfsle__EnvelopeStatus__c record with test data
     */
    public static dfsle__EnvelopeStatus__c getEnvelopeStatus() {
       dfsle__EnvelopeStatus__c st1 = new dfsle__EnvelopeStatus__c(
            dfsle__DocuSignId__c = 'DOC-123',
            dfsle__Status__c = 'Sent',
            dfsle__Sent__c = System.now(),
            dfsle__LastStatusUpdate__c = System.now()
        );
        return st1;
    }
    /**
     * @description Custom exception for TestDataFactory errors
     */
    public class TestDataFactoryException extends Exception {}
}