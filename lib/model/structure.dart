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
    outputLines.add(ParsedLine.fromSingleField(fieldMap[mainFieldName]!));
    outputLines.add(ParsedLine.fromSingleField(fieldMap[categoryFieldName]!));
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
    jsonData['leaves'] = await [for (var leaf in leafNodes) leaf.toJson()];
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

  void editNodeData(Node node) {
    // Defined as a separate function for future undo implementation.
    updateAll();
  }

  void deleteNode(Node node) {
    leafNodes.remove(node);
    updateAllChildren();
    obsoleteNodes.add(node);
    notifyListeners();
    saveFile();
  }

  void addNewField(Field field) {
    fieldMap[field.name] = field;
    updateAll();
  }

  void editField(Field field) {
    if (!fieldMap.containsKey(field.name)) {
      // Field was renamed.
      var oldName = fieldMap.keys.firstWhere((key) => fieldMap[key] == field);
      fieldMap.remove(oldName);
      fieldMap[field.name] = field;
      for (var leaf in leafNodes) {
        var data = leaf.data[oldName];
        if (data != null) leaf.data[field.name] = data;
      }
    }
    updateAll();
  }

  void deleteField(Field field) {
    fieldMap.remove(field.name);
    if (isFieldInTitle(field))
      titleLine.deleteField(field, replacement: List.of(fieldMap.values)[0]);
    if (isFieldInOutput(field)) {
      for (var line in outputLines.toList()) {
        if (line.fields().contains(field)) {
          if (line.hasMultipleFields()) {
            line.deleteField(field);
          } else {
            outputLines.remove(line);
          }
        }
      }
      if (outputLines.isEmpty) {
        outputLines
            .add(ParsedLine.fromSingleField(List.of(fieldMap.values)[0]));
      }
    }
    var badRules = <RuleNode>[];
    for (var root in rootNodes) {
      for (var item in storedNodeGenerator(root)) {
        if (item.node is RuleNode) {
          var rule = item.node as RuleNode;
          if (rule.ruleLine.fields().contains(field)) badRules.add(rule);
        }
      }
    }
    for (var ruleNode in badRules) {
      if (ruleNode.parent != null) {
        if (ruleNode.parent is RuleNode) {
          (ruleNode.parent as RuleNode).childRuleNode = ruleNode.childRuleNode;
        } else {
          (ruleNode.parent as TitleNode)
              .replaceChildRule(ruleNode.childRuleNode);
        }
      } else {
        rootNodes.remove(ruleNode);
      }
    }
    updateAll();
  }

  void moveField(Field field, {bool up = true}) {
    var fieldList = List.of(fieldMap.values);
    var pos = fieldList.indexOf(field);
    fieldList.removeAt(pos);
    fieldList.insert(up ? --pos : ++pos, field);
    fieldMap.clear();
    for (var fld in fieldList) {
      fieldMap[fld.name] = fld;
    }
    notifyListeners();
    saveFile();
  }

  bool isFieldInTitle(Field field) {
    return titleLine.fields().contains(field);
  }

  bool isFieldInOutput(Field field) {
    for (var line in outputLines) {
      if (line.fields().contains(field)) return true;
    }
    return false;
  }

  bool isFieldInGroup(Field field) {
    for (var root in rootNodes) {
      for (var item in storedNodeGenerator(root)) {
        if (item.node is RuleNode) {
          var rule = item.node as RuleNode;
          if (rule.ruleLine.fields().contains(field)) return true;
        }
      }
    }
    return false;
  }

  void addTitleSibling(TitleNode siblingNode, String newTitle) {
    var newNode =
        TitleNode(title: newTitle, modelRef: this, parent: siblingNode.parent);
    if (siblingNode.parent != null) {
      (siblingNode.parent as TitleNode)
          .addChildTitleNode(newNode, afterChild: siblingNode);
    } else {
      var pos = rootNodes.indexOf(siblingNode) + 1;
      rootNodes.insert(pos, newNode);
    }
    updateAll();
  }

  void addTitleChild(TitleNode parentNode, String newTitle) {
    var newNode =
        TitleNode(title: newTitle, modelRef: this, parent: parentNode);
    parentNode.addChildTitleNode(newNode);
    updateAll();
  }

  void editTitle(TitleNode node, String newTitle) {
    node.title = newTitle;
    updateAll();
  }

  void editRuleLine(RuleNode node, ParsedLine newRuleLine) {
    node.ruleLine = newRuleLine;
    updateAll();
  }

  void deleteTreeNode(Node node) {
    if (node.parent == null) {
      rootNodes.remove(node);
    } else if (node is TitleNode) {
      (node.parent! as TitleNode).removeTitleChild(node);
    } else if (node.parent is TitleNode) {
      // Deleting a RuleNode from a TitleNode.
      (node.parent! as TitleNode).replaceChildRule(null);
    } else {
      (node.parent! as RuleNode).childRuleNode = null;
    }
    updateAll();
  }

  void moveTitleNode(TitleNode node, {bool up = true}) {
    var siblings =
        node.parent != null ? node.parent!.storedChildren() : rootNodes;
    var pos = siblings.indexOf(node);
    siblings.removeAt(pos);
    siblings.insert(up ? --pos : ++pos, node);
    updateAll();
  }

  bool canNodeMove(Node node, {bool up = true}) {
    if (node is! TitleNode) return false;
    var siblings =
        node.parent != null ? node.parent!.storedChildren() : rootNodes;
    var pos = siblings.indexOf(node);
    if (up && pos > 0) return true;
    if (!up && pos < siblings.length - 1) return true;
    return false;
  }

  void ruleSortKeysUpdated(RuleNode node) {
    updateAll();
  }

  void childSortKeysUpdated(RuleNode node) {
    updateAll();
  }

  void addOutputLine(int pos, ParsedLine newLine) {
    outputLines.insert(pos, newLine);
    updateAll();
  }

  void editOutputLine(ParsedLine origLine, ParsedLine newLine) {
    if (origLine == titleLine) {
      titleLine = newLine;
    } else {
      int pos = outputLines.indexOf(origLine);
      if (pos >= 0)
        outputLines[pos] = newLine;
    }
    updateAll();
  }

  void removeOutputLine(ParsedLine origLine) {
    outputLines.remove(origLine);
    updateAll();
  }

  void moveOutputLine(ParsedLine line, {bool up = true}) {
    var pos = outputLines.indexOf(line);
    outputLines.removeAt(pos);
    outputLines.insert(up ? --pos : ++pos, line);
    updateAll();
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

Iterable<LeveledNode> storedNodeGenerator(Node node, {int level = 0}) sync* {
  yield LeveledNode(node, level);
  for (var child in node.storedChildren()) {
    yield* storedNodeGenerator(child, level: level + 1);
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
