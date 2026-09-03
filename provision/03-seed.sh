#!/usr/bin/env bash
#
# 03-seed.sh — seed the lists with the mock-up's own data.
#
# Run order is strict:   01-lists.sh  →  02-fields.sh  →  03-seed.sh
# Never run this before 02-fields.sh: SharePoint refuses to add an index to a list
# that is already over 5000 items, and every indexed column must exist first.
#
# Every value below is taken from the HTML mock-up in the repo root. Where the
# mock-up is silent, the line is marked  # ASSUMED  and the reasoning is stated.
#
# Schema contract: ../docs/schema.md
#
set -euo pipefail

SITE_URL="${SITE_URL:-https://trailanalyticslimited602.sharepoint.com/sites/OfficeSupplies}"

# ###########################################################################
# EDIT ME — people
#
# The mock-up names eleven people but gives no email addresses. These are
# plausible UPNs on the target tenant. Correct them to the real accounts before
# running, or the Person-column writes will fail (the shadow email columns will
# still be written with whatever is set here).
# ###########################################################################
UPN_DOMAIN="${UPN_DOMAIN:-trailanalyticslimited602.onmicrosoft.com}"

UPN_DANIEL_OTIENO="daniel.otieno@${UPN_DOMAIN}"     # Administrative Associate · Reviewer AND Requester, Garissa FO, Operations
UPN_AMINA_YUSUF="amina.yusuf@${UPN_DOMAIN}"         # Programme Officer · Requester, Garissa FO, Programme
UPN_SAMUEL_KIPTOO="samuel.kiptoo@${UPN_DOMAIN}"     # Storekeeper, Garissa FO
UPN_FATUMA_NOOR="fatuma.noor@${UPN_DOMAIN}"         # Chief Field Office, Garissa FO
UPN_SUSAN_NJERI="susan.njeri@${UPN_DOMAIN}"         # OIC for the Reviewer stage
UPN_JAMES_ODHIAMBO="james.odhiambo@${UPN_DOMAIN}"   # OIC for the Chief Field Office stage
UPN_LYDIA_CHEBET="lydia.chebet@${UPN_DOMAIN}"       # OIC for the Storekeeper stage
UPN_HALIMA_ABDI="halima.abdi@${UPN_DOMAIN}"         # Requester, Garissa FO, Child Protection
UPN_JOHN_BARAZA="john.baraza@${UPN_DOMAIN}"         # Requester, Garissa FO, Health & Nutrition
UPN_MERCY_ACHIENG="mercy.achieng@${UPN_DOMAIN}"     # Requester, Garissa FO, Operations
UPN_PETER_MWANGI="peter.mwangi@${UPN_DOMAIN}"       # Administrator, Nairobi CO, all offices

# Set SEED_PEOPLE=0 to write ONLY the shadow email columns and skip the Person
# columns. Use this when the accounts above do not exist in the tenant yet — the
# app filters on the shadow columns anyway, so the seed stays usable.
SEED_PEOPLE="${SEED_PEOPLE:-1}"

# ###########################################################################
# EDIT ME — the one figure the mock-up contradicts itself on
#
# Archive boxes (pack of 5), Garissa FO:
#   distribute.html  says "Available now 6"  (the state BEFORE SR-202607-0035
#                        is distributed, which is what the seed represents —
#                        that request is seeded as "Reviewed", not distributed)
#   admin.html tab 2 says "In stock 0"       (the state AFTER that distribution)
#   reports.html     says "Current stock 0"  (likewise, after)
#
# Default is 6, so the Phase 5 check "archive boxes hit 0 and flip to Out of
# stock" after distributing 6 of 10 actually exercises the code. Set to 0 if you
# would rather the catalogue screen match admin.html on day one.
# ###########################################################################
GFO_ARCHBOX_STOCK="${GFO_ARCHBOX_STOCK:-6}"

# ---------------------------------------------------------------------------
# Guard: must be signed in.
# ---------------------------------------------------------------------------
if ! command -v m365 >/dev/null 2>&1; then
  echo "ERROR: the 'm365' command was not found on PATH." >&2
  echo "       npm i -g @pnp/cli-microsoft365" >&2
  exit 1
fi

if ! m365 status --output text >/dev/null 2>&1; then
  echo "ERROR: not signed in to Microsoft 365." >&2
  echo "       Run these interactively first (they cannot be automated):" >&2
  echo "         m365 setup" >&2
  echo "         m365 login" >&2
  echo "         m365 status" >&2
  exit 1
fi

echo "Site:        $SITE_URL"
echo "UPN domain:  $UPN_DOMAIN"
echo "Seed people: $SEED_PEOPLE (1 = also write Person columns)"
echo

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# item_count <listTitle> <odataFilter>  ->  prints an integer
item_count() {
  local n
  n=$(m365 spo listitem list --webUrl "$SITE_URL" --listTitle "$1" \
        --filter "$2" --fields "ID" --output json --query "length(@)" 2>/dev/null) || n=0
  [ -n "$n" ] || n=0
  echo "$n"
}

# PERSON_ARGS is rebuilt before each seed call that needs Person columns.
PERSON_ARGS=()
person_reset() { PERSON_ARGS=(); }
# person <fieldInternalName> <upn>
person() {
  if [ "$SEED_PEOPLE" = "1" ] && [ -n "${2:-}" ]; then
    PERSON_ARGS+=( "--$1" "[{'Key':'i:0#.f|membership|$2'}]" )
  fi
}
# seed <label> <listTitle> <odataFilter> <m365 field args...>
# Any Person columns queued with `person` are appended automatically, then cleared.
seed() {
  local label="$1" list="$2" filter="$3"; shift 3
  if [ "$(item_count "$list" "$filter")" != "0" ]; then
    echo "  = $label — already present, skipping"
    person_reset
    return 0
  fi
  echo "  + $label"
  if ! m365 spo listitem add --webUrl "$SITE_URL" --listTitle "$list" --output none \
        "$@" ${PERSON_ARGS[@]+"${PERSON_ARGS[@]}"}; then
    echo "  ! FAILED: $label" >&2
    person_reset
    return 1
  fi
  person_reset
}

