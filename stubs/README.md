# stubs/

This directory holds **user stubs** for managed packages and types
Nimbus doesn't know about natively. If your tests reference types from
a managed package — for example `Nebula.LogEntryEventBuilder` from
nebula-logger or anything in the `fflib_` namespace — Nimbus needs to
know how to treat them.

## When you need a stub

You'll know when you see a warning like:

```
⚠ Found references to managed package 'Nebula' with no stub configured.
```

That's Nimbus telling you it encountered a type it can't resolve.

## Two ways to handle managed packages

### 1. Treat the whole namespace as opaque (most common)

Add the namespace to `nimbus.properties`:

```properties
nimbus.stubs.namespaces=Nebula,fflib
```

Nimbus will silently auto-stub any reference to a type in those
namespaces. Method calls return null/zero/empty, side effects are
no-ops. Matching is case-insensitive (Apex itself is). This is what
you want 95% of the time — managed packages your tests don't actually
exercise behaviorally.

### 2. Define explicit stub behavior (advanced)

For managed packages you DO need test-time behavior from, drop a
folder under `stubs/` named after the package — `stubs/<Pkg>/` — and
put everything for that package inside it:

```
stubs/
└── Hoplog/
    ├── Hoplog.cls                              # Apex class surface
    └── objects/
        └── Hoplog__LogEntry__c/                # namespaced custom object
            ├── Hoplog__LogEntry__c.object-meta.xml
            └── fields/
                ├── Hoplog__Severity__c.field-meta.xml
                ├── Hoplog__EventType__c.field-meta.xml
                └── Hoplog__Message__c.field-meta.xml
```

Nimbus loads:

- **Apex classes** under `stubs/<Pkg>/` so type-position references
  (`Hoplog.Logger ctx = ...`) bind cleanly.
- **Namespaced custom objects/fields** under `stubs/<Pkg>/objects/`
  the same way it loads any other custom object — DML and SOQL on
  `Hoplog__LogEntry__c` work end-to-end without the package being
  installed.

One folder per package keeps surfaces from different managed
dependencies cleanly separated. Adding `Nebula` later is just
`stubs/Nebula/` next to `stubs/Hoplog/`.

By convention, capitalize the namespace folder and class name —
Nimbus matches case-insensitively but consistent capitalization is
clearer on grep and in code review.

Full reference: https://testnimbus.dev/docs/managed-packages

## Commit this directory

The whole `stubs/` tree belongs in git — your team shares one
configuration. `stubs/` is in `.forceignore` so nothing here ever
ships to a real org.
