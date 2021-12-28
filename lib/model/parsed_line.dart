// parsed_line.dart, a class to parse and output lines with field content.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'fields.dart';
import 'nodes.dart';

/// A single line of output, broken into fields and static text.
class ParsedLine {
  var segments = <LineSegment>[];

  ParsedLine(String unparsedLine, Map<String, Field> fieldMap) {
    parseLine(unparsedLine, fieldMap);
  }

  ParsedLine.fromSingleField(Field field) {
    segments.add(LineSegment(field: field));
  }

  ParsedLine.empty();

  ParsedLine copy() {
    var newParsedLine = ParsedLine.empty();
    for (var segment in segments) {
      newParsedLine.segments.add(segment._copy());
    }
    return newParsedLine;
  }

  void parseLine(String unparsedLine, Map<String, Field> fieldMap) {
    segments.clear();
    var start = 0;
    var regExp = RegExp(r'{\*([\w_\-.]+)(:\d+)?\*}');
    for (var match in regExp.allMatches(unparsedLine, start)) {
      if (match.start > start)
        segments
            .add(LineSegment(text: unparsedLine.substring(start, match.start)));
      var field = fieldMap[match.group(1)];
      if (field != null) {
        var altFieldStr = match.group(2);
        if (altFieldStr != null) {
          var altField =
              field.altFormatField(int.parse(altFieldStr.substring(1)));
          if (altField != null) field = altField;
        }
        segments.add(LineSegment(field: field));
      } else {
        segments.add(LineSegment(text: match.group(0)!));
      }
      start = match.end;
    }
    if (start < unparsedLine.length)
      segments.add(LineSegment(text: unparsedLine.substring(start)));
  }

  String formattedLine(LeafNode node) {
    var result = StringBuffer();
    var fieldsBlank = true;
    for (var segment in segments) {
      var text = segment.output(node);
      if (text.isNotEmpty) {
        if (segment.hasField) fieldsBlank = false;
        result.write(text);
      }
    }
    if (fieldsBlank && segments.any((s) => s.hasField)) return '';
    return result.toString();
  }

  String getUnparsedLine() {
    var result = StringBuffer();
    for (var segment in segments) {
      result.write(segment.unparsedKey());
    }
    return result.toString();
  }

  List<Field> fields() {
    return List.of(segments.where((s) => s.hasField).map((s) => s.field!));
  }

  bool hasMultipleFields() {
    return fields().toSet().length > 1;
  }

  void deleteField(Field field, {Field? replacement}) {
    if (fields().contains(field)) {
      if (hasMultipleFields()) {
        var pos = segments.indexWhere((s) => s.field == field);
        while (pos >= 0) {
          // Remove prefix and suffix text if applicable
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

  List<TextSpan> richLineSpans(TextStyle fieldStyle) {
    var spans = <TextSpan>[];
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

  LineSegment({this.field, this.text});

  bool get hasField => field != null;

  String output(LeafNode node) {
    if (field != null) return field!.outputText(node);
    return text ?? '';
  }

  String unparsedKey() {
    if (field != null) return field!.lineText();
    return text ?? '';
  }

  TextSpan richText(TextStyle fieldStyle) {
    if (field != null) return TextSpan(text: field!.name, style: fieldStyle);
    return TextSpan(text: text ?? '');
  }

  LineSegment _copy() {
    var newSegment = LineSegment();
    newSegment.field = field;
    newSegment.text = text;
    return newSegment;
  }
}