# ===========================================================================
# Offices                                     source: admin.html tab 3
# ===========================================================================
echo "Offices…"
seed "NCO Nairobi Country Office" Offices "Title eq 'NCO'" \
  --Title "NCO" --OfficeName "Nairobi Country Office" --OfficeType "Headquarters" \
  --Country "Kenya" --IsActive true                                   # Country ASSUMED
seed "GFO Garissa Field Office" Offices "Title eq 'GFO'" \
  --Title "GFO" --OfficeName "Garissa Field Office" --OfficeType "Field office" \
  --Country "Kenya" --IsActive true
seed "KFO Kisumu Field Office" Offices "Title eq 'KFO'" \
  --Title "KFO" --OfficeName "Kisumu Field Office" --OfficeType "Field office" \
  --Country "Kenya" --IsActive true

# ===========================================================================
# OfficeSharing                               source: admin.html tab 3
# "When a secondary office lacks stock, requests can be fulfilled from the
#  primary office." Primary (lends) → Secondary (borrows).
# ===========================================================================
echo "OfficeSharing…"
seed "NCO -> GFO" OfficeSharing "FromOfficeCode eq 'NCO' and ToOfficeCode eq 'GFO'" \
  --Title "NCO → GFO" --FromOfficeCode "NCO" --ToOfficeCode "GFO" --SharePriority 1 --IsActive true
seed "NCO -> KFO" OfficeSharing "FromOfficeCode eq 'NCO' and ToOfficeCode eq 'KFO'" \
  --Title "NCO → KFO" --FromOfficeCode "NCO" --ToOfficeCode "KFO" --SharePriority 1 --IsActive true

# ===========================================================================
# Catalogue
#
# Garissa stock and thresholds:
#   admin.html tab 2 — A4 paper 64/25, whiteboard markers 2/5,
#                      archive boxes 0/4, fax toner 3/— (Discontinued)
#   review.html      — flipchart pads 0 in Garissa (+15 in Nairobi CO),
#                      stapler heavy duty 5
#   distribute.html  — toner cartridge HP 26A available 7,
#                      archive boxes available 6  (see GFO_ARCHBOX_STOCK above)
#   receipt.html     — reveals ballpoint pens (box of 50), lever-arch files and
#                      desk tape dispenser exist at Garissa, but states no stock
#
# The "Discontinued" badge is IsActive = false. "Low stock" and "Out of stock"
# are derived from StockQty vs ReorderLevel and are never stored.
# ===========================================================================
echo "Catalogue…"

seed "GFO A4 photocopy paper (ream)" Catalogue "ItemCode eq 'A4PAPER' and OfficeCode eq 'GFO'" \
  --Title "A4 photocopy paper (ream)" --ItemCode "A4PAPER" --OfficeCode "GFO" \
  --OfficeItemKey "GFO|A4PAPER" --UnitOfMeasure "Ream" \
  --StockQty 64 --ReorderLevel 25 --RowVersion 1 --IsActive true

seed "GFO Whiteboard markers (box of 10)" Catalogue "ItemCode eq 'WBMARKER' and OfficeCode eq 'GFO'" \
  --Title "Whiteboard markers (box of 10)" --ItemCode "WBMARKER" --OfficeCode "GFO" \
  --OfficeItemKey "GFO|WBMARKER" --UnitOfMeasure "Box of 10" \
  --StockQty 2 --ReorderLevel 5 --RowVersion 1 --IsActive true

seed "GFO Archive boxes (pack of 5)" Catalogue "ItemCode eq 'ARCHBOX' and OfficeCode eq 'GFO'" \
  --Title "Archive boxes (pack of 5)" --ItemCode "ARCHBOX" --OfficeCode "GFO" \
  --OfficeItemKey "GFO|ARCHBOX" --UnitOfMeasure "Pack of 5" \
  --StockQty "$GFO_ARCHBOX_STOCK" --ReorderLevel 4 --RowVersion 1 --IsActive true

# ReorderLevel omitted: admin.html shows "—" for this item.
seed "GFO Fax toner, Canon L100 (discontinued)" Catalogue "ItemCode eq 'FAXTONER-L100' and OfficeCode eq 'GFO'" \
  --Title "Fax toner, Canon L100" --ItemCode "FAXTONER-L100" --OfficeCode "GFO" \
  --OfficeItemKey "GFO|FAXTONER-L100" --UnitOfMeasure "Cartridge" \
  --StockQty 3 --RowVersion 1 --IsActive false

seed "GFO Flipchart pads" Catalogue "ItemCode eq 'FLIPCHART' and OfficeCode eq 'GFO'" \
  --Title "Flipchart pads" --ItemCode "FLIPCHART" --OfficeCode "GFO" \
  --OfficeItemKey "GFO|FLIPCHART" --UnitOfMeasure "Pad" \
  --StockQty 0 --RowVersion 1 --IsActive true

