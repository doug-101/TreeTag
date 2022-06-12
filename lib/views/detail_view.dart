// detail_view.dart, a view showing node and child output.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/nodes.dart';
import '../model/structure.dart';

const emptyTitleName = '[Empty Title]';

/// A detail view that shows node and child output.
///
/// This view is opened after a long press on a [TreeView], with content
/// based on the last entry in [detailViewNodes] in the model.
/// Previous entries are the history of this view.
/// Shows details of a single node if it is a [LeafNode].
/// Shows a node and children if it is a [TitleNode] or a [GroupNode].
class DetailView extends StatelessWidget {
  DetailView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<Structure>(
      builder: (context, model, child) {
        var rootNode = model.currentDetailViewNode();
        var cards = <Widget>[];
        if (rootNode != null) {
          if (model.obsoleteNodes.contains(rootNode)) {
            cards.add(
              // Show a deleted or removed notation if the node is already gone.
              Card(
                child: Container(
                  margin: const EdgeInsets.all(10.0),
                  child: Text(
                      rootNode is LeafNode ? 'Node Deleted' : 'Group Removed',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            );
          } else if (rootNode is LeafNode) {
            cards.add(
              Card(
                child: Container(
                  margin: const EdgeInsets.all(10.0),
                  child: Text(rootNode.outputs().join('\n')),
                ),
              ),
            );
          } else {
            // Show node and children for [GroupNode] or [TitleNode].
            for (var childNode in rootNode.childNodes()) {
              cards.add(
                Card(
                  child: InkWell(
                    // Add tapped child to view history and update this view.
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
        }
        return ListView(
          children: cards,
          controller: ScrollController(),
        );
      },
    );
  }
}
