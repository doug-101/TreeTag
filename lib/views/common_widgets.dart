// common_widgets.dart, miscellaneous custom widgets.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:flutter_markdown_selectionarea/flutter_markdown.dart'
    as renderer;
import 'package:markdown/markdown.dart' as markdown;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show prefs;

/// A widget that displays Markdown and launches URLs.
class MarkdownWithLinks extends StatelessWidget {
  final String data;
  final ThemeData? theme;
  final bool doShowMatches;

  const MarkdownWithLinks({
    super.key,
    required this.data,
    this.theme,
    this.doShowMatches = false,
  });

  @override
  Widget build(BuildContext context) {
    renderer.MarkdownStyleSheet? style;
    if (theme != null) style = renderer.MarkdownStyleSheet.fromTheme(theme!);
    return renderer.MarkdownBody(
      data: data,
      // Tried internal links to headers, but not supported.
      //extensionSet: md.ExtensionSet.gitHubWeb,
      styleSheet: style,
      builders: {if (doShowMatches) 'match': ShowMatchBuilder()},
      inlineSyntaxes: [if (doShowMatches) ShowMatchSyntax()],
      onTapLink: (String text, String? href, String title) async {
        if (href != null && !href.startsWith('#')) {
          if (href.startsWith('file:')) {
            var path = href.substring(5);
            if (p.isRelative(path)) {
              path = p.normalize(p.join(prefs.getString('workdir')!, path));
              href = 'file:$path';
            }
          }
          launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}

class ShowMatchSyntax extends markdown.InlineSyntax {
  static const matchPrefix = '\u001e';
  static const matchSuffix = '\u001f';

  ShowMatchSyntax() : super('$matchPrefix(.*?)$matchSuffix');

  @override
  bool onMatch(markdown.InlineParser parser, Match match) {
    markdown.Element matchTag = markdown.Element.text('match', match[1] ?? '');
    parser.addNode(matchTag);
    return true;
  }
}

class ShowMatchBuilder extends renderer.MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    markdown.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return SelectableText.rich(
      TextSpan(
        text: element.textContent,
        style: (preferredStyle ?? parentStyle ?? const TextStyle()).copyWith(
          color: Colors.red,
        ),
      ),
    );
  }
}
