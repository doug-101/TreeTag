// file_control.dart, a view showing options for opening a new or existing file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

enum MenuItems { addFromFolder, copy, copyToFolder, rename, delete }

class _FileControlState extends State<FileControl> {
  late Directory workDir;
  var fileList = <File>[];
  var selectFiles = <File>{};
  final _filenameEditKey = GlobalKey<FormFieldState>();

  @override
  void initState() {
    super.initState();
    _findWorkDir();
  }

  void _findWorkDir() async {
    if (Platform.isAndroid) {
      var dir = await getExternalStorageDirectory();
      if (dir == null) dir = await getApplicationDocumentsDirectory();
      workDir = dir;
    } else {
      workDir = await getApplicationDocumentsDirectory();
    }
    _updateFileList();
  }

  void _updateFileList() async {
    fileList.clear();
    selectFiles.clear();
    await for (var entity in workDir.list()) {
      if (entity != null && entity is File) fileList.add(entity);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((selectFiles.isEmpty)
            ? 'TreeTag Files'
            : '${selectFiles.length} Selected'),
        actions: <Widget>[
          if (selectFiles.isEmpty)
            IconButton(
              // New file command.
              icon: const Icon(Icons.add_box),
              onPressed: () async {
                var filename =
                    await filenameDialog(label: 'Nane for the new file:');
                if (filename != null) {
                  var fileObj = File(p.join(workDir.path, filename + '.trtg'));
                  var model = Provider.of<Structure>(context, listen: false);
                  model.newFile(fileObj);
                  Navigator.pushNamed(context, '/treeView', arguments: filename)
                      .then((value) async {
                    _updateFileList();
                  });
                }
              },
            ),
          if (selectFiles.length == 1)
            IconButton(
              icon: const Icon(Icons.info),
              onPressed: () {
                fileInfoDialog(File(selectFiles.first.path));
              },
            ),
          PopupMenuButton(
            icon: const Icon(Icons.menu),
            onSelected: (result) async {
              switch (result) {
                case MenuItems.addFromFolder:
                  FilePickerResult? answer =
                      await FilePicker.platform.pickFiles();
                  if (answer != null) {
                    var cachePath = answer.files.single.path;
                    if (cachePath != null) {
                      var newName = p.basenameWithoutExtension(cachePath);
                      var newPath = p.join(workDir.path, newName + '.trtg');
                      if (File(newPath).existsSync()) {
                        var ans = await confirmOverwriteDialog(newName);
                        if (ans == null || !ans) {
                          FilePicker.platform.clearTemporaryFiles();
                          break;
                        }
                      }
                      await File(cachePath).copy(newPath);
                      setState(() {
                        _updateFileList();
                      });
                      FilePicker.platform.clearTemporaryFiles();
                    }
                  }
                  break;
                case MenuItems.copy:
                  var initName =
                      p.basenameWithoutExtension(selectFiles.first.path);
                  var answer = await filenameDialog(
                    initName: initName,
                    label: 'Copy "$initName" to:',
                  );
                  if (answer != null) {
                    var newPath = p.join(workDir.path, answer + '.trtg');
                    if (File(newPath).existsSync()) {
                      var ans = await confirmOverwriteDialog(answer);
                      if (ans == null || !ans) break;
                    }
                    await selectFiles.first.copy(newPath);
                    setState(() {
                      _updateFileList();
                    });
                  }
                  break;
                case MenuItems.copyToFolder:
                  String? folder = await FilePicker.platform.getDirectoryPath();
                  if (folder != null) {
                    var newPath =
                        p.join(folder, p.basename(selectFiles.first.path));
                    if (File(newPath).existsSync()) {
                      var ans = await confirmOverwriteDialog(
                          p.basenameWithoutExtension(selectFiles.first.path));
                      if (ans == null || !ans) break;
                    }
                    if (await Permission.storage.request().isGranted) {
                      try {
                        await selectFiles.first.copy(newPath);
                      } on FileSystemException {
                        await errorConfirmDialog('Could not write to $newPath');
                      }
                    } else if (await Permission.storage
                        .request()
                        .isPermanentlyDenied) {
                      await openAppSettings();
                    }
                  }
                  break;
                case MenuItems.rename:
                  var initName =
                      p.basenameWithoutExtension(selectFiles.first.path);
                  var answer = await filenameDialog(
                    initName: initName,
                    label: 'Rename "$initName" to:',
                  );
                  if (answer != null) {
                    var newPath = p.join(workDir.path, answer + '.trtg');
                    if (File(newPath).existsSync()) {
                      var ans = await confirmOverwriteDialog(answer);
                      if (ans == null || !ans) break;
                    }
                    await selectFiles.first.rename(newPath);
                    setState(() {
                      _updateFileList();
                    });
                  }
                  break;
                case MenuItems.delete:
                  var deleteOk = await confirmDeleteDialog();
                  if (deleteOk ?? false) {
                    for (var file in selectFiles) {
                      file.deleteSync();
                    }
                    setState(() {
                      _updateFileList();
                    });
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              if (selectFiles.isEmpty)
                PopupMenuItem(
                  child: Text('Add from folder'),
                  value: MenuItems.addFromFolder,
                ),
              if (selectFiles.length == 1)
                PopupMenuItem(
                  child: Text('Create a copy'),
                  value: MenuItems.copy,
                ),
              if (selectFiles.isNotEmpty)
                PopupMenuItem(
                  child: Text('Copy to folder'),
                  value: MenuItems.copyToFolder,
                ),
              if (selectFiles.length == 1)
                PopupMenuItem(
                  child: Text('Rename'),
                  value: MenuItems.rename,
                ),
              if (selectFiles.isNotEmpty)
                PopupMenuItem(
                  child: Text('Delete'),
                  value: MenuItems.delete,
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: _fileRows(context),
      ),
    );
  }

  List<Widget> _fileRows(BuildContext context) {
    final items = <Widget>[];
    for (var fileObj in fileList) {
      items.add(
        Card(
          color: (selectFiles.contains(fileObj))
              ? Theme.of(context).highlightColor
              : null,
          child: ListTile(
            title: Text(p.basenameWithoutExtension(fileObj.path)),
            onTap: () {
              var model = Provider.of<Structure>(context, listen: false);
              model.openFile(fileObj);
              Navigator.pushNamed(context, '/treeView',
                      arguments: p.basenameWithoutExtension(fileObj.path))
                  .then((value) async {
                _updateFileList();
              });
            },
            onLongPress: () {
              setState(() {
                if (selectFiles.contains(fileObj)) {
                  selectFiles.remove(fileObj);
                } else {
                  selectFiles.add(fileObj);
                }
              });
            },
          ),
        ),
      );
    }
    return items;
  }

  Future<String?> filenameDialog({String? initName, String? label}) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New Filename'),
          content: TextFormField(
            key: _filenameEditKey,
            decoration: InputDecoration(labelText: label ?? ''),
            initialValue: initName ?? '',
            validator: (String? text) {
              if (text?.isEmpty ?? false) return 'Cannot be empty';
              if (text?.contains('/') ?? false)
                return 'Cannot contain "/" characters';
              if (text == initName) return 'A new name is required';
              return null;
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                if (_filenameEditKey.currentState!.validate()) {
                  Navigator.pop(context, _filenameEditKey.currentState!.value);
                }
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, null),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> confirmOverwriteDialog(String filename) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Overwrite?'),
          content: Text('File $filename already exists.\nOverwrite it?'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context, true),
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> confirmDeleteDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete?'),
          content: Text(selectFiles.length == 1
              ? 'Delete 1 item?'
              : 'Delete ${selectFiles.length} items?'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context, true),
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> errorConfirmDialog(String errorText) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(errorText),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );
  }

  void fileInfoDialog(File fileObj) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title:
              Text('File Info - ${p.basenameWithoutExtension(fileObj.path)}'),
          content: Text('Full Path: ${fileObj.path}\n\n' +
              'Last Modiified: ${fileObj.lastModifiedSync().toString()}\n\n' +
              'Size: ${fileObj.statSync().size} bytes'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }
}
