// undos.dart, stores and executes undo operations.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:collection';
import 'fields.dart';
import '../main.dart' show prefs;
import 'nodes.dart';
import 'parsed_line.dart';
import 'structure.dart';

/// Storage of an undo list with undo operations.
class UndoList extends ListBase<Undo> {
  final _innerList = <Undo>[];
  static late Structure _modelRef;

  UndoList(Structure modelRef) {
    _modelRef = modelRef;
  }

  UndoList.fromJson(List<dynamic> jsonData, Structure modelRef) {
    _modelRef = modelRef;
    addAll([for (var data in jsonData) Undo._fromJson(data)]);
  }

  int get length => _innerList.length;

  void set length(int length) {
    _innerList.length = length;
  }

  Undo operator [](int index) => _innerList[index];

  void operator []=(int index, Undo value) {
    _innerList[index] = value;
  }

  void add(Undo value) => _innerList.add(value);

  void addAll(Iterable<Undo> all) => _innerList.addAll(all);

  /// Perform an undo from the list end to [pos].
  void undoToPos(int pos) {
    var firstUndoPos = indexWhere((undo) => !undo.isRedo, pos);
    var redoList = <Undo>[];
    // Perform undos backward (last-in, first-out).
    for (int i = length - 1; i >= pos; i--) {
      // Skip and remove all redo's that come after an active undo.
      if (!this[i].isRedo || pos > firstUndoPos) {
        redoList.add(this[i].undo());
      }
    }
    removeRange(pos, length);
    addAll(redoList);
    _modelRef.updateAll();
  }

  List<dynamic> toJson() {
    var daysToStore = prefs.getInt('undodays') ?? 7;
    var cutOffDate = DateTime.now().subtract(Duration(days: daysToStore));
    return [
      for (var undo in this)
        if (undo.timeStamp.isAfter(cutOffDate)) undo.toJson()
    ];
  }
}

/// Base class for many types of undo operations.
abstract class Undo {
  /// Displayed in the undo list view for users.
  final String title;

  /// Type name in text for JSON input/output.
  final String undoType;

  final bool isRedo;
  DateTime timeStamp = DateTime.now();

  Undo(this.title, this.undoType, this.isRedo);

  factory Undo._fromJson(Map<String, dynamic> jsonData) {
    Undo undo;
    switch (jsonData['type']) {
      case 'batch':
        undo = UndoBatch._fromJson(jsonData);
        break;
      case 'editleafnode':
        undo = UndoEditLeafNode._fromJson(jsonData);
        break;
      case 'addleafnode':
        undo = UndoAddLeafNode._fromJson(jsonData);
        break;
      case 'deleteleafnode':
        undo = UndoDeleteLeafNode._fromJson(jsonData);
        break;
      case 'addnewfield':
        undo = UndoAddNewField._fromJson(jsonData);
        break;
      case 'editfield':
        undo = UndoEditField._fromJson(jsonData);
        break;
      case 'deletefield':
        undo = UndoDeleteField._fromJson(jsonData);
        break;
      case 'movefield':
        undo = UndoMoveField._fromJson(jsonData);
        break;
      case 'edittitlenode':
        undo = UndoEditTitleNode._fromJson(jsonData);
        break;
      case 'editruleline':
        undo = UndoEditRuleLine._fromJson(jsonData);
        break;
      case 'addtreenode':
        undo = UndoAddTreeNode._fromJson(jsonData);
        break;
      case 'deletetreenode':
        undo = UndoDeleteTreeNode._fromJson(jsonData);
        break;
      case 'movetitlenode':
        undo = UndoMoveTitleNode._fromJson(jsonData);
        break;
      case 'editsortkeys':
        undo = UndoEditSortKeys._fromJson(jsonData);
        break;
      case 'addoutputline':
        undo = UndoAddOutputLine._fromJson(jsonData);
        break;
      case 'removeoutputline':
        undo = UndoRemoveOutputLine._fromJson(jsonData);
        break;
      case 'editoutputline':
        undo = UndoEditOutputLine._fromJson(jsonData);
        break;
      case 'moveoutputline':
        undo = UndoMoveOutputLine._fromJson(jsonData);
        break;
      default:
        throw FormatException('Stored undo data is corrupt');
        break;
    }
    undo.timeStamp = DateTime.parse(jsonData['time']);
    return undo;
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': undoType,
      'isredo': isRedo,
      'time': timeStamp.toIso8601String(),
    };
  }

  /// Subclasses perform the undo and return an opposite redo object.
  Undo undo();

  /// Return a modified title to specify a redo in place of an undo.
  String _toggleTitleRedo(String title) {
    if (title.isEmpty) return '';
    if (title.startsWith('Redo '))
      return title.replaceRange(0, 6, title[5].toUpperCase());
    return 'Redo ${title.replaceRange(0, 1, title[0].toLowerCase())}';
  }
}

