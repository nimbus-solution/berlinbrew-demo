@IsTest
private class BrewAccountHandlerTest {

    @IsTest
    static void insert_normalizes_website_withScheme() {
        Account a = new Account(Name = 'A', Website = 'example.com');
        insert a;
        Account out = [SELECT Website FROM Account WHERE Id = :a.Id];
        Assert.areEqual('https://example.com', out.Website);
    }

    @IsTest
    static void insert_normalizes_website_lowercased() {
        Account a = new Account(Name = 'A', Website = 'HTTPS://EXAMPLE.COM');
        insert a;
        Assert.areEqual('https://example.com', [SELECT Website FROM Account WHERE Id = :a.Id].Website);
    }

    @IsTest
    static void insert_normalizes_phone_strips_non_digits() {
        Account a = new Account(Name = 'A', Phone = '(030) 12345-678');
        insert a;
        Assert.areEqual('03012345678', [SELECT Phone FROM Account WHERE Id = :a.Id].Phone);
    }

    @IsTest
    static void insert_normalizes_phone_00_to_plus() {
        Account a = new Account(Name = 'A', Phone = '004930555555');
        insert a;
        Assert.areEqual('+4930555555', [SELECT Phone FROM Account WHERE Id = :a.Id].Phone);
    }

    @IsTest
    static void insert_setsDefault_loyalty_fields() {
        Account a = new Account(Name = 'A');
        insert a;
        Account out = [SELECT LoyaltyTier__c, LoyaltyPoints__c, LifetimeValue__c FROM Account WHERE Id = :a.Id];
        Assert.areEqual('Bronze', out.LoyaltyTier__c);
        Assert.areEqual(0, out.LoyaltyPoints__c);
        Assert.areEqual(0, out.LifetimeValue__c);
    }

    @IsTest
    static void update_negativeLifetimeValue_putsAccountOnCreditHold() {
        Account a = BrewTestFactory.account('A');
        a.LifetimeValue__c = -10;
        update a;
        Account out = [SELECT OnCreditHold__c, CreditHoldReason__c FROM Account WHERE Id = :a.Id];
        Assert.areEqual(true, out.OnCreditHold__c);
        Assert.areEqual('Negative lifetime value detected', out.CreditHoldReason__c);
    }

    @IsTest
    static void update_positiveLifetimeValue_noHold() {
        Account a = BrewTestFactory.account('A');
        a.LifetimeValue__c = 500;
        update a;
        Account out = [SELECT OnCreditHold__c FROM Account WHERE Id = :a.Id];
        Assert.areEqual(false, out.OnCreditHold__c);
    }

    @IsTest
    static void delete_accountWithActiveSubscription_blocked() {
        Account a = BrewTestFactory.account('A');
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        BrewTestFactory.subscription(a.Id, p.Id, 'Monthly');
        try {
            delete a;
            Assert.fail('expected delete to fail');
        } catch (DmlException e) {
            Assert.isTrue(e.getMessage().contains('Cannot delete account with 1 active subscription'));
        }
    }

    @IsTest
    static void delete_accountWithoutSubscriptions_succeeds() {
        Account a = BrewTestFactory.account('A');
        delete a;
        Assert.areEqual(0, [SELECT COUNT() FROM Account WHERE Id = :a.Id]);
    }

    @IsTest
    static void bulk_insert_doesNotBlowGovernorLimits() {
        List<Account> batch = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            batch.add(new Account(Name = 'Bulk ' + i, Website = 'bulk' + i + '.de'));
        }
        Test.startTest();
        insert batch;
        Test.stopTest();

        Integer total = [SELECT COUNT() FROM Account WHERE Name LIKE 'Bulk %'];
        Assert.areEqual(200, total);
        for (Account a : [SELECT Website FROM Account WHERE Name LIKE 'Bulk %' LIMIT 5]) {
            Assert.isTrue(a.Website.startsWith('https://'), 'normalized: ' + a.Website);
        }
    }
}
