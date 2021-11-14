// parsed_line.dart, a class to parse and output lines with field content.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'fields.dart';
import 'nodes.dart';

/// A single line of output, broken into fields and static text.
class ParsedLine {
  var _textSegments = <String>[];
  var lineFields = <Field>[];

  ParsedLine(String unparsedLine, Map<String, Field> fieldMap) {
    parseLine(unparsedLine, fieldMap);
  }

  ParsedLine.fromSingleField(Field field) {
    lineFields = [field];
    _textSegments = ['', ''];
  }

  void parseLine(String unparsedLine, Map<String, Field> fieldMap) {
    _textSegments.clear();
    lineFields.clear();
    var start = 0;
    var regExp = RegExp(r'{\*([\w_\-.]+)(:\d+)?\*}');
    for (var match in regExp.allMatches(unparsedLine, start)) {
      _textSegments.add(unparsedLine.substring(start, match.start));
      var field = fieldMap[match.group(1)];
      if (field != null) {
        var altFieldStr = match.group(2);
        if (altFieldStr != null) {
          var altField =
              field.altFormatField(int.parse(altFieldStr.substring(1)));
          if (altField != null) field = altField;
        }
        lineFields.add(field);
      } else {
        _textSegments.add(match.group(0)!);
      }
      start = match.end;
    }
    _textSegments.add(unparsedLine.substring(start));
  }

  String formattedLine(LeafNode node) {
    var initText = _textSegments[0];
    var result = StringBuffer(initText);
    var fieldsBlank = true;
    for (var i = 0; i < lineFields.length; i++) {
      var fieldText = lineFields[i].outputText(node);
      if (fieldText.length > 0) {
        fieldsBlank = false;
        result.write(fieldText);
      }
      var formText = _textSegments[i + 1];
      result.write(formText);
    }
    if (fieldsBlank && lineFields.length > 0) return '';
    return result.toString();
  }

  String getUnparsedLine() {
    var result = StringBuffer(_textSegments[0]);
    for (var i = 0; i < lineFields.length; i++) {
      result.write(lineFields[i].lineText());
      result.write(_textSegments[i + 1]);
    }
    return result.toString();
  }

  bool hasMultipleFields() {
    return lineFields.toSet().length > 1;
  }

  void deleteField(Field field, {Field? replacement}) {
    if (lineFields.contains(field)) {
      if (hasMultipleFields()) {
        while (lineFields.contains(field)) {
          var i = lineFields.indexOf(field);
          // Remove prefix text if field at start, otherwise remove suffix text
          _textSegments.removeAt(i == 0 ? 0 : i + 1);
          lineFields.removeAt(i);
        }
      } else if (replacement != null) {
        lineFields = [replacement];
        _textSegments = ['', ''];
      } else {
        lineFields.clear();
        _textSegments = ['NO FIELD'];
      }
    }
  }
}
