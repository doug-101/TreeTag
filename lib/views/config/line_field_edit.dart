// line_field_edit.dart, a view to customize a field's details in a line.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import '../../model/fields.dart';
import '../../model/structure.dart';
import 'field_format_edit.dart';

// The field edit view with a form for only format, prefix and suffix.
//
// Called from [LineEdit] views for fields in rules and output lines.
class LineFieldEdit extends StatefulWidget {
  final Field field;

  // Original values stored to determine whether there are changes.
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

  // Keys are needed to allow a reset back to the alt format's parent field.
  final _fieldFormatKey = GlobalKey<FormFieldState<String>>();
  final _fieldPrefixKey = GlobalKey<FormFieldState<String>>();
  final _fieldSuffixKey = GlobalKey<FormFieldState<String>>();

  Future<bool> updateOnPop() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final isChanged = widget.origPrefix != widget.field.prefix ||
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
          // Reset back to the alt format's parent field.
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restore settings',
            onPressed: () {
              final parentField = widget.field.altFormatParent;
              if (parentField != null) {
                if (parentField.format.isNotEmpty) {
                  _fieldFormatKey.currentState!.didChange(parentField.format);
                }
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
              // Check for a field format; exclude Choice since the data
              // cannot change.
              if (widget.field.format.isNotEmpty &&
                  widget.field is! ChoiceField)
                // Defined in field_format_edit.dart.
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
