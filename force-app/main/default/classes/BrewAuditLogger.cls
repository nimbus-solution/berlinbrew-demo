/**
 * Audit logging facade. Routes domain events (subscriptions activated,
 * shipments dispatched, loyalty tier graduated, etc.) into the HopLog
 * managed package — a fictional third-party logging library installed
 * in the org with namespace `Hoplog`.
 *
 * Why this is interesting for a Nimbus demo:
 *
 * The HopLog source isn't in the repo (it lives inside an installed
 * managed package). nimbus.properties declares
 * `nimbus.stubs.namespaces=Hoplog`, so every `Hoplog.Logger.*` call
 * here gets auto-stubbed (returns null/empty/no-op) at test time.
 * Tests still run end-to-end without the managed-package source.
 *
 * For richer scenarios where you need test-time TYPES from the
 * managed package (e.g. a `Hoplog.LogContext ctx = ...` declaration),
 * the auto-stub isn't enough — Nimbus needs the type to actually
 * resolve. That's what `stubs/Hoplog/Hoplog.cls` is for: see
 * `stubs/README.md` for the configuration pattern.
 */
public with sharing class BrewAuditLogger {

    public class AuditException extends Exception {}

    /**
     * Records a structured audit event against the HopLog logger.
     * eventType is a short verb tag ("subscription.activated",
     * "shipment.dispatched"); payload is whatever shape the call site
     * wants, serialized to JSON before handoff so the managed package
     * doesn't dictate our domain types.
     */
    public static void record(String eventType, Map<String, Object> payload) {
        if (String.isBlank(eventType)) {
            throw new AuditException('eventType is required');
        }
        String json = payload == null ? null : JSON.serialize(payload);
        Hoplog.Logger.info(eventType, json);
    }

    /**
     * Records an exception with full stack-trace context. Used by
     * domain services in their catch blocks so failures don't get
     * swallowed without leaving a trail.
     */
    public static void recordError(String eventType, Exception ex) {
        if (String.isBlank(eventType) || ex == null) return;
        String json = JSON.serialize(new Map<String, Object>{
            'message' => ex.getMessage(),
            'type'    => ex.getTypeName(),
            'line'    => ex.getLineNumber(),
            'stack'   => ex.getStackTraceString()
        });
        Hoplog.Logger.error(eventType, json);
    }

    /**
     * Bulk-record variant for trigger-handler call sites that need to
     * log one event per record without N round-trips into Hoplog.
     */
    public static void recordBatch(String eventType, List<Map<String, Object>> payloads) {
        if (String.isBlank(eventType) || payloads == null || payloads.isEmpty()) return;
        List<String> jsonPayloads = new List<String>();
        for (Map<String, Object> p : payloads) {
            jsonPayloads.add(JSON.serialize(p));
        }
        Hoplog.Logger.batchInfo(eventType, jsonPayloads);
    }
}
