// treeline_import.dart, translations to import a node type from TreeLine files.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert' show json;
import 'dart:io' show File;
import 'field_format_tools.dart';
import 'fields.dart';
import 'nodes.dart';
import 'parsed_line.dart';
import 'structure.dart';

/// Main class for TreeLine file imports.
class TreeLineImport {
  late final dynamic jsonData;

  TreeLineImport(File fileObj) {
    jsonData = json.decode(fileObj.readAsStringSync());
  }

  List<String> formatNames() {
    return [for (var format in jsonData['formats']) format['formatname'] ?? ''];
  }

  void convertNodeType(String typeName, Structure model) {
    var boolFieldNames = <String>{};
    var formatData = jsonData['formats']
        .firstWhere((item) => item['formatname'] == typeName);
    for (var fieldData in formatData['fields'] ?? []) {
      if (fieldData['fieldtype'] == 'Boolean') {
        fieldData['fieldtype'] = 'Choice';
        boolFieldNames.add(fieldData['fieldname']);
      }
      var field = Field.fromJson(fieldData);
      model.fieldMap[field.name] = field;
      if (field.fieldType == 'Date' || field.fieldType == 'Time') {
        field.format = _adjustDateTimeFormat(field.format);
      }
    }
    model.titleLine = ParsedLine(formatData['titleline'] ?? '', model.fieldMap);
    for (var lineString in formatData['outputlines'] ?? []) {
      model.outputLines.add(ParsedLine(lineString ?? '', model.fieldMap));
    }
    for (var nodeInfo in jsonData['nodes']) {
      if (nodeInfo['format'] == typeName && nodeInfo['data'] != null) {
        var leafNode = LeafNode.fromJson(nodeInfo['data'], model);
        model.leafNodes.add(leafNode);
        for (var field in model.fieldMap.values) {
          if (leafNode.data[field.name] != null) {
            if (field is AutoChoiceField) {
              field.options.add(leafNode.data[field.name]!);
            } else if (boolFieldNames.contains(field.name)) {
              if ({'true', 'yes'}
                  .contains(leafNode.data[field.name]!.toLowerCase())) {
                leafNode.data[field.name] = splitChoiceFormat(field.format)[0];
              } else {
                leafNode.data[field.name] = splitChoiceFormat(field.format)[1];
              }
            } else if (!field.isStoredTextValid(leafNode)) {
              leafNode.data.remove(field.name);
            }
          }
        }
      }
    }
    var root = TitleNode(title: 'Root', modelRef: model);
    root.isOpen = true;
    model.rootNodes.add(root);
    root.childRuleNode = RuleNode(
      rule: 'All Nodes',
      modelRef: model,
      parent: root,
    );
  }
}

String _adjustDateTimeFormat(String origFormat) {
  final replacements = const {
    '%-d': 'd',
    '%d': 'dd',
    '%a': 'EEE',
    '%A': 'EEEE',
    '%-m': 'M',
    '%m': 'MM',
    '%b': 'MMM',
    '%B': 'MMMM',
    '%y': 'yy',
    '%Y': 'yyyy',
    '%-j': 'D',
    '%-H': 'H',
    '%H': 'HH',
    '%-I': 'h',
    '%I': 'hh',
    '%-M': 'm',
    '%M': 'mm',
    '%-S': 's',
    '%S': 'ss',
    '%f': 'S',
    '%p': 'a',
    '%%': "'%'",
  };
  var regExp = RegExp(r'%-?[daAmbByYjHIMSfp%]');
  var newFormat = origFormat.replaceAllMapped(
      regExp,
      (Match m) => replacements[m.group(0)] != null
          ? "'${replacements[m.group(0)]}'"
          : m.group(0)!);
  newFormat = "'$newFormat'";
  newFormat = newFormat.replaceAll("''", "");
  return newFormat;
}
