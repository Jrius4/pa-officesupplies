# SharePoint schema — Office Supplies

Site: `https://trailanalyticslimited602.sharepoint.com/sites/OfficeSupplies`

This is the definitive data-layer contract for the Power Apps canvas app. It is
implemented verbatim by `provision/01-lists.sh`, `provision/02-fields.sh` and
`provision/03-seed.sh`. If this document and those scripts ever disagree, the
scripts are wrong.

---

## Rules that hold across every list

1. **Internal names are clean PascalCase, no spaces.** Every column is created
   through `m365 spo field add --options AddFieldInternalNameHint --xml '<Field …/>'`
   with `Name` and `StaticName` both set. Creating a column called "Office code"
   in the web UI would give it the internal name `Office_x0020_Code`; almost every
   "delegation randomly stopped working" report traces to exactly that. Display
   names may contain spaces; internal names never do.
2. **Zero Lookup columns anywhere in the design.** Relationships are carried by
   shadow text keys — `RequestRefNo`, `OfficeCode`, `OfficeItemKey`, `MatrixKey`.
   Lookups make a column Complex (killing `Sort` and `StartsWith` on it), hit the
   per-view lookup cap, throw on over-threshold lists, and — decisively — a Lookup
   to `Catalogue` would make the "Other (type it in)…" free-text line impossible.
3. **Every Person column has a shadow `…Email` single-line-of-text column**,
   written in the same `Patch`. Filter only on the shadow (deterministic index use
   above 5000 items); the Person column earns its keep for the list UI and future
   flows.
4. **Indexes are declared inline at column-creation time** (`Indexed="TRUE"` in the
   CAML). SharePoint refuses to add an index to a list already over 5000 items, so
   the provisioning order is strictly `01-lists.sh` → `02-fields.sh` → `03-seed.sh`.
   Getting this backwards is unrecoverable without recreating the list.
5. **Uniqueness** is `EnforceUniqueValues="TRUE"`, which requires `Indexed="TRUE"`
   on the same column. Two columns carry it: `Requests.Title` and
   `Catalogue.OfficeItemKey`.
6. **Multiple-lines-of-text columns are plain text**: `RichText="FALSE"`,
   `AppendOnly="FALSE"`. Rich text and append-only versioning both break Power Fx
   round-tripping.
7. **Number columns are `Decimals="0"`** unless they are currency, which is
   `Type="Currency" Decimals="2"`.
8. **`RequestDocuments` is a document library** (`--baseTemplate DocumentLibrary`),
   not a list with attachments — attachments cannot be queried across items.
   Attachments are disabled on every other list.
9. **`Title`** is the SharePoint built-in and cannot be created with `spo field add`.
   Where a list uses it as a real key it is reconfigured afterwards with
   `m365 spo field set --internalName Title …` (display name, `Required`, `Indexed`,
   `EnforceUniqueValues`). Where a list has no natural use for it, it still exists
   and is required by SharePoint, so it carries a human-readable label.

### CAML shapes used

| Kind | Shape |
|---|---|
| Text | `<Field Type="Text" DisplayName="Office code" Name="OfficeCode" StaticName="OfficeCode" Required="TRUE" Indexed="TRUE" MaxLength="255"/>` |
| Number | `<Field Type="Number" DisplayName="Status rank" Name="StatusRank" StaticName="StatusRank" Required="TRUE" Indexed="TRUE" Decimals="0" Min="0"/>` |
| Currency | `<Field Type="Currency" DisplayName="Unit cost" Name="UnitCost" StaticName="UnitCost" Decimals="2"/>` |
| Choice | `<Field Type="Choice" DisplayName="Movement" Name="MovementType" StaticName="MovementType" Required="TRUE" Indexed="TRUE" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Receipt</CHOICE>…</CHOICES></Field>` |
| Person | `<Field Type="User" DisplayName="Currently with" Name="CurrentlyWith" StaticName="CurrentlyWith" UserSelectionMode="PeopleOnly" UserSelectionScope="0" Mult="FALSE" ShowField="ImnName"/>` |
| Yes/No | `<Field Type="Boolean" DisplayName="Active" Name="IsActive" StaticName="IsActive"><Default>1</Default></Field>` |
| DateTime | `<Field Type="DateTime" DisplayName="Submitted on" Name="SubmittedOn" StaticName="SubmittedOn" Indexed="TRUE" Format="DateTime"/>` |
| Multi-line | `<Field Type="Note" DisplayName="Return reason" Name="ReturnReason" StaticName="ReturnReason" NumLines="4" RichText="FALSE" AppendOnly="FALSE"/>` |

