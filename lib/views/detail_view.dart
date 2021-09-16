// tree_view.dart, the main view showing the tree data.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import '../model/nodes.dart';

/// A detail view that shows node and child output after a long press.
class DetailView extends StatefulWidget {
  final Node node;

  DetailView({Key? key, required this.node}) : super(key: key);

  @override
  State<DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<DetailView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.node.title),
        actions: <Widget>[
          if (widget.node is LeafNode)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {},
            ),
          if (widget.node is LeafNode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {},
            ),
        ],
      ),
      body: ListView(
        children: _detailRows(widget.node),
      ),
    );
  }

  List<Widget> _detailRows(Node node) {
    var items = <Widget>[];
    if (node is LeafNode) {
      items.add(
        Card(
          child: Container(
            margin: const EdgeInsets.all(10.0),
            child: Text(node.outputs().join('\n')),
          ),
        ),
      );
    } else {
      // node is GroupNode
      for (var childNode in node.childNodes()) {
        if (childNode is LeafNode) {
          items.add(
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailView(node: childNode),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.all(10.0),
                  child: Text(childNode.outputs().join('\n')),
                ),
              ),
              margin: EdgeInsets.all(5.0),
            ),
          );
        }
      }
    }
    return items;
  }
}
