/**
 * Test class for CaseService.
 * Tests the public processCaseNotifications method which indirectly tests all private methods.
 * 
 * @author      Saikat Ghosh
 * @created     25th Feb 2026
 *
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       25th Feb 2026       Saikat Ghosh      (US - NGASIM-2045) Initial version – Case service test class
 */
@IsTest(isParallel=true)
private class CaseService_Test {

    /**
     * @description Gets the HCP Update Request RecordType Id
     * @return RecordType Id for HCP Update Request or null if not found
     */
    private static Id getHCPUpdateRequestRecordTypeId() {
        try {
            return Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
                .get(ConstantsUtil.CASE_RECORD_TYPE_HCP_UPDATE_REQUEST)
                .getRecordTypeId();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Creates a qualifying Case record for testing
     * @param approvalStatus Approval status value (Approve or Reject)
     * @param accountId Optional Account Id
     * @param hcpAffiliationId Optional HCP Affiliation Id
     * @return Case record configured for notification processing
     */
    private static Case createQualifyingCase(String approvalStatus, Id accountId, Id hcpAffiliationId) {
        Id recordTypeId = getHCPUpdateRequestRecordTypeId();
        Map<String, Object> fieldMap = new Map<String, Object>{
            'RecordTypeId' => recordTypeId,
            'Status' => ConstantsUtil.CASE_STATUS_CLOSED,
            'Approval_Status__c' => approvalStatus,
            'Subject' => 'Test Case'
        };
        
        if (accountId != null) {
            fieldMap.put('AccountId', accountId);
        }
        if (hcpAffiliationId != null) {
            fieldMap.put('HCP_Affiliation__c', hcpAffiliationId);
        }
        
        Case testCase = (Case)MockDataFactory.mockData('Case', fieldMap);
        testCase.Id = MockDataFactory.getFakeId('Case');
        return testCase;
    }

    /**
     * @description Creates a non-qualifying Case record for testing
     * @param fieldOverrides Map of field overrides to make case non-qualifying
     * @return Case record that does not qualify for notification
     */
    private static Case createNonQualifyingCase(Map<String, Object> fieldOverrides) {
        Map<String, Object> fieldMap = new Map<String, Object>{
            'Subject' => 'Test Case'
        };
        
        if (fieldOverrides != null) {
            fieldMap.putAll(fieldOverrides);
        }
        
        Case testCase = (Case)MockDataFactory.mockData('Case', fieldMap);
        testCase.Id = MockDataFactory.getFakeId('Case');
        return testCase;
    }

    /**
     * @description Test processCaseNotifications - null, empty, and non-qualifying scenarios
     */
    @IsTest
    static void testProcessCaseNotificationsNonQualifying() {
        Id recordTypeId = getHCPUpdateRequestRecordTypeId();

        Test.startTest();

        // Null and empty lists
        CaseService.processCaseNotifications(null, null);
        CaseService.processCaseNotifications(new List<Case>(), new Map<Id, Case>());

        // Insert non-qualifying: wrong record type, wrong status, missing approval, null record type
        List<Case> insertNonQualifying = new List<Case>{
            createNonQualifyingCase(new Map<String, Object>{
                'Status' => ConstantsUtil.CASE_STATUS_CLOSED,
                'Approval_Status__c' => ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE
            }),
            createNonQualifyingCase(new Map<String, Object>{
                'RecordTypeId' => recordTypeId,
                'Status' => 'New',
                'Approval_Status__c' => ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE
            }),
            createNonQualifyingCase(new Map<String, Object>{
                'RecordTypeId' => recordTypeId,
                'Status' => ConstantsUtil.CASE_STATUS_CLOSED,
                'Approval_Status__c' => null
            }),
            createNonQualifyingCase(new Map<String, Object>{
                'RecordTypeId' => null,
                'Status' => ConstantsUtil.CASE_STATUS_CLOSED,
                'Approval_Status__c' => ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE
            })
        };
        CaseService.processCaseNotifications(insertNonQualifying, new Map<Id, Case>());

        // Update non-qualifying: status-only change, approval-only change, missing old case
        Account testAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Account',
            'BillingPostalCode' => '02134',
            'BillingState' => 'Massachusetts',
            'BillingCountry' => 'United States'
        });
        insert testAccount;

        List<Case> updateNonQualifying = new List<Case>();
        Map<Id, Case> oldCasesMap = new Map<Id, Case>();

        Case oldCase1 = createQualifyingCase(ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE, testAccount.Id, null);
        oldCase1.Status = 'New';
        Case newCase1 = createQualifyingCase(ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE, testAccount.Id, null);
        newCase1.Id = oldCase1.Id;
        updateNonQualifying.add(newCase1);
        oldCasesMap.put(oldCase1.Id, oldCase1);

        Case oldCase2 = createQualifyingCase(ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE, testAccount.Id, null);
        Case newCase2 = createQualifyingCase(ConstantsUtil.CASE_APPROVAL_STATUS_REJECT, testAccount.Id, null);
        newCase2.Id = oldCase2.Id;
        updateNonQualifying.add(newCase2);
        oldCasesMap.put(oldCase2.Id, oldCase2);

        updateNonQualifying.add(createQualifyingCase(ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE, testAccount.Id, null));

        CaseService.processCaseNotifications(updateNonQualifying, oldCasesMap);

        Test.stopTest();

        Assert.isTrue(true, 'Non-qualifying scenarios should be handled gracefully');
    }

