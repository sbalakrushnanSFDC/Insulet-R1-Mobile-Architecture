/**
 * @description Service class for ContactPointEmail business logic.
 *              Handles complex primary email processing logic for after insert/update events.
 * Created Date : Dec 2025
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Feb 2026       Charchit N.           Initial Version (NGASIM-2207)
 * V2.0.0       20th Feb 2026       Ayush Shrivastava     Updated the logic to handle email changes (NGASIM-2575)
 */
public with sharing class ContactPointEmailService {

    /**
     * @description Handles primary ContactPointEmail logic from flow.
     *              Sets IsPrimary to true for new records, sets others to false, and updates Account.PersonEmail
     * @param emailRecords List of ContactPointEmail records
     * @param newRecordsMap Map of new records
     * @param oldRecordsMap Map of old records
     */
    public static void handlePrimaryContactPointEmail(List<ContactPointEmail> emailRecords, Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        ProcessingContext context = identifyEmailsToProcess(emailRecords, oldRecordsMap);
        if (context.parentAccountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> parentAccountsMap = queryParentAccounts(context.parentAccountIds);
        Map<Id, List<ContactPointEmail>> parentIdToOtherEmailsMap = queryOtherPrimaryEmails(context.parentAccountIds, context.currentEmailIds);

        ProcessingDataContext dataContext = new ProcessingDataContext();
        dataContext.emailsToProcessMap = context.emailsToProcessMap;
        dataContext.parentAccountsMap = parentAccountsMap;
        dataContext.parentIdToOtherEmailsMap = parentIdToOtherEmailsMap;
        dataContext.oldRecordsMap = oldRecordsMap;
        dataContext.emailsToUpdate = new List<ContactPointEmail>();
        dataContext.accountsToUpdate = new List<Account>();

        processEmailRecords(dataContext);

        performDMLUpdates(dataContext.emailsToUpdate, dataContext.accountsToUpdate);
    }

    /**
     * @description Inner class to hold processing context
     */
    private class ProcessingContext {
        public Set<Id> parentAccountIds;
        public Set<Id> currentEmailIds;
        public Map<Id, ContactPointEmail> emailsToProcessMap;

        /**
         * @description Constructor that initializes empty collections for processing context
         */
        public ProcessingContext() {
            this.parentAccountIds = new Set<Id>();
            this.currentEmailIds = new Set<Id>();
            this.emailsToProcessMap = new Map<Id, ContactPointEmail>();
        }
    }

    /**
     * @description Inner class to hold processing data context for email records processing
     */
    private class ProcessingDataContext {
        public Map<Id, ContactPointEmail> emailsToProcessMap;
        public Map<Id, Account> parentAccountsMap;
        public Map<Id, List<ContactPointEmail>> parentIdToOtherEmailsMap;
        public Map<Id, SObject> oldRecordsMap;
        public List<ContactPointEmail> emailsToUpdate;
        public List<Account> accountsToUpdate;
    }

    /**
     * @description Identifies emails that need processing and collects parent account IDs
     * @param emailRecords List of ContactPointEmail records
     * @param oldRecordsMap Map of old records
     * @return ProcessingContext with emails to process and account IDs
     */
    private static ProcessingContext identifyEmailsToProcess(List<ContactPointEmail> emailRecords, Map<Id, SObject> oldRecordsMap) {
        ProcessingContext context = new ProcessingContext();

        for (ContactPointEmail email : emailRecords) {
            if (email.ParentId == null) {
                continue;
            }

            if (shouldProcessEmail(email, oldRecordsMap)) {
                context.parentAccountIds.add(email.ParentId);
                context.currentEmailIds.add(email.Id);
                context.emailsToProcessMap.put(email.Id, email);
            }
        }

        return context;
    }

    /**
     * @description Determines if an email should be processed
     * @param email ContactPointEmail record
     * @param oldRecordsMap Map of old records
     * @return Boolean indicating if email should be processed
     */
    private static Boolean shouldProcessEmail(ContactPointEmail email, Map<Id, SObject> oldRecordsMap) {
        Boolean isNew = (oldRecordsMap == null || !oldRecordsMap.containsKey(email.Id));

        if (isNew && email.IsPrimary == true) {
            return true;
        }

        if (!isNew && oldRecordsMap.containsKey(email.Id)) {
            ContactPointEmail oldEmail = (ContactPointEmail)oldRecordsMap.get(email.Id);
            Boolean isPrimaryChanged = (email.IsPrimary != oldEmail.IsPrimary);
            Boolean wasPrimary = (oldEmail.IsPrimary == true);

            if (isPrimaryChanged && email.IsPrimary == true && !wasPrimary) {
                return true;

            }else if(email.EmailAddress != oldEmail.EmailAddress && email.IsPrimary == true){
                return true;
            }
            
        }

        return false;
    }

    /**
     * @description Queries parent accounts in batch
     * @param parentAccountIds Set of parent account IDs
     * @return Map of Account ID to Account record
     */
    private static Map<Id, Account> queryParentAccounts(Set<Id> parentAccountIds) {
        Map<Id, Account> parentAccountsMap = new Map<Id, Account>();
        for (Account acc : [
            SELECT Id, PersonEmail
            FROM Account
            WHERE Id IN :parentAccountIds
            WITH USER_MODE
        ]) {
            parentAccountsMap.put(acc.Id, acc);
        }
        return parentAccountsMap;
    }

    /**
     * @description Queries other primary ContactPointEmail records for parent accounts
     * @param parentAccountIds Set of parent account IDs
     * @param currentEmailIds Set of current email IDs to exclude
     * @return Map of Parent ID to List of other primary ContactPointEmail records
     */
    private static Map<Id, List<ContactPointEmail>> queryOtherPrimaryEmails(Set<Id> parentAccountIds, Set<Id> currentEmailIds) {
        Map<Id, List<ContactPointEmail>> parentIdToOtherEmailsMap = new Map<Id, List<ContactPointEmail>>();
        for (ContactPointEmail otherEmail : [
            SELECT Id, IsPrimary, ParentId
            FROM ContactPointEmail
            WHERE ParentId IN :parentAccountIds
            AND Id NOT IN :currentEmailIds
            AND IsPrimary = true
            WITH USER_MODE
        ]) {
            if (!parentIdToOtherEmailsMap.containsKey(otherEmail.ParentId)) {
                parentIdToOtherEmailsMap.put(otherEmail.ParentId, new List<ContactPointEmail>());
            }
            parentIdToOtherEmailsMap.get(otherEmail.ParentId).add(otherEmail);
        }
        return parentIdToOtherEmailsMap;
    }

    /**
     * @description Processes email records and updates emails and accounts
     * @param dataContext ProcessingDataContext containing all necessary data for processing
     */
    private static void processEmailRecords(ProcessingDataContext dataContext) {
        for (ContactPointEmail email : dataContext.emailsToProcessMap.values()) {
            if (email.ParentId == null || !dataContext.parentAccountsMap.containsKey(email.ParentId)) {
                continue;
            }

            Account parentAccount = dataContext.parentAccountsMap.get(email.ParentId);
            Boolean isNew = (dataContext.oldRecordsMap == null || !dataContext.oldRecordsMap.containsKey(email.Id));
            Boolean wasPrimary = getWasPrimary(email, dataContext.oldRecordsMap);
			
            ContactPointEmail oldEmail = (ContactPointEmail)dataContext?.oldRecordsMap?.get(email.Id);
            
            if (isPrimaryOnCreateOrUpdate(email, isNew, wasPrimary)) {
                updateOtherEmailsToNonPrimary(email.ParentId, dataContext.parentIdToOtherEmailsMap, dataContext.emailsToUpdate);
                updateAccountPersonEmail(email, parentAccount, dataContext.accountsToUpdate);
            }else if(oldEmail !=null && oldEmail.EmailAddress != email.EmailAddress && email.IsPrimary == true && email.ParentId != null){
                updateAccountPersonEmail(email, parentAccount, dataContext.accountsToUpdate);
            }
        }
    }

    /**
     * @description Gets whether the email was primary before
     * @param email ContactPointEmail record
     * @param oldRecordsMap Map of old records
     * @return Boolean indicating if email was primary
     */
    private static Boolean getWasPrimary(ContactPointEmail email, Map<Id, SObject> oldRecordsMap) {
        if (oldRecordsMap != null && oldRecordsMap.containsKey(email.Id)) {
            ContactPointEmail oldEmail = (ContactPointEmail)oldRecordsMap.get(email.Id);
            return (oldEmail.IsPrimary == true);
        }
        return false;
    }

    /**
     * @description Determines if email is primary on create or update
     * @param email ContactPointEmail record
     * @param isNew Boolean indicating if record is new
     * @param wasPrimary Boolean indicating if record was primary before
     * @return Boolean indicating if email is primary on create or update
     */
    private static Boolean isPrimaryOnCreateOrUpdate(ContactPointEmail email, Boolean isNew, Boolean wasPrimary) {
        return (email.IsPrimary == true && (isNew || !wasPrimary) && email.ParentId != null);
    }

    /**
     * @description Updates other emails to non-primary
     * @param parentId Parent account ID
     * @param parentIdToOtherEmailsMap Map of other emails by parent
     * @param emailsToUpdate List to collect emails to update
     */
    private static void updateOtherEmailsToNonPrimary(
        Id parentId,
        Map<Id, List<ContactPointEmail>> parentIdToOtherEmailsMap,
        List<ContactPointEmail> emailsToUpdate
    ) {
        if (parentIdToOtherEmailsMap.containsKey(parentId)) {
            for (ContactPointEmail otherEmail : parentIdToOtherEmailsMap.get(parentId)) {
                otherEmail.IsPrimary = false;
                emailsToUpdate.add(otherEmail);
            }
        }
    }

    /**
     * @description Updates Account.PersonEmail if different
     * @param email ContactPointEmail record
     * @param parentAccount Account record to update
     * @param accountsToUpdate List to collect accounts to update
     */
    private static void updateAccountPersonEmail(ContactPointEmail email, Account parentAccount, List<Account> accountsToUpdate) {
        if (parentAccount.PersonEmail != email.EmailAddress) {
            parentAccount.PersonEmail = email.EmailAddress;
            accountsToUpdate.add(parentAccount);
        }
    }

    /**
     * @description Performs DML updates for emails and accounts
     * @param emailsToUpdate List of emails to update
     * @param accountsToUpdate List of accounts to update
     */
    private static void performDMLUpdates(List<ContactPointEmail> emailsToUpdate, List<Account> accountsToUpdate) {
        if (!emailsToUpdate.isEmpty()) {
            Database.update(emailsToUpdate, false, AccessLevel.USER_MODE);
        }

        if (!accountsToUpdate.isEmpty()) {
            Database.update(accountsToUpdate, false, AccessLevel.USER_MODE);
        }
    }
}