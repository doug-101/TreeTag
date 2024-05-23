// tree_view.dart, the main view showing indented tree data.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_widgets.dart';
import '../main.dart' show prefs;
import '../model/nodes.dart';
import '../model/structure.dart';

const emptyName = '[Empty Title]';

/// The main indented tree view.
///
/// A tap opens or closes tree items.
/// A long press opens a [DetailView] for an item and/or its children.
/// Menu items open config views, undo views and do file operations.
class TreeView extends StatelessWidget {
  late final String headerName;

  TreeView({super.key, required String fileRootName}) {
    headerName = 'TreeTag - $fileRootName';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Structure>(
      builder: (context, model, child) {
        final items = <Widget>[];
        for (var root in model.rootNodes) {
          for (var leveledNode in leveledNodeGenerator(root)) {
            items.add(_row(leveledNode, context));
          }
        }
        return ListView(
          controller: ScrollController(),
          children: items,
        );
      },
    );
  }

  /// A single widget for a tree node.
  Widget _row(LeveledNode leveledNode, BuildContext context) {
    final spacing = (prefs.getBool('linespacing') ??
            Platform.isLinux || Platform.isWindows || Platform.isMacOS)
        ? 2.0
        : 8.0;
    final model = Provider.of<Structure>(context, listen: false);
    final node = leveledNode.node;
    String nodeText;
    if (node is LeafNode && node.isExpanded(leveledNode.parent!)) {
      nodeText = node.outputs().join(model.useMarkdownOutput ? '\n\n' : '\n');
    } else {
      nodeText = node.title.isNotEmpty ? node.title : emptyName;
    }
    final isNodeSelected =
        model.hasWideDisplay && node == model.currentDetailViewNode();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          25.0 * leveledNode.level + 4.0, spacing, 4.0, spacing),
      child: GestureDetector(
        onTap: () {
          if (node.hasChildren) {
            model.toggleNodeOpen(node);
          } else if (node is LeafNode) {
            model.toggleNodeExpanded(node, leveledNode.parent!);
          }
        },
        onLongPress: () {
          model.addDetailViewRecord(
            node,
            parent: leveledNode.parent,
            doClearFirst: true,
          );
        },
        child: Row(
          crossAxisAlignment: node.hasChildren
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            node.hasChildren
                ? node.isOpen
                    ? isNodeSelected
                        ? Icon(
                            Icons.arrow_drop_down,
                            size: 24.0,
                            color: Theme.of(context).colorScheme.secondary,
                          )
                        : const Icon(Icons.arrow_drop_down, size: 24.0)
                    : isNodeSelected
                        ? Icon(
                            Icons.arrow_right,
                            size: 24.0,
                            color: Theme.of(context).colorScheme.secondary,
                          )
                        : const Icon(Icons.arrow_right, size: 24.0)
                : Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    child: isNodeSelected
                        ? Icon(
                            Icons.circle,
                            size: 8.0,
                            color: Theme.of(context).colorScheme.secondary,
                          )
                        : const Icon(Icons.circle, size: 8.0),
                  ),
            Expanded(
              child: model.useMarkdownOutput
                  ? MarkdownWithLinks(
                      data: nodeText,
                    )
                  : Text(
                      nodeText,
                      softWrap: true,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
