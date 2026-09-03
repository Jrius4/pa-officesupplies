# Designing screens in Power Apps Studio (web) — a hands-on guide

This is a how-to for building the Office Supplies screens **yourself**, by hand,
in Power Apps Studio at `make.powerapps.com` — no `.pa.yaml`, no paste-code, no
browser automation. Keep the live mock-up open at `http://127.0.0.1:5500/` in one
tab and Studio in another; you'll go back and forth between them constantly.

It assumes `App.Formulas` and `App.OnStart` are already typed into the app (see
[`app-glue.md`](app-glue.md) Sections 1–2) and the 8 data sources are connected
(Section 3). Once those exist, every colour, spacing value, font and status
lookup in this app has a **name** — `clrBrand`, `spc12`, `dimNavWidth`, `szBody`,
`tblStatus`, etc. — that you type straight into a property's formula bar. Design
here means *referencing those names*, never picking a colour from a swatcher or
typing a raw hex code or magic pixel number. That's what keeps 8 screens
visually identical without 8 separate design decisions.

---

## 1. Orient yourself in Studio

Open `make.powerapps.com` → **Apps** → **Office Supplies** → **Edit**. That opens
Studio in the browser. Four areas matter:

| Area | Where | What it's for |
|---|---|---|
| **Tree view** | far left | The screen/control hierarchy. Click a control here to select it — often more reliable than clicking it on the canvas, especially once controls overlap. |
| **Insert** | top ribbon | Where every new control comes from — Layout, Icons, Input, Display, Media, Charts, etc. |
| **Properties pane + fx bar** | right side / just above the canvas | The dropdown on the left of the fx bar picks *which* property you're editing (`Fill`, `X`, `Text`, …); the bar itself is a full Power Fx formula editor — this is where token names go. |
| **Preview** | ▷ icon top-right, or F5 | Runs the screen live, real fonts and sizes, no publish needed. Judge your work here, not off the design canvas. |

Two panes you'll dip into less often but need for this app specifically:

- **Data** (left rail) — confirms the 12 SharePoint lists/library are connected
  and shows their columns, useful when you forget an internal name.
- **View → Collections / Variables** — while Previewing, shows what
  `colAwaiting`, `colMyRoles`, `varOffice` etc. actually hold. Handy when a
  gallery renders empty and you need to know whether the data or the layout is
  the problem.

---

## 2. The per-screen workflow

Repeat this for each of the 8 screens (`scrHome`, `scrNewRequest`, `scrReview`,
`scrDistribute`, `scrReceipt`, `scrRequestDetail`, `scrAdmin`, `scrReports` — see
`app-glue.md` §4 for the exact name-to-mock-up mapping).

**Step 0 — look before you build.** Open the matching page at
`127.0.0.1:5500/<page>.html`. Identify its regions: fixed left nav, fixed
topbar, then a stack of cards/sections in the content area. Everything in this
app is pixel-positioned to match `styles.css`, so you're not guessing at a
layout — you're transcribing one.

**Step 1 — block out the two fixed regions first.**
Nav (`Width: =dimNavWidth`, full height, `Fill: =clrSurface`) and topbar
(`Height` matching `.topbar` in the CSS, `Fill: =clrSurface`, bottom border via
a 1px Rectangle in `clrLine`). Get these placed and locked before touching
content — every other measurement on the screen is relative to them.

**Step 2 — the content region.** A bounding area capped at
`Width: =dimContentMax` (1180), horizontally centred under the nav, with
`spc28` side padding and `spc24` top padding — copy these straight off
`app-glue.md` §1.5.

**Step 3 — one card/section at a time, top to bottom.** For each one:
label(s) for the heading, a Rectangle or two for structure, then whatever
repeating content it holds (see the control-mapping table in §4 below).
Don't try to build a whole screen's content in one pass — finish one card,
Preview it, then move to the next.

**Step 4 — reference tokens, never raw values.** Every `Fill`, `Color`,
`Size`, `Font` should be a name from `App.Formulas`, not a literal. Positions
should chain off siblings where possible —
`Y: =lblCardTitle.Y + lblCardTitle.Height + spc10` — rather than a magic
number, exactly like the idiom in `oracle/NOTES.md` #10. That's what makes a
later spacing tweak a one-line change instead of a screen-by-screen hunt.

