// option_config.dart, a view to edit extra config options for this file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../common_dialogs.dart' as common_dialogs;
import '../../model/structure.dart';

/// The extra config option widget.
///
/// Lists options that don't belong elsewhere.
class OptionConfig extends StatefulWidget {
  const OptionConfig({super.key});

  @override
  State<OptionConfig> createState() => _OptionConfigState();
}

class _OptionConfigState extends State<OptionConfig> {
  @override
  Widget build(BuildContext context) {
    final model = Provider.of<Structure>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Center(
        child: SizedBox(
          width: 450.0,
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
              // File liks are only supported on the desktop.
              if (!Platform.isAndroid && !Platform.isIOS)
                SwitchListTile(
                  title: const Text('Use relative paths for file links'),
                  value: model.useRelativeLinks,
                  onChanged: (bool value) async {
                    model.setUseRelativeLink(value);
                    if (!model.useMarkdownOutput) {
                      await common_dialogs.okDialog(
                        context: context,
                        title: 'Markdown Required',
                        label: 'Markdwon formatting must be enabled to use '
                            'file links',
                      );
                    }
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
