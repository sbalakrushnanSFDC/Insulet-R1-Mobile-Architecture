/**
 * @author      : Saikat Ghosh
 * @created Date: 30th Jan 2026
 * @description : Main trigger for Identifier that delegates processing to the handler class.
 *
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       30th Jan 2026       Saikat Ghosh       (US - NGOMCT-1750) Initial version – trigger framework setup
 */
trigger IdentifierTrigger on Identifier(
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete,
    after undelete
) {
    new IdentifierTriggerHandler().execute();
}