---
# TreeTag
---

TreeTag is a personal data manager.  It stores information in a hierarchy (the
"Tree" part of the name).  But unlike other tree-based applications, TreeTag
automatically positions items in the tree based on field values (the "Tag" part
of the name).

The data items are generally configured to contain several fields.  Different
types of fields are available, including text, numbers, dates, times and
predefined choices. The output format of each field can be defined for group
headings, for data item titles and for data item output.

The user configures the base portion of the tree, defining rules that will group
the data items into desired categories.  The same items can appear in multiple
locations, with sections of the tree structure using different fields for
grouping or sorting.  For example, data items can be arranged by date in one
section, by a name field sorted alphabetically in another, and by some other
category field in another.  This allows the differently organized portions of
the tree to act almost like predefined searches.

Also visit <http://treetag.bellz.org> for more information.

# Features

* Stores almost any type of information, including plain text, formatted text,
  numbers, dates, times, booleans, URLs, etc.
* Nodes can have several fields that form a mini-database.
* The user-defined tree structure automatically keeps things organized.
* The same nodes can appear in multiple locations.
* Users can drill down into various sections of the tree to find nodes using
  different criteria.
* Pressing on a leaf node in the tree expands it to show its full output.
* A long or double press on a node in the tree opens a detail view showing the
  full output of the node and any children.
* Creating a new leaf node when the detail view shows a grouping node will
  pre-populate fields to match the group.
* A keyword search will list all matching nodes from an active group or from the
  entire tree.
* By default, the text field editor will show misspelled English words with a
  red underline.
* Undo operations are stored in the files, so operations from a previous session
  can be undone.
* The data from a two TreeTag files can be merged together.
* Files can be imported and exported to or from both TreeLine and CSV files.
* TreeTag can interface with a Kinto storage server to store and retrieve files
  from the cloud.

# System Requirements

## Android

TreeTag should run on Android 4.1 (Jelly Bean) and above.

## Linux

TreeTag should run on any 64-bit Linux OS.  There is no support for 32-bit
platforms.

## Windows

TreeTag should run on Windows 10 and above, 64-bit.  There is no support for
32-bit platforms.

## macOS

Due to a lack of Macs for testing, TreeTag on macOS is not supported.
Assistance with creating a Mac port would be appreciated.

## iOS

Due to a lack of hardware for development and testing, TreeTag on iOS is not
supported.  Assistance with creating an iOS port would be appreciated.

# Installation

## Android

An APK file (treetag_x.x.x.apk) is provided that can be downloaded to an Android
device and run. This app is not yet in any app stores.

## Linux

The simplest approach is to install from a snap.  If not already installed,
install snapd from a distribution package.  Then enter "sudo snap install
treetag" in a terminal.

To compile TreeTag from source, install the TreeTag source from
<https://github.com/doug-101/TreeTag>.  Also install Flutter based on the
instructions in <https://docs.flutter.dev/get-started/install/linux>.  The
Android Setup is not required - just the Linux setup from the bottom of the
page.  In addition to the libraries noted in the Flutter instructions, TreeTag
also requires zenity to be installed.

## Windows

The simplest approach is to download the "treetag_x.x.x.zip" file and extract
all of its contents to an empty folder.  Then run the "treetag.exe" file.

To compile TreeTag from source, install the TreeTag source from
<https://github.com/doug-101/TreeTag>.  Also install Flutter based on the
instructions in <https://docs.flutter.dev/get-started/install/linux>.  The
Android Setup is not required - just the Linux setup from the bottom of the
page.

# Usage

## Files

When TreeTag opens, it shows a list of files in the app's private storage
folder.  It will be empty the first time the app is run.  A tap/click on a file
name will select the file.  A double tap/click or a long press/click will open
the file.

In addition to opening TreeTag files (with a .trtg file extension), it can also
import files from TreeLine (with a .trln file extension).  Double or long
tapping/clicking on these files will show a prompt to select a single node type
to be imported. Imports should only be done from basic TreeLine files -
formatting and complex field types are not currently supported.

If a file to be opened is not a TreeTag or a TreeLine file, it will try to
import it as a CSV table.  The first row becomes the field names, and every
subsequent row becomes a leaf node.  The file will have a simple tree structure
that can then be configured manually to add more categories.

In the top bar, the "+" icon can be used to create a new file.  When a single
file is selected, it will instead show an "i" icon, used to show file details
(path, modified time and size).

The three-dots icon shows a menu whose commands vary depending on how many
files are currently selected.  There are commands that can copy a file to or
from an external folder, make a local copy of a file, rename a file, or delete
a file.

