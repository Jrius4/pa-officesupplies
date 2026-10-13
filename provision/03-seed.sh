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

UPN_DENG_MACHAR="deng.machar@${UPN_DOMAIN}"        # Administrative Associate · Reviewer AND Requester, Bor ZO, Operations
UPN_NYANDENG_AKOL="nyandeng.akol@${UPN_DOMAIN}"    # Programme Officer · Requester, Bor ZO, Programme
UPN_SIMON_MAJOK="simon.majok@${UPN_DOMAIN}"        # Storekeeper, Bor ZO
UPN_REBECCA_ACHOL="rebecca.achol@${UPN_DOMAIN}"    # Chief Field Office, Bor ZO
UPN_GRACE_ALUEL="grace.aluel@${UPN_DOMAIN}"        # OIC for the Reviewer stage
UPN_PETER_GATLUAK="peter.gatluak@${UPN_DOMAIN}"    # OIC for the Chief Field Office stage
UPN_MARY_NYALUAK="mary.nyaluak@${UPN_DOMAIN}"      # OIC for the Storekeeper stage
UPN_SARAH_AYEN="sarah.ayen@${UPN_DOMAIN}"          # Requester, Bor ZO, Child Protection
UPN_JOHN_LADO="john.lado@${UPN_DOMAIN}"            # Requester, Bor ZO, Health & Nutrition
UPN_JOSEPHINE_PONI="josephine.poni@${UPN_DOMAIN}"  # Requester, Bor ZO, Operations
UPN_EMMANUEL_WANI="emmanuel.wani@${UPN_DOMAIN}"    # Administrator, Juba CO, all offices

# Set SEED_PEOPLE=0 to write ONLY the shadow email columns and skip the Person
# columns. Use this when the accounts above do not exist in the tenant yet — the
# app filters on the shadow columns anyway, so the seed stays usable.
SEED_PEOPLE="${SEED_PEOPLE:-1}"

# ###########################################################################
# EDIT ME — the one figure the mock-up contradicts itself on
#
# Archive boxes (pack of 5), Bor ZO:
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
BOR_ARCHBOX_STOCK="${BOR_ARCHBOX_STOCK:-6}"

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
#
# UNICEF South Sudan: the Juba Country Office plus the four zonal offices named
# in the UNICEF OIAI audit of the South Sudan Country Office (Dec 2018) — Bentiu,
# Bor, Malakal, Wau. JUDGEMENT CALL: UNICEF publishes no current office list, so
# the audit is the best public source. Field offices (Aweil, Kuajok, Pibor,
# Rumbek, Yambio, Yei) are deliberately not seeded; add them in Admin → Offices
# with type "Field office". Torit closed c. 2022.
#
# BEN and WAU get no Catalogue, ApprovalMatrix or AppRoles rows — like MAL, a
# request raised there cannot route until an administrator configures them.
# ===========================================================================
echo "Offices…"
seed "JCO Juba Country Office" Offices "Title eq 'JCO'" \
  --Title "JCO" --OfficeName "Juba Country Office" --OfficeType "Headquarters" \
  --Country "South Sudan" --IsActive true
seed "BOR Bor Zonal Office" Offices "Title eq 'BOR'" \
  --Title "BOR" --OfficeName "Bor Zonal Office" --OfficeType "Zonal office" \
  --Country "South Sudan" --IsActive true
seed "MAL Malakal Zonal Office" Offices "Title eq 'MAL'" \
  --Title "MAL" --OfficeName "Malakal Zonal Office" --OfficeType "Zonal office" \
  --Country "South Sudan" --IsActive true
seed "BEN Bentiu Zonal Office" Offices "Title eq 'BEN'" \
  --Title "BEN" --OfficeName "Bentiu Zonal Office" --OfficeType "Zonal office" \
  --Country "South Sudan" --IsActive true
seed "WAU Wau Zonal Office" Offices "Title eq 'WAU'" \
  --Title "WAU" --OfficeName "Wau Zonal Office" --OfficeType "Zonal office" \
  --Country "South Sudan" --IsActive true

# ===========================================================================
# OfficeSharing                               source: admin.html tab 3
# "When a secondary office lacks stock, requests can be fulfilled from the
#  primary office." Primary (lends) → Secondary (borrows).
# ===========================================================================
echo "OfficeSharing…"
seed "JCO -> BOR" OfficeSharing "FromOfficeCode eq 'JCO' and ToOfficeCode eq 'BOR'" \
  --Title "JCO → BOR" --FromOfficeCode "JCO" --ToOfficeCode "BOR" --SharePriority 1 --IsActive true
