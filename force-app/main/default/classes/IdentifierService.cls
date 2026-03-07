/**
* @author      : Saikat Ghosh
* @created Date: 30th Jan 2026
* @description : Service class for Identifier-related operations.
*                Contains reusable and bulk-safe business logic.
*
* Version      Modified Date       Modified By        Brief Note
* V1.0.0       30th Jan 2026       Saikat Ghosh       (US - NGOMCT-1750) Initial service implementation
*/

/**
 * @description Service class for Identifier-related operations.
 *              Contains reusable and bulk-safe business logic for managing Identifier records.
 */
public inherited sharing class IdentifierService {
    
    /**
    * @description Populates IdValue with a randomly generated UUID
    *              for Identifier records where IdValue is null.
    * @param identifiers List of Identifier records
    */
    public static void populateIdValueWithUUID(List<Identifier> identifiers) {
        if(!identifiers.isEmpty()){
            for (Identifier idf : identifiers) {
                if (idf.IdValue == null) {
                    idf.IdValue = String.valueOf(UUID.randomUUID());
                }
            }
        }
    }
}