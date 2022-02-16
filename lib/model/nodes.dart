// nodes.dart, defines node types for the tree model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'fields.dart';
import 'parsed_line.dart';
import 'structure.dart' show Structure;

/// Interface definition for multiple types of tree nodes.
abstract class Node {
  late Structure modelRef;
  Node? parent;

  factory Node(Map<String, dynamic> jsonData, Structure modelRef,
      [Node? parent]) {
    if (jsonData.containsKey('title'))
      return TitleNode._fromJson(jsonData, modelRef, parent);
    if (jsonData.containsKey('rule'))
      return RuleNode._fromJson(jsonData, modelRef, parent);
    throw FormatException('Node does not match a title or a rule node');
  }

  // Using getters avoid needing to initialize abstract variables.
  bool get hasChildren;
  bool get isOpen;
  void set isOpen(bool value);
  bool get isStale;
  void set isStale(bool value);
  List<LeafNode> get availableNodes;
  String get title;
  // Needed for sorting GroupNodes as well as in LeafNode.
  Map<String, String> get data;

  List<Node> childNodes({bool forceUpdate});

  List<Node> storedChildren();
  Map<String, dynamic> toJson();
}

class TitleNode implements Node {
  late Structure modelRef;
  Node? parent;
  late String title;
  var _children = <Node>[];
  RuleNode? childRuleNode;
  var isOpen = false;
  var isStale = false;
  var data = <String, String>{};

  TitleNode({required this.title, required this.modelRef, this.parent});

  TitleNode._fromJson(Map<String, dynamic> jsonData, this.modelRef,
      [this.parent]) {
    title = jsonData['title']!;
    for (var childData in jsonData['children'] ?? []) {
      _children.add(Node(childData, modelRef, this));
    }
    if (_children.length == 1 && _children[0] is RuleNode) {
      childRuleNode = _children[0] as RuleNode;
      _children = [];
    }
  }

  bool get hasChildren => _children.isNotEmpty || childRuleNode != null;
  List<LeafNode> get availableNodes => modelRef.leafNodes;

  List<Node> childNodes({bool forceUpdate = false}) {
    if (childRuleNode != null && (forceUpdate || _children.length == 0)) {
      _children = childRuleNode!.createGroups(modelRef.leafNodes, this);
    }
    return _children;
  }

  List<Node> storedChildren() {
    if (childRuleNode != null) return [childRuleNode!];
    return _children;
  }

  void replaceChildRule(RuleNode? newChildRuleNode) {
    childRuleNode = newChildRuleNode;
    _children.clear();
  }

  void addChildTitleNode(TitleNode newNode, {TitleNode? afterChild}) {
    // Adds at end if afterChild is null.
    assert(childRuleNode == null);
    var pos = 0;
    if (afterChild != null) {
      pos = _children.indexOf(afterChild) + 1;
    } else {
      pos = _children.length;
    }
    _children.insert(pos, newNode as Node);
  }

  void removeTitleChild(TitleNode node) {
    _children.remove(node);
  }

  Map<String, dynamic> toJson() {
    var result = <String, dynamic>{'title': title};
    if (hasChildren) {
      var childList = <Map<String, dynamic>>[];
      for (var child in storedChildren()) {
        childList.add(child.toJson());
      }
      result['children'] = childList;
    }
    return result;
  }
}

class RuleNode implements Node {
  late Structure modelRef;
  Node? parent;
  late ParsedLine ruleLine;
  late List<SortKey> sortFields;
  bool hasUniqueSortFields = false;
  late List<SortKey> childSortFields;
  bool hasUniqueChildSortFields = false;
  RuleNode? childRuleNode;
  var isOpen = false;
  var isStale = false;
  var availableNodes = <LeafNode>[];
  var title = '';
  var data = <String, String>{};

  RuleNode({required String rule, required this.modelRef, this.parent}) {
    ruleLine = ParsedLine(rule, modelRef.fieldMap);
    setDefaultRuleSortFields();
    setDefaultChildSortFields();
  }

  RuleNode._fromJson(Map<String, dynamic> jsonData, this.modelRef,
      [this.parent]) {
    ruleLine = ParsedLine(jsonData['rule']!, modelRef.fieldMap);
    var sortData = jsonData['sortfields'];
    if (sortData != null) {
      sortFields = [
        for (var fieldName in sortData)
          SortKey.fromString(fieldName, modelRef.fieldMap)
      ];
      hasUniqueSortFields = true;
    } else {
      setDefaultRuleSortFields();
    }
    var childSortData = jsonData['childsortfields'];
    if (childSortData != null) {
      childSortFields = [
        for (var fieldName in childSortData)
          SortKey.fromString(fieldName, modelRef.fieldMap)
      ];
      hasUniqueChildSortFields = true;
    } else {
      setDefaultChildSortFields();
    }
    var childData = jsonData['child'];
    if (childData != null) {
      childRuleNode = RuleNode._fromJson(childData, modelRef, this);
    }
  }

  bool get hasChildren => childRuleNode != null;

  List<Node> childNodes({bool forceUpdate = false}) => [];

  List<Node> storedChildren() {
    if (childRuleNode != null) return [childRuleNode!];
    return [];
  }

  void setDefaultRuleSortFields({bool checkUnique = false}) {
    if (!hasUniqueSortFields) {
      sortFields = [for (var field in ruleLine.fields()) SortKey(field)];
    } else if (checkUnique) {
      // Only keep unique sort fields that are found in the rules.
      var ruleFields = ruleLine.fields();
      for (var key in List.of(sortFields)) {
        if (!ruleFields.contains(key.keyField)) sortFields.remove(key);
      }
      if (sortFields.isEmpty) {
        hasUniqueSortFields = false;
        setDefaultRuleSortFields();
      }
    }
  }

