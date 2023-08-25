---
# Installation
---

## Android

An APK file (treetag_x.x.x.apk) is provided that can be downloaded to an Android
device and run. This app is not yet in any app stores.

---

## Linux

Extract the files from the archive (treetag_x.x.x.tar.gz) into a user-owned
directory.  You need to have at least 2GB of disk space available for the
automated build.  Then change to the `TreeTag` directory in a terminal, and
run the following commands:

    $ sudo ./tt_make.sh depends
    $ ./tt_make.sh build
    $ sudo ./tt_make.sh install

The first command automatically installs dependencies using the `apt-get`,
`dnf` or `pacman` native packaging system.  If desired, you can manually
install the dependencies in the [Requirements](requirements.md) section and
skip this line.

The second line (build) downloads Flutter and builds TreeTag.

The third line (install) copies the necessary files into directories under
`/opt`.  After this step, the temporary `TreeTag` build directory can be
deleted.

---

## Windows

The simplest approach is to download the "treetag_x.x.x.zip" file and extract
all of its contents to an empty folder.  Then run the "treetag.exe" file.

To compile TreeTag from source, install the TreeTag source from
<https://github.com/doug-101/TreeTag>.  Also install Flutter based on the
instructions in <https://docs.flutter.dev/get-started/install/linux>.  The
Android Setup is not required - just the Linux setup from the bottom of the
page.
