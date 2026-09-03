// ── Brand ─────────────────────────────────────────────────────────────────
clrBrand       = ColorValue("#1CABE2");   // --brand       UNICEF cyan
clrBrandDark   = ColorValue("#0F86B5");   // --brand-dark
clrBrandTint   = ColorValue("#E6F6FC");   // --brand-tint
clrFocus       = ColorValue("#1CABE2");   // --focus  (same value as --brand,
                                          //  kept separate so focus can be
                                          //  retuned without moving the brand)

// ── Fluent neutrals ───────────────────────────────────────────────────────
clrCanvas      = ColorValue("#FAF9F8");   // --canvas       page background
clrSurface     = ColorValue("#FFFFFF");   // --surface      cards, nav, topbar
clrInk         = ColorValue("#323130");   // --ink          primary text
clrInk2        = ColorValue("#605E5C");   // --ink-2        secondary text
clrInk3        = ColorValue("#8A8886");   // --ink-3        tertiary / disabled
clrLine        = ColorValue("#EDEBE9");   // --line         hairline borders
clrLineStrong  = ColorValue("#D2D0CE");   // --line-strong  input + button borders
clrOnBrand     = ColorValue("#FFFFFF");   // #fff on .btn-primary, .avatar, .dot
// --st-draft / --st-draft-bg …
clrStDraft       = ColorValue("#605E5C");  clrStDraftBg       = ColorValue("#F3F2F1");
clrStSubmitted   = ColorValue("#0078D4");  clrStSubmittedBg   = ColorValue("#EFF6FC");
clrStReviewed    = ColorValue("#8764B8");  clrStReviewedBg    = ColorValue("#F5F0FA");
clrStPartial     = ColorValue("#CA5010");  clrStPartialBg     = ColorValue("#FCF1EA");
clrStDelivered   = ColorValue("#038387");  clrStDeliveredBg   = ColorValue("#E9F5F5");
clrStReceived    = ColorValue("#107C10");  clrStReceivedBg    = ColorValue("#EDF6ED");
clrStClosed      = ColorValue("#323130");  clrStClosedBg      = ColorValue("#F3F2F1");
clrStReturned    = ColorValue("#986F0B");  clrStReturnedBg    = ColorValue("#FBF6E9");
clrStRejected    = ColorValue("#A4262C");  clrStRejectedBg    = ColorValue("#FAEEEF");
clrStockOk     = clrStReceived;   // .stock-ok    "Active"
clrStockLow    = clrStPartial;    // .stock-low   "Low stock"
clrStockOut    = clrStRejected;   // .stock-out   "Out of stock"
clrStockLend   = clrStReviewed;   // .stock-lend  borrowed from a sharing office
clrAvatar      = clrBrandDark;             // .avatar        default
clrAvatarAlt   = ColorValue("#8764B8");    // .avatar.alt
clrAvatarAlt2  = ColorValue("#038387");    // .avatar.alt2
clrAvatarAlt3  = ColorValue("#CA5010");    // .avatar.alt3

// Deterministic accent from a person's name, so the same person is always the
// same colour. Usage: Index(tblAvatarAccent, Mod(Len(ThisItem.Requester), 4) + 1).Colour
tblAvatarAccent =
Table(
    { Slot: 1, Colour: clrAvatar    },
    { Slot: 2, Colour: clrAvatarAlt },
    { Slot: 3, Colour: clrAvatarAlt2},
    { Slot: 4, Colour: clrAvatarAlt3}
);
spc2   = 2;    // .leg dot ring inset, .chip .held margin
spc4   = 4;    // .nav gap, .tile gap
spc5   = 5;    // .field gap, .btn-sm vertical padding
spc6   = 6;    // .badge icon gap, .nav-label bottom padding
spc7   = 7;    // .btn icon gap
spc8   = 8;    // .btn vertical padding, .nav item vertical padding
spc9   = 9;    // .chip gap, .leg .lbl margin-top
spc10  = 10;   // .nav item gap, .callout gap, .card-head gap
spc11  = 11;   // .btn-sm horizontal padding, .table td vertical padding
spc12  = 12;   // .nav padding, .nav-user padding
spc14  = 14;   // .topbar gap, .table cell horizontal padding, .card-head padding
spc16  = 16;   // .btn horizontal padding, .field margin-bottom, .grid-3 gap
spc18  = 18;   // .card-body padding, .tile horizontal padding
spc20  = 20;   // .grid-2 gap
spc22  = 22;   // .journey top padding, .timeline li bottom padding
spc24  = 24;   // .content top padding
spc28  = 28;   // .content horizontal padding
spc34  = 34;   // .mock-note margin-top
spc56  = 56;   // .content bottom padding

