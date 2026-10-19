#!/usr/bin/env python3
"""
Build "Office Supplies Canvas Rebuild Guide.pdf" from the Markdown chapters in this folder.

    .venv/bin/python powerapps/guide/build.py            # screenshots + diagrams + PDF
    .venv/bin/python powerapps/guide/build.py --no-shots # reuse the screenshots already in img/

Steps:
  1. Screenshot the eight HTML mock-ups at the repo root with headless Chrome, with numbered markers drawn on the
     controls each chapter talks about (ANNOTATIONS below). Written to img/mockup-<key>.jpg.
  2. Draw the diagrams (diagrams.py) into img/*.svg.
  3. Join the chapters (NN-*.md, in name order), expand their ::include lines, convert to HTML.
  4. Print the HTML to PDF with headless Chrome, the same way pa.init.officesupplies/scripts/build-manual.py prints the
     user manual.

Needs: Google Chrome, macOS `sips` (PNG -> JPEG), and the `markdown` package (`python3 -m venv .venv &&
.venv/bin/pip install markdown==3.7` at the repo root).
"""

import argparse
import datetime
import html
import json
import os
import re
import shlex
import subprocess
import sys
from urllib.parse import quote

import markdown

import diagrams

GUIDE = os.path.dirname(os.path.abspath(__file__))
POWERAPPS = os.path.dirname(GUIDE)
REPO = os.path.dirname(POWERAPPS)
IMG = os.path.join(GUIDE, 'img')
SCRATCH = os.path.join(GUIDE, '.build')
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
PDF_NAME = 'Office Supplies Canvas Rebuild Guide.pdf'
TITLE = 'Office Supplies — Canvas Rebuild Guide'
SUBTITLE = 'Rebuilding the Office Supplies app in Power Apps Canvas on the existing SharePoint lists'
WIDTH = 1366

# ── Mock-up screenshots ─────────────────────────────────────────────────────
# key -> (mock-up file, radio tab to select or None, [(CSS selector, nth match, marker number)])
# The marker numbers are the ones each screen chapter's "What is on this screen" table uses.
ANNOTATIONS = {
    'home': ('index.html', None, [
        ('.nav', 0, 1), ('.topbar h1', 0, 2), ('.topbar .persona', 0, 3), ('.topbar .btn-primary', 0, 4),
        ('.grid-3 .tile', 0, 5), ('.grid-3 .tile', 1, 6), ('.grid-3 .tile', 2, 7),
        ('section.card', 0, 8), ('section.card .btn-sm', 0, 9), ('section.card', 1, 10)]),
    'new-request': ('new-request.html', None, [
        ('.topbar h1', 0, 1), ('.topbar .btn', 0, 2), ('.topbar .btn-primary', 0, 3),
        ('.card', 0, 4), ('.card', 1, 5), ('.callout', 0, 6)]),
    'request-detail': ('request-detail.html', None, [
        ('.topbar h1', 0, 1), ('.topbar .btn-primary', 0, 2), ('.card', 0, 3), ('.journey', 0, 4),
        ('.table', 0, 5), ('.tabs', 0, 6)]),
    'review': ('review.html', None, [
        ('.topbar h1', 0, 1), ('.topbar .btn', 0, 2), ('.topbar .btn', 1, 3), ('.topbar .btn-primary', 0, 4),
        ('.callout', 0, 5), ('.table', 0, 6), ('textarea', 0, 7)]),
    'distribute': ('distribute.html', None, [
        ('.topbar .btn-primary', 0, 1), ('.card', 0, 2), ('.table', 0, 3), ('.callout', 0, 4)]),
    'receipt': ('receipt.html', None, [
        ('.topbar .btn-primary', 0, 1), ('.callout', 0, 2), ('.table', 0, 3), ('textarea', 0, 4)]),
    'admin-matrix': ('admin.html', 'tab-1', [
        ('.tab-list', 0, 1), ('.panel-1 select', 0, 2), ('.panel-1 .btn', 0, 3), ('.panel-1 .btn-primary', 0, 4),
        ('.panel-1 .callout', 0, 5), ('.panel-1 .table', 0, 6)]),
    'admin-catalogue': ('admin.html', 'tab-2', [
        ('.panel-2 select', 0, 1), ('.panel-2 .btn', 0, 2), ('.panel-2 .btn-primary', 0, 3),
        ('.panel-2 .table', 0, 4)]),
    'admin-offices': ('admin.html', 'tab-3', [
        ('.panel-3 .table', 0, 1), ('.panel-3 .table', 1, 2), ('.panel-3 .btn', 0, 3)]),
    'reports': ('reports.html', None, [
        ('.topbar select', 0, 1), ('.topbar .btn', 0, 2), ('.grid-3', 0, 3), ('.grid-2', 0, 4),
        ('section.card', 0, 5)]),
}

