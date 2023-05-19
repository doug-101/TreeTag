// rule_edit.dart, a view to edit a rule node's details.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/nodes.dart';
import '../../model/structure.dart';
import 'line_edit.dart';
import 'sort_edit.dart';

/// The rule node edit view.
///
/// Allows editing of rule line, rule sorting and child sorting.
/// Called from [TreeConfig] widget.
class RuleEdit extends StatefulWidget {
  final RuleNode node;
  final bool isNew;

  RuleEdit({Key? key, required this.node, this.isNew = false})
      : super(key: key);

  @override
  State<RuleEdit> createState() => _RuleEditState();
}

class _RuleEditState extends State<RuleEdit> {
  @override
  Widget build(BuildContext context) {
    final model = Provider.of<Structure>(context, listen: false);
    final contrastStyle =
        TextStyle(color: Theme.of(context).colorScheme.secondary);
    if (widget.isNew && widget.node.ruleLine.isEmpty) {
      // A new rule is empty, so it goes directly to the LineEdit.
      // Use a microtask to delay the push until after the build.
      Future.microtask(() async {
        final isChanged = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LineEdit(line: widget.node.ruleLine, title: 'New Rule Line'),
          ),
        );
        if (isChanged) {
          setState(() {
            model.addRuleChild(widget.node);
          });
        } else {
          Navigator.pop(context);
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Node'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
          children: <Widget>[
            // Displays rule line, edits when tapped.
            InkWell(
              onTap: () async {
                final newRuleLine = widget.node.ruleLine.copy();
                final isChanged = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LineEdit(line: newRuleLine, title: 'Rule Line Edit'),
                  ),
                );
                if (isChanged) {
                  setState(() {
                    model.editRuleLine(widget.node, newRuleLine);
                  });
                }
              },
              child: Padding(
                padding: EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Rule Definition',
                        style: Theme.of(context).textTheme.caption),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: Text.rich(
                        TextSpan(
                          children:
                              widget.node.ruleLine.richLineSpans(contrastStyle),
                        ),
                        style: Theme.of(context).textTheme.subtitle1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(),
            // The rule sorting controls.
            Padding(
              padding: EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Group Sorting',
                      style: Theme.of(context).textTheme.caption),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: ToggleButtons(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.all(10.0),
                          child: Text('Default'),
                        ),
                        Padding(
                          padding: EdgeInsets.all(10.0),
                          child: Text('Custom'),
                        ),
                      ],
                      borderWidth: 3.0,
                      constraints:
                          BoxConstraints(minWidth: 48.0, minHeight: 24.0),
                      borderRadius: BorderRadius.circular(10.0),
                      isSelected: [
                        !widget.node.hasCustomSortFields,
                        widget.node.hasCustomSortFields
                      ],
                      onPressed: (int index) async {
                        if (index == 0) {
                          // Default button pushed.
                          if (widget.node.hasCustomSortFields) {
                            setState(() {
                              model.ruleSortKeysToDefault(widget.node);
                            });
                          }
                        } else {
                          // Custom button pushed.
                          var newSortKeys = [
                            for (var key in widget.node.sortFields)
                              SortKey.copy(key)
                          ];
                          var isChanged = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SortEdit(
                                sortKeys: newSortKeys,
                                availFields: widget.node.ruleLine.fields(),
                              ),
                            ),
                          );
                          if (isChanged) {
                            setState(() {
                              model.updateRuleSortKeys(
                                  widget.node, newSortKeys);
                            });
                          }
                        }
                      },
                    ),
                  ),
                  // Show rule sort field names for reference.
                  Text('[${widget.node.sortFields.join(', ')}]'),
                ],
              ),
            ),
            Divider(),
            // The child sorting controls.
            if (widget.node.childRuleNode == null)
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Child Sorting',
                        style: Theme.of(context).textTheme.caption),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: ToggleButtons(
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Text('Default'),
                          ),
                          Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Text('Custom'),
                          ),
                        ],
                        borderWidth: 3.0,
                        constraints:
                            BoxConstraints(minWidth: 48.0, minHeight: 24.0),
                        borderRadius: BorderRadius.circular(10.0),
                        isSelected: [
                          !widget.node.hasCustomChildSortFields,
                          widget.node.hasCustomChildSortFields
                        ],
                        onPressed: (int index) async {
                          if (index == 0) {
                            // Default button pushed.
                            if (widget.node.hasCustomChildSortFields) {
                              setState(() {
                                model.childSortKeysToDefault(widget.node);
                              });
                            }
                          } else {
                            // Custom button pushed.
                            final newSortKeys = [
                              for (var key in widget.node.childSortFields)
                                SortKey.copy(key)
                            ];
                            final isChanged = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SortEdit(sortKeys: newSortKeys),
                              ),
                            );
                            if (isChanged) {
                              setState(() {
                                model.updateChildSortKeys(
                                    widget.node, newSortKeys);
                              });
                            }
                          }
                        },
                      ),
                    ),
                    // Show child sort field names for reference.
                    Text('[${widget.node.childSortFields.join(', ')}]'),
                  ],
                ),
              ),
            if (widget.node.childRuleNode == null) Divider(),
          ],
        ),
      ),
    );
  }
}
