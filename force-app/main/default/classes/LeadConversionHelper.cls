/**
 * Helper class to handle Account and Opportunity creation for lead conversion.
 * This class provides methods to create Patient PersonAccount records and NCS Opportunity records
 * from Lead data, including field mapping, Individual ID transfer, and error handling.
 * It also supports updating existing Accounts with Lead data during conversion.
 *
 * @author      : Priyansh Shukla
 * @created Date: 4th November 2025
 * @description : Helper class to handle Account and Opportunity creation for lead conversion
 * @story Number: NGASIM-992
 * =========================== Logs ======================================
 * Version      Modified Date           Modified By                 Brief Note
 * V1.0.0       4th November 2025       Priyansh Shukla             Initial Version(US - NGASIM-992)
 * V1.0.1       18th November 2025      Charchit N.                 US - NGOMCT-509
 * V1.0.2       26th November 2025      Bijayalaxmi Prusty          Updated(US - NGASIM-1050)
 * V1.0.0       27th November 2025      Priyansh Shukla             Modified(US - NGASIM-1210)
 * V1.0.3       2nd December 2025       Bijayalaxmi Prusty          Modified(US - NGASIM-1080)
 * V1.0.4       15th December 2025      Bijayalaxmi Prusty          Modified(US - NGOMCT-824)
 * v1.0.5       12th Jan 2026           Anup Bandawar               Updated(US - NGASIM-1029)
 * v1.0.6       14th Jan 2026           Jatin Butta                 Modified(US - NGASIM-1901, NGASIM-1602)
 * v1.0.7       22nd Jan 2026           Priyansh Shukla             Modified(US - NGOMCT-1749)
 * V1.2.2		29th JAN 2026		    Priyansh Shukla			    Updated(US - NGASIM-2120)
 * V1.2.3		12nd Feb 2026		    Bijayalaxmi Prusty			Modified(US - NGASIM-2065)
 */