Selecting "Sample Files" from the hamburger (three lines) menu on the left
shows a list of available samples.  A double tap/click or a long press/click
will open a sample.  If the sample is edited, a modified copy will show up in
the app's working storage folder.

Once a file is opened, the "Close File" command in the menu will return to the
file list.

## Network Files

TreeTag can interface with a Kinto storage server to access files from multiple
devices or locations.  You can either install and run your own server or choose
a low-cost cloud provider.

The server information is entered under the Settings item in the hamburger menu.
The Network Address is set to the full URL of a specific bucket object on a
Kinto server.  The Network User Name must also be set.  Setting the Network
Password item is optional.  If not set (the more secure option), TreeTag will
prompt you for the password once per session.

Use the Local and Network Storage items in the hamburger menu to switch between
network and local storage.  The file list and commands work basically the same
way under both.  The upload and download commands can be used to copy a file
from one storage area to the other.  Note that only JSON files, such as TreeTag
and TreeLine file formats, can be stored in the network.

## Tree View

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
view. Once the editing is complete, the new node will be properly placed into
the tree.  In many cases, it's easier to start new nodes when the detail view is
showing a group or leaf node, since at least some of the fields will initially
be populated to match the group or leaf.

The magnifying glass icon will show a search view for finding leaf nodes that
match key words.  If the detail view is showing a grouping node, search results
will be limited to the children of that group.  If the detail view is showing a
title node or no node, all leaf nodes will be searched.  As key words are typed
in the top bar, matching nodes will be shown in the main view.  The key words
are matched individually, not as a complete phrase.  Tapping/clicking on a
resulting node will select it and show its full output.  A node that is selected
when leaving the search view will become current in the detail view and expanded
in the tree.

The hamburger (three lines) menu includes commands for the configuration editor,
the settings view and the undo list, all described in subsequent sections. There
is also a command to merge the data from a second file.  The second file should
have similar fields, but any missing fields will be added as necessary.
Otherwise, the configuration of the current file is kept.  Finally, there are
commands to export the current data to a TreeLine file or to a CSV file. The CSV
export gives options for field text to be as output (same as displayed) or as
stored (better for re-import).

## Detail View

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

## Configure Fields

The Fields tab of the Configuration view lists the fields that are defined for
leaf node data.  Tapping/clicking a field name toggles its selection.  There are
icons above the list to create a new field ("+"), edit a field (pencil), delete
a field (trashcan), or move a field up or down (arrows).

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
oval chips for each segment of the format.  The chips can be tapped/clicked to
select them, and can be edited using the icons above the chips.  The Number,
Date and Time types show a format sample preview below the chips that formats an
arbitrary value.

## Configure the Tree

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

## Configure Output

The Output tab of the Configuration view shows a title line followed by one or
more output lines.  The title line defines how a leaf node is shown as a single
line in the main tree view.  The output lines are combined to define how a leaf
node is shown when expanded in the main tree view and in the detail view.

Tapping/clicking a title or output line toggles its selection.  There are icons
above the lines to add a new output line ("+"), edit a line (pencil), delete an
output line (trashcan), or move an output line up or down.

Adding or editing a line shows the line editor.  Fields and text that are added
show up as oval chips for each segment of the line.  These chips can be edited,
deleted and moved to fully define the line.  Editing a field chip allows the
user to define a custom prefix and suffix, as well as a field format for
applicable field types.  If not explicitly set, these will use the field
defaults.  Once the line is not empty, the line editor can be exited by using
the left arrow at the top.

## Configure Options

The Options tab of the Configuration view shows only one option: to enable
Markdown text formatting.  If enabled, text entries with Markdown syntax will
show formatted text in the Tree and Detail Views.  Many guides to markdown
syntax are available on the web.  TreeTag specifically supports the GitHub
Flavored Markdown version.  Clickable links to http and https addresses can be
entered with the link text enclosed in square brackets followed by the address
in parenthesis.

## Undo View

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

## Settings View

The settings view contains general customization options.  Options not
previously discussed include hiding dot files, tight line spacing, remember
window geometry and enabling spell checks.  File names that begin with a dot
will not be shown if the hidden option is enabled. The tight line spacing option
allows more lines to fit on the screen.  It is recommended when using a mouse,
but may not leave enough space for touch interfaces.  The window size and
position will be restored from the previous session use if enabled.  The red
underline under misspelled English words is controlled by the spell check
setting.  Currently, no suggestions are shown for misspelled words on desktop
platforms.

On desktop platforms, there is also an option to set the working directory.
This is where all files in the main file list are stored.