seed "JCO -> MAL" OfficeSharing "FromOfficeCode eq 'JCO' and ToOfficeCode eq 'MAL'" \
  --Title "JCO → MAL" --FromOfficeCode "JCO" --ToOfficeCode "MAL" --SharePriority 1 --IsActive true
seed "JCO -> BEN" OfficeSharing "FromOfficeCode eq 'JCO' and ToOfficeCode eq 'BEN'" \
  --Title "JCO → BEN" --FromOfficeCode "JCO" --ToOfficeCode "BEN" --SharePriority 1 --IsActive true
seed "JCO -> WAU" OfficeSharing "FromOfficeCode eq 'JCO' and ToOfficeCode eq 'WAU'" \
  --Title "JCO → WAU" --FromOfficeCode "JCO" --ToOfficeCode "WAU" --SharePriority 1 --IsActive true

# ===========================================================================
# Catalogue
#
# Bor stock and thresholds:
#   admin.html tab 2 — A4 paper 64/25, whiteboard markers 2/5,
#                      archive boxes 0/4, fax toner 3/— (Discontinued)
#   review.html      — flipchart pads 0 in Bor (+15 in Juba CO),
#                      stapler heavy duty 5
#   distribute.html  — toner cartridge HP 26A available 7,
#                      archive boxes available 6  (see BOR_ARCHBOX_STOCK above)
#   receipt.html     — reveals ballpoint pens (box of 50), lever-arch files and
#                      desk tape dispenser exist at Bor, but states no stock
#
# The "Discontinued" badge is IsActive = false. "Low stock" and "Out of stock"
# are derived from StockQty vs ReorderLevel and are never stored.
# ===========================================================================
echo "Catalogue…"

seed "BOR A4 photocopy paper (ream)" Catalogue "ItemCode eq 'A4PAPER' and OfficeCode eq 'BOR'" \
  --Title "A4 photocopy paper (ream)" --ItemCode "A4PAPER" --OfficeCode "BOR" \
  --OfficeItemKey "BOR|A4PAPER" --UnitOfMeasure "Ream" \
  --StockQty 64 --ReorderLevel 25 --RowVersion 1 --IsActive true

seed "BOR Whiteboard markers (box of 10)" Catalogue "ItemCode eq 'WBMARKER' and OfficeCode eq 'BOR'" \
  --Title "Whiteboard markers (box of 10)" --ItemCode "WBMARKER" --OfficeCode "BOR" \
  --OfficeItemKey "BOR|WBMARKER" --UnitOfMeasure "Box of 10" \
  --StockQty 2 --ReorderLevel 5 --RowVersion 1 --IsActive true

seed "BOR Archive boxes (pack of 5)" Catalogue "ItemCode eq 'ARCHBOX' and OfficeCode eq 'BOR'" \
  --Title "Archive boxes (pack of 5)" --ItemCode "ARCHBOX" --OfficeCode "BOR" \
  --OfficeItemKey "BOR|ARCHBOX" --UnitOfMeasure "Pack of 5" \
  --StockQty "$BOR_ARCHBOX_STOCK" --ReorderLevel 4 --RowVersion 1 --IsActive true

# ReorderLevel omitted: admin.html shows "—" for this item.
seed "BOR Fax toner, Canon L100 (discontinued)" Catalogue "ItemCode eq 'FAXTONER-L100' and OfficeCode eq 'BOR'" \
  --Title "Fax toner, Canon L100" --ItemCode "FAXTONER-L100" --OfficeCode "BOR" \
  --OfficeItemKey "BOR|FAXTONER-L100" --UnitOfMeasure "Cartridge" \
  --StockQty 3 --RowVersion 1 --IsActive false

seed "BOR Flipchart pads" Catalogue "ItemCode eq 'FLIPCHART' and OfficeCode eq 'BOR'" \
  --Title "Flipchart pads" --ItemCode "FLIPCHART" --OfficeCode "BOR" \
  --OfficeItemKey "BOR|FLIPCHART" --UnitOfMeasure "Pad" \
  --StockQty 0 --RowVersion 1 --IsActive true

seed "BOR Stapler, heavy duty" Catalogue "ItemCode eq 'STAPLER-HD' and OfficeCode eq 'BOR'" \
  --Title "Stapler, heavy duty" --ItemCode "STAPLER-HD" --OfficeCode "BOR" \
  --OfficeItemKey "BOR|STAPLER-HD" --UnitOfMeasure "Each" \
  --StockQty 5 --RowVersion 1 --IsActive true

seed "BOR Toner cartridge, HP 26A" Catalogue "ItemCode eq 'TONER-HP26A' and OfficeCode eq 'BOR'" \
  --Title "Toner cartridge, HP 26A" --ItemCode "TONER-HP26A" --OfficeCode "BOR" \
  --OfficeItemKey "BOR|TONER-HP26A" --UnitOfMeasure "Cartridge" \
  --StockQty 7 --RowVersion 1 --IsActive true

