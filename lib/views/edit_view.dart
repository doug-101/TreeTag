// edit_view.dart, a view to edit data for an existing or a new node.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'common_dialogs.dart' as commonDialogs;
import '../model/field_format_tools.dart';
import '../model/fields.dart';
import '../model/nodes.dart';
import '../model/structure.dart';

enum EditMode { normal, newNode, nodeChildren }

/// An edit view for node data.
///
/// Called from new or edit operations in a [FrameView].
/// Set [editMode] to handle updates properly (new nodes or multiple children).
class EditView extends StatefulWidget {
  final LeafNode node;
  final EditMode editMode;

  EditView({Key? key, required this.node, this.editMode = EditMode.normal})
      : super(key: key);

  @override
  State<EditView> createState() => _EditViewState();
}

class _EditViewState extends State<EditView> {
  final _formKey = GlobalKey<FormState>();
  var _isChanged = false;
  // The [nodeData] is copied to allow undo creation before the edit is saved.
  late final Map<String, String> nodeData;

  void initState() {
    super.initState();
    nodeData = Map.of(widget.node.data);
  }

  Future<bool> updateOnPop() async {
    if (_formKey.currentState!.validate()) {
      // Allow user to discard an unchanged new node.
      if (!_isChanged && widget.editMode == EditMode.newNode) {
        var toBeSaved = await commonDialogs.okCancelDialog(
          context: context,
          title: 'Save Unchanged',
          label: 'Save unmodified new node?',
          trueButtonText: 'SAVE',
          falseButtonText: 'DISCARD',
        );
        if (toBeSaved != null && !toBeSaved) {
          widget.node.modelRef.deleteNode(widget.node, withUndo: false);
          return true;
        }
      }
      // Handle all updates.
      _formKey.currentState!.save();
      if (_isChanged && widget.editMode == EditMode.nodeChildren) {
        widget.node.modelRef.editChildData(nodeData);
      } else if (_isChanged || widget.editMode == EditMode.newNode) {
        widget.node.modelRef.editNodeData(
          widget.node,
          nodeData,
          newNode: widget.editMode == EditMode.newNode,
        );
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    var windowTitle = widget.node.title;
    if (windowTitle.contains('\u0000')) windowTitle = '[title varies]';
    return Scaffold(
      appBar: AppBar(
        title: Text(windowTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () {
              _formKey.currentState!.reset();
              _isChanged = false;
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        onWillPop: updateOnPop,
        onChanged: () {
          _isChanged = true;
        },
        // Use scroll view and column rather than a listviw to avoid items
        // losing their data when scrolled out of view then rebuilt.
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: <Widget>[
                for (var field in widget.node.modelRef.fieldMap.values)
                  _fieldEditor(widget.node, field),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Return the proper field editor based on field type.
  Widget _fieldEditor(LeafNode node, Field field) {
    var labelString = field.name;
    String? initString = node.data[field.name];
    if (widget.editMode == EditMode.nodeChildren && initString == '\u0000') {
      labelString = '$labelString [varies]';
      initString = null;
    }
    if (field is LongTextField) {
      return TextFormField(
        decoration: InputDecoration(labelText: labelString),
        minLines: 4,
        maxLines: 12,
        initialValue: initString ?? '',
        validator: field.validateMessage,
        onSaved: (String? value) {
          if (value != null && value.isNotEmpty) {
            nodeData[field.name] = value;
          } else if (widget.editMode == EditMode.nodeChildren &&
              node.data[field.name] == '\u0000') {
            nodeData[field.name] = '\u0000';
          } else {
            nodeData.remove(field.name);
          }
        },
      );
    }
    if (field is ChoiceField) {
      return DropdownButtonFormField<String>(
        items: [
          for (var str in splitChoiceFormat(field.format))
            DropdownMenuItem<String>(
              value: str,
              child: Text(str.isNotEmpty ? str : '[Empty Value]'),
            )
        ],
        decoration: InputDecoration(labelText: labelString),
        // Null value gives a blank.
        value: initString,
        onChanged: (String? value) {
          setState(() {});
        },
        onSaved: (String? value) {
          if (value != null) {
            if (value.isNotEmpty) {
              nodeData[field.name] = value;
            } else if (widget.editMode == EditMode.nodeChildren &&
                node.data[field.name] == '\u0000') {
              nodeData[field.name] = '\u0000';
            } else {
              nodeData.remove(field.name);
            }
          }
        },
      );
    }
    if (field is AutoChoiceField) {
      return AutoChoiceForm(
        label: labelString,
        initialValue: initString ?? '',
        initialOptions: field.options,
        onSaved: (String? value) {
          if (value != null && value.isNotEmpty) {
            nodeData[field.name] = value;
            field.options.add(value);
          } else if (widget.editMode == EditMode.nodeChildren &&
              node.data[field.name] == '\u0000') {
            nodeData[field.name] = '\u0000';
          } else {
            nodeData.remove(field.name);
          }
        },
      );
    }
    if (field is NumberField) {
      return TextFormField(
        decoration: InputDecoration(labelText: labelString),
        initialValue: initString ?? '',
        validator: field.validateMessage,
        onSaved: (String? value) {
          if (value != null && value.isNotEmpty) {
            nodeData[field.name] = num.parse(value).toString();
          } else if (widget.editMode == EditMode.nodeChildren &&
              node.data[field.name] == '\u0000') {
            nodeData[field.name] = '\u0000';
          } else {
            nodeData.remove(field.name);
          }
        },
      );
    }
    if (field is DateField) {
      var storedDateFormat = DateFormat('yyyy-MM-dd');
      return DateFormField(
        fieldFormat: field.format,
        initialValue:
            initString != null ? storedDateFormat.parse(initString) : null,
        heading: labelString,
        onSaved: (DateTime? value) async {
          if (value != null) {
            nodeData[field.name] = storedDateFormat.format(value);
          } else {
            nodeData.remove(field.name);
          }
        },
      );
    }
    if (field is TimeField) {
      var storedTimeFormat = DateFormat('HH:mm:ss.S');
      return TimeFormField(
        fieldFormat: field.format,
        initialValue:
            initString != null ? storedTimeFormat.parse(initString) : null,
        heading: labelString,
        onSaved: (DateTime? value) {
          if (value != null) {
            nodeData[field.name] = storedTimeFormat.format(value);
          } else {
            nodeData.remove(field.name);
          }
        },
      );
    }
    // Default return for a regular TextField
    return TextFormField(
      decoration: InputDecoration(labelText: labelString),
      initialValue: initString ?? '',
      validator: field.validateMessage,
      onSaved: (String? value) {
        if (value != null && value.isNotEmpty) {
          nodeData[field.name] = value;
        } else if (widget.editMode == EditMode.nodeChildren &&
            node.data[field.name] == '\u0000') {
          nodeData[field.name] = '\u0000';
        } else {
          nodeData.remove(field.name);
        }
      },
    );
  }
}

/// An editor for an [AutoChoiceField].
///
/// Combines a [TextField] with a popup menu.
class AutoChoiceForm extends FormField<String> {
  AutoChoiceForm({
    String? label,
    String? initialValue,
    required Set<String> initialOptions,
    FormFieldSetter<String>? onSaved,
  }) : super(
          onSaved: onSaved,
          initialValue: initialValue,
          builder: (FormFieldState<String> origState) {
            final state = origState as _AutoChoiceFormState;
            return Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: label ?? 'AutoChoice Field',
                          border: InputBorder.none,
                        ),
                        controller: state._textController,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.arrow_drop_down),
                      onSelected: (String value) {
                        state._textController.text = value;
                      },
                      itemBuilder: (BuildContext context) {
                        var options = List.of(initialOptions);
                        var newText = state._textController.text;
                        if (newText.isNotEmpty &&
                            !initialOptions.contains(newText)) {
                          options.add(newText);
                        }
                        options.sort();
                        return [
                          for (var s in options)
                            PopupMenuItem(child: Text(s), value: s)
                        ];
                      },
                    ),
                  ],
                ),
                Divider(thickness: 3.0),
              ],
            );
          },
        );

  @override
  _AutoChoiceFormState createState() => _AutoChoiceFormState();
}

class _AutoChoiceFormState extends FormFieldState<String> {
  var _textController = TextEditingController();

