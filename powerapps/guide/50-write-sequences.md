# 13. The buttons that save

This chapter holds every formula that writes to SharePoint. The sections keep the numbers they have in `powerapps/app-glue.md` (§7 to §15), so the file and this guide always agree. The screen chapters point here by those numbers.

Wire them up in this order, testing each against its screen before the next:

| Order | Section | Button | Screen |
|---|---|---|---|
| 1 | §8 | `btnCreateCore` (Save draft, Submit) | New request |
| 2 | §9 | `btnResubmitCore` (Resubmit) | New request, in edit mode |
| 3 | §10 | `btnProceed` | Review |
| 4 | §11 | `btnDialogConfirm` (Return, Reject) | Review |
| 5 | §12 | `btnRecordDistribution` | Distribute |
| 6 | §13 | `btnConfirmReceipt` | Confirm receipt |
| 7 | §14 | `btnPostComment`, `btnAttach` | Request detail |
| 8 | §15 | the dialogs' Save buttons, `btnValidateChain` | Catalogue & matrix |

!!! trap "Before you press any of them"
    Raise the data row limit back to 2,000 first (chapter 15). With the limit at 1, a total the formula adds up comes from one row, and the wrong number would be saved.

Each diagram shows what one button writes, in order. A step that fails stops what comes after it, and the button tells the user what was and wasn't saved.

::include ../app-glue.md sections=7-15
