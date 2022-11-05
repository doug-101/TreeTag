// option_config.dart, a view to edit extra config options for this file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/structure.dart';

/// The extra config option widget.
///
/// Lists options that don't belong elsewhere.
class OptionConfig extends StatefulWidget {
  OptionConfig({Key? key}) : super(key: key);

  @override
  State<OptionConfig> createState() => _OptionConfigState();
}

class _OptionConfigState extends State<OptionConfig> {
  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: ListView(
        children: <Widget>[
          SwitchListTile(
            title: const Text('Enable Markdown text formatting'),
            value: model.useMarkdownOutput,
            onChanged: (bool value) {
              model.setMarkdownOutput(value);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
