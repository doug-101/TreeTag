// file_control.dart, a view showing options for opening a new or existing file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tree_view.dart';
import '../model/structure.dart';

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
                  var fileRootName = fileObj.name;
                  var ext = fileObj.extension;
                  if (ext != null) {
                    var endPos = fileRootName.length - ext.length - 1;
                    if (endPos > 0)
                      fileRootName = fileRootName.substring(0, endPos);
                  }
                  var model = Provider.of<Structure>(context, listen: false);
                  model.openFile(fileObj.path);
                  Navigator.pushNamed(context, '/treeView',
                      arguments: fileRootName);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