SHOT_SCRIPT = """
<style>
  .mock-note { display:none !important; }
  .os-mark { position:absolute; z-index:9999; width:26px; height:26px; border-radius:13px; background:#C50F1F;
             color:#fff; font:700 14px/26px "Segoe UI", Arial, sans-serif; text-align:center;
             box-shadow:0 0 0 3px #fff, 0 2px 6px rgba(0,0,0,.35); }
  .os-ring { position:absolute; z-index:9998; border:2px dashed #C50F1F; border-radius:6px; pointer-events:none; }
</style>
<script>
window.addEventListener('load', function () {
  var tab = %(tab)s;
  if (tab) { var r = document.getElementById(tab); if (r) r.checked = true; }
  var marks = %(marks)s, missing = [];
  marks.forEach(function (m) {
    var el = document.querySelectorAll(m[0])[m[1]];
    if (!el) { missing.push(m[2] + ' ' + m[0]); return; }
    var b = el.getBoundingClientRect(), x = b.left + window.scrollX, y = b.top + window.scrollY;
    var ring = document.createElement('div');
    ring.className = 'os-ring';
    ring.style.left = (x - 3) + 'px'; ring.style.top = (y - 3) + 'px';
    ring.style.width = (b.width + 6) + 'px'; ring.style.height = (b.height + 6) + 'px';
    document.body.appendChild(ring);
    var dot = document.createElement('div');
    dot.className = 'os-mark';
    dot.textContent = m[2];
    // Beside the element's top-left corner, so the marker never hides the text it points at.
    dot.style.left = (x >= 34 ? x - 32 : x + 4) + 'px'; dot.style.top = Math.max(2, y - 13) + 'px';
    document.body.appendChild(dot);
  });
  document.documentElement.setAttribute('data-h', document.documentElement.scrollHeight);
  document.documentElement.setAttribute('data-missing', missing.join('; '));
});
</script>
"""


def chrome(*args):
    return subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                           '--allow-file-access-from-files', *args], check=True, capture_output=True, text=True)


def shoot(key, page, tab, marks):
    with open(os.path.join(REPO, page), encoding='utf-8') as f:
        src = f.read()
    base = f'<base href="file://{quote(REPO)}/">'
    inject = SHOT_SCRIPT % {'tab': json.dumps(tab), 'marks': json.dumps(marks)}
    src = src.replace('<head>', '<head>' + base, 1).replace('</body>', inject + '</body>', 1)
    tmp = os.path.join(SCRATCH, f'shot-{key}.html')
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write(src)
    url = 'file://' + quote(tmp)
    dom = chrome(f'--window-size={WIDTH},900', '--virtual-time-budget=3000', '--dump-dom', url).stdout
    height = int(re.search(r'data-h="(\d+)"', dom).group(1))
    missing = re.search(r'data-missing="([^"]*)"', dom).group(1)
    if missing:
        sys.exit(f'build: {page}: no element for marker(s) {missing}')
    png = os.path.join(SCRATCH, f'mockup-{key}.png')
    chrome(f'--window-size={WIDTH},{height}', '--force-device-scale-factor=1.5', '--virtual-time-budget=3000',
           f'--screenshot={png}', url)
    jpg = os.path.join(IMG, f'mockup-{key}.jpg')
    subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '82', png, '--out', jpg],
                   check=True, capture_output=True)
    return height


# ── Markdown ────────────────────────────────────────────────────────────────

INCLUDE = re.compile(r'^::include\s+(\S+)(.*)$', re.M)


