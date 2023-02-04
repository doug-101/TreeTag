// help_view.dart, shows a Markdown output of the README file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

/// Provides a view with Markdown output of the README file.
class HelpView extends StatefulWidget {
  @override
  State<HelpView> createState() => _HelpViewState();
}

class _HelpViewState extends State<HelpView> {
  String _helpContent = '';

  @override
  void initState() {
    super.initState();
    _loadHelpContent();
  }

  void _loadHelpContent() async {
    _helpContent = await rootBundle.loadString('README.md');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help - TreeTag'),
      ),
      body: Markdown(
        data: _helpContent,
        onTapLink: (String text, String? href, String title) async {
          if (href != null) {
            launchUrl(
              Uri.parse(href),
              mode: LaunchMode.externalApplication,
            );
          }
        },
      ),
    );
  }
}
