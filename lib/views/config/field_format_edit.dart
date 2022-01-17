// field_format_edit.dart, a view to edit a field format entity.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat, DateFormat;
import 'package:provider/provider.dart';
import '../../model/structure.dart';
import '../../model/field_format_tools.dart';
import '../../model/fields.dart';

// The field format display form field widget.
class FieldFormatDisplay extends FormField<String> {
  FieldFormatDisplay({
    required String fieldType,
    required String initialFormat,
    FormFieldSetter<String>? onSaved,
  }) : super(
            onSaved: onSaved,
            initialValue: initialFormat,
            builder: (FormFieldState<String> state) {
              final contrastStyle = TextStyle(
                  color: Theme.of(state.context).colorScheme.secondary);
              return InkWell(
                onTap: () async {
                  var newFormat = await Navigator.push(
                    state.context,
                    MaterialPageRoute<String?>(
                      builder: (context) => FieldFormatEdit(
                        fieldType: fieldType,
                        initFormat: state.value!,
                      ),
                    ),
                  );
                  if (newFormat != null) {
                    state.didChange(newFormat);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(top: 10.0),
                      child: Text('$fieldType Field Format',
                          style: Theme.of(state.context).textTheme.overline),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 5.0),
                      child: Text(
                        _fieldFormatPreview(fieldType, state.value!),
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

// The field format edit widget.
class FieldFormatEdit extends StatefulWidget {
  final String fieldType;
  final String initFormat;

  FieldFormatEdit({Key? key, required this.fieldType, required this.initFormat})
      : super(key: key);

  @override
  State<FieldFormatEdit> createState() => _FieldFormatEditState();
}

class _FieldFormatEditState extends State<FieldFormatEdit> {
  FormatSegment? selectedSegment;
  final segments = <FormatSegment>[];
  final formatMap = <String, String>{};
  bool isChanged = false;
  final _textEditKey = GlobalKey<FormFieldState>();

  @override
  void initState() {
    super.initState();
    if (widget.fieldType == 'Number') {
      formatMap.addAll(numberFormatMap);
    } else if (widget.fieldType == 'Date') {
      formatMap.addAll(dateFormatMap);
    } else {
      formatMap.addAll(timeFormatMap);
    }
    segments.addAll(parseFieldFormat(widget.initFormat, formatMap));
  }

  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    final contrastStyle =
        TextStyle(color: Theme.of(context).colorScheme.secondary);
    return Scaffold(
      appBar: AppBar(
        title: Text('Field Format Edit'),
      ),
      body: WillPopScope(
        onWillPop: () async {
          var formatResult = combineFieldFormat(segments, condense: true);
          if (!_fieldFormatIsValid(widget.fieldType, formatResult))
            return false;
          Navigator.pop<String?>(
            context,
            isChanged ? formatResult : null,
          );
          return true;
        },
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_circle_outline),
                    onSelected: (result) async {
                      FormatSegment? newSegment;
                      if (result == 'add text') {
                        var text = await textDialog();
                        if (text != null)
                          newSegment = FormatSegment(extraText: text);
                      } else {
                        newSegment = FormatSegment(formatCode: result);
                      }
                      if (newSegment != null) {
                        var pos = segments.length;
                        if (selectedSegment != null)
                          pos = segments.indexOf(selectedSegment!);
                        setState(() {
                          segments.insert(pos, newSegment!);
                          selectedSegment = newSegment;
                          isChanged = true;
                        });
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      if (widget.fieldType != 'Number')
                        PopupMenuItem<String>(
                          child: Text('Add Text'),
                          value: 'add text',
                        ),
                      if (widget.fieldType != 'Number') PopupMenuDivider(),
                      for (var code in formatMap.keys)
                        PopupMenuItem<String>(
                          child: Text('Add: ${formatMap[code]}'),
                          value: code,
                        )
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: (selectedSegment == null ||
                            selectedSegment?.extraText == null)
                        ? null
                        : () async {
                            var text = await textDialog(
                                initText: selectedSegment!.extraText!);
                            if (text != null &&
                                text != selectedSegment!.extraText) {
                              setState(() {
                                selectedSegment!.extraText = text;
                                isChanged = true;
                              });
                            }
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: (selectedSegment == null || segments.length < 2)
                        ? null
                        : () {
                            setState(() {
                              segments.remove(selectedSegment!);
                              selectedSegment = null;
                              isChanged = true;
                            });
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: (selectedSegment == null ||
                            segments.indexOf(selectedSegment!) == 0)
                        ? null
                        : () {
                            var pos = segments.indexOf(selectedSegment!);
                            setState(() {
                              segments.removeAt(pos);
                              segments.insert(pos - 1, selectedSegment!);
                              isChanged = true;
                            });
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: (selectedSegment == null ||
                            segments.indexOf(selectedSegment!) ==
                                segments.length - 1)
                        ? null
                        : () {
                            var pos = segments.indexOf(selectedSegment!);
                            setState(() {
                              segments.removeAt(pos);
                              segments.insert(pos + 1, selectedSegment!);
                              isChanged = true;
                            });
                          },
                  ),
                ],
              ),
              Flexible(
                flex: 1,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var segment in segments)
                      Padding(
                        padding: EdgeInsets.all(2.0),
                        child: InputChip(
                          backgroundColor: Colors.transparent,
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.0,
                            ),
                          ),
                          showCheckmark: false,
                          label: segment.formatCode != null
                              ? Text(formatMap[segment.formatCode]!,
                                  style: contrastStyle)
                              : Text(segment.extraText ?? ''),
                          // Tap target setting prevents uneven spacing
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          selected: segment == selectedSegment,
                          onSelected: (bool isSelected) {
                            setState(() {
                              if (isSelected) {
                                selectedSegment = segment;
                              } else {
                                selectedSegment = null;
                              }
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 15.0),
                child: Text('Format Sample',
                    style: Theme.of(context).textTheme.overline),
              ),
              Padding(
                padding: EdgeInsets.only(top: 5.0),
                child: Text(
                  _fieldFormatPreview(
                    widget.fieldType,
                    combineFieldFormat(segments),
                  ),
                  style: Theme.of(context).textTheme.subtitle1,
                ),
              ),
              Spacer(flex: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> textDialog({String? initText}) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Field Format'),
          content: TextFormField(
            key: _textEditKey,
            decoration: InputDecoration(labelText: 'Segment Text'),
            initialValue: initText ?? '',
            validator: (String? text) {
              if (text?.isEmpty ?? false) return 'Cannot be empty';
              return null;
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
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, null),
            ),
          ],
        );
      },
    );
  }
}

String _fieldFormatPreview(String fieldType, String fieldFormat) {
  try {
    if (fieldType == 'Date' || fieldType == 'Time')
      return DateFormat(fieldFormat).format(DateTime.now());
    if (fieldType == 'Number') {
      var result = NumberFormat(fieldFormat).format(12345.6789);
      return '$result  ($fieldFormat)';
    }
  } on FormatException {
    return 'Invalid Format';
  }
  return '';
}

bool _fieldFormatIsValid(String fieldType, String fieldFormat) {
  try {
    if (fieldType == 'Date' || fieldType == 'Time')
      DateFormat(fieldFormat).format(DateTime.now());
    if (fieldType == 'Number') NumberFormat(fieldFormat).format(12345.6789);
  } on FormatException {
    return false;
  }
  return true;
}
