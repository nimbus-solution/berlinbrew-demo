/**
 * Tests for BrewWelcomeMailer. Demonstrates Nimbus's automatic
 * loading of custom labels from `labels/CustomLabels.labels-meta.xml`,
 * with optional override via `nimbus.seed.label.*=` in
 * nimbus.properties.
 *
 * The `BrewWelcomeSubject` label is overridden in nimbus.properties
 * (`nimbus.seed.label.BrewWelcomeSubject=Welcome to BerlinBrew`),
 * which is what the welcome-subject test asserts. The other two
 * labels load straight from the labels-meta.xml file — no override
 * needed.
 */
@isTest
private class BrewWelcomeMailerTest {

    @isTest
    static void compose_nullAccount_throws() {
        try {
            BrewWelcomeMailer.compose(null);
            Assert.fail('expected MailerException');
        } catch (BrewWelcomeMailer.MailerException e) {
            Assert.isTrue(e.getMessage().contains('required'));
        }
    }

    @isTest
    static void compose_validAccount_includesWelcomeSubject() {
        Account a = new Account(Name = 'Test Cafe');
        insert a;
        a = [SELECT Id, Name, OwnerId FROM Account WHERE Id = :a.Id];

        Messaging.SingleEmailMessage msg = BrewWelcomeMailer.compose(a);
        Assert.areNotEqual(null, msg);
        // Subject pulled from the seeded label in nimbus.properties.
        Assert.areEqual('Welcome to BerlinBrew', msg.getSubject());
    }

    @isTest
    static void compose_bodyIncludesAccountName() {
        Account a = new Account(Name = 'Test Cafe');
        insert a;
        a = [SELECT Id, Name, OwnerId FROM Account WHERE Id = :a.Id];

        Messaging.SingleEmailMessage msg = BrewWelcomeMailer.compose(a);
        String body = msg.getPlainTextBody();
        Assert.isTrue(body.contains('Test Cafe'), 'body should mention account name');
    }

    @isTest
    static void compose_bodyIncludesSignoff() {
        Account a = new Account(Name = 'X');
        insert a;
        a = [SELECT Id, Name, OwnerId FROM Account WHERE Id = :a.Id];

        Messaging.SingleEmailMessage msg = BrewWelcomeMailer.compose(a);
        // Multi-line label — newline preserved through the loader.
        Assert.isTrue(msg.getPlainTextBody().contains('The BerlinBrew Team'));
    }

    @isTest
    static void composeTierGraduation_interpolatesTierName() {
        String result = BrewWelcomeMailer.composeTierGraduation('Gold');
        Assert.isTrue(result.contains('Gold'), 'expected tier name in message');
    }

    @isTest
    static void composeTierGraduation_blankTier_throws() {
        try {
            BrewWelcomeMailer.composeTierGraduation('');
            Assert.fail('expected MailerException');
        } catch (BrewWelcomeMailer.MailerException e) {
            Assert.isTrue(e.getMessage().contains('required'));
        }
    }

    @isTest
    static void supportSignoff_returnsLabelValue() {
        // Loads from labels-meta.xml — no nimbus.properties override
        // needed, so this verifies the regular label-loading path.
        String s = BrewWelcomeMailer.supportSignoff();
        Assert.isTrue(String.isNotBlank(s));
        Assert.isTrue(s.contains('BerlinBrew'));
    }
}
