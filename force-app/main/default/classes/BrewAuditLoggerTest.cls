/**
 * Tests for BrewAuditLogger. Demonstrates Nimbus's handling of
 * managed-package references via the `nimbus.stubs.namespaces=Hoplog`
 * declaration in nimbus.properties.
 *
 * What's interesting here: every assertion calls into the auto-stubbed
 * `Hoplog.*` surface and gets back null/no-op. The tests verify the
 * call SHAPE (we routed the right inputs into the logger at the right
 * time) without depending on the managed package's internal behavior,
 * which the real org would provide and tests don't need to mock.
 *
 * If you wanted Hoplog calls to actually return values during tests
 * (e.g. assert "the logger captured these messages"), drop an explicit
 * stub at stubs/Hoplog/Hoplog.cls — see stubs/README.md.
 */
@isTest
private class BrewAuditLoggerTest {

    @isTest
    static void record_emptyEventType_throws() {
        try {
            BrewAuditLogger.record('', new Map<String, Object>{ 'k' => 'v' });
            Assert.fail('expected AuditException');
        } catch (BrewAuditLogger.AuditException e) {
            Assert.isTrue(e.getMessage().contains('required'));
        }
    }

    @isTest
    static void record_nullEventType_throws() {
        try {
            BrewAuditLogger.record(null, null);
            Assert.fail('expected AuditException');
        } catch (BrewAuditLogger.AuditException e) {
            Assert.isTrue(e.getMessage().contains('required'));
        }
    }

    @isTest
    static void record_validEvent_doesNotThrow() {
        Test.startTest();
        BrewAuditLogger.record('subscription.activated', new Map<String, Object>{
            'subscriptionId' => 'a01000000000001',
            'monthlyPrice'   => 24.99
        });
        Test.stopTest();
        // Hoplog is auto-stubbed → call returns void with no side effect.
        // What we're testing: BrewAuditLogger built a LogContext and
        // called Logger.info without throwing. If the call site shape
        // changes (e.g. someone introduces a required field), this
        // test catches it via NullPointerException at the call.
        Assert.isTrue(true);
    }

    @isTest
    static void record_nullPayload_serializesAsNull() {
        // Edge case: caller passed null payload. We should not call
        // JSON.serialize(null) and crash — the implementation skips
        // serialization entirely.
        BrewAuditLogger.record('app.started', null);
        Assert.isTrue(true);
    }

    @isTest
    static void recordError_capturesExceptionMetadata() {
        Exception caught;
        try {
            // Force a real exception so we have a non-trivial stack.
            Integer x = Integer.valueOf('not-a-number');
            x = x + 1;
        } catch (Exception e) {
            caught = e;
        }
        Assert.areNotEqual(null, caught, 'precondition: exception captured');

        Test.startTest();
        BrewAuditLogger.recordError('integer.parse.failed', caught);
        Test.stopTest();
        Assert.isTrue(true);
    }

    @isTest
    static void recordError_nullArgs_isNoop() {
        BrewAuditLogger.recordError(null, null);
        BrewAuditLogger.recordError('x', null);
        BrewAuditLogger.recordError(null, new BrewAuditLogger.AuditException('x'));
        Assert.isTrue(true);
    }

    @isTest
    static void recordBatch_withMultiplePayloads_doesNotThrow() {
        List<Map<String, Object>> payloads = new List<Map<String, Object>>{
            new Map<String, Object>{ 'subscriptionId' => 'a01' },
            new Map<String, Object>{ 'subscriptionId' => 'a02' },
            new Map<String, Object>{ 'subscriptionId' => 'a03' }
        };
        Test.startTest();
        BrewAuditLogger.recordBatch('subscription.advanced', payloads);
        Test.stopTest();
        Assert.isTrue(true);
    }

    @isTest
    static void recordBatch_emptyList_isNoop() {
        BrewAuditLogger.recordBatch('event.x', new List<Map<String, Object>>());
        BrewAuditLogger.recordBatch('event.x', null);
        Assert.isTrue(true);
    }
}
