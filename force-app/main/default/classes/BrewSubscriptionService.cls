/**
 * Subscription lifecycle. Handles creation, renewal, pause/resume, cancel.
 *
 * Next-delivery calculation is deterministic given (startDate, cadence)
 * and is the same algorithm used by the billing job — keep it pure so
 * tests can validate without stubbing the clock.
 */
public with sharing class BrewSubscriptionService {

    public class SubscriptionException extends Exception {}

    public static Subscription__c activate(Id accountId, Id productId, String cadence, Date startDate) {
        if (accountId == null || productId == null) {
            throw new SubscriptionException('Account and Product are required');
        }
        Account acc = [SELECT Id, OnCreditHold__c FROM Account WHERE Id = :accountId];
        if (acc.OnCreditHold__c == true) {
            throw new SubscriptionException('Cannot activate subscription: account on credit hold');
        }
        CoffeeProduct__c product = [
            SELECT Id, RetailPrice__c, Active__c
            FROM CoffeeProduct__c WHERE Id = :productId
        ];
        if (product.Active__c == false) {
            throw new SubscriptionException('Product is not active');
        }
        Decimal monthly = BrewPricingService.calculateSubscriptionPrice(product, cadence);
        Subscription__c s = new Subscription__c(
            Account__c          = accountId,
            Product__c          = productId,
            Cadence__c          = cadence,
            Status__c           = 'Active',
            StartDate__c        = startDate,
            NextDeliveryDate__c = nextDeliveryAfter(startDate, cadence),
            MonthlyPrice__c     = monthly
        );
        insert s;
        return s;
    }

    public static Date nextDeliveryAfter(Date anchor, String cadence) {
        if (anchor == null) return null;
        switch on cadence {
            when 'Weekly'    { return anchor.addDays(7); }
            when 'Biweekly'  { return anchor.addDays(14); }
            when 'Monthly'   { return anchor.addMonths(1); }
            when 'Quarterly' { return anchor.addMonths(3); }
            when else        { throw new SubscriptionException('Unknown cadence: ' + cadence); }
        }
    }

    public static void pause(Id subscriptionId) {
        Subscription__c s = [SELECT Id, Status__c FROM Subscription__c WHERE Id = :subscriptionId FOR UPDATE];
        if (s.Status__c == 'Cancelled' || s.Status__c == 'Churned') {
            throw new SubscriptionException('Cannot pause a terminated subscription');
        }
        s.Status__c = 'Paused';
        update s;
    }

    public static void resume(Id subscriptionId, Date resumeDate) {
        Subscription__c s = [SELECT Id, Status__c, Cadence__c FROM Subscription__c WHERE Id = :subscriptionId FOR UPDATE];
        if (s.Status__c != 'Paused') {
            throw new SubscriptionException('Only paused subscriptions can be resumed');
        }
        s.Status__c           = 'Active';
        s.NextDeliveryDate__c = nextDeliveryAfter(resumeDate, s.Cadence__c);
        update s;
    }

    public static void cancel(Id subscriptionId, String reason) {
        Subscription__c s = [SELECT Id, Status__c FROM Subscription__c WHERE Id = :subscriptionId FOR UPDATE];
        s.Status__c           = 'Cancelled';
        s.NextDeliveryDate__c = null;
        update s;
    }

    public static List<Subscription__c> dueForDelivery(Date asOf) {
        return [
            SELECT Id, Account__c, Account__r.Name, Product__c, Cadence__c,
                   MonthlyPrice__c, Status__c, NextDeliveryDate__c
            FROM Subscription__c
            WHERE Status__c = 'Active' AND NextDeliveryDate__c <= :asOf
            ORDER BY NextDeliveryDate__c
        ];
    }

    public static Integer advanceDeliveries(List<Subscription__c> subs) {
        if (subs == null || subs.isEmpty()) return 0;
        List<Subscription__c> toUpdate = new List<Subscription__c>();
        Map<Id, Integer> pointsByAccount = new Map<Id, Integer>();
        for (Subscription__c s : subs) {
            if (s.Status__c != null && s.Status__c != 'Active') continue;
            s.NextDeliveryDate__c = nextDeliveryAfter(s.NextDeliveryDate__c, s.Cadence__c);
            toUpdate.add(s);
            Integer pts = BrewLoyaltyEngine.pointsForPurchase(s.MonthlyPrice__c);
            Integer running = pointsByAccount.get(s.Account__c);
            pointsByAccount.put(s.Account__c, (running == null ? 0 : running) + pts);
        }
        if (!toUpdate.isEmpty()) update toUpdate;
        BrewLoyaltyEngine.awardPointsBulk(pointsByAccount);
        return toUpdate.size();
    }
}
