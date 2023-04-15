// file_control.dart, a view showing options for opening a new or existing file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'common_dialogs.dart' as commonDialogs;
import 'frame_view.dart';
import 'help_view.dart';
import 'sample_control.dart';
import 'setting_edit.dart';
import '../main.dart' show prefs, saveWindowGeo;
import '../model/csv_import.dart';
import '../model/io_file.dart';
import '../model/structure.dart';
import '../model/treeline_import.dart';

const fileExtension = '.trtg';

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

class _FileControlState extends State<FileControl> with WindowListener {
  var _fileList = <IOFile>[];
  final _selectedFiles = <IOFile>{};
  late bool _usingLocalFiles;

  /// Initialize with last local/network setting and load file list.
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
    _usingLocalFiles = prefs.getBool('uselocalfiles') ?? true;
    if (!_usingLocalFiles && !_checkNetworkParams()) {
      _usingLocalFiles = true;
      prefs.setBool('uselocalfiles', true);
    }
    _updateFileList();
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  /// Call main function to save window geometry after a resize.
  @override
  void onWindowResize() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await saveWindowGeo();
    }
  }

  /// Call main function to save window geometry after a move.
  @override
  void onWindowMove() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await saveWindowGeo();
    }
  }

  /// Verify that network preference ssettings are valid.
  bool _checkNetworkParams() {
    return (prefs.getString('netaddress') ?? '').isNotEmpty &&
        (prefs.getString('netuser') ?? '').isNotEmpty;
  }

  /// Request a password if it's not stored in the preferences.
  Future<bool> _findNetworkPassword() async {
    if (NetworkFile.password.isNotEmpty) return true;
    NetworkFile.password = prefs.getString('netpassword') ?? '';
    if (NetworkFile.password.isNotEmpty) return true;
    var value = await commonDialogs.textDialog(
      context: context,
      title: 'Password:',
      label: 'Enter network password',
      obscureText: true,
    );
    if (value != null && value.isNotEmpty) {
      NetworkFile.password = value;
      return true;
    }
    return false;
  }

  /// Refresh the list of files.
  void _updateFileList() async {
    if (!_usingLocalFiles) {
      await _findNetworkPassword();
    }
    try {
      _fileList = _usingLocalFiles
          ? await LocalFile.fileList()
          : await NetworkFile.fileList();
    } on IOException catch (e) {
      _fileList = [];
      await commonDialogs.okDialog(
        context: context,
        title: 'Error',
        label: 'Could not read from directory: \n$e',
        isDissmissable: false,
      );
    }
    _fileList.sort((a, b) => a.filename.compareTo(b.filename));
    _selectedFiles.clear();
    setState(() {});
  }

  /// Open a long- or double-tapped file.
  void _openTappedFile(IOFile fileObj) async {
    var model = Provider.of<Structure>(context, listen: false);
    try {
      await model.openFile(fileObj);
      Navigator.pushNamed(context, '/frameView',
              arguments: fileObj.nameNoExtension)
          .then((value) async {
        _updateFileList();
      });
    } on FormatException {
      // If not TreeTag formt, try to import as a TreeLine file.
      try {
        var import = TreeLineImport(await fileObj.readJson());
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
          model.fileObject = IOFile.currentType(fileWithExt);
          if (!(await model.fileObject.exists) ||
              await askOverwriteOk(fileWithExt)) {
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
        // If not TreeTag or TreeLine format, try a CSV import.
        try {
          if (fileObj is! LocalFile) throw FormatException();
          var import = CsvImport(await fileObj.readString());
          model.clearModel();
          import.convertCsv(model);
          var baseFilename = fileObj.nameNoExtension;
          var fileWithExt = _addExtensionIfNone(baseFilename);
          model.fileObject = IOFile.currentType(fileWithExt);
          if (!(await model.fileObject.exists) ||
              await askOverwriteOk(fileWithExt)) {
            model.saveFile();
            Navigator.pushNamed(
              context,
              '/frameView',
              arguments: baseFilename,
            ).then((value) async {
              _updateFileList();
            });
          }
        } on FormatException {
          await commonDialogs.okDialog(
            context: context,
            title: 'Error',
            label: 'Could not interpret file: ${fileObj.nameNoExtension}',
            isDissmissable: false,
          );
        }
      }
    } on IOException catch (e) {
      await commonDialogs.okDialog(
        context: context,
        title: 'Error',
        label: 'Could not read file: ${fileObj.nameNoExtension}\n$e',
        isDissmissable: false,
      );
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
              selected: _usingLocalFiles,
              onTap: () {
                Navigator.pop(context);
                if (!_usingLocalFiles) {
                  _usingLocalFiles = true;
                  prefs.setBool('uselocalfiles', true);
                }
                _updateFileList();
              },
            ),
            ListTile(
              leading: const Icon(Icons.phonelink),
              title: const Text('Network Storage'),
              enabled: _checkNetworkParams(),
              selected: !_usingLocalFiles,
              onTap: () {
                Navigator.pop(context);
                if (_usingLocalFiles) {
                  _usingLocalFiles = false;
                  prefs.setBool('uselocalfiles', false);
                }
                _updateFileList();
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
            if (Platform.isLinux || Platform.isMacOS) Divider(),
            if (Platform.isLinux || Platform.isMacOS)
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
            ? (_usingLocalFiles
                ? 'Local Files - TreeTag'
                : 'Network Files - TreeTag')
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
                  var fileObj =
                      IOFile.currentType(_addExtensionIfNone(filename));
                  if (!(await fileObj.exists) ||
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
              onPressed: () async {
                var fileObj = _selectedFiles.first;
                var modTime = await fileObj.dataModTime;
                var timeStr = DateFormat('MMM d, yyyy, h:mm a').format(modTime);
                commonDialogs.okDialog(
                  context: context,
                  title: 'File Info - ${fileObj.nameNoExtension}',
                  label: 'Full Path: ${fileObj.fullPath}\n\n'
                      'Last Modiified: $timeStr\n\n'
                      'Size: ${await fileObj.fileSize} bytes',
                );
              },
            ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            onSelected: (result) async {
              // Set error messages to display if a IOException is caught later.
              var errorLabel = '';
              try {
                switch (result) {
                  case MenuItems.addFromFolder:
                    // Copy file from external path.
                    FilePickerResult? answer =
                        await FilePicker.platform.pickFiles(
                      initialDirectory: prefs.getString('workdir')!,
                      dialogTitle: 'Select File to be Added',
                    );
                    if (answer != null) {
                      var cachePath = answer.files.single.path;
                      if (cachePath != null) {
                        var newFileObj =
                            IOFile.currentType(p.basename(cachePath));
                        if (await newFileObj.exists) {
                          if (!(await askOverwriteOk(newFileObj.filename))) {
                            break;
                          }
                        }
                        errorLabel =
                            'Could not write to ${newFileObj.fullPath}';
                        await newFileObj.copyFromPath(cachePath);
                      }
                      if (Platform.isAndroid || Platform.isIOS) {
                        FilePicker.platform.clearTemporaryFiles();
                      }
                      setState(() {
                        _updateFileList();
                      });
                    }
                    break;
                  case MenuItems.copy:
                    // Copy current file to another name.
                    var initName = _selectedFiles.first.nameNoExtension;
                    var origExt = _selectedFiles.first.extension;
                    var answer = await commonDialogs.filenameDialog(
                      context: context,
                      initName: initName,
                      label: 'Copy "$initName" to:',
                    );
                    if (answer != null) {
                      var fileObj = _selectedFiles.first;
                      var newFileObj = IOFile.currentType(
                        _addExtensionIfNone(answer, ext: origExt),
                      );
                      if (await newFileObj.exists) {
                        if (!(await askOverwriteOk(newFileObj.filename))) {
                          break;
                        }
                      }
                      errorLabel = 'Could not write to ${newFileObj.fullPath}';
                      await fileObj.copyToFile(newFileObj);
                      setState(() {
                        _updateFileList();
                      });
                    }
                    break;
                  case MenuItems.copyToFolder:
                    // Copy current file to an external directory.
                    String? folder = await FilePicker.platform.getDirectoryPath(
                      initialDirectory: prefs.getString('workdir')!,
                      dialogTitle: 'Select Directory for Copy',
                    );
                    if (folder != null) {
                      if (Platform.isLinux ||
                          Platform.isWindows ||
                          Platform.isMacOS ||
                          await Permission.storage.request().isGranted) {
                        for (var fileObj in _selectedFiles) {
                          var newPath = p.join(folder, fileObj.filename);
                          errorLabel = 'Could not write to $newPath';
                          if (await File(newPath).exists()) {
                            if (!(await askOverwriteOk(p.basename(newPath)))) {
                              break;
                            }
                          }
                          await fileObj.copyToPath(newPath);
                        }
                      } else if (await Permission.storage
                          .request()
                          .isPermanentlyDenied) {
                        await openAppSettings();
                      }
                    }
                    if (Platform.isAndroid || Platform.isIOS) {
                      FilePicker.platform.clearTemporaryFiles();
                    }
                    break;
                  case MenuItems.uploadToNetwork:
                    // Copy current file from disk to the network.
                    for (var fileObj in _selectedFiles) {
                      var newObj = NetworkFile(fileObj.filename);
                      if (await newObj.exists) {
                        if (!(await askOverwriteOk(newObj.filename))) {
                          break;
                        }
                      }
                      errorLabel = 'Could not write to ${newObj.filename}';
                      await fileObj.copyToFile(newObj);
                    }
                    break;
                  case MenuItems.downloadToStorage:
                    // Copy the current network file to local working directory.
                    for (var fileObj in _selectedFiles) {
                      var newObj = LocalFile(fileObj.filename);
                      if (await newObj.exists) {
                        if (!(await askOverwriteOk(newObj.filename))) {
                          break;
                        }
                      }
                      errorLabel = 'Could not read/write to ${newObj.filename}';
                      await fileObj.copyToFile(newObj);
                    }
                    break;
                  case MenuItems.rename:
                    // Give the current file a new name.
                    var initName = _selectedFiles.first.nameNoExtension;
                    var origExt = _selectedFiles.first.extension;
                    var answer = await commonDialogs.filenameDialog(
                      context: context,
                      initName: initName,
                      label: 'Rename "$initName" to:',
                    );
                    if (answer != null) {
                      var newName = _addExtensionIfNone(answer, ext: origExt);
                      var fileObj = _selectedFiles.first;
                      if (await IOFile.currentType(newName).exists) {
                        if (!(await askOverwriteOk(newName))) {
                          break;
                        }
                      }
                      errorLabel = 'Could not write to $newName';
                      await fileObj.rename(newName);
                      setState(() {
                        _updateFileList();
                      });
                    }
                    break;
                  case MenuItems.delete:
                    // Delete the current file(s).
                    var deleteOk = await commonDialogs.okCancelDialog(
                      context: context,
                      title: 'Confirm Delete',
                      label: _selectedFiles.length == 1
                          ? 'Delete 1 item?'
                          : 'Delete ${_selectedFiles.length} items?',
                    );
                    if (deleteOk ?? false) {
                      for (var fileObj in _selectedFiles) {
                        errorLabel = 'Could not delete ${fileObj.filename}';
                        await fileObj.delete();
                      }
                      setState(() {
                        _updateFileList();
                      });
                    }
                    break;
                }
              } on IOException catch (e) {
                // Exception handling for all menu commands.
                await commonDialogs.okDialog(
                  context: context,
                  title: 'Error',
                  label: '$errorLabel\n$e',
                  isDissmissable: false,
                );
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
              if (_selectedFiles.isNotEmpty && _usingLocalFiles)
                PopupMenuItem(
                  child: Text('Upload to network'),
                  value: MenuItems.uploadToNetwork,
                ),
              if (_selectedFiles.isNotEmpty && !_usingLocalFiles)
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
                    // Show file extension less prominently.
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

/// Add an extension (.trtg by default) unless an extension is already there.
String _addExtensionIfNone(String filename, {ext = fileExtension}) {
  if (filename.endsWith('.')) {
    filename = filename.substring(0, filename.length - 1);
  }
  if (filename.lastIndexOf('.') < 1) {
    filename = '$filename$ext';
  }
  return filename;
}
