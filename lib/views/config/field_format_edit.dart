// field_format_edit.dart, a display widget and an edit view for field formats.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat, DateFormat;
import 'choice_format_edit.dart';
import '../common_dialogs.dart' as common_dialogs;
import '../../model/field_format_tools.dart';

/// A form field widget used to display field formats.
///
/// Used from [FieldEdit] and [LineFieldEdit] views.
class FieldFormatDisplay extends FormField<String> {
  FieldFormatDisplay({
    required String fieldType,
    required String initialFormat,
    super.key,
    super.onSaved,
  }) : super(
            initialValue: initialFormat,
            builder: (FormFieldState<String> state) {
              return InkWell(
                onTap: () async {
                  final newFormat = await Navigator.push(
                    state.context,
                    MaterialPageRoute<String?>(
                      builder: (context) {
                        if (fieldType == 'Choice') {
                          return ChoiceFormatEdit(initFormat: state.value!);
                        }
                        return FieldFormatEdit(
                            fieldType: fieldType, initFormat: state.value!);
                      },
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
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text('$fieldType Field Format',
                          style: Theme.of(state.context).textTheme.bodySmall),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5.0),
                      child: Text(
                        _fieldFormatPreview(fieldType, state.value!),
                        style: Theme.of(state.context).textTheme.titleMedium,
                      ),
                    ),
                    const Divider(
                      thickness: 3.0,
                    ),
                  ],
                ),
              );
            });
}

/// The field format edit widget.
///
/// Used for Number, Date and Time fields.
/// Used from the [FieldFormatDisplay], above.
class FieldFormatEdit extends StatefulWidget {
  final String fieldType;
  final String initFormat;

  const FieldFormatEdit(
      {super.key, required this.fieldType, required this.initFormat});

  @override
  State<FieldFormatEdit> createState() => _FieldFormatEditState();
}

class _FieldFormatEditState extends State<FieldFormatEdit> {
  FormatSegment? selectedSegment;

  /// The current format segments in the editor.
  final segments = <FormatSegment>[];

  /// The format strings to use for the applicable field type.
  final formatMap = <String, String>{};

  var isChanged = false;

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
    final contrastStyle =
        TextStyle(color: Theme.of(context).colorScheme.primary);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.fieldType} Field Format'),
      ),
      body: PopScope(
        // Avoid pop due to back button until a result can be returned.
        canPop: false,
        onPopInvoked: (bool didPop) {
          if (!didPop) {
            final formatResult = combineFieldFormat(segments, condense: true);
            if (_fieldFormatIsValid(widget.fieldType, formatResult)) {
              Navigator.pop<String?>(
                context,
                isChanged ? formatResult : null,
              );
            }
          }
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
                    tooltip: 'Show add menu',
                    onSelected: (result) async {
                      FormatSegment? newSegment;
                      if (result == 'add text') {
                        // Add a segemnt with extra text.
                        final text = await common_dialogs.textDialog(
                          context: context,
                          title: 'Field Format',
                          label: 'Segment Text',
                        );
                        if (text != null) {
                          newSegment = FormatSegment(extraText: text);
                        }
                      } else {
                        // Add a segemnt with a format code.
                        newSegment = FormatSegment(formatCode: result);
                      }
                      if (newSegment != null) {
                        var pos = segments.length;
                        if (selectedSegment != null) {
                          pos = segments.indexOf(selectedSegment!);
                        }
                        setState(() {
                          segments.insert(pos, newSegment!);
                          isChanged = true;
                        });
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      if (widget.fieldType != 'Number')
                        const PopupMenuItem<String>(
                          value: 'add text',
                          child: Text('Add Text'),
                        ),
                      if (widget.fieldType != 'Number')
                        const PopupMenuDivider(),
                      for (var code in formatMap.keys)
                        PopupMenuItem<String>(
                          value: code,
                          child: Text('Add: ${formatMap[code]}'),
                        )
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit segment',
                    onPressed: (selectedSegment == null ||
                            selectedSegment?.extraText == null)
                        ? null
                        : () async {
                            // Edit a segment with extra text.
                            final text = await common_dialogs.textDialog(
                              context: context,
                              initText: selectedSegment!.extraText!,
                              title: 'Field Format',
                              label: 'Segment Text',
                            );
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
                    tooltip: 'Delete segment',
                    onPressed: (selectedSegment == null || segments.length < 2)
                        ? null
                        : () {
                            // Delete a segment.
                            setState(() {
                              segments.remove(selectedSegment!);
                              selectedSegment = null;
                              isChanged = true;
                            });
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Move segment left',
                    onPressed: (selectedSegment == null ||
                            segments.indexOf(selectedSegment!) == 0)
                        ? null
                        : () {
                            // Move a segment to the left.
                            final pos = segments.indexOf(selectedSegment!);
                            setState(() {
                              segments.removeAt(pos);
                              segments.insert(pos - 1, selectedSegment!);
                              isChanged = true;
                            });
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Move segment right',
                    onPressed: (selectedSegment == null ||
                            segments.indexOf(selectedSegment!) ==
                                segments.length - 1)
                        ? null
                        : () {
                            // Move a segment to the right.
                            final pos = segments.indexOf(selectedSegment!);
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
                // This is required to work around a desktop horizontal scroll
                // issue.
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.touch,
                    },
                  ),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var segment in segments)
                        Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: InputChip(
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
                            // Tap target setting prevents uneven spacing.
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
              ),
              Padding(
                padding: const EdgeInsets.only(top: 15.0),
                child: Text('Format Sample',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: Text(
                  _fieldFormatPreview(
                    widget.fieldType,
                    combineFieldFormat(segments),
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Spacer(flex: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Show a preview of the current format.
String _fieldFormatPreview(String fieldType, String fieldFormat) {
  try {
    if (fieldType == 'Date' || fieldType == 'Time') {
      return DateFormat(fieldFormat).format(DateTime.now());
    }
    if (fieldType == 'Number') {
      final result = NumberFormat(fieldFormat).format(12345.6789);
      return '$result  ($fieldFormat)';
    }
    if (fieldType == 'Choice') {
      return splitChoiceFormat(fieldFormat).join(' | ');
    }
  } on FormatException {
    return 'Invalid Format';
  }
  return '';
}

/// Return true of the format is valid.
bool _fieldFormatIsValid(String fieldType, String fieldFormat) {
  try {
    if (fieldType == 'Date' || fieldType == 'Time') {
      DateFormat(fieldFormat).format(DateTime.now());
    }
    if (fieldType == 'Number') NumberFormat(fieldFormat).format(12345.6789);
  } on FormatException {
    return false;
  }
  return true;
}