seed "GFO Stapler, heavy duty" Catalogue "ItemCode eq 'STAPLER-HD' and OfficeCode eq 'GFO'" \
  --Title "Stapler, heavy duty" --ItemCode "STAPLER-HD" --OfficeCode "GFO" \
  --OfficeItemKey "GFO|STAPLER-HD" --UnitOfMeasure "Each" \
  --StockQty 5 --RowVersion 1 --IsActive true

seed "GFO Toner cartridge, HP 26A" Catalogue "ItemCode eq 'TONER-HP26A' and OfficeCode eq 'GFO'" \
  --Title "Toner cartridge, HP 26A" --ItemCode "TONER-HP26A" --OfficeCode "GFO" \
  --OfficeItemKey "GFO|TONER-HP26A" --UnitOfMeasure "Cartridge" \
  --StockQty 7 --RowVersion 1 --IsActive true

# The next three appear only in receipt.html as delivered items. The mock-up gives
# no Garissa stock figure for any of them.  # ASSUMED StockQty 0
seed "GFO Ballpoint pens, blue (box of 50)" Catalogue "ItemCode eq 'PEN-BLUE-50' and OfficeCode eq 'GFO'" \
  --Title "Ballpoint pens, blue (box of 50)" --ItemCode "PEN-BLUE-50" --OfficeCode "GFO" \
  --OfficeItemKey "GFO|PEN-BLUE-50" --UnitOfMeasure "Box of 50" \
  --StockQty 0 --RowVersion 1 --IsActive true

seed "GFO Lever-arch files" Catalogue "ItemCode eq 'LEVERARCH' and OfficeCode eq 'GFO'" \
  --Title "Lever-arch files" --ItemCode "LEVERARCH" --OfficeCode "GFO" \
  --OfficeItemKey "GFO|LEVERARCH" --UnitOfMeasure "Each" \
  --StockQty 0 --RowVersion 1 --IsActive true

seed "GFO Desk tape dispenser" Catalogue "ItemCode eq 'TAPEDISP' and OfficeCode eq 'GFO'" \
  --Title "Desk tape dispenser" --ItemCode "TAPEDISP" --OfficeCode "GFO" \
  --OfficeItemKey "GFO|TAPEDISP" --UnitOfMeasure "Each" \
  --StockQty 0 --RowVersion 1 --IsActive true

# The sharing-fallback row: review.html says "0 (+ 15 in Nairobi CO)".
seed "NCO Flipchart pads (15 — the sharing fallback)" Catalogue "ItemCode eq 'FLIPCHART' and OfficeCode eq 'NCO'" \
  --Title "Flipchart pads" --ItemCode "FLIPCHART" --OfficeCode "NCO" \
  --OfficeItemKey "NCO|FLIPCHART" --UnitOfMeasure "Pad" \
  --StockQty 15 --RowVersion 1 --IsActive true

# ===========================================================================
# ApprovalMatrix                              source: admin.html tab 1
#
# Garissa, all sections, FOUR rows. There is deliberately NO 'Approval' row —
# that absence IS the skip rule, and it is why the journey rail strikes the
# Approval leg through and admin.html shows four steps.
#
# The Stage strings admin.html displays (SUBMIT → Review, REVIEW → Confirm,
# CONFIRM → Distribute, DISTRIBUTE → Receipt) are DERIVED at render time from
# <previous active stage> → <this stage>. They are never stored.
# ===========================================================================
echo "ApprovalMatrix (Garissa, 4 rows, no Approval row)…"

person_reset
person Approver "$UPN_DANIEL_OTIENO"
person OIC      "$UPN_SUSAN_NJERI"
seed "GFO step 1 · Review · Daniel Otieno (OIC Susan Njeri)" ApprovalMatrix \
  "OfficeCode eq 'GFO' and Section eq 'All sections' and StageOrder eq 1" \
  --Title "GFO · Review" --OfficeCode "GFO" --Section "All sections" \
  --MatrixKey "GFO|All sections" --StageCode "Review" --StageOrder 1 \
  --ActorRoleCode "Reviewer" \
  --ApproverEmail "$UPN_DANIEL_OTIENO" --OICEmail "$UPN_SUSAN_NJERI" --IsActive true

person_reset
person Approver "$UPN_FATUMA_NOOR"
person OIC      "$UPN_JAMES_ODHIAMBO"
seed "GFO step 2 · Confirm · Fatuma Noor (OIC James Odhiambo)" ApprovalMatrix \
  "OfficeCode eq 'GFO' and Section eq 'All sections' and StageOrder eq 2" \
  --Title "GFO · Confirm" --OfficeCode "GFO" --Section "All sections" \
  --MatrixKey "GFO|All sections" --StageCode "Confirm" --StageOrder 2 \
  --ActorRoleCode "Chief Field Office" \
  --ApproverEmail "$UPN_FATUMA_NOOR" --OICEmail "$UPN_JAMES_ODHIAMBO" --IsActive true

person_reset
person Approver "$UPN_SAMUEL_KIPTOO"
person OIC      "$UPN_LYDIA_CHEBET"
seed "GFO step 3 · Deliver · Samuel Kiptoo (OIC Lydia Chebet)" ApprovalMatrix \
  "OfficeCode eq 'GFO' and Section eq 'All sections' and StageOrder eq 3" \
  --Title "GFO · Deliver" --OfficeCode "GFO" --Section "All sections" \
  --MatrixKey "GFO|All sections" --StageCode "Deliver" --StageOrder 3 \
  --ActorRoleCode "Storekeeper" \
  --ApproverEmail "$UPN_SAMUEL_KIPTOO" --OICEmail "$UPN_LYDIA_CHEBET" --IsActive true

