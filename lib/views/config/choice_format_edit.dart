// choice_format_edit.dart, a view to edit a choice field format entity.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import '../common_dialogs.dart' as commonDialogs;
import '../../model/field_format_tools.dart';
import '../../model/fields.dart';

/// The Choice field format edit widget.
///
/// Used from the [FieldFormatDisplay] widget.
class ChoiceFormatEdit extends StatefulWidget {
  final String initFormat;

  ChoiceFormatEdit({Key? key, required this.initFormat}) : super(key: key);

  @override
  State<ChoiceFormatEdit> createState() => _ChoiceFormatEditState();
}

class _ChoiceFormatEditState extends State<ChoiceFormatEdit> {
  String? selectedSegment;

  /// The current format segments in the editor.
  final segments = <String>[];

  bool isChanged = false;

  @override
  void initState() {
    super.initState();
    segments.addAll(splitChoiceFormat(widget.initFormat));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Choice Field Format Edit'),
      ),
      body: WillPopScope(
        onWillPop: () async {
          var formatResult = combineChoiceFormat(segments);
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
                  // Add a new text segment.
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () async {
                      var text = await commonDialogs.textDialog(
                        context: context,
                        title: 'Choice Field Format',
                        label: 'Segment Text',
                        allowEmpty: true,
                      );
                      if (text != null && !segments.contains(text)) {
                        var pos = segments.length;
                        if (selectedSegment != null)
                          pos = segments.indexOf(selectedSegment!);
                        setState(() {
                          segments.insert(pos, text);
                          selectedSegment = text;
                          isChanged = true;
                        });
                      }
                    },
                  ),
                  // Edit an existing text segment.
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: (selectedSegment == null)
                        ? null
                        : () async {
                            var text = await commonDialogs.textDialog(
                              context: context,
                              initText: selectedSegment,
                              title: 'Choice Field Format',
                              label: 'Segment Text',
                              allowEmpty: true,
                            );
                            if (text != null && !segments.contains(text)) {
                              setState(() {
                                var pos = segments.indexOf(selectedSegment!);
                                segments[pos] = text;
                                selectedSegment = text;
                                isChanged = true;
                              });
                            }
                          },
                  ),
                  // Delete a text segment.
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
                  // Move a segment to the left.
                  IconButton(
                    icon: const Icon(Icons.arrow_circle_up),
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
                  // Move a segment to the right.
                  IconButton(
                    icon: const Icon(Icons.arrow_circle_down),
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
              Expanded(
                child: Wrap(
                  direction: Axis.vertical,
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
                          label: Text(segment),
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
            ],
          ),
        ),
      ),
    );
  }
}
