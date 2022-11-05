// detail_view.dart, a view showing node and child output.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../main.dart' show prefs;
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
    var innerMargin = (prefs.getBool('linespacing') ??
            Platform.isLinux || Platform.isWindows || Platform.isMacOS)
        ? const EdgeInsets.symmetric(vertical: 4, horizontal: 10)
        : const EdgeInsets.all(10.0);
    var outerMargin = (prefs.getBool('linespacing') ??
            Platform.isLinux || Platform.isWindows || Platform.isMacOS)
        ? const EdgeInsets.symmetric(vertical: 3, horizontal: 5)
        : const EdgeInsets.all(5.0);
    return Consumer<Structure>(
      builder: (context, model, child) {
        var outWidget = model.useMarkdownOutput
            ? ((String s) {
                return MarkdownBody(data: s);
              })
            : ((String s) {
                return Text(s);
              });
            var lineEnd = model.useMarkdownOutput ? '\n\n' : '\n';
        var rootNode = model.currentDetailViewNode();
        var cards = <Widget>[];
        if (rootNode != null) {
          if (model.obsoleteNodes.contains(rootNode)) {
            cards.add(
              // Show a deleted or removed notation if the node is already gone.
              Card(
                child: Container(
                  margin: innerMargin,
                  child: Text(
                      rootNode is LeafNode ? 'Node Deleted' : 'Group Removed',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            );
          } else if (rootNode is LeafNode) {
            cards.add(
              Card(
                child: SelectionArea(
                  child: Container(
                    margin: innerMargin,
                    child: outWidget(rootNode.outputs().join(lineEnd)),
                  ),
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
                      margin: innerMargin,
                      child: childNode is LeafNode
                          ? outWidget(childNode.outputs().join(lineEnd))
                          : outWidget(childNode.title.isNotEmpty
                              ? childNode.title
                              : emptyTitleName),
                    ),
                  ),
                  margin: outerMargin,
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