---

## 1. Offices

Base template `GenericList`. Versioning on. Attachments off.

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Office code | Single line of text (built-in) | Yes | Yes | The office code. `JCO`, `BOR`, `MAL`, `BEN`, `WAU`. Reconfigured with `spo field set`. |
| `OfficeName` | Office name | Single line of text | Yes | No | `Juba Country Office`, `Bor Zonal Office`, `Malakal Zonal Office`, `Bentiu Zonal Office`, `Wau Zonal Office` |
| `OfficeType` | Office type | Choice | Yes | No | `Headquarters`, `Zonal office`, `Field office` — `Headquarters` and `Field office` verbatim from `admin.html` tab 3; `Zonal office` added for UNICEF South Sudan (see the judgement-call note below) |
| `Country` | Country | Single line of text | No | No | Not stated in the mock-up; seeded `South Sudan` |
| `IsActive` | Active | Yes/No | No | No | Default `1` |

## 2. OfficeSharing

Base template `GenericList`. Versioning on. Attachments off.

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Sharing link | Single line of text (built-in) | Yes | No | Human label, e.g. `JCO → BOR` |
| `FromOfficeCode` | From office code | Single line of text | Yes | No | The primary office that **lends** |
| `ToOfficeCode` | To office code | Single line of text | Yes | No | The secondary office that **borrows** |
| `SharePriority` | Share priority | Number (0 dp) | Yes | No | `Min="1"`. Lower number wins when several offices can lend. |
| `IsActive` | Active | Yes/No | No | No | Default `1` |

## 3. Catalogue

Base template `GenericList`. Versioning on. Attachments off.

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Item name | Single line of text (built-in) | Yes | No | Verbatim item name, e.g. `A4 photocopy paper (ream)` |
| `ItemCode` | Item code | Single line of text | Yes | No | Stable per-item code, unique **within** an office |
| `OfficeCode` | Office code | Single line of text | Yes | **Yes** | |
| `OfficeItemKey` | Office item key | Single line of text | Yes | **Yes — unique** | `EnforceUniqueValues="TRUE"`. Composed `<OfficeCode>\|<ItemCode>`, e.g. `BOR\|A4PAPER` |
| `Category` | Category | Single line of text | No | No | The mock-up states no categories — free text rather than an invented Choice |
| `UnitOfMeasure` | Unit of measure | Single line of text | No | No | `Ream`, `Box of 10`, `Pack of 5`, `Each`, `Pad`, `Cartridge`, `Box of 50` |
| `StockQty` | Stock quantity | Number (0 dp) | Yes | No | `Min="0"`. A **cache** — the ledger is truth. |
| `ReorderLevel` | Low-stock threshold | Number (0 dp) | No | No | `Min="0"`. Blank = no threshold (the mock-up shows `—` for Fax toner). |
| `UnitCost` | Unit cost | Currency (2 dp) | No | No | Not stated in the mock-up; left blank |
| `RowVersion` | Row version | Number (0 dp) | No | No | `Min="0"`. Bumped on every stock write for optimistic concurrency. |
| `IsActive` | Active | Yes/No | No | No | Default `1`. `FALSE` = the mock-up's **Discontinued** badge. |

**Derived, never stored:** the mock-up's four catalogue badges. `Discontinued` when
`IsActive = false`; `Out of stock` when `StockQty = 0`; `Low stock` when
`StockQty <= ReorderLevel`; otherwise `Active`.