# Step 4 has no named person and no OIC — admin.html shows "Requester (originator)"
# and "—". ActorRoleCode is what tells the app to route to the request's originator.
seed "GFO step 4 · Receive · Requester (originator)" ApprovalMatrix \
  "OfficeCode eq 'GFO' and Section eq 'All sections' and StageOrder eq 4" \
  --Title "GFO · Receive" --OfficeCode "GFO" --Section "All sections" \
  --MatrixKey "GFO|All sections" --StageCode "Receive" --StageOrder 4 \
  --ActorRoleCode "Requester" --IsActive true

# ===========================================================================
# AppRoles
# Sources: the .nav-user block on every page, plus admin.html tab 1.
#   index.html / request-detail.html / review.html — Daniel Otieno, Reviewer
#   receipt.html                                   — Daniel Otieno, Requester
#   new-request.html                               — Amina Yusuf, Requester
#   distribute.html                                — Samuel Kiptoo, Storekeeper
#   admin.html / reports.html                      — Peter Mwangi, Administrator
#   admin.html tab 1                               — Fatuma Noor (CFO), and the
#                                                    three OICs Susan Njeri,
#                                                    James Odhiambo, Lydia Chebet
#   index.html "Awaiting my action"                — Halima Abdi, John Baraza,
#                                                    Mercy Achieng (requesters)
# Office assignment is ASSUMED Garissa for everyone except Peter Mwangi, whose
# nav reads "All offices"; he is seeded against NCO.
# ===========================================================================
echo "AppRoles…"
role() { # <label> <displayName> <upn> <officeCode> <roleCode>
  seed "$1" AppRoles "UserEmail eq '$3' and RoleCode eq '$5'" \
    --Title "$2" --UserEmail "$3" --OfficeCode "$4" --RoleCode "$5" --IsActive true
}
role "Daniel Otieno · Reviewer"          "Daniel Otieno"   "$UPN_DANIEL_OTIENO"  GFO "Reviewer"
role "Daniel Otieno · Requester"         "Daniel Otieno"   "$UPN_DANIEL_OTIENO"  GFO "Requester"
role "Amina Yusuf · Requester"           "Amina Yusuf"     "$UPN_AMINA_YUSUF"    GFO "Requester"
role "Halima Abdi · Requester"           "Halima Abdi"     "$UPN_HALIMA_ABDI"    GFO "Requester"
role "John Baraza · Requester"           "John Baraza"     "$UPN_JOHN_BARAZA"    GFO "Requester"
role "Mercy Achieng · Requester"         "Mercy Achieng"   "$UPN_MERCY_ACHIENG"  GFO "Requester"
role "Susan Njeri · Reviewer (OIC)"      "Susan Njeri"     "$UPN_SUSAN_NJERI"    GFO "Reviewer"
role "Fatuma Noor · Chief Field Office"  "Fatuma Noor"     "$UPN_FATUMA_NOOR"    GFO "Chief Field Office"
role "James Odhiambo · CFO (OIC)"        "James Odhiambo"  "$UPN_JAMES_ODHIAMBO" GFO "Chief Field Office"
role "Samuel Kiptoo · Storekeeper"       "Samuel Kiptoo"   "$UPN_SAMUEL_KIPTOO"  GFO "Storekeeper"
role "Lydia Chebet · Storekeeper (OIC)"  "Lydia Chebet"    "$UPN_LYDIA_CHEBET"   GFO "Storekeeper"
role "Peter Mwangi · Administrator"      "Peter Mwangi"    "$UPN_PETER_MWANGI"   NCO "Administrator"

# ===========================================================================
# RefCounter
# Consistent with the highest reference used in each month:
#   SR-202605-0087, SR-202606-0114, SR-202607-0045
# ===========================================================================
echo "RefCounter…"
seed "202605 -> 87"  RefCounter "Title eq '202605'" --Title "202605" --LastSeq 87
seed "202606 -> 114" RefCounter "Title eq '202606'" --Title "202606" --LastSeq 114
seed "202607 -> 45"  RefCounter "Title eq '202607'" --Title "202607" --LastSeq 45

# ===========================================================================
# Requests                                    source: index.html (10 requests)
#
# StatusRank mapping (docs/schema.md): Draft 10, Returned 15, Submitted 20,
# Reviewed 30, Partial delivery 40, Fully delivered 50, Fully received 60,
# Closed 70, Rejected 90.
#
# DateTime format is "yyyy-MM-dd HH:mm:ss" in the SITE's local timezone — the
# only format m365 accepts on every regional setting. ISO 8601 / UTC is refused.
#
# LineCount carries the item count index.html states for each request. Only three
# requests have their lines shown anywhere in the mock-up — SR-202607-0038 (5, in
# request-detail.html), SR-202607-0035 (2, in distribute.html) and SR-202607-0029
# (4, in receipt.html) — so those three are the only ones with RequestItems rows.
# The other seven are header-only and their LineCount will not match a row count
# until someone adds lines.
#
# index.html gives "Held for" durations rather than timestamps for the four
# submitted requests. SR-202607-0038 is dated 11 Jul 2026 09:14 in
# request-detail.html and shown as held 4 days, which puts "now" at 15 Jul 2026.
# The other three submitted-on times are DERIVED from that anchor and their
# stated hold times, and are marked accordingly.
# ===========================================================================
echo "Requests…"