# The next three appear only in receipt.html as delivered items. The mock-up gives
# no Bor stock figure for any of them.  # ASSUMED StockQty 0
seed "BOR Ballpoint pens, blue (box of 50)" Catalogue "ItemCode eq 'PEN-BLUE-50' and OfficeCode eq 'BOR'" \
  --Title "Ballpoint pens, blue (box of 50)" --ItemCode "PEN-BLUE-50" --OfficeCode "BOR" \
  --OfficeItemKey "BOR|PEN-BLUE-50" --UnitOfMeasure "Box of 50" \
  --StockQty 0 --RowVersion 1 --IsActive true

seed "BOR Lever-arch files" Catalogue "ItemCode eq 'LEVERARCH' and OfficeCode eq 'BOR'" \
  --Title "Lever-arch files" --ItemCode "LEVERARCH" --OfficeCode "BOR" \
  --OfficeItemKey "BOR|LEVERARCH" --UnitOfMeasure "Each" \
  --StockQty 0 --RowVersion 1 --IsActive true

seed "BOR Desk tape dispenser" Catalogue "ItemCode eq 'TAPEDISP' and OfficeCode eq 'BOR'" \
  --Title "Desk tape dispenser" --ItemCode "TAPEDISP" --OfficeCode "BOR" \
  --OfficeItemKey "BOR|TAPEDISP" --UnitOfMeasure "Each" \
  --StockQty 0 --RowVersion 1 --IsActive true

# The sharing-fallback row: review.html says "0 (+ 15 in Juba CO)".
seed "JCO Flipchart pads (15 — the sharing fallback)" Catalogue "ItemCode eq 'FLIPCHART' and OfficeCode eq 'JCO'" \
  --Title "Flipchart pads" --ItemCode "FLIPCHART" --OfficeCode "JCO" \
  --OfficeItemKey "JCO|FLIPCHART" --UnitOfMeasure "Pad" \
  --StockQty 15 --RowVersion 1 --IsActive true

# ===========================================================================
# ApprovalMatrix                              source: admin.html tab 1
#
# Bor, all sections, FOUR rows. There is deliberately NO 'Approval' row —
# that absence IS the skip rule, and it is why the journey rail strikes the
# Approval leg through and admin.html shows four steps.
#
# The Stage strings admin.html displays (SUBMIT → Review, REVIEW → Confirm,
# CONFIRM → Distribute, DISTRIBUTE → Receipt) are DERIVED at render time from
# <previous active stage> → <this stage>. They are never stored.
# ===========================================================================
echo "ApprovalMatrix (Bor, 4 rows, no Approval row)…"

person_reset
person Approver "$UPN_DENG_MACHAR"
person OIC      "$UPN_GRACE_ALUEL"
seed "BOR step 1 · Review · Deng Machar (OIC Grace Aluel)" ApprovalMatrix \
  "OfficeCode eq 'BOR' and Section eq 'All sections' and StageOrder eq 1" \
  --Title "BOR · Review" --OfficeCode "BOR" --Section "All sections" \
  --MatrixKey "BOR|All sections" --StageCode "Review" --StageOrder 1 \
  --ActorRoleCode "Reviewer" \
  --ApproverEmail "$UPN_DENG_MACHAR" --OICEmail "$UPN_GRACE_ALUEL" --IsActive true

person_reset
person Approver "$UPN_REBECCA_ACHOL"
person OIC      "$UPN_PETER_GATLUAK"
seed "BOR step 2 · Confirm · Rebecca Achol (OIC Peter Gatluak)" ApprovalMatrix \
  "OfficeCode eq 'BOR' and Section eq 'All sections' and StageOrder eq 2" \
  --Title "BOR · Confirm" --OfficeCode "BOR" --Section "All sections" \
  --MatrixKey "BOR|All sections" --StageCode "Confirm" --StageOrder 2 \
  --ActorRoleCode "Chief Field Office" \
  --ApproverEmail "$UPN_REBECCA_ACHOL" --OICEmail "$UPN_PETER_GATLUAK" --IsActive true

person_reset
person Approver "$UPN_SIMON_MAJOK"
person OIC      "$UPN_MARY_NYALUAK"
seed "BOR step 3 · Deliver · Simon Majok (OIC Mary Nyaluak)" ApprovalMatrix \
  "OfficeCode eq 'BOR' and Section eq 'All sections' and StageOrder eq 3" \
  --Title "BOR · Deliver" --OfficeCode "BOR" --Section "All sections" \
  --MatrixKey "BOR|All sections" --StageCode "Deliver" --StageOrder 3 \
  --ActorRoleCode "Storekeeper" \
  --ApproverEmail "$UPN_SIMON_MAJOK" --OICEmail "$UPN_MARY_NYALUAK" --IsActive true

