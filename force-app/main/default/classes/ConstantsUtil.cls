/**
 * @description : Centralized constants for custom permissions.
 * @author      : Shailja Jain
 * @created Date: 2nd September 2025
 * @story Number: NGONDL-97
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       2nd Sept 2025       Shailja Jain                  Initial Version(US - NGONDL-97)
 * V1.0.1       1st Oct 2025        Bijayalaxmi Prusty            Updated(US - NGASIM-376)
 * V1.0.2       9th Oct 2025        Ramesh Dhaka                  Updated(US- NGOMCT-202)
 * V1.0.3       28th Oct 2025       Ankur Chauhan                 Updated(US- NGOMCT-337)
 * V1.0.4       30th Oct 2025       Bijayalaxmi Prusty            Updated(US - NGASIM-219)
 * V1.0.5       03rd Nov 2025       Ramesh Dhaka                  Updated(US - NGOMCT-709)
 * V1.0.6       04th Nov 2025       Priyansh Shukla               Updated(US - NGASIM-992)
 * V1.0.7       06th Nov 2025       Bijayalaxmi Prusty            Updated(US - NGASIM-622)
 * V1.0.8       07th Nov 2025       Ayush Sharma                  Updated(US - NGOMCT-657)
 * V1.0.9       13th Nov 2025       Ankur Chauhan                 Updated(US - NGOMCT-689)
 * V1.0.10      12th Nov 2025       Bijayalaxmi Prusty            Updated(US - NGASIM-1065)
 * V1.0.11      14th Nov 2025       Charchit Nirayanwal           Updated(US - NGASIM-1223)
 * V1.0.12      18th Nov 2025       Jatin Butta                   Updated(US - NGASIM-1166)
 * V1.0.13      19th Nov 2025       Srinivas Shanigarapu          Updated(US - NGOMCT-469)
 * V1.0.14      24th Nov 2025       Srinivas Shanigarapu          Updated(US - NGOMCT-787)
 * V1.0.15      27th Nov 2025       Anup Bandawar                 Updated(US - NGOMCT-725)
 * V1.0.16      28th Nov 2025       Bijayalaxmi Prusty            Updated(US - NGASIM-1050)
 * v1.0.17      2nd Dec 2025        Niranjan Elangovan            Updated(US - NGASIM-1389)
 * V1.0.18      3rd Dec 2025        Srinivas Shanigarapu          Updated(US - NGOMCT-645)
 * v1.0.19      10th Dec 2025       Bijayalaxmi Prusty            Updated(US - NGASIM-368)
 * v1.0.20      15th Dec 2025       Anup Bandawar                 Updated(US - NGOMCT-1202) - Added Opportunity Source Constants
 * v1.0.21      12th Dec 2025       Shashank Nigam                Updated(US - NGOMCT-1049)
 * v1.0.22      15th Dec 2025       Bijayalaxmi Prusty            Updated(US - NGOMCT-824)
 * v1.0.23      22nd Dec 2025       Jatin Butta                   Updated(US - NGASIM-1273) - Added Task Generation Constants
 * v1.0.24      23rd Dec 2025       Rohan Saxena                  Updated(US - NGOMCT-1530)
 * v1.0.25      29th Dec 2025       Charchit Nirayanwal           Updated(US - NGOMCT-1454) - Added Customer ID Identifier Usage Type Constant
 * v1.0.26      29th Dec 2025       Srinivas Shanigarapu          Updated(US - NGOMCT-235)
 * v1.0.27      12th Jan 2026       Anup Bandawar                 Updated(US - NGASIM-1029) - Added New Opportunity Stage Constant
 * v1.0.27      13th Jan 2026       Bhavya Chanan          		  Updated(US - NGOMCT-583)
 * v1.0.28      22nd Jan 2026       Sushanth Shetty               Updated(US - NGASIM-1274) - Added Opportunity Object Constant
 * V1.0.29      23rd Jan 2026       Bijayalaxmi Prusty            Updated(US - NGASIM-1885)
 * V1.0.31      28th Jan 2026       Bijayalaxmi Prusty            Updated(US - NGASIM-1905) - Added MINOR_AGE_THRESHOLD constant for minor lead processing
 * V1.0.30      29th Jan 2026       Tanu Tyagi                    Updated(US - NGASIM-1911) - Added Consent Service Constants
 * V1.0.32      29th Jan 2026       Charchit Nirayanwal           Updated(US - NGASIM-1147) - Added MINOR_AGE_THRESHOLD constant for minor lead processing
 * V1.0.32      29th Jan 2026       Priyansh Shukla               Updated(US - NGOMCT-1356)
 * V1.0.33      02nd Feb 2026       Charchit Nirayanwal           Updated(US - NGASIM-1147) - Added ContactPoint UsageType Constants
 * V1.0.35      05th Feb 2026       Charchit Nirayanwal           Updated - Added PATIENT_LEGAL_GUARDIAN_CCR_ROLE constant for CaregiverRelationshipService
 * V1.0.37      05th Feb 2026       Ayush Sharma                  Updated(US - NGOMCT-482) - Added ASPN Inactivity Alert - Opportunity Sub Status and Threshold Values
 * V1.0.38      09th Feb 2026       Saikat Ghosh                  Updated(US - NGASIM-2252) - Replaced US_STANDARD_PRICEBOOK_NAME with PRIMARY_PRICEBOOK
 * V1.2.3		12nd Feb 2026		Bijayalaxmi Prusty		      Modified(US - NGASIM-2065)
 * V1.0.39      12th Feb 2026       Yogesh Rana                   Updated(US - NGOMCT-2099)
 * V1.0.40      17th Feb 2026       Saikat Ghosh                  Updated(US - NGOMCT-2352) - Added DIABETES_TYPE_2 constant for ASPN outbound
 * V1.1.1       20th Feb 2026       Bijayalaxmi Prusty            Updated(NGASIM-2157)
 * V1.0.43      24th Feb 2026       Saikat Ghosh 		     	  Updated(US - NGASIM-2045) - Added Case Notification Constants
 * V1.0.44      26th Feb 2026       Saikat Ghosh                  Updated(US - NGASIM-1722) - Added TERRITORY2_ASSIGNMENT_RULE_AC for Provider Practice Lead Territory
 * V2.0.1       25th Feb 2026       Ramesh Kumar                  Updated(NGCRMI-1836) - Added AUTHORIZED_CALLER_CCR_ROLE constant for OrgSync_GuardianCCRHandler
 */
