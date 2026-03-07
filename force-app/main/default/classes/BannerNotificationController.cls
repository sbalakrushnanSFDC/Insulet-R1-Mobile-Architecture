/**
 * @description Controller for preparing banner notifications for trainers in LWC.
 *              Provides a cacheable method to retrieve notifications related to trainer certification status.
 *              Uses an internal helper to evaluate certification and prepare links to a relevant ListView.
 * @author Shashank Nigam
 * @createdDate 8/2/2026
 *
 *                                  Change Log
 * =======================================================================================
 * v1.0.0       8th Dec 2025       Shashank Nigam          Initial Version (NGOMCT-2094)
 * v1.0.1       10th Dec 2025      Shashank Nigam          Check for Contracts (NGOMCT-2094)
 *
 * @notes Queries run WITH SYSTEM_MODE to support access for external users viewing Experience Cloud pages.
 */
public with sharing class BannerNotificationController {
  /**
   * @description Cached Account reference for the trainer being evaluated during a single request.
   *              This value is set in getNotification and cleared before returning response.
   */
  private static Account trainer;

  /**
   * @description Returns a list of notifications to display for a given trainer.
   *              Currently evaluates certification expiration and emits an appropriate message and link.
   * @param trainerId The Account Id of the trainer
   * @return List<NotificationWrapper> collection of notifications for the UI (typically size 1)
   * @throws AuraHandledException when an unexpected error occurs while building notifications
   */
  @AuraEnabled(cacheable=true)
  public static List<NotificationWrapper> getNotification(String trainerId) {
    try {
      List<NotificationWrapper> wrapper = new List<NotificationWrapper>();
      trainer = [
        SELECT
          Id,
          PersonContactId,
          Certification_Expiration_Date__c,
          Contract_Expiration_Date__c,
          Trainer_Type__c
        FROM Account
        WHERE Id = :trainerId
        WITH SYSTEM_MODE
      ];
      wrapper.add(verifyCertification());
      wrapper.add(verifyContract());
      trainer = null; // Flush class variable
      return wrapper;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * @description Builds a certification-related notification based on the trainer's Certification_Expiration_Date__c.
   *              - error: certification expired or missing
   *              - warning: certification expiring within 60 days
   *              Includes a link to the "My_Certification" ListView for additional details.
   * @return NotificationWrapper a single notification (empty message when no notification required)
   */
  private static NotificationWrapper verifyCertification() {
    NotificationWrapper wrapper = new NotificationWrapper();
    ListView lv = [
      SELECT Id, Name, DeveloperName, SobjectType
      FROM ListView
      WHERE
        DeveloperName = :ConstantsUtil.MY_CERTIFICATION_LISTVIEW
        AND SobjectType = :ConstantsUtil.CERTIFICATION_APINAME
      WITH SYSTEM_MODE
    ];
    LinkWrapper link = new LinkWrapper();
    link.label = System.Label.See_Details;
    link.url = lv.Id;
    if (trainer.Certification_Expiration_Date__c == null) {
      return wrapper;
    } else if (trainer.Certification_Expiration_Date__c < System.today()) {
      wrapper.setMessage(
        System.Label.Certificate_Expired_Message,
        ConstantsUtil.Message_Type.ERROR.name().toLowerCase(),
        false
      );
      wrapper.links.add(link);
    } else if (
      trainer.Certification_Expiration_Date__c <= System.today().addDays(60) &&
      trainer.Certification_Expiration_Date__c >= System.today()
    ) {
      wrapper.setMessage(
        System.Label.Certificate_Expiring_Message,
        ConstantsUtil.Message_Type.WARNING.name().toLowerCase(),
        false
      );
      wrapper.links.add(link);
    }
    return wrapper;
  }

  /**
   * @description Builds a contract-related notification based on the trainer's Certification_Expiration_Date__c.
   *              - error: contract expired or missing
   *              - warning: contract expiring within 60 days
   * @return NotificationWrapper a single notification (empty message when no notification required)
   */
  private static NotificationWrapper verifyContract() {
    NotificationWrapper wrapper = new NotificationWrapper();
    LinkWrapper link = new LinkWrapper();
    link.label = System.Label.See_Details;
    link.pageName = ConstantsUtil.CONTRACT_LIST_PAGE_APINAME;
    if (
      trainer.Trainer_Type__c == ConstantsUtil.CERTIFIED_POD_TRAINER ||
      trainer.Trainer_Type__c ==
      ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER
    ) {
      if (trainer.Contract_Expiration_Date__c < System.today()) {
        wrapper.setMessage(
          System.Label.Contract_Expired,
          ConstantsUtil.Message_Type.ERROR.name().toLowerCase(),
          false
        );
        wrapper.links.add(link);
        return wrapper;
      } else if (
        trainer.Contract_Expiration_Date__c <= System.today().addDays(60) &&
        trainer.Contract_Expiration_Date__c >= System.today()
      ) {
        wrapper.setMessage(
          System.Label.Contract_Expiring,
          ConstantsUtil.Message_Type.WARNING.name().toLowerCase(),
          false
        );
        wrapper.links.add(link);
        return wrapper;
      }
    }
    if (trainer.Trainer_Type__c != ConstantsUtil.CERTIFIED_POD_TRAINER) {
      List<AccountContactRelation> practices = [
        SELECT Id, Account.Contract_Expiration_Date__c
        FROM AccountContactRelation
        WHERE
          ContactId = :trainer.PersonContactId
          AND Roles = :ConstantsUtil.ACR_ROLE_TRAINER
        WITH SYSTEM_MODE
      ];
      for (AccountContactRelation practice : practices) {
        if (practice.Account.Contract_Expiration_Date__c < System.today()) {
          wrapper.setMessage(
            System.Label.Contract_Expired,
            ConstantsUtil.Message_Type.ERROR.name().toLowerCase(),
            false
          );
          wrapper.links.add(link);
          break;
        } else if (
          practice.Account.Contract_Expiration_Date__c <=
          System.today().addDays(60) &&
          practice.Account.Contract_Expiration_Date__c >= System.today()
        ) {
          wrapper.setMessage(
            System.Label.Contract_Expiring,
            ConstantsUtil.Message_Type.WARNING.name().toLowerCase(),
            false
          );
          wrapper.links.add(link);
          break;
        }
      }
    }
    return wrapper;
  }

  /**
   * @description Wrapper representing a single toast/alert style notification for LWC.
   *              Contains message, type, dismissibility and optional links.
   */
  public class NotificationWrapper {
    /** @description Notification text rendered to the user */
    @AuraEnabled
    public String message;
    /** @description Notification variant (e.g., 'error', 'warning', 'success', 'info') */
    @AuraEnabled
    public String type;
    /** @description Whether the UI should allow dismissing the notification */
    @AuraEnabled
    public Boolean isDismissible;
    /** @description Optional list of related links appended to the message */
    @AuraEnabled
    public List<LinkWrapper> links;
    /** @description Separator string between multiple links (default ' | ') */
    @AuraEnabled
    public String linkSeperator;

    /**
     * @description Convenience method to set all message properties and initialize defaults.
     * @param msg The notification text
     * @param type The variant (error, warning, success, info)
     * @param isDismissible Whether the notification is dismissible
     */
    public void setMessage(String msg, String type, Boolean isDismissible) {
      this.message = msg;
      this.type = type;
      this.isDismissible = isDismissible;
      this.links = new List<LinkWrapper>();
      this.linkSeperator = ' | ';
    }
  }

  /**
   * @description Wrapper for a link to be displayed at the end of a notification message.
   *              Add additional properties as needed for Experience Cloud navigation patterns.
   */
  public class LinkWrapper {
    /** @description Display label for the link */
    @AuraEnabled
    public String label;
    /** @description Optional Experience Cloud page name (when using named pages) */
    @AuraEnabled
    public String pageName;
    /** @description Target URL or record Id for navigation */
    @AuraEnabled
    public String url;
  }
}