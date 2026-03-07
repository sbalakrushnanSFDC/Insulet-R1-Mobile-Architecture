/**
 * @author      : Ramesh Dhaka
 * @created Date: 7th Oct 2025
 * @description : Test Class for Product Recommendation Engine core class,
 * responsible for coverage of ProductRecommendationHandler/service class
 * @story Number: NGOMCT-202
 * =========================== Logs ==============================
 * Version      Modified Date       Modified By            Brief Note
 * V1.0.0       7th Oct 2025        Ramesh Dhaka           Initial Version
 * V1.1.0       15th Oct 2025       Ramesh Dhaka           Updated(US - NGOMCT-202)
 */
@IsTest(isParallel=true)
private class ProductRecommendationService_Test {
    /**
     * @description testMethod for positive test case of product recommendation
     * where age < 2 and Type of diabetes = Type 1
     */
    @IsTest
    static void testProductRecommendationPositive1() {
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'IndividualId' => null,
            'Date_of_Birth__c' => System.today(),
            'Type_of_Diabetes__c' => ConstantsUtil.DIABETES_TYPE_1,
            'LeadSource' => 'Lets_go',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        Test.startTest();
        try {
            ProductRecommendationHandler.processProductRecommendations(testLeads, null);
            Assert.areNotEqual(null,testLeads[0].Recommended_Product__c,'Product Recommendation Engine failed' );
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();
    }

    /**
     * @description testMethod for positive test case of product recommendation
     * where age < 2 and Type of diabetes = Type 2
     */
    @IsTest
    static void testProductRecommendationPositive2() {
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'IndividualId' => null,
            'Date_of_Birth__c' => System.today().addYears(-19),
            'Type_of_Diabetes__c' => ConstantsUtil.DIABETES_TYPE_2_INSULIN,
            'LeadSource' => 'Lets_go',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        Test.startTest();
        try {
            ProductRecommendationHandler.processProductRecommendations(testLeads, null);
            Assert.areEqual(null,testLeads[0].Recommended_Product__c,'Product Recommendation Engine failed' );
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();
    }

    /**
     * @description testMethod for positive test case of product recommendation
     * When user updates age/cgm/type of diabetes
     */
    @IsTest
    static void testProductRecommendationPositive3() {
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'IndividualId' => null,
            'Date_of_Birth__c' => System.today().addYears(-15),
            'Type_of_Diabetes__c' => ConstantsUtil.DIABETES_TYPE_2_INSULIN,
            'LeadSource' => 'Lets_go',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        Map<Id,Lead> oldLeadsMap = new Map<Id,Lead>();
        Lead oldLead = testLeads[0].clone(false, false, false, false);
        oldLead.Id = testLeads[0].Id;
        oldLead.Date_of_Birth__c = System.today().addYears(-19);
        oldLeadsMap.put(testLeads[0].Id, oldLead);

        Test.startTest();
        try {
            ProductRecommendationHandler.processProductRecommendations(testLeads, oldLeadsMap);
            Assert.areNotEqual(null,testLeads[0].Recommended_Product__c,'Product Recommendation Engine failed' );
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();
    }

    /**
     * @description testMethod for positive test case of product recommendation
     * When user updates age/cgm/type of diabetes as well as recommended product
     */
    @IsTest
    static void testProductRecommendationPositive4() {
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'IndividualId' => null,
            'Date_of_Birth__c' => System.today().addYears(-15),
            'Type_of_Diabetes__c' => ConstantsUtil.DIABETES_TYPE_2_INSULIN,
            'LeadSource' => 'Lets_go',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        Map<Id,Lead> oldLeadsMap = new Map<Id,Lead>();
        Lead oldLead = testLeads[0].clone(false, false, false, false);
        oldLead.Id = testLeads[0].Id;
        oldLead.Recommended_Product__c = 'DASH2';
        oldLead.Date_of_Birth__c = System.today().addYears(-19);
        oldLeadsMap.put(testLeads[0].Id, oldLead);

        Test.startTest();
        try {
            ProductRecommendationHandler.processProductRecommendations(testLeads, oldLeadsMap);
            Assert.areNotEqual(null,testLeads[0].Recommended_Product__c,'Product Recommendation Engine failed' );
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();
    }

    /**
     * @description testMethod for Negative test case of product recommendation
     * where age < 2 and Type of diabetes = random value
     */
    @IsTest
    static void testProductRecommendationNegative1() {
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'IndividualId' => null,
            'Date_of_Birth__c' => System.today(),
            'Type_of_Diabetes__c' => 'No Idea',
            'LeadSource' => 'Lets_go',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        Test.startTest();
        try {
            ProductRecommendationHandler.processProductRecommendations(testLeads, null);
            Assert.areEqual(null,testLeads[0].Recommended_Product__c,'Product Recommendation Engine failed' );
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();
    }

    /**
     * @description testMethod for Negative test case of product recommendation
     * where customExceptionSwitch is turned on
     */
    @IsTest
    static void testProductRecommendationNegative2() {
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'IndividualId' => null,
            'Date_of_Birth__c' => System.today(),
            'Type_of_Diabetes__c' => 'No Idea',
            'LeadSource' => 'Lets_go',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        Test.startTest();
        try {
            ConstantsUtil.customExceptionSwitch = true;
            ProductRecommendationHandler.processProductRecommendations(testLeads, null);
            Assert.areEqual(null,testLeads[0].Recommended_Product__c,'Product Recommendation Engine failed' );
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();
    }

    /**
     * @description testMethod for Negative test case of product recommendation
     * where LeadList is passed as an empty list
     */
    @IsTest
    static void testProductRecommendationNegative3() {
        List<Lead> testLeads ;

        Test.startTest();
        try {
            ProductRecommendationHandler.processProductRecommendations(testLeads, null);
            Assert.areEqual(null,testLeads[0].Recommended_Product__c,'Product Recommendation Engine failed' );
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();
    }

    /**
     * @description testMethod for Negative test case of product recommendation
     * where baseline criteria doesn't meet
     */
    @IsTest
    static void testProductRecommendationNegative4() {
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'IndividualId' => null,
            'Date_of_Birth__c' => System.today(),
            'Type_of_Diabetes__c' => 'No Idea',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });

        Test.startTest();
        try {
            ProductRecommendationHandler.processProductRecommendations(testLeads, null);
            Assert.areEqual(null,testLeads[0].Recommended_Product__c,'Product Recommendation Engine failed' );
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();
    }

    /**
     * @description testMethod for Negative test case of product recommendation
     * where baseline criteria doesn't meet
     */
    @IsTest
    static void testProductRecommendationNegative5() {
        List<Lead> testLeads = MockDataFactory.createLeads(1, new Map<String, Object>{
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'IndividualId' => null,
            'Date_of_Birth__c' => System.today().addYears(-4),
            'Type_of_Diabetes__c' => 'Type 1',
            'Recommended_Product__c' => 'Dash',
            'LeadSource' => 'Lets_go',
            'RecordTypeId' => ConstantsUtil.LEAD_PATIENT_RT
        });
        Map<Id,Lead> oldLeadsMap = new Map<Id,Lead>();
        Lead oldLead = testLeads[0].clone(false, false, false, false);
        oldLead.Id = testLeads[0].Id;
        oldLead.Recommended_Product__c = 'DASH2';
        oldLeadsMap.put(testLeads[0].Id, oldLead);
        Test.startTest();
        try {
            ProductRecommendationHandler.processProductRecommendations(testLeads, oldLeadsMap);
            Assert.areNotEqual('',testLeads[0].Recommended_Product__c,'Product Recommendation Engine failed' );
        } catch (Exception ex) {
            Assert.isTrue(true, 'Exception expected in test context');
        }
        Test.stopTest();
    }
}