# Step 4 has no named person and no OIC — admin.html shows "Requester (originator)"
# and "—". ActorRoleCode is what tells the app to route to the request's originator.
seed "BOR step 4 · Receive · Requester (originator)" ApprovalMatrix \
  "OfficeCode eq 'BOR' and Section eq 'All sections' and StageOrder eq 4" \
  --Title "BOR · Receive" --OfficeCode "BOR" --Section "All sections" \
  --MatrixKey "BOR|All sections" --StageCode "Receive" --StageOrder 4 \
  --ActorRoleCode "Requester" --IsActive true

# ===========================================================================
# AppRoles
# Sources: the .nav-user block on every page, plus admin.html tab 1.
#   index.html / request-detail.html / review.html — Deng Machar, Reviewer
#   receipt.html                                   — Deng Machar, Requester
#   new-request.html                               — Nyandeng Akol, Requester
#   distribute.html                                — Simon Majok, Storekeeper
#   admin.html / reports.html                      — Emmanuel Wani, Administrator
#   admin.html tab 1                               — Rebecca Achol (CFO), and the
#                                                    three OICs Grace Aluel,
#                                                    Peter Gatluak, Mary Nyaluak
#   index.html "Awaiting my action"                — Sarah Ayen, John Lado,
#                                                    Josephine Poni (requesters)
# Office assignment is ASSUMED Bor for everyone except Emmanuel Wani, whose
# nav reads "All offices"; he is seeded against JCO.
# ===========================================================================
echo "AppRoles…"
role() { # <label> <displayName> <upn> <officeCode> <roleCode>
  seed "$1" AppRoles "UserEmail eq '$3' and RoleCode eq '$5'" \
    --Title "$2" --UserEmail "$3" --OfficeCode "$4" --RoleCode "$5" --IsActive true
}
role "Deng Machar · Reviewer"          "Deng Machar"   "$UPN_DENG_MACHAR"  BOR "Reviewer"
role "Deng Machar · Requester"         "Deng Machar"   "$UPN_DENG_MACHAR"  BOR "Requester"
role "Nyandeng Akol · Requester"           "Nyandeng Akol"     "$UPN_NYANDENG_AKOL"    BOR "Requester"
role "Sarah Ayen · Requester"           "Sarah Ayen"     "$UPN_SARAH_AYEN"    BOR "Requester"
role "John Lado · Requester"           "John Lado"     "$UPN_JOHN_LADO"    BOR "Requester"
role "Josephine Poni · Requester"         "Josephine Poni"   "$UPN_JOSEPHINE_PONI"  BOR "Requester"
role "Grace Aluel · Reviewer (OIC)"      "Grace Aluel"     "$UPN_GRACE_ALUEL"    BOR "Reviewer"
role "Rebecca Achol · Chief Field Office"  "Rebecca Achol"     "$UPN_REBECCA_ACHOL"    BOR "Chief Field Office"
role "Peter Gatluak · CFO (OIC)"        "Peter Gatluak"  "$UPN_PETER_GATLUAK" BOR "Chief Field Office"
role "Simon Majok · Storekeeper"       "Simon Majok"   "$UPN_SIMON_MAJOK"  BOR "Storekeeper"
role "Mary Nyaluak · Storekeeper (OIC)"  "Mary Nyaluak"    "$UPN_MARY_NYALUAK"   BOR "Storekeeper"
role "Emmanuel Wani · Administrator"      "Emmanuel Wani"    "$UPN_EMMANUEL_WANI"   JCO "Administrator"

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

# --- 1. SR-202607-0038 — Nyandeng Akol, Programme, 5 items, Submitted, held 4 days
person_reset
person Requester    "$UPN_NYANDENG_AKOL"
person CurrentlyWith "$UPN_DENG_MACHAR"
seed "SR-202607-0038" Requests "Title eq 'SR-202607-0038'" \
  --Title "SR-202607-0038" --OfficeCode "BOR" --Section "Programme" \
  --RequesterEmail "$UPN_NYANDENG_AKOL" \
  --CurrentlyWithEmail "$UPN_DENG_MACHAR" --CurrentlyWithOICEmail "$UPN_GRACE_ALUEL" \
  --Status "Submitted" --StatusRank 20 --CurrentStageCode "Review" --Purpose "Internal" \
  --SubmittedOn "2026-07-11 09:14:00" \
  --LineCount 5 --TotalQtyRequested 62 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0

