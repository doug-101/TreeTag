// main.dart, the main app entry point file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'model/structure.dart';
import 'model/nodes.dart';
import 'views/detail_view.dart';
import 'views/file_control.dart';
import 'views/tree_view.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => Structure(),
      child: MaterialApp(
          title: 'TreeTag',
          initialRoute: '/fileControl',
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/fileControl':
                return MaterialPageRoute(builder: (context) {
                  return FileControl();
                });
              case '/treeView':
                final fileName = settings.arguments as String;
                return MaterialPageRoute(builder: (context) {
                  return TreeView(fileRootName: fileName);
                });
              case '/detailView':
                final node = settings.arguments as Node;
                return MaterialPageRoute(builder: (context) {
                  return DetailView(node: node);
                });
            }
          }),
    ),
  );
}
