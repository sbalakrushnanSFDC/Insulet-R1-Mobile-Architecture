/**
 * @description Helper class for CCR DML operations
 * Created Date : Jan 19, 2026
 * Created By   : Pradip Kokate
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Jan 19, 2026        Pradip Kokate      Initial Version
 */
public with sharing class OrgSync_CCRDMLHelper {

    private static final String TAG_NAME = 'OrgSync';

    /**
     * @description Inserts CCR records with error handling
     * @param ccrToInsert List of CCR records to insert
     */
    public static void insertCCRs(List<ContactContactRelation> ccrToInsert) {
        if (ccrToInsert.isEmpty()) {
            return;
        }
        Database.SaveResult[] results = Database.insert(ccrToInsert, false);

    }

    /**
     * @description Updates CCR records with error handling
     * @param ccrToUpdate List of CCR records to update
     */
    public static void updateCCRs(List<ContactContactRelation> ccrToUpdate) {
        if (ccrToUpdate.isEmpty()) {
            return;
        }

        Database.SaveResult[] results = Database.update(ccrToUpdate, false);
    }
}