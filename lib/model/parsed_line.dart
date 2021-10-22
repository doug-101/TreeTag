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

  void parseLine(String unparsedLine, Map<String, Field> fieldMap) {
    _textSegments.clear();
    lineFields.clear();
    var start = 0;
    var regExp = RegExp(r'{\*([\w_\-.]+)\*}');
    for (var match in regExp.allMatches(unparsedLine, start)) {
      _textSegments.add(unparsedLine.substring(start, match.start));
      if (fieldMap.containsKey(match.group(1))) {
        lineFields.add(fieldMap[match.group(1)!]!);
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
}
