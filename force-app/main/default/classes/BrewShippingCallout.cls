/**
 * Calls the DHL rate-quote endpoint to compute shipping cost for a
 * subscription delivery. Returns EUR with 2-decimal precision.
 *
 * Tests mock the HTTP callout via Test.setMock(HttpCalloutMock.class, ...).
 */
public with sharing class BrewShippingCallout {

    public class ShippingException extends Exception {}

    private static final String ENDPOINT = 'https://api.dhl.example/rates/v1/quote';

    public class Quote {
        public Decimal amount;
        public String  currencyIso;
        public Integer estimatedDays;
    }

    public static Quote getRate(String postalCode, Decimal weightKg) {
        if (String.isBlank(postalCode) || weightKg == null || weightKg <= 0) {
            throw new ShippingException('postalCode and weightKg required');
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{
            'postalCode' => postalCode,
            'weightKg'   => weightKg,
            'origin'     => '10115'
        }));
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new ShippingException(
                'DHL rate lookup failed: ' + res.getStatusCode() + ' ' + res.getStatus()
            );
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Quote q = new Quote();
        q.amount        = (Decimal) body.get('amount');
        q.currencyIso   = (String)  body.get('currency');
        q.estimatedDays = (Integer) body.get('estimatedDays');
        if (q.amount == null) {
            throw new ShippingException('Malformed rate response: missing amount');
        }
        return q;
    }
}
