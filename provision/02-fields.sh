#!/usr/bin/env bash
#
# 02-fields.sh — create every column on the 12 lists, from CAML.
#
# Run order is strict:   01-lists.sh  →  02-fields.sh  →  03-seed.sh
#
# WHY CAML AND NOT THE WEB UI: creating a column called "Office code" through the
# browser gives it the internal name Office_x0020_Code. Almost every "delegation
# randomly stopped working" report traces to exactly that. Every field below is
# created with --options AddFieldInternalNameHint and an explicit
# Name=/StaticName= pair, so the internal name is clean PascalCase.
#
# WHY INDEXES ARE INLINE: SharePoint refuses to add an index to a list already over
# 5000 items. Every Indexed="TRUE" below must therefore land before 03-seed.sh runs.
#
# There are ZERO Lookup columns in this file, by design. Relationships use shadow
# text keys (RequestRefNo, OfficeCode, OfficeItemKey, MatrixKey).
#
# Schema contract: ../docs/schema.md
#
set -euo pipefail

SITE_URL="${SITE_URL:-https://trailanalyticslimited602.sharepoint.com/sites/OfficeSupplies}"

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

echo "Site: $SITE_URL"
echo

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# field_exists <listTitle> <internalName>
field_exists() {
  m365 spo field get --webUrl "$SITE_URL" --listTitle "$1" --internalName "$2" --output none >/dev/null 2>&1
}

# fld <listTitle> <internalName> <camlXml>
fld() {
  local list="$1" internal="$2" xml="$3"
  if field_exists "$list" "$internal"; then
    echo "  = $list.$internal — already exists, skipping"
    return 0
  fi
  echo "  + $list.$internal"
  if ! m365 spo field add \
        --webUrl "$SITE_URL" \
        --listTitle "$list" \
        --options AddFieldInternalNameHint \
        --xml "$xml" \
        --output none; then
    if field_exists "$list" "$internal"; then
      echo "  = $list.$internal — already exists (created concurrently), continuing"
      return 0
    fi
    echo "  ! FAILED: $list.$internal" >&2
    return 1
  fi
}

# set_title_field <listTitle> <displayName> <required:true|false> <indexed:true|false> <unique:true|false>
#
# Title is the SharePoint built-in and cannot be created with 'spo field add'. Where
# a list uses it as a real key it is reconfigured here. Indexed is set BEFORE
# EnforceUniqueValues, because SharePoint requires the index to exist first.
set_title_field() {
  local list="$1" display="$2" required="$3" indexed="$4" unique="$5"
  echo "  ~ $list.Title -> '$display' (required=$required indexed=$indexed unique=$unique)"
  m365 spo field set --webUrl "$SITE_URL" --listTitle "$list" --internalName Title \
    --Title "$display" --Required "$required" --Indexed "$indexed" --output none \
    || { echo "  ! FAILED to reconfigure $list.Title" >&2; return 1; }
  if [ "$unique" = "true" ]; then
    m365 spo field set --webUrl "$SITE_URL" --listTitle "$list" --internalName Title \
      --EnforceUniqueValues true --output none \
      || { echo "  ! FAILED to set EnforceUniqueValues on $list.Title" >&2; return 1; }
  fi
}

# ===========================================================================
# 1. Offices
# ===========================================================================
echo "Offices…"
set_title_field "Offices" "Office code" true true false
fld Offices OfficeName '<Field Type="Text" DisplayName="Office name" Name="OfficeName" StaticName="OfficeName" Required="TRUE" MaxLength="255"/>'
fld Offices OfficeType '<Field Type="Choice" DisplayName="Office type" Name="OfficeType" StaticName="OfficeType" Required="TRUE" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Headquarters</CHOICE><CHOICE>Field office</CHOICE></CHOICES></Field>'
fld Offices Country '<Field Type="Text" DisplayName="Country" Name="Country" StaticName="Country" MaxLength="255"/>'
fld Offices IsActive '<Field Type="Boolean" DisplayName="Active" Name="IsActive" StaticName="IsActive"><Default>1</Default></Field>'