def expand_include(match, here):
    """::include <path> [sections=a-b] [from="heading"] [to="heading"] [demote=n] [skip-title=1] [code=lang]"""
    path = os.path.normpath(os.path.join(here, match.group(1)))
    opts = dict(o.split('=', 1) for o in shlex.split(match.group(2)))
    with open(path, encoding='utf-8') as f:
        text = f.read()
    if 'sections' in opts:
        # "## Section N — ..." blocks of app-glue.md, from N=a to N=b inclusive.
        a, b = (int(x) for x in opts['sections'].split('-'))
        parts = re.split(r'(?m)^(?=## Section \d+)', text)
        keep = [p for p in parts if (m := re.match(r'## Section (\d+)', p)) and a <= int(m.group(1)) <= b]
        if len(keep) != b - a + 1:
            sys.exit(f'build: {path} has {len(keep)} of sections {a}-{b}')
        text = ''.join(keep)
        text = re.sub(r'(?m)^---\s*$', '', text)
    if 'from' in opts:
        start = text.find('\n' + opts['from'])
        if start < 0:
            sys.exit(f'build: {path} has no heading "{opts["from"]}"')
        end = text.find('\n' + opts['to'], start + 1) if 'to' in opts else -1
        if 'to' in opts and end < 0:
            sys.exit(f'build: {path} has no heading "{opts["to"]}"')
        text = text[start:end if end >= 0 else None]
        text = re.sub(r'(?m)^---\s*$', '', text)
    if opts.get('skip-title') == '1':
        text = re.sub(r'\A#+\s[^\n]*\n', '', text.lstrip())
    demote = int(opts.get('demote', '0'))
    if demote:
        text = re.sub(r'(?m)^(#{1,5}) ', lambda m: '#' * (len(m.group(1)) + demote) + ' ', text)
    if 'code' in opts:
        text = f"```{opts['code']}\n{text.rstrip()}\n```\n"
    return text


def load_chapters():
    names = sorted(n for n in os.listdir(GUIDE) if re.match(r'\d\d-.*\.md$', n))
    out = []
    for n in names:
        with open(os.path.join(GUIDE, n), encoding='utf-8') as f:
            text = f.read()
        text = INCLUDE.sub(lambda m: expand_include(m, GUIDE), text)
        out.append(text)
    return names, '\n\n'.join(out)


def slug(text):
    return re.sub(r'[^a-z0-9]+', '-', html.unescape(re.sub('<[^>]+>', '', text)).lower()).strip('-')


LIST_FENCE = re.compile(r'(?ms)^( {4})```\w*\n(.*?)^ {4}```[ \t]*$')


def to_html(md_text):
    # Python-Markdown's fenced code does not work inside a list item; an 8-space indented
    # block does, so a fence indented under a list item is rewritten as one.
    md_text = LIST_FENCE.sub(lambda m: '\n'.join('        ' + ln[4:] if ln.strip() else ''
                                                  for ln in m.group(2).rstrip('\n').split('\n')), md_text)
    body = markdown.markdown(md_text, extensions=['tables', 'fenced_code', 'admonition', 'attr_list', 'md_in_html'],
                             output_format='html5')

    # Figures: a paragraph holding only an image becomes a numbered <figure>.
    n = [0]

    def figure(m):
        alt, src = html.unescape(m.group(1)), m.group(2)
        n[0] += 1
        tall = ' class="tall"' if 'mockup-' in src else ''
        return (f'<figure{tall}><img src="{src}" alt="{html.escape(alt)}">'
                f'<figcaption>Figure {n[0]}. {html.escape(alt)}</figcaption></figure>')
    body = re.sub(r'<p><img alt="([^"]*)" src="([^"]+)"\s*/?></p>', figure, body)

    # Headings get ids, h1 starts a page; collect the table of contents from h1 and h2.
    toc, seen = [], set()

    def heading(m):
        level, attrs, inner = m.group(1), m.group(2), m.group(3)
        hid = slug(inner) or f'h{len(seen)}'
        while hid in seen:
            hid += '-x'
        seen.add(hid)
        if level in ('1', '2'):
            toc.append((level, hid, html.unescape(re.sub('<[^>]+>', '', inner))))
        return f'<h{level} id="{hid}"{attrs}>{inner}</h{level}>'
    body = re.sub(r'<h([1-3])([^>]*)>(.*?)</h\1>', heading, body)

    # Power Fx comments in a lighter colour, so the formula stands out.
    def comments(m):
        code = re.sub(r'(?m)(^|[^:"])(//[^\n]*)', r'\1<span class="c">\2</span>', m.group(2))
        return m.group(1) + code + '</code></pre>'
    body = re.sub(r'(<pre><code[^>]*>)(.*?)</code></pre>', comments, body, flags=re.S)

    # DEF-01 and SR-202607-0038 never break at their hyphen in running text (code is left alone).
    parts = re.split(r'(<pre>.*?</pre>)', body, flags=re.S)
    body = ''.join(p if p.startswith('<pre>') else re.sub(r'\b(DEF|E2E|UAT)-(\d)', '\\1&#8209;\\2', p) for p in parts)
    return body, toc


