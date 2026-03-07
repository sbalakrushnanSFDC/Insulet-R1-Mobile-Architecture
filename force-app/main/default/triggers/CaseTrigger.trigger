/**
 * @author      : Saikat Ghosh
 * @created Date: 25th Feb 2026
 * @description : Main trigger for Case that delegates processing to the handler class.
 *
 * Version      Modified Date       Modified By        Brief Note
 * V1.0.0       25th Feb 2026       Saikat Ghosh       (US - NGASIM-2045) Initial version – trigger framework setup
 */
trigger CaseTrigger on Case(
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete,
    after undelete
) {
    new CaseTriggerHandler().execute();
}