/**
 * @description Handler class for ContactPointEmail triggers.
 *              Handles Insert, Update, and Delete events for ContactPointEmail.
 *              Converts flow logic from Contact_Point_Email_After_Insert_After_Update flow.
 * Created Date : Dec 2025
 * Created By   : Ramesh Kumar
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       11th Feb 2026       Charchit N.           Initial Version (NGASIM-2207)
 */
public with sharing class ContactPointEmailHandler {
    
    /**
     * @description Static variable to control behavior when newly created ContactPointEmail records
     *              have IsPrimary = true. When true, the new email remains primary (IsPrimary = true)
     *              and Account.PersonEmail is updated. Existing primary ContactPointEmail records will
     *              still be set to IsPrimary = false to maintain single primary email per account.
     *              When false (default), normal behavior: new primary email sets others to non-primary.
     */
    public static Boolean skipSetPrimaryOnNewContactPointEmail = false;

    /**
     * @description Handles primary ContactPointEmail logic before insert.
     *              Sets IsPrimary = true to the latest created ContactPointEmail for each account.
     *              If multiple records are being inserted for the same account and multiple have IsPrimary = true,
     *              only one will remain primary (the last one in the list).
     * @param emailRecords List of ContactPointEmail records being inserted
     */
    public static void handleBeforeInsert(List<ContactPointEmail> emailRecords) {
        if (emailRecords == null || emailRecords.isEmpty()) {
            return;
        }

        if (skipSetPrimaryOnNewContactPointEmail) {
            return; // Skip setting primary in before insert when flag is true
        }

        processPrimaryContactPointEmailBeforeInsert(emailRecords);
    }

    /**
     * @description Processes primary ContactPointEmail logic before insert.
     *              Groups emails by account and sets primary based on multiple insert logic.
     *              Modifies the original emailRecords list directly.
     * @param emailRecords List of ContactPointEmail records being inserted (modified in place)
     */
    private static void processPrimaryContactPointEmailBeforeInsert(List<ContactPointEmail> emailRecords) {
        Map<Id, List<ContactPointEmail>> accountToEmailsMap = groupEmailsByAccount(emailRecords);

        for (Id accountId : accountToEmailsMap.keySet()) {
            List<ContactPointEmail> emailsForAccount = accountToEmailsMap.get(accountId);
            if (!emailsForAccount.isEmpty()) {
                processEmailsForAccount(emailsForAccount);
            }
        }
    }

    /**
     * @description Groups emails by their ParentId (Account)
     * @param emailRecords List of ContactPointEmail records
     * @return Map of Account ID to List of ContactPointEmail records
     */
    private static Map<Id, List<ContactPointEmail>> groupEmailsByAccount(List<ContactPointEmail> emailRecords) {
        Map<Id, List<ContactPointEmail>> accountToEmailsMap = new Map<Id, List<ContactPointEmail>>();

        for (ContactPointEmail email : emailRecords) {
            if (email.ParentId != null) {
                if (!accountToEmailsMap.containsKey(email.ParentId)) {
                    accountToEmailsMap.put(email.ParentId, new List<ContactPointEmail>());
                }
                accountToEmailsMap.get(email.ParentId).add(email);
            }
        }

        return accountToEmailsMap;
    }

    /**
     * @description Processes emails for a single account to set primary status
     * @param emailsForAccount List of ContactPointEmail records for the account
     */
    private static void processEmailsForAccount(List<ContactPointEmail> emailsForAccount) {
        if (emailsForAccount.size() == 1) {
            setSingleEmailAsPrimary(emailsForAccount[0]);
        } else {
            processMultipleEmails(emailsForAccount);
        }
    }

    /**
     * @description Sets a single email as primary
     * @param email ContactPointEmail record to set as primary
     */
    private static void setSingleEmailAsPrimary(ContactPointEmail email) {
        email.IsPrimary = true;
    }

    /**
     * @description Processes multiple emails to ensure only one is primary
     * @param emailsForAccount List of ContactPointEmail records for the account
     */
    private static void processMultipleEmails(List<ContactPointEmail> emailsForAccount) {
        List<ContactPointEmail> primaryEmails = getPrimaryEmails(emailsForAccount);

        if (primaryEmails.size() > 1) {
            keepOnlyLastPrimaryEmail(emailsForAccount, primaryEmails);
        } else if (primaryEmails.isEmpty()) {
            setLastEmailAsPrimary(emailsForAccount);
        }
        // If exactly one primary email, keep it as is (no change needed)
    }

    /**
     * @description Gets list of emails that are currently marked as primary
     * @param emailsForAccount List of ContactPointEmail records
     * @return List of primary ContactPointEmail records
     */
    private static List<ContactPointEmail> getPrimaryEmails(List<ContactPointEmail> emailsForAccount) {
        List<ContactPointEmail> primaryEmails = new List<ContactPointEmail>();
        for (ContactPointEmail email : emailsForAccount) {
            if (email.IsPrimary == true) {
                primaryEmails.add(email);
            }
        }
        return primaryEmails;
    }

    /**
     * @description Keeps only the last primary email as primary, sets others to false
     * @param emailsForAccount List of ContactPointEmail records
     * @param primaryEmails List of currently primary emails
     */
    private static void keepOnlyLastPrimaryEmail(List<ContactPointEmail> emailsForAccount, List<ContactPointEmail> primaryEmails) {
        ContactPointEmail lastPrimaryEmail = primaryEmails[primaryEmails.size() - 1];
        for (ContactPointEmail email : emailsForAccount) {
            email.IsPrimary = (email == lastPrimaryEmail);
        }
    }

    /**
     * @description Sets the last email in the list as primary
     * @param emailsForAccount List of ContactPointEmail records
     */
    private static void setLastEmailAsPrimary(List<ContactPointEmail> emailsForAccount) {
        emailsForAccount[emailsForAccount.size() - 1].IsPrimary = true;
    }

    /**
     * @description Handles primary ContactPointEmail logic after insert.
     *              Makes all other ContactPointEmail records non-primary except the recently inserted primary one.
     *              Updates Account.PersonEmail with the current primary email.
     * @param emailRecords List of ContactPointEmail records that were inserted
     * @param newRecordsMap Map of new records
     */
    public static void handleAfterInsert(List<ContactPointEmail> emailRecords, Map<Id, SObject> newRecordsMap) {
        if (emailRecords == null || emailRecords.isEmpty()) {
            return;
        }

        try {
            ContactPointEmailService.handlePrimaryContactPointEmail(emailRecords, newRecordsMap, null);
        } catch (Exception e) {
            Logger.error('ContactPointEmailHandler: Error processing contact point emails after insert. Details: ' + e.getMessage())
                .addTag(ConstantsUtil.ASIM_TAG);
        }
    }

    /**
     * @description Handles primary ContactPointEmail logic after update.
     *              Makes all other ContactPointEmail records non-primary except the recently updated primary one.
     *              Updates Account.PersonEmail with the latest email.
     * @param emailRecords List of ContactPointEmail records that were updated
     * @param updatedRecordsMap Map of updated records
     * @param oldRecordsMap Map of old records
     */
    public static void handleAfterUpdate(List<ContactPointEmail> emailRecords, Map<Id, SObject> updatedRecordsMap, Map<Id, SObject> oldRecordsMap) {
        if (emailRecords == null || emailRecords.isEmpty()) {
            return;
        }

        try {
            ContactPointEmailService.handlePrimaryContactPointEmail(emailRecords, updatedRecordsMap, oldRecordsMap);
        } catch (Exception e) {
            Logger.error('ContactPointEmailHandler: Error processing contact point emails after update. Details: ' + e.getMessage())
                .addTag(ConstantsUtil.ASIM_TAG);
        }
    }

}