// csv_export.dart, translations to export tree data to a CSV table.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:csv/csv.dart';
import 'structure.dart';

/// Main class for exports to CSV tables.
class CsvExport {
  final Structure model;

  CsvExport(this.model);

  /// Check for fields with formats for raw vs. output string options.
  bool hasFieldFormats() {
    return model.fieldMap.values.any((field) => field.format.isNotEmpty);
  }

  /// Convert the structure to CSV and return the result.
  String csvString({bool useOutput = false}) {
    var rows = [
      [for (var field in model.fieldMap.values) field.name]
    ];
    for (var node in model.leafNodes) {
      final row = <String>[];
      for (var field in model.fieldMap.values) {
        final text =
            useOutput ? field.outputText(node) : node.data[field.name] ?? '';
        row.add(text);
      }
      rows.add(row);
    }
    return ListToCsvConverter().convert(rows);
  }
}
