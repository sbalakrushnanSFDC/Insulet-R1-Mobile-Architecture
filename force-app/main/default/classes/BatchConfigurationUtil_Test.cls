/**
 * @description Test class for BatchConfigurationUtil
 *              Note: Custom Metadata records cannot be created in test methods via DML.
 *              Custom metadata records deployed to the org are visible in tests.
 *              This test class achieves 100% code coverage.Is parallel is not allowed on the current method
 *
 * @author      Niranjan Elangovan
 * @createdDate November 16, 2025
 *
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By             Brief Note
 * V1.0.0       Nov 16, 2025        Niranjan Elangovan      Initial Version
 * V1.0.1       Nov 17, 2025        Niranjan Elangovan      Updated for 100% coverage
 * V1.0.2       Dec 19, 2025        Anup Bandawar           Added Custom Metadata DTCIncompleteTaskBatch for time windows
 */
@isTest
private class BatchConfigurationUtil_Test {
     private static void mockMetadata(String className, Integer size) {
        // Clear the cache
        BatchConfigurationUtil.clearCache();

        // Create a fake CMDT record in memory
        Batch_Configuration__mdt fake = (Batch_Configuration__mdt)
            JSON.deserialize(
                JSON.serialize(new Map<String, Object>{
                    'Batch_Class_Name__c' => className,
                    'Batch_Size__c'       => size,
                    'Is_Active__c'        => true,
                    'Processing_Window__c' => 60,
                    'Wait_Time_After_Creation__c' => 1440
                }),
                Batch_Configuration__mdt.class
            );

        // Manually populate the cache to simulate loadCache() result
        BatchConfigurationUtil.configCache.put(className, fake);
    }
    /**
     * @description Test getting batch size with existing custom metadata
     *              Uses the TerritoryAliasSyncBatch custom metadata deployed to org
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testGetBatchSizeHappyPath() {
        Integer batchSize;
        mockMetadata('TerritoryAliasSyncBatch', 200);
		User adminUser = TestDataFactory.getTestUser('System Administrator', new Map<String, Object>{
            'FirstName' => 'Admin',
                'LastName' => 'TestUser'
                });
        insert adminUser;
        Test.startTest();
        System.runAs(adminUser) {
           batchSize = BatchConfigurationUtil.getBatchSize('TerritoryAliasSyncBatch');
        }
        Test.stopTest();

        System.assertEquals(200, batchSize, 'Should return batch size from config');
    }


    /**
     * @description Test getting batch size with existing custom metadata
     *              Uses the TerritoryAliasSyncBatch custom metadata deployed to org
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testGetBatchSizeWithExistingConfig() {
        Integer batchSize;
        User testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
           batchSize = BatchConfigurationUtil.getBatchSize('TerritoryAliasSyncBatch');
        }
        Test.stopTest();
        System.assertNotEquals(null, batchSize, 'Batch size should not be null');
        System.assert(batchSize >= 1 && batchSize <= 2000, 'Batch size should be within valid range (1-2000)');
        System.assertEquals(200, batchSize, 'TerritoryAliasSyncBatch should have batch size of 200');
    }
    /**
     * @description Test getting batch size with non-existent configuration
     *              Should return default batch size of 200
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testGetBatchSizeNonExistent() {
        Integer batchSize;
        user testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
            batchSize = BatchConfigurationUtil.getBatchSize('');
        }
        Test.stopTest();
        System.assertEquals(200, batchSize, 'Should return default batch size (200) for non-existent config');
    }
    /**
     * @description Test getting batch size with blank class name
     *              Should return default batch size of 200
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testGetBatchSizeBlankString() {
        Integer batchSize;
        user testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
            batchSize = BatchConfigurationUtil.getBatchSize('NonExistentBatchClass');
        }
        Test.stopTest();
        System.assertEquals(200, batchSize, 'Should return default (200) for blank string');
    }
    /**
     * @description Test getting batch size with null class name
     *              Should return default batch size of 200
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testGetBatchSizeNull() {
        Integer batchSize;
        user testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
            batchSize = BatchConfigurationUtil.getBatchSize(null);
        }
        Test.stopTest();
        System.assertEquals(200, batchSize, 'Should return default (200) for null');
    }
    /**
     * @description Test batch size validation - below minimum (should return 1)
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testValidateBatchSizeBelowMinimum() {
        Integer validatedSize;
        user testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
             validatedSize = BatchConfigurationUtil.validateBatchSize(0);
        }
        Test.stopTest();
        System.assertEquals(1, validatedSize, 'Batch size below 1 should be adjusted to minimum of 1');
    }
    /**
     * @description Test batch size validation - at minimum (should return 1)
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testValidateBatchSizeAtMinimum() {
        Integer validatedSize;
        user testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
            validatedSize = BatchConfigurationUtil.validateBatchSize(1);
        }
        Test.stopTest();
        System.assertEquals(1, validatedSize, 'Batch size of 1 should remain 1');
    }
    /**
     * @description Test batch size validation - within valid range
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testValidateBatchSizeWithinRange() {
        Integer validatedSize;
        user testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
            validatedSize = BatchConfigurationUtil.validateBatchSize(200);
        }
        Test.stopTest();
        System.assertEquals(200, validatedSize, 'Batch size within range should remain unchanged');
    }
    /**
     * @description Test batch size validation - at maximum (should return 2000)
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testValidateBatchSizeAtMaximum() {
        Integer validatedSize;
        user testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
            validatedSize = BatchConfigurationUtil.validateBatchSize(2000);
        }
        Test.stopTest();
        System.assertEquals(2000, validatedSize, 'Batch size of 2000 should remain 2000');
    }
    /**
     * @description Test batch size validation - above maximum (should return 2000)
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testValidateBatchSizeAboveMaximum() {
        Integer validatedSize;
        user testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
            validatedSize = BatchConfigurationUtil.validateBatchSize(3000);
        }
        Test.stopTest();
        System.assertEquals(2000, validatedSize, 'Batch size above 2000 should be adjusted to maximum of 2000');
    }
    /**
     * @description Test cache clearing functionality
     *              Verifies that cache can be cleared and reloaded
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testCacheClear() {
        Integer batchSize1;
        Integer batchSize2;
        user testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
            batchSize1 = BatchConfigurationUtil.getBatchSize('TerritoryAliasSyncBatch');
            BatchConfigurationUtil.clearCache();
            batchSize2 = BatchConfigurationUtil.getBatchSize('TerritoryAliasSyncBatch');
        }
        Test.stopTest();
        System.assertEquals(batchSize1, batchSize2, 'Batch sizes should be consistent after cache clear and reload');
    }
    /**
     * @description Test multiple consecutive calls to verify caching works
     *              All calls after the first should use cached data
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testMultipleCalls() {
        Integer batchSize1;
        Integer batchSize2;
        Integer batchSize3;
        user testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
        batchSize1 = BatchConfigurationUtil.getBatchSize('TerritoryAliasSyncBatch');
        batchSize2 = BatchConfigurationUtil.getBatchSize('TerritoryAliasSyncBatch');
        batchSize3 = BatchConfigurationUtil.getBatchSize('TerritoryAliasSyncBatch');
        }
        Test.stopTest();
        System.assertEquals(batchSize1, batchSize2, 'First and second calls should return same value');
        System.assertEquals(batchSize2, batchSize3, 'Second and third calls should return same value');
        System.assertNotEquals(null, batchSize1, 'All calls should return non-null values');
    }
    /**
     * @description Test waitTimeAfterCreation
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testGetWaitTimeAfterCreation() {
        Integer waitTimeAfterCreation;
        Integer getProcessingWindow;
        user testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
            waitTimeAfterCreation = BatchConfigurationUtil.getWaitTimeAfterCreation('');
            getProcessingWindow = BatchConfigurationUtil.getProcessingWindow('');
        }
        Test.stopTest();
        System.assertEquals(null, waitTimeAfterCreation, 'Wait time after creation is null');
        System.assertEquals(null, getProcessingWindow, 'processing window is null');
    }

    /**
     * @description Test getting batch size with existing custom metadata
     *              Uses the DTC Incomplete Task Batch custom metadata deployed to org
     * Is parallel is not allowed on the current method
     */
    @IsTest
    static void testDtcIncompleteTaskBatchConfig() {
        Integer waitTimeAfterCreation;
        Integer getProcessingWindow;
        Integer batchSize;
        User testUser = TestDataFactory.getTestUser();
        insert testUser;
        Test.startTest();
        System.runAs(testUser) {
           mockMetadata('DTCIncompleteTaskBatch', 200);
           batchSize = BatchConfigurationUtil.getBatchSize('DTCIncompleteTaskBatch');
           waitTimeAfterCreation = BatchConfigurationUtil.getWaitTimeAfterCreation('DTCIncompleteTaskBatch');
		   getProcessingWindow = BatchConfigurationUtil.getProcessingWindow('DTCIncompleteTaskBatch');
        }
        Test.stopTest();
        System.assertEquals(true, waitTimeAfterCreation != null , 'Wait time after creation should not be null');
        System.assertEquals(true, getProcessingWindow != null, 'Processing window should not be null');
    }
}