/**
 * Subscription trigger handler. Validates state transitions and
 * keeps account lifetime value in sync when subscriptions are billed.
 */
public with sharing class BrewSubscriptionHandler {

    private static final Set<String> TERMINAL = new Set<String>{ 'Cancelled', 'Churned' };

    public static void beforeInsert(List<Subscription__c> subs) {
        for (Subscription__c s : subs) {
            if (s.Status__c == null)    s.Status__c    = 'Active';
            if (s.StartDate__c == null) s.StartDate__c = Date.today();
            if (s.NextDeliveryDate__c == null && s.Cadence__c != null) {
                s.NextDeliveryDate__c = BrewSubscriptionService.nextDeliveryAfter(s.StartDate__c, s.Cadence__c);
            }
        }
    }

    public static void beforeUpdate(List<Subscription__c> subs, Map<Id, Subscription__c> oldMap) {
        for (Subscription__c s : subs) {
            Subscription__c prev = oldMap.get(s.Id);
            if (TERMINAL.contains(prev.Status__c) && s.Status__c != prev.Status__c) {
                s.addError('Cannot change status of a ' + prev.Status__c + ' subscription');
            }
            if (s.Status__c == 'Cancelled' && s.NextDeliveryDate__c != null) {
                s.NextDeliveryDate__c = null;
            }
        }
    }

    public static void afterUpdate(List<Subscription__c> subs, Map<Id, Subscription__c> oldMap) {
        Map<Id, Decimal> ltvDelta = new Map<Id, Decimal>();
        for (Subscription__c s : subs) {
            Subscription__c prev = oldMap.get(s.Id);
            if (prev.NextDeliveryDate__c != s.NextDeliveryDate__c
                && s.Status__c == 'Active'
                && prev.Status__c == 'Active'
                && s.MonthlyPrice__c != null) {
                Decimal running = ltvDelta.containsKey(s.Account__c) ? ltvDelta.get(s.Account__c) : 0;
                ltvDelta.put(s.Account__c, running + s.MonthlyPrice__c);
            }
        }
        if (ltvDelta.isEmpty()) return;

        Map<Id, Account> accts = new Map<Id, Account>(
            [SELECT Id, LifetimeValue__c FROM Account WHERE Id IN :ltvDelta.keySet()]
        );
        List<Account> toUpdate = new List<Account>();
        for (Id accId : ltvDelta.keySet()) {
            Account a = accts.get(accId);
            if (a == null) continue;
            a.LifetimeValue__c = (a.LifetimeValue__c == null ? 0 : a.LifetimeValue__c) + ltvDelta.get(accId);
            toUpdate.add(a);
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }
}
