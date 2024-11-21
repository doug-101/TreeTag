// file_control.dart, a view showing options for opening a new or existing file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'common_dialogs.dart' as common_dialogs;
import 'help_view.dart';
import 'sample_control.dart';
import 'setting_edit.dart';
import '../main.dart' show prefs, saveWindowGeo;
import '../model/csv_import.dart';
import '../model/io_file.dart';
import '../model/structure.dart';
import '../model/treeline_import.dart';

const fileExtension = '.trtg';

enum MenuItems {
  addFromFolder,
  refreshList,
  copy,
  copyToFolder,
  uploadToNetwork,
  downloadToStorage,
  rename,
  delete,
  clearSelection,
}

/// Provides a file listview with options for new files, open files, etc.
///
/// File handling options include new, open, copy, add from folder, rename,
/// and delete.
class FileControl extends StatefulWidget {
  final String? initialFilePath;

  const FileControl({super.key, this.initialFilePath});

  @override
  State<FileControl> createState() => _FileControlState();
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
    // Handle file name as a command line argument.
    if (widget.initialFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openInitialFile(widget.initialFilePath!);
      });
    }
  }

  /// Open a file given as a command line argument.
  Future<void> _openInitialFile(String initialFilePath) async {
    final newFileObj = IOFile.currentType(p.basename(initialFilePath));
    final dir = p.dirname(initialFilePath);
    if (dir.isEmpty ||
        dir == '.' ||
        p.equals(dir, prefs.getString('workdir')!)) {
      _openTappedFile(newFileObj);
    } else if (await File(initialFilePath).exists()) {
      if (await newFileObj.exists) {
        if (!(await askOverwriteOk(newFileObj.filename))) {
          return;
        }
      }
      try {
        await newFileObj.copyFromPath(initialFilePath);
      } on IOException {
        if (!mounted) return;
        await common_dialogs.okDialog(
          context: context,
          title: 'Error',
          label: 'Could not write to ${newFileObj.fullPath}',
          isDissmissable: false,
        );
      }
      _openTappedFile(newFileObj);
    } else {
      if (!mounted) return;
      await common_dialogs.okDialog(
        context: context,
        title: 'Error',
        label: 'File ${newFileObj.fullPath} does not exist',
      );
    }
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

  /// Verify that network preference settings are valid.
  bool _checkNetworkParams() {
    return (prefs.getString('netaddress') ?? '').isNotEmpty &&
        (prefs.getString('netuser') ?? '').isNotEmpty;
  }

  /// Request a password if it's not stored in the preferences.
  Future<bool> _findNetworkPassword() async {
    if (NetworkFile.password.isNotEmpty) return true;
    NetworkFile.password = prefs.getString('netpassword') ?? '';
    if (NetworkFile.password.isNotEmpty) return true;
    final value = await common_dialogs.textDialog(
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
      if (!mounted) return;
      await common_dialogs.okDialog(
        context: context,
        title: 'Error',
        label: 'Could not read from directory: \n$e',
        isDissmissable: false,
      );
    }
    _fileList.sort(
        (a, b) => a.filename.toLowerCase().compareTo(b.filename.toLowerCase()));
    _selectedFiles.clear();
    setState(() {});
  }

  /// Open a long- or double-tapped file.
  void _openTappedFile(IOFile fileObj) async {
    final model = Provider.of<Structure>(context, listen: false);
    try {
      await model.openFile(fileObj);
      if (!mounted) return;
      Navigator.pushNamed(context, '/frameView',
              arguments: fileObj.nameNoExtension)
          .then((value) async {
        _updateFileList();
      });
    } on FormatException {
      // If not TreeTag formt, try to import as a TreeLine file.
      try {
        final import = TreeLineImport(await fileObj.readJson());
        if (!mounted) return;
        final typeName = await common_dialogs.choiceDialog(
          context: context,
          choices: import.formatNames(),
          title: 'TreeLine File Import\n\nChoose Node Type',
        );
        if (typeName != null) {
          model.clearModel();
          import.convertNodeType(typeName, model);
          final baseFilename = fileObj.nameNoExtension;
          final fileWithExt = _addExtensionIfNone(baseFilename);
          model.fileObject = IOFile.currentType(fileWithExt);
          if (!(await model.fileObject.exists) ||
              await askOverwriteOk(fileWithExt)) {
            model.saveFile();
            if (!mounted) return;
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
          if (fileObj is! LocalFile) throw const FormatException();
          final import = CsvImport(await fileObj.readString());
          model.clearModel();
          import.convertCsv(model);
          final baseFilename = fileObj.nameNoExtension;
          final fileWithExt = _addExtensionIfNone(baseFilename);
          model.fileObject = IOFile.currentType(fileWithExt);
          if (!(await model.fileObject.exists) ||
              await askOverwriteOk(fileWithExt)) {
            model.saveFile();
            if (!mounted) return;
            Navigator.pushNamed(
              context,
              '/frameView',
              arguments: baseFilename,
            ).then((value) async {
              _updateFileList();
            });
          }
        } on FormatException {
          if (!mounted) return;
          await common_dialogs.okDialog(
            context: context,
            title: 'Error',
            label: 'Could not interpret file: ${fileObj.nameNoExtension}',
            isDissmissable: false,
          );
        }
      }
    } on IOException catch (e) {
      await common_dialogs.okDialog(
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
                color: Theme.of(context).colorScheme.tertiary,
              ),
              child: Text(
                'TreeTag',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiary,
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Sample Files'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SampleControl(),
                  ),
                );
                _updateFileList();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingEdit(),
                  ),
                );
                _updateFileList();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help View'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpView(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About TreeTag'),
              onTap: () {
                Navigator.pop(context);
                common_dialogs.aboutDialog(context: context);
              },
            ),
            if (Platform.isLinux || Platform.isMacOS) const Divider(),
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
              tooltip: 'New file',
              onPressed: () async {
                final filename = await common_dialogs.filenameDialog(
                  context: context,
                  label: 'Name for the new file:',
                );
                if (filename != null) {
                  final fileObj =
                      IOFile.currentType(_addExtensionIfNone(filename));
                  if (!(await fileObj.exists) ||
                      await askOverwriteOk(fileObj.filename)) {
                    if (!context.mounted) return;
                    final model =
                        Provider.of<Structure>(context, listen: false);
                    model.newFile(fileObj);
                    if (!context.mounted) return;
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
              tooltip: 'File info',
              onPressed: () async {
                final fileObj = _selectedFiles.first;
                final modTime = await fileObj.dataModTime;
                final timeStr =
                    DateFormat('MMM d, yyyy, h:mm a').format(modTime);
                if (!context.mounted) return;
                await common_dialogs.okDialog(
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
                      final cachePath = answer.files.single.path;
                      if (cachePath != null) {
                        final newFileObj =
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
                      _updateFileList();
                    }
                  case MenuItems.refreshList:
                    // Update the list of files after external changes.
                    _updateFileList();
                  case MenuItems.copy:
                    // Copy current file to another name.
                    final initName = _selectedFiles.first.nameNoExtension;
                    final origExt = _selectedFiles.first.extension;
                    final answer = await common_dialogs.filenameDialog(
                      context: context,
                      initName: initName,
                      label: 'Copy "$initName" to:',
                    );
                    if (answer != null) {
                      final fileObj = _selectedFiles.first;
                      final newFileObj = IOFile.currentType(
                        _addExtensionIfNone(answer, ext: origExt),
                      );
                      if (await newFileObj.exists) {
                        if (!(await askOverwriteOk(newFileObj.filename))) {
                          break;
                        }
                      }
                      errorLabel = 'Could not write to ${newFileObj.fullPath}';
                      await fileObj.copyToFile(newFileObj);
                      _updateFileList();
                    }
                  case MenuItems.copyToFolder:
                    // Copy current file to an external directory.
                    String? folder = await FilePicker.platform.getDirectoryPath(
                      initialDirectory: prefs.getString('workdir')!,
                      dialogTitle: 'Select Directory for Copy',
                    );
                    if (folder != null) {
                      // Removed await Permission.storage.request().isGranted
                      // for Android - didn't work on Android 13+ (at least).
                      for (var fileObj in _selectedFiles) {
                        final newPath = p.join(folder, fileObj.filename);
                        errorLabel = 'Could not write to $newPath';
                        if (await File(newPath).exists()) {
                          if (!(await askOverwriteOk(p.basename(newPath)))) {
                            break;
                          }
                        }
                        await fileObj.copyToPath(newPath);
                      }
                    }
                    if (Platform.isAndroid || Platform.isIOS) {
                      FilePicker.platform.clearTemporaryFiles();
                    }
                  case MenuItems.uploadToNetwork:
                    // Copy current file from disk to the network.
                    for (var fileObj in _selectedFiles) {
                      final newObj = NetworkFile(fileObj.filename);
                      if (await newObj.exists) {
                        if (!(await askOverwriteOk(newObj.filename))) {
                          break;
                        }
                      }
                      errorLabel = 'Could not write to ${newObj.filename}';
                      await fileObj.copyToFile(newObj);
                    }
                  case MenuItems.downloadToStorage:
                    // Copy the current network file to local working directory.
                    for (var fileObj in _selectedFiles) {
                      final newObj = LocalFile(fileObj.filename);
                      if (await newObj.exists) {
                        if (!(await askOverwriteOk(newObj.filename))) {
                          break;
                        }
                      }
                      errorLabel = 'Could not read/write to ${newObj.filename}';
                      await fileObj.copyToFile(newObj);
                    }
                  case MenuItems.rename:
                    // Give the current file a new name.
                    final initName = _selectedFiles.first.nameNoExtension;
                    final origExt = _selectedFiles.first.extension;
                    final answer = await common_dialogs.filenameDialog(
                      context: context,
                      initName: initName,
                      label: 'Rename "$initName" to:',
                    );
                    if (answer != null) {
                      final newName = _addExtensionIfNone(answer, ext: origExt);
                      final fileObj = _selectedFiles.first;
                      if (await IOFile.currentType(newName).exists) {
                        if (!(await askOverwriteOk(newName))) {
                          break;
                        }
                      }
                      errorLabel = 'Could not write to $newName';
                      await fileObj.rename(newName);
                      _updateFileList();
                    }
                  case MenuItems.delete:
                    // Delete the current file(s).
                    final deleteOk = await common_dialogs.okCancelDialog(
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
                      _updateFileList();
                    }
                  case MenuItems.clearSelection:
                    setState(() {
                      _selectedFiles.clear();
                    });
                }
              } on IOException catch (e) {
                if (!context.mounted) return;
                // Exception handling for all menu commands.
                await common_dialogs.okDialog(
                  context: context,
                  title: 'Error',
                  label: '$errorLabel\n$e',
                  isDissmissable: false,
                );
              }
            },
            itemBuilder: (context) => [
              if (_selectedFiles.isEmpty)
                const PopupMenuItem(
                  value: MenuItems.addFromFolder,
                  child: Text('Add from folder'),
                ),
              if (_selectedFiles.isEmpty)
                const PopupMenuItem(
                  value: MenuItems.refreshList,
                  child: Text('Refresh file list'),
                ),
              if (_selectedFiles.length == 1)
                const PopupMenuItem(
                  value: MenuItems.copy,
                  child: Text('Create a copy'),
                ),
              if (_selectedFiles.isNotEmpty)
                const PopupMenuItem(
                  value: MenuItems.copyToFolder,
                  child: Text('Copy to folder'),
                ),
              if (_selectedFiles.isNotEmpty && _usingLocalFiles)
                const PopupMenuItem(
                  value: MenuItems.uploadToNetwork,
                  child: Text('Upload to network'),
                ),
              if (_selectedFiles.isNotEmpty && !_usingLocalFiles)
                const PopupMenuItem(
                  value: MenuItems.downloadToStorage,
                  child: Text('Download to storage'),
                ),
              if (_selectedFiles.length == 1)
                const PopupMenuItem(
                  value: MenuItems.rename,
                  child: Text('Rename'),
                ),
              if (_selectedFiles.isNotEmpty)
                const PopupMenuItem(
                  value: MenuItems.delete,
                  child: Text('Delete'),
                ),
              if (_selectedFiles.isNotEmpty)
                const PopupMenuItem(
                  value: MenuItems.clearSelection,
                  child: Text('Clear Selection'),
                )
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(4),
        child: Center(
          child: SizedBox(
            width: 350.0,
            child: ListView(
              children: <Widget>[
                for (var fileObj in _fileList)
                  Card(
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
                        selected: _selectedFiles.contains(fileObj),
                        title: Text.rich(
                          // Show file extension less prominently.
                          TextSpan(
                            text: '${fileObj.nameNoExtension} ',
                            children: <TextSpan>[
                              TextSpan(
                                text: fileObj.extension,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ask user to overwrite a filename and return result.
  Future<bool> askOverwriteOk(String filename) async {
    final ans = await common_dialogs.okCancelDialog(
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
