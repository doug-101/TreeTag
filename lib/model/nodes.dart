// nodes.dart, defines node types for the tree model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'fields.dart';
import 'parsed_line.dart';
import 'structure.dart' show Structure;

/// Interface definition for multiple types of tree nodes.
abstract class Node {
  late final Structure modelRef;
  Node? parent;

  /// Used to create stored nodes ([TitleNode] and [RuleNode] types).
  factory Node(Map<String, dynamic> jsonData, Structure modelRef,
      [Node? parent]) {
    if (jsonData.containsKey('title'))
      return TitleNode._fromJson(jsonData, modelRef, parent);
    if (jsonData.containsKey('rule'))
      return RuleNode._fromJson(jsonData, modelRef, parent);
    throw FormatException('Node does not match a title or a rule node');
  }

  // Using getters avoid needing to initialize abstract variables.

  /// Includes children of types [TitleNode], [GroupNode] and [LeafNode].
  bool get hasChildren;

  bool get isOpen;
  void set isOpen(bool value);

  /// Used to mark nodes that skipped a child update due to being closed.
  bool get isStale;
  void set isStale(bool value);

  /// The [LeafNode] types that are still available for placement at each level.
  List<LeafNode> get availableNodes;
  String get title;

  /// [data] is needed for sorting GroupNodes as well as in LeafNode.
  Map<String, String> get data;

  List<Node> childNodes({bool forceUpdate});

  /// Includes children of types [TitleNode] and [[RuleNode].
  List<Node> storedChildren();

  Map<String, dynamic> toJson();
}

