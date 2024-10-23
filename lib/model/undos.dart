// undos.dart, stores and executes undo operations.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:collection';
import 'display_node.dart';
import 'fields.dart';
import '../main.dart' show prefs;
import 'parsed_line.dart';
import 'stored_node.dart';
import 'structure.dart';

/// Storage of an undo list with undo operations.
class UndoList extends ListBase<Undo> {
  final _innerList = <Undo>[];
  late final Structure _modelRef;

  UndoList(Structure modelRef) {
    _modelRef = modelRef;
  }

  UndoList.fromJson(List<dynamic> jsonData, Structure modelRef) {
    _modelRef = modelRef;
    addAll([for (var data in jsonData) Undo._fromJson(data)]);
  }

  @override
  int get length => _innerList.length;

  @override
  set length(int length) {
    _innerList.length = length;
  }

  @override
  Undo operator [](int index) => _innerList[index];

  @override
  void operator []=(int index, Undo value) {
    _innerList[index] = value;
  }

  @override
  void add(Undo element) => _innerList.add(element);

  @override
  void addAll(Iterable<Undo> iterable) => _innerList.addAll(iterable);

  /// Perform an undo from the list end to [pos].
  void undoToPos(int pos) {
    final firstUndoPos = indexWhere((undo) => !undo.isRedo, pos);
    final redoList = <Undo>[];
    // Perform undos backward (last-in, first-out).
    for (int i = length - 1; i >= pos; i--) {
      // Skip and remove all redo's that come after an active undo.
      if (!this[i].isRedo || pos > firstUndoPos) {
        redoList.add(this[i].undo(_modelRef));
      }
    }
    removeRange(pos, length);
    addAll(redoList);
    _modelRef.updateAll();
  }

  List<dynamic> toJson() {
    final daysToStore = prefs.getInt('undodays') ?? 7;
    final cutOffDate = DateTime.now().subtract(Duration(days: daysToStore));
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
      case 'editleafnode':
        undo = UndoEditLeafNode._fromJson(jsonData);
      case 'addleafnode':
        undo = UndoAddLeafNode._fromJson(jsonData);
      case 'deleteleafnode':
        undo = UndoDeleteLeafNode._fromJson(jsonData);
      case 'addnewfield':
        undo = UndoAddNewField._fromJson(jsonData);
      case 'editfield':
        undo = UndoEditField._fromJson(jsonData);
      case 'deletefield':
        undo = UndoDeleteField._fromJson(jsonData);
      case 'movefield':
        undo = UndoMoveField._fromJson(jsonData);
      case 'edittitlenode':
        undo = UndoEditTitleNode._fromJson(jsonData);
      case 'editruleline':
        undo = UndoEditRuleLine._fromJson(jsonData);
      case 'addtreenode':
        undo = UndoAddTreeNode._fromJson(jsonData);
      case 'deletetreenode':
        undo = UndoDeleteTreeNode._fromJson(jsonData);
      case 'movetitlenode':
        undo = UndoMoveTitleNode._fromJson(jsonData);
      case 'editsortkeys':
        undo = UndoEditSortKeys._fromJson(jsonData);
      case 'addoutputline':
        undo = UndoAddOutputLine._fromJson(jsonData);
      case 'removeoutputline':
        undo = UndoRemoveOutputLine._fromJson(jsonData);
      case 'editoutputline':
        undo = UndoEditOutputLine._fromJson(jsonData);
      case 'moveoutputline':
        undo = UndoMoveOutputLine._fromJson(jsonData);
      case 'parameters':
        undo = UndoParameters._fromJson(jsonData);
      default:
        throw const FormatException('Stored undo data is corrupt');
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
  Undo undo(Structure modelRef);

  /// Return a modified title to specify a redo in place of an undo.
  String _toggleTitleRedo(String title) {
    if (title.isEmpty) return '';
    if (title.startsWith('Redo ')) {
      return title.replaceRange(0, 6, title[5].toUpperCase());
    }
    return 'Redo ${title.replaceRange(0, 1, title[0].toLowerCase())}';
  }
}

/// An undo type that groups several child undos under one parent list entry.
class UndoBatch extends Undo {
  final List<Undo> storedUndos;

