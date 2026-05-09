/**
 * REST facade over BrewSubscriptionService. Exposes subscription
 * lifecycle to external clients (storefront, mobile app).
 *
 * URL: /services/apexrest/subscriptions/*
 *   POST   /subscriptions             — activate
 *   GET    /subscriptions/{id}        — fetch
 *   PATCH  /subscriptions/{id}        — pause | resume | cancel
 */
@RestResource(urlMapping='/subscriptions/*')
global with sharing class BrewSubscriptionApi {

    @HttpPost
    global static void activate() {
        Map<String, Object> body = readBody();
        if (body == null) { badRequest('Request body is required'); return; }
        try {
            Id accountId    = toId(body.get('accountId'));
            Id productId    = toId(body.get('productId'));
            String cadence  = (String) body.get('cadence');
            Date startDate  = toDate(body.get('startDate'));
            if (startDate == null) startDate = Date.today();

            Subscription__c s = BrewSubscriptionService.activate(accountId, productId, cadence, startDate);
            writeJson(201, toMap(load(s.Id)));
        } catch (BrewSubscriptionService.SubscriptionException e) {
            badRequest(e.getMessage());
        }
    }

    @HttpGet
    global static void fetch() {
        Id subId = parseIdFromUri();
        if (subId == null) { badRequest('Subscription Id is required'); return; }
        List<Subscription__c> rows = [
            SELECT Id, Account__c, Product__c, Cadence__c, Status__c,
                   StartDate__c, NextDeliveryDate__c, MonthlyPrice__c
            FROM Subscription__c WHERE Id = :subId
        ];
        if (rows.isEmpty()) {
            writeJson(404, new Map<String, Object>{ 'message' => 'Not found' });
            return;
        }
        writeJson(200, toMap(rows[0]));
    }

    @HttpPatch
    global static void transition() {
        Id subId = parseIdFromUri();
        if (subId == null) { badRequest('Subscription Id is required'); return; }
        Map<String, Object> body = readBody();
        if (body == null) { badRequest('action is required (pause | resume | cancel)'); return; }
        String action = (String) body.get('action');
        if (String.isBlank(action)) { badRequest('action is required (pause | resume | cancel)'); return; }
        try {
            switch on action.toLowerCase() {
                when 'pause' {
                    BrewSubscriptionService.pause(subId);
                }
                when 'resume' {
                    Date d = toDate(body.get('resumeDate'));
                    if (d == null) d = Date.today();
                    BrewSubscriptionService.resume(subId, d);
                }
                when 'cancel' {
                    BrewSubscriptionService.cancel(subId, (String) body.get('reason'));
                }
                when else {
                    badRequest('Unknown action: ' + action);
                    return;
                }
            }
            writeJson(200, toMap(load(subId)));
        } catch (BrewSubscriptionService.SubscriptionException e) {
            badRequest(e.getMessage());
        }
    }

    private static Subscription__c load(Id subId) {
        return [
            SELECT Id, Account__c, Product__c, Cadence__c, Status__c,
                   StartDate__c, NextDeliveryDate__c, MonthlyPrice__c
            FROM Subscription__c WHERE Id = :subId
        ];
    }

    private static Map<String, Object> toMap(Subscription__c s) {
        return new Map<String, Object>{
            'id'                => s.Id,
            'accountId'         => s.Account__c,
            'productId'         => s.Product__c,
            'cadence'           => s.Cadence__c,
            'status'            => s.Status__c,
            'startDate'         => s.StartDate__c,
            'nextDeliveryDate'  => s.NextDeliveryDate__c,
            'monthlyPrice'      => s.MonthlyPrice__c
        };
    }

    private static Map<String, Object> readBody() {
        if (RestContext.request == null || RestContext.request.requestBody == null) return null;
        String raw = RestContext.request.requestBody.toString();
        if (String.isBlank(raw)) return null;
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(raw);
        } catch (Exception e) {
            return null;
        }
    }

    private static Id parseIdFromUri() {
        String uri = RestContext.request == null ? null : RestContext.request.requestURI;
        if (String.isBlank(uri)) return null;
        Integer slash = uri.lastIndexOf('/');
        if (slash < 0 || slash == uri.length() - 1) return null;
        String tail = uri.substring(slash + 1);
        try {
            return (Id) tail;
        } catch (Exception e) {
            return null;
        }
    }

    private static Id toId(Object v) {
        if (v == null) return null;
        try { return (Id) String.valueOf(v); } catch (Exception e) { return null; }
    }

    private static Date toDate(Object v) {
        if (v == null) return null;
        try { return Date.valueOf(String.valueOf(v)); } catch (Exception e) { return null; }
    }

    private static void badRequest(String msg) {
        writeJson(400, new Map<String, Object>{ 'message' => msg });
    }

    private static void writeJson(Integer statusCode, Map<String, Object> body) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(body));
    }
}
