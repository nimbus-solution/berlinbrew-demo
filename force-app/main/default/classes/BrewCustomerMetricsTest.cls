@IsTest
private class BrewCustomerMetricsTest {

    @TestSetup static void setup() {
        List<Account> accts = new List<Account>{
            new Account(Name = 'A1', LoyaltyTier__c = 'Bronze', LifetimeValue__c = 100),
            new Account(Name = 'A2', LoyaltyTier__c = 'Bronze', LifetimeValue__c = 50),
            new Account(Name = 'A3', LoyaltyTier__c = 'Silver', LifetimeValue__c = 500),
            new Account(Name = 'A4', LoyaltyTier__c = 'Gold',   LifetimeValue__c = 2000),
            new Account(Name = 'A5', LoyaltyTier__c = 'Gold',   LifetimeValue__c = 3000)
        };
        insert accts;

        CoffeeProduct__c p = new CoffeeProduct__c(Name = 'Blend', RetailPrice__c = 10);
        insert p;

        List<Subscription__c> subs = new List<Subscription__c>();
        for (Integer i = 0; i < 3; i++) {
            subs.add(new Subscription__c(
                Account__c = accts[i].Id,
                Product__c = p.Id,
                Cadence__c = 'Monthly',
                Status__c = 'Active',
                StartDate__c = Date.today(),
                MonthlyPrice__c = 10,
                NextDeliveryDate__c = Date.today().addDays(7)
            ));
        }
        for (Integer i = 0; i < 2; i++) {
            subs.add(new Subscription__c(
                Account__c = accts[i].Id,
                Product__c = p.Id,
                Cadence__c = 'Quarterly',
                Status__c = 'Active',
                StartDate__c = Date.today(),
                MonthlyPrice__c = 27,
                NextDeliveryDate__c = Date.today().addDays(30)
            ));
        }
        for (Integer i = 0; i < 2; i++) {
            subs.add(new Subscription__c(
                Account__c = accts[i].Id,
                Product__c = p.Id,
                Cadence__c = 'Monthly',
                Status__c = 'Cancelled',
                StartDate__c = Date.today(),
                MonthlyPrice__c = 10
            ));
        }
        insert subs;
    }

    // The two Account-level metrics roll up EVERY Account in the database, and a
    // test cannot assume it is the only thing that put Accounts there: an org run
    // under seeAllData, or a local run whose nimbus.properties seeds demo rows,
    // both start with data. So these two tests assert on the change they make,
    // not on absolute totals -- the same pattern that keeps a test green under
    // seeAllData=true.
    @IsTest
    static void byTier_rollsUpCorrectly() {
        Map<String, BrewCustomerMetrics.TierRollup> before = rollupByTier();

        insert new List<Account>{
            new Account(Name = 'B1', LoyaltyTier__c = 'Bronze', LifetimeValue__c = 100),
            new Account(Name = 'B2', LoyaltyTier__c = 'Bronze', LifetimeValue__c = 50),
            new Account(Name = 'B3', LoyaltyTier__c = 'Silver', LifetimeValue__c = 500),
            new Account(Name = 'B4', LoyaltyTier__c = 'Gold',   LifetimeValue__c = 2000),
            new Account(Name = 'B5', LoyaltyTier__c = 'Gold',   LifetimeValue__c = 3000)
        };

        Map<String, BrewCustomerMetrics.TierRollup> after = rollupByTier();
        Assert.areEqual(customerCount(before, 'Bronze') + 2, after.get('Bronze').customerCount);
        Assert.areEqual(customerCount(before, 'Silver') + 1, after.get('Silver').customerCount);
        Assert.areEqual(customerCount(before, 'Gold') + 2,   after.get('Gold').customerCount);
        Assert.areEqual(lifetimeValue(before, 'Gold') + 5000, after.get('Gold').totalLifetimeValue);
    }

    @IsTest
    static void mrrByCadence_sumsActiveOnly() {
        Map<String, Decimal> mrr = BrewCustomerMetrics.monthlyRecurringRevenueByCadence();
        Assert.areEqual(30, mrr.get('Monthly'));
        Assert.areEqual(54, mrr.get('Quarterly'));
    }

    @IsTest
    static void churnByCadence_producesRates() {
        List<BrewCustomerMetrics.ChurnMetric> rows = BrewCustomerMetrics.churnByCadence();
        Map<String, BrewCustomerMetrics.ChurnMetric> byC = new Map<String, BrewCustomerMetrics.ChurnMetric>();
        for (BrewCustomerMetrics.ChurnMetric m : rows) {
            byC.put(m.cadence, m);
        }
        Assert.areEqual(3, byC.get('Monthly').activeCount);
        Assert.areEqual(2, byC.get('Monthly').churnedCount);
        Assert.areEqual(40.00, byC.get('Monthly').churnRate);
    }

    @IsTest
    static void totalLifetimeRevenue_sumsAll() {
        Decimal before = BrewCustomerMetrics.totalLifetimeRevenue();

        insert new List<Account>{
            new Account(Name = 'R1', LifetimeValue__c = 4000),
            new Account(Name = 'R2', LifetimeValue__c = 1650)
        };

        Assert.areEqual(before + 5650, BrewCustomerMetrics.totalLifetimeRevenue());
    }

    private static Map<String, BrewCustomerMetrics.TierRollup> rollupByTier() {
        Map<String, BrewCustomerMetrics.TierRollup> byTier = new Map<String, BrewCustomerMetrics.TierRollup>();
        for (BrewCustomerMetrics.TierRollup r : BrewCustomerMetrics.byTier()) {
            byTier.put(r.tier, r);
        }
        return byTier;
    }

    private static Integer customerCount(Map<String, BrewCustomerMetrics.TierRollup> rollup, String tier) {
        return rollup.containsKey(tier) ? rollup.get(tier).customerCount : 0;
    }

    private static Decimal lifetimeValue(Map<String, BrewCustomerMetrics.TierRollup> rollup, String tier) {
        return rollup.containsKey(tier) ? rollup.get(tier).totalLifetimeValue : 0;
    }
}
