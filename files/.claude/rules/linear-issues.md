# Linear Issues

Any time I point you at a Linear issue, read its activity before acting on it — at least once per issue. The description is a snapshot someone wrote; the activity is what actually happened. Check `stateHistory` and `assignee` from `get_issue`, plus `list_comments`. Linear exposes no actor-attributed activity feed and no assignment history, so current assignee plus state timestamps is all you get — never claim to know who moved a card or when it was assigned.

## Assignment guard

If the status name starts with "In" — In Progress, In Review, In Test — confirm the card is assigned to me before doing any work on it. Unassigned, or assigned to someone else: stop and tell me. Don't start, and don't set the assignee yourself; that needs an explicit yes from me every time.

Ask rather than guess when:

- the status isn't literally an "In *" column but looks active (Ready for Review, Ready for Test)
- it's assigned to someone else and unclear whether that's intentional
- it's ambiguous whether the work belongs to that card at all
