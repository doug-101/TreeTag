// fields.dart, defines field types and operations in the model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:intl/intl.dart' show NumberFormat, DateFormat;
import 'field_format_tools.dart';
import 'nodes.dart';

final fieldTypes = const [
  'Text',
  'LongText',
  'Choice',
  'AutoChoice',
  'Number',
  'Date',
  'Time'
];

/// A stored format for a data item held within a leaf node.
abstract class Field {
  String name;
  String fieldType;
  String format;
  String initValue;
  String prefix;
  String suffix;

  /// Similar sub-fields with different formatting.
  /// Used in specific rules or output lines.
  var _altFormatFields = <Field>[];
  int? _altFormatNumber;
  Field? altFormatParent;

  Field({
    required this.name,
    this.fieldType = 'Text',
    this.format = '',
    this.initValue = '',
    this.prefix = '',
    this.suffix = '',
  });

  // Create a subtype based on the given [fieldType].
  ///
  /// Default to a [RegTextField].
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
        newField = RegTextField(
          name: name,
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );
        break;
      case 'LongText':
        newField = LongTextField(
          name: name,
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );
        break;
      case 'Choice':
        newField = ChoiceField(
          name: name,
          format: format,
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );
        break;
      case 'AutoChoice':
        newField = AutoChoiceField(
          name: name,
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );
        break;
      case 'Number':
        newField = NumberField(
          name: name,
          format: format,
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );
        break;
      case 'Date':
        newField = DateField(
          name: name,
          format: format,
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );
        break;
      case 'Time':
        newField = TimeField(
          name: name,
          format: format,
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );
        break;
      default:
        newField = RegTextField(
          name: name,
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );
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
      altField.altFormatParent = newField;
      newField._altFormatFields.add(altField);
      i++;
    }
    return newField;
  }

  /// Returns a new field with the same settings.
  ///
  /// Keeps the [_altFormatField]; does not make a deep copy
  factory Field.copy(Field origField) {
    var newField = Field.createField(
      name: origField.name,
      fieldType: origField.fieldType,
      format: origField.format,
      initValue: origField.initValue,
      prefix: origField.prefix,
      suffix: origField.suffix,
    );
    newField._altFormatFields = origField._altFormatFields;
    newField._altFormatNumber = origField._altFormatNumber;
    newField.altFormatParent = origField.altFormatParent;
    return newField;
  }

  /// Copy settings from [otherField] to save changes from edit views.
  void updateSettings(Field otherField) {
    if (name != otherField.name) {
      name = otherField.name;
      for (var altField in _altFormatFields) altField.name = otherField.name;
    }
    format = otherField.format;
    initValue = otherField.initValue;
    prefix = otherField.prefix;
    suffix = otherField.suffix;
  }

  /// Make fields equal if they have the same settings.
  ///
  /// Used to detect whether an [_altFormatField] is redundant.
  @override
  bool operator ==(Object otherField) {
    if (runtimeType != otherField.runtimeType) return false;
    otherField = otherField as Field;
    return name == otherField.name &&
        format == otherField.format &&
        initValue == otherField.initValue &&
        prefix == otherField.prefix &&
        suffix == otherField.suffix;
  }

  /// Make fields equal if they have the same settings.
  @override
  int get hashCode =>
      Object.hash(name, fieldType, format, initValue, prefix, suffix);

  /// Return text used in node titles and output lines.
  String outputText(LeafNode node) {
    var storedText = node.data[name] ?? '';
    if (storedText.isEmpty) return '';
    return _formatOutput(storedText);
  }

  /// Return formatted text, including [prefix] and [suffix].
  ///
  /// Overridden by other field types with more specific formatting.
  String _formatOutput(String storedText) {
    return prefix + storedText + suffix;
  }

  /// Return a value for a new node or null if not set.
  ///
  /// Overridden by some field types for specific needs ("now" for dates/times).
  String? initialValue() {
    if (initValue.isNotEmpty) return initValue;
    return null;
  }

  bool isStoredTextValid(LeafNode node) {
    // Stored text is always valid for regular text fields.
    return true;
  }

  /// Return an error message if [text] would not be valid as stored data.
  String? validateMessage(String? text) {
    return null;
  }

  /// Return -1, 0 or 1 compare values for field data.
  ///
  /// Overridden by other field types with more specific sorting keys.
  int compareNodes(Node firstNode, Node secondNode) {
    var firstValue = firstNode.data[name]?.toLowerCase() ?? '';
    var secondValue = secondNode.data[name]?.toLowerCase() ?? '';
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

  /// Create a field with a different type to handle user type changes.
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

  bool get isAltFormatField => _altFormatNumber != null;

  /// Return the fields from [fields] that have the same name.
  ///
  /// Used to find regular fields as well as [_altFormatFields].
  List<Field> matchingFieldDescendents(List<Field> fields) {
    return [
      for (var field in fields)
        if (field.name == this.name) field
    ];
  }

  /// Create a new [_altFormatFields] based on this parent field's settings.
  Field createAltFormatField() {
    var altField = Field.createField(
        name: name,
        fieldType: fieldType,
        format: format,
        initValue: initValue,
        prefix: prefix,
        suffix: suffix);
    altField._altFormatNumber = _altFormatFields.length;
    altField.altFormatParent = this;
    _altFormatFields.add(altField);
    return altField;
  }

  void removeAltFormatField(Field altField) {
    _altFormatFields.remove(altField);
    for (int i = 0; i < _altFormatFields.length; i++) {
      _altFormatFields[i]._altFormatNumber = i;
    }
  }

  /// Remove any [_altFormatFields] not contained in [usedFields].
  void removeUnusedAltFormatFields(Set<Field> usedFields) {
    _altFormatFields.retainWhere((field) => usedFields.contains(field));
    for (int i = 0; i < _altFormatFields.length; i++) {
      _altFormatFields[i]._altFormatNumber = i;
    }
  }

  /// Add an alt format field if not already present.
  void addAltFormatFieldIfMissing(Field altField) {
    if (!_altFormatFields.contains(altField)) {
      altField._altFormatNumber = _altFormatFields.length;
      _altFormatFields.add(altField);
    }
  }

  /// Return the unparsed version of this field's name.
  String lineText() {
    return _altFormatNumber != null
        ? '{*$name:$_altFormatNumber*}'
        : '{*$name*}';
  }
}

