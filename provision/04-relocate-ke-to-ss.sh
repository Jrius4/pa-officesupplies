#!/usr/bin/env bash
#
# 04-relocate-ke-to-ss.sh — move an ALREADY-SEEDED site from the Kenya narrative
# to UNICEF South Sudan, in place.
#
#   NCO Nairobi Country Office  ->  JCO Juba Country Office     (Headquarters)
#   GFO Garissa Field Office    ->  BOR Bor Zonal Office         (main narrative)
#   KFO Kisumu Field Office     ->  MAL Malakal Zonal Office
#   Country "Kenya"             ->  "South Sudan"
#   the eleven seeded personas  ->  South Sudanese names / UPNs
#
# Why a migration and not a re-run of 03-seed.sh: the office code is a KEY, not a
# label. It is embedded in `Catalogue.OfficeItemKey` (`GFO|A4PAPER`),
# `ApprovalMatrix.MatrixKey` (`GFO|All sections`) and the `OfficeCode` filter
# column on six lists. Re-seeding would leave every pre-existing row orphaned
# under a code the app no longer queries, including any request created through
# the UI. This rewrites them instead.
#
# Run AFTER 01-lists.sh / 02-fields.sh / 03-seed.sh have already been applied.
# Safe to run twice: every write is conditional on the value actually changing,
# so a second pass reports 0 updates.
#
# DRY RUN BY DEFAULT. Nothing is written until you pass DRY_RUN=0.
#
#   ./04-relocate-ke-to-ss.sh            # report what would change
#   DRY_RUN=0 ./04-relocate-ke-to-ss.sh  # apply it
#
# Schema contract: ../docs/schema.md
#
set -euo pipefail

SITE_URL="${SITE_URL:-https://trailanalyticslimited602.sharepoint.com/sites/OfficeSupplies}"
UPN_DOMAIN="${UPN_DOMAIN:-trailanalyticslimited602.onmicrosoft.com}"
DRY_RUN="${DRY_RUN:-1}"

if ! command -v m365 >/dev/null 2>&1; then
  echo "m365 (CLI for Microsoft 365) is not on PATH." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required (used for the value rewrite)." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Which columns on which list carry a code, a composite key, or an email.
# Derived from docs/schema.md; Person columns are deliberately NOT in this list
# (see the note at the end of the run).
# ---------------------------------------------------------------------------
LISTS=(
  "Offices:Title,OfficeName,Country"
  "OfficeSharing:Title,FromOfficeCode,ToOfficeCode"
  "Catalogue:OfficeCode,OfficeItemKey"
  "StockLedger:Title,OfficeCode,OfficeItemKey,MovedByEmail"
  "ApprovalMatrix:Title,MatrixKey,OfficeCode,ApproverEmail,OICEmail"
  "Requests:OfficeCode,SharingOfficeCode,RequesterEmail,CurrentlyWithEmail,CurrentlyWithOICEmail"
  "RequestItems:OfficeCode,SourceOfficeCode,OfficeItemKey"
  "RequestComments:AuthorEmail"
  "RequestTimeline:ActorEmail"
  "RequestDocuments:UploadedByEmail"
  "AppRoles:OfficeCode,UserEmail"
)

export UPN_DOMAIN

# Rewrites one field value. Word-bounded so `GFO` in `GFO|A4PAPER` is caught but
# a code embedded in a longer token is not.
rewrite() {
  python3 -c '
import re, sys
v = sys.argv[1]
rules = [
    (r"Nairobi Country Office", "Juba Country Office"),
    (r"Garissa Field Office",   "Bor Zonal Office"),
    (r"Kisumu Field Office",    "Malakal Zonal Office"),
    (r"\bNairobi\b",            "Juba"),
    (r"\bGarissa\b",            "Bor"),
    (r"\bKisumu\b",             "Malakal"),
    (r"\bKenya\b",              "South Sudan"),
    (r"\bNCO\b",                "JCO"),
    (r"\bGFO\b",                "BOR"),
    (r"\bKFO\b",                "MAL"),
    ("daniel.otieno",  "deng.machar"),
    ("amina.yusuf",    "nyandeng.akol"),
    ("samuel.kiptoo",  "simon.majok"),
    ("fatuma.noor",    "rebecca.achol"),
    ("susan.njeri",    "grace.aluel"),
    ("james.odhiambo", "peter.gatluak"),
    ("lydia.chebet",   "mary.nyaluak"),
    ("halima.abdi",    "sarah.ayen"),
    ("john.baraza",    "john.lado"),
    ("mercy.achieng",  "josephine.poni"),
    ("peter.mwangi",   "emmanuel.wani"),
    (r"Daniel Otieno",  "Deng Machar"),
    (r"Amina Yusuf",    "Nyandeng Akol"),
    (r"Samuel Kiptoo",  "Simon Majok"),
    (r"Fatuma Noor",    "Rebecca Achol"),
    (r"Susan Njeri",    "Grace Aluel"),
    (r"James Odhiambo", "Peter Gatluak"),
    (r"Lydia Chebet",   "Mary Nyaluak"),
    (r"Halima Abdi",    "Sarah Ayen"),
    (r"John Baraza",    "John Lado"),
    (r"Mercy Achieng",  "Josephine Poni"),
    (r"Peter Mwangi",   "Emmanuel Wani"),
]
for pat, rep in rules:
    v = re.sub(pat, rep, v)
sys.stdout.write(v)
' "$1"
}

