// file_control.dart, a view showing options for opening a new or existing file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'common_dialogs.dart' as commonDialogs;
import 'frame_view.dart';
import 'help_view.dart';
import 'sample_control.dart';
import 'setting_edit.dart';
import '../main.dart' show prefs;
import '../model/io_file.dart';
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

enum MenuItems {
  addFromFolder,
  copy,
  copyToFolder,
  uploadToNetwork,
  downloadToStorage,
  rename,
  delete,
}

class _FileControlState extends State<FileControl> {
  var _fileList = <IOFile>[];
  final _selectedFiles = <IOFile>{};
  var _showingLocalFiles = true;

  @override
  void initState() {
    super.initState();
    _updateFileList();
  }

  void _updateFileList() async {
    try {
      _fileList = _showingLocalFiles
          ? await LocalFile.fileList()
          : await NetworkFile.fileList();
    } on IOException {
      await commonDialogs.okDialog(
        context: context,
        title: 'Error',
        label: 'Could not read from working directory: '
            '${prefs.getString('workdir')!}',
        isDissmissable: false,
      );
    }
    _fileList.sort((a, b) => a.filename.compareTo(b.filename));
    _selectedFiles.clear();
    setState(() {});
  }

  void _openTappedFile(IOFile fileObj) async {
    var model = Provider.of<Structure>(context, listen: false);
    try {
      model.openFile(fileObj);
      Navigator.pushNamed(context, '/frameView',
              arguments: fileObj.nameNoExtension)
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
          var baseFilename = fileObj.nameNoExtension;
          var fileWithExt = _addExtensionIfNone(baseFilename);
          model.fileObject = LocalFile(fileWithExt);
          if (!model.fileObject.exists || await askOverwriteOk(fileWithExt)) {
            model.saveFile();
            Navigator.pushNamed(
              context,
              '/frameView',
              arguments: baseFilename,
            ).then((value) async {
              _updateFileList();
            });
          }
        }
      } on FormatException {
        await commonDialogs.okDialog(
          context: context,
          title: 'Error',
          label: 'Could not open file: ${fileObj.nameNoExtension}',
          isDissmissable: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'TreeTag',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 36,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Local Storage'),
              selected: _showingLocalFiles,
              onTap: () {
                if (!_showingLocalFiles) {
                  Navigator.pop(context);
                  _showingLocalFiles = true;
                  _updateFileList();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.phonelink),
              title: const Text('Network Storage'),
              enabled: true,
              selected: !_showingLocalFiles,
              onTap: () {
                if (_showingLocalFiles) {
                  Navigator.pop(context);
                  _showingLocalFiles = false;
                  _updateFileList();
                }
              },
            ),
            Divider(),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Sample Files'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SampleControl(),
                  ),
                );
                _updateFileList();
              },
            ),
            Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingEdit(),
                  ),
                );
                _updateFileList();
              },
            ),
            Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help View'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HelpView(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About TreeTag'),
              onTap: () {
                Navigator.pop(context);
                commonDialogs.aboutDialog(context: context);
              },
            ),
            if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
              Divider(),
            if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
              ListTile(
                leading: const Icon(Icons.highlight_off_outlined),
                title: const Text('Quit'),
                onTap: () {
                  SystemNavigator.pop();
                },
              ),
          ],
        ),
      ),
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
                  var fileObj = LocalFile(_addExtensionIfNone(filename));
                  if (!fileObj.exists ||
                      await askOverwriteOk(fileObj.filename)) {
                    var model = Provider.of<Structure>(context, listen: false);
                    model.newFile(fileObj);
                    Navigator.pushNamed(context, '/frameView',
                            arguments: filename)
                        .then((value) async {
                      _updateFileList();
                    });
                  }
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
                  title: 'File Info - ${fileObj.nameNoExtension}',
                  label: 'Full Path: ${fileObj.fullPath}\n\n'
                      'Last Modiified: ${fileObj.lastModified}'
                      '\n\nSize: ${fileObj.fileSize} bytes',
                );
              },
            ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (result) async {
              switch (result) {
                case MenuItems.addFromFolder:
                  FilePickerResult? answer =
                      await FilePicker.platform.pickFiles(
                    initialDirectory: prefs.getString('workdir')!,
                    dialogTitle: 'Select File to be Added',
                  );
                  if (answer != null) {
                    var cachePath = answer.files.single.path;
                    if (cachePath != null) {
                      try {
                        var newFile = await LocalFile.copyFromPath(cachePath);
                      } on FileExistsException catch (e) {
                        if (await askOverwriteOk('$e')) {
                          var newFile = await LocalFile.copyFromPath(cachePath,
                              forceIfExists: true);
                        }
                      }
                      setState(() {
                        _updateFileList();
                      });
                    }
                    FilePicker.platform.clearTemporaryFiles();
                  }
                  break;
                case MenuItems.copy:
                  var initName = _selectedFiles.first.nameNoExtension;
                  var answer = await commonDialogs.filenameDialog(
                    context: context,
                    initName: initName,
                    label: 'Copy "$initName" to:',
                  );
                  if (answer != null) {
                    var fileObj = _selectedFiles.first;
                    var newFileObj = LocalFile(_addExtensionIfNone(answer));
                    try {
                      await fileObj.copyToFile(newFileObj);
                    } on FileExistsException catch (e) {
                      if (await askOverwriteOk('$e')) {
                        await fileObj.copyToFile(newFileObj,
                            forceIfExists: true);
                      }
                    }
                    setState(() {
                      _updateFileList();
                    });
                  }
                  break;
                case MenuItems.copyToFolder:
                  String? folder = await FilePicker.platform.getDirectoryPath(
                    initialDirectory: prefs.getString('workdir')!,
                    dialogTitle: 'Select Directory for Copy',
                  );
                  if (folder != null) {
                    if (Platform.isLinux ||
                        Platform.isWindows ||
                        Platform.isMacOS ||
                        await Permission.storage.request().isGranted) {
                      try {
                        for (var fileObj in _selectedFiles) {
                          var newPath = p.join(folder, fileObj.filename);
                          try {
                            await fileObj.copyToPath(newPath);
                          } on FileExistsException catch (e) {
                            if (await askOverwriteOk('$e')) {
                              await fileObj.copyToPath(newPath,
                                  forceIfExists: true);
                            }
                          }
                        }
                      } on IOException {
                        await commonDialogs.okDialog(
                          context: context,
                          title: 'Error',
                          label: 'Could not write to $folder',
                          isDissmissable: false,
                        );
                      }
                    } else if (await Permission.storage
                        .request()
                        .isPermanentlyDenied) {
                      await openAppSettings();
                    }
                  }
                  FilePicker.platform.clearTemporaryFiles();
                  break;
                case MenuItems.uploadToNetwork:
                  break;
                case MenuItems.downloadToStorage:
                  break;
                case MenuItems.rename:
                  var initName = _selectedFiles.first.nameNoExtension;
                  var answer = await commonDialogs.filenameDialog(
                    context: context,
                    initName: initName,
                    label: 'Rename "$initName" to:',
                  );
                  if (answer != null) {
                    var fileObj = _selectedFiles.first;
                    try {
                      await fileObj.rename(_addExtensionIfNone(answer));
                    } on FileExistsException catch (e) {
                      if (await askOverwriteOk('$e')) {
                        await fileObj.rename(answer, forceIfExists: true);
                      }
                    }
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
                    for (var fileObj in _selectedFiles) {
                      await fileObj.delete();
                    }
                    setState(() {
                      _updateFileList();
                    });
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              if (_selectedFiles.isEmpty && _showingLocalFiles)
                PopupMenuItem(
                  child: Text('Add from folder'),
                  value: MenuItems.addFromFolder,
                ),
              if (_selectedFiles.length == 1)
                PopupMenuItem(
                  child: Text('Create a copy'),
                  value: MenuItems.copy,
                ),
              if (_selectedFiles.isNotEmpty && _showingLocalFiles)
                PopupMenuItem(
                  child: Text('Copy to folder'),
                  value: MenuItems.copyToFolder,
                ),
              if (_selectedFiles.isNotEmpty && _showingLocalFiles)
                PopupMenuItem(
                  child: Text('Upload to network'),
                  value: MenuItems.uploadToNetwork,
                ),
              if (_selectedFiles.isNotEmpty && !_showingLocalFiles)
                PopupMenuItem(
                  child: Text('Download to storage'),
                  value: MenuItems.downloadToStorage,
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
              child: InkWell(
                onTap: () async {
                  setState(() {
                    if (_selectedFiles.contains(fileObj)) {
                      _selectedFiles.remove(fileObj);
                    } else {
                      _selectedFiles.add(fileObj);
                    }
                  });
                },
                onLongPress: () {
                  _openTappedFile(fileObj);
                },
                onDoubleTap: () {
                  _openTappedFile(fileObj);
                },
                child: ListTile(
                  title: Text.rich(
                    TextSpan(
                      text: '${fileObj.nameNoExtension} ',
                      children: <TextSpan>[
                        TextSpan(
                          text: fileObj.extension,
                          style: Theme.of(context).textTheme.caption,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Ask user to overwrite a filename and return result.
  Future<bool> askOverwriteOk(String filename) async {
    var ans = await commonDialogs.okCancelDialog(
      context: context,
      title: 'Confirm Overwrite',
      label: 'File $filename already exists.\n\nOverwrite it?',
    );
    if (ans == null || !ans) {
      return false;
    }
    return true;
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
