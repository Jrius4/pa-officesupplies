#!/usr/bin/env bash
#
# 05-zonal-offices.sh — bring an ALREADY-SEEDED site onto the UNICEF South Sudan
# zonal-office structure, in place.
#
#   Offices.OfficeType choices  + "Zonal office"  (Headquarters, Zonal office, Field office)
#   BOR Bor Field Office        ->  Bor Zonal Office      (type Zonal office)
#   MAL Malakal Field Office    ->  Malakal Zonal Office  (type Zonal office)
#
# Office codes do not change, so no key rewrite is needed (contrast 04).
#
# Why a migration: 02-fields.sh skips fields that already exist and 03-seed.sh
# skips rows that already exist, so re-running them leaves the old choice set and
# the old BOR / MAL names in place.
#
# Run order on an existing site:
#   ./04-relocate-ke-to-ss.sh   (only if the site still carries the Kenya narrative)
#   ./05-zonal-offices.sh
#   ./03-seed.sh                (adds BEN, WAU and JCO → BEN / JCO → WAU)
#
# Safe to run twice: every write is conditional on the value actually changing,
# so a second pass reports 0 updates.
#
# DRY RUN BY DEFAULT. Nothing is written until you pass DRY_RUN=0.
#
#   ./05-zonal-offices.sh            # report what would change
#   DRY_RUN=0 ./05-zonal-offices.sh  # apply it
#
# Schema contract: ../docs/schema.md
#
set -euo pipefail

SITE_URL="${SITE_URL:-https://trailanalyticslimited602.sharepoint.com/sites/OfficeSupplies}"
DRY_RUN="${DRY_RUN:-1}"

if ! command -v m365 >/dev/null 2>&1; then
  echo "m365 (CLI for Microsoft 365) is not on PATH." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required (used to read JSON)." >&2
  exit 1
fi

updated=0

# ---------------------------------------------------------------------------
# 1. OfficeType choices. Verbatim order from 02-fields.sh.
# ---------------------------------------------------------------------------
CHOICES_JSON='["Headquarters","Zonal office","Field office"]'

echo "── Offices.OfficeType choices"
current="$(m365 spo field get --webUrl "$SITE_URL" --listTitle Offices \
             --internalName OfficeType --output json \
           | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin).get("Choices") or []))')"

if [ "$current" = "$CHOICES_JSON" ]; then
  echo "   = already $current"
else
  echo "   $current  ->  $CHOICES_JSON"
  updated=$((updated + 1))
  if [ "$DRY_RUN" = "0" ]; then
    # `spo field set` passes properties as strings; Choices is a collection, so
    # MERGE it through the REST API instead.
    body="$(python3 -c '
import json, sys
print(json.dumps({
    "__metadata": {"type": "SP.FieldChoice"},
    "Choices": {"__metadata": {"type": "Collection(Edm.String)"},
                "results": json.loads(sys.argv[1])},
}))' "$CHOICES_JSON")"
    if ! m365 request \
           --url "$SITE_URL/_api/web/lists/getbytitle('Offices')/fields/getbyinternalnameortitle('OfficeType')" \
           --method post \
           --accept 'application/json;odata=nometadata' \
           --content-type 'application/json;odata=verbose' \
           --x-http-method MERGE \
           --if-match '*' \
           --body "$body" >/dev/null; then
      echo "   ! FAILED to update Offices.OfficeType choices" >&2
      exit 1
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 2. BOR and MAL rows.
# ---------------------------------------------------------------------------
echo "── Offices rows"
rows="$(m365 spo listitem list --webUrl "$SITE_URL" --listTitle Offices \
          --fields "Id,Title,OfficeName,OfficeType" --output json)"

# code<TAB>new name<TAB>new type
TARGETS=$'BOR\tBor Zonal Office\tZonal office\nMAL\tMalakal Zonal Office\tZonal office'

while IFS=$'\t' read -r code name type; do
  row="$(printf '%s' "$rows" | python3 -c '
import json, sys
for r in json.load(sys.stdin):
    if r.get("Title") == sys.argv[1]:
        print("%s\t%s\t%s" % (r.get("Id") or r.get("ID"), r.get("OfficeName") or "", r.get("OfficeType") or ""))
        break
' "$code")"
  if [ -z "$row" ]; then
    echo "   - $code not present — 03-seed.sh will create it"
    continue
  fi
  IFS=$'\t' read -r id old_name old_type <<< "$row"
  if [ "$old_name" = "$name" ] && [ "$old_type" = "$type" ]; then
    echo "   = $code already $name / $type"
    continue
  fi
  echo "   ${id}  $code: $old_name / $old_type  ->  $name / $type"
  updated=$((updated + 1))
  if [ "$DRY_RUN" = "0" ]; then
    if ! m365 spo listitem set --webUrl "$SITE_URL" --listTitle Offices --id "$id" \
           --OfficeName "$name" --OfficeType "$type" --output none; then
      echo "   ! FAILED to set Offices#$id" >&2
    fi
  fi
done <<< "$TARGETS"

echo
echo "──────────────────────────────────────────────────────────────"
if [ "$DRY_RUN" = "0" ]; then
  echo "Applied $updated update(s). Now run ./03-seed.sh to add BEN and WAU."
else
  echo "DRY RUN — $updated update(s) would be applied."
  echo "Re-run with DRY_RUN=0 to write them."
fi
