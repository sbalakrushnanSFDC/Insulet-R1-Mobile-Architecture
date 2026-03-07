/**
 * @author      : Anup Bandawar
 * @description : Send TO ASPN core class, responsible for creating the platform events.
 * @created Date: 26th Nov 2025
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       26th Nov 2025       Anup Bandawar      Initial Version(US - NGOMCT-725)
 * V1.0.1       2nd Dec 2025        Anup Bandawar      Added cancellation scenario handling(US - NGOMCT-781)
 * V1.0.2       15th Dec 2025       Anup Bandawar      Added Source ID Update scenario for ASPN opportunities(US - NGOMCT-1202)
 * V1.0.3       29th Dec 2025       Charchit Nirayanwal Updated(US - NGOMCT-1454) - Changed transaction type to SourceID Update, updated ExtPatientID to use Customer ID
 * V1.0.4       23rd Jan 2026       Anup Bandawar      Updated(US - NGOMCT-1832) - Replaced Standard Identifier.IdValue with custom Identifier.ID_Value__c
 * V1.0.5       29rd Jan 2026       Priyansh Shukla    Updated(US - NGOMCT-1356)
 * V1.0.6       30th Jan 2026       Saikat Ghosh       Updated(US - NGOMCT-1750) - Updated the ASPN event builder to set the patient external ID using accountIdentifierMap instead of accountCustomerIdMap for correct identifier mapping.
 * V1.0.7       17th Feb 2026       Saikat Ghosh       Updated(US - NGOMCT-2352) - Transform "Type 2: Using Insulin" to "Type 2" for ASPN outbound
 * V1.0.8       18th Feb 2026       Saikat Ghosh       Updated(NGOMCT-2329) - Add Opportunity and Account IDs to ASPN outbound payload for Integration Log merging
 */
