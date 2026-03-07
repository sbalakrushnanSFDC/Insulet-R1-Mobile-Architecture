/**
 * @author      : Charchit Nirayanwal
 * @created Date: 13 NOV 2025
 * @description : Class to create ObjectTerritory2Association records.
 * NOTE -System Mode  : DML and SOQL operations are executed for non-admin users who do not have access to Territory fields. 
 *                      To allow these operations for non-admin users, they must be executed in system context.
 *
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       13 NOV 2025         Charchit Nirayanwal     Initial Version (US-1223)
 * V1.0.1       6  JAN 2026         Srinivas Shanigarapu    Modified Version (NGOMCT-235)
 */
public inherited sharing class ObjectTerritory2AService {
  public static final String ACTIVE = 'Active';
  public static final String ERROR_TAG_NAME = 'ObjectTerritory2AService';
  public static final String ASSOCIATION_CAUSE = 'Territory2Manual';
  public static final String VALUE = 'value';
  public static final String LABEL = 'label';
  public static final String RECORDTYPE_ID = 'recordTypeId';

  /**
   * @description Create ObjectTerritory2Association Record on Lead creation and territory.
   * @param newRecords List of SObject records to update
   * @param oldRecordsMap List of Old SObject records
   * @param objectType String indicating the object type
   */
  public static void createOT2ARecords(
    List<SObject> newRecords,
    Map<Id, SObject> oldRecordsMap,
    Schema.SObjectType objectType
  ) {
    List<SObject> eligibleRecords = new List<SObject>();
    try {
     
      eligibleRecords = filterRecords(newRecords, oldRecordsMap, objectType);  

      Map<string, Id> territoryNameIdMap = getTerritoryNameIdMap(
        eligibleRecords,
        objectType
      );
      List<ObjectTerritory2Association> oT2AList = new List<ObjectTerritory2Association>();
      Set<Id> recordIds = new Set<Id>();
      for (SObject record : eligibleRecords) {
        String territoryName = getTerritoryFromRecord(record, objectType);
        recordIds.add(record.Id);
        if (
          territoryName != null ||
          territoryNameIdMap.get(territoryName) != null
        ) {
          oT2AList.add(
            new ObjectTerritory2Association(
              Territory2Id = territoryNameIdMap.get(territoryName),
              ObjectId = (Id) record.get(ConstantsUtil.ID),
              AssociationCause = ConstantsUtil.TERRITORY2_MANUAL_AC
            )
          );
        }
      }
      if (!recordIds.isEmpty()) {
        Database.DeleteResult[] saveDeleteResults = Database.delete(
          [
            SELECT Id
            FROM ObjectTerritory2Association
            WHERE
              SObjectType = :String.valueOf(objectType)
              AND ObjectId IN :recordIds
            WITH SYSTEM_MODE
          ]
        );
        logger.error(
          'Failed to delete existing ObjectTerritory2Association Records',
          saveDeleteResults
        );
        if (oT2AList != null && !oT2AList.isEmpty()) {
          Database.SaveResult[] saveResults = Database.insert(
            oT2AList,
            false,
            AccessLevel.SYSTEM_MODE
          );
          logger.error(
            'Failed to create existing ObjectTerritory2Association Records',
            saveResults
          );
        }
      }
    } catch (exception e) {
      Logger.error(
          'Failed to create ObjectTerritory2Association Records',
          eligibleRecords,
          e
        )
        .addTag(ConstantsUtil.ASIM_TAG);
      Logger.saveLog();
    }
  }

  /**
   * @description filter records where territory is changed
   * @param newRecords List of SObject records to update
   * @param oldRecordMap Map of Old SObject records
   * @param objectType String indicating the object type
   * @return List of eligible SObject records
   */
  public static List<SObject> filterRecords(
    List<SObject> newRecords,
    Map<Id, SObject> oldRecordMap,
    SobjectType objectType
  ) {
    List<SObject> eligibleRecords = new List<SObject>();
    for (SObject record : newRecords) {
      if (record.get(RECORDTYPE_ID) == ConstantsUtil.LEAD_PATIENT_RT) {
        if (oldRecordMap!= null && !oldRecordMap.isEmpty()) {
          String oldTerritoryAlias = getTerritoryFromRecord(
            oldRecordMap.get(record.Id),
            objectType
          );
          String newTerritoryAlias = getTerritoryFromRecord(record, objectType);
          if (oldTerritoryAlias != newTerritoryAlias) {
            eligibleRecords.add(record);
            continue;
          }
        }
        eligibleRecords.add(record);
      }
    }
    return eligibleRecords;
  }
  /**
   * @description Get Territory Value for the Record
   * @param record Record to get Territory Value
   * @param objectType String indicating the object type
   * @return String Territory Value
   */
  private static String getTerritoryFromRecord(
    SObject record,
    Schema.SObjectType objectType
  ) {
    if (objectType == Lead.SObjectType) {
      return (String) record.get(ConstantsUtil.LEAD_TERRITORY_ALIAS);
    }
    return null;
  }

  /**
   * @description Get List of Territory Names from Records
   * @param records List of SObject records
   * @param objectType String indicating the object type
   * @return List<String> List of Territory Names
   */
  private static map<string, Id> getTerritoryNameIdMap(
    List<SObject> records,
    Schema.SObjectType objectType
  ) {
    Set<String> territoryNameList = new Set<String>();
    for (SObject record : records) {
      String territoryName = getTerritoryFromRecord(record, objectType);
      if (territoryName != null) {
        territoryNameList.add(territoryName);
      }
    }

    List<Territory2> territoryList = new List<Territory2>();
    if (territoryNameList != null && !territoryNameList.isEmpty()) {
      territoryList = [
        SELECT Id, Name, DeveloperName
        FROM Territory2
        WHERE DeveloperName IN :territoryNameList
        WITH SECURITY_ENFORCED
      ];
    }
    map<string, Id> territoryNameIdMap = new Map<string, Id>();
    for (Territory2 territory : territoryList) {
      territoryNameIdMap.put(territory.DeveloperName, territory.Id);
    }
    return territoryNameIdMap;
  }

  /**
   * @description
   * Retrieves the lowest-level (leaf) territories based on the provided search term.
   * This method queries active Territory2 records that do not have child territories
   * and returns a simplified list containing territory Id and Name, formatted for
   * typeahead or lookup-style UI components.
   *
   * @param searchTerm
   *        The text used to search territory names. Matching is performed using
   *        a case-insensitive partial search.
   *
   * @return
   *         A list of maps where each entry contains:
   *         - 'territoryId' : The Id of the territory
   *         - 'territoryName' : The Name of the territory
   *
   * @cacheable true
   *        Indicates that the method supports client-side caching for improved
   *        performance in Lightning components.
   */

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getLowestLevelTerritories(
    String searchTerm
  ) {
    List<Map<String, String>> options = new List<Map<String, String>>();
    try {
      String searchKey =
        '%' +
        (String.isBlank(searchTerm) ? '' : searchTerm) +
        '%';

      // Identify all IDs that act as parents to filter them out
      Set<Id> parentTerritoryIds = new Set<Id>();
         if(Test.isRunningTest() && ConstantsUtil.customExceptionSwitch == true){
              parentTerritoryIds = null;
          }
      for (Territory2 territory : [
        SELECT ParentTerritory2Id
        FROM Territory2
        WHERE Territory2Model.State = :ACTIVE AND ParentTerritory2Id != NULL
        WITH SYSTEM_MODE
      ]) {

        parentTerritoryIds.add(territory.ParentTerritory2Id);
      }

      // Query territories matching search that are NOT parents
      List<Territory2> lowestLevelTerritories = [
        SELECT Id, Name
        FROM Territory2
        WHERE
          Territory2Model.State = :ACTIVE
          AND Name LIKE :searchKey
          AND Id NOT IN :parentTerritoryIds
        WITH SYSTEM_MODE
      ];

      // Format results for the LWC
      for (Territory2 territory : lowestLevelTerritories) {
        options.add(
          new Map<String, String>{
            VALUE => territory.Id,
            LABEL => territory.Name
          }
        );
      }
    } catch (Exception e) {
      Logger.error(
          'An error occurred while retrieving territory records:' +
          e.getMessage()
        )
        .addTag(ERROR_TAG_NAME);
      Logger.saveLog();
      throw new AuraHandledException(
        'An error occurred while retrieving territory records: ' +
        e.getMessage()
      );
    }
    return options;
  }

  /**
   * @description Creates manual ObjectTerritory2Association records for the given record and
   * selected territories. Before inserting, the method validates existing
   * associations to prevent duplicate ObjectId and Territory2Id combinations.
   * Only new, non-existing associations are inserted.
   *
   * @param recordId
   *        The Id of the record to which territories need to be assigned.
   *
   * @param territoryIds
   *        A list of Territory2 Ids selected for manual association.
   *
   */
  @AuraEnabled
  public static void createAssociations(Id recordId, List<Id> territoryIds) {
    if (recordId == null || territoryIds == null || territoryIds.isEmpty()) {
      return;
    }
    try {
      //Query existing associations for this record and given territories
      Set<Id> territoryIdSet = new Set<Id>(territoryIds);
      Map<Id, ObjectTerritory2Association> existingTerritoryMap = new Map<Id, ObjectTerritory2Association>();
      for (ObjectTerritory2Association ota : [
        SELECT Id, Territory2Id
        FROM ObjectTerritory2Association
        WHERE ObjectId = :recordId AND Territory2Id IN :territoryIdSet
        WITH SYSTEM_MODE
      ]) {
        existingTerritoryMap.put(ota.Territory2Id, ota);
      }

         if(Test.isRunningTest() && ConstantsUtil.customExceptionSwitch == true){
              existingTerritoryMap = null;
          }
      // Prepare only NEW associations (remove existing combinations)
      List<ObjectTerritory2Association> associationsToInsert = new List<ObjectTerritory2Association>();
      for (Id territoryId : territoryIdSet) {
        if (!existingTerritoryMap.containsKey(territoryId)) {
          associationsToInsert.add(
            new ObjectTerritory2Association(
              ObjectId = recordId,
              Territory2Id = territoryId,
              AssociationCause = ASSOCIATION_CAUSE
            )
          );
        }
      }

      //Insert new associations
      if (!associationsToInsert.isEmpty()) {
        Database.insert(associationsToInsert, AccessLevel.SYSTEM_MODE);
      }
    } catch (Exception e) {
      Logger.error(
          'An error occurred while assigning territory records: ' +
          e.getMessage()
        )
        .addTag(ERROR_TAG_NAME);
      Logger.saveLog();
      throw new AuraHandledException(
        'An error occurred while assigning territory records: ' + e.getMessage()
      );
    }
  }
}