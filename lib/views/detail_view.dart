// detail_view.dart, a view showing node and child output.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/nodes.dart';
import '../model/structure.dart';
import '../views/edit_view.dart';

const emptyViewName = '[No Current Nodes]';
const emptyTitleName = '[Empty Title]';

/// A detail view that shows node and child output.
///
/// This view is opened after a long press on a [TreeView], with content
/// based on the last entry in [detailViewNodes] in the model.
/// Previous entries are the histroy of this view.
/// Shows details of a single node if it is a [LeafNode].
/// Shows a node and children if it is a [TitleNode] or a [GroupNode].
class DetailView extends StatelessWidget {
  DetailView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<Structure>(
      builder: (context, model, child) {
        var rootNode = model.lastDetailViewNode();
        return Scaffold(
          appBar: AppBar(
            title: Text(
              rootNode != null
                  ? (rootNode.title.isNotEmpty
                      ? rootNode.title
                      : emptyTitleName)
                  : emptyViewName,
            ),
            // A true setting adds a back button, always for narrow displays,
            // otherwise if needed.
            automaticallyImplyLeading:
                !model.hasWideDisplay || model.detailViewNodes.length > 1,
            actions: <Widget>[
              if (rootNode is LeafNode &&
                  !model.obsoleteNodes.contains(rootNode))
                IconButton(
                  icon: const Icon(Icons.delete),
                  // Delete the shown [LeafNode].
                  onPressed: () {
                    model.deleteNode(rootNode as LeafNode);
                  },
                ),
              if (rootNode is LeafNode &&
                  !model.obsoleteNodes.contains(rootNode))
                IconButton(
                  icon: const Icon(Icons.edit),
                  // Edit the shown [LeafNode].
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              EditView(node: rootNode as LeafNode)),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                // Create a new node using data copied from the shown nodes.
                onPressed: () {
                  var newNode = model.newNode(copyFromNode: rootNode);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EditView(node: newNode, isNew: true),
                    ),
                  );
                },
              ),
            ],
          ),
          body: WillPopScope(
            onWillPop: () async {
              // Return false to keep the view open if [detailViewNodes]
              // are not empty.
              return !model.removeDetailViewNode();
            },
            child: ListView(
              children: _detailRows(rootNode, context),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _detailRows(Node? node, BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    var items = <Widget>[];
    if (node == null) return items;
    if (model.obsoleteNodes.contains(node)) {
      items.add(
        // Show a deleted or removed notation if the node is already gone.
        Card(
          child: Container(
            margin: const EdgeInsets.all(10.0),
            child: Text(node is LeafNode ? 'Node Deleted' : 'Group Removed',
                style: TextStyle(color: Colors.red)),
          ),
        ),
      );
    } else if (node is LeafNode) {
      items.add(
        Card(
          child: Container(
            margin: const EdgeInsets.all(10.0),
            child: Text(node.outputs().join('\n')),
          ),
        ),
      );
    } else {
      // Show node and children for [GroupNode] or [TitleNode].
      for (var childNode in node.childNodes()) {
        items.add(
          Card(
            child: InkWell(
              // Add a tapped child to the view history and update this view.
              onTap: () {
                model.addDetailViewNode(childNode);
              },
              child: Container(
                margin: const EdgeInsets.all(10.0),
                child: childNode is LeafNode
                    ? Text(childNode.outputs().join('\n'))
                    : Text(childNode.title.isNotEmpty
                        ? childNode.title
                        : emptyTitleName),
              ),
            ),
            margin: EdgeInsets.all(5.0),
          ),
        );
      }
    }
    return items;
  }
}
