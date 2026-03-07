/**
 * @description Perform processing of records on lead conversion,
 *              and sets field values for converted accounts, opportunities.
 * Created Date : Oct 10, 2025
 * Created By   : Sunil Khanchandani
 * 
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Oct 10, 2025       Sunil Khanchandani       Initial Version
 * V1.0.1       Oct 10, 2025       Shailja Jain             for US OMCT-343 (processTrainerLeads method added)
 * V1.0.2       Nov 6, 2025        Priyansh Shukla          Added Patient lead filtering logic (US NGASIM-992)
 * V1.0.3       Nov 7, 2025        Ayush Sharma             Added TrainingService create training logic (US NGOMCT-657)
 * V1.0.4       Dec 29, 2025       Srinivas Shanigarapu     Added try-catch for parent methods (US NGOMCT-235)
 * V1.0.5       Feb 2, 2026        Charchit Nirayanwal      Updated to use auto-conversion logic (US NGASIM-1147)
 * V1.0.6       Feb 24, 2026       Bijayalaxmi Prusty       Added ContactPoint creation for Provider-Practice lead conversion
 */

public with sharing class LeadConversionHandler {
  @TestVisible
  private static Boolean simulateFLSFailure = false;
  @TestVisible
  private static Boolean simulateEligibleLeads = false;

  /**
   * @description Entry point from trigger - Filters leads and initiates automatic Patient lead conversion
   * This method filters leads based on conversion criteria and delegates to PatientLeadConversionService
   * @param newLeads The full list of leads from the trigger
   */
  public static void filterLeadsForConversion(List<Lead> newLeads) {
    List<Lead> eligibleLeads = new List<Lead>();

    try {
      if (newLeads == null || newLeads.isEmpty()) {
        return;
      }
      // Allow test to simulate eligible leads to throw exception
      if (Test.isRunningTest() && simulateEligibleLeads) {
        eligibleLeads = null;
      }

      // Filter leads that meet conversion criteria
      for (Lead currentLead : newLeads) {
        if (meetsConversionCriteria(currentLead)) {
          eligibleLeads.add(currentLead);
        }
      }

      // If eligible leads found, delegate to service for conversion
      if (!eligibleLeads.isEmpty()) {
        PatientLeadConversionService.processAutomaticLeadConversion(
          eligibleLeads
        );
      }
    } catch (Exception ex) {
      Logger.error('Error while filtering Leads');
      Logger.saveLog();
    }
  }

  /**
   * @description Checks if a single lead meets all conversion criteria
   * @param ld The Lead record to check
   * @return Boolean True if all criteria are met, otherwise False
   */
  private static Boolean meetsConversionCriteria(Lead ld) {
    // FLS checks
    Boolean canReadFields =
      Schema.SObjectType.Lead.fields.Matching_Status__c.isAccessible() &&
      Schema.SObjectType.Lead.fields.Request_a_Call_Back__c.isAccessible() &&
      Schema.SObjectType.Lead.fields.Provider_Practice_Affiliation__c.isAccessible() &&
      Schema.SObjectType.Lead.fields.RecordTypeId.isAccessible();

    // Allow test to simulate FLS failure
    if (Test.isRunningTest() && simulateFLSFailure) {
      canReadFields = false;
    }
    if (!canReadFields) {
      return false;
    }

    // Business criteria checks
    return !ld.IsConverted &&
      ld.Matching_Status__c == ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH &&
      (ld.Request_a_Call_Back__c == null ||
      ld.Request_a_Call_Back__c == false) &&
      ld.Provider_Practice_Affiliation__c != null &&
      ld.RecordTypeId == ConstantsUtil.LEAD_PATIENT_RT;
  }

  /**
   * @description Processes leads that have just been converted and routes them by record type
   * @param records List of Lead records from the trigger (Trigger.new).
   * @param oldRecordsMap Map of prior Lead records keyed by Id (Trigger.oldMap).
   */
  public static void processLeadConversion(
    List<Lead> records,
    Map<Id, Lead> oldRecordsMap
  ) {
    // Check if the lead just got converted
    List<Lead> patientLeadsToProcess = new List<Lead>();
    List<Lead> trainerLeadsToProcess = new List<Lead>();
    List<Lead> trainerLeadsWithPracticeToProcess = new List<Lead>();
      List<Lead> providerPracticeLeadsToProcess = new List<Lead>();

    try {
      if (records == null || records.isEmpty()) {
        return;
      }

      for (Lead record : records) {
        Lead oldLead = oldRecordsMap.get(record.Id);
        if (
          isNewlyConverted(record, oldLead) &&
          record.RecordTypeId == ConstantsUtil.LEAD_PATIENT_RT
        ) {
          patientLeadsToProcess.add(record);
        } else if (
          isNewlyConverted(record, oldLead) &&
          record.RecordTypeId == ConstantsUtil.LEAD_THIRDPARTYTRAINER_RT
        ) {
          trainerLeadsToProcess.add(record);
          if (record.Practice__c != null && record.ConvertedContactId != null) {
            trainerLeadsWithPracticeToProcess.add(record);
          }
          } else if (
            isNewlyConverted(record, oldLead) &&
            record.RecordTypeId == ConstantsUtil.LEAD_PROVIDERPRACTICE_RT
          ) {
            providerPracticeLeadsToProcess.add(record);
        }
      }

      if (!patientLeadsToProcess.isEmpty()) {
        processPatientLeads(patientLeadsToProcess);
      }
      if (!trainerLeadsToProcess.isEmpty()) {
        processTrainerLeads(
          trainerLeadsToProcess,
          trainerLeadsWithPracticeToProcess
        );
      }
        if (!providerPracticeLeadsToProcess.isEmpty()) {
          processProviderPracticeLeads(providerPracticeLeadsToProcess);
        }
    } catch (Exception ex) {
      Logger.error('Error while processing Lead conversion');
      Logger.saveLog();
    }
  }

  /**
   * @description Determines if a Lead has just transitioned to a converted state in this transaction.
   * @param newLead The Lead record after the DML operation (typically from Trigger.new).
   * @param oldLead The Lead record before the DML operation (typically from Trigger.old).
   * @return Boolean True if IsConverted changed from false to true; otherwise False.
   */
  private static Boolean isNewlyConverted(Lead newLead, Lead oldLead) {
    return oldLead.IsConverted != newLead.IsConverted &&
      newLead.IsConverted == true;
  }

  /**
   * @description Handles post-conversion processing for Patient leads.
   * Maps Account, Opportunity, and ContactPoint data.
   * @param patientLeadsToProcess List of converted Patient leads.
   */
  private static void processPatientLeads(List<Lead> patientLeadsToProcess) {
    // Map ContactPoint fields synchronously (must happen in trigger context)
    AccountRelatedObjectsService.mapContactPointFields(
      patientLeadsToProcess,
      ConstantsUtil.ACCOUNT_PATIENT_RT,
      ConstantsUtil.ASIM_TAG
    );
    }

  /**
   * @description Handles post-conversion processing for Trainer leads.
   * Updates related Account, ContactPoint, and ACR (AccountContactRelation) records.
   * @param trainerLeadsToProcess List of converted Trainer leads.
   * @param trainerLeadsWithPracticeToProcess Subset of trainer leads linked to a Practice.
   */
  private static void processTrainerLeads(
    List<Lead> trainerLeadsToProcess,
    List<Lead> trainerLeadsWithPracticeToProcess
  ) {
    AccountService.updateTrainerAccRecord(
      trainerLeadsToProcess,
      ConstantsUtil.OMCT_TAG
    );

    AccountRelatedObjectsService.mapContactPointFields(
      trainerLeadsToProcess,
      ConstantsUtil.ACCOUNT_TRAINER_RT,
      ConstantsUtil.OMCT_TAG
    );

    if (!trainerLeadsWithPracticeToProcess.isEmpty()) {
      AccountContactRelationService.createACRForTrainerPractice(
        trainerLeadsWithPracticeToProcess,
        ConstantsUtil.OMCT_TAG
      );
    }

    //to create CPT Training records - NGOMCT-657
    TrainingService.createTrainings(
      trainerLeadsToProcess,
      ConstantsUtil.OMCT_TAG
    );
  }
  
    /**
     * @description Handles post-conversion processing for Provider-Practice leads.
     * Maps ContactPoint data (Address, Email, Phone) to the converted Provider Account.
     * @param providerPracticeLeadsToProcess List of converted Provider-Practice leads.
     */
    private static void processProviderPracticeLeads(
      List<Lead> providerPracticeLeadsToProcess
    ) {
      AccountRelatedObjectsService.mapContactPointFields(
        providerPracticeLeadsToProcess,
        ConstantsUtil.ACCOUNT_PROVIDER_RT,
        ConstantsUtil.ASIM_TAG
      );
    }
}