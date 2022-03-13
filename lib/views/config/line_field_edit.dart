// line_field_edit.dart, a view to customize a field's details in a line.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import '../../model/fields.dart';
import '../../model/structure.dart';
import 'field_format_edit.dart';

// The line field edit widget
class LineFieldEdit extends StatefulWidget {
  final Field field;
  late final String origFormat;
  late final String origPrefix;
  late final String origSuffix;

  LineFieldEdit({Key? key, required this.field}) : super(key: key) {
    origFormat = field.format;
    origPrefix = field.prefix;
    origSuffix = field.suffix;
  }

  @override
  State<LineFieldEdit> createState() => _LineFieldEditState();
}

class _LineFieldEditState extends State<LineFieldEdit> {
  final _formKey = GlobalKey<FormState>();
  final _fieldFormatKey = GlobalKey<FormFieldState<String>>();
  final _fieldPrefixKey = GlobalKey<FormFieldState<String>>();
  final _fieldSuffixKey = GlobalKey<FormFieldState<String>>();

  Future<bool> updateOnPop() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      var isChanged = widget.origPrefix != widget.field.prefix ||
          widget.origSuffix != widget.field.suffix ||
          widget.origFormat != widget.field.format;
      Navigator.pop(context, isChanged);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.field.name + ' Line Field'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () {
              var parentField = widget.field.altFormatParent;
              if (parentField != null) {
                if (parentField.format.isNotEmpty)
                  _fieldFormatKey.currentState!.didChange(parentField.format);
                _fieldPrefixKey.currentState!.didChange(parentField.prefix);
                _fieldSuffixKey.currentState!.didChange(parentField.suffix);
              } else {
                _formKey.currentState!.reset();
              }
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
              if (widget.field.format.isNotEmpty)
                FieldFormatDisplay(
                  key: _fieldFormatKey,
                  fieldType: widget.field.fieldType,
                  initialFormat: widget.field.format,
                  onSaved: (String? value) {
                    if (value != null) widget.field.format = value;
                  },
                ),
              TextFormField(
                key: _fieldPrefixKey,
                decoration: InputDecoration(labelText: 'Prefix'),
                initialValue: widget.field.prefix,
                onSaved: (String? value) {
                  if (value != null) widget.field.prefix = value;
                },
              ),
              TextFormField(
                key: _fieldSuffixKey,
                decoration: InputDecoration(labelText: 'Suffix'),
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