  UndoBatch(String title, this.storedUndos, {bool isRedo = false})
      : super(title, 'batch', isRedo);

  UndoBatch._fromJson(Map<String, dynamic> jsonData)
      : storedUndos = [
          for (var item in jsonData['children']) Undo._fromJson(item)
        ],
        super(jsonData['title'], 'batch', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final redos = [for (var undoInst in storedUndos) undoInst.undo(modelRef)];
    return UndoBatch(_toggleTitleRedo(title), List.of(redos.reversed),
        isRedo: !isRedo);
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result.addAll({
      'children': [for (var undoInst in storedUndos) undoInst.toJson()]
    });
    return result;
  }
}

class UndoEditLeafNode extends Undo {
  final int nodePos;
  final Map<String, List<String>> storedNodeData;

  UndoEditLeafNode(
      String title, this.nodePos, Map<String, List<String>> nodeData,
      {bool isRedo = false})
      : storedNodeData = Map.of(nodeData),
        super(title, 'editleafnode', isRedo);

  UndoEditLeafNode._fromJson(Map<String, dynamic> jsonData)
      : nodePos = jsonData['nodepos'],
        storedNodeData = (jsonData['nodedata'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value.cast<String>())),
        super(jsonData['title'], 'editleafnode', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final node = modelRef.leafNodes[nodePos];
    final redo = UndoEditLeafNode(_toggleTitleRedo(title), nodePos, node.data,
        isRedo: !isRedo);
    node.data = storedNodeData;
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result.addAll({'nodepos': nodePos, 'nodedata': storedNodeData});
    return result;
  }
}

class UndoAddLeafNode extends Undo {
  final int nodePos;

  UndoAddLeafNode(String title, this.nodePos, {bool isRedo = false})
      : super(title, 'addleafnode', isRedo);

  UndoAddLeafNode._fromJson(Map<String, dynamic> jsonData)
      : nodePos = jsonData['nodepos'],
        super(jsonData['title'], 'addleafnode', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final redo = UndoDeleteLeafNode(
        _toggleTitleRedo(title), nodePos, modelRef.leafNodes[nodePos],
        isRedo: !isRedo);
    modelRef.leafNodes.removeAt(nodePos);
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['nodepos'] = nodePos;
    return result;
  }
}

class UndoDeleteLeafNode extends Undo {
  final int nodePos;
  final Map<String, dynamic> nodeData;

  UndoDeleteLeafNode(String title, this.nodePos, LeafNode node,
      {bool isRedo = false})
      : nodeData = node.data,
        super(title, 'deleteleafnode', isRedo);

  UndoDeleteLeafNode._fromJson(Map<String, dynamic> jsonData)
      : nodePos = jsonData['nodepos'],
        nodeData = jsonData['nodeobject'],
        super(jsonData['title'], 'deleteleafnode', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final node = LeafNode.fromJson(nodeData);
    final redo =
        UndoAddLeafNode(_toggleTitleRedo(title), nodePos, isRedo: !isRedo);
    modelRef.leafNodes.insert(nodePos, node);
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['nodepos'] = nodePos;
    result['nodeobject'] = nodeData;
    return result;
  }
}

class UndoAddNewField extends Undo {
  final String fieldName;

  UndoAddNewField(String title, this.fieldName, {bool isRedo = false})
      : super(title, 'addnewfield', isRedo);

  UndoAddNewField._fromJson(Map<String, dynamic> jsonData)
      : fieldName = jsonData['fieldname'],
        super(jsonData['title'], 'addnewfield', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final redo = UndoDeleteField(
        _toggleTitleRedo(title),
        List.of(modelRef.fieldMap.keys).indexOf(fieldName),
        modelRef.fieldMap[fieldName]!,
        isRedo: !isRedo);
    modelRef.fieldMap.remove(fieldName);
    modelRef.updateRuleChildSortFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['fieldname'] = fieldName;
    return result;
  }
}

class UndoEditField extends Undo {
  final int fieldPos;
  final Map<String, dynamic> fieldData;