# ===========================================================================
# 2. OfficeSharing
# ===========================================================================
echo "OfficeSharing…"
set_title_field "OfficeSharing" "Sharing link" true false false
fld OfficeSharing FromOfficeCode '<Field Type="Text" DisplayName="From office code" Name="FromOfficeCode" StaticName="FromOfficeCode" Required="TRUE" MaxLength="255"/>'
fld OfficeSharing ToOfficeCode '<Field Type="Text" DisplayName="To office code" Name="ToOfficeCode" StaticName="ToOfficeCode" Required="TRUE" MaxLength="255"/>'
fld OfficeSharing SharePriority '<Field Type="Number" DisplayName="Share priority" Name="SharePriority" StaticName="SharePriority" Required="TRUE" Decimals="0" Min="1"/>'
fld OfficeSharing IsActive '<Field Type="Boolean" DisplayName="Active" Name="IsActive" StaticName="IsActive"><Default>1</Default></Field>'

# ===========================================================================
# 3. Catalogue
# ===========================================================================
echo "Catalogue…"
set_title_field "Catalogue" "Item name" true false false
fld Catalogue ItemCode '<Field Type="Text" DisplayName="Item code" Name="ItemCode" StaticName="ItemCode" Required="TRUE" MaxLength="255"/>'
fld Catalogue OfficeCode '<Field Type="Text" DisplayName="Office code" Name="OfficeCode" StaticName="OfficeCode" Required="TRUE" Indexed="TRUE" MaxLength="255"/>'
fld Catalogue OfficeItemKey '<Field Type="Text" DisplayName="Office item key" Name="OfficeItemKey" StaticName="OfficeItemKey" Required="TRUE" Indexed="TRUE" EnforceUniqueValues="TRUE" MaxLength="255"/>'
fld Catalogue Category '<Field Type="Text" DisplayName="Category" Name="Category" StaticName="Category" MaxLength="255"/>'
fld Catalogue UnitOfMeasure '<Field Type="Text" DisplayName="Unit of measure" Name="UnitOfMeasure" StaticName="UnitOfMeasure" MaxLength="255"/>'
fld Catalogue StockQty '<Field Type="Number" DisplayName="Stock quantity" Name="StockQty" StaticName="StockQty" Required="TRUE" Decimals="0" Min="0"/>'
fld Catalogue ReorderLevel '<Field Type="Number" DisplayName="Low-stock threshold" Name="ReorderLevel" StaticName="ReorderLevel" Decimals="0" Min="0"/>'
fld Catalogue UnitCost '<Field Type="Currency" DisplayName="Unit cost" Name="UnitCost" StaticName="UnitCost" Decimals="2"/>'
fld Catalogue RowVersion '<Field Type="Number" DisplayName="Row version" Name="RowVersion" StaticName="RowVersion" Decimals="0" Min="0"/>'
fld Catalogue IsActive '<Field Type="Boolean" DisplayName="Active" Name="IsActive" StaticName="IsActive"><Default>1</Default></Field>'

