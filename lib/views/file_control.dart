// file_control.dart, a view showing options for opening a new or existing file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
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

/// Provides a file listview with options for new files, open files, etc.
///
/// File handling options include new, open, copy, add from folder, rename,
/// and delete.
class FileControl extends StatefulWidget {
  @override
  State<FileControl> createState() => _FileControlState();
}

enum MenuItems { addFromFolder, copy, copyToFolder, rename, delete }

class _FileControlState extends State<FileControl> {
  late final Directory _workDir;
  final _fileList = <File>[];
  final _selectedFiles = <File>{};
  final _filenameEditKey = GlobalKey<FormFieldState>();

  @override
  void initState() {
    super.initState();
    _findWorkDir();
  }

  void _findWorkDir() async {
    if (Platform.isAndroid) {
      // Use "external" user-accessible location if possible.
      var dir = await getExternalStorageDirectory();
      if (dir == null) dir = await getApplicationDocumentsDirectory();
      _workDir = dir;
    } else {
      _workDir = await getApplicationDocumentsDirectory();
    }
    _updateFileList();
  }

  void _updateFileList() async {
    _fileList.clear();
    _selectedFiles.clear();
    await for (var entity in _workDir.list()) {
      if (entity != null && entity is File) _fileList.add(entity);
    }
    _fileList.sort((a, b) => a.path.compareTo(b.path));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((_selectedFiles.isEmpty)
            ? 'TreeTag Files'
            : '${_selectedFiles.length} Selected'),
        actions: <Widget>[
          if (_selectedFiles.isEmpty)
            IconButton(
              // New file command.
              icon: const Icon(Icons.add_box),
              onPressed: () async {
                var filename =
                    await filenameDialog(label: 'Name for the new file:');
                if (filename != null) {
                  var fileObj = File(p.join(_workDir.path, '$filename.trtg'));
                  var model = Provider.of<Structure>(context, listen: false);
                  model.newFile(fileObj);
                  Navigator.pushNamed(context, '/treeView', arguments: filename)
                      .then((value) async {
                    _updateFileList();
                  });
                }
              },
            ),
          if (_selectedFiles.length == 1)
            IconButton(
              // Command to show path, modified date & size for a selected file.
              icon: const Icon(Icons.info),
              onPressed: () {
                fileInfoDialog(File(_selectedFiles.first.path));
              },
            ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (result) async {
              switch (result) {
                case MenuItems.addFromFolder:
                  FilePickerResult? answer =
                      await FilePicker.platform.pickFiles();
                  if (answer != null) {
                    var cachePath = answer.files.single.path;
                    if (cachePath != null) {
                      var newName = p.basenameWithoutExtension(cachePath);
                      var newPath = p.join(_workDir.path, '$newName.trtg');
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
                      p.basenameWithoutExtension(_selectedFiles.first.path);
                  var answer = await filenameDialog(
                    initName: initName,
                    label: 'Copy "$initName" to:',
                  );
                  if (answer != null) {
                    var newPath = p.join(_workDir.path, '$answer.trtg');
                    if (File(newPath).existsSync()) {
                      var ans = await confirmOverwriteDialog(answer);
                      if (ans == null || !ans) break;
                    }
                    await _selectedFiles.first.copy(newPath);
                    setState(() {
                      _updateFileList();
                    });
                  }
                  break;
                case MenuItems.copyToFolder:
                  String? folder = await FilePicker.platform.getDirectoryPath();
                  if (folder != null) {
                    var newPath =
                        p.join(folder, p.basename(_selectedFiles.first.path));
                    if (File(newPath).existsSync()) {
                      var ans = await confirmOverwriteDialog(p
                          .basenameWithoutExtension(_selectedFiles.first.path));
                      if (ans == null || !ans) break;
                    }
                    if (await Permission.storage.request().isGranted) {
                      try {
                        await _selectedFiles.first.copy(newPath);
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
                      p.basenameWithoutExtension(_selectedFiles.first.path);
                  var answer = await filenameDialog(
                    initName: initName,
                    label: 'Rename "$initName" to:',
                  );
                  if (answer != null) {
                    var newPath = p.join(_workDir.path, '$answer.trtg');
                    if (File(newPath).existsSync()) {
                      var ans = await confirmOverwriteDialog(answer);
                      if (ans == null || !ans) break;
                    }
                    await _selectedFiles.first.rename(newPath);
                    setState(() {
                      _updateFileList();
                    });
                  }
                  break;
                case MenuItems.delete:
                  var deleteOk = await confirmDeleteDialog();
                  if (deleteOk ?? false) {
                    for (var file in _selectedFiles) {
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
              if (_selectedFiles.isEmpty)
                PopupMenuItem(
                  child: Text('Add from folder'),
                  value: MenuItems.addFromFolder,
                ),
              if (_selectedFiles.length == 1)
                PopupMenuItem(
                  child: Text('Create a copy'),
                  value: MenuItems.copy,
                ),
              if (_selectedFiles.isNotEmpty)
                PopupMenuItem(
                  child: Text('Copy to folder'),
                  value: MenuItems.copyToFolder,
                ),
              if (_selectedFiles.length == 1)
                PopupMenuItem(
                  child: Text('Rename'),
                  value: MenuItems.rename,
                ),
              if (_selectedFiles.isNotEmpty)
                PopupMenuItem(
                  child: Text('Delete'),
                  value: MenuItems.delete,
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: <Widget>[
          for (var fileObj in _fileList)
            Card(
              color: (_selectedFiles.contains(fileObj))
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
                    if (_selectedFiles.contains(fileObj)) {
                      _selectedFiles.remove(fileObj);
                    } else {
                      _selectedFiles.add(fileObj);
                    }
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Prompt the user for a new filename.
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
              child: const Text('CANCEL'),
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
              child: const Text('CANCEL'),
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
          content: Text(_selectedFiles.length == 1
              ? 'Delete 1 item?'
              : 'Delete ${_selectedFiles.length} items?'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context, true),
            ),
            TextButton(
              child: const Text('CANCEL'),
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
          content: Text('Full Path: ${fileObj.path}\n\n'
              'Last Modiified: ${fileObj.lastModifiedSync().toString()}\n\n'
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