# --- 2. SR-202607-0042 — Sarah Ayen, Child Protection, 3 items, held 2 days
person_reset
person Requester    "$UPN_SARAH_AYEN"
person CurrentlyWith "$UPN_DENG_MACHAR"
seed "SR-202607-0042" Requests "Title eq 'SR-202607-0042'" \
  --Title "SR-202607-0042" --OfficeCode "BOR" --Section "Child Protection" \
  --RequesterEmail "$UPN_SARAH_AYEN" \
  --CurrentlyWithEmail "$UPN_DENG_MACHAR" --CurrentlyWithOICEmail "$UPN_GRACE_ALUEL" \
  --Status "Submitted" --StatusRank 20 --CurrentStageCode "Review" --Purpose "Internal" \
  --SubmittedOn "2026-07-13 09:00:00" \
  --LineCount 3 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0
  # SubmittedOn and Purpose ASSUMED — index.html gives only "2 days" held.

# --- 3. SR-202607-0044 — John Lado, Health & Nutrition, 2 items, held 1 day
person_reset
person Requester    "$UPN_JOHN_LADO"
person CurrentlyWith "$UPN_DENG_MACHAR"
seed "SR-202607-0044" Requests "Title eq 'SR-202607-0044'" \
  --Title "SR-202607-0044" --OfficeCode "BOR" --Section "Health & Nutrition" \
  --RequesterEmail "$UPN_JOHN_LADO" \
  --CurrentlyWithEmail "$UPN_DENG_MACHAR" --CurrentlyWithOICEmail "$UPN_GRACE_ALUEL" \
  --Status "Submitted" --StatusRank 20 --CurrentStageCode "Review" --Purpose "Internal" \
  --SubmittedOn "2026-07-14 09:00:00" \
  --LineCount 2 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0

# --- 4. SR-202607-0045 — Josephine Poni, Operations, 7 items, held 4 hours
person_reset
person Requester    "$UPN_JOSEPHINE_PONI"
person CurrentlyWith "$UPN_DENG_MACHAR"
seed "SR-202607-0045" Requests "Title eq 'SR-202607-0045'" \
  --Title "SR-202607-0045" --OfficeCode "BOR" --Section "Operations" \
  --RequesterEmail "$UPN_JOSEPHINE_PONI" \
  --CurrentlyWithEmail "$UPN_DENG_MACHAR" --CurrentlyWithOICEmail "$UPN_GRACE_ALUEL" \
  --Status "Submitted" --StatusRank 20 --CurrentStageCode "Review" --Purpose "Internal" \
  --SubmittedOn "2026-07-15 05:14:00" \
  --LineCount 7 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0

# --- 5. SR-202607-0029 — Deng Machar's own, 3 Jul 2026, 4 items, Fully delivered
#        receipt.html: delivered by Simon Majok on 13 Jul 2026; 10+2+12+1 = 25.
person_reset
person Requester    "$UPN_DENG_MACHAR"
person CurrentlyWith "$UPN_DENG_MACHAR"
seed "SR-202607-0029" Requests "Title eq 'SR-202607-0029'" \
  --Title "SR-202607-0029" --OfficeCode "BOR" --Section "Operations" \
  --RequesterEmail "$UPN_DENG_MACHAR" \
  --CurrentlyWithEmail "$UPN_DENG_MACHAR" \
  --Status "Fully delivered" --StatusRank 50 --CurrentStageCode "Receive" --Purpose "Internal" \
  --SubmittedOn "2026-07-03 09:00:00" \
  --LineCount 4 --TotalQtyRequested 25 --TotalQtyApproved 25 --TotalQtyDistributed 25 --TotalQtyReceived 0
  # Time of day ASSUMED (index.html gives the date only). Requested = delivered
  # ASSUMED, since the request is "Fully delivered".

# --- 6. SR-202607-0035 — Deng Machar's own, 8 Jul 2026, 2 items, Reviewed
#        distribute.html: with Simon Majok; confirmed by Rebecca Achol 14 Jul 2026.
person_reset
person Requester    "$UPN_DENG_MACHAR"
person CurrentlyWith "$UPN_SIMON_MAJOK"
seed "SR-202607-0035" Requests "Title eq 'SR-202607-0035'" \
  --Title "SR-202607-0035" --OfficeCode "BOR" --Section "Operations" \
  --RequesterEmail "$UPN_DENG_MACHAR" \
  --CurrentlyWithEmail "$UPN_SIMON_MAJOK" --CurrentlyWithOICEmail "$UPN_MARY_NYALUAK" \
  --Status "Reviewed" --StatusRank 30 --CurrentStageCode "Deliver" --Purpose "Internal" \
  --SubmittedOn "2026-07-08 09:00:00" \
  --LineCount 2 --TotalQtyRequested 13 --TotalQtyApproved 13 --TotalQtyDistributed 0 --TotalQtyReceived 0

