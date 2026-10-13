#!/usr/bin/env bash
#
# 01-lists.sh — create the 12 SharePoint lists/libraries for the Office Supplies app.
#
# Run order is strict:   01-lists.sh  →  02-fields.sh  →  03-seed.sh
# All indexed columns must exist before any seeding, because SharePoint refuses to
# add an index to a list that is already over 5000 items.
#
# Schema contract: ../docs/schema.md
#
set -euo pipefail

SITE_URL="${SITE_URL:-https://trailanalyticslimited602.sharepoint.com/sites/OfficeSupplies}"

MAJOR_VERSION_LIMIT="${MAJOR_VERSION_LIMIT:-50}"

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

echo "Site:    $SITE_URL"
echo "Signed in as: $(m365 status --output text 2>/dev/null | head -5 | tr '\n' ' ')"
echo

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# list_exists <title>
list_exists() {
  m365 spo list get --webUrl "$SITE_URL" --title "$1" --output none >/dev/null 2>&1
}

# add_list <title> <baseTemplate> <description> [extra m365 args...]
add_list() {
  local title="$1"; shift
  local template="$1"; shift
  local description="$1"; shift

  if list_exists "$title"; then
    echo "  = $title — already exists, skipping"
    return 0
  fi

  echo "  + $title ($template)"
  if ! m365 spo list add \
        --webUrl "$SITE_URL" \
        --title "$title" \
        --baseTemplate "$template" \
        --description "$description" \
        --output none "$@"; then
    if list_exists "$title"; then
      echo "  = $title — already exists (created concurrently), continuing"
      return 0
    fi
    echo "  ! FAILED to create list: $title" >&2
    return 1
  fi
}

# A plain data list: versioned, no attachments.
add_data_list() {
  add_list "$1" GenericList "$2" \
    --enableVersioning true \
    --majorVersionLimit "$MAJOR_VERSION_LIMIT" \
    --enableAttachments false
}

# ---------------------------------------------------------------------------
# The 12 lists
# ---------------------------------------------------------------------------
echo "Creating lists…"

add_data_list "Offices" \
  "Offices and their codes. Title = the office code (JCO, BOR, MAL, BEN, WAU)."

add_data_list "OfficeSharing" \
  "Supply-sharing links. When a secondary office lacks stock, requests can be fulfilled from the primary office."

add_data_list "Catalogue" \
  "Per-office catalogue and stock cache. StockQty is a cache; StockLedger is the truth."

add_data_list "StockLedger" \
  "Append-only stock movement ledger with a running balance. Expected to exceed 5000 items."

add_data_list "ApprovalMatrix" \
  "Per-office, per-section approval chain. Up to 5 rows per MatrixKey. A stage is skipped iff no active row exists for it."

add_data_list "Requests" \
  "Supply requests. Title is the reference (SR-YYYYMM-NNNN) and is unique."

add_data_list "RequestItems" \
  "Request lines. Carries a snapshot of the catalogue item at line-creation time."

add_data_list "RequestComments" \
  "Comments on a request, visible to everyone on that request."

add_data_list "RequestTimeline" \
  "Append-only audit timeline of every state change on a request."

# A document LIBRARY, not a list with attachments — attachments cannot be queried
# across items. Attachments are irrelevant here; versioning is major-only.
add_list "RequestDocuments" DocumentLibrary \
  "Documents attached to requests. A library, not attachments, so documents can be queried across requests." \
  --enableVersioning true \
  --enableMinorVersions false \
  --majorVersionLimit "$MAJOR_VERSION_LIMIT"

add_data_list "AppRoles" \
  "Which role each person holds in which office. One person may hold several."

add_data_list "RefCounter" \
  "Reference-number counter. Title = YYYYMM, LastSeq = highest sequence minted that month."

echo
echo "Done. 12 lists/libraries present."
echo "Next: bash provision/02-fields.sh"
