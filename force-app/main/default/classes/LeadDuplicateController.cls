/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 12th Nov 2025
 * @description : Controller class for Lead duplicate viewer Lightning Web Component
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       12th Nov 2025       Bijayalaxmi Prusty      Initial Version(US - NGASIM-1065)
 */
public with sharing class LeadDuplicateController {

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
     * @description Wrapper class for duplicate match results accessible from LWC
     */
    public class DuplicateMatchResult {
        /**
         * @description Record ID of the duplicate match (Lead or Account)
         */
        @AuraEnabled public Id recordId { get; set; }

        /**
         * @description Object type ('Lead' or 'Account')
         */
        @AuraEnabled public String recordType { get; set; }

        /**
         * @description Matching status ('Full Match', 'Partial Match', 'No Match')
         */
        @AuraEnabled public String matchingStatus { get; set; }

        /**
         * @description Full name (first, middle, last name combined)
         */
        @AuraEnabled public String name { get; set; }

        /**
         * @description Email address
         */
        @AuraEnabled public String email { get; set; }

        /**
         * @description Phone number
         */
        @AuraEnabled public String phone { get; set; }

        /**
         * @description Formatted address string
         */
        @AuraEnabled public String address { get; set; }

        /**
         * @description Record status (Lead records only)
         */
        @AuraEnabled public String status { get; set; }

        /**
         * @description Date of birth
         */
        @AuraEnabled public Date dateOfBirth { get; set; }
    }

    /**
     * @description Gets all duplicate matches (both Leads and Accounts) for a given Lead ID
     * @param leadId The ID of the Lead to find duplicates for
     * @return List of DuplicateMatchResult containing all duplicate matches
     */
    @AuraEnabled(cacheable=true)
    public static List<DuplicateMatchResult> getDuplicateMatches(Id leadId) {
        try {
            if (leadId == null) {
                return new List<DuplicateMatchResult>();
            }

            // Query the current lead with all necessary fields
            Lead currentLead = queryLeadById(leadId);

            // Only process Patient record types
            if (!LeadDuplicateHelper.isEligibleRecordType(currentLead.RecordTypeId)) {
                return new List<DuplicateMatchResult>();
            }

            // Use the helper class to find matching records
            List<LeadDuplicateHelper.MatchingCriteria> allMatches =
                LeadDuplicateHelper.findMatchingRecords(currentLead);

            List<DuplicateMatchResult> duplicateResults = convertToMatchResults(allMatches);

            return filterSignificantMatches(duplicateResults);

        } catch (Exception ex) {
            logError('Failed to get duplicate matches for Lead: ' + leadId, new List<SObject>(), ex);
            return new List<DuplicateMatchResult>();
        }
    }

    /**
     * @description Queries Lead record by ID with all necessary fields
     * @param leadId The Lead ID to query
     * @return Lead record with all required fields
     */
    private static Lead queryLeadById(Id leadId) {
        return [
            SELECT Id, FirstName, MiddleName, LastName, Email, Phone, Street, City, State, PostalCode, Country,
                   Status, LeadSource, RecordTypeId, Date_of_Birth__c
            FROM Lead
            WHERE Id = :leadId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    }

    /**
     * @description Converts matching criteria to duplicate match results
     * @param allMatches List of matching criteria
     * @return List of duplicate match results
     */
    private static List<DuplicateMatchResult> convertToMatchResults(List<LeadDuplicateHelper.MatchingCriteria> allMatches) {
        List<DuplicateMatchResult> duplicateResults = new List<DuplicateMatchResult>();

        for (LeadDuplicateHelper.MatchingCriteria match : allMatches) {
            DuplicateMatchResult result = createDuplicateMatchResult(match);
            if (result != null) {
                duplicateResults.add(result);
            }
        }

        return duplicateResults;
    }

    /**
     * @description Filters out "No Match" records - only returns Full Match and Partial Match
     * @param duplicateResults List of all duplicate results
     * @return Filtered list containing only significant matches
     */
    private static List<DuplicateMatchResult> filterSignificantMatches(List<DuplicateMatchResult> duplicateResults) {
        List<DuplicateMatchResult> filteredResults = new List<DuplicateMatchResult>();

        for (DuplicateMatchResult result : duplicateResults) {
            if (result.matchingStatus != ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH) {
                filteredResults.add(result);
            }
        }

        return filteredResults;
    }

    /**
     * @description Creates a DuplicateMatchResult from a MatchingCriteria
     * @param match MatchingCriteria to convert
     * @return DuplicateMatchResult with populated fields
     */
    private static DuplicateMatchResult createDuplicateMatchResult(LeadDuplicateHelper.MatchingCriteria match) {
        if (match == null || match.record == null) {
            return null;
        }

        DuplicateMatchResult result = new DuplicateMatchResult();
        result.recordId = match.recordId;
        result.recordType = match.recordType;

        // Determine matching status using helper class
        if (LeadDuplicateHelper.isFullMatch(match)) {
            result.matchingStatus = ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH;
        } else {
            Integer matchingFieldCount = LeadDuplicateHelper.countMatchingFields(match);
            result.matchingStatus = matchingFieldCount >= 2 ?
                ConstantsUtil.LEAD_MATCHING_STATUS_PARTIAL_MATCH :
                ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH;
        }

        // Populate fields based on record type
        if (match.recordType == ConstantsUtil.LEAD_OBJECT) {
            Lead leadRecord = (Lead) match.record;
            result.name = buildFullName(leadRecord.FirstName, leadRecord.MiddleName, leadRecord.LastName);
            result.email = leadRecord.Email;
            result.phone = leadRecord.Phone;
            result.address = buildLeadAddress(leadRecord);
            result.status = leadRecord.Status;
            result.dateOfBirth = leadRecord.Date_of_Birth__c;
        } else if (match.recordType == ConstantsUtil.ACCOUNT_OBJECT) {
            Account accountRecord = (Account) match.record;
            result.name = buildFullName(accountRecord.FirstName, accountRecord.MiddleName, accountRecord.LastName);
            result.email = accountRecord.PersonEmail;
            result.phone = accountRecord.Phone;
            result.address = buildAccountAddress(accountRecord);
            result.dateOfBirth = accountRecord.Date_of_Birth__c;
        }

        return result;
    }

    /**
     * @description Builds full name from first, middle, and last name
     * @param firstName First name
     * @param middleName Middle name
     * @param lastName Last name
     * @return Combined full name
     */
    private static String buildFullName(String firstName, String middleName, String lastName) {
        List<String> nameParts = new List<String>();
        if (String.isNotBlank(firstName)) {
            nameParts.add(firstName.trim());
        }
        if (String.isNotBlank(middleName)) {
            nameParts.add(middleName.trim());
        }
        if (String.isNotBlank(lastName)) {
            nameParts.add(lastName.trim());
        }
        return String.join(nameParts, ' ');
    }

    /**
     * @description Builds address string from Lead address fields
     * @param leadRecord Lead record with address fields
     * @return Formatted address string
     */
    private static String buildLeadAddress(Lead leadRecord) {
        List<String> addressParts = new List<String>();

        if (String.isNotBlank(leadRecord.Street)) {
            addressParts.add(leadRecord.Street.trim());
        }
        if (String.isNotBlank(leadRecord.City)) {
            addressParts.add(leadRecord.City.trim());
        }
        if (String.isNotBlank(leadRecord.State)) {
            addressParts.add(leadRecord.State.trim());
        }
        if (String.isNotBlank(leadRecord.PostalCode)) {
            addressParts.add(leadRecord.PostalCode.trim());
        }
        if (String.isNotBlank(leadRecord.Country)) {
            addressParts.add(leadRecord.Country.trim());
        }

        return String.join(addressParts, ', ');
    }

    /**
     * @description Builds address string from Account person address fields
     * @param accountRecord Account record with person address fields
     * @return Formatted address string
     */
    private static String buildAccountAddress(Account accountRecord) {
        List<String> addressParts = new List<String>();

        if (String.isNotBlank(accountRecord.BillingStreet)) {
            addressParts.add(accountRecord.BillingStreet.trim());
        }
        if (String.isNotBlank(accountRecord.BillingCity)) {
            addressParts.add(accountRecord.BillingCity.trim());
        }
        if (String.isNotBlank(accountRecord.BillingState)) {
            addressParts.add(accountRecord.BillingState.trim());
        }
        if (String.isNotBlank(accountRecord.BillingPostalCode)) {
            addressParts.add(accountRecord.BillingPostalCode.trim());
        }
        if (String.isNotBlank(accountRecord.BillingCountry)) {
            addressParts.add(accountRecord.BillingCountry.trim());
        }

        return String.join(addressParts, ', ');
    }
}