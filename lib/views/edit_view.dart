// edit_view.dart, a view to edit data for an existing or a new node.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../model/field_format_tools.dart';
import '../model/fields.dart';
import '../model/nodes.dart';
import '../model/structure.dart';

/// An edit view for node data.
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
  bool _isChanged = false;

  Future<bool> updateOnPop() async {
    if (_formKey.currentState!.validate()) {
      if (!_isChanged && widget.isNew) {
        var toBeSaved = await saveUnchangedDialog();
        if (toBeSaved != null && !toBeSaved) {
          widget.node.modelRef.deleteNode(widget.node);
          return true;
        }
      }
      if (_isChanged || widget.isNew) {
        _formKey.currentState!.save();
        widget.node.modelRef.editNodeData(widget.node);
      }
      return true;
    }
    return false;
  }

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
              child: const Text('Save'),
              onPressed: () => Navigator.pop(context, true),
            ),
            TextButton(
              child: const Text('Discard'),
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

  Widget _fieldEditor(LeafNode node, Field field) {
    if (field is LongTextField) {
      return TextFormField(
        decoration: InputDecoration(labelText: field.name),
        minLines: 4,
        maxLines: 12,
        initialValue: widget.node.data[field.name] ?? '',
        validator: field.validateMessage,
        onSaved: (String? value) {
          if (value != null) widget.node.data[field.name] = value;
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
        value: widget.node.data[field.name],
        onChanged: (String? value) {
          setState(() {});
        },
        onSaved: (String? value) {
          if (value != null) {
            if (value.isNotEmpty) {
              widget.node.data[field.name] = value;
            } else {
              widget.node.data.remove(field.name);
            }
          }
        },
      );
    }
    if (field is NumberField) {
      return TextFormField(
        decoration: InputDecoration(labelText: field.name),
        initialValue: widget.node.data[field.name] ?? '',
        validator: field.validateMessage,
        onSaved: (String? value) {
          if (value != null)
            widget.node.data[field.name] = num.parse(value).toString();
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
            widget.node.data[field.name] = storedDateFormat.format(value);
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
            widget.node.data[field.name] = storedTimeFormat.format(value);
        },
      );
    }
    // Default return for a regular TextField
    return TextFormField(
      decoration: InputDecoration(labelText: field.name),
      initialValue: widget.node.data[field.name] ?? '',
      validator: field.validateMessage,
      onSaved: (String? value) {
        if (value != null) widget.node.data[field.name] = value;
      },
    );
  }
}

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
                        style: Theme.of(state.context).textTheme.overline),
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
                        style: Theme.of(state.context).textTheme.overline),
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
