// field_edit.dart, a view to edit a field's details.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/fields.dart';
import '../../model/structure.dart';
import 'field_format_edit.dart';

// The field edit widget
class FieldEdit extends StatefulWidget {
  Field field;
  final bool isNew;

  FieldEdit({Key? key, required this.field, this.isNew = false})
      : super(key: key);

  @override
  State<FieldEdit> createState() => _FieldEditState();
}

class _FieldEditState extends State<FieldEdit> {
  final _formKey = GlobalKey<FormState>();
  final _dropdownState = GlobalKey<FormFieldState>();
  var cancelNewFlag = false;
  // The original field is only used for field type changes.
  Field? origField;

  Future<bool> updateOnPop() async {
    if (cancelNewFlag) return true;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      var model = Provider.of<Structure>(context, listen: false);
      if (widget.isNew) {
        model.addNewField(widget.field);
      } else if (origField != null) {
        // Used for field type changes.
        model.replaceField(origField!, widget.field);
      } else {
        model.editField(widget.field);
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.field.name + ' Field'),
        actions: widget.isNew
            ? <Widget>[
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      cancelNewFlag = true;
                      Navigator.pop(context, null);
                    }),
              ]
            : <Widget>[
                IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: () {
                    _formKey.currentState!.reset();
                  },
                ),
              ],
      ),
      body: Form(
        key: _formKey,
        onWillPop: updateOnPop,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: ListView(
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(labelText: 'Field Name'),
                initialValue: widget.field.name,
                validator: (String? text) {
                  if (text == null) return null;
                  if (text.isEmpty) return 'Cannot be empty';
                  var badCharMatches = RegExp(r'\W').allMatches(text);
                  if (badCharMatches.isNotEmpty) {
                    var badChars = [
                      for (var match in badCharMatches) match.group(0)
                    ];
                    return 'Illegal characters: "${badChars.join()}"';
                  }
                  var model = Provider.of<Structure>(context, listen: false);
                  if (text != widget.field.name &&
                      model.fieldMap.containsKey(text))
                    return 'Duplicate field name';
                  return null;
                },
                onSaved: (String? text) {
                  if (text != null) widget.field.name = text;
                },
              ),
              DropdownButtonFormField<String>(
                key: _dropdownState,
                decoration: InputDecoration(labelText: 'Field Type'),
                value: widget.field.fieldType,
                items: [
                  for (var type in fieldTypes)
                    DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    )
                ],
                onSaved: (String? newType) {
                  // Changes are made in onChanged.
                },
                onChanged: (String? newType) async {
                  if (newType != null) {
                    if (newType != widget.field.fieldType) {
                      if (model.isFieldInData(widget.field)) {
                        // Do no allow type changes with existing data.
                        // It would cause format errors, especially in rules.
                        await _noTypeChangeDialog();
                        _dropdownState.currentState!
                            .didChange(widget.field.fieldType);
                      } else {
                        if (origField == null) origField = widget.field;
                        widget.field = widget.field.copyToType(newType);
                      }
                    }
                    if (newType == origField?.fieldType) {
                      widget.field = origField!;
                      origField == null;
                    }
                    setState(() {});
                  }
                },
              ),
              if (widget.field.format.isNotEmpty)
                FieldFormatDisplay(
                  fieldType: widget.field.fieldType,
                  initialFormat: widget.field.format,
                  onSaved: (String? value) {
                    if (value != null) widget.field.format = value;
                  },
                ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Default Prefix'),
                initialValue: widget.field.prefix,
                onSaved: (String? value) {
                  if (value != null) widget.field.prefix = value;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Default Suffix'),
                initialValue: widget.field.suffix,
                onSaved: (String? value) {
                  if (value != null) widget.field.suffix = value;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _noTypeChangeDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cannot Change Type'),
          content: const Text(
              'A field with data in leaf nodes cannot have its type changed.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }
}
