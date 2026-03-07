/**
 * @author      : Ramesh Dhaka
 * @created Date: 6th Oct 2025
 * @description : Product Recommendation Engine core class, responsible for assigning the recommended product to a lead.
 * @story Number: NGOMCT-202
 * =========================== Logs ==============================
 * Version      Modified Date       Modified By            Brief Note
 * V1.0.0       6th Oct 2025        Ramesh Dhaka           Initial Version
 */
public inherited sharing class ProductRecommendationService {
    /**
     * @description Main method to assign the recommended product to a list of leads.
     * @param leads The list of Lead records to process.
     */
    public static void assignRecommendedProduct(List<Lead> leads) {
        Map<String, String> recommendationMap = buildRecommendationMap();
        if (recommendationMap.isEmpty()) {
            Logger.debug('Could not find any active product recommendation matrix cmdt record').addTag('ProductRecommendationEngine');
            Logger.saveLog();
            return;
        }

        for (Lead l : leads) {
            String ageCategory = calculateAgeCategory(l.Date_of_Birth__c, l.Type_of_Diabetes__c);
            String sensorCGM =  ageCategory?.contains('Under') ? null : l.Sensor_CGM_Continuous_Glucose_Monitor__c;
            String lookupKey = buildLookupKey(ageCategory,l.Type_of_Diabetes__c,sensorCGM);
            if (recommendationMap.containsKey(lookupKey)) {
                l.Recommended_Product__c = recommendationMap.get(lookupKey);
            }
        }
    }

    /**
     * @description Queries active metadata records and builds a map for quick lookups.
     * @return Map<String, String> A map where the key is the criteria and the value is the product name.
     */
    @TestVisible
    private static Map<String, String> buildRecommendationMap() {
        Map<String, String> matrix = new Map<String, String>();
        List<Product_Recommendation_Matrix__mdt> activeRules;
        if(!(ConstantsUtil.customExceptionSwitch && Test.isRunningTest())){
            activeRules = [
                SELECT Age__c, Type_of_Diabetes__c, Sensor_CGM__c, Recommended_Product__c
                FROM Product_Recommendation_Matrix__mdt
                WHERE IsActive__c = true WITH SYSTEM_MODE
            ];

            for (Product_Recommendation_Matrix__mdt rule : activeRules) {
                String key = buildLookupKey(rule.Age__c, rule.Type_of_Diabetes__c, rule.Sensor_CGM__c);
                matrix.put(key, rule.Recommended_Product__c);
            }
        }
        return matrix;
    }

    /**
     * @description Calculates the age category string based on DOB and diabetes type.
     * @param dob The lead's date of birth.
     * @param diabetesType The lead's type of diabetes.
     * @return String The calculated age category.
     */
    @TestVisible
    private static String calculateAgeCategory(Date dob, String diabetesType) {
        Integer ageInYears = dob.monthsBetween(Date.today()) / 12;
        if (diabetesType == ConstantsUtil.DIABETES_TYPE_1 || diabetesType == ConstantsUtil.DIABETES_OTHER) {
            return (ageInYears < 2) ? ConstantsUtil.AGE_UNDER_2 : ConstantsUtil.AGE_2_PLUS;
        } else if (diabetesType == ConstantsUtil.DIABETES_TYPE_2_INSULIN) {
            return (ageInYears < 18) ? ConstantsUtil.AGE_UNDER_18 : ConstantsUtil.AGE_18_PLUS;
        }
        Logger.debug('Calculated Age Category is Null as did not match any of the given condition').addTag('ProductRecommendationEngine');
        Logger.saveLog();
        return null;
    }

    /**
     * @description Creates a consistent, unique key from the three criteria fields.
     * @param age The patient's calculated age
     * @param diabetesType The patient's diabetes type
     * @param sensorCGM CGM sensor used by patient
     * @return String A concatenated key for map lookups.
     */
    @TestVisible
    private static String buildLookupKey(String age, String diabetesType, String sensorCGM) {
        return age+'|'+diabetesType+'|'+sensorCGM;
    }
}