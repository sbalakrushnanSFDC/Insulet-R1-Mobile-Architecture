/**
* @description Apex service class to process Provider–Practice Leads and perform record creation, mapping, and lead conversion.
* Executes in system mode, ensuring the process runs with elevated privileges.
* ============================ Logs =============================================
* Version      Modified Date       Modified By                   Brief Note
* V1.0.0       29th Oct 2025       Sunil Khanchandani            Initial Version
* V1.0.1       10th Dec 2025       Charchit Nirayanwal           Updated(US - NGASIM-1214) - Added HCPF duplicate prevention and reactivation logic
* V1.0.2       22nd Jan 2026       Saikat Ghosh                  Replaced this IdValue with ID_Value__c(US - NGASIM-1899)
* V1.0.3       09th Feb 2026       Chitresh Vijayvargiya         Added new methods to create ACR and CCR record for ASPN Source Lead(US - NGOMCT-2121)
* V1.0.4       10th Feb 2026       Saikat Ghosh                  Updated(US - NGASIM-2252) - Updated convertLead method to handle Queue owner scenario
* V1.0.5       10th Feb 2026       Sushanth Shetty               Updated(US - NGASIM-2252) - Added addtinal fields to fetchLeadRecord method
* V1.0.6       12th Feb 2026       Chitresh Vijayvargiya         Updated processProviderPracticeAccount where added check on Legacy Id of Lead before calling linkOppwithPracticeAndProvider Lead(US - NGOMCT-2121)
* V1.0.7       18th Feb 2026       Chitresh Vijayvargiya         Updated processProviderPracticeAccount where added Roles for ACR record creation(US - NGOMCT-2121)
* V1.0.8	   05th Mar 2026	   Ramesh Dhaka					 Added BillingStateCode mapping in practice account create method
*/

