# Format oracle — what Studio actually emits

Captured from Power Apps Studio, this tenant, 2 Sep 2026. Everything here is
observed, not inferred from documentation. `01-baseline.pa.yaml` is the verbatim
capture.

## 1. The envelope is `Screens:`, not `Children:`

The plan said each screen file would hold "that screen's `Children:` tree". That is
wrong and a paste built that way would be rejected. The real shape is:

```yaml
Screens:
  <ScreenName>:
    Properties:
      <ScreenProp>: =<expr>
    Children:
      - <ControlName>:
          Control: <Type>@<version>
          Properties:
            <Prop>: =<expr>
```

`Children` is a YAML **sequence** of single-key mappings (`- Name:`), not a mapping.

## 2. Control types are version-pinned, and some are namespaced

Observed exactly:

| Control | Type string |
|---|---|
| Label | `Label@2.5.1` |
| Rectangle | `Rectangle@2.3.0` |
| Button | `Classic/Button@2.2.0` |

**Button lives under `Classic/`.** Writing `Button@2.2.0` is not the same control.
Never invent a version number — an unknown `@version` is a rejected paste. Every
type used in Phase 3 must first be observed in a capture here.

## 3. Every property value is `=`-prefixed

`X: =40`, not `X: 40`. This matches the v3.0 schema's `^=.*` rule. Percentage
literals are valid inside expressions: `=ColorFade(Self.Fill, -15%)`.

## 4. `ZIndex` does not appear

Confirmed absent. Order within `Children` is z-order, ascending — later siblings
paint on top. Phase 3 must order containers and overlays deliberately.

## 5. The default font is `Open Sans`, NOT Segoe UI

Studio emitted `Font: =Font.'Open Sans'` on both the Label and the Button.
`app-glue.md` §1.7 specifies `fntUI = Font.'Segoe UI'` to match `styles.css`.

**RESOLVED — the token stands.** The Font dropdown on a Label in this environment
offers, in full: Arial, Courier New, Dancing Script, Georgia, Great Vibes, Lato,
Lato Black, Lato Hairline, Lato Light, **Open Sans**, Open Sans Condensed,
Patrick Hand, **Segoe UI**, Verdana.

So `Font.'Segoe UI'` is available and `app-glue.md` §1.7 needs no change — Open Sans
is merely Studio's default for newly inserted controls, not a constraint. Because it
IS the default, every Label and Button written in Phase 3 must set `Font` explicitly;
omitting it silently yields Open Sans.

`Font.'Courier New'` is also confirmed present, settling the monospace token for the
`.ref` reference number. There is no Cascadia and no Consolas, as expected.

## 6. Only non-default properties are serialised — but "default" is theme-relative

The Label emitted just `BorderColor`, `Font`, `X`, `Y`. The Button emitted thirteen
properties, because the Classic Button carries an explicit colour set. Do not expect
a property you set to survive a round trip if it happens to equal the theme default;
conversely, do not strip properties from a capture on the assumption they are noise.

## 7. `Variant:` is a real key, and it sits BESIDE `Control:`

Not in the plan, and easy to miss:

```yaml
- Gallery1:
    Control: Gallery@2.15.0
    Variant: BrowseLayout_Vertical_TwoTextOneImageVariant_ver5.0
    Properties: ...
    Children: ...
```

A Gallery pasted without its `Variant` is not the same control. Capture the
variant string for every control that has one.

## 8. Two different paste units

- **View code on a SCREEN** emits the `Screens:` wrapper (oracle 01). That is what
  a whole-screen paste needs.
- **View code on a CONTROL** emits a bare sequence item — the document literally
  begins `- Gallery1:` with no wrapper (oracle 02). That is the unit for pasting a
  subtree into an existing screen, which is also the per-container fallback the plan
  names for when a full-screen paste is rejected.

Phase 3 must emit the right one for the intended paste target.

## 9. Control types confirmed so far

