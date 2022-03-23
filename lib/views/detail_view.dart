// detail_view.dart, a view showing node and child output.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/nodes.dart';
import '../model/structure.dart';
import '../views/edit_view.dart';

const emptyName = '[Empty Title]';

/// A detail view that shows node and child output.
///
/// This view is opened after a long press on a [TreeView].
/// Shows details of a single node if passed a [LeafNode].
/// Shows a node and children if passed a [TitleNode] or a [GroupNode].
class DetailView extends StatelessWidget {
  final Node node;

  DetailView({Key? key, required this.node}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(node.title.isNotEmpty ? node.title : emptyName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_circle),
            // Create a new node using some data copied from the shown nodes.
            onPressed: () {
              var model = Provider.of<Structure>(context, listen: false);
              var newNode = model.newNode(copyFromNode: node);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditView(node: newNode, isNew: true),
                ),
              );
            },
          ),
          if (node is LeafNode)
            IconButton(
              icon: const Icon(Icons.edit),
              // Edit the shown [LeafNode].
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EditView(node: node as LeafNode)),
                );
              },
            ),
          if (node is LeafNode)
            IconButton(
              icon: const Icon(Icons.delete),
              // Delete the shown [LeafNode].
              onPressed: () {
                var model = Provider.of<Structure>(context, listen: false);
                model.deleteNode(node as LeafNode);
              },
            ),
        ],
      ),
      body: Consumer<Structure>(
        builder: (context, model, child) {
          return ListView(
            children: _detailRows(node, context),
          );
        },
      ),
    );
  }

  List<Widget> _detailRows(Node node, BuildContext context) {
    var items = <Widget>[];
    if (node.modelRef.obsoleteNodes.contains(node)) {
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
              // open a new child [DetailView] for a tapped child.
              onTap: () {
                Navigator.pushNamed(context, '/detailView',
                    arguments: childNode);
              },
              child: Container(
                margin: const EdgeInsets.all(10.0),
                child: childNode is LeafNode
                    ? Text(childNode.outputs().join('\n'))
                    : Text(childNode.title.isNotEmpty
                        ? childNode.title
                        : emptyName),
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