/// An undo type that groups several child undos under one parent list entry.
class UndoBatch extends Undo {
  List<Undo> storedUndos;

  UndoBatch(String title, this.storedUndos, {bool isRedo = false})
      : super(title, 'batch', isRedo);

  UndoBatch._fromJson(Map<String, dynamic> jsonData)
      : storedUndos = [
          for (var item in jsonData['children']) Undo._fromJson(item)
        ],
        super(jsonData['title'], 'batch', jsonData['isredo']);

  @override
  Undo undo() {
    var redos = [for (var undoInst in storedUndos) undoInst.undo()];
    return UndoBatch(_toggleTitleRedo(title), List.of(redos.reversed),
        isRedo: !isRedo);
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result.addAll({
      'children': [for (var undoInst in storedUndos) undoInst.toJson()]
    });
    return result;
  }
}

class UndoEditLeafNode extends Undo {
  int nodePos;
  Map<String, String> storedNodeData;

  UndoEditLeafNode(String title, this.nodePos, Map<String, String> nodeData,
      {bool isRedo = false})
      : storedNodeData = Map.of(nodeData),
        super(title, 'editleafnode', isRedo);

  UndoEditLeafNode._fromJson(Map<String, dynamic> jsonData)
      : nodePos = jsonData['nodepos'],
        storedNodeData = jsonData['nodedata'].cast<String, String>(),
        super(jsonData['title'], 'editleafnode', jsonData['isredo']);

  @override
  Undo undo() {
    var node = UndoList._modelRef.leafNodes[nodePos];
    var redo = UndoEditLeafNode(_toggleTitleRedo(title), nodePos, node.data,
        isRedo: !isRedo);
    node.data = storedNodeData;
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result.addAll({'nodepos': nodePos, 'nodedata': storedNodeData});
    return result;
  }
}

class UndoAddLeafNode extends Undo {
  int nodePos;

  UndoAddLeafNode(String title, this.nodePos, {bool isRedo = false})
      : super(title, 'addleafnode', isRedo);

  UndoAddLeafNode._fromJson(Map<String, dynamic> jsonData)
      : nodePos = jsonData['nodepos'],
        super(jsonData['title'], 'addleafnode', jsonData['isredo']);

  @override
  Undo undo() {
    var redo = UndoDeleteLeafNode(
        _toggleTitleRedo(title), nodePos, UndoList._modelRef.leafNodes[nodePos],
        isRedo: !isRedo);
    UndoList._modelRef.leafNodes.removeAt(nodePos);
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['nodepos'] = nodePos;
    return result;
  }
}

class UndoDeleteLeafNode extends Undo {
  int nodePos;
  Map<String, dynamic> nodeData;

  UndoDeleteLeafNode(String title, this.nodePos, LeafNode node,
      {bool isRedo = false})
      : nodeData = node.data,
        super(title, 'deleteleafnode', isRedo);

  UndoDeleteLeafNode._fromJson(Map<String, dynamic> jsonData)
      : nodePos = jsonData['nodepos'],
        nodeData = jsonData['nodeobject'],
        super(jsonData['title'], 'deleteleafnode', jsonData['isredo']);

