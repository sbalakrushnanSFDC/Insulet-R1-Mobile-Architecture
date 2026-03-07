/**
* @description Class responsible for fetching DocuSign envelope status events for a given record.
* Runs in 'without sharing' mode as per requirement as we are fetching DocuSign(Installed package) related data.
* US NGOMCT-475
* @author Lokesh P
* @date 2026-01-14

* Version      Modified Date       Modified By                   Brief Note
* V1.0.0       2026-01-14          Lokesh P                      Initial Version(US - NGOMCT-475)
*/

public without sharing class DocusignEnvelopeStatusTimelineController {
    private static final String UNKNOWN_CONFIGURATION = 'Unknown Configuration';

    /**
    * @description fetch the envelope status events.
    * @param recordId The source record Id.
    * @return List of EnvelopeStatusGroup
    */
    @AuraEnabled(cacheable=true)
    public static List<EnvelopeStatusGroup> getEvents(Id recordId) {
        if (recordId == null) {
            return new List<EnvelopeStatusGroup>();
        }

        String sourceId = String.valueOf(recordId);
        try {
            // Test support: allow forcing exception for catch-block coverage
            Utility.throwExceptionForTestCoverage();
            List<dfsle__Envelope__c> envelopes = new List<dfsle__Envelope__c>();

            envelopes = [
                SELECT Id,
                dfsle__SourceId__c,
                dfsle__DocuSignId__c,
                dfsle__EnvelopeConfiguration__r.Name
                FROM dfsle__Envelope__c
                WHERE dfsle__SourceId__c = :sourceId
                AND dfsle__DocuSignId__c != null
                WITH SYSTEM_MODE ORDER BY CreatedDate DESC
            ];

            if (envelopes.isEmpty()) {
                return new List<EnvelopeStatusGroup>();
            }

            Map<String, dfsle__Envelope__c> docIdToEnvelope = new Map<String, dfsle__Envelope__c>();
            Set<String> docuSignIds = new Set<String>();

            // Get the DocuSign IDs from the envelopes
            for (dfsle__Envelope__c env : envelopes) {
                if(env.dfsle__DocuSignId__c != null){
                    docuSignIds.add(env.dfsle__DocuSignId__c);
                    docIdToEnvelope.put(env.dfsle__DocuSignId__c, env);
                }
            }

            // Fetch the statuses for the envelopes
            List<dfsle__EnvelopeStatus__c> statuses = [
                SELECT Id,
                dfsle__Sent__c,
                CreatedDate,
                dfsle__Completed__c,
                Name,
                dfsle__Status__c,
                dfsle__SenderName__c,
                dfsle__SenderEmail__c,
                dfsle__EmailSubject__c,
                dfsle__Expires__c,
                dfsle__Reason__c,
                dfsle__LastStatusUpdate__c,
                dfsle__DocuSignId__c
                FROM dfsle__EnvelopeStatus__c
                WHERE dfsle__DocuSignId__c IN :docuSignIds WITH SYSTEM_MODE
                ORDER BY dfsle__LastStatusUpdate__c DESC, CreatedDate DESC
            ];

            // If no statuses are found, return an empty list
            if(statuses.isEmpty()){
                return new List<EnvelopeStatusGroup>();
            }

            Map<String, EnvelopeStatusGroup> configNameToGroup = new Map<String, EnvelopeStatusGroup>();
            for (dfsle__EnvelopeStatus__c status : statuses) {
                // Get the envelope for the status
                dfsle__Envelope__c envelope = docIdToEnvelope.get(status.dfsle__DocuSignId__c);
                // Get the envelope configuration name
                String configName = (envelope.dfsle__EnvelopeConfiguration__r != null)
                    ? envelope.dfsle__EnvelopeConfiguration__r.Name
                    : UNKNOWN_CONFIGURATION;

                if (!configNameToGroup.containsKey(configName)) {
                    configNameToGroup.put(
                        configName,
                        new EnvelopeStatusGroup(configName, status.dfsle__DocuSignId__c)
                    );
                }
                configNameToGroup.get(configName).statuses.add(status);
            }
            return configNameToGroup.values() ;
        } catch (Exception e) {
            Logger.error('Error while DocuSign status related records', e)
                .addTag('DocusignEnvelopeStatusTimelineController');
            Logger.saveLog();
            throw new AuraHandledException('DocuSign timeline failed to load: ' + e.getMessage());
        }
    }

    /**
    * @description Wrapper class to group and return envelope statuses.
    */
    public class EnvelopeStatusGroup {
        @AuraEnabled public String envelopeConfigName;
        @AuraEnabled public String docusignId;
        @AuraEnabled public List<dfsle__EnvelopeStatus__c> statuses = new List<dfsle__EnvelopeStatus__c>();

        /**
        * @description Constructor of wrapper class.
        * @param name The envelope configuration name.
        * @param docId The DocuSign Id.
        */
        public EnvelopeStatusGroup(String name, String docId) {
            this.envelopeConfigName = name;
            this.docusignId = docId;
        }
    }
}