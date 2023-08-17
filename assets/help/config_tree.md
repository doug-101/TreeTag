---
# Usage
---
## Configure the Tree
---

The Tree tab of the Configuration view shows how the title and grouping nodes
are arranged in the tree.  Tapping/clicking a node name toggles its selection.
There are icons above the tree to create a new node ("+"), edit a node (pencil),
delete a node (trashcan), or move a title node up or down (arrows).  The new
node button shows a menu for adding a title node as a sibling or child of the
selected node, or for adding a group node as a child.  The delete a node button
shows a menu for deleting just the node or deleting the node along with its
children.

Title nodes function as static headings in the tree.  They form a scaffold that
organizes and arranges the grouping nodes.  The top level of the structure must
consist only of title node(s).  When adding and editing title nodes, a dialog
box prompts for the title text.  Deleting a title with the node only option will
move any child nodes up by one level.

Grouping nodes contain rules that categorize the leaf nodes into groups.  The
rules consist of a field, sometimes combined with other fields or extra text. In
the main tree view, the data from each leaf node is used to fill in the fields,
and the resulting text strings become headings.  Leaf nodes that match are
placed under that heading.  Group nodes can be nested to further subdivide the
leaf nodes, but they cannot have any siblings and cannot have title nodes as
children.  Adding a new child title or group when there is an existing group
node will move the existing group down by one level.

Nested group nodes can also contain the same field as their parent but with a
different field format.  For example, a group node with a date field could have
a field format showing only the year, and a nested group could have a field
format showing months as lower level headings.

Adding a new group node shows a rule line editor.  Fields and text that are
added show up as oval chips for each segment of the rule.  These chips can be
edited, deleted and moved to define the rule.  Editing a field chip allows the
user to define a custom prefix and suffix, as well as a field format for
applicable field types.  If not explicitly set, these will use the field
defaults.  Once the rule line contains at least one field, the line editor can
be exited by using the left arrow at the top. Then a summary view for the group
node will be shown.

The summary view for the group node is also shown when editing an existing group
node. Tapping the rule definition at the top will start the rule line editor
described above.  Group sorting settings are shown below the rule definition.
This defines how the group's headings are sorted.  The default sorts using the
fields from the rule line in ascending order.  The custom button can be used to
define other sequences.  Finally, if the group node has no nested child groups,
child sorting settings are shown below the group sort settings.  This defines
how the child leaf nodes are sorted.  The default sorts using all of the fields
in ascending order.  The custom button can be used to define other sequences.
