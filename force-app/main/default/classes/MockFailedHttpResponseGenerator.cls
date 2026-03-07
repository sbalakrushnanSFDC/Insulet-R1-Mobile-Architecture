/**
 * @Author      : Niranjan Elangovan
 * @Created Date: 19th September 2025
 * @description : Mock class to set exception to the callout and test the negative response from the downstream system.
 * @Story Number: NGONDL-190
 */

public with sharing class MockFailedHttpResponseGenerator implements HttpCalloutMock{
    /**
        * @description Mocks a failed HTTP response with a 500 status code.
        * @param req The HTTPRequest object for the callout.
        * @return A mocked HTTPResponse with a 500 status code.
     */
    public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('Error occurred');
            res.setStatusCode(500);
            return res;
        }
}