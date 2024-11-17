// edit_view.dart, a view to edit data for an existing or a new node.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'dart:math' show max;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path/path.dart' as p;
import 'common_dialogs.dart' as common_dialogs;
import '../main.dart' show prefs;
import '../model/display_node.dart';
import '../model/field_format_tools.dart';
import '../model/fields.dart';
import '../../model/structure.dart';
import '../model/word_set_en.dart';

enum EditMode { normal, newNode, nodeChildren }

/// An edit view for node data.
///
/// Called from new or edit operations in a [FrameView].
/// Set [editMode] to handle updates properly (new nodes or multiple children).
class EditView extends StatefulWidget {
  final LeafNode node;
  final EditMode editMode;

  const EditView({
    super.key,
    required this.node,
    this.editMode = EditMode.normal,
  });

  @override
  State<EditView> createState() => _EditViewState();
}

class _EditViewState extends State<EditView> {
  final _formKey = GlobalKey<FormState>();
  var _rowWidgetList = <TableRow>[];
  var _isChanged = false;
  // The [nodeData] is copied to allow undo creation before the edit is saved.
  late final Map<String, List<String>> nodeData;

  @override
  void initState() {
    super.initState();
    // A deep copy of the original data.
    nodeData =
        widget.node.data.map((key, value) => MapEntry(key, List.of(value)));
  }