# --- 7. SR-202607-0040 — Deng Machar's own, 10 Jul 2026, 1 item, Returned
#        Return is blocked on an empty reason, so one is required here.
#        reports.html attributes returns to "mostly missing purpose detail".
person_reset
person Requester    "$UPN_DENG_MACHAR"
person CurrentlyWith "$UPN_DENG_MACHAR"
seed "SR-202607-0040" Requests "Title eq 'SR-202607-0040'" \
  --Title "SR-202607-0040" --OfficeCode "BOR" --Section "Operations" \
  --RequesterEmail "$UPN_DENG_MACHAR" \
  --CurrentlyWithEmail "$UPN_DENG_MACHAR" \
  --Status "Returned" --StatusRank 15 --Purpose "Internal" \
  --SubmittedOn "2026-07-10 09:00:00" \
  --LineCount 1 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0 \
  --ReturnReason "Purpose detail is missing — please state the intended use and resubmit."
  # ReturnReason text ASSUMED; the mock-up shows no wording for this request.

# --- 8. SR-202606-0114 — 26 Jun 2026, 6 items, Partial delivery, with Simon Majok
person_reset
person Requester    "$UPN_DENG_MACHAR"
person CurrentlyWith "$UPN_SIMON_MAJOK"
seed "SR-202606-0114" Requests "Title eq 'SR-202606-0114'" \
  --Title "SR-202606-0114" --OfficeCode "BOR" --Section "Operations" \
  --RequesterEmail "$UPN_DENG_MACHAR" \
  --CurrentlyWithEmail "$UPN_SIMON_MAJOK" --CurrentlyWithOICEmail "$UPN_MARY_NYALUAK" \
  --Status "Partial delivery" --StatusRank 40 --CurrentStageCode "Deliver" --Purpose "Internal" \
  --SubmittedOn "2026-06-26 09:00:00" \
  --LineCount 6 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0
  # Lines for this request are not in the mock-up — header only.

# --- 9. SR-202606-0102 — 19 Jun 2026, 3 items, Fully received, currently with "—"
person_reset
person Requester "$UPN_DENG_MACHAR"
seed "SR-202606-0102" Requests "Title eq 'SR-202606-0102'" \
  --Title "SR-202606-0102" --OfficeCode "BOR" --Section "Operations" \
  --RequesterEmail "$UPN_DENG_MACHAR" \
  --Status "Fully received" --StatusRank 60 --CurrentStageCode "Receive" --Purpose "Internal" \
  --SubmittedOn "2026-06-19 09:00:00" \
  --LineCount 3 --TotalQtyRequested 0 --TotalQtyApproved 0 --TotalQtyDistributed 0 --TotalQtyReceived 0

# --- 10. SR-202605-0087 — 28 May 2026, 2 items, Closed
person_reset
person Requester "$UPN_DENG_MACHAR"
seed "SR-202605-0087" Requests "Title eq 'SR-202605-0087'" \
  --Title "SR-202605-0087" --OfficeCode "BOR" --Section "Operations" \
  --RequesterEmail "$UPN_DENG_MACHAR" \
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
  --Title "SR-202607-0038-01" --RequestRefNo "SR-202607-0038" --OfficeCode "BOR" --LineNo 1 \
  --ItemCode "A4PAPER" --ItemName "A4 photocopy paper (ream)" --IsCatalogueItem true \
  --OfficeItemKey "BOR|A4PAPER" --UnitOfMeasure "Ream" --LinePurpose "Training workshop" \
  --QtyRequested 20 --QtyApproved 0 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

seed "SR-202607-0038 line 2 · Whiteboard markers (box of 10)" RequestItems \
  "RequestRefNo eq 'SR-202607-0038' and LineNo eq 2" \
  --Title "SR-202607-0038-02" --RequestRefNo "SR-202607-0038" --OfficeCode "BOR" --LineNo 2 \
  --ItemCode "WBMARKER" --ItemName "Whiteboard markers (box of 10)" --IsCatalogueItem true \
  --OfficeItemKey "BOR|WBMARKER" --UnitOfMeasure "Box of 10" --LinePurpose "Training workshop" \
  --QtyRequested 4 --QtyApproved 0 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

