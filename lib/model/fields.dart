// fields.dart, defines field types and operations in the model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'nodes.dart';

/// A stored format for a portion of the data held within a leaf node.
class Field {
  late String name, _type, _format, _prefix, _suffix;

  Field(Map<String, dynamic> jsonData) {
    name = jsonData['fieldname'] ?? '';
    _type = jsonData['fieldtype'] ?? 'Text';
    _format = jsonData['format'] ?? '';
    _prefix = jsonData['prefix'] ?? '';
    _suffix = jsonData['suffix'] ?? '';
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
}
