---
# Usage
---
## Tree View
---

In the tree view, title and grouping nodes are proceeded by small triangles.
These nodes can be tapped/clicked to expand or collapse the node's children.
The leaf nodes, proceeded by circles, contain the data.  They have no children
but they can be tapped/clicked to toggle between showing a single title line
(the default) or multiple output lines.

A long press/click on a tree node will show a detail view listing that node's
children (for title and grouping nodes) or the node output (for a leaf node). On
wide screens/windows (generally on desktops or tablets), the detail view is
shown to the right of the tree view.  Otherwise it temporarily covers the tree
view.  The detail view is described in the next section.  The tree view will
highlight current parent or node in the detail view.

The "+" icon in the top bar will create a new leaf node and show it in an edit
view.  Once the editing is complete, the new node will be properly placed into
the tree.  In many cases, it's easier to start new nodes when the detail view is
showing a group or leaf node, since at least some of the fields will initially
be populated to match the group or leaf.

The magnifying glass icon will show a search view for finding matching leaf
nodes.  If the detail view is showing a grouping node, search results will be
limited to the children of that group.  If the detail view is showing a title
node or no node, all leaf nodes will be searched.  Note that searching is not
available if a leaf node is being shown.  The search view menu can be used to
set the search method to a phrase, keywords or regular expressions.  Note that
only regular expressions are case sensitive.  The menu can also select between
searching in a specific field, in all fields, or in all output.  As a string is
typed in the top bar, matching nodes will be shown in the main view.
Tapping/clicking on a resulting node will select it and show its full output,
with the matching text highlighted.  The last node selected when leaving the
search view will become current in the detail view and expanded in the tree.
There is also a replace option in the menu when searching by phrase or regular
expression.  When searching with regular expressions, adding "$1", "$2", etc.
in the replacement string will substitute matching groups from the search
results.

The hamburger (three lines) menu includes commands for the configuration
editor, the settings view and the undo list, all described in subsequent
sections.  There is also a command to merge the data from a second file.  The
second file should have similar fields, but any missing fields will be added as
necessary.  Otherwise, the configuration of the current file is kept.  Finally,
there are commands to export the current data to a TreeLine file, to a CSV file
or to an indented text file.  The CSV export gives options for field text to be
as output (same as displayed) or as stored (better for re-import).  The
indented text export gives options to include titles only or all node output
lines.
