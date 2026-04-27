/**
 * FIFO inventory reservation against RoastBatch__c rows.
 * Fails hard when stock is insufficient rather than partially reserving.
 */
public with sharing class BrewInventoryService {

    public class OutOfStockException extends Exception {}

    public static final Decimal SUBSCRIPTION_KG = 0.25;

    public static List<RoastBatch__c> reserve(Id productId, Decimal kgNeeded) {
        if (productId == null || kgNeeded == null || kgNeeded <= 0) return new List<RoastBatch__c>();

        // FOR UPDATE forbids explicit ORDER BY (Salesforce implicitly orders
        // by Id when locking). Pull the rows with a lock, then sort the
        // in-memory result by RoastDate__c for FIFO reservation.
        List<RoastBatch__c> batches = [
            SELECT Id, QuantityKg__c, ReservedKg__c, RoastDate__c
            FROM RoastBatch__c
            WHERE Product__c = :productId
            FOR UPDATE
        ];
        List<RoastBatchByDate> sortable = new List<RoastBatchByDate>();
        for (RoastBatch__c b : batches) sortable.add(new RoastBatchByDate(b));
        sortable.sort();
        batches = new List<RoastBatch__c>();
        for (RoastBatchByDate w : sortable) batches.add(w.batch);

        Decimal available = 0;
        for (RoastBatch__c b : batches) {
            available += (b.QuantityKg__c - (b.ReservedKg__c == null ? 0 : b.ReservedKg__c));
        }
        if (available < kgNeeded) {
            throw new OutOfStockException(
                'Not enough stock: needed ' + kgNeeded + 'kg, available ' + available + 'kg'
            );
        }

        Decimal remaining = kgNeeded;
        List<RoastBatch__c> toUpdate = new List<RoastBatch__c>();
        for (RoastBatch__c b : batches) {
            if (remaining <= 0) break;
            Decimal free = b.QuantityKg__c - (b.ReservedKg__c == null ? 0 : b.ReservedKg__c);
            if (free <= 0) continue;
            Decimal take = (free >= remaining) ? remaining : free;
            b.ReservedKg__c = (b.ReservedKg__c == null ? 0 : b.ReservedKg__c) + take;
            toUpdate.add(b);
            remaining -= take;
        }
        update toUpdate;
        return toUpdate;
    }

    /**
     * Wrapper that makes RoastBatch__c sortable by RoastDate__c
     * for the in-memory FIFO ordering after a FOR UPDATE query.
     * Apex requires Comparable for List.sort with a comparator.
     */
    public class RoastBatchByDate implements Comparable {
        public RoastBatch__c batch;
        public RoastBatchByDate(RoastBatch__c b) { this.batch = b; }
        public Integer compareTo(Object other) {
            RoastBatchByDate o = (RoastBatchByDate) other;
            Date a = batch.RoastDate__c;
            Date b = o.batch.RoastDate__c;
            if (a == null && b == null) return 0;
            if (a == null) return -1;
            if (b == null) return 1;
            if (a < b) return -1;
            if (a > b) return 1;
            return 0;
        }
    }

    public static Decimal availableStock(Id productId) {
        AggregateResult[] rows = [
            SELECT SUM(QuantityKg__c) total, SUM(ReservedKg__c) reserved
            FROM RoastBatch__c
            WHERE Product__c = :productId
        ];
        Decimal total    = (Decimal) rows[0].get('total');
        Decimal reserved = (Decimal) rows[0].get('reserved');
        if (total == null) return 0;
        return total - (reserved == null ? 0 : reserved);
    }
}
