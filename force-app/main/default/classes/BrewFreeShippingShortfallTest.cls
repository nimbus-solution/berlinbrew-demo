@IsTest
private class BrewFreeShippingShortfallTest {

    @IsTest
    static void belowThreshold_hasPositiveShortfall() {
        Decimal s = BrewRegionalConfig.freeShippingShortfall('EU', 0);
        Assert.isNotNull(s, 'EU should have a configured threshold');
        Assert.isTrue(s > 0, 'a zero-value order should have a positive shortfall');
    }

    @IsTest
    static void aboveThreshold_hasZeroShortfall() {
        Assert.areEqual(0, BrewRegionalConfig.freeShippingShortfall('EU', 100000));
    }

    @IsTest
    static void unknownRegion_isNull() {
        Assert.isNull(BrewRegionalConfig.freeShippingShortfall('ZZ', 50));
    }

    @IsTest
    static void nullTotal_treatedAsZero() {
        Decimal s = BrewRegionalConfig.freeShippingShortfall('EU', null);
        Assert.isTrue(s > 0, 'null total should be treated as 0 spend');
    }
}