seed "SR-202607-0038 line 3 · Flipchart pads" RequestItems \
  "RequestRefNo eq 'SR-202607-0038' and LineNo eq 3" \
  --Title "SR-202607-0038-03" --RequestRefNo "SR-202607-0038" --OfficeCode "BOR" --LineNo 3 \
  --ItemCode "FLIPCHART" --ItemName "Flipchart pads" --IsCatalogueItem true \
  --OfficeItemKey "BOR|FLIPCHART" --UnitOfMeasure "Pad" --LinePurpose "Training workshop" \
  --QtyRequested 6 --QtyApproved 0 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"
  # SourceOfficeCode is deliberately NOT stamped yet — the JCO fallback is chosen
  # on the Review screen, which has not been saved for this request.

seed "SR-202607-0038 line 4 · Stapler, heavy duty" RequestItems \
  "RequestRefNo eq 'SR-202607-0038' and LineNo eq 4" \
  --Title "SR-202607-0038-04" --RequestRefNo "SR-202607-0038" --OfficeCode "BOR" --LineNo 4 \
  --ItemCode "STAPLER-HD" --ItemName "Stapler, heavy duty" --IsCatalogueItem true \
  --OfficeItemKey "BOR|STAPLER-HD" --UnitOfMeasure "Each" --LinePurpose "Section office" \
  --QtyRequested 2 --QtyApproved 0 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

# The free-text line: "Field notebooks, A5 (free text)". No ItemCode, no
# OfficeItemKey, IsCatalogueItem = false. review.html: "Not a catalogue item —
# cannot be stocked".
seed "SR-202607-0038 line 5 · Field notebooks, A5 (free text)" RequestItems \
  "RequestRefNo eq 'SR-202607-0038' and LineNo eq 5" \
  --Title "SR-202607-0038-05" --RequestRefNo "SR-202607-0038" --OfficeCode "BOR" --LineNo 5 \
  --ItemName "Field notebooks, A5" --IsCatalogueItem false --LinePurpose "Monitoring visits" \
  --QtyRequested 30 --QtyApproved 0 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

# --- SR-202607-0035, 2 lines           source: distribute.html
#     "Approved qty" 3 and 10. The originally requested quantities are not shown;
#     ASSUMED equal to approved.
seed "SR-202607-0035 line 1 · Toner cartridge, HP 26A" RequestItems \
  "RequestRefNo eq 'SR-202607-0035' and LineNo eq 1" \
  --Title "SR-202607-0035-01" --RequestRefNo "SR-202607-0035" --OfficeCode "BOR" --LineNo 1 \
  --ItemCode "TONER-HP26A" --ItemName "Toner cartridge, HP 26A" --IsCatalogueItem true \
  --OfficeItemKey "BOR|TONER-HP26A" --UnitOfMeasure "Cartridge" \
  --QtyRequested 3 --QtyApproved 3 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

seed "SR-202607-0035 line 2 · Archive boxes (pack of 5)" RequestItems \
  "RequestRefNo eq 'SR-202607-0035' and LineNo eq 2" \
  --Title "SR-202607-0035-02" --RequestRefNo "SR-202607-0035" --OfficeCode "BOR" --LineNo 2 \
  --ItemCode "ARCHBOX" --ItemName "Archive boxes (pack of 5)" --IsCatalogueItem true \
  --OfficeItemKey "BOR|ARCHBOX" --UnitOfMeasure "Pack of 5" \
  --QtyRequested 10 --QtyApproved 10 --QtyDistributed 0 --QtyReceived 0 --LineStatus "Pending"

# --- SR-202607-0029, 4 lines           source: receipt.html
#     Status is "Fully delivered", so QtyDistributed is set and QtyReceived is 0.
#     Requested/approved ASSUMED equal to delivered.
seed "SR-202607-0029 line 1 · A4 photocopy paper (ream)" RequestItems \
  "RequestRefNo eq 'SR-202607-0029' and LineNo eq 1" \
  --Title "SR-202607-0029-01" --RequestRefNo "SR-202607-0029" --OfficeCode "BOR" --LineNo 1 \
  --ItemCode "A4PAPER" --ItemName "A4 photocopy paper (ream)" --IsCatalogueItem true \
  --OfficeItemKey "BOR|A4PAPER" --UnitOfMeasure "Ream" \
  --QtyRequested 10 --QtyApproved 10 --QtyDistributed 10 --QtyReceived 0 --LineStatus "Fully distributed"

seed "SR-202607-0029 line 2 · Ballpoint pens, blue (box of 50)" RequestItems \
  "RequestRefNo eq 'SR-202607-0029' and LineNo eq 2" \
  --Title "SR-202607-0029-02" --RequestRefNo "SR-202607-0029" --OfficeCode "BOR" --LineNo 2 \
  --ItemCode "PEN-BLUE-50" --ItemName "Ballpoint pens, blue (box of 50)" --IsCatalogueItem true \
  --OfficeItemKey "BOR|PEN-BLUE-50" --UnitOfMeasure "Box of 50" \
  --QtyRequested 2 --QtyApproved 2 --QtyDistributed 2 --QtyReceived 0 --LineStatus "Fully distributed"