  void initState() {
    super.initState();
    _textController.text = value!;
    _textController.addListener(() {
      didChange(_textController.text);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

/// Editor for a [DateField].
class DateFormField extends FormField<DateTime> {
  DateFormField({
    required String fieldFormat,
    DateTime? initialValue,
    String? heading,
    FormFieldSetter<DateTime>? onSaved,
  }) : super(
          onSaved: onSaved,
          initialValue: initialValue,
          builder: (FormFieldState<DateTime> state) {
            return InkWell(
              onTap: () async {
                var newDate = await showDatePicker(
                  context: state.context,
                  initialDate: state.value ?? DateTime.now(),
                  firstDate: DateTime(0),
                  lastDate: DateTime(3000),
                );
                if (newDate != null) {
                  state.didChange(newDate);
                } else if (state.value != null) {
                  // Give option of removing the value after cancelling.
                  var keepValue = await commonDialogs.okCancelDialog(
                    context: state.context,
                    title: 'Cancelled Date Entry',
                    label: 'Keep the previous date value?',
                    trueButtonText: 'KEEP',
                    falseButtonText: 'REMOVE',
                  );
                  if (keepValue != null && !keepValue) {
                    state.didChange(null);
                  }
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(heading ?? 'Date',
                        style: Theme.of(state.context).textTheme.caption),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 5.0),
                    child: Text(
                      state.value != null
                          ? DateFormat(fieldFormat).format(state.value!)
                          : '',
                      style: Theme.of(state.context).textTheme.subtitle1,
                    ),
                  ),
                  Divider(thickness: 3.0),
                ],
              ),
            );
          },
        );
}

/// Editor for a [TimeField].
class TimeFormField extends FormField<DateTime> {
  TimeFormField({
    required String fieldFormat,
    DateTime? initialValue,
    String? heading,
    FormFieldSetter<DateTime>? onSaved,
  }) : super(
          onSaved: onSaved,
          initialValue: initialValue,
          builder: (FormFieldState<DateTime> state) {
            return InkWell(
              onTap: () async {
                var newTime = await showTimePicker(
                  context: state.context,
                  initialTime: state.value != null
                      ? TimeOfDay.fromDateTime(state.value!)
                      : TimeOfDay.now(),
                );
                if (newTime != null) {
                  state.didChange(
                    DateTime(1970, 1, 1, newTime.hour, newTime.minute),
                  );
                } else if (state.value != null) {
                  // Give option of removing the value after cancelling.
                  var keepValue = await commonDialogs.okCancelDialog(
                    context: state.context,
                    title: 'Cancelled Time Entry',
                    label: 'Keep the previous time value?',
                    trueButtonText: 'KEEP',
                    falseButtonText: 'REMOVE',
                  );
                  if (keepValue != null && !keepValue) {
                    state.didChange(null);
                  }
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(heading ?? 'Time',
                        style: Theme.of(state.context).textTheme.caption),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 5.0),
                    child: Text(
                      state.value != null
                          ? DateFormat(fieldFormat).format(state.value!)
                          : '',
                      style: Theme.of(state.context).textTheme.subtitle1,
                    ),
                  ),
                  Divider(
                    thickness: 3.0,
                  ),
                ],
              ),
            );
          },
        );
}
