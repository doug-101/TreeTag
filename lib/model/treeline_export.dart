// treeline_export.dart, translations to export a tree to a TreeLine file.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert' show HtmlEscape, HtmlEscapeMode;
import 'package:uuid/uuid.dart';
import 'display_node.dart';
import 'field_format_tools.dart';
import 'structure.dart';

/// Main class for exports to TreeLine files.
class TreeLineExport {
  final Structure model;

  TreeLineExport(this.model);

  Map<String, dynamic> jsonData() {
    var headingFormat = <String, dynamic>{
      'formatname': 'HEADING',
      'fields': [
        {'fieldname': 'Title', 'fieldtype': 'Text'},
      ],
      'titleline': '{*Title*}',
      'outputlines': ['{*Title*}'],
    };
    final fieldData = <Map<String, dynamic>>[];
    for (var field in model.fieldMap.values) {
      final data = field.toJson();
      if (field.fieldType == 'LongText' || field.allowMultiples) {
        // TreeLine can't handle multiple field values, so fall back to text.
        data['fieldtype'] = 'Text';
        data.remove('format');
      } else if (field.fieldType == 'Date') {
        data['format'] = _adjustDateFormat(field.format);
      } else if (field.fieldType == 'Time') {
        data['format'] = _adjustTimeFormat(field.format);
      }
      if (data['initvalue'] != null) {
        data['init'] = data['initvalue'];
        data.remove('initvalue');
      }
      data.remove('separator');
      data.remove('allow_multiples');
      fieldData.add(data);
    }
    final leafFormat = <String, dynamic>{
      'formatname': 'LEAF',
      'fields': fieldData,
      'titleline': model.titleLine.getUnparsedLine(),
      'outputlines': [
        for (var line in model.outputLines) line.getUnparsedLine(),
      ],
    };
    const uuid = Uuid();
    final nodeIDs = <DisplayNode, String>{};
    for (var root in model.rootNodes) {
      for (var node in allNodeGenerator(root)) {
        nodeIDs.putIfAbsent(node, () => uuid.v1().replaceAll('-', ''));
      }
    }
    final nodeData = <Map<String, dynamic>>[];
    const htmlEscape = HtmlEscape(HtmlEscapeMode.attribute);
    for (var entry in nodeIDs.entries) {
      final node = entry.key;
      final uid = entry.value;
      Map<String, String> data;
      if (node is LeafNode) {
        data = {};
        for (var field in model.fieldMap.values) {
          var value = node.data[field.name]?.join(', ');
          if (value != null) data[field.name] = htmlEscape.convert(value);
        }
      } else {
        data = {'Title': node.title};
      }
      nodeData.add({
        'format': node is LeafNode ? 'LEAF' : 'HEADING',
        'uid': uid,
        'data': data,
        'children': [for (var child in node.childNodes()) nodeIDs[child]],
      });
    }
    final topNodes = [for (var node in model.rootNodes) nodeIDs[node]];
    return <String, dynamic>{
      'formats': [headingFormat, leafFormat],
      'nodes': nodeData,
      'properties': <String, dynamic>{'topnodes': topNodes},
    };
  }
}

/// Change the Date field formats to match the Python tags.
String _adjustDateFormat(String origFormat) {
  const replacements = {
    'yyyy': '%Y',
    'yy': '%y',
    'MMMM': '%B',
    'MMM': '%b',
    'MM': '%m',
    'M': '%-m',
    'dd': '%d',
    'd': '%-d',
    'EEEE': '%A',
    'EEE': '%a',
    'D': '%-j',
  };
  final result = StringBuffer();
  for (var segment in parseFieldFormat(origFormat, dateFormatMap)) {
    if (segment.formatCode != null) {
      final replace = replacements[segment.formatCode];
      if (replace != null) result.write(replace);
    } else if (segment.extraText != null) {
      result.write(segment.extraText);
    }
  }
  return result.toString();
}

/// Change the Time field formats to match the Python tags.
String _adjustTimeFormat(String origFormat) {
  const replacements = {
    'hh': '%I',
    'h': '%-I',
    'HH': '%H',
    'H': '%-H',
    'mm': '%M',
    'm': '%-M',
    'ss': '%S',
    's': '%-S',
    'S': '%f',
    'a': '%p',
  };
  final result = StringBuffer();
  for (var segment in parseFieldFormat(origFormat, timeFormatMap)) {
    if (segment.formatCode != null) {
      final replace = replacements[segment.formatCode];
      if (replace != null) result.write(replace);
    } else if (segment.extraText != null) {
      result.write(segment.extraText);
    }
  }
  return result.toString();
}
