/**
 * @author      : Shashank Nigam
 * @created Date: 18th Nov 2025
 * @description : Trigger for AssessmentQuestionResponse Object.
 * @test Class  : TrainerAssessmentHandlerTest
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       18th Nov 2025       Shashank Nigam          Initial Version (US - NGOMCT-789)
 */
trigger AssessmentQuestionResponseTrigger on AssessmentQuestionResponse (before insert) {
	new AssessmentQuestionResponseTriggerHandler().execute();
}