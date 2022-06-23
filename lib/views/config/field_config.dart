// field_config.dart, a view to edit the field list configuration.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import '../common_dialogs.dart' as commonDialogs;
import 'package:provider/provider.dart';
import '../../model/fields.dart';
import '../../model/structure.dart';
import 'field_edit.dart';

/// The field config widget.
///
/// Lists all of the fields with edit controls.
/// One of the tabbed items on the [ConfigView].
/// Uses the [FieldEdit] view on new fields and fields to be edited.
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
            // Add a new field.
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () async {
                var newField = Field.createField(name: '');
                int? newPos;
                if (selectedField != null) {
                  newPos = fieldList.indexOf(selectedField!);
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        FieldEdit(field: newField, isNew: true, newPos: newPos),
                  ),
                );
                setState(() {});
              },
            ),
            // Edit the selected field.
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
            // Delete the selected field.
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
                        var ans = await commonDialogs.okCancelDialog(
                          context: context,
                          title: 'Confirm Delete',
                          label: 'This field is used ${errorText.join()}. '
                              'Continue?',
                        );
                        if (ans == null || !ans) return;
                      }
                      setState(() {
                        model.deleteField(selectedField!);
                        selectedField = null;
                      });
                    },
            ),
            // Move the selected field up.
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
            // Move the selected field down.
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
}
