/**
 * @Author      : Niranjan Elangovan
 * @Created Date: 19th September 2025
 * @description : Utility class to make the callout.
 * @Story Number: NGONDL-190
 */
public with sharing class HttpIntegrationService {
    /**
     * @description Sends an HTTP request based on the provided CalloutConfig and returns the response.
     * @param cfg The configuration for the HTTP callout.
     * @return HttpResponse The response from the HTTP callout.
     * @throws CalloutException if the callout fails.
     */
    public static HttpResponse send(CalloutConfig cfg) {
        Http http = new Http();
        HttpResponse res;
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + cfg.namedCredential + cfg.resourcePath);
            req.setMethod(cfg.method);
            if(cfg.headers != null && !cfg.headers.isEmpty()){
                for (String key : cfg.headers.keySet()) {
                    req.setHeader(key, cfg.headers.get(key));
                }
            }
            if (cfg.body != null) {
                req.setHeader('Content-Type', 'application/json');
                req.setBody(cfg.body);
            }
            res = http.send(req);
            // Log after callout
            return res;
        } catch (Exception e) {
            // Log failure
            throw e;
        }
    }
}