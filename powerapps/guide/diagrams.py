"""
The guide's diagrams, drawn as SVG so they stay sharp in the PDF. build.py calls write_all(img_dir).

Colours are the app's own tokens from App.Formulas.fx, so the diagrams look like the screens.
"""

import html
import os

BRAND, BRAND_DARK, BRAND_TINT = '#1CABE2', '#0F86B5', '#E6F6FC'
INK, INK2, INK3 = '#323130', '#605E5C', '#8A8886'
LINE, LINE_STRONG, CANVAS, SURFACE = '#EDEBE9', '#D2D0CE', '#FAF9F8', '#FFFFFF'
OK, OK_BG = '#107C10', '#EDF6ED'
WARN, WARN_BG = '#CA5010', '#FCF1EA'
BAD, BAD_BG = '#A4262C', '#FAEEEF'
LEND, LEND_BG = '#8764B8', '#F5F0FA'
FONT = 'Segoe UI, -apple-system, Helvetica, Arial, sans-serif'
MONO = 'Menlo, Consolas, monospace'


def esc(t):
    return html.escape(str(t), quote=True)


def wrap(text, width, size):
    """Greedy word wrap by an average glyph width; good enough for labels."""
    per = max(4, int(width / (size * 0.53)))
    lines, cur = [], ''
    for word in str(text).split():
        if cur and len(cur) + 1 + len(word) > per:
            lines.append(cur)
            cur = word
        else:
            cur = (cur + ' ' + word).strip()
    if cur:
        lines.append(cur)
    return lines or ['']


