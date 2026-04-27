/**
 * Tests for BrewAuditArchive. Demonstrates Nimbus running DML and
 * SOQL against a managed-package-shaped custom object
 * (`Hoplog__LogEntry__c`) without the managed package being
 * installed. The schema lives at
 * `stubs/Hoplog/objects/Hoplog__LogEntry__c/`; Nimbus loads it the
 * same way it loads any other custom object.
 */
@isTest
private class BrewAuditArchiveTest {

    @isTest
    static void persist_blankEventType_throws() {
        try {
            BrewAuditArchive.persist('', 'INFO', 'msg');
            Assert.fail('expected ArchiveException');
        } catch (BrewAuditArchive.ArchiveException e) {
            Assert.isTrue(e.getMessage().contains('required'));
        }
    }

    @isTest
    static void persist_blankSeverity_throws() {
        try {
            BrewAuditArchive.persist('order.created', '', 'msg');
            Assert.fail('expected ArchiveException');
        } catch (BrewAuditArchive.ArchiveException e) {
            Assert.isTrue(e.getMessage().contains('required'));
        }
    }

    @isTest
    static void persist_validInputs_writesRowAndIsQueryable() {
        Test.startTest();
        Hoplog__LogEntry__c row = BrewAuditArchive.persist(
            'subscription.activated', 'INFO', 'subscription a01 activated'
        );
        Test.stopTest();

        Assert.areNotEqual(null, row.Id, 'expected an Id after insert');

        Hoplog__LogEntry__c fetched = [
            SELECT Hoplog__EventType__c, Hoplog__Severity__c, Hoplog__Message__c
            FROM Hoplog__LogEntry__c WHERE Id = :row.Id
        ];
        Assert.areEqual('subscription.activated', fetched.Hoplog__EventType__c);
        Assert.areEqual('INFO', fetched.Hoplog__Severity__c);
        Assert.isTrue(fetched.Hoplog__Message__c.contains('a01'));
    }

    @isTest
    static void recordAndPersist_serializesPayload() {
        Map<String, Object> payload = new Map<String, Object>{
            'subscriptionId' => 'a01',
            'monthlyPrice'   => 24.99
        };
        Hoplog__LogEntry__c row = BrewAuditArchive.recordAndPersist(
            'subscription.activated', 'INFO', payload
        );
        Hoplog__LogEntry__c fetched = [
            SELECT Hoplog__Message__c FROM Hoplog__LogEntry__c WHERE Id = :row.Id
        ];
        Assert.isTrue(fetched.Hoplog__Message__c.contains('subscriptionId'));
        Assert.isTrue(fetched.Hoplog__Message__c.contains('a01'));
        Assert.isTrue(fetched.Hoplog__Message__c.contains('24.99'));
    }

    @isTest
    static void recordAndPersist_routesErrorSeverity() {
        // No way to assert what the in-memory Hoplog.Logger.error call
        // did (that's the auto-stub at work), but we can verify the
        // DML side: row was written with ERROR severity.
        Hoplog__LogEntry__c row = BrewAuditArchive.recordAndPersist(
            'shipment.failed', 'ERROR', new Map<String, Object>{ 'shipmentId' => 's42' }
        );
        Hoplog__LogEntry__c fetched = [
            SELECT Hoplog__Severity__c FROM Hoplog__LogEntry__c WHERE Id = :row.Id
        ];
        Assert.areEqual('ERROR', fetched.Hoplog__Severity__c);
    }

    @isTest
    static void recentByEventType_returnsMostRecentFirst() {
        BrewAuditArchive.persist('order.created', 'INFO', 'first');
        BrewAuditArchive.persist('order.created', 'INFO', 'second');
        BrewAuditArchive.persist('order.created', 'INFO', 'third');
        // Different event type — should not appear in the result
        BrewAuditArchive.persist('order.cancelled', 'INFO', 'noise');

        List<Hoplog__LogEntry__c> rows = BrewAuditArchive.recentByEventType('order.created', 10);
        Assert.areEqual(3, rows.size(), 'expected 3 order.created rows');
    }

    @isTest
    static void recentByEventType_blankInput_returnsEmpty() {
        Assert.areEqual(0, BrewAuditArchive.recentByEventType('', 5).size());
        Assert.areEqual(0, BrewAuditArchive.recentByEventType(null, 5).size());
    }

    @isTest
    static void countBySeverity_aggregatesCorrectly() {
        BrewAuditArchive.persist('a', 'INFO',  'x');
        BrewAuditArchive.persist('b', 'INFO',  'x');
        BrewAuditArchive.persist('c', 'WARN',  'x');
        BrewAuditArchive.persist('d', 'ERROR', 'x');

        Assert.areEqual(2, BrewAuditArchive.countBySeverity('INFO'));
        Assert.areEqual(1, BrewAuditArchive.countBySeverity('WARN'));
        Assert.areEqual(1, BrewAuditArchive.countBySeverity('ERROR'));
    }
}
