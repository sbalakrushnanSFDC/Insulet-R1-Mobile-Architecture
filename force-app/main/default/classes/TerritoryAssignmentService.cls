/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 4th Nov 2025
 * @description : Service class to handle territory assignment based on postal codes.
 *                Processes Practice Accounts and Patient Leads.
 * NOTE -System Mode  : DML and SOQL operations are executed for non-admin users who do not have access to Territory fields. 
 *                      To allow these operations for non-admin users, they must be executed in system context.
 * 
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       4th Nov 2025        Bijayalaxmi Prusty      Initial Version (US - NGASIM-622)
 * V1.0.1       19th Nov 2025       Srinivas Shanigarapu    Updated(US - NGOMCT-469)
 * V1.0.2       29th Dec 2025       Srinivas Shanigarapu    Updated(US - NGOMCT-235)
 * V1.0.3		16th JAN 2026		Shashank Nigam			Updated(US - NGOMCT-1719) Removed assignExternalTrainerTerritoryToLeads
 */
public inherited sharing class TerritoryAssignmentService {
  @TestVisible
  private static boolean isExceptionThrown = false;

  // Track Contact IDs that have a primary trainer relationship to avoid SOQL in loops
  @TestVisible
  private static Set<Id> contactsWithPrimaryTrainerSet = new Set<Id>();

  /**
   * @description Processes Account records to assign territory based on billing postal code
   * @param accountRecords List of Account records to process
   * @param oldAccountRecords Map of old Account records
   */
  public static void assignTerritoryToAccounts(
    List<Account> accountRecords,
    Map<Id, Account> oldAccountRecords
  ) {
    processTerritoryAssignment(
      accountRecords,
      oldAccountRecords,
      Account.SObjectType
    );
  }

  /**
   * @description Processes Lead records to assign territory based on postal code
   * @param leadRecords List of Lead records to process
   * @param oldLeadRecords Map of old Lead records
   */
  public static void assignTerritoryToLeads(
    List<Lead> leadRecords,
    Map<Id, Lead> oldLeadRecords
  ) {
    processTerritoryAssignment(leadRecords, oldLeadRecords, Lead.SObjectType);
  }

  /**
   * @description Common method to process territory assignment for any SObject type
   * @param records List of SObject records to process
   * @param oldRecordsMap Map of old SObject records
   * @param objectType String indicating the object type
   */
  private static void processTerritoryAssignment(
    List<SObject> records,
    Map<Id, SObject> oldRecordsMap,
    Schema.SObjectType objectType
  ) {
    if (records == null || records.isEmpty()) {
      return;
    }

    try {
      List<SObject> eligibleRecords = filterEligibleRecords(
        records,
        oldRecordsMap,
        objectType
      );

      if (eligibleRecords.isEmpty()) {
        return;
      }

      Set<String> postalCodes = extractPostalCodes(eligibleRecords, objectType);
      Map<String, String> zipTerritoryMap = getZipCodeTerritoryMapping(
        postalCodes
      );

      assignTerritoryToRecords(eligibleRecords, zipTerritoryMap, objectType);
    } catch (Exception ex) {
      Logger.error(
          'Failed to assign territory to ' + objectType + ' records',
          records
        )
        .addTag(ConstantsUtil.ASIM_TAG);
      Logger.saveLog();
    }
  }

  /**
   * @description Filters records that are eligible for territory assignment based on object type
   * @param records List of SObject records to filter
   * @param oldRecordsMap Map of old SObject records
   * @param objectType String indicating the object type
   * @return List of eligible SObject records
   */
  private static List<SObject> filterEligibleRecords(
    List<SObject> records,
    Map<Id, SObject> oldRecordsMap,
    Schema.SObjectType objectType
  ) {
    List<SObject> eligibleRecords = new List<SObject>();

    // Logic to Bulkify ACR check: Pre-populate the primary trainer set if processing Accounts
    if (objectType == Account.SObjectType) {
      prepareTrainerEligibility(records);
    }

    for (SObject record : records) {
      String postalCode = getPostalCodeFromRecord(record, objectType);

      // Check if postal code is not null or empty
      if (String.isBlank(postalCode)) {
        continue;
      }

      // Check record type conditions based on object type
      if (!isRecordEligible(record, objectType)) {
        continue;
      }

      // For updates, only process if postal code has changed
      // For inserts, oldRecordsMap is null so all eligible records are processed
      if (oldRecordsMap != null) {
        SObject oldRecord = oldRecordsMap.get(record.Id);
        if (oldRecord != null) {
          String oldPostalCode = getPostalCodeFromRecord(oldRecord, objectType);
          // Skip if postal code hasn't changed
          if (postalCode == oldPostalCode) {
            continue;
          }
        }
      }

      eligibleRecords.add(record);
    }

    return eligibleRecords;
  }

  /**
   * @description Checks if a record is eligible for territory assignment based on business rules
   * @param record SObject record to check
   * @param objectType String indicating the object type
   * @return Boolean indicating if record is eligible
   */
  @TestVisible
  private static Boolean isRecordEligible(
    SObject record,
    Schema.SObjectType objectType
  ) {
    if (objectType == Account.SObjectType) {
      Account acc = (Account) record;
      // Check record type condition: Practice only
      if (acc.RecordTypeId == ConstantsUtil.ACCOUNT_PRACTICE_RT) {
        return true;
      } else if (acc.RecordTypeId == ConstantsUtil.ACCOUNT_TRAINER_RT) {
        return !contactsWithPrimaryTrainerSet.contains(acc.PersonContactId); 
      }
    } else if (objectType == Lead.SObjectType) {
      Lead ld = (Lead) record;
      // Check record type condition: Patient only
      return ld.RecordTypeId == ConstantsUtil.LEAD_PATIENT_RT;
    }
    return false;
  }

  /**
   * @description Helper to bulk-query primary AccountContactRelations to avoid SOQL in loops
   * @param records List of SObject records
   */
  @TestVisible
  private static void prepareTrainerEligibility(List<SObject> records) {
    Set<Id> contactIds = new Set<Id>();
    for (SObject record : records) {
      Account acc = (Account) record;
      if (
        acc.RecordTypeId == ConstantsUtil.ACCOUNT_TRAINER_RT &&
        acc.PersonContactId != null
      ) {
        contactIds.add(acc.PersonContactId);
      }
    }
      if(contactIds.isEmpty()){
          return;
      }

      for (AccountContactRelation acr : [
        SELECT ContactId
        FROM AccountContactRelation
        WHERE
          ContactId IN :contactIds
          AND Roles = :ConstantsUtil.ACR_ROLE_TRAINER
          AND Is_Primary__c = TRUE
        WITH SYSTEM_MODE
      ]) {
        contactsWithPrimaryTrainerSet.add(acr.ContactId);
      }
  }

  /**
   * @description Gets postal code from record based on object type
   * @param record SObject record
   * @param objectType String indicating the object type
   * @return String postal code value
   */
  @TestVisible
  private static String getPostalCodeFromRecord(
    SObject record,
    Schema.SObjectType objectType
  ) {
    if (objectType == Account.SObjectType) {
      return (String) record.get(ConstantsUtil.ACCOUNT_BILLING_POSTAL_CODE);
    } else if (objectType == Lead.SObjectType) {
      return (String) record.get(ConstantsUtil.LEAD_POSTAL_CODE);
    }
    return null;
  }

  /**
   * @description Extracts postal codes from SObject records based on object type
   * @param records List of SObject records
   * @param objectType String indicating the object type
   * @return Set of postal codes
   */
  private static Set<String> extractPostalCodes(
    List<SObject> records,
    Schema.SObjectType objectType
  ) {
    Set<String> postalCodes = new Set<String>();

    for (SObject record : records) {
      String postalCode = getPostalCodeFromRecord(record, objectType);
      if (String.isNotBlank(postalCode)) {
        postalCodes.add(postalCode);
      }
    }

    return postalCodes;
  }

  /**
   * @description Queries ZipCode__c records to get territory mapping for given postal codes
   * @param postalCodes Set of postal codes to query
   * @return Map of postal code to territory name
   */
  @TestVisible
  private static Map<String, String> getZipCodeTerritoryMapping(
    Set<String> postalCodes
  ) {
    Map<String, String> zipTerritoryMap = new Map<String, String>();

    if (postalCodes == null || postalCodes.isEmpty()) {
      return zipTerritoryMap;
    }

    // Query for postal codes
    List<ZipCode__c> zipCodeRecords = Database.query(
      'SELECT Name, Territory_Name__r.Territory_Developer_Name__c ' +
        'FROM ZipCode__c ' +
        'WHERE Name IN :postalCodes ' +
        'AND Territory_Name__r.Territory_Developer_Name__c != null',
      AccessLevel.SYSTEM_MODE
    );

    for (ZipCode__c zipCode : zipCodeRecords) {
      String territoryName = zipCode.Territory_Name__r.Territory_Developer_Name__c;
      zipTerritoryMap.put(zipCode.Name, territoryName);
    }

    return zipTerritoryMap;
  }

  /**
   * @description Assigns territory to SObject records based on zip code mapping
   * @param records List of SObject records to update
   * @param zipTerritoryMap Map of postal code to territory name
   * @param objectType String indicating the object type
   */
  @TestVisible
  private static void assignTerritoryToRecords(
    List<SObject> records,
    Map<String, String> zipTerritoryMap,
    Schema.SObjectType objectType
  ) {
    for (SObject record : records) {
      try {
        String territoryFieldName = (objectType == Account.SObjectType)
          ? ConstantsUtil.ACCOUNT_TERRITORY_ALIAS
          : ConstantsUtil.LEAD_TERRITORY_ALIAS;

        // Special handling for Practice accounts with Pediatrics specialty
        if (objectType == Account.SObjectType) {
          Account acc = (Account) record;
          String specialty = (String) acc.get(ConstantsUtil.ACCOUNT_SPECIALTY);

          // Set TerritoryAlias__c to blank for Practice accounts with Pediatrics specialty
          if (
            acc.RecordTypeId == ConstantsUtil.ACCOUNT_PRACTICE_RT &&
            ConstantsUtil.EXCLUDED_SPECIALTIES.contains(specialty)
          ) {
            record.put(territoryFieldName, null);
            continue;
          }
        }

        // Normal territory assignment logic for other records
        String postalCode = getPostalCodeFromRecord(record, objectType);
        String territoryName = zipTerritoryMap.get(postalCode);

        if (String.isNotBlank(territoryName)) {
          record.put(territoryFieldName, territoryName);
        } else {
          // Clear territory alias if no mapping found for postal code
          record.put(territoryFieldName, null);
        }
      } catch (SObjectException ex) {
        Logger.error(
            'Failed to assign territory to record: ' + record.Id,
            new List<SObject>{ record },
            ex
          )
          .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();   
      }
    }
  }
}