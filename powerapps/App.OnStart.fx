// ── 1. Reference data (small lists, one round trip each) ───────────────────

// All offices, including inactive ones — scrAdmin tab 3 renders the full table
// with an Active column, so it must not be pre-filtered. Pickers filter it
// locally (DEF-14: an inactive office is hidden from pickers, still listed here).
ClearCollect(colOffices, Offices);

// The approval matrix. IsActive = true on a Yes/No column IS delegable to
// SharePoint. Small list (max 5 rows per office+section).
ClearCollect(colMatrix, Filter(ApprovalMatrix, IsActive = true));

// Office sharing links — needed by the Review screen's ceiling calculation.
ClearCollect(colSharing, Filter(OfficeSharing, IsActive = true));

// ── 2. Who is using the app ─────────────────────────────────────────────────
// Emails are compared lower-case everywhere (DEF-09: "Email casing is compared
// exactly"). SharePoint's own filters ignore case, but a comparison the app
// makes itself, such as Lower(varReq.CurrentlyWithEmail) = varUserEmail, does not.
Set(varRealEmail, Lower(User().Email));
Set(varUserName,  User().FullName);

// Testing only: open the app with &as=<email> to behave as a seeded persona,
// the canvas equivalent of the SPFx "impersonate email" setting. Ignored unless
// cfgAllowImpersonation (App.Formulas) is true.
Set(
    varUserEmail,
    If(
        cfgAllowImpersonation && !IsBlank(Param("as")),
        Lower(Trim(Param("as"))),
        varRealEmail
    )
);
Set(varImpersonating, varUserEmail <> varRealEmail);

// ── 3. The single role query ───────────────────────────────────────────────
// ONE delegable query (UserEmail is indexed text, IsActive is Yes/No). Every
// role check after this is local. Never re-query AppRoles per screen.
ClearCollect(
    colMyRoles,
    Filter(AppRoles, UserEmail = varUserEmail, IsActive = true)
);

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
// user's own office; scrAdmin and scrReports let the user repoint it.
Set(varOffice, varMyOffice);

// ── 4. Role booleans ───────────────────────────────────────────────────────
// Derived from colMyRoles, so they are variables, not named formulas. If
// AppRoles changes mid-session these are stale until the app is reopened.
Set(varIsRequester,   !IsEmpty(Filter(colMyRoles, RoleCode.Value = "Requester")));
Set(varIsReviewer,    !IsEmpty(Filter(colMyRoles, RoleCode.Value = "Reviewer")));
Set(varIsCFO,         !IsEmpty(Filter(colMyRoles, RoleCode.Value = "Chief Field Office")));
Set(varIsStorekeeper, !IsEmpty(Filter(colMyRoles, RoleCode.Value = "Storekeeper")));
Set(varIsAdmin,       !IsEmpty(Filter(colMyRoles, RoleCode.Value = "Administrator")));

// The persona line ("Viewing as: Reviewer · Bor Zonal Office"): the highest
// role wins, in the order HomePage.tsx uses.
Set(
    varPersonaRole,
    If(
        varIsAdmin,       "Administrator",
        varIsCFO,         "Chief Field Office",
        varIsReviewer,    "Reviewer",
        varIsStorekeeper, "Storekeeper",
        varIsRequester,   "Requester",
        "No role"
    )
);
Set(
    varMyOfficeName,
    Coalesce(LookUp(colOffices, Title = varMyOffice).OfficeName, varMyOffice, "No default office")
);

// ── 5. Working state ───────────────────────────────────────────────────────
Set(varBusy, false);           // button guard: every multi-write sets it first
Set(varErrorMsg, "");          // last user-facing error, "" when clean

// The request currently open. A link with &req=SR-202607-0038 opens it
// directly (App.StartScreen sends the user to scrRequestDetail); every screen
// that shows a request reads it again with LookUp(Requests, Title = varRef).
Set(varRef, Coalesce(Param("req"), ""));
Set(varEditRef, "");           // scrNewRequest: "" = new request, else the ref being edited
Set(varQueue, "review");       // scrWorkQueue: "review" | "distribute" | "receipt"
