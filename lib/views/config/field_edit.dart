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
  late Field _editedField;
  bool _isFieldTypeChanged = false;
  var _cancelNewFlag = false;
  final _formKey = GlobalKey<FormState>();
  final _dropdownState = GlobalKey<FormFieldState>();

  @override
  void initState() {
    super.initState();
    _editedField = Field.copy(widget.field);
  }

  Future<bool> updateOnPop() async {
    if (_cancelNewFlag) return true;
    var removeChoices = false;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      var model = Provider.of<Structure>(context, listen: false);
      if (widget.isNew) {
        model.addNewField(widget.field);
        return true;
      }
      if (_isFieldTypeChanged) {
        var numErrors = model.badFieldCount(_editedField);
        if (numErrors > 0) {
          var doKeep = await _keepTypeChangeDialog(numErrors: numErrors);
          if (doKeep != null && !doKeep) {
            _editedField = _editedField.copyToType(widget.field.fieldType);
            _isFieldTypeChanged = false;
          }
        }
        if (_isFieldTypeChanged) {
          model.replaceField(widget.field, _editedField);
          return true;
        }
      }
      if (_editedField != widget.field) {
        // Used for other changes.
        if (_editedField is ChoiceField) {
          var numErrors = model.badFieldCount(_editedField);
          if (numErrors > 0) {
            var doKeep = await _keepChoiceErrorDialog(numErrors: numErrors);
            if (doKeep != null && doKeep) {
              removeChoices = true;
            } else {
              _editedField.format = widget.field.format;
            }
          }
        }
        if (_editedField != widget.field) {
          model.editField(widget.field, _editedField,
              removeChoices: removeChoices);
        }
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
        title: Text(_editedField.name + ' Field'),
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
                    if (_isFieldTypeChanged) {
                      _editedField = Field.copy(widget.field);
                      _isFieldTypeChanged = false;
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
                initialValue: _editedField.name,
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
                  if (text != null) {
                    _editedField.name = text;
                  }
                },
              ),
              DropdownButtonFormField<String>(
                key: _dropdownState,
                decoration: InputDecoration(labelText: 'Field Type'),
                value: _editedField.fieldType,
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
                onChanged: (String? newType) {
                  if (newType != null && newType != _editedField.fieldType) {
                    if (newType == widget.field.fieldType) {
                      _editedField = Field.copy(widget.field);
                      // TODO - any resets required?
                      _isFieldTypeChanged = false;
                    } else {
                      _editedField = _editedField.copyToType(newType);
                      _isFieldTypeChanged = true;
                    }
                  }
                  setState(() {});
                },
              ),
              if (_editedField.format.isNotEmpty)
                FieldFormatDisplay(
                  fieldType: _editedField.fieldType,
                  initialFormat: _editedField.format,
                  onSaved: (String? value) async {
                    if (value != null && value != _editedField.format) {
                      _editedField.format = value;
                    }
                  },
                ),
              if (_editedField is DateField || _editedField is TimeField)
                InitNowBoolFormField(
                  initialValue: _editedField.initValue == 'now' ? true : false,
                  heading: _editedField is DateField
                      ? 'Initial Value to Current Date'
                      : 'Initial Value to Current Time',
                  onSaved: (bool? value) {
                    if (value != null) {
                      _editedField.initValue = value ? 'now' : '';
                    }
                  },
                )
              else
                // Initial value for other fields.
                TextFormField(
                  decoration: InputDecoration(labelText: 'Initial Value'),
                  initialValue: widget.field.initValue,
                  validator: _editedField.validateMessage,
                  onSaved: (String? value) {
                    if (value != null) {
                      _editedField.initValue = value;
                    }
                  },
                ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Default Prefix'),
                initialValue: _editedField.prefix,
                onSaved: (String? value) {
                  if (value != null) {
                    _editedField.prefix = value;
                  }
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Default Suffix'),
                initialValue: _editedField.suffix,
                onSaved: (String? value) {
                  if (value != null) {
                    _editedField.suffix = value;
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