  UndoEditField(String title, this.fieldPos, Field field, {bool isRedo = false})
      : fieldData = field.toJson(),
        super(title, 'editfield', isRedo);

  UndoEditField._fromJson(Map<String, dynamic> jsonData)
      : fieldPos = jsonData['fieldpos'],
        fieldData = jsonData['field'],
        super(jsonData['title'], 'editfield', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final fieldList = List.of(modelRef.fieldMap.values);
    final field = Field.fromJson(fieldData);
    final redoField = fieldList[fieldPos].fieldType == field.fieldType
        ? Field.copy(fieldList[fieldPos])
        : field;
    final redo = UndoEditField(_toggleTitleRedo(title), fieldPos, redoField,
        isRedo: !isRedo);
    if (field.name != fieldList[fieldPos].name) {
      // Field was renamed.
      modelRef.fieldMap.clear();
      for (var fld in fieldList) {
        if (fld == fieldList[fieldPos]) {
          modelRef.fieldMap[field.name] = fld;
        } else {
          modelRef.fieldMap[fld.name] = fld;
        }
      }
    }
    if (fieldList[fieldPos].fieldType == field.fieldType) {
      fieldList[fieldPos].updateSettings(field);
    } else {
      fieldList[fieldPos] = field;
      modelRef.fieldMap.clear();
      for (var fld in fieldList) {
        modelRef.fieldMap[fld.name] = fld;
      }
    }
    modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['fieldpos'] = fieldPos;
    result['field'] = fieldData;
    return result;
  }
}

class UndoDeleteField extends Undo {
  final int fieldPos;
  final Map<String, dynamic> fieldData;

  UndoDeleteField(String title, this.fieldPos, Field field,
      {bool isRedo = false})
      : fieldData = field.toJson(),
        super(title, 'deletefield', isRedo);

  UndoDeleteField._fromJson(Map<String, dynamic> jsonData)
      : fieldPos = jsonData['fieldpos'],
        fieldData = jsonData['field'],
        super(jsonData['title'], 'deletefield', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final field = Field.fromJson(fieldData);
    final redo =
        UndoAddNewField(_toggleTitleRedo(title), field.name, isRedo: !isRedo);
    final fieldList = List.of(modelRef.fieldMap.values);
    fieldList.insert(fieldPos, field);
    modelRef.fieldMap.clear();
    for (var fld in fieldList) {
      modelRef.fieldMap[fld.name] = fld;
    }
    modelRef.updateRuleChildSortFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['fieldpos'] = fieldPos;
    result['field'] = fieldData;
    return result;
  }
}

class UndoMoveField extends Undo {
  final int fieldPos;
  final bool isUp;

  UndoMoveField(String title, this.fieldPos, this.isUp, {bool isRedo = false})
      : super(title, 'movefield', isRedo);

  UndoMoveField._fromJson(Map<String, dynamic> jsonData)
      : fieldPos = jsonData['fieldpos'],
        isUp = jsonData['isup'],
        super(jsonData['title'], 'movefield', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final currFieldPos = isUp ? fieldPos - 1 : fieldPos + 1;
    final redo = UndoMoveField(_toggleTitleRedo(title), currFieldPos, !isUp,
        isRedo: !isRedo);
    final fieldList = List.of(modelRef.fieldMap.values);
    modelRef.fieldMap.clear();
    final field = fieldList.removeAt(currFieldPos);
    fieldList.insert(fieldPos, field);
    for (var fld in fieldList) {
      modelRef.fieldMap[fld.name] = fld;
    }
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['fieldpos'] = fieldPos;
    result['isup'] = isUp;
    return result;
  }
}

class UndoEditTitleNode extends Undo {
  final String nodeId;
  final String titleText;

  UndoEditTitleNode(String title, this.nodeId, this.titleText,
      {bool isRedo = false})
      : super(title, 'edittitlenode', isRedo);

