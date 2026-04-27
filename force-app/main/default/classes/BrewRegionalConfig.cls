/**
 * Reads region-specific business rules from the BrewConfig__mdt
 * custom metadata type. Three records ship in customMetadata/:
 * EU, US, UK — each carrying free-shipping thresholds, default
 * subscription cadence, and loyalty-enabled flag.
 *
 * Why this is interesting for a Nimbus demo:
 *
 * Custom metadata records normally live in the org. Salesforce loads
 * them when an org boots and they're queryable like any other SObject.
 * Local test runners that don't understand mdt either ignore them
 * entirely (returning empty lists from the SOQL) or require manual
 * stubbing in every test.
 *
 * Nimbus reads the project's `customMetadata/*.md-meta.xml` files at
 * Setup time and seeds them into the local database — so a SOQL like
 * `SELECT Region__c FROM BrewConfig__mdt` returns three rows during
 * tests, exactly the way it would on a real org. No test-time stub
 * needed.
 *
 * The service caches the lookup map at class-load time (Apex static
 * initializer). On a real org this is a one-shot SOQL per transaction;
 * in Nimbus it's the same — the embedded Postgres roundtrip is sub-ms.
 */
public with sharing class BrewRegionalConfig {

    public class ConfigException extends Exception {}

    private static final Map<String, BrewConfig__mdt> CONFIG_BY_REGION = loadAll();

    private static Map<String, BrewConfig__mdt> loadAll() {
        Map<String, BrewConfig__mdt> out = new Map<String, BrewConfig__mdt>();
        for (BrewConfig__mdt cfg : [
            SELECT DeveloperName, Region__c, FreeShippingThreshold__c,
                   DefaultCadence__c, EnableLoyalty__c
            FROM BrewConfig__mdt
        ]) {
            if (cfg.Region__c != null) {
                out.put(cfg.Region__c.toUpperCase(), cfg);
            }
        }
        return out;
    }

    /**
     * Returns the config for the given region (case-insensitive),
     * or null if no record matches. Callers that REQUIRE a config
     * should use forRegionRequired instead — it throws on miss.
     */
    public static BrewConfig__mdt forRegion(String region) {
        if (String.isBlank(region)) return null;
        return CONFIG_BY_REGION.get(region.toUpperCase());
    }

    /**
     * Returns the config for the given region; throws ConfigException
     * if no record exists. Use this in production paths where a
     * missing region indicates a deployment error.
     */
    public static BrewConfig__mdt forRegionRequired(String region) {
        BrewConfig__mdt cfg = forRegion(region);
        if (cfg == null) {
            throw new ConfigException('No BrewConfig record for region: ' + region);
        }
        return cfg;
    }

    /**
     * Reports whether free shipping applies for an order subtotal in
     * a given region. Convenience wrapper around the threshold check
     * — the hot path on every checkout.
     */
    public static Boolean qualifiesForFreeShipping(String region, Decimal orderTotal) {
        if (orderTotal == null) return false;
        BrewConfig__mdt cfg = forRegion(region);
        if (cfg == null || cfg.FreeShippingThreshold__c == null) return false;
        return orderTotal >= cfg.FreeShippingThreshold__c;
    }

    /**
     * Returns the default subscription cadence for a region, falling
     * back to "Monthly" if the region isn't configured. Used by the
     * onboarding flow when a customer signs up without an explicit
     * cadence preference.
     */
    public static String defaultCadenceForRegion(String region) {
        BrewConfig__mdt cfg = forRegion(region);
        if (cfg != null && cfg.DefaultCadence__c != null) {
            return cfg.DefaultCadence__c;
        }
        return 'Monthly';
    }

    /**
     * Returns the set of regions where the loyalty program is on.
     * Used by BrewLoyaltyEngine to skip point-awards in regions that
     * don't participate.
     */
    public static Set<String> regionsWithLoyaltyEnabled() {
        Set<String> out = new Set<String>();
        for (BrewConfig__mdt cfg : CONFIG_BY_REGION.values()) {
            if (cfg.EnableLoyalty__c == true && cfg.Region__c != null) {
                out.add(cfg.Region__c.toUpperCase());
            }
        }
        return out;
    }
}
