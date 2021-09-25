// main.dart, the main app entry point file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'model/structure.dart';
import 'views/file_control.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => Structure(),
      child: MaterialApp(
        title: 'TreeTag',
        home: FileControl(),
      ),
    ),
  );
}