class Svg:
    def __init__(self, w, h):
        self.w, self.h, self.parts = w, h, []

    def add(self, s):
        self.parts.append(s)

    def rect(self, x, y, w, h, fill=SURFACE, stroke=LINE_STRONG, r=6, dash=None, sw=1.2):
        d = f' stroke-dasharray="{dash}"' if dash else ''
        self.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')

    def text(self, x, y, t, size=13, color=INK, weight=400, anchor='start', mono=False, italic=False, strike=False):
        deco = ' text-decoration="line-through"' if strike else ''
        st = ' font-style="italic"' if italic else ''
        self.add(f'<text x="{x}" y="{y}" font-family="{MONO if mono else FONT}" font-size="{size}" fill="{color}" '
                 f'font-weight="{weight}" text-anchor="{anchor}"{st}{deco}>{esc(t)}</text>')

    def para(self, x, y, t, width, size=12, color=INK2, anchor='start', weight=400, lh=1.32, mono=False):
        lines = wrap(t, width, size)
        for i, ln in enumerate(lines):
            self.text(x, y + i * size * lh, ln, size, color, weight, anchor, mono)
        return len(lines) * size * lh

    def line(self, x1, y1, x2, y2, color=INK3, sw=1.4, dash=None, arrow=False):
        d = f' stroke-dasharray="{dash}"' if dash else ''
        m = ' marker-end="url(#arr)"' if arrow else ''
        self.add(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{sw}"{d}{m}/>')

    def path(self, d, color=INK3, sw=1.4, dash=None, arrow=False, fill='none'):
        da = f' stroke-dasharray="{dash}"' if dash else ''
        m = ' marker-end="url(#arr)"' if arrow else ''
        self.add(f'<path d="{d}" fill="{fill}" stroke="{color}" stroke-width="{sw}"{da}{m}/>')

    def circle(self, cx, cy, r, fill, stroke, dash=None, sw=2):
        d = f' stroke-dasharray="{dash}"' if dash else ''
        self.add(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')

    def render(self):
        defs = (f'<defs><marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
                f'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{INK3}"/></marker></defs>')
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" width="{self.w}" '
                f'height="{self.h}">{defs}<rect width="100%" height="100%" fill="{SURFACE}"/>' + ''.join(self.parts) + '</svg>')


# ── The journey ─────────────────────────────────────────────────────────────

def journey():
    s = Svg(1000, 330)
    legs = [('Submitted', 'Requester', 'done'), ('Review', 'Reviewer', 'now'), ('Approval', 'Finance approval', 'skip'),
            ('Confirm', 'Chief Field Office', 'todo'), ('Deliver', 'Storekeeper', 'todo'),
            ('Receive & close', 'Requester', 'todo')]
    xs = [90 + i * 164 for i in range(6)]
    y = 80
    for i in range(5):
        s.line(xs[i] + 22, y, xs[i + 1] - 22, y, BRAND if i == 0 else LINE_STRONG, 3,
               dash='6 5' if legs[i + 1][2] == 'skip' or legs[i][2] == 'skip' else None)
    for i, (lbl, who, st) in enumerate(legs):
        if st == 'done':
            s.circle(xs[i], y, 20, BRAND, BRAND)
            s.text(xs[i], y + 5, '✓', 16, SURFACE, 700, 'middle')
        elif st == 'now':
            s.circle(xs[i], y, 20, SURFACE, BRAND, sw=3)
            s.text(xs[i], y + 5, '●', 14, BRAND_DARK, 700, 'middle')
        elif st == 'skip':
            s.circle(xs[i], y, 20, CANVAS, LINE_STRONG, dash='4 3')
            s.text(xs[i], y + 5, '–', 16, INK3, 700, 'middle')
        else:
            s.circle(xs[i], y, 20, SURFACE, LINE_STRONG)
            s.text(xs[i], y + 5, str(i + 1), 14, INK3, 600, 'middle')
        s.text(xs[i], y + 46, lbl, 14, INK3 if st in ('skip', 'todo') else INK, 600, 'middle', strike=st == 'skip')
        s.text(xs[i], y + 66, 'skipped: no matrix row' if st == 'skip' else who, 12, INK2, 400, 'middle', italic=st == 'skip')
    s.text(30, 30, 'Every request: six legs, five stage codes. A stage with no active ApprovalMatrix row is skipped.', 13, INK2)
    # Return / reject
    s.rect(220, 190, 360, 54, WARN_BG, WARN)
    s.text(236, 212, 'Return (Review, Approval or Confirm)', 13, WARN, 600)
    s.text(236, 232, 'goes back to the requester as Returned; they edit and resubmit', 12, INK2)
    s.path(f'M {xs[1]} 150 L {xs[1]} 190', WARN, 1.6, arrow=True)
    s.rect(600, 190, 230, 54, BAD_BG, BAD)
    s.text(616, 212, 'Reject', 13, BAD, 600)
    s.text(616, 232, 'ends the request as Rejected', 12, INK2)
    s.path(f'M {xs[3]} 150 L {xs[3]} 190', BAD, 1.6, arrow=True)
    s.rect(640, 262, 330, 54, LEND_BG, LEND)
    s.text(656, 284, 'Partial delivery', 13, LEND, 600)
    s.text(656, 304, 'stays at Deliver until everything approved is out', 12, INK2)
    s.path(f'M {xs[4]} 150 L {xs[4]} 262', LEND, 1.6, arrow=True)
    s.text(30, 300, 'Status ranks: Draft 10 · Returned 15 · Submitted 20 · Reviewed 30 · Partial 40', 12, INK2)
    s.text(30, 318, 'Fully delivered 50 · Fully received 60 · Closed 70 · Rejected 90.   Open = rank below 70.', 12, INK2)
    return s.render()


# ── SPFx → Canvas ──────────────────────────────────────────────────────────

def architecture():
    rows = [
        ('src/domain/*.ts', 'business rules: status, stages, routing, stock', 'App.Formulas + Recipes R1–R6', 'tblStatus, tblJourney, tblStageAction; app-glue §7'),
        ('src/hooks/use*Action.ts', 'the write sequences', 'Button OnSelect formulas', 'app-glue §8–§15 (chapter 13)'),
        ('src/hooks/useSessionData.ts', 'offices, matrix, sharing, my roles', 'App.OnStart', 'colOffices, colMatrix, colSharing, colMyRoles'),
        ('src/data/sharepoint/*', 'PnPjs filters, delegable', 'Screen OnVisible / loaders', 'the same filters, in Power Fx'),
        ('src/features/*Page.tsx', 'the eight pages', 'scrHome … scrReports', 'nine screens (adds scrWorkQueue)'),
        ('src/shell/AppShell.tsx', 'menu and top bar', 'The copied frame', 'three menu galleries + varNavActive'),
        ('src/app/deepLink.ts', '?req= opens a request', 'App.StartScreen + Param("req")', '&req=SR-… opens Request detail'),
        ('Web part "impersonate email"', 'testing as a persona', 'Param("as")', 'only while cfgAllowImpersonation'),
        ('PnPjs file upload', 'RequestDocuments library', 'Power Automate flow', 'UploadRequestDocument'),
    ]
    rh, top = 52, 70
    s = Svg(1000, top + len(rows) * rh + 90)
    s.text(40, 34, 'Current app: SPFx web part', 15, INK, 700)
    s.text(560, 34, 'Rebuild: Power Apps Canvas', 15, BRAND_DARK, 700)
    for i, (a, a2, b, b2) in enumerate(rows):
        y = top + i * rh
        s.rect(40, y, 400, rh - 10, CANVAS, LINE_STRONG)
        s.text(54, y + 18, a, 12.5, INK, 600, mono=True)
        s.text(54, y + 34, a2, 11.5, INK2)
        s.rect(560, y, 400, rh - 10, BRAND_TINT, BRAND)
        s.text(574, y + 18, b, 12.5, BRAND_DARK, 600)
        s.text(574, y + 34, b2, 11.5, INK2)
        s.line(445, y + (rh - 10) / 2, 555, y + (rh - 10) / 2, INK3, 1.4, arrow=True)
    y = top + len(rows) * rh + 8
    s.rect(40, y, 920, 56, OK_BG, OK)
    s.text(500, y + 24, 'The same 12 SharePoint lists, unchanged', 14, OK, 700, 'middle')
    s.text(500, y + 43, 'Offices · OfficeSharing · Catalogue · StockLedger · ApprovalMatrix · Requests · RequestItems · '
           'RequestComments · RequestTimeline · RequestDocuments · AppRoles · RefCounter', 11, INK2, 400, 'middle')
    return s.render()


# ── The lists ──────────────────────────────────────────────────────────────

def data_model():
    s = Svg(1000, 560)

    def box(x, y, w, name, cols, fill=SURFACE, stroke=LINE_STRONG):
        h = 30 + 16 * len(cols)
        s.rect(x, y, w, h, fill, stroke)
        s.text(x + 12, y + 20, name, 13.5, INK, 700)
        for i, c in enumerate(cols):
            s.text(x + 12, y + 40 + i * 16, c, 11, INK2, 400, mono=True)
        return h

    def bus(x, y1, y2, label, targets, color):
        s.line(x, y1, x, y2, color, 2.4)
        for ty in targets:
            s.line(x, ty, x + 18, ty, color, 2.4, arrow=True)
        s.add(f'<text x="{x - 8}" y="{(y1 + y2) / 2}" font-family="{FONT}" font-size="11.5" fill="{color}" '
              f'font-weight="600" text-anchor="middle" transform="rotate(-90 {x - 8} {(y1 + y2) / 2})">{esc(label)}</text>')

    s.text(30, 30, 'Lists are joined by text keys, never by Lookup columns (schema.md rule 2).', 13, INK2)
    # Request side
    box(60, 60, 270, 'Requests', ['Title = SR-YYYYMM-NNNN (unique)', 'OfficeCode, Section, Status, StatusRank',
                                   'CurrentStageCode, CurrentlyWithEmail', 'CurrentlyWithOICEmail, TotalQty*'],
        BRAND_TINT, BRAND)
    ys = [190, 270, 350, 430]
    for y, (n, c) in zip(ys, [('RequestItems', ['RequestRefNo, LineNo, OfficeItemKey', 'QtyRequested … QtyReceived']),
                              ('RequestTimeline', ['RequestRefNo, EventType, StageCode', 'OccurredOn, ActorEmail, Detail']),
                              ('RequestComments', ['RequestRefNo, CommentText', 'AuthorEmail, PostedOn']),
                              ('RequestDocuments (library)', ['RequestRefNo, DocType', 'UploadedByEmail'])]):
        box(80, y, 250, n, c)
    bus(48, 150, ys[-1] + 30, 'RequestRefNo = Requests.Title', [y + 20 for y in ys], BRAND_DARK)
    box(60, 500, 270, 'RefCounter', ['Title = YYYYMM, LastSeq'], CANVAS)
    s.text(340, 520, 'mints the next Requests.Title', 11.5, INK2)
    # Office side
    box(400, 60, 260, 'Offices', ['Title = office code (BOR)', 'OfficeName, OfficeType, IsActive'], BRAND_TINT, BRAND)
    oys = [160, 270, 370, 460]
    for y, (n, c) in zip(oys, [('ApprovalMatrix', ['MatrixKey = BOR|All sections', 'StageCode, StageOrder', 'ActorRoleCode, ApproverEmail', 'OICEmail, IsActive']),
                               ('OfficeSharing', ['FromOfficeCode (lends)', 'ToOfficeCode (borrows)', 'SharePriority, IsActive']),
                               ('AppRoles', ['UserEmail, OfficeCode', 'RoleCode, IsActive']),
                               ('Requests, RequestItems', ['OfficeCode (and SourceOfficeCode)'])]):
        box(420, y, 240, n, c, CANVAS if n.startswith('Requests,') else SURFACE)
    bus(388, 120, oys[-1] + 30, 'OfficeCode = Offices.Title', [y + 20 for y in oys], BRAND_DARK)
    # Stock side
    box(730, 60, 250, 'Catalogue', ['OfficeItemKey = BOR|A4PAPER', '(unique) Title, ItemCode', 'OfficeCode',
                                    'StockQty, ReorderLevel, RowVersion', 'IsActive'], BRAND_TINT, BRAND)
    box(750, 210, 230, 'StockLedger', ['OfficeItemKey, OfficeCode', 'MovementType, QtyDelta', 'BalanceAfter, MovedOn', 'RequestRefNo'])
    box(750, 350, 230, 'RequestItems', ['OfficeItemKey of the line'], CANVAS)
    bus(718, 150, 370, 'OfficeItemKey', [230, 370], BRAND_DARK)
    s.para(730, 440, 'Catalogue.StockQty is a cached figure. The ledger is the record: every stock move writes a ledger row '
                     'first, then the new figure.', 250, 11.5)
    return s.render()


# ── The frame ──────────────────────────────────────────────────────────────

def shell_layout():
    s = Svg(1000, 520)
    k = 0.66
    W, H = 1366 * k, 700 * k
    x0, y0 = 40, 40
    s.rect(x0, y0, W, H, CANVAS, LINE_STRONG, 4)
    s.rect(x0, y0, 264 * k, H, SURFACE, LINE_STRONG, 0)
    s.rect(x0 + 264 * k, y0, W - 264 * k, 56 * k, SURFACE, LINE_STRONG, 0)
    cx = x0 + (264 + 28) * k
    cw = min(W - (264 + 56) * k, 1180 * k)
    s.rect(cx, y0 + (56 + 24) * k, cw, 120 * k, SURFACE, LINE, 4)
    s.rect(cx, y0 + (56 + 24 + 140) * k, cw, 260 * k, SURFACE, LINE, 4)
    s.text(x0 + 132 * k, y0 + 40, 'Menu', 14, INK, 700, 'middle')
    s.text(x0 + 132 * k, y0 + 60, 'width dimNavWidth = 264', 11.5, INK2, 400, 'middle')
    for i, t in enumerate(['galNavGeneral', 'galNavQueue', 'galNavManage']):
        s.text(x0 + 16, y0 + 100 + i * 46, t, 11.5, BRAND_DARK, 600, mono=True)
    s.text(x0 + 16, y0 + H - 18, 'user block', 11.5, INK2)
    s.text(x0 + 264 * k + 16, y0 + 24, 'Top bar · height 56 · lblPageTitle · lblPersona · buttons right', 12, INK, 600)
    s.text(cx + 12, y0 + (56 + 24) * k + 22, 'Content: X = dimNavWidth + spc28', 12, INK, 600)
    s.text(cx + 12, y0 + (56 + 24) * k + 40, 'Width = Min(Parent.Width − dimNavWidth − 2·spc28, dimContentMax = 1180)', 11.5, INK2)
    s.text(cx + 12, y0 + (56 + 24) * k + 58, 'first card at Y = 56 + spc24; cards: Classic Button shape, rad6, clrLine border', 11.5, INK2)
    s.text(cx + 12, y0 + (56 + 24 + 140) * k + 22, 'Cards stack: next Y = previous.Y + previous.Height + spc20', 12, INK, 600)
    s.text(cx + 12, y0 + (56 + 24 + 140) * k + 40, 'Tables are blank vertical galleries, TemplateSize 44, one label per column', 11.5, INK2)
    s.text(40, 26, 'Scale to fit off: positions are formulas of Parent.Width and Parent.Height, not fixed pixels.', 12.5, INK2)
    return s.render()


# ── Write sequences ────────────────────────────────────────────────────────

KIND = {
    'write': (BRAND_TINT, BRAND, BRAND_DARK),
    'read': (CANVAS, LINE_STRONG, INK2),
    'check': (WARN_BG, WARN, WARN),
    'end': (OK_BG, OK, OK),
    'stop': (BAD_BG, BAD, BAD),
}


def sequence(title, lanes, steps, note=None):
    """lanes: list names across the top. steps: (lane or None, kind, op, text). Rows grow with their text."""
    lane_w, left, top = 132, 330, 64
    heights = [max(46, 16 + 14.4 * len(wrap(t, left - 70, 11.5))) for _, _, _, t in steps]
    w = left + lane_w * len(lanes) + 20
    body = sum(heights)
    h = top + body + (60 if note else 22)
    s = Svg(max(w, 760), h)
    s.text(20, 28, title, 14, INK, 700)
    for i, ln in enumerate(lanes):
        cx = left + lane_w * i + lane_w / 2
        s.rect(left + lane_w * i + 6, 40, lane_w - 12, 22, CANVAS, LINE_STRONG, 4)
        s.text(cx, 56, ln, 11.5, INK, 600, 'middle')
        s.line(cx, 62, cx, top + body, LINE, 1.2, dash='3 4')
    y = top
    for j, (lane, kind, op, text) in enumerate(steps):
        fill, stroke, color = KIND[kind]
        s.circle(32, y + 24, 12, fill, stroke, sw=1.6)
        s.text(32, y + 28.5, str(j + 1), 11.5, color, 700, 'middle')
        s.para(54, y + 20, text, left - 70, 11.5, INK, lh=1.25)
        if lane is not None:
            cx = left + lane_w * lanes.index(lane) + lane_w / 2
            s.line(left - 12, y + 24, cx - 46, y + 24, LINE_STRONG, 1.2, arrow=True)
            s.rect(cx - 44, y + 12, 88, 24, fill, stroke, 12)
            s.text(cx, y + 28.5, op, 11.5, color, 700, 'middle')
        y += heights[j]
    if note:
        s.para(20, top + body + 24, note, max(w, 760) - 40, 11.5, INK2)
    return s.render()


def seq_submit():
    return sequence('Save draft / Submit — §8', ['RefCounter', 'Requests', 'RequestItems', 'RequestTimeline'], [
        (None, 'check', '', 'Drop empty rows. Submit needs a line with quantity > 0.'),
        (None, 'read', '', 'Recipes R1 + R2: the office’s chain and the first holder.'),
        ('RefCounter', 'write', 'ensure', 'Create this month’s counter row if it is missing.'),
        ('RefCounter', 'write', 'LastSeq+1', 'Attempt: bump the counter …'),
        ('Requests', 'write', 'insert', '… and insert the header as SR-YYYYMM-NNNN. A clash on the unique Title: next attempt (5 in all).'),
        ('RequestItems', 'write', 'insert all', 'Insert every line, numbered -01, -02 …'),
        ('RequestTimeline', 'write', 'add', '"Request submitted" (or "Draft created").'),
        ('RequestTimeline', 'write', 'add', '"Routed to <stage>", with its StageCode (not for a draft).'),
        (None, 'end', '', 'Open the new request on Request detail.'),
    ])


def seq_resubmit():
    return sequence('Resubmit — §9', ['RequestItems', 'Requests', 'RequestTimeline'], [
        (None, 'check', '', 'A line with quantity > 0. Recipes R1 + R2 route it afresh.'),
        ('RequestItems', 'write', 'remove', 'Delete the request’s old lines.'),
        ('RequestItems', 'write', 'insert all', 'Insert the amended lines under the same reference.'),
        ('Requests', 'write', 'patch', 'Back to Submitted (20), new holder, totals reset, ReturnReason cleared.'),
        ('RequestTimeline', 'write', 'add', '"Request resubmitted", then "Routed to <stage>".'),
        (None, 'end', '', 'Open it on Request detail.'),
    ])


def seq_proceed():
    return sequence('Proceed at Review, Approval or Confirm — §10', ['RequestItems', 'Requests', 'RequestTimeline'], [
        (None, 'check', '', 'Holder, at a review stage, Submitted or Reviewed; a note if quantities differ (Review).'),
        (None, 'read', '', 'Recipe R2: the next live stage and its holders.'),
        ('RequestItems', 'write', 'patch each', 'Review only: QtyApproved, the source office, Pending / Cancelled.'),
        ('Requests', 'write', 'patch', 'Reviewed (30), next stage and holders; TotalQtyApproved at Review.'),
        ('RequestTimeline', 'write', 'add', '"Request reviewed / approved / confirmed", with the note.'),
        ('RequestTimeline', 'write', 'add', '"Routed to <next stage>".'),
        (None, 'end', '', 'Open it on Request detail.'),
    ], 'If any line fails to save, the header is not touched and nothing has moved on.')


def seq_return():
    return sequence('Return / Reject — §11', ['Requests', 'RequestTimeline'], [
        (None, 'check', '', 'Holder, at a review stage. A reason is required.'),
        ('Requests', 'write', 'patch', 'Return: Returned (15), back to the requester. Reject: Rejected (90), nobody. Stage cleared.'),
        ('RequestTimeline', 'write', 'add', '"Returned to requester" or "Request rejected", with the reason.'),
        (None, 'end', '', 'Back to Home.'),
    ])


def seq_distribute():
    return sequence('Record distribution — §12, for each line', ['Catalogue', 'StockLedger', 'RequestItems', 'Requests', 'RequestTimeline'], [
        ('Catalogue', 'read', 're-read', 'Read the live stock of the office supplying the line.'),
        (None, 'check', '', 'Not enough now? Record the line as failed and go to the next one.'),
        ('StockLedger', 'write', 'add', 'The ledger row first: Distribution, −qty, BalanceAfter.'),
        ('Catalogue', 'write', 'patch', 'Then the new StockQty and RowVersion + 1.'),
        ('RequestItems', 'write', 'patch', 'Then QtyDistributed and Fully / Partially distributed.'),
        (None, 'check', '', 'After every line: did at least one line move? If not, stop here.'),
        ('Requests', 'write', 'patch', 'Fully delivered (50) → Receive, to the requester; else Partial (40), stays at Deliver.'),
        ('RequestTimeline', 'write', 'add', '"Items distributed": this step and the running total.'),
        ('RequestTimeline', 'write', 'add', 'When fully delivered: "Routed to Receive".'),
    ], 'Failed lines are listed on screen and the screen reloads; lines that moved are already off the list.')


def seq_receipt():
    return sequence('Confirm receipt — §13', ['RequestItems', 'Requests', 'RequestTimeline'], [
        (None, 'check', '', 'The requester, holding it.'),
        ('RequestItems', 'write', 'patch each', 'QtyReceived, condition, Fully / Partially received, the note if not Complete.'),
        ('Requests', 'write', 'patch', 'Everything approved delivered: Closed (70), ClosedOn. Otherwise Fully received (60).'),
        ('RequestTimeline', 'write', 'add', '"Receipt confirmed": received of distributed, or the note.'),
        ('RequestTimeline', 'write', 'add', 'When closed: "Request closed".'),
        (None, 'end', '', 'Open it on Request detail.'),
    ])


def seq_rename():
    lists = ['OfficeSharing', 'Catalogue', 'StockLedger', 'ApprovalMatrix', 'Requests', 'RequestItems', 'AppRoles', 'Offices']
    steps = [(None, 'check', '', 'The new code is 2–10 capitals or digits and not used by another office.')]
    what = {
        'OfficeSharing': 'From / To codes, and the "JCO → BOR" title.',
        'Catalogue': 'OfficeCode, and the BOR| prefix of OfficeItemKey.',
        'StockLedger': 'OfficeCode, and the prefix of OfficeItemKey and Title.',
        'ApprovalMatrix': 'OfficeCode, MatrixKey and Title prefixes.',
        'Requests': 'OfficeCode and SharingOfficeCode.',
        'RequestItems': 'OfficeCode, SourceOfficeCode, OfficeItemKey prefix.',
        'AppRoles': 'OfficeCode.',
        'Offices': 'Last: the office row itself, with its other fields.',
    }
    for ln in lists:
        steps.append((ln, 'write', 'rewrite', what[ln]))
    return sequence('Renaming an office code — §15.5', lists, steps,
                    'Each list is finished before the next starts. If one fails, the rest are not touched; saving again '
                    'carries on, because rows already renamed no longer match the old code.')


def flow_upload():
    s = Svg(1000, 470)

    def node(x, y, w, h, title, sub, kind='read'):
        fill, stroke, color = KIND[kind]
        s.rect(x, y, w, h, fill, stroke)
        s.text(x + w / 2, y + 22, title, 13, color, 700, 'middle')
        s.para(x + w / 2, y + 40, sub, w - 20, 11.5, INK2, 'middle')

    node(350, 20, 300, 60, 'When Power Apps calls a flow (V2)', 'RequestRefNo, DocType, StoredName, UploadedByEmail, File')
    s.line(500, 80, 500, 105, arrow=True)
    node(350, 105, 300, 60, 'Get files (properties only)', "FileLeafRef eq '<StoredName>'")
    s.line(500, 165, 500, 190, arrow=True)
    node(350, 190, 300, 56, 'Condition: any file found?', 'length(value) > 0', 'check')
    s.path('M 350 218 L 160 218 L 160 270', WARN, 1.4, arrow=True)
    s.text(250, 210, 'True', 12, WARN, 700, 'middle')
    node(40, 270, 240, 70, 'Respond: ok = false', '"A file called … is already attached to SR-…"', 'stop')
    s.path('M 650 218 L 780 218 L 780 260', OK, 1.4, arrow=True)
    s.text(715, 210, 'False', 12, OK, 700, 'middle')
    s.rect(560, 260, 420, 140, SURFACE, BRAND, 8, dash='6 4')
    s.text(576, 280, 'Scope: Upload', 12, BRAND_DARK, 700)
    node(580, 292, 120, 64, 'Create file', '/RequestDocuments', 'write')
    s.line(700, 324, 718, 324, arrow=True)
    node(720, 292, 120, 64, 'Update file properties', 'RequestRefNo, DocType, UploadedByEmail', 'write')
    s.line(840, 324, 858, 324, arrow=True)
    node(860, 292, 110, 64, 'Respond', 'ok = true', 'end')
    s.line(780, 400, 780, 420, BAD, 1.4, arrow=True)
    node(640, 420, 280, 46, 'Respond: ok = false', 'runs only if Upload failed', 'stop')
    return s.render()


ALL = {
    'journey.svg': journey, 'architecture.svg': architecture, 'data-model.svg': data_model,
    'shell-layout.svg': shell_layout, 'seq-submit.svg': seq_submit, 'seq-resubmit.svg': seq_resubmit,
    'seq-proceed.svg': seq_proceed, 'seq-return.svg': seq_return, 'seq-distribute.svg': seq_distribute,
    'seq-receipt.svg': seq_receipt, 'seq-rename.svg': seq_rename, 'flow-upload.svg': flow_upload,
}


def write_all(img_dir):
    for name, fn in ALL.items():
        with open(os.path.join(img_dir, name), 'w', encoding='utf-8') as f:
            f.write(fn())
    return list(ALL)
