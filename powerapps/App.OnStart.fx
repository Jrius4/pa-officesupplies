// ── 1. Reference data (small lists, one round trip each) ───────────────────

// All offices, including inactive ones — scrAdmin tab 3 renders the full table
// with an Active column, so it must not be pre-filtered.
ClearCollect(colOffices, Offices);

// The approval matrix. IsActive = true on a Yes/No column IS delegable to
// SharePoint. Small list (max 5 rows per office+section).
ClearCollect(colMatrix, Filter(ApprovalMatrix, IsActive = true));

// Office sharing links — needed by the Review screen's ceiling calculation.
ClearCollect(colSharing, Filter(OfficeSharing, IsActive = true));

// ── 2. The single role query ───────────────────────────────────────────────
// ONE delegable query (UserEmail is indexed text, IsActive is Yes/No). Every
// role check after this is local. Never re-query AppRoles per screen.
ClearCollect(
    colMyRoles,
    Filter(AppRoles, UserEmail = User().Email, IsActive = true)
);

// ── 3. User and context variables ──────────────────────────────────────────
Set(varUserEmail, User().Email);
Set(varUserName,  User().FullName);

// Default office = the office on the user's Requester role if they have one,
// else whatever their first role names, else blank. Coalesce over blank text.
Set(
    varMyOffice,
    Coalesce(
        LookUp(colMyRoles, RoleCode.Value = "Requester").OfficeCode,
        First(colMyRoles).OfficeCode,
        ""
    )
);

// varOffice is the office the screens are CURRENTLY looking at. It starts at the
// user's own office; scrAdmin and scrReports let an Administrator repoint it.
// Every Catalogue / StockLedger query keys off varOffice, never off varMyOffice.
Set(varOffice, varMyOffice);

// ── 4. Role booleans ───────────────────────────────────────────────────────
// Derived from colMyRoles, so they are variables, not named formulas — a named
// formula cannot reference a collection. Consequence: if AppRoles changes
// mid-session these are stale until the app is relaunched. Acceptable; roles
// are administered rarely. RoleCode is a Choice column, hence .Value.
Set(varIsRequester,  CountRows(Filter(colMyRoles, RoleCode.Value = "Requester"))           > 0);
Set(varIsReviewer,   CountRows(Filter(colMyRoles, RoleCode.Value = "Reviewer"))            > 0);
Set(varIsCFO,        CountRows(Filter(colMyRoles, RoleCode.Value = "Chief Field Office"))  > 0);
Set(varIsStorekeeper,CountRows(Filter(colMyRoles, RoleCode.Value = "Storekeeper"))         > 0);
Set(varIsAdmin,      CountRows(Filter(colMyRoles, RoleCode.Value = "Administrator"))       > 0);

// ── 5. Working state ───────────────────────────────────────────────────────
Set(varBusy, false);        // button guard — see Section 5
Set(varRef, "");            // the request reference currently open
Set(varMatrixKey, "");      // "<OfficeCode>|<Section>" for the open request
Set(varErrorMsg, "");       // last user-facing error, "" when clean