CSS = """
:root { --ink:#1f2933; --ink2:#52606d; --line:#d9e2ec; --surface:#ffffff; --canvas:#f5f7fa; --brand:#0f6cbd;
        --chip:#e6f0fa; --see:#107c10; --trap:#986f0b; --def:#8764b8; }
* { box-sizing:border-box; }
html, body { margin:0; background:#fff; color:var(--ink);
             font:10.5pt/1.5 -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
a { color:var(--brand); text-decoration:none; }
@page { size:A4; margin:15mm 12mm 17mm;
        @bottom-left { content:"Office Supplies — Canvas Rebuild Guide"; font-size:8pt; color:#7b8794; }
        @bottom-right { content:"Page " counter(page) " of " counter(pages); font-size:8pt; color:#7b8794; } }
@page :first { @bottom-left { content:none; } @bottom-right { content:none; } }
h1 { page-break-before:always; font-size:22pt; margin:0 0 6mm; padding-bottom:3mm; border-bottom:3px solid var(--brand); }
h2 { font-size:14.5pt; margin:8mm 0 2mm; page-break-after:avoid; }
h3 { font-size:12pt; margin:6mm 0 2mm; page-break-after:avoid; }
h4 { font-size:10.5pt; margin:4mm 0 1mm; page-break-after:avoid; }
p, li { orphans:3; widows:3; }
ol, ul { padding-left:7mm; }
li { margin:1mm 0; }
code { font-family:Menlo, Consolas, "Courier New", monospace; font-size:8.8pt; background:#f0f4f8;
       padding:0 3px; border-radius:3px; }
pre { background:#f7f9fb; border:1px solid var(--line); border-left:4px solid var(--brand); border-radius:4px;
      padding:2.5mm 3.5mm; white-space:pre-wrap; word-break:break-word; font-size:7.5pt; line-height:1.4; }
pre code { background:none; padding:0; font-size:inherit; }
pre .c { color:#7b8794; }
table { border-collapse:collapse; width:100%; margin:3mm 0; page-break-inside:auto; }
tr { page-break-inside:avoid; }
th, td { border:1px solid var(--line); padding:4px 7px; text-align:left; vertical-align:top; font-size:9.3pt; }
th { background:var(--chip); }
td code { font-size:8pt; word-break:break-word; }
td:first-child code { white-space:nowrap; word-break:normal; }
figure { margin:4mm 0; page-break-inside:avoid; text-align:center; }
figure img { max-width:100%; max-height:205mm; border:1px solid var(--line); border-radius:4px; }
figure.tall img { max-height:218mm; }
figcaption { font-size:9pt; color:var(--ink2); margin-top:2mm; }
.admonition { border:1px solid var(--line); border-left:5px solid var(--brand); border-radius:4px;
              padding:2mm 4mm; margin:4mm 0; page-break-inside:avoid; background:#fbfdff; }
.admonition-title { font-weight:700; margin:0 0 1mm; }
.admonition.see { border-left-color:var(--see); background:#f4faf4; }
.admonition.see .admonition-title::before { content:"✓  "; color:var(--see); }
.admonition.trap { border-left-color:var(--trap); background:#fdf9ef; }
.admonition.trap .admonition-title::before { content:"⚠  "; color:var(--trap); }
.admonition.def { border-left-color:var(--def); background:#f8f5fc; }
.admonition.note .admonition-title::before { content:"ℹ  "; color:var(--brand); }
.cover { height:255mm; display:flex; flex-direction:column; justify-content:center; }
.cover .kicker { color:var(--brand); font-weight:700; letter-spacing:.08em; text-transform:uppercase; font-size:10pt; }
.cover h1.title { page-break-before:avoid; border:0; font-size:32pt; margin:2mm 0 4mm; padding:0; }
.cover p.sub { font-size:14pt; color:var(--ink2); margin:0 0 12mm; }
.cover table { width:auto; }
.cover td { border:0; padding:1mm 6mm 1mm 0; font-size:10.5pt; }
.toc { page-break-before:always; }
.toc h2 { margin-top:0; }
.toc ol { list-style:none; padding:0; margin:0; }
.toc li.l1 { font-weight:700; margin-top:3mm; }
.toc li.l2 { padding-left:7mm; font-weight:400; margin:.5mm 0; font-size:9.8pt; }
.shots { display:grid; grid-template-columns:1fr 1fr; gap:4mm; margin:4mm 0; }
.shots figure { margin:0; }
.shots img { max-height:62mm; object-fit:cover; object-position:top; width:100%; }
.small { font-size:9pt; color:var(--ink2); }
"""


