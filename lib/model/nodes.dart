// nodes.dart, defines node types for the tree model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'fields.dart';
import 'parsed_line.dart';
import 'struct.dart' show leafNodes, fieldMap, titleLine, outputLines;

/// Interface definition for multiple types of tree nodes.
abstract class Node {
  Node? parent;

  factory Node(Map<String, dynamic> jsonData, [Node? parent]) {
    if (jsonData.containsKey('title'))
      return TitleNode._fromJson(jsonData, parent);
    if (jsonData.containsKey('rule'))
      return RuleNode._fromJson(jsonData, parent);
    throw FormatException('Node does not match a title or a rule node');
  }

  // Using getters avoid needing to initialize abstract variables.
  bool get hasChildren;
  bool get isOpen;
  void set isOpen(bool value);
  List<LeafNode> get availableNodes;
  String get title;
  // Needed for sorting GroupNodes as well as in LeafNode.
  Map<String, String> get data;

  List<Node> childNodes({bool forceUpdate});

  List<Node> storedChildren();
}

class TitleNode implements Node {
  Node? parent;
  late String title;
  var _children = <Node>[];
  RuleNode? _childRuleNode;
  var isOpen = false;
  var data = <String, String>{};

  TitleNode._fromJson(Map<String, dynamic> jsonData, [this.parent]) {
    title = jsonData['title']!;
    for (var childData in jsonData['children'] ?? []) {
      _children.add(Node(childData, this));
    }
    if (_children.length == 1 && _children[0] is RuleNode) {
      _childRuleNode = _children[0] as RuleNode?;
      _children = [];
    }
  }

  bool get hasChildren => _children.isNotEmpty || _childRuleNode != null;
  List<LeafNode> get availableNodes => leafNodes;

  List<Node> childNodes({bool forceUpdate = false}) {
    if (_childRuleNode != null && (forceUpdate || _children.length == 0)) {
      _children = _childRuleNode!.createGroups(leafNodes, this);
    }
    return _children;
  }

  List<Node> storedChildren() {
    if (_childRuleNode != null) return [_childRuleNode!];
    return _children;
  }
}

class RuleNode implements Node {
  Node? parent;
  late ParsedLine _ruleLine;
  late List<SortKey> sortFields;
  late List<SortKey> childSortFields;
  RuleNode? _childRuleNode;
  var isOpen = false;
  var availableNodes = <LeafNode>[];
  var title = '';
  var data = <String, String>{};

  RuleNode._fromJson(Map<String, dynamic> jsonData, [this.parent]) {
    _ruleLine = ParsedLine(jsonData['rule']!, fieldMap);
    var sortData = jsonData['sortfields'];
    if (sortData != null) {
      sortFields = [
        for (var fieldName in sortData) SortKey.fromString(fieldName)
      ];
    } else {
      sortFields = [for (var field in _ruleLine.lineFields) SortKey(field)];
    }
    var childSortData = jsonData['childsortfields'];
    if (childSortData != null) {
      childSortFields = [
        for (var fieldName in childSortData) SortKey.fromString(fieldName)
      ];
    } else {
      childSortFields = [for (var field in fieldMap.values) SortKey(field)];
    }
    var childData = jsonData['child'];
    if (childData != null) {
      _childRuleNode = RuleNode._fromJson(childData, this);
    }
  }

  bool get hasChildren => _childRuleNode != null;

  List<Node> childNodes({bool forceUpdate = false}) => [];

  List<Node> storedChildren() {
    if (_childRuleNode != null) return [_childRuleNode!];
    return [];
  }

  List<GroupNode> createGroups(List<LeafNode> availableNodes,
      [Node? parentRef]) {
    var nodeData = <String, List<LeafNode>>{};
    for (var node in availableNodes) {
      nodeData.update(
          _ruleLine.formattedLine(node), (List<LeafNode> list) => list + [node],
          ifAbsent: () => [node]);
    }
    var groups = <GroupNode>[];
    for (var line in nodeData.keys) {
      var groupNode = GroupNode(line, this, parentRef);
      groupNode.matchingNodes = nodeData[line]!;
      for (var field in _ruleLine.lineFields) {
        groupNode.data[field.name] =
            groupNode.matchingNodes[0].data[field.name]!;
      }
      groups.add(groupNode);
    }
    nodeFullSort(groups, sortFields);
    return groups;
  }
}

class GroupNode implements Node {
  Node? parent;
  late String title;
  late RuleNode _ruleRef;
  var matchingNodes = <LeafNode>[];
  var childGroups = <GroupNode>[];
  var hasChildren = true;
  var isOpen = false;
  var data = <String, String>{};
  var nodesSorted = false;

  GroupNode(this.title, this._ruleRef, this.parent);

  List<LeafNode> get availableNodes => matchingNodes;

  List<Node> childNodes({bool forceUpdate = false}) {
    if (_ruleRef._childRuleNode != null &&
        (forceUpdate || childGroups.length == 0)) {
      childGroups = _ruleRef._childRuleNode!.createGroups(matchingNodes, this);
      nodeFullSort(childGroups, _ruleRef.sortFields);
    }
    if (childGroups.length > 0) {
      return childGroups;
    }
    if (forceUpdate || !nodesSorted) {
      nodeFullSort(matchingNodes, _ruleRef.childSortFields);
      nodesSorted = true;
    }
    return matchingNodes;
  }

  List<Node> storedChildren() => [];
}

class LeafNode implements Node {
  // parent is ambiguous; not used for leaves
  Node? parent;
  late Map<String, String> data;
  final hasChildren = false;
  var isOpen = false;
  var availableNodes = <LeafNode>[];

  LeafNode(Map<String, dynamic> jsonData) {
    data = jsonData.cast<String, String>();
  }

  List<Node> childNodes({bool forceUpdate = false}) => [];

  List<Node> storedChildren() => [];

  String get title => titleLine.formattedLine(this);

  List<String> outputs() {
    return [for (var line in outputLines) line.formattedLine(this)];
  }
}

class SortKey {
  late final Field keyField;
  bool isAscend = true;

  SortKey(this.keyField, [this.isAscend = true]);

  SortKey.fromString(String fieldName) {
    if (fieldName[0] == '+' || fieldName[0] == '-') {
      if (fieldName[0] == '-') isAscend = false;
      fieldName = fieldName.substring(1);
    }
    keyField = fieldMap[fieldName]!;
  }
}

/// A stable insertion sort for nodes using multiple keys.
void nodeFullSort(List<Node> nodes, List<SortKey> keys) {
  for (var key in keys.reversed) {
    nodeSingleSort(nodes, key);
  }
}

/// A stable insertion sort for nodes using a single field key.
void nodeSingleSort(List<Node> nodes, SortKey key) {
  var start = 0;
  var end = nodes.length;
  for (var pos = start + 1; pos < end; pos++) {
    var min = start;
    var max = pos;
    var node = nodes[pos];
    while (min < max) {
      var mid = min + ((max - min) >> 1);
      var comparison = key.keyField.compareNodes(node, nodes[mid]);
      if (!key.isAscend) comparison = -comparison;
      if (comparison < 0) {
        max = mid;
      } else {
        min = mid + 1;
      }
    }
    nodes.setRange(min + 1, pos + 1, nodes, min);
    nodes[min] = node;
  }
}
