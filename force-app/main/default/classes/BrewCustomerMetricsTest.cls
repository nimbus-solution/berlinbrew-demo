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
        for (Integer i = 0; i < 3; i++) subs.add(new Subscription__c(Account__c = accts[i].Id, Product__c = p.Id, Cadence__c = 'Monthly',   Status__c = 'Active',    StartDate__c = Date.today(), MonthlyPrice__c = 10, NextDeliveryDate__c = Date.today().addDays(7)));
        for (Integer i = 0; i < 2; i++) subs.add(new Subscription__c(Account__c = accts[i].Id, Product__c = p.Id, Cadence__c = 'Quarterly', Status__c = 'Active',    StartDate__c = Date.today(), MonthlyPrice__c = 27, NextDeliveryDate__c = Date.today().addDays(30)));
        for (Integer i = 0; i < 2; i++) subs.add(new Subscription__c(Account__c = accts[i].Id, Product__c = p.Id, Cadence__c = 'Monthly',   Status__c = 'Cancelled', StartDate__c = Date.today(), MonthlyPrice__c = 10));
        insert subs;
    }

    @IsTest static void byTier_rollsUpCorrectly() {
        List<BrewCustomerMetrics.TierRollup> rows = BrewCustomerMetrics.byTier();
        Map<String, BrewCustomerMetrics.TierRollup> byTier = new Map<String, BrewCustomerMetrics.TierRollup>();
        for (BrewCustomerMetrics.TierRollup r : rows) byTier.put(r.tier, r);
        Assert.areEqual(2, byTier.get('Bronze').customerCount);
        Assert.areEqual(1, byTier.get('Silver').customerCount);
        Assert.areEqual(2, byTier.get('Gold').customerCount);
        Assert.areEqual(5000, byTier.get('Gold').totalLifetimeValue);
    }

    @IsTest static void mrrByCadence_sumsActiveOnly() {
        Map<String, Decimal> mrr = BrewCustomerMetrics.monthlyRecurringRevenueByCadence();
        Assert.areEqual(30, mrr.get('Monthly'));
        Assert.areEqual(54, mrr.get('Quarterly'));
    }

    @IsTest static void churnByCadence_producesRates() {
        List<BrewCustomerMetrics.ChurnMetric> rows = BrewCustomerMetrics.churnByCadence();
        Map<String, BrewCustomerMetrics.ChurnMetric> byC = new Map<String, BrewCustomerMetrics.ChurnMetric>();
        for (BrewCustomerMetrics.ChurnMetric m : rows) byC.put(m.cadence, m);
        Assert.areEqual(3, byC.get('Monthly').activeCount);
        Assert.areEqual(2, byC.get('Monthly').churnedCount);
        Assert.areEqual(40.00, byC.get('Monthly').churnRate);
    }

    @IsTest static void totalLifetimeRevenue_sumsAll() {
        Assert.areEqual(5650, BrewCustomerMetrics.totalLifetimeRevenue());
    }
}
