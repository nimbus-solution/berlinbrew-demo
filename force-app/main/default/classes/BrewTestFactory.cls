/**
 * Test data factory. Single source of truth for test fixtures so
 * tests stay short and intent-focused.
 */
@IsTest
public class BrewTestFactory {

    public static Account account(String name) {
        Account a = new Account(
            Name              = name,
            Website           = 'example.com',
            Phone             = '+49 30 12345678',
            LoyaltyPoints__c  = 0,
            LoyaltyTier__c    = 'Bronze',
            LifetimeValue__c  = 0,
            OnCreditHold__c   = false
        );
        insert a;
        return a;
    }

    public static List<Account> accounts(Integer n) {
        List<Account> out = new List<Account>();
        for (Integer i = 0; i < n; i++) {
            out.add(new Account(
                Name              = 'Brew Account ' + i,
                LoyaltyPoints__c  = 0,
                LoyaltyTier__c    = 'Bronze',
                LifetimeValue__c  = 0,
                OnCreditHold__c   = false
            ));
        }
        insert out;
        return out;
    }

    public static CoffeeProduct__c product(String sku, Decimal retail, Decimal wholesale) {
        CoffeeProduct__c p = new CoffeeProduct__c(
            Name             = sku,
            Origin__c        = 'Ethiopia',
            RoastLevel__c    = 'Medium',
            RetailPrice__c   = retail,
            WholesaleCost__c = wholesale,
            Active__c        = true
        );
        insert p;
        return p;
    }

    public static RoastBatch__c batch(Id productId, Decimal kg) {
        RoastBatch__c b = new RoastBatch__c(
            Product__c    = productId,
            RoastDate__c  = Date.today(),
            QuantityKg__c = kg,
            ReservedKg__c = 0
        );
        insert b;
        return b;
    }

    public static Subscription__c subscription(Id accountId, Id productId, String cadence) {
        return BrewSubscriptionService.activate(accountId, productId, cadence, Date.today());
    }
}
