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

  // Subclasses perform the undo and return an opposite redo object.
  Undo undo();

  factory Undo.fromJson(Map<String, dynamic> jsonData) {
    Undo undo;
    switch (jsonData['type']) {
      case 'editnode':
        undo = UndoEditNode(jsonData['title'], jsonData['nodepos'],
            jsonData['nodedata'].cast<String, String>());
        break;
      case 'addnode':
        undo = UndoAddNode(jsonData['title'], jsonData['nodepos']);
        break;
      case 'deletenode':
        undo = UndoDeleteNode(jsonData['title'],
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

  String _toggleTitleRedo(String title) {
    if (title.startsWith('Redo '))
      return title.replaceRange(0, 6, title[5].toUpperCase());
    return 'Redo ${title.replaceRange(0, 1, title[0].toLowerCase())}';
  }
}

class UndoEditNode extends Undo {
  int nodePos;
  late Map<String, String> storedNodeData;

  UndoEditNode(String title, this.nodePos, Map<String, String> nodeData)
      : super(title, 'editnode') {
    storedNodeData = Map.of(nodeData);
  }

  @override
  Undo undo() {
    var node = UndoList._modelRef.leafNodes[nodePos];
    var redo = UndoEditNode(_toggleTitleRedo(title), nodePos, node.data);
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

class UndoAddNode extends Undo {
  int nodePos;

  UndoAddNode(String title, this.nodePos) : super(title, 'addnode');

  @override
  Undo undo() {
    var redo = UndoDeleteNode(
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

class UndoDeleteNode extends Undo {
  LeafNode node;

  UndoDeleteNode(String title, this.node) : super(title, 'deletenode');

  @override
  Undo undo() {
    var redo = UndoAddNode(
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
