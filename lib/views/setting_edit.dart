// setting_edit.dart, a view to edit the apps settings/preferences.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart';
import '../main.dart' show prefs, allowSaveWindowGeo, saveWindowGeo;
import '../model/io_file.dart';
import '../model/structure.dart';
import '../model/theme_model.dart';

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
  final _passwordKey = GlobalKey<FormFieldState>();

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
        title: Text('Settings - TreeTag'),
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
              TextFormField(
                initialValue: prefs.getString('netaddress'),
                decoration: const InputDecoration(
                  labelText: 'Network Address',
                ),
                onSaved: (String? value) async {
                  if (value != null) {
                    await prefs.setString('netaddress', value);
                  }
                },
              ),
              TextFormField(
                initialValue: prefs.getString('netuser'),
                decoration: const InputDecoration(
                  labelText: 'Network User Name',
                ),
                onSaved: (String? value) async {
                  if (value != null) {
                    await prefs.setString('netuser', value);
                  }
                },
              ),
              TextFormField(
                key: _passwordKey,
                initialValue: prefs.getString('netpassword'),
                decoration: const InputDecoration(
                  labelText: 'Network Password',
                ),
                obscureText: true,
                onSaved: (String? value) async {
                  if (value != null) {
                    await prefs.setString('netpassword', value);
                    NetworkFile.password = value;
                  }
                },
              ),
              // Links to dialog to change password on server.
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  InkWell(
                    onTap: () async {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                      } else {
                        return;
                      }
                      if ((prefs.getString('netaddress') ?? '').isEmpty ||
                          (prefs.getString('netuser') ?? '').isEmpty) {
                        await okDialog(
                          context: context,
                          title: 'Missing Data',
                          label:
                              'Network address & user name must be filled in',
                        );
                        return;
                      }
                      var result = await serverPassDialog(context: context);
                      if (result ?? false) {
                        // Set the form value to avoid overwriting it on close.
                        _passwordKey.currentState!
                            .setValue(prefs.getString('netpassword'));
                        setState(() {});
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('Change Password on Network Server'),
                    ),
                  ),
                  Divider(
                    thickness: 3.0,
                    height: 6.0,
                  ),
                ],
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
              BoolFormField(
                initialValue: prefs.getBool('enablespellcheck') ?? true,
                heading: 'Enable Editor Spell Check',
                onSaved: (bool? value) async {
                  if (value != null) {
                    await prefs.setBool('enablespellcheck', value);
                  }
                },
              ),
              BoolFormField(
                initialValue: prefs.getBool('linespacing') ??
                    (Platform.isLinux ||
                        Platform.isWindows ||
                        Platform.isMacOS),
                heading: 'Tight Text Line Spacing',
                onSaved: (bool? value) async {
                  if (value != null) {
                    await prefs.setBool('linespacing', value);
                    Provider.of<Structure>(context, listen: false)
                        .notifyListeners();
                  }
                },
              ),
              BoolFormField(
                initialValue: prefs.getBool('darktheme') ?? false,
                heading: 'Use Dark Color Theme',
                onSaved: (bool? value) async {
                  if (value != null) {
                    await prefs.setBool('darktheme', value);
                    Provider.of<ThemeModel>(context, listen: false)
                        .updateTheme();
                  }
                },
              ),
              if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
                BoolFormField(
                  initialValue: prefs.getBool('savewindowgeo') ?? true,
                  heading: 'Remember Window Position and Size',
                  onSaved: (bool? value) async {
                    if (value != null) {
                      await prefs.setBool('savewindowgeo', value);
                      allowSaveWindowGeo = value;
                      if (allowSaveWindowGeo) saveWindowGeo();
                    }
                  },
                ),
              TextFormField(
                initialValue: (prefs.getDouble('viewscale') ?? 1.0).toString(),
                decoration: const InputDecoration(
                  labelText: 'App view scale ratio',
                ),
                validator: (String? value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null) {
                      return 'Must be an number';
                    }
                    var scale = double.parse(value);
                    if (scale > 5.0 || scale < 0.2) {
                      return 'Valid range is 0.2 to 5.0';
                    }
                  }
                  return null;
                },
                onSaved: (String? value) async {
                  if (value != null && value.isNotEmpty) {
                    await prefs.setDouble('viewscale', double.parse(value));
                  }
                },
              ),
              TextFormField(
                initialValue: (prefs.getInt('undodays') ?? 7).toString(),
                decoration: const InputDecoration(
                  labelText: 'Days to Store Undo History',
                ),
                validator: (String? value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      int.tryParse(value) == null) {
                    return 'Must be an integer';
                  }
                  return null;
                },
                onSaved: (String? value) async {
                  if (value != null && value.isNotEmpty) {
                    await prefs.setInt('undodays', int.parse(value));
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
                  height: 6.0,
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                InkWell(
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
                      Text(
                        state.value!,
                        style: Theme.of(state.context).textTheme.subtitle1,
                      ),
                    ],
                  ),
                ),
                Divider(
                  thickness: 3.0,
                  height: 9.0,
                ),
              ],
            );
          },
        );
}

/// Dialog to change the password on the server.
Future<bool?> serverPassDialog({
  required BuildContext context,
}) async {
  var currentTextKey = GlobalKey<FormFieldState>();
  var newTextKey = GlobalKey<FormFieldState>();
  var repeatedTextKey = GlobalKey<FormFieldState>();
  var boolStoreKey = GlobalKey<FormFieldState>();
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Server Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              key: currentTextKey,
              decoration: const InputDecoration(
                labelText: 'Current Password',
              ),
              obscureText: true,
              autofocus: true,
            ),
            TextFormField(
              key: newTextKey,
              decoration: const InputDecoration(
                labelText: 'New Password',
              ),
              obscureText: true,
            ),
            TextFormField(
              key: repeatedTextKey,
              decoration: const InputDecoration(
                labelText: 'Repeat New Password',
              ),
              obscureText: true,
            ),
            BoolFormField(
              key: boolStoreKey,
              initialValue: false,
              heading: 'Store new password',
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            child: Text('OK'),
            onPressed: () async {
              var currentPass = currentTextKey.currentState!.value;
              var newPass = newTextKey.currentState!.value;
              if (newPass != repeatedTextKey.currentState!.value) {
                await okDialog(
                  context: context,
                  title: 'Passsword Error',
                  label: 'New and repeated passwords do not match',
                );
              } else if (newPass.isEmpty) {
                await okDialog(
                  context: context,
                  title: 'Passsword Error',
                  label: 'New password cannot be empty',
                );
              } else {
                var prevPass = NetworkFile.password;
                NetworkFile.password = currentPass;
                if (await changeNetworkPassword(newPass)) {
                  NetworkFile.password = newPass;
                  if (boolStoreKey.currentState!.value) {
                    await prefs.setString('netpassword', newPass);
                  } else {
                    await prefs.setString('netpassword', '');
                  }
                  Navigator.pop(context, true);
                } else {
                  NetworkFile.password = prevPass;
                  await okDialog(
                    context: context,
                    title: 'Passsword Change Error',
                    label: 'Failed to change the password',
                  );
                }
              }
            },
          ),
          TextButton(
            child: Text('CANCEL'),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      );
    },
  );
}
