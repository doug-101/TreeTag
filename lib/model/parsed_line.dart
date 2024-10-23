// parsed_line.dart, a class to parse and output lines with field content.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'display_node.dart';
import 'fields.dart';

/// A single line of output, broken into fields and static text.
class ParsedLine {
  final segments = <LineSegment>[];

  ParsedLine(String unparsedLine, Map<String, Field> fieldMap) {
    parseLine(unparsedLine, fieldMap);
  }

  /// Create a line containing only a single field.
  ParsedLine.fromSingleField(Field field) {
    segments.add(LineSegment(field: field));
  }

  ParsedLine.empty();

  ParsedLine copy() {
    final newParsedLine = ParsedLine.empty();
    for (var segment in segments) {
      newParsedLine.segments.add(segment._copy());
    }
    return newParsedLine;
  }

  bool get isEmpty => segments.isEmpty;

  /// Replace this line by parsing [unparsedLine].
  void parseLine(String unparsedLine, Map<String, Field> fieldMap) {
    segments.clear();
    var start = 0;
    final regExp = RegExp(r'{\*([\w_\-.]+)(:\d+)?\*}');
    for (var match in regExp.allMatches(unparsedLine, start)) {
      if (match.start > start) {
        segments
            .add(LineSegment(text: unparsedLine.substring(start, match.start)));
      }
      var field = fieldMap[match.group(1)];
      if (field != null) {
        final altFieldStr = match.group(2);
        if (altFieldStr != null) {
          final altField =
              field.altFormatField(int.parse(altFieldStr.substring(1)));
          if (altField != null) field = altField;
        }
        segments.add(LineSegment(field: field));
      } else {
        segments.add(LineSegment(text: match.group(0)!));
      }
      start = match.end;
    }
    if (start < unparsedLine.length) {
      segments.add(LineSegment(text: unparsedLine.substring(start)));
    }
  }

  /// Return this line filled in with data fields from [node].
  String formattedLine(LeafNode node) {
    if (fields().any((f) => f.allowMultiples)) {
      final multiField = fields().singleWhere((f) => f.allowMultiples);
      if (multiField.separator.contains('\n')) {
        // With the multiple line separator, the output contains full lines.
        return formattedLineList(node).join(multiField.separator);
      }
    }
    final result = StringBuffer();
    var fieldsBlank = true;
    for (var segment in segments) {
      String text = '';
      final textList = segment.allOutput(node);
      // With a single line separator, only segment is repeated with multiples.
      text = textList.join(segment.field!.separator);
      if (text.isNotEmpty) {
        if (segment.hasField) fieldsBlank = false;
        result.write(text);
      }
    }
    if (fieldsBlank && segments.any((s) => s.hasField)) return '';
    return result.toString();
  }

  /// Return a list of lines filled in with all data fields from [node].
  List<String> formattedLineList(LeafNode node) {
    final results = [StringBuffer()];
    var fieldsBlank = true;
    for (var segment in segments) {
      final texts = segment.allOutput(node);
      if (texts.length == 1) {
        if (texts[0].isNotEmpty) {
          for (var buf in results) {
            buf.write(texts[0]);
          }
          if (segment.hasField) fieldsBlank = false;
        }
      } else {
        // Only one field should have multiple entries.
        assert(results.length == 1);
        while (results.length < texts.length) {
          results.add(StringBuffer(results[0].toString()));
        }
        for (var i = 0; i < texts.length; i++) {
          results[i].write(texts[i]);
        }
        fieldsBlank = false;
      }
    }
    if (fieldsBlank && segments.any((s) => s.hasField)) return [''];
    return results.map((s) => s.toString()).toList();
  }

  String getUnparsedLine() {
    final result = StringBuffer();
    for (var segment in segments) {
      result.write(segment.unparsedKey());
    }
    return result.toString();
  }

  List<Field> fields() {
    return List.of(segments.where((s) => s.hasField).map((s) => s.field!));
  }

  bool hasMultipleFields() {
    return fields().map((field) => field.name).toSet().length > 1;
  }

  bool hasMultiplesAllowedField() {
    return fields().any((field) => field.allowMultiples);
  }

  /// Remove the [field] from this line.
  ///
  /// Replace the [field] with [replacement] if given if there are no other
  /// fields present.
  void deleteField(Field field, {Field? replacement}) {
    if (fields().contains(field)) {
      if (hasMultipleFields()) {
        var pos = segments.indexWhere((s) => s.field == field);
        while (pos >= 0) {
          // Combine prefix and suffix text around deleted field if applicable.
          if (pos > 0 &&
              pos < segments.length - 1 &&
              !segments[pos - 1].hasField &&
              !segments[pos + 1].hasField) {
            segments[pos - 1].text =
                segments[pos - 1].text! + segments[pos + 1].text!;
            segments.removeAt(pos + 1);
          }
          segments.removeAt(pos);
          pos = segments.indexWhere((s) => s.field == field);
        }
      } else if (replacement != null) {
        var pos = segments.indexWhere((s) => s.field == field);
        segments[pos] = LineSegment(field: replacement);
      } else {
        segments.clear();
        segments[0] = LineSegment(text: 'NO FIELD');
      }
    }
  }

  void replaceField(Field oldField, Field newField) {
    for (var s in segments) {
      s.replaceField(oldField, newField);
    }
  }

  /// Return this line as Flutter text spans using [fieldStyle] for field names.
  List<TextSpan> richLineSpans(TextStyle fieldStyle) {
    final spans = <TextSpan>[];
    for (var segment in segments) {
      spans.add(segment.richText(fieldStyle));
    }
    return spans;
  }
}

/// A portion of the output line, either a field or text.
class LineSegment {
  Field? field;
  String? text;

  /// Either a field or a text sring should be supplied (not both).
  LineSegment({this.field, this.text});

  bool get hasField => field != null;

  List<String> allOutput(LeafNode node) {
    if (field != null) return field!.allOutputText(node);
    return [text ?? ''];
  }

  String unparsedKey() {
    if (field != null) return field!.lineText();
    return text ?? '';
  }

  /// Return a Flutter text span using [fieldStyle] for a field name.
  TextSpan richText(TextStyle fieldStyle) {
    if (field != null) return TextSpan(text: field!.name, style: fieldStyle);
    return TextSpan(text: text ?? '');
  }

  /// Replace [oldField] with [newField] if applicable.
  ///
  /// Return true if changed.
  bool replaceField(Field oldField, Field newField) {
    if (field != null && field!.name == oldField.name) {
      field = newField;
      return true;
    }
    return false;
  }

  LineSegment _copy() {
    final newSegment = LineSegment();
    newSegment.field = field;
    newSegment.text = text;
    return newSegment;
  }
}
