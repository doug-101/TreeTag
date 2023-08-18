// tree_config.dart, a view to edit the tree structure configuration.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'rule_edit.dart';
import '../common_dialogs.dart' as commonDialogs;
import '../../model/nodes.dart';
import '../../model/structure.dart';

enum AddMenuItems { titleSibling, titleChild, ruleChild }

enum DeleteMenuItems { nodeOnly, branch }

// The tree config widget.
///
/// Lists all of the stored nodes in a tree.
/// One of the tabbed items on the [ConfigView].
class TreeConfig extends StatefulWidget {
  @override
  State<TreeConfig> createState() => _TreeConfigState();
}

class _TreeConfigState extends State<TreeConfig> {
  Node? selectedNode;

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<Structure>(context, listen: false);
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Menu for adding nodes.
            PopupMenuButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add an item',
              onSelected: (result) async {
                switch (result) {
                  case AddMenuItems.titleSibling:
                    final name = await commonDialogs.textDialog(
                      context: context,
                      title: 'Title Name',
                      label: 'New title text',
                    );
                    if (name != null) {
                      setState(() {
                        model.addTitleSibling(selectedNode! as TitleNode, name);
                      });
                    }
                  case AddMenuItems.titleChild:
                    final name = await commonDialogs.textDialog(
                      context: context,
                      title: 'Title Name',
                      label: 'New title text',
                    );
                    if (name != null) {
                      setState(() {
                        model.addTitleChild(selectedNode! as TitleNode, name);
                      });
                    }
                  case AddMenuItems.ruleChild:
                    final newRule = RuleNode(
                      rule: '',
                      modelRef: model,
                      parent: selectedNode!,
                    );
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RuleEdit(node: newRule, isNew: true),
                      ),
                    );
                    setState(() {});
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Text('Add Title Sibling'),
                  enabled: selectedNode != null && selectedNode! is TitleNode,
                  value: AddMenuItems.titleSibling,
                ),
                PopupMenuItem(
                  child: Text('Add Title Child'),
                  enabled: selectedNode != null && selectedNode! is TitleNode,
                  value: AddMenuItems.titleChild,
                ),
                PopupMenuItem(
                  child: Text('Add Group Rule Child'),
                  enabled: selectedNode != null &&
                      (!selectedNode!.hasChildren ||
                          selectedNode is RuleNode ||
                          (selectedNode as TitleNode).childRuleNode != null),
                  value: AddMenuItems.ruleChild,
                ),
              ],
            ),
            // Button to edit a selected node.
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit an item',
              onPressed: selectedNode == null
                  ? null
                  : () async {
                      if (selectedNode! is TitleNode) {
                        final node = selectedNode! as TitleNode;
                        final name = await commonDialogs.textDialog(
                          context: context,
                          initText: node.title,
                          title: 'Title Name',
                          label: 'Edit title text',
                        );
                        if (name != null) {
                          setState(() {
                            model.editTitle(node, name);
                          });
                        }
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RuleEdit(node: selectedNode! as RuleNode),
                          ),
                        );
                        setState(() {});
                      }
                    },
            ),
            // Menu for deleting a nodes.
            PopupMenuButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove an item',
              onSelected: (result) async {
                switch (result) {
                  case DeleteMenuItems.nodeOnly:
                    setState(() {
                      model.deleteTreeNode(
                        selectedNode!,
                        keepChildren: selectedNode!.hasChildren,
                      );
                      selectedNode = null;
                    });
                  case DeleteMenuItems.branch:
                    setState(() {
                      model.deleteTreeNode(selectedNode!);
                      selectedNode = null;
                    });
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Text('Delete Node Only'),
                  enabled: selectedNode != null &&
                      (!selectedNode!.hasChildren ||
                          selectedNode is RuleNode ||
                          (selectedNode as TitleNode).childRuleNode == null ||
                          (selectedNode?.parent != null &&
                              selectedNode!.parent!.storedChildren().length ==
                                  1)) &&
                      (selectedNode?.parent != null ||
                          model.rootNodes.length > 1),
                  value: DeleteMenuItems.nodeOnly,
                ),
                PopupMenuItem(
                  child: Text('Delete Node with Children'),
                  enabled: selectedNode != null &&
                      selectedNode!.hasChildren &&
                      (selectedNode?.parent != null ||
                          model.rootNodes.length > 1),
                  value: DeleteMenuItems.branch,
                ),
              ],
            ),
            // Button to move a title node up.
            IconButton(
              icon: const Icon(Icons.arrow_circle_up),
              tooltip: 'Move an item up',
              onPressed:
                  (selectedNode == null || !model.canNodeMove(selectedNode!))
                      ? null
                      : () {
                          setState(() {
                            model.moveTitleNode(selectedNode! as TitleNode);
                          });
                        },
            ),
            // Button to move a title node down.
            IconButton(
              icon: const Icon(Icons.arrow_circle_down),
              tooltip: 'Move an item down',
              onPressed: (selectedNode == null ||
                      !model.canNodeMove(selectedNode!, up: false))
                  ? null
                  : () {
                      setState(() {
                        model.moveTitleNode(selectedNode! as TitleNode,
                            up: false);
                      });
                    },
            ),
          ],
        ),
        Expanded(
          child: ListView(
            children: _treeRows(context),
          ),
        ),
      ],
    );
  }

  /// Returns a list of indented tree node cards,
  List<Widget> _treeRows(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    final contrastStyle =
        TextStyle(color: Theme.of(context).colorScheme.secondary);
    final items = <Widget>[];
    for (var root in model.rootNodes) {
      for (var leveledNode in storedNodeGenerator(root)) {
        final node = leveledNode.node;
        late Text titleText;
        if (node is RuleNode) {
          var ruleTitleSpans = node.ruleLine.richLineSpans(contrastStyle);
          if (ruleTitleSpans.length == 1 &&
              ruleTitleSpans[0].style != contrastStyle) {
            ruleTitleSpans
                .add(TextSpan(text: ' <no_fields>', style: contrastStyle));
          }
          titleText = Text.rich(TextSpan(children: ruleTitleSpans));
        } else {
          titleText = Text(node.title);
        }
        items.add(
          Padding(
            padding:
                EdgeInsets.only(left: 25 * leveledNode.level + 8.0, right: 8.0),
            child: Card(
              color: node == selectedNode
                  ? Theme.of(context).highlightColor
                  : null,
              child: ListTile(
                title: titleText,
                onTap: () {
                  setState(() {
                    if (node != selectedNode) {
                      selectedNode = node;
                    } else {
                      selectedNode = null;
                    }
                  });
                },
              ),
            ),
          ),
        );
      }
    }
    return items;
  }
}