# ===========================================================================
# 4. StockLedger  (append-only; expected to exceed 5000 items)
# ===========================================================================
echo "StockLedger…"
set_title_field "StockLedger" "Entry" true false false
fld StockLedger OfficeItemKey '<Field Type="Text" DisplayName="Office item key" Name="OfficeItemKey" StaticName="OfficeItemKey" Required="TRUE" Indexed="TRUE" MaxLength="255"/>'
fld StockLedger OfficeCode '<Field Type="Text" DisplayName="Office code" Name="OfficeCode" StaticName="OfficeCode" Required="TRUE" Indexed="TRUE" MaxLength="255"/>'
fld StockLedger ItemCode '<Field Type="Text" DisplayName="Item code" Name="ItemCode" StaticName="ItemCode" Required="TRUE" MaxLength="255"/>'
fld StockLedger MovementType '<Field Type="Choice" DisplayName="Movement" Name="MovementType" StaticName="MovementType" Required="TRUE" Indexed="TRUE" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Receipt</CHOICE><CHOICE>Distribution</CHOICE><CHOICE>Adjustment</CHOICE><CHOICE>Transfer in</CHOICE><CHOICE>Transfer out</CHOICE><CHOICE>Return</CHOICE></CHOICES></Field>'
# QtyDelta is signed — deliberately no Min.
fld StockLedger QtyDelta '<Field Type="Number" DisplayName="Quantity delta" Name="QtyDelta" StaticName="QtyDelta" Required="TRUE" Decimals="0"/>'
fld StockLedger BalanceAfter '<Field Type="Number" DisplayName="Balance after" Name="BalanceAfter" StaticName="BalanceAfter" Required="TRUE" Decimals="0" Min="0"/>'
fld StockLedger RequestRefNo '<Field Type="Text" DisplayName="Request reference" Name="RequestRefNo" StaticName="RequestRefNo" Indexed="TRUE" MaxLength="255"/>'
fld StockLedger MovedOn '<Field Type="DateTime" DisplayName="Moved on" Name="MovedOn" StaticName="MovedOn" Required="TRUE" Indexed="TRUE" Format="DateTime"/>'
fld StockLedger MovedByEmail '<Field Type="Text" DisplayName="Moved by (email)" Name="MovedByEmail" StaticName="MovedByEmail" Required="TRUE" MaxLength="255"/>'
fld StockLedger MovedBy '<Field Type="User" DisplayName="Moved by" Name="MovedBy" StaticName="MovedBy" UserSelectionMode="PeopleOnly" UserSelectionScope="0" Mult="FALSE" ShowField="ImnName"/>'
fld StockLedger Notes '<Field Type="Note" DisplayName="Notes" Name="Notes" StaticName="Notes" NumLines="4" RichText="FALSE" AppendOnly="FALSE"/>'

# ===========================================================================
# 5. ApprovalMatrix
# ===========================================================================
echo "ApprovalMatrix…"
set_title_field "ApprovalMatrix" "Step" true false false
fld ApprovalMatrix OfficeCode '<Field Type="Text" DisplayName="Office code" Name="OfficeCode" StaticName="OfficeCode" Required="TRUE" MaxLength="255"/>'
fld ApprovalMatrix Section '<Field Type="Text" DisplayName="Section scope" Name="Section" StaticName="Section" Required="TRUE" MaxLength="255"/>'
fld ApprovalMatrix MatrixKey '<Field Type="Text" DisplayName="Matrix key" Name="MatrixKey" StaticName="MatrixKey" Required="TRUE" Indexed="TRUE" MaxLength="255"/>'
fld ApprovalMatrix StageCode '<Field Type="Choice" DisplayName="Stage code" Name="StageCode" StaticName="StageCode" Required="TRUE" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Review</CHOICE><CHOICE>Approval</CHOICE><CHOICE>Confirm</CHOICE><CHOICE>Deliver</CHOICE><CHOICE>Receive</CHOICE></CHOICES></Field>'
fld ApprovalMatrix StageOrder '<Field Type="Number" DisplayName="Step" Name="StageOrder" StaticName="StageOrder" Required="TRUE" Decimals="0" Min="1"/>'
fld ApprovalMatrix ActorRoleCode '<Field Type="Choice" DisplayName="Acts as" Name="ActorRoleCode" StaticName="ActorRoleCode" Required="TRUE" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Requester</CHOICE><CHOICE>Reviewer</CHOICE><CHOICE>Chief Field Office</CHOICE><CHOICE>Storekeeper</CHOICE><CHOICE>Administrator</CHOICE></CHOICES></Field>'
fld ApprovalMatrix ApproverEmail '<Field Type="Text" DisplayName="Approver (email)" Name="ApproverEmail" StaticName="ApproverEmail" MaxLength="255"/>'
fld ApprovalMatrix Approver '<Field Type="User" DisplayName="Approver" Name="Approver" StaticName="Approver" UserSelectionMode="PeopleOnly" UserSelectionScope="0" Mult="FALSE" ShowField="ImnName"/>'
fld ApprovalMatrix OICEmail '<Field Type="Text" DisplayName="OIC (email)" Name="OICEmail" StaticName="OICEmail" MaxLength="255"/>'
fld ApprovalMatrix OIC '<Field Type="User" DisplayName="Officer in charge" Name="OIC" StaticName="OIC" UserSelectionMode="PeopleOnly" UserSelectionScope="0" Mult="FALSE" ShowField="ImnName"/>'
fld ApprovalMatrix IsActive '<Field Type="Boolean" DisplayName="Active" Name="IsActive" StaticName="IsActive"><Default>1</Default></Field>'