**Not modelled:** the mock-up's "Added by" column maps to SharePoint's built-in
`Author` (Created By), which cannot be set at seed time and will show the account
that runs `03-seed.sh`.

## 4. StockLedger

Base template `GenericList`. Append-only by convention (nothing in the app updates
or deletes a row). **This list will exceed 5000 items** — every index below matters.
Versioning on. Attachments off.

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Entry | Single line of text (built-in) | Yes | No | Label, e.g. `BOR\|A4PAPER 2026-07-13` |
| `OfficeItemKey` | Office item key | Single line of text | Yes | **Yes** | |
| `OfficeCode` | Office code | Single line of text | Yes | **Yes** | |
| `ItemCode` | Item code | Single line of text | Yes | No | |
| `MovementType` | Movement | Choice | Yes | **Yes** | `Receipt`, `Distribution`, `Adjustment`, `Transfer in`, `Transfer out`, `Return` |
| `QtyDelta` | Quantity delta | Number (0 dp) | Yes | No | **Signed** — no `Min`. Negative for a distribution. |
| `BalanceAfter` | Balance after | Number (0 dp) | Yes | No | `Min="0"`. Computed before the `Catalogue` patch. |
| `RequestRefNo` | Request reference | Single line of text | No | **Yes** | Blank for a manual adjustment |
| `MovedOn` | Moved on | Date and time | Yes | **Yes** | |
| `MovedByEmail` | Moved by (email) | Single line of text | Yes | No | Shadow of `MovedBy` |
| `MovedBy` | Moved by | Person | No | No | |
| `Notes` | Notes | Multiple lines of text | No | No | Plain text, 4 lines |

## 5. ApprovalMatrix

Base template `GenericList`. Versioning on (matrix changes are audited). Attachments off.

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Step | Single line of text (built-in) | Yes | No | Label, e.g. `BOR · Review` |
| `OfficeCode` | Office code | Single line of text | Yes | No | |
| `Section` | Section scope | Single line of text | Yes | No | A section name, or the literal `All sections` for an office-wide row. Text, not Choice, precisely so `All sections` is expressible. |
| `MatrixKey` | Matrix key | Single line of text | Yes | **Yes** | `<OfficeCode>\|<Section>`, e.g. `BOR\|All sections` |
| `StageCode` | Stage code | Choice | Yes | No | `Review`, `Approval`, `Confirm`, `Deliver`, `Receive` |
| `StageOrder` | Step | Number (0 dp) | Yes | No | `Min="1"`. The step number the admin screen shows. |
| `ActorRoleCode` | Acts as | Choice | Yes | No | `Requester`, `Reviewer`, `Chief Field Office`, `Storekeeper`, `Administrator` |
| `ApproverEmail` | Approver (email) | Single line of text | No | No | Shadow of `Approver`. Blank on the `Receive` row, which routes to the originator. |
| `Approver` | Approver | Person | No | No | |
| `OICEmail` | OIC (email) | Single line of text | No | No | Shadow of `OIC` |
| `OIC` | Officer in charge | Person | No | No | |
| `IsActive` | Active | Yes/No | No | No | Default `1` |

**Resolution at runtime.** The app computes `MatrixKey = OfficeCode & "|" & Section`
and falls back to `OfficeCode & "|All sections"` — both are `MatrixKey = x`, so both
delegate. A section-scoped row overrides an office-wide row for the same stage.

## 6. Requests

