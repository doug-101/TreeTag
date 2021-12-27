// rule_edit.dart, a view to edit a rule node's details.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/nodes.dart';
import '../../model/structure.dart';
import 'line_edit.dart';
import 'sort_edit.dart';

// The rule node edit widget.
class RuleEdit extends StatefulWidget {
  final RuleNode node;

  RuleEdit({Key? key, required this.node}) : super(key: key);

  @override
  State<RuleEdit> createState() => _RuleEditState();
}

class _RuleEditState extends State<RuleEdit> {
  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    final contrastStyle =
        TextStyle(color: Theme.of(context).colorScheme.secondary);
    return Scaffold(
      appBar: AppBar(
        title: Text('Rule Node'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
          children: <Widget>[
            InkWell(
              onTap: () async {
                final newRuleLine = widget.node.ruleLine.copy();
                final isChanged = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LineEdit(line: newRuleLine),
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
                        style: Theme.of(context).textTheme.overline),
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
            Padding(
              padding: EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Rule Sorting',
                      style: Theme.of(context).textTheme.overline),
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
                        !widget.node.hasUniqueSortFields,
                        widget.node.hasUniqueSortFields
                      ],
                      onPressed: (int index) async {
                        if (index == 0) {
                          // Default button pushed.
                          if (widget.node.hasUniqueSortFields) {
                            widget.node.setDefaultRuleSortFields();
                            widget.node.hasUniqueSortFields = false;
                            model.ruleSortKeysUpdated(widget.node);
                            setState(() {});
                          }
                        } else {
                          // Custom button pushed.
                          var isChanged = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SortEdit(
                                sortKeys: widget.node.sortFields,
                                availFields: widget.node.ruleLine.fields(),
                              ),
                            ),
                          );
                          if (isChanged) {
                            widget.node.hasUniqueSortFields = true;
                            model.ruleSortKeysUpdated(widget.node);
                            setState(() {});
                          }
                        }
                      },
                    ),
                  ),
                  Text('[${widget.node.sortFields.join(', ')}]'),
                ],
              ),
            ),
            Divider(),
            if (widget.node.childRuleNode == null)
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Child Sorting',
                        style: Theme.of(context).textTheme.overline),
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
                          !widget.node.hasUniqueChildSortFields,
                          widget.node.hasUniqueChildSortFields
                        ],
                        onPressed: (int index) async {
                          if (index == 0) {
                            // Default button pushed.
                            if (widget.node.hasUniqueChildSortFields) {
                              widget.node.setDefaultChildSortFields();
                              widget.node.hasUniqueChildSortFields = false;
                              model.childSortKeysUpdated(widget.node);
                              setState(() {});
                            }
                          } else {
                            // Custom button pushed.
                            var isChanged = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SortEdit(
                                    sortKeys: widget.node.childSortFields),
                              ),
                            );
                            if (isChanged) {
                              widget.node.hasUniqueChildSortFields = true;
                              model.childSortKeysUpdated(widget.node);
                              setState(() {});
                            }
                          }
                        },
                      ),
                    ),
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