  @override
  Undo undo() {
    var node = LeafNode.fromJson(nodeData, UndoList._modelRef);
    var redo =
        UndoAddLeafNode(_toggleTitleRedo(title), nodePos, isRedo: !isRedo);
    UndoList._modelRef.leafNodes.insert(nodePos, node);
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['nodepos'] = nodePos;
    result['nodeobject'] = nodeData;
    return result;
  }
}

class UndoAddNewField extends Undo {
  String fieldName;

  UndoAddNewField(String title, this.fieldName, {bool isRedo = false})
      : super(title, 'addnewfield', isRedo);

  UndoAddNewField._fromJson(Map<String, dynamic> jsonData)
      : fieldName = jsonData['fieldname'],
        super(jsonData['title'], 'addnewfield', jsonData['isredo']);

  @override
  Undo undo() {
    var redo = UndoDeleteField(
        _toggleTitleRedo(title),
        List.of(UndoList._modelRef.fieldMap.keys).indexOf(fieldName),
        UndoList._modelRef.fieldMap[fieldName]!,
        isRedo: !isRedo);
    UndoList._modelRef.fieldMap.remove(fieldName);
    UndoList._modelRef.updateRuleChildSortFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['fieldname'] = fieldName;
    return result;
  }
}

class UndoEditField extends Undo {
  int fieldPos;
  Map<String, dynamic> fieldData;

  UndoEditField(String title, this.fieldPos, Field field, {bool isRedo = false})
      : fieldData = field.toJson(),
        super(title, 'editfield', isRedo);

  UndoEditField._fromJson(Map<String, dynamic> jsonData)
      : fieldPos = jsonData['fieldpos'],
        fieldData = jsonData['field'],
        super(jsonData['title'], 'editfield', jsonData['isredo']);

  @override
  Undo undo() {
    var fieldList = List.of(UndoList._modelRef.fieldMap.values);
    var field = Field.fromJson(fieldData);
    var redoField = fieldList[fieldPos].fieldType == field.fieldType
        ? Field.copy(fieldList[fieldPos])
        : field;
    var redo = UndoEditField(_toggleTitleRedo(title), fieldPos, redoField,
        isRedo: !isRedo);
    if (field.name != fieldList[fieldPos].name) {
      // Field was renamed.
      UndoList._modelRef.fieldMap.clear();
      for (var fld in fieldList) {
        if (fld == fieldList[fieldPos]) {
          UndoList._modelRef.fieldMap[field.name] = fld;
        } else {
          UndoList._modelRef.fieldMap[fld.name] = fld;
        }
      }
    }
    if (fieldList[fieldPos].fieldType == field.fieldType) {
      fieldList[fieldPos].updateSettings(field);
    } else {
      fieldList[fieldPos] = field;
      UndoList._modelRef.fieldMap.clear();
      for (var fld in fieldList) {
        UndoList._modelRef.fieldMap[fld.name] = fld;
      }
    }
    UndoList._modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['fieldpos'] = fieldPos;
    result['field'] = fieldData;
    return result;
  }
}

class UndoDeleteField extends Undo {
  int fieldPos;
  Map<String, dynamic> fieldData;

  UndoDeleteField(String title, this.fieldPos, Field field,
      {bool isRedo = false})
      : fieldData = field.toJson(),
        super(title, 'deletefield', isRedo);

  UndoDeleteField._fromJson(Map<String, dynamic> jsonData)
      : fieldPos = jsonData['fieldpos'],
        fieldData = jsonData['field'],
        super(jsonData['title'], 'deletefield', jsonData['isredo']);

  @override
  Undo undo() {
    var field = Field.fromJson(fieldData);
    var redo =
        UndoAddNewField(_toggleTitleRedo(title), field.name, isRedo: !isRedo);
    var fieldList = List.of(UndoList._modelRef.fieldMap.values);
    fieldList.insert(fieldPos, field);
    UndoList._modelRef.fieldMap.clear();
    for (var fld in fieldList) {
      UndoList._modelRef.fieldMap[fld.name] = fld;
    }
    UndoList._modelRef.updateRuleChildSortFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['fieldpos'] = fieldPos;
    result['field'] = fieldData;
    return result;
  }
}

