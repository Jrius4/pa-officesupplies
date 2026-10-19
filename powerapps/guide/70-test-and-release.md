# 15. Test, run UAT and release

## Step 1 — the delegation check, at a row limit of 1

Do this when every screen shows data and **before** any button that saves has been pressed (chapter 2 explains why).

1. Check **Settings › General › Data row limit** is still **1**.
2. Open each screen in Preview, as the persona who sees most on it, and check the lists below still show all their rows. A list that shows one row, or none, has a formula SharePoint can't run.

| Screen | The list to check | Expected with the seeded data |
|---|---|---|
| Home | `galAwaiting`, `galMine` | Every request the persona holds / raised |
| Work queue | `galQueue` | Every request at that stage |
| New request | the product picker | Every active item of the office |
| Request detail | items, timeline, comments | Every line and every event |
| Review | `galReview` | Every line, with stock |
| Distribute | `galDist` | Every line still owed |
| Admin | `galCatalogue` | Every item of the office, active or not |
| Reports | the tiles | The same numbers as at 2,000 |

The four start-up collections (`colOffices`, `colMatrix`, `colSharing`, `colMyRoles`) hold one row each at this limit. That's expected: they are loaded whole, by design, and are checked at 2,000.

!!! trap "If a list comes back with one row"
    Hover over the blue underline or the warning triangle on its formula: Studio names the part it can't send to SharePoint. The fix is nearly always in the formula's filter (use `=`, `<`, `>` on an indexed text, number or date column; never `<>`, `Not`, `IsBlank` or `Search` on a SharePoint list), not in the screen. Appendix A lists the indexed columns.

## Step 2 — raise the limit and test the buttons

1. Set **Data row limit** to **2000**.
2. Check `colMatrix` holds the seeded matrix rows and `colMyRoles` your roles (**Variables**, the *(x)* icon).
3. Wire up and test the buttons in the order of chapter 13.

!!! see "The test that matters most"
    Submit one request and check SharePoint: exactly **one** new row in `Requests`, its lines in `RequestItems`, and two rows in `RequestTimeline`. Then submit two requests at the same moment from two browsers: both get references, and they differ.

## Step 3 — user acceptance testing

Run the 31 cases the SPFx build passed, in the same order and with the same people. The full list, with where each is tested in the canvas app, is below. Each case's steps and expected results are in `pa.init.officesupplies/uat/scenarios/<case>.md`; they describe the same screens, so they apply to the canvas app unchanged, with one difference: instead of the web part's "impersonate email" setting, add `&as=<email>` to the app link.

To get the app link: in **make.powerapps.com › Apps**, select **⋯ › Details** on Office Supplies and copy the **Web link**. It looks like `https://apps.powerapps.com/play/e/<environment>/a/<app id>?tenantId=…`. Add `&as=daniel.otieno@…` to the end to open it as that persona.

::include ../uat-mapping.md from="## UAT cases" to="## Defect checklist" demote=1

## Step 4 — release

1. **Turn off testing access.** In `App.Formulas`, set `cfgAllowImpersonation = false`.
2. **Save and publish.** **File › Save**, then **Publish › Publish this version**.
3. **Share.** Select **Share** on the app, add the users (a Microsoft Entra security group is easiest), and leave **Co-owner** unticked for everyone but makers. Each user also needs **Contribute** on the SharePoint site, and must exist in `AppRoles` to see their work.
4. **Share the flow.** Users run `UploadRequestDocument` as themselves, so nothing more is needed. If the flow's owner leaves, add a co-owner to the flow so it keeps working.
5. **Tell users the first launch asks for permission** to use SharePoint: they select **Allow**.

## Moving between environments

If you build in a test environment and release to production, put the app and the flow in a **solution**:

1. In **make.powerapps.com › Solutions**, create a solution called `Office Supplies` with your publisher.
2. Select **Add existing › App › Canvas app** and pick the app, then **Add existing › Automation › Cloud flow** and pick `UploadRequestDocument`.
3. Studio creates **connection references** for the SharePoint connection. When you import the solution into production, you pick the production connection for each.
4. If production uses a different SharePoint site, turn on the Studio setting **Automatically create environment variables when adding data sources** (under **Settings**) before adding the lists, so the site address becomes an environment variable you can change on import.
5. Export the solution as **managed** for production, **unmanaged** for keeping in source control.

## Keeping this repository in step with the app

The app lives in Studio; the repository keeps a copy of each screen so changes can be reviewed.

1. In Studio, right-click a screen in the Tree view and select **View code**, then **Copy code**.
2. On macOS, in a terminal at the repository root: `pbpaste > powerapps/screens/<screen>.pa.yaml`. On Windows, paste into the file in a text editor.
3. Commit the change. Studio removes comments and sorts properties alphabetically, so the copy won't look like what you typed; that's expected (`oracle/NOTES.md` §19).

Keep `App.Formulas.fx`, `App.OnStart.fx` and `app-glue.md` §7–§15 in step the same way: when you change a formula in Studio, change it here too.
