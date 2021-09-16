// main.dart, the main app entry point file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'views/file_control.dart';

void main() {
  runApp(MaterialApp(
    title: 'TreeTag',
    home: FileControl(),
  ));
}