  void setDefaultChildSortFields() {
    if (!hasUniqueChildSortFields)
      childSortFields = [
        for (var field in modelRef.fieldMap.values) SortKey(field)
      ];
  }

  bool isFieldInChildSort(Field field) {
    if (!hasUniqueChildSortFields) return false;
    for (var key in childSortFields) {
      if (key.keyField == field) return true;
    }
    return false;
  }

  bool removeChildSortField(Field field) {
    if (!hasUniqueChildSortFields) return false;
    for (var key in childSortFields) {
      if (key.keyField == field) {
        if (childSortFields.length > 1) {
          childSortFields.remove(key);
        } else {
          hasUniqueChildSortFields = false;
        }
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    var result = <String, dynamic>{};
    result['rule'] = ruleLine.getUnparsedLine();
    if (hasUniqueSortFields) {
      result['sortfields'] = [
        for (var sortKey in sortFields) sortKey.toString()
      ];
    }
    if (hasUniqueChildSortFields) {
      result['childsortfields'] = [
        for (var sortKey in childSortFields) sortKey.toString()
      ];
    }
    if (hasChildren) {
      result['child'] = childRuleNode!.toJson();
    }
    return result;
  }

  List<GroupNode> createGroups(List<LeafNode> availableNodes,
      [Node? parentRef]) {
    var nodeData = <String, List<LeafNode>>{};
    for (var node in availableNodes) {
      nodeData.update(
          ruleLine.formattedLine(node), (List<LeafNode> list) => list + [node],
          ifAbsent: () => [node]);
    }
    var oldGroups = <String, GroupNode>{};
    if (parentRef is GroupNode) {
      for (var grp in parentRef.childGroups) {
        oldGroups[grp.title] = grp;
      }
    } else if (parentRef is TitleNode) {
      for (var node in parentRef._children) {
        if (node is GroupNode) oldGroups[node.title] = node;
      }
    }
    var groups = <GroupNode>[];
    for (var line in nodeData.keys) {
      var groupNode =
          oldGroups[line] ?? GroupNode(line, modelRef, this, parentRef);
      oldGroups.remove(line);
      groupNode._ruleRef = this;
      groupNode.matchingNodes = nodeData[line]!;
      groupNode.data.clear();
      for (var field in ruleLine.fields()) {
        groupNode.data[field.name] =
            groupNode.matchingNodes[0].data[field.name]!;
      }
      groups.add(groupNode);
    }
    modelRef.obsoleteNodes.addAll(oldGroups.values);
    nodeFullSort(groups, sortFields);
    return groups;
  }
}

class GroupNode implements Node {
  late Structure modelRef;
  Node? parent;
  late String title;
  late RuleNode _ruleRef;
  var matchingNodes = <LeafNode>[];
  var childGroups = <GroupNode>[];
  var hasChildren = true;
  var isOpen = false;
  var isStale = false;
  var data = <String, String>{};
  var nodesSorted = false;

  GroupNode(this.title, this.modelRef, this._ruleRef, this.parent);

  List<LeafNode> get availableNodes => matchingNodes;

  List<Node> childNodes({bool forceUpdate = false}) {
    if (_ruleRef.childRuleNode != null) {
      if (forceUpdate || childGroups.isEmpty) {
        childGroups = _ruleRef.childRuleNode!.createGroups(matchingNodes, this);
        nodeFullSort(childGroups, _ruleRef.sortFields);
      }
      return childGroups;
    }
    childGroups.clear();
    if (forceUpdate || !nodesSorted) {
      nodeFullSort(matchingNodes, _ruleRef.childSortFields);
      nodesSorted = true;
    }
    return matchingNodes;
  }

  List<Node> storedChildren() => [];

  Map<String, dynamic> toJson() {
    var result = <String, dynamic>{};
    return result;
  }
}

class LeafNode implements Node {
  late Structure modelRef;
  // parent is ambiguous; not used for leaves
  Node? parent;
  late Map<String, String> data;
  final hasChildren = false;
  var isOpen = false;
  var isStale = false;
  var availableNodes = <LeafNode>[];

  LeafNode({required this.data, required this.modelRef});

  LeafNode.fromJson(Map<String, dynamic> jsonData, this.modelRef) {
    data = jsonData.cast<String, String>();
  }

  List<Node> childNodes({bool forceUpdate = false}) => [];

  List<Node> storedChildren() => [];

  String get title => modelRef.titleLine.formattedLine(this);

  List<String> outputs() {
    return [for (var line in modelRef.outputLines) line.formattedLine(this)];
  }

  Map<String, dynamic> toJson() {
    var result = <String, dynamic>{};
    result = data;
    return result;
  }
}

class SortKey {
  late final Field keyField;
  bool isAscend = true;

  SortKey(this.keyField, [this.isAscend = true]);

  SortKey.fromString(String fieldName, Map<String, Field> fieldMap) {
    if (fieldName[0] == '+' || fieldName[0] == '-') {
      if (fieldName[0] == '-') isAscend = false;
      fieldName = fieldName.substring(1);
    }
    keyField = fieldMap[fieldName]!;
  }

  SortKey.copy(SortKey origKey) {
    keyField = origKey.keyField;
    isAscend = origKey.isAscend;
  }

  String toString() {
    return (isAscend ? '+' : '-') + keyField.name;
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
