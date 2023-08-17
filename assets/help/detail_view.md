---
# Usage
---
## Detail View 
---

If started from a title or grouping node, the detail view shows a list of that
node's children.  Child title or grouping nodes show the same line of text as
is shown in the tree view.  Child leaf nodes show the lines that are configured
in the output configuration.

Tapping/clicking on a child title or grouping node will show a new detail view
with that node's children.  Tapping/clicking on a child leaf node will show a
new detail view with that node by itself.  Tapping/clicking the left arrow above
the view will return to the previous view.

Tapping/clicking the "+" icon will create a new leaf node and show it in an edit
view. If started from a view of a grouping node or a leaf node, at least some of
the fields will initially be populated to match the group or leaf.

A detail view showing the children of a title node or a grouping node will have
a three-dots menu.  This menu includes commands to edit or delete all descendant
leaf nodes.  The edit command will show an edit view filled with data that is
common to all nodes.  The edits from adding or changing any fields will be
applied to all of the nodes.  The delete command will remove all of the
descendant leaf nodes.  Deleting with a title node as the current parent will
remove all leaf nodes from the file.

A detail view with an isolated leaf node will show edit (pencil icon) and delete
(trash icon) commands.  The edit command will show an edit view for this leaf
node. The delete command will remove all instances of this leaf node.

Also, text can be selected and copied from an isolated leaf node in a detail
view.