public inherited sharing class LeadConversionHelper {

    @TestVisible
    private static Boolean simulateAccountPermissionFailure = false;

    @TestVisible
    private static Boolean simulateOpportunityPermissionFailure = false;

    /**
     * @description Creates Patient PersonAccount records from Lead data
     * @param leadsToConvert The list of Lead records to create accounts from
     * @return List of created and inserted Account records (empty list if insert fails)
     */
    public static List<Account> createPatientAccounts(List<Lead> leadsToConvert) {
        // Check CRUD permission for Account creation
		if (!Schema.SObjectType.Account.isCreateable() || (Test.isRunningTest() && simulateAccountPermissionFailure)) {
            LeadConversionLogUtil.logDebug('User does not have permission to create Account records');
            return new List<Account>();
        }

        List<Account> accountsToInsert = buildAccountRecords(leadsToConvert, ConstantsUtil.ACCOUNT_PATIENT_RT);

        if (!accountsToInsert.isEmpty()) {
            return insertAccountsWithErrorHandling(accountsToInsert);
        }

        return accountsToInsert;
    }

    /**
     * @description Creates NCS Opportunity records for the converted Accounts
     * @param leadsToConvert The list of Lead records
     * @param accountsCreated The list of created Account records
     * @return List of created and inserted Opportunity records (empty list if insert fails)
     */
    public static List<Opportunity> createNCSOpportunities(List<Lead> leadsToConvert, List<Account> accountsCreated) {
        return LeadConversionOpportunityHelper.createNCSOpportunities(
            leadsToConvert,
            accountsCreated,
            simulateOpportunityPermissionFailure
        );
    }

    /**
     * @description Updates existing accounts with lead data
     * @param leadsToAccountMap Map of leads to their matched accounts for updating
     */
    public static void updateExistingAccountsWithLeadData(Map<Lead, Account> leadsToAccountMap) {
        if (leadsToAccountMap == null || leadsToAccountMap.isEmpty()) { return; }

        // Check CRUD permission for Account update
        if (!Schema.SObjectType.Account.isUpdateable()) {
            LeadConversionLogUtil.logDebug('User does not have permission to update Account records');
            return;
        }

        List<Account> accountsToUpdate = buildAccountsWithLeadData(leadsToAccountMap);

        if (!accountsToUpdate.isEmpty()) {
            List<Database.SaveResult> updateResults = Database.update(accountsToUpdate, false, AccessLevel.USER_MODE);

            // Log any update failures
            for (Integer i = 0; i < updateResults.size(); i++) {
                if (!updateResults[i].isSuccess()) {
                    LeadConversionLogUtil.logError( 'Failed to update Account with Lead data at index ' + i + '. Errors: ' +LeadConversionLogUtil.buildErrorMessage(updateResults[i].getErrors()));
                }
            }
        }
    }

    /**
     * @description Gets field value from lead if not blank, otherwise from account
     * @param leadValue The lead field value
     * @param accountValue The account field value to fallback to
     * @return Object The lead value if not blank, otherwise account value
     */
    private static Object getFieldValue(Object leadValue, Object accountValue) {
        if (leadValue == null) {
            return accountValue;
        }
        if (leadValue instanceof String && String.isBlank((String) leadValue)) { return accountValue; }
        return leadValue; }
    /**
     * @description Lead-to-Account field mappings used for both Account creation and updating.
     *              Key = Lead field API name, Value = Account field API name.
     */
    private static final Map<String, String> LEAD_TO_ACCOUNT_FIELD_MAP = new Map<String, String>{
        'Salutation' => 'Salutation',
        'Suffix' => 'Suffix',
        'FirstName' => 'FirstName',
        'MiddleName' => 'MiddleName',
        'LastName' => 'LastName',
        'Email' => 'PersonEmail',
        'Phone' => 'Phone',
        'Street' => 'BillingStreet',
        'City' => 'BillingCity',
        'State' => 'BillingState',
        'PostalCode' => 'BillingPostalCode',
        'Country' => 'BillingCountry',
        'Date_of_Birth__c' => 'Date_of_Birth__c',
        'LeadSource' => 'PersonLeadSource',
        'Type_of_Diabetes__c' => 'Type_of_Diabetes__c',
        'GenderIdentity' => 'PersonGenderIdentity',
        'Preferred_Language__c' => 'Preferred_Language__c',
        'Sensor_CGM_Continuous_Glucose_Monitor__c' => 'Sensor_CGM_Continuous_Glucose_Monitor__c',
        'Insurance_Type__c' => 'Insurance_Type__c',
        'Current_Therapy__c' => 'Current_Therapy__c'
    };

    /**
     * @description Applies Lead-to-Account field mappings on the target Account.
     *              If existingAccount is provided, blank/null Lead values fall back to existing Account values.
     * @param targetAccount The Account being created/updated
     * @param leadRec The Lead record
     * @param existingAccount Existing Account record (optional) used for fallback values
     */
    private static void applyLeadFieldsToAccount(Account targetAccount, Lead leadRec, Account existingAccount) {
        if (targetAccount == null || leadRec == null) { return; }

        for (String leadFieldApi : LEAD_TO_ACCOUNT_FIELD_MAP.keySet()) {
            String accountFieldApi = LEAD_TO_ACCOUNT_FIELD_MAP.get(leadFieldApi);
            Object leadValue = leadRec.get(leadFieldApi);
            Object accountValue = (existingAccount == null) ? null : existingAccount.get(accountFieldApi);
            Object valueToSet = (existingAccount == null) ? leadValue : getFieldValue(leadValue, accountValue);
            targetAccount.put(accountFieldApi, valueToSet);
        }
    }

    /**
     * @description Updates existing Account records with Lead data
     * @param leadsToAccountMap Map of leads to their matched accounts for updating
     * @return List of Account records ready for update
     */
    private static List<Account> buildAccountsWithLeadData(Map<Lead, Account> leadsToAccountMap) {
        List<Account> accountsToUpdate = new List<Account>();

        // Get Lead IndividualId map (with re-query fallback for trigger context)
        List<Lead> leadsList = new List<Lead>(leadsToAccountMap.keySet());
        Map<Id, Id> leadToIndividualId = getLeadToIndividualIdMap(leadsList);

        for (Lead ld : leadsToAccountMap.keySet()) {
            Account existingAccount = leadsToAccountMap.get(ld);
            if (existingAccount == null || existingAccount.Id == null) {
                continue;
            }

            // Transfer IndividualId from Lead to Account only if Account doesn't already have one
            Id individualId = null;
            if (existingAccount.PersonIndividualId == null) {
                individualId = leadToIndividualId.get(ld.Id);
            } else {
                individualId = existingAccount.PersonIndividualId;
            }

            Account accountToUpdate = new Account(Id = existingAccount.Id);
            applyLeadFieldsToAccount(accountToUpdate, ld, existingAccount);
            accountToUpdate.PersonIndividualId = individualId;

            accountsToUpdate.add(accountToUpdate);
        }
        return accountsToUpdate;
    }

    /**
     * @description Gets a map of Lead Id to IndividualId, with re-query fallback if IndividualId is not in memory
     * @param leads List of Lead records
     * @return Map of Lead Id to IndividualId
     */
    private static Map<Id, Id> getLeadToIndividualIdMap(List<Lead> leads) {
        Map<Id, Id> leadToIndividualId = new Map<Id, Id>();
        if (leads == null || leads.isEmpty()) { return leadToIndividualId; }

        // First pass: try to use in-memory IndividualId without throwing if the field wasn't queried.
        // Note: even if IndividualId is present-but-null in memory, we may still re-query because a trigger
        // could have populated it via DML and the in-memory Lead won't reflect that change.
        Set<Id> leadIdsToQuery = collectLeadIdsNeedingIndividualIdQuery(leads, leadToIndividualId);
        if (leadIdsToQuery.isEmpty()) {
            return leadToIndividualId;
        }

        // Re-query for any leads that don't have IndividualId in memory.
        try {
            for (Lead ld : [
                SELECT Id, IndividualId
                FROM Lead
                WHERE Id IN :leadIdsToQuery
                WITH USER_MODE
            ]) {
                if (ld.IndividualId != null) {
                    leadToIndividualId.put(ld.Id, ld.IndividualId);
                }
            }
        } catch (Exception e) { LeadConversionLogUtil.logDebug('Unable to query Lead.IndividualId for transfer to PersonAccount. Error: ' + e.getMessage()); }

        return leadToIndividualId;
    }

    /**
     * @description Collects Lead Ids that need a DB query to retrieve IndividualId and populates any in-memory values found.
     * @param leads List of Lead records (may be trigger context records)
     * @param leadToIndividualId Output map to populate with any non-null in-memory IndividualId values
     * @return Set of Lead Ids that should be queried for IndividualId
     */
    private static Set<Id> collectLeadIdsNeedingIndividualIdQuery(List<Lead> leads, Map<Id, Id> leadToIndividualId) {
        Set<Id> leadIdsToQuery = new Set<Id>();
        for (Lead ld : leads) {
            if (ld == null || ld.Id == null) { continue; }

            Id individualId = getInMemoryIndividualId(ld);
            if (individualId != null) {
                leadToIndividualId.put(ld.Id, individualId);
            } else {
                leadIdsToQuery.add(ld.Id);
            }
        }
        return leadIdsToQuery;
    }

    /**
     * @description Returns the in-memory IndividualId if the field was queried/populated; otherwise returns null without throwing.
     * @param ld Lead record to read from
     * @return Id (IndividualId) if present in memory; otherwise null
     */
    private static Id getInMemoryIndividualId(Lead ld) {
        if (ld == null) { return null; }
        Map<String, Object> populated = ld.getPopulatedFieldsAsMap();
        if (populated == null
            || !populated.containsKey('IndividualId')) {
            return null;
        }
        return (Id) populated.get('IndividualId');
    }

    /**
     * @description Builds Account records from Lead data with specified record type
     * @param leadsToConvert The list of Lead records
     * @param accountRecordTypeId The RecordType Id to use for the created Accounts
     * @return List of Account records ready for insert
     */
    private static List<Account> buildAccountRecords(List<Lead> leadsToConvert, Id accountRecordTypeId) {
        List<Account> accountsToInsert = new List<Account>();

        // Get Lead IndividualId map (with re-query fallback for trigger context)
        Map<Id, Id> leadToIndividualId = getLeadToIndividualIdMap(leadsToConvert);

        for (Lead ld : leadsToConvert) {
            Id individualId = leadToIndividualId.get(ld.Id);

            Account patientAccount = new Account(RecordTypeId = accountRecordTypeId);
            applyLeadFieldsToAccount(patientAccount, ld, null);
            patientAccount.PersonIndividualId = individualId;
            accountsToInsert.add(patientAccount);
        }
        return accountsToInsert;
    }

    /**
     * @description Inserts Account records with error handling and maintains index positions
     * @param accountsToInsert List of Account records to insert
     * @return List of Accounts with null entries for failed records
     */
    private static List<Account> insertAccountsWithErrorHandling(List<Account> accountsToInsert) {
        // Configure DML options to bypass duplicate rule warnings
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        dml.optAllOrNone = false;  // Allow partial success

        // Insert with SYSTEM_MODE to bypass sharing and FLS
        // DML options (including duplicate bypass) are applied via setOptions above
        List<Database.SaveResult> saveResults = Database.insert(
            accountsToInsert,
            dml,                     // bypass DuplicateRules
            AccessLevel.SYSTEM_MODE  // Bypass sharing rules and FLS
        );

        // Process results - maintain index positions by keeping failed records as null
        for (Integer i = 0; i < saveResults.size(); i++) {
            if (!saveResults[i].isSuccess()) {
                LeadConversionLogUtil.logError(
                    'Failed to create Patient Account at index ' + i + '. Errors: ' +
                    LeadConversionLogUtil.buildErrorMessage(saveResults[i].getErrors())
                );
                accountsToInsert[i] = null; // Mark as failed by setting to null
            }
        }

        return accountsToInsert;
    }

    /**
     * @description Prepares all data needed for lead conversion including categorization, opportunity creation, and building convert objects
     * @param leadsToAccountMap Map of leads to convert and their matched accounts
     * @return LeadConversionData containing prepared conversion objects
     */
    public static LeadConversionData prepareLeadConversionData(Map<Lead, Account> leadsToAccountMap) {
        return LeadConversionConversionPlanner.prepareLeadConversionData(
            leadsToAccountMap,
            simulateOpportunityPermissionFailure
        );
    }

    /**
     * @description Executes lead conversions and handles results
     * @param conversionData LeadConversionData containing conversion objects
     * @return List of lead conversion results
     */
    public static List<Database.LeadConvertResult> executeLeadConversions(LeadConversionData conversionData) {
        return LeadConversionConversionPlanner.executeLeadConversions(conversionData);
    }

    /**
     * @description Deletes accounts by their IDs with error handling
     * Used to clean up accounts created for failed lead conversions
     * Uses SYSTEM_MODE to bypass user permissions and ensure cleanup happens
     * @param accountIds List of Account IDs to delete
     */
    public static void deleteAccountsByIds(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        try {
            // Query accounts to verify they exist
            // Using SYSTEM_MODE to bypass sharing rules and FLS
            List<Account> accountsToDelete = [
                SELECT Id
                FROM Account
                WHERE Id IN :accountIds
                WITH SYSTEM_MODE
            ];

            if (!accountsToDelete.isEmpty()) {
                // Delete accounts created for failed conversions
                // Using SYSTEM_MODE to bypass user permissions and ensure cleanup
                List<Database.DeleteResult> deleteResults = Database.delete(accountsToDelete, false, AccessLevel.SYSTEM_MODE);

                // Log individual deletion failures
                for (Integer i = 0; i < deleteResults.size(); i++) {
                    if (!deleteResults[i].isSuccess()) {
                        Id accountId = accountsToDelete[i].Id;
                        LeadConversionLogUtil.logError('Failed to delete Account ' + accountId + ' created for failed lead conversion. Errors: ' + LeadConversionLogUtil.buildErrorMessage(deleteResults[i].getErrors()));
                    }
                }
            }
        } catch (Exception ex) {
            // Log error but don't throw - account deletion failure shouldn't block the process
            LeadConversionLogUtil.logError('Failed to delete accounts created for failed lead conversions. Account IDs: ' + accountIds + '. Error: ' + ex.getMessage());
        }
    }

    /**
     * @description Data structure to hold lead conversion preparation results
     */
    public class LeadConversionData {
        public List<Database.LeadConvert> leadConverts;
        public List<Opportunity> existingOpportunitiesToUpdate;

        /**
         * @description Constructor to initialize LeadConversionData with empty collections
         */
        public LeadConversionData() {
            this.leadConverts = new List<Database.LeadConvert>();
            this.existingOpportunitiesToUpdate = new List<Opportunity>();
        }
    }

    /**
     * @description Data structure to hold input parameters for lead convert object building
     */
    public class LeadConvertBuildContext {
        public Map<Lead, Account> leadsToAccountMap;
        public Set<Id> accountsWithExistingOpportunities;
        public Map<Id, Opportunity> opportunityByAccountId;

        /**
         * @description Constructor to initialize LeadConvertBuildContext
         * @param leadsToAccountMap Map of leads to convert and their matched accounts
         * @param accountsWithExistingOpportunities Set of account IDs that have existing opportunities
         * @param opportunityByAccountId Map of Account Id to created opportunities for accounts that need them
         */
        public LeadConvertBuildContext(
            Map<Lead, Account> leadsToAccountMap,
            Set<Id> accountsWithExistingOpportunities,
            Map<Id, Opportunity> opportunityByAccountId
        ) {
            this.leadsToAccountMap = leadsToAccountMap;
            this.accountsWithExistingOpportunities = accountsWithExistingOpportunities;
            this.opportunityByAccountId = opportunityByAccountId;
        }
    }


    /**
     * @description Updates Validation_Bypass__c field to true for leads before conversion
     *              This bypasses validation rules that prevent manual status updates to 'Converted'
     *              Uses trigger bypass to prevent recursive trigger execution
     * @param leadsToConvert List of Lead records to update
     */
    @TestVisible
    public static void updateValidationBypassForLeads(List<Lead> leadsToConvert) {
        if (leadsToConvert == null || leadsToConvert.isEmpty()) {
            return;
        }

        // Check if Validation_Bypass__c field is updateable
        if (!Schema.SObjectType.Lead.fields.Validation_Bypass__c.isUpdateable()) {
            logDebug('User does not have permission to update Validation_Bypass__c field');
            return;
        }

        List<Lead> leadsToUpdate = new List<Lead>();
        for (Lead lead : leadsToConvert) {
            if (lead != null && lead.Id != null) {
                leadsToUpdate.add(new Lead(
                    Id = lead.Id,
                    Validation_Bypass__c = true
                ));
            }
        }

        if (!leadsToUpdate.isEmpty()) {
            // Bypass trigger handler to prevent recursive trigger execution
            // This update is only to set Validation_Bypass__c and should not trigger conversion logic
            TriggerHandler.bypass('LeadTriggerHandler');
            try {
                if (ConstantsUtil.customExceptionSwitch && Test.isRunningTest()) {
                    throw new System.DmlException('customExceptionSwitch is turned on for updateValidationBypassForLeads');
                }
                Database.update(leadsToUpdate, false, AccessLevel.USER_MODE);
            } catch (Exception e) {
                logError('Failed to update Validation_Bypass__c for leads before conversion', leadsToUpdate, e);
            } finally {
                TriggerHandler.clearBypass('LeadTriggerHandler');
            }
        }
    }

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null for permission errors)
     */
    private static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    /**
     * @description Logs debug messages using Logger framework
     * @param message The debug message
     */
    @TestVisible
    private static void logDebug(String message) {
        Logger.debug(message);
        Logger.saveLog();
    }
}