// Fixed dimensions lifted straight from the CSS
dimNavWidth    = 264;   // .shell grid-template-columns
dimContentMax  = 1180;  // .content max-width
dimAvatar      = 28;    // .avatar, .leg .dot, .t-dot
dimBrandMark   = 32;    // .brand-mark
dimGlyph       = 18;    // .nav .glyph
dimQtyBox      = 84;    // .qty input
dimRailBar     = 2;     // .leg::before / ::after connector thickness
dimActiveBar   = 3;     // .nav a[aria-current] left indicator
rad4      = 4;    // --radius : buttons, inputs, nav items, callouts, t-note
rad6      = 6;    // .card, .brand-mark
radPill   = 999;  // .badge, .chip, .persona, .card-head .count
radCircle = 14;   // 50% of dimAvatar (28) — .avatar, .leg .dot, .t-dot
// size                       weight                    where it is used
szDisplay      = 26;   // FontWeight.Bold        .tile .t-num  (KPI number)
szPageTitle    = 18;   // FontWeight.Semibold    .topbar h1
szSection      = 15;   // FontWeight.Semibold    .brand-name, .brand-mark (Bold)
szCardTitle    = 14.5; // FontWeight.Semibold    .card-head h2
szBody         = 14;   // FontWeight.Normal      body base
szControl      = 13.5; // Semibold on .btn and .tab-list label,
                       // Normal on .input / .select / textarea
szTable        = 13;   // FontWeight.Normal      .table td
                       // also .leg .dot (Bold) and .t-title (Semibold)
szLabel        = 12.5; // Semibold on .field label and .chip .who;
                       // Normal on .ref, .tile .t-cap, .callout, .t-note,
                       // .btn-sm, .nav-user .who
szBadge        = 12;   // FontWeight.Semibold    .badge, .leg .lbl, .stock-*
                       // Normal on .t-dot glyph
szCaption      = 11.5; // Semibold on .table th, .card-head .count, .tile .t-flag
                       // Normal on .persona, .field .hint, .t-meta, .mock-note
szMicro        = 11;   // Bold on .avatar; Semibold on .nav-label, .chip .held
                       // Normal on .leg .sub, .brand-name small, .chip small
// styles.css --font is "Segoe UI Variable Text", "Segoe UI", system-ui.
// VERIFIED present in this environment's Font list. Accept the loss of the
// Variable Text optical sizing.
fntUI   = Font.'Segoe UI';
// styles.css --mono is "Cascadia Code", Consolas, "Courier New".
// VERIFIED: the Font list has no Cascadia and no Consolas; Courier New is the
// only monospace offered. Used only by the .ref reference number.
fntMono = Font.'Courier New';

