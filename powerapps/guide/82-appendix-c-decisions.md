# Appendix C. Decisions to confirm with the product owner

The current app made these choices during UAT. Each one is reproduced in this guide, because the canvas app should behave the same way. Each is also easy to change, and this appendix says where.

| # | Decision | What the app does | Where to change it |
|---|---|---|---|
| 1 | **The officer in charge holds a stage beside the approver** (DEF-103) | When a matrix row names both, either person can act, and both see the request in "Awaiting my action". | Recipe R2 (§7): to make the OIC *replace* the approver while set, use `WithEmail: Coalesce(next.OIC, next.Approver, R)` and `OICEmail: ""`. |
| 2 | **A partial delivery stays with the storekeeper** (DEF-05) | The requester can only confirm receipt once everything approved has gone out. | §12, `CurrentStageCode` / `CurrentlyWithEmail` in the header patch. |
| 3 | **A short receipt still closes the request** | If everything approved was delivered, confirming receipt closes it; a shortfall is recorded on the line only. | §13, `varCloseNow`. |
| 4 | **Proceed always writes "Reviewed"** (DEF-12) | The status says Reviewed at Approval and Confirm too; the stage column says where it is. | §10, the header patch's `Status`. |
| 5 | **Held for counts from the last change** (DEF-132) | Any change to the request, not just a hand-off, restarts the clock. | Recipe R5. |
| 6 | **No segregation of duties** (DEF-08) | One person may review, confirm and distribute the same request if the matrix names them. | Add a check on the Proceed and Record distribution buttons against `colTimeline`'s actors. |
| 7 | **Everyone can open Catalogue & matrix and Reports** (DEF-135) | No role gate. | Chapter 11, "Who can open this screen". |
| 8 | **Home counts my own Returned and Fully delivered requests** (DEF-102) | They are mine to act on (edit, confirm receipt), so they are "awaiting my action". | Home's `colAwaiting` filter. |
| 9 | **The stage order is fixed** | Requests always move Review → Approval → Confirm → Deliver → Receive, skipping stages with no row. `StageOrder` on the matrix only orders the admin list. | `tblJourney` in `App.Formulas`. |
| 10 | **Reports filter on the office of the request** (DEF-13) | Every figure follows the office filter. | Chapter 12, `colScopeReq`. |

## Small differences from the current app

These are deliberate. Each corrects something the current app did by accident.

| Difference | Why |
|---|---|
| Return, Reject and Close **clear** `CurrentStageCode` (`Blank()`). | The SPFx build sent an empty value that SharePoint ignored, so the old stage code stayed; four defects (DEF-124, 127, 128, 141) were screen-side workarounds for that. The workarounds stay too, so older rows still show correctly. |
| Return and Reject timeline rows carry the stage they left. | Reports counts a return as the end of a stage, as `src/domain/timeline.ts` intends; the SPFx rows had no stage code, so returns were never counted. |
| The distribution timeline row's "from" status is the request's real status. | The SPFx build always wrote "Reviewed", which is wrong for a second partial delivery. |
| Edit mode disables Submit for anyone but the requester, and once the request is no longer a Draft or Returned. | The SPFx build relied on the Edit buttons being hidden. |
| Reference minting writes five attempts out in full. | The first canvas plan's loop (`app-glue.md` §6) can't be built: Power Apps doesn't allow `Set` inside `ForAll`. |

## Not reproduced

| Item | Note |
|---|---|
| **Reconciliation** (`app-glue.md` §5.2) | The first canvas plan specified a "Reconcile" button that repairs `Catalogue.StockQty` from the ledger. The SPFx build never shipped it (its `findDrift` is unused), so this guide leaves it out. It can be added to Catalogue & stock from §5.2 as written. |
| **Reassign** | The Request detail mock-up has a Reassign button; neither build implements it. |
| **Open in Power BI** | Disabled in both builds. |