class UndoMoveField extends Undo {
  int fieldPos;
  bool isUp;

  UndoMoveField(String title, this.fieldPos, this.isUp, {bool isRedo = false})
      : super(title, 'movefield', isRedo);

  UndoMoveField._fromJson(Map<String, dynamic> jsonData)
      : fieldPos = jsonData['fieldpos'],
        isUp = jsonData['isup'],
        super(jsonData['title'], 'movefield', jsonData['isredo']);

  @override
  Undo undo() {
    var currFieldPos = isUp ? fieldPos - 1 : fieldPos + 1;
    var redo = UndoMoveField(_toggleTitleRedo(title), currFieldPos, !isUp,
        isRedo: !isRedo);
    var fieldList = List.of(UndoList._modelRef.fieldMap.values);
    UndoList._modelRef.fieldMap.clear();
    var field = fieldList.removeAt(currFieldPos);
    fieldList.insert(fieldPos, field);
    for (var fld in fieldList) {
      UndoList._modelRef.fieldMap[fld.name] = fld;
    }
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['fieldpos'] = fieldPos;
    result['isup'] = isUp;
    return result;
  }
}

class UndoEditTitleNode extends Undo {
  String nodeId;
  String titleText;

  UndoEditTitleNode(String title, this.nodeId, this.titleText,
      {bool isRedo = false})
      : super(title, 'edittitlenode', isRedo);

  UndoEditTitleNode._fromJson(Map<String, dynamic> jsonData)
      : nodeId = jsonData['nodeid'],
        titleText = jsonData['titletext'],
        super(jsonData['title'], 'edittitlenode', jsonData['isredo']);

  @override
  Undo undo() {
    var node = UndoList._modelRef.storedNodeFromId(nodeId) as TitleNode;
    var redo = UndoEditTitleNode(_toggleTitleRedo(title), nodeId, node.title,
        isRedo: !isRedo);
    node.title = titleText;
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['nodeid'] = nodeId;
    result['titletext'] = titleText;
    return result;
  }
}

class UndoEditRuleLine extends Undo {
  String nodeId;
  String rawRuleLine;

  UndoEditRuleLine(String title, this.nodeId, ParsedLine ruleLine,
      {bool isRedo = false})
      : rawRuleLine = ruleLine.getUnparsedLine(),
        super(title, 'editruleline', isRedo);

  UndoEditRuleLine._fromJson(Map<String, dynamic> jsonData)
      : nodeId = jsonData['nodeid'],
        rawRuleLine = jsonData['ruleline'],
        super(jsonData['title'], 'editruleline', jsonData['isredo']);

  @override
  Undo undo() {
    var node = UndoList._modelRef.storedNodeFromId(nodeId) as RuleNode;
    var redo = UndoEditRuleLine(_toggleTitleRedo(title), nodeId, node.ruleLine,
        isRedo: !isRedo);
    node.ruleLine = ParsedLine(rawRuleLine, UndoList._modelRef.fieldMap);
    node.setDefaultRuleSortFields();
    UndoList._modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['nodeid'] = nodeId;
    result['ruleline'] = rawRuleLine;
    return result;
  }
}

/// Undo class for adding [TitleNode] or [RuleNode] types.
class UndoAddTreeNode extends Undo {
  String parentId;
  int nodePos;

  /// This is used only for re-doing a delete node only, without children.
  late int replaceCount;

  UndoAddTreeNode(String title, this.parentId, this.nodePos,
      {this.replaceCount = 0, bool isRedo = false})
      : super(title, 'addtreenode', isRedo);

  UndoAddTreeNode._fromJson(Map<String, dynamic> jsonData)
      : parentId = jsonData['parentid'],
        nodePos = jsonData['nodepos'],
        replaceCount = jsonData['replacecount'] ?? 0,
        super(jsonData['title'], 'addtreenode', jsonData['isredo']);

