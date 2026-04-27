/**
 * Pricing engine for BerlinBrew subscriptions and orders.
 *
 * Margin calculation is FLS-sensitive: WholesaleCost__c is hidden
 * from support agents, so callers running as a restricted user
 * must use queryRetailPriceWithUserMode() and accept that margin
 * data will not be available.
 */
public with sharing class BrewPricingService {

    public class PricingException extends Exception {}

    public static final Decimal VAT_RATE = 0.19;

    public static Decimal calculateSubscriptionPrice(CoffeeProduct__c product, String cadence) {
        if (product == null) {
            throw new PricingException('Product required');
        }
        if (product.RetailPrice__c == null) {
            throw new PricingException('Product missing RetailPrice__c');
        }
        Decimal base = product.RetailPrice__c;
        switch on cadence {
            when 'Weekly'    { return (base * 4).setScale(2); }
            when 'Biweekly'  { return (base * 2).setScale(2); }
            when 'Monthly'   { return base.setScale(2); }
            when 'Quarterly' { return (base * 3 * 0.90).setScale(2); }
            when else        { throw new PricingException('Unknown cadence: ' + cadence); }
        }
    }

    public static Decimal applyVat(Decimal netPrice) {
        if (netPrice == null) return null;
        return (netPrice * (1 + VAT_RATE)).setScale(2);
    }

    public static Decimal calculateMargin(CoffeeProduct__c product) {
        if (product == null || product.RetailPrice__c == null || product.WholesaleCost__c == null) {
            return null;
        }
        Decimal retail = product.RetailPrice__c;
        Decimal cost   = product.WholesaleCost__c;
        if (retail == 0) return 0;
        return ((retail - cost) * 100 / retail).setScale(2);
    }

    public static List<CoffeeProduct__c> queryActiveProducts() {
        return [
            SELECT Id, Name, Origin__c, RoastLevel__c, RetailPrice__c, WholesaleCost__c, Active__c
            FROM CoffeeProduct__c
            WHERE Active__c = true
            ORDER BY Name
        ];
    }

    public static List<CoffeeProduct__c> queryActiveProductsAsUser() {
        return [
            SELECT Id, Name, Origin__c, RoastLevel__c, RetailPrice__c
            FROM CoffeeProduct__c
            WHERE Active__c = true
            WITH USER_MODE
            ORDER BY Name
        ];
    }

    public static Decimal applyLoyaltyDiscount(Decimal price, String tier) {
        if (price == null) return null;
        Decimal multiplier;
        switch on tier {
            when 'Bronze'  { multiplier = 1.00; }
            when 'Silver'  { multiplier = 0.95; }
            when 'Gold'    { multiplier = 0.90; }
            when 'Roaster' { multiplier = 0.85; }
            when else      { multiplier = 1.00; }
        }
        return (price * multiplier).setScale(2);
    }
}
