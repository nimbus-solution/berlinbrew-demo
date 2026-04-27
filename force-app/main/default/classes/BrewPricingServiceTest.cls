@IsTest
private class BrewPricingServiceTest {

    @IsTest static void weeklyPrice_is_fourTimesBase() {
        CoffeeProduct__c p = new CoffeeProduct__c(RetailPrice__c = 12.50);
        Assert.areEqual(50.00, BrewPricingService.calculateSubscriptionPrice(p, 'Weekly'));
    }

    @IsTest static void biweeklyPrice_is_twiceBase() {
        CoffeeProduct__c p = new CoffeeProduct__c(RetailPrice__c = 12.50);
        Assert.areEqual(25.00, BrewPricingService.calculateSubscriptionPrice(p, 'Biweekly'));
    }

    @IsTest static void monthlyPrice_is_base() {
        CoffeeProduct__c p = new CoffeeProduct__c(RetailPrice__c = 12.50);
        Assert.areEqual(12.50, BrewPricingService.calculateSubscriptionPrice(p, 'Monthly'));
    }

    @IsTest static void quarterlyPrice_is_tenPercentDiscount() {
        CoffeeProduct__c p = new CoffeeProduct__c(RetailPrice__c = 10.00);
        Assert.areEqual(27.00, BrewPricingService.calculateSubscriptionPrice(p, 'Quarterly'));
    }

    @IsTest static void unknownCadence_throws() {
        CoffeeProduct__c p = new CoffeeProduct__c(RetailPrice__c = 10.00);
        try {
            BrewPricingService.calculateSubscriptionPrice(p, 'Yearly');
            Assert.fail('expected exception');
        } catch (BrewPricingService.PricingException e) {
            Assert.isTrue(e.getMessage().contains('Unknown cadence'));
        }
    }

    @IsTest static void nullProduct_throws() {
        try {
            BrewPricingService.calculateSubscriptionPrice(null, 'Monthly');
            Assert.fail();
        } catch (BrewPricingService.PricingException e) {
            Assert.isTrue(e.getMessage().contains('Product required'));
        }
    }

    @IsTest static void vat_is_appliedCorrectly() {
        Assert.areEqual(11.90, BrewPricingService.applyVat(10.00));
    }

    @IsTest static void vat_nullReturnsNull() {
        Assert.areEqual(null, BrewPricingService.applyVat(null));
    }

    @IsTest static void margin_computesCorrectly() {
        CoffeeProduct__c p = new CoffeeProduct__c(RetailPrice__c = 20, WholesaleCost__c = 8);
        Assert.areEqual(60.00, BrewPricingService.calculateMargin(p));
    }

    @IsTest static void margin_nullWholesale_returnsNull() {
        CoffeeProduct__c p = new CoffeeProduct__c(RetailPrice__c = 20);
        Assert.areEqual(null, BrewPricingService.calculateMargin(p));
    }

    @IsTest static void margin_zeroRetail_returnsZero() {
        CoffeeProduct__c p = new CoffeeProduct__c(RetailPrice__c = 0, WholesaleCost__c = 8);
        Assert.areEqual(0, BrewPricingService.calculateMargin(p));
    }

    @IsTest static void loyaltyDiscount_bronze_noDiscount() {
        Assert.areEqual(100.00, BrewPricingService.applyLoyaltyDiscount(100, 'Bronze'));
    }

    @IsTest static void loyaltyDiscount_silver_fivePercent() {
        Assert.areEqual(95.00, BrewPricingService.applyLoyaltyDiscount(100, 'Silver'));
    }

    @IsTest static void loyaltyDiscount_gold_tenPercent() {
        Assert.areEqual(90.00, BrewPricingService.applyLoyaltyDiscount(100, 'Gold'));
    }

    @IsTest static void loyaltyDiscount_roaster_fifteenPercent() {
        Assert.areEqual(85.00, BrewPricingService.applyLoyaltyDiscount(100, 'Roaster'));
    }

    @IsTest static void loyaltyDiscount_unknownTier_noDiscount() {
        Assert.areEqual(100.00, BrewPricingService.applyLoyaltyDiscount(100, 'Platinum'));
    }

    @IsTest static void queryActiveProducts_returnsOnlyActive() {
        insert new List<CoffeeProduct__c>{
            new CoffeeProduct__c(Name = 'SKU-A', RetailPrice__c = 10, Active__c = true),
            new CoffeeProduct__c(Name = 'SKU-B', RetailPrice__c = 10, Active__c = false),
            new CoffeeProduct__c(Name = 'SKU-C', RetailPrice__c = 10, Active__c = true)
        };
        List<CoffeeProduct__c> result = BrewPricingService.queryActiveProducts();
        Assert.areEqual(2, result.size());
        for (CoffeeProduct__c p : result) Assert.areEqual(true, p.Active__c);
    }
}
