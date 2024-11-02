// field_edit.dart, a view to edit a field's details.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'field_format_edit.dart';
import '../common_dialogs.dart' as common_dialogs;
import '../setting_edit.dart' show BoolFormField;
import '../../model/fields.dart';
import '../../model/structure.dart';

/// The field edit view with a form for all field paramters.
///
/// Called from the [FieldConfig] view (part of the [ConfigView]).
class FieldEdit extends StatefulWidget {
  final Field field;
  final bool isNew;
  final int? newPos;

  const FieldEdit({
    super.key,
    required this.field,
    this.isNew = false,
    this.newPos,
  });

  @override
  State<FieldEdit> createState() => _FieldEditState();
}

class _FieldEditState extends State<FieldEdit> {
  /// A copy of the original field to contain the changes.
  late Field _editedField;

  var _isFieldTypeChanged = false;

  late bool _hasSeparator;

  final _formKey = GlobalKey<FormState>();
  final _fieldNameKey = GlobalKey<FormFieldState<String>>();
  final _dropdownTypeKey = GlobalKey<FormFieldState<String>>();
  final _fieldFormatKey = GlobalKey<FormFieldState<String>>();
  final _fieldInitBoolKey = GlobalKey<FormFieldState<bool>>();
  final _fieldInitStrKey = GlobalKey<FormFieldState<String>>();
  final _fieldPrefixKey = GlobalKey<FormFieldState<String>>();
  final _fieldSuffixKey = GlobalKey<FormFieldState<String>>();
  final _fieldAllowMultipleKey = GlobalKey<FormFieldState<bool>>();
  final _fieldSeparatorKey = GlobalKey<FormFieldState<bool>>();

  @override
  void initState() {
    super.initState();
    _editedField = Field.copy(widget.field);
    _hasSeparator = _editedField.allowMultiples;
  }

