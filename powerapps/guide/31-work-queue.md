# 5. Work queue — scrWorkQueue

The three work-queue items in the menu (**Review & distribution**, **Distribute**, **Confirm receipt**) open this one screen. It lists the requests waiting on the user at that stage. The mock-ups have no page for it: it looks like Home's "Awaiting my action" card on its own (marker 8 on the Home mock-up in chapter 4), with the title of the queue. The current app added it to fix DEF-10, where those three menu items went back to Home.

`varQueue` says which queue to show. The menu sets it (chapter 3) before it navigates here.

| `varQueue` | Title | Stages it lists | Empty message |
|---|---|---|---|
| `review` | Review & distribution | Review, Approval, Confirm | Nothing is waiting for you to review, approve or confirm. |
| `distribute` | Distribute | Deliver | Nothing is waiting for you to distribute. |
| `receipt` | Confirm receipt | Receive | Nothing is waiting for you to confirm receipt of. |

## Build it

1. Paste the frame (chapter 3) onto `scrWorkQueue`.
2. Copy `recCard1`, its header labels and `galAwaiting` from `scrHome`, paste them here, and rename the gallery `galQueue`.
3. Set the formulas below.

```powerfx
// scrWorkQueue.OnVisible
Set(varNavActive, varQueue);
Set(varPageTitle, Switch(varQueue, "review", "Review & distribution", "distribute", "Distribute", "Confirm receipt"));
ClearCollect(
    colAwaiting,
    SortByColumns(
        Filter(Requests, StatusRank < 70,
               Or(CurrentlyWithEmail = varUserEmail, CurrentlyWithOICEmail = varUserEmail)),
        "SubmittedOn", SortOrder.Ascending
    )
)

// galQueue.Items — this queue's stages only, and never a Draft or Returned request (DEF-128)
Filter(
    colAwaiting,
    LookUp(tblStageAction, StageCode = CurrentStageCode.Value).Screen = varQueue,
    !(Status.Value in ["Draft", "Returned"])
)

// lblQueueCount.Text (the pill beside the card title)
CountRows(galQueue.AllItems)

// btnQueueAction.Text — the stage's row label
LookUp(tblStageAction, StageCode = ThisItem.CurrentStageCode.Value).RowLabel

// btnQueueAction.OnSelect
Set(varRef, ThisItem.Title);
Switch(varQueue, "review", Navigate(scrReview), "distribute", Navigate(scrDistribute), Navigate(scrReceipt))

// galQueue.OnSelect
Set(varRef, ThisItem.Title); Navigate(scrRequestDetail)

// lblQueueEmpty.Text and .Visible
Switch(varQueue,
    "review",     "Nothing is waiting for you to review, approve or confirm.",
    "distribute", "Nothing is waiting for you to distribute.",
    "Nothing is waiting for you to confirm receipt of.")
IsEmpty(galQueue.AllItems)
```

The `Filter` on `galQueue.Items` runs in the app, on `colAwaiting`, which was itself loaded by a filter SharePoint does. That is why it doesn't need to delegate.

!!! see "You should now see"
    As a reviewer with requests at Review, **Review & distribution** lists them with a **Review** button each, and the menu item is highlighted. A request you returned to its requester is not listed.

!!! def "Defects this screen must get right"
    DEF-10 (the menu opens a queue, not Home) · DEF-128 (a Returned request isn't offered for review) · DEF-120 (the button names the stage)
