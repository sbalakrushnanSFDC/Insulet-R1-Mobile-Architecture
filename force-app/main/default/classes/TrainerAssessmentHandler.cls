/**
 * @author      : Shashank Nigam
 * @created Date: 18th Nov 2025
 * @description : Handler Class for TrainerAssessmentResult LWC.
 * @test Class  : TrainerAssessmentHandlerTest
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       18th Nov 2025       Shashank Nigam          Initial Version (US - NGOMCT-789)
 */
public without sharing class TrainerAssessmentHandler {
    /**
     * @description Creates an Assessment record tied to the provided Certification__c and initializes attempt tracking.
     *              Also calculates Max_Score__c from the assigned question set and sets AssessmentStatus to 'In Progress'.
     *
     * @param certificationId Id of the Certification__c for which an Assessment should be created.
     * @return Id of the newly created Assessment record.
     *
     * @throws AuraHandledException
     * 
     * Behavior:
     * - Queries Certification__c to obtain trainer account, name, and assessment definition.
     * - Computes maximum score based on number of assigned questions in the question set.
     * - Inserts Assessment and increments Certification__c.Number_of_Attempts__c, resets Retake_Exam__c=false.
     * - Returns the Assessment Id for the UI to navigate or continue the flow.
     */
    @Auraenabled public static String createAssessment(String certificationId){ 

        if(String.isBlank(certificationId)){
            throw new AuraHandledException('Certification ID Cannot be null');
        }

        try{
            Certification__c certRecord = [SELECT Id,Certification_Assessment__r.Passing_Percentage__c,
                                           Certification_Assessment__r.Id,Certification_Assessment__r.Assessment_Question_Set__c,
                                           Trainer_Name__c,Name,Number_of_Attempts__c
                                           FROM Certification__c 
                                           WHERE Id = :certificationId 
                                           WITH SYSTEM_MODE LIMIT 1];
            Integer maxScore = [Select id from AssessmentQuestionAssignment where AssessmentQuestionSetId = :certRecord.Certification_Assessment__r.Assessment_Question_Set__c WITH SYSTEM_MODE].size();
            
            Assessment asmtRecord = new Assessment();
            asmtRecord.AccountId = certRecord.Trainer_Name__c;
            asmtRecord.Certification__c = certificationId;
            asmtRecord.Max_Score__c = maxScore;
            asmtRecord.Name =  certRecord.Name;
            asmtRecord.AssessmentStatus = 'In Progress';
            Database.insert(asmtRecord, AccessLevel.SYSTEM_MODE);
            
            certRecord.Number_of_Attempts__c = certRecord.Number_of_Attempts__c + 1;
            
            Database.update(certRecord, AccessLevel.SYSTEM_MODE);
            return asmtRecord.Id;
        }
        catch(Exception e){
            Logger.error('TrainerAssessmentHandler.createAssessment', e);
            Logger.saveLog();
            throw new AuraHandledException('An error occurred while creating assessment record: ' + e.getMessage());
        }
        
    }
    
    /**
     * @description Finalizes an Assessment after completion: evaluates pass/fail based on
     *              Certification_Assessment__r.Passing_Percentage__c, stamps results on both
     *              Assessment and Certification__c, and marks AssessmentStatus as 'Completed'.
     *
     * @param assessmentId Id of the Assessment to finalize.
     * @return true if Assessment passed based on final score; false otherwise.
     *
     * @throws AuraHandledException 
     *
     * Behavior:
     * - Reads Assessment.Final_Score__c and compares to passing percentage on related Certification assessment.
     * - Updates Certification__c fields: Certification_Results__c, Completion_Status__c,
     *   Certification_Date__c (on pass), and Certification_Exam_Score__c.
     * - Updates Assessment.Results__c ('Pass'/'Fail') and AssessmentStatus='Completed'.
     * - Performs a single DML update for both records for efficiency.
     */
    @Auraenabled public static ResultResponseWrapper postSaveAsmtProcessing(String assessmentId){
        List<SObject> recordsToUpdate = new List<SObject>();
        
        if(String.isBlank(assessmentId)){
            throw new AuraHandledException('Assessment ID Cannot be null');
        }

        try {
            Assessment asmtRecord = [SELECT Id,Certification__r.Id,Final_Score__c,Results__c,Total_Response_Value_Score__c 
                                 FROM Assessment 
                                 WHERE Id = :assessmentId WITH SYSTEM_MODE];
        
        Certification__c certRecord = [SELECT Id,Certification_Assessment__r.Passing_Percentage__c,
                                       Certification_Exam_Score__c,Certification_Results__c,
                                       Completion_Status__c,Certification_Date__c,
                                       Number_of_Attempts__c,Retake_Exam__c ,Certification_Test_Name__c 
                                       FROM Certification__c 
                                       WHERE Id = :asmtRecord.Certification__r.Id 
                                       WITH SYSTEM_MODE LIMIT 1];
        
        Boolean result = asmtRecord.Final_Score__c >= certRecord.Certification_Assessment__r.Passing_Percentage__c;
        
        if(result){
            certRecord.Certification_Results__c = 'Passed';
            certRecord.Completion_Status__c = 'Completed';
            certRecord.Certification_Date__c = System.today();
            certRecord.Certification_Exam_Score__c = asmtrecord.Final_Score__c;
            
            
            asmtRecord.Results__c = 'Pass';
        }
        else{
            certRecord.Certification_Results__c = 'Failed';
            certRecord.Completion_Status__c = 'Pending';
            certRecord.Certification_Exam_Score__c = asmtrecord.Final_Score__c;
            
            asmtRecord.Results__c = 'Fail';
        }
        
		asmtRecord.AssessmentStatus = 'Completed';
        certRecord.Retake_Exam__c = false;

        recordsToUpdate.add(certRecord);
        recordsToUpdate.add(asmtRecord);
        
        Database.update(recordsToUpdate, AccessLevel.SYSTEM_MODE);
        ResultResponseWrapper wrapper = new ResultResponseWrapper();
        wrapper.finalScore = asmtRecord.Final_Score__c;
        wrapper.totalQuestionAnswered = asmtRecord.Total_Response_Value_Score__c;
        wrapper.status = result;
        wrapper.certificationName = certRecord.Certification_Test_Name__c;
            
        return wrapper;
        } catch (Exception e) {
            Logger.error('TrainerAssessmentHandler.postSaveAsmtProcessing', e);
            Logger.saveLog();
            throw new AuraHandledException('An error occurred while updating certification record:' + e.getMessage());
        }
        
    }
    /**
     * @description Wrapper class for result response
     *
     */
    public class ResultResponseWrapper{
        @Auraenabled public  Double finalScore;
        @Auraenabled public  Double totalQuestionAnswered;
        @Auraenabled public  Boolean status;
        @Auraenabled public String certificationName;
        
    }
}