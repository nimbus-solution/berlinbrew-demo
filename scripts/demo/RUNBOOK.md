# Mass update, dry run first — recording runbook

A ~3 minute demo: get data out of nimbus, edit it like a normal human in a
spreadsheet, and find out what it would really do **before** anything touches an
org. The point to land is the last one: a spreadsheet of six harmless-looking
edits quietly puts two customers on credit hold, and you can see that on your
own machine, in seconds, with nothing deployed.

## Before you record

```bash
cd berlinbrew-demo
nimbus reset               # the six demo accounts come back automatically
```

Use `nimbus reset`, not `nimbus data reset`: a database that already holds
rows seeded by an older nimbus keeps them, and you end up with two copies of
every account under different Ids.

The accounts are seeded from `nimbus.properties` (`nimbus.seed.row.Account.*`),
so they are simply there for the daemon, the IDE and the CLI, with stable Ids.
Nothing to run by hand. Check them if you like:

```bash
nimbus soql "SELECT Name, LifetimeValue__c, OnCreditHold__c FROM Account ORDER BY Name"
```

Every one starts **off** credit hold, with a tidy website and phone — so
anything the demo shows is a change the sheet or a trigger actually made.

Then regenerate the spreadsheet so its Ids match this machine:

```bash
./scripts/demo/make-sheet.sh
```

Open `scripts/demo/lifetime-value-corrections.csv` in Excel or Numbers and leave
it on a second desktop, ready to cut to.

## The automation you are demonstrating

`BrewAccountHandler.beforeUpdate`, reached from `AccountTrigger`:

| It does this | When |
|---|---|
| `OnCreditHold__c = true` **and** writes `CreditHoldReason__c` | `LifetimeValue__c` goes negative |
| Rewrites `Website` to a normalised URL | `Website` changed |
| Rewrites `Phone` to a normalised number | `Phone` changed |

Nobody puts "put this customer on credit hold" in a spreadsheet. That is the
whole demo.

## Act 1 — getting data out (~30s)

Nimbus tool window → **SOQL** tab. Run:

```sql
SELECT Id, Name, LifetimeValue__c, Website, Phone
FROM Account
WHERE Name LIKE '%(demo)%'
ORDER BY Name
```

Then **Export…** → CSV.

> "This is the local database — the same one my tests run against. I can pull
>  any slice of it straight into a spreadsheet."

## Act 2 — the edits (~20s)

Cut to the spreadsheet. Walk the four edits without dwelling:

- **Kreuzberg Kaffee** lifetime value → **-1250** (a refund went in wrong)
- **Prenzlauer Bohne** lifetime value → **-380**
- **Mitte Roasters** website → `mitteroasters.de` (someone dropped the https)
- **Neukoelln Espresso Bar** phone → `030 / 444 555` (typed by a human)

> "Six rows. Two of them negative, which happens after a bad refund batch.
>  Nothing here mentions credit holds."

## Act 3 — the dry run (~45s)

Nimbus tool window → **Mass Update** tab.

1. **Object:** Account
2. **Choose file:** `scripts/demo/lifetime-value-corrections.csv`
3. The column mapping fills itself in; **Id** is the key column
4. **Simulate**

> "This runs the update through the real triggers, on my machine, in a
>  transaction that is thrown away. Nothing is committed and no org is touched."

## Act 4 — the reveal (~60s)

Read the report top down. The changes are split by **who wrote them**, and that
split is the product. What you will see, exactly:

**From your sheet — 7 rows.** Five lifetime values, the website, the phone.
Only what actually differs: Friedrichshain Filter's value was already 2400, so
it produces no row at all. The summary says it plainly — **24 assignments, 19 of
which matched what was already there**. That number is worth reading out.

**From automation — 6 rows**, and this is the beat to slow down on:

| Field | Change | Who |
|---|---|---|
| `OnCreditHold__c` | false → **true** | `BrewAccountHandler.beforeUpdate:26` |
| `CreditHoldReason__c` | → *Negative lifetime value detected* | `BrewAccountHandler.beforeUpdate:27` |
| `Website` | `mitteroasters.de` → `https://mitteroasters.de` | `BrewAccountHandler.normalizeWebsite:56` |
| `Phone` | `030 / 444 555` → `030444555` | `BrewAccountHandler.normalizePhone:63` |

The credit-hold pair fires twice — Kreuzberg Kaffee and Prenzlauer Bohne, the
two accounts whose lifetime value went negative.

Note the Website and Phone rows appear **twice**: once as what the sheet asked
for, once as what the trigger did to it. That pairing is the point.

> "Two customers just went on credit hold. Nobody asked for that, it is not in
>  the spreadsheet, and in an org you would have found out from an angry email.
>  Here it took four seconds and touched nothing."

Then finish on isolation — the report says it itself: *"runner test transaction,
rolled back — the simulation is never committed."*

Re-run the SOQL from Act 1 to prove it: still `false`, still the old values.

## Act 5 — hand it back (~20s)

**Export** the report and send it to whoever sent the spreadsheet.

> "That is the answer to 'what will this do', in a file, before anyone deploys."

## Honest edges, if someone asks

Worth knowing rather than being caught by:

- The prior value on a sheet change is blank past the 20th record in a batch —
  the trace caps its per-statement record diff.
- Platform events, HTTP callouts and emails are counted but not itemised; the
  report says so in its own "not observed" list rather than pretending.
- Applying to an org, and the ≤8 batches in flight, are the next slice. This
  demo is the simulation only.
