/**
 * @description Test data factory class for OrgSync test classes
 *              Provides reusable methods to create test data for Practice, Patient, Provider accounts,
 *              Patient Stage, Physician Stage records, and related test data
 * Created Date : Feb 10, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Feb 10, 2026        Pradip Kokate           Initial Version
 */

@isTest
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessivePublicCount,PMD.StdCyclomaticComplexity,PMD.ExcessiveParameterList')
public class OrgSync_TestDataFactory {

    /**
     * @description Gets DML options configured for test data (bypasses duplicate rules)
     * @return Database.DMLOptions configured for test data
     */
    public static Database.DMLOptions getDMLOptions() {
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.DuplicateRuleHeader.runAsCurrentUser = true;
        return dmlOptions;
    }

    /**
     * @description Creates a single Practice Account
     * @param name Account Name
     * @param externalId XCDC_ExternalId__c value
     * @param postalCode BillingPostalCode value
     * @param additionalFields Map of additional field values to set
     * @return Practice Account record (not inserted)
     */
    public static Account createPracticeAccount(String name, String externalId, String postalCode, Map<String, Object> additionalFields) {
        Account practiceAccount = TestDataFactory.getAccountofPracticeRecordType();
        practiceAccount.Name = name;
        practiceAccount.XCDC_ExternalId__c = externalId;
        practiceAccount.BillingPostalCode = postalCode;
        if (additionalFields != null && !additionalFields.isEmpty()) {
            for (String fieldName : additionalFields.keySet()) {
                practiceAccount.put(fieldName, additionalFields.get(fieldName));
            }
        }
        return practiceAccount;
    }

    /**
     * @description Creates a single Practice Account with postal code
     * @param name Account Name
     * @param externalId XCDC_ExternalId__c value
     * @param postalCode BillingPostalCode value
     * @return Practice Account record (not inserted)
     */
    public static Account createPracticeAccount(String name, String externalId, String postalCode) {
        return createPracticeAccount(name, externalId, postalCode, null);
    }

    /**
     * @description Creates a single Practice Account with default values
     * @param name Account Name
     * @param externalId XCDC_ExternalId__c value
     * @return Practice Account record (not inserted)
     */
    public static Account createPracticeAccount(String name, String externalId) {
        return createPracticeAccount(name, externalId, '12345', null);
    }

    /**
     * @description Creates multiple Practice Accounts for bulk testing
     * @param count Number of Practice Accounts to create
     * @param baseName Base name for accounts (will be appended with index)
     * @param baseExternalId Base external ID (will be appended with index)
     * @param basePostalCode Base postal code (will be incremented)
     * @return List of Practice Account records (not inserted)
     */
    public static List<Account> createPracticeAccounts(Integer count, String baseName, String baseExternalId, String basePostalCode) {
        List<Account> practiceAccounts = new List<Account>();
        Integer postalCodeInt = String.isNotBlank(basePostalCode) ? Integer.valueOf(basePostalCode) : 12345;
        for (Integer i = 0; i < count; i++) {
            String name = baseName + ' ' + (i + 1);
            String externalId = baseExternalId + '-' + String.valueOf(i + 1).leftPad(3, '0');
            String postalCode = String.valueOf(postalCodeInt + i);
            practiceAccounts.add(createPracticeAccount(name, externalId, postalCode, null));
        }
        return practiceAccounts;
    }

    /**
     * @description Creates and inserts multiple Practice Accounts for bulk testing
     * @param count Number of Practice Accounts to create
     * @param baseName Base name for accounts
     * @param baseExternalId Base external ID
     * @return List of inserted Practice Account IDs
     */
    public static List<Id> createAndInsertPracticeAccounts(Integer count, String baseName, String baseExternalId) {
        List<Account> accounts = createPracticeAccounts(count, baseName, baseExternalId, '12345');
        Database.SaveResult[] results = Database.insert(accounts, getDMLOptions());
        List<Id> accountIds = new List<Id>();
        for (Integer i = 0; i < accounts.size(); i++) {
            if (results[i].isSuccess()) {
                accountIds.add(accounts[i].Id);
            }
        }
        return accountIds;
    }

