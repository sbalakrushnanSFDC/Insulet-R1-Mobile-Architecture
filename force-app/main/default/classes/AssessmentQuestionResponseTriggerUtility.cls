/**
 * @author      : Shashank Nigam
 * @created Date: 18th Nov 2025
 * @description : Utility methods to support AssessmentQuestionResponse trigger processing.
 *                Provides scoring logic and response matching helpers.
 * @test Class  : TrainerAssessmentHandlerTest
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       18th Nov 2025       Shashank Nigam          Initial Version (US - NGOMCT-789)
 */
public with sharing class AssessmentQuestionResponseTriggerUtility {
    
    /**
     * @description Calculates and sets ResponseValueScore for each AssessmentQuestionResponse in the input list.
     *              For each response, determines whether to evaluate free-text (ResponseText) or choice value (ChoiceValue)
     *              against the corresponding AssessmentQuestionVersion.Correct_Response_Values__c.
     *
     * @param recordList List of AssessmentQuestionResponse records to score. Expected to be trigger-level NEW records.
     *
     * @remarks
     * - Bulkified: Performs a single SOQL query using the AssessmentQuestionId keys and does not do DML.
     * - Mutates in-memory records only; caller (trigger/handler) is responsible for persisting updates.
     * - Matching logic allows semicolon-delimited multi-select style comparisons via matchResponse(...).
     *
     * @example
     * // In trigger context:
     * // AssessmentQuestionResponseTriggerUtility.calculateScore(Trigger.new);
     */
    public static void calculateScore(List<AssessmentQuestionResponse> recordList){
        Map<Id,AssessmentQuestionResponse> questionVsResponseMap = new Map<Id,AssessmentQuestionResponse>();
        try{
            if(recordList.isEmpty()){
            	throw new ListException('Null input');
        	}
            for(AssessmentQuestionResponse response : recordList){
                questionVsResponseMap.put(response.AssessmentQuestionId,response);
            }
            for(AssessmentQuestionVersion q : [Select id,Correct_Response_Values__c from AssessmentQuestionVersion where id in :questionVsResponseMap.keySet() WITH SYSTEM_MODE]){
                if(String.isEmpty(questionVsResponseMap.get(q.id).ResponseText)){  
                    questionVsResponseMap.get(q.id).ResponseValueScore = matchResponse(questionVsResponseMap.get(q.id).ChoiceValue,q.Correct_Response_Values__c) ? 1 : 0;
                }
                else{
                    questionVsResponseMap.get(q.id).ResponseValueScore = matchResponse(questionVsResponseMap.get(q.id).ResponseText,q.Correct_Response_Values__c) ? 1 : 0;
                }
            }
        }
        catch(Exception e){
            Logger.error('Error while calculating score for AssessmentQuestionResponse',recordList,e).addTag('AssessmentQuestionResponseTriggerUtility');
            Logger.saveLog();
        }
    }	
    
    /**
     * @description Compares a provided response value (single or semicolon-delimited list) against a set of
     *              correct answers (semicolon-delimited), returning true only if every provided response token
     *              exists in the set of correct answers.
     *
     * @param response The user-provided response value(s). Semicolon-delimited when multiple selections are present.
     * @param correctAnswer The correct answer value(s) from the question version. Semicolon-delimited for multiple.
     * @return Boolean True if all response tokens are contained within the correct answer set; otherwise false.
     *
     * @remarks
     * - Null/empty safety: Returns false when either input is blank.
     * - Whitespace sensitivity: Tokens are compared exactly as split by ';'. Ensure upstream values are normalized if needed.
     * - Test visibility: @testVisible for direct unit testing of matching behavior.
     *
     * @example
     * // matchResponse('A;B', 'A;B;C') -> true
     * // matchResponse('A;D', 'A;B;C') -> false
     */
    @testVisible
    public static Boolean matchResponse(String response,String correctAnswer){
        if(String.isEmpty(response) || String.isEmpty(correctAnswer)){
            return False;
        }
        Set<String> stringList = new Set<String>(correctAnswer.split(';'));
        for(String s : response.split(';')){
            if(!stringList.contains(s)){
                return false;
            }
        }
        return true;
    }
}