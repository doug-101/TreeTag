---
# Usage
---
## Undo View
---

Undo operations can be essential because TreeTag is continually writing changes
to the file.  The undo list is also stored in the file.  It contains all undo
operations that have not been explicitly deleted by the user.  The undo items
are listed from oldest to newest.

To undo some operations, select "Undo to here" from the three-dots menu on the
earliest (highest) item to be undone.  That item and the lower, newer items will
change color to indicate that they have been selected.  Exiting the view using
the left arrow at the top will complete the undo operation.  The undo can be
aborted by selecting "Cancel undo" on the earliest item set to be undone.

Once operations are undone, they are automatically converted to redo operations.
They can be redone the same as undo operations, by selecting "Undo to here".  An
exception is if undo operations prior to the redo operations are also selected
to be completed.  In this case the redo operations will become gray to indicate
that they will be removed to allow the older undo operations to be completed.

Undo operations can be removed to keep the list manageable and to reduce the
size of the TreeTag data file.  To remove old undo operations, select "Delete to
here" from the three-dots menu on the most recent (lowest) item to be removed.
That item and the higher, older items will become gray to indicate that they
have been marked for deletion.  The deletion can be aborted by selecting "Cancel
delete" on the most recent item set to be removed.  Exiting the view using the
left arrow at the top will complete the deletion.  Once completed, deleted items
cannot be recovered.

In TreeTag Settings, there is an option for the Days to Store Undo History.
Undo operations older than this many days are not written to files.  This does
not remove undos currently in a session - it only affects what is written.  So
undo operations from the most recent changes will always be available, even if
older than this setting.  They only disappear after more changes are made
(written to a file), and then the file is closed.  Setting the number of days to
0 will prevent all undo operations from being written to files.  Setting it to a
very large number will effectively prevent undos from being automatically
removed.
