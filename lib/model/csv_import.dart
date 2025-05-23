// csv_import.dart, translations to import leaf node data from CSV files.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:csv/csv.dart';
import 'package:csv/csv_settings_autodetection.dart';
import 'display_node.dart';
import 'fields.dart';
import 'parsed_line.dart';
import 'stored_node.dart';
import 'structure.dart';

/// Main class for CSV file imports.
class CsvImport {
  final String strData;

  CsvImport(this.strData);

  /// Convert the CSV data in [strData] to leaf nodes in a TreeTag file.
  void convertCsv(Structure model) {
    // Detect the first EOL and quotation delimiters in the file.
    const detector = FirstOccurrenceSettingsDetector(
      eols: ['\r\n', '\n'],
      fieldDelimiters: [',', ';', '\t'],
      textDelimiters: ['"', "'"],
    );
    const converter = CsvToListConverter(
      shouldParseNumbers: false,
      allowInvalid: false,
      csvSettingsDetector: detector,
    );
    final rows = converter.convert(strData);
    for (var fieldName in rows.first) {
      // Replace all illegal characters with underscores.
      fieldName = fieldName.replaceAll(RegExp(r'\W'), '_');
      if (fieldName.isEmpty) throw const FormatException();
      var field = Field.createField(name: fieldName);
      model.fieldMap[fieldName] = field;
      model.outputLines.add(ParsedLine.fromSingleField(field));
    }
    final fieldList = List.of(model.fieldMap.values);
    // Check for duplicate fields.
    if (Set.of(fieldList).length != fieldList.length) {
      throw const FormatException();
    }
    model.titleLine = ParsedLine.fromSingleField(fieldList.first);
    rows.removeAt(0);
    for (var row in rows) {
      if (row.length > fieldList.length) throw const FormatException();
      final data = <String, List<String>>{};
      for (var i = 0; i < row.length; i++) {
        data[fieldList[i].name] = [row[i]];
      }
      model.leafNodes.add(LeafNode(data: data));
    }
    final root = TitleNode(title: 'Root');
    root.isOpen = true;
    model.rootNodes.add(root);
    root.childRuleNode = RuleNode(rule: 'All Nodes', storedParent: root);
  }
}
