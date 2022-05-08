# TreeTag

TreeTag is a personal data manager.  It stores information in a hierarchy (the
"Tree" part of the name).  But unlike other tree-based applications, TreeTag
automatically positions items in the tree based on field values (the "Tag" part
of the name).

The data items can be set up to have several fields.  Different types of fields
are available, including text, numbers, dates, times and predefined choices. The
output format of each field can be defined for group item headings, for data item
titles and for data item output.

The user configures the base portion of the tree, defining rules that group the
data items into desired categories.  The same items can appear in multiple
locations, with different sections of the tree structure using different fields
for grouping or sorting.  For example, data items can be found by date in one
section, by a name field sorted alphabetically in another, and by some other
category field in another.

## Installation

So far, TreeTag is only available for Android devices.  It's written in Flutter,
so it should be relatively easy to port it to other platforms.  I plan to create
versions for Linux and Windows desktops.  I may also do a version for IOS if I
can find a device for testing.

An APK file is provided that can be downloaded to an Android device and run.
This app is not yet in any app stores.

## Usage

### Files

When TreeTag opens, it shows a list of files in the app's private storage
folder.  It will be empty the first time the app is run.  A tap on a file name
will open the file.  A long press will select the file.

In addition to opening TreeTag files (with a .trtg file extension), it can also
import files from treeLine (with a .trln file extension).  Tapping on these
files will show a prompt to select a single node type to be imported.  Imports
should only be done from basic TreeLine files - formatting and complex field
types are not currently supported.

The "+" icon can be used to create a new file.  If a single file is selected, it
will become an "i" icon, used to show file details (path, modified time and
size).

The three-dots icon shows a menu whose commands vary depending on the currently
selected files.  There are commands that can copy a file to or from an external
folder, make a local copy of a file, rename a file, or delete a file.

Once a file is opened, the "Close File" command in the menu will return to the
file list.

### Tree View

In the tree view, title and grouping nodes are proceeded by small triangles.
These nodes can be tapped to expand or collapse the node's children.  The leaf
nodes, proceeded by circles, contain the data.  They have no children but they
can be tapped to toggle between showing a single title line (the default) or
the output lines.

A long press on a node will open up a detail view listing that node's children
(for title and grouping nodes) or the node output (for a leaf node). The detail
view is described in the next section.

The "+" icon at the top will create a new leaf node and show it in an edit view.
Once the editing is complete, the new node will be properly placed into the
tree.  In many cases, it's easier to start new nodes from the detail view of a
group or leaf node, since at least some of the fields will initially be
populated to match the group or leaf.

The three-dots menu includes commands for the configuration editor and for the
undo list, both described in the following sections.  There is also a command to
export the current data to a TreeLine file.

### Detail View

If started from a title or grouping node, the detail view shows a list of that
node's children.  Child title or grouping nodes show the same line of text as
is shown in the tree view.  Child leaf nodes show the lines that are configured
in the output configuration.

Tapping on a child title or grouping node will show a new detail view with that
node's children.  Tapping on a child leaf node will show a new detail view with
that node by itself.  Tapping the left arrow at the top of the view will return
to the previous view.

Tapping the "+" icon will create a new leaf node and show it in an edit view. If
started from a view of a grouping node or a leaf node, at least some of the
fields will initially be populated to match the group or leaf.

A detail view with an isolated leaf node will show edit (pencil icon) and delete
(trash icon) commands.  The edit command will show an edit view for this leaf
node. The delete command will remove all instances of this leaf node.

### Configure Fields

The Fields tab of the Configuration view lists the fields that are defined for
leaf node data.  Tapping a field name toggles its selection.  There are icons
above the list to create a new field ("+"), edit a field (pencil), delete a
field (trashcan), or move a field up or down (arrows).

Editing a new or existing field shows a form with the field name, type, initial
value, and default prefix and suffix.  When done editing, use the  left arrow at
the top to finish editing.  There is also a reset button on the upper right to
restore previous settings.

