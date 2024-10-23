// stored_node.dart, defines node types for storage in the tree model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'display_node.dart';
import 'fields.dart';
import 'parsed_line.dart';
import 'structure.dart' show Structure;

/// Interface definition for title and rule nodes.
abstract class StoredNode {
  /// modelRef must be set extenally before any node creation.
  static late Structure modelRef;
  StoredNode? storedParent;
  RuleNode? childRuleNode;

  /// Used to create subclass node types.
  factory StoredNode(Map<String, dynamic> jsonData,
      [StoredNode? storedParent]) {
    if (jsonData.containsKey('title')) {
      return TitleNode._fromJson(jsonData, storedParent);
    } else if (jsonData.containsKey('rule')) {
      return RuleNode._fromJson(jsonData, storedParent);
    }
    throw const FormatException('Node does not match a title or a rule node');
  }

  // Using getters avoid needing to initialize abstract variables.

  /// Includes children of types [TitleNode] and [[RuleNode].
  List<StoredNode> storedChildren();

  Map<String, dynamic> toJson();
}

/// Node type that has a fixed title.
class TitleNode implements StoredNode, DisplayNode {
  final _titleChildren = <TitleNode>[];
  final _groupChildren = <GroupNode>[];
  @override
  RuleNode? childRuleNode;
  @override
  late String title;
  @override
  var isOpen = false;
  @override
  var isStale = false;
  @override
  var data = <String, List<String>>{};

  // Keep storedParent and parent consistent.
  StoredNode? _storedParent;
  DisplayNode? _parent;
  @override
  StoredNode? get storedParent => _storedParent;
  @override
  set storedParent(StoredNode? p) {
    _storedParent = p;
    _parent = p as DisplayNode?;
  }

  // Keep parent and storedParent consistent.
  @override
  DisplayNode? get parent => _parent;
  @override
  set parent(DisplayNode? p) {
    _parent = p;
    _storedParent = p as StoredNode?;
  }

  TitleNode({required this.title, DisplayNode? parent}) {
    _parent = parent;
    _storedParent = parent as StoredNode?;
  }

  TitleNode._fromJson(Map<String, dynamic> jsonData,
      [StoredNode? storedParent]) {
    _storedParent = storedParent;
    _parent = storedParent as DisplayNode?;
    title = jsonData['title']!;
    final storedChildren = <StoredNode>[];
    for (var childData in jsonData['children'] ?? []) {
      storedChildren.add(StoredNode(childData, this));
    }
    if (storedChildren.length == 1 && storedChildren[0] is RuleNode) {
      childRuleNode = storedChildren[0] as RuleNode;
    } else {
      _titleChildren.addAll(storedChildren.cast<TitleNode>());
    }
  }

  @override
  bool get hasChildren => _titleChildren.isNotEmpty || childRuleNode != null;

  @override
  List<StoredNode> storedChildren() {
    if (childRuleNode != null) return [childRuleNode!];
    return _titleChildren;
  }

  @override
  List<LeafNode> get availableNodes => StoredNode.modelRef.leafNodes;

  /// Return child nodes.
  ///
  /// Update child groups if [forceUpdate] is true or if the list is empty.
  @override
  List<DisplayNode> childNodes({bool forceUpdate = false}) {
    if (childRuleNode != null) {
      if (forceUpdate || _groupChildren.isEmpty) {
        _groupChildren.clear();
        _groupChildren.addAll(
          childRuleNode!.createGroups(StoredNode.modelRef.leafNodes, this),
        );
      }
      return _groupChildren;
    }
    return _titleChildren.cast<DisplayNode>();
  }

  void replaceChildRule(RuleNode? newChildRuleNode) {
    childRuleNode = newChildRuleNode;
    if (newChildRuleNode != null) {
      newChildRuleNode.storedParent = this;
    }
    _titleChildren.clear();
    _groupChildren.clear();
  }

  /// Adds at end if afterChild and pos are both null.
  void addChildTitleNode(TitleNode newNode, {TitleNode? afterChild, int? pos}) {
    assert(childRuleNode == null);
    if (afterChild != null) {
      pos = _titleChildren.indexOf(afterChild) + 1;
    } else {
      pos ??= _titleChildren.length;
    }
    _titleChildren.insert(pos, newNode);
    newNode.storedParent = this;
  }

  /// Replace a given child title node with a list of new nodes.
  void replaceChildTitleNode(TitleNode oldNode, List<TitleNode> newNodes) {
    var pos = _titleChildren.indexOf(oldNode);
    assert(pos >= 0);
    for (var newNode in newNodes) {
      newNode.storedParent = this;
    }
    _titleChildren.replaceRange(pos, pos + 1, newNodes);
  }