public inherited sharing class SendtoAspnService {

    // Tag for Logger framework
    private static final String TAG_NAME = 'SendtoAspnService';

    // ASPN Configuration Constants
    private static final String EXTERNAL_SOURCE_INSULET = 'Insulet';
    private static final String TRANSACTION_TYPE_STANDARD = 'Standard';
    private static final String TRANSACTION_TYPE_CANCELLATION = 'Cancellation';
    private static final String TRANSACTION_TYPE_SOURCE_ID_UPDATE = 'SourceID Update';
    private static final Boolean ASPN_RX_CHASE_CONSENT_DEFAULT = false;
    private static final Boolean EMAIL_OPT_IN_DEFAULT = false;
    private static final Boolean SMS_OPT_IN_DEFAULT = false;
    private static final Boolean THIRD_PARTY_CONSENT_DEFAULT = false;

    /**
     * @description Processes the send to ASPN opportunities
     * @param sendToAspnOpportunities List of opportunities to process
     */
    public static void processSendToAspn(List<Opportunity> sendToAspnOpportunities) {
        // Validate input parameters
        if (sendToAspnOpportunities == null || sendToAspnOpportunities.isEmpty()) {
            return;
        }

        try {
            // Collect Account and Opportunity IDs
            Map<String, Set<Id>> collectedIds = collectAccountAndOpportunityIds(sendToAspnOpportunities);
            Set<Id> accountIds = collectedIds.get('accountIds');
            Set<Id> opptyIdsSet = collectedIds.get('opptyIdsSet');

            // Exit if no valid Account IDs found
            if (accountIds.isEmpty()) {
                return;
            }

            // Query all related data
            AspnDataContext dataContext = SendtoAspnServiceHelper.queryRelatedData(accountIds, opptyIdsSet);

            // Build ASPN Platform Events
            List<ASPN_Integration__e> aspnEventRecords = buildAspnPlatformEvents(
                sendToAspnOpportunities,
                dataContext
            );

            // Publish Platform Events if any events were created
            if (!aspnEventRecords.isEmpty()) {
                publishPlatformEvents(aspnEventRecords);
            }

            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new AspnProcessingException('customExceptionSwitch is turned on');
            }

        } catch (QueryException qe) {
            Logger.error('QueryException in processSendToAspn: Error querying related records for ASPN integration', sendToAspnOpportunities, qe)
                .addTag(TAG_NAME);
            Logger.saveLog();
            throw new AspnProcessingException('Error querying related records for ASPN integration: ' + qe.getMessage(), qe);
        } catch (Exception e) {
            Logger.error('Exception in processSendToAspn: Error processing ASPN opportunities', sendToAspnOpportunities, e)
                .addTag(TAG_NAME);
            Logger.saveLog();
            throw new AspnProcessingException('Error processing ASPN opportunities: ' + e.getMessage(), e);
        }
    }

    /**
     * @description Collects Account and Opportunity IDs from the opportunities
     * @param sendToAspnOpportunities List of opportunities
     * @return Map containing accountIds and opptyIdsSet
     */
    private static Map<String, Set<Id>> collectAccountAndOpportunityIds(List<Opportunity> sendToAspnOpportunities) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> opptyIdsSet = new Set<Id>();

        for (Opportunity opp : sendToAspnOpportunities) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
            opptyIdsSet.add(opp.Id);
        }

        return new Map<String, Set<Id>>{
            'accountIds' => accountIds,
            'opptyIdsSet' => opptyIdsSet
        };
    }


    /**
     * @description Builds ASPN Platform Events from opportunities and related data
     * @param sendToAspnOpportunities List of opportunities
     * @param dataContext All queried data context
     * @return List of ASPN Platform Events
     */
    private static List<ASPN_Integration__e> buildAspnPlatformEvents(
        List<Opportunity> sendToAspnOpportunities,
        AspnDataContext dataContext
    ) {
        List<ASPN_Integration__e> aspnEventRecords = new List<ASPN_Integration__e>();

        for (Opportunity opp : sendToAspnOpportunities) {
            if (opp.AccountId == null) {
                continue;
            }

            ASPN_Integration__e aspnEvent = buildSingleAspnEvent(opp, dataContext);
            aspnEventRecords.add(aspnEvent);
        }

        return aspnEventRecords;
    }

    /**
     * @description Builds a single ASPN Platform Event for an opportunity
     * @param opp Opportunity record
     * @param dataContext All queried data context
     * @return ASPN Platform Event
     */
    private static ASPN_Integration__e buildSingleAspnEvent(Opportunity opp, AspnDataContext dataContext) {
        // Get the full opportunity record with Cancel_Order__c, Reason_For_Cancellation__c, and Opportunity_Source__c
        Opportunity fullOpportunity = dataContext.opportunityMap.get(opp.Id);

        // Check if this is a cancellation scenario
        if (fullOpportunity != null && fullOpportunity.Cancel_Order__c == true) {
            return buildCancellationEvent(fullOpportunity, dataContext);
        }

        // Check if this is a Source ID Update scenario (Opportunity Source = ASPN)
        if (fullOpportunity != null && fullOpportunity.Opportunity_Source__c == ConstantsUtil.OPPORTUNITY_SOURCE_ASPN) {
            return buildSourceIdUpdateEvent(fullOpportunity, dataContext);
        }

        // Build full ASPN event for normal scenario
        return buildStandardEvent(opp, dataContext);
    }

    /**
     * @description Builds a cancellation ASPN Platform Event with minimal fields
     * @param opp Opportunity record
     * @param dataContext All queried data context
     * @return ASPN Platform Event with cancellation data
     */
    private static ASPN_Integration__e buildCancellationEvent(Opportunity opp, AspnDataContext dataContext) {
        Account patientAccount = dataContext.accountMap.get(opp.AccountId);

        // Prepare cancellation source configuration
        AspnEventBuilder.SourceConfig cancellationConfig = new AspnEventBuilder.SourceConfig();
        cancellationConfig.transactionType = TRANSACTION_TYPE_CANCELLATION;

        // Prepare patient info with only SourceID
        AspnEventBuilder.PatientInfo cancellationPatientInfo = new AspnEventBuilder.PatientInfo();
        cancellationPatientInfo.sourceId = patientAccount?.Custom_UniqueID__c;

        // Prepare product info with only reason for cancellation
        AspnEventBuilder.ProductInfo cancellationProductInfo = new AspnEventBuilder.ProductInfo();
        cancellationProductInfo.reasonForCancellation = opp.Reason_For_Cancellation__c;

        // Build cancellation event using AspnEventBuilder
        return new AspnEventBuilder()
            .setSourceConfiguration(cancellationConfig)
            .setPatientInfo(cancellationPatientInfo)
            .setPatientExternalId(dataContext.accountIdentifierMap.get(opp.AccountId))
            .setProductInfo(cancellationProductInfo)
            .setOpportunityAndAccountIds(String.valueOf(opp.Id), String.valueOf(opp.AccountId)) //Added as part of NGOMCT-2329
            .build();
    }

    /**
     * @description Builds a Source ID Update ASPN Platform Event for ASPN source opportunities
     * @param opp Opportunity record
     * @param dataContext All queried data context
     * @return ASPN Platform Event with Source ID Update data
     */
    private static ASPN_Integration__e buildSourceIdUpdateEvent(Opportunity opp, AspnDataContext dataContext) {
        Account patientAccount = dataContext.accountMap.get(opp.AccountId);

        // Prepare source configuration for Source ID Update
        AspnEventBuilder.SourceConfig sourceIdUpdateConfig = new AspnEventBuilder.SourceConfig();
        sourceIdUpdateConfig.transactionType = TRANSACTION_TYPE_SOURCE_ID_UPDATE;

        // Prepare patient info with Patient Custom Unique ID (sourceId)
        AspnEventBuilder.PatientInfo sourceIdUpdatePatientInfo = new AspnEventBuilder.PatientInfo();
        sourceIdUpdatePatientInfo.sourceId = patientAccount?.Custom_UniqueID__c;

        // Build Source ID Update event using AspnEventBuilder
        // ExtPatientID comes from Identifier where IDUsageType = 'Customer ID' (NGOMCT-1454)
        return new AspnEventBuilder()
            .setSourceConfiguration(sourceIdUpdateConfig)
            .setPatientInfo(sourceIdUpdatePatientInfo)
            .setPatientExternalId(dataContext.accountIdentifierMap.get(opp.AccountId))//(US - NGOMCT-1750) - Updated the ASPN event builder to set the patient external ID using accountIdentifierMap instead of accountCustomerIdMap for correct identifier mapping.
            .setOpportunityAndAccountIds(String.valueOf(opp.Id), String.valueOf(opp.AccountId)) //Added as part of NGOMCT-2329
            .build();
    }

    /**
     * @description Builds a standard ASPN Platform Event with all fields
     * @param opp Opportunity record
     * @param dataContext All queried data context
     * @return ASPN Platform Event with full data
     */
    private static ASPN_Integration__e buildStandardEvent(Opportunity opp, AspnDataContext dataContext) {
        // Get PersonContactId and related IDs for lookups
        Id personContactId = dataContext.accountPersonContactIdMap.get(opp.AccountId);
        Id practiceAccountId = dataContext.practiceAccountConAccIdMap.get(personContactId);
        Id providerContactId = dataContext.ccrMap.get(personContactId)?.RelatedContactId;
        Id providerAccountId = dataContext.providerConAccIdMap.get(providerContactId);

        // Get related records
        Account patientAccount = dataContext.accountMap.get(opp.AccountId);
        Account practiceAccount = dataContext.practiceAccountMap.get(practiceAccountId);
        ContactContactRelation ccr = dataContext.ccrMap.get(personContactId);
        ContactPointAddress address = dataContext.accountCpAddressMap.get(opp.AccountId);
        OpportunityLineItem lineItem = dataContext.opptyLineItemMap.get(opp.Id);

        // Calculate consent values from ContactPointTypeConsent records
        Id individualId = dataContext.accountIndividualIdMap.get(opp.AccountId);
        ConsentValues consentValues = calculateConsentValues(individualId, dataContext);

        // Prepare wrapper objects
        AspnEventBuilder.SourceConfig sourceConfig = prepareSourceConfig(consentValues);
        AspnEventBuilder.PatientInfo patientInfo = preparePatientInfo(patientAccount);
        AspnEventBuilder.PatientContact patientContact = preparePatientContact(opp.AccountId, address, dataContext);

        // Prepare provider data wrapper
        ProviderDataWrapper providerData = new ProviderDataWrapper();
        providerData.ccr = ccr;
        providerData.practiceAccount = practiceAccount;
        providerData.providerAccountId = providerAccountId;

        AspnEventBuilder.ProviderInfo providerInfo = prepareProviderInfo(providerData, dataContext);
        AspnEventBuilder.ProductInfo productInfo = prepareProductInfo(lineItem);

        // Build and return the event
        return new AspnEventBuilder()
            .setSourceConfiguration(sourceConfig)
            .setPatientInfo(patientInfo)
            .setPatientContact(patientContact)
            .setPatientExternalId(dataContext.accountIdentifierMap.get(opp.AccountId))
            .setProviderInfo(providerInfo)
            .setProductInfo(productInfo)
            .setOpportunityAndAccountIds(String.valueOf(opp.Id), String.valueOf(opp.AccountId)) //Added as part of NGOMCT-2329
            .build();
    }

    /**
     * @description Calculates consent values from ContactPointTypeConsent records
     * @param individualId Individual ID to look up consent records
     * @param dataContext Data context containing consent records
     * @return ConsentValues wrapper object with all consent values
     */
    private static ConsentValues calculateConsentValues(Id individualId, AspnDataContext dataContext) {
        ConsentValues consentValues = new ConsentValues();

        if (individualId == null) {
            return consentValues;
        }

        List<ContactPointTypeConsent> consentRecords = dataContext.individualConsentMap.get(individualId);
        if (consentRecords == null || consentRecords.isEmpty()) {
            return consentValues;
        }

        for (ContactPointTypeConsent consent : consentRecords) {
            if (consent.Name == ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL && consent.PrivacyConsentStatus == ConstantsUtil.CONSENT_STATUS_OPT_IN) {
                consentValues.emailOptIn = true;
                consentValues.aspnRxChaseConsent = true;
            } else if (consent.Name == ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
                       && (consent.PrivacyConsentStatus == ConstantsUtil.CONSENT_STATUS_OPT_IN || consent.PrivacyConsentStatus == ConstantsUtil.CONSENT_STATUS_OPT_IN_PENDING)) {
                consentValues.smsOptIn = true;
            }
        }

        return consentValues;
    }

    /**
     * @description Prepares source configuration for ASPN event
     * @param consentValues ConsentValues wrapper containing all consent-related values
     * @return SourceConfig object
     */
    private static AspnEventBuilder.SourceConfig prepareSourceConfig(ConsentValues consentValues) {
        AspnEventBuilder.SourceConfig sourceConfig = new AspnEventBuilder.SourceConfig();
        sourceConfig.externalSource = EXTERNAL_SOURCE_INSULET;
        sourceConfig.transactionType = TRANSACTION_TYPE_STANDARD;
        sourceConfig.aspnRxChaseConsent = consentValues != null && consentValues.aspnRxChaseConsent != null
            ? consentValues.aspnRxChaseConsent
            : ASPN_RX_CHASE_CONSENT_DEFAULT;
        sourceConfig.emailOptIn = consentValues != null && consentValues.emailOptIn != null
            ? consentValues.emailOptIn
            : EMAIL_OPT_IN_DEFAULT;
        sourceConfig.smsOptIn = consentValues != null && consentValues.smsOptIn != null
            ? consentValues.smsOptIn
            : SMS_OPT_IN_DEFAULT;
        sourceConfig.thirdPartyConsent = THIRD_PARTY_CONSENT_DEFAULT;
        return sourceConfig;
    }

    /**
     * @description Prepares patient information for ASPN event
     * @param patientAccount Patient Account record
     * @return PatientInfo object
     */
    private static AspnEventBuilder.PatientInfo preparePatientInfo(Account patientAccount) {
        AspnEventBuilder.PatientInfo patientInfo = new AspnEventBuilder.PatientInfo();
        patientInfo.firstName = patientAccount?.FirstName;
        patientInfo.lastName = patientAccount?.LastName;
        patientInfo.gender = patientAccount?.PersonGenderIdentity;
        patientInfo.birthdate = patientAccount?.Date_of_Birth__c;
        patientInfo.diabetesType = patientAccount?.Type_of_Diabetes__c == ConstantsUtil.DIABETES_TYPE_2_INSULIN ? ConstantsUtil.DIABETES_TYPE_2 : patientAccount?.Type_of_Diabetes__c; // Modified as per NGOMCT-2352
        patientInfo.preferredLanguage = patientAccount?.Preferred_Language__c;
        patientInfo.sourceId = patientAccount?.Custom_UniqueID__c;
        return patientInfo;
    }

    /**
     * @description Prepares patient contact information for ASPN event
     * @param accountId Patient Account ID
     * @param address Patient Address
     * @param dataContext Data context
     * @return PatientContact object
     */
    private static AspnEventBuilder.PatientContact preparePatientContact(
        Id accountId,
        ContactPointAddress address,
        AspnDataContext dataContext
    ) {
        AspnEventBuilder.PatientContact patientContact = new AspnEventBuilder.PatientContact();
        patientContact.email = dataContext.accountCpEmailMap.get(accountId)?.EmailAddress;
        patientContact.phone = dataContext.accountCpPhoneMap.get(accountId)?.TelephoneNumber;
        patientContact.address = address?.Street;
        patientContact.city = address?.City;
        patientContact.state = address?.StateCode;
        patientContact.postalCode = address?.PostalCode;
        return patientContact;
    }

    /**
     * @description Prepares provider information for ASPN event
     * @param providerData Provider data wrapper
     * @param dataContext Data context
     * @return ProviderInfo object
     */
    private static AspnEventBuilder.ProviderInfo prepareProviderInfo(
        ProviderDataWrapper providerData,
        AspnDataContext dataContext
    ) {
        AspnEventBuilder.ProviderInfo providerInfo = new AspnEventBuilder.ProviderInfo();
        providerInfo.firstName = providerData.ccr?.RelatedContact?.FirstName;
        providerInfo.lastName = providerData.ccr?.RelatedContact?.LastName;
        providerInfo.npi = dataContext.providerAccIdentifierMap.get(providerData.providerAccountId);
        providerInfo.phone = providerData.practiceAccount?.Phone;
        providerInfo.city = providerData.practiceAccount?.BillingCity;
        providerInfo.state = providerData.practiceAccount?.BillingStateCode;
        providerInfo.zip = providerData.practiceAccount?.BillingPostalCode;
        return providerInfo;
    }

    /**
     * @description Prepares product information for ASPN event
     * @param lineItem Opportunity Line Item
     * @return ProductInfo object
     */
    private static AspnEventBuilder.ProductInfo prepareProductInfo(OpportunityLineItem lineItem) {
        AspnEventBuilder.ProductInfo productInfo = new AspnEventBuilder.ProductInfo();
        productInfo.externalAspnId = lineItem?.External_ASPNID__c;
        productInfo.productName = lineItem?.Product2?.Name;
        productInfo.productNDC = lineItem?.Product_NDC__c;
        productInfo.reasonForCancellation = lineItem?.Sub_Status__c;
        return productInfo;
    }

    /**
     * @description Data context wrapper class to hold all queried data
     */
    public class AspnDataContext {
        public Map<Id, Account> accountMap = new Map<Id, Account>();
        public Set<Id> personContactIdsSet = new Set<Id>();
        public Map<Id, Id> accountPersonContactIdMap = new Map<Id, Id>();
        public Set<Id> individualIdsSet = new Set<Id>();
        public Map<Id, Id> accountIndividualIdMap = new Map<Id, Id>();
        public Map<Id, ContactPointEmail> accountCpEmailMap = new Map<Id, ContactPointEmail>();
        public Map<Id, ContactPointPhone> accountCpPhoneMap = new Map<Id, ContactPointPhone>();
        public Map<Id, ContactPointAddress> accountCpAddressMap = new Map<Id, ContactPointAddress>();
        public Map<Id, ContactContactRelation> ccrMap = new Map<Id, ContactContactRelation>();
        public Set<Id> providerAccountIdsSet = new Set<Id>();
        public Map<Id, Id> providerConAccIdMap = new Map<Id, Id>();
        public Map<Id, String> accountIdentifierMap = new Map<Id, String>();
        public Map<Id, String> accountCustomerIdMap = new Map<Id, String>();
        public Map<Id, String> providerAccIdentifierMap = new Map<Id, String>();
        public Map<Id, Id> practiceAccountConAccIdMap = new Map<Id, Id>();
        public Map<Id, Account> practiceAccountMap = new Map<Id, Account>();
        public Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>();
        public Map<Id, OpportunityLineItem> opptyLineItemMap = new Map<Id, OpportunityLineItem>();
        public Map<Id, List<ContactPointTypeConsent>> individualConsentMap = new Map<Id, List<ContactPointTypeConsent>>();
    }

    /**
     * @description Wrapper class to hold provider-related data
     */
    private class ProviderDataWrapper {
        public ContactContactRelation ccr;
        public Account practiceAccount;
        public Id providerAccountId;
    }

    /**
     * @description Wrapper class to hold consent-related values
     *              Extensible for future consent requirements
     */
    private class ConsentValues {
        public Boolean emailOptIn = EMAIL_OPT_IN_DEFAULT;
        public Boolean smsOptIn = SMS_OPT_IN_DEFAULT;
        public Boolean aspnRxChaseConsent = ASPN_RX_CHASE_CONSENT_DEFAULT;
        // Future consent fields can be added here without changing method signatures
    }

    /**
     * @description Publishes ASPN Platform Events and handles errors
     * @param aspnEventRecords List of ASPN Platform Events to publish
     */
    @TestVisible
    private static void publishPlatformEvents(List<ASPN_Integration__e> aspnEventRecords) {
        try {
            Database.SaveResult[] results = EventBus.publish(aspnEventRecords);

            // Check for publish failures
            List<String> errorMessages = new List<String>();
            for (Integer i = 0; i < results.size(); i++) {
                Database.SaveResult result = results[i];
                if (!result.isSuccess()) {
                    String errorMsg = 'Failed to publish ASPN event at index ' + i + ': ';
                    for (Database.Error error : result.getErrors()) {
                        errorMsg += error.getMessage() + '; ';
                    }
                    errorMessages.add(errorMsg);
                    Logger.error(errorMsg).addTag(TAG_NAME);
                }
            }

            // If there were any failures, throw an exception
            if (!errorMessages.isEmpty()) {
                Logger.saveLog();
                throw new AspnProcessingException('Platform Event publish failures: ' + String.join(errorMessages, ' | '));
            }

            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new AspnProcessingException('customExceptionSwitch is turned on');
            }

        } catch (Exception e) {
            Logger.error('Error publishing ASPN Platform Events', aspnEventRecords, e)
                .addTag(TAG_NAME);
            Logger.saveLog();
            throw new AspnProcessingException('Error publishing ASPN Platform Events: ' + e.getMessage(), e);
        }
    }

    /**
     * @description Custom Exception class for ASPN processing errors
     */
    public class AspnProcessingException extends Exception {
    }
}