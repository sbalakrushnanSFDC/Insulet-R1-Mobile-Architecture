/**
 * @author      : Anup Bandawar
 * @created Date: 1st Dec 2025
 * @description : Reusable builder class for creating ASPN Integration Platform Events
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       1st Dec 2025        Anup Bandawar      Initial Version(US - NGOMCT-725)
 * V1.0.1		15th Dec 2025       Anup Bandawar      Added truncate logic for phone number
 * V1.0.2       18th Feb 2026       Saikat Ghosh       Added Opportunity and Account ID fields for Integration Log merging (NGOMCT-2329)
 */
public inherited sharing class AspnEventBuilder {
    // Instance variables to hold field values
    private ASPN_Integration__e event;

    /**
     * @description Constructor initializes a new ASPN Integration event
     */
    public AspnEventBuilder() {
        this.event = new ASPN_Integration__e();
    }

    // ==================== Wrapper Classes for Parameters ====================

    /**
     * @description Wrapper class for source configuration parameters
     */
    public class SourceConfig {
        public String externalSource;
        public String transactionType;
        public Boolean aspnRxChaseConsent;
        public Boolean emailOptIn;
        public Boolean smsOptIn;
        public Boolean thirdPartyConsent;
    }

    /**
     * @description Wrapper class for patient information parameters
     */
    public class PatientInfo {
        public String firstName;
        public String lastName;
        public String gender;
        public Date birthdate;
        public String diabetesType;
        public String preferredLanguage;
        public String sourceId;
    }

    /**
     * @description Wrapper class for patient contact parameters
     */
    public class PatientContact {
        public String email;
        public String phone;
        public String address;
        public String city;
        public String state;
        public String postalCode;
    }

    /**
     * @description Wrapper class for provider information parameters
     */
    public class ProviderInfo {
        public String firstName;
        public String lastName;
        public String npi;
        public String phone;
        public String city;
        public String state;
        public String zip;
    }

    /**
     * @description Wrapper class for product information parameters
     */
    public class ProductInfo {
        public String externalAspnId;
        public String productName;
        public String productNDC;
        public String reasonForCancellation;
    }

    // ==================== Configuration Methods ====================

    /**
     * @description Sets the source system configuration values
     * @param config SourceConfig wrapper containing all configuration values
     * @return AspnEventBuilder Current builder instance for method chaining
     */
    public AspnEventBuilder setSourceConfiguration(SourceConfig config) {
        if (config == null) {
            return this;
        }
        this.event.ExternalSource__c = config.externalSource;
        this.event.Transactiontype__c = config.transactionType;
        this.event.ASPNRxChaseConsent__c = config.aspnRxChaseConsent;
        this.event.emailOptIn__c = config.emailOptIn;
        this.event.smsOptIn__c = config.smsOptIn;
        this.event.thirdPartyConsent__c = config.thirdPartyConsent;
        return this;
    }

    // ==================== Patient Information Methods ====================

    /**
     * @description Sets patient demographic information
     * @param patientInfo PatientInfo wrapper containing all patient demographic data
     * @return AspnEventBuilder Current builder instance for method chaining
     */
    public AspnEventBuilder setPatientInfo(PatientInfo patientInfo) {
        if (patientInfo == null) {
            return this;
        }
        this.event.patientFirstName__c = patientInfo.firstName;
        this.event.patientLastName__c = truncate(patientInfo.lastName, 50);
        this.event.gender__c = patientInfo.gender;
        this.event.patientBirthdate__c = patientInfo.birthdate;
        this.event.patientDiabetesType__c = patientInfo.diabetesType;
        this.event.PreferredLanguage__c = patientInfo.preferredLanguage;
        this.event.SourceID__c = truncate(patientInfo.sourceId, 18);
        return this;
    }

    /**
     * @description Sets patient contact information
     * @param contact PatientContact wrapper containing all patient contact data
     * @return AspnEventBuilder Current builder instance for method chaining
     */
    public AspnEventBuilder setPatientContact(PatientContact contact) {
        if (contact == null) {
            return this;
        }
        this.event.patientEmail__c = contact.email;
        this.event.patientPhone__c = truncate(contact.phone, 12);
        this.event.patientAddress__c = truncate(contact.address, 80);
        this.event.patientCity__c = truncate(contact.city, 80);
        this.event.patientState__c = contact.state;
        this.event.patientPostalCode__c = truncate(contact.postalCode, 5);
        return this;
    }

    /**
     * @description Sets patient external identifier
     * @param externalPatientId External patient ID (will be truncated to 15 chars)
     * @return AspnEventBuilder Current builder instance for method chaining
     */
    public AspnEventBuilder setPatientExternalId(String externalPatientId) {
        this.event.ExtPatientID__c = truncate(externalPatientId, 15);
        return this;
    }
    
     /**
     * @description Sets Opportunity and Account IDs for downstream Integration Log merging
     * (NGOMCT-2329) - Add Opportunity and Account IDs to ASPN payload for Integration Log merging
     * @param opportunityId Opportunity record ID (18 chars)
     * @param accountId Account (Patient) record ID (18 chars)
     * @return AspnEventBuilder Current builder instance for method chaining
     */
    public AspnEventBuilder setOpportunityAndAccountIds(String opportunityId, String accountId) {
        this.event.Opportunity__c = truncate(opportunityId, 18);
        this.event.Account__c = truncate(accountId, 18);
        return this;
    }

    // ==================== Provider/Doctor Information Methods ====================

    /**
     * @description Sets provider/doctor information
     * @param providerInfo ProviderInfo wrapper containing all provider data
     * @return AspnEventBuilder Current builder instance for method chaining
     */
    public AspnEventBuilder setProviderInfo(ProviderInfo providerInfo) {
        if (providerInfo == null) {
            return this;
        }
        this.event.doctorFirstName__c = providerInfo.firstName;
        this.event.doctorLastName__c = providerInfo.lastName;
        this.event.doctorNPI__c = truncate(providerInfo.npi, 50);
        this.event.doctorPhone__c = truncate(providerInfo.phone, 12);
        this.event.doctorCity__c = providerInfo.city;
        this.event.doctorState__c = providerInfo.state;
        this.event.doctorZip__c = truncate(providerInfo.zip, 5);
        return this;
    }

    // ==================== Product Information Methods ====================

    /**
     * @description Sets product and opportunity information
     * @param productInfo ProductInfo wrapper containing all product data
     * @return AspnEventBuilder Current builder instance for method chaining
     */
    public AspnEventBuilder setProductInfo(ProductInfo productInfo) {
        if (productInfo == null) {
            return this;
        }
        this.event.ExternalASPNID__c = truncate(productInfo.externalAspnId, 15);
        this.event.productName__c = truncate(productInfo.productName, 50);
        this.event.productNDC__c = truncate(productInfo.productNDC, 11);
        this.event.ReasonForCancellation__c = productInfo.reasonForCancellation;
        return this;
    }

    // ==================== Build Method ====================

    /**
     * @description Builds and returns the ASPN Integration Platform Event
     * @return ASPN_Integration__e The populated platform event ready to publish
     */
    public ASPN_Integration__e build() {
        return this.event;
    }

    // ==================== Utility Methods ====================

    /**
     * @description Safely truncates a string to the specified length
     * @param value The string to truncate
     * @param maxLength Maximum length
     * @return String Truncated string or null if input is null
     */
    public static String truncate(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return null;
        }
        return value.length() <= maxLength ? value : value.substring(0, maxLength);
    }
}