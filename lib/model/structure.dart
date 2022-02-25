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
import 'undos.dart';

/// Top-level storage for tree formats and nodes.
class Structure extends ChangeNotifier {
  var rootNodes = <Node>[];
  var leafNodes = <LeafNode>[];
  var obsoleteNodes = <Node>{};
  var fieldMap = <String, Field>{};
  late ParsedLine titleLine;
  var outputLines = <ParsedLine>[];
  var fileObject = File('.');
  late UndoList undoList;

  Structure() {
    titleLine = ParsedLine('', fieldMap);
    undoList = UndoList(this);
  }

  void openFile(File fileObj) {
    clearModel();
    var autoChoiceFields = <AutoChoiceField>[];
    fileObject = fileObj;
    var jsonData = json.decode(fileObj.readAsStringSync());
    for (var fieldData in jsonData['fields'] ?? []) {
      var field = Field.fromJson(fieldData);
      fieldMap[field.name] = field;
      if (field is AutoChoiceField) autoChoiceFields.add(field);
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
    if (autoChoiceFields.isNotEmpty) {
      for (var leaf in leafNodes) {
        for (var field in autoChoiceFields) {
          if (leaf.data[field.name] != null)
            field.options.add(leaf.data[field.name]!);
        }
      }
    }
    undoList = UndoList.fromJson(jsonData['undos'] ?? [], this);
  }

  void newFile(File fileObj) {
    clearModel();
    fileObject = fileObj;
    const mainFieldName = 'Name';
    fieldMap[mainFieldName] = Field.createField(name: mainFieldName);
    const categoryFieldName = 'Category';
    fieldMap[categoryFieldName] = Field.createField(name: categoryFieldName);
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
    undoList = UndoList(this);
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
    jsonData['undos'] = await undoList.toJson();
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
    for (var field in fieldMap.values) {
      var initValue = field.initialValue();
      if (initValue != null) newNode.data[field.name] = initValue;
    }
    leafNodes.add(newNode);
    return newNode;
  }

  void editNodeData(LeafNode node, Map<String, String> nodeData,
      {bool newNode = false}) {
    if (newNode) {
      undoList
          .add(UndoAddLeafNode('Add new leaf node', leafNodes.indexOf(node)));
    } else {
      undoList.add(UndoEditLeafNode(
          'Edit leaf node: ${node.title}', leafNodes.indexOf(node), node.data));
    }
    node.data = nodeData;
    updateAll();
  }

  void deleteNode(LeafNode node, {bool withUndo = true}) {
    if (withUndo)
      undoList.add(
        UndoDeleteLeafNode(
            'Delete leaf node: ${node.title}', leafNodes.indexOf(node), node),
      );
    leafNodes.remove(node);
    updateAllChildren();
    obsoleteNodes.add(node);
    notifyListeners();
    saveFile();
  }

  void addNewField(Field field) {
    fieldMap[field.name] = field;
    updateRuleChildSortFields();
    updateAll();
  }

  void editField(Field oldField, Field editedField,
      {bool removeChoices = false}) {
    if (oldField.name != editedField.name) {
      // Field was renamed.
      fieldMap.remove(oldField.name);
      fieldMap[editedField.name] = oldField;
      for (var leaf in leafNodes) {
        var data = leaf.data[oldField.name];
        if (data != null) {
          leaf.data[editedField.name] = data;
          leaf.data.remove(oldField.name);
        }
      }
    }
    oldField.updateSettings(editedField);
    if (removeChoices) {
      for (var leaf in leafNodes) {
        if (!oldField.isStoredTextValid(leaf)) leaf.data.remove(oldField.name);
      }
    }
    updateAll();
  }

  // Used for field type changes.
  void replaceField(Field oldField, Field newField) {
    if (oldField.name != newField.name) {
      for (var leaf in leafNodes) {
        var data = leaf.data[oldField.name];
        if (data != null) {
          leaf.data[newField.name] = data;
          leaf.data.remove(oldField.name);
        }
      }
    }
    fieldMap.remove(oldField.name);
    fieldMap[newField.name] = newField;
    if (isFieldInTitle(oldField)) titleLine.replaceField(oldField, newField);
    if (isFieldInOutput(oldField)) {
      for (var line in outputLines.toList()) {
        line.replaceField(oldField, newField);
      }
    }
    for (var root in rootNodes) {
      for (var item in storedNodeGenerator(root)) {
        if (item.node is RuleNode) {
          (item.node as RuleNode).ruleLine.replaceField(oldField, newField);
        }
      }
    }
    for (var leaf in leafNodes) {
      if (!newField.isStoredTextValid(leaf)) leaf.data.remove(newField.name);
    }
    updateAll();
  }

  void deleteField(Field field) {
    fieldMap.remove(field.name);
    for (var leaf in leafNodes) {
      leaf.data.remove(field.name);
    }
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
          if (rule.isFieldInChildSort(field)) {
            rule.removeChildSortField(field);
          }
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
    updateRuleChildSortFields();
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
    updateRuleChildSortFields();
    notifyListeners();
    saveFile();
  }

  void updateRuleChildSortFields() {
    for (var root in rootNodes) {
      for (var item in storedNodeGenerator(root)) {
        if (item.node is RuleNode) {
          (item.node as RuleNode).setDefaultChildSortFields();
        }
      }
    }
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

  bool isFieldInData(Field field) {
    for (var leaf in leafNodes) {
      if (leaf.data.containsKey(field.name)) return true;
    }
    return false;
  }

  int badFieldCount(Field field) {
    var count = 0;
    for (var leaf in leafNodes) {
      if (!field.isStoredTextValid(leaf)) count++;
    }
    return count;
  }

  String storedNodeId(Node? node) {
    if (node == null) return '';
    var posList = <int>[];
    while (node!.parent != null) {
      posList.insert(0, node.parent!.storedChildren().indexOf(node));
      assert(posList[0] != -1);
      node = node.parent;
    }
    posList.insert(0, rootNodes.indexOf(node));
    assert(posList[0] != -1);
    return posList.join('.');
  }

  Node? storedNodeFromId(String id) {
    if (id.isEmpty) return null;
    var posList = [for (var i in id.split('.')) int.parse(i)];
    var node = rootNodes[posList.removeAt(0)];
    while (posList.isNotEmpty) {
      node = node.storedChildren()[posList.removeAt(0)];
    }
    return node;
  }

  int storedNodePos(Node node) {
    var parent = node.parent;
    if (parent != null) return parent.storedChildren().indexOf(node);
    return rootNodes.indexOf(node);
  }

  void addTitleSibling(TitleNode siblingNode, String newTitle) {
    var parent = siblingNode.parent as TitleNode;
    var pos = storedNodePos(siblingNode) + 1;
    undoList.add(
        UndoAddTreeNode('Add title sibling node', storedNodeId(parent), pos));
    var newNode = TitleNode(title: newTitle, modelRef: this, parent: parent);
    if (parent != null) {
      parent.addChildTitleNode(newNode, pos: pos);
    } else {
      rootNodes.insert(pos, newNode);
    }
    updateAll();
  }

  void addTitleChild(TitleNode parentNode, String newTitle) {
    undoList.add(UndoAddTreeNode('Add title child node',
        storedNodeId(parentNode), parentNode.storedChildren().length));
    var newNode =
        TitleNode(title: newTitle, modelRef: this, parent: parentNode);
    parentNode.addChildTitleNode(newNode);
    updateAll();
  }

  void editTitle(TitleNode node, String newTitle) {
    undoList.add(UndoEditTitleNode(
        'Edit title node: ${node.title}', storedNodeId(node), node.title));
    node.title = newTitle;
    updateAll();
  }

  void addRuleChild(RuleNode newNode) {
    undoList.add(UndoAddTreeNode(
        'Add rule child node', storedNodeId(newNode.parent), 0));
    if (newNode.parent is TitleNode) {
      (newNode.parent! as TitleNode).childRuleNode = newNode;
    } else {
      (newNode.parent! as RuleNode).childRuleNode = newNode;
    }
    newNode.setDefaultRuleSortFields();
    updateAll();
  }

  void editRuleLine(RuleNode node, ParsedLine newRuleLine) {
    var editUndo = UndoEditRuleLine(
        'Edit rule line: ${node.ruleLine.getUnparsedLine()}',
        storedNodeId(node),
        node.ruleLine);
    node.ruleLine = newRuleLine;
    var prevSortKeys = List.of(node.sortFields);
    if (node.setDefaultRuleSortFields(checkCustom: true)) {
      // Save custom sort keys if they've changed.
      var sortUndo = UndoEditSortKeys('', storedNodeId(node), prevSortKeys,
          isCustom: node.hasCustomSortFields);
      undoList.add(UndoBatch(editUndo.title, [editUndo, sortUndo]));
    } else {
      undoList.add(editUndo);
    }
    updateAll();
  }

  void deleteTreeNode(Node node) {
    if (node is TitleNode) {
      undoList.add(UndoDeleteTreeNode('Delete title node: ${node.title}',
          storedNodeId(node.parent), storedNodePos(node), node));
      if (node.parent != null) {
        (node.parent as TitleNode).removeTitleChild(node);
      } else {
        rootNodes.remove(node);
      }
    } else {
      undoList.add(UndoDeleteTreeNode(
          'Delete rule node: ${(node as RuleNode).ruleLine.getUnparsedLine()}',
          storedNodeId(node.parent),
          storedNodePos(node),
          node));
      if (node.parent is TitleNode) {
        // Deleting a RuleNode from a TitleNode.
        (node.parent as TitleNode).replaceChildRule(null);
      } else {
        (node.parent as RuleNode).childRuleNode = null;
      }
    }
    updateAll();
  }

  void moveTitleNode(TitleNode node, {bool up = true}) {
    var siblings =
        node.parent != null ? node.parent!.storedChildren() : rootNodes;
    var pos = siblings.indexOf(node);
    undoList.add(UndoMoveTitleNode(
        'Move title node: ${node.title}', storedNodeId(node.parent), pos, up));
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

  void ruleSortKeysToDefault(RuleNode node) {
    undoList.add(UndoEditSortKeys(
        'Rule sort keys to default', storedNodeId(node), node.sortFields,
        isCustom: node.hasCustomSortFields));
    node.hasCustomSortFields = false;
    node.setDefaultRuleSortFields();
    updateAll();
  }

  void childSortKeysToDefault(RuleNode node) {
    undoList.add(UndoEditSortKeys(
        'Child sort keys to default', storedNodeId(node), node.childSortFields,
        isCustom: node.hasCustomChildSortFields, isChildSort: true));
    node.hasCustomChildSortFields = false;
    node.setDefaultChildSortFields();
    updateAll();
  }

  void updateRuleSortKeys(RuleNode node, List<SortKey> newKeys) {
    undoList.add(UndoEditSortKeys(
        'Edit rule sort keys', storedNodeId(node), node.sortFields,
        isCustom: node.hasCustomSortFields));
    node.hasCustomSortFields = true;
    node.sortFields = newKeys;
    updateAll();
  }

  void updateChildSortKeys(RuleNode node, List<SortKey> newKeys) {
    undoList.add(UndoEditSortKeys(
        'Edit child sort keys', storedNodeId(node), node.childSortFields,
        isCustom: node.hasCustomChildSortFields, isChildSort: true));
    node.hasCustomChildSortFields = true;
    node.childSortFields = newKeys;
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
      if (pos >= 0) outputLines[pos] = newLine;
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