# ===========================================================================
# 6. Requests
# ===========================================================================
echo "Requests…"
# Title is the reference number and is UNIQUE. SharePoint enforces uniqueness; the
# app only retries the mint.
set_title_field "Requests" "Reference" true true true
fld Requests OfficeCode '<Field Type="Text" DisplayName="Office code" Name="OfficeCode" StaticName="OfficeCode" Required="TRUE" Indexed="TRUE" MaxLength="255"/>'
fld Requests Section '<Field Type="Choice" DisplayName="Section" Name="Section" StaticName="Section" Required="TRUE" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Programme</CHOICE><CHOICE>Child Protection</CHOICE><CHOICE>Health &amp; Nutrition</CHOICE><CHOICE>Operations</CHOICE><CHOICE>Supply &amp; Logistics</CHOICE></CHOICES></Field>'
fld Requests RequesterEmail '<Field Type="Text" DisplayName="Requester (email)" Name="RequesterEmail" StaticName="RequesterEmail" Required="TRUE" Indexed="TRUE" MaxLength="255"/>'
fld Requests Requester '<Field Type="User" DisplayName="Requester" Name="Requester" StaticName="Requester" UserSelectionMode="PeopleOnly" UserSelectionScope="0" Mult="FALSE" ShowField="ImnName"/>'
fld Requests CurrentlyWithEmail '<Field Type="Text" DisplayName="Currently with (email)" Name="CurrentlyWithEmail" StaticName="CurrentlyWithEmail" Indexed="TRUE" MaxLength="255"/>'
fld Requests CurrentlyWith '<Field Type="User" DisplayName="Currently with" Name="CurrentlyWith" StaticName="CurrentlyWith" UserSelectionMode="PeopleOnly" UserSelectionScope="0" Mult="FALSE" ShowField="ImnName"/>'
fld Requests CurrentlyWithOICEmail '<Field Type="Text" DisplayName="Currently with OIC (email)" Name="CurrentlyWithOICEmail" StaticName="CurrentlyWithOICEmail" Indexed="TRUE" MaxLength="255"/>'
fld Requests Status '<Field Type="Choice" DisplayName="Status" Name="Status" StaticName="Status" Required="TRUE" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Draft</CHOICE><CHOICE>Returned</CHOICE><CHOICE>Submitted</CHOICE><CHOICE>Reviewed</CHOICE><CHOICE>Partial delivery</CHOICE><CHOICE>Fully delivered</CHOICE><CHOICE>Fully received</CHOICE><CHOICE>Closed</CHOICE><CHOICE>Rejected</CHOICE></CHOICES></Field>'
fld Requests StatusRank '<Field Type="Number" DisplayName="Status rank" Name="StatusRank" StaticName="StatusRank" Required="TRUE" Indexed="TRUE" Decimals="0" Min="0"/>'
fld Requests CurrentStageCode '<Field Type="Choice" DisplayName="Current stage" Name="CurrentStageCode" StaticName="CurrentStageCode" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Review</CHOICE><CHOICE>Approval</CHOICE><CHOICE>Confirm</CHOICE><CHOICE>Deliver</CHOICE><CHOICE>Receive</CHOICE></CHOICES></Field>'
fld Requests Purpose '<Field Type="Choice" DisplayName="Purpose" Name="Purpose" StaticName="Purpose" Required="TRUE" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Internal</CHOICE><CHOICE>External</CHOICE></CHOICES></Field>'
fld Requests SubmittedOn '<Field Type="DateTime" DisplayName="Submitted on" Name="SubmittedOn" StaticName="SubmittedOn" Indexed="TRUE" Format="DateTime"/>'
fld Requests ClosedOn '<Field Type="DateTime" DisplayName="Closed on" Name="ClosedOn" StaticName="ClosedOn" Format="DateTime"/>'
fld Requests LineCount '<Field Type="Number" DisplayName="Line count" Name="LineCount" StaticName="LineCount" Required="TRUE" Decimals="0" Min="0"/>'
fld Requests TotalQtyRequested '<Field Type="Number" DisplayName="Total requested" Name="TotalQtyRequested" StaticName="TotalQtyRequested" Decimals="0" Min="0"/>'
fld Requests TotalQtyApproved '<Field Type="Number" DisplayName="Total approved" Name="TotalQtyApproved" StaticName="TotalQtyApproved" Decimals="0" Min="0"/>'
fld Requests TotalQtyDistributed '<Field Type="Number" DisplayName="Total distributed" Name="TotalQtyDistributed" StaticName="TotalQtyDistributed" Decimals="0" Min="0"/>'
fld Requests TotalQtyReceived '<Field Type="Number" DisplayName="Total received" Name="TotalQtyReceived" StaticName="TotalQtyReceived" Decimals="0" Min="0"/>'
fld Requests SharingOfficeCode '<Field Type="Text" DisplayName="Sharing office code" Name="SharingOfficeCode" StaticName="SharingOfficeCode" MaxLength="255"/>'
fld Requests ReturnReason '<Field Type="Note" DisplayName="Return reason" Name="ReturnReason" StaticName="ReturnReason" NumLines="4" RichText="FALSE" AppendOnly="FALSE"/>'
fld Requests RejectReason '<Field Type="Note" DisplayName="Reject reason" Name="RejectReason" StaticName="RejectReason" NumLines="4" RichText="FALSE" AppendOnly="FALSE"/>'

