// sort_edit.dart, a view to edit sorting rules containing fields.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/fields.dart';
import '../../model/nodes.dart';
import '../../model/structure.dart';

/// The sort edit view.
///
/// Called from [RuleEdit] to edit custom sort fields, for both rule sort and
/// child sort fields.
class SortEdit extends StatefulWidget {
  final List<SortKey> sortKeys;

  /// The fields available if given, otherwise assumes all fields.
  List<Field>? availFields;

  SortEdit({Key? key, required this.sortKeys, this.availFields})
      : super(key: key);

  @override
  State<SortEdit> createState() => _SortEditState();
}

class _SortEditState extends State<SortEdit> {
  var isChanged = false;
  SortKey? selectedKey;

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<Structure>(context, listen: false);
    final usedFieldNames = [for (var key in widget.sortKeys) key.keyField.name];
    final availFieldNames = [
      for (var field in widget.availFields ?? model.fieldMap.values) field.name
    ];
    // Position number for the field card label.
    var posNum = 1;
    return Scaffold(
      appBar: AppBar(
        title:
            Text('${widget.availFields != null ? 'Rule' : 'Child'} Sort Edit'),
      ),
      body: WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, isChanged);
          return true;
        },
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Add a field to the list.
                  PopupMenuButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add a field',
                    enabled: usedFieldNames.length < availFieldNames.length,
                    onSelected: (fieldName) async {
                      var pos = widget.sortKeys.length;
                      if (selectedKey != null)
                        pos = widget.sortKeys.indexOf(selectedKey!);
                      setState(() {
                        widget.sortKeys
                            .insert(pos, SortKey(model.fieldMap[fieldName]!));
                        isChanged = true;
                      });
                    },
                    itemBuilder: (context) => <PopupMenuEntry>[
                      for (var fieldName in availFieldNames)
                        if (!usedFieldNames.contains(fieldName))
                          PopupMenuItem(
                            child: Text('Add Field: $fieldName'),
                            value: fieldName,
                          )
                    ],
                  ),
                  // Swap sort direction for the selected field.
                  IconButton(
                    icon: const Icon(Icons.swap_vert),
                    tooltip: 'Swap sort direction',
                    onPressed: selectedKey == null
                        ? null
                        : () {
                            setState(() {
                              selectedKey!.isAscend = !selectedKey!.isAscend;
                              isChanged = true;
                            });
                          },
                  ),
                  // Delete the selected field.
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove a field',
                    onPressed:
                        (selectedKey == null || widget.sortKeys.length < 2)
                            ? null
                            : () {
                                setState(() {
                                  widget.sortKeys.remove(selectedKey);
                                  selectedKey = null;
                                  isChanged = true;
                                });
                              },
                  ),
                  // Move the selected field up.
                  IconButton(
                    icon: const Icon(Icons.arrow_circle_up),
                    tooltip: 'Move a field up',
                    onPressed: (selectedKey == null ||
                            widget.sortKeys.indexOf(selectedKey!) == 0)
                        ? null
                        : () {
                            setState(() {
                              final pos = widget.sortKeys.indexOf(selectedKey!);
                              widget.sortKeys.removeAt(pos);
                              widget.sortKeys.insert(pos - 1, selectedKey!);
                              isChanged = true;
                            });
                          },
                  ),
                  // Move the selected field down.
                  IconButton(
                    icon: const Icon(Icons.arrow_circle_down),
                    tooltip: 'Move a field down',
                    onPressed: (selectedKey == null ||
                            widget.sortKeys.indexOf(selectedKey!) ==
                                widget.sortKeys.length - 1)
                        ? null
                        : () {
                            setState(() {
                              final pos = widget.sortKeys.indexOf(selectedKey!);
                              widget.sortKeys.removeAt(pos);
                              widget.sortKeys.insert(pos + 1, selectedKey!);
                              isChanged = true;
                            });
                          },
                  ),
                ],
              ),
              // The list of sort field cards.
              Expanded(
                child: ListView(
                  children: <Widget>[
                    for (var key in widget.sortKeys)
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Card(
                          color: key == selectedKey
                              ? Theme.of(context).highlightColor
                              : null,
                          child: ListTile(
                            leading: Icon(key.isAscend
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down),
                            title: Text(key.keyField.name),
                            trailing: Text((posNum++).toString()),
                            onTap: () {
                              setState(() {
                                if (key != selectedKey) {
                                  selectedKey = key;
                                } else {
                                  selectedKey = null;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
