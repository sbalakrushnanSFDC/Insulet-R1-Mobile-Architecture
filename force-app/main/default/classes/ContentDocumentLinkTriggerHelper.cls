/**
 * @author      : Rohan Saxena
 * @created Date: 23rd Dec 2025
 * @description : Content Document Link Helper Class
 * @story Number: NGOMCT-936
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By         Brief Note
 * V1.0.0       23rd Dec 2025       Rohan Saxena        Initial Version
 * V1.1.0       05th Jan 2026       Yogesh Rana         Added metadata-based visibility configuration
 */
public with sharing class ContentDocumentLinkTriggerHelper {

  // Cache for metadata records to avoid repeated queries
  private static Map<String, Content_Document_Visibility_Config__mdt> visibilityConfigCache;

  /**
   * @description Updates ContentDocumentLink visibility based on Content_Document_Visibility_Config__mdt
   *              custom metadata configuration. Checks if the linked entity's object type matches
   *              an active metadata record and applies the configured visibility level.
   * @param newrecord List of ContentDocumentLink records to process
   */
  public static void changeDocusignFileVisibility(
    List<ContentDocumentLink> newrecord
  ) {
    if (newrecord == null || newrecord.isEmpty()) {
      return;
    }

    // Load metadata configuration if not already cached
    if (visibilityConfigCache == null) {
      loadVisibilityConfiguration();
    }

    // Cache to avoid repeated getDescribe() calls for the same SObjectType
    Map<Schema.SObjectType, String> objectTypeCache = new Map<Schema.SObjectType, String>();

    // Process each ContentDocumentLink record
    for (ContentDocumentLink cdl : newrecord) {
      if (cdl.LinkedEntityId != null) {
        Schema.SObjectType sType = cdl.LinkedEntityId.getSObjectType();

        // Only call getDescribe() once per SObjectType
        if (!objectTypeCache.containsKey(sType)) {
          objectTypeCache.put(sType, sType.getDescribe().getName());
        }

        String objectApiName = objectTypeCache.get(sType);

        // Check if there's an active configuration for this object
        if (visibilityConfigCache != null && visibilityConfigCache.containsKey(objectApiName)) {
          Content_Document_Visibility_Config__mdt config = visibilityConfigCache.get(objectApiName);

          // Apply the visibility level from metadata
          if (String.isNotBlank(config.Visibility_Level__c)) {
            cdl.Visibility = config.Visibility_Level__c;
          }
        }
      }
    }
  }

  /**
   * @description Loads active Content_Document_Visibility_Config__mdt records into cache
   *              Filters by Active__c = true and indexes by Object_API_Name__c
   */
  @TestVisible
  private static void loadVisibilityConfiguration() {
    visibilityConfigCache = new Map<String, Content_Document_Visibility_Config__mdt>();

    List<Content_Document_Visibility_Config__mdt> configs = [
      SELECT Object_API_Name__c, Visibility_Level__c, Active__c
      FROM Content_Document_Visibility_Config__mdt
      WHERE Active__c = true
      WITH SYSTEM_MODE
    ];

    if(configs != null && !configs.isEmpty()) {
      for (Content_Document_Visibility_Config__mdt config : configs) {
        visibilityConfigCache.put(config.Object_API_Name__c, config);
      }
    }
  }
}