  /// Prepare to close by validating and updating.
  ///
  /// Returns true if it's ok to close.
  Future<bool> _handleClose() async {
    if (_formKey.currentState!.validate()) {
      final model = Provider.of<Structure>(context, listen: false);
      // Allow user to discard an unchanged new node.
      if (!_isChanged && widget.editMode == EditMode.newNode) {
        final toBeSaved = await common_dialogs.okCancelDialog(
          context: context,
          title: 'Save Unchanged',
          label: 'Save unmodified new node?',
          trueButtonText: 'SAVE',
          falseButtonText: 'DISCARD',
        );
        if (toBeSaved != null && !toBeSaved) {
          model.deleteNode(widget.node, withUndo: false);
          return true;
        }
      }
      // Handle all updates.
      _formKey.currentState!.save();
      for (var field in model.fieldMap.values) {
        var dataList = nodeData[field.name];
        if (dataList != null && dataList.isNotEmpty) {
          dataList.removeWhere((data) => data.isEmpty);
          if (dataList.isNotEmpty) {
            if (dataList.length > 1) {
              // Sort entries in an ascending direction for consistency.
              dataList.sort(field.compareData);
            }
            nodeData[field.name] = dataList;
          } else {
            nodeData.remove(field.name);
          }
        }
      }
      if (_isChanged && widget.editMode == EditMode.nodeChildren) {
        model.editChildData(nodeData);
      } else if (_isChanged || widget.editMode == EditMode.newNode) {
        model.editNodeData(
          widget.node,
          nodeData,
          newNode: widget.editMode == EditMode.newNode,
        );
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<Structure>(context, listen: false);
    if (_rowWidgetList.isEmpty) {
      _rowWidgetList = [
        for (var field in model.fieldMap.values)
          for (var dataPos = 0;
              dataPos < max(nodeData[field.name]?.length ?? 1, 1);
              dataPos++)
            _tableRow(field, dataPos),
      ];
    }
    late String windowTitle;
    if (widget.editMode == EditMode.nodeChildren &&
        model.titleLine
            .fields()
            .any((field) => nodeData[field.name]?.isEmpty ?? false)) {
      windowTitle = '[title varies]';
    } else {
      windowTitle = widget.node.title;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(windowTitle),
        leading: IconButton(
          icon: const Icon(Icons.check_circle),
          tooltip: 'Save changes and close',
          onPressed: () async {
            if (await _handleClose()) {
              if (!context.mounted) return;
              Navigator.of(context).pop();
            }
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restore values',
            onPressed: () {
              _formKey.currentState!.reset();
              _isChanged = false;
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel changes and close',
            onPressed: () {
              if (widget.editMode == EditMode.newNode) {
                // Discard temporary new node to cancel.
                model.deleteNode(widget.node, withUndo: false);
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          if (!didPop && await _handleClose()) {
            if (!context.mounted) return;
            // Pop manually (bypass canPop) if update is complete.
            Navigator.of(context).pop();
          }
        },
        onChanged: () {
          _isChanged = true;
        },
        // Use scroll view and column rather than a listviw to avoid items
        // losing their data when scrolled out of view then rebuilt.
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Table(
              columnWidths: <int, TableColumnWidth>{
                0: FlexColumnWidth(),
                1: FixedColumnWidth(model.areMultiplesAllowed ? 20 : 0),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: _rowWidgetList,
            ),
          ),
        ),
      ),
    );
  }

  /// Return a table row with a field editor.
  TableRow _tableRow(Field field, int dataPos) {
    return TableRow(
      children: <Widget>[
        _fieldEditor(field, dataPos),
        ExcludeFocus(
          child: InkWell(
            onTap: () {
              if (field.allowMultiples &&
                  (nodeData[field.name]?.isNotEmpty ?? true)) {
                if (nodeData[field.name] == null) {
                  nodeData[field.name] = ['', ''];
                } else {
                  nodeData[field.name]!.add('');
                }
                setState(() {
                  _rowWidgetList.insert(
                    _rowPosition(field.name),
                    _tableRow(field, dataPos + 1),
                  );
                });
              }
            },
            child: Text(
              field.allowMultiples && (nodeData[field.name]?.isNotEmpty ?? true)
                  ? '+'
                  : '',
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ],
    );
  }

  /// Return the number the last row with the given field.
  int _rowPosition(String fieldName) {
    final model = Provider.of<Structure>(context, listen: false);
    var count = 0;
    for (var field in model.fieldMap.values) {
      count += max(nodeData[field.name]?.length ?? 1, 1);
      if (field.name == fieldName) {
        // Subtract 1, since extra row was already added.
        return count - 1;
      }
    }
    assert(false, 'Should never fall through');
    return 0;
  }

  /// Return the proper field editor based on field type.
  Widget _fieldEditor(Field field, int dataPos) {
    final model = Provider.of<Structure>(context, listen: false);
    var labelString = field.name;
    String? initString;
    if (widget.editMode == EditMode.nodeChildren &&
        (nodeData[field.name]?.isEmpty ?? false)) {
      labelString = '$labelString [varies]';
      initString = null;
    } else {
      initString = nodeData[field.name]?[dataPos];
    }
    switch (field) {
      case LongTextField _:
        return TextForm(
          key: UniqueKey(),
          label: labelString,
          minLines: 4,
          maxLines: 12,
          isFileLinkAvail: model.useMarkdownOutput &&
              !(Platform.isAndroid || Platform.isIOS),
          useRelativeLinks: model.useRelativeLinks,
          initialValue: initString ?? '',
          validator: field.validateMessage,
          onSaved: (String? value) {
            if (value != null && value.isNotEmpty) {
              _setFieldData(nodeData, field.name, value, dataPos);
            } else if (widget.editMode == EditMode.nodeChildren &&
                (nodeData[field.name]?.isEmpty ?? false)) {
              nodeData[field.name] = [];
            } else {
              _setFieldData(nodeData, field.name, '', dataPos);
            }
          },
        );
      case ChoiceField _:
        return DropdownButtonFormField<String>(
          key: UniqueKey(),
          items: [
            for (var str in splitChoiceFormat(field.format))
              DropdownMenuItem<String>(
                value: str,
                child: Text(str.isNotEmpty ? str : '[Empty Value]'),
              )
          ],
          decoration: InputDecoration(labelText: labelString),
          // Null value gives a blank.
          value:
              (initString != null && initString.isNotEmpty) ? initString : null,
          onChanged: (String? value) {},
          onSaved: (String? value) {
            if (value != null) {
              if (value.isNotEmpty) {
                _setFieldData(nodeData, field.name, value, dataPos);
              } else if (widget.editMode == EditMode.nodeChildren &&
                  (nodeData[field.name]?.isEmpty ?? false)) {
                nodeData[field.name] = [];
              } else {
                _setFieldData(nodeData, field.name, '', dataPos);
              }
            }
          },
        );
      case AutoChoiceField _:
        return AutoChoiceForm(
          key: UniqueKey(),
          label: labelString,
          initialValue: initString ?? '',
          initialOptions: field.options,
          onSaved: (String? value) {
            if (value != null && value.isNotEmpty) {
              _setFieldData(nodeData, field.name, value, dataPos);
              field.options.add(value);
            } else if (widget.editMode == EditMode.nodeChildren &&
                (nodeData[field.name]?.isEmpty ?? false)) {
              nodeData[field.name] = [];
            } else {
              _setFieldData(nodeData, field.name, '', dataPos);
            }
          },
        );
      case NumberField _:
        return TextFormField(
          key: UniqueKey(),
          decoration: InputDecoration(labelText: labelString),
          initialValue: initString ?? '',
          validator: field.validateMessage,
          onSaved: (String? value) {
            if (value != null && value.isNotEmpty) {
              _setFieldData(nodeData, field.name, value, dataPos);
            } else if (widget.editMode == EditMode.nodeChildren &&
                (nodeData[field.name]?.isEmpty ?? false)) {
              nodeData[field.name] = [];
            } else {
              _setFieldData(nodeData, field.name, '', dataPos);
            }
          },
        );
      case DateField _:
        var storedDateFormat = DateFormat('yyyy-MM-dd');
        return DateFormField(
          key: UniqueKey(),
          fieldFormat: field.format,
          initialValue: (initString != null && initString.isNotEmpty)
              ? storedDateFormat.parse(initString)
              : null,
          heading: labelString,
          onSaved: (DateTime? value) async {
            if (value != null) {
              _setFieldData(
                nodeData,
                field.name,
                storedDateFormat.format(value),
                dataPos,
              );
            } else if (widget.editMode == EditMode.nodeChildren &&
                (nodeData[field.name]?.isEmpty ?? false)) {
              nodeData[field.name] = [];
            } else {
              _setFieldData(nodeData, field.name, '', dataPos);
            }
          },
        );
      case TimeField _:
        var storedTimeFormat = DateFormat('HH:mm:ss.S');
        return TimeFormField(
          key: UniqueKey(),
          fieldFormat: field.format,
          initialValue: (initString != null && initString.isNotEmpty)
              ? storedTimeFormat.parse(initString)
              : null,
          heading: labelString,
          onSaved: (DateTime? value) {
            if (value != null) {
              _setFieldData(
                nodeData,
                field.name,
                storedTimeFormat.format(value),
                dataPos,
              );
            } else if (widget.editMode == EditMode.nodeChildren &&
                (nodeData[field.name]?.isEmpty ?? false)) {
              nodeData[field.name] = [];
            } else {
              _setFieldData(nodeData, field.name, '', dataPos);
            }
          },
        );
      default:
        // Default return for a regular TextField
        return TextForm(
          key: UniqueKey(),
          label: labelString,
          isFileLinkAvail: model.useMarkdownOutput &&
              !(Platform.isAndroid || Platform.isIOS),
          useRelativeLinks: model.useRelativeLinks,
          initialValue: initString ?? '',
          validator: field.validateMessage,
          onSaved: (String? value) {
            if (value != null && value.isNotEmpty) {
              _setFieldData(nodeData, field.name, value, dataPos);
            } else if (widget.editMode == EditMode.nodeChildren &&
                (nodeData[field.name]?.isEmpty ?? false)) {
              nodeData[field.name] = [];
            } else {
              _setFieldData(nodeData, field.name, '', dataPos);
            }
          },
        );
    }
  }
}

/// Sets node data at a given position, expanding the list if necessary.
void _setFieldData(
  Map<String, List<String>> nodeData,
  String fieldName,
  String data, [
  int dataPos = 0,
]) {
  var dataList = nodeData[fieldName] ?? <String>[];
  while (dataList.length < dataPos + 1) {
    dataList.add('');
  }
  dataList[dataPos] = data;
  nodeData[fieldName] = dataList;
}

/// An editor for a text field that works with forms.
class TextForm extends FormField<String> {
  TextForm({
    super.key,
    String? label,
    bool isFileLinkAvail = false,
    bool useRelativeLinks = false,
    int? minLines,
    int? maxLines,
    super.initialValue,
    super.validator,
    super.onSaved,
  }) : super(
          builder: (FormFieldState<String> origState) {
            final state = origState as TextFormState;
            return TextField(
              decoration: InputDecoration(labelText: label),
              minLines: minLines,
              maxLines: maxLines,
              controller: state._textController,
              spellCheckConfiguration:
                  (prefs.getBool('enablespellcheck') ?? true)
                      ? SpellCheckConfiguration(
                          spellCheckService: state._spellChecker)
                      : const SpellCheckConfiguration.disabled(),
              contextMenuBuilder: (context, editableTextState) {
                final buttonItems = editableTextState.contextMenuButtonItems;
                if (isFileLinkAvail && !editableTextState.copyEnabled) {
                  final cursorPos = editableTextState
                      .currentTextEditingValue.selection.base.offset;
                  buttonItems.add(
                    ContextMenuButtonItem(
                      label: 'Add file link',
                      onPressed: () async {
                        ContextMenuController.removeAny();
                        FilePickerResult? answer =
                            await FilePicker.platform.pickFiles(
                          initialDirectory: prefs.getString('workdir')!,
                          dialogTitle: 'Select Link File',
                        );
                        if (answer != null) {
                          var linkPath = answer.files.single.path;
                          if (linkPath != null) {
                            if (useRelativeLinks) {
                              linkPath = p.relative(linkPath,
                                  from: prefs.getString('workdir')!);
                            }
                            // Convert to URI to fix path separators onWindows.
                            var uri = p.toUri(linkPath).toString();
                            if (!uri.startsWith('file:')) {
                              // This is only needed for relative paths.
                              uri = 'file:$uri';
                            }
                            final linkText = '[${p.basename(linkPath)}]($uri)';
                            final text = state._textController.text
                                .replaceRange(cursorPos, cursorPos, linkText);
                            state._textController.text = text;
                          }
                        }
                      },
                    ),
                  );
                }
                return AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: editableTextState.contextMenuAnchors,
                  buttonItems: buttonItems,
                );
              },
            );
          },
        );

  @override
  TextFormState createState() => TextFormState();
}

class TextFormState extends FormFieldState<String> {
  final _textController = TextEditingController();
  final _spellChecker = (Platform.isAndroid || Platform.isIOS)
      ? DefaultSpellCheckService()
      : SpellChecker();

  @override
  void initState() {
    super.initState();
    _textController.text = value!;
    _textController.addListener(() {
      didChange(_textController.text);
    });
  }

  @override
  void reset() {
    _textController.text = widget.initialValue ?? '';
    super.reset();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

/// Spell check service definition.
class SpellChecker extends SpellCheckService {
  static const sepChars = {
    ' ',
    '\n',
    '\r',
    '\f',
    '\t',
    ',',
    '.',
    '/',
    '?',
    ';',
    ':',
    '"',
    '~',
    '!',
    '@',
    '#',
    '\$',
    '%',
    '^',
    '&',
    '*',
    '(',
    ')',
    '-',
    '=',
    '+',
    '[',
    ']',
    '{',
    '}',
    '\\',
    '|',
    '<',
    '>',
  };
  SpellChecker();

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    final errorSpans = <SuggestionSpan>[];
    var textPos = 0;
    var wordStart = -1;
    for (var rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (SpellChecker.sepChars.contains(char)) {
        if (wordStart >= 0) {
          final word = text.substring(wordStart, textPos).toLowerCase();
          if (!wordSet.contains(word)) {
            errorSpans.add(
              SuggestionSpan(
                TextRange(start: wordStart, end: textPos),
                const <String>[],
              ),
            );
          }
          wordStart = -1;
        }
      } else if (wordStart < 0) {
        wordStart = textPos;
      }
      textPos += char.length;
    }
    return errorSpans.isNotEmpty ? errorSpans : null;
  }
}

/// An editor for an [AutoChoiceField].
///
/// Combines a [TextField] with a popup menu.
class AutoChoiceForm extends FormField<String> {
  AutoChoiceForm({
    super.key,
    String? label,
    super.initialValue,
    required Set<String> initialOptions,
    super.onSaved,
  }) : super(
          builder: (FormFieldState<String> origState) {
            final state = origState as AutoChoiceFormState;
            return Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: label ?? 'AutoChoice Field',
                          border: InputBorder.none,
                        ),
                        controller: state._textController,
                        spellCheckConfiguration:
                            (prefs.getBool('enablespellcheck') ?? true)
                                ? SpellCheckConfiguration(
                                    spellCheckService: state._spellChecker)
                                : const SpellCheckConfiguration.disabled(),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.arrow_drop_down),
                      onSelected: (String value) {
                        state._textController.text = value;
                      },
                      itemBuilder: (BuildContext context) {
                        final options = List.of(initialOptions);
                        final newText = state._textController.text;
                        if (newText.isNotEmpty &&
                            !initialOptions.contains(newText)) {
                          options.add(newText);
                        }
                        options.sort();
                        return [
                          for (var s in options)
                            PopupMenuItem(value: s, child: Text(s))
                        ];
                      },
                    ),
                  ],
                ),
                const Divider(thickness: 3.0),
              ],
            );
          },
        );

