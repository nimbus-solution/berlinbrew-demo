/**
 * Routes a checkout into the right shipping decision: free if the
 * subtotal qualifies for the region, otherwise paid via the
 * configured shipping provider. Designed to be unit-tested with
 * Test.createStub on IBrewShippingProvider — no HTTP, no callout
 * mock, no DML on the real provider.
 *
 * Why this is interesting for a Nimbus demo:
 *
 * The Stub API (Test.createStub + Apex's StubProvider interface) is
 * a real Salesforce feature for mocking instances of interfaces or
 * non-final classes during tests. Nimbus implements it faithfully so
 * tests like the ones in BrewOrderRouterTest run end-to-end without
 * a real org or HTTP mocks.
 *
 * For the HTTP-mock alternative, see BrewShippingCalloutTest — both
 * patterns coexist; pick whichever fits your test better.
 */
public with sharing class BrewOrderRouter {

    public class RoutingException extends Exception {}

    public class ShippingDecision {
        public Boolean isFree;
        public Decimal cost;
        public String reason;
    }

    private final IBrewShippingProvider provider;
    private final String region;

    public BrewOrderRouter(IBrewShippingProvider provider, String region) {
        if (provider == null) throw new RoutingException('provider is required');
        if (String.isBlank(region)) throw new RoutingException('region is required');
        this.provider = provider;
        this.region = region;
    }

    /**
     * Decides shipping for an order. Returns ShippingDecision with
     * isFree=true (and cost=0) when the order qualifies for free
     * shipping per BrewConfig__mdt; otherwise looks up the live
     * rate from the provider.
     */
    public ShippingDecision decideShipping(Decimal subtotal, String postalCode, Decimal weightKg) {
        ShippingDecision d = new ShippingDecision();
        if (BrewRegionalConfig.qualifiesForFreeShipping(region, subtotal)) {
            d.isFree = true;
            d.cost   = 0;
            d.reason = 'Order subtotal meets free-shipping threshold for ' + region;
            return d;
        }
        d.isFree = false;
        d.cost   = provider.getRate(postalCode, weightKg);
        d.reason = 'Standard shipping';
        return d;
    }
}
