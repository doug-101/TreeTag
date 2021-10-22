// struct.dart, top level storage for the tree model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert' show json;
import 'dart:io' show File;
import 'package:flutter/foundation.dart'; // contains ChangeNotifier

import 'fields.dart';
import 'nodes.dart';
import 'parsed_line.dart';

/// Top-level storage for tree formats and nodes.
class Structure extends ChangeNotifier {
  var rootNodes = <Node>[];
  var leafNodes = <LeafNode>[];
  var obsoleteNodes = <Node>{};
  var fieldMap = <String, Field>{};
  late ParsedLine titleLine;
  var outputLines = <ParsedLine>[];
  var fileObject = File('.');

  Structure() {
    titleLine = ParsedLine('', fieldMap);
  }

  void openFile(File fileObj) {
    clearModel();
    fileObject = fileObj;
    var jsonData = json.decode(fileObj.readAsStringSync());
    for (var fieldData in jsonData['fields'] ?? []) {
      var field = Field.fromJson(fieldData);
      fieldMap[field.name] = field;
    }
    for (var nodeData in jsonData['template'] ?? []) {
      rootNodes.add(Node(nodeData, this));
    }
    if (rootNodes.length == 1) rootNodes[0].isOpen = true;
    titleLine = ParsedLine(jsonData['titleline'] ?? '', fieldMap);
    for (var lineString in jsonData['outputlines'] ?? []) {
      outputLines.add(ParsedLine(lineString ?? '', fieldMap));
    }
    for (var leaf in jsonData['leaves'] ?? []) {
      leafNodes.add(LeafNode.fromJson(leaf, this));
    }
  }

  void newFile(File fileObj) {
    clearModel();
    fileObject = fileObj;
    const mainFieldName = 'Name';
    fieldMap[mainFieldName] = Field(name: mainFieldName);
    const categoryFieldName = 'Category';
    fieldMap[categoryFieldName] = Field(name: categoryFieldName);
    var root = TitleNode(title: 'Root', modelRef: this);
    root.isOpen = true;
    rootNodes.add(root);
    root.childRuleNode = RuleNode(
        rule: fieldMap[categoryFieldName]!.lineText(),
        modelRef: this,
        parent: root);
    leafNodes.add(LeafNode(data: {
      mainFieldName: 'Sample Node',
      categoryFieldName: 'First Category',
    }, modelRef: this));
    titleLine = ParsedLine(fieldMap[mainFieldName]!.lineText(), fieldMap);
    outputLines.add(ParsedLine(
        fieldMap[mainFieldName]!.lineText() +
            '\n' +
            fieldMap[categoryFieldName]!.lineText(),
        fieldMap));
    saveFile();
  }

  void clearModel() {
    rootNodes = [];
    leafNodes = [];
    obsoleteNodes = {};
    fieldMap = {};
    titleLine = ParsedLine('', fieldMap);
    outputLines = [];
  }

  void saveFile() async {
    var jsonData = await <String, dynamic>{
      'template': [for (var root in rootNodes) root.toJson()]
    };
    jsonData['fields'] =
        await [for (var field in fieldMap.values) field.toJson()];
    jsonData['titleline'] = titleLine.getUnparsedLine();
    jsonData['outputlines'] =
        await [for (var line in outputLines) line.getUnparsedLine()];
    jsonData['leaves'] = await [for (var leaf in leafNodes) leaf..toJson()];
    await fileObject.writeAsString(json.encode(jsonData));
  }

  void toggleNodeOpen(Node node) {
    node.isOpen = !node.isOpen;
    notifyListeners();
  }

  LeafNode newNode({Node? copyFromNode}) {
    var data = Map<String, String>.of(copyFromNode?.data ?? <String, String>{});
    if (copyFromNode is GroupNode) {
      while (copyFromNode?.parent is GroupNode) {
        copyFromNode = copyFromNode?.parent;
        data.addAll(copyFromNode?.data ?? {});
      }
    }
    var newNode = LeafNode(data: data, modelRef: this);
    leafNodes.add(newNode);
    return newNode;
  }

  void deleteNode(Node node) {
    leafNodes.remove(node);
    updateAllChildren();
    obsoleteNodes.add(node);
    notifyListeners();
    saveFile();
  }

  void updateAll() {
    updateAllChildren();
    notifyListeners();
    saveFile();
  }

  void updateAllChildren({bool forceUpdate = true}) {
    obsoleteNodes.clear();
    for (var root in rootNodes) {
      updateChildren(root, forceUpdate: forceUpdate);
    }
  }
}

void updateChildren(Node node, {bool forceUpdate = true}) {
  if (node.isOpen) {
    if (node.isStale) {
      forceUpdate = true;
      node.isStale = false;
    }
    for (var child in node.childNodes(forceUpdate: forceUpdate)) {
      updateChildren(child, forceUpdate: forceUpdate);
    }
  } else if (forceUpdate && node.hasChildren) {
    node.isStale == true;
  }
}

class LeveledNode {
  late final Node node;
  late final int level;

  LeveledNode(this.node, this.level);
}

Iterable<LeveledNode> nodeGenerator(Node node,
    {int level = 0, bool forceUpdate = false}) sync* {
  yield LeveledNode(node, level);
  if (node.isOpen) {
    if (node.isStale) {
      forceUpdate = true;
      node.isStale = false;
    }
    for (var child in node.childNodes(forceUpdate: forceUpdate)) {
      yield* nodeGenerator(child, level: level + 1, forceUpdate: forceUpdate);
    }
  } else if (forceUpdate && node.hasChildren) {
    node.isStale == true;
  }
}

void main(List<String> args) {
  var struct = Structure();
  struct.openFile(File(args[0]));
  for (var root in struct.rootNodes) {
    for (var leveledNode in nodeGenerator(root)) {
      print('   ' * leveledNode.level + leveledNode.node.title);
    }
  }
}
