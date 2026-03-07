/**
 * @author      : Rohan Saxena
 * @created Date: 20th Nov 2025
 * @description : This class provide Certification and its related object data.
 */
public without sharing class TakeExamCmpController {
   /**
   * @description Method to get Certification record.
   * @param certificationId Id of Certification.
   *  @return Certification record.
   */
    @AuraEnabled(cacheable=false)
    public static Certification__c getCertification(Id certificationId) {
        List<Certification__c> lstCertification = [
            SELECT Id, Retake_Exam__c, Completion_Status__c, Certification_Results__c, Product__c
            FROM Certification__c
            WHERE Id = :certificationId
            WITH USER_MODE
        ];
        if (!lstCertification.isEmpty()) {
            return lstCertification[0];
        }
        return null;
    }

    /**
   * @description Method to get Certification related omni data.
   * @param certificationId Id of Certification.
   * @return Certification record.
   */
    @AuraEnabled(cacheable=true)
    public static Certification__c getCertificationRelatedOmniscript(Id certificationId) {
        List<Certification__c> lstCertification = [
            SELECT Id,
                   Certification_Assessment__r.OmniProcess.Type,
                   Certification_Assessment__r.OmniProcess.SubType,
                   Certification_Assessment__r.OmniProcess.Language,
                   Certification_Assessment__r.OmniProcess.Name,
                   Certification_Assessment__r.Assessment_Question_Set__c
            FROM Certification__c
            WHERE Id = :certificationId WITH SYSTEM_MODE
        ];
        if (!lstCertification.isEmpty()) {
            return lstCertification[0];
        }
        return null;
    }
}