**Step 5 — Preview against the mock-up.** Switch tabs, compare. Zoom both to
the same level if pixel alignment matters (it does, for this app).

**Step 6 — save often.** Don't wait for the whole screen to be "done" before
saving.

---

## 3. Build the nav + topbar shell once, reuse it 8 times

The left nav and topbar are pixel-identical across all 8 screens except for
which nav item is highlighted, the `<h1>` text, and the persona line. Don't
rebuild this from scratch 8 times. Two ways to reuse it, in order of
recommendation:

1. **Make it a Component.** `Insert → Components → New component` (or a
   Component Library if you want it shared across apps later). Give it input
   properties — e.g. `ActiveNavItem` (Text), `PageTitle` (Text), `PersonaText`
   (Text) — and drive the highlighted nav row and the topbar `<h1>`/persona
   label off those inputs. Build it once on `scrHome`, then drop one instance
   on each of the other 7 screens and just set its three inputs per screen.
   One edit to the component (say, a new nav item) then ripples everywhere —
   which matches this app's own philosophy elsewhere (role/matrix data is
   "administered rarely" and centralised for the same reason).
2. **Copy/paste the control group.** Select the nav + topbar containers in
   the tree view, `Cmd+C`, switch screens, `Cmd+V`. Faster to get started,
   but every future tweak means editing it in 8 places. Fine if you're still
   iterating on the shell's look and don't want to lock in a component API
   yet — switch to the component once the shell design has settled.

---

## 4. Mock-up pattern → Studio control

This app has already been through one full screen build (`scrHome`, via a
different route — YAML paste), and the control types below are **confirmed
against this tenant's Studio**, not guessed. Use them as-is; a wrong control
name/prefix is a common source of "why doesn't this look right."

