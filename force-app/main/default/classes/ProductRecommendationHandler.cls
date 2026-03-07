/**
 * @author      : Ramesh Dhaka
 * @created Date: 6th Oct 2025
 * @description : Product Recommendation Engine controller class
 * Determines which leads are eligible for product recommendation and invokes the service class.
 * @story Number: NGOMCT-202
 * =========================== Logs ==============================
 * Version      Modified Date       Modified By         Brief Note
 * V1.0.0       06th Oct 2025       Ramesh Dhaka        Initial Version
 * V1.1.0       15th Oct 2025       Ramesh Dhaka        Updated(US - NGOMCT-508)
 */
public inherited sharing class ProductRecommendationHandler {
    /**
     * @description Determines which leads are eligible for product recommendation
     * @param newLeads The list of Lead records to process.
     * @param oldMap The map of old Lead records.
     */
	public static void processProductRecommendations(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        try{
            /** if no lead is supplied in the method then exit the method */
            if (newLeads == null || newLeads.isEmpty()) {
                return;
            }
            /** if lead list isn't empty then iterate over to find eligible records */
            List<Lead> leadsToProcess = new List<Lead>();
            for (Lead currentLead : newLeads) {
                if (isEligible(currentLead, oldMap?.get(currentLead.Id))) {
                    leadsToProcess.add(currentLead);
                }
            }
            /** when leadToProcess list is not empty then call recommendation engine */
            if (!leadsToProcess.isEmpty()) {
                ProductRecommendationService.assignRecommendedProduct(leadsToProcess);
            }
            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new MyCustomException('customExceptionSwitch is turned on');
            }
        }catch(Exception e){
            Logger.error('Error While recommending Product',newLeads, e).addTag('ProductRecommendationEngine');
            Logger.saveLog();
        }
    }

    /**
     * @description Determines if a lead is eligible for product recommendation.
     * @param newLead The new Lead record.
     * @param oldLead The old Lead record.
     * @return Boolean True if the lead is eligible, false otherwise.
     */
    private static Boolean isEligible(Lead newLead, Lead oldLead) {
        Boolean meetsBaselineCriteria = newLead.RecordTypeId == ConstantsUtil.LEAD_PATIENT_RT &&
                                        !((ConstantsUtil.PROD_RECOMMEND_NOT_ELIGIBLE_LEADSOURCE).contains(newLead.LeadSource)) &&
                                        newLead.Date_of_Birth__c != null &&
                                        newLead.Type_of_Diabetes__c != null;
        if (!meetsBaselineCriteria) {
            // If the record doesn't even meet the basic requirements, stop here.
            return false;
        }
        // Differentiate between Insert and Update
        if (oldLead == null) {
            // For a new record, if it meets the baseline criteria, it's eligible.
            return true;
        }else {
            // Update Event SCENARIO 1: Check if the user manually changed the recommended product.
            if (newLead.Recommended_Product__c != oldLead.Recommended_Product__c && newLead.Recommended_Product__c != null) {
                return false;
            }

            // Update Event SCENARIO 2: Check if one of the key input fields has changed.
            Boolean hasRelevantInputChange = String.isBlank(newLead.Recommended_Product__c) && (newLead.Type_of_Diabetes__c != oldLead.Type_of_Diabetes__c ||
                                            newLead.Sensor_CGM_Continuous_Glucose_Monitor__c != oldLead.Sensor_CGM_Continuous_Glucose_Monitor__c ||
                                            newLead.Date_of_Birth__c != oldLead.Date_of_Birth__c);
            return hasRelevantInputChange;
        }
    }

    /**
     * @description Exception class for Product Recommendation Engine
     */
    public class MyCustomException extends Exception {}
}