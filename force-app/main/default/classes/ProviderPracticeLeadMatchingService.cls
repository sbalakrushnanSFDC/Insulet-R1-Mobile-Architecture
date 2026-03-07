/**
 * @author      : Bijayalaxmi Prusty
 * @created Date: 10th Dec 2025
 * @description : Service class for Provider and Practice Lead Matching logic
 * @story Number: NGASIM-368
 * * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * v1.0.0       10th Dec 2025       Bijayalaxmi Prusty            Initial Version(US - NGASIM-368)
 */
public inherited sharing class ProviderPracticeLeadMatchingService {

    /**
     * @description Logs error messages with context using Logger framework
     * @param message The error message
     * @param records List of SObject records related to the error
     * @param ex Exception object (can be null)
     */
    private static void logError(String message, List<SObject> records, Exception ex) {
        Logger.error(message, records, ex)
            .addTag(ConstantsUtil.ASIM_TAG);
        Logger.saveLog();
    }


    /**
     * @description Main method to process Provider Practice Lead matching
     * @param newLeads List of new Lead records
     * @param oldLeadsMap Map of old Lead records (null for insert)
     */
    public static void processProviderPracticeMatching(List<Lead> newLeads, Map<Id, Lead> oldLeadsMap) {
        try {
            if (newLeads == null || newLeads.isEmpty()) {
                return;
            }

            /**
             * when customExceptionSwitch static variable is turned on
             * it covers exceptions in test coverage
             */
            if(ConstantsUtil.customExceptionSwitch && Test.isRunningTest()){
                throw new ProviderPracticeMatchingException('customExceptionSwitch is turned on');
            }

            // Filter Provider Practice Leads that need processing
            List<Lead> leadsToProcess = filterProviderPracticeLeads(newLeads, oldLeadsMap);

            if (leadsToProcess.isEmpty()) {
                return;
            }

            // Process matching logic
            processMatching(leadsToProcess);

        } catch (Exception ex) {
            List<SObject> leadSObjects = new List<SObject>();
            leadSObjects.addAll(newLeads);
            for (Integer i = 0; i < leadSObjects.size(); i++) {
                logError('Failed to process Lead at index ' + i + ' during Provider Practice matching. Errors: ' + ex.getMessage(),
                            new List<SObject>{leadSObjects[i]}, ex);
            }
        }
    }

    /**
     * @description Filters leads that need Provider Practice matching
     * @param newLeads List of new Lead records
     * @param oldLeadsMap Map of old Lead records
     * @return List of leads that need processing
     */
    private static List<Lead> filterProviderPracticeLeads(List<Lead> newLeads, Map<Id, Lead> oldLeadsMap) {
        List<Lead> leadsToProcess = new List<Lead>();

        for (Lead lead : newLeads) {
            // Only process Provider Practice Lead record type
            if (lead.RecordTypeId != ConstantsUtil.LEAD_PROVIDERPRACTICE_RT) {
                continue;
            }

            // For insert, process all Provider Practice leads
            if (oldLeadsMap == null) {
                leadsToProcess.add(lead);
                continue;
            }

            // For update, process if relevant fields changed
            Lead oldLead = oldLeadsMap.get(lead.Id);
            if (oldLead != null && hasRelevantFieldsChanged(lead, oldLead)) {
                leadsToProcess.add(lead);
            }
        }
        return leadsToProcess;
    }

    /**
     * @description Checks if relevant fields for matching have changed
     * @param newLead New Lead record
     * @param oldLead Old Lead record
     * @return True if relevant fields changed
     */
    private static Boolean hasRelevantFieldsChanged(Lead newLead, Lead oldLead) {
        return ((String)newLead.get(ConstantsUtil.LEAD_NPI) != (String)oldLead.get(ConstantsUtil.LEAD_NPI) ||
                (String)newLead.get(ConstantsUtil.LEAD_PRACTICE_NAME) != (String)oldLead.get(ConstantsUtil.LEAD_PRACTICE_NAME) ||
                (String)newLead.get(ConstantsUtil.LEAD_STREET) != (String)oldLead.get(ConstantsUtil.LEAD_STREET) ||
                (String)newLead.get(ConstantsUtil.LEAD_CITY) != (String)oldLead.get(ConstantsUtil.LEAD_CITY) ||
                (String)newLead.get(ConstantsUtil.LEAD_STATE) != (String)oldLead.get(ConstantsUtil.LEAD_STATE));
    }

    /**
     * @description Main processing method for matching logic
     * @param leadsToProcess List of leads to process
     */
    private static void processMatching(List<Lead> leadsToProcess) {
        // Collect NPIs and Practice keys for query
        Set<String> npiSet = new Set<String>();
        Set<String> practiceNames = new Set<String>();

        for (Lead lead : leadsToProcess) {
            String npi = (String)lead.get(ConstantsUtil.LEAD_NPI);
            if (String.isNotBlank(npi)) {
                npiSet.add(npi);
            }

            String practiceName = (String)lead.get(ConstantsUtil.LEAD_PRACTICE_NAME);
            if (String.isNotBlank(practiceName)) {
                practiceNames.add(practiceName);
            }
        }

        // Query existing accounts
        Map<String, Account> accountsMap = queryExistingAccounts(npiSet, practiceNames);

        // Update matching status for all leads
        updateMatchingStatus(leadsToProcess, accountsMap);
    }

    /**
     * @description Query existing Provider and Practice accounts in single query
     * @param npiSet Set of NPIs to search for Provider accounts
     * @param practiceNames Set of Practice names to search for Practice accounts
     * @return Map of identifier to Account record
     */
    private static Map<String, Account> queryExistingAccounts(Set<String> npiSet, Set<String> practiceNames) {
        Map<String, Account> accountsMap = new Map<String, Account>();

        try {
            // Use proper bind variables for RecordType IDs
            Id providerRecordTypeId = ConstantsUtil.ACCOUNT_PROVIDER_RT;
            Id practiceRecordTypeId = ConstantsUtil.ACCOUNT_PRACTICE_RT;

            // Query matching Provider and Practice accounts based on NPI and Name criteria
            String queryFields = 'SELECT Id, RecordTypeId, ' +
                               String.escapeSingleQuotes(ConstantsUtil.ACCOUNT_CUSTOM_UNIQUE_ID) + ', ' +
                               String.escapeSingleQuotes(ConstantsUtil.ACCOUNT_NAME) + ', ' +
                               String.escapeSingleQuotes(ConstantsUtil.ACCOUNT_BILLING_STREET) + ', ' +
                               String.escapeSingleQuotes(ConstantsUtil.ACCOUNT_BILLING_CITY) + ', ' +
                               String.escapeSingleQuotes(ConstantsUtil.ACCOUNT_BILLING_STATE) + ', ' +
                               String.escapeSingleQuotes(ConstantsUtil.ACCOUNT_BILLING_STATE_CODE);

            String queryWhere = ' FROM Account WHERE (' +
                              'RecordTypeId = :providerRecordTypeId AND ' +
                              String.escapeSingleQuotes(ConstantsUtil.ACCOUNT_CUSTOM_UNIQUE_ID) + ' IN :npiSet) OR (' +
                              'RecordTypeId = :practiceRecordTypeId AND ' +
                              String.escapeSingleQuotes(ConstantsUtil.ACCOUNT_NAME) + ' IN :practiceNames) WITH SYSTEM_MODE';

            List<Account> accounts = Database.query(queryFields + queryWhere);//NOPMD (escaped single quotes for all passed variable , static code analysis is giving false positive error)

            for (Account account : accounts) {
                if (account.RecordTypeId == ConstantsUtil.ACCOUNT_PROVIDER_RT &&
                    String.isNotBlank((String)account.get(ConstantsUtil.ACCOUNT_CUSTOM_UNIQUE_ID))) {
                    // Provider account - key by NPI
                    String uniqueId = (String)account.get(ConstantsUtil.ACCOUNT_CUSTOM_UNIQUE_ID);
                    accountsMap.put(uniqueId, account);
                } else if (account.RecordTypeId == ConstantsUtil.ACCOUNT_PRACTICE_RT) {
                    // Practice account - use Name as key
                    String accountName = (String)account.get(ConstantsUtil.ACCOUNT_NAME);
                    accountsMap.put(accountName, account);
                }
            }

        } catch (Exception ex) {
            logError('Error querying existing accounts', new List<SObject>(), ex);
        }

        return accountsMap;
    }

    /**
     * @description Update matching status for all leads
     * @param leadsToProcess List of leads to update
     * @param accountsMap Map of existing accounts
     */
    private static void updateMatchingStatus(List<Lead> leadsToProcess, Map<String, Account> accountsMap) {
        // Create account matching keys maps
        Map<String, Account> providerKeyMap = new Map<String, Account>();
        Map<String, Account> practiceKeyMap = new Map<String, Account>();

        // Generate account matching keys
        for (Account account : accountsMap.values()) {
            if (account.RecordTypeId == ConstantsUtil.ACCOUNT_PROVIDER_RT) {
                String providerKey = generateAccountProviderKey(account);
                if (String.isNotBlank(providerKey)) {
                    providerKeyMap.put(providerKey, account);
                }
            } else if (account.RecordTypeId == ConstantsUtil.ACCOUNT_PRACTICE_RT) {
                String practiceKey = generateAccountPracticeKey(account);
                if (String.isNotBlank(practiceKey)) {
                    practiceKeyMap.put(practiceKey, account);
                }
            }
        }

        // Process each lead
        for (Lead lead : leadsToProcess) {
            // Provider matching using keys
            String leadProviderKey = generateLeadProviderKey(lead);
            if (String.isNotBlank(leadProviderKey)) {
                if (providerKeyMap.containsKey(leadProviderKey)) {
                    lead.put(ConstantsUtil.LEAD_PROVIDER_MATCHING_STATUS, ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH);
                } else {
                    lead.put(ConstantsUtil.LEAD_PROVIDER_MATCHING_STATUS, ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH);
                }
            }

            // Practice matching using keys
            String leadPracticeKey = generateLeadPracticeKey(lead);
            if (String.isNotBlank(leadPracticeKey)) {
                if (practiceKeyMap.containsKey(leadPracticeKey)) {
                    lead.put(ConstantsUtil.LEAD_PRACTICE_MATCHING_STATUS, ConstantsUtil.LEAD_MATCHING_STATUS_FULL_MATCH);
                } else {
                    lead.put(ConstantsUtil.LEAD_PRACTICE_MATCHING_STATUS, ConstantsUtil.LEAD_MATCHING_STATUS_NO_MATCH);
                }
            }
        }
    }

    /**
     * @description Generate provider matching key for Lead
     * @param lead Lead record
     * @return String provider key or null if insufficient data
     */
    private static String generateLeadProviderKey(Lead lead) {
        String npi = (String)lead.get(ConstantsUtil.LEAD_NPI);
        if (String.isBlank(npi)) {
            return null;
        }
        return npi.toLowerCase().trim();
    }

    /**
     * @description Generate provider matching key for Account
     * @param account Account record
     * @return String provider key or null if insufficient data
     */
    @TestVisible
    private static String generateAccountProviderKey(Account account) {
        String customUniqueId = (String)account.get(ConstantsUtil.ACCOUNT_CUSTOM_UNIQUE_ID);
        if (String.isBlank(customUniqueId)) {
            return null;
        }
        return customUniqueId.toLowerCase().trim();
    }

    /**
     * @description Generate practice matching key for Lead
     * @param lead Lead record
     * @return String practice key or null if insufficient data
     */
    private static String generateLeadPracticeKey(Lead lead) {
        String practiceName = (String)lead.get(ConstantsUtil.LEAD_PRACTICE_NAME);

        // Only practice name is required
        if (String.isBlank(practiceName)) {
            return null;
        }

        // Start with normalized name
        List<String> keyParts = new List<String>{practiceName.toLowerCase().trim()};

        // Get optional fields
        String leadState = getLeadStateValue(lead);
        String street = (String)lead.get(ConstantsUtil.LEAD_STREET);
        String city = (String)lead.get(ConstantsUtil.LEAD_CITY);

        // Add available fields to key
        if (String.isNotBlank(leadState)) {
            keyParts.add(leadState.toLowerCase().trim());
        }
        if (String.isNotBlank(street)) {
            keyParts.add(street.toLowerCase().trim());
        }
        if (String.isNotBlank(city)) {
            keyParts.add(city.toLowerCase().trim());
        }

        return String.join(keyParts, '|');
    }

    /**
     * @description Generate practice matching key for Account
     * @param account Account record
     * @return String practice key or null if insufficient data
     */
    @TestVisible
    private static String generateAccountPracticeKey(Account account) {
        String accountName = (String)account.get(ConstantsUtil.ACCOUNT_NAME);

        // Only account name is required
        if (String.isBlank(accountName)) {
            return null;
        }

        // Start with normalized name
        List<String> keyParts = new List<String>{accountName.toLowerCase().trim()};

        // Get optional fields
        String accountState = getAccountStateValue(account);
        String street = (String)account.get(ConstantsUtil.ACCOUNT_BILLING_STREET);
        String city = (String)account.get(ConstantsUtil.ACCOUNT_BILLING_CITY);

        // Add available fields to key
        if (String.isNotBlank(accountState)) {
            keyParts.add(accountState.toLowerCase().trim());
        }
        if (String.isNotBlank(street)) {
            keyParts.add(street.toLowerCase().trim());
        }
        if (String.isNotBlank(city)) {
            keyParts.add(city.toLowerCase().trim());
        }

        return String.join(keyParts, '|');
    }


    /**
     * @description Gets state value from Lead - prefers StateCode, falls back to State
     * @param lead Lead record
     * @return String state value
     */
    private static String getLeadStateValue(Lead lead) {
        String stateCode = (String)lead.get(ConstantsUtil.LEAD_STATE_CODE);
        if (String.isNotBlank(stateCode)) {
            return stateCode;
        }
        return (String)lead.get(ConstantsUtil.LEAD_STATE);
    }

    /**
     * @description Gets state value from Account - prefers BillingStateCode, falls back to BillingState
     * @param account Account record
     * @return String state value
     */
    @TestVisible
    private static String getAccountStateValue(Account account) {
        String billingStateCode = (String)account.get(ConstantsUtil.ACCOUNT_BILLING_STATE_CODE);
        if (String.isNotBlank(billingStateCode)) {
            return billingStateCode;
        }
        return (String)account.get(ConstantsUtil.ACCOUNT_BILLING_STATE);
    }

    /**
     * @description Custom exception class for Provider Practice Lead Matching Service
     */
    public class ProviderPracticeMatchingException extends Exception {}
}