  @override
  Undo undo() {
    var parentNode = UndoList._modelRef.storedNodeFromId(parentId);
    var node = parentNode == null
        ? UndoList._modelRef.rootNodes[nodePos]
        : parentNode.storedChildren()[nodePos];
    var redo = UndoDeleteTreeNode(
      _toggleTitleRedo(title),
      parentId,
      nodePos,
      node,
      replaceCount: replaceCount,
      isRedo: !isRedo,
    );
    if (parentNode == null) {
      if (replaceCount == 0) {
        UndoList._modelRef.rootNodes.removeAt(nodePos);
      } else {
        node.storedChildren().forEach((newNode) {
          newNode.parent = null;
        });
        UndoList._modelRef.rootNodes.replaceRange(
            nodePos, nodePos + replaceCount, node.storedChildren());
      }
    } else if (node is TitleNode) {
      var titleNode = node as TitleNode;
      var parentTitle = parentNode as TitleNode;
      if (titleNode.childRuleNode != null) {
        parentTitle.replaceChildRule(titleNode.childRuleNode);
        titleNode.replaceChildRule(null);
      }
      if (replaceCount == 0) {
        parentTitle.removeChildTitleNode(titleNode);
      } else {
        parentTitle.replaceChildTitleNode(
            titleNode, titleNode.storedChildren());
      }
    } else if (parentNode is TitleNode) {
      var ruleNode = node as RuleNode;
      var parentTitle = parentNode as TitleNode;
      if (ruleNode.childRuleNode != null) {
        parentTitle.replaceChildRule(ruleNode.childRuleNode);
      } else {
        parentTitle.replaceChildRule(null);
      }
    } else {
      var ruleNode = node as RuleNode;
      var parentRule = parentNode as RuleNode;
      if (ruleNode.childRuleNode != null) {
        parentRule.replaceChildRule(ruleNode.childRuleNode);
      } else {
        parentRule.replaceChildRule(null);
      }
    }
    UndoList._modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['parentid'] = parentId;
    result['nodepos'] = nodePos;
    result['replacecount'] = replaceCount;
    return result;
  }
}

/// Undo class for deleting [TitleNode] or [RuleNode] types.
class UndoDeleteTreeNode extends Undo {
  String parentId;
  int nodePos;
  Map<String, dynamic> nodeData;
  int replaceCount;

  UndoDeleteTreeNode(String title, this.parentId, this.nodePos, Node node,
      {this.replaceCount = 0, bool isRedo = false})
      : nodeData = node.toJson(),
        super(title, 'deletetreenode', isRedo);

  UndoDeleteTreeNode._fromJson(Map<String, dynamic> jsonData)
      : parentId = jsonData['parentid'],
        nodePos = jsonData['nodepos'],
        nodeData = jsonData['nodeobject'],
        replaceCount = jsonData['replacecount'] ?? 0,
        super(jsonData['title'], 'deletetreenode', jsonData['isredo']);

  @override
  Undo undo() {
    var redo = UndoAddTreeNode(_toggleTitleRedo(title), parentId, nodePos,
        replaceCount: replaceCount, isRedo: !isRedo);
    var node = Node(nodeData, UndoList._modelRef);
    var parentNode = UndoList._modelRef.storedNodeFromId(parentId);
    if (parentNode == null) {
      UndoList._modelRef.rootNodes
          .replaceRange(nodePos, nodePos + replaceCount, [node]);
      node.parent = null;
      (node as TitleNode).updateChildParentRefs();
    } else if (node is TitleNode) {
      var titleNode = node as TitleNode;
      var parentTitle = parentNode as TitleNode;
      if (replaceCount > 0) {
        List.of(parentTitle.storedChildren())
            .getRange(nodePos, nodePos + replaceCount)
            .forEach((child) {
          parentTitle.removeChildTitleNode(child as TitleNode);
        });
      }
      parentTitle.addChildTitleNode(node as TitleNode, pos: nodePos);
      titleNode.updateChildParentRefs();
    } else if (parentNode is TitleNode) {
      var ruleNode = node as RuleNode;
      (parentNode as TitleNode).replaceChildRule(ruleNode);
      if (ruleNode.childRuleNode != null) {
        ruleNode.childRuleNode!.parent = ruleNode;
      }
    } else {
      var ruleNode = node as RuleNode;
      (parentNode as RuleNode).replaceChildRule(ruleNode);
      if (ruleNode.childRuleNode != null) {
        ruleNode.childRuleNode!.parent = ruleNode;
      }
    }
    UndoList._modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['parentid'] = parentId;
    result['nodepos'] = nodePos;
    result['nodeobject'] = nodeData;
    result['replacecount'] = replaceCount;
    return result;
  }
}