/// Node type that has a fixed title.
///
/// Can have other [TitleNode] or [GroupNode] types as children.
/// [GroupNode] children are generated by a [childRuleNode].
class TitleNode implements Node {
  late Structure modelRef;
  Node? parent;
  late String title;
  final _children = <Node>[];
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
      _children.clear();
    }
  }

  bool get hasChildren => _children.isNotEmpty || childRuleNode != null;

  List<LeafNode> get availableNodes => modelRef.leafNodes;

  /// Return child nodes.
  ///
  /// Update child groups if [forceUpdate] is true or if the list is empty.
  List<Node> childNodes({bool forceUpdate = false}) {
    if (childRuleNode != null && (forceUpdate || _children.length == 0)) {
      var newChildren = childRuleNode!.createGroups(modelRef.leafNodes, this);
      _children.clear();
      _children.addAll(newChildren);
    }
    return _children;
  }

  List<Node> storedChildren() {
    if (childRuleNode != null) return [childRuleNode!];
    return _children;
  }

  void replaceChildRule(RuleNode? newChildRuleNode) {
    childRuleNode = newChildRuleNode;
    if (newChildRuleNode != null) {
      newChildRuleNode.parent = this;
    }
    _children.clear();
  }

  /// Adds at end if afterChild and pos are both null.
  void addChildTitleNode(TitleNode newNode, {TitleNode? afterChild, int? pos}) {
    assert(childRuleNode == null);
    if (afterChild != null) {
      pos = _children.indexOf(afterChild) + 1;
    } else if (pos == null) {
      pos = _children.length;
    }
    _children.insert(pos, newNode);
    newNode.parent = this;
  }

  /// Replace a given child title node with a list of new nodes.
  void replaceChildTitleNode(TitleNode oldNode, List<Node> newNodes) {
    var pos = _children.indexOf(oldNode);
    assert(pos >= 0);
    newNodes.forEach((newNode) {
      newNode.parent = this;
    });
    _children.replaceRange(pos, pos + 1, newNodes);
  }

  void removeChildTitleNode(TitleNode node) {
    _children.remove(node);
  }

  void updateChildParentRefs() {
    _children.forEach((child) {
      child.parent = this;
    });
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

/// A stored node type that generated [GroupNode] types in its place.
///
/// Can have another [RuleNode] as a child for a further breakdown.
class RuleNode implements Node {
  late Structure modelRef;
  Node? parent;
  late ParsedLine ruleLine;

  /// Used to sort [GroupNode] types.
  late List<SortKey> sortFields;
  bool hasCustomSortFields = false;

  /// Used to sort [LeafNode] types if there is not a [childRuleNode].
  late List<SortKey> childSortFields;
  bool hasCustomChildSortFields = false;

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
      hasCustomSortFields = true;
    } else {
      setDefaultRuleSortFields();
    }
    var childSortData = jsonData['childsortfields'];
    if (childSortData != null) {
      childSortFields = [
        for (var fieldName in childSortData)
          SortKey.fromString(fieldName, modelRef.fieldMap)
      ];
      hasCustomChildSortFields = true;
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

  void replaceChildRule(RuleNode? newChildRuleNode) {
    childRuleNode = newChildRuleNode;
    if (newChildRuleNode != null) {
      newChildRuleNode.parent = this;
    }
  }

  /// Updates only non-custom sort fields unless [checkCustom] is true.
  ///
  /// Returns true if custom sort fields have changed.
  bool setDefaultRuleSortFields({bool checkCustom = false}) {
    var hasCustomChange = false;
    if (!hasCustomSortFields) {
      sortFields = [for (var field in ruleLine.fields()) SortKey(field)];
    } else if (checkCustom) {
      // Only keep unique sort fields that are found in the rules.
      var ruleFields = ruleLine.fields();
      for (var key in List.of(sortFields)) {
        if (!ruleFields.contains(key.keyField)) {
          sortFields.remove(key);
          hasCustomChange = true;
        }
      }
      if (sortFields.isEmpty) {
        hasCustomSortFields = false;
        hasCustomChange = false;
        setDefaultRuleSortFields();
      }
    }
    return hasCustomChange;
  }

  /// Set [childSortFields] to default of all fields if not custom.
  void setDefaultChildSortFields() {
    if (!hasCustomChildSortFields)
      childSortFields = [
        for (var field in modelRef.fieldMap.values) SortKey(field)
      ];
  }

  /// Return true if [field] is used in a custom child sort field.
  bool isFieldInChildSort(Field field) {
    if (!hasCustomChildSortFields) return false;
    for (var key in childSortFields) {
      if (key.keyField == field) return true;
    }
    return false;
  }

  /// Return true if [field] is removed from a custom child sort field.
  bool removeChildSortField(Field field) {
    if (!hasCustomChildSortFields) return false;
    for (var key in childSortFields) {
      if (key.keyField == field) {
        if (childSortFields.length > 1) {
          childSortFields.remove(key);
        } else {
          hasCustomChildSortFields = false;
        }
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    var result = <String, dynamic>{};
    result['rule'] = ruleLine.getUnparsedLine();
    if (hasCustomSortFields) {
      result['sortfields'] = [
        for (var sortKey in sortFields) sortKey.toString()
      ];
    }
    if (hasCustomChildSortFields) {
      result['childsortfields'] = [
        for (var sortKey in childSortFields) sortKey.toString()
      ];
    }
    if (hasChildren) {
      result['child'] = childRuleNode!.toJson();
    }
    return result;
  }

  /// Return a new list of [GroupNode] based on this node's rule.
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
      for (var grp in parentRef._childGroups) {
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
        var fieldValue = groupNode.matchingNodes[0].data[field.name];
        if (fieldValue != null) groupNode.data[field.name] = fieldValue;
      }
      groups.add(groupNode);
    }
    modelRef.obsoleteNodes.addAll(oldGroups.values);
    nodeFullSort(groups, sortFields);
    return groups;
  }
}

/// A generated (non-stored) node type that covers a specific rule category.
///
/// Has other [GroupNode] types as children if there is a further breakdown,
/// otherwise has [LeafNode] types as children.
class GroupNode implements Node {
  late Structure modelRef;
  Node? parent;
  late String title;
  late RuleNode _ruleRef;
  var matchingNodes = <LeafNode>[];
  final _childGroups = <GroupNode>[];
  var hasChildren = true;
  var isOpen = false;
  var isStale = false;
  var data = <String, String>{};

  /// Flag to avoid redundant re-sorting of child nodes.
  var nodesSorted = false;

  GroupNode(this.title, this.modelRef, this._ruleRef, this.parent);

  List<LeafNode> get availableNodes => matchingNodes;

  /// Return child nodes.
  ///
  /// Update child groups if [forceUpdate] is true or if the list is empty.
  List<Node> childNodes({bool forceUpdate = false}) {
    if (_ruleRef.childRuleNode != null) {
      if (forceUpdate || _childGroups.isEmpty) {
        var newChildren =
            _ruleRef.childRuleNode!.createGroups(matchingNodes, this);
        _childGroups.clear();
        _childGroups.addAll(newChildren);
        nodeFullSort(_childGroups, _ruleRef.sortFields);
      }
      return _childGroups;
    }
    _childGroups.clear();
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

/// The lowest level nodes that contain the [data].
///
/// They are stored separately from other tree nodes and placed dynamically.
class LeafNode implements Node {
  late Structure modelRef;

  /// [parent] is ambiguous; not used for leaves
  Node? parent;

  late Map<String, String> data;
  final hasChildren = false;
  var isOpen = false;
  var isStale = false;
  var availableNodes = <LeafNode>[];

  /// Stores group parents for leaf instances with expanded output.
  final _expandedParents = <Node>{};

  LeafNode({required this.data, required this.modelRef});

  LeafNode.fromJson(Map<String, dynamic> jsonData, this.modelRef) {
    data = jsonData.cast<String, String>();
  }

  List<Node> childNodes({bool forceUpdate = false}) => [];

  List<Node> storedChildren() => [];

  String get title => modelRef.titleLine.formattedLine(this);

  List<String> outputs() {
    var lines = [
      for (var line in modelRef.outputLines) line.formattedLine(this)
    ];
    lines.removeWhere((line) => line.isEmpty);
    return lines;
  }

  bool isExpanded(Node parent) => _expandedParents.contains(parent);

  void toggleExpanded(Node parent) {
    if (!_expandedParents.remove(parent)) {
      _expandedParents.add(parent);
    }
  }

  Map<String, dynamic> toJson() {
    var result = <String, dynamic>{};
    result = data;
    return result;
  }

  /// Return true if all of the searchTrems are found in the data output.
  bool isSearchMatch(List<String> searchTerms, Field? searchField) {
    var text = searchField == null
        ? outputs().join('\n').toLowerCase()
        : searchField.outputText(this);
    for (var term in searchTerms) {
      if (!text.contains(term)) return false;
    }
    return true;
  }

  /// Return true if the regular expression is found in the data output.
  bool isRegExpMatch(RegExp exp, Field? searchField) {
    var text = searchField == null
        ? outputs().join('\n').toLowerCase()
        : searchField.outputText(this);
    return exp.hasMatch(text);
  }
}

/// A combination of a [Field] and a direction used for sorting.
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
