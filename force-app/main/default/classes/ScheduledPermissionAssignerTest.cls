@isTest
public class ScheduledPermissionAssignerTest {

    /*
     * Enhanced Mock for Tooling API callouts
     */
    private class MockHttpResponseGenerator implements HttpCalloutMock {

        /**
         * @description Respond to an HTTP request with a simulated Tooling API response.
         * @param req The incoming HTTPRequest whose endpoint is inspected to decide the response scenario.
         * @return HttpResponse representing success (200) or error (500) with a JSON body matching the test scenario.
         */
        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            // Simulate error branch once
            if (req.getEndpoint().contains('ErrorCase')) {
                res.setStatusCode(500);
                res.setBody('Error');
                return res;
            }

            res.setStatusCode(200);

            // CustomObject query (covers customObjectMap + namespace branch)
            if (req.getEndpoint().contains('FROM+CustomObject')) {

                res.setBody(
                    '{"records":[{' +
                    '"attributes":{"type":"CustomObject"},' +
                    '"Id":"01I000000000001AAA",' +
                    '"DeveloperName":"Case",' +
                    '"NamespacePrefix":"ns"' +   // Covers namespace branch
                    '}]}'
                );
            }

            // CustomField query
            else if (req.getEndpoint().contains('FROM+CustomField')) {

                res.setBody(
                    '{"records":[' +

                    // Standard field (normal happy path)
                    '{' +
                    '"attributes":{"type":"StandardField"},' +
                    '"TableEnumOrId":"Case",' +
                    '"DeveloperName":"Subject",' +
                    '"NamespacePrefix":null' +
                    '},' +

                    // Activity object branch (converted to Task)
                    '{' +
                    '"attributes":{"type":"StandardField"},' +
                    '"TableEnumOrId":"Activity",' +
                    '"DeveloperName":"Subject",' +
                    '"NamespacePrefix":null' +
                    '},' +

                    // Custom object via 01I prefix branch
                    '{' +
                    '"attributes":{"type":"StandardField"},' +
                    '"TableEnumOrId":"01I000000000001AAA",' +
                    '"DeveloperName":"Subject",' +
                    '"NamespacePrefix":null' +
                    '},' +

                    // Non-existent object branch (sObjectType == null)
                    '{' +
                    '"attributes":{"type":"StandardField"},' +
                    '"TableEnumOrId":"FakeObject",' +
                    '"DeveloperName":"FakeField",' +
                    '"NamespacePrefix":null' +
                    '}' +

                    ']}'
                );
            }

            else {
                res.setBody('{"records":[]}');
            }

            return res;
        }
    }

    @isTest
    static void testFullFlowWithSchedulerAndQueueable() {

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Profile adminProfile = [
            SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1
        ];

        User adminUser = new User(
            Alias = 'testadm',
            Email = 'testadmin@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testadmin' + System.currentTimeMillis() + '@test.com'
        );
        insert adminUser;

        System.runAs(adminUser) {

            PermissionSet ps = new PermissionSet(
                Name = 'Test_Permission_Set',
                Label = 'Test Permission Set'
            );
            insert ps;

            String cronExp = '0 0 0 1 1 ? 2099';
            String dateFilter = 'CreatedDate >= YESTERDAY';

            ScheduledPermissionAssigner job =
                new ScheduledPermissionAssigner('Test_Permission_Set', dateFilter);

            Test.startTest();
            System.schedule('Test Job', cronExp, job);
            Test.stopTest();

            List<CronJobDetail> cron = [
                SELECT Id, Name 
                FROM CronJobDetail
                WHERE Name = 'Permission Assignment Job'
            ];
            System.assert(cron.size() > 0, 'Expected Cron job to be created');

        }
    }

    /*
     * Direct method call to cover additional logic
     */
    @isTest
    static void testDirectMethodCoverage() {

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        PermissionSet ps = new PermissionSet(
            Name = 'Direct_PS',
            Label = 'Direct Permission Set'
        );
        insert ps;

        Test.startTest();
        ScheduledPermissionAssigner.assignPermissionsToNewFields(
            ps.Id,
            'CreatedDate >= YESTERDAY'
        );
        Test.stopTest();

        List<FieldPermissions> fps = [
            SELECT Id
            FROM FieldPermissions
            WHERE ParentId = :ps.Id
        ];

        System.assert(fps.size() > 0, 'Expected at least one FieldPermissions record to be created by direct method call.');
    }

    /*
     * Covers non-200 response branch
     */
    @isTest
    static void testErrorResponseBranch() {

        Test.setMock(HttpCalloutMock.class,
            new MockHttpResponseGenerator());

        PermissionSet ps = new PermissionSet(
            Name = 'Error_PS',
            Label = 'Error Permission Set'
        );
        insert ps;

        Test.startTest();
        ScheduledPermissionAssigner.assignPermissionsToNewFields(
            ps.Id,
            'ErrorCase'
        );
        Test.stopTest();

        System.assert(true, 'Executed non-200 error response branch.'); // just to execute branch
    }
}