| Control | Type string | Source |
|---|---|---|
| Label | `Label@2.5.1` | oracle 01, 02 |
| Rectangle | `Rectangle@2.3.0` | oracle 01, 02 |
| Button | `Classic/Button@2.2.0` | oracle 01 |
| Gallery | `Gallery@2.15.0` + `Variant:` | oracle 02 |
| Image | `Image@2.2.3` | oracle 02 |
| Icon | `Classic/Icon@2.5.0`, glyph via `Icon: =Icon.ChevronRight` | oracle 02 |
| Dropdown | `Classic/DropDown@2.3.1` — **capital D** | oracle 03 |
| ComboBox | `Classic/ComboBox@2.4.0` | oracle 03 |
| Text input | `Classic/TextInput@2.3.2` | oracle 03 |

`Classic/Icon` settles the `app-glue.md` §1.9 fallback: if the Unicode status
glyphs do not render, the Icon-enum Switch is available on a real control type.

## 10. Useful idioms lifted from the default gallery

- `OnSelect: =Select(Parent)` on every child, so a click anywhere in the row
  selects the row. Phase 3's request rows need this.
- Vertical centring: `Y: =(Parent.TemplateHeight / 2) - (Self.Height / 2)`.
- Right-alignment: `X: =Parent.TemplateWidth - Self.Width - 12`.
- Selection bar: a Rectangle with `Visible: =ThisItem.IsSelected`, `Width: =4`.
- Relative stacking: `Y: =Title1.Y + Title1.Height` — this is how the mock-up's
  stacked cells should be positioned rather than with magic numbers.
- Text sizing: `Height: =Self.Size * 1.8` ties a label's box to its font size.

## 11. The oracle is complete — every control the rebuild needs is captured

Nine types, all observed. Nothing left to guess.

Note the split: `Label`, `Rectangle`, `Gallery` and `Image` are modern controls with
bare names; `Button`, `Icon`, `DropDown`, `ComboBox` and `TextInput` all live under
**`Classic/`**. Getting that prefix wrong is a rejected paste. So is the casing —
it is `Classic/DropDown`, with a capital D, not `Classic/Dropdown`.

## 12. A property path can appear as a key

`Dropdown1` emitted `Items.Value: =Value`. Dotted property paths are legal YAML keys
here, not just bare property names. Do not "correct" one to a nested mapping.

## 13. Inserting controls in Studio — the working procedure

The Insert flyout is inside Studio's iframe, so `find` and `read_page` cannot see it
and it is pixel-clicking only. What works:

1. Click **Insert**, then take a screenshot **in the same batch**. The screenshot is
   what gives the flyout time to render, and it confirms the item coordinates.
2. Click the item in a **separate tool call**. Clicking in the same batch, even after
   a `wait`, silently does nothing.
3. After the control lands, clicking **Insert** again in a batch re-opens the flyout
   with the expanded category still expanded — so several controls can be added with
   one call each.

Do not click into the flyout's search box: if the flyout has closed, the click lands
on the canvas and the subsequent typing goes into the **formula bar**, corrupting the
selected control's property. (That happened once; the control was deleted and
re-inserted.)

---

# PASTE PROVEN — what the first successful screen delivery taught us

`scrHome` was authored, rejected once, fixed, pasted successfully, and copied back
out. 84 controls survived the round trip intact. Everything below is observed.

## 14. The delivery mechanism is a native Cmd+V, NOT the "Paste" menu item

The tree-view context menu's **Paste** reads Studio's *internal* clipboard (what a
previous in-Studio **Copy** put there). Invoking it with YAML on the system clipboard
does **nothing at all** — no paste, no error, no feedback. That silence is a trap: it
looks like the format was rejected when in fact Studio never saw the text.

What works: select the target screen in the tree view, then press **Cmd+V** (Ctrl+V on
Windows). A native paste event hands the clipboard to the page directly.

This matters because `navigator.permissions.query({name:'clipboard-read'})` on
`make.powerapps.com` reports **`prompt`**, not `granted` — Studio cannot read the
system clipboard on its own, and Chrome's permission bubble is browser UI that page
automation cannot click. The native paste event bypasses the permission entirely.