    /**
     * @description Creates a single Provider Account
     * @param firstName First Name
     * @param lastName Last Name
     * @param email PersonEmail
     * @param postalCode BillingPostalCode
     * @param additionalFields Map of additional field values to set
     * @return Provider Account record (not inserted)
     */
    public static Account createProviderAccount(String firstName, String lastName, String email, String postalCode, Map<String, Object> additionalFields) {
        Account providerAccount = TestDataFactory.getAccountofProviderRecordType();
        providerAccount.FirstName = firstName;
        providerAccount.LastName = lastName;
        providerAccount.PersonEmail = email;
        providerAccount.BillingPostalCode = postalCode;
        if (additionalFields != null && !additionalFields.isEmpty()) {
            for (String fieldName : additionalFields.keySet()) {
                providerAccount.put(fieldName, additionalFields.get(fieldName));
            }
        }
        return providerAccount;
    }

    /**
     * @description Creates a single Provider Account with default values
     * @param firstName First Name
     * @param lastName Last Name
     * @param email PersonEmail
     * @return Provider Account record (not inserted)
     */
    public static Account createProviderAccount(String firstName, String lastName, String email) {
        return createProviderAccount(firstName, lastName, email, '12345', null);
    }

    /**
     * @description Creates multiple Provider Accounts for bulk testing
     * @param count Number of Provider Accounts to create
     * @param baseFirstName Base first name (will be appended with index)
     * @param baseLastName Base last name (will be appended with index)
     * @param baseEmail Base email (will be appended with index)
     * @param basePostalCode Base postal code (will be incremented)
     * @return List of Provider Account records (not inserted)
     */
    public static List<Account> createProviderAccounts(Integer count, String baseFirstName, String baseLastName, String baseEmail, String basePostalCode) {
        List<Account> providerAccounts = new List<Account>();
        Integer postalCodeInt = String.isNotBlank(basePostalCode) ? Integer.valueOf(basePostalCode) : 12345;
        for (Integer i = 0; i < count; i++) {
            String firstName = baseFirstName + (i + 1);
            String lastName = baseLastName + (i + 1);
            String email = baseEmail.replace('@', (i + 1) + '@');
            String postalCode = String.valueOf(postalCodeInt + i);
            providerAccounts.add(createProviderAccount(firstName, lastName, email, postalCode, null));
        }
        return providerAccounts;
    }

    /**
     * @description Creates and inserts multiple Provider Accounts for bulk testing
     * @param count Number of Provider Accounts to create
     * @param baseFirstName Base first name
     * @param baseLastName Base last name
     * @param baseEmail Base email
     * @return List of successfully inserted Provider Account IDs
     */
    public static List<Id> createAndInsertProviderAccounts(Integer count, String baseFirstName, String baseLastName, String baseEmail) {
        List<Account> accounts = createProviderAccounts(count, baseFirstName, baseLastName, baseEmail, '12345');
        Database.SaveResult[] results = Database.insert(accounts, getDMLOptions());
        List<Id> accountIds = new List<Id>();
        for (Integer i = 0; i < accounts.size(); i++) {
            if (results[i].isSuccess()) {
                accountIds.add(accounts[i].Id);
            }
        }
        return accountIds;
    }

    /**
     * @description Creates a single Patient Delegate Account
     * @param firstName First Name
     * @param lastName Last Name
     * @param email PersonEmail (optional)
     * @param additionalFields Map of additional field values to set (PersonHomePhone, Phone, PersonMobilePhone, etc.)
     * @return Patient Delegate Account record (not inserted)
     */
    public static Account createDelegateAccount(String firstName, String lastName, String email, Map<String, Object> additionalFields) {
        Account delegateAccount = new Account(
            RecordTypeId = ConstantsUtil.ACCOUNT_PATIENT_DELICATE_RT,
            FirstName = firstName,
            LastName = lastName,
            PersonEmail = email
        );
        if (additionalFields != null && !additionalFields.isEmpty()) {
            for (String fieldName : additionalFields.keySet()) {
                delegateAccount.put(fieldName, additionalFields.get(fieldName));
            }
        }
        return delegateAccount;
    }

