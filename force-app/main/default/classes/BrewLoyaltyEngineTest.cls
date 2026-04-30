@IsTest
private class BrewLoyaltyEngineTest {

    @IsTest
    static void tierFor_zero_isBronze()     { Assert.areEqual('Bronze',  BrewLoyaltyEngine.tierFor(0));     }
    @IsTest
    static void tierFor_499_isBronze()      { Assert.areEqual('Bronze',  BrewLoyaltyEngine.tierFor(499));   }
    @IsTest
    static void tierFor_500_isSilver()      { Assert.areEqual('Silver',  BrewLoyaltyEngine.tierFor(500));   }
    @IsTest
    static void tierFor_1999_isSilver()     { Assert.areEqual('Silver',  BrewLoyaltyEngine.tierFor(1999));  }
    @IsTest
    static void tierFor_2000_isGold()       { Assert.areEqual('Gold',    BrewLoyaltyEngine.tierFor(2000));  }
    @IsTest
    static void tierFor_9999_isGold()       { Assert.areEqual('Gold',    BrewLoyaltyEngine.tierFor(9999));  }
    @IsTest
    static void tierFor_10000_isRoaster()   { Assert.areEqual('Roaster', BrewLoyaltyEngine.tierFor(10000)); }
    @IsTest
    static void tierFor_negative_isBronze() { Assert.areEqual('Bronze',  BrewLoyaltyEngine.tierFor(-50));   }
    @IsTest
    static void tierFor_null_isBronze()     { Assert.areEqual('Bronze',  BrewLoyaltyEngine.tierFor(null));  }

    @IsTest
    static void pointsForPurchase_floors() {
        Assert.areEqual(19, BrewLoyaltyEngine.pointsForPurchase(19.99));
    }

    @IsTest
    static void pointsForPurchase_null_isZero() {
        Assert.areEqual(0, BrewLoyaltyEngine.pointsForPurchase(null));
    }

    @IsTest
    static void pointsForPurchase_negative_isZero() {
        Assert.areEqual(0, BrewLoyaltyEngine.pointsForPurchase(-5));
    }

    @IsTest
    static void awardPoints_addsToBalance() {
        Account a = BrewTestFactory.account('A');
        BrewLoyaltyEngine.awardPoints(a.Id, 100, 'Purchase');
        Assert.areEqual(100, [SELECT LoyaltyPoints__c FROM Account WHERE Id = :a.Id].LoyaltyPoints__c);
    }

    @IsTest
    static void awardPoints_writesTransactionRow() {
        Account a = BrewTestFactory.account('A');
        BrewLoyaltyEngine.awardPoints(a.Id, 42, 'Referral');
        List<LoyaltyTransaction__c> txns = [SELECT Points__c, Reason__c FROM LoyaltyTransaction__c WHERE Account__c = :a.Id];
        Assert.areEqual(1, txns.size());
        Assert.areEqual(42, txns[0].Points__c);
        Assert.areEqual('Referral', txns[0].Reason__c);
    }

    @IsTest
    static void awardPoints_crossTierThreshold_upgrades() {
        Account a = BrewTestFactory.account('A');
        BrewLoyaltyEngine.awardPoints(a.Id, 600, 'Purchase');
        Assert.areEqual('Silver', [SELECT LoyaltyTier__c FROM Account WHERE Id = :a.Id].LoyaltyTier__c);
    }

    @IsTest
    static void awardPoints_zero_isNoop() {
        Account a = BrewTestFactory.account('A');
        BrewLoyaltyEngine.awardPoints(a.Id, 0, 'Purchase');
        Assert.areEqual(0, [SELECT COUNT() FROM LoyaltyTransaction__c WHERE Account__c = :a.Id]);
    }

    @IsTest
    static void awardPoints_tierGraduation_publishesPlatformEvent() {
        Account a = BrewTestFactory.account('A');
        Test.startTest();
        BrewLoyaltyEngine.awardPoints(a.Id, 2500, 'Purchase');
        Test.getEventBus().deliver();
        Test.stopTest();
        Assert.areEqual('Gold', [SELECT LoyaltyTier__c FROM Account WHERE Id = :a.Id].LoyaltyTier__c);
    }

    @IsTest
    static void awardPointsBulk_updatesAllAccounts() {
        List<Account> accts = BrewTestFactory.accounts(5);
        Map<Id, Integer> pts = new Map<Id, Integer>();
        for (Account a : accts) pts.put(a.Id, 300);
        Test.startTest();
        BrewLoyaltyEngine.awardPointsBulk(pts);
        Test.stopTest();

        for (Account a : [SELECT LoyaltyPoints__c FROM Account WHERE Id IN :pts.keySet()]) {
            Assert.areEqual(300, a.LoyaltyPoints__c);
        }
        Assert.areEqual(5, [SELECT COUNT() FROM LoyaltyTransaction__c]);
    }

    @IsTest
    static void awardPointsBulk_null_isNoop() {
        BrewLoyaltyEngine.awardPointsBulk(null);
        Assert.areEqual(0, [SELECT COUNT() FROM LoyaltyTransaction__c]);
    }

    @IsTest
    static void awardPointsBulk_empty_isNoop() {
        BrewLoyaltyEngine.awardPointsBulk(new Map<Id, Integer>());
        Assert.areEqual(0, [SELECT COUNT() FROM LoyaltyTransaction__c]);
    }
}
