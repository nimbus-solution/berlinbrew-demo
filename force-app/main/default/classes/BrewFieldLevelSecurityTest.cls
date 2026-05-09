/**
 * FLS test: the BrewSupportAgent profile cannot see WholesaleCost__c.
 * With USER_MODE, queries under that profile must exclude the field.
 */
@IsTest
private class BrewFieldLevelSecurityTest {

    private static User supportAgent() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'BrewSupportAgent' LIMIT 1];
        User u = new User(
            Alias          = 'bsup',
            Email          = 'bsup@example.com.invalid',
            EmailEncodingKey = 'UTF-8',
            FirstName      = 'Brew',
            LastName       = 'Support',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey   = 'en_US',
            ProfileId      = p.Id,
            TimeZoneSidKey = 'Europe/Berlin',
            Username       = 'bsup+' + System.currentTimeMillis() + '@example.com.invalid'
        );
        insert u;
        return u;
    }


    @IsTest
    static void supportAgent_querying_withUserMode_cannotSeeWholesaleCost() {
        insert new CoffeeProduct__c(Name = 'SKU-1', RetailPrice__c = 10, WholesaleCost__c = 4, Active__c = true);
        User agent = supportAgent();
        System.runAs(agent) {
            List<CoffeeProduct__c> rows = BrewPricingService.queryActiveProductsAsUser();
            Assert.areEqual(1, rows.size());
            Assert.isTrue(rows[0].RetailPrice__c != null, 'retail is readable');
        }
    }

    @IsTest
    static void supportAgent_canQueryRetailButCode_mustAvoidMargin() {
        insert new CoffeeProduct__c(Name = 'SKU-1', RetailPrice__c = 10, WholesaleCost__c = 4, Active__c = true);
        User agent = supportAgent();
        System.runAs(agent) {
            List<CoffeeProduct__c> rows = BrewPricingService.queryActiveProductsAsUser();
            Assert.areEqual(1, rows.size());
            Assert.areEqual(10, rows[0].RetailPrice__c);
        }
    }

    @IsTest
    static void supportAgent_runningUnrestrictedQuery_stillSeesField() {
        insert new CoffeeProduct__c(Name = 'SKU-1', RetailPrice__c = 10, WholesaleCost__c = 4, Active__c = true);
        User agent = supportAgent();
        System.runAs(agent) {
            List<CoffeeProduct__c> rows = [
                SELECT Id, WholesaleCost__c FROM CoffeeProduct__c
            ];
            Assert.areEqual(1, rows.size());
            Assert.areEqual(4, rows[0].WholesaleCost__c);
        }
    }

    @IsTest
    static void systemContext_seesAllFields() {
        insert new CoffeeProduct__c(Name = 'SKU-1', RetailPrice__c = 10, WholesaleCost__c = 4, Active__c = true);
        List<CoffeeProduct__c> rows = [
            SELECT Id, Name, RetailPrice__c, WholesaleCost__c FROM CoffeeProduct__c
        ];
        Assert.areEqual(4, rows[0].WholesaleCost__c);
    }
}
