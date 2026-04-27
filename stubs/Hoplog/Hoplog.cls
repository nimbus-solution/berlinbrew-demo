/**
 * User stub for the HopLog managed-package logger.
 *
 * This file declares the surface BerlinBrew uses from the fictional
 * `Hoplog` managed package. Method bodies are no-ops — at test time
 * we don't care what the logger actually did with our messages, we
 * only care that the call shape is valid and our domain code routes
 * the right inputs into it.
 *
 * Why this file exists:
 *   - The real `Hoplog` package isn't in our repo (it ships as a
 *     compiled managed package installed in the org).
 *   - `nimbus.stubs.namespaces=Hoplog` in nimbus.properties tells
 *     Nimbus the namespace is intentional, but for type-position
 *     references (`Hoplog.Logger.info(...)`) Nimbus needs an actual
 *     class definition to bind to.
 *   - Drop one .cls per public class you reference inside the
 *     package's folder (`stubs/<Pkg>/`). Apex is case-insensitive,
 *     so `hoplog.Logger` and `Hoplog.Logger` both bind to this stub
 *     — but lead by example: capitalize.
 *
 * For managed packages where you DO need test-time behavior (e.g.
 * a logger that captures messages so tests can assert on them),
 * replace the no-op bodies with whatever in-memory test double
 * matches your needs.
 */
public class Hoplog {

    public class Logger {
        public static void info(String eventType, String payload) {
            // no-op stub
        }

        public static void warn(String eventType, String payload) {
            // no-op stub
        }

        public static void error(String eventType, String payload) {
            // no-op stub
        }

        public static void batchInfo(String eventType, List<String> payloads) {
            // no-op stub
        }
    }
}