def write_html(body, toc, names):
    today = datetime.date.today().strftime('%d %B %Y').lstrip('0')
    toc_html = ''.join(f'<li class="l{lvl}"><a href="#{hid}">{html.escape(text)}</a></li>'
                       for lvl, hid, text in toc)
    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>{html.escape(TITLE)}</title><style>{CSS}</style></head>
<body>
<section class="cover">
  <div class="kicker">Power Apps Canvas · SharePoint</div>
  <h1 class="title">Office Supplies<br>Canvas Rebuild Guide</h1>
  <p class="sub">{html.escape(SUBTITLE)}</p>
  <table>
    <tr><td><b>For</b></td><td>A Power Apps maker who will build the app in Studio</td></tr>
    <tr><td><b>Rebuilds</b></td><td>The Office Supplies SPFx web part, build 1.0.0.20 (31 of 31 UAT cases passing)</td></tr>
    <tr><td><b>Data</b></td><td>The 12 existing lists on the Office Supplies SharePoint site</td></tr>
    <tr><td><b>Date</b></td><td>{today}</td></tr>
  </table>
</section>
<nav class="toc"><h2>Contents</h2><ol>{toc_html}</ol></nav>
{body}
</body></html>
"""
    out = os.path.join(SCRATCH, 'guide.html')
    with open(out, 'w', encoding='utf-8') as f:
        f.write(page)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--no-shots', action='store_true', help='reuse the screenshots already in img/')
    args = ap.parse_args()
    os.makedirs(IMG, exist_ok=True)
    os.makedirs(SCRATCH, exist_ok=True)

    if not args.no_shots:
        for key, (page, tab, marks) in ANNOTATIONS.items():
            h = shoot(key, page, tab, marks)
            print(f'  shot  {key:<16} {page:<20} {WIDTH}x{h}')
    for name in diagrams.write_all(IMG):
        print(f'  draw  {name}')

    names, md_text = load_chapters()
    body, toc = to_html(md_text)
    # Image paths in the chapters are relative to this folder; the HTML is written to .build/.
    body = body.replace('src="../guide/img/', 'src="img/').replace('src="guide/img/', 'src="img/').replace('src="img/', f'src="file://{quote(IMG)}/')
    src = write_html(body, toc, names)
    pdf = os.path.join(GUIDE, PDF_NAME)
    chrome('--no-pdf-header-footer', '--generate-pdf-document-outline', f'--print-to-pdf={pdf}',
           'file://' + quote(src))
    print(f'{len(names)} chapters, {len(toc)} contents entries -> {pdf} ({os.path.getsize(pdf) / 1e6:.1f} MB)')


if __name__ == '__main__':
    main()