  UndoEditTitleNode._fromJson(Map<String, dynamic> jsonData)
      : nodeId = jsonData['nodeid'],
        titleText = jsonData['titletext'],
        super(jsonData['title'], 'edittitlenode', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final node = modelRef.storedNodeFromId(nodeId) as TitleNode;
    final redo = UndoEditTitleNode(_toggleTitleRedo(title), nodeId, node.title,
        isRedo: !isRedo);
    node.title = titleText;
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['nodeid'] = nodeId;
    result['titletext'] = titleText;
    return result;
  }
}

class UndoEditRuleLine extends Undo {
  final String nodeId;
  final String rawRuleLine;

  UndoEditRuleLine(String title, this.nodeId, ParsedLine ruleLine,
      {bool isRedo = false})
      : rawRuleLine = ruleLine.getUnparsedLine(),
        super(title, 'editruleline', isRedo);

  UndoEditRuleLine._fromJson(Map<String, dynamic> jsonData)
      : nodeId = jsonData['nodeid'],
        rawRuleLine = jsonData['ruleline'],
        super(jsonData['title'], 'editruleline', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final node = modelRef.storedNodeFromId(nodeId) as RuleNode;
    final redo = UndoEditRuleLine(
        _toggleTitleRedo(title), nodeId, node.ruleLine,
        isRedo: !isRedo);
    node.ruleLine = ParsedLine(rawRuleLine, modelRef.fieldMap);
    node.setDefaultRuleSortFields();
    modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['nodeid'] = nodeId;
    result['ruleline'] = rawRuleLine;
    return result;
  }
}

/// Undo class for adding [TitleNode] or [RuleNode] types.
class UndoAddTreeNode extends Undo {
  final String parentId;
  final int nodePos;

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
  Undo undo(Structure modelRef) {
    final parentNode = modelRef.storedNodeFromId(parentId);
    final node = parentNode == null
        ? modelRef.rootNodes[nodePos]
        : parentNode.storedChildren()[nodePos];
    final redo = UndoDeleteTreeNode(
      _toggleTitleRedo(title),
      parentId,
      nodePos,
      node,
      replaceCount: replaceCount,
      isRedo: !isRedo,
    );
    if (parentNode == null) {
      if (replaceCount == 0) {
        modelRef.rootNodes.removeAt(nodePos);
      } else {
        node.storedChildren().forEach((newNode) {
          newNode.storedParent = null;
        });
        modelRef.rootNodes.replaceRange(
          nodePos,
          nodePos + replaceCount,
          node.storedChildren().cast<TitleNode>(),
        );
      }
    } else if (node is TitleNode) {
      final parentTitle = parentNode as TitleNode;
      if (node.childRuleNode != null) {
        parentTitle.replaceChildRule(node.childRuleNode);
        node.replaceChildRule(null);
      }
      if (replaceCount == 0) {
        parentTitle.removeChildTitleNode(node);
      } else {
        parentTitle.replaceChildTitleNode(
          node as TitleNode,
          node.storedChildren().cast<TitleNode>(),
        );
      }
    } else if (parentNode is TitleNode) {
      final ruleNode = node as RuleNode;
      if (ruleNode.childRuleNode != null) {
        parentNode.replaceChildRule(ruleNode.childRuleNode);
      } else {
        parentNode.replaceChildRule(null);
      }
    } else {
      final ruleNode = node as RuleNode;
      final parentRule = parentNode as RuleNode;
      if (ruleNode.childRuleNode != null) {
        parentRule.replaceChildRule(ruleNode.childRuleNode);
      } else {
        parentRule.replaceChildRule(null);
      }
    }
    modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['parentid'] = parentId;
    result['nodepos'] = nodePos;
    result['replacecount'] = replaceCount;
    return result;
  }
}

/// Undo class for deleting [TitleNode] or [RuleNode] types.
class UndoDeleteTreeNode extends Undo {
  final String parentId;
  final int nodePos;
  final Map<String, dynamic> nodeData;
  final int replaceCount;

