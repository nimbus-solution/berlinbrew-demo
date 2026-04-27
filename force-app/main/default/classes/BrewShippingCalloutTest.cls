@IsTest
private class BrewShippingCalloutTest {

    private class OkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            Assert.areEqual('POST', req.getMethod());
            Assert.areEqual('application/json', req.getHeader('Content-Type'));
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setStatus('OK');
            r.setHeader('Content-Type', 'application/json');
            r.setBody('{"amount": 4.99, "currency": "EUR", "estimatedDays": 3}');
            return r;
        }
    }

    private class Error500Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(500);
            r.setStatus('Internal Server Error');
            return r;
        }
    }

    private class MalformedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody('{"currency": "EUR"}');
            return r;
        }
    }

    @IsTest static void getRate_happyPath_parses() {
        Test.setMock(HttpCalloutMock.class, new OkMock());
        BrewShippingCallout.Quote q = BrewShippingCallout.getRate('10115', 0.25);
        Assert.areEqual(4.99, q.amount);
        Assert.areEqual('EUR', q.currencyIso);
        Assert.areEqual(3, q.estimatedDays);
    }

    @IsTest static void getRate_httpError_throws() {
        Test.setMock(HttpCalloutMock.class, new Error500Mock());
        try {
            BrewShippingCallout.getRate('10115', 0.25);
            Assert.fail();
        } catch (BrewShippingCallout.ShippingException e) {
            Assert.isTrue(e.getMessage().contains('500'));
        }
    }

    @IsTest static void getRate_malformedResponse_throws() {
        Test.setMock(HttpCalloutMock.class, new MalformedMock());
        try {
            BrewShippingCallout.getRate('10115', 0.25);
            Assert.fail();
        } catch (BrewShippingCallout.ShippingException e) {
            Assert.isTrue(e.getMessage().contains('missing amount'));
        }
    }

    @IsTest static void getRate_blankPostalCode_throws() {
        try {
            BrewShippingCallout.getRate('', 0.25);
            Assert.fail();
        } catch (BrewShippingCallout.ShippingException e) {
            Assert.isTrue(e.getMessage().contains('required'));
        }
    }

    @IsTest static void getRate_zeroWeight_throws() {
        try {
            BrewShippingCallout.getRate('10115', 0);
            Assert.fail();
        } catch (BrewShippingCallout.ShippingException e) {
            Assert.isTrue(e.getMessage().contains('required'));
        }
    }
}
