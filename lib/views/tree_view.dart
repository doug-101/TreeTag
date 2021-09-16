// tree_view.dart, the main view showing the tree data.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../model/nodes.dart';
import '../model/struct.dart';
import '../views/detail_view.dart';

/// The main indented tree view.
class TreeView extends StatefulWidget {
  final PlatformFile fileObj;

  TreeView({Key? key, required this.fileObj}) : super(key: key);

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView> {
  final _closedIcon = Icon(Icons.arrow_right, size: 24.0, color: Colors.blue);
  final _openIcon = Icon(Icons.arrow_drop_down, size: 24.0, color: Colors.blue);
  final _leafIcon = Icon(Icons.circle, size: 8.0, color: Colors.blue);
  late final headerName;
  void initState() {
    super.initState();
    openFile(widget.fileObj.path);
    var fileName = widget.fileObj.name;
    var ext = widget.fileObj.extension;
    if (ext != null) {
      var endPos = fileName.length - ext.length - 1;
      if (endPos > 0) fileName = fileName.substring(0, endPos);
    }
    headerName = 'TreeTag - ' + fileName;
    FilePicker.platform.clearTemporaryFiles();
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
      body: ListView(
        children: _itemRows(),
      ),
    );
  }

  /// The widgets for each node in the tree.
  List<Widget> _itemRows() {
    final items = <Widget>[];
    for (var root in rootNodes) {
      for (var leveledNode in nodeGenerator(root)) {
        items.add(_row(leveledNode));
      }
    }
    return items;
  }

  /// A single widget for a tree node.
  Widget _row(LeveledNode leveledNode) {
    final node = leveledNode.node;
    return Container(
      padding:
          EdgeInsets.fromLTRB(25.0 * leveledNode.level + 4.0, 8.0, 4.0, 8.0),
      child: GestureDetector(
        onTap: () {
          if (node.hasChildren) {
            setState(() {
              node.isOpen = !node.isOpen;
            });
          }
        },
        onLongPress: () {
          if (node is LeafNode ||
              (node.hasChildren && node.childNodes()[0] is LeafNode)) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailView(node: node),
              ),
            );
          }
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