To load the clipboard from outside the browser, on macOS: `pbcopy < file.pa.yaml`.

## 15. Paste CREATES a screen; it does not fill the selected one

The screen name comes from the `Screens:` key in the YAML, not from the paste target.
Pasting `Screens: scrHome:` while an empty screen called `scrHome` already existed
produced a second screen, **`scrHome_1`**, holding all the controls.

**So: do not pre-create the screen.** Paste onto any existing screen and let Studio
create the named one, then delete the placeholder. (Or paste, delete the empty
original, and rename `X_1` back to `X` — which is what was done here.)

## 16. `Rectangle@2.3.0` has NO corner-radius properties

The first paste failed with 36 instances of:

```
(60,13) : error PA2108 : Unknown property 'RadiusBottomLeft' for control type 'Rectangle@2.3.0'.
```

`RadiusTopLeft` / `RadiusTopRight` / `RadiusBottomLeft` / `RadiusBottomRight` do not
exist on Rectangle. The radius example in oracle 02 was on `Image@2.2.3`, a different
control — do not generalise a property from one control to another.

**`Classic/Button@2.2.0` does accept all four**, confirmed by the error list stopping
at line 1294 (the last Rectangle radius line) while the Button radius lines at
1371-1374 went unreported, and by the successful second paste.

**The workaround, and it is a good one:** anything that needs rounded corners — cards,
status pills, avatars, the brand mark — is a `Classic/Button` styled as a static
shape:

```yaml
Control: Classic/Button@2.2.0
Properties:
  Text: =""
  HoverFill: =Self.Fill
  PressedFill: =Self.Fill
  HoverBorderColor: =Self.BorderColor
  PressedBorderColor: =Self.BorderColor
  OnSelect: =Select(Parent)     # inside a gallery template; =false elsewhere
  RadiusTopLeft: =rad6          # etc.
```

Neutralising Hover/Pressed against `Self` is what stops it behaving like a button.
Plain Rectangles remain correct for square things: backgrounds, 1px rules, nav bars,
the active-state indicator.

## 17. The error dialog is precise — and readable if you resize it

Errors come as `(line,col) : error PA#### : message`, against the line numbers of the
pasted text. Validation is all-or-nothing but reports **every** error at once, so one
failed paste enumerates the whole problem set.

The Details box is a resizable `<textarea>`: it ignores the mouse wheel, but dragging
the grip at its bottom-right corner enlarges it, and dragging its internal scrollbar
moves it. Read to the end — the last line before the "Note:" block is the final error.

## 18. Round-tripping out of Studio: "Copy code" + `pbpaste`

The Code dialog cannot be scrolled reliably or scripted (it lives in Studio's iframe,
invisible to the accessibility tree). But its **Copy code** button writes to the system
clipboard, which a shell can read with `pbpaste`. That is the extraction path, and it
is exact.

## 19. What Studio normalises on the way in

- **Comments are stripped.** Keep the authored, commented version if you want it, but
  the repo copy is Studio's.
- **Properties are alphabetised** within each control. Authoring order is not kept.
- **Preserved exactly:** `Variant:` on galleries, `Radius*` on Buttons, multi-line
  block scalars (`OnVisible: |`), `Self.` references, and the full `Children` z-order.
- Control count in = control count out (84 here).

## 20. Still to fix on scrHome (found at runtime, not by the parser)

1. **`Filter(Catalogue, …, StockQty <= ReorderLevel)` is a column-to-column comparison.**
   SharePoint cannot express it server-side; it produced *"Fetching items failed.
   Possible invalid string in filter query."* Bound the set with a delegable filter and
   compare the two columns locally instead.
2. The requester column renders a raw email, because Person columns were seeded blank
   by design. Display the local-part, or backfill Person columns.
3. `User().Email` is Otim Samuel's and matches no seeded row, so "Viewing as" shows
   *No role* and the role-gated counts read 0.
