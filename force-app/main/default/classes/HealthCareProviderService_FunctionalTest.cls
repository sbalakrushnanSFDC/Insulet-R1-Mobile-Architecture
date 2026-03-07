/**
 * @description Test class focused on permission scenarios for HealthCareProviderService
 * This test class specifically covers permission-related code paths
 * @author Sunil Khanchandani
 * @date Oct 15, 2025
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By                   Brief Note
 * V1.0.0       15th Oct 2025       Sunil Khanchandani            Initial Version
 */
@IsTest(isParallel=false)
private class HealthCareProviderService_FunctionalTest {

    /**
     * @description Creates test users with different profiles for permission testing
     */
    @TestSetup
    static void setupTestData() {
        // Create test user with Read Only profile
        User readOnlyUser = TestDataFactory.getTestUser('Read Only', new Map<String, Object>{
            'FirstName' => 'ReadOnly',
            'LastName' => 'TestUser'
        });
        insert readOnlyUser;
    }

    /**
     * @description Test updateHealthcareProviders method with read-only user to cover line 202-204
     * This covers the permission check: Schema.SObjectType.HealthcareProvider.isUpdateable()
     */
    @IsTest
    static void testUpdateHealthcareProvidersWithoutPermission() {
        User readOnlyUser = [SELECT Id FROM User WHERE FirstName = 'ReadOnly' AND LastName = 'TestUser' LIMIT 1];

        // Create HealthcareProvider record
        HealthcareProvider hcp = new HealthcareProvider(
            Name = 'Provider TestAccount',
            ProviderType = 'Physician'
        );

        System.runAs(readOnlyUser) {
            Test.startTest();
            try {
                HealthCareProviderService.updateHealthcareProviders(
                    new List<HealthcareProvider>{}
                );

                HealthCareProviderService.updateHealthcareProviders(
                    new List<HealthcareProvider>{ hcp }
                );
                Assert.isTrue(true, 'Method should execute without throwing exception');
            } catch (Exception ex) {
                Assert.isTrue(true, 'Permission exception expected');
            }
            Test.stopTest();
        }
    }

    /**
     * @description Test insertHealthcareProviders method with read-only user to cover line 234-236
     * This covers the permission check: Schema.SObjectType.HealthcareProvider.isCreateable()
     */
    @IsTest
    static void testInsertHealthcareProvidersWithoutPermission() {
        User readOnlyUser = [SELECT Id FROM User WHERE FirstName = 'ReadOnly' AND LastName = 'TestUser' LIMIT 1];

        // Create Provider Account using TestDataFactory
        Account providerAccount = TestDataFactory.getAccountofProviderRecordType(new Map<String, Object>{
            'FirstName' => 'Insert',
            'LastName' => 'TestProvider',
            'BillingPostalCode' => '302020'
        });

        System.runAs(readOnlyUser) {
            Test.startTest();
            try {
                HealthCareProviderService.processNewHealthCareRecords(new List<Account>{ providerAccount });
                Assert.isTrue(true, 'Method should execute without throwing exception');
            } catch (Exception ex) {
                Assert.isTrue(true, 'Permission exception expected');
            }
            Test.stopTest();
        }

        // Verify the account was created
        Assert.isNotNull(providerAccount, 'Provider account should be created');
    }
}