    /**
     * @description Creates a single Patient Delegate Account with default values
     * @param firstName First Name
     * @param lastName Last Name
     * @param email PersonEmail
     * @return Patient Delegate Account record (not inserted)
     */
    public static Account createDelegateAccount(String firstName, String lastName, String email) {
        return createDelegateAccount(firstName, lastName, email, null);
    }

    /**
     * @description Creates a single Patient Account
     * @param firstName First Name
     * @param lastName Last Name
     * @param email PersonEmail
     * @param externalId XCDC_ExternalId__c value
     * @param postalCode BillingPostalCode
     * @param additionalFields Map of additional field values to set
     * @return Patient Account record (not inserted)
     */
    public static Account createPatientAccount(String firstName, String lastName, String email, String externalId, String postalCode, Map<String, Object> additionalFields) {
        Account patientAccount = TestDataFactory.getAccountofPatientRecordType();
        patientAccount.FirstName = firstName;
        patientAccount.LastName = lastName;
        patientAccount.PersonEmail = email;
        patientAccount.XCDC_ExternalId__c = externalId;
        patientAccount.BillingPostalCode = postalCode;

        if (additionalFields != null && !additionalFields.isEmpty()) {
            for (String fieldName : additionalFields.keySet()) {
                patientAccount.put(fieldName, additionalFields.get(fieldName));
            }
        }
        return patientAccount;
    }

    /**
     * @description Creates a single Patient Account with default values
     * @param firstName First Name
     * @param lastName Last Name
     * @param email PersonEmail
     * @param externalId XCDC_ExternalId__c value
     * @return Patient Account record (not inserted)
     */
    public static Account createPatientAccount(String firstName, String lastName, String email, String externalId) {
        return createPatientAccount(firstName, lastName, email, externalId, '12345', null);
    }

    /**
     * @description Creates multiple Patient Accounts for bulk testing
     * @param count Number of Patient Accounts to create
     * @param baseFirstName Base first name (will be appended with index)
     * @param baseLastName Base last name (will be appended with index)
     * @param baseEmail Base email (will be appended with index)
     * @param baseExternalId Base external ID (will be appended with index)
     * @param basePostalCode Base postal code (will be incremented)
     * @return List of Patient Account records (not inserted)
     */
    public static List<Account> createPatientAccounts(Integer count, String baseFirstName, String baseLastName, String baseEmail, String baseExternalId, String basePostalCode) {
        List<Account> patientAccounts = new List<Account>();
        Integer postalCodeInt = String.isNotBlank(basePostalCode) ? Integer.valueOf(basePostalCode) : 12345;

        for (Integer i = 0; i < count; i++) {
            String firstName = baseFirstName + (i + 1);
            String lastName = baseLastName + (i + 1);
            String email = baseEmail.replace('@', (i + 1) + '@');
            String externalId = baseExternalId + '-' + String.valueOf(i + 1).leftPad(3, '0');
            String postalCode = String.valueOf(postalCodeInt + i);
            patientAccounts.add(createPatientAccount(firstName, lastName, email, externalId, postalCode, null));
        }

        return patientAccounts;
    }

    /**
     * @description Creates and inserts multiple Patient Accounts for bulk testing
     * @param count Number of Patient Accounts to create
     * @param baseFirstName Base first name
     * @param baseLastName Base last name
     * @param baseEmail Base email
     * @param baseExternalId Base external ID
     * @return List of successfully inserted Patient Account IDs
     */
    public static List<Id> createAndInsertPatientAccounts(Integer count, String baseFirstName, String baseLastName, String baseEmail, String baseExternalId) {
        List<Account> accounts = createPatientAccounts(count, baseFirstName, baseLastName, baseEmail, baseExternalId, '12345');
        Database.SaveResult[] results = Database.insert(accounts, getDMLOptions());
        List<Id> accountIds = new List<Id>();
        for (Integer i = 0; i < accounts.size(); i++) {
            if (results[i].isSuccess()) {
                accountIds.add(accounts[i].Id);
            }
        }
        return accountIds;
    }

