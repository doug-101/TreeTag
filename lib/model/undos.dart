// undos.dart, stores and executes undo operations.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:collection';
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
    var redoList = <Undo>[];
    for (int i = length - 1; i >= pos; i--) {
      redoList.add(this[i].undo());
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
  DateTime timeStamp = DateTime.now();

  Undo(this.title, this.undoType);

  factory Undo.fromJson(Map<String, dynamic> jsonData) {
    Undo undo;
    switch (jsonData['type']) {
      case 'batch':
        undo = UndoBatch(
          jsonData['title'],
          [for (var item in jsonData['children']) Undo.fromJson(item)],
        );
        break;
      case 'editleafnode':
        undo = UndoEditLeafNode(
          jsonData['title'],
          jsonData['nodepos'],
          jsonData['nodedata'].cast<String, String>(),
        );
        break;
      case 'addleafnode':
        undo = UndoAddLeafNode(
          jsonData['title'],
          jsonData['nodepos'],
        );
        break;
      case 'deleteleafnode':
        undo = UndoDeleteLeafNode(
          jsonData['title'],
          jsonData['nodepos'],
          LeafNode.fromJson(jsonData['nodeobject'], UndoList._modelRef),
        );
        break;
      case 'edittitlenode':
        undo = UndoEditTitleNode(
          jsonData['title'],
          jsonData['nodeid'],
          jsonData['titletext'],
        );
        break;
      case 'editruleline':
        undo = UndoEditRuleLine(
          jsonData['title'],
          jsonData['nodeid'],
          ParsedLine(jsonData['ruleline'], UndoList._modelRef.fieldMap),
        );
        break;
      case 'addtreenode':
        undo = UndoAddTreeNode(
          jsonData['title'],
          jsonData['parentid'],
          jsonData['nodepos'],
        );
        break;
      case 'deletetreenode':
        undo = UndoDeleteTreeNode(
          jsonData['title'],
          jsonData['parentid'],
          jsonData['nodepos'],
          Node(jsonData['nodeobject'], UndoList._modelRef),
        );
        break;
      case 'movetitlenode':
        undo = UndoMoveTitleNode(
          jsonData['title'],
          jsonData['parentid'],
          jsonData['nodepos'],
          jsonData['isup'],
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

  UndoBatch(String title, this.storedUndos) : super(title, 'batch');

  @override
  Undo undo() {
    var redos = [for (var undoInst in storedUndos) undoInst.undo()];
    return UndoBatch(_toggleTitleRedo(title), redos);
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

  UndoEditLeafNode(String title, this.nodePos, Map<String, String> nodeData)
      : super(title, 'editleafnode') {
    storedNodeData = Map.of(nodeData);
  }

  @override
  Undo undo() {
    var node = UndoList._modelRef.leafNodes[nodePos];
    var redo = UndoEditLeafNode(_toggleTitleRedo(title), nodePos, node.data);
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

  UndoAddLeafNode(String title, this.nodePos) : super(title, 'addleafnode');

  @override
  Undo undo() {
    var redo = UndoDeleteLeafNode(_toggleTitleRedo(title), nodePos,
        UndoList._modelRef.leafNodes[nodePos]);
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

  UndoDeleteLeafNode(String title, this.nodePos, this.node)
      : super(title, 'deleteleafnode');

  @override
  Undo undo() {
    var redo = UndoAddLeafNode(
        _toggleTitleRedo(title), UndoList._modelRef.leafNodes.indexOf(node));
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

class UndoEditTitleNode extends Undo {
  String nodeId;
  String titleText;

  UndoEditTitleNode(String title, this.nodeId, this.titleText)
      : super(title, 'edittitlenode');

  @override
  Undo undo() {
    var node = UndoList._modelRef.storedNodeFromId(nodeId) as TitleNode;
    var redo = UndoEditTitleNode(_toggleTitleRedo(title), nodeId, node.title);
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

  UndoEditRuleLine(String title, this.nodeId, this.ruleLine)
      : super(title, 'editruleline');

  @override
  Undo undo() {
    var node = UndoList._modelRef.storedNodeFromId(nodeId) as RuleNode;
    var redo = UndoEditRuleLine(_toggleTitleRedo(title), nodeId, node.ruleLine);
    node.ruleLine = ruleLine;
    node.setDefaultRuleSortFields();
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

  UndoAddTreeNode(String title, this.parentId, this.nodePos)
      : super(title, 'addtreenode');

  @override
  Undo undo() {
    var parentNode = UndoList._modelRef.storedNodeFromId(parentId);
    var node = parentNode == null
        ? UndoList._modelRef.rootNodes[nodePos]
        : parentNode.storedChildren()[nodePos];
    var redo =
        UndoDeleteTreeNode(_toggleTitleRedo(title), parentId, nodePos, node);
    if (parentNode == null) {
      UndoList._modelRef.rootNodes.removeAt(nodePos);
    } else if (node is TitleNode) {
      (parentNode as TitleNode).removeTitleChild(node as TitleNode);
    } else if (parentNode is TitleNode) {
      (parentNode as TitleNode).replaceChildRule(null);
    } else {
      (parentNode as RuleNode).childRuleNode = null;
    }
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

  UndoDeleteTreeNode(String title, this.parentId, this.nodePos, this.node)
      : super(title, 'deletetreenode');

  @override
  Undo undo() {
    var redo = UndoAddTreeNode(_toggleTitleRedo(title), parentId, nodePos);
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

  UndoMoveTitleNode(String title, this.parentId, this.origNodePos, this.isUp)
      : super(title, 'movetitlenode');

  @override
  Undo undo() {
    var currNodePos = isUp ? --origNodePos : ++origNodePos;
    var redo = UndoMoveTitleNode(
        _toggleTitleRedo(title), parentId, currNodePos, !isUp);
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
      {this.isCustom = true, this.isChildSort = false})
      : super(title, 'editsortkeys');

  @override
  Undo undo() {
    var node = UndoList._modelRef.storedNodeFromId(nodeId) as RuleNode;
    UndoEditSortKeys redo;
    if (isChildSort) {
      redo = UndoEditSortKeys(
          _toggleTitleRedo(title), nodeId, node.childSortFields,
          isCustom: node.hasCustomChildSortFields, isChildSort: true);
      node.childSortFields = sortFields;
      node.hasCustomChildSortFields = isCustom;
    } else {
      redo = UndoEditSortKeys(_toggleTitleRedo(title), nodeId, node.sortFields,
          isCustom: node.hasCustomSortFields, isChildSort: false);
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
