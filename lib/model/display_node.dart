// display_node.dart, defines node types for display in the tree model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'fields.dart';
import 'stored_node.dart';
import 'structure.dart' show Structure;

/// Interface definition for title, group and leaf nodes.
abstract class DisplayNode {
  /// modelRef must be set extenally before any node creation.
  static late Structure modelRef;

  /// Needed for titles and groups; null for leaf nodes (ambiguous).
  DisplayNode? parent;

  // Using getters avoid needing to initialize abstract variables.

  String get title;
  bool get hasChildren;

  bool get isOpen;
  set isOpen(bool value);

  /// Used to mark nodes that skipped a child update due to being closed.
  bool get isStale;
  set isStale(bool value);

  /// The [LeafNode] types that are still available for placement at each level.
  List<LeafNode> get availableNodes;

  /// Needed for grup node sorting and for leaf nodes (not title nodes).
  Map<String, String> get data;

  List<DisplayNode> childNodes({bool forceUpdate});
}

/// A generated (non-stored) node type that covers a specific rule category.
///
/// Has other [GroupNode] types as children if there is a further breakdown,
/// otherwise has [LeafNode] types as children.
class GroupNode implements DisplayNode {
  @override
  DisplayNode? parent;
  @override
  late String title;
  @override
  var hasChildren = true;
  @override
  var isOpen = false;
  @override
  var isStale = false;
  @override
  List<LeafNode> get availableNodes => matchingNodes;
  @override
  var data = <String, String>{};
  RuleNode ruleRef;
  var matchingNodes = <LeafNode>[];
  final _childGroups = <GroupNode>[];

  /// Flag to avoid redundant re-sorting of child nodes.
  var nodesSorted = false;

  GroupNode(this.title, this.ruleRef, this.parent);

  /// Return child nodes.
  ///
  /// Update child groups if [forceUpdate] is true or if the list is empty.
  @override
  List<DisplayNode> childNodes({bool forceUpdate = false}) {
    if (ruleRef.childRuleNode != null) {
      if (forceUpdate || _childGroups.isEmpty) {
        final newChildren =
            ruleRef.childRuleNode!.createGroups(matchingNodes, this);
        _childGroups.clear();
        _childGroups.addAll(newChildren);
        nodeFullSort(_childGroups, ruleRef.sortFields);
      }
      return _childGroups;
    }
    _childGroups.clear();
    if (forceUpdate || !nodesSorted) {
      nodeFullSort(matchingNodes, ruleRef.childSortFields);
      nodesSorted = true;
    }
    return matchingNodes;
  }

  /// Return current child groups only.
  List<GroupNode> previousChildNodes() {
    return _childGroups;
  }
}

/// The lowest level nodes that contain the [data].
///
/// They are stored separately from other tree nodes and placed dynamically.
class LeafNode implements DisplayNode {
  /// [parent] is ambiguous; not used for leaves.
  @override
  DisplayNode? parent;

  @override
  String get title => DisplayNode.modelRef.titleLine.formattedLine(this);
  @override
  final hasChildren = false;
  @override
  var isOpen = false;
  @override
  var isStale = false;
  @override
  var availableNodes = <LeafNode>[];
  @override
  late Map<String, String> data;

  /// Stores group parents for leaf instances with expanded output.
  final _expandedParents = <DisplayNode>{};

  LeafNode({required this.data});

  LeafNode.fromJson(Map<String, dynamic> jsonData) {
    data = jsonData.cast<String, String>();
  }

  @override
  List<DisplayNode> childNodes({bool forceUpdate = false}) => [];

  List<String> outputs() {
    final lines = [
      for (var line in DisplayNode.modelRef.outputLines)
        line.formattedLine(this)
    ];
    lines.removeWhere((line) => line.isEmpty);
    return lines;
  }

  bool isExpanded(DisplayNode parent) => _expandedParents.contains(parent);

  void toggleExpanded(DisplayNode parent) {
    if (!_expandedParents.remove(parent)) {
      _expandedParents.add(parent);
    }
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result;
    result = data;
    return result;
  }

  /// Return true if all of the searchTerms are found in the data output.
  bool isSearchMatch(List<String> searchTerms, Field? searchField) {
    final text = searchField == null
        ? outputs().join('\n').toLowerCase()
        : searchField.outputText(this).toLowerCase();
    for (var term in searchTerms) {
      if (!text.contains(term)) return false;
    }
    return true;
  }

  /// Return true if the regular expression is found in the data output.
  bool isRegExpMatch(RegExp exp, Field? searchField) {
    final text = searchField == null
        ? outputs().join('\n')
        : searchField.outputText(this);
    return exp.hasMatch(text);
  }

  /// Return a list of matches for the pattern found in the data output.
  List<Match> allPatternMatches(Pattern pattern, Field? searchField) {
    var text = searchField == null
        ? outputs().join('\n')
        : searchField.outputText(this);
    if (pattern is String) text = text.toLowerCase();
    return pattern.allMatches(text).toList();
  }

  /// Return the starting position of a field in the output.
  ///
  /// Return null if the field isn't in the output.
  int? fieldOuputStart(Field field) {
    int pos = 0;
    for (var line in DisplayNode.modelRef.outputLines) {
      var fieldsBlank = true;
      int linePos = 0;
      for (var segment in line.segments) {
        if (segment.field == field) return pos + linePos;
        var text = segment.output(this);
        if (text.isNotEmpty && segment.hasField) fieldsBlank = false;
        linePos += text.length;
      }
      if (!fieldsBlank || !(line.segments.any((s) => s.hasField))) {
        // Adding and extra one for the linefeed character.
        pos += linePos + 1;
      }
    }
    return null;
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

  @override
  String toString() {
    return (isAscend ? '+' : '-') + keyField.name;
  }
}

/// A stable insertion sort for nodes using multiple keys.
void nodeFullSort(List<DisplayNode> nodes, List<SortKey> keys) {
  for (var key in keys.reversed) {
    nodeSingleSort(nodes, key);
  }
}

/// A stable insertion sort for nodes using a single field key.
void nodeSingleSort(List<DisplayNode> nodes, SortKey key) {
  const start = 0;
  final end = nodes.length;
  for (var pos = start + 1; pos < end; pos++) {
    var min = start;
    var max = pos;
    var node = nodes[pos];
    while (min < max) {
      final mid = min + ((max - min) >> 1);
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
