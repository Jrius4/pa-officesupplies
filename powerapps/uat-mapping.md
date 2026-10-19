# UAT mapping — where the canvas build meets each test

Generated from `pa.init.officesupplies/uat/catalogue.yaml`, `uat/defects.seed.yaml` and the round 2 fix list
(`.state/round2-fixed.json`). The SPFx build passed all 31 cases in round 2 (build 1.0.0.20); the canvas build
must pass the same cases, in the same run order.

## UAT cases

Run them in block order. Where a block impersonates a seeded person, open the app link with
`&as=<their email from AppRoles>` (it needs `cfgAllowImpersonation = true`).


### Block 1 Test account, self-routed office

*No impersonation.*

| Case | Title | Where it is tested in the canvas app |
|---|---|---|
| UAT-001 | Add a new office with a generated code | Catalogue & matrix › Offices & sharing: **＋ Add office**, the suggested code (ch. 11, §15.4) |
| UAT-002 | A clashing office code gets a number | Office dialog: `lblCodeSuggestion` adds a number on a clash; `lblOfficeCodeError` (§15.4) |
| UAT-003 | Build an approval chain for the test office | Approval matrix: **＋ Add step** four times, then **Validate chain** (§15.1, §15.2) |
| UAT-004 | Add catalogue items and load stock | Catalogue & stock: **＋ Add catalogue item**, then **Adjust stock** (§15.3) |
| UAT-005 | Let the country office lend stock to the test office | Offices & sharing: **＋ Add sharing link** (§15.4) |
| UAT-010 | A request with no items cannot be submitted | New request: **Submit** with no quantity shows the error, writes nothing (§8) |
| UAT-011 | Save a request as a draft | New request: **Save draft** (§8); Home shows it with **Edit** |
| UAT-012 | Submit a request from the catalogue | New request: catalogue picker, **Submit** (§8); Request detail shows it at Review |
| UAT-013 | Review a request and change a quantity | Review: change a quantity, note, **Proceed** (§10) |
| UAT-014 | Return a request, then edit and resubmit it | Review: **Return** (§11); New request in edit mode, **Resubmit** (§9) |
| UAT-015 | Reject a request | Review: **Reject** (§11); journey stops at its stage (DEF-141) |
| UAT-016 | Confirm a reviewed request | Review at the Confirm stage: "Confirm SR-…", **Proceed** (§10) |
| UAT-017 | Distribute part of a request | Distribute: less than approved, **Record distribution**; stays at Deliver (§12) |
| UAT-018 | Distribute the rest of a request | Distribute again: the remainder; moves to Receive (§12) |
| UAT-019 | Confirm receipt and close the request | Confirm receipt: **Confirm receipt** closes the request (§13) |
| UAT-020 | Stock is offered from the lending office | Review: "⇄ From sharing office" and the lender stock (ch. 8 loader) |
| UAT-021 | Comment on a request and attach a document | Request detail: **Post comment**, **Attach a file** and the flow (§14, ch. 14) |

### Block 2 Reviewer / requester persona (Daniel Otieno)

*Impersonate Daniel Otieno.*

| Case | Title | Where it is tested in the canvas app |
|---|---|---|
| UAT-030 | A reviewer sees stock hints on a request | Review as the seeded reviewer: availability badges (ch. 8) |
| UAT-031 | A reviewer approves a request | Review as the seeded reviewer: **Proceed** (§10) |
| UAT-035 | A requester fixes and resubmits a returned request | Home **Edit** on a Returned request; return reason shown; **Resubmit** (§9) |
| UAT-040 | Home shows my work and my requests | Home tiles and both lists as the reviewer/requester persona (ch. 4) |

### Block 3 Chief Field Office persona (Fatuma Noor)

*Impersonate Fatuma Noor.*

| Case | Title | Where it is tested in the canvas app |
|---|---|---|
| UAT-032 | The Chief Field Office confirms a request | Review at Confirm as the Chief Field Office persona: **Proceed** (§10) |

### Block 4 Storekeeper persona (Samuel Kiptoo)

*Impersonate Samuel Kiptoo.*

| Case | Title | Where it is tested in the canvas app |
|---|---|---|
| UAT-033 | A storekeeper distributes and stock runs out | Distribute as the storekeeper persona: "flags out of stock" (ch. 9, §12) |

### Block 5 Requester persona again (Daniel Otieno)

*Impersonate Daniel Otieno.*

| Case | Title | Where it is tested in the canvas app |
|---|---|---|
| UAT-034 | A requester confirms receipt of a delivery | Confirm receipt as the requester persona (§13) |

### Block 6 Empty-account persona (Peter Mwangi)

*Impersonate Peter Mwangi.*