The available field types include Text, LongText, Choice, AutoChoice, Number,
Date and Time.  The default type is Text.  LongText is the same except for
showing more lines in the edit view.  The AutoChoice type allows prior values
for the field to be selected from a pull-down menu, or a new value can be typed.

The Choice, Number, Date and Time types add a field format definition editor to
the configuration edit form.  Tapping on the format will show an edit view with
oval chips for each segment of the format.  The chips can be tapped to select
them, and can be edited using the icons above the chips.  The Number, Date and
Time types show a format sample preview below the chips that formats an
arbitrary value.

### Configure the Tree

The Tree tab of the Configuration view shows how the title and grouping nodes
are arranged in the tree.  Tapping a node name toggles its selection.  There are
icons above the tree to create a new node ("+"), edit a node (pencil), delete a
node (trashcan), or move a title node up or down (arrows).  The new node button
shows a menu for adding a title node as a sibling or child of the selected node,
or for adding a group node as a child.

Title nodes function as static headings in the tree.  They form a scaffold that
organizes and arranges the grouping nodes.  When adding and editing title nodes,
a dialog box prompts for the title text.  Deleting a title also removes any
child nodes.

Grouping nodes contain rules that categorize the leaf nodes into groups.  The
rules consist of a field, sometimes combined with other fields or extra text. In
the main tree view, the data from each leaf node is used to fill in the fields,
and the resulting text strings become headings.  Leaf nodes that match that
heading are placed under that heading.  Group nodes can be nested to further
subdivide the leaf nodes, but they cannot have any siblings and cannot have
title nodes as children.  Nested group nodes can also contain the same field as
their parent but with a different field format.  For example, a group node with
a date field could have a field format showing only the year, and a nested group
could have a field format showing months as lower level headings.

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
define other sequences.  Finally, if the group node has no child nodes, child
sorting settings are shown at the bottom.  This defines how the child leaf nodes
are sorted.  The default sorts using all of the fields in ascending order.  The
custom button can be used to define other sequences.

### Configure Output

The Output tab of the Configuration view shows a title line followed by one or
more output lines.  The title line defines how a leaf node is shown as a single
line in the main tree view.  The output lines are combined to define how a leaf
node is shown with multiple lines in the main tree view and in the detail view.

Tapping a title or output line toggles its selection.  There are icons above the
lines to add a new output line ("+"), edit a line (pencil), delete an output
line (trashcan), or move an output line up or down.

Adding or editing a line shows the line editor.  Fields and text that are added
show up as oval chips for each segment of the line.  These chips can be edited,
deleted and moved to fully define the line.  Editing a field chip allows the
user to define a custom prefix and suffix, as well as a field format for
applicable field types.  If not explicitly set, these will use the field
defaults.  Once the line is not empty, the line editor can be exited by using
the left arrow at the top.

### Undo View

Undo operations can be essential because TreeTag is continually writing changes
to the file.  The undo list is also stored in the file.  It contains all undo
operations that have not been explicitly deleted by the user.  The undo items
are listed from oldest to newest.

To undo some operations, select "Undo to here" from the three-dots menu on the
earliest item to be undone.  That item and the newer items will change color to
indicate that they have been selected.  Exiting the view using the left arrow at
the top will complete the undo operation.  The undo can be aborted by selecting
"Cancel undo" on the earliest item set to be undone.

Once operations are undone, they are automatically converted to redo operations.
They can be redone the same as undo operations, by selecting "Undo to here".  An
exception is if undo operations prior to the redo operations are also selected
to be completed.  In this case the redo operations will become gray to indicate
that they will be removed to allow the older undo operations to be completed.

Undo operations can be removed to keep the list manageable and to reduce the
size of the TreeTag data file.  To remove old undo operations, select "Delete to
here" from the three-dots menu on the most recent item to be removed.  That item
and the older items will become gray to indicate that they have been marked for
deletion.  Exiting the view using the left arrow at the top will complete the
deletion.  The deletion can be aborted by selecting "Cancel delete" on the most
recent item set to be removed.
