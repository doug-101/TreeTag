// fields.dart, defines field types and operations in the model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:intl/intl.dart' show DateFormat;
import 'nodes.dart';

final fieldTypes = const ['Text', 'LongText', 'Date'];

/// A stored format for a portion of the data held within a leaf node.
abstract class Field {
  late String name, fieldType, format, initValue, prefix, suffix;
  var _altFormatFields = <Field>[];
  int? _altFormatNumber;

  Field({
    required this.name,
    this.fieldType = 'Text',
    this.format = '',
    this.initValue = '',
    this.prefix = '',
    this.suffix = '',
  });

  factory Field.createField({
    required String name,
    fieldType = 'Text',
    format = '',
    initValue = '',
    prefix = '',
    suffix = '',
  }) {
    Field newField;
    switch (fieldType) {
      case 'Text':
        newField = TextField(
            name: name,
            initValue: initValue,
            prefix: prefix,
            suffix: suffix);
        break;
      case 'LongText':
        newField = LongTextField(
            name: name,
            initValue: initValue,
            prefix: prefix,
            suffix: suffix);
        break;
      case 'Date':
        newField = DateField(
            name: name,
            format: format,
            initValue: initValue,
            prefix: prefix,
            suffix: suffix);
        break;
      default:
        newField = TextField(
            name: name,
            initValue: initValue,
            prefix: prefix,
            suffix: suffix);
        break;
    }
    return newField;
  }

  factory Field.fromJson(Map<String, dynamic> jsonData) {
    var newField = Field.createField(
      name: jsonData['fieldname'] ?? '',
      fieldType: jsonData['fieldtype'] ?? 'Text',
      format: jsonData['format'] ?? '',
      initValue: jsonData['initvalue'] ?? '',
      prefix: jsonData['prefix'] ?? '',
      suffix: jsonData['suffix'] ?? '',
    );
    var i = 0;
    while (List.of(jsonData.keys).any((var key) => key.endsWith(':$i'))) {
      var altField = Field.createField(
        name: newField.name,
        fieldType: newField.fieldType,
        format: jsonData['format:$i'] ?? '',
        initValue: newField.initValue,
        prefix: jsonData['prefix:$i'] ?? '',
        suffix: jsonData['suffix:$i'] ?? '',
      );
      altField._altFormatNumber = i;
      newField._altFormatFields.add(altField);
      i++;
    }
    return newField;
  }

  String outputText(LeafNode node) {
    var storedText = node.data[name] ?? '';
    if (storedText.isEmpty) return '';
    return _formatOutput(storedText);
  }

  String _formatOutput(String storedText) {
    return prefix + storedText + suffix;
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
    var result = <String, dynamic>{'fieldname': name, 'fieldtype': fieldType};
    if (format.isNotEmpty) result['format'] = format;
    if (initValue.isNotEmpty) result['initvalue'] = initValue;
    if (prefix.isNotEmpty) result['prefix'] = prefix;
    if (suffix.isNotEmpty) result['suffix'] = suffix;
    var i = 0;
    for (var altField in _altFormatFields) {
      if (altField.format.isNotEmpty) result['format:$i'] = altField.format;
      if (altField.prefix.isNotEmpty) result['prefix:$i'] = altField.prefix;
      if (altField.suffix.isNotEmpty) result['suffix:$i'] = altField.suffix;
      i++;
    }
    return result;
  }

  Field copyToType(String newFieldType) {
    return Field.createField(
      name: name,
      fieldType: newFieldType,
      prefix: prefix,
      suffix: suffix,
    );
  }

  Field? altFormatField(int num) {
    if (num < _altFormatFields.length) return _altFormatFields[num];
    return null;
  }

  bool isAltFormatField() => _altFormatNumber != null;

  Field createAltFormatField() {
    var altField = Field.createField(
        name: name,
        fieldType: fieldType,
        format: format,
        initValue: initValue,
        prefix: prefix,
        suffix: suffix);
    altField._altFormatNumber = _altFormatFields.length;
    _altFormatFields.add(altField);
    return altField;
  }

  void removeAltFormatField(Field altField) {
    _altFormatFields.remove(altField);
  }

  String lineText() {
    return _altFormatNumber != null
        ? '{*$name:$_altFormatNumber*}'
        : '{*$name*}';
  }
}

class TextField extends Field {
  TextField({
    required String name,
    initValue = '',
    prefix = '',
    suffix = '',
  }) : super(
          name: name,
          fieldType: 'Text',
          format: '',
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );
}

class LongTextField extends Field {
  LongTextField({
    required String name,
    initValue = '',
    prefix = '',
    suffix = '',
  }) : super(
          name: name,
          fieldType: 'LongText',
          format: '',
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );
}

class DateField extends Field {
  DateField({
    required String name,
    format = '',
    initValue = '',
    prefix = '',
    suffix = '',
  }) : super(
          name: name,
          fieldType: 'Date',
          format: format.isNotEmpty ? format : 'MMMM d, yyyy',
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );

  DateTime _parseStored(String storedText) {
    return DateFormat('yyyy-MM-dd').parse(storedText);
  }

  @override
  String _formatOutput(String storedText) {
    var date = _parseStored(storedText);
    var dateString = DateFormat(format).format(date);
    return prefix + dateString + suffix;
  }

  @override
  int compareNodes(Node firstNode, Node secondNode) {
    var firstValue = _parseStored(firstNode.data[name] ?? '0000-01-01');
    var secondValue = _parseStored(secondNode.data[name] ?? '0000-01-01');
    return firstValue.compareTo(secondValue);
  }
}
