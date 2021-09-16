// struct.dart, top level storage for the tree model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert' show jsonDecode, HtmlEscape;
import 'dart:io' show File;

import 'fields.dart';
import 'nodes.dart';
import 'parsed_line.dart';

/// Top-level storage for tree formats and nodes.
var rootNodes = <Node>[];
var leafNodes = <LeafNode>[];
var fieldMap = <String, Field>{};
late ParsedLine titleLine;
var outputLines = <ParsedLine>[];

void openFile(String filename) {
  resetVars();
  var jsonData = jsonDecode(File(filename).readAsStringSync());
  for (var fieldData in jsonData['fields'] ?? []) {
    var field = Field(fieldData);
    fieldMap[field.name] = field;
  }
  for (var nodeData in jsonData['template'] ?? []) {
    rootNodes.add(Node(nodeData));
  }
  if (rootNodes.length == 1) rootNodes[0].isOpen = true;
  titleLine = ParsedLine(jsonData['titleline'] ?? '', fieldMap);
  for (var lineString in jsonData['outputlines'] ?? []) {
    outputLines.add(ParsedLine(lineString ?? '', fieldMap));
  }
  for (var leaf in jsonData['leaves'] ?? []) {
    leafNodes.add(LeafNode(leaf));
  }
}

void resetVars() {
  rootNodes.clear();
  leafNodes.clear();
  fieldMap.clear();
  outputLines.clear();
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
    for (var child in node.childNodes(forceUpdate: forceUpdate)) {
      yield* nodeGenerator(child, level: level + 1);
    }
  }
}

void main(List<String> args) {
  openFile(args[0]);
  for (var root in rootNodes) {
    for (var leveledNode in nodeGenerator(root)) {
      print('   ' * leveledNode.level + leveledNode.node.title);
    }
  }
}
