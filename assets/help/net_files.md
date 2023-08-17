---
# Usage
---
## Network Files
---

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
