// sample_control.dart, a view listing and opening sample files.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert' show json;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'adaptive_split.dart';
import 'common_dialogs.dart' as commonDialogs;
import '../main.dart' show prefs;
import '../model/structure.dart';

/// Provides a sample listview that can open sample files.
class SampleControl extends StatefulWidget {
  @override
  State<SampleControl> createState() => _SampleControlState();
}

class _SampleControlState extends State<SampleControl> {
  var _samplePaths = <String>[];

  @override
  void initState() {
    super.initState();
    _loadSampleList();
  }

  /// Load the sample file list from the resources.
  void _loadSampleList() async {
    var manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    _samplePaths = List.of(
        manifestMap.keys.where((path) => path.startsWith('assets/samples')));
    setState(() {});
  }

  /// Open a sample file after a user tap.
  void _openSample(String path) async {
    var model = Provider.of<Structure>(context, listen: false);
    var newFile = File(p.join(prefs.getString('workdir')!, p.basename(path)));
    if (newFile.existsSync()) {
      // Handle a sample already in the working directory.
      var ans = await commonDialogs.okCancelDialog(
        context: context,
        title: 'Working File Exists',
        label: 'Working file ${p.basename(path)} already exists.\n\n'
            'Open it from the working directory?',
      );
      if (ans == null || !ans) return;
      try {
        model.openFile(newFile);
      } on FormatException {
        await commonDialogs.okDialog(
          context: context,
          title: 'Error',
          label: 'Could not open file: '
              '${p.basenameWithoutExtension(newFile.path)}',
          isDissmissable: false,
        );
        return;
      }
    } else {
      var data = await rootBundle.loadString(path);
      model.openFromData(json.decode(data));
      model.fileObject = newFile;
    }
    Navigator.pushNamed(context, '/adaptiveSplit',
            arguments: p.basenameWithoutExtension(path))
        .then((value) async {
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample Files'),
      ),
      body: ListView(
        children: <Widget>[
          for (var path in _samplePaths)
            Card(
              child: InkWell(
                onLongPress: () {
                  _openSample(path);
                },
                onDoubleTap: () {
                  _openSample(path);
                },
                child: ListTile(
                  title: Text(p.basenameWithoutExtension(path)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
