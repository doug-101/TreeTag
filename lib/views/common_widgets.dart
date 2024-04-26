// common_widgets.dart, miscellaneous custom widgets.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:flutter_markdown_selectionarea/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show prefs;

/// A widget that displays Markdown and launches URLs.
class MarkdownWithLinks extends StatelessWidget {
  final String data;
  final ThemeData? theme;

  MarkdownWithLinks({super.key, required this.data, this.theme});

  @override
  Widget build(BuildContext context) {
    MarkdownStyleSheet? style;
    if (theme != null) style = MarkdownStyleSheet.fromTheme(theme!);
    return MarkdownBody(
      data: data,
      // Tried internal links to headers, but not supported.
      //extensionSet: md.ExtensionSet.gitHubWeb,
      styleSheet: style,
      onTapLink: (String text, String? href, String title) async {
        if (href != null && !href.startsWith('#')) {
          if (href.startsWith('file:')) {
            var path = href.substring(5);
            if (p.isRelative(path)) {
              path = p.normalize(p.join(prefs.getString('workdir')!, path));
              href = 'file:$path';
            }
          }
          launchUrl(
            Uri.parse(href),
            mode: LaunchMode.externalApplication,
          );
        }
      },
    );
  }
}
