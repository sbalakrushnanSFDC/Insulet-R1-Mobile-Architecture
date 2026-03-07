/**
* @description Test class for DocusignEnvelopeStatusTimelineController.
* Created Date : 14th January 2026
* Created By   : Lokesh P
* =========================== Logs ======================================
* Version      Modified Date            Modified By             Brief Note
* V1.0.0        14th January 2026       Lokesh P               Initial Version
*/
@isTest(isParallel=true)
public class DocusignEnvelopeStatusTimelineCtrl_Test {
    /**
* @description Sets up test data practice, envelope configuration, envelope, and envelope status.
*/
    @TestSetup
    static void setup() {
        // Common test data setup can be done here if needed
        Id currentUserId = UserInfo.getUserId();

        // Ensure running admin user has a Role to avoid "portal account owner must have a role"
        System.runAs(new User(Id = currentUserId)) {
            User adminUser = [SELECT Id, UserRoleId FROM User WHERE Id = :currentUserId LIMIT 1];

            if (adminUser.UserRoleId == null) {
                UserRole userRole;
                List<UserRole> ceoRole = [SELECT Id FROM UserRole WHERE DeveloperName = 'Training_Coordinator' LIMIT 1];
                if (!ceoRole.isEmpty()) {
                    userRole = ceoRole[0];
                } else {
                    userRole = new UserRole(DeveloperName = 'Training_Coordinator', Name = 'Training Coordinator');
                    insert userRole;
                }
                adminUser.UserRoleId = userRole.Id;
                update adminUser;
            }
        }
        Account practice = TestDataFactory.getAccountofPracticeRecordType();
        insert practice;

        dfsle__EnvelopeConfiguration__c cfg = TestDataFactory.getEnvelopeConfiguration();
        insert cfg;

        dfsle__Envelope__c env = TestDataFactory.getEnvelope(practice.Id,cfg.Id);
        insert env;

        dfsle__EnvelopeStatus__c st1 = TestDataFactory.getEnvelopeStatus();
        insert st1;

        // Create Portal User (Setup DML - Must be separated from Non-Setup
         Individual ind = TestDataFactory.getIndividual(
            new Map<String, Object>{
                'FirstName' => 'Test',
                'LastName' => 'Individual'
            }
        );
        insert ind;

         Account acct = TestDataFactory.getAccountofPatientRecordType(
            new Map<String, Object>{
                'FirstName' => 'Test',
                'LastName' => 'Patient',
                'PersonEmail' => 'test@test.com'
            }
        );
        insert acct;
        acct = [
            SELECT Id, PersonIndividualId, PersonContactId
            FROM Account
            WHERE Id = :acct.Id
        ];

        if (acct.PersonIndividualId == null) {
            acct.PersonIndividualId = ind.Id;
            update acct;
        }
        User portalUser;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'External Trainer' LIMIT 1];
            portalUser = TestDataFactory.getCommunityUser(acct, portalProfile, 'patConsent');
        }

    }

    /**
* @description Helper method to retrieve portal user created in test setup
* @return User The portal user
*/
    private static User getPortalUser() {
        return [SELECT Id FROM User WHERE LastName = 'UserpatConsent' LIMIT 1];
    }

    /**
* @description Tests retrieval of grouped envelope statuses
*/
    @IsTest
    static void testGetEventsReturnsGroupedStatuses() {
        User portalUser = getPortalUser();
        Account practice = [SELECT Id FROM Account WHERE RecordTypeId =: ConstantsUtil.ACCOUNT_PRACTICE_RT LIMIT 1];
        System.runAs(portalUser) {
            Test.startTest();
            List<DocusignEnvelopeStatusTimelineController.EnvelopeStatusGroup> result =
                DocusignEnvelopeStatusTimelineController.getEvents(practice.Id);
            Test.stopTest();

            Assert.areNotEqual(null, result, 'Result should not be null');
            Assert.areEqual(1, result.size(), 'Should return 1 grouped item');

            Assert.areEqual(
                'Virtual Consent Form - E-sign - English',
                result[0].envelopeConfigName,
                'Envelope config name should match'
            );

            Assert.areEqual('DOC-123', result[0].docusignId, 'DocuSign Id should match');
        }
    }

    /**
* @description Tests retrieval when no envelopes exist for the practice
*/
    @IsTest
    static void testGetEventsNoEnvelopesReturnsEmptyList() {
        User portalUser = getPortalUser();
        Account practice = [SELECT Id FROM Account WHERE RecordTypeId !=: ConstantsUtil.ACCOUNT_PRACTICE_RT LIMIT 1];
        System.runAs(portalUser) {
            Test.startTest();
            List<DocusignEnvelopeStatusTimelineController.EnvelopeStatusGroup> result =
                DocusignEnvelopeStatusTimelineController.getEvents(practice.Id);
            Test.stopTest();
            Assert.areEqual(0, result.size(), 'Should return empty list when no envelopes exist');
        }
    }

    /**
     * @description Tests that null request
     */
    @IsTest
    static void testNullchecks() {
        Boolean exceptionThrown = false;
        User portalUser = getPortalUser();
        Test.startTest();
        try {
            Account practice = [SELECT Id FROM Account WHERE RecordTypeId =: ConstantsUtil.ACCOUNT_PRACTICE_RT LIMIT 1];
            List<dfsle__EnvelopeStatus__c> statuses = [SELECT Id,dfsle__DocuSignId__c FROM dfsle__EnvelopeStatus__c];
            statuses[0].dfsle__DocuSignId__c = null;
            update statuses;
            List<dfsle__Envelope__c> envelopes = [SELECT Id,dfsle__DocuSignId__c FROM dfsle__Envelope__c];
            envelopes[0].dfsle__EnvelopeConfiguration__c = null;
            update envelopes;
            System.runAs(portalUser) {
                DocusignEnvelopeStatusTimelineController.getEvents(null);
                DocusignEnvelopeStatusTimelineController.getEvents(practice.Id);
            }
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Assert.areEqual(false,exceptionThrown , 'No exception should be thrown for null checks');
        Test.stopTest();
    }

    /**
     * @description Tests the catch block via customExceptionSwitch
     */
    @IsTest
    static void testGetEventsCatchBlock() {
        User portalUser = getPortalUser();
        Account practice = [SELECT Id FROM Account WHERE RecordTypeId =: ConstantsUtil.ACCOUNT_PRACTICE_RT LIMIT 1];
        Boolean exceptionThrown = false;

        Test.startTest();
        ConstantsUtil.customExceptionSwitch = true;
        try {
            System.runAs(portalUser) {
                DocusignEnvelopeStatusTimelineController.getEvents(practice.Id);
            }
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        } finally {
            ConstantsUtil.customExceptionSwitch = false;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Expected AuraHandledException when customExceptionSwitch is enabled');
    }
}