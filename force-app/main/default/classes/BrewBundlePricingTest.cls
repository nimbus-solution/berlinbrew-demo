@IsTest
private class BrewBundlePricingTest {

    @IsTest
    static void twoProducts_get10PercentOff() {
        List<CoffeeProduct__c> bundle = new List<CoffeeProduct__c>{
            new CoffeeProduct__c(RetailPrice__c = 12.00),
            new CoffeeProduct__c(RetailPrice__c = 8.00)
        };
        Assert.areEqual(18.00, BrewPricingService.bundlePrice(bundle));
    }

    @IsTest
    static void emptyBundle_isZero() {
        Assert.areEqual(0, BrewPricingService.bundlePrice(new List<CoffeeProduct__c>()));
    }

    @IsTest
    static void nullBundle_isZero() {
        Assert.areEqual(0, BrewPricingService.bundlePrice(null));
    }

    @IsTest
    static void missingPrice_treatedAsZero() {
        List<CoffeeProduct__c> bundle = new List<CoffeeProduct__c>{
            new CoffeeProduct__c(RetailPrice__c = 10.00),
            new CoffeeProduct__c()
        };
        Assert.areEqual(9.00, BrewPricingService.bundlePrice(bundle));
    }
}
