# Appendix D. Glossary

| Term | Meaning |
|---|---|
| **Canvas app** | A Power Apps app you lay out screen by screen, like a slide deck, and wire up with formulas. |
| **Studio** | The Power Apps editor at make.powerapps.com, where you build the app. |
| **Power Fx** | The formula language of canvas apps, close to Excel formulas. |
| **Control** | Anything on a screen: a label, button, gallery, text box, dropdown. |
| **Property** | A setting of a control, such as `Text`, `Fill`, `Visible` or `OnSelect`. A property holds a formula. |
| **Behaviour property** | A property that runs when something happens (`OnSelect`, `OnChange`, `OnVisible`). Only these can save data or set variables. |
| **Gallery** | A control that repeats a template for each row of a table. Every list and table in this app is a gallery. |
| **Collection** | A table held in the app's memory, named `col…`. Filled with `ClearCollect`. |
| **Variable** | A single value held by the app, named `var…`. Set with `Set`. |
| **Named formula** | A value defined once in `App.Formulas` and used by name everywhere (`clrBrand`, `tblStatus`). |
| **Data source** | A SharePoint list the app is connected to. |
| **Delegation** | Asking SharePoint to do the filtering, so the app gets only the rows it needs. A formula that can't be delegated quietly works on the first rows only. |
| **Data row limit** | The most rows the app fetches when a formula can't be delegated. 1 while checking, 2,000 in use. |
| **Choice column** | A SharePoint column with a fixed list of values. Read as `Status.Value`, written as `{ Value: "Submitted" }`. |
| **Shadow column** | A plain column kept beside another so it can be filtered quickly: `StatusRank` beside `Status`, `RequesterEmail` beside `Requester`. |
| **Approval matrix** | The `ApprovalMatrix` list: one row per office, section and stage, naming who acts. |
| **Stage** | One step of a request's journey: Review, Approval, Confirm, Deliver, Receive. |
| **Holder** | The person a request is currently with (`CurrentlyWithEmail`), and the officer in charge beside them (`CurrentlyWithOICEmail`). |
| **OIC** | Officer in charge: a stand-in named on a matrix row, who can act alongside the approver. |
| **Lending office** | An office that can supply another's shortfall (`OfficeSharing`), lower `SharePriority` first. |
| **Ledger** | `StockLedger`: one row for every stock movement. The stock figure on `Catalogue` must always match its newest row. |
| **Reference** | A request's number, `SR-YYYYMM-NNNN`, unique and counting from 1 each month (`RefCounter`). |
| **Recipe** | A block of Power Fx this guide uses on several screens, defined in §7 (R1–R6). |
| **Impersonation** | Opening the app as someone else with `&as=<email>`, for testing only. |
| **Flow** | A Power Automate process. This app has one, `UploadRequestDocument`. |
| **Solution** | A package that carries the app and the flow between environments. |
| **DEF-nnn** | A defect number from the UAT defect log (Appendix B). |
| **UAT** | User acceptance testing: the 31 recorded cases the app must pass. |
