@IsTest
private class BrewSubscriptionServiceTest {

    @IsTest static void activate_createsSubscription_withCorrectPrice() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 12.00, 5.00);
        Subscription__c s = BrewSubscriptionService.activate(a.Id, p.Id, 'Monthly', Date.today());
        Subscription__c out = [
            SELECT MonthlyPrice__c, Status__c, NextDeliveryDate__c, Cadence__c FROM Subscription__c WHERE Id = :s.Id
        ];
        Assert.areEqual(12.00, out.MonthlyPrice__c);
        Assert.areEqual('Active', out.Status__c);
        Assert.areEqual(Date.today().addMonths(1), out.NextDeliveryDate__c);
    }

    @IsTest static void activate_quarterlyApplies10PercentDiscount() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10.00, 4.00);
        Subscription__c s = BrewSubscriptionService.activate(a.Id, p.Id, 'Quarterly', Date.today());
        Assert.areEqual(27.00, [SELECT MonthlyPrice__c FROM Subscription__c WHERE Id = :s.Id].MonthlyPrice__c);
    }

    @IsTest static void activate_onCreditHold_throws() {
        Account a = BrewTestFactory.account('A');
        a.OnCreditHold__c = true;
        update a;
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        try {
            BrewSubscriptionService.activate(a.Id, p.Id, 'Monthly', Date.today());
            Assert.fail();
        } catch (BrewSubscriptionService.SubscriptionException e) {
            Assert.isTrue(e.getMessage().contains('credit hold'));
        }
    }

    @IsTest static void activate_inactiveProduct_throws() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        p.Active__c = false;
        update p;
        try {
            BrewSubscriptionService.activate(a.Id, p.Id, 'Monthly', Date.today());
            Assert.fail();
        } catch (BrewSubscriptionService.SubscriptionException e) {
            Assert.isTrue(e.getMessage().contains('not active'));
        }
    }

    @IsTest static void nextDeliveryAfter_weekly_isPlus7() {
        Assert.areEqual(Date.newInstance(2026, 5, 8),
            BrewSubscriptionService.nextDeliveryAfter(Date.newInstance(2026, 5, 1), 'Weekly'));
    }

    @IsTest static void nextDeliveryAfter_monthly_handlesYearBoundary() {
        Assert.areEqual(Date.newInstance(2027, 1, 15),
            BrewSubscriptionService.nextDeliveryAfter(Date.newInstance(2026, 12, 15), 'Monthly'));
    }

    @IsTest static void nextDeliveryAfter_null_returnsNull() {
        Assert.areEqual(null, BrewSubscriptionService.nextDeliveryAfter(null, 'Monthly'));
    }

    @IsTest static void pause_activeSubscription_setsStatus() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');
        BrewSubscriptionService.pause(s.Id);
        Assert.areEqual('Paused', [SELECT Status__c FROM Subscription__c WHERE Id = :s.Id].Status__c);
    }

    @IsTest static void pause_cancelledSubscription_throws() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');
        BrewSubscriptionService.cancel(s.Id, 'test');
        try {
            BrewSubscriptionService.pause(s.Id);
            Assert.fail();
        } catch (BrewSubscriptionService.SubscriptionException e) {
            Assert.isTrue(e.getMessage().contains('terminated'));
        }
    }

    @IsTest static void resume_pausedSubscription_updatesNextDelivery() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Weekly');
        BrewSubscriptionService.pause(s.Id);
        Date resumeDate = Date.newInstance(2026, 7, 1);
        BrewSubscriptionService.resume(s.Id, resumeDate);
        Subscription__c out = [SELECT Status__c, NextDeliveryDate__c FROM Subscription__c WHERE Id = :s.Id];
        Assert.areEqual('Active', out.Status__c);
        Assert.areEqual(resumeDate.addDays(7), out.NextDeliveryDate__c);
    }

    @IsTest static void resume_activeSubscription_throws() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Weekly');
        try {
            BrewSubscriptionService.resume(s.Id, Date.today());
            Assert.fail();
        } catch (BrewSubscriptionService.SubscriptionException e) {
            Assert.isTrue(e.getMessage().contains('Only paused'));
        }
    }

    @IsTest static void cancel_clearsNextDelivery() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');
        BrewSubscriptionService.cancel(s.Id, 'user request');
        Subscription__c out = [SELECT Status__c, NextDeliveryDate__c FROM Subscription__c WHERE Id = :s.Id];
        Assert.areEqual('Cancelled', out.Status__c);
        Assert.areEqual(null, out.NextDeliveryDate__c);
    }

    @IsTest static void dueForDelivery_returnsOnlyActive_withNextDeliveryOnOrBeforeAsOf() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Subscription__c s1 = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');
        s1.NextDeliveryDate__c = Date.today();
        update s1;

        Subscription__c s2 = BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');
        s2.NextDeliveryDate__c = Date.today().addDays(7);
        update s2;

        List<Subscription__c> due = BrewSubscriptionService.dueForDelivery(Date.today());
        Assert.areEqual(1, due.size());
        Assert.areEqual(s1.Id, due[0].Id);
    }

    @IsTest static void advanceDeliveries_updatesNext_andAwardsLoyalty() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 100, 40);
        Subscription__c s = BrewSubscriptionService.activate(a.Id, p.Id, 'Monthly', Date.today());
        Test.startTest();
        Integer processed = BrewSubscriptionService.advanceDeliveries(new List<Subscription__c>{ s });
        Test.stopTest();
        Assert.areEqual(1, processed);
        Account out = [SELECT LoyaltyPoints__c FROM Account WHERE Id = :a.Id];
        Assert.areEqual(100, out.LoyaltyPoints__c);
    }

    @IsTest static void advanceDeliveries_skipsNonActive() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 50, 20);
        Subscription__c s = BrewSubscriptionService.activate(a.Id, p.Id, 'Monthly', Date.today());
        s.Status__c = 'Paused';
        update s;
        Integer processed = BrewSubscriptionService.advanceDeliveries(new List<Subscription__c>{ s });
        Assert.areEqual(0, processed);
    }
}