# --- 1. SR-202607-0038 — Amina Yusuf, Programme, 5 items, Submitted, held 4 days
person_reset
person Requester    "$UPN_AMINA_YUSUF"
person CurrentlyWith "$UPN_DANIEL_OTIENO"
seed "SR-202607-0038" Requests "Title eq 'SR-202607-0038'" \
  --Title "SR-202607-0038" --OfficeCode "GFO" --Section "Programme" \
  --RequesterEmail "$UPN_AMINA_YUSUF" \
  --CurrentlyWithEmail "$UPN_DANIEL_OTIENO" --CurrentlyWithOICEmail "$UPN_SUSAN_NJERI" \
  --Status "Submitted" --StatusRank 20 --CurrentStageCode "Review" --Purpose "Internal" \
  --SubmittedOn "2026-07-11 09:14:00" \
  --LineCount 5 --TotalQtyRequested 62 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0

# --- 2. SR-202607-0042 — Halima Abdi, Child Protection, 3 items, held 2 days
person_reset
person Requester    "$UPN_HALIMA_ABDI"
person CurrentlyWith "$UPN_DANIEL_OTIENO"
seed "SR-202607-0042" Requests "Title eq 'SR-202607-0042'" \
  --Title "SR-202607-0042" --OfficeCode "GFO" --Section "Child Protection" \
  --RequesterEmail "$UPN_HALIMA_ABDI" \
  --CurrentlyWithEmail "$UPN_DANIEL_OTIENO" --CurrentlyWithOICEmail "$UPN_SUSAN_NJERI" \
  --Status "Submitted" --StatusRank 20 --CurrentStageCode "Review" --Purpose "Internal" \
  --SubmittedOn "2026-07-13 09:00:00" \
  --LineCount 3 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0
  # SubmittedOn and Purpose ASSUMED — index.html gives only "2 days" held.

# --- 3. SR-202607-0044 — John Baraza, Health & Nutrition, 2 items, held 1 day
person_reset
person Requester    "$UPN_JOHN_BARAZA"
person CurrentlyWith "$UPN_DANIEL_OTIENO"
seed "SR-202607-0044" Requests "Title eq 'SR-202607-0044'" \
  --Title "SR-202607-0044" --OfficeCode "GFO" --Section "Health & Nutrition" \
  --RequesterEmail "$UPN_JOHN_BARAZA" \
  --CurrentlyWithEmail "$UPN_DANIEL_OTIENO" --CurrentlyWithOICEmail "$UPN_SUSAN_NJERI" \
  --Status "Submitted" --StatusRank 20 --CurrentStageCode "Review" --Purpose "Internal" \
  --SubmittedOn "2026-07-14 09:00:00" \
  --LineCount 2 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0

# --- 4. SR-202607-0045 — Mercy Achieng, Operations, 7 items, held 4 hours
person_reset
person Requester    "$UPN_MERCY_ACHIENG"
person CurrentlyWith "$UPN_DANIEL_OTIENO"
seed "SR-202607-0045" Requests "Title eq 'SR-202607-0045'" \
  --Title "SR-202607-0045" --OfficeCode "GFO" --Section "Operations" \
  --RequesterEmail "$UPN_MERCY_ACHIENG" \
  --CurrentlyWithEmail "$UPN_DANIEL_OTIENO" --CurrentlyWithOICEmail "$UPN_SUSAN_NJERI" \
  --Status "Submitted" --StatusRank 20 --CurrentStageCode "Review" --Purpose "Internal" \
  --SubmittedOn "2026-07-15 05:14:00" \
  --LineCount 7 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0

# --- 5. SR-202607-0029 — Daniel Otieno's own, 3 Jul 2026, 4 items, Fully delivered
#        receipt.html: delivered by Samuel Kiptoo on 13 Jul 2026; 10+2+12+1 = 25.
person_reset
person Requester    "$UPN_DANIEL_OTIENO"
person CurrentlyWith "$UPN_DANIEL_OTIENO"
seed "SR-202607-0029" Requests "Title eq 'SR-202607-0029'" \
  --Title "SR-202607-0029" --OfficeCode "GFO" --Section "Operations" \
  --RequesterEmail "$UPN_DANIEL_OTIENO" \
  --CurrentlyWithEmail "$UPN_DANIEL_OTIENO" \
  --Status "Fully delivered" --StatusRank 50 --CurrentStageCode "Receive" --Purpose "Internal" \
  --SubmittedOn "2026-07-03 09:00:00" \
  --LineCount 4 --TotalQtyRequested 25 --TotalQtyApproved 25 --TotalQtyDistributed 25 --TotalQtyReceived 0
  # Time of day ASSUMED (index.html gives the date only). Requested = delivered
  # ASSUMED, since the request is "Fully delivered".

# --- 6. SR-202607-0035 — Daniel Otieno's own, 8 Jul 2026, 2 items, Reviewed
#        distribute.html: with Samuel Kiptoo; confirmed by Fatuma Noor 14 Jul 2026.
person_reset
person Requester    "$UPN_DANIEL_OTIENO"
person CurrentlyWith "$UPN_SAMUEL_KIPTOO"
seed "SR-202607-0035" Requests "Title eq 'SR-202607-0035'" \
  --Title "SR-202607-0035" --OfficeCode "GFO" --Section "Operations" \
  --RequesterEmail "$UPN_DANIEL_OTIENO" \
  --CurrentlyWithEmail "$UPN_SAMUEL_KIPTOO" --CurrentlyWithOICEmail "$UPN_LYDIA_CHEBET" \
  --Status "Reviewed" --StatusRank 30 --CurrentStageCode "Deliver" --Purpose "Internal" \
  --SubmittedOn "2026-07-08 09:00:00" \
  --LineCount 2 --TotalQtyRequested 13 --TotalQtyApproved 13 --TotalQtyDistributed 0 --TotalQtyReceived 0

