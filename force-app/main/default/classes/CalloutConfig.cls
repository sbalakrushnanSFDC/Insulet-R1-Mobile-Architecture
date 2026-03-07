/**
 * @Author      : Niranjan Elangovan
 * @Created Date: 19th September 2025
 * @description : Utility class to set the variables for callout.
 * @Story Number: NGONDL-190
 */
public with sharing class CalloutConfig {
     /**
      * @description The name of the Named Credential to use for the callout.
      */
    @AuraEnabled public String namedCredential { get; set; }
    /**
     * @description The resource path for the API endpoint.
     */
    @AuraEnabled public String resourcePath    { get; set; }
    /**
     * @description The HTTP method (e.g., GET, POST) for the callout.
     */
    @AuraEnabled public String method          { get; set; }
    /**
     * @description The request body for the callout.
     */
    @AuraEnabled public String body            { get; set; }
    /**
     * @description The HTTP headers to include in the callout request.
     */
    @AuraEnabled public Map<String, String> headers { get; set; }
    
    /**
     * @description Constructor to initialize CalloutConfig with required parameters.
     * @param namedCredential The name of the Named Credential to use for the callout.
     * @param resourcePath The resource path for the API endpoint.
     * @param method The HTTP method (e.g., GET, POST) for the callout.
     */
    public CalloutConfig(String namedCredential, String resourcePath, String method) {
        this.namedCredential = namedCredential;
        this.resourcePath    = resourcePath;
        this.method          = method;
        this.headers         = new Map<String, String>();
    }
}