  void removeChildTitleNode(TitleNode node) {
    _titleChildren.remove(node);
  }

  void updateChildParentRefs() {
    for (var child in _titleChildren) {
      child.storedParent = this;
    }
  }

  @override
  Map<String, dynamic> toJson() {
    var result = <String, dynamic>{'title': title};
    if (hasChildren) {
      final childList = <Map<String, dynamic>>[];
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
class RuleNode implements StoredNode {
  @override
  StoredNode? storedParent;
  @override
  RuleNode? childRuleNode;
  late ParsedLine ruleLine;

  /// Used to sort [GroupNode] types.
  late List<SortKey> sortFields;
  bool hasCustomSortFields = false;

  /// Used to sort [LeafNode] types if there is not a [childRuleNode].
  late List<SortKey> childSortFields;
  bool hasCustomChildSortFields = false;

  RuleNode({required String rule, this.storedParent}) {
    ruleLine = ParsedLine(rule, StoredNode.modelRef.fieldMap);
    setDefaultRuleSortFields();
    setDefaultChildSortFields();
  }

  RuleNode._fromJson(Map<String, dynamic> jsonData, [this.storedParent]) {
    ruleLine = ParsedLine(jsonData['rule']!, StoredNode.modelRef.fieldMap);
    final sortData = jsonData['sortfields'];
    if (sortData != null) {
      sortFields = [
        for (var fieldName in sortData)
          SortKey.fromString(fieldName, StoredNode.modelRef.fieldMap)
      ];
      hasCustomSortFields = true;
    } else {
      setDefaultRuleSortFields();
    }
    final childSortData = jsonData['childsortfields'];
    if (childSortData != null) {
      childSortFields = [
        for (var fieldName in childSortData)
          SortKey.fromString(fieldName, StoredNode.modelRef.fieldMap)
      ];
      hasCustomChildSortFields = true;
    } else {
      setDefaultChildSortFields();
    }
    final childData = jsonData['child'];
    if (childData != null) {
      childRuleNode = RuleNode._fromJson(childData, this);
    }
  }

  @override
  List<StoredNode> storedChildren() {
    if (childRuleNode != null) return [childRuleNode!];
    return [];
  }

  void replaceChildRule(RuleNode? newChildRuleNode) {
    childRuleNode = newChildRuleNode;
    if (newChildRuleNode != null) {
      newChildRuleNode.storedParent = this;
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
      final ruleFields = ruleLine.fields();
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

  /// Set [childSortFields] to default of all fields not in rules if not custom.
  void setDefaultChildSortFields() {
    if (!hasCustomChildSortFields) {
      childSortFields = [
        for (var field in StoredNode.modelRef.fieldMap.values) SortKey(field)
      ];
      StoredNode parent = this;
      while (parent is RuleNode) {
        for (var field in parent.ruleLine.fields()) {
          childSortFields.removeWhere((key) => key.keyField == field);
        }
        parent = parent.storedParent!;
      }
    }
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

  /// Return a new list of [GroupNode] based on this node's rule.
  List<GroupNode> createGroups(List<LeafNode> availableNodes,
      [DisplayNode? parentRef]) {
    final nodeData = <String, List<LeafNode>>{};
    for (var node in availableNodes) {
      for (var line in ruleLine.formattedLineList(node)) {
        nodeData.update(
          line,
          (List<LeafNode> list) => list + [node],
          ifAbsent: () => [node],
        );
      }
    }
    final oldGroups = <String, GroupNode>{};
    if (parentRef is GroupNode) {
      for (var grp in (parentRef as GroupNode).previousChildNodes()) {
        oldGroups[grp.title] = grp;
      }
    } else if (parentRef is TitleNode) {
      for (var node in parentRef._groupChildren) {
        oldGroups[node.title] = node;
      }
    }
    final groups = <GroupNode>[];
    for (var line in nodeData.keys) {
      final groupNode = oldGroups[line] ?? GroupNode(line, this, parentRef);
      oldGroups.remove(line);
      groupNode.ruleRef = this;
      groupNode.matchingNodes = nodeData[line]!;
      groupNode.data.clear();
      for (var field in ruleLine.fields()) {
        final fieldValue = groupNode.matchingNodes[0].data[field.name];
        if (fieldValue != null) groupNode.data[field.name] = fieldValue;
      }
      groups.add(groupNode);
    }
    StoredNode.modelRef.obsoleteNodes.addAll(oldGroups.values);
    nodeFullSort(groups, sortFields);
    return groups;
  }

  @override
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
    if (childRuleNode != null) {
      result['child'] = childRuleNode!.toJson();
    }
    return result;
  }
}
