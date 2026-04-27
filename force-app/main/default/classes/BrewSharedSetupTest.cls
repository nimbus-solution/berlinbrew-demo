/**
 * Demonstrates the @testSetup pattern: a single setup method runs
 * once before any test method in this class, populating shared
 * fixtures into the test database. Each test method then runs in
 * its own per-test transaction that rolls back on exit, so setup
 * data is reused but mutations don't leak between tests.
 *
 * Why this is interesting for a Nimbus demo:
 *
 * Nimbus implements the @testSetup contract faithfully:
 *   - The setup method runs ONCE per test class.
 *   - Records inserted in setup are visible to every test method.
 *   - DML inside a test method is rolled back per-test (the next
 *     test sees the same setup state, NOT this test's mutations).
 *   - Governor limits reset between setup and each test method,
 *     matching Salesforce's runtime semantics.
 *
 * The four tests below all share the same three accounts + product +
 * subscriptions, but each test mutates them in its own way and the
 * other tests never see those mutations. If you suspect setup
 * isolation isn't working, run them with `--parallel 1` to compare
 * against parallel mode — both should pass identically.
 */
@isTest
private class BrewSharedSetupTest {

    @testSetup
    static void seedAccountsAndSubscriptions() {
        // Three accounts at varying lifetime values. Used by tests
        // that need to verify metric aggregation, tier-based pricing,
        // and bulk-DML behavior.
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Cafe Alpha',   LifetimeValue__c = 500.00,  LoyaltyPoints__c = 200, LoyaltyTier__c = 'Silver'),
            new Account(Name = 'Cafe Beta',    LifetimeValue__c = 1500.00, LoyaltyPoints__c = 800, LoyaltyTier__c = 'Gold'),
            new Account(Name = 'Cafe Gamma',   LifetimeValue__c = 2500.00, LoyaltyPoints__c = 2000, LoyaltyTier__c = 'Platinum')
        };
        insert accounts;

        CoffeeProduct__c product = new CoffeeProduct__c(
            Name = 'Berlin Roast',
            RetailPrice__c = 24.99,
            WholesaleCost__c = 8.00,
            Origin__c = 'Ethiopia',
            Active__c = true
        );
        insert product;

        // One Active subscription per account, varying cadence.
        List<Subscription__c> subs = new List<Subscription__c>();
        String[] cadences = new String[]{ 'Weekly', 'Biweekly', 'Monthly' };
        for (Integer i = 0; i < accounts.size(); i++) {
            subs.add(new Subscription__c(
                Account__c          = accounts[i].Id,
                Product__c          = product.Id,
                Cadence__c          = cadences[i],
                Status__c           = 'Active',
                StartDate__c        = Date.today().addDays(-30),
                NextDeliveryDate__c = Date.today().addDays(7),
                MonthlyPrice__c     = BrewPricingService.calculateSubscriptionPrice(product, cadences[i])
            ));
        }
        insert subs;
    }

    @isTest
    static void allThreeAccountsVisibleInEachTest_pre() {
        // The first test sees the 3 setup accounts cleanly — no other
        // test has mutated them yet (or if it has, the rollback happened).
        Integer count = [SELECT COUNT() FROM Account WHERE Name LIKE 'Cafe %'];
        Assert.areEqual(3, count, 'expected exactly the 3 seeded accounts');
    }

    @isTest
    static void thisTestInsertsAFourthAccount() {
        // Verify the setup state, then mutate. The mutation should
        // be invisible to other tests because of per-test rollback.
        Integer pre = [SELECT COUNT() FROM Account WHERE Name LIKE 'Cafe %'];
        Assert.areEqual(3, pre, 'setup gave us 3');

        insert new Account(Name = 'Cafe Delta', LifetimeValue__c = 100.00);

        Integer post = [SELECT COUNT() FROM Account WHERE Name LIKE 'Cafe %'];
        Assert.areEqual(4, post, 'we just inserted a 4th in this test');
    }

    @isTest
    static void thisTestUpdatesTierToBronze() {
        // Confirm we still see the seeded data (i.e. the previous
        // test's insert was rolled back), then mutate again.
        List<Account> accs = [SELECT Id, LoyaltyTier__c FROM Account WHERE Name = 'Cafe Beta'];
        Assert.areEqual(1, accs.size());
        Assert.areEqual('Gold', accs[0].LoyaltyTier__c, 'should be Gold from setup, not whatever previous test changed');

        accs[0].LoyaltyTier__c = 'Bronze';
        update accs[0];

        Account beta = [SELECT LoyaltyTier__c FROM Account WHERE Id = :accs[0].Id];
        Assert.areEqual('Bronze', beta.LoyaltyTier__c);
    }

    @isTest
    static void thisTestVerifiesPriorMutationsRolledBack() {
        // The previous test set Cafe Beta to Bronze. This test should
        // see the original Gold value because the previous test's
        // update was rolled back.
        Account beta = [SELECT LoyaltyTier__c FROM Account WHERE Name = 'Cafe Beta'];
        Assert.areEqual('Gold', beta.LoyaltyTier__c, 'previous test mutation should be rolled back');
    }

    @isTest
    static void subscriptionsArePreservedAcrossTests() {
        Integer count = [SELECT COUNT() FROM Subscription__c WHERE Status__c = 'Active'];
        Assert.areEqual(3, count, 'three Active subscriptions from setup');
    }
}
