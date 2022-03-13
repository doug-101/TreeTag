// undos.dart, stores and executes undo operations.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:collection';
import 'fields.dart';
import 'nodes.dart';
import 'parsed_line.dart';
import 'structure.dart';

/// Storage of an undo list with operations.
class UndoList extends ListBase<Undo> {
  final _innerList = <Undo>[];
  static late Structure _modelRef;

  UndoList(Structure modelRef) {
    _modelRef = modelRef;
  }

  UndoList.fromJson(List<dynamic> jsonData, Structure modelRef) {
    _modelRef = modelRef;
    addAll([for (var data in jsonData) Undo.fromJson(data)]);
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

  void undoToPos(int pos) {
    var firstUndoPos = indexWhere((undo) => !undo.isRedo, pos);
    var redoList = <Undo>[];
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
    return [for (var undo in this) undo.toJson()];
  }
}

abstract class Undo {
  final String title;
  final String undoType;
  final bool isRedo;
  DateTime timeStamp = DateTime.now();

  Undo(this.title, this.undoType, this.isRedo);

  factory Undo.fromJson(Map<String, dynamic> jsonData) {
    Undo undo;
    switch (jsonData['type']) {
      case 'batch':
        undo = UndoBatch(
          jsonData['title'],
          [for (var item in jsonData['children']) Undo.fromJson(item)],
          isRedo: jsonData['isredo'],
        );
        break;
      case 'editleafnode':
        undo = UndoEditLeafNode(
          jsonData['title'],
          jsonData['nodepos'],
          jsonData['nodedata'].cast<String, String>(),
          isRedo: jsonData['isredo'],
        );
        break;
      case 'addleafnode':
        undo = UndoAddLeafNode(
          jsonData['title'],
          jsonData['nodepos'],
          isRedo: jsonData['isredo'],
        );
        break;
      case 'deleteleafnode':
        undo = UndoDeleteLeafNode(
          jsonData['title'],
          jsonData['nodepos'],
          LeafNode.fromJson(jsonData['nodeobject'], UndoList._modelRef),
          isRedo: jsonData['isredo'],
        );
        break;
      case 'addnewfield':
        undo = UndoAddNewField(
          jsonData['title'],
          jsonData['fieldname'],
          isRedo: jsonData['isredo'],
        );
        break;
      case 'editfield':
        undo = UndoEditField(
          jsonData['title'],
          jsonData['fieldpos'],
          Field.fromJson(jsonData['field']),
          isRedo: jsonData['isredo'],
        );
        break;
      case 'deletefield':
        undo = UndoDeleteField(
          jsonData['title'],
          jsonData['fieldpos'],
          Field.fromJson(jsonData['field']),
          isRedo: jsonData['isredo'],
        );
        break;
      case 'movefield':
        undo = UndoMoveField(
          jsonData['title'],
          jsonData['fieldpos'],
          jsonData['isup'],
          isRedo: jsonData['isredo'],
        );
        break;
      case 'edittitlenode':
        undo = UndoEditTitleNode(
          jsonData['title'],
          jsonData['nodeid'],
          jsonData['titletext'],
          isRedo: jsonData['isredo'],
        );
        break;
      case 'editruleline':
        undo = UndoEditRuleLine(
          jsonData['title'],
          jsonData['nodeid'],
          ParsedLine(jsonData['ruleline'], UndoList._modelRef.fieldMap),
          isRedo: jsonData['isredo'],
        );
        break;
      case 'addtreenode':
        undo = UndoAddTreeNode(
          jsonData['title'],
          jsonData['parentid'],
          jsonData['nodepos'],
          isRedo: jsonData['isredo'],
        );
        break;
      case 'deletetreenode':
        undo = UndoDeleteTreeNode(
          jsonData['title'],
          jsonData['parentid'],
          jsonData['nodepos'],
          Node(jsonData['nodeobject'], UndoList._modelRef),
          isRedo: jsonData['isredo'],
        );
        break;
      case 'movetitlenode':
        undo = UndoMoveTitleNode(
          jsonData['title'],
          jsonData['parentid'],
          jsonData['nodepos'],
          jsonData['isup'],
          isRedo: jsonData['isredo'],
        );
        break;
      case 'editsortkeys':
        undo = UndoEditSortKeys(
          jsonData['title'],
          jsonData['nodeid'],
          [
            for (var fieldName in jsonData['sortfields'])
              SortKey.fromString(fieldName, UndoList._modelRef.fieldMap)
          ],
          isCustom: jsonData['iscustom'],
          isChildSort: jsonData['ischildsort'],
          isRedo: jsonData['isredo'],
        );
        break;
      case 'addoutputline':
        undo = UndoAddOutputLine(
          jsonData['title'],
          jsonData['linepos'],
          isRedo: jsonData['isredo'],
        );
        break;
      case 'removeoutputline':
        undo = UndoRemoveOutputLine(
          jsonData['title'],
          jsonData['linepos'],
          ParsedLine(jsonData['outputline'], UndoList._modelRef.fieldMap),
          isRedo: jsonData['isredo'],
        );
        break;
      case 'editoutputline':
        undo = UndoEditOutputLine(
          jsonData['title'],
          jsonData['linepos'],
          ParsedLine(jsonData['outputline'], UndoList._modelRef.fieldMap),
          isRedo: jsonData['isredo'],
        );
        break;
      case 'moveoutputline':
        undo = UndoMoveOutputLine(
          jsonData['title'],
          jsonData['linepos'],
          jsonData['isup'],
          isRedo: jsonData['isredo'],
        );
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

  // Subclasses perform the undo and return an opposite redo object.
  Undo undo();

  String _toggleTitleRedo(String title) {
    if (title.isEmpty) return '';
    if (title.startsWith('Redo '))
      return title.replaceRange(0, 6, title[5].toUpperCase());
    return 'Redo ${title.replaceRange(0, 1, title[0].toLowerCase())}';
  }
}

class UndoBatch extends Undo {
  late List<Undo> storedUndos;

  UndoBatch(String title, this.storedUndos, {bool isRedo = false})
      : super(title, 'batch', isRedo);

  @override
  Undo undo() {
    var redos = [for (var undoInst in storedUndos.reversed) undoInst.undo()];
    return UndoBatch(_toggleTitleRedo(title), redos, isRedo: !isRedo);
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
  late Map<String, String> storedNodeData;

  UndoEditLeafNode(String title, this.nodePos, Map<String, String> nodeData,
      {bool isRedo = false})
      : super(title, 'editleafnode', isRedo) {
    storedNodeData = Map.of(nodeData);
  }

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
  LeafNode node;

  UndoDeleteLeafNode(String title, this.nodePos, this.node,
      {bool isRedo = false})
      : super(title, 'deleteleafnode', isRedo);

  @override
  Undo undo() {
    var redo = UndoAddLeafNode(
        _toggleTitleRedo(title), UndoList._modelRef.leafNodes.indexOf(node),
        isRedo: !isRedo);
    UndoList._modelRef.leafNodes.insert(nodePos, node);
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['nodeobject'] = node.toJson();
    return result;
  }
}

class UndoAddNewField extends Undo {
  String fieldName;

  UndoAddNewField(String title, this.fieldName, {bool isRedo = false})
      : super(title, 'addnewfield', isRedo);

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
  Field field;

  UndoEditField(String title, this.fieldPos, this.field, {bool isRedo = false})
      : super(title, 'editfield', isRedo);

  @override
  Undo undo() {
    var fieldList = List.of(UndoList._modelRef.fieldMap.values);
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
    result['field'] = field.toJson();
    return result;
  }
}

class UndoDeleteField extends Undo {
  int fieldPos;
  Field field;

  UndoDeleteField(String title, this.fieldPos, this.field,
      {bool isRedo = false})
      : super(title, 'deletefield', isRedo);

  @override
  Undo undo() {
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
    result['field'] = field.toJson();
    return result;
  }
}

class UndoMoveField extends Undo {
  int fieldPos;
  bool isUp;

  UndoMoveField(String title, this.fieldPos, this.isUp, {bool isRedo = false})
      : super(title, 'movefield', isRedo);

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
  ParsedLine ruleLine;

  UndoEditRuleLine(String title, this.nodeId, this.ruleLine,
      {bool isRedo = false})
      : super(title, 'editruleline', isRedo);

  @override
  Undo undo() {
    var node = UndoList._modelRef.storedNodeFromId(nodeId) as RuleNode;
    var redo = UndoEditRuleLine(_toggleTitleRedo(title), nodeId, node.ruleLine,
        isRedo: !isRedo);
    node.ruleLine = ruleLine;
    node.setDefaultRuleSortFields();
    UndoList._modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['nodeid'] = nodeId;
    result['ruleline'] = ruleLine.getUnparsedLine();
    return result;
  }
}

class UndoAddTreeNode extends Undo {
  String parentId;
  int nodePos;

  UndoAddTreeNode(String title, this.parentId, this.nodePos,
      {bool isRedo = false})
      : super(title, 'addtreenode', isRedo);

  @override
  Undo undo() {
    var parentNode = UndoList._modelRef.storedNodeFromId(parentId);
    var node = parentNode == null
        ? UndoList._modelRef.rootNodes[nodePos]
        : parentNode.storedChildren()[nodePos];
    var redo = UndoDeleteTreeNode(
        _toggleTitleRedo(title), parentId, nodePos, node,
        isRedo: !isRedo);
    if (parentNode == null) {
      UndoList._modelRef.rootNodes.removeAt(nodePos);
    } else if (node is TitleNode) {
      (parentNode as TitleNode).removeTitleChild(node as TitleNode);
    } else if (parentNode is TitleNode) {
      (parentNode as TitleNode).replaceChildRule(null);
    } else {
      (parentNode as RuleNode).childRuleNode = null;
    }
    UndoList._modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['parentid'] = parentId;
    result['nodepos'] = nodePos;
    return result;
  }
}

class UndoDeleteTreeNode extends Undo {
  String parentId;
  int nodePos;
  Node node;

  UndoDeleteTreeNode(String title, this.parentId, this.nodePos, this.node,
      {bool isRedo = false})
      : super(title, 'deletetreenode', isRedo);

  @override
  Undo undo() {
    var redo = UndoAddTreeNode(_toggleTitleRedo(title), parentId, nodePos,
        isRedo: !isRedo);
    var parentNode = UndoList._modelRef.storedNodeFromId(parentId);
    if (parentNode == null) {
      UndoList._modelRef.rootNodes.insert(nodePos, node);
    } else {
      node.parent = parentNode;
      if (node is TitleNode) {
        (parentNode as TitleNode)
            .addChildTitleNode(node as TitleNode, pos: nodePos);
      } else if (parentNode is TitleNode) {
        (parentNode as TitleNode).childRuleNode = node as RuleNode;
      } else {
        (parentNode as RuleNode).childRuleNode = node as RuleNode;
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
    result['nodeobject'] = node.toJson();
    return result;
  }
}

class UndoMoveTitleNode extends Undo {
  String parentId;
  int origNodePos;
  bool isUp;

  UndoMoveTitleNode(String title, this.parentId, this.origNodePos, this.isUp,
      {bool isRedo = false})
      : super(title, 'movetitlenode', isRedo);

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

class UndoEditSortKeys extends Undo {
  String nodeId;
  List<SortKey> sortFields;
  bool isCustom;
  bool isChildSort;

  UndoEditSortKeys(String title, this.nodeId, this.sortFields,
      {this.isCustom = true, this.isChildSort = false, bool isRedo = false})
      : super(title, 'editsortkeys', isRedo);

  @override
  Undo undo() {
    var node = UndoList._modelRef.storedNodeFromId(nodeId) as RuleNode;
    UndoEditSortKeys redo;
    if (isChildSort) {
      redo = UndoEditSortKeys(
          _toggleTitleRedo(title), nodeId, node.childSortFields,
          isCustom: node.hasCustomChildSortFields,
          isChildSort: true,
          isRedo: !isRedo);
      node.childSortFields = sortFields;
      node.hasCustomChildSortFields = isCustom;
    } else {
      redo = UndoEditSortKeys(_toggleTitleRedo(title), nodeId, node.sortFields,
          isCustom: node.hasCustomSortFields,
          isChildSort: false,
          isRedo: !isRedo);
      node.sortFields = sortFields;
      node.hasCustomSortFields = isCustom;
    }
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['nodeid'] = nodeId;
    result['sortfields'] = [for (var sortKey in sortFields) sortKey.toString()];
    result['iscustom'] = isCustom;
    result['ischildsort'] = isChildSort;
    return result;
  }
}

class UndoAddOutputLine extends Undo {
  int linePos;

  UndoAddOutputLine(String title, this.linePos, {bool isRedo = false})
      : super(title, 'addoutputline', isRedo);

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

class UndoRemoveOutputLine extends Undo {
  int linePos;
  ParsedLine outputLine;

  UndoRemoveOutputLine(String title, this.linePos, this.outputLine,
      {bool isRedo = false})
      : super(title, 'removeoutputline', isRedo);

  @override
  Undo undo() {
    var redo =
        UndoAddOutputLine(_toggleTitleRedo(title), linePos, isRedo: !isRedo);
    UndoList._modelRef.outputLines.insert(linePos, outputLine);
    UndoList._modelRef.updateAltFormatFields();
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['linepos'] = linePos;
    result['outputline'] = outputLine.getUnparsedLine();
    return result;
  }
}

class UndoEditOutputLine extends Undo {
  // linePos is -1 for the title line.
  int linePos;
  ParsedLine outputLine;

  UndoEditOutputLine(String title, this.linePos, this.outputLine,
      {bool isRedo = false})
      : super(title, 'editoutputline', isRedo);

  @override
  Undo undo() {
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
    result['outputline'] = outputLine.getUnparsedLine();
    return result;
  }
}

class UndoMoveOutputLine extends Undo {
  int origLinePos;
  bool isUp;

  UndoMoveOutputLine(String title, this.origLinePos, this.isUp,
      {bool isRedo = false})
      : super(title, 'moveoutputline', isRedo);

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
