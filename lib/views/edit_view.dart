// edit_view.dart, a view to edit data for an existing or a new node.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
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
        widget.node.modelRef.updateAll();
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
            children: _fieldEditors(widget.node, context),
          ),
        ),
      ),
    );
  }

  List<Widget> _fieldEditors(LeafNode node, BuildContext context) {
    var items = <Widget>[];
    for (var field in node.modelRef.fieldMap.values) {
      items.add(
        TextFormField(
            decoration: InputDecoration(labelText: field.name),
            initialValue: node.data[field.name] ?? '',
            validator: field.validateMessage,
            onSaved: (String? value) {
              if (value != null) node.data[field.name] = value;
            }),
      );
    }
    return items;
  }
}