  @override
  AutoChoiceFormState createState() => AutoChoiceFormState();
}

class AutoChoiceFormState extends FormFieldState<String> {
  final _textController = TextEditingController();
  final _spellChecker = (Platform.isAndroid || Platform.isIOS)
      ? DefaultSpellCheckService()
      : SpellChecker();

  @override
  void initState() {
    super.initState();
    _textController.text = value!;
    _textController.addListener(() {
      didChange(_textController.text);
    });
  }

  @override
  void reset() {
    _textController.text = widget.initialValue ?? '';
    super.reset();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

/// Editor for a [DateField].
class DateFormField extends FormField<DateTime> {
  DateFormField({
    super.key,
    required String fieldFormat,
    super.initialValue,
    String? heading,
    super.onSaved,
  }) : super(
          builder: (FormFieldState<DateTime> state) {
            return InkWell(
              onTap: () async {
                final newDate = await showDatePicker(
                  context: state.context,
                  initialDate: state.value ?? DateTime.now(),
                  firstDate: DateTime(0),
                  lastDate: DateTime(3000),
                );
                if (newDate != null) {
                  state.didChange(newDate);
                } else if (state.value != null && state.mounted) {
                  // Give option of removing the value after cancelling.
                  final keepValue = await common_dialogs.okCancelDialog(
                    context: state.context,
                    title: 'Cancelled Date Entry',
                    label: 'Keep the previous date value?',
                    trueButtonText: 'KEEP',
                    falseButtonText: 'REMOVE',
                  );
                  if (keepValue != null && !keepValue) {
                    state.didChange(null);
                  }
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(heading ?? 'Date',
                        style: Theme.of(state.context).textTheme.bodySmall),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Text(
                      state.value != null
                          ? DateFormat(fieldFormat).format(state.value!)
                          : '',
                      style: Theme.of(state.context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(thickness: 3.0),
                ],
              ),
            );
          },
        );
}

/// Editor for a [TimeField].
class TimeFormField extends FormField<DateTime> {
  TimeFormField({
    super.key,
    required String fieldFormat,
    super.initialValue,
    String? heading,
    super.onSaved,
  }) : super(
          builder: (FormFieldState<DateTime> state) {
            return InkWell(
              onTap: () async {
                final newTime = await showTimePicker(
                  context: state.context,
                  initialTime: state.value != null
                      ? TimeOfDay.fromDateTime(state.value!)
                      : TimeOfDay.now(),
                );
                if (newTime != null) {
                  state.didChange(
                    DateTime(1970, 1, 1, newTime.hour, newTime.minute),
                  );
                } else if (state.value != null && state.mounted) {
                  // Give option of removing the value after cancelling.
                  final keepValue = await common_dialogs.okCancelDialog(
                    context: state.context,
                    title: 'Cancelled Time Entry',
                    label: 'Keep the previous time value?',
                    trueButtonText: 'KEEP',
                    falseButtonText: 'REMOVE',
                  );
                  if (keepValue != null && !keepValue) {
                    state.didChange(null);
                  }
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(heading ?? 'Time',
                        style: Theme.of(state.context).textTheme.bodySmall),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Text(
                      state.value != null
                          ? DateFormat(fieldFormat).format(state.value!)
                          : '',
                      style: Theme.of(state.context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(
                    thickness: 3.0,
                  ),
                ],
              ),
            );
          },
        );
}