| Case | Title | Where it is tested in the canvas app |
|---|---|---|
| UAT-041 | Home explains when there is nothing to show | Home as a persona with nothing: empty messages (ch. 4) |

### Block 7 Test account, reports and rename

*No impersonation.*

| Case | Title | Where it is tested in the canvas app |
|---|---|---|
| UAT-042 | Reports show activity and respond to filters | Reports: both filters change every figure (ch. 12) |
| UAT-050 | Rename an office code and keep its data | Edit office with a new code: the rename across seven lists (§15.5) |

### Block 8 End-to-end journeys

*Test account (no impersonation).*

| Case | Title | Where it is tested in the canvas app |
|---|---|---|
| E2E-01 | A catalogue request from set-up to a closed request | Admin set-up, then submit → review → confirm → distribute → receipt |
| E2E-02 | A partial delivery and then the remainder | Two distributions; the request stays at Deliver between them |
| E2E-03 | A request is returned, discussed, corrected and approved | Return, comment, resubmit, approve |
| E2E-04 | Short stock is met by another office | A short line filled from the lending office, distributed from it |

## Defect checklist

All 60 defects from UAT round 2. **Fixed** ones are behaviour the canvas app must reproduce; **By design** ones
are deliberate and stay as they are unless the product owner decides otherwise (Appendix C).

