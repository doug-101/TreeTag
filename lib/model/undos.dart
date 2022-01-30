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
  Structure _modelRef;

  UndoList(this._modelRef);

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
}

abstract class Undo {
  final String title;
  final DateTime timeStamp = DateTime.now();

  Undo(this.title);

  // Subclasses perform the undo and return an opposite redo object.
  Undo undo();

  String _toggleTitleRedo(String title) {
    if (title.startsWith('Redo '))
      return title.replaceRange(0, 6, title[5].toUpperCase());
    return 'Redo ${title.replaceRange(0, 1, title[0].toLowerCase())}';
  }
}

class UndoEditNode extends Undo {
  LeafNode node;
  late Map<String, String> storedNodeData;

  UndoEditNode(String title, this.node, Map<String, String> nodeData)
      : super(title) {
    storedNodeData = Map.of(nodeData);
  }

  Undo undo() {
    var redo = UndoEditNode(_toggleTitleRedo(title), node, node.data);
    node.data = storedNodeData;
    return redo;
  }
}

class UndoAddNode extends Undo {
  LeafNode node;
  Structure _modelRef;

  UndoAddNode(String title, this.node, this._modelRef) : super(title);

  Undo undo() {
    var redo = UndoDeleteNode(_toggleTitleRedo(title), node, _modelRef);
    _modelRef.leafNodes.remove(node);
    return redo;
  }
}

class UndoDeleteNode extends Undo {
  LeafNode node;
  Structure _modelRef;

  UndoDeleteNode(String title, this.node, this._modelRef) : super(title);

  Undo undo() {
    var redo = UndoAddNode(_toggleTitleRedo(title), node, _modelRef);
    _modelRef.leafNodes.add(node);
    return redo;
  }
}
