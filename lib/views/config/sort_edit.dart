// sort_edit.dart, a view to edit sorting rules containing fields.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/fields.dart';
import '../../model/nodes.dart';
import '../../model/structure.dart';

// The sort edit widget
class SortEdit extends StatefulWidget {
  final List<SortKey> sortKeys;
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
    var model = Provider.of<Structure>(context, listen: false);
    var usedFieldNames = [for (var key in widget.sortKeys) key.keyField.name];
    var availFieldNames = [
      for (var field in widget.availFields ?? model.fieldMap.values) field.name
    ];
    var posNum = 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('Sort Edit'),
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
                  PopupMenuButton(
                    icon: const Icon(Icons.add_circle_outline),
                    enabled: usedFieldNames.length < availFieldNames.length,
                    onSelected: (fieldName) async {
                      int pos = widget.sortKeys.length;
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
                  IconButton(
                    icon: const Icon(Icons.swap_vert),
                    onPressed: selectedKey == null
                        ? null
                        : () {
                            setState(() {
                              selectedKey!.isAscend = !selectedKey!.isAscend;
                              isChanged = true;
                            });
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
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
                  IconButton(
                    icon: const Icon(Icons.arrow_circle_up),
                    onPressed: (selectedKey == null ||
                            widget.sortKeys.indexOf(selectedKey!) == 0)
                        ? null
                        : () {
                            setState(() {
                              var pos = widget.sortKeys.indexOf(selectedKey!);
                              widget.sortKeys.removeAt(pos);
                              widget.sortKeys.insert(pos - 1, selectedKey!);
                              isChanged = true;
                            });
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_circle_down),
                    onPressed: (selectedKey == null ||
                            widget.sortKeys.indexOf(selectedKey!) ==
                                widget.sortKeys.length - 1)
                        ? null
                        : () {
                            setState(() {
                              var pos = widget.sortKeys.indexOf(selectedKey!);
                              widget.sortKeys.removeAt(pos);
                              widget.sortKeys.insert(pos + 1, selectedKey!);
                              isChanged = true;
                            });
                          },
                  ),
                ],
              ),
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