Base template `GenericList`. Versioning on. Attachments off (documents live in
`RequestDocuments`).

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Reference | Single line of text (built-in) | Yes | **Yes — unique** | `EnforceUniqueValues="TRUE"`. `SR-YYYYMM-NNNN`. SharePoint enforces uniqueness; the app only retries. |
| `OfficeCode` | Office code | Single line of text | Yes | **Yes** | |
| `Section` | Section | Choice | Yes | No | `Programme`, `Child Protection`, `Health & Nutrition`, `Operations`, `Supply & Logistics` |
| `RequesterEmail` | Requester (email) | Single line of text | Yes | **Yes** | Shadow of `Requester`. Drives "My requests". |
| `Requester` | Requester | Person | No | No | |
| `CurrentlyWithEmail` | Currently with (email) | Single line of text | No | **Yes** | Shadow of `CurrentlyWith`. Drives "Awaiting my action". |
| `CurrentlyWith` | Currently with | Person | No | No | |
| `CurrentlyWithOICEmail` | Currently with OIC (email) | Single line of text | No | **Yes** | The OIC standing in for `CurrentlyWith`. No Person twin — it is a filter key only. |
| `Status` | Status | Choice | Yes | No | `Draft`, `Returned`, `Submitted`, `Reviewed`, `Partial delivery`, `Fully delivered`, `Fully received`, `Closed`, `Rejected` — verbatim, in this order |
| `StatusRank` | Status rank | Number (0 dp) | Yes | **Yes** | `Min="0"`. See the mapping table below. Written in the same `Patch` as `Status`. |
| `CurrentStageCode` | Current stage | Choice | No | No | `Review`, `Approval`, `Confirm`, `Deliver`, `Receive` |
| `Purpose` | Purpose | Choice | Yes | No | `Internal`, `External` — verbatim from `new-request.html` |
| `SubmittedOn` | Submitted on | Date and time | No | **Yes** | Blank while `Draft` |
| `ClosedOn` | Closed on | Date and time | No | No | Stamped by the auto-close path |
| `LineCount` | Line count | Number (0 dp) | Yes | No | `Min="0"` |
| `TotalQtyRequested` | Total requested | Number (0 dp) | No | No | `Min="0"` |
| `TotalQtyApproved` | Total approved | Number (0 dp) | No | No | `Min="0"` |
| `TotalQtyDistributed` | Total distributed | Number (0 dp) | No | No | `Min="0"` |
| `TotalQtyReceived` | Total received | Number (0 dp) | No | No | `Min="0"` |
| `SharingOfficeCode` | Sharing office code | Single line of text | No | No | Stamped when any line was sourced from a lending office |
| `ReturnReason` | Return reason | Multiple lines of text | No | No | Plain text. Return is blocked on an empty reason. |
| `RejectReason` | Reject reason | Multiple lines of text | No | No | Plain text. Reject is blocked on an empty reason. |

`LineCount` and the four `TotalQty*` columns are **load-bearing, not convenience**.
Without them the Home gallery needs a `CountRows`/`Sum` per row, which is both
non-delegable and N+1.

## 7. RequestItems

Base template `GenericList`. The largest list in the design. Versioning on.
Attachments off.

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Line | Single line of text (built-in) | Yes | No | Label, e.g. `SR-202607-0038-01` |
| `RequestRefNo` | Request reference | Single line of text | Yes | **Yes** | |
| `OfficeCode` | Office code | Single line of text | Yes | No | The requesting office |
| `LineNo` | Line no. | Number (0 dp) | Yes | No | `Min="1"` |
| `ItemCode` | Item code | Single line of text | No | No | Blank on a free-text line |
| `ItemName` | Item name | Single line of text | Yes | No | **Snapshot** at line creation |
| `IsCatalogueItem` | Catalogue item | Yes/No | No | No | Default `1`. `FALSE` for the "Other (type it in)…" line. |
| `OfficeItemKey` | Office item key | Single line of text | No | No | Blank on a free-text line |
| `UnitOfMeasure` | Unit of measure | Single line of text | No | No | **Snapshot** at line creation |
| `UnitCost` | Unit cost | Currency (2 dp) | No | No | **Snapshot** at line creation |
| `LinePurpose` | Purpose | Single line of text | No | No | `Training workshop`, `Section office`, `Monitoring visits` |
| `QtyRequested` | Requested | Number (0 dp) | Yes | No | `Min="0"` |
| `QtyApproved` | Approved | Number (0 dp) | No | No | `Min="0"`. Set on the Review screen. |
| `QtyDistributed` | Distributed | Number (0 dp) | No | No | `Min="0"` |
| `QtyReceived` | Received | Number (0 dp) | No | No | `Min="0"` |
| `SourceOfficeCode` | Source office code | Single line of text | No | No | Stamped when the line is filled from a lending office (`JCO` for the flipchart pads) |
| `LineStatus` | Line status | Choice | No | No | `Pending`, `Partially distributed`, `Fully distributed`, `Partially received`, `Fully received`, `Cancelled` |
| `ReceiptCondition` | Receipt condition | Choice | No | No | `Complete`, `Short`, `Damaged`, `Not received` |
| `LineNote` | Line note | Multiple lines of text | No | No | Plain text |

