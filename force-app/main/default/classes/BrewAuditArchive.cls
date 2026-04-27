/**
 * Persists audit events into the HopLog managed package's
 * `Hoplog__LogEntry__c` custom object — alongside the in-memory
 * `Hoplog.Logger.*` fan-out that BrewAuditLogger performs.
 *
 * Why this is interesting for a Nimbus demo:
 *
 * `Hoplog__LogEntry__c` is shaped like a managed-package custom object
 * (namespace prefix `Hoplog__`, fields `Hoplog__Message__c`,
 * `Hoplog__Severity__c`, `Hoplog__EventType__c`). On a real org you
 * wouldn't define this in source — it'd ship inside the installed
 * package. For the demo we define it under `stubs/Hoplog/objects/`
 * so Nimbus can run DML against it; `stubs/` is `.forceignore`d so
 * real-org deploys never try to ship it (which would fail since you
 * can't define objects in a namespace you don't own).
 *
 * Nimbus's schema synthesizer reads the object-meta.xml + field XMLs
 * from `stubs/Hoplog/objects/`, creates the matching Postgres table,
 * and INSERT/SELECT/UPDATE on `Hoplog__LogEntry__c` work exactly like
 * any other SObject during tests.
 */
public with sharing class BrewAuditArchive {

    public class ArchiveException extends Exception {}

    /**
     * Inserts a log entry into the managed-package object. Wrap your
     * own audit calls in this when you need a queryable trail in
     * addition to the live Hoplog fan-out.
     */
    public static Hoplog__LogEntry__c persist(String eventType, String severity, String message) {
        if (String.isBlank(eventType) || String.isBlank(severity)) {
            throw new ArchiveException('eventType and severity are required');
        }
        Hoplog__LogEntry__c row = new Hoplog__LogEntry__c(
            Hoplog__EventType__c = eventType,
            Hoplog__Severity__c  = severity,
            Hoplog__Message__c   = message
        );
        insert row;
        return row;
    }

    /**
     * Persist + announce in one call — the typical usage from a
     * domain service that wants both a permanent record AND the
     * live logger fan-out.
     */
    public static Hoplog__LogEntry__c recordAndPersist(String eventType, String severity, Map<String, Object> payload) {
        String json = payload == null ? null : JSON.serialize(payload);
        Hoplog__LogEntry__c row = persist(eventType, severity, json);

        // Live announce via the in-memory logger so subscribers
        // (dashboards, alerting) see it before the DML commits.
        if (severity == 'ERROR') {
            Hoplog.Logger.error(eventType, json);
        } else if (severity == 'WARN') {
            Hoplog.Logger.warn(eventType, json);
        } else {
            Hoplog.Logger.info(eventType, json);
        }
        return row;
    }

    public static List<Hoplog__LogEntry__c> recentByEventType(String eventType, Integer limitN) {
        if (String.isBlank(eventType)) return new List<Hoplog__LogEntry__c>();
        Integer n = (limitN == null || limitN <= 0) ? 50 : limitN;
        return [
            SELECT Id, Hoplog__EventType__c, Hoplog__Severity__c, Hoplog__Message__c, CreatedDate
            FROM Hoplog__LogEntry__c
            WHERE Hoplog__EventType__c = :eventType
            ORDER BY CreatedDate DESC
            LIMIT :n
        ];
    }

    public static Integer countBySeverity(String severity) {
        if (String.isBlank(severity)) return 0;
        return [
            SELECT COUNT()
            FROM Hoplog__LogEntry__c
            WHERE Hoplog__Severity__c = :severity
        ];
    }
}
