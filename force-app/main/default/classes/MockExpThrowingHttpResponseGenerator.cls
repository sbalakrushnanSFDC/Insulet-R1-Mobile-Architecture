/**
 * @Author      : Niranjan Elangovan
 * @Created Date: 19th September 2025
 * @description : Mock class to set exception to the callout and test the call out exception handling.
 * @Story Number: NGONDL-190
 */
public with sharing class MockExpThrowingHttpResponseGenerator implements HttpCalloutMock{
    /**
        * @description Mocks an HTTP callout that throws a CalloutException.
        * @param req The HTTP request to respond to.
        * @return Never returns; always throws CalloutException.
     */
    public HttpResponse respond(HttpRequest req) {
        throw new CalloutException('Simulated network failure');
    }
}