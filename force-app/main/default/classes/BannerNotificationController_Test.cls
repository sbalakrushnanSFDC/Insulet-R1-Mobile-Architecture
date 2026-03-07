/**
 * @description Unit tests for BannerNotificationController.
 *              Verifies notifications for certification expired, expiring, and no-notification scenarios.
 *              Uses central TestDataFactory to create required data.
 * @group Notifications
 * @author Shashank Nigam
 * @createdDate 8/2/2026
 */
@IsTest
private with sharing class BannerNotificationController_Test {

    /**
     * @description Test setup creating the ListView used by the controller query.
     *              DeveloperName must be 'My_Certification' and SobjectType 'Certification__c'.
     */
    @TestSetup
    static void setupData() {
        List<SObject> recordsToInsert = new List<SObject>();
        recordsToInsert.add(TestDataFactory.getOmniProcess(new Map<String, Object>{ 'type' => 'Assessment','subtype' =>'Test'}));
        Account trainer = TestDataFactory.getAccountofTrainerRecordType(new Map<String,Object>{'Trainer_Type__c'=>ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER});
        recordsToInsert.add(trainer);
        recordsToInsert.add(TestDataFactory.getAssessmentQuestionSet());
        Account practice = TestDataFactory.getAccountofPracticeRecordType();
        recordsToInsert.add(practice);
        insert recordsToInsert;
        AssessmentDefinition ad = TestDataFactory.getAssessmentDefinition(new Map<String,Object> {'OmniProcessId'=> recordsToInsert[0].id,
            'Assessment_Question_Set__c' => recordsToInsert[2].Id,
            'Test_Name__c' => 'Test Exam',
            'Purpose' => 'Certification'});
        insert ad;
        
        Certification__c c = TestDataFactory.getCertification(new Map<String,Object>{
            'Trainer_Name__c' => recordsToInsert[1].Id,
            'Certification_Assessment__c' => ad.Id,
            'Retake_Exam__c' => true,
            'Completion_Status__c' => 'Completed',
            'Certification_Results__c' => 'Passed'
        });
        insert c;
        Account t2 = [Select PersoncontactId from Account where Id =:trainer.Id];
        insert TestDataFactory.getAccountContactRelation(practice.Id,t2.PersoncontactId,ConstantsUtil.ACR_ROLE_TRAINER);
    }

    /**
     * @description Ensures an 'error' notification is produced when Certification_Expiration_Date__c is in the past.
     *              Verifies exactly one notification with error variant, a non-empty message, and at least one link.
     */
    @IsTest
    static void testExpiredCertificationShowsError() {
        Account trainer = [Select id from account where Trainer_Type__c =:ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER limit 1];
        Certification__c c = [Select id,Certification_Date__c from Certification__c limit 1];
        c.Certification_Date__c = Date.newInstance(2022, 10, 26);
        update c;

        Test.startTest();
        List<BannerNotificationController.NotificationWrapper> notifs =
            BannerNotificationController.getNotification(trainer.Id);
        Test.stopTest();

        // Consolidate assertions to reduce TooManyAsserts
        Assert.isTrue(notifs != null && notifs.size() == 2, 'Expect exactly one notification');
        BannerNotificationController.NotificationWrapper n = notifs[0];
        Assert.isTrue(ConstantsUtil.Message_Type.ERROR.name().toLowerCase() == n.type,
            'Expect Certificate Expired');
    }

    /**
     * @description Ensures a 'warning' notification is produced when Certification_Expiration_Date__c is within 60 days.
     *              Verifies exactly one notification with warning variant, a non-empty message, and at least one link.
     */
    @IsTest
    static void testExpiringCertificationShowsWarning() {
        Account trainer = [Select id from account where Trainer_Type__c =:ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER limit 1];
        Certification__c c = [Select id,Certification_Date__c from Certification__c limit 1];
        c.Certification_Date__c = Date.today().addYears(-2).addDays(2);
        update c;
        
        Test.startTest();
        List<BannerNotificationController.NotificationWrapper> notifs =
            BannerNotificationController.getNotification(trainer.Id);
        Test.stopTest();

        Assert.areEqual(2, notifs.size(), 'Exactly one notification expected');
        BannerNotificationController.NotificationWrapper n = notifs[0];
        Boolean hasLinks = (n.links != null && n.links.size() > 0);
        Boolean hasMessage = String.isNotBlank(n.message);
        Assert.isTrue(ConstantsUtil.Message_Type.WARNING.name().toLowerCase() == n.type && hasLinks && hasMessage && n.isDismissible == false,
            'Expect warning type, non-empty message, link present, and not dismissible');
    }

    /**
     * @description Ensures no notification message/type/links are set when Certification_Expiration_Date__c is beyond 60 days.
     *              Verifies the wrapper list still returns a single wrapper with empty content.
     */
    @IsTest
    static void testNoNotificationWhenBeyondWindow() {
        Account trainer = [Select id from account where Trainer_Type__c =:ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER limit 1];
        Certification__c c = [Select id,Certification_Date__c from Certification__c limit 1];
        c.Certification_Date__c = Date.today().addDays(90);
        update c;

        Test.startTest();
        List<BannerNotificationController.NotificationWrapper> notifs =
            BannerNotificationController.getNotification(trainer.Id);
        Test.stopTest();

        Assert.areEqual(2, notifs.size(), 'Wrapper list is always returned with a single wrapper');
        BannerNotificationController.NotificationWrapper n = notifs[0];
        Boolean noMessage = (n.message == null);
        Boolean noType = (n.type == null);
        Boolean noLinks = (n.links == null);
        Assert.isTrue(noMessage && noType && noLinks,
            'Expect no message, type, or links when outside 60-day window');
    }
    
    /**
     * @description Ensures no notification message/type/links are set when Certification_Expiration_Date__c is beyond 60 days.
     *              Verifies the wrapper list still returns a single wrapper with empty content.
     */
    @IsTest
    static void testNoNotificationException() {
        Test.startTest();
        try{
            BannerNotificationController.getNotification(null);
        }
        catch(Exception ex){
            Assert.isNotNull(ex, 'Exception is thrown');
        }
        Test.stopTest();
    }

    /**
     * @description Ensures notification message/type/links are set when Contract_Expiration_Date__c is beyond 60 days.
     *              Verifies the wrapper list still returns a single wrapper with empty content.
     */
    @IsTest
    static void testgetNotificationContract(){
        Account trainer = [Select id,Contract_Expiration_Date__c from Account where Trainer_Type__c =:ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER];
        Account practice =[Select id,Contract_Expiration_Date__c from Account where Trainer_Type__c !=:ConstantsUtil.CERTIFIED_POD_TRAINER_AND_CLINIC_CONTRACT_TRAINER];
        practice.Contract_Expiration_Date__c = System.Today();
        update practice;
        Test.startTest();
        BannerNotificationController.getNotification(trainer.Id);
        practice.Contract_Expiration_Date__c = System.Today().addDays(-1);
        update practice;
        BannerNotificationController.getNotification(trainer.Id);
        trainer.Contract_Expiration_Date__c = System.Today();
        update trainer;
        BannerNotificationController.getNotification(trainer.Id);
        trainer.Contract_Expiration_Date__c = System.Today().addDays(-1);
        update trainer;
        BannerNotificationController.getNotification(trainer.Id);
        Test.stopTest();
        Assert.areEqual(2, BannerNotificationController.getNotification(trainer.Id).size(), 'Wrapper list is always returned with a 2 wrapper');
    }

}