@IsTest
private class BrewLoyaltyBirthdayTest {

    @IsTest
    static void bronze_getsBaseBonus() {
        Assert.areEqual(250, BrewLoyaltyEngine.birthdayBonus('Bronze'));
    }

    @IsTest
    static void silver_getsDoubleBonus() {
        Assert.areEqual(500, BrewLoyaltyEngine.birthdayBonus('Silver'));
    }

    @IsTest
    static void gold_getsTripleBonus() {
        Assert.areEqual(750, BrewLoyaltyEngine.birthdayBonus('Gold'));
    }

    @IsTest
    static void roaster_getsQuadrupleBonus() {
        Assert.areEqual(1000, BrewLoyaltyEngine.birthdayBonus('Roaster'));
    }

    @IsTest
    static void unknownTier_fallsBackToBase() {
        Assert.areEqual(250, BrewLoyaltyEngine.birthdayBonus('Platinum'));
    }
}
