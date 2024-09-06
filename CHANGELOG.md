
---
## September 15, 2024 - Release 0.7.4 (stable)

### Updates:
- Made several minor code cleanup changes.
- Updated several versions of library code used for building TreeTag.
- Converted to a newer style of Android plugin build settings.
- Added metadata to support an F-Droid build.

---
## July 24, 2024 - Release 0.7.3 (stable)

### New Features:
- Added a setting to hide the windows title bar on desktop platforms.
  This is useful for improving the appearance under Linux/Wayland.

### Updates:
- Made many minor code cleanup changes.
- Updated several versions of library code used for building TreeTag.
- Updated to use the latest target API (level 34) for Android.

### Bug Fixes:
- Fixed problems with permissions for the copy to folder command under
  Android.
- Display search results properly formatted when using Markdown
  formatting. Matches are also properly highlighted.

---
## November 30, 2023 - Release 0.7.2 (stable)

### Bug Fixes:
- Fixed theme color visibility problems under the new Material 3
  default settings.

---
## November 26, 2023 - Release 0.7.1 (stable)

### Updates:
- A file path given in the command line will be opened at startup.
- The maximum width of several views has been reduced to improve the
  appearance.
- The minimum size of the desktop window has been adjusted.
- A warning was added to the Linux installer if the /usr/local/bin
  directory used for the startup symlink is not in the PATH variable.

### Bug Fixes:
- The Linux installer explicitly sets permissions for the installation
  directory rather than relying on the system mask settings.

---
## August 27, 2023 - Release 0.7.0 (stable)

### New Features:
- Created a new script for Linux installation. It uses the native
  packaging system to install dependencies, builds TreeTag and
  installs it. This replaces the TreeTag snap package, which is no
  longer supported.
- On desktop systems, a new interface can easily add local file links
  in Markdown text fields. Clicking on a link opens the default
  application for that file type. A setting controls whether new
  links use full or relative paths.

### Updates:
- The Android version of TreeTag is now available in the Google Play
  store.
- Changed the file list to use a case-insensitive sort order.
- Improved the built-in help interface by splitting pages and adding
  navigation controls.
- Added tooltips to most of the icon buttons.

### Bug Fixes:
- Fixed indenting of multi-line fields when exporting indented text.
- Fixed the appearance of the application bar when using a dark theme
  with Markdown text fields.

---
## May 26, 2023 - Release 0.6.0 (stable)

### New Features:
- An option was added to select between light and dark visual themes.
- Added a view scale setting that is useful for high-dpi displays.
- Added a command to export the TreeTag tree to an indented text file.
- Before saving a file, TreeTag checks for external modifications from
  other sessions or over a network. The user has options to load or
  overwrite the file.

### Updates:
- If a leaf node moves due to field edits, its new parent is
  automatically opened to make the new position visible.
- The code was updated to use the Dart version 3.0 library.

### Bug Fixes:
- Switched to a forked version of a Markdown library to make select
  and copy commands work properly in Markdown detail output.

---
## March 31, 2023 - Release 0.5.0 (stable)

### New Features:
- Improved searching by adding options to search by phrase, keywords
  or regular expressions.
- Added highlighting of matched words to the search results.
- Implemented a replace function for use on search results. On regular
  expression searches, matched groups can be substituted back into the
  replacement string.
- Added an option on desktop platforms to restore the previously used
  window size and position at startup.

### Updates:
- When a new field is configured, ask the user whether it should be
  automatically added as an output line.
- Trim leading and trailing spaces from new file names entered for
  new, copy and rename operations.

### Bug Fixes:
- Fixed spell checking of words in angle brackets.

---
## February 21, 2023 - Release 0.4.0 (beta)

### New Features:
- Added a spell checker that shows misspelled English words with a red
  underline by default. Currently, making spelling suggestions is not
  supported on desktop platforms.
- Added functions to import and output node data as CSV files.
- A new command merges node data from a second TreeTag file. This is
  useful to add data from a CSV imported file without affecting the
  configuration.
- A new setting automatically removes undo operations stored in
  TreeTag files that are older than a set number of days.

### Updates:
- TreeTag is now available as a snap on Linux platforms. This should
  eliminate previous issues with some library dependencies.
- Placed the filename earlier in the window header text to avoid
  truncating it on narrow screens.

### Bug Fixes:
- Fixed a bug that could revert changes in data editors when they were
  scrolled far out of view.
- Fixed problems using the data editor reset command with auto choice
  fields.
- Fixed issues with file extensions for other file types when copying
  or renaming files.

---
## January 14, 2023 - Release 0.3.0 (beta)

### New Features:
- Added optional display of formatted text using Markdown text tags.
- Added support for storing and retrieving files from a Kinto network
  server.

---
## October 29, 2022 - Release 0.2.0 (beta)

### New Features:
- Added a search function.
- Added commands to edit or delete multiple child nodes
  simultaneously.
- Added the ability to select and copy text from the detail view.

---
## July 30, 2022 - Release 0.1.0 (beta)

### New Features:
- Ported TreeTag to Linux and Windows desktops.
- Added a two-pane view on wide screens.
- Added sample files.

### Bug Fixes:
- Many bug fixes.

---
## May 9, 2022 - Release 0.0.3 (beta)

### New Features:
- Added import and export to/from TreeLine files.

---
## April 23, 2022 - Release 0.0.2 (beta)

### Updates:
- Updated build parameters to work with older Android devices.

---
## April 19, 2022 - Release 0.0.1 (beta)

### New Features:
- Initial release.