/// A plain text field, the default type.
class RegTextField extends Field {
  RegTextField({
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

/// A plain text field that provides more lines in editors.
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

/// A field for choosing between pre-defined options.
class ChoiceField extends Field {
  ChoiceField({
    required String name,
    format = '',
    initValue = '',
    prefix = '',
    suffix = '',
  }) : super(
          name: name,
          fieldType: 'Choice',
          format: format.isNotEmpty ? format : '/1/2/3/4',
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );

  @override
  bool isStoredTextValid(LeafNode node) {
    var storedText = node.data[name] ?? '';
    return storedText.isEmpty || splitChoiceFormat(format).contains(storedText);
  }

  @override
  String? validateMessage(String? text) {
    if (text != null &&
        text.isNotEmpty &&
        !splitChoiceFormat(format).contains(text)) {
      return 'Not a valid choice.';
    }
    return null;
  }
}

/// A field for choosing between previously used options or entering a new one.
class AutoChoiceField extends Field {
  final options = <String>{};

  AutoChoiceField({
    required String name,
    initValue = '',
    prefix = '',
    suffix = '',
  }) : super(
          name: name,
          fieldType: 'AutoChoice',
          format: '',
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );
}

/// A field that formats numbers and properly sorts them.
class NumberField extends Field {
  NumberField({
    required String name,
    format = '',
    initValue = '',
    prefix = '',
    suffix = '',
  }) : super(
          name: name,
          fieldType: 'Number',
          format: format.isNotEmpty ? format : '#0.##',
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );

  @override
  String _formatOutput(String storedText) {
    var numValue = num.parse(storedText);
    return NumberFormat(format).format(numValue);
  }

  @override
  bool isStoredTextValid(LeafNode node) {
    var storedText = node.data[name] ?? '';
    return storedText.isEmpty || num.tryParse(storedText) != null;
  }

  @override
  String? validateMessage(String? text) {
    if (text != null && text.isNotEmpty && num.tryParse(text) == null)
      return 'Not a valid number entry.';
    return null;
  }

  @override
  int compareNodes(Node firstNode, Node secondNode) {
    var firstValue = num.parse(firstNode.data[name] ?? '0');
    var secondValue = num.parse(secondNode.data[name] ?? '0');
    return firstValue.compareTo(secondValue);
  }
}

/// A field that formats date values.
class DateField extends Field {
  DateField({
    required String name,
    format = '',
    // An [initValue] of 'now' is supported.
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
  String? initialValue() {
    if (initValue == 'now')
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    return null;
  }

  @override
  bool isStoredTextValid(LeafNode node) {
    var storedText = node.data[name] ?? '';
    try {
      if (storedText.isNotEmpty) DateFormat('yyyy-MM-dd').parse(storedText);
    } on FormatException {
      return false;
    }
    return true;
  }

  @override
  int compareNodes(Node firstNode, Node secondNode) {
    var firstValue = _parseStored(firstNode.data[name] ?? '0001-01-01');
    var secondValue = _parseStored(secondNode.data[name] ?? '0001-01-01');
    return firstValue.compareTo(secondValue);
  }
}

/// A field that formats time of day values.
class TimeField extends Field {
  TimeField({
    required String name,
    format = '',
    // An [initValue] of 'now' is supported.
    initValue = '',
    prefix = '',
    suffix = '',
  }) : super(
          name: name,
          fieldType: 'Time',
          format: format.isNotEmpty ? format : 'h:mm a',
          initValue: initValue,
          prefix: prefix,
          suffix: suffix,
        );

  DateTime _parseStored(String storedText) {
    return DateFormat('HH:mm:ss.S').parse(storedText);
  }

  @override
  String _formatOutput(String storedText) {
    var time = _parseStored(storedText);
    var timeString = DateFormat(format).format(time);
    return prefix + timeString + suffix;
  }

  @override
  String? initialValue() {
    if (initValue == 'now')
      return DateFormat('HH:mm:ss.S').format(DateTime.now());
    return null;
  }

  @override
  bool isStoredTextValid(LeafNode node) {
    var storedText = node.data[name] ?? '';
    try {
      if (storedText.isNotEmpty) DateFormat('HH:mm:ss.S').parse(storedText);
    } on FormatException {
      return false;
    }
    return true;
  }

  @override
  int compareNodes(Node firstNode, Node secondNode) {
    var firstValue = _parseStored(firstNode.data[name] ?? '00:00:00.000');
    var secondValue = _parseStored(secondNode.data[name] ?? '00:00:00.000');
    return firstValue.compareTo(secondValue);
  }
}
