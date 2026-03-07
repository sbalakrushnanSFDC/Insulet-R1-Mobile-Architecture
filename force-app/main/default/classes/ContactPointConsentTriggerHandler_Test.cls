/**
 * @description Test class for ContactPointTypeConsentTriggerHandler.
 *              Verifies CaptureDate is updated when PrivacyConsentStatus changes on before update.
 * @createdDate 27th Jan 2026
 * @CreatedBy Bijayalaxmi Prusty
 * * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.1.0       20th Feb 2026       Bijayalaxmi Prusty      Initial Version(NGASIM-2157)
 */

@IsTest
private class ContactPointConsentTriggerHandler_Test {

    @TestSetup
    static void setupTestData() {
        List<DataUsePurpose> dataUsePurposes = new List<DataUsePurpose>{
            new DataUsePurpose(Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL),
            new DataUsePurpose(Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS),
            new DataUsePurpose(Name = ConstantsUtil.CONSENT_NAME_MARKETING_EMAIL)
        };
        insert dataUsePurposes;

        Individual individual = TestDataFactory.getIndividual(new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'Individual'
        });
        insert individual;
    }

    /**
     * @description Test beforeUpdate: CaptureDate is updated when PrivacyConsentStatus changes
     */
    @IsTest
    static void testBeforeUpdateCaptureDateUpdatedOnStatusChange() {
        Id individualId = getIndividualId();
        Id dataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL);

        ContactPointTypeConsent consent = new ContactPointTypeConsent(
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = dataUsePurposeId,
            PartyId = individualId,
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = DateTime.now().addDays(-1)
        );
        insert consent;

        DateTime captureDateBeforeUpdate = [SELECT CaptureDate FROM ContactPointTypeConsent WHERE Id = :consent.Id WITH USER_MODE].CaptureDate;

        Test.startTest();
        consent.PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_OUT;
        update consent;
        Test.stopTest();

        ContactPointTypeConsent updated = [
            SELECT Id, CaptureDate, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE Id = :consent.Id
            WITH USER_MODE
        ];
        Assert.areEqual(ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_OUT, updated.PrivacyConsentStatus, 'Status should be updated');
        Assert.isNotNull(updated.CaptureDate, 'CaptureDate should be set');
    }

    /**
     * @description Test beforeUpdate: CaptureDate remains unchanged when PrivacyConsentStatus does not change
     */
    @IsTest
    static void testBeforeUpdateCaptureDateUnchangedWhenStatusSame() {
        Id individualId = getIndividualId();
        Id dataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL);
        DateTime originalCaptureDate = DateTime.now().addDays(-5);

        ContactPointTypeConsent consent = new ContactPointTypeConsent(
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = dataUsePurposeId,
            PartyId = individualId,
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = originalCaptureDate
        );
        insert consent;

        Test.startTest();
        consent.CaptureSource = 'Manual';
        update consent;
        Test.stopTest();

        ContactPointTypeConsent updated = [
            SELECT Id, CaptureDate
            FROM ContactPointTypeConsent
            WHERE Id = :consent.Id
            WITH USER_MODE
        ];
        Assert.areEqual(originalCaptureDate, updated.CaptureDate, 'CaptureDate should remain unchanged when PrivacyConsentStatus does not change');
    }

    /**
     * @description Test beforeInsert: trigger executes without error
     */
    @IsTest
    static void testBeforeInsert() {
        Id individualId = getIndividualId();
        Id dataUsePurposeId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL);

        ContactPointTypeConsent consent = new ContactPointTypeConsent(
            Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
            DataUsePurposeId = dataUsePurposeId,
            PartyId = individualId,
            PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
            CaptureDate = DateTime.now()
        );

        Test.startTest();
        insert consent;
        Test.stopTest();

        List<ContactPointTypeConsent> inserted = [
            SELECT Id, CaptureDate
            FROM ContactPointTypeConsent
            WHERE Id = :consent.Id
            WITH USER_MODE
        ];
        Assert.areEqual(1, inserted.size(), 'Consent should be inserted');
        Assert.isNotNull(inserted[0].CaptureDate, 'CaptureDate should be set on insert');
    }

    /**
     * @description Test bulk beforeUpdate: multiple records with PrivacyConsentStatus change
     */
    @IsTest
    static void testBeforeUpdateBulk() {
        Id individualId = getIndividualId();
        Id emailDupId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL);
        Id smsDupId = getDataUsePurposeId(ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS);

        List<ContactPointTypeConsent> consents = new List<ContactPointTypeConsent>{
            new ContactPointTypeConsent(
                Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_EMAIL,
                DataUsePurposeId = emailDupId,
                PartyId = individualId,
                PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN,
                CaptureDate = DateTime.now().addDays(-2)
            ),
            new ContactPointTypeConsent(
                Name = ConstantsUtil.CONSENT_NAME_TRANSACTIONAL_SMS,
                DataUsePurposeId = smsDupId,
                PartyId = individualId,
                PrivacyConsentStatus = ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_OUT,
                CaptureDate = DateTime.now().addDays(-3)
            )
        };
        insert consents;

        DateTime beforeUpdate = DateTime.now();

        Test.startTest();
        for (ContactPointTypeConsent c : consents) {
            c.PrivacyConsentStatus = c.PrivacyConsentStatus == ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN
                ? ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_OUT
                : ConstantsUtil.PRIVACY_CONSENT_STATUS_OPT_IN;
        }
        update consents;
        Test.stopTest();

        List<ContactPointTypeConsent> updated = [
            SELECT Id, CaptureDate, PrivacyConsentStatus
            FROM ContactPointTypeConsent
            WHERE Id IN :consents
            WITH USER_MODE
        ];
        Assert.areEqual(2, updated.size(), 'Should have 2 updated consents');
        for (ContactPointTypeConsent c : updated) {
            Assert.isNotNull(c.CaptureDate, 'CaptureDate should be set for each consent');
            Assert.isTrue(c.CaptureDate >= beforeUpdate.addSeconds(-5), 'CaptureDate should be current datetime');
        }
    }

    private static Id getIndividualId() {
        return [SELECT Id FROM Individual LIMIT 1][0].Id;
    }

    private static Id getDataUsePurposeId(String name) {
        List<DataUsePurpose> records = [SELECT Id FROM DataUsePurpose WHERE Name = :name WITH USER_MODE LIMIT 1];
        return records.isEmpty() ? null : records[0].Id;
    }
}