// The full list this environment offers, confirmed in Studio: Arial, Courier New,
// Dancing Script, Georgia, Great Vibes, Lato, Lato Black, Lato Hairline, Lato
// Light, Open Sans, Open Sans Condensed, Patrick Hand, Segoe UI, Verdana.
//
// WARNING: Studio's default for a newly inserted Label or Button is Open Sans,
// NOT Segoe UI. Every text control Phase 3 writes must set Font: =fntUI
// explicitly. Omit it and the control silently renders in Open Sans, which is a
// visibly different face from the mock-up.
// Rank values are the plan's StatusRank table, verbatim. Requests.StatusRank is
// written in the same Patch as Requests.Status; this table is what supplies the
// number. Open = Rank < 70.
tblStatus =
Table(
    { StatusText: "Draft",            Rank: 10, Fg: clrStDraft,     Bg: clrStDraftBg,     Glyph: "✎", StockLike: false },
    { StatusText: "Returned",         Rank: 15, Fg: clrStReturned,  Bg: clrStReturnedBg,  Glyph: "↩", StockLike: false },
    { StatusText: "Submitted",        Rank: 20, Fg: clrStSubmitted, Bg: clrStSubmittedBg, Glyph: "●", StockLike: false },
    { StatusText: "Reviewed",         Rank: 30, Fg: clrStReviewed,  Bg: clrStReviewedBg,  Glyph: "◆", StockLike: false },
    { StatusText: "Partial delivery", Rank: 40, Fg: clrStPartial,   Bg: clrStPartialBg,   Glyph: "◐", StockLike: false },
    { StatusText: "Fully delivered",  Rank: 50, Fg: clrStDelivered, Bg: clrStDeliveredBg, Glyph: "▣", StockLike: false },
    { StatusText: "Fully received",   Rank: 60, Fg: clrStReceived,  Bg: clrStReceivedBg,  Glyph: "✓", StockLike: false },
    { StatusText: "Closed",           Rank: 70, Fg: clrStClosed,    Bg: clrStClosedBg,    Glyph: "■", StockLike: false },
    { StatusText: "Rejected",         Rank: 90, Fg: clrStRejected,  Bg: clrStRejectedBg,  Glyph: "✕", StockLike: false }
);

// Fallback record, so a status typed into SharePoint that this table does not
// know about renders as neutral text rather than blowing up the gallery.
recStatusFallback =
    { StatusText: "", Rank: 0, Fg: clrInk2, Bg: clrStDraftBg, Glyph: "•", StockLike: false };

// Catalogue badge states (admin.html). Derived, never stored — see schema.md §3.
tblStockState =
Table(
    { StateText: "Active",       Fg: clrStockOk,   Bg: clrStReceivedBg, Glyph: "✓" },
    { StateText: "Low stock",    Fg: clrStockLow,  Bg: clrStPartialBg,  Glyph: "⚠" },
    { StateText: "Out of stock", Fg: clrStockOut,  Bg: clrStRejectedBg, Glyph: "✕" },
    { StateText: "Discontinued", Fg: clrStClosed,  Bg: clrStClosedBg,   Glyph: "■" }
);
// Verbatim from request-detail.html lines 81-109, in order.
// StageCode matches ApprovalMatrix.StageCode / Requests.CurrentStageCode /
// RequestTimeline.StageCode (5 Choice values). "Submitted" is the requester's own
// act and has NO StageCode and NO matrix row — that is why there are 6 legs and
// 5 stage codes.
//
// The skip rule is the ABSENCE of a matrix row: a leg is skipped iff no active
// row exists in colMatrix for the request's MatrixKey + this StageCode.
tblJourney =
Table(
    { Leg: 1, LegLabel: "Submitted",       StageCode: "",         ActorLabel: "Requester",           Skippable: false },
    { Leg: 2, LegLabel: "Review",          StageCode: "Review",   ActorLabel: "Reviewer",            Skippable: true  },
    { Leg: 3, LegLabel: "Approval",        StageCode: "Approval", ActorLabel: "Finance approval",    Skippable: true  },
    { Leg: 4, LegLabel: "Confirm",         StageCode: "Confirm",  ActorLabel: "Chief Field Office",  Skippable: true  },
    { Leg: 5, LegLabel: "Deliver",         StageCode: "Deliver",  ActorLabel: "Storekeeper",         Skippable: true  },
    { Leg: 6, LegLabel: "Receive & close", StageCode: "Receive",  ActorLabel: "Requester",           Skippable: true  }
);

// The copy the mock-up puts under a struck-through leg.
txtLegSkipped = "not required in this office";