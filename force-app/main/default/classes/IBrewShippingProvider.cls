/**
 * Provider interface for shipping-rate lookups. Lets the order flow
 * be tested without an HTTP callout (Test.createStub) or even an
 * HttpCalloutMock — pass an in-memory stub that returns deterministic
 * rates per (postalCode, weight) combo.
 *
 * The real implementation lives in BrewShippingCallout (which makes
 * the live HTTP call). The Stub-API test path uses Test.createStub
 * to inject a controlled mock — see BrewOrderRouterTest for the
 * call site and BrewShippingProviderStubTest for a focused stub
 * verification.
 */
public interface IBrewShippingProvider {
    Decimal getRate(String postalCode, Decimal weightKg);
}