# --- 7. SR-202607-0040 — Daniel Otieno's own, 10 Jul 2026, 1 item, Returned
#        Return is blocked on an empty reason, so one is required here.
#        reports.html attributes returns to "mostly missing purpose detail".
person_reset
person Requester    "$UPN_DANIEL_OTIENO"
person CurrentlyWith "$UPN_DANIEL_OTIENO"
seed "SR-202607-0040" Requests "Title eq 'SR-202607-0040'" \
  --Title "SR-202607-0040" --OfficeCode "GFO" --Section "Operations" \
  --RequesterEmail "$UPN_DANIEL_OTIENO" \
  --CurrentlyWithEmail "$UPN_DANIEL_OTIENO" \
  --Status "Returned" --StatusRank 15 --Purpose "Internal" \
  --SubmittedOn "2026-07-10 09:00:00" \
  --LineCount 1 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0 \
  --ReturnReason "Purpose detail is missing — please state the intended use and resubmit."
  # ReturnReason text ASSUMED; the mock-up shows no wording for this request.

# --- 8. SR-202606-0114 — 26 Jun 2026, 6 items, Partial delivery, with Samuel Kiptoo
person_reset
person Requester    "$UPN_DANIEL_OTIENO"
person CurrentlyWith "$UPN_SAMUEL_KIPTOO"
seed "SR-202606-0114" Requests "Title eq 'SR-202606-0114'" \
  --Title "SR-202606-0114" --OfficeCode "GFO" --Section "Operations" \
  --RequesterEmail "$UPN_DANIEL_OTIENO" \
  --CurrentlyWithEmail "$UPN_SAMUEL_KIPTOO" --CurrentlyWithOICEmail "$UPN_LYDIA_CHEBET" \
  --Status "Partial delivery" --StatusRank 40 --CurrentStageCode "Deliver" --Purpose "Internal" \
  --SubmittedOn "2026-06-26 09:00:00" \
  --LineCount 6 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0
  # Lines for this request are not in the mock-up — header only.

# --- 9. SR-202606-0102 — 19 Jun 2026, 3 items, Fully received, currently with "—"
person_reset
person Requester "$UPN_DANIEL_OTIENO"
seed "SR-202606-0102" Requests "Title eq 'SR-202606-0102'" \
  --Title "SR-202606-0102" --OfficeCode "GFO" --Section "Operations" \
  --RequesterEmail "$UPN_DANIEL_OTIENO" \
  --Status "Fully received" --StatusRank 60 --CurrentStageCode "Receive" --Purpose "Internal" \
  --SubmittedOn "2026-06-19 09:00:00" \
  --LineCount 3 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0

# --- 10. SR-202605-0087 — 28 May 2026, 2 items, Closed
person_reset
person Requester "$UPN_DANIEL_OTIENO"
seed "SR-202605-0087" Requests "Title eq 'SR-202605-0087'" \
  --Title "SR-202605-0087" --OfficeCode "GFO" --Section "Operations" \
  --RequesterEmail "$UPN_DANIEL_OTIENO" \
  --Status "Closed" --StatusRank 70 --Purpose "Internal" \
  --SubmittedOn "2026-05-28 09:00:00" --ClosedOn "2026-06-02 09:00:00" \
  --LineCount 2 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0
  # ClosedOn ASSUMED — derived from reports.html's 4.2-day median submission→delivery.

# ===========================================================================
# RequestItems
# ===========================================================================
echo "RequestItems…"

# --- SR-202607-0038, 5 lines           source: request-detail.html
#     All show Distributed 0 / Received 0 and the "Pending" badge. The quantities
#     on review.html are the reviewer's UNSAVED proposal (the request is still
#     "Submitted"), so QtyApproved is seeded 0 here.
seed "SR-202607-0038 line 1 · A4 photocopy paper (ream)" RequestItems \
  "RequestRefNo eq 'SR-202607-0038' and LineNo eq 1" \
  --Title "SR-202607-0038-01" --RequestRefNo "SR-202607-0038" --OfficeCode "GFO" --LineNo 1 \
  --ItemCode "A4PAPER" --ItemName "A4 photocopy paper (ream)" --IsCatalogueItem true \
  --OfficeItemKey "GFO|A4PAPER" --UnitOfMeasure "Ream" --LinePurpose "Training workshop" \
  --QtyRequested 20 --QtyApproved 0 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

seed "SR-202607-0038 line 2 · Whiteboard markers (box of 10)" RequestItems \
  "RequestRefNo eq 'SR-202607-0038' and LineNo eq 2" \
  --Title "SR-202607-0038-02" --RequestRefNo "SR-202607-0038" --OfficeCode "GFO" --LineNo 2 \
  --ItemCode "WBMARKER" --ItemName "Whiteboard markers (box of 10)" --IsCatalogueItem true \
  --OfficeItemKey "GFO|WBMARKER" --UnitOfMeasure "Box of 10" --LinePurpose "Training workshop" \
  --QtyRequested 4 --QtyApproved 0 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

seed "SR-202607-0038 line 3 · Flipchart pads" RequestItems \
  "RequestRefNo eq 'SR-202607-0038' and LineNo eq 3" \
  --Title "SR-202607-0038-03" --RequestRefNo "SR-202607-0038" --OfficeCode "GFO" --LineNo 3 \
  --ItemCode "FLIPCHART" --ItemName "Flipchart pads" --IsCatalogueItem true \
  --OfficeItemKey "GFO|FLIPCHART" --UnitOfMeasure "Pad" --LinePurpose "Training workshop" \
  --QtyRequested 6 --QtyApproved 0 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"
  # SourceOfficeCode is deliberately NOT stamped yet — the NCO fallback is chosen
  # on the Review screen, which has not been saved for this request.