  UndoDeleteTreeNode(String title, this.parentId, this.nodePos, StoredNode node,
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
  Undo undo(Structure modelRef) {
    final redo = UndoAddTreeNode(_toggleTitleRedo(title), parentId, nodePos,
        replaceCount: replaceCount, isRedo: !isRedo);
    final node = StoredNode(nodeData);
    final parentNode = modelRef.storedNodeFromId(parentId);
    if (parentNode == null) {
      modelRef.rootNodes.replaceRange(
        nodePos,
        nodePos + replaceCount,
        [node as TitleNode],
      );
      node.storedParent = null;
      (node as TitleNode).updateChildParentRefs();
    } else if (node is TitleNode) {
      final parentTitle = parentNode as TitleNode;
      if (replaceCount > 0) {
        List.of(parentTitle.storedChildren())
            .getRange(nodePos, nodePos + replaceCount)
            .forEach((child) {
          parentTitle.removeChildTitleNode(child as TitleNode);
        });
      }
      parentTitle.addChildTitleNode(node, pos: nodePos);
      node.updateChildParentRefs();
    } else if (parentNode is TitleNode) {
      final ruleNode = node as RuleNode;
      parentNode.replaceChildRule(ruleNode);
      if (ruleNode.childRuleNode != null) {
        ruleNode.childRuleNode!.storedParent = ruleNode;
      }
    } else {
      final ruleNode = node as RuleNode;
      (parentNode as RuleNode).replaceChildRule(ruleNode);
      if (ruleNode.childRuleNode != null) {
        ruleNode.childRuleNode!.storedParent = ruleNode;
      }
    }
    modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['parentid'] = parentId;
    result['nodepos'] = nodePos;
    result['nodeobject'] = nodeData;
    result['replacecount'] = replaceCount;
    return result;
  }
}

/// Undo for moving [TitleNode] in the tree.
class UndoMoveTitleNode extends Undo {
  final String parentId;
  final int origNodePos;
  final bool isUp;

  UndoMoveTitleNode(String title, this.parentId, this.origNodePos, this.isUp,
      {bool isRedo = false})
      : super(title, 'movetitlenode', isRedo);

  UndoMoveTitleNode._fromJson(Map<String, dynamic> jsonData)
      : parentId = jsonData['parentid'],
        origNodePos = jsonData['nodepos'],
        isUp = jsonData['isup'],
        super(jsonData['title'], 'movetitlenode', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final currNodePos = isUp ? origNodePos - 1 : origNodePos + 1;
    final redo = UndoMoveTitleNode(
        _toggleTitleRedo(title), parentId, currNodePos, !isUp,
        isRedo: !isRedo);
    final siblings = modelRef.storedNodeFromId(parentId)?.storedChildren() ??
        modelRef.rootNodes;
    final node = siblings.removeAt(currNodePos);
    siblings.insert(origNodePos, node);
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['parentid'] = parentId;
    result['nodepos'] = origNodePos;
    result['isup'] = isUp;
    return result;
  }
}

/// Undo for custom group sort keys and for custom child sort keys.
class UndoEditSortKeys extends Undo {
  final String nodeId;
  final List<String> sortKeyStrings;
  final bool isCustom;
  final bool isChildSort;

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
  Undo undo(Structure modelRef) {
    final node = modelRef.storedNodeFromId(nodeId) as RuleNode;
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
          SortKey.fromString(fieldName, modelRef.fieldMap)
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
          SortKey.fromString(fieldName, modelRef.fieldMap)
      ];
      node.hasCustomSortFields = isCustom;
    }
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['nodeid'] = nodeId;
    result['sortfields'] = sortKeyStrings;
    result['iscustom'] = isCustom;
    result['ischildsort'] = isChildSort;
    return result;
  }
}

/// Undo for adding an output line.
class UndoAddOutputLine extends Undo {
  final int linePos;

  UndoAddOutputLine(String title, this.linePos, {bool isRedo = false})
      : super(title, 'addoutputline', isRedo);

  UndoAddOutputLine._fromJson(Map<String, dynamic> jsonData)
      : linePos = jsonData['linepos'],
        super(jsonData['title'], 'addoutputline', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final redo = UndoRemoveOutputLine(
        _toggleTitleRedo(title), linePos, modelRef.outputLines[linePos],
        isRedo: !isRedo);
    modelRef.outputLines.removeAt(linePos);
    modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['linepos'] = linePos;
    return result;
  }
}

/// Undo for removing an output line.
class UndoRemoveOutputLine extends Undo {
  final int linePos;
  final String rawOutputLine;