    /**
     * @description Queries Provider Accounts to get PersonContactId
     * @param providerAccountIds List of Provider Account IDs
     * @return Map of Account ID to Account with PersonContactId populated
     */
    public static Map<Id, Account> queryProviderAccounts(List<Id> providerAccountIds) {
        return new Map<Id, Account>([
            SELECT Id, PersonContactId, FirstName, LastName, PersonEmail
            FROM Account
            WHERE Id IN :providerAccountIds
            AND PersonContactId != null
        ]);
    }

    /**
     * @description Queries Patient Accounts to get PersonContactId
     * @param patientAccountIds List of Patient Account IDs
     * @return Map of Account ID to Account with PersonContactId populated
     */
    public static Map<Id, Account> queryPatientAccounts(List<Id> patientAccountIds) {
        return new Map<Id, Account>([
            SELECT Id, PersonContactId, FirstName, LastName, PersonEmail, XCDC_ExternalId__c
            FROM Account
            WHERE Id IN :patientAccountIds
            AND PersonContactId != null
        ]);
    }

    /**
     * @description Creates Identifier records (NPI) for Provider Accounts
     * @param providerAccountIds List of Provider Account IDs
     * @param npiValues List of NPI values (must match count of providerAccountIds)
     * @return List of Identifier records (not inserted)
     */
    public static List<Identifier> createIdentifierRecords(List<Id> providerAccountIds, List<String> npiValues) {
        List<Identifier> identifiers = new List<Identifier>();
        for (Integer i = 0; i < providerAccountIds.size() && i < npiValues.size(); i++) {
            identifiers.add(new Identifier(
                ParentRecordId = providerAccountIds[i],
                ID_Value__c = npiValues[i],
                IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
            ));
        }
        return identifiers;
    }

    /**
     * @description Creates and inserts Identifier records (NPI) for Provider Accounts
     * @param providerAccountIds List of Provider Account IDs
     * @param npiValues List of NPI values (must match count of providerAccountIds)
     * @return List of inserted Identifier records
     */
    public static List<Identifier> createAndInsertIdentifierRecords(List<Id> providerAccountIds, List<String> npiValues) {
        List<Identifier> identifiers = createIdentifierRecords(providerAccountIds, npiValues);

        if (!identifiers.isEmpty()) {
            insert identifiers;
        }
        return identifiers;
    }

    /**
     * @description Creates a single Physician Staging record
     * @param npi OrgSync_NPI__c value
     * @param practiceId OrgSync_Parent_Practice__c value
     * @param firstName OrgSync_FirstName__c value
     * @param lastName OrgSync_LastName__c value
     * @param additionalFields Map of additional field values to set
     * @return Physician Staging record (not inserted)
     */
    public static OrgSync_Physician_Staging__c createPhysicianStagingRecord(String npi, Id practiceId, String firstName, String lastName, Map<String, Object> additionalFields) {
        OrgSync_Physician_Staging__c physicianStage = new OrgSync_Physician_Staging__c(
            Name = firstName + ' ' + lastName,
            OrgSync_NPI__c = npi,
            OrgSync_Parent_Practice__c = practiceId,
            OrgSync_FirstName__c = firstName,
            OrgSync_LastName__c = lastName,
            OrgSync_Do_Not_Use__c = false
        );
        if (additionalFields != null && !additionalFields.isEmpty()) {
            for (String fieldName : additionalFields.keySet()) {
                physicianStage.put(fieldName, additionalFields.get(fieldName));
            }
        }
        return physicianStage;
    }