| In the mock-up (`styles.css` / HTML) | Use in Studio | Notes |
|---|---|---|
| `<aside class="nav">` background | `Rectangle` | Plain rectangle, no radius needed. |
| Anything **rounded** — `.card`, `.badge`, `.chip`, `.avatar`, the brand mark, status pills | `Button` **under the Classic/ category**, styled as a static shape | **`Rectangle` has no corner-radius property at all** — confirmed, not a Studio bug. For a rounded shape, insert a Button, set `Text: =""`, neutralise `HoverFill`/`PressedFill`/`HoverBorderColor`/`PressedBorderColor` to `=Self.Fill` / `=Self.BorderColor` so it doesn't visibly react to hover/press, then set the four `Radius*` properties. |
| `<table>` rows (Home's "Awaiting my action", "My requests"; any list) | A blank **vertical Gallery**, `Items` bound to a collection (e.g. `colAwaiting`) | Lay out each "column" as a Label positioned at a fixed `X` inside the gallery template — that's how a CSS `<table>` becomes a canvas gallery. |
| `<select>` | `Dropdown`, **under Classic/**, capital D | `Classic/Dropdown` (lowercase d) does not exist as a type — double-check the tree view shows `Classic/DropDown`. |
| The item-picker search box (type-ahead) | `ComboBox`, under Classic/ | |
| `<input type="text">`, `<textarea>` | `TextInput`, under Classic/ | Set `Mode: TextMode.MultiLine` for a textarea equivalent. |
| Nav/status glyphs (`⌂ ＋ ☰ ✓ …`) | A Label with the literal Unicode character | Matches the mock-up's `<span class="glyph">` exactly. Fall back to `Icon` (Classic/, via the `Icon.*` enum) only if a specific glyph renders as a box in this environment — `◐` and `▣` are the two flagged as risky. |
| `<img>` (logo, avatar photo) | `Image` | |

**Font — set it explicitly, every time.** A newly inserted Label or Button
defaults to *Open Sans* in this environment, not the `fntUI` (Segoe UI) this
app uses everywhere. Every text control needs `Font: =fntUI` (or `=fntMono`
for the one monospaced reference number) set by hand, or it will silently
mismatch the mock-up.

**No `gap`, no flexbox.** Canvas controls don't have CSS's `gap`. That's
exactly why `app-glue.md` §1.5 predefines `spc4` … `spc56` — use them as
explicit `X`/`Y` offsets and `Height`/`Width` padding between siblings.

**No letter-spacing.** The mock-up's tracked-out uppercase labels (table
headers, nav-group labels) have no canvas equivalent. Wrap the text in
`Upper(...)` and accept the slightly tighter default tracking — that's the
documented trade-off, not a missed setting.

---

## 5. Checking your work

- Trust **Preview** (▷ / F5), not the design-time canvas, for how text
  actually renders — the design canvas sometimes shows a control's bounding
  box more literally than a user will ever see it.
- Keep the mock-up tab at the same browser zoom as Studio's Preview when you
  want to eyeball pixel alignment.
- If a gallery renders empty, check **View → Collections** first (is
  `colAwaiting` actually populated?) before assuming the layout is wrong —
  `App.OnStart` has to have run once (Studio does this automatically on
  Preview) for these collections to exist.

---

## 6. Screen-by-screen worked examples

The sections below walk one real screen at a time, region by region, with the
exact `styles.css` values translated into the tokens from `app-glue.md` §1.
New screens get appended here as you ask about them — the methodology in §§1–5
above doesn't change, this is just it applied.

### 6.1 `scrNewRequest` — New / Edit request

One screen serves **two** flows: creating a brand-new draft, and editing a
`Returned` request to resubmit it (Home's "Edit" button on a returned row
opens this same screen, per `index.html`). Build the New-request layout first
— everything below — then read §6.1.5 for the small set of things to leave
room for so Edit mode doesn't force a redesign later.

Worth knowing before you start: **every measurement on this screen already
has a name** in `app-glue.md` §1 — you won't need to invent a single new
token for it.

#### 6.1.1 Topbar (this screen's variant)

Home's topbar is one h1 + one primary button. This one has five things in a
row: a back arrow, the h1, a status pill, a persona pill, and *two* buttons.
Because the right-hand content differs per screen, build the topbar bespoke
on each screen (reuse the **nav** as a component per §3, but not the topbar)
— it's cheap, and every piece below is still driven by shared tokens so it
stays visually consistent.

Left to right, all vertically centred in the topbar band:

| Control | Type | Key properties |
|---|---|---|
| Topbar background | `Rectangle` | `X: =dimNavWidth`, `Width: =Parent.Width - dimNavWidth`, `Fill: =clrSurface`; a second 1px `Rectangle` in `clrLine` along the bottom edge. |
| Back arrow | `Label`, text `"←"` | `Size: =16` (this one's set inline in the mock-up, not off the type scale), `Color: =clrInk`, `X: =dimNavWidth + spc28`. |
| Page title | `Label`, text `"New request"` | `Font: =fntUI`, `Size: =szPageTitle` (18), `FontWeight: =FontWeight.Semibold`. |
| Status pill | `Button` (Classic/, styled as a shape — it's rounded) | `Text: ="✎ Draft"`, `Fill: =clrStDraftBg`, `Color: =clrStDraft`, `Size: =szBadge` (12), `FontWeight: =FontWeight.Semibold`, radius `=radPill`. |
| Persona pill | Same trick | `Text: ="Viewing as: Requester"`, `Fill: =clrCanvas`, `BorderColor: =clrLineStrong`, `Color: =clrInk2`, `Size: =szCaption` (11.5), radius `=radPill`. |
| **Save draft** button | `Button` (Classic/) | Neutral style: `Fill: =clrSurface`, `BorderColor: =clrLineStrong`, `Color: =clrInk`, `Font: =fntUI`, `Size: =szControl` (13.5), `FontWeight: =FontWeight.Semibold`. Right-align it: `X: =btnSubmit.X - Self.Width - spc14` (topbar's own item gap). |
| **Submit request** button | `Button` (Classic/) | Primary style: `Fill: =clrBrand`, `BorderColor: =clrBrand`, `Color: =clrOnBrand`. Right edge pinned: `X: =Parent.Width - Self.Width - spc28`. |

Give everything else in the row `X` formulas chained off the previous
control's `X + Width + spc14`, the same left-to-right idiom as the nav.

#### 6.1.2 "Request details" card

This is the first card in the content area — a heading bar, then a 3-column
field grid.

- **Card shape.** Rounded (`rad6`), so it's the `Button`-as-shape trick again:
  `Fill: =clrSurface`, `BorderColor: =clrLine`, `BorderThickness: =1`.
- **Card head band.** `Height` sized to its content plus `spc14` top/bottom
  padding; a bottom-edge `Rectangle` in `clrLine`. Title label: `Font: =fntUI`,
  `Size: =szCardTitle` (14.5), `FontWeight: =FontWeight.Semibold`, positioned
  `spc18` from the card's left edge (card-head horizontal padding matches
  card-body's).
- **Card body.** Everything below the head band inset by `spc18` on every
  side.
- **The 3-column grid.** With the body's usable width as `w`, each column is
  `(w - 2*spc16) / 3` wide, and column *i* (0, 1, 2) starts at
  `spc18 + i * (colWidth + spc16)` from the card's left edge — that `spc16`
  is the grid's own gap. This grid-math pattern (equal columns, `spc16` or
  `spc20` gap) recurs elsewhere in this app (Home's KPI tiles, Admin's
  tables), so it's worth internalising once here.
- **Each field**, top to bottom inside its column:
  - Label (e.g. "Office"): `Size: =szLabel` (12.5), `FontWeight: =FontWeight.Semibold`.
  - Dropdown, `spc5` below the label (the CSS `.field` gap): `Classic/DropDown`,
    `Font: =fntUI`, `Size: =szControl` (13.5), `BorderColor: =clrLineStrong`,
    horizontal padding `spc10`, vertical `spc8` (these are the `.input`/`.select`
    padding values, and both already have tokens).
  - Optional hint text below the dropdown (Office's field has one — "Defaulted
    from your profile"): `Size: =szCaption` (11.5), normal weight, `Color: =clrInk2`.
  - **The required-field asterisk on Purpose** needs two adjacent Labels, not
    one — canvas Labels can't mix two text colours in one string. Put
    `"Purpose "` in the normal label and a second small Label right after it
    for `"*"` in `Color: =clrStRejected`.
  - Leave `spc16` clearance below the field before the next row starts (the
    CSS `.field` bottom margin) — moot here since it's one row of three, but
    it's the number to reach for the moment this card grows a second row.

#### 6.1.3 "Items" card — the line-items table

The trickiest region, because rows are added/removed by the user and one row
(the free-text "Other" line) renders differently from the rest.

**Header band:** "Items" title, a count pill (`Fill: =clrBrandTint`,
`Color: =clrBrandDark`, `Size: =szCaption`, `FontWeight: =FontWeight.Semibold`,
radius `=radPill` — same rounded-shape trick), then a right-aligned
`btn-sm`-style "＋ Add item" button (smaller padding than the topbar buttons:
horizontal `spc11`, vertical `spc5`).

**Column header row**, styled like the mock-up's `<table><thead>`: five
Labels — Product, Purpose, Quantity (right-aligned), Notes, and a blank one
over the remove-button column — each `Upper(...)`'d (no letter-spacing in
canvas, see §4), `Size: =szCaption` (11.5), `FontWeight: =FontWeight.Semibold`,
`Color: =clrInk2`, sitting on a `clrCanvas` band with a `clrLine` bottom edge.
Widths: Product gets 38% of the table's width (verbatim from the mock-up's
`width:38%`); split the rest across Purpose/Notes, except Quantity, which is
a fixed `dimQtyBox` (84 — this token exists *specifically* for this column).

**The row itself — build one Gallery template:**

- **Product cell.** Two controls stacked in the same space, only one
  `Visible` at a time per row: a `Classic/ComboBox` (the catalogue picker, for
  a normal line) and a `Classic/TextInput` (free text, for the "Other (type
  it in)…" line — row 3 in the mock-up, which also carries a small hint label
  underneath: *"Not in the catalogue — entered as free text"*, `Size: =szCaption`,
  `Color: =clrInk2`). Which one shows will key off a per-line flag once this
  is wired to data — for now, build both controls in place so the layout is
  ready.
- **Purpose cell.** `Classic/TextInput`.
- **Quantity cell.** `Classic/TextInput`, `Width: =dimQtyBox`, right-aligned
  text, numeric.
- **Notes cell.** `Classic/TextInput` with its `HintText` property set to
  `"Optional"` (canvas's equivalent of the mock-up's placeholder text).
- **Remove button.** Small, quiet, text-only `Classic/Button`: `Text: ="✕"`,
  `Color: =clrStRejected`, no fill/border — the "danger-quiet" style.
- A `clrLine` bottom edge under the template closes out each row, matching
  `.table td { border-bottom: 1px solid var(--line) }`.

**While you're still designing** (before this is wired to a real collection),
point the Gallery's `Items` at a small static `Table(...)` of two or three
sample rows so you can see real layout and try the catalogue-vs-free-text
Visible toggle by hand. Swap it for the live collection later — that's a data
question, not a design one.

#### 6.1.4 The info callout

Sits between the Items card and the bottom of the page.

- Two overlapping rectangles: a wide one behind for the tint fill
  (`Fill: =clrBrandTint`, `BorderColor: =clrLine`, `BorderThickness: =1`,
  corner radius `=rad4` if you route it through the Button trick, or square
  corners if you decide this one doesn't need rounding — the mock-up's radius
  here is small enough that either reads fine), and a narrow `Width: =3`
  accent strip in `clrBrand` along the left edge (there's no named token for
  this exact 3px value — not every measurement in the mock-up has one, and
  that's fine).
- An "ℹ" glyph Label, then the body text at `Size: =szLabel` (12.5).
  "Daniel Otieno" is bold in the mock-up — same two-Labels-side-by-side
  technique as the Purpose asterisk, since there's no rich-text run inside a
  single canvas Label.
- `spc14` clearance above and below the whole callout.

#### 6.1.5 Designing so "Edit request" mode fits later

There's no second screen to build — Home's "Edit" action on a `Returned`
request reopens this exact layout, pre-filled. Nothing here needs building
now, but two things are worth deciding while the layout is fresh rather than
retrofitting later:

- **Leave room for a second callout**, styled with the `.callout.warn`
  variant (`clrStPartial`/`clrStPartialBg` instead of the brand colours),
  directly under the "Request details" card, to surface the reviewer's return
  reason. It doesn't exist in the New-request state — a blank draft has
  nothing to show there — so build it now with `Visible: =false` (or just
  leave the space and add the control when you get to that flow) rather than
  squeezing it in between two already-placed cards later.
- **Don't hardcode "Draft" onto the status pill's `Text`/colours.** Build it
  so the string and the `clrSt*`/`clrSt*Bg` pair are easy to swap for
  `"Returned"` / `clrStReturned` / `clrStReturnedBg` — same control, just
  driven by whichever mode the screen is in. Same idea for the h1: "New
  request" vs "Edit request" is a text swap on the same Label, not a
  different control.

Everything else — the field grid, the item gallery, both footer buttons — is
pixel-identical between the two modes. That's the point of it being one
screen.

---

## 7. Where this leaves the rest of the repo

`docs/schema.md`, `app-glue.md` and `oracle/NOTES.md` stay the reference for
the data model, design tokens and Studio's quirks — keep them open alongside
this guide rather than duplicating their content into Studio's own comments
(Studio strips comments on any code round-trip anyway).

If, after hand-building a screen, you want the repo's `powerapps/screens/*.pa.yaml`
to mirror what you built (purely optional — only relevant if you want a
version-controlled copy of the screen): select the screen in the tree view →
**…** → **View code** → **Copy code**, then `pbpaste > powerapps/screens/scrX.pa.yaml`
in a terminal. That's a one-way export; the file is downstream of Studio, never
the other way around — canvas apps can't be packed from a file and imported,
so this repo copy is documentation of what's in Studio, not a source Studio
reads from. Not needed at all for the manual-build workflow this guide
describes; it only matters if you want the change history.
