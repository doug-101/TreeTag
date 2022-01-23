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
  bool _isChanged = false;
  var _cancelNewFlag = false;
  // The original field is only used for field type changes.
  Field? _origField;
  // The original field format is only to recover from Choice field errors.
  String? _origFormat;

  Future<bool> updateOnPop() async {
    if (_cancelNewFlag) return true;
    var removeChoices = false;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      var model = Provider.of<Structure>(context, listen: false);
      if (widget.isNew) {
        model.addNewField(widget.field);
        _isChanged = false;
      } else if (_origField != null) {
        // Used for field type changes.
        var numErrors = model.badFieldCount(widget.field);
        if (numErrors > 0) {
          var doKeep = await _keepTypeChangeDialog(numErrors: numErrors);
          if (doKeep != null && !doKeep) {
            _isChanged = widget.field.name != _origField!.name ||
                widget.field.format != _origField!.format ||
                widget.field.initValue != _origField!.initValue ||
                widget.field.prefix != _origField!.prefix ||
                widget.field.suffix != _origField!.suffix;
            widget.field = _origField!;
            _origField == null;
          }
        }
        if (_origField != null) {
          model.replaceField(_origField!, widget.field);
          _isChanged = false;
        }
      }
      if (_isChanged) {
        // Used for other changes.
        if (widget.field is ChoiceField) {
          var numErrors = model.badFieldCount(widget.field);
          if (numErrors > 0) {
            var doKeep = await _keepChoiceErrorDialog(numErrors: numErrors);
            if (doKeep != null && doKeep) {
              removeChoices = true;
            } else {
              widget.field.format = _origFormat!;
            }
          }
        }
        model.editField(widget.field, removeChoices: removeChoices);
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
                      _cancelNewFlag = true;
                      Navigator.pop(context, null);
                    }),
              ]
            : <Widget>[
                IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: () {
                    if (_origField != null) {
                      widget.field = _origField!;
                      _origField == null;
                    }
                    _formKey.currentState!.reset();
                    setState(() {});
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
                  if (text != null && text != widget.field.name) {
                    _isChanged = true;
                    widget.field.name = text;
                  }
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
                  if (_origField != null) _isChanged = true;
                },
                onChanged: (String? newType) {
                  if (newType != null && newType != widget.field.fieldType) {
                    if (newType != _origField?.fieldType) {
                      if (_origField == null) _origField = widget.field;
                      widget.field = widget.field.copyToType(newType);
                    } else {
                      widget.field = _origField!;
                      _origField == null;
                    }
                  }
                  setState(() {});
                },
              ),
              if (widget.field.format.isNotEmpty)
                FieldFormatDisplay(
                  fieldType: widget.field.fieldType,
                  initialFormat: widget.field.format,
                  onSaved: (String? value) async {
                    if (value != null && value != widget.field.format) {
                      _isChanged = true;
                      _origFormat = widget.field.format;
                      widget.field.format = value;
                    }
                  },
                ),
              if (widget.field is DateField || widget.field is TimeField)
                InitNowBoolFormField(
                  initialValue: widget.field.initValue == 'now' ? true : false,
                  heading: widget.field is DateField
                      ? 'Initial Value to Current Date'
                      : 'Initial Value to Current Time',
                  onSaved: (bool? value) {
                    if (value != null &&
                        widget.field.initValue != (value ? 'now' : '')) {
                      _isChanged = true;
                      widget.field.initValue = value ? 'now' : '';
                    }
                  },
                )
              else
                // Initial value for other fields.
                TextFormField(
                  decoration: InputDecoration(labelText: 'Initial Value'),
                  initialValue: widget.field.initValue,
                  validator: widget.field.validateMessage,
                  onSaved: (String? value) {
                    if (value != null && value != widget.field.initValue) {
                      _isChanged = true;
                      widget.field.initValue = value;
                    }
                  },
                ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Default Prefix'),
                initialValue: widget.field.prefix,
                onSaved: (String? value) {
                  if (value != null && value != widget.field.prefix) {
                    _isChanged = true;
                    widget.field.prefix = value;
                  }
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Default Suffix'),
                initialValue: widget.field.suffix,
                onSaved: (String? value) {
                  if (value != null && value != widget.field.suffix) {
                    _isChanged = true;
                    widget.field.suffix = value;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _keepTypeChangeDialog({required int numErrors}) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Type for Data'),
          content: Text(
              'Field type change will cause $numErrors nodes to lose data.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Keep changes'),
              onPressed: () => Navigator.pop(context, true),
            ),
            TextButton(
              child: const Text('Discard changes'),
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _keepChoiceErrorDialog({required int numErrors}) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choice Data Mismatch'),
          content: Text(
              'Choice field changes will cause $numErrors nodes to lose data.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Keep changes'),
              onPressed: () => Navigator.pop(context, true),
            ),
            TextButton(
              child: const Text('Discard changes'),
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        );
      },
    );
  }
}

class InitNowBoolFormField extends FormField<bool> {
  InitNowBoolFormField({
    bool? initialValue,
    String? heading,
    FormFieldSetter<bool>? onSaved,
  }) : super(
          onSaved: onSaved,
          initialValue: initialValue,
          builder: (FormFieldState<bool> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  onTap: () {
                    state.didChange(!state.value!);
                  },
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(heading ?? 'Initial Value to Now'),
                      ),
                      Switch(
                        value: state.value!,
                        onChanged: (bool value) {
                          state.didChange(!state.value!);
                        },
                      ),
                    ],
                  ),
                ),
                Divider(
                  thickness: 3.0,
                ),
              ],
            );
          },
        );
}