**Why the snapshot.** A requisition must record what was requested *at the time*,
not what the catalogue says today after a rename or reprice. It also makes the
free-text line a normal row rather than a special case.

## 8. RequestComments

Base template `GenericList`. Versioning on. Attachments off.

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Comment | Single line of text (built-in) | Yes | No | Label, e.g. `SR-202607-0038` |
| `RequestRefNo` | Request reference | Single line of text | Yes | **Yes** | |
| `CommentText` | Comment | Multiple lines of text | Yes | No | Plain text, 4 lines |
| `AuthorEmail` | Author (email) | Single line of text | Yes | No | Shadow of `CommentAuthor` |
| `CommentAuthor` | Author | Person | No | No | **Named `CommentAuthor`, not `Author`** — `Author` is the reserved internal name of SharePoint's built-in Created By field and cannot be created. |
| `PostedOn` | Posted on | Date and time | Yes | **Yes** | |

## 9. RequestTimeline

Base template `GenericList`. Append-only by convention. Versioning on. Attachments off.

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Event | Single line of text (built-in) | Yes | No | The headline the timeline renders, e.g. `Request submitted` |
| `RequestRefNo` | Request reference | Single line of text | Yes | **Yes** | |
| `EventType` | Event type | Choice | Yes | No | `Draft created`, `Submitted`, `Routed`, `Reviewed`, `Returned`, `Rejected`, `Confirmed`, `Distributed`, `Received`, `Closed`, `Comment added`, `Reassigned`, `Stock adjusted` |
| `FromStatus` | From status | Single line of text | No | No | Text, not Choice — blank at draft creation and never filtered on |
| `ToStatus` | To status | Single line of text | No | No | |
| `StageCode` | Stage code | Choice | No | No | `Review`, `Approval`, `Confirm`, `Deliver`, `Receive` |
| `ActorEmail` | Actor (email) | Single line of text | No | No | Shadow of `Actor`. Blank for a system event. |
| `Actor` | Actor | Person | No | No | |
| `OccurredOn` | Occurred on | Date and time | Yes | **Yes** | |
| `Detail` | Detail | Multiple lines of text | No | No | Plain text, 4 lines |

## 10. RequestDocuments

**Base template `DocumentLibrary`** — a library, not a list with attachments,
because attachments cannot be queried across items. Versioning on, major versions only.

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Title | Single line of text (built-in) | No | No | Optional in a library; `FileLeafRef` is the real name |
| `RequestRefNo` | Request reference | Single line of text | Yes | **Yes** | |
| `DocType` | Document type | Choice | Yes | No | `Request PDF`, `Delivery note`, `Receipt note`, `Supporting document` |
| `UploadedByEmail` | Uploaded by (email) | Single line of text | No | No | |

## 11. AppRoles

Base template `GenericList`. Versioning on. Attachments off.

Not in the mock-up's implied model, but required: the screens gate on role, and one
person holds several — Deng Machar is both **Reviewer** and **Requester**.

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Person | Single line of text (built-in) | Yes | No | Display name, e.g. `Deng Machar` |
| `UserEmail` | User email | Single line of text | Yes | **Yes** | |
| `OfficeCode` | Office code | Single line of text | Yes | No | |
| `RoleCode` | Role | Choice | Yes | No | `Requester`, `Reviewer`, `Chief Field Office`, `Storekeeper`, `Administrator` |
| `IsActive` | Active | Yes/No | No | No | Default `1` |

