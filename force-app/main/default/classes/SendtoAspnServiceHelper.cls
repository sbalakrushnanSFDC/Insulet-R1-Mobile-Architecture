/**
 * @author      : Priyansh Shukla
 * @description : Helper class responsible for querying all data needed for ASPN integration
 *                Extracted from SendtoAspnService to reduce complexity
 * @created Date: 27th Jan 2026
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       27th Jan 2026       Priyansh Shukla    Initial Version(NGOMCT-1356)
 * V1.0.1       18th Feb 2026       Saikat Ghosh       Updated(NGASIM-2347) - Prefer Primary Mobile over Primary Phone for ASPN outbound
 */
public inherited sharing class SendtoAspnServiceHelper {
    /**
     * @description Queries all related data needed for ASPN integration
     * @param accountIds Set of Account IDs
     * @param opptyIdsSet Set of Opportunity IDs
     * @return AspnDataContext containing all queried data
     */
    public static SendtoAspnService.AspnDataContext queryRelatedData(Set<Id> accountIds, Set<Id> opptyIdsSet) {
        SendtoAspnService.AspnDataContext dataContext = new SendtoAspnService.AspnDataContext();

        // Query Account records and build maps
        queryAccountData(accountIds, dataContext);

        // Query Contact Point records
        queryContactPointData(accountIds, dataContext);

        // Query Provider relationships
        queryProviderData(dataContext);

        // Query Identifiers
        queryIdentifierData(accountIds, dataContext);

        // Query Practice relationships
        queryPracticeData(dataContext);

        // Query Opportunity Line Items
        queryOpportunityLineItems(opptyIdsSet, dataContext);

        // Query Contact Point Type Consent records
        queryContactPointTypeConsentData(dataContext);

        return dataContext;
    }

    /**
     * @description Queries Account data and builds related maps
     * @param accountIds Set of Account IDs
     * @param dataContext Data context to populate
     */
    private static void queryAccountData(Set<Id> accountIds, SendtoAspnService.AspnDataContext dataContext) {
        List<Account> accounts = [
            SELECT Id, FirstName, LastName, PersonGenderIdentity, Custom_UniqueID__c,
                   Date_of_Birth__c, Type_of_Diabetes__c, Preferred_Language__c, PersonContactId, PersonIndividualId
            FROM Account
            WHERE Id IN :accountIds WITH USER_MODE
        ];

        for (Account acc : accounts) {
            dataContext.accountMap.put(acc.Id, acc);
            if (acc.PersonContactId != null) {
                dataContext.personContactIdsSet.add(acc.PersonContactId);
                dataContext.accountPersonContactIdMap.put(acc.Id, acc.PersonContactId);
            }
            if (acc.PersonIndividualId != null) {
                dataContext.individualIdsSet.add(acc.PersonIndividualId);
                dataContext.accountIndividualIdMap.put(acc.Id, acc.PersonIndividualId);
            }
        }
    }

    /**
     * @description Queries Contact Point data for patients
     * @param accountIds Set of Account IDs
     * @param dataContext Data context to populate
     */
    private static void queryContactPointData(Set<Id> accountIds, SendtoAspnService.AspnDataContext dataContext) {
        List<ContactPointEmail> cpEmailList = [
            SELECT Id, ParentId, EmailAddress
            FROM ContactPointEmail
            WHERE ParentId IN :accountIds
            AND IsPrimary = true
            AND EmailAddress != NULL WITH SYSTEM_MODE
        ];

        List<ContactPointPhone> cpPhoneList = [
            SELECT Id, ParentId, TelephoneNumber, UsageType // Added UsageType as part of NGASIM-2347
            FROM ContactPointPhone
            WHERE ParentId IN :accountIds
            AND IsPrimary = true
            AND UsageType!= NULL // Added UsageType condition as part of NGASIM-2347
            AND TelephoneNumber != NULL WITH SYSTEM_MODE
        ];

        List<ContactPointAddress> cpAddressList = [
            SELECT Id, ParentId, Street, City, PostalCode, Country, StateCode
            FROM ContactPointAddress
            WHERE ParentId IN :accountIds
            AND IsPrimary = true WITH SYSTEM_MODE
        ];

        for (ContactPointEmail cpEmail : cpEmailList) {
            dataContext.accountCpEmailMap.put(cpEmail.ParentId, cpEmail);
        }
        for (ContactPointPhone cpPhone : cpPhoneList) {
            // Prefer Primary Mobile for ASPN outbound (NGASIM-2347)
            if (ConstantsUtil.CONTACT_POINT_USAGE_TYPE_MOBILE.equals(cpPhone.UsageType)) {
                dataContext.accountCpPhoneMap.put(cpPhone.ParentId, cpPhone);
            }
            // Fallback to Primary Phone when no Mobile exists (NGASIM-2347)
            else if (!dataContext.accountCpPhoneMap.containsKey(cpPhone.ParentId)) {
                dataContext.accountCpPhoneMap.put(cpPhone.ParentId, cpPhone);
            }
        }
        for (ContactPointAddress cpAddress : cpAddressList) {
            dataContext.accountCpAddressMap.put(cpAddress.ParentId, cpAddress);
        }
    }

    /**
     * @description Queries Provider relationship data
     * @param dataContext Data context to populate
     */
    private static void queryProviderData(SendtoAspnService.AspnDataContext dataContext) {
        if (dataContext.personContactIdsSet.isEmpty()) {
            return;
        }

        List<ContactContactRelation> ccrList = [
            SELECT Id, RelatedContactId, ContactId, PartyRoleRelation.Name,
                   RelatedContact.FirstName, RelatedContact.LastName
            FROM ContactContactRelation
            WHERE PartyRoleRelation.Name = :ConstantsUtil.PARTY_ROLE_RELATION_TYPE_PATIENT_PROVIDER
            AND Is_Primary__c = true
            AND IsActive = true
            AND ContactId IN :dataContext.personContactIdsSet WITH SYSTEM_MODE
        ];

        Set<Id> relatedContactIdSet = new Set<Id>();
        for (ContactContactRelation ccr : ccrList) {
            if (ccr.RelatedContactId != null) {
                relatedContactIdSet.add(ccr.RelatedContactId);
                dataContext.ccrMap.put(ccr.ContactId, ccr);
            }
        }

        if (!relatedContactIdSet.isEmpty()) {
            List<Account> providerAccountList = [
                SELECT Id, PersonContactId
                FROM Account
                WHERE PersonContactId IN :relatedContactIdSet WITH SYSTEM_MODE
            ];

            for (Account acc : providerAccountList) {
                dataContext.providerAccountIdsSet.add(acc.Id);
                if (acc.PersonContactId != null) {
                    dataContext.providerConAccIdMap.put(acc.PersonContactId, acc.Id);
                }
            }
        }
    }

    /**
     * @description Queries Identifier data for patients and providers
     * @param accountIds Set of Patient Account IDs
     * @param dataContext Data context to populate
     */
    private static void queryIdentifierData(Set<Id> accountIds, SendtoAspnService.AspnDataContext dataContext) {
        Set<Id> allAccountIds = new Set<Id>();
        allAccountIds.addAll(accountIds);
        if (!dataContext.providerAccountIdsSet.isEmpty()) {
            allAccountIds.addAll(dataContext.providerAccountIdsSet);
        }

        if (allAccountIds.isEmpty()) {
            return;
        }

        List<Identifier> allIdentifiers = [
            SELECT Id, ParentRecordId, IdUsageType, ID_Value__c
            FROM Identifier
            WHERE ParentRecordId IN :allAccountIds
            AND (
                (IdUsageType = :ConstantsUtil.IDENTIFIER_EXTERNAL_PATIENT_ID_USAGE_TYPE AND ID_Value__c != NULL)
                OR
                (IdUsageType = :ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE AND ID_Value__c != NULL)
                OR
                (IdUsageType = :ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE AND ID_Value__c != NULL)
            )
            WITH SYSTEM_MODE
        ];

        for (Identifier identifier : allIdentifiers) {
            if (identifier.IdUsageType == ConstantsUtil.IDENTIFIER_EXTERNAL_PATIENT_ID_USAGE_TYPE) {
                dataContext.accountIdentifierMap.put(identifier.ParentRecordId, identifier.ID_Value__c);
            } else if (identifier.IdUsageType == ConstantsUtil.IDENTIFIER_NPI_USAGE_TYPE) {
                dataContext.providerAccIdentifierMap.put(identifier.ParentRecordId, identifier.ID_Value__c);
            } else if (identifier.IdUsageType == ConstantsUtil.IDENTIFIER_CUSTOMER_ID_USAGE_TYPE) {
                // Only store Customer ID identifiers for Patient Accounts, not Provider Accounts
                // Customer ID should only be associated with Patient Accounts per NGOMCT-1454
                if (accountIds.contains(identifier.ParentRecordId)) {
                    dataContext.accountCustomerIdMap.put(identifier.ParentRecordId, identifier.ID_Value__c);
                }
            }
        }
    }

    /**
     * @description Queries Practice relationship data
     * @param dataContext Data context to populate
     */
    private static void queryPracticeData(SendtoAspnService.AspnDataContext dataContext) {
        if (dataContext.personContactIdsSet.isEmpty()) {
            return;
        }

        List<AccountContactRelation> acrList = [
            SELECT Id, ContactId, AccountId
            FROM AccountContactRelation
            WHERE Roles = :ConstantsUtil.ACR_ROLE_PATIENT_PRACTICE
            AND Is_Primary__c = true
            AND IsActive = true
            AND ContactId IN :dataContext.personContactIdsSet WITH SYSTEM_MODE
        ];

        Set<Id> practiceAccountIds = new Set<Id>();
        for (AccountContactRelation acr : acrList) {
            if (acr.AccountId != null) {
                practiceAccountIds.add(acr.AccountId);
                dataContext.practiceAccountConAccIdMap.put(acr.ContactId, acr.AccountId);
            }
        }

        if (!practiceAccountIds.isEmpty()) {
            for (Account acc : [
                SELECT Id, Phone, BillingCity, BillingStateCode, BillingPostalCode
                FROM Account
                WHERE Id IN :practiceAccountIds WITH SYSTEM_MODE
            ]) {
                dataContext.practiceAccountMap.put(acc.Id, acc);
            }
        }
    }

    /**
     * @description Queries Opportunity Line Items
     * @param opptyIdsSet Set of Opportunity IDs
     * @param dataContext Data context to populate
     */
    private static void queryOpportunityLineItems(Set<Id> opptyIdsSet, SendtoAspnService.AspnDataContext dataContext) {
        List<Opportunity> opportunityList = [
            SELECT Id, Name, Cancel_Order__c, Reason_For_Cancellation__c, Opportunity_Source__c, AccountId, (
                SELECT Id, Name, Product_NDC__c, Sub_Status__c, External_ASPNID__c, Product2.Name
                FROM OpportunityLineItems
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            )
            FROM Opportunity
            WHERE Id IN :opptyIdsSet WITH SYSTEM_MODE
        ];

        for (Opportunity opp : opportunityList) {
            dataContext.opportunityMap.put(opp.Id, opp);
            if (opp.OpportunityLineItems != null && !opp.OpportunityLineItems.isEmpty()) {
                dataContext.opptyLineItemMap.put(opp.Id, opp.OpportunityLineItems[0]);
            }
        }
    }

    /**
     * @description Queries Contact Point Type Consent records for Individuals
     *              Queries records where Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL or ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS
     * @param dataContext Data context to populate
     */
    private static void queryContactPointTypeConsentData(SendtoAspnService.AspnDataContext dataContext) {
        if (dataContext.individualIdsSet.isEmpty()) {
            return;
        }

        List<ContactPointTypeConsent> consentList = [
            SELECT Id, PartyId, Name, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE PartyId IN :dataContext.individualIdsSet
            AND Name IN (:ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL, :ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS)
            WITH SYSTEM_MODE
        ];

        for (ContactPointTypeConsent consent : consentList) {
            if (!dataContext.individualConsentMap.containsKey(consent.PartyId)) {
                dataContext.individualConsentMap.put(consent.PartyId, new List<ContactPointTypeConsent>());
            }
            dataContext.individualConsentMap.get(consent.PartyId).add(consent);
        }
    }
}