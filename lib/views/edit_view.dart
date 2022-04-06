// edit_view.dart, a view to edit data for an existing or a new node.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../model/field_format_tools.dart';
import '../model/fields.dart';
import '../model/nodes.dart';
import '../model/structure.dart';

/// An edit view for node data.
///
/// Called from new or edit operations in a [DetailView].
/// [isNew] is true for newly created nodes, to handle updates properly.
class EditView extends StatefulWidget {
  final LeafNode node;
  final bool isNew;

  EditView({Key? key, required this.node, this.isNew = false})
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
      if (!_isChanged && widget.isNew) {
        var toBeSaved = await saveUnchangedDialog();
        if (toBeSaved != null && !toBeSaved) {
          widget.node.modelRef.deleteNode(widget.node, withUndo: false);
          return true;
        }
      }
      // Handle all updates.
      if (_isChanged || widget.isNew) {
        _formKey.currentState!.save();
        widget.node.modelRef
            .editNodeData(widget.node, nodeData, newNode: widget.isNew);
      }
      return true;
    }
    return false;
  }

  /// Ask user about saving an unchanged new node.
  Future<bool?> saveUnchangedDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Unchanged?'),
          content: const Text('Save unmodified new node?'),
          actions: <Widget>[
            TextButton(
              child: const Text('SAVE'),
              onPressed: () => Navigator.pop(context, true),
            ),
            TextButton(
              child: const Text('DISCARD'),
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.node.title),
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
        child: Container(
          margin: const EdgeInsets.all(10.0),
          child: ListView(
            children: <Widget>[
              for (var field in widget.node.modelRef.fieldMap.values)
                _fieldEditor(widget.node, field),
            ],
          ),
        ),
      ),
    );
  }

  /// Return the proper field editor based on field type.
  Widget _fieldEditor(LeafNode node, Field field) {
    if (field is LongTextField) {
      return TextFormField(
        decoration: InputDecoration(labelText: field.name),
        minLines: 4,
        maxLines: 12,
        initialValue: nodeData[field.name] ?? '',
        validator: field.validateMessage,
        onSaved: (String? value) {
          if (value != null) nodeData[field.name] = value;
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
        decoration: InputDecoration(labelText: field.name),
        // Null value gives a blank.
        value: nodeData[field.name],
        onChanged: (String? value) {
          setState(() {});
        },
        onSaved: (String? value) {
          if (value != null) {
            if (value.isNotEmpty) {
              nodeData[field.name] = value;
            } else {
              nodeData.remove(field.name);
            }
          }
        },
      );
    }
    if (field is AutoChoiceField) {
      return AutoChoiceForm(
        label: field.name,
        initialValue: nodeData[field.name] ?? '',
        initialOptions: field.options,
        onSaved: (String? value) {
          if (value != null && value.isNotEmpty) {
            nodeData[field.name] = value;
            field.options.add(value);
          } else {
            nodeData.remove(field.name);
          }
        },
      );
    }
    if (field is NumberField) {
      return TextFormField(
        decoration: InputDecoration(labelText: field.name),
        initialValue: nodeData[field.name] ?? '',
        validator: field.validateMessage,
        onSaved: (String? value) {
          if (value != null) nodeData[field.name] = num.parse(value).toString();
        },
      );
    }
    if (field is DateField) {
      var initString = node.data[field.name];
      var storedDateFormat = DateFormat('yyyy-MM-dd');
      return DateFormField(
        fieldFormat: field.format,
        initialValue:
            initString != null ? storedDateFormat.parse(initString) : null,
        heading: field.name,
        onSaved: (DateTime? value) {
          if (value != null)
            nodeData[field.name] = storedDateFormat.format(value);
        },
      );
    }
    if (field is TimeField) {
      var initString = node.data[field.name];
      var storedTimeFormat = DateFormat('HH:mm:ss.S');
      return TimeFormField(
        fieldFormat: field.format,
        initialValue:
            initString != null ? storedTimeFormat.parse(initString) : null,
        heading: field.name,
        onSaved: (DateTime? value) {
          if (value != null)
            nodeData[field.name] = storedTimeFormat.format(value);
        },
      );
    }
    // Default return for a regular TextField
    return TextFormField(
      decoration: InputDecoration(labelText: field.name),
      initialValue: nodeData[field.name] ?? '',
      validator: field.validateMessage,
      onSaved: (String? value) {
        if (value != null && value.isNotEmpty) {
          nodeData[field.name] = value;
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