public with sharing class ConstantsUtil {
    /** Static variable - in use for test coverage*/
    public static Boolean customExceptionSwitch = false;
    /** Static Constants */
    public static final String BYPASS_APEX_TRIGGER = 'Bypass_Apex_Trigger';
    public static final String ASIM_TAG = 'ASIM';
    public static final String INSERT_OPERATION = 'INSERT';
    public static final String UPDATE_OPERATION = 'UPDATE';

    public static final String OMCT_TAG = 'OMCT';
    public static final String EXTERNAL_TRAINER_TERRITORY = 'External Trainer';
    public static final String ASSOCIATION_CAUSE = 'Territory2Manual';
    public static final String ACC_TRIGGER_HANDLER = 'AccountTriggerHandler';
    public static final Id LEAD_PATIENT_RT = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Patient').getRecordTypeId();
    public static final Id LEAD_THIRDPARTYTRAINER_RT = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Third_Party_Trainer').getRecordTypeId();
	public static final Id LEAD_PROVIDERPRACTICE_RT = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Provider_Practice_Lead').getRecordTypeId();
    public static final Id ACCOUNT_PATIENT_RT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Patient').getRecordTypeId();
    public static final Id ACCOUNT_PROVIDER_RT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Provider').getRecordTypeId();
    public static final Id ACCOUNT_TRAINER_RT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Trainer').getRecordTypeId();
    public static final Id ACCOUNT_PRACTICE_RT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Practice').getRecordTypeId();
	public static final Id ACCOUNT_PATIENT_DELICATE_RT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Patient_Delegate').getRecordTypeId();
    public static final Id OPPORTUNITY_NCS_RT = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('NCS_Opportunity').getRecordTypeId();
    public static final Id ASSET_CONTROLLER_RT = Schema.SObjectType.Asset.getRecordTypeInfosByDeveloperName().get('Controller').getRecordTypeId();

    // Training Record Type Ids
	public static final Id TRAINING_LIVE_TRAINING_RT = Schema.SObjectType.Training__c.getRecordTypeInfosByDeveloperName().get('Live_Training').getRecordTypeId();
	public static final Id TRAINING_E_LEARNING_RT = Schema.SObjectType.Training__c.getRecordTypeInfosByDeveloperName().get('E_Learning').getRecordTypeId();
    public static final Id TRAINING_CPT_TRAINING_RT = Schema.SObjectType.Training__c.getRecordTypeInfosByDeveloperName().get('CPT_Training').getRecordTypeId();
    public static final String GUARDIAN_RELATIONSHIP_NAME = 'Legal Guardian';
    public static final String AUTHORIZED_CALLER_RELATIONSHIP_NAME = 'Authorized Caller'; //need to make it more specific otherwise it is giving 2 records CCR and AAR for Authorized Caller
    public static final String AUTHORIZED_CALLER_CCR_ROLE = 'Authorized Caller-Authorized Caller-CCR'; //Specific to Authorized Caller role to be selected on CCR
    public static final String PROVIDER_RELATIONSHIP_NAME = 'Provider';
    public static final String CLINIC_CONTRACT_TRAINER = 'Clinic Contract Trainer';
    public static final String CERTIFIED_POD_TRAINER = 'Certified Pod Trainer';
    public static final String CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER = 'Certified Pod & Clinic Contract Trainer';
    public static final String CONTACT_CONTACT_RELATION = 'Contact_Contact_Relationship';
    public static final String PATIENT_PROVIDER_CCR_ROLE = 'Patient-Provider-CCR';
    public static final String PATIENT_LEGAL_GUARDIAN_CCR_ROLE = 'Patient-Legal Guardian-CCR';
    // Diabetes Types from the 'Type_of_Diabetes__c' field
    public static final String DIABETES_TYPE_1 = 'Type 1';
    public static final String DIABETES_TYPE_2 = 'Type 2';// Added as per NGOMCT-2352
    public static final String DIABETES_OTHER = 'Other/Unsure';
    public static final String DIABETES_TYPE_2_INSULIN = 'Type 2: Using Insulin';
    // Age Categories used in the recommendation logic and metadata
    public static final String AGE_UNDER_2 = 'Under 2';
    public static final String AGE_2_PLUS = '2+';
    public static final String AGE_UNDER_18 = 'Under 18';
    public static final String AGE_18_PLUS = '18+';
    public static final Set<String> PROD_RECOMMEND_NOT_ELIGIBLE_LEADSOURCE = new Set<String>{'ASPN'};
    // Excluded Lead Statuses for Duplicate Matching
    public static final Set<String> EXCLUDED_LEAD_STATUSES = new Set<String>{
        'Closed', 'Converted', 'Lost', 'Closed Duplicate'
    };
    // Lead Matching Statuses for Duplicate Matching
    public static final String LEAD_MATCHING_STATUS_NO_MATCH = 'No Match';
    public static final String LEAD_MATCHING_STATUS_PARTIAL_MATCH = 'Partial Match';
    public static final String LEAD_MATCHING_STATUS_FULL_MATCH = 'Full Match';
    //Lead Fields
    public static final String LEAD_EMAIL = 'Email';
    public static final String LEAD_SOURCE = 'LeadSource';
    public static final String LEAD_STATUS = 'Status';
    public static final String LEAD_LAST_NAME = 'LastName';
    public static final String LEAD_FIRST_NAME = 'FirstName';
    public static final String LEAD_MIDDLE_NAME = 'MiddleName';
    public static final String LEAD_DATE_OF_BIRTH = 'Date_of_Birth__c';
    public static final String LEAD_POSTAL_CODE = 'PostalCode';
    public static final String LEAD_STREET = 'Street';
    public static final String LEAD_CITY = 'City';
    public static final String LEAD_STATE = 'State';
    public static final String LEAD_COUNTRY = 'Country';
    public static final String LEAD_TERRITORY_ALIAS = 'Territory_Alias__c';
    public static final String LEAD_PHONE = 'Phone';
    public static final String LEAD_STATE_CODE = 'StateCode';
    public static final String ID = 'Id';
    //Lead Source for Duplicate Matching
    public static final String LEAD_SOURCE_ASPN = 'ASPN';

    public static final String LEAD_STATUS_NEW = 'New';
    public static final String LEAD_STATUS_PENDING_REVIEW = 'Pending Review';
    public static final String LEAD_STATUS_QUALIFICATION = 'Qualification';

    //Lead Source for Spanish Language Scenario (NGASIM-1273)
    public static final String LEAD_SOURCE_EMPEZAR = 'Empezar';
    public static final String LEAD_SOURCE_GET_STARTED = 'Get Started';
    //Language Values
    public static final String LANGUAGE_SPANISH = 'Spanish';
    //Object Names
    public static final String LEAD_OBJECT = 'Lead';
    public static final String OPPORTUNITY_OBJECT = 'Opportunity';
    public static final String ACCOUNT_OBJECT = 'Account';
    public static final String HEALTHCARE_PROVIDER_OBJECT = 'HealthcareProvider';
    public static final String HEALTHCARE_PRACTITIONER_FACILITY_OBJECT = 'HealthcarePractitionerFacility';
    //Class Names
    public static final String OPPORTUNITY_SERVICE_CLASS = 'OpportunityService';
    //Identifier Usage Type
    public static final String IDENTIFIER_NPI_USAGE_TYPE = 'NPI';
    public static final String IDENTIFIER_EXTERNAL_PATIENT_ID_USAGE_TYPE = 'External PatientID';
    public static final String IDENTIFIER_CUSTOMER_ID_USAGE_TYPE = 'Customer ID';
    //Provider Practice Lead Converted Status
    public static final String LEAD_PROVIDERPRACTICE_CONVERT_STATUS = 'Converted';
    //Patient Lead Converted Status
    public static final String LEAD_PATIENT_CONVERT_STATUS = 'Converted';
    //Converted Lead Opportunity status
    public static final String OPPORTUNITY_CONVERTED_STAGE = 'Qualification';
    public static final String NEW_OPPORTUNITY_OPPORTUNITY_STAGE = 'New Opportunity';
    //Account Fields
    public static final String ACCOUNT_BILLING_POSTAL_CODE = 'BillingPostalCode';
    public static final String ACCOUNT_BILLING_STREET = 'BillingStreet';
    public static final String ACCOUNT_BILLING_CITY = 'BillingCity';
    public static final String ACCOUNT_BILLING_STATE = 'BillingState';
    public static final String ACCOUNT_BILLING_STATE_CODE = 'BillingStateCode';
    public static final String ACCOUNT_BILLING_COUNTRY = 'BillingCountry';
    public static final String ACCOUNT_TERRITORY_ALIAS = 'Territory_Alias__c';
    public static final String ACCOUNT_SPECIALTY = 'Specialty__c';
    public static final String ACCOUNT_FIRST_NAME = 'FirstName';
    public static final String ACCOUNT_MIDDLE_NAME = 'MiddleName';
    public static final String ACCOUNT_LAST_NAME = 'LastName';
    public static final String ACCOUNT_PERSON_EMAIL = 'PersonEmail';
    public static final String ACCOUNT_PHONE = 'Phone';
    public static final String ACCOUNT_DATE_OF_BIRTH = 'Date_of_Birth__c';
    public static final String ACCOUNT_CUSTOM_UNIQUE_ID = 'Custom_UniqueID__c';
    public static final String ACCOUNT_NAME = 'Name';
    public static final String DO_NOT_USE_FOR_TRAINING_REASON_TERMINATED = 'Terminated';
    // Account Specialty Values
    public static final String SPECIALTY_PEDIATRIC = 'Pediatrics';
    //Excluded Specialties for Territory Assignment
    public static final Set<String> EXCLUDED_SPECIALTIES = new Set<String>{'Pediatrics'};
    //Territory2 Assignment Types
    public static final String TERRITORY2_MANUAL_AC = 'Territory2Manual';
    
    public static final String TERRITORY2_ASSIGNMENT_RULE_AC = 'Territory2AssignmentRule'; // Added as part of NGASIM-1722

    //Lead Closed Duplicate Status
    public static final String LEAD_CLOSED_DUPLICATE_STATUS = 'Closed Duplicate';
        //Training Record Type
    public static final String LIVE_TRAINING_RECORD_TYPE = 'Live_Training';
    public static final String E_LEARNING_RECORD_TYPE = 'E_Learning';
    //Training Stage
    public static final String STAGE_NEW = 'New';
    public static final String STAGE_PENDING_ACCEPTANCE = 'Pending Acceptance';
    public static final String STAGE_PENDING_ASSIGNMENT = 'Pending Assignment';
    public static final String STAGE_ACCEPTED = 'Accepted';
    public static final String STAGE_COMPLETED = 'Completed';
    public static final String STAGE_IN_PROGRESS = 'In Progress';
    public static final String STAGE_DECLINED = 'Declined';
    public static final String ALREADY_ACCEPTED = 'ALREADY_ACCEPTED';
    public static final String SUCCESS = 'SUCCESS';
    public static final String TRAINING_OBJECT_NAME = 'Training__c';
    public static final String REASON_FIELD = 'Decline_Reason__c';

    //Training Educator Type
    public static final String EDUCATOR_TYPE_CTS = 'CTS';
    public static final String EDUCATOR_TYPE_IT = 'IT';
    public static final String EDUCATOR_TYPE_OT = 'OT';
    public static final String EDUCATOR_TYPE_CC = 'CC';
    public static final String EDUCATOR_TYPE_ST = 'ST';
    public static final String EDUCATOR_TYPE_SG = 'SG';
    public static final String EDUCATOR_TYPE_OH = 'OH';
    public static final String EDUCATOR_TYPE_CPT = 'CPT';

    //ZipCode Fields
    public static final String ZIPCODE_TERRITORY_NAME_FIELD = 'Territory_Name__c';

    //Opportunity Stage
    public static final String OPPORTUNITY_STAGE_SEND_TO_ASPN = 'Send to ASPN';
	public static final String OPPORTUNITY_STAGE_CLOSED_WON = 'Closed Won';

    //Opportunity Source
    public static final String OPPORTUNITY_SOURCE_ASPN = 'ASPN';
    public static final String OPPORTUNITY_SOURCE_INSULET = 'Insulet';
    //Opportunity Product Constants
    public static final String PRIMARY_PRICEBOOK = 'Primary Price Book';//Added as part of NGASIM-2252
    public static final Integer DEFAULT_OPPORTUNITY_QUANTITY = 1;

    //Party Role Relation Type
    public static final String PARTY_ROLE_RELATION_TYPE_PATIENT_PROVIDER = 'Patient-Provider-CCR';

    //Account Contact Relation Role
    public static final String ACR_ROLE_PATIENT_PRACTICE = 'Patient - Practice Affiliation';

    //Lead Provider Practice Matching Fields
    public static final String LEAD_PROVIDER_MATCHING_STATUS = 'Provider_Matching_Status__c';
    public static final String LEAD_PRACTICE_MATCHING_STATUS = 'Practice_Matching_Status__c';
    public static final String LEAD_NPI = 'NPI__c';
    public static final String LEAD_PRACTICE_NAME = 'Practice_Name__c';
    public static final String PASSED = 'Passed';
    public static final String FAILED = 'Failed';
    public static final String NOT_ATTEMPTED = 'Not Attempted';
    public static final String COMPLETED = 'Completed';
    public static final String PASS = 'Pass';
    public static final String FAIL = 'Fail';
    public static final String  PENDING = 'Pending';
    public static final String  IN_PROGRESS = 'In Progress';

    public static final String  ACR_ROLE_TRAINER = 'Trainer';
    public static final String USER_PERSONA_CSM = 'Clinical Services Manager';
    // Error Messages
    public static final String TASK_GEN_ERROR_NO_ACTIVE_RULES = 'No active Task Generation rules found for the specified object.';
    public static final String TASK_GEN_ERROR_RECORD_NOT_MATCH = 'Record did not match any Task Generation criteria.';
    public static final String TASK_GEN_ERROR_PROCESSING_BATCH = 'Error occurred while processing Task Generation batch.';
    public static final String TASK_GEN_ERROR_EMPTY_REQUEST = 'Task generation request list is empty or null.';
    public static final String TASK_GEN_ERROR_NO_RULES_FOR_TRIGGER_EVENT = 'No rules match the trigger event';
    // Task Defaults
    public static final String TASK_STATUS_DEFAULT = 'Open';
    public static final String TASK_PRIORITY_DEFAULT = 'Normal';
    public static final String TASK_STATUS_COMPLETED = 'Completed';
    public static final String TASK_STATUS_CLOSED = 'Closed';
    public static final String TASK_TRAINING_ACTIVITIES_RT = 'Training Activities';
    public static final String TASK_SUBJECT_PATIENT_7_DAY_FOLLOWUP = 'Patient 7 day Follow-up';

    //Group Type
    public static final String GROUP_TYPE_QUEUE = 'Queue';
    public static final String PRACTICE_PROVIDER_LEAD_QUEUE = 'Practice_Provider_Lead';
    public static final String DTC_OPEN_QUEUE = 'DTC_Open';

    // Task Generation - Max Iterations for Next Business Day
    public static final Integer MAX_ITERATIONS_FOR_NEXT_BUSINESS_DAY = 5;
    public static final String ALL_USERS = 'AllUsers';

    public static final String CONTRACT_STATUS_ACTIVATED = 'Activated';

    public static final String CONVERSION_TYPE_AUTO = 'Auto';
    public static final String CONVERSION_TYPE_MANUAL = 'Manual';
    public static final String CONVERSION_TYPE_BOTH = 'Both';

    // Metadata Field Category
    public static final String METADATA_FIELD_CATEGORY_ADDRESS_INFORMATION = 'Address Information';

    // ContactPointTypeConsent Privacy Consent Status
    public static final String PRIVACY_CONSENT_STATUS_OPT_IN = 'OptIn';
    public static final String PRIVACY_CONSENT_STATUS_OPT_OUT = 'OptOut';
    public static final String PRIVACY_CONSENT_STATUS_NOT_SEEN = 'NotSeen';

    // Consent Service Constants (NGASIM-1911)
    // Consent status values - using standard API names
    public static final String CONSENT_STATUS_OPT_IN = 'OptIn';
    public static final String CONSENT_STATUS_OPT_IN_PENDING = 'OptInPending';

    // Contact Point Type Consent Name Constants (from Custom Labels)
    public static final String CONSENT_NAME_TRANSACTIONAL_EMAIL = System.Label.Consent_Name_Email;
    public static final String CONSENT_NAME_TRANSACTIONAL_SMS = System.Label.Consent_Name_SMS;
    public static final String CONSENT_NAME_MARKETING_EMAIL = System.Label.Consent_Name_Marketing_Email;
    public static final Set<String> CONSENT_NAMES = new Set<String>{
        CONSENT_NAME_TRANSACTIONAL_EMAIL,
        CONSENT_NAME_TRANSACTIONAL_SMS,
        CONSENT_NAME_MARKETING_EMAIL
    };
    public static final String CONTRACT_TYPE_1 = 'LEVEL 1';
    public static final String CONTRACT_TYPE_2 = 'LEVEL 2';
    public static final String CONTRACT_TYPE_3 = 'LEVEL 3';

    public static final String RATE_TYPE_OBSERVATION = 'Observation';
    public static final String RATE_TYPE_TRAINING = 'Training';
    public static final String RATE_TYPE_MILEAGE = 'Mileage';

    public static final String REIMBURSEMENT_API_NAME = 'Reimbursement__c';
    public static final String REIMBURSEMENT_ASSOCIATION_API_NAME = 'Reimbursement_Association__c';
    public static final String REIMBURSEMENT_TYPE_API_NAME = 'Type__c';
    public static final String REIMBURSEMENT_NUMBER_OF_MINUTES_API_NAME = 'Number_Of_Minutes__c';
    public static final String REIMBURSEMENT_TYPE_1_1_PATIENT_TRAINING = '1:1 Patient Training';
    public static final String REIMBURSEMENT_TYPE_OBSERVATION = 'Observation';

    public static final String STATUS_SUBMITTED = 'Submitted';
    public static final String STATUS_APPROVED = 'Approved';
    public static final String STATUS_PAID = 'Paid';

    public static final String STATUS_DRAFT = 'Draft';

    public static final String CONTACT_POINT_TYPE_PHONE = 'Phone';//added by saikat for tanu's consentservice class
	public static final String CONTACT_POINT_TYPE_EMAIL = 'Email';//added by saikat for tanu's consentservice class
    public static final Integer MINOR_AGE_THRESHOLD = 18;//added by saikat for Charchit's LeadConversionHandler class
    // ContactPoint UsageType Constants
    public static final String CONTACT_POINT_USAGE_TYPE_HOME = 'Home';
    public static final String CONTACT_POINT_USAGE_TYPE_MOBILE = 'Mobile';

    public static final String NULL_STRING = 'null';

    public static final String MY_CERTIFICATION_LISTVIEW = 'My_Certification';
    public static final String CERTIFICATION_APINAME = 'Certification__c';
    public enum MESSAGE_TYPE {
        ERROR,
        WARNING
    }
    public static final String CONTRACT_LIST_PAGE_APINAME = 'Contract_List__c';
    public static final String CONTRACT_LIST_ICON = 'utility:warning';
    public static final String CONTRACT_LIST_WARNING_CLASS= 'cell-warning';
    public static final String CONTRACT_LIST_ERROR_CLASS = 'cell-error';
    
    // Case Notification Constants (NGASIM-2045)
    public static final String CASE_RECORD_TYPE_HCP_UPDATE_REQUEST = 'HCP_Update_Request'; // Created as part of NGASIM-2045
    public static final String CASE_STATUS_CLOSED = 'Closed'; // Created as part of NGASIM-2045
    public static final String CASE_APPROVAL_STATUS_APPROVE = 'Approve'; // Created as part of NGASIM-2045
    public static final String CASE_APPROVAL_STATUS_REJECT = 'Reject'; // Created as part of NGASIM-2045
    public static final String CASE_CLOSURE_NOTIFICATION_TYPE = 'Case_Closure_Notification'; // Created as part of NGASIM-2045
    public static final String CASE_CLOSURE_NOTIFICATION_TITLE = 'Case Closed'; // Created as part of NGASIM-2045
    public static final String CASE_NOTIFICATION_MESSAGE_PREFIX = 'The update you requested for '; // Created as part of NGASIM-2045
    public static final String CASE_NOTIFICATION_MESSAGE_SUFFIX = ' has been '; // Created as part of NGASIM-2045
    public static final String CASE_NOTIFICATION_STATUS_APPROVED = 'Approved'; // Created as part of NGASIM-2045
    public static final String CASE_NOTIFICATION_STATUS_DENIED = 'Denied'; // Created as part of NGASIM-2045
    public static final String CASE_NOTIFICATION_STATUS_PROCESSED = 'processed'; // Created as part of NGASIM-2045
    public static final String SEND_NOTIFICATIONS_SERVICE_TAG = 'SendNotificationsService'; // Created as part of NGASIM-2045
    
    /**
     * @description Returns the CONVERSION_TYPE_MANUAL constant value for use in Lightning Web Components
     * @return String The conversion type value 'Manual'
     */
    @AuraEnabled(cacheable=true)
    public static String getConversionTypeManual() {
        return CONVERSION_TYPE_MANUAL;
    }

    // ASPN Inactivity Alert - Opportunity Stage, Created and Sub Status Field
    public static final String OPPORTUNITY_STAGE_PRIOR_AUTH = 'Prior Auth';
    public static final String OPPORTUNITY_FIELD_SUB_STATUS = 'Sub_Status__c';
    public static final String OPPORTUNITY_FIELD_CREATED = 'Created';

    // ASPN Inactivity Alert - Threshold Values (SubStatus not updated within, business days excluding weekends)
    public static final Integer OPPORTUNITY_ASPN_INACTIVITY_ALERT_THRESHOLD_14_DAYS = 14; // 14 business days when Stage = Prior Auth
    public static final Integer OPPORTUNITY_ASPN_INACTIVITY_ALERT_THRESHOLD_3_DAYS = 3; // 3 business days when Stage != Prior Auth

    public static final String DASH_CONTROLLER_PRODUCT = 'Dash Controller';
    public static final String DASH_PRODUCT = 'DASH';
    public static final String DASH_CONTROLLER_PRODUCT_NDC = '0850820000';
    
    public static final List<String> OPPORTUNITY_SUB_STATUS_CHECK = new List<String>{'Shipped','Sent to Retail Pharmacy','Sent to Retail Pharmacy.','Patient Pick Up'};
}