    /**
     * @description Creates a single Physician Staging record with minimal fields
     * @param npi OrgSync_NPI__c value
     * @param practiceId OrgSync_Parent_Practice__c value
     * @return Physician Staging record (not inserted)
     */
    public static OrgSync_Physician_Staging__c createPhysicianStagingRecord(String npi, Id practiceId) {
        return createPhysicianStagingRecord(npi, practiceId, 'Test', 'Physician', null);
    }

    /**
     * @description Creates multiple Physician Staging records for bulk testing
     * @param npiValues List of NPI values
     * @param practiceIds List of Practice Account IDs (can be same or different)
     * @param firstNameValues List of First Name values (optional, defaults to 'Test')
     * @param lastNameValues List of Last Name values (optional, defaults to 'Physician')
     * @return List of Physician Staging records (not inserted)
     */
    public static List<OrgSync_Physician_Staging__c> createPhysicianStagingRecords(
        List<String> npiValues,
        List<Id> practiceIds,
        List<String> firstNameValues,
        List<String> lastNameValues
    ) {
        List<OrgSync_Physician_Staging__c> physicianStages = new List<OrgSync_Physician_Staging__c>();
        for (Integer i = 0; i < npiValues.size(); i++) {
            String npi = npiValues[i];
            Id practiceId = i < practiceIds.size() ? practiceIds[i] : practiceIds[0];
            String firstName = (firstNameValues != null && i < firstNameValues.size()) ? firstNameValues[i] : 'Test';
            String lastName = (lastNameValues != null && i < lastNameValues.size()) ? lastNameValues[i] : 'Physician' + (i + 1);
            physicianStages.add(createPhysicianStagingRecord(npi, practiceId, firstName, lastName, null));
        }
        return physicianStages;
    }

    /**
     * @description Creates and inserts multiple Physician Staging records for bulk testing
     * @param npiValues List of NPI values
     * @param practiceIds List of Practice Account IDs
     * @param firstNameValues List of First Name values (optional)
     * @param lastNameValues List of Last Name values (optional)
     * @return List of inserted Physician Staging records
     */
    public static List<OrgSync_Physician_Staging__c> createAndInsertPhysicianStagingRecords(
        List<String> npiValues,
        List<Id> practiceIds,
        List<String> firstNameValues,
        List<String> lastNameValues
    ) {
        List<OrgSync_Physician_Staging__c> physicianStages = createPhysicianStagingRecords(npiValues, practiceIds, firstNameValues, lastNameValues);
        if (!physicianStages.isEmpty()) {
            // Generate External IDs before insert if needed
            if (OrgSync_PublishSettingService.class != null) {
                OrgSync_PublishSettingService.generateExternalId(physicianStages);
            }
            insert physicianStages;
        }
        return physicianStages;
    }

    /**
     * @description Creates a single Patient Staging record
     * @param externalId XCDC_ExternalId__c value (must match Patient Account External ID)
     * @param practiceId OrgSync_Practice__c value
     * @param providerStageId OrgSync_Provider__c value (Physician Staging ID, optional)
     * @param firstName OrgSync_FirstName__c value
     * @param lastName OrgSync_LastName__c value
     * @param additionalFields Map of additional field values to set
     * @return Patient Staging record (not inserted)
     */
    public static OrgSync_Patient_Staging__c createPatientStagingRecord(
        String externalId,
        Id practiceId,
        Id providerStageId,
        String firstName,
        String lastName,
        Map<String, Object> additionalFields
    ) {
        OrgSync_Patient_Staging__c patientStage = new OrgSync_Patient_Staging__c(
            Name = firstName + ' ' + lastName,
            XCDC_ExternalId__c = externalId,
            OrgSync_Practice__c = practiceId,
            OrgSync_FirstName__c = firstName,
            OrgSync_LastName__c = lastName
        );
        if (providerStageId != null) {
            patientStage.OrgSync_Provider__c = providerStageId;
        }
        if (additionalFields != null && !additionalFields.isEmpty()) {
            for (String fieldName : additionalFields.keySet()) {
                patientStage.put(fieldName, additionalFields.get(fieldName));
            }
        }
        return patientStage;
    }

