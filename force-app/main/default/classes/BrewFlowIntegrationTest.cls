/**
 * Proves the RecordBeforeSave flow (Account_WelcomeEnrichment)
 * runs end-to-end inside the test interpreter and the Apex trigger
 * sees the flow's mutations.
 */
@IsTest
private class BrewFlowIntegrationTest {

    @IsTest
    static void flow_setsIndustry_onInsert() {
        Account a = new Account(Name = 'Berlin Espresso Bar');
        insert a;
        Account out = [SELECT Industry, Description FROM Account WHERE Id = :a.Id];
        Assert.areEqual('Coffee', out.Industry, 'Flow should set Industry');
        Assert.areEqual('Welcome to BerlinBrew', out.Description);
    }

    @IsTest
    static void flow_runsBeforeTrigger_soTriggerSeesFlowWrites() {
        Account a = new Account(Name = 'Cafe Neue', Website = 'cafeneue.de');
        insert a;
        Account out = [SELECT Industry, Website FROM Account WHERE Id = :a.Id];
        Assert.areEqual('Coffee', out.Industry);
        Assert.areEqual('https://cafeneue.de', out.Website);
    }

    @IsTest
    static void flow_does_not_runOnUpdate() {
        Account a = new Account(Name = 'X');
        insert a;
        update new Account(Id = a.Id, Industry = 'Other');
        Assert.areEqual('Other', [SELECT Industry FROM Account WHERE Id = :a.Id].Industry);
    }

    @IsTest
    static void flow_writes_syncBack_forDownstreamValidations() {
        Account a = new Account(Name = 'Roaster HQ', Website = 'roaster.de');
        insert a;
        Account out = [SELECT Industry, Website, Description FROM Account WHERE Id = :a.Id];
        Assert.isTrue(out.Industry == 'Coffee' && out.Website.startsWith('https://') && out.Description != null,
            'Flow writes + trigger writes must both persist; got Industry=' + out.Industry
            + ' Website=' + out.Website + ' Description=' + out.Description);
    }

    @IsTest
    static void bulk_insert_flowFiresPerRecord() {
        List<Account> batch = new List<Account>();
        for (Integer i = 0; i < 50; i++) batch.add(new Account(Name = 'Cafe ' + i));
        insert batch;
        Integer industryCount = [SELECT COUNT() FROM Account WHERE Industry = 'Coffee' AND Name LIKE 'Cafe %'];
        Assert.areEqual(50, industryCount);
    }

    @IsTest
    static void serial_inserts_flowFiresPerRecord() {
        for (Integer i = 0; i < 5; i++) {
            insert new Account(Name = 'Serial ' + i);
        }
        Integer industryCount = [SELECT COUNT() FROM Account WHERE Industry = 'Coffee' AND Name LIKE 'Serial %'];
        Assert.areEqual(5, industryCount);
    }
}
