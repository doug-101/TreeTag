// file_control.dart, a view showing options for opening a new or existing file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
// TODO; Note that zenity is a requirement for file_picker under Linux.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart' as commonDialogs;
import 'tree_view.dart';
import '../model/structure.dart';
import '../model/treeline_import.dart';

const _fileExtension = '.trtg';

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
      if (entity != null &&
          entity is File &&
          !p.basename(entity.path).startsWith('.')) {
        _fileList.add(entity);
      }
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
                var filename = await commonDialogs.filenameDialog(
                  context: context,
                  label: 'Name for the new file:',
                );
                if (filename != null) {
                  var fileWithExt = _addExtensionIfNone(filename);
                  var fileObj = File(p.join(_workDir.path, fileWithExt));
                  if (fileObj.existsSync()) {
                    var ans = await commonDialogs.okCancelDialog(
                      context: context,
                      title: 'Confirm Overwrite',
                      label:
                          'File $fileWithExt already exists.\n\nOverwrite it?',
                    );
                    if (ans == null || !ans) {
                      FilePicker.platform.clearTemporaryFiles();
                      return;
                    }
                  }
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
                var fileObj = _selectedFiles.first;
                commonDialogs.okDialog(
                  context: context,
                  title:
                      'File Info - ${p.basenameWithoutExtension(fileObj.path)}',
                  label: 'Full Path: ${fileObj.path}\n\n'
                      'Last Modiified: ${fileObj.lastModifiedSync().toString()}\n\n'
                      'Size: ${fileObj.statSync().size} bytes',
                );
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
                      var newName = p.basename(cachePath);
                      var newPath = p.join(_workDir.path, newName);
                      if (File(newPath).existsSync()) {
                        var ans = await commonDialogs.okCancelDialog(
                          context: context,
                          title: 'Confirm Overwrite',
                          label:
                              'File $newName already exists.\n\nOverwrite it?',
                        );
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
                  var initName = _selectedFiles.first.path
                          .endsWith(_fileExtension)
                      ? p.basenameWithoutExtension(_selectedFiles.first.path)
                      : p.basename(_selectedFiles.first.path);
                  var answer = await commonDialogs.filenameDialog(
                    context: context,
                    initName: initName,
                    label: 'Copy "$initName" to:',
                  );
                  if (answer != null) {
                    var newPath =
                        p.join(_workDir.path, _addExtensionIfNone(answer));
                    if (File(newPath).existsSync()) {
                      var ans = await commonDialogs.okCancelDialog(
                        context: context,
                        title: 'Confirm Overwrite',
                        label: 'File $answer already exists.\n\nOverwrite it?',
                      );
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
                    var fileNoExt =
                        p.basenameWithoutExtension(_selectedFiles.first.path);
                    if (File(newPath).existsSync()) {
                      var ans = await commonDialogs.okCancelDialog(
                        context: context,
                        title: 'Confirm Overwrite',
                        label:
                            'File $fileNoExt already exists.\n\nOverwrite it?',
                      );
                      if (ans == null || !ans) break;
                    }
                    if (await Permission.storage.request().isGranted) {
                      try {
                        await _selectedFiles.first.copy(newPath);
                      } on FileSystemException {
                        await commonDialogs.okDialog(
                          context: context,
                          title: 'Error',
                          label: 'Could not write to $newPath',
                          isDissmissable: false,
                        );
                      }
                    } else if (await Permission.storage
                        .request()
                        .isPermanentlyDenied) {
                      await openAppSettings();
                    }
                  }
                  break;
                case MenuItems.rename:
                  var initName = _selectedFiles.first.path
                          .endsWith(_fileExtension)
                      ? p.basenameWithoutExtension(_selectedFiles.first.path)
                      : p.basename(_selectedFiles.first.path);
                  var answer = await commonDialogs.filenameDialog(
                    context: context,
                    initName: initName,
                    label: 'Rename "$initName" to:',
                  );
                  if (answer != null) {
                    var newPath =
                        p.join(_workDir.path, _addExtensionIfNone(answer));
                    if (File(newPath).existsSync()) {
                      var ans = await commonDialogs.okCancelDialog(
                        context: context,
                        title: 'Confirm Overwrite',
                        label: 'File $answer already exists.\n\nOverwrite it?',
                      );
                      if (ans == null || !ans) break;
                    }
                    await _selectedFiles.first.rename(newPath);
                    setState(() {
                      _updateFileList();
                    });
                  }
                  break;
                case MenuItems.delete:
                  var deleteOk = await commonDialogs.okCancelDialog(
                    context: context,
                    title: 'Confirm Delete',
                    label: _selectedFiles.length == 1
                        ? 'Delete 1 item?'
                        : 'Delete ${_selectedFiles.length} items?',
                  );
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
                title: Text.rich(
                  TextSpan(
                    text: '${p.basenameWithoutExtension(fileObj.path)} ',
                    children: <TextSpan>[
                      TextSpan(
                        text: p.extension(fileObj.path),
                        style: Theme.of(context).textTheme.caption,
                      ),
                    ],
                  ),
                ),
                onTap: () async {
                  var model = Provider.of<Structure>(context, listen: false);
                  try {
                    model.openFile(fileObj);
                    Navigator.pushNamed(context, '/treeView',
                            arguments: p.basenameWithoutExtension(fileObj.path))
                        .then((value) async {
                      _updateFileList();
                    });
                  } on FormatException {
                    try {
                      var import = TreeLineImport(fileObj);
                      var typeName = await commonDialogs.choiceDialog(
                        context: context,
                        choices: import.formatNames(),
                        title: 'TreeLine File Import\n\nChoose Node Type',
                      );
                      if (typeName != null) {
                        model.clearModel();
                        import.convertNodeType(typeName, model);
                        var baseFilename =
                            p.basenameWithoutExtension(fileObj.path);
                        var fileWithExt = _addExtensionIfNone(baseFilename);
                        model.fileObject =
                            File(p.join(_workDir.path, fileWithExt));
                        if (model.fileObject.existsSync()) {
                          var ans = await commonDialogs.okCancelDialog(
                            context: context,
                            title: 'Confirm Overwrite',
                            label:
                                'File $fileWithExt already exists.\n\nOverwrite it?',
                          );
                          if (ans == null || !ans) {
                            FilePicker.platform.clearTemporaryFiles();
                            return;
                          }
                        }
                        model.saveFile();
                        Navigator.pushNamed(
                          context,
                          '/treeView',
                          arguments: baseFilename,
                        ).then((value) async {
                          _updateFileList();
                        });
                      }
                    } on FormatException {
                      await commonDialogs.okDialog(
                        context: context,
                        title: 'Error',
                        label: 'Could not open file: '
                            '${p.basenameWithoutExtension(fileObj.path)}',
                        isDissmissable: false,
                      );
                    }
                  }
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
}

/// Add a default TreeTag extension unless an extension is already there.
String _addExtensionIfNone(String filename) {
  if (filename.endsWith('.')) {
    filename = filename.substring(0, filename.length - 1);
  }
  if (filename.lastIndexOf('.') < 1) {
    filename = '$filename$_fileExtension';
  }
  return filename;
}
