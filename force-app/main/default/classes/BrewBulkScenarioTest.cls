/**
 * End-to-end workflow tests that exercise multiple subsystems.
 * These are the "show something substantial runs fast" tests.
 */
@IsTest
private class BrewBulkScenarioTest {

    @IsTest
    static void fullLifecycle_100_subscriptions() {
        List<Account> accts = BrewTestFactory.accounts(100);
        CoffeeProduct__c p = BrewTestFactory.product('BLEND-A', 15, 6);
        BrewTestFactory.batch(p.Id, 100.0);

        List<Subscription__c> subs = new List<Subscription__c>();
        for (Account a : accts) {
            subs.add(new Subscription__c(
                Account__c          = a.Id,
                Product__c          = p.Id,
                Cadence__c          = 'Monthly',
                Status__c           = 'Active',
                StartDate__c        = Date.today(),
                NextDeliveryDate__c = Date.today(),
                MonthlyPrice__c     = 15
            ));
        }
        insert subs;

        Test.startTest();
        Integer advanced = BrewSubscriptionService.advanceDeliveries(
            BrewSubscriptionService.dueForDelivery(Date.today())
        );
        Test.stopTest();

        Assert.areEqual(100, advanced);
        Integer points = [SELECT COUNT() FROM LoyaltyTransaction__c];
        Assert.areEqual(100, points);
    }

    @IsTest
    static void inventoryReservation_under_concurrentSubscriptions() {
        CoffeeProduct__c p = BrewTestFactory.product('BLEND-B', 15, 6);
        BrewTestFactory.batch(p.Id, 10.0);

        for (Integer i = 0; i < 30; i++) {
            BrewInventoryService.reserve(p.Id, 0.25);
        }
        Assert.areEqual(2.5, BrewInventoryService.availableStock(p.Id));
    }

    @IsTest
    static void metricsReflect_bulkActivity() {
        List<Account> accts = BrewTestFactory.accounts(20);
        CoffeeProduct__c p = BrewTestFactory.product('BLEND-C', 20, 8);
        List<Subscription__c> subs = new List<Subscription__c>();
        for (Integer i = 0; i < 20; i++) {
            subs.add(new Subscription__c(
                Account__c          = accts[i].Id,
                Product__c          = p.Id,
                Cadence__c          = (Math.mod(i, 2) == 0) ? 'Monthly' : 'Quarterly',
                Status__c           = 'Active',
                StartDate__c        = Date.today(),
                NextDeliveryDate__c = Date.today().addDays(7),
                MonthlyPrice__c     = (Math.mod(i, 2) == 0) ? 20 : 54
            ));
        }
        insert subs;

        Map<String, Decimal> mrr = BrewCustomerMetrics.monthlyRecurringRevenueByCadence();
        Assert.areEqual(200, mrr.get('Monthly'));
        Assert.areEqual(540, mrr.get('Quarterly'));
    }

    @IsTest
    static void tierGraduation_afterMonthsOfActivity() {
        Account a = BrewTestFactory.account('BigSpender');
        CoffeeProduct__c p = BrewTestFactory.product('BLEND-D', 60, 20);
        Subscription__c s = BrewSubscriptionService.activate(a.Id, p.Id, 'Monthly', Date.today());

        for (Integer i = 0; i < 10; i++) {
            BrewSubscriptionService.advanceDeliveries(new List<Subscription__c>{ s });
            s = [SELECT Id, Status__c, Account__c, Cadence__c, MonthlyPrice__c, NextDeliveryDate__c FROM Subscription__c WHERE Id = :s.Id];
        }
        Account out = [SELECT LoyaltyPoints__c, LoyaltyTier__c FROM Account WHERE Id = :a.Id];
        Assert.areEqual(600, out.LoyaltyPoints__c);
        Assert.areEqual('Silver', out.LoyaltyTier__c);
    }
}
