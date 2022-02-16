// undos.dart, stores and executes undo operations.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:collection';
import 'nodes.dart';
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
        undo = UndoBatch(jsonData['title'],
            [for (var item in jsonData['children']) Undo.fromJson(item)]);
        break;
      case 'editleafnode':
        undo = UndoEditLeafNode(jsonData['title'], jsonData['nodepos'],
            jsonData['nodedata'].cast<String, String>());
        break;
      case 'addleafnode':
        undo = UndoAddLeafNode(jsonData['title'], jsonData['nodepos']);
        break;
      case 'deleteleafnode':
        undo = UndoDeleteLeafNode(jsonData['title'],
            LeafNode.fromJson(jsonData['nodeobject'], UndoList._modelRef));
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
    var redo = UndoDeleteLeafNode(
        _toggleTitleRedo(title), UndoList._modelRef.leafNodes[nodePos]);
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
  LeafNode node;

  UndoDeleteLeafNode(String title, this.node) : super(title, 'deleteleafnode');

  @override
  Undo undo() {
    var redo = UndoAddLeafNode(
        _toggleTitleRedo(title), UndoList._modelRef.leafNodes.indexOf(node));
    UndoList._modelRef.leafNodes.add(node);
    return redo;
  }

  @override
  Map<String, dynamic> toJson() {
    var result = super.toJson();
    result['nodeobject'] = node.toJson();
    return result;
  }
}
