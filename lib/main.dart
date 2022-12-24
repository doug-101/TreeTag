// main.dart, the main app entry point file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_size/window_size.dart';
import 'model/io_file.dart';
import 'model/structure.dart';
import 'model/nodes.dart';
import 'views/common_dialogs.dart' as commonDialogs;
import 'views/detail_view.dart';
import 'views/file_control.dart';
import 'views/frame_view.dart';
import 'views/tree_view.dart';
import 'views/undo_view.dart';
import 'views/config/config_view.dart';

/// [prefs] is the global shared_preferences instance.
late final SharedPreferences prefs;

Future<void> main() async {
  LicenseRegistry.addLicense(
    () => Stream<LicenseEntry>.value(
      const LicenseEntryWithLineBreaks(
        <String>['TreeTag'],
        'TreeTag, Copyright (C) 2022 by Douglas W. Bell\n\n'
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
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('TreeTag');
    setWindowMinSize(const Size(160, 160));
  }
  prefs = await SharedPreferences.getInstance();
  if (prefs.getString('workdir') == null) {
    Directory? workDir;
    if (Platform.isAndroid) {
      // Use "external" user-accessible location if possible.
      workDir = await getExternalStorageDirectory();
    }
    if (workDir == null) {
      // For failed external stroage or for non-Android platforms.
      workDir = await getApplicationDocumentsDirectory();
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
              title: Text('Error'),
              content:
                  Text('Failed to save file changes:\n${error.toString()}'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context, true),
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
  runApp(
    ChangeNotifierProvider(
      create: (context) => Structure(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'TreeTag',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.teal,
          ).copyWith(
            secondary: Colors.green,
          ),
          iconTheme: IconThemeData(color: Colors.green),
        ),
        initialRoute: '/fileControl',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/fileControl':
              return MaterialPageRoute(builder: (context) {
                return FileControl();
              });
            case '/frameView':
              final fileName = settings.arguments as String;
              return MaterialPageRoute(builder: (context) {
                return FrameView(fileRootName: fileName);
              });
            case '/treeView':
              final fileName = settings.arguments as String;
              return MaterialPageRoute(builder: (context) {
                return TreeView(fileRootName: fileName);
              });
            case '/detailView':
              return MaterialPageRoute(builder: (context) {
                return DetailView();
              });
            case '/configView':
              return MaterialPageRoute(builder: (context) {
                return ConfigView();
              });
            case '/undoView':
              return MaterialPageRoute(builder: (context) {
                return UndoView();
              });
          }
        },
      ),
    ),
  );
}