seed "SR-202607-0038 line 4 · Stapler, heavy duty" RequestItems \
  "RequestRefNo eq 'SR-202607-0038' and LineNo eq 4" \
  --Title "SR-202607-0038-04" --RequestRefNo "SR-202607-0038" --OfficeCode "GFO" --LineNo 4 \
  --ItemCode "STAPLER-HD" --ItemName "Stapler, heavy duty" --IsCatalogueItem true \
  --OfficeItemKey "GFO|STAPLER-HD" --UnitOfMeasure "Each" --LinePurpose "Section office" \
  --QtyRequested 2 --QtyApproved 0 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

# The free-text line: "Field notebooks, A5 (free text)". No ItemCode, no
# OfficeItemKey, IsCatalogueItem = false. review.html: "Not a catalogue item —
# cannot be stocked".
seed "SR-202607-0038 line 5 · Field notebooks, A5 (free text)" RequestItems \
  "RequestRefNo eq 'SR-202607-0038' and LineNo eq 5" \
  --Title "SR-202607-0038-05" --RequestRefNo "SR-202607-0038" --OfficeCode "GFO" --LineNo 5 \
  --ItemName "Field notebooks, A5" --IsCatalogueItem false --LinePurpose "Monitoring visits" \
  --QtyRequested 30 --QtyApproved 0 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

# --- SR-202607-0035, 2 lines           source: distribute.html
#     "Approved qty" 3 and 10. The originally requested quantities are not shown;
#     ASSUMED equal to approved.
seed "SR-202607-0035 line 1 · Toner cartridge, HP 26A" RequestItems \
  "RequestRefNo eq 'SR-202607-0035' and LineNo eq 1" \
  --Title "SR-202607-0035-01" --RequestRefNo "SR-202607-0035" --OfficeCode "GFO" --LineNo 1 \
  --ItemCode "TONER-HP26A" --ItemName "Toner cartridge, HP 26A" --IsCatalogueItem true \
  --OfficeItemKey "GFO|TONER-HP26A" --UnitOfMeasure "Cartridge" \
  --QtyRequested 3 --QtyApproved 3 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

seed "SR-202607-0035 line 2 · Archive boxes (pack of 5)" RequestItems \
  "RequestRefNo eq 'SR-202607-0035' and LineNo eq 2" \
  --Title "SR-202607-0035-02" --RequestRefNo "SR-202607-0035" --OfficeCode "GFO" --LineNo 2 \
  --ItemCode "ARCHBOX" --ItemName "Archive boxes (pack of 5)" --IsCatalogueItem true \
  --OfficeItemKey "GFO|ARCHBOX" --UnitOfMeasure "Pack of 5" \
  --QtyRequested 10 --QtyApproved 10 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

# --- SR-202607-0029, 4 lines           source: receipt.html
#     Status is "Fully delivered", so QtyDistributed is set and QtyReceived is 0.
#     Requested/approved ASSUMED equal to delivered.
seed "SR-202607-0029 line 1 · A4 photocopy paper (ream)" RequestItems \
  "RequestRefNo eq 'SR-202607-0029' and LineNo eq 1" \
  --Title "SR-202607-0029-01" --RequestRefNo "SR-202607-0029" --OfficeCode "GFO" --LineNo 1 \
  --ItemCode "A4PAPER" --ItemName "A4 photocopy paper (ream)" --IsCatalogueItem true \
  --OfficeItemKey "GFO|A4PAPER" --UnitOfMeasure "Ream" \
  --QtyRequested 10 --QtyApproved 10 --QtyDistributed 10 --QtyReceived 0 --LineStatus "Fully distributed"

seed "SR-202607-0029 line 2 · Ballpoint pens, blue (box of 50)" RequestItems \
  "RequestRefNo eq 'SR-202607-0029' and LineNo eq 2" \
  --Title "SR-202607-0029-02" --RequestRefNo "SR-202607-0029" --OfficeCode "GFO" --LineNo 2 \
  --ItemCode "PEN-BLUE-50" --ItemName "Ballpoint pens, blue (box of 50)" --IsCatalogueItem true \
  --OfficeItemKey "GFO|PEN-BLUE-50" --UnitOfMeasure "Box of 50" \
  --QtyRequested 2 --QtyApproved 2 --QtyDistributed 2 --QtyReceived 0 --LineStatus "Fully distributed"

seed "SR-202607-0029 line 3 · Lever-arch files" RequestItems \
  "RequestRefNo eq 'SR-202607-0029' and LineNo eq 3" \
  --Title "SR-202607-0029-03" --RequestRefNo "SR-202607-0029" --OfficeCode "GFO" --LineNo 3 \
  --ItemCode "LEVERARCH" --ItemName "Lever-arch files" --IsCatalogueItem true \
  --OfficeItemKey "GFO|LEVERARCH" --UnitOfMeasure "Each" \
  --QtyRequested 12 --QtyApproved 12 --QtyDistributed 12 --QtyReceived 0 --LineStatus "Fully distributed"

seed "SR-202607-0029 line 4 · Desk tape dispenser" RequestItems \
  "RequestRefNo eq 'SR-202607-0029' and LineNo eq 4" \
  --Title "SR-202607-0029-04" --RequestRefNo "SR-202607-0029" --OfficeCode "GFO" --LineNo 4 \
  --ItemCode "TAPEDISP" --ItemName "Desk tape dispenser" --IsCatalogueItem true \
  --OfficeItemKey "GFO|TAPEDISP" --UnitOfMeasure "Each" \
  --QtyRequested 1 --QtyApproved 1 --QtyDistributed 1 --QtyReceived 0 --LineStatus "Fully distributed"

