// line_edit.dart, a view to edit an output field line or a rule field line.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'line_field_edit.dart';
import '../common_dialogs.dart' as common_dialogs;
import '../../model/parsed_line.dart';
import '../../model/structure.dart';

/// The line edit view that edits a line with fields and text.
///
/// Called from both [RuleEdit] and [OutputConfig] views.
class LineEdit extends StatefulWidget {
  final ParsedLine line;
  final String title;

  const LineEdit({super.key, required this.line, this.title = 'Line Edit'});

  @override
  State<LineEdit> createState() => _LineEditState();
}

class _LineEditState extends State<LineEdit> {
  LineSegment? _selectedSegment;
  var _isChanged = false;

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<Structure>(context, listen: false);
    final contrastStyle =
        TextStyle(color: Theme.of(context).colorScheme.primary);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context, false);
            },
          ),
        ],
      ),
      body: PopScope<Object?>(
        // Avoid pop due to back button until the value can be checked.
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          if (!didPop) {
            if (widget.line.isEmpty) {
              await common_dialogs.okDialog(
                context: context,
                title: 'Cannot be empty',
                label: 'Must add a field or a text entry',
              );
            } else {
              Navigator.pop(context, _isChanged);
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Add a field or text.
                  PopupMenuButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Show add menu',
                    onSelected: (result) async {
                      LineSegment? newSegment;
                      if (result == 'add text') {
                        final text = await common_dialogs.textDialog(
                          context: context,
                          title: 'Title Name',
                          label: 'Segment Text',
                        );
                        if (text != null) newSegment = LineSegment(text: text);
                      } else {
                        final field = model.fieldMap[result];
                        if (field != null) {
                          newSegment = LineSegment(field: field);
                        }
                      }
                      if (newSegment != null) {
                        var pos = widget.line.segments.length;
                        if (_selectedSegment != null) {
                          pos = widget.line.segments.indexOf(_selectedSegment!);
                        }
                        setState(() {
                          widget.line.segments.insert(pos, newSegment!);
                          _isChanged = true;
                        });
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry>[
                      const PopupMenuItem(
                        value: 'add text',
                        child: Text('Add Text'),
                      ),
                      const PopupMenuDivider(),
                      for (var fieldName in model.fieldMap.keys)
                        PopupMenuItem(
                          value: fieldName,
                          child: Text('Add Field: $fieldName'),
                        )
                    ],
                  ),
                  // Edit the selected segment.
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit a segment',
                    onPressed: _selectedSegment == null
                        ? null
                        : () async {
                            if (_selectedSegment?.field != null) {
                              var altField = _selectedSegment!.field!;
                              var altCreated = false;
                              if (!altField.isAltFormatField) {
                                altField = altField.createAltFormatField();
                                altCreated = true;
                              }
                              final fieldIsChanged = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      LineFieldEdit(field: altField),
                                ),
                              );
                              if (fieldIsChanged) {
                                _isChanged = true;
                                if (altCreated) {
                                  _selectedSegment!.field = altField;
                                }
                                if (altField == altField.altFormatParent) {
                                  // Revert to parent field format if same.
                                  _selectedSegment!.field =
                                      altField.altFormatParent;
                                  _selectedSegment!.field!
                                      .removeAltFormatField(altField);
                                }
                              } else if (altCreated) {
                                _selectedSegment!.field!
                                    .removeAltFormatField(altField);
                              }
                            } else {
                              final text = await common_dialogs.textDialog(
                                context: context,
                                initText: _selectedSegment!.text!,
                                title: 'Title Name',
                                label: 'Segment Text',
                              );
                              if (text != null &&
                                  text != _selectedSegment!.text) {
                                setState(() {
                                  _selectedSegment!.text = text;
                                  _isChanged = true;
                                });
                              }
                            }
                          },
                  ),
                  // Delete the selected segment.
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete a segment',
                    onPressed: (_selectedSegment == null ||
                            widget.line.segments.length < 2)
                        ? null
                        : () {
                            setState(() {
                              widget.line.segments.remove(_selectedSegment!);
                              _selectedSegment = null;
                              _isChanged = true;
                            });
                          },
                  ),
                  // Move the selected segment to the left.
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Move a segment left',
                    onPressed: (_selectedSegment == null ||
                            widget.line.segments.indexOf(_selectedSegment!) ==
                                0)
                        ? null
                        : () {
                            final pos =
                                widget.line.segments.indexOf(_selectedSegment!);
                            setState(() {
                              widget.line.segments.removeAt(pos);
                              widget.line.segments
                                  .insert(pos - 1, _selectedSegment!);
                              _isChanged = true;
                            });
                          },
                  ),
                  // Move the selected segment to the right.
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Move a segment right',
                    onPressed: (_selectedSegment == null ||
                            widget.line.segments.indexOf(_selectedSegment!) ==
                                widget.line.segments.length - 1)
                        ? null
                        : () {
                            final pos =
                                widget.line.segments.indexOf(_selectedSegment!);
                            setState(() {
                              widget.line.segments.removeAt(pos);
                              widget.line.segments
                                  .insert(pos + 1, _selectedSegment!);
                              _isChanged = true;
                            });
                          },
                  ),
                ],
              ),
              // The chips for the segments.
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
                      for (var segment in widget.line.segments)
                        Padding(
                          padding: const EdgeInsets.all(1.5),
                          child: InputChip(
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.0,
                              ),
                            ),
                            elevation: 2.0,
                            showCheckmark: false,
                            label: segment.hasField
                                ? Text(segment.field!.name,
                                    style: contrastStyle)
                                : Text(segment.text ?? ''),
                            selected: segment == _selectedSegment,
                            onSelected: (bool isSelected) {
                              setState(() {
                                if (isSelected) {
                                  _selectedSegment = segment;
                                } else {
                                  _selectedSegment = null;
                                }
                              });
                            },
                          ),
                        ),
                    ],
                  ),
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
