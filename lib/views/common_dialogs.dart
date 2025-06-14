// common_dialogs.dart, several common dialog functions.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart' show prefs;

final _filenameEditKey = GlobalKey<FormFieldState>();
final _textEditKey = GlobalKey<FormFieldState>();

/// Dialog with two buttons (OK and CANCEL by default) for confirmation.
Future<bool?> okCancelDialog({
  required BuildContext context,
  String title = 'Confirm?',
  String? label,
  String trueButtonText = 'OK',
  String falseButtonText = 'CANCEL',
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(label ?? ''),
        actions: <Widget>[
          TextButton(
            child: Text(trueButtonText),
            onPressed: () => Navigator.pop(context, true),
          ),
          TextButton(
            child: Text(falseButtonText),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      );
    },
  );
}

/// Dialog with an OK button to create a pause to inform the user.
Future<bool?> okDialog({
  required BuildContext context,
  String title = 'Confirm?',
  String? label,
  bool isDissmissable = true,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: isDissmissable,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(label ?? ''),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      );
    },
  );
}

/// Dialog to select between the given choices.
Future<String?> choiceDialog({
  required BuildContext context,
  required List<String> choices,
  String title = 'Choose',
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return SimpleDialog(
        title: Text(title),
        children: <Widget>[
          for (var choice in choices)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, choice);
              },
              child: Text(choice),
            ),
        ],
      );
    },
  );
}

/// Prompt the user for a new filename.
Future<String?> filenameDialog({
  required BuildContext context,
  String? initName,
  String title = 'New Filename',
  String? label,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: TextFormField(
          key: _filenameEditKey,
          decoration: InputDecoration(labelText: label ?? ''),
          autofocus: true,
          initialValue: initName ?? '',
          validator: (String? text) {
            if (text == null) return 'Cannot be empty';
            text = text.trim();
            if (text.isEmpty) return 'Cannot be empty';
            if (text.contains('/')) {
              return 'Cannot contain "/" characters';
            }
            if (Platform.isWindows && (text.contains('\\'))) {
              return 'Cannot contain "\\" characters';
            }
            if ((text.startsWith('.')) &&
                (prefs.getBool('hidedotfiles') ?? true)) {
              return 'Cannot start with a "."';
            }
            if (text == initName) return 'A new name is required';
            return null;
          },
          onFieldSubmitted: (value) {
            // Complete the dialog when the user presses enter.
            if (_filenameEditKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _filenameEditKey.currentState!.value.trim(),
              );
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              if (_filenameEditKey.currentState!.validate()) {
                Navigator.pop(
                  context,
                  _filenameEditKey.currentState!.value.trim(),
                );
              }
            },
          ),
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      );
    },
  );
}

/// Prompt for a one-line text entry with OK and CANCEL buttons.
Future<String?> textDialog({
  required BuildContext context,
  String? initText,
  String title = 'Enter Text',
  String? label,
  bool allowEmpty = false,
  bool obscureText = false,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: TextFormField(
          key: _textEditKey,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
          obscureText: obscureText,
          initialValue: initText ?? '',
          validator: (String? text) {
            if (!allowEmpty && (text?.isEmpty ?? false)) {
              return 'Cannot be empty';
            }
            return null;
          },
          onFieldSubmitted: (value) {
            // Complete the dialog when the user presses enter.
            if (_textEditKey.currentState!.validate()) {
              Navigator.pop(context, _textEditKey.currentState!.value);
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              if (_textEditKey.currentState!.validate()) {
                Navigator.pop(context, _textEditKey.currentState!.value);
              }
            },
          ),
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      );
    },
  );
}

Future<void> aboutDialog({required BuildContext context}) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  showAboutDialog(
    context: context,
    applicationName: 'TreeTag',
    applicationVersion: 'Version ${packageInfo.version}',
    applicationLegalese: '©2025 by Douglas W. Bell',
    applicationIcon: Image.asset('assets/images/tree_icon_48.png'),
  );
}