/// Undo for moving [TitleNode] in the tree.
class UndoMoveTitleNode extends Undo {
  String parentId;
  int origNodePos;
  bool isUp;

  UndoMoveTitleNode(String title, this.parentId, this.origNodePos, this.isUp,
      {bool isRedo = false})
      : super(title, 'movetitlenode', isRedo);

  UndoMoveTitleNode._fromJson(Map<String, dynamic> jsonData)
      : parentId = jsonData['parentid'],
        origNodePos = jsonData['nodepos'],
        isUp = jsonData['isup'],
        super(jsonData['title'], 'movetitlenode', jsonData['isredo']);

  @override
  Undo undo() {
    var currNodePos = isUp ? origNodePos - 1 : origNodePos + 1;
    var redo = UndoMoveTitleNode(
        _toggleTitleRedo(title), parentId, currNodePos, !isUp,
        isRedo: !isRedo);
    var siblings =
        UndoList._modelRef.storedNodeFromId(parentId)?.storedChildren() ??
            UndoList._modelRef.rootNodes;
    var node = siblings.removeAt(currNodePos);
    siblings.insert(origNodePos, node);
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['parentid'] = parentId;
    result['nodepos'] = origNodePos;
    result['isup'] = isUp;
    return result;
  }
}

/// Undo for custom group sort keys and for custom child sort keys.
class UndoEditSortKeys extends Undo {
  String nodeId;
  List<String> sortKeyStrings;
  bool isCustom;
  bool isChildSort;

  UndoEditSortKeys(String title, this.nodeId, sortKeys,
      {this.isCustom = true, this.isChildSort = false, bool isRedo = false})
      : sortKeyStrings = [for (var sortField in sortKeys) sortField.toString()],
        super(title, 'editsortkeys', isRedo);

  UndoEditSortKeys._fromJson(Map<String, dynamic> jsonData)
      : nodeId = jsonData['nodeid'],
        sortKeyStrings = jsonData['sortfields'].cast<String>(),
        isCustom = jsonData['iscustom'],
        isChildSort = jsonData['ischildsort'],
        super(jsonData['title'], 'editsortkeys', jsonData['isredo']);

  @override
  Undo undo() {
    var node = UndoList._modelRef.storedNodeFromId(nodeId) as RuleNode;
    UndoEditSortKeys redo;
    if (isChildSort) {
      redo = UndoEditSortKeys(
        _toggleTitleRedo(title),
        nodeId,
        node.childSortFields,
        isCustom: node.hasCustomChildSortFields,
        isChildSort: true,
        isRedo: !isRedo,
      );
      node.childSortFields = [
        for (var fieldName in sortKeyStrings)
          SortKey.fromString(fieldName, UndoList._modelRef.fieldMap)
      ];
      node.hasCustomChildSortFields = isCustom;
    } else {
      redo = UndoEditSortKeys(
        _toggleTitleRedo(title),
        nodeId,
        node.sortFields,
        isCustom: node.hasCustomSortFields,
        isChildSort: false,
        isRedo: !isRedo,
      );
      node.sortFields = [
        for (var fieldName in sortKeyStrings)
          SortKey.fromString(fieldName, UndoList._modelRef.fieldMap)
      ];
      node.hasCustomSortFields = isCustom;
    }
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['nodeid'] = nodeId;
    result['sortfields'] = sortKeyStrings;
    result['iscustom'] = isCustom;
    result['ischildsort'] = isChildSort;
    return result;
  }
}

/// Undo for adding an output line.
class UndoAddOutputLine extends Undo {
  int linePos;

  UndoAddOutputLine(String title, this.linePos, {bool isRedo = false})
      : super(title, 'addoutputline', isRedo);

