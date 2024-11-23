---
# Usage
---
## Configure Fields
---

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

The field configuration edit form includes an option for allowing multiple
entries.  If enabled, a plus sign will appear at that field when editing a leaf
node.  Clicking the plus will add an extra entry for that field.  This allows
leaf nodes to show under multiple categories.  Any blank entries will be removed
after editing.  Enabling this option in the field configuration edit form also
shows a field separator option.  This separator is used in leaf node outputs to
join multiple entries.  By default, it is set to a comma and a space.  Use a
"\n" in the separator to show the entries on different lines, duplicating the
entire output line.  Note that two fields with the multiple entries option
enabled can not be combined in the same rule or output line. Also note that
multiple entry fields do not work well when nested rules use that same field
with different formats (such as date field rules for years then for months).