  /// Prepare to close by validating and updating.
  ///
  /// Returns true if it's ok to close.
  Future<bool> _handleClose() async {
    var removeChoices = false;
    var removeMultiples = false;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final model = Provider.of<Structure>(context, listen: false);
      if (widget.isNew) {
        final doAddOutput = await common_dialogs.okCancelDialog(
          context: context,
          title: 'Output Fields',
          label: 'Add an output line with the new field?',
          trueButtonText: 'YES',
          falseButtonText: 'NO',
        );
        model.addNewField(_editedField,
            newPos: widget.newPos, doAddOutput: doAddOutput ?? false);
        return true;
      }
      if (_isFieldTypeChanged) {
        final numErrors = model.badFieldCount(_editedField);
        if (numErrors > 0) {
          final doKeep = await common_dialogs.okCancelDialog(
            context: context,
            title: 'Change Type for Data',
            label:
                'Field type change will cause $numErrors nodes to lose data.',
            trueButtonText: 'KEEP CHANGE',
            falseButtonText: 'REVERT CHANGE',
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
          final numErrors = model.badFieldCount(_editedField);
          if (numErrors > 0) {
            if (!mounted) return false;
            final doKeep = await common_dialogs.okCancelDialog(
              context: context,
              title: 'Choice Data Mismatch',
              label: 'Choice field changes will cause $numErrors '
                  'nodes to lose data.',
              trueButtonText: 'KEEP CHANGES',
              falseButtonText: 'REVERT CHANGES',
            );
            if (doKeep != null && doKeep) {
              removeChoices = true;
            } else {
              _editedField.format = widget.field.format;
            }
          }
        }
        if (widget.field.allowMultiples &&
            !_editedField.allowMultiples &&
            model.fieldHasMultiples(widget.field)) {
          if (!mounted) return false;
          final doKeep = await common_dialogs.okCancelDialog(
            context: context,
            title: 'Disabling Multiple Entries',
            label: 'Some leaf nodes have multiple data entries that '
                'will be discarded.',
            trueButtonText: 'KEEP CHANGE',
            falseButtonText: 'REVERT CHANGE',
          );
          if (doKeep != null && doKeep) {
            removeMultiples = true;
          } else {
            _editedField.allowMultiples = true;
          }
        }
        if (_editedField != widget.field) {
          model.editField(
            widget.field,
            _editedField,
            removeChoices: removeChoices,
            removeMultiples: removeMultiples,
          );
        }
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<Structure>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text('${_editedField.name} Field'),
        leading: IconButton(
          icon: const Icon(Icons.check_circle),
          tooltip: 'Save current updates and close',
          onPressed: () async {
            if (await _handleClose() && context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: <Widget>[
          if (!widget.isNew)
            // Restore control for non-new fields.
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Restore field settings',
              onPressed: () {
                if (_isFieldTypeChanged) {
                  _editedField = Field.copy(widget.field);
                  _isFieldTypeChanged = false;
                }
                _formKey.currentState!.reset();
                // It's unclear why the format needs to be set separately
                // to avoid needing two reset presses.
                if (_fieldFormatKey.currentState != null) {
                  _fieldFormatKey.currentState!.didChange(_editedField.format);
                }
                setState(() {});
              },
            ),
          // Close control for new and non-new fields.
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel this field operation',
            onPressed: () {
              Navigator.pop(context, null);
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          if (!didPop && await _handleClose() && context.mounted) {
            // Pop manually (bypass canPop) if update is complete.
            Navigator.of(context).pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Center(
            child: SizedBox(
              width: 350.0,
              child: ListView(
                children: <Widget>[
                  TextFormField(
                    key: _fieldNameKey,
                    decoration: const InputDecoration(labelText: 'Field Name'),
                    autofocus: widget.isNew,
                    initialValue: _editedField.name,
                    validator: (String? text) {
                      if (text == null) return null;
                      if (text.isEmpty) return 'Cannot be empty';
                      final badCharMatches = RegExp(r'\W').allMatches(text);
                      if (badCharMatches.isNotEmpty) {
                        final badChars = [
                          for (var match in badCharMatches) match.group(0)
                        ];
                        return 'Illegal characters: "${badChars.join()}"';
                      }
                      final model =
                          Provider.of<Structure>(context, listen: false);
                      if (text != widget.field.name &&
                          model.fieldMap.containsKey(text)) {
                        return 'Duplicate field name';
                      }
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
                    decoration: const InputDecoration(labelText: 'Field Type'),
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
                      if (newType != null &&
                          newType != _editedField.fieldType) {
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
                      initialValue:
                          _editedField.initValue == 'now' ? true : false,
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
                      decoration:
                          const InputDecoration(labelText: 'Initial Value'),
                      initialValue: _editedField.initValue,
                      validator: (String? value) {
                        // Update field format before validating the init value.
                        if (_editedField.format.isNotEmpty) {
                          var value = _fieldFormatKey.currentState!.value;
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
                    key: _fieldPrefixKey,
                    decoration:
                        const InputDecoration(labelText: 'Default Prefix'),
                    initialValue: _editedField.prefix,
                    onSaved: (String? value) {
                      if (value != null) {
                        _editedField.prefix = value;
                      }
                    },
                  ),
                  TextFormField(
                    key: _fieldSuffixKey,
                    decoration:
                        const InputDecoration(labelText: 'Default Suffix'),
                    initialValue: _editedField.suffix,
                    onSaved: (String? value) {
                      if (value != null) {
                        _editedField.suffix = value;
                      }
                    },
                  ),
                  BoolFormField(
                    key: _fieldAllowMultipleKey,
                    initialValue: _editedField.allowMultiples,
                    heading: 'Allow Multiple Entries',
                    onSaved: (bool? value) async {
                      if (value != null) {
                        _editedField.allowMultiples = value;
                      }
                    },
                    onChange: (bool? value) async {
                      if (value != null) {
                        if (value == true) {
                          final sameRuleFields =
                              model.multipleFieldsInSameLine(_editedField);
                          if (sameRuleFields.isNotEmpty) {
                            final fields =
                                sameRuleFields.map((f) => f.name).join(' & ');
                            final fieldtext = sameRuleFields.length > 1
                                ? 'fields.'
                                : 'field.';
                            await common_dialogs.okDialog(
                              context: context,
                              title: 'Multiple Fields in Lines',
                              label: 'This field cannot be set to multiple '
                                  'entries, since it is in the same rule or '
                                  'output line as the $fields $fieldtext',
                            );
                            setState(() {
                              _fieldAllowMultipleKey.currentState!
                                  .didChange(false);
                              _hasSeparator = false;
                            });
                            return;
                          }
                        }
                        setState(() {
                          _hasSeparator = value;
                        });
                      }
                    },
                  ),
                  if (_hasSeparator)
                    TextFormField(
                      key: _fieldSeparatorKey,
                      decoration:
                          const InputDecoration(labelText: 'Field Separator'),
                      initialValue:
                          _editedField.separator.replaceAll('\n', '\\n'),
                      onSaved: (String? value) {
                        if (value != null) {
                          _editedField.separator =
                              value.replaceAll('\\n', '\n');
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A [FormField] for setting the date and time init value to now.
class InitNowBoolFormField extends FormField<bool> {
  InitNowBoolFormField({
    super.initialValue,
    String? heading,
    super.key,
    super.onSaved,
  }) : super(
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
                const Divider(
                  thickness: 3.0,
                ),
              ],
            );
          },
        );
}
