// detail_view.dart, a view showing node and child output.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/nodes.dart';
import '../model/structure.dart';
import '../views/edit_view.dart';

/// A detail view that shows node and child output after a long press.
class DetailView extends StatelessWidget {
  final Node node;

  DetailView({Key? key, required this.node}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(node.title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_circle),
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
      // node is GroupNode or TitleNode
      for (var childNode in node.childNodes()) {
        items.add(
          Card(
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, '/detailView',
                    arguments: childNode);
              },
              child: Container(
                margin: const EdgeInsets.all(10.0),
                child: childNode is LeafNode
                    ? Text(childNode.outputs().join('\n'))
                    : Text(childNode.title),
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
