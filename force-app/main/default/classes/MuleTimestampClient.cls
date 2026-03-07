/**
 * @Author      : Niranjan Elangovan
 * @Created Date: 19th September 2025
 * @description : Main class to make the callout to MuleSoft API to fetch the current timestamp.
 * @Story Number: NGONDL-190
 */
public with sharing class MuleTimestampClient {
    /**
     * @description Makes a callout to the MuleSoft API to fetch the current timestamp.
     * @return String The current timestamp from the MuleSoft API.
     * @throws CalloutException if the callout fails or returns a non-200 status code.
     */
    public static String getTimestamp() {
        CalloutConfig cfg = new CalloutConfig(
            'Mulesoft_Named_Credentials',
            '/api/timestamp',
            'GET'
        );
        HttpResponse res = HttpIntegrationService.send(cfg);
        if (res.getStatusCode() == 200) {
            return res.getBody();
        } else {
            throw new CalloutException('Failed: ' + res.getStatus() + ' - ' + res.getBody());
        }
    }
}