    /**
     * @description Creates a single Patient Staging record with minimal fields
     * @param externalId XCDC_ExternalId__c value
     * @param practiceId OrgSync_Practice__c value
     * @return Patient Staging record (not inserted)
     */
    public static OrgSync_Patient_Staging__c createPatientStagingRecord(String externalId, Id practiceId) {
        return createPatientStagingRecord(externalId, practiceId, null, 'Test', 'Patient', null);
    }

    /**
     * @description Creates multiple Patient Staging records for bulk testing
     * @param externalIds List of External ID values
     * @param practiceIds List of Practice Account IDs (can be same or different)
     * @param providerStageIds List of Provider Staging IDs (optional)
     * @param firstNameValues List of First Name values (optional)
     * @param lastNameValues List of Last Name values (optional)
     * @return List of Patient Staging records (not inserted)
     */
    public static List<OrgSync_Patient_Staging__c> createPatientStagingRecords(
        List<String> externalIds,
        List<Id> practiceIds,
        List<Id> providerStageIds,
        List<String> firstNameValues,
        List<String> lastNameValues
    ) {
        List<OrgSync_Patient_Staging__c> patientStages = new List<OrgSync_Patient_Staging__c>();
        for (Integer i = 0; i < externalIds.size(); i++) {
            String externalId = externalIds[i];
            Id practiceId = i < practiceIds.size() ? practiceIds[i] : practiceIds[0];
            Id providerStageId = (providerStageIds != null && i < providerStageIds.size()) ? providerStageIds[i] : null;
            String firstName = (firstNameValues != null && i < firstNameValues.size()) ? firstNameValues[i] : 'Test';
            String lastName = (lastNameValues != null && i < lastNameValues.size()) ? lastNameValues[i] : 'Patient' + (i + 1);
            patientStages.add(createPatientStagingRecord(externalId, practiceId, providerStageId, firstName, lastName, null));
        }
        return patientStages;
    }

    /**
     * @description Creates and inserts multiple Patient Staging records for bulk testing
     * @param externalIds List of External ID values
     * @param practiceIds List of Practice Account IDs
     * @param providerStageIds List of Provider Staging IDs (optional)
     * @param firstNameValues List of First Name values (optional)
     * @param lastNameValues List of Last Name values (optional)
     * @return List of inserted Patient Staging records
     */
    public static List<OrgSync_Patient_Staging__c> createAndInsertPatientStagingRecords(
        List<String> externalIds,
        List<Id> practiceIds,
        List<Id> providerStageIds,
        List<String> firstNameValues,
        List<String> lastNameValues
    ) {
        List<OrgSync_Patient_Staging__c> patientStages = createPatientStagingRecords(externalIds, practiceIds, providerStageIds, firstNameValues, lastNameValues);
        if (!patientStages.isEmpty()) {
            Database.DMLOptions dmlOptions = getDMLOptions();
            Database.insert(patientStages, dmlOptions);
        }
        return patientStages;
    }

    /**
     * @description Creates a single HPF (HealthcarePractitionerFacility) record
     * @param practiceId AccountId (Practice Account ID)
     * @param practitionerId PractitionerId (Provider Contact ID)
     * @param name Name field value
     * @param isActive IsActive field value
     * @param additionalFields Map of additional field values to set
     * @return HPF record (not inserted)
     */
    public static HealthcarePractitionerFacility createHPFRecord(Id practiceId, Id practitionerId, String name, Boolean isActive, Map<String, Object> additionalFields) {
        HealthcarePractitionerFacility hpf = new HealthcarePractitionerFacility(
            AccountId = practiceId,
            PractitionerId = practitionerId,
            Name = name,
            IsActive = isActive
        );
        if (additionalFields != null && !additionalFields.isEmpty()) {
            for (String fieldName : additionalFields.keySet()) {
                hpf.put(fieldName, additionalFields.get(fieldName));
            }
        }
        return hpf;
    }

