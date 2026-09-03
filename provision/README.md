# Provisioning the SharePoint data layer

> ## ALREADY DONE — do not run these scripts
>
> The data layer is **live and verified** at
> `https://trailanalyticslimited602.sharepoint.com/sites/OfficeSupplies`
> (SiteId `a309ce93-d140-4d99-b4b8-0a9080b85f29`), provisioned on 2 Sep 2026.
>
> It was **not** built with the `m365` CLI. The SharePoint domain — previously
> blocked from the browser, which is the only reason this was ever scripted for a
> human to run — became reachable, so the same CAML and the same seed values were
> posted directly through the SharePoint REST API in an authenticated browser
> session.
>
> **These scripts are now reference material, not a runbook.** They remain the
> reviewed source of truth for the CAML in `02-fields.sh` and the seed values in
> `03-seed.sh`, which is exactly what the REST calls were built from. Re-running
> them against the live site would attempt to recreate lists that already exist.
>
> What was provisioned, verified by reading it back:
>
> | | |
> |---|---|
> | Lists | 12 (`RequestDocuments` as a document library) |
> | Columns | 113, **zero** `_x0020_` encoded internal names |
> | Indexes | 24, matching the index inventory exactly |
> | Unique | `Catalogue.OfficeItemKey`, `Requests.Title` |
> | Choice columns | 13, all with verbatim values, none left on placeholders |
> | Seed rows | 62 (61 items + 1 library file) |
> | `StockLedger` | deliberately empty — see `03-seed.sh` |
> | Person columns | **all blank** — see below |
> | Site timezone | (UTC+03:00) Nairobi |
>
> **Person columns are empty by design.** The eleven UPNs in the `03-seed.sh`
> EDIT-ME block do not exist in this tenant; the only real account is Otim Samuel's.
> A Person write with an unresolvable claim fails the whole item, so seeding took
> the `SEED_PEOPLE=0` path: the shadow email **text** columns carry the addresses
> and every Person column is null. The app filters on the shadow columns by design,
> so nothing downstream breaks — but the SharePoint list UI shows blank people, and
> `User().Email` during testing resolves to Otim Samuel rather than to any seeded
> persona. Backfill the Person columns once real accounts exist.
>
> **If you ever need to rebuild from scratch**, use the REST recipe recorded in the
> plan file rather than these scripts: create the list with
> `POST _api/web/lists`, then post each `<Field/>` from `02-fields.sh` to
> `_api/web/lists/getbytitle('X')/fields/createfieldasxml` with `Options:8`
> (`AddFieldInternalNameHint` — this is what prevents `Office code` becoming
> `Office_x0020_Code`). `Indexed="TRUE"` and `EnforceUniqueValues="TRUE"` both take
> effect inline in a single call over REST, so the two-step index-then-unique
> sequence these scripts perform is unnecessary there.

---

Three scripts build the whole data layer for the Office Supplies canvas app. They
must run in order — `01` → `02` → `03` — and the order is not cosmetic: SharePoint
refuses to add an index to a list that is already over 5000 items, so every
`Indexed="TRUE"` column has to exist before a single row is seeded. Getting this
backwards is unrecoverable without recreating the list.

The schema these scripts implement is documented in [`../docs/schema.md`](../docs/schema.md).
That document is the contract; if it and these scripts ever disagree, the scripts
are wrong.

---

## Step 1 — Install CLI for Microsoft 365

```bash
npm i -g @pnp/cli-microsoft365
m365 --version
```

Check the Node version first — the package declares no `engines` field, so npm
will not warn you if the CLI needs a newer Node than you have:

```bash
node -v
```

Node 20 and CLI v11 are a verified-working pair. If `m365 --version` fails, fall
back to `npm i -g @pnp/cli-microsoft365@9`, or switch to Node 22 with nvm.

## Step 2 — Set up and sign in (interactive, you must do this yourself)

`m365 setup` creates and consents the Entra application the CLI uses. From v10 the
CLI no longer ships a default multi-tenant app, so this step is required and it
needs a Global Administrator. It cannot be automated or delegated.

```bash
m365 setup
m365 login
m365 status
```

`m365 status` must print your signed-in identity before you go any further. All
three provisioning scripts refuse to run if it does not.

## Step 3 — Create the site collection

A **dedicated** site collection — not the tenant root, and not a Teams-attached
site (a Teams-connected group site brings ownership and permissions you do not
want on a data layer).

```bash
m365 spo site add \
  --type TeamSite \
  --alias OfficeSupplies \
  --title "Office Supplies" \
  --isPublic
```

Or create it from the SharePoint admin centre. Either way the result must be
reachable at:

```
https://trailanalyticslimited602.sharepoint.com/sites/OfficeSupplies
```

If your tenant or site path differs, export `SITE_URL` before running anything:

```bash
export SITE_URL="https://<tenant>.sharepoint.com/sites/<site>"
```

## Step 4 — Run the three scripts, in order

```bash
bash provision/01-lists.sh    # 12 lists/libraries
bash provision/02-fields.sh   # every column, from CAML, indexes inline
bash provision/03-seed.sh     # the mock-up's own sample data
```

Each script echoes one line per object, so a failure is locatable. They tolerate
"already exists" rather than aborting, so a partial run can be re-run safely.

**Before running `03-seed.sh`, open it and edit the block marked `EDIT ME — people`
at the top.** The mock-up names eleven people but gives no email addresses; the
script maps them to plausible UPNs on `trailanalyticslimited602.onmicrosoft.com`.
Correct them to real accounts, or the Person-column writes will fail.

If those accounts do not exist in the tenant yet, seed without Person columns —
the app filters on the shadow email columns anyway, so the data stays usable:

```bash
SEED_PEOPLE=0 bash provision/03-seed.sh
```

---

## Why the columns are scripted and not clicked

Creating a column called "Office code" through the SharePoint web UI gives it the
internal name `Office_x0020_Code`. Power Fx then silently stops delegating filters
on it. Almost every "delegation randomly stopped working" report traces to exactly
that. Every column here is created with:

```
m365 spo field add --options AddFieldInternalNameHint --xml '<Field … Name="OfficeCode" StaticName="OfficeCode"/>'
```

which pins the internal name to clean PascalCase. Do not add columns to these
lists through the browser — add them to `02-fields.sh` and `docs/schema.md`.

Two more invariants worth knowing before you touch anything:

- **There are zero Lookup columns.** Relationships use shadow text keys
  (`RequestRefNo`, `OfficeCode`, `OfficeItemKey`, `MatrixKey`). A Lookup makes a
  column Complex, which kills `Sort` and `StartsWith` on it, and a Lookup to
  `Catalogue` would make the "Other (type it in)…" free-text line impossible.
- **Every Person column has a shadow `…Email` text column**, written in the same
  `Patch`. Filter on the shadow, never on the Person column.

## Environment variables

| Variable | Default | Used by |
|---|---|---|
| `SITE_URL` | `https://trailanalyticslimited602.sharepoint.com/sites/OfficeSupplies` | all three |
| `MAJOR_VERSION_LIMIT` | `50` | `01-lists.sh` |
| `UPN_DOMAIN` | `trailanalyticslimited602.onmicrosoft.com` | `03-seed.sh` |
| `SEED_PEOPLE` | `1` | `03-seed.sh` — set `0` to skip Person columns |
| `GFO_ARCHBOX_STOCK` | `6` | `03-seed.sh` — see the note in the script; the mock-up contradicts itself on this one figure |

## Starting over

There is no teardown script, deliberately — deleting lists is not something a
script should do on your behalf. To reset, delete the lists in the site's
Site contents and empty the recycle bin, then re-run from `01`.
