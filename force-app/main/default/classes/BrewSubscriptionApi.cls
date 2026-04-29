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
    global static Map<String, Object> activate() {
        Map<String, Object> body = readBody();
        if (body == null) return badRequest('Request body is required');
        try {
            Id accountId    = toId(body.get('accountId'));
            Id productId    = toId(body.get('productId'));
            String cadence  = (String) body.get('cadence');
            Date startDate  = toDate(body.get('startDate'));
            if (startDate == null) startDate = Date.today();

            Subscription__c s = BrewSubscriptionService.activate(accountId, productId, cadence, startDate);
            RestContext.response.statusCode = 201;
            return toMap(load(s.Id));
        } catch (BrewSubscriptionService.SubscriptionException e) {
            return badRequest(e.getMessage());
        }
    }

    @HttpGet
    global static Map<String, Object> fetch() {
        Id subId = parseIdFromUri();
        if (subId == null) return badRequest('Subscription Id is required');
        List<Subscription__c> rows = [
            SELECT Id, Account__c, Product__c, Cadence__c, Status__c,
                   StartDate__c, NextDeliveryDate__c, MonthlyPrice__c
            FROM Subscription__c WHERE Id = :subId
        ];
        if (rows.isEmpty()) {
            RestContext.response.statusCode = 404;
            return new Map<String, Object>{ 'message' => 'Not found' };
        }
        return toMap(rows[0]);
    }

    @HttpPatch
    global static Map<String, Object> transition() {
        Id subId = parseIdFromUri();
        if (subId == null) return badRequest('Subscription Id is required');
        Map<String, Object> body = readBody();
        if (body == null) return badRequest('action is required (pause | resume | cancel)');
        String action = (String) body.get('action');
        if (String.isBlank(action)) return badRequest('action is required (pause | resume | cancel)');
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
                    return badRequest('Unknown action: ' + action);
                }
            }
            return toMap(load(subId));
        } catch (BrewSubscriptionService.SubscriptionException e) {
            return badRequest(e.getMessage());
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

    private static Map<String, Object> badRequest(String msg) {
        RestContext.response.statusCode = 400;
        return new Map<String, Object>{ 'message' => msg };
    }
}
