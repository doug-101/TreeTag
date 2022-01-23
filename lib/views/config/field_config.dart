// field_config.dart, a view to edit the field list configuration.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/fields.dart';
import '../../model/structure.dart';
import 'field_edit.dart';

// The field config widget.
class FieldConfig extends StatefulWidget {
  @override
  State<FieldConfig> createState() => _FieldConfigState();
}

class _FieldConfigState extends State<FieldConfig> {
  Field? selectedField;

  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    var fieldList = List.of(model.fieldMap.values);
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () async {
                var newField = Field.createField(name: '');
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        FieldEdit(field: newField, isNew: true),
                  ),
                );
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: selectedField == null
                  ? null
                  : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                FieldEdit(field: selectedField!)),
                      );
                      setState(() {});
                    },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: (selectedField == null || fieldList.length < 2)
                  ? null
                  : () async {
                      var errorText = <String>[];
                      if (model.isFieldInTitle(selectedField!))
                        errorText.add('in node titles');
                      if (model.isFieldInOutput(selectedField!))
                        errorText.add('in node outputs');
                      if (model.isFieldInGroup(selectedField!))
                        errorText.add('in node group rules');
                      if (errorText.length > 1) {
                        errorText.last = ' and ' + errorText.last;
                        if (errorText.length == 3) {
                          errorText[0] = errorText[0] + ', ';
                        }
                      }
                      if (errorText.isNotEmpty) {
                        var ans = await confirmDeleteDialog(errorText.join());
                        if (ans == null || !ans) return;
                      }
                      setState(() {
                        model.deleteField(selectedField!);
                        selectedField = null;
                      });
                    },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_circle_up),
              onPressed: (selectedField == null ||
                      fieldList.indexOf(selectedField!) == 0)
                  ? null
                  : () {
                      setState(() {
                        model.moveField(selectedField!);
                      });
                    },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_circle_down),
              onPressed: (selectedField == null ||
                      fieldList.indexOf(selectedField!) == fieldList.length - 1)
                  ? null
                  : () {
                      setState(() {
                        model.moveField(selectedField!, up: false);
                      });
                    },
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: ListView(
              children: <Widget>[
                for (var field in model.fieldMap.values)
                  Card(
                    color: field == selectedField
                        ? Theme.of(context).highlightColor
                        : null,
                    child: ListTile(
                      title: Text(field.name),
                      subtitle: Text(field.fieldType),
                      onTap: () {
                        setState(() {
                          if (field != selectedField) {
                            selectedField = field;
                          } else {
                            selectedField = null;
                          }
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> confirmDeleteDialog(String errorText) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete?'),
          content: Text('This field is used $errorText. Continue?'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context, true),
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        );
      },
    );
  }
}