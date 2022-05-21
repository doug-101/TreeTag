// setting_edit.dart, a view to edit the apps settings/preferences.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../main.dart' show prefs;

/// A user settings view.
class SettingEdit extends StatefulWidget {
  SettingEdit({Key? key}) : super(key: key);

  @override
  State<SettingEdit> createState() => _SettingEditState();
}

class _SettingEditState extends State<SettingEdit> {
  /// A flag showing that the view was forced to close.
  var _cancelFlag = false;

  final _formKey = GlobalKey<FormState>();

  Future<bool> updateOnPop() async {
    if (_cancelFlag) return true;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TreeTag Settings'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _cancelFlag = true;
              Navigator.pop(context, null);
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
              if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
                PathFormField(
                  initialValue: prefs.getString('workdir'),
                  heading: 'Working Directory',
                  onSaved: (String? value) async {
                    if (value != null) {
                      await prefs.setString('workdir', value);
                    }
                  },
                ),
              BoolFormField(
                initialValue: prefs.getBool('hidedotfiles') ?? true,
                heading: 'Hide Dot Files',
                onSaved: (bool? value) async {
                  if (value != null) {
                    await prefs.setBool('hidedotfiles', value);
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

/// A [FormField] widget for boolean settings.
class BoolFormField extends FormField<bool> {
  BoolFormField({
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
                        child: Text(heading ?? 'Boolean Value'),
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

/// A [FormField] widget for defining the working directory.
class PathFormField extends FormField<String> {
  PathFormField({
    String? initialValue,
    String? heading,
    Key? key,
    FormFieldSetter<String>? onSaved,
  }) : super(
            onSaved: onSaved,
            initialValue: initialValue,
            key: key,
            builder: (FormFieldState<String> state) {
              return InkWell(
                onTap: () async {
                  String? folder = await FilePicker.platform.getDirectoryPath(
                    initialDirectory: state.value!,
                    dialogTitle: 'Select Working Directory',
                  );
                  if (folder != null) {
                    state.didChange(folder);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(top: 10.0),
                      child: Text(heading ?? 'Selected Path',
                          style: Theme.of(state.context).textTheme.caption),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 5.0),
                      child: Text(
                        state.value!,
                        style: Theme.of(state.context).textTheme.subtitle1,
                      ),
                    ),
                    Divider(
                      thickness: 3.0,
                    ),
                  ],
                ),
              );
            });
}
