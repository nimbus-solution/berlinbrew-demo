@IsTest
private class BrewInventoryServiceTest {

    @IsTest static void reserve_singleBatch_reducesAvailable() {
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        BrewTestFactory.batch(p.Id, 5.0);
        BrewInventoryService.reserve(p.Id, 1.5);
        Assert.areEqual(3.5, BrewInventoryService.availableStock(p.Id));
    }

    @IsTest static void reserve_spans_multipleBatches_fifo() {
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        RoastBatch__c older = new RoastBatch__c(Product__c = p.Id, RoastDate__c = Date.today().addDays(-10), QuantityKg__c = 2, ReservedKg__c = 0);
        RoastBatch__c newer = new RoastBatch__c(Product__c = p.Id, RoastDate__c = Date.today(),              QuantityKg__c = 5, ReservedKg__c = 0);
        insert new List<RoastBatch__c>{ older, newer };

        List<RoastBatch__c> reserved = BrewInventoryService.reserve(p.Id, 3.0);
        Assert.areEqual(2, reserved.size());

        RoastBatch__c outOlder = [SELECT ReservedKg__c FROM RoastBatch__c WHERE Id = :older.Id];
        RoastBatch__c outNewer = [SELECT ReservedKg__c FROM RoastBatch__c WHERE Id = :newer.Id];
        Assert.areEqual(2.0, outOlder.ReservedKg__c);
        Assert.areEqual(1.0, outNewer.ReservedKg__c);
    }

    @IsTest static void reserve_outOfStock_throws() {
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        BrewTestFactory.batch(p.Id, 1.0);
        try {
            BrewInventoryService.reserve(p.Id, 5.0);
            Assert.fail();
        } catch (BrewInventoryService.OutOfStockException e) {
            Assert.isTrue(e.getMessage().contains('Not enough stock'));
        }
    }

    @IsTest static void reserve_zeroOrNull_noOp() {
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Assert.isTrue(BrewInventoryService.reserve(p.Id, 0).isEmpty());
        Assert.isTrue(BrewInventoryService.reserve(p.Id, null).isEmpty());
    }

    @IsTest static void availableStock_noBatches_isZero() {
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        Assert.areEqual(0, BrewInventoryService.availableStock(p.Id));
    }

    @IsTest static void availableStock_aggregate_sumsAllBatches() {
        CoffeeProduct__c p = BrewTestFactory.product('SKU-1', 10, 4);
        insert new List<RoastBatch__c>{
            new RoastBatch__c(Product__c = p.Id, RoastDate__c = Date.today(), QuantityKg__c = 3.5, ReservedKg__c = 0.5),
            new RoastBatch__c(Product__c = p.Id, RoastDate__c = Date.today(), QuantityKg__c = 2.0, ReservedKg__c = 1.0)
        };
        Assert.areEqual(4.0, BrewInventoryService.availableStock(p.Id));
    }
}