  UndoAddOutputLine._fromJson(Map<String, dynamic> jsonData)
      : linePos = jsonData['linepos'],
        super(jsonData['title'], 'addoutputline', jsonData['isredo']);

  @override
  Undo undo() {
    var redo = UndoRemoveOutputLine(_toggleTitleRedo(title), linePos,
        UndoList._modelRef.outputLines[linePos],
        isRedo: !isRedo);
    UndoList._modelRef.outputLines.removeAt(linePos);
    UndoList._modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['linepos'] = linePos;
    return result;
  }
}

/// Undo for removing an output line.
class UndoRemoveOutputLine extends Undo {
  int linePos;
  String rawOutputLine;

  UndoRemoveOutputLine(String title, this.linePos, ParsedLine outputLine,
      {bool isRedo = false})
      : rawOutputLine = outputLine.getUnparsedLine(),
        super(title, 'removeoutputline', isRedo);

  UndoRemoveOutputLine._fromJson(Map<String, dynamic> jsonData)
      : linePos = jsonData['linepos'],
        rawOutputLine = jsonData['outputline'],
        super(jsonData['title'], 'removeoutputline', jsonData['isredo']);

  @override
  Undo undo() {
    var redo =
        UndoAddOutputLine(_toggleTitleRedo(title), linePos, isRedo: !isRedo);
    var outputLine = ParsedLine(rawOutputLine, UndoList._modelRef.fieldMap);
    UndoList._modelRef.outputLines.insert(linePos, outputLine);
    UndoList._modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['linepos'] = linePos;
    result['outputline'] = rawOutputLine;
    return result;
  }
}

/// Undo for editng an output line.
class UndoEditOutputLine extends Undo {
  // linePos is -1 for the title line.
  int linePos;
  String rawOutputLine;

  UndoEditOutputLine(String title, this.linePos, ParsedLine outputLine,
      {bool isRedo = false})
      : rawOutputLine = outputLine.getUnparsedLine(),
        super(title, 'editoutputline', isRedo);

  UndoEditOutputLine._fromJson(Map<String, dynamic> jsonData)
      : linePos = jsonData['linepos'],
        rawOutputLine = jsonData['outputline'],
        super(jsonData['title'], 'editoutputline', jsonData['isredo']);

  @override
  Undo undo() {
    var outputLine = ParsedLine(rawOutputLine, UndoList._modelRef.fieldMap);
    UndoEditOutputLine redo;
    if (linePos < 0) {
      redo = UndoEditOutputLine(
          _toggleTitleRedo(title), linePos, UndoList._modelRef.titleLine,
          isRedo: !isRedo);
      UndoList._modelRef.titleLine = outputLine;
    } else {
      redo = UndoEditOutputLine(_toggleTitleRedo(title), linePos,
          UndoList._modelRef.outputLines[linePos],
          isRedo: !isRedo);
      UndoList._modelRef.outputLines[linePos] = outputLine;
    }
    UndoList._modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['linepos'] = linePos;
    result['outputline'] = rawOutputLine;
    return result;
  }
}

class UndoMoveOutputLine extends Undo {
  int origLinePos;
  bool isUp;

  UndoMoveOutputLine(String title, this.origLinePos, this.isUp,
      {bool isRedo = false})
      : super(title, 'moveoutputline', isRedo);

  UndoMoveOutputLine._fromJson(Map<String, dynamic> jsonData)
      : origLinePos = jsonData['linepos'],
        isUp = jsonData['isup'],
        super(jsonData['title'], 'moveoutputline', jsonData['isredo']);

  @override
  Undo undo() {
    var currLinePos = isUp ? origLinePos - 1 : origLinePos + 1;
    var redo = UndoMoveOutputLine(_toggleTitleRedo(title), currLinePos, !isUp,
        isRedo: !isRedo);
    var outputLine = UndoList._modelRef.outputLines.removeAt(currLinePos);
    UndoList._modelRef.outputLines.insert(origLinePos, outputLine);
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['linepos'] = origLinePos;
    result['isup'] = isUp;
    return result;
  }
}
