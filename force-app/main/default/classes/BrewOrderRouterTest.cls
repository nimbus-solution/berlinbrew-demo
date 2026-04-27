/**
 * Tests for BrewOrderRouter. Demonstrates the Stub API:
 * Test.createStub + Apex's System.StubProvider interface, used to
 * mock IBrewShippingProvider without an HTTP callout.
 *
 * The stub captures every method invocation, lets the test inspect
 * which methods were called with which arguments, and returns
 * canned values per call. This is the idiomatic way to isolate a
 * unit test from external dependencies in modern Apex.
 */
@isTest
private class BrewOrderRouterTest {

    /**
     * Manual StubProvider: tests pass it to Test.createStub which
     * returns an instance of IBrewShippingProvider whose calls are
     * intercepted by handleMethodCall below.
     */
    private class FakeShippingProvider implements System.StubProvider {

        public Decimal nextRate;
        public Integer callCount = 0;
        public List<Object> lastArgs;

        public Object handleMethodCall(
            Object stubbedObject, String methodName, Type returnType,
            List<Type> paramTypes, List<String> paramNames, List<Object> args
        ) {
            callCount++;
            lastArgs = args;
            if (methodName == 'getRate') {
                return nextRate;
            }
            return null;
        }
    }

    private static IBrewShippingProvider buildStub(FakeShippingProvider fake) {
        return (IBrewShippingProvider) Test.createStub(IBrewShippingProvider.class, fake);
    }

    @isTest
    static void decideShipping_belowThreshold_callsProvider() {
        FakeShippingProvider fake = new FakeShippingProvider();
        fake.nextRate = 8.50;
        IBrewShippingProvider provider = buildStub(fake);

        BrewOrderRouter router = new BrewOrderRouter(provider, 'EU');
        // EU threshold is 50.00; subtotal of 30 should NOT qualify.
        BrewOrderRouter.ShippingDecision d = router.decideShipping(30.00, '10115', 1.5);

        Assert.areEqual(false, d.isFree);
        Assert.areEqual(8.50, d.cost);
        Assert.areEqual(1, fake.callCount, 'stub should have been called exactly once');
        Assert.areEqual('10115', fake.lastArgs[0]);
        Assert.areEqual(1.5, fake.lastArgs[1]);
    }

    @isTest
    static void decideShipping_aboveThreshold_skipsProvider() {
        FakeShippingProvider fake = new FakeShippingProvider();
        fake.nextRate = 999.99; // Should never be returned.
        IBrewShippingProvider provider = buildStub(fake);

        BrewOrderRouter router = new BrewOrderRouter(provider, 'EU');
        // 60.00 > 50.00 → free shipping, no provider call.
        BrewOrderRouter.ShippingDecision d = router.decideShipping(60.00, '10115', 1.5);

        Assert.areEqual(true, d.isFree);
        Assert.areEqual(0, d.cost);
        Assert.areEqual(0, fake.callCount, 'free-shipping path should NOT call the provider');
        Assert.isTrue(d.reason.contains('free-shipping threshold'));
    }

    @isTest
    static void decideShipping_unknownRegion_routesAsPaid() {
        // No BrewConfig record for region 'CA' → qualifies returns
        // false → provider is called.
        FakeShippingProvider fake = new FakeShippingProvider();
        fake.nextRate = 12.00;
        IBrewShippingProvider provider = buildStub(fake);

        BrewOrderRouter router = new BrewOrderRouter(provider, 'CA');
        BrewOrderRouter.ShippingDecision d = router.decideShipping(1000.00, '90210', 5.0);

        Assert.areEqual(false, d.isFree);
        Assert.areEqual(12.00, d.cost);
        Assert.areEqual(1, fake.callCount);
    }

    @isTest
    static void constructor_nullProvider_throws() {
        try {
            new BrewOrderRouter(null, 'EU');
            Assert.fail('expected RoutingException');
        } catch (BrewOrderRouter.RoutingException e) {
            Assert.isTrue(e.getMessage().contains('provider'));
        }
    }

    @isTest
    static void constructor_blankRegion_throws() {
        FakeShippingProvider fake = new FakeShippingProvider();
        IBrewShippingProvider provider = buildStub(fake);
        try {
            new BrewOrderRouter(provider, '');
            Assert.fail('expected RoutingException');
        } catch (BrewOrderRouter.RoutingException e) {
            Assert.isTrue(e.getMessage().contains('region'));
        }
    }
}
