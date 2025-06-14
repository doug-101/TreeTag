// main.dart, the main app entry point file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'model/io_file.dart';
import 'model/structure.dart';
import 'model/theme_model.dart';
import 'views/common_dialogs.dart' as common_dialogs;
import 'views/detail_view.dart';
import 'views/file_control.dart';
import 'views/frame_view.dart';
import 'views/tree_view.dart';
import 'views/undo_view.dart';
import 'views/config/config_view.dart';

/// [prefs] is the global shared_preferences instance.
late final SharedPreferences prefs;

/// This is initially false to avoid saving window geometry during setup.
bool allowSaveWindowGeo = false;

Future<void> main(List<String> cmdLineArgs) async {
  LicenseRegistry.addLicense(
    () => Stream<LicenseEntry>.value(
      const LicenseEntryWithLineBreaks(
        <String>['TreeTag'],
        'TreeTag, Copyright (C) 2024 by Douglas W. Bell\n\n'
        'This program is free software; you can redistribute it and/or modify '
        'it under the terms of the GNU General Public License as published by '
        'the Free Software Foundation; either version 2 of the License, or '
        '(at your option) any later version.\n\n'
        'This program is distributed in the hope that it will be useful, but '
        'WITHOUT ANY WARRANTY; without even the implied warranty of '
        'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU '
        'General Public License for more details.\n\n'
        'You should have received a copy of the GNU General Public License '
        'along with this program; if not, write to the Free Software '
        'Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  '
        '02110-1301, USA.',
      ),
    ),
  );
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    var size = const Size(800.0, 600.0);
    double? offsetX, offsetY;
    if (prefs.getBool('savewindowgeo') ?? true) {
      size = Size(
        prefs.getDouble('winsizex') ?? 800.0,
        prefs.getDouble('winsizey') ?? 600.0,
      );
      offsetX = prefs.getDouble('winposx');
      offsetY = prefs.getDouble('winposy');
    }
    // Setting size, etc. twice (early & later) to work around linux problems.
    if (!(prefs.getBool('showtitlebar') ?? true)) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    await windowManager.setSize(size);
    windowManager.waitUntilReadyToShow(null, () async {
      await windowManager.setTitle('TreeTag');
      if (!(prefs.getBool('showtitlebar') ?? true)) {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      }
      await windowManager.setMinimumSize(const Size(300, 180));
      await windowManager.setSize(size);
      if (offsetX != null && offsetY != null) {
        await windowManager.setPosition(Offset(offsetX, offsetY));
      }
      await windowManager.show();
      allowSaveWindowGeo = prefs.getBool('savewindowgeo') ?? true;
    });
  }
  if (prefs.getString('workdir') == null) {
    Directory? workDir;
    if (Platform.isAndroid) {
      // Use "external" user-accessible location if possible.
      workDir = await getExternalStorageDirectory();
    }
    try {
      // For failed external storage or for non-Android platforms.
      workDir ??= await getApplicationDocumentsDirectory();
    } on MissingPlatformDirectoryException {
      // Can fail on Linux if XDG packages aren't installed.
      final workDirStr = Platform.environment['HOME'];
      if (workDirStr != null) {
        workDir = Directory(workDirStr);
      } else {
        // Last resort is system working directory.
        workDir = Directory.current;
      }
    }
    await prefs.setString('workdir', workDir.path);
  }
  // Use a global navigator key to get a BuildContext for an error dialog.
  final navigatorKey = GlobalKey<NavigatorState>();
  // This catches exceptions from the async save function.
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is SaveException) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text(
                'Failed to save file changes:\n${error.toString()}',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        ),
      );
      return true;
    } else if (error is ExternalModException) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) {
            final model = Provider.of<Structure>(context, listen: false);
            return AlertDialog(
              title: const Text('Warning'),
              content: Text(
                'This file appears to have been externally modified.'
                '\n${error.toString()}',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('RELOAD'),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await model.openFile(model.fileObject, doUpdate: true);
                    } on IOException catch (e) {
                      if (!context.mounted) return;
                      await common_dialogs.okDialog(
                        context: context,
                        title: 'Error',
                        label:
                            'Could not read file: '
                            '${model.fileObject.nameNoExtension}\n$e',
                        isDissmissable: false,
                      );
                    }
                  },
                ),
                TextButton(
                  child: const Text('OVERWRITE'),
                  onPressed: () async {
                    Navigator.pop(context);
                    model.saveFile(doModCheck: false);
                  },
                ),
              ],
            );
          },
        ),
      );
      return true;
    }
    return false;
  };
  String? initialPath = cmdLineArgs.isNotEmpty ? cmdLineArgs.first : null;
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<Structure>(create: (_) => Structure()),
        ChangeNotifierProvider<ThemeModel>(create: (_) => ThemeModel()),
      ],
      child: Consumer<ThemeModel>(
        builder: (context, themeModel, child) {
          final ratio = prefs.getDouble('viewscale') ?? 1.0;
          return FractionallySizedBox(
            widthFactor: 1 / ratio,
            heightFactor: 1 / ratio,
            child: Transform.scale(
              scale: ratio,
              child: MaterialApp(
                navigatorKey: navigatorKey,
                title: 'TreeTag',
                theme: themeModel.getTheme(),
                debugShowCheckedModeBanner: false,
                initialRoute: '/fileControl',
                onGenerateRoute: (settings) {
                  switch (settings.name) {
                    case '/fileControl':
                      return MaterialPageRoute(
                        builder: (context) {
                          if (initialPath != null) {
                            final tmpPath = initialPath;
                            initialPath = null;
                            return FileControl(initialFilePath: tmpPath);
                          }
                          return const FileControl();
                        },
                      );
                    case '/frameView':
                      final fileName = settings.arguments as String;
                      return MaterialPageRoute(
                        builder: (context) {
                          return FrameView(fileRootName: fileName);
                        },
                      );
                    case '/treeView':
                      final fileName = settings.arguments as String;
                      return MaterialPageRoute(
                        builder: (context) {
                          return TreeView(fileRootName: fileName);
                        },
                      );
                    case '/detailView':
                      return MaterialPageRoute(
                        builder: (context) {
                          return const DetailView();
                        },
                      );
                    case '/configView':
                      return MaterialPageRoute(
                        builder: (context) {
                          return const ConfigView();
                        },
                      );
                    case '/undoView':
                      return MaterialPageRoute(
                        builder: (context) {
                          return const UndoView();
                        },
                      );
                    default:
                      return null;
                  }
                },
              ),
            ),
          );
        },
      ),
    ),
  );
}

Future<void> saveWindowGeo() async {
  if (!allowSaveWindowGeo) return;
  final bounds = await windowManager.getBounds();
  await prefs.setDouble('winsizex', bounds.size.width);
  await prefs.setDouble('winsizey', bounds.size.height);
  await prefs.setDouble('winposx', bounds.left);
  await prefs.setDouble('winposy', bounds.top);
}
