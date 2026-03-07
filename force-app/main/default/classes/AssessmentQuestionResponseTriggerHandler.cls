/**
 * @author      : Shashank Nigam
 * @created Date: 18th Nov 2025
 * @description : Handles all trigger logic for the Assessment Question Response object
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       18th NOV 2025       Shashank Nigam          Initial Version(US - NGOMCT-789)
 *
*/
public with sharing class AssessmentQuestionResponseTriggerHandler extends TriggerHandler {
	/**
     * @description Handles the before insert trigger logic for the Assessment Question Response object
     * @param newRecords The list of new Lead records
     */
    public override void beforeInsert(List<SObject> newRecords){
        List<AssessmentQuestionResponse> responseList = (List<AssessmentQuestionResponse>) newRecords;
        AssessmentQuestionResponseTriggerUtility.calculateScore(responseList);
    }
}