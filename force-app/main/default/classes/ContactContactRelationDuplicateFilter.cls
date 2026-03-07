/**
 * @description Utility class for filtering duplicate ContactContactRelation records
 * Created Date : Feb 12, 2026
 * Created By   : Charchit N.
 */
public inherited sharing class ContactContactRelationDuplicateFilter {

    /**
     * @description Filters out duplicate ContactContactRelation records
     * Checks for duplicates both within the batch and against existing records in the database
     * ContactContactRelation has a unique constraint on ContactId + RelatedContactId combination
     * @param ccrRecords List of ContactContactRelation records to filter
     * @return List of ContactContactRelation records with duplicates removed
     */
    public static List<ContactContactRelation> filterDuplicateCCRs(List<ContactContactRelation> ccrRecords) {
        if (ccrRecords == null || ccrRecords.isEmpty()) {
            return new List<ContactContactRelation>();
        }

        BatchDuplicateContext batchContext = removeBatchDuplicates(ccrRecords);
        if (batchContext.ccrKeyToRecordMap.isEmpty()) {return new List<ContactContactRelation>();
        }

        Set<String> existingCCRKeys = queryExistingCCRKeys(batchContext.contactIds, batchContext.relatedContactIds);
        return filterExistingRecords(batchContext.ccrKeyToRecordMap, existingCCRKeys);
    }

    /**
     * @description Removes duplicates within the batch and collects contact IDs
     * @param ccrRecords List of ContactContactRelation records
     * @return BatchDuplicateContext containing the map of unique records and contact ID sets
     */
    private static BatchDuplicateContext removeBatchDuplicates(List<ContactContactRelation> ccrRecords) {
        BatchDuplicateContext context = new BatchDuplicateContext();

        for (ContactContactRelation ccr : ccrRecords) {
            if (ccr.ContactId == null || ccr.RelatedContactId == null) {continue;
            }

            context.contactIds.add(ccr.ContactId);
            context.relatedContactIds
                .add(ccr.RelatedContactId);

            String ccrKey = buildCCRKey(ccr.ContactId, ccr.RelatedContactId);
            if (!context.ccrKeyToRecordMap.containsKey(ccrKey)) {
                context.ccrKeyToRecordMap
                    .put(ccrKey, ccr);
            }
        }

        return context;
    }

    /**
     * @description Builds a unique key for ContactContactRelation from ContactId and RelatedContactId
     * @param contactId Contact ID
     * @param relatedContactId Related Contact ID
     * @return Unique key string
     */
    private static String buildCCRKey(Id contactId, Id relatedContactId) {
        return String.valueOf(contactId) + '_' + String.valueOf(relatedContactId);
    }

    /**
     * @description Queries existing ContactContactRelation records and returns their keys
     * @param contactIds Set of Contact IDs
     * @param relatedContactIds Set of Related Contact IDs
     * @return Set of existing CCR keys
     */
    private static Set<String> queryExistingCCRKeys(Set<Id> contactIds, Set<Id> relatedContactIds) {
        Set<String> existingCCRKeys = new Set<String>();

        if (contactIds.isEmpty() || relatedContactIds.isEmpty()) {return existingCCRKeys;
        }

        for (ContactContactRelation existingCCR : [
            SELECT ContactId, RelatedContactId
            FROM ContactContactRelation
            WHERE ContactId IN :contactIds
            AND RelatedContactId IN :relatedContactIds WITH SYSTEM_MODE])
        {
            String existingKey = buildCCRKey(existingCCR.ContactId, existingCCR.RelatedContactId);
            existingCCRKeys.add(existingKey);
        }

        return existingCCRKeys;
    }

    /**
     * @description Filters out records that already exist in the database
     * @param ccrKeyToRecordMap Map of CCR keys to records
     * @param existingCCRKeys Set of existing CCR keys
     * @return List of filtered ContactContactRelation records
     */
    private static List<ContactContactRelation> filterExistingRecords(
        Map<String, ContactContactRelation> ccrKeyToRecordMap,
        Set<String> existingCCRKeys
    ) {
        List<ContactContactRelation> filteredRecords = new List<ContactContactRelation>();
        for (String ccrKey : ccrKeyToRecordMap.keySet()) {
            if (!existingCCRKeys.contains(ccrKey)) {
                filteredRecords.add(ccrKeyToRecordMap.get(ccrKey));
            }
        }
        return filteredRecords;
    }

    /**
     * @description Inner class to hold batch duplicate context data
     */
    private class BatchDuplicateContext {
        public Set<Id> contactIds;
        public Set<Id> relatedContactIds;
        public Map<String, ContactContactRelation> ccrKeyToRecordMap;

        /**
         * @description Constructor that initializes empty collections
         */
        public BatchDuplicateContext() {
            this.contactIds = new Set<Id>();
            this.relatedContactIds = new Set<Id>();
            this.ccrKeyToRecordMap = new Map<String, ContactContactRelation>();
        }
    }
}