  UndoRemoveOutputLine(String title, this.linePos, ParsedLine outputLine,
      {bool isRedo = false})
      : rawOutputLine = outputLine.getUnparsedLine(),
        super(title, 'removeoutputline', isRedo);

  UndoRemoveOutputLine._fromJson(Map<String, dynamic> jsonData)
      : linePos = jsonData['linepos'],
        rawOutputLine = jsonData['outputline'],
        super(jsonData['title'], 'removeoutputline', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final redo =
        UndoAddOutputLine(_toggleTitleRedo(title), linePos, isRedo: !isRedo);
    final outputLine = ParsedLine(rawOutputLine, modelRef.fieldMap);
    modelRef.outputLines.insert(linePos, outputLine);
    modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['linepos'] = linePos;
    result['outputline'] = rawOutputLine;
    return result;
  }
}

/// Undo for editng an output line.
class UndoEditOutputLine extends Undo {
  // linePos is -1 for the title line.
  final int linePos;
  final String rawOutputLine;

  UndoEditOutputLine(String title, this.linePos, ParsedLine outputLine,
      {bool isRedo = false})
      : rawOutputLine = outputLine.getUnparsedLine(),
        super(title, 'editoutputline', isRedo);

  UndoEditOutputLine._fromJson(Map<String, dynamic> jsonData)
      : linePos = jsonData['linepos'],
        rawOutputLine = jsonData['outputline'],
        super(jsonData['title'], 'editoutputline', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final outputLine = ParsedLine(rawOutputLine, modelRef.fieldMap);
    UndoEditOutputLine redo;
    if (linePos < 0) {
      redo = UndoEditOutputLine(
          _toggleTitleRedo(title), linePos, modelRef.titleLine,
          isRedo: !isRedo);
      modelRef.titleLine = outputLine;
    } else {
      redo = UndoEditOutputLine(
          _toggleTitleRedo(title), linePos, modelRef.outputLines[linePos],
          isRedo: !isRedo);
      modelRef.outputLines[linePos] = outputLine;
    }
    modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['linepos'] = linePos;
    result['outputline'] = rawOutputLine;
    return result;
  }
}

class UndoMoveOutputLine extends Undo {
  final int origLinePos;
  final bool isUp;

  UndoMoveOutputLine(String title, this.origLinePos, this.isUp,
      {bool isRedo = false})
      : super(title, 'moveoutputline', isRedo);

  UndoMoveOutputLine._fromJson(Map<String, dynamic> jsonData)
      : origLinePos = jsonData['linepos'],
        isUp = jsonData['isup'],
        super(jsonData['title'], 'moveoutputline', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final currLinePos = isUp ? origLinePos - 1 : origLinePos + 1;
    final redo = UndoMoveOutputLine(_toggleTitleRedo(title), currLinePos, !isUp,
        isRedo: !isRedo);
    final outputLine = modelRef.outputLines.removeAt(currLinePos);
    modelRef.outputLines.insert(origLinePos, outputLine);
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['linepos'] = origLinePos;
    result['isup'] = isUp;
    return result;
  }
}

class UndoParameters extends Undo {
  final bool useMarkdownOutput;
  final bool useRelativeLinks;

  UndoParameters(String title, this.useMarkdownOutput, this.useRelativeLinks,
      {bool isRedo = false})
      : super(title, 'parameters', isRedo);

  UndoParameters._fromJson(Map<String, dynamic> jsonData)
      : useMarkdownOutput = jsonData['markdown'],
        useRelativeLinks = jsonData['relative'],
        super(jsonData['title'], 'parameters', jsonData['isredo']);

  @override
  Undo undo(Structure modelRef) {
    final redo = UndoParameters(
        _toggleTitleRedo(title), !useMarkdownOutput, !useRelativeLinks,
        isRedo: !isRedo);
    modelRef.useMarkdownOutput = useMarkdownOutput;
    modelRef.useRelativeLinks = useRelativeLinks;
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    final result = super.toJson();
    result['markdown'] = useMarkdownOutput;
    result['relative'] = useRelativeLinks;
    return result;
  }
}