## 12. RefCounter

Base template `GenericList`. Versioning on. Attachments off.

| Internal name | Display name | SharePoint type | Required | Indexed | Notes / verbatim choice values |
|---|---|---|---|---|---|
| `Title` | Period | Single line of text (built-in) | Yes | Yes | `YYYYMM`, e.g. `202607`. Indexed so the per-mint lookup is deterministic. |
| `LastSeq` | Last sequence | Number (0 dp) | Yes | No | `Min="0"`. The highest `NNNN` minted in that month. |

Reference numbering restarts each month, as the mock-up shows (`SR-202606-0114` in
June, then `SR-202607-0029` in July). Implementation: `Patch` the `RefCounter` row
for `YYYYMM`, read back `LastSeq + 1`, mint the reference, and rely on
`EnforceUniqueValues` on `Requests.Title` plus an `IfError` retry loop capped at 5
attempts.

---

## StatusRank

`<>` on Text does not delegate to SharePoint and `Not` never delegates, so
`Status <> "Closed"` is poison. Every workflow query is a *range* query, so status
carries a shadow number written in the same `Patch`.

| Status (verbatim, Choice) | StatusRank |
|---|---|
| Draft | 10 |
| Returned | 15 |
| Submitted | 20 |
| Reviewed | 30 |
| Partial delivery | 40 |
| Fully delivered | 50 |
| Fully received | 60 |
| Closed | 70 |
| Rejected | 90 |

**Open = `StatusRank < 70`.** Never `Sort` by `Status` — sorting a Choice column is
not delegable under any circumstances.

---

## StageCode

Five choice values, used by `ApprovalMatrix.StageCode`, `Requests.CurrentStageCode`
and `RequestTimeline.StageCode`:

| StageCode | The actor stage it names |
|---|---|
| `Review` | Reviewer |
| `Approval` | Finance approval |
| `Confirm` | Chief Field Office |
| `Deliver` | Storekeeper |
| `Receive` | Requester (originator) |

The six journey legs the rail renders are, verbatim from `request-detail.html`:

`Submitted` → `Review` → `Approval` → `Confirm` → `Deliver` → `Receive & close`

`Submitted` is the requester's own act and needs no matrix row, which is why there
are five `StageCode` values for six legs. So **`ApprovalMatrix` holds up to five
rows per office + section**.

**The skip rule is the absence of a row.** A stage is skipped iff no active matrix
row exists for that `MatrixKey` + `StageCode`. No sentinel rows, no `IsSkipped`
flag. Bor has four rows and no `Approval` row — which is exactly why
`admin.html` shows four steps and the rail strikes `Approval` through. The rail
renders by left-joining the six canonical stages against the collected matrix rows;
a skipped leg uses the Label `Strikethrough` property, not a separate control.

**The matrix's displayed `Stage` string is derived, never stored.** `admin.html`
shows `SUBMIT → Review`, `REVIEW → Confirm`, `CONFIRM → Distribute`,
`DISTRIBUTE → Receipt`. That label is built at render time from
`<previous active stage> → <this stage>`. That is precisely what makes the chain
reconfigurable: add an `Approval` row and step 2's label becomes `REVIEW → Approval`
with no code change. Storing it would freeze the chain.

---

## Delegation contract

Five queries, verified against the SharePoint connector's delegation table. The
app-build phase copies these verbatim.

| Query | Formula |
|---|---|
| Awaiting my action | `Filter(Requests, StatusRank < 70, Or(CurrentlyWithEmail = User().Email, CurrentlyWithOICEmail = User().Email))` |
| My requests | `SortByColumns(Filter(Requests, RequesterEmail = User().Email), "SubmittedOn", SortOrder.Descending)` |
| Lines for a request | `Filter(RequestItems, RequestRefNo = varRef)` |
| Catalogue for an office | `Filter(Catalogue, OfficeCode = varOffice, IsActive = true)` |
| Item picker search | `Filter(Catalogue, OfficeCode = varOffice, StartsWith(ItemName, cbo.SearchText))` — use `StartsWith`, **never** `Search()` |