# ===========================================================================
# 7. RequestItems  (the largest list)
# ===========================================================================
echo "RequestItems…"
set_title_field "RequestItems" "Line" true false false
fld RequestItems RequestRefNo '<Field Type="Text" DisplayName="Request reference" Name="RequestRefNo" StaticName="RequestRefNo" Required="TRUE" Indexed="TRUE" MaxLength="255"/>'
fld RequestItems OfficeCode '<Field Type="Text" DisplayName="Office code" Name="OfficeCode" StaticName="OfficeCode" Required="TRUE" MaxLength="255"/>'
fld RequestItems LineNo '<Field Type="Number" DisplayName="Line no." Name="LineNo" StaticName="LineNo" Required="TRUE" Decimals="0" Min="1"/>'
fld RequestItems ItemCode '<Field Type="Text" DisplayName="Item code" Name="ItemCode" StaticName="ItemCode" MaxLength="255"/>'
fld RequestItems ItemName '<Field Type="Text" DisplayName="Item name" Name="ItemName" StaticName="ItemName" Required="TRUE" MaxLength="255"/>'
fld RequestItems IsCatalogueItem '<Field Type="Boolean" DisplayName="Catalogue item" Name="IsCatalogueItem" StaticName="IsCatalogueItem"><Default>1</Default></Field>'
fld RequestItems OfficeItemKey '<Field Type="Text" DisplayName="Office item key" Name="OfficeItemKey" StaticName="OfficeItemKey" MaxLength="255"/>'
fld RequestItems UnitOfMeasure '<Field Type="Text" DisplayName="Unit of measure" Name="UnitOfMeasure" StaticName="UnitOfMeasure" MaxLength="255"/>'
fld RequestItems UnitCost '<Field Type="Currency" DisplayName="Unit cost" Name="UnitCost" StaticName="UnitCost" Decimals="2"/>'
fld RequestItems LinePurpose '<Field Type="Text" DisplayName="Purpose" Name="LinePurpose" StaticName="LinePurpose" MaxLength="255"/>'
fld RequestItems QtyRequested '<Field Type="Number" DisplayName="Requested" Name="QtyRequested" StaticName="QtyRequested" Required="TRUE" Decimals="0" Min="0"/>'
fld RequestItems QtyApproved '<Field Type="Number" DisplayName="Approved" Name="QtyApproved" StaticName="QtyApproved" Decimals="0" Min="0"/>'
fld RequestItems QtyDistributed '<Field Type="Number" DisplayName="Distributed" Name="QtyDistributed" StaticName="QtyDistributed" Decimals="0" Min="0"/>'
fld RequestItems QtyReceived '<Field Type="Number" DisplayName="Received" Name="QtyReceived" StaticName="QtyReceived" Decimals="0" Min="0"/>'
fld RequestItems SourceOfficeCode '<Field Type="Text" DisplayName="Source office code" Name="SourceOfficeCode" StaticName="SourceOfficeCode" MaxLength="255"/>'
fld RequestItems LineStatus '<Field Type="Choice" DisplayName="Line status" Name="LineStatus" StaticName="LineStatus" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Pending</CHOICE><CHOICE>Partially distributed</CHOICE><CHOICE>Fully distributed</CHOICE><CHOICE>Partially received</CHOICE><CHOICE>Fully received</CHOICE><CHOICE>Cancelled</CHOICE></CHOICES></Field>'
fld RequestItems ReceiptCondition '<Field Type="Choice" DisplayName="Receipt condition" Name="ReceiptCondition" StaticName="ReceiptCondition" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Complete</CHOICE><CHOICE>Short</CHOICE><CHOICE>Damaged</CHOICE><CHOICE>Not received</CHOICE></CHOICES></Field>'
fld RequestItems LineNote '<Field Type="Note" DisplayName="Line note" Name="LineNote" StaticName="LineNote" NumLines="4" RichText="FALSE" AppendOnly="FALSE"/>'

