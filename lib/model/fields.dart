// fields.dart, defines field types and operations in the model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'nodes.dart';

/// A stored format for a portion of the data held within a leaf node.
class Field {
  late String name, _type, _format, _editFormat, _prefix, _suffix;
  var _altFormatFields = <Field>[];
  int? _altFormatNumber;

  Field(
      {required this.name,
      type = 'Text',
      format = '',
      editFormat = '',
      prefix = '',
      suffix = ''})
      : _type = type,
        _format = format,
        _editFormat = editFormat,
        _prefix = prefix,
        _suffix = suffix;

  Field.fromJson(Map<String, dynamic> jsonData) {
    name = jsonData['fieldname'] ?? '';
    _type = jsonData['fieldtype'] ?? 'Text';
    _format = jsonData['format'] ?? '';
    _editFormat = jsonData['editformat'] ?? '';
    _prefix = jsonData['prefix'] ?? '';
    _suffix = jsonData['suffix'] ?? '';
    var i = 0;
    while (List.from(jsonData.keys).any((var key) => key.endsWith(':$i'))) {
      var altField = Field(
          name: name,
          type: _type,
          format: jsonData['format:$i'] ?? '',
          editFormat: _editFormat,
          prefix: jsonData['prefix:$i'] ?? '',
          suffix: jsonData['suffix:$i'] ?? '');
      altField._altFormatNumber = i;
      _altFormatFields.add(altField);
      i++;
    }
  }

  String outputText(LeafNode node) {
    var storedText = node.data[name] ?? '';
    if (storedText.isEmpty) return '';
    return _formatOutput(storedText);
  }

  String _formatOutput(String storedText) {
    return _prefix + storedText + _suffix;
  }

  String? validateMessage(String? text) {
    // should return error message if invalid
    //if (text?.isEmpty ?? false) return '$name field should not be empty';
    return null;
  }

  int compareNodes(Node firstNode, Node secondNode) {
    var firstValue = firstNode.data[name] ?? '';
    var secondValue = secondNode.data[name] ?? '';
    return firstValue.compareTo(secondValue);
  }

  Map<String, dynamic> toJson() {
    var result = <String, dynamic>{'fieldname': name, 'fieldtype': _type};
    if (_format.isNotEmpty) result['format'] = _format;
    if (_editFormat.isNotEmpty) result['editformat'] = _editFormat;
    if (_prefix.isNotEmpty) result['prefix'] = _prefix;
    if (_suffix.isNotEmpty) result['suffix'] = _suffix;
    var i = 0;
    for (var altField in _altFormatFields) {
      if (altField._format.isNotEmpty) result['format:$i'] = altField._format;
      if (altField._prefix.isNotEmpty) result['prefix:$i'] = altField._prefix;
      if (altField._suffix.isNotEmpty) result['suffix:$i'] = altField._suffix;
      i++;
    }
    return result;
  }

  Field? altFormatField(int num) {
    if (num < _altFormatFields.length) return _altFormatFields[num];
    return null;
  }

  String lineText() {
    return _altFormatNumber != null
        ? '{*$name:$_altFormatNumber*}'
        : '{*$name*}';
  }
}