    /**
     * @description Creates a single HPF record with default values
     * @param practiceId AccountId (Practice Account ID)
     * @param practitionerId PractitionerId (Provider Contact ID)
     * @param name Name field value
     * @return HPF record (not inserted)
     */
    public static HealthcarePractitionerFacility createHPFRecord(Id practiceId, Id practitionerId, String name) {
        return createHPFRecord(practiceId, practitionerId, name, true, null);
    }

    /**
     * @description Creates multiple HPF records for bulk testing
     * @param practiceIds List of Practice Account IDs
     * @param practitionerIds List of Provider Contact IDs
     * @param names List of Name values
     * @param isActiveValues List of IsActive values (optional, defaults to true)
     * @return List of HPF records (not inserted)
     */
    public static List<HealthcarePractitionerFacility> createHPFRecords(
        List<Id> practiceIds,
        List<Id> practitionerIds,
        List<String> names,
        List<Boolean> isActiveValues
    ) {
        List<HealthcarePractitionerFacility> hpfRecords = new List<HealthcarePractitionerFacility>();
        for (Integer i = 0; i < practiceIds.size() && i < practitionerIds.size() && i < names.size(); i++) {
            Id practiceId = practiceIds[i];
            Id practitionerId = practitionerIds[i];
            String name = names[i];
            Boolean isActive = (isActiveValues != null && i < isActiveValues.size()) ? isActiveValues[i] : true;
            hpfRecords.add(createHPFRecord(practiceId, practitionerId, name, isActive, null));
        }
        return hpfRecords;
    }

    /**
     * @description Creates and inserts multiple HPF records for bulk testing
     * @param practiceIds List of Practice Account IDs
     * @param practitionerIds List of Provider Contact IDs
     * @param names List of Name values
     * @param isActiveValues List of IsActive values (optional)
     * @return List of inserted HPF records
     */
    public static List<HealthcarePractitionerFacility> createAndInsertHPFRecords(
        List<Id> practiceIds,
        List<Id> practitionerIds,
        List<String> names,
        List<Boolean> isActiveValues
    ) {
        List<HealthcarePractitionerFacility> hpfRecords = createHPFRecords(practiceIds, practitionerIds, names, isActiveValues);
        if (!hpfRecords.isEmpty()) {
            insert hpfRecords;
        }
        return hpfRecords;
    }

    /**
     * @description Helper method to get Provider Account by NPI using Identifier records
     * @param npi NPI value to search for
     * @return Provider Account with PersonContactId populated, or null if not found
     */
    public static Account getProviderAccountByNPI(String npi) {
        if (String.isBlank(npi)) {
            return null;
        }

        List<Identifier> identifiers = [
            SELECT Id, ParentRecordId, ID_Value__c
            FROM Identifier
            WHERE ID_Value__c = :npi
            AND IdUsageType = :ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
            AND ParentRecordId != null
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (identifiers.isEmpty() || identifiers[0].ParentRecordId == null) {
            return null;
        }

        List<Account> providerAccounts = [
            SELECT Id, PersonContactId, FirstName, LastName, Name
            FROM Account
            WHERE Id = :identifiers[0].ParentRecordId
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PROVIDER_RT
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (!providerAccounts.isEmpty() && providerAccounts[0].PersonContactId != null) {
            return providerAccounts[0];
        }
        return null;
    }

    /**
     * @description Helper method to get Practice Account by External ID
     * @param externalId XCDC_ExternalId__c value
     * @return Practice Account, or null if not found
     */
    public static Account getPracticeAccountByExternalId(String externalId) {
        List<Account> accounts = [
            SELECT Id, XCDC_ExternalId__c, Name
            FROM Account
            WHERE XCDC_ExternalId__c = :externalId
            AND RecordTypeId = :ConstantsUtil.ACCOUNT_PRACTICE_RT
            LIMIT 1
        ];
        return accounts.isEmpty() ? null : accounts[0];
    }
}