# ===========================================================================
# 8. RequestComments
# ===========================================================================
echo "RequestComments…"
set_title_field "RequestComments" "Comment" true false false
fld RequestComments RequestRefNo '<Field Type="Text" DisplayName="Request reference" Name="RequestRefNo" StaticName="RequestRefNo" Required="TRUE" Indexed="TRUE" MaxLength="255"/>'
fld RequestComments CommentText '<Field Type="Note" DisplayName="Comment" Name="CommentText" StaticName="CommentText" Required="TRUE" NumLines="4" RichText="FALSE" AppendOnly="FALSE"/>'
fld RequestComments AuthorEmail '<Field Type="Text" DisplayName="Author (email)" Name="AuthorEmail" StaticName="AuthorEmail" Required="TRUE" MaxLength="255"/>'
# NOTE: named CommentAuthor, not Author — "Author" is the reserved internal name of
# SharePoint's built-in Created By field and cannot be created.
fld RequestComments CommentAuthor '<Field Type="User" DisplayName="Author" Name="CommentAuthor" StaticName="CommentAuthor" UserSelectionMode="PeopleOnly" UserSelectionScope="0" Mult="FALSE" ShowField="ImnName"/>'
fld RequestComments PostedOn '<Field Type="DateTime" DisplayName="Posted on" Name="PostedOn" StaticName="PostedOn" Required="TRUE" Indexed="TRUE" Format="DateTime"/>'

