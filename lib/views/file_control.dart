// file_control.dart, a view showing options for opening a new or existing file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'tree_view.dart';

/// Provides a simple view with buttons to open files.
///
/// Buttons include new file, file browse and recent files (future).
class FileControl extends StatefulWidget {
  @override
  State<FileControl> createState() => _FileControlState();
}

class _FileControlState extends State<FileControl> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TreeTag'),
      ),
      body: ListView(
        children: <Widget>[
          Card(
            child: ListTile(
              title: Text('File Browse'),
              onTap: () async {
                FilePickerResult? result =
                    await FilePicker.platform.pickFiles();
                if (result != null) {
                  PlatformFile fileObj = result.files.single;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TreeView(fileObj: fileObj),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