| DEF | Severity | What went wrong in the SPFx build | Status | Where the canvas build handles it |
|---|---|---|---|---|
| DEF-01 | High | Catalogue product dropdown never appears on New request | Fixed | ch. 6 `cboProduct`, `btnAddLine` |
| DEF-02 | Medium | Item notes are not saved | Fixed | §8/§9 `LineNote`; ch. 7 Notes column |
| DEF-03 | Medium | Home's Review button ignores the stage | Fixed | ch. 4 `btnAwaitingAction` via `tblStageAction` |
| DEF-04 | Medium | Return and Reject are not limited to the current holder | Fixed | §10/§11 `DisplayMode` |
| DEF-05 | High | Remainder of a partial delivery cannot be distributed | Fixed | §12 `varDeliverWith`: a partial stays at Deliver |
| DEF-06 | Medium | Failed saves are mostly silent | Fixed | Every `IfError` in §8–§15; §12 line summary |
| DEF-07 | Medium | Documents with the same file name overwrite each other | Fixed | §14 stored name and duplicate check; the flow |
| DEF-08 | Low | No segregation of duties | By design | Not changed: one person may hold several stages |
| DEF-09 | Low | Email casing is compared exactly | Fixed | App.OnStart `Lower()`; Recipe R3 |
| DEF-10 | Low | Three left-nav items go back to Home | Fixed | ch. 3 menu `OnSelect`; ch. 5 |
| DEF-11 | Low | A deactivated catalogue item cannot be reactivated in the app | Fixed | ch. 11 `colAdminCat` keeps inactive items; `tglEditItemActive` |
| DEF-12 | Low | Status says Reviewed after the Confirm step | By design | Not changed: Proceed writes Reviewed at every stage |
| DEF-13 | Low | Reports: Requests by office ignores the office filter | Fixed | ch. 12 `colByOffice` from `colScopeReq` |
| DEF-14 | Low | The Active flag on an office does nothing | Fixed | `IsActive <> false` in every office picker; ch. 11 lists all |
| DEF-101 | Medium | Posting a comment or attaching a document adds no event to the Timeline | Fixed | §14 timeline rows |
| DEF-102 | Medium | Home counts a person's own Returned and Fully delivered requests as awaiting their action | By design | Not changed: Home counts them |
| DEF-103 | Medium | Confirm and Deliver steps are routed to the officer in charge, not the matrix approver | Fixed | Recipe R2: approver holds, OIC beside |
| DEF-104 | Low | Confirm step writes the timeline title "Request confirm confirmed" | Fixed | §10 `Switch(varFromStage, …)` titles |
| DEF-105 | Medium | Add dialogs keep the previous values when reopened | Fixed | ch. 11 `Reset()` before each dialog |
| DEF-106 | Medium | A closed request shows 'Unknown' as the actor of the last journey step | Fixed | ch. 7 `colJourney.Actor` |
| DEF-107 | Low | The Confirm step's screen is titled 'Review' | Fixed | ch. 8 `ScreenTitle` in `varPageTitle` |
| DEF-108 | Low | A new line's Tracking badge says 'Unknown' | Fixed | ch. 7 Tracking `Coalesce(…, "Pending")` |
| DEF-109 | Low | The request reference wraps over three lines in a narrow header | Fixed | ch. 3 reference label `Wrap: false` |
| DEF-110 | Low | The Edit request banner promises a new reference number | Fixed | ch. 6 `lblRouting` |
| DEF-111 | Low | Currently with says Unknown for a draft | Fixed | `txtNoHolder` in "Currently with" |
| DEF-112 | Medium | Distribute does not say which office the stock comes from | Fixed | ch. 9 "Available now · from …" |
| DEF-113 | Low | '1 items' on the Review and Distribute headers | Fixed | "1 item" / "N items" formulas |
| DEF-114 | Medium | The request reference is clipped in the Review and Confirm headers | Fixed | ch. 3 reference label; top bar sizing |
| DEF-115 | Low | New request says Defaulted from your profile after the office is changed | Fixed | ch. 6 `lblOfficeHint.Visible` |
| DEF-116 | Low | A bare ellipsis stands in for the office name, and the persona chip is clipped | Fixed | `varMyOfficeName` falls back to "No default office" |
| DEF-117 | Medium | Remaining on the request screen counts requested minus received, not what is still to be delivered | Fixed | ch. 7 Remaining column |
| DEF-118 | Low | Stock after says below threshold when the stock after equals the threshold | Fixed | ch. 9 `lblAfter` |
| DEF-119 | Low | The Distributed timeline row prints the running total as if it were this step | Fixed | §12 `Detail` |
| DEF-120 | Low | Home's action button says Review for a request waiting at Confirm | Fixed | ch. 4 and 5 `RowLabel` |
| DEF-121 | Low | The item note typed on New request is shown nowhere | Fixed | ch. 7 Notes column |
| DEF-122 | Low | No Routed to Receive row after the last distribution | Fixed | §12 "Routed to Receive" |
| DEF-123 | Low | The Receipt confirmed row is blank | Fixed | §13 `Detail` |
| DEF-124 | Medium | A Returned request offers Review, and the Review screen lets a reviewer act on it | Fixed | Recipe R3 `varIsEditable`; ch. 4, 7, 8 buttons |
| DEF-125 | Low | The Edit request screen does not show why the request was returned | Fixed | ch. 6 `lblReturnReason` |
| DEF-126 | Low | Distribute says 'above threshold' for an item with no threshold | Fixed | ch. 9 `lblAfter` wording |
| DEF-127 | Low | A Returned request still shows the Reviewer holding it at the Review step | Fixed | ch. 7 `varJourneyStage` |
| DEF-128 | Low | Review & distribution offers Review for a Returned request | Fixed | ch. 5 `galQueue.Items` |
| DEF-129 | Low | The Edit request screen lights New request in the nav | Fixed | ch. 6 `varNavActive` |
| DEF-130 | Low | Timeline rows from the same minute swap places between loads | Fixed | ch. 7 sort by OccurredOn then ID |
| DEF-131 | Low | The brand line under Supply Requests is blank on New and Edit request | Fixed | ch. 3 `lblBrandOffice` |
| DEF-132 | Medium | 'Held for' counts from submission, not from the last hand-off | Fixed | Recipe R5 from `Modified` |
| DEF-133 | Low | The Edit request title does not show the reference | Fixed | ch. 6 `varPageTitle` |
| DEF-134 | Medium | Home's Confirm receipt button in Awaiting my action opens the request screen, not the receipt form | Fixed | ch. 4 button `OnSelect` is not `Select(Parent)` |
| DEF-135 | Medium | Any role can open Catalogue & matrix and its edit controls | By design | Not changed; ch. 11 shows the optional gate |
| DEF-136 | Low | A line cut by the reviewer shows Requested 4 and Fully received 2 with no explanation | Fixed | ch. 7 Approved column |
| DEF-137 | Low | 'This quarter' on Reports is a rolling 91 days | Fixed | ch. 12 `varSince` |
| DEF-138 | Medium | Median time held per stage shows only Review | Fixed | Routed rows carry `StageCode` (§8, §10, §12) |
| DEF-139 | Low | The Active hint on Edit office is stale | Fixed | ch. 11 office dialog resets from `varEditOffice` |
| DEF-140 | Low | Median delivery tile reads 0.0 days | Fixed | ch. 12 `lblKpiMedian` |
| DEF-141 | Low | A rejected request shows its later journey legs as complete | Fixed | ch. 7 `varJourneyStage`, `varJourneyDone` |
| DEF-142 | Low | The 'This quarter' range chip starts on 30 Sep | Fixed | ch. 12 `DateTime(…, 1, 0, 0, 0)` |
| DEF-143 | Medium | Median time held per stage draws no bars | Fixed | ch. 12 `varStageUnit` |
| DEF-144 | Medium | Distribute screen shows zero stock for a few seconds after it opens | Fixed | ch. 9 `varDistReady` |
| DEF-145 | Low | Reports stage chart and delivery tile ignore the office filter | Fixed | ch. 12 `colScopeTL` |
| DEF-146 | Low | The stage chart caption always names Review as the slowest stage | Fixed | ch. 12 `lblStageCaption` |
