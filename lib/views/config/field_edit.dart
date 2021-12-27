// field_edit.dart, a view to edit a field's details.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/fields.dart';
import '../../model/structure.dart';

// The field edit widget
class FieldEdit extends StatefulWidget {
  final Field field;
  final bool isNew;

  FieldEdit({Key? key, required this.field, this.isNew = false})
      : super(key: key);

  @override
  State<FieldEdit> createState() => _FieldEditState();
}

class _FieldEditState extends State<FieldEdit> {
  final _formKey = GlobalKey<FormState>();
  var cancelNewFlag = false;

  Future<bool> updateOnPop() async {
    if (cancelNewFlag) return true;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      var model = Provider.of<Structure>(context, listen: false);
      if (widget.isNew) {
        model.addNewField(widget.field);
      } else {
        model.editField(widget.field);
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
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
                decoration: InputDecoration(labelText: 'Field Type'),
                value: widget.field.fieldType,
                items: [
                  for (var type in fieldTypes.keys)
                    DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    )
                ],
                onSaved: (String? value) {},
                onChanged: (String? value) {
                  setState(() {});
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
}
