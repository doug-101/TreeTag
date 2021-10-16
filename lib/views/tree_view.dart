// tree_view.dart, the main view showing the tree data.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/nodes.dart';
import '../model/structure.dart';
import '../views/detail_view.dart';

/// The main indented tree view.
class TreeView extends StatelessWidget {
  final _closedIcon = Icon(Icons.arrow_right, size: 24.0, color: Colors.blue);
  final _openIcon = Icon(Icons.arrow_drop_down, size: 24.0, color: Colors.blue);
  final _leafIcon = Icon(Icons.circle, size: 8.0, color: Colors.blue);
  late final String headerName;

  TreeView({Key? key, required String fileRootName}) : super(key: key) {
    headerName = 'TreeTag - ' + fileRootName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(headerName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close File',
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Consumer<Structure>(
        builder: (context, model, child) {
          return ListView(
            children: _itemRows(model, context),
          );
        },
      ),
    );
  }

  /// The widgets for each node in the tree.
  List<Widget> _itemRows(Structure model, BuildContext context) {
    final items = <Widget>[];
    for (var root in model.rootNodes) {
      for (var leveledNode in nodeGenerator(root)) {
        items.add(_row(leveledNode, context));
      }
    }
    return items;
  }

  /// A single widget for a tree node.
  Widget _row(LeveledNode leveledNode, BuildContext context) {
    final node = leveledNode.node;
    return Container(
      padding:
          EdgeInsets.fromLTRB(25.0 * leveledNode.level + 4.0, 8.0, 4.0, 8.0),
      child: GestureDetector(
        onTap: () {
          if (node.hasChildren) {
            node.modelRef.toggleNodeOpen(node);
          }
        },
        onLongPress: () {
          Navigator.pushNamed(context, '/detailView', arguments: node);
        },
        child: Row(children: <Widget>[
          node.hasChildren
              ? Container(
                  child: node.isOpen ? _openIcon : _closedIcon,
                )
              : Container(
                  child: _leafIcon,
                  padding: EdgeInsets.only(left: 8.0, right: 8.0),
                ),
          Expanded(child: Text(node.title, softWrap: true)),
        ]),
      ),
    );
  }
}