updated=0; scanned=0; skipped_lists=0

for entry in "${LISTS[@]}"; do
  list="${entry%%:*}"
  cols="${entry#*:}"

  echo "── $list  [$cols]"

  if ! rows="$(m365 spo listitem list --webUrl "$SITE_URL" --listTitle "$list" \
                 --fields "Id,$cols" --output json 2>/dev/null)"; then
    echo "   ! could not read $list — skipping (does it exist yet?)" >&2
    skipped_lists=$((skipped_lists + 1))
    continue
  fi

  count="$(printf '%s' "$rows" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
  [ "$count" = "0" ] && { echo "   (empty)"; continue; }

  # Emit "id<TAB>column<TAB>oldvalue" for every populated cell we may rewrite.
  while IFS=$'\t' read -r id col old; do
    [ -z "${old:-}" ] && continue
    scanned=$((scanned + 1))
    new="$(rewrite "$old")"
    [ "$new" = "$old" ] && continue

    echo "   ${id}  ${col}: ${old}  ->  ${new}"
    updated=$((updated + 1))
    if [ "$DRY_RUN" = "0" ]; then
      if ! m365 spo listitem set --webUrl "$SITE_URL" --listTitle "$list" \
             --id "$id" --"$col" "$new" --output none; then
        echo "   ! FAILED to set $list#$id.$col" >&2
      fi
    fi
  done < <(printf '%s' "$rows" | python3 -c '
import json, sys
cols = sys.argv[1].split(",")
for row in json.load(sys.stdin):
    rid = row.get("Id") or row.get("ID")
    for c in cols:
        v = row.get(c)
        if isinstance(v, str) and v:
            sys.stdout.write("%s\t%s\t%s\n" % (rid, c, v))
' "$cols")
done

echo
echo "──────────────────────────────────────────────────────────────"
if [ "$DRY_RUN" = "0" ]; then
  echo "Applied $updated field updates across $scanned scanned values."
else
  echo "DRY RUN — $updated field updates would be applied ($scanned values scanned)."
  echo "Re-run with DRY_RUN=0 to write them."
fi
[ "$skipped_lists" != "0" ] && echo "WARNING: $skipped_lists list(s) could not be read."

cat <<'NOTE'

Person columns are NOT touched by this script.
  StockLedger.MovedBy, ApprovalMatrix.Approver / .OIC, Requests.Requester /
  .CurrentlyWith, RequestTimeline.Actor and RequestComments.CommentAuthor are
  SharePoint Person columns bound to real tenant accounts. Their shadow email
  columns above have been rewritten, and the app filters on the shadow columns
  (see docs/schema.md section "Shadow text keys"), so the app behaves correctly
  either way. Re-point the Person columns only once the new personas exist as
  real accounts in the tenant.

Verify with:
  m365 spo listitem list --webUrl "$SITE_URL" --listTitle Offices   --fields 'Title,OfficeName,Country' --output text
  m365 spo listitem list --webUrl "$SITE_URL" --listTitle Catalogue --fields 'OfficeItemKey,OfficeCode,StockQty' --output text
  m365 spo listitem list --webUrl "$SITE_URL" --listTitle AppRoles  --fields 'UserEmail,RoleCode,OfficeCode' --output text
NOTE
