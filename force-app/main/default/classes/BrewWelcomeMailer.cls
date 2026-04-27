/**
 * Composes the welcome email sent to a new account on enrollment.
 * Demonstrates Nimbus's handling of Apex `System.Label` references —
 * the labels live in `force-app/main/default/labels/CustomLabels.labels-meta.xml`
 * and Nimbus loads them at Setup time, so `Label.BrewWelcomeSubject`
 * resolves to the right value during tests with no per-test setup.
 *
 * Labels that need to differ between environments (e.g. an
 * environment-specific URL) can be overridden via
 * `nimbus.seed.label.<FullName>=<value>` in nimbus.properties — see
 * the comment block in this project's nimbus.properties for a working
 * example. The seeded value wins over the labels-meta.xml value, so
 * the same metadata file can ship to dev/staging/prod while tests
 * pin a deterministic value.
 */
public with sharing class BrewWelcomeMailer {

    public class MailerException extends Exception {}

    public static Messaging.SingleEmailMessage compose(Account account) {
        if (account == null) {
            throw new MailerException('account is required');
        }
        Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
        msg.setTargetObjectId(account.OwnerId);
        msg.setSubject(Label.BrewWelcomeSubject);
        msg.setPlainTextBody(buildBody(account));
        msg.setSaveAsActivity(false);
        return msg;
    }

    /**
     * Composes a loyalty-tier graduation message with the new tier
     * name interpolated into the label template. Demonstrates
     * String.format on a Label value — a real-Salesforce idiom.
     */
    public static String composeTierGraduation(String newTier) {
        if (String.isBlank(newTier)) {
            throw new MailerException('newTier is required');
        }
        return String.format(Label.BrewLoyaltyTierMessage, new List<String>{ newTier });
    }

    /**
     * Returns the support signoff. A multi-line label (note the
     * embedded newline in the labels-meta.xml file) — Nimbus
     * preserves it intact through the loader.
     */
    public static String supportSignoff() {
        return Label.BrewSupportSignoff;
    }

    private static String buildBody(Account account) {
        return 'Hi ' + (account.Name == null ? 'there' : account.Name) + ',\n\n' +
               'Welcome to BerlinBrew. Your first roast is being prepared.\n\n' +
               supportSignoff();
    }
}
