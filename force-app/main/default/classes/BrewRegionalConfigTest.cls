/**
 * Tests for BrewRegionalConfig. Demonstrates Nimbus's automatic
 * loading of `customMetadata/*.md-meta.xml` records — three records
 * (EU, US, UK) are visible to SOQL during these tests without any
 * test-time setup.
 *
 * If you remove a record file from customMetadata/, the corresponding
 * test below will fail with "no record" — the local DB stays in sync
 * with the project's metadata XML.
 */
@isTest
private class BrewRegionalConfigTest {

    @isTest
    static void forRegion_eu_returnsRecord() {
        BrewConfig__mdt cfg = BrewRegionalConfig.forRegion('EU');
        Assert.areNotEqual(null, cfg, 'expected EU record');
        Assert.areEqual('EU', cfg.Region__c);
        Assert.areEqual(50.00, cfg.FreeShippingThreshold__c);
        Assert.areEqual('Monthly', cfg.DefaultCadence__c);
        Assert.areEqual(true, cfg.EnableLoyalty__c);
    }

    @isTest
    static void forRegion_us_returnsRecord() {
        BrewConfig__mdt cfg = BrewRegionalConfig.forRegion('US');
        Assert.areNotEqual(null, cfg);
        Assert.areEqual(75.00, cfg.FreeShippingThreshold__c);
        Assert.areEqual('Biweekly', cfg.DefaultCadence__c);
    }

    @isTest
    static void forRegion_caseInsensitive() {
        BrewConfig__mdt low = BrewRegionalConfig.forRegion('eu');
        BrewConfig__mdt mix = BrewRegionalConfig.forRegion('Eu');
        BrewConfig__mdt up = BrewRegionalConfig.forRegion('EU');
        Assert.areNotEqual(null, low);
        Assert.areNotEqual(null, mix);
        Assert.areNotEqual(null, up);
        Assert.areEqual(low.Id, up.Id, 'same record regardless of casing');
    }

    @isTest
    static void forRegion_unknownRegion_returnsNull() {
        Assert.areEqual(null, BrewRegionalConfig.forRegion('CA'));
        Assert.areEqual(null, BrewRegionalConfig.forRegion(''));
        Assert.areEqual(null, BrewRegionalConfig.forRegion(null));
    }

    @isTest
    static void forRegionRequired_unknown_throws() {
        try {
            BrewRegionalConfig.forRegionRequired('CA');
            Assert.fail('expected ConfigException');
        } catch (BrewRegionalConfig.ConfigException e) {
            Assert.isTrue(e.getMessage().contains('CA'));
        }
    }

    @isTest
    static void qualifiesForFreeShipping_aboveThreshold_true() {
        // EU threshold is 50.00
        Assert.areEqual(true, BrewRegionalConfig.qualifiesForFreeShipping('EU', 60.00));
        Assert.areEqual(true, BrewRegionalConfig.qualifiesForFreeShipping('EU', 50.00));
    }

    @isTest
    static void qualifiesForFreeShipping_belowThreshold_false() {
        Assert.areEqual(false, BrewRegionalConfig.qualifiesForFreeShipping('EU', 49.99));
        Assert.areEqual(false, BrewRegionalConfig.qualifiesForFreeShipping('EU', 0));
    }

    @isTest
    static void qualifiesForFreeShipping_unknownRegion_false() {
        Assert.areEqual(false, BrewRegionalConfig.qualifiesForFreeShipping('CA', 1000));
    }

    @isTest
    static void qualifiesForFreeShipping_nullTotal_false() {
        Assert.areEqual(false, BrewRegionalConfig.qualifiesForFreeShipping('EU', null));
    }

    @isTest
    static void defaultCadenceForRegion_known_matchesRecord() {
        Assert.areEqual('Monthly', BrewRegionalConfig.defaultCadenceForRegion('EU'));
        Assert.areEqual('Biweekly', BrewRegionalConfig.defaultCadenceForRegion('US'));
    }

    @isTest
    static void defaultCadenceForRegion_unknown_fallsBackToMonthly() {
        Assert.areEqual('Monthly', BrewRegionalConfig.defaultCadenceForRegion('CA'));
        Assert.areEqual('Monthly', BrewRegionalConfig.defaultCadenceForRegion(null));
    }

    @isTest
    static void regionsWithLoyaltyEnabled_excludesUK() {
        // UK has EnableLoyalty__c=false; EU and US have true.
        Set<String> enabled = BrewRegionalConfig.regionsWithLoyaltyEnabled();
        Assert.isTrue(enabled.contains('EU'), 'expected EU enabled');
        Assert.isTrue(enabled.contains('US'), 'expected US enabled');
        Assert.isTrue(!enabled.contains('UK'), 'expected UK NOT enabled');
    }
}