public inherited sharing class ProviderPracticeLeadService {

    /**
    * @description Entry point for LWC or Flow to process the Lead and return resulting Provider & Practice names.
    * @param leadId lead record Id to process
    * @return Map containing keys 'ProviderName' and 'PracticeName'
    */
    @AuraEnabled
    public static Map<String, SObject> processLead(Id leadId) {
        Map<String,SObject> responseMap = new Map<String,SObject>();
        Lead leadRecord = fetchLeadRecord(leadId);
        if(leadRecord!= null) {
            responseMap = processProviderPracticeAccount(leadRecord);
        }
        return responseMap;
    }



    /**
    * @description Processes the lead to create Provider/Practice accounts and a Healthcare Practitioner Facility relation.
    * @param leadRecord Lead record to process
    * @return Map with Provider and Practice Account names
    */
    public static Map<String, SObject> processProviderPracticeAccount(Lead leadRecord) {

        Account provider = null;
        Account practice = null;
        Boolean isLeadConverted = false;
        Boolean identifierCreated = false;
        HealthcarePractitionerFacility facilityCreated = null;
        Map<String, SObject> returnResponse = new Map<String, SObject>();

        if (hasProviderOnly(leadRecord)) {
            provider = getAccountRecord(leadRecord.Related_Provider__c);
            practice = createPracticeAccount(leadRecord);
        } else if (hasPracticeOnly(leadRecord)) {
            practice = getAccountRecord(leadRecord.Practice__c);
            provider = createProviderAccount(leadRecord);
        } else if (isBothBlank(leadRecord)) {
            practice = createPracticeAccount(leadRecord);
            provider = createProviderAccount(leadRecord);
        }else{
            provider = getAccountRecord(leadRecord.Related_Provider__c);
            practice = getAccountRecord(leadRecord.Practice__c);
        }


        //if lead, provider record and practice record is not null then create identifier & heath care facility record
        if (provider != null && practice != null) {
            identifierCreated = createNPIIdentifier(leadRecord, provider);
            facilityCreated = createHealthcareFacility(provider, practice);
            isLeadConverted = convertLead(leadRecord.Id, provider.Id);
            if(leadRecord.LeadSource==ConstantsUtil.LEAD_SOURCE_ASPN && leadRecord.Patient__c !=null){
                createACR(leadRecord.Patient__r.PersonContactId,practice.Id);
                createCCR(leadRecord.Patient__r.PersonContactId,provider.PersonContactId);
                if(leadRecord.Legacy_Id__c !=null){ 
                linkOppwithPracticeAndProvider(leadRecord.Legacy_Id__c,practice.Id,provider.Id);
                }
            }
        }

        if (isLeadConverted && facilityCreated!=null) {
            provider.Name = provider.FirstName + ' - ' + provider.LastName;

            Map<String,Id> relatedPatientLeadsUpdateMap = new Map<String,Id>{'convertedLeadId' => leadRecord.Id,
                'providerId' => provider.Id,
                'practiceId' => practice.Id,
                'practitionerId' => facilityCreated.Id
                };
                    PatientLeadUpdateWrapper wrapper = new PatientLeadUpdateWrapper(relatedPatientLeadsUpdateMap);
            updateRelatedPatientLeads(JSON.serialize(wrapper));

            LeadConversionEnqueueConsentMapping.enqueueConsentMappingForProvider(leadRecord, provider);
        }

        // Return actual Account SObjects
        returnResponse.put('Provider', provider);
        returnResponse.put('Practice', practice);
        return returnResponse;
    }

    /* ======================== Helper Condition Methods ======================== */

    /**
    * @description Checks if lead has Provider only (no Practice)
    * @param ld Lead record
    * @return Boolean flag
    */
    private static Boolean hasProviderOnly(Lead ld) {
        return ld.Related_Provider__c != null && ld.Practice__c == null;
    }

    /**
    * @description Checks if lead has Practice only (no Provider)
    * @param ld Lead record
    * @return Boolean flag
    */
    private static Boolean hasPracticeOnly(Lead ld) {
        return ld.Practice__c != null && ld.Related_Provider__c == null;
    }

    /**
    * @description Checks if both Provider and Practice are blank
    * @param ld Lead record
    * @return Boolean flag
    */
    private static Boolean isBothBlank(Lead ld) {
        return ld.Related_Provider__c == null && ld.Practice__c == null;
    }

    /* ======================== Data Operations ======================== */

    /**
    * @description Queries Lead fields used in processing.
    * @param leadId Id of the Lead record
    * @return Lead record with required fields
    */
    @AuraEnabled
    public static Lead fetchLeadRecord(Id leadId) {
        Lead leadRecord;
        try{
            throwExceptionForTest('customExceptionSwitch is turned on');
            if (leadId == null) {
                Logger.debug('Lead Id is required.').addTag(ConstantsUtil.ASIM_TAG);
                Logger.saveLog();
                leadRecord = null;
                return leadRecord;
            }
            leadRecord = [
                SELECT Id, IndividualId, Practice__c, IsConverted, Related_Provider__c,Practice_Name__c,
                Street, City, State, StateCode, PostalCode, Country,NPI__c,LeadSource,Patient__c,Patient__r.PersonContactId,Legacy_Id__c,
                FirstName, LastName, Salutation, Suffix, Phone, Email,
                Provider_Matching_Status__c,
                Practice_Matching_Status__c,
                Related_Provider__r.IsActive,
                Practice__r.IsActive
                FROM Lead
                WHERE Id = :leadId
                WITH SYSTEM_MODE
            ];
        }catch (Exception ex) {
            leadRecord = null;
            logError('Failed to fetch lead record', ex);
        }
        return leadRecord;
    }

    /**
    * @description Fetches the account record
    * @param accountId Id of the Provider Account
    * @return Account record
    */
    @TestVisible
    private static Account getAccountRecord(Id accountId) {
        Account accountRecord;
        try{
            throwExceptionForTest('customExceptionSwitch is turned on');
            accountRecord = [
                SELECT Id, Name, PersonContactId, PersonIndividualId,
                FirstName, LastName, RecordTypeId
                FROM Account
                WHERE Id = :accountId
                WITH SYSTEM_MODE
            ];
        }catch (Exception ex) {
            accountRecord = null;
            logError('Failed to fetch account record', ex);
        }
        return accountRecord;
    }

    /**
    * @description Fetches existing Identifier record for given provider and NPI.
    * @param providerId The Id of the Provider Account.
    * @param npiValue The NPI value from the Lead.
    * @return Identifier record if found, otherwise null.
    */
    private static Identifier getExistingIdentifier(Id providerId, String npiValue) {
        List<Identifier> existingIdentifiers = [
            SELECT Id, ParentRecordId, IdUsageType, ID_Value__c
            FROM Identifier
            WHERE ParentRecordId = :providerId
            AND IdUsageType = :ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE
            AND ID_Value__c = :npiValue
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        return existingIdentifiers.isEmpty() ? null : existingIdentifiers[0];
    }

    /**
    * @description Creates a new Practice Account
    * @param ld Lead record
    * @return Created Account record
    */
    private static Account createPracticeAccount(Lead ld) {
        Account acc = new Account();
        if (ld.Practice_Name__c == null || ld.PostalCode == null) {
            Logger.debug('Practice Name and Postal Code is required for creating Practice Account').addTag(ConstantsUtil.ASIM_TAG);
            Logger.saveLog();
            acc = null;
            return acc;
        }
        acc.Name = ld.Practice_Name__c;
        acc.RecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT;
        acc.BillingStreet = ld.Street;
        acc.BillingCity = ld.City;
        acc.BillingStateCode = ld.StateCode;// Added state code for orgsync Fix NGCRMI-2850
        acc.BillingState = ld.State;
        acc.BillingPostalCode = ld.PostalCode;
        acc.BillingCountry = ld.Country;
        acc.IsActive=true;
        return insertNewAccount(acc);
    }

    /**
    * @description Creates a new Provider Account
    * @param ld Lead record
    * @return Created Account record
    */
    private static Account createProviderAccount(Lead ld) {
        Account acc = new Account();
        acc.RecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT;
        acc.FirstName = ld.FirstName;
        acc.LastName = ld.LastName;
        acc.Salutation = ld.Salutation;
        acc.Phone = ld.Phone;
        acc.PersonEmail = ld.Email;
        acc.Suffix = ld.Suffix;
        acc.BillingPostalCode = ld.PostalCode;
        acc.IsActive=true;
        Account accountRecord = insertNewAccount(acc);
        return (accountRecord?.Id != null) ? getAccountRecord(accountRecord.Id) : null;
    }

    /**
    * @description insert new account with System mode access
    * @param account account record to insert record
    * @return account inserted account record
    */
    @TestVisible
    private static Account insertNewAccount(Account account){
        // Create DML options to bypass duplicate alert rules
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        dmlOpts.optAllOrNone = false;

        List<Database.SaveResult> saveResults = Database.insert(new List<Account>{account}, dmlOpts, AccessLevel.SYSTEM_MODE);

        if (!saveResults.isEmpty() && !saveResults[0].isSuccess()) {
            logSaveResultErrors('Failed to create account record.', saveResults[0], null);
            account = null;
        }

        return account;
    }

    /**
    * @description Creates a new Identifier record
    * @param ld Lead record
    * @param provider Provider Account record
    * @return success flag for failure or success insertion
    */
    @TestVisible
    private static Boolean createNPIIdentifier(Lead ld, Account provider) {
        Boolean success = false;
        try {
            throwExceptionForTest('customExceptionSwitch is turned on');
            if (ld.NPI__c != null) {
                Identifier existingIdentifier = getExistingIdentifier(provider.Id, ld.NPI__c);
                if (existingIdentifier == null) {
                    Identifier identifierRecord = new Identifier(
                        ParentRecordId = provider.Id,
                        IdUsageType = ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE,
                        ID_Value__c = ld.NPI__c
                    );
                    Database.insert(identifierRecord, AccessLevel.SYSTEM_MODE);
                    success = true;
                }
            }
        } catch (Exception ex) {
            logError('Failed to create Identifier record', ex);
        }
        return success;
    }

    /**
    * @description Fetches all existing HealthcarePractitionerFacility records for given provider and practice.
    * @param practitionerId The Contact Id (PersonContactId) of the Provider Account.
    * @param accountId The Id of the Practice Account.
    * @return List of HealthcarePractitionerFacility records (empty list if none found).
    */
    @TestVisible
    private static List<HealthcarePractitionerFacility> getExistingHCPFList(Id practitionerId, Id accountId) {
        return [
            SELECT Id, Name, IsActive, AccountId, PractitionerId, IsPrimaryFacility
            FROM HealthcarePractitionerFacility
            WHERE PractitionerId = :practitionerId
            AND AccountId = :accountId
            WITH SYSTEM_MODE
            ORDER BY IsActive DESC
        ];
    }

    /**
    * @description Creates a new Healthcare Facility record, reactivates existing inactive one, or returns existing active one.
    * Prevents duplicate HCPF creation by checking for existing records.
    * Handles edge case where multiple HCPF records exist (both active and inactive).
    * @param provider Provider Account record
    * @param practice Practice Account record
    * @return HealthcarePractitionerFacility record (existing active, reactivated, or newly created)
    */
    @TestVisible
    private static HealthcarePractitionerFacility createHealthcareFacility(Account provider, Account practice) {
        HealthcarePractitionerFacility facility = null;
        try {
            throwExceptionForTest('customExceptionSwitch is turned on');
            // Query once for all existing HCPF records (ordered by IsActive DESC so active comes first)
            List<HealthcarePractitionerFacility> existingHCPFList = getExistingHCPFList(
                provider.PersonContactId,
                practice.Id
            );

            if (!existingHCPFList.isEmpty()) {
                // Check if any active HCPF exists
                HealthcarePractitionerFacility activeHCPF = null;
                HealthcarePractitionerFacility inactiveHCPF = null;

                for (HealthcarePractitionerFacility hcpf : existingHCPFList) {
                    if (hcpf.IsActive) {
                        activeHCPF = hcpf;
                        break; // Found active, no need to continue
                    } else if (inactiveHCPF == null) {
                        inactiveHCPF = hcpf; // Save first inactive
                        break; // Found first inactive, all remaining will be inactive too (due to ORDER BY)
                    }
                }

                // Step 1: If active HCPF exists, use it (block creation of new)
                if (activeHCPF != null) {
                    return activeHCPF; // Return existing - don't create duplicate
                }

                // Step 2: If only inactive HCPF exists, reactivate the first one
                if (inactiveHCPF != null) {
                    inactiveHCPF.IsActive = true;
                    Database.SaveResult saveResult = Database.update(inactiveHCPF, false, AccessLevel.SYSTEM_MODE);

                    if (!saveResult.isSuccess()) {
                        logSaveResultErrors('Failed to reactivate HCPF.', saveResult, inactiveHCPF.Id);
                        return null;
                    }
                    return inactiveHCPF;

                }
            }

            // Step 3: Create new HCPF (only if no existing HCPF found)
            facility = new HealthcarePractitionerFacility();
            String facilityName = generateFacilityName(provider, practice);
            facility.Name = facilityName;
            facility.AccountId = practice.Id;
            facility.PractitionerId = provider.PersonContactId;
            facility.IsActive = true;
            facility.IsPrimaryFacility = true;

            Database.SaveResult saveResult = Database.insert(facility, false, AccessLevel.SYSTEM_MODE);

            if (!saveResult.isSuccess()) {
                logSaveResultErrors('Failed to create new HCPF.', saveResult, null);
                facility = null;
            }
        } catch (Exception ex) {
            facility = null;
            logError('Failed to create/update Healthcare Facility record', ex);
        }
        return facility;
    }


    /**
    * @description Builds and validates Healthcare Facility Name.
    * If provider first name is blank, omits it. Ensures name ≤ 255 chars.
    * @param provider Provider Account record
    * @param practice Practice Account record
    * @return Valid facility name (≤ 255 chars)
    */
    private static String generateFacilityName(Account provider, Account practice) {
        // Build name (skip first name if empty)
        String fullName = (String.isNotBlank(provider.FirstName)
                           ? provider.FirstName + ' '
                           : '')
            + provider.LastName + ' - ' + practice.Name;
        //Trim to 255 characters if needed
        if (fullName.length() > 255) {
            fullName = fullName.substring(0, 255);
        }

        return fullName;
    }


    /**
    * @description Converts the Lead
    * @param leadId Id of the Lead record
    * @param accountId Id of the Provider Account to be used in lead convertion
    * @return isLeadConverted flag to indicate success or failure
    */
    @TestVisible
    private static Boolean convertLead(Id leadId, Id accountId) {
        Boolean isLeadConverted = false;
        try {
            throwExceptionForTest('customExceptionSwitch is turned on');
            // Change the owner to the current user if the ProviderPractice Lead owner is queue (Added as part of NGASIM-2252)
            List<Group> queueList = [
                SELECT Id
                FROM Group
                WHERE Type = 'Queue'
                AND Id IN (
                    SELECT OwnerId
                    FROM Lead
                    WHERE OwnerId != null AND Id = :leadId
                )
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            // Configure Lead conversion settings
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(leadId);
            lc.setConvertedStatus(ConstantsUtil.LEAD_PROVIDERPRACTICE_CONVERT_STATUS);
            lc.setAccountId(accountId);
            lc.setDoNotCreateOpportunity(true);
            lc.setSendNotificationEmail(false);

            // If Lead owner is Queue, set owner to current user(Added as part of NGASIM-2252)
            if (!queueList.isEmpty()) {
                lc.setOwnerId(UserInfo.getUserId());
            }

            // Perform Lead conversion
            Database.LeadConvertResult lcr = Database.convertLead(lc);
            isLeadConverted = lcr.isSuccess();

        } catch (Exception ex) {
            logError('Failed to convert lead record ' + leadId, ex);
        }
        return isLeadConverted;
    }

    /**
    * @description Wrapper class used to bundle multiple identifiers related to Provider–Practice–Lead mapping.
    * Helps reduce the number of parameters passed to the @future method, adhering to Apex limits and PMD rules.
    */
    public class PatientLeadUpdateWrapper {
        public Id convertedLeadId;
        public Id providerId;
        public Id practiceId;
        public Id practitionerId;

        /**
        * @description Constructor to initialize wrapper using a Map of record Ids.
        * @param ids A Map containing the required record Ids:
        *  - convertedLeadId
        *  - providerId
        *  - practiceId
        *  - practitionerId
        */
        public PatientLeadUpdateWrapper(Map<String, Id> ids) {
            this.convertedLeadId = ids.get('convertedLeadId');
            this.providerId = ids.get('providerId');
            this.practiceId = ids.get('practiceId');
            this.practitionerId = ids.get('practitionerId');
        }
    }

    /**
    * @description Updates all Patient Leads related to the same Provider/Practice
    *              as the converted Provider–Practice Lead.
    *              Runs in System Mode for elevated access.
    * @param wrapperJson JSON string representation of the LeadUpdateWrapper containing all relevant IDs.
    */
    @future
    private static void updateRelatedPatientLeads(String wrapperJson) {
        try {
            throwExceptionForTest('customExceptionSwitch is turned on');
            PatientLeadUpdateWrapper input = (PatientLeadUpdateWrapper) JSON.deserialize(wrapperJson, PatientLeadUpdateWrapper.class);
            // Query all Patient leads matching the related provider or practice
            List<Lead> patientLeadsToUpdate = getRelatedPatientLeads(input.convertedLeadId);
            // Update each patient lead with related Provider and Practice IDs
            if(!patientLeadsToUpdate.isEmpty()){
                for (Lead patientLead : patientLeadsToUpdate) {
                    patientLead.Related_Provider__c = input.providerId;
                    patientLead.Practice__c = input.practiceId;
                    patientLead.Provider_Practice_Affiliation__c = input.practitionerId;
                    patientLead.Provider_Practice_Lead__c = null;
                }
                // Perform the database update in system mode
                Database.update(patientLeadsToUpdate, AccessLevel.SYSTEM_MODE);
            }
        } catch (Exception ex) {
            logError('Failed to update Patient Leads after Provider–Practice conversion', ex);
        }
    }

    /**
    * @description Create ACR record
    * @param patientContactId  string representation Id of the Patient Contact to be used in creation of ACR.
    * @param practiceId string representation Practice Account Id to be used in creation of ACR.
    */
    @TestVisible
    private static void createACR(string patientContactId, string practiceId) {

        try{
            throwExceptionForTest('customExceptionSwitch is turned on');
            List<AccountContactRelation> acrList = new List<AccountContactRelation>();
            if(patientContactId !=null && practiceId !=null ) {
                List<AccountContactRelation> listOfExistingACR = [select Id,isActive,Is_Primary__c from AccountContactRelation where contactId = :patientContactId and AccountId = :practiceId WITH SYSTEM_MODE limit 1 ];

                if(listOfExistingACR.size()>0 ) {
                    listOfExistingACR[0].isActive = true;
                    listOfExistingACR[0].Is_Primary__c = true;
                    acrList.add(listOfExistingACR[0]);
                    Database.update(acrList, AccessLevel.SYSTEM_MODE);


                } else {
                    AccountContactRelation acrInstance = new AccountContactRelation();
                    acrInstance.contactId = patientContactId;
                    acrInstance.AccountId = practiceId;
                    acrInstance.isActive = true;
                    acrInstance.Roles = ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE;
                    acrInstance.Is_Primary__c = true;
                    acrList.add(acrInstance);
                    Database.insert(acrList, AccessLevel.SYSTEM_MODE);

                }
            }
        }
        catch (Exception ex) {
            logError('Failed to create ACR record in Lead conversion process', ex);
        }
    }


    /**
    * @description Create CCR record
    * @param patientContactId  string representation Id of the Patient Contact to be used in creation of CCR.
    * @param providerId string representation Provider Account's PersonContact Id to be used in creation of CCR.
    */
    @TestVisible
    private static void createCCR(string patientContactId, string providerId) {
        try{
            throwExceptionForTest('customExceptionSwitch is turned on');
            List<ContactContactRelation>ccrList = new List<ContactContactRelation>();
            if(patientContactId !=null && providerId !=null ) {
                List<ContactContactRelation> listOfExistingCCR = [SELECT Id,isActive,Is_Primary__c FROM ContactContactRelation WHERE contactId = :patientContactId and RelatedContactId = :providerId WITH SYSTEM_MODE limit 1 ];

                if(listOfExistingCCR.size()>0 ) {
                    listOfExistingCCR[0].isActive = true;
                    listOfExistingCCR[0].Is_Primary__c = true;
                    ccrList.add(listOfExistingCCR[0]);
                    Database.update(ccrList, AccessLevel.SYSTEM_MODE);

                } else {

                    List<PartyRoleRelation> prr = [SELECT Id, Name FROM PartyRoleRelation WHERE Name = :ConstantsUtil.PARTY_ROLE_RELATION_TYPE_PATIENT_PROVIDER WITH SYSTEM_MODE limit 1];

                    ContactContactRelation ccrInstance = new ContactContactRelation();
                    ccrInstance.contactId = patientContactId;
                    ccrInstance.RelatedContactId = providerId;
                    if(prr.size()>0){
                        ccrInstance.PartyRoleRelationId = prr[0].Id;
                    }
                    ccrInstance.isActive = true;
                    ccrInstance.Is_Primary__c = true;
                    ccrList.add(ccrInstance);
                    Database.insert(ccrList, AccessLevel.SYSTEM_MODE);
                }
            }
        }
        catch (Exception ex) {
            logError('Failed to create CCR record in Lead conversion process', ex);
        }
    }

    /**
    * @description link Practice and Provider with Opportunity
    * @param practiceId  string representation Id of the Patient Contact to be used in creation of CCR.
    * @param providerId string representation Provider Account's PersonContact Id to be used in creation of CCR.
    * @param leadLegacyId string representation LegacyId from Lead record to be used in finding OpportunityLineItem.
    */
    private static void linkOppwithPracticeAndProvider(string leadLegacyId, string practiceId, string providerId) {
        try {
            throwExceptionForTest('customExceptionSwitch is turned on');
            List<OpportunityLineItem> opLineList = [SELECT Id, OpportunityId FROM OpportunityLineItem WHERE External_ASPNID__c = :leadLegacyId WITH SYSTEM_MODE LIMIT 1];
            List<Opportunity> opList = new List<Opportunity>();
            if (!opLineList.isEmpty()) {
                Opportunity op = new Opportunity();
                op.Id = opLineList[0].OpportunityId;
                op.Provider__c = providerId;
                op.Practice__c = practiceId;
                opList.add(op);
                Database.update(opList, AccessLevel.SYSTEM_MODE);
            }
        } catch (Exception ex) {
            logError('Failed to link Opportunity with Practice and Provider', ex);
        }
    }

    /**
    * @description get related patient lead records
    * @param leadId convertedLeadId
    * @return patientLeads  list of related patient leads
    */
    @TestVisible
    private static List<Lead> getRelatedPatientLeads(Id leadId){
        List<Lead> patientLeads = new List<Lead>();
        try{
            throwExceptionForTest('customExceptionSwitch is turned on');

            patientLeads = [
                SELECT Id, Related_Provider__c, Practice__c, Provider_Practice_Affiliation__c,
                Provider_Practice_Lead__c, RecordType.DeveloperName
                FROM Lead
                WHERE RecordTypeId =:ConstantsUtil.LEAD_PATIENT_RT AND
                Provider_Practice_Lead__c = :leadId
                WITH SYSTEM_MODE
            ];
        }catch (Exception ex) {
            logError('Failed to fetch related patient leads record', ex);
        }
        return patientLeads;
    }

    /**
    * @description Logs error messages with context using Logger framework
    * @param message The error message
    * @param ex Exception object (can be null for permission errors)
    */
    private static void logError(String message, Exception ex) {
        Logger.error(message, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    /**
    * @description Builds error message from Database.SaveResult and logs it
    * @param contextMessage Context message describing what operation failed
    * @param saveResult The Database.SaveResult containing error details
    * @param recordId Optional record Id to include in error message
    */
    /**
     * @description Generic test-only exception hook. Throws when Test.isRunningTest() and customExceptionSwitch is true.
     * @param message The exception message to display
     */
    @TestVisible
    private static void throwExceptionForTest(String message) {
        if (Test.isRunningTest() && ConstantsUtil.customExceptionSwitch) {
            throw new MyCustomException(message);
        }
    }

    @TestVisible
    private static void logSaveResultErrors(String contextMessage, Database.SaveResult saveResult, Id recordId) {
        String errorMsg = contextMessage;
        if (recordId != null) {
            errorMsg += ' Record Id: ' + recordId + '.';
        }
        errorMsg += ' Errors: ';

        for (Database.Error err : saveResult.getErrors()) {
            errorMsg += err.getMessage() + '; ';
        }

        Logger.error(errorMsg)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    /**
    * @description Exception class for Product Recommendation Engine
    */
    public class MyCustomException extends Exception {}
}