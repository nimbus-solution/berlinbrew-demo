@IsTest
private class BrewSubscriptionHandlerTest {

    @IsTest
    static void beforeInsert_defaults_statusActive() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = new Subscription__c(Account__c = a.Id, Product__c = p.Id, Cadence__c = 'Monthly');
        insert s;
        Assert.areEqual('Active', [SELECT Status__c FROM Subscription__c WHERE Id = :s.Id].Status__c);
    }

    @IsTest
    static void beforeInsert_computesNextDelivery_fromStartDate() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = new Subscription__c(
            Account__c = a.Id, Product__c = p.Id, Cadence__c = 'Weekly',
            StartDate__c = Date.newInstance(2026, 5, 1)
        );
        insert s;
        Assert.areEqual(Date.newInstance(2026, 5, 8),
            [SELECT NextDeliveryDate__c FROM Subscription__c WHERE Id = :s.Id].NextDeliveryDate__c);
    }

    @IsTest
    static void beforeUpdate_cancelledToActive_blocked() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');
        s.Status__c = 'Cancelled';
        update s;

        s.Status__c = 'Active';
        try {
            update s;
            Assert.fail();
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('Cannot change status'));
        }
    }

    @IsTest
    static void beforeUpdate_cancelled_clearsNextDelivery() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');
        s.Status__c = 'Cancelled';
        update s;
        Assert.areEqual(null,
            [SELECT NextDeliveryDate__c FROM Subscription__c WHERE Id = :s.Id].NextDeliveryDate__c);
    }

    @IsTest
    static void afterUpdate_advancingNextDelivery_bumpsAccountLtv() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 25, 10);
        Subscription__c s = BrewSubscriptionService.activate(a.Id, p.Id, 'Monthly', Date.today());

        s.NextDeliveryDate__c = s.NextDeliveryDate__c.addMonths(1);
        update s;

        Assert.areEqual(25, [SELECT LifetimeValue__c FROM Account WHERE Id = :a.Id].LifetimeValue__c);
    }
}
