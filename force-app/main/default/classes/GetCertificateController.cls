/**
 * @author      : Ankur Chauhan
 * @created Date: 1st Nov 2025
 * @description : Controller class to support Get Certificate button.
 * @story Number: NGOMCT-847
 */
public with sharing class GetCertificateController {
    /**
     * @description Method to get Conga Template Id.
     * @param templateName Name of the Conga Template.
     * @return Map of Conga Template Id.
    */
    @AuraEnabled(cacheable=true)
    public static Map<String, Id> getCongaTemplateId(String templateName) {
        try{
            if (String.isBlank(templateName)) {
                return null;
            }

            APXTConga4__Conga_Template__c templateRecord = [SELECT Id, APXTConga4__Name__c FROM APXTConga4__Conga_Template__c WHERE APXTConga4__Name__c = :templateName WITH USER_MODE LIMIT 1];

            Map<String, Id> returnMap = new Map<String, Id>();
            returnMap.put('templateId', templateRecord?.Id);
            return returnMap;
        }
        catch(Exception e){
            Logger.error('Error while accessing template record', e)
                .addTag('GetCertificateController');
            Logger.saveLog();
            throw new AuraHandledException(e.getMessage());
        }
    }
}