# ===========================================================================
# 9. RequestTimeline
# ===========================================================================
echo "RequestTimeline…"
set_title_field "RequestTimeline" "Event" true false false
fld RequestTimeline RequestRefNo '<Field Type="Text" DisplayName="Request reference" Name="RequestRefNo" StaticName="RequestRefNo" Required="TRUE" Indexed="TRUE" MaxLength="255"/>'
fld RequestTimeline EventType '<Field Type="Choice" DisplayName="Event type" Name="EventType" StaticName="EventType" Required="TRUE" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Draft created</CHOICE><CHOICE>Submitted</CHOICE><CHOICE>Routed</CHOICE><CHOICE>Reviewed</CHOICE><CHOICE>Returned</CHOICE><CHOICE>Rejected</CHOICE><CHOICE>Confirmed</CHOICE><CHOICE>Distributed</CHOICE><CHOICE>Received</CHOICE><CHOICE>Closed</CHOICE><CHOICE>Comment added</CHOICE><CHOICE>Reassigned</CHOICE><CHOICE>Stock adjusted</CHOICE></CHOICES></Field>'
fld RequestTimeline FromStatus '<Field Type="Text" DisplayName="From status" Name="FromStatus" StaticName="FromStatus" MaxLength="255"/>'
fld RequestTimeline ToStatus '<Field Type="Text" DisplayName="To status" Name="ToStatus" StaticName="ToStatus" MaxLength="255"/>'
fld RequestTimeline StageCode '<Field Type="Choice" DisplayName="Stage code" Name="StageCode" StaticName="StageCode" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Review</CHOICE><CHOICE>Approval</CHOICE><CHOICE>Confirm</CHOICE><CHOICE>Deliver</CHOICE><CHOICE>Receive</CHOICE></CHOICES></Field>'
fld RequestTimeline ActorEmail '<Field Type="Text" DisplayName="Actor (email)" Name="ActorEmail" StaticName="ActorEmail" MaxLength="255"/>'
fld RequestTimeline Actor '<Field Type="User" DisplayName="Actor" Name="Actor" StaticName="Actor" UserSelectionMode="PeopleOnly" UserSelectionScope="0" Mult="FALSE" ShowField="ImnName"/>'
fld RequestTimeline OccurredOn '<Field Type="DateTime" DisplayName="Occurred on" Name="OccurredOn" StaticName="OccurredOn" Required="TRUE" Indexed="TRUE" Format="DateTime"/>'
fld RequestTimeline Detail '<Field Type="Note" DisplayName="Detail" Name="Detail" StaticName="Detail" NumLines="4" RichText="FALSE" AppendOnly="FALSE"/>'

# ===========================================================================
# 10. RequestDocuments  (document LIBRARY)
# ===========================================================================
echo "RequestDocuments…"
fld RequestDocuments RequestRefNo '<Field Type="Text" DisplayName="Request reference" Name="RequestRefNo" StaticName="RequestRefNo" Required="TRUE" Indexed="TRUE" MaxLength="255"/>'
fld RequestDocuments DocType '<Field Type="Choice" DisplayName="Document type" Name="DocType" StaticName="DocType" Required="TRUE" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Request PDF</CHOICE><CHOICE>Delivery note</CHOICE><CHOICE>Receipt note</CHOICE><CHOICE>Supporting document</CHOICE></CHOICES></Field>'
fld RequestDocuments UploadedByEmail '<Field Type="Text" DisplayName="Uploaded by (email)" Name="UploadedByEmail" StaticName="UploadedByEmail" MaxLength="255"/>'

# ===========================================================================
# 11. AppRoles
# ===========================================================================
echo "AppRoles…"
set_title_field "AppRoles" "Person" true false false
fld AppRoles UserEmail '<Field Type="Text" DisplayName="User email" Name="UserEmail" StaticName="UserEmail" Required="TRUE" Indexed="TRUE" MaxLength="255"/>'
fld AppRoles OfficeCode '<Field Type="Text" DisplayName="Office code" Name="OfficeCode" StaticName="OfficeCode" Required="TRUE" MaxLength="255"/>'
fld AppRoles RoleCode '<Field Type="Choice" DisplayName="Role" Name="RoleCode" StaticName="RoleCode" Required="TRUE" Format="Dropdown" FillInChoice="FALSE"><CHOICES><CHOICE>Requester</CHOICE><CHOICE>Reviewer</CHOICE><CHOICE>Chief Field Office</CHOICE><CHOICE>Storekeeper</CHOICE><CHOICE>Administrator</CHOICE></CHOICES></Field>'
fld AppRoles IsActive '<Field Type="Boolean" DisplayName="Active" Name="IsActive" StaticName="IsActive"><Default>1</Default></Field>'

# ===========================================================================
# 12. RefCounter
# ===========================================================================
echo "RefCounter…"
set_title_field "RefCounter" "Period" true true false
fld RefCounter LastSeq '<Field Type="Number" DisplayName="Last sequence" Name="LastSeq" StaticName="LastSeq" Required="TRUE" Decimals="0" Min="0"/>'

echo
echo "Done. All columns created."
echo "Next: bash provision/03-seed.sh"
