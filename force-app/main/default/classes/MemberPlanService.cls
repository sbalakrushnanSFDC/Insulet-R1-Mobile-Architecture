/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 15th Dec 2025
 * @description : Service class for managing MemberPlan records during Lead conversion process
 *  * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.1       15th Dec 2025       Bijayalaxmi Prusty      Initial Version(US - NGOMCT-824)
 * V1.0.2       8th Jan 2026        Bijayalaxmi Prusty      Updated(US - NGOMCT-1550)
 */
public with sharing class MemberPlanService {

    /**
     * @description Cached map of Lead Insurance Type to MemberPlan Insurance Type
     * Key: Lead.Insurance_Type__c value
     * Value: MemberPlan.Type__c value
     */
    private static Map<String, String> insuranceTypeMapping;

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null for permission errors)
     */
    private static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }

    /**
     * @description Creates MemberPlan records from Lead data after successful conversions
     * @param conversionResults List of conversion results from lead conversion
     * @param leadToAccountMap Map of leads to their associated accounts
     * @param tag Optional tag for logging/tracking purposes
     */
    public static void createMemberPlans(List<Database.LeadConvertResult> conversionResults,
                                                 Map<Lead, Account> leadToAccountMap,
                                                 String tag) {
        try {
            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on');
            }

            if (!isValidInput(conversionResults, leadToAccountMap)) {
                return;
            }

            List<MemberPlan> memberPlansToInsert = buildMemberPlansFromLeads(leadToAccountMap);

            if (!memberPlansToInsert.isEmpty()) {
                insertMemberPlans(memberPlansToInsert);
            }

        } catch (Exception ex) {
            List<SObject> leadSObjects = new List<SObject>();
            if (leadToAccountMap != null) {
                for (Lead leadRec : leadToAccountMap.keySet()) {
                    leadSObjects.add(leadRec);
                }
            }
            for (Integer i = 0; i < leadSObjects.size(); i++) {
                logError('Failed to create MemberPlan for Lead at index ' + i + '. Error: ' + ex.getMessage(),
                        new List<SObject>{leadSObjects[i]}, ex);
            }
        }
    }

    /**
     * @description Validates input parameters
     * @param conversionResults List of conversion results
     * @param leadToAccountMap Map of leads to accounts
     * @return true if input is valid, false otherwise
     */
    private static Boolean isValidInput(List<Database.LeadConvertResult> conversionResults,
                                         Map<Lead, Account> leadToAccountMap) {
        return conversionResults != null && !conversionResults.isEmpty() &&
               leadToAccountMap != null && !leadToAccountMap.isEmpty();
    }

    /**
     * @description Builds MemberPlan records from Lead and Account mappings
     * @param leadToAccountMap Map of leads to their associated accounts
     * @return List of MemberPlan records ready for insertion
     */
    private static List<MemberPlan> buildMemberPlansFromLeads(Map<Lead, Account> leadToAccountMap) {
        List<MemberPlan> memberPlansToInsert = new List<MemberPlan>();

        for (Lead lead : leadToAccountMap.keySet()) {
            Account relatedAccount = leadToAccountMap.get(lead);

            if (isValidLeadAndAccount(lead, relatedAccount)) {
                MemberPlan memberPlan = buildMemberPlan(lead, relatedAccount);
                if (memberPlan != null) {
                    memberPlansToInsert.add(memberPlan);
                }
            }
        }

        return memberPlansToInsert;
    }

    /**
     * @description Validates Lead and Account for MemberPlan creation
     * @param lead The Lead record
     * @param account The Account record
     * @return true if valid, false otherwise
     */
    private static Boolean isValidLeadAndAccount(Lead lead, Account account) {
        return account != null && account.Id != null &&
               String.isNotBlank(lead.Insurance_Company_Name__c);
    }



    /**
     * @description Builds a MemberPlan record from Lead data
     * @param lead The source Lead record
     * @param account The associated Account record
     * @return MemberPlan record ready for insertion or null if insufficient data
     */
    private static MemberPlan buildMemberPlan(Lead lead, Account account) {
        MemberPlan memberPlan = new MemberPlan();
        // Required Account association
        memberPlan.MemberId = account.Id;

        // Map Lead.Insurance_Type__c to MemberPlan.Type__c using custom metadata mapping
        // Falls back to original value if no mapping exists
        if (String.isNotBlank(lead.Insurance_Type__c)) {
            String mappedInsuranceType = getMappedInsuranceType(lead.Insurance_Type__c);
            memberPlan.Type__c = String.isNotBlank(mappedInsuranceType)
                ? mappedInsuranceType
                : lead.Insurance_Type__c;
        }

        // Map Lead.Insurance_Company_Name__c to MemberPlan.Name
        // Note: Insurance_Company_Name__c is already validated before calling this method
        memberPlan.Name = lead.Insurance_Company_Name__c;

        return memberPlan;
    }

    /**
     * @description Gets the mapped MemberPlan Insurance Type from Lead Insurance Type using custom metadata
     * @param leadInsuranceType The Lead Insurance Type value
     * @return The mapped MemberPlan Insurance Type, or null if no mapping exists
     */
    @testVisible
    private static String getMappedInsuranceType(String leadInsuranceType) {
        if (String.isBlank(leadInsuranceType)) {
            return null;
        }

        Map<String, String> mapping = getInsuranceTypeMapping();
        return mapping.get(leadInsuranceType);
    }

    /**
     * @description Loads and caches the insurance type mapping from custom metadata
     * @return Map of Lead Insurance Type to MemberPlan Insurance Type
     */
    private static Map<String, String> getInsuranceTypeMapping() {
        if (insuranceTypeMapping == null) {
            insuranceTypeMapping = new Map<String, String>();
           	List<Lead2MemberPlan_InsuranceType_Mapping__mdt> mappings = [
                    SELECT Lead_Insurance_Type__c, MemberPlan_Insurance_Type__c
                    FROM Lead2MemberPlan_InsuranceType_Mapping__mdt
                    WITH USER_MODE
                ];

            for (Lead2MemberPlan_InsuranceType_Mapping__mdt mapping : mappings) {
                if (String.isNotBlank(mapping.Lead_Insurance_Type__c) &&
                    String.isNotBlank(mapping.MemberPlan_Insurance_Type__c)) {
                        insuranceTypeMapping.put(
                            mapping.Lead_Insurance_Type__c,
                            mapping.MemberPlan_Insurance_Type__c
                        );
                    }
            }
        }

        return insuranceTypeMapping;
    }

    /**
     * @description Inserts MemberPlan records
     * @param memberPlansToInsert List of MemberPlan records to insert
     */
    private static void insertMemberPlans(List<MemberPlan> memberPlansToInsert) {
        if(!memberPlansToInsert.isEmpty()){
            Database.insert(memberPlansToInsert, false, AccessLevel.USER_MODE);
        }
    }

    /**
     * @description Exception class for Member Plan Service
     */
    public class MyCustomException extends Exception {}
}