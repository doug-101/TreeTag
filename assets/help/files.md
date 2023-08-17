---
# Usage
---
## Files
---

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
