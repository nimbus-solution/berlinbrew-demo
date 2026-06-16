# Contributing

Berlin Brew uses **trunk-based development**. `main` is the single source of
truth and is always releasable.

## Workflow

1. Branch off `main` for a short-lived change:
   ```bash
   git switch -c feat/loyalty-tier-rules main
   ```
2. Keep it small and merge within a day or two. Avoid long-lived branches.
3. Open a pull request into `main`. CI runs automatically.
4. Merge once **CI is green** and the PR is approved. Squash to keep `main`
   linear.

## CI gate

Every PR runs the [`CI`](.github/workflows/ci.yml) workflow, which executes the
full Apex suite locally with [Nimbus](https://testnimbus.dev) — no Salesforce
org required. The merge is blocked unless:

- all Apex tests pass, and
- line coverage is at least **75%** (the Salesforce production minimum).

Run the same checks locally before pushing:

```bash
nimbus test "*" --profile ci --coverage --coverage-report coverage.xml
```

The `%ci` profile (see `nimbus.properties`) enforces strict governor limits and
parallel execution, matching CI.

## No deployment here

This repository validates code; it does not deploy. Releasing to an org is a
separate, deliberate step outside this pipeline.
