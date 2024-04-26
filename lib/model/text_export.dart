// text_export.dart, translations to export tree data to indented text.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'nodes.dart';
import 'structure.dart';

const emptyName = '[Empty Title]';

/// Main class for exports to indented text.
class TextExport {
  final Structure model;

  TextExport(this.model);

  String textString({bool includeOutput = false}) {
    final resultLines = <String>[];
    for (var root in model.rootNodes) {
      for (var leveledNode in leveledNodeGenerator(root, openOnly: false)) {
        final node = leveledNode.node;
        final lines = includeOutput && node is LeafNode
            ? node.outputs() + ['']
            : [node.title.isNotEmpty ? node.title : emptyName];
        for (var line in lines) {
          for (var ln in line.trimRight().split('\n')) {
            resultLines.add('\t' * leveledNode.level + ln);
          }
        }
      }
    }
    return resultLines.join('\n');
  }
}
