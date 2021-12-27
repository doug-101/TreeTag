// line_edit.dart, a view to edit an output field line or a rule field line.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/parsed_line.dart';
import '../../model/structure.dart';
import 'line_field_edit.dart';

// The line edit widget.
class LineEdit extends StatefulWidget {
  final ParsedLine line;

  LineEdit({Key? key, required this.line}) : super(key: key);

  @override
  State<LineEdit> createState() => _LineEditState();
}

class _LineEditState extends State<LineEdit> {
  LineSegment? selectedSegment;
  bool isChanged = false;
  final _textEditKey = GlobalKey<FormFieldState>();

  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    final contrastStyle =
        TextStyle(color: Theme.of(context).colorScheme.secondary);
    return Scaffold(
      appBar: AppBar(
        title: Text('Line Edit'),
      ),
      body: WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, isChanged);
          return true;
        },
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  PopupMenuButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onSelected: (result) async {
                      LineSegment? newSegment;
                      if (result == 'add text') {
                        var text = await textDialog();
                        if (text != null) newSegment = LineSegment(text: text);
                      } else {
                        var field = model.fieldMap[result];
                        if (field != null)
                          newSegment = LineSegment(field: field);
                      }
                      if (newSegment != null) {
                        var pos = widget.line.segments.length;
                        if (selectedSegment != null)
                          pos = widget.line.segments.indexOf(selectedSegment!);
                        setState(() {
                          widget.line.segments.insert(pos, newSegment!);
                          selectedSegment = newSegment;
                          isChanged = true;
                        });
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry>[
                      PopupMenuItem(
                        child: Text('Add Text'),
                        value: 'add text',
                      ),
                      PopupMenuDivider(),
                      for (var fieldName in model.fieldMap.keys)
                        PopupMenuItem(
                          child: Text('Add Field: $fieldName'),
                          value: fieldName,
                        )
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: selectedSegment == null
                        ? null
                        : () async {
                            if (selectedSegment?.field != null) {
                              var altField = selectedSegment!.field!;
                              var altCreated = false;
                              if (!altField.isAltFormatField()) {
                                altField = altField.createAltFormatField();
                                altCreated = true;
                              }
                              var fieldIsChanged = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      LineFieldEdit(field: altField),
                                ),
                              );
                              if (fieldIsChanged) isChanged = true;
                              if (altCreated) {
                                if (fieldIsChanged) {
                                  selectedSegment!.field = altField;
                                } else {
                                  selectedSegment!.field!
                                      .removeAltFormatField(altField);
                                }
                              }
                            } else {
                              var text = await textDialog(
                                  initText: selectedSegment!.text!);
                              if (text != null &&
                                  text != selectedSegment!.text) {
                                setState(() {
                                  selectedSegment!.text = text;
                                  isChanged = true;
                                });
                              }
                            }
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: (selectedSegment == null ||
                            widget.line.segments.length < 2)
                        ? null
                        : () {
                            setState(() {
                              widget.line.segments.remove(selectedSegment!);
                              selectedSegment = null;
                              isChanged = true;
                            });
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: (selectedSegment == null ||
                            widget.line.segments.indexOf(selectedSegment!) == 0)
                        ? null
                        : () {
                            var pos =
                                widget.line.segments.indexOf(selectedSegment!);
                            setState(() {
                              widget.line.segments.removeAt(pos);
                              widget.line.segments
                                  .insert(pos - 1, selectedSegment!);
                              isChanged = true;
                            });
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: (selectedSegment == null ||
                            widget.line.segments.indexOf(selectedSegment!) ==
                                widget.line.segments.length - 1)
                        ? null
                        : () {
                            var pos =
                                widget.line.segments.indexOf(selectedSegment!);
                            setState(() {
                              widget.line.segments.removeAt(pos);
                              widget.line.segments
                                  .insert(pos + 1, selectedSegment!);
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
                    for (var segment in widget.line.segments)
                      Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: InputChip(
                          backgroundColor: Colors.transparent,
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.0,
                            ),
                          ),
                          elevation: 2.0,
                          showCheckmark: false,
                          label: segment.hasField
                              ? Text(segment.field!.name, style: contrastStyle)
                              : Text(segment.text ?? ''),
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
          title: const Text('Title Name'),
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
