# BerlinBrew

A fictional specialty-coffee subscription company built as a Salesforce DX project.
The official starter / showcase repo for [Nimbus](https://testnimbus.dev) — local
Apex test execution without an org.

## Install Nimbus

One-line install. Single static binary into `~/.local/bin`. No JVM, no Node, no Docker.
Linux, macOS (Intel + Apple Silicon), and Windows (via WSL) supported.

```bash
curl -fsSL https://install.testnimbus.dev | sh

# Verify
nimbus --version
```

Re-run any time to upgrade. Full install options: [testnimbus.dev/quickstart](https://testnimbus.dev/quickstart).

## Run the demo

```bash
git clone https://github.com/nimbus-solution/berlinbrew-demo
cd berlinbrew-demo
nimbus test
```

Expected: **all green in under a second on a warm daemon.** No org
connection, no credentials, no scratch org pool.

## What you get

A real-shape Salesforce project that exercises every facet of Nimbus you'd hit
on a production codebase — and a few you'd hit *eventually*. Not a toy.

**Domain:** coffee products, subscriptions, roast-batch inventory, FIFO
reservation, regional config, loyalty programs, shipping callouts, customer
metrics. Real-shape Apex with realistic state machines, governor-aware bulk
patterns, and trigger handlers.

### Salesforce metadata in this repo

| Kind | Files | What it shows |
|---|---|---|
| **Custom objects** | `CoffeeProduct__c`, `Subscription__c`, `RoastBatch__c`, `LoyaltyTransaction__c` | Lookups (with proper `<deleteConstraint>`), required fields, formula fields |
| **Custom Metadata Type** | `BrewConfig__mdt` + 3 records (EU, US, UK) | Region-specific config (free-shipping threshold, default cadence, loyalty toggle). Records load from `customMetadata/*.md-meta.xml` automatically — Nimbus seeds them into the local DB at Setup. |
| **Custom labels** | `BrewWelcomeSubject`, `BrewLoyaltyTierMessage`, `BrewSupportSignoff` | Loaded from `labels/CustomLabels.labels-meta.xml`. `BrewWelcomeSubject` overridden via `nimbus.seed.label.*` in nimbus.properties. |
| **Platform event** | `ShipmentEvent__e` | High-volume / publish-after-commit |
| **Triggers** | `AccountTrigger`, `SubscriptionTrigger` | Before/after handlers via TriggerHandler-style classes |
| **Record-triggered Flow** | `Account_WelcomeEnrichment` | RecordBeforeSave |
| **Profiles** | `BrewSupportAgent`, `BrewFulfillment` | FLS demo (BrewSupportAgent cannot read `WholesaleCost__c`) |
| **Permission set** | `BrewLoyaltyManager` | Used by `runAs` tests |

### Apex surface

| Class | What it shows |
|---|---|
| `BrewPricingService` | Pure pricing/margin math, FLS-gated query helper |
| `BrewLoyaltyEngine` | DML + platform events on tier graduation |
| `BrewSubscriptionService` | Lifecycle with state guards (activate/pause/resume/cancel) |
| `BrewInventoryService` | FIFO batch reservation with `FOR UPDATE` lock + in-memory date sort |
| `BrewShippingCallout` | HTTP callout with mockable boundary |
| `BrewCustomerMetrics` | Aggregate SOQL (`GROUP BY`, `SUM`, `COUNT`) |
| `BrewAccountHandler` | Before/after triggers with normalization + DML guards |
| `BrewSubscriptionHandler` | State-transition rules + after-update ripple to Account |
| `BrewAuditLogger` | **HopLog managed-package facade** — calls into `Hoplog.Logger.*` (see below) |
| `BrewAuditArchive` | **DML on a managed-package custom object** — `Hoplog__LogEntry__c` |
| `BrewRegionalConfig` | Reads `BrewConfig__mdt` records with class-load caching |
| `BrewWelcomeMailer` | Custom-label composition with `String.format` interpolation |
| `BrewOrderRouter` | Shipping decision combining mdt config + `IBrewShippingProvider` (Stub API target) |
| `IBrewShippingProvider` | Interface for `Test.createStub` mocking |
| `BrewLegacyAuditLog` | **Demonstrates the API-version mismatch warning** (see below) |

## Nimbus features showcased

### `nimbus init` scaffolding

Run on a fresh project: writes `nimbus.properties` (heavily commented) and
`stubs/README.md`. Both committed. Idempotent — re-running on a configured
project leaves the user's edits alone.

### Auto-doctor on first test run

When `.nimbus/history` is empty, `nimbus test` runs the doctor checks before
firing tests, prefixed with *"First run on this project — surfaced now so they
don't surprise you as test failures."* Subsequent runs silent.

### Managed-package handling — the **HopLog** showcase

HopLog is a fictional logging managed package this repo references in two
shapes — Apex classes (`Hoplog.Logger.*`) and a namespaced custom object
(`Hoplog__LogEntry__c` with fields `Hoplog__Severity__c`,
`Hoplog__EventType__c`, `Hoplog__Message__c`). Together they exercise both
sides of how Nimbus handles managed dependencies your org doesn't have.

Everything HopLog-related lives under `stubs/Hoplog/` — one folder per
managed package, classes and objects co-located. Adding Nebula tomorrow
is just `stubs/Nebula/` next to `stubs/Hoplog/`.

**Apex surface — `BrewAuditLogger`** calls `Hoplog.Logger.info(...)`,
`Hoplog.Logger.error(...)`, etc. Resolution at test time is two-layer:

1. `nimbus.properties` declares `nimbus.stubs.namespaces=Hoplog` — Nimbus
   resolves any `Hoplog` reference to null/no-op for static method calls.
   Matching is case-insensitive (Apex itself is).
2. `stubs/Hoplog/Hoplog.cls` provides the type definitions
   (`Hoplog.Logger` with no-op methods) so type-position references bind
   cleanly during tests.

**Custom object — `BrewAuditArchive`** runs real DML and SOQL against
`Hoplog__LogEntry__c`: `insert new Hoplog__LogEntry__c(...)`,
`SELECT ... FROM Hoplog__LogEntry__c WHERE Hoplog__Severity__c = 'ERROR'`.
The schema lives at `stubs/Hoplog/objects/Hoplog__LogEntry__c/`. Nimbus
loads the XML the same way it loads any other custom object and creates
the matching table in the embedded Postgres — so tests query the
namespaced object end-to-end without the package being installed.

The `.forceignore` excludes the entire `stubs/` tree plus the four
classes that call into HopLog (HopLog isn't installed in a real org, so
deploys would fail with "Variable does not exist: Hoplog.Logger") —
but Nimbus runs all of it locally green. **This is the demo: Nimbus runs
code that wouldn't deploy without dependencies your org doesn't have.**

### Custom metadata records — `BrewConfig__mdt`

Three records ship in `customMetadata/`. Nimbus loads them at Setup time and
they're queryable via SOQL with no test setup needed. `BrewRegionalConfig`
reads them via a static initializer (one-time per JVM) — same pattern you'd
write on a real org.

### Custom labels with seeded overrides

Labels load from `labels/CustomLabels.labels-meta.xml`. The
`BrewWelcomeSubject` label is overridden via
`nimbus.seed.label.BrewWelcomeSubject=...` in nimbus.properties to demonstrate
the per-environment override pattern.

### `@testSetup` per-test rollback

`BrewSharedSetupTest` exercises the contract end-to-end: setup runs once,
each test method runs in its own transaction that rolls back, mutations
in test 2 are invisible to test 3. Run with `--parallel 1` and `--parallel 8`
to verify isolation across both modes.

### Stub API — `Test.createStub`

`BrewOrderRouterTest.FakeShippingProvider` implements
`System.StubProvider`; tests mock `IBrewShippingProvider` without an HTTP
callout. The stub captures invocations, lets the test assert on call count
and arguments, and returns canned values per call.

### API-version mismatch detection

`BrewLegacyAuditLog.cls-meta.xml` declares apiVersion 52.0 but the class
calls `System.Assert.areEqual` — a method Salesforce introduced in v56.
Nimbus surfaces the mismatch at the start of every test run with a clear
hint about which symbol came in at which version:

```
⚠ src/.../BrewLegacyAuditLog.cls:36
  references System.Assert.areEqual (introduced in API 56.0)
  but class apiVersion is 52.0
```

Tests still run — it's advisory. Two ways to resolve: bump the apiVersion,
or use the older `System.assertEquals` form. The class is `.forceignore`d so
real-org deploys don't try to ship it.

### Pre-deploy field-metadata validation

The doctor check `Field metadata validity` walks every `*.field-meta.xml`
and runs the same shape-validation Salesforce does at deploy time. Today
it catches two of the most common deploy failures:

- **Required lookups that would fail at deploy** — when a required Lookup
  field has no `<deleteConstraint>` (or has `SetNull`), Salesforce rejects
  the deploy with *"must specify either cascade delete or restrict delete
  for required lookup foreign key."* The doctor surfaces this locally before
  you push.
- **Currency fields on Custom Metadata Types** — CMTs don't support
  Currency. Salesforce rejects at deploy; the doctor catches it earlier.

Auto-fires on first `nimbus test` run via the doctor preamble. Closes the
"passed locally, failed on org" gap.

## Project structure

```
berlinbrew-demo/
├── README.md                  # this file
├── nimbus.properties          # Nimbus config (managed packages, governor, label seeds)
├── sfdx-project.json          # standard SFDX project file
├── .forceignore               # excludes the HopLog showcase + API-version mismatch demo from sf deploys
├── stubs/
│   ├── README.md              # how to add managed-package stubs
│   └── Hoplog/                # one folder per package: classes + namespaced objects
│       ├── Hoplog.cls
│       └── objects/Hoplog__LogEntry__c/
└── force-app/main/default/
    ├── classes/               # services + test classes
    ├── customMetadata/        # 3 BrewConfig records (EU, US, UK)
    ├── flows/                 # Account_WelcomeEnrichment
    ├── labels/                # 3 custom labels
    ├── objects/               # 7 custom objects + Account/Contact extensions
    ├── permissionsets/        # BrewLoyaltyManager
    ├── profiles/              # BrewSupportAgent, BrewFulfillment
    ├── staticresources/       # demo CSV + sample shipping API JSON
    └── triggers/              # AccountTrigger, SubscriptionTrigger
```

## Common commands

```bash
# Run everything
nimbus test

# Run one class
nimbus test BrewPricingServiceTest

# Run one method
nimbus test BrewPricingServiceTest.weeklyPrice_is_fourTimesBase

# Pattern match
nimbus test "*Subscription*"

# With coverage
nimbus test --coverage

# Machine-readable output (for CI / AI agents)
nimbus test --json

# Open the browser dashboard
nimbus dev

# Run doctor (auto-fires on first run too)
nimbus doctor
```

## Disclaimer

The pricing, VAT handling, loyalty rules, and shipping economics are plausible
but not intended for production use. Any resemblance to a real Berlin
roastery is coincidental.

## License

MIT. See [LICENSE](LICENSE).

## Maintained by

[Nimbus](https://testnimbus.dev) — fast, local Apex test execution.