# ===========================================================================
# RequestComments                             source: request-detail.html tab 2
# ===========================================================================
echo "RequestComments…"

person_reset
person CommentAuthor "$UPN_AMINA_YUSUF"
seed "SR-202607-0038 comment · Amina Yusuf" RequestComments \
  "RequestRefNo eq 'SR-202607-0038' and AuthorEmail eq '$UPN_AMINA_YUSUF'" \
  --Title "SR-202607-0038" --RequestRefNo "SR-202607-0038" \
  --CommentText "The workshop starts on 21 July — grateful if this can be reviewed this week." \
  --AuthorEmail "$UPN_AMINA_YUSUF" --PostedOn "2026-07-11 09:20:00"

person_reset
person CommentAuthor "$UPN_DANIEL_OTIENO"
seed "SR-202607-0038 comment · Daniel Otieno" RequestComments \
  "RequestRefNo eq 'SR-202607-0038' and AuthorEmail eq '$UPN_DANIEL_OTIENO'" \
  --Title "SR-202607-0038" --RequestRefNo "SR-202607-0038" \
  --CommentText "Noted. Checking marker stock — we may substitute the box size." \
  --AuthorEmail "$UPN_DANIEL_OTIENO" --PostedOn "2026-07-12 11:03:00"

# ===========================================================================
# RequestTimeline                             source: request-detail.html tab 1
# Rendered newest-first in the mock-up; seeded oldest-first.
# ===========================================================================
echo "RequestTimeline…"

person_reset
person Actor "$UPN_AMINA_YUSUF"
seed "SR-202607-0038 timeline · Draft created" RequestTimeline \
  "RequestRefNo eq 'SR-202607-0038' and EventType eq 'Draft created'" \
  --Title "Draft created" --RequestRefNo "SR-202607-0038" --EventType "Draft created" \
  --ToStatus "Draft" --ActorEmail "$UPN_AMINA_YUSUF" --OccurredOn "2026-07-10 16:42:00"

person_reset
person Actor "$UPN_AMINA_YUSUF"
seed "SR-202607-0038 timeline · Request submitted" RequestTimeline \
  "RequestRefNo eq 'SR-202607-0038' and EventType eq 'Submitted'" \
  --Title "Request submitted" --RequestRefNo "SR-202607-0038" --EventType "Submitted" \
  --FromStatus "Draft" --ToStatus "Submitted" --StageCode "Review" \
  --ActorEmail "$UPN_AMINA_YUSUF" --OccurredOn "2026-07-11 09:14:00" \
  --Detail "reference SR-202607-0038 issued"

# A system event: no actor.
seed "SR-202607-0038 timeline · Routed to Reviewer" RequestTimeline \
  "RequestRefNo eq 'SR-202607-0038' and EventType eq 'Routed'" \
  --Title "Routed to Reviewer" --RequestRefNo "SR-202607-0038" --EventType "Routed" \
  --ToStatus "Submitted" --StageCode "Review" --OccurredOn "2026-07-11 09:14:00" \
  --Detail "assigned to Daniel Otieno (OIC: Susan Njeri)"

# ===========================================================================
# RequestDocuments                            source: request-detail.html tab 3
# A document LIBRARY, so the row is created by uploading a file, not by
# 'spo listitem add'. The uploaded file is a minimal placeholder standing in for
# the generated request PDF; the file NAME is the one the mock-up shows.
# ===========================================================================
echo "RequestDocuments…"
if [ "$(item_count "RequestDocuments" "RequestRefNo eq 'SR-202607-0038'")" != "0" ]; then
  echo "  = SR-202607-0038-request.pdf — already present, skipping"
else
  TMP_PDF="$(mktemp -t sr-request)".pdf
  cat > "$TMP_PDF" <<'PDF'
%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]>>endobj
trailer<</Root 1 0 R/Size 4>>
%%EOF
PDF
  echo "  + SR-202607-0038-request.pdf"
  m365 spo file add --webUrl "$SITE_URL" --folder "RequestDocuments" \
    --path "$TMP_PDF" --fileName "SR-202607-0038-request.pdf" --overwrite false \
    --RequestRefNo "SR-202607-0038" --DocType "Request PDF" \
    --UploadedByEmail "$UPN_AMINA_YUSUF" --output none \
    || echo "  ! FAILED to upload SR-202607-0038-request.pdf (continuing)" >&2
  rm -f "$TMP_PDF"
fi

# ===========================================================================
# StockLedger
#
# Deliberately NOT seeded. The ledger is the audit truth for stock movements and
# every row must carry a real BalanceAfter computed at the moment of the move.
# The mock-up shows no historical movements, and fabricating them would put the
# reconciliation check (Catalogue.StockQty == newest StockLedger.BalanceAfter)
# into a false-mismatch state on day one. The first rows are written by the app
# on the first distribution.
# ===========================================================================
echo "StockLedger… (intentionally empty — see the comment in this script)"

echo
echo "Done."
echo
echo "Sanity checks worth running:"
echo "  m365 spo listitem list --webUrl \"\$SITE_URL\" --listTitle Requests   --fields 'Title,Status,StatusRank,CurrentlyWithEmail' --output text"
echo "  m365 spo listitem list --webUrl \"\$SITE_URL\" --listTitle Catalogue  --fields 'Title,OfficeCode,StockQty,ReorderLevel,IsActive' --output text"
echo "  m365 spo listitem list --webUrl \"\$SITE_URL\" --listTitle ApprovalMatrix --fields 'MatrixKey,StageOrder,StageCode,ActorRoleCode,ApproverEmail' --output text"
