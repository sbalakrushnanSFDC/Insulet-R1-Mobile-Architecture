/**
 * @description Handler class for HealthcarePractitionerFacility insertions.
 *              Creates OrgSync_Physician_Staging__c records when new HPF records are created
 *              by mapping from the Provider Account of each HPF record (similar to after-insert
 *              flow in OrgSync_ProviderHandler.handleUpsertProviderToStaging).
 * Created Date : Jan 30, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 30, 2026        Pradip Kokate           Initial Version
 * V1.1.0       Feb 20, 2026        Pradip Kokate           Create Physician Stage from Provider Account instead of existing Physician Stage
 * V1.2.0.      Feb 25, 2026		Neeraj Kumar			Added changes for contact point updates on the HPF
 */
@SuppressWarnings('PMD.CognitiveComplexity, PMD.CyclomaticComplexity')
public with sharing class OrgSync_HandleHPFInsertion {

    private static final String TAG_NAME = 'OrgSync';
    private static final String PROVIDER_FIELD_SET = 'OrgSync_Provider_Mapping';

    /**
     * @description Main entry point for handling HPF insertions.
     *              Processes bulk HPF records and creates Physician Staging records from Provider Accounts.
     * @param newRecords List of new HealthcarePractitionerFacility records
     */
    public static void handleHPFInsertion(List<HealthcarePractitionerFacility> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }
        
         if (OrgSync_UtilityService.isOrgSyncUser()) {
            return;
        }

        try {
            // Step 1: Build processing context with Provider Account data
            ProcessingContext context = buildProcessingContext(newRecords);

            if (!context.isValid()) {
                return;
            }

            // Step 2: Create Physician Staging records from Provider Accounts
            List<OrgSync_Physician_Staging__c> physicianStagesToCreate = createPhysicianStagingRecords(
                newRecords,
                context
            );

            // Step 3: Insert Physician Staging records
            if (!physicianStagesToCreate.isEmpty()) {
                List<Database.SaveResult> results = Database.insert(physicianStagesToCreate, false, AccessLevel.SYSTEM_MODE);
                logInsertResults(results, physicianStagesToCreate);
            }

        } catch (Exception ex) {
            Logger.error('Error in handleHPFInsertion: ' + ex.getMessage(), newRecords, ex)
                .addTag(TAG_NAME);
        }
    }

    /**
     * @description Inner class to hold processing context data
     */
    private class ProcessingContext {
        Set<Id> providerContactIds;
        Set<Id> practiceAccountIds;
        Map<Id, Id> contactIdToProviderAccountIdMap;
        Map<Id, Account> providerAccountIdToAccountMap;
        Map<Id, String> providerAccountIdToNPIMap;
        List<Schema.FieldSetMember> fieldSetMembers;

        Boolean isValid() {
            return providerContactIds != null && !providerContactIds.isEmpty()
                && practiceAccountIds != null && !practiceAccountIds.isEmpty()
                && contactIdToProviderAccountIdMap != null && !contactIdToProviderAccountIdMap.isEmpty()
                && providerAccountIdToAccountMap != null && !providerAccountIdToAccountMap.isEmpty()
                && fieldSetMembers != null;
        }
    }

    /**
     * @description Builds processing context by collecting Provider Account data
     * @param hpfRecords List of HPF records
     * @return ProcessingContext containing all collected data
     */
    private static ProcessingContext buildProcessingContext(List<HealthcarePractitionerFacility> hpfRecords) {
        ProcessingContext context = new ProcessingContext();

        // Step 1: Collect Contact IDs and Practice Account IDs from HPF records
        collectHPFIds(hpfRecords, context);
        if (context.providerContactIds.isEmpty() || context.practiceAccountIds.isEmpty()) {
            return context;
        }

        // Step 2: Load field set for Provider-to-Staging mapping
        context.fieldSetMembers = OrgSync_UtilityService.getFieldSetMembers('Account', PROVIDER_FIELD_SET);

        // Step 3: Query Provider Accounts by PersonContactId with all fields needed (single SOQL)
        queryProviderAccountsByContactIds(context);
        if (context.contactIdToProviderAccountIdMap.isEmpty() || context.providerAccountIdToAccountMap.isEmpty()) {
            return context;
        }

        // Step 4: Get NPI from Identifier when Custom_UniqueID__c is blank (fallback for test/legacy data)
        context.providerAccountIdToNPIMap = OrgSync_UtilityService.getProviderNPIs(
            new Set<Id>(context.providerAccountIdToAccountMap.keySet())
        );

        return context;
    }

    /**
     * @description Collects Contact IDs and Practice Account IDs from HPF records
     * @param hpfRecords List of HPF records
     * @param context ProcessingContext to populate
     */
    private static void collectHPFIds(
        List<HealthcarePractitionerFacility> hpfRecords,
        ProcessingContext context
    ) {
        context.providerContactIds = new Set<Id>();
        context.practiceAccountIds = new Set<Id>();

        for (HealthcarePractitionerFacility hpf : hpfRecords) {
            if (hpf.PractitionerId != null && hpf.AccountId != null) {
                context.providerContactIds.add(hpf.PractitionerId);
                context.practiceAccountIds.add(hpf.AccountId);
            }
        }
    }

    /**
     * @description Queries Provider Accounts by PersonContactId with all fields needed for Physician Staging mapping.
     *              Populates contactIdToProviderAccountIdMap and providerAccountIdToAccountMap in a single SOQL.
     * @param context ProcessingContext to populate
     */
    private static void queryProviderAccountsByContactIds(ProcessingContext context) {
        context.contactIdToProviderAccountIdMap = new Map<Id, Id>();
        context.providerAccountIdToAccountMap = new Map<Id, Account>();

        if (context.providerContactIds == null || context.providerContactIds.isEmpty()) {
            return;
        }

        Set<Id> contactIds = context.providerContactIds;
        Id providerRecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT;
        Set<String> queryFields = new Set<String>{
            'Id', 'PersonContactId', 'FirstName', 'LastName', 'Custom_UniqueID__c', 'BillingStreet', 'BillingCity', 'BillingPostalCode', 'BillingStateCode'
        };

        List<Schema.FieldSetMember> fieldSetMembers = context.fieldSetMembers;
        if (fieldSetMembers != null && !fieldSetMembers.isEmpty()) {
            for (Schema.FieldSetMember fsm : fieldSetMembers) {
                String fieldPath = fsm.getFieldPath();
                if (isValidFieldPath(fieldPath)) {
                    queryFields.add(fieldPath);
                }
            }
        }

        String fieldList = String.join(new List<String>(queryFields), ', ');
        String queryString = 'SELECT ' + fieldList +
            ' FROM Account' +
            ' WHERE PersonContactId IN :contactIds' +
            ' AND PersonContactId != null' +
            ' AND RecordTypeId = :providerRecordTypeId' +
            ' WITH SYSTEM_MODE';

        for (Account acc : (List<Account>) Database.query(queryString)) { //NOPMD - Field paths from Schema metadata, validated, WHERE uses bind variables
            context.contactIdToProviderAccountIdMap.put(acc.PersonContactId, acc.Id);
            context.providerAccountIdToAccountMap.put(acc.Id, acc);
        }
    }

    /**
     * @description Validates field path contains only safe characters
     * @param fieldPath Field path to validate
     * @return Boolean true if valid, false otherwise
     */
    private static Boolean isValidFieldPath(String fieldPath) {
        if (String.isBlank(fieldPath)) {
            return false;
        }
        Pattern fieldPathPattern = Pattern.compile('[a-zA-Z0-9_.]+');
        Matcher matcher = fieldPathPattern.matcher(fieldPath);
        return matcher.matches();
    }

    /**
     * @description Creates Physician Staging records from HPF records by mapping from Provider Accounts
     * @param hpfRecords List of HPF records
     * @param context ProcessingContext containing Provider Account data
     * @return List of Physician Staging records to insert
     */
    private static List<OrgSync_Physician_Staging__c> createPhysicianStagingRecords(
        List<HealthcarePractitionerFacility> hpfRecords,
        ProcessingContext context
    ) {
        List<OrgSync_Physician_Staging__c> physicianStagesToCreate = new List<OrgSync_Physician_Staging__c>();

        for (HealthcarePractitionerFacility hpf : hpfRecords) {
            OrgSync_Physician_Staging__c newPhysicianStage = createPhysicianStageFromProviderAccount(hpf, context);
            if (newPhysicianStage != null) {
                physicianStagesToCreate.add(newPhysicianStage);
            }
        }


        return physicianStagesToCreate;
    }

    /**
     * @description Creates a single Physician Staging record from the Provider Account of an HPF record.
     *              Mirrors the logic in OrgSync_SyncPhysicianStageService.createStagingFromAccount (after-insert flow).
     * @param hpf HPF record
     * @param context ProcessingContext containing Provider Account data
     * @return Physician Staging record or null if cannot be created
     */
    private static OrgSync_Physician_Staging__c createPhysicianStageFromProviderAccount(
        HealthcarePractitionerFacility hpf,
        ProcessingContext context
    ) {
        Id providerAccountId = context.contactIdToProviderAccountIdMap.get(hpf.PractitionerId);
        if (providerAccountId == null) {
            return null;
        }

        Account providerAccount = context.providerAccountIdToAccountMap.get(providerAccountId);
        if (providerAccount == null) {
            return null;
        }

        // Create Physician Staging record from Provider Account (like OrgSync_SyncPhysicianStageService)
        OrgSync_Physician_Staging__c staging = new OrgSync_Physician_Staging__c();
        staging.Name = providerAccount.FirstName + ' ' + providerAccount.LastName;
        // Use Custom_UniqueID__c when available, else fallback to NPI from Identifier (for test/legacy data)
        String npi = String.isNotBlank(providerAccount.Custom_UniqueID__c)
            ? providerAccount.Custom_UniqueID__c
            : (context.providerAccountIdToNPIMap != null ? context.providerAccountIdToNPIMap.get(providerAccountId) : null);
        staging.OrgSync_NPI__c = npi;

        // Map fields from Provider Account using OrgSync_Provider_Mapping field set
        for (Schema.FieldSetMember fsm : context.fieldSetMembers) {
            String accFieldName = fsm.getFieldPath();
            String stagingFieldName = OrgSync_UtilityService.mapTargetToSourceField(accFieldName);
            try {
                Object fieldValue = providerAccount.get(accFieldName);
                if (fieldValue != null) {
                    staging.put(stagingFieldName, fieldValue);
                }
            } catch (Exception e) {
                Logger.error('Error mapping field ' + accFieldName + ': ' + e.getMessage())
                    .addTag(TAG_NAME);
            }
        }

        // Set HPF-specific fields: Parent Practice from HPF, Do Not Use from HPF IsActive
        // Use composite External ID (provider + practice) for uniqueness - a provider can have multiple Physician Stage records across practices
        staging.OrgSync_Parent_Practice__c = hpf.AccountId;
        staging.OrgSync_Do_Not_Use__c = !hpf.IsActive;
        staging.XCDC_ExternalId__c = buildCompositeExternalId(providerAccountId, hpf.AccountId);
        //Adding contact point fields - Phone,Email and Address on HPF creation START
        staging.OrgSync_Phone__c = providerAccount?.Phone;
        staging.OrgSync_PersonEmail__c = providerAccount?.PersonEmail;
        staging.OrgSync_Mailing_Address__Street__s = providerAccount?.BillingStreet;
        staging.OrgSync_Mailing_Address__City__s = providerAccount?.BillingCity;
        staging.OrgSync_Mailing_Address__PostalCode__s = providerAccount?.BillingPostalCode;
        staging.OrgSync_Mailing_Address__StateCode__s = providerAccount?.BillingStateCode;
        //Adding contact point fields - Phone,Email and Address on HPF creation END

        return staging;
    }

    /**
     * @description Builds composite External ID for Physician Staging (provider + practice) to ensure uniqueness per provider-practice
     * @param providerExternalId Provider Account's External ID
     * @param practiceAccountId Practice Account ID from HPF
     * @return Composite external ID string
     */
    private static String buildCompositeExternalId(String providerAccountId, Id practiceAccountId) {
        if (String.isNotBlank(providerAccountId) && practiceAccountId != null) {
            return XCDC_OrgSettings__c.getInstance().ExternalIdOrgprefix__c + XCDC_Constants.HYPHEN + providerAccountId + XCDC_Constants.HYPHEN + practiceAccountId;
        }
        return null;
    }

    /**
     * @description Logs insert results for Physician Staging records
     * @param results List of Database.SaveResult
     * @param records List of Physician Staging records that were inserted
     */
    private static void logInsertResults(
        List<Database.SaveResult> results,
        List<OrgSync_Physician_Staging__c> records
    ) {
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult result = results[i];
            OrgSync_Physician_Staging__c record = records[i];

            if (!result.isSuccess()) {
                String errorMessage = 'Failed to insert Physician Staging record';
                for (Database.Error error : result.getErrors()) {
                    errorMessage += ' - ' + error.getMessage();
                }
                Logger.error(errorMessage, record).addTag(TAG_NAME);
            }
        }
    }
}