seed "SR-202607-0029 line 3 · Lever-arch files" RequestItems \
  "RequestRefNo eq 'SR-202607-0029' and LineNo eq 3" \
  --Title "SR-202607-0029-03" --RequestRefNo "SR-202607-0029" --OfficeCode "BOR" --LineNo 3 \
  --ItemCode "LEVERARCH" --ItemName "Lever-arch files" --IsCatalogueItem true \
  --OfficeItemKey "BOR|LEVERARCH" --UnitOfMeasure "Each" \
  --QtyRequested 12 --QtyApproved 12 --QtyDistributed 12 --QtyReceived 0 --LineStatus "Fully distributed"

seed "SR-202607-0029 line 4 · Desk tape dispenser" RequestItems \
  "RequestRefNo eq 'SR-202607-0029' and LineNo eq 4" \
  --Title "SR-202607-0029-04" --RequestRefNo "SR-202607-0029" --OfficeCode "BOR" --LineNo 4 \
  --ItemCode "TAPEDISP" --ItemName "Desk tape dispenser" --IsCatalogueItem true \
  --OfficeItemKey "BOR|TAPEDISP" --UnitOfMeasure "Each" \
  --QtyRequested 1 --QtyApproved 1 --QtyDistributed 1 --QtyReceived 0 --LineStatus "Fully distributed"

# ===========================================================================
# RequestComments                             source: request-detail.html tab 2
# ===========================================================================
echo "RequestComments…"

person_reset
person CommentAuthor "$UPN_NYANDENG_AKOL"
seed "SR-202607-0038 comment · Nyandeng Akol" RequestComments \
  "RequestRefNo eq 'SR-202607-0038' and AuthorEmail eq '$UPN_NYANDENG_AKOL'" \
  --Title "SR-202607-0038" --RequestRefNo "SR-202607-0038" \
  --CommentText "The workshop starts on 21 July — grateful if this can be reviewed this week." \
  --AuthorEmail "$UPN_NYANDENG_AKOL" --PostedOn "2026-07-11 09:20:00"

person_reset
person CommentAuthor "$UPN_DENG_MACHAR"
seed "SR-202607-0038 comment · Deng Machar" RequestComments \
  "RequestRefNo eq 'SR-202607-0038' and AuthorEmail eq '$UPN_DENG_MACHAR'" \
  --Title "SR-202607-0038" --RequestRefNo "SR-202607-0038" \
  --CommentText "Noted. Checking marker stock — we may substitute the box size." \
  --AuthorEmail "$UPN_DENG_MACHAR" --PostedOn "2026-07-12 11:03:00"

# ===========================================================================
# RequestTimeline                             source: request-detail.html tab 1
# Rendered newest-first in the mock-up; seeded oldest-first.
# ===========================================================================
echo "RequestTimeline…"

person_reset
person Actor "$UPN_NYANDENG_AKOL"
seed "SR-202607-0038 timeline · Draft created" RequestTimeline \
  "RequestRefNo eq 'SR-202607-0038' and EventType eq 'Draft created'" \
  --Title "Draft created" --RequestRefNo "SR-202607-0038" --EventType "Draft created" \
  --ToStatus "Draft" --ActorEmail "$UPN_NYANDENG_AKOL" --OccurredOn "2026-07-10 16:42:00"

person_reset
person Actor "$UPN_NYANDENG_AKOL"
seed "SR-202607-0038 timeline · Request submitted" RequestTimeline \
  "RequestRefNo eq 'SR-202607-0038' and EventType eq 'Submitted'" \
  --Title "Request submitted" --RequestRefNo "SR-202607-0038" --EventType "Submitted" \
  --FromStatus "Draft" --ToStatus "Submitted" --StageCode "Review" \
  --ActorEmail "$UPN_NYANDENG_AKOL" --OccurredOn "2026-07-11 09:14:00" \
  --Detail "reference SR-202607-0038 issued"

# A system event: no actor.
seed "SR-202607-0038 timeline · Routed to Reviewer" RequestTimeline \
  "RequestRefNo eq 'SR-202607-0038' and EventType eq 'Routed'" \
  --Title "Routed to Reviewer" --RequestRefNo "SR-202607-0038" --EventType "Routed" \
  --ToStatus "Submitted" --StageCode "Review" --OccurredOn "2026-07-11 09:14:00" \
  --Detail "assigned to Deng Machar (OIC: Grace Aluel)"

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
    --UploadedByEmail "$UPN_NYANDENG_AKOL" --output none \
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
