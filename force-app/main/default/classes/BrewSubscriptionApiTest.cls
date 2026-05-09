@IsTest
private class BrewSubscriptionApiTest {

    private static void newRequest(String method, String uri, Object body) {
        RestRequest req = new RestRequest();
        req.httpMethod  = method;
        req.requestURI  = uri;
        if (body != null) {
            req.requestBody = Blob.valueOf(JSON.serialize(body));
        }
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    private static Map<String, Object> readResponse() {
        Blob b = RestContext.response.responseBody;
        if (b == null) return null;
        return (Map<String, Object>) JSON.deserializeUntyped(b.toString());
    }

    @IsTest
    static void post_activatesSubscription_returns201() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 12.00, 5.00);

        Map<String, Object> body = new Map<String, Object>{
            'accountId' => a.Id,
            'productId' => p.Id,
            'cadence'   => 'Monthly',
            'startDate' => String.valueOf(Date.today())
        };
        newRequest('POST', '/subscriptions', body);

        BrewSubscriptionApi.activate();
        Map<String, Object> out = readResponse();

        Assert.areEqual(201, RestContext.response.statusCode);
        Assert.isNotNull(out);
        Assert.areEqual('Active', (String) out.get('status'));
        Assert.areEqual(12.00, (Decimal) out.get('monthlyPrice'));
        Assert.areEqual(Date.today().addMonths(1), Date.valueOf((String) out.get('nextDeliveryDate')));
    }

    @IsTest
    static void post_missingBody_returns400() {
        newRequest('POST', '/subscriptions', null);
        BrewSubscriptionApi.activate();
        Map<String, Object> out = readResponse();
        Assert.areEqual(400, RestContext.response.statusCode);
        Assert.areEqual('Request body is required', (String) out.get('message'));
    }

    @IsTest
    static void post_creditHold_returns400_withMessage() {
        Account a = BrewTestFactory.account('A');
        a.OnCreditHold__c = true;
        update a;
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);

        Map<String, Object> body = new Map<String, Object>{
            'accountId' => a.Id,
            'productId' => p.Id,
            'cadence'   => 'Monthly'
        };
        newRequest('POST', '/subscriptions', body);

        BrewSubscriptionApi.activate();
        Map<String, Object> out = readResponse();
        Assert.areEqual(400, RestContext.response.statusCode);
        Assert.isTrue(((String) out.get('message')).contains('credit hold'));
    }

    @IsTest
    static void get_returnsSubscription() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Weekly');
        newRequest('GET', '/subscriptions/' + s.Id, null);

        BrewSubscriptionApi.fetch();
        Map<String, Object> out = readResponse();

        Assert.areEqual(s.Id, (Id) out.get('id'));
        Assert.areEqual('Weekly', (String) out.get('cadence'));
    }

    @IsTest
    static void get_missingId_returns400() {
        newRequest('GET', '/subscriptions/', null);
        BrewSubscriptionApi.fetch();
        Map<String, Object> out = readResponse();
        Assert.areEqual(400, RestContext.response.statusCode);
        Assert.areEqual('Subscription Id is required', (String) out.get('message'));
    }

    @IsTest
    static void get_unknownId_returns404() {
        Id fake = '0010000000000000AAA';
        newRequest('GET', '/subscriptions/' + fake, null);
        BrewSubscriptionApi.fetch();
        Map<String, Object> out = readResponse();
        Assert.areEqual(404, RestContext.response.statusCode);
        Assert.areEqual('Not found', (String) out.get('message'));
    }

    @IsTest
    static void patch_pause_setsStatusPaused() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');

        newRequest('PATCH', '/subscriptions/' + s.Id, new Map<String, Object>{ 'action' => 'pause' });
        BrewSubscriptionApi.transition();
        Map<String, Object> out = readResponse();
        Assert.areEqual('Paused', (String) out.get('status'));
    }

    @IsTest
    static void patch_resume_updatesNextDelivery() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Weekly');
        BrewSubscriptionService.pause(s.Id);

        newRequest('PATCH', '/subscriptions/' + s.Id, new Map<String, Object>{
            'action'     => 'resume',
            'resumeDate' => String.valueOf(Date.newInstance(2026, 7, 1))
        });
        BrewSubscriptionApi.transition();
        Map<String, Object> out = readResponse();
        Assert.areEqual('Active', (String) out.get('status'));
        Assert.areEqual(Date.newInstance(2026, 7, 8), Date.valueOf((String) out.get('nextDeliveryDate')));
    }

    @IsTest
    static void patch_cancel_clearsNextDelivery() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');

        newRequest('PATCH', '/subscriptions/' + s.Id, new Map<String, Object>{
            'action' => 'cancel',
            'reason' => 'user request'
        });
        BrewSubscriptionApi.transition();
        Map<String, Object> out = readResponse();
        Assert.areEqual('Cancelled', (String) out.get('status'));
        Assert.areEqual(null, (Date) out.get('nextDeliveryDate'));
    }

    @IsTest
    static void patch_unknownAction_returns400() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');

        newRequest('PATCH', '/subscriptions/' + s.Id, new Map<String, Object>{ 'action' => 'explode' });
        BrewSubscriptionApi.transition();
        Map<String, Object> out = readResponse();
        Assert.areEqual(400, RestContext.response.statusCode);
        Assert.isTrue(((String) out.get('message')).contains('Unknown action'));
    }

    @IsTest
    static void patch_missingAction_returns400() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');

        newRequest('PATCH', '/subscriptions/' + s.Id, new Map<String, Object>{});
        BrewSubscriptionApi.transition();
        Map<String, Object> out = readResponse();
        Assert.areEqual(400, RestContext.response.statusCode);
    }

    @IsTest
    static void patch_resumeOnActive_returns400() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');

        newRequest('PATCH', '/subscriptions/' + s.Id, new Map<String, Object>{ 'action' => 'resume' });
        BrewSubscriptionApi.transition();
        Map<String, Object> out = readResponse();
        Assert.areEqual(400, RestContext.response.statusCode);
        Assert.isTrue(((String) out.get('message')).contains('Only paused'));
    }
}
