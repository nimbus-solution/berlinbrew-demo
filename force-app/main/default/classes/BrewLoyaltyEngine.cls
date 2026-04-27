/**
 * Loyalty points engine. Awards points on purchase, computes tier,
 * and fires a ShipmentEvent__e when a customer graduates tiers.
 *
 * Tier thresholds are driven by lifetime points (not lifetime spend) so
 * that redemptions don't push a customer backwards.
 */
public with sharing class BrewLoyaltyEngine {

    public static final Integer SILVER_THRESHOLD  = 500;
    public static final Integer GOLD_THRESHOLD    = 2000;
    public static final Integer ROASTER_THRESHOLD = 10000;

    public static Integer pointsForPurchase(Decimal amount) {
        if (amount == null || amount <= 0) return 0;
        return Integer.valueOf(amount.setScale(0, System.RoundingMode.DOWN));
    }

    public static String tierFor(Integer points) {
        if (points == null)                        return 'Bronze';
        if (points >= ROASTER_THRESHOLD)           return 'Roaster';
        if (points >= GOLD_THRESHOLD)              return 'Gold';
        if (points >= SILVER_THRESHOLD)            return 'Silver';
        return 'Bronze';
    }

    public static void awardPoints(Id accountId, Integer points, String reason) {
        if (accountId == null || points == null || points <= 0) return;
        Account a = [SELECT Id, LoyaltyPoints__c, LoyaltyTier__c FROM Account WHERE Id = :accountId FOR UPDATE];
        Integer current = Integer.valueOf(a.LoyaltyPoints__c == null ? 0 : a.LoyaltyPoints__c);
        String previousTier = a.LoyaltyTier__c == null ? 'Bronze' : a.LoyaltyTier__c;
        Integer updated = current + points;
        String newTier = tierFor(updated);

        a.LoyaltyPoints__c = updated;
        a.LoyaltyTier__c   = newTier;
        update a;

        insert new LoyaltyTransaction__c(
            Account__c = accountId,
            Points__c  = points,
            Reason__c  = reason
        );

        if (newTier != previousTier) {
            EventBus.publish(new ShipmentEvent__e(
                SubscriptionId__c = accountId,
                TrackingNumber__c = null,
                EventType__c      = 'TIER_GRADUATED:' + previousTier + '->' + newTier
            ));
        }
    }

    public static void awardPointsBulk(Map<Id, Integer> pointsByAccount) {
        if (pointsByAccount == null || pointsByAccount.isEmpty()) return;
        List<Account> toUpdate = new List<Account>();
        List<LoyaltyTransaction__c> txns = new List<LoyaltyTransaction__c>();
        List<ShipmentEvent__e> events = new List<ShipmentEvent__e>();

        Map<Id, Account> existing = new Map<Id, Account>(
            [SELECT Id, LoyaltyPoints__c, LoyaltyTier__c FROM Account WHERE Id IN :pointsByAccount.keySet()]
        );
        for (Id accId : pointsByAccount.keySet()) {
            Account a = existing.get(accId);
            if (a == null) continue;
            Integer delta = pointsByAccount.get(accId);
            if (delta == null || delta <= 0) continue;
            Integer current = Integer.valueOf(a.LoyaltyPoints__c == null ? 0 : a.LoyaltyPoints__c);
            String prev = a.LoyaltyTier__c == null ? 'Bronze' : a.LoyaltyTier__c;
            Integer updated = current + delta;
            String next = tierFor(updated);
            a.LoyaltyPoints__c = updated;
            a.LoyaltyTier__c   = next;
            toUpdate.add(a);
            txns.add(new LoyaltyTransaction__c(Account__c = accId, Points__c = delta, Reason__c = 'Purchase'));
            if (next != prev) {
                events.add(new ShipmentEvent__e(
                    SubscriptionId__c = accId,
                    EventType__c      = 'TIER_GRADUATED:' + prev + '->' + next
                ));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
        if (!txns.isEmpty())     insert txns;
        if (!events.isEmpty())   EventBus.publish(events);
    }
}
