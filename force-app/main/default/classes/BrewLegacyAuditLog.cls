/**
 * Demonstrates Nimbus's API-version mismatch warning. This class
 * declares apiVersion 52.0 (Spring '21) in its sibling .cls-meta.xml
 * — but uses System.Assert.areEqual, which Salesforce introduced in
 * API 56.0 (Summer '22). On a real org, deploying this code to a
 * production org would fail with a cryptic "method does not exist"
 * error at install time.
 *
 * When Nimbus runs the test suite, it surfaces this mismatch as a
 * warning at the start of the run:
 *
 *     ⚠ src/.../BrewLegacyAuditLog.cls:N  references
 *       System.Assert.areEqual (introduced in API 56.0) but class
 *       apiVersion is 52.0
 *
 * Tests still run — the warning is advisory. Two ways to resolve:
 *
 *   1. Bump the apiVersion in BrewLegacyAuditLog.cls-meta.xml from
 *      52.0 to 56.0 (or higher).
 *   2. Rewrite the call to use System.assertEquals (the pre-56.0
 *      static-method-of-System form).
 *
 * The cleanest framing on a brand-new project is "always use the
 * latest apiVersion you can"; on legacy projects with version-pinned
 * managed packages, sometimes #2 is the only viable fix.
 */
public class BrewLegacyAuditLog {

    public static Boolean verifyOrderTotal(Decimal expected, Decimal actual) {
        // System.Assert.areEqual is API 56.0+. With apiVersion 52.0
        // declared in the meta.xml, Nimbus warns about the mismatch.
        System.Assert.areEqual(expected, actual, 'order total mismatch');
        return true;
    }
}
