/**
 * @description Test class for IdentifierService
 * Created Date : 30th Jan 2026
 * Created By   : Saikat Ghosh
 *
 * =========================== Logs ======================================
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       30th Jan 2026       Saikat Ghosh       (US - NGOMCT-1750)- Initial test class
 */
@IsTest(IsParallel=true)
public class IdentifierService_Test {

    /**
     * @description Test populateIdValueWithUUID when IdValue is null
     */
    @IsTest
    static void testPopulateIdValueWithUUIDNullIdValue() {
        Identifier idf = new Identifier();
        idf.IdValue = null;

        List<Identifier> identifiers = new List<Identifier>{ idf };

        Test.startTest();
        IdentifierService.populateIdValueWithUUID(identifiers);
        Test.stopTest();

        System.assertNotEquals(
            null,
            idf.IdValue,
            'IdValue should be populated with UUID when null'
        );
    }

    /**
     * @description Test populateIdValueWithUUID when IdValue already exists
     */
    @IsTest
    static void testPopulateIdValueWithUUIDExistingValue() {
        Identifier idf = new Identifier();
        idf.IdValue = 'EXISTING_ID_VALUE';

        List<Identifier> identifiers = new List<Identifier>{ idf };

        Test.startTest();
        IdentifierService.populateIdValueWithUUID(identifiers);
        Test.stopTest();

        System.assertEquals(
            'EXISTING_ID_VALUE',
            idf.IdValue,
            'Existing IdValue should not be overwritten'
        );
    }

    /**
     * @description Test populateIdValueWithUUID with empty list
     */
    @IsTest
    static void testPopulateIdValueWithUUIDEmptyList() {
        Test.startTest();
        IdentifierService.populateIdValueWithUUID(new List<Identifier>());
        Test.stopTest();

        System.assert(true, 'Method should safely handle empty list');
    }
}