### The rules those queries rest on

- `Person.Email = X` **is** delegable (only `Email` and `DisplayName` are).
- `Choice.Value = X` **is** delegable; `Sort` on Choice is **not**.
- `<>` on Text, `Not`, `IsBlank`, `Sum`, `CountRows` — **not** delegable.
- SharePoint `ID` delegates `=` only; there is no `ID >` paging.
- `And`/`Or` of delegable expressions **are** delegable.

### Reports

**Reports cannot aggregate server-side.** Bound the set with a delegable filter
(office + date range) into a collection, aggregate locally with `GroupBy`/`Sum`,
and display the row count so a truncated aggregate is never presented as a KPI.

---

## Index inventory

Every column below carries `Indexed="TRUE"` at creation time. SharePoint allows 20
indexes per list; the busiest list here uses seven.

| List | Indexed columns |
|---|---|
| Offices | `Title` |
| OfficeSharing | — |
| Catalogue | `OfficeCode`, `OfficeItemKey` (unique) |
| StockLedger | `OfficeItemKey`, `OfficeCode`, `MovementType`, `RequestRefNo`, `MovedOn` |
| ApprovalMatrix | `MatrixKey` |
| Requests | `Title` (unique), `OfficeCode`, `RequesterEmail`, `CurrentlyWithEmail`, `CurrentlyWithOICEmail`, `StatusRank`, `SubmittedOn` |
| RequestItems | `RequestRefNo` |
| RequestComments | `RequestRefNo`, `PostedOn` |
| RequestTimeline | `RequestRefNo`, `OccurredOn` |
| RequestDocuments | `RequestRefNo` |
| AppRoles | `UserEmail` |
| RefCounter | `Title` |

---

## Departures from the plan's column list, and why

Four columns exist here that the plan's "Lists (12)" shape does not name. Each is
recorded so the review can accept or reject it individually.

| List | Column | Why |
|---|---|---|
| `Offices` | `OfficeType` | `admin.html` tab 3 shows a **Type** column with the values `Headquarters` and `Field office`. Without it that table cannot be rendered. **Judgement call:** `Zonal office` is added as a third value because UNICEF South Sudan runs zone offices (Bentiu, Bor, Malakal, Wau) between the country office and its field offices, per the UNICEF OIAI audit of the South Sudan Country Office (Dec 2018). No current public list exists. |
| `ApprovalMatrix` | `ActorRoleCode` | `admin.html` tab 1's **Acts** column, and specifically step 4 — `Requester (originator)`, which has no named approver and no OIC. Without the role code there is no way to know that row routes to the request's originator rather than to a named person. |
| `RequestItems` | `UnitCost` | The plan's "Denormalise the catalogue snapshot onto the line" section states that `RequestItems` carries `ItemName`, `UnitOfMeasure` **and `UnitCost`** copied at line creation; its abbreviated column list omits it. Prose wins. |
| `RequestComments` | `CommentAuthor` (renamed) | The plan names this Person column `Author`. `Author` is a reserved SharePoint internal name (Created By) and `spo field add` will refuse it. The shadow stays `AuthorEmail` as planned. |

Two indexes exist beyond the ones the plan marks:

| List | Column | Why |
|---|---|---|
| `StockLedger` | `MovementType` | This list is stated to exceed 5000 items, and reconciliation filters it by movement type. An index cannot be added later once it is over threshold. |
| `RefCounter` | `Title` | It is the only lookup key on the list and every reference mint reads it. |

One column the plan names is deliberately absent: there is **no `CurrentlyWithOIC`
Person column** on `Requests`. The plan lists `CurrentlyWithOICEmail` only, and that
column exists purely as a delegable filter key for the "Awaiting my action" query.
