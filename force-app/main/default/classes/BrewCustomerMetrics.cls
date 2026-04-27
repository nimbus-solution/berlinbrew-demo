/**
 * Read-side analytics for customer cohorts, revenue, and churn.
 * Uses aggregate SOQL exclusively — no per-row processing in here.
 */
public with sharing class BrewCustomerMetrics {

    public class TierRollup {
        public String tier;
        public Integer customerCount;
        public Decimal totalLifetimeValue;
    }

    public class ChurnMetric {
        public String cadence;
        public Integer activeCount;
        public Integer churnedCount;
        public Decimal churnRate;
    }

    public static List<TierRollup> byTier() {
        AggregateResult[] rows = [
            SELECT LoyaltyTier__c tier, COUNT(Id) cnt, SUM(LifetimeValue__c) ltv
            FROM Account
            WHERE LoyaltyTier__c != null
            GROUP BY LoyaltyTier__c
            ORDER BY LoyaltyTier__c
        ];
        List<TierRollup> out = new List<TierRollup>();
        for (AggregateResult r : rows) {
            TierRollup t = new TierRollup();
            t.tier               = (String)  r.get('tier');
            t.customerCount      = (Integer) r.get('cnt');
            t.totalLifetimeValue = (Decimal) r.get('ltv');
            out.add(t);
        }
        return out;
    }

    public static Map<String, Decimal> monthlyRecurringRevenueByCadence() {
        AggregateResult[] rows = [
            SELECT Cadence__c cadence, SUM(MonthlyPrice__c) mrr
            FROM Subscription__c
            WHERE Status__c = 'Active'
            GROUP BY Cadence__c
        ];
        Map<String, Decimal> out = new Map<String, Decimal>();
        for (AggregateResult r : rows) {
            out.put((String) r.get('cadence'), (Decimal) r.get('mrr'));
        }
        return out;
    }

    public static List<ChurnMetric> churnByCadence() {
        AggregateResult[] activeRows = [
            SELECT Cadence__c cadence, COUNT(Id) cnt
            FROM Subscription__c
            WHERE Status__c = 'Active'
            GROUP BY Cadence__c
        ];
        AggregateResult[] churnedRows = [
            SELECT Cadence__c cadence, COUNT(Id) cnt
            FROM Subscription__c
            WHERE Status__c IN ('Cancelled', 'Churned')
            GROUP BY Cadence__c
        ];
        Map<String, Integer> active  = new Map<String, Integer>();
        Map<String, Integer> churned = new Map<String, Integer>();
        for (AggregateResult r : activeRows)  active.put((String) r.get('cadence'),  (Integer) r.get('cnt'));
        for (AggregateResult r : churnedRows) churned.put((String) r.get('cadence'), (Integer) r.get('cnt'));

        Set<String> allCadences = new Set<String>();
        allCadences.addAll(active.keySet());
        allCadences.addAll(churned.keySet());

        List<ChurnMetric> out = new List<ChurnMetric>();
        for (String c : allCadences) {
            Integer a = active.containsKey(c)  ? active.get(c)  : 0;
            Integer x = churned.containsKey(c) ? churned.get(c) : 0;
            ChurnMetric m = new ChurnMetric();
            m.cadence      = c;
            m.activeCount  = a;
            m.churnedCount = x;
            m.churnRate    = (a + x == 0) ? 0 : (Decimal.valueOf(x) / (a + x) * 100).setScale(2);
            out.add(m);
        }
        return out;
    }

    public static Decimal totalLifetimeRevenue() {
        AggregateResult[] rows = [SELECT SUM(LifetimeValue__c) total FROM Account];
        Decimal total = (Decimal) rows[0].get('total');
        return total == null ? 0 : total;
    }
}
