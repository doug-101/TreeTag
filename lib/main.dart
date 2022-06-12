// main.dart, the main app entry point file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_size/window_size.dart';
import 'model/structure.dart';
import 'model/nodes.dart';
import 'views/detail_view.dart';
import 'views/file_control.dart';
import 'views/frame_view.dart';
import 'views/tree_view.dart';
import 'views/undo_view.dart';
import 'views/config/config_view.dart';

/// [prefs] is the global shared_preferences instance.
///
/// It is initialized in file_control.dart.
late final SharedPreferences prefs;

void main() {
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
  runApp(
    ChangeNotifierProvider(
      create: (context) => Structure(),
      child: MaterialApp(
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
