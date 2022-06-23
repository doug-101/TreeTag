// field_edit.dart, a view to edit a field's details.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'field_format_edit.dart';
import '../common_dialogs.dart' as commonDialogs;
import '../../model/fields.dart';
import '../../model/structure.dart';

/// The field edit view with a form for all field paramters.
///
/// Called from the [FieldConfig] view (part of the [ConfigView]).
class FieldEdit extends StatefulWidget {
  Field field;
  final bool isNew;
  final int? newPos;

  FieldEdit({Key? key, required this.field, this.isNew = false, this.newPos})
      : super(key: key);

  @override
  State<FieldEdit> createState() => _FieldEditState();
}

class _FieldEditState extends State<FieldEdit> {
  /// A copy of the original field to contain the changes.
  late Field _editedField;

  bool _isFieldTypeChanged = false;

  /// A flag showing that the view was closed while editing a new field.
  var _cancelNewFlag = false;

  final _formKey = GlobalKey<FormState>();
  final _dropdownTypeKey = GlobalKey<FormFieldState<String>>();
  final _fieldFormatKey = GlobalKey<FormFieldState<String>>();
  final _fieldInitBoolKey = GlobalKey<FormFieldState<bool>>();
  final _fieldInitStrKey = GlobalKey<FormFieldState<String>>();

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
        model.addNewField(_editedField, newPos: widget.newPos);
        return true;
      }
      if (_isFieldTypeChanged) {
        var numErrors = model.badFieldCount(_editedField);
        if (numErrors > 0) {
          var doKeep = await commonDialogs.okCancelDialog(
            context: context,
            title: 'Change Type for Data',
            label:
                'Field type change will cause $numErrors nodes to lose data.',
            trueButtonText: 'KEEP CHANGES',
            falseButtonText: 'DISCARD CHANGES',
          );
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
      // Used for other changes.
      if (_editedField != widget.field) {
        if (_editedField is ChoiceField) {
          var numErrors = model.badFieldCount(_editedField);
          if (numErrors > 0) {
            var doKeep = await commonDialogs.okCancelDialog(
              context: context,
              title: 'Choice Data Mismatch',
              label: 'Choice field changes will cause $numErrors '
                  'nodes to lose data.',
              trueButtonText: 'KEEP CHANGES',
              falseButtonText: 'DISCARD CHANGES',
            );
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
                // Close control for new fields only.
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _cancelNewFlag = true;
                    Navigator.pop(context, null);
                  },
                ),
              ]
            : <Widget>[
                // Restore control for non-new fields.
                IconButton(
                  icon: const Icon(Icons.restore),
                  onPressed: () {
                    if (_isFieldTypeChanged) {
                      _editedField = Field.copy(widget.field);
                      _isFieldTypeChanged = false;
                    }
                    _formKey.currentState!.reset();
                    // It's unclear why the format needs to be set separately
                    // to avoid needing two reset presses.
                    if (_fieldFormatKey.currentState != null) {
                      _fieldFormatKey.currentState!
                          .didChange(_editedField.format);
                    }
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
                autofocus: widget.isNew,
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
                key: _dropdownTypeKey,
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
                      _isFieldTypeChanged = false;
                    } else {
                      _editedField = _editedField.copyToType(newType);
                      _isFieldTypeChanged = true;
                      if (_fieldFormatKey.currentState != null) {
                        _fieldFormatKey.currentState!
                            .didChange(_editedField.format);
                      }
                      if (_editedField.initValue.isNotEmpty) {
                        _editedField.initValue = '';
                        if (_fieldInitBoolKey.currentState != null) {
                          _fieldInitBoolKey.currentState!.didChange(false);
                        }
                        if (_fieldInitStrKey.currentState != null) {
                          _fieldInitStrKey.currentState!.didChange('');
                        }
                      }
                    }
                  }
                  setState(() {});
                },
              ),
              if (_editedField.format.isNotEmpty)
                // Defined in field_format_edit.dart.
                FieldFormatDisplay(
                  key: _fieldFormatKey,
                  fieldType: _editedField.fieldType,
                  initialFormat: _editedField.format,
                  onSaved: (String? value) async {
                    if (value != null && value != _editedField.format) {
                      _editedField.format = value;
                    }
                  },
                ),
              if (_editedField is DateField || _editedField is TimeField)
                // Defined below.
                InitNowBoolFormField(
                  key: _fieldInitBoolKey,
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
                  key: _fieldInitStrKey,
                  decoration: InputDecoration(labelText: 'Initial Value'),
                  initialValue: _editedField.initValue,
                  validator: (String? value) {
                    // Update field format before validating the init value.
                    if (_editedField.format.isNotEmpty) {
                      var value = _fieldFormatKey.currentState!.value!;
                      if (value != null) _editedField.format = value;
                    }
                    return _editedField.validateMessage(value);
                  },
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
}

/// A [FormField] for setting the date and time init value to now.
class InitNowBoolFormField extends FormField<bool> {
  InitNowBoolFormField({
    bool? initialValue,
    String? heading,
    Key? key,
    FormFieldSetter<bool>? onSaved,
  }) : super(
          onSaved: onSaved,
          initialValue: initialValue,
          key: key,
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
