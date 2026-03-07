/**
 * @description Generic service class for Identifier record creation and management.
 * Created Date : Dec 02, 2025
 * Created By   : Ramesh Dhaka
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Dec 16, 2025        Ramesh Dhaka            Initial Version
 */
public inherited sharing class OrgSync_IdentifierService {

    /**
     * @description Creates Identifier records for given parent records and identifier values.
     * @param parentRecordIds Map of external identifier (or key) to parent record ID
     * @param identifierValues Map of external identifier (or key) to identifier value
     * @param idUsageType Usage type for the identifier (default: 'Official')
     */
    public void createIdentifiers(Map<String, Id> parentRecordIds, Map<String, String> identifierValues, String idUsageType) {
        if (parentRecordIds == null || parentRecordIds.isEmpty() || identifierValues == null || identifierValues.isEmpty()) {
            return;
        }

        String usageType = String.isNotBlank(idUsageType) ? idUsageType : 'Official';
        List<SObject> identifiersToInsert = buildIdentifierList(parentRecordIds, identifierValues, usageType);

        if (!identifiersToInsert.isEmpty()) {
            insertIdentifiers(identifiersToInsert);
        }
    }

    /**
     * @description Builds the Identifier list for the given parent records and identifier values.
     * @param parentRecordIds Map of key (external identifier or generated key) to parent record ID
     * @param identifierValues Map of key (external identifier or generated key) to identifier value
     * @param idUsageType Usage type for the identifier
     * @return List<SObject> List of Identifier records to insert
     */
    private List<SObject> buildIdentifierList(Map<String, Id> parentRecordIds, Map<String, String> identifierValues, String idUsageType) {
        List<SObject> identifiersToInsert = new List<SObject>();
        for (String key : parentRecordIds.keySet()) {
            Id parentId = parentRecordIds.get(key);
            String idValue = identifierValues.get(key);
            if (parentId != null && String.isNotBlank(idValue)) {
                try {
                    Identifier ident = new Identifier();
                    ident.put('IdUsageType', idUsageType);
                    ident.put('ParentRecordId', parentId);
                    ident.put('ID_Value__c', idValue);
                    identifiersToInsert.add(ident);
                } catch (Exception e) {
                    Logger.error('OrgSync_IdentifierService: buildIdentifierList: Error populating Identifier: ' + e.getMessage()).addTag('OrgSync');
                }
            }
        }
        return identifiersToInsert;
    }

    /**
     * @description Inserts the Identifier records.
     * @param identifiersToInsert List of Identifier records to insert
     */
    private void insertIdentifiers(List<SObject> identifiersToInsert) {
        List<Database.SaveResult> results = Database.insert(identifiersToInsert, false, AccessLevel.SYSTEM_MODE);
        OrgSync_LoggingUtility.handleDatabaseResults(results, identifiersToInsert, new Map<String, String>{
            'className' => 'OrgSync_IdentifierService',
            'methodName' => 'insertIdentifiers',
            'operationDescription' => 'inserting Identifier'
        });
    }
}