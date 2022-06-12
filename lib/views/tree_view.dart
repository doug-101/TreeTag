// tree_view.dart, the main view showing indented tree data.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/nodes.dart';
import '../model/structure.dart';

const emptyName = '[Empty Title]';
const _closedIcon = Icon(Icons.arrow_right, size: 24.0);
const _openIcon = Icon(Icons.arrow_drop_down, size: 24.0);
const _leafIcon = Icon(Icons.circle, size: 8.0);

/// The main indented tree view.
///
/// A tap opens or closes tree items.
/// A long press opens a [DetailView] for an item and/or its children.
/// Menu items open config views, undo views and do file operations.
class TreeView extends StatelessWidget {
  late final String headerName;

  TreeView({Key? key, required String fileRootName}) : super(key: key) {
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
          children: items,
          controller: ScrollController(),
        );
      },
    );
  }

  /// A single widget for a tree node.
  Widget _row(LeveledNode leveledNode, BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    final node = leveledNode.node;
    String nodeText;
    if (node is LeafNode && node.isExpanded(leveledNode.parent!)) {
      nodeText = node.outputs().join('\n');
    } else {
      nodeText = node.title.isNotEmpty ? node.title : emptyName;
    }
    return Container(
      padding:
          EdgeInsets.fromLTRB(25.0 * leveledNode.level + 4.0, 8.0, 4.0, 8.0),
      child: GestureDetector(
        onTap: () {
          if (node.hasChildren) {
            model.toggleNodeOpen(node);
          } else if (node is LeafNode) {
            model.toggleNodeExpanded(node, leveledNode.parent!);
          }
        },
        onLongPress: () {
          model.addDetailViewNode(node, doClearFirst: true);
        },
        child: Row(
          crossAxisAlignment: node.hasChildren
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            node.hasChildren
                ? Container(
                    child: node.isOpen ? _openIcon : _closedIcon,
                  )
                : Container(
                    child: _leafIcon,
                    padding: EdgeInsets.only(left: 8.0, right: 8.0),
                  ),
            Expanded(child: Text(nodeText, softWrap: true)),
          ],
        ),
      ),
    );
  }
}
