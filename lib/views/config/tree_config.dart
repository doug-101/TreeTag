// tree_config.dart, a view to edit the tree structure configuration.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/nodes.dart';
import '../../model/structure.dart';
import 'rule_edit.dart';

enum MenuItems { titleSibling, titleChild, ruleChild }

// The tree config widget.
class TreeConfig extends StatefulWidget {
  @override
  State<TreeConfig> createState() => _TreeConfigState();
}

class _TreeConfigState extends State<TreeConfig> {
  Node? selectedNode;
  final _titleEditKey = GlobalKey<FormFieldState>();

  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            PopupMenuButton(
              icon: const Icon(Icons.add_circle_outline),
              onSelected: (result) async {
                switch (result) {
                  case MenuItems.titleSibling:
                    var name = await titleDialog(label: 'New title text');
                    if (name != null) {
                      setState(() {
                        model.addTitleSibling(selectedNode! as TitleNode, name);
                      });
                    }
                    break;
                  case MenuItems.titleChild:
                    var name = await titleDialog(label: 'New title text');
                    if (name != null) {
                      setState(() {
                        model.addTitleChild(selectedNode! as TitleNode, name);
                      });
                    }
                    break;
                  case MenuItems.ruleChild:
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Text('Add Title Sibling'),
                  enabled: selectedNode != null && selectedNode! is TitleNode,
                  value: MenuItems.titleSibling,
                ),
                PopupMenuItem(
                  child: Text('Add Title Child'),
                  enabled: selectedNode != null &&
                      selectedNode! is TitleNode &&
                      (selectedNode! as TitleNode).childRuleNode == null,
                  value: MenuItems.titleChild,
                ),
                PopupMenuItem(
                  child: Text('Add Group Rule Child'),
                  enabled: selectedNode != null && !selectedNode!.hasChildren,
                  value: MenuItems.ruleChild,
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: selectedNode == null
                  ? null
                  : () async {
                      if (selectedNode! is TitleNode) {
                        var node = selectedNode! as TitleNode;
                        var name = await titleDialog(
                            initName: node.title, label: 'Edit title text');
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
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: (selectedNode == null ||
                      (selectedNode?.parent == null &&
                          model.rootNodes.length < 2))
                  ? null
                  : () async {
                      setState(() {
                        model.deleteTreeNode(selectedNode!);
                        selectedNode = null;
                      });
                    },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_circle_up),
              onPressed:
                  (selectedNode == null || !model.canNodeMove(selectedNode!))
                      ? null
                      : () {
                          setState(() {
                            model.moveTitleNode(selectedNode! as TitleNode);
                          });
                        },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_circle_down),
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

  List<Widget> _treeRows(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    final contrastStyle =
        TextStyle(color: Theme.of(context).colorScheme.secondary);
    final items = <Widget>[];
    for (var root in model.rootNodes) {
      for (var leveledNode in storedNodeGenerator(root)) {
        var node = leveledNode.node;
        items.add(
          Padding(
            padding:
                EdgeInsets.only(left: 25 * leveledNode.level + 8.0, right: 8.0),
            child: Card(
              color: node == selectedNode
                  ? Theme.of(context).highlightColor
                  : null,
              child: ListTile(
                title: node is RuleNode
                    ? Text.rich(TextSpan(
                        children: node.ruleLine.richLineSpans(contrastStyle)))
                    : Text(node.title),
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

  Future<String?> titleDialog({String? initName, String? label}) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Title Name'),
          content: TextFormField(
            key: _titleEditKey,
            decoration: InputDecoration(labelText: label ?? ''),
            initialValue: initName ?? '',
            validator: (String? text) {
              if (text?.isEmpty ?? false) return 'Cannot be empty';
              return null;
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                if (_titleEditKey.currentState!.validate()) {
                  Navigator.pop(context, _titleEditKey.currentState!.value);
                }
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, null),
            ),
          ],
        );
      },
    );
  }
}