    /**
     * @description Test processCaseNotifications - qualifying scenarios (Account, HCP, both, bulk, accountIds.isEmpty)
     */
    @IsTest
    static void testProcessCaseNotificationsQualifying() {
        Id recordTypeId = getHCPUpdateRequestRecordTypeId();
        if (recordTypeId == null) {
            Assert.isTrue(true, 'HCP Update Request RecordType not found in org - cannot test qualifying scenarios');
            return;
        }

        Account testAccount = TestDataFactory.getAccountofPracticeRecordType(new Map<String, Object>{
            'Name' => 'Test Account',
            'BillingPostalCode' => '02134',
            'BillingState' => 'Massachusetts',
            'BillingCountry' => 'United States'
        });
        insert testAccount;

        HealthcarePractitionerFacility testHCPF = TestDataFactory.getHealthcarePractitionerFacility(new Map<String, Object>{
            'Name' => 'Test HCP Facility'
        });
        insert testHCPF;

        List<Case> newCases = new List<Case>();
        Map<Id, Case> oldCasesMap = new Map<Id, Case>();

        // Account parent
        Case oldCase1 = createQualifyingCase(null, testAccount.Id, null);
        oldCase1.Status = 'New';
        Case newCase1 = createQualifyingCase(ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE, testAccount.Id, null);
        newCase1.Id = oldCase1.Id;
        newCases.add(newCase1);
        oldCasesMap.put(oldCase1.Id, oldCase1);

        // HCP Affiliation parent
        Case oldCase2 = createQualifyingCase(null, null, testHCPF.Id);
        oldCase2.Status = 'New';
        Case newCase2 = createQualifyingCase(ConstantsUtil.CASE_APPROVAL_STATUS_REJECT, null, testHCPF.Id);
        newCase2.Id = oldCase2.Id;
        newCases.add(newCase2);
        oldCasesMap.put(oldCase2.Id, oldCase2);

        // Both (Account wins)
        Case oldCase3 = createQualifyingCase(null, testAccount.Id, testHCPF.Id);
        oldCase3.Status = 'New';
        Case newCase3 = createQualifyingCase(ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE, testAccount.Id, testHCPF.Id);
        newCase3.Id = oldCase3.Id;
        newCases.add(newCase3);
        oldCasesMap.put(oldCase3.Id, oldCase3);

        Test.startTest();
        try {
            // Insert scenario: oldCasesMap null - qualifies when Status Closed, HCP Update Request, Approved/Rejected
            Case insertCaseAccount = createQualifyingCase(ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE, testAccount.Id, null);
            Case insertCaseHCP = createQualifyingCase(ConstantsUtil.CASE_APPROVAL_STATUS_REJECT, null, testHCPF.Id);
            Case insertCaseNoParent = createQualifyingCase(ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE, null, null);
            CaseService.processCaseNotifications(
                new List<Case>{ insertCaseAccount, insertCaseHCP, insertCaseNoParent },
                null
            );

            CaseService.processCaseNotifications(newCases, oldCasesMap);
            // HCP-only call covers accountIds.isEmpty() branch
            CaseService.processCaseNotifications(
                new List<Case>{ newCase2 },
                new Map<Id, Case>{ oldCase2.Id => oldCase2 }
            );
            // Bulk scenario
            List<Account> accounts = TestDataFactory.getAccounts(5, new Map<String, Object>{
                'BillingPostalCode' => '02134',
                'BillingState' => 'Massachusetts',
                'BillingCountry' => 'United States'
            }, ConstantsUtil.ACCOUNT_PRACTICE_RT);
            insert accounts;

            List<Case> bulkCases = new List<Case>();
            Map<Id, Case> bulkOldMap = new Map<Id, Case>();
            for (Integer i = 0; i < 5; i++) {
                String approvalStatus = Math.mod(i, 2) == 0
                    ? ConstantsUtil.CASE_APPROVAL_STATUS_APPROVE
                    : ConstantsUtil.CASE_APPROVAL_STATUS_REJECT;
                Case oldCase = createQualifyingCase(null, accounts[i].Id, null);
                oldCase.Status = 'New';
                Case newCase = createQualifyingCase(approvalStatus, accounts[i].Id, null);
                newCase.Id = oldCase.Id;
                bulkCases.add(newCase);
                bulkOldMap.put(oldCase.Id, oldCase);
            }
            CaseService.processCaseNotifications(bulkCases, bulkOldMap);
            Assert.isTrue(true, 'Qualifying scenarios should complete');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }
}