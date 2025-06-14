// structure.dart, top level storage for the tree model.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2025, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
// foundation.dart includes [ChangeNotifier].
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:package_info_plus/package_info_plus.dart';
import 'display_node.dart';
import 'fields.dart';
import 'io_file.dart';
import 'parsed_line.dart';
import 'stored_node.dart';
import 'undos.dart';

/// Top-level storage for tree formats, nodes and undo operations.
///
/// Includes methods for all operations that modify this model.
/// [ChangeNotifier] is used to handle view state updates.
class Structure extends ChangeNotifier {
  final rootNodes = <TitleNode>[];
  final leafNodes = <LeafNode>[];

  /// The node series currently shown in the [DetailView].
  final detailViewRecords = <({DisplayNode node, GroupNode? parent})>[];

  /// Rencently deleted nodes, used by [DetailView] to label old pages.
  final obsoleteNodes = <DisplayNode>{};

  final fieldMap = <String, Field>{};
  late ParsedLine titleLine;
  final outputLines = <ParsedLine>[];
  var useMarkdownOutput = false;
  var useRelativeLinks = false;
  IOFile fileObject = IOFile.currentType('');
  var modTime = DateTime.fromMillisecondsSinceEpoch(0);
  late UndoList undoList;

  var hasWideDisplay = false;

  Structure() {
    titleLine = ParsedLine('', fieldMap);
    undoList = UndoList(this);
    StoredNode.modelRef = this;
    DisplayNode.modelRef = this;
  }

  /// Open an existng file using the JSON data in [fileObj].
  Future<void> openFile(IOFile fileObj, {doUpdate = false}) async {
    fileObject = fileObj;
    openFromData(await fileObj.readJson());
    if (doUpdate) {
      notifyListeners();
    }
  }

  /// Open an existng file using the given JSON data.
  void openFromData(Map<String, dynamic> jsonData) {
    clearModel();
    final autoChoiceFields = <AutoChoiceField>[];
    for (var fieldData in jsonData['fields'] ?? []) {
      final field = Field.fromJson(fieldData);
      fieldMap[field.name] = field;
      if (field is AutoChoiceField) autoChoiceFields.add(field);
    }
    for (var nodeData in jsonData['template'] ?? []) {
      rootNodes.add(StoredNode(nodeData) as TitleNode);
    }
    if (rootNodes.length == 1) rootNodes[0].isOpen = true;
    titleLine = ParsedLine(jsonData['titleline'] ?? '', fieldMap);
    for (var lineString in jsonData['outputlines'] ?? []) {
      outputLines.add(ParsedLine(lineString ?? '', fieldMap));
    }
    final String fileVersion = jsonData['properties']?['ttversion'] ?? '0.0.0';
    final hasOldDataFormat = compareVersions(fileVersion, '0.8.0') < 0;
    for (var leaf in jsonData['leaves'] ?? []) {
      leafNodes.add(LeafNode.fromJson(leaf, oldFormat: hasOldDataFormat));
    }
    if (fieldMap.isEmpty || rootNodes.isEmpty || outputLines.isEmpty) {
      throw const FormatException('Missing sections in file');
    }
    if (jsonData['usemarkdown'] != null) useMarkdownOutput = true;
    if (jsonData['userelativelinks'] != null) useRelativeLinks = true;
    final int? seconds = jsonData['properties']?['modtime'];
    if (seconds != null) {
      modTime = DateTime.fromMillisecondsSinceEpoch(seconds);
    }
    if (autoChoiceFields.isNotEmpty) {
      for (var leaf in leafNodes) {
        for (var field in autoChoiceFields) {
          if (leaf.data[field.name] != null) {
            field.options.addAll(leaf.data[field.name]!);
          }
        }
      }
    }
    if (!hasOldDataFormat) {
      undoList = UndoList.fromJson(jsonData['undos'] ?? [], this);
    } else {
      // Remove old undos if updating TreeTag version.
      undoList = UndoList(this);
    }
  }

  /// Start a new, skeleton file.
  ///
  /// The data and future changes will be saved to [fileObj].
  void newFile(IOFile fileObj) {
    clearModel();
    fileObject = fileObj;
    const mainFieldName = 'Name';
    fieldMap[mainFieldName] = Field.createField(name: mainFieldName);
    const categoryFieldName = 'Category';
    fieldMap[categoryFieldName] = Field.createField(name: categoryFieldName);
    final root = TitleNode(title: 'Root');
    root.isOpen = true;
    rootNodes.add(root);
    root.childRuleNode = RuleNode(
      rule: fieldMap[categoryFieldName]!.lineText(),
      storedParent: root,
    );
    leafNodes.add(
      LeafNode(
        data: {
          mainFieldName: ['Sample Node'],
          categoryFieldName: ['First Category'],
        },
      ),
    );
    titleLine = ParsedLine(fieldMap[mainFieldName]!.lineText(), fieldMap);
    outputLines.add(ParsedLine.fromSingleField(fieldMap[mainFieldName]!));
    outputLines.add(ParsedLine.fromSingleField(fieldMap[categoryFieldName]!));
    saveFile();
  }

  /// Empty the model to prepare for opening a file or starting a new file.
  void clearModel() {
    rootNodes.clear();
    leafNodes.clear();
    detailViewRecords.clear();
    obsoleteNodes.clear();
    fieldMap.clear();
    titleLine = ParsedLine('', fieldMap);
    outputLines.clear();
    useMarkdownOutput = false;
    useRelativeLinks = false;
    modTime = DateTime.fromMillisecondsSinceEpoch(0);
    undoList.clear();
  }

  void saveFile({bool doModCheck = true}) async {
    // Prior to saving, check for files that were externally modified.
    if (doModCheck) {
      try {
        final fileModTime = await fileObject.fileModTime;
        // Quickly check based on file's system modified time.
        // Uses a one minute difference to account for file system or
        // network delays during the previous save.
        if (fileModTime.difference(modTime).inSeconds >= 60) {
          // Do a slower data time check to avoid false positives due to copies
          // or other file system changes.
          final dataModTime = await fileObject.dataModTime;
          if (dataModTime.difference(modTime).inSeconds >= 60) {
            final timeStr = DateFormat(
              'MMM d, yyyy, h:mm a',
            ).format(fileModTime);
            throw ExternalModException('Modified on $timeStr');
          }
        }
      } on IOException {
        // Skip the modified check for new files or other file problems.
      }
    }
    final packageInfo = await PackageInfo.fromPlatform();
    modTime = DateTime.now();
    final jsonData = <String, dynamic>{
      'properties': {
        'ttversion': packageInfo.version,
        'modtime': modTime.millisecondsSinceEpoch,
      },
    };
    jsonData['template'] = [for (var root in rootNodes) root.toJson()];
    jsonData['fields'] = [for (var field in fieldMap.values) field.toJson()];
    jsonData['titleline'] = titleLine.getUnparsedLine();
    jsonData['outputlines'] = [
      for (var line in outputLines) line.getUnparsedLine(),
    ];
    jsonData['leaves'] = [for (var leaf in leafNodes) leaf.toJson()];
    if (useMarkdownOutput) jsonData['usemarkdown'] = true;
    if (useRelativeLinks) jsonData['userelativelinks'] = true;
    jsonData['undos'] = undoList.toJson();
    await fileObject.writeJson(jsonData);
  }

  /// Opens or closes a node based on a tap in the [TreeView].
  void toggleNodeOpen(DisplayNode node) {
    node.isOpen = !node.isOpen;
    notifyListeners();
  }

  /// Open and return the first immediate parent of a given [LeafNode].
  ///
  /// Starts from [startNode] if given, else starts from the [rootNodes].
  /// Called from [SearchView] and from the updateAllChildren member below.
  DisplayNode? openLeafParent(LeafNode targetNode, {DisplayNode? startNode}) {
    final startNodes = startNode != null ? [startNode] : rootNodes;
    final parentMatch = _parentOfMatch(startNodes, targetNode);
    var parent = parentMatch;
    while (parent != null) {
      parent.isOpen = true;
      parent = parent.parent;
    }
    return parentMatch;
  }

  // Return the first immediate parent matching the given [LeafNode].
  DisplayNode? _parentOfMatch(
    List<DisplayNode> startNodes,
    LeafNode targetNode,
  ) {
    GroupNode? previousParent;
    for (var rootNode in startNodes) {
      for (var node in allNodeGenerator(rootNode)) {
        if (node == targetNode) return previousParent;
        if (node is GroupNode) previousParent = node;
      }
    }
    return null;
  }

  /// Expands or contracts a [LeafNode] at [parentNode] instance.
  ///
  /// This either shows or hides the full output.
  void toggleNodeExpanded(LeafNode node, DisplayNode parentNode) {
    node.toggleExpanded(parentNode);
    notifyListeners();
  }

  /// Return the last node in [detailViewRecords] or null if none present.
  DisplayNode? currentDetailViewNode() {
    if (detailViewRecords.isNotEmpty) return detailViewRecords.last.node;
    return null;
  }

  /// Remove the last node in [detailViewRecords] and do an update.
  ///
  /// Return true if at least one node remains.
  bool removeDetailViewRecord() {
    if (detailViewRecords.isNotEmpty) {
      detailViewRecords.removeLast();
      notifyListeners();
    }
    return detailViewRecords.isNotEmpty;
  }

  /// Add a child to [detailViewRecords] and do an update.
  void addDetailViewRecord(
    DisplayNode node, {
    DisplayNode? parent,
    bool doClearFirst = false,
  }) {
    if (doClearFirst) detailViewRecords.clear();
    // Only stores the parent for leaves (other nodes have parent member).
    detailViewRecords.add((
      node: node,
      parent: node is LeafNode && parent is GroupNode ? parent : null,
    ));
    notifyListeners();
  }

  /// Return nodes from [availableNodes] that match the [searchTerms].
  ///
  /// All search words must match the node output text, but not consecutively.
  List<LeafNode> stringSearchResults(
    List<String> searchTerms,
    List<LeafNode> availableNodes, {
    bool doOutputSearch = true,
    Field? searchField,
  }) {
    // [searchFields] is empty for output searches, otherwise has search fields.
    var searchFields = <Field>[];
    if (!doOutputSearch) {
      if (searchField != null) {
        searchFields = [searchField];
      } else {
        searchFields = List.of(fieldMap.values);
      }
    }
    final results = <LeafNode>[];
    for (var node in availableNodes) {
      if (node.isSearchMatch(searchTerms, searchFields)) {
        results.add(node);
      }
    }
    if (results.length > 1) {
      var sortFields = [for (var field in fieldMap.values) SortKey(field)];
      nodeFullSort(results, sortFields);
    }
    return results;
  }

  /// Return nodes from [availableNodes] that match the [regExp].
  List<LeafNode> regExpSearchResults(
    RegExp exp,
    List<LeafNode> availableNodes, {
    bool doOutputSearch = true,
    Field? searchField,
  }) {
    // [searchFields] is empty for output searches, otherwise has search fields.
    var searchFields = <Field>[];
    if (!doOutputSearch) {
      if (searchField != null) {
        searchFields = [searchField];
      } else {
        searchFields = List.of(fieldMap.values);
      }
    }
    final results = <LeafNode>[];
    for (var node in availableNodes) {
      if (node.isRegExpMatch(exp, searchFields)) {
        results.add(node);
      }
    }
    if (results.length > 1) {
      final sortFields = [for (var field in fieldMap.values) SortKey(field)];
      nodeFullSort(results, sortFields);
    }
    return results;
  }

  /// Replace [pattern] with [replacement] in matches from [availableNodes].
  ///
  /// Do the replace in the [searchField] if given or in all fields.
  /// Return the count of nodes changed.
  int replaceMatches({
    required Pattern pattern,
    required String replacement,
    required List<LeafNode> availableNodes,
    Field? searchField,
  }) {
    var replaceGroupMatches = <Match>[];
    if (pattern is RegExp) {
      // Find backreferences ($1, $2, etc.) in replacement that get loaded
      // with matched groups.
      replaceGroupMatches = RegExp(
        r'(?<!\$)\$\d',
      ).allMatches(replacement).toList();
    }
    final fields = searchField != null
        ? [searchField]
        : fieldMap.values.toList();
    final undos = <Undo>[];
    for (var node in availableNodes) {
      undos.add(UndoEditLeafNode('', leafNodes.indexOf(node), node.data));
      var nodeChanged = false;
      for (var field in fields) {
        for (var i = 0; i < (node.data[field.name]?.length ?? 1); i++) {
          var fieldChanged = false;
          // Blank on null allows regexp searches to replace blank fields.
          var text = node.data[field.name]?[i] ?? '';
          final searchText = pattern is RegExp ? text : text.toLowerCase();
          // reversed to avoid mismatches due to varying replacement lengths.
          for (var match in pattern.allMatches(searchText).toList().reversed) {
            var newReplacement = replacement;
            // Add match groups to backreferences in replacement string.
            for (var replaceMatch in replaceGroupMatches.reversed) {
              var groupNum = int.tryParse(replaceMatch.group(0)![1]);
              if (groupNum != null && groupNum <= match.groupCount) {
                newReplacement = newReplacement.replaceRange(
                  replaceMatch.start,
                  replaceMatch.end,
                  match.group(groupNum)!,
                );
              }
            }
            text = text.replaceRange(match.start, match.end, newReplacement);
            nodeChanged = true;
            fieldChanged = true;
          }
          if (fieldChanged) {
            if (text.isNotEmpty) {
              if (node.data[field.name] != null) {
                node.data[field.name]![i] = text;
              } else {
                node.data[field.name] = [text];
              }
            } else if (node.data[field.name] != null) {
              if (node.data[field.name]!.length > 1) {
                node.data[field.name]!.removeAt(i);
              } else {
                node.data.remove(field.name);
              }
            }
          }
        }
      }
      if (!nodeChanged) undos.removeLast();
    }
    if (undos.isNotEmpty) {
      undoList.add(UndoBatch('Replace search matches', undos));
    }
    updateAll();
    return undos.length;
  }

  /// Creates a new node using some data copied from [copyFromNode] if given.
  ///
  /// Called from the [FrameView].
  /// Does not create undo objects or update views - that is done in
  /// [editNodeData()] after the user edits the new node.
  LeafNode newNode({DisplayNode? copyFromNode}) {
    final data = Map<String, List<String>>.of(
      copyFromNode?.data ?? <String, List<String>>{},
    );
    if (copyFromNode is GroupNode) {
      while (copyFromNode?.parent is GroupNode) {
        copyFromNode = copyFromNode?.parent;
        data.addAll(copyFromNode?.data ?? {});
      }
    }
    final newNode = LeafNode(data: data);
    for (var field in fieldMap.values) {
      if (data[field.name] == null) {
        final initValue = field.initialValue();
        if (initValue != null) newNode.data[field.name] = [initValue];
      }
    }
    leafNodes.add(newNode);
    return newNode;
  }

  /// Called from [FrameView] to create a node with common child data.
  ///
  /// Used for editing all child nodes at once.
  /// All children from the current detail view are considered.
  /// Common data is included in the node's map, including null values for
  /// mising/empty values.  The map contains a null char when values vary.
  LeafNode? commonChildDataNode() {
    final rootNode = currentDetailViewNode();
    if (rootNode == null ||
        rootNode is LeafNode ||
        rootNode.availableNodes.isEmpty ||
        obsoleteNodes.contains(rootNode)) {
      return null;
    }
    Map<String, List<String>> data = {};
    for (var field in fieldMap.values) {
      final value = _commonData(field, rootNode.availableNodes);
      if (value != null) data[field.name] = value;
    }
    return LeafNode(data: data);
  }

  // Called from above to provide common data value lists.
  // Returns an empty list if values vary, but returns null for
  // consistently missing/empty values.
  List<String>? _commonData(Field field, List<LeafNode> nodes) {
    final values = nodes[0].data[field.name];
    for (var node in nodes) {
      final nodeData = node.data[field.name];
      if (nodeData?.length != values?.length) return [];
      for (var i = 0; i < (nodeData?.length ?? 0); i++) {
        if (nodeData?[i] != values?[i]) return [];
      }
    }
    return values;
  }

  /// Called from the [EditView] to update new or edited node data.
  void editNodeData(
    LeafNode node,
    Map<String, List<String>> nodeData, {
    bool newNode = false,
  }) {
    if (newNode) {
      node.data = nodeData;
      undoList.add(
        UndoAddLeafNode(
          'New leaf node: ${node.title}',
          leafNodes.indexOf(node),
        ),
      );
    } else {
      undoList.add(
        UndoEditLeafNode(
          'Edit leaf node: ${node.title}',
          leafNodes.indexOf(node),
          node.data,
        ),
      );
      node.data = nodeData;
    }
    updateAll();
  }

  /// Called from the [EditView] to edit data in all child nodes.
  void editChildData(Map<String, List<String>> nodeData) {
    final rootNode = currentDetailViewNode();
    if (rootNode != null) {
      final undos = <Undo>[];
      for (var node in rootNode.availableNodes) {
        undos.add(UndoEditLeafNode('', leafNodes.indexOf(node), node.data));
        for (var field in fieldMap.values) {
          final newValues = nodeData[field.name];
          if (newValues != null && newValues.isNotEmpty) {
            node.data[field.name] = newValues;
          } else if (newValues == null) {
            node.data.remove(field.name);
          }
        }
      }
      undoList.add(UndoBatch('Edit child nodes of ${rootNode.title}', undos));
      updateAll();
    }
  }

  /// Called from the [DetailView] to delete a node.
  ///
  /// Can also be called from [EditView] to remove an unwanted new node.
  void deleteNode(LeafNode node, {bool withUndo = true}) {
    if (withUndo) {
      undoList.add(
        UndoDeleteLeafNode(
          'Delete leaf node: ${node.title}',
          leafNodes.indexOf(node),
          node,
        ),
      );
    }
    leafNodes.remove(node);
    updateAllChildren();
    obsoleteNodes.add(node);
    notifyListeners();
    saveFile();
  }

  /// Called from [FrameView] to delete all children of current detail view.
  void deleteChildren() {
    var rootNode = currentDetailViewNode();
    if (rootNode != null &&
        rootNode is! LeafNode &&
        rootNode.availableNodes.isNotEmpty &&
        !obsoleteNodes.contains(rootNode)) {
      final childNodes = List.of(rootNode.availableNodes);
      final undos = [
        for (var leafNode in childNodes)
          UndoDeleteLeafNode('', leafNodes.indexOf(leafNode), leafNode),
      ];
      // Sort undos to return to original sequence at undo without error.
      undos.sort((a, b) => a.nodePos.compareTo(b.nodePos));
      undoList.add(UndoBatch('Delete children of ${rootNode.title}', undos));
      leafNodes.removeWhere((node) => childNodes.contains(node));
      updateAllChildren();
      obsoleteNodes.addAll(childNodes);
      notifyListeners();
      saveFile();
    }
  }

  /// Called from [FrameView] to merge another TreeTag file with this one.
  Future<void> mergeFile(IOFile fileObj) async {
    final mergeStruct = Structure();
    await mergeStruct.openFile(fileObj);
    final undos = <Undo>[];
    for (var field in mergeStruct.fieldMap.values) {
      if (!fieldMap.containsKey(field.name)) {
        undos.add(UndoAddNewField('', field.name));
        fieldMap[field.name] = field;
      }
    }
    for (var node in mergeStruct.leafNodes) {
      undos.insert(0, UndoAddLeafNode('', leafNodes.length));
      leafNodes.add(node);
    }
    undoList.add(UndoBatch('Merge file: ${fileObj.filename}', undos));
    updateRuleChildSortFields();
    updateAll();
  }

  /// Return true if any fields allow multiple entries.
  bool get areMultiplesAllowed {
    return fieldMap.values.any((field) => field.allowMultiples);
  }

  /// Called from the [FieldEdit] view to add a new [field].
  void addNewField(Field field, {int? newPos, bool doAddOutput = false}) {
    final fieldUndo = UndoAddNewField(
      'Add new field: ${field.name}',
      field.name,
    );
    if (newPos != null) {
      final fieldList = List.of(fieldMap.values);
      fieldList.insert(newPos, field);
      fieldMap.clear();
      for (var fld in fieldList) {
        fieldMap[fld.name] = fld;
      }
    } else {
      fieldMap[field.name] = field;
    }
    if (doAddOutput) {
      final outputUndo = UndoAddOutputLine('', outputLines.length);
      final newLine = ParsedLine.empty();
      newLine.segments.add(LineSegment(field: field));
      outputLines.add(newLine);
      undoList.add(
        UndoBatch('Add new field: ${field.name}', [fieldUndo, outputUndo]),
      );
    } else {
      undoList.add(fieldUndo);
    }
    updateRuleChildSortFields();
    updateAll();
  }

  /// Called from the [FieldEdit] view to add settings from [editedField].
  ///
  /// Choices from [ChoiceField] need to be updated if [removeChoices].
  void editField(
    Field oldField,
    Field editedField, {
    bool removeChoices = false,
    bool removeMultiples = false,
  }) {
    final undos = <Undo>[];
    final pos = List.of(fieldMap.values).indexOf(oldField);
    undos.add(
      UndoEditField('Edit field: ${oldField.name}', pos, Field.copy(oldField)),
    );
    if (oldField.name != editedField.name) {
      // Field was renamed.
      final fieldList = List.of(fieldMap.values);
      fieldMap.clear();
      for (var fld in fieldList) {
        if (fld == oldField) {
          fieldMap[editedField.name] = fld;
        } else {
          fieldMap[fld.name] = fld;
        }
      }
      for (var leaf in leafNodes) {
        final data = leaf.data[oldField.name];
        if (data != null) {
          undos.add(UndoEditLeafNode('', leafNodes.indexOf(leaf), leaf.data));
          leaf.data[editedField.name] = data;
          leaf.data.remove(oldField.name);
        }
      }
    }
    oldField.updateSettings(editedField);
    if (removeChoices) {
      for (var leaf in leafNodes) {
        if (!oldField.isStoredTextValid(leaf)) {
          undos.add(UndoEditLeafNode('', leafNodes.indexOf(leaf), leaf.data));
          leaf.data.remove(editedField.name);
        }
      }
    }
    if (removeMultiples) {
      for (var leaf in leafNodes) {
        if ((leaf.data[editedField.name]?.length ?? 0) > 1) {
          undos.add(UndoEditLeafNode('', leafNodes.indexOf(leaf), leaf.data));
          leaf.data[editedField.name] = [leaf.data[editedField.name]![0]];
        }
      }
    }
    if (undos.length > 1) {
      undoList.add(UndoBatch(undos[0].title, undos));
    } else {
      undoList.add(undos[0]);
    }
    updateAll();
  }

  /// Used for field type changes.
  ///
  /// Called from the [FieldEdit] view.
  void replaceField(Field oldField, Field newField) {
    final undos = <Undo>[];
    final pos = List.of(fieldMap.values).indexOf(oldField);
    undos.add(UndoEditField('Edit field: ${oldField.name}', pos, oldField));
    if (oldField.name != newField.name) {
      for (var leaf in leafNodes) {
        final data = leaf.data[oldField.name];
        if (data != null) {
          undos.add(UndoEditLeafNode('', leafNodes.indexOf(leaf), leaf.data));
          leaf.data[newField.name] = data;
          leaf.data.remove(oldField.name);
        }
      }
    }
    // Replace the field stored in the [fieldMap].
    final fieldList = List.of(fieldMap.values);
    fieldMap.clear();
    for (var fld in fieldList) {
      if (fld == oldField) {
        fieldMap[newField.name] = newField;
      } else {
        fieldMap[fld.name] = fld;
      }
    }
    if (isFieldInTitle(oldField)) {
      undos.add(UndoEditOutputLine('', -1, titleLine.copy()));
      titleLine.replaceField(oldField, newField);
    }
    if (isFieldInOutput(oldField)) {
      for (var line in outputLines.toList()) {
        if (line.fields().contains(oldField)) {
          int linePos = outputLines.indexOf(line);
          undos.add(UndoEditOutputLine('', linePos, line.copy()));
          line.replaceField(oldField, newField);
        }
      }
    }
    // Replace field in rules.
    for (var root in rootNodes) {
      for (var item in storedNodeGenerator(root)) {
        if (item.node is RuleNode) {
          final rule = item.node as RuleNode;
          if (rule.ruleLine.fields().contains(oldField)) {
            undos.add(UndoEditRuleLine('', storedNodeId(rule), rule.ruleLine));
            rule.ruleLine.replaceField(oldField, newField);
          }
        }
      }
    }
    // Remove invalid [LeafNode] data.
    for (var leaf in leafNodes) {
      if (!newField.isStoredTextValid(leaf)) {
        undos.add(UndoEditLeafNode('', leafNodes.indexOf(leaf), leaf.data));
        leaf.data.remove(newField.name);
      }
    }
    if (undos.length > 1) {
      undoList.add(UndoBatch(undos[0].title, undos));
    } else {
      undoList.add(undos[0]);
    }
    updateAltFormatFields();
    updateAll();
  }

  /// Called from [FieldConfig] to remove a field.
  void deleteField(Field field) {
    final undos = <Undo>[];
    final pos = List.of(fieldMap.values).indexOf(field);
    undos.add(UndoDeleteField('Delete field: ${field.name}', pos, field));
    fieldMap.remove(field.name);
    for (var leaf in leafNodes) {
      if (leaf.data.containsKey(field.name)) {
        undos.add(UndoEditLeafNode('', leafNodes.indexOf(leaf), leaf.data));
        leaf.data.remove(field.name);
      }
    }
    if (isFieldInTitle(field)) {
      undos.add(UndoEditOutputLine('', -1, titleLine.copy()));
      for (var fld in field.matchingFieldDescendents(titleLine.fields())) {
        titleLine.deleteField(fld, replacement: List.of(fieldMap.values)[0]);
      }
    }
    if (isFieldInOutput(field)) {
      for (var line in outputLines.toList()) {
        final fieldMatches = field.matchingFieldDescendents(line.fields());
        if (fieldMatches.isNotEmpty) {
          int linePos = outputLines.indexOf(line);
          if (line.hasMultipleFields()) {
            undos.add(UndoEditOutputLine('', linePos, line.copy()));
            for (var fld in fieldMatches) {
              line.deleteField(fld);
            }
          } else {
            undos.add(UndoRemoveOutputLine('', linePos, line));
            outputLines.remove(line);
          }
        }
      }
      if (outputLines.isEmpty) {
        undos.add(UndoAddOutputLine('', 0));
        outputLines.add(
          ParsedLine.fromSingleField(List.of(fieldMap.values)[0]),
        );
      }
    }
    var badRules = <RuleNode>[];
    for (var root in rootNodes) {
      for (var item in storedNodeGenerator(root)) {
        if (item.node is RuleNode) {
          final rule = item.node as RuleNode;
          if (field
              .matchingFieldDescendents(rule.ruleLine.fields())
              .isNotEmpty) {
            badRules.add(rule);
          }
          if (rule.isFieldInChildSort(field)) {
            undos.add(
              UndoEditSortKeys(
                '',
                storedNodeId(rule),
                rule.childSortFields,
                isChildSort: true,
              ),
            );
            rule.removeChildSortField(field);
          }
        }
      }
    }
    for (var ruleNode in badRules) {
      undos.add(
        UndoDeleteTreeNode(
          '',
          storedNodeId(ruleNode.storedParent),
          0,
          ruleNode,
        ),
      );
      if (ruleNode.childRuleNode != null) {
        undos.add(UndoAddTreeNode('', storedNodeId(ruleNode), 0));
      }
      if (ruleNode.storedParent != null) {
        if (ruleNode.storedParent is RuleNode) {
          (ruleNode.storedParent as RuleNode).childRuleNode =
              ruleNode.childRuleNode;
        } else {
          (ruleNode.storedParent as TitleNode).replaceChildRule(
            ruleNode.childRuleNode,
          );
        }
      }
    }
    if (undos.length > 1) {
      undoList.add(UndoBatch(undos[0].title, undos));
    } else {
      undoList.add(undos[0]);
    }
    updateRuleChildSortFields();
    updateAltFormatFields();
    updateAll();
  }

  /// Called from [FieldConfig] to move a field up or down.
  void moveField(Field field, {bool up = true}) {
    final fieldList = List.of(fieldMap.values);
    var pos = fieldList.indexOf(field);
    undoList.add(UndoMoveField('Move field: ${field.name}', pos, up));
    fieldList.removeAt(pos);
    fieldList.insert(up ? --pos : ++pos, field);
    fieldMap.clear();
    for (var fld in fieldList) {
      fieldMap[fld.name] = fld;
    }
    updateRuleChildSortFields();
    notifyListeners();
    saveFile();
  }

  void updateRuleChildSortFields() {
    for (var root in rootNodes) {
      for (var item in storedNodeGenerator(root)) {
        if (item.node is RuleNode) {
          (item.node as RuleNode).setDefaultChildSortFields();
        }
      }
    }
  }

  bool isFieldInTitle(Field field) {
    return field.matchingFieldDescendents(titleLine.fields()).isNotEmpty;
  }

  bool isFieldInOutput(Field field) {
    for (var line in outputLines) {
      if (field.matchingFieldDescendents(line.fields()).isNotEmpty) return true;
    }
    return false;
  }

  bool isFieldInGroup(Field field) {
    for (var root in rootNodes) {
      for (var item in storedNodeGenerator(root)) {
        if (item.node is RuleNode) {
          var rule = item.node as RuleNode;
          if (field
              .matchingFieldDescendents(rule.ruleLine.fields())
              .isNotEmpty) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool isFieldInData(Field field) {
    for (var leaf in leafNodes) {
      if (leaf.data.containsKey(field.name)) return true;
    }
    return false;
  }

  /// Return how many leaf nodes where the field data doesn't match the format.
  int badFieldCount(Field field) {
    var count = 0;
    for (var leaf in leafNodes) {
      if (!field.isStoredTextValid(leaf)) count++;
    }
    return count;
  }

  /// Return true if any leaf nodes have multiple data entries in [field].
  bool fieldHasMultiples(Field field) {
    return leafNodes.any((leaf) => (leaf.data[field.name]?.length ?? 0) > 1);
  }

  /// Return multiple-enabled fields in the smae rule/output line as [field].
  List<Field> multipleFieldsInSameLine(Field field) {
    final result = <Field>[];
    if (fieldMap.values.every((f) => !f.allowMultiples)) {
      return result;
    }
    final allLines = <ParsedLine>[];
    for (var root in rootNodes) {
      for (var item in storedNodeGenerator(root)) {
        if (item.node is RuleNode) {
          allLines.add((item.node as RuleNode).ruleLine);
        }
      }
    }
    allLines.add(titleLine);
    allLines.addAll(outputLines);
    for (var line in allLines) {
      if (line.fields().length > 1 && line.fields().contains(field)) {
        for (var otherField in line.fields()) {
          if (otherField != field &&
              otherField.allowMultiples &&
              !result.contains(otherField)) {
            result.add(otherField);
          }
        }
      }
    }
    return result;
  }

  /// Update all alt format fields by removing unused and updating parents.
  void updateAltFormatFields() {
    final usedFields = <Field>{};
    usedFields.addAll(titleLine.fields());
    for (var line in outputLines) {
      usedFields.addAll(line.fields());
    }
    for (var root in rootNodes) {
      for (var item in storedNodeGenerator(root)) {
        if (item.node is RuleNode) {
          usedFields.addAll((item.node as RuleNode).ruleLine.fields());
        }
      }
    }
    usedFields.retainWhere((field) => field.isAltFormatField);
    for (var field in fieldMap.values) {
      field.removeUnusedAltFormatFields(usedFields);
    }
    for (var altField in usedFields) {
      altField.name = altField.altFormatParent!.name;
      altField.altFormatParent!.addAltFormatFieldIfMissing(altField);
    }
  }

  String storedNodeId(StoredNode? node) {
    if (node == null) return '';
    final posList = <int>[];
    while (node!.storedParent != null) {
      posList.insert(0, node.storedParent!.storedChildren().indexOf(node));
      assert(posList[0] != -1);
      node = node.storedParent;
    }
    posList.insert(0, rootNodes.indexOf(node as TitleNode));
    assert(posList[0] != -1);
    return posList.join('.');
  }

  StoredNode? storedNodeFromId(String id) {
    if (id.isEmpty) return null;
    final posList = [for (var i in id.split('.')) int.parse(i)];
    var node = rootNodes[posList.removeAt(0)] as StoredNode;
    while (posList.isNotEmpty) {
      node = node.storedChildren()[posList.removeAt(0)];
    }
    return node;
  }

  int storedNodePos(StoredNode node) {
    final parent = node.storedParent;
    if (parent != null) return parent.storedChildren().indexOf(node);
    return rootNodes.indexOf(node as TitleNode);
  }

  /// Called from [TreeConfig] to add a new title node as a sibling.
  void addTitleSibling(TitleNode siblingNode, String newTitle) {
    final parent = siblingNode.storedParent as TitleNode?;
    final pos = storedNodePos(siblingNode) + 1;
    undoList.add(
      UndoAddTreeNode('Add title node: $newTitle', storedNodeId(parent), pos),
    );
    final newNode = TitleNode(title: newTitle, parent: parent);
    if (parent != null) {
      parent.addChildTitleNode(newNode, pos: pos);
    } else {
      rootNodes.insert(pos, newNode);
    }
    updateAll();
  }

  /// Called from [TreeConfig] to add a new title node as a child.
  void addTitleChild(TitleNode parentNode, String newTitle) {
    undoList.add(
      UndoAddTreeNode(
        'Add title node: $newTitle',
        storedNodeId(parentNode),
        parentNode.childRuleNode == null
            ? parentNode.storedChildren().length
            : 0,
      ),
    );
    final newNode = TitleNode(title: newTitle, parent: parentNode);
    if (parentNode.childRuleNode != null) {
      newNode.replaceChildRule(parentNode.childRuleNode);
      parentNode.replaceChildRule(null);
    }
    parentNode.addChildTitleNode(newNode);
    updateAll();
  }

  /// Called from [TreeConfig] to edit an existing title node.
  void editTitle(TitleNode node, String newTitle) {
    undoList.add(
      UndoEditTitleNode(
        'Edit title node: ${node.title}',
        storedNodeId(node),
        node.title,
      ),
    );
    node.title = newTitle;
    updateAll();
  }

  /// Called from [TreeConfig] to add a new rule node as a child.
  void addRuleChild(RuleNode newNode) {
    if (newNode.storedParent == null) return;
    undoList.add(
      UndoAddTreeNode(
        'Add rule node: ${newNode.ruleLine.getUnparsedLine()}',
        storedNodeId(newNode.storedParent),
        0,
      ),
    );
    if (newNode.storedParent is TitleNode) {
      final parent = newNode.storedParent as TitleNode;
      if (parent.childRuleNode != null) {
        // Move any existing rule nodes lower in the structure.
        newNode.replaceChildRule(parent.childRuleNode);
      }
      parent.replaceChildRule(newNode);
    } else {
      final parent = newNode.storedParent as RuleNode;
      if (parent.childRuleNode != null) {
        // Move any existing rule nodes lower in the structure.
        newNode.replaceChildRule(parent.childRuleNode!);
      }
      parent.replaceChildRule(newNode);
    }
    newNode.setDefaultRuleSortFields();
    updateAltFormatFields();
    updateAll();
  }

  void editRuleLine(RuleNode node, ParsedLine newRuleLine) {
    final editUndo = UndoEditRuleLine(
      'Edit rule line: ${node.ruleLine.getUnparsedLine()}',
      storedNodeId(node),
      node.ruleLine,
    );
    node.ruleLine = newRuleLine;
    final prevSortKeys = List.of(node.sortFields);
    if (node.setDefaultRuleSortFields(checkCustom: true)) {
      // Save custom sort keys if they've changed.
      final sortUndo = UndoEditSortKeys(
        '',
        storedNodeId(node),
        prevSortKeys,
        isCustom: node.hasCustomSortFields,
      );
      undoList.add(UndoBatch(editUndo.title, [editUndo, sortUndo]));
    } else {
      undoList.add(editUndo);
    }
    updateAltFormatFields();
    updateAll();
  }

  /// Called from [TreeConfig] to delete a title or rule node.
  void deleteTreeNode(StoredNode node, {bool keepChildren = false}) {
    if (node is TitleNode) {
      undoList.add(
        UndoDeleteTreeNode(
          'Delete title node: ${node.title}',
          storedNodeId(node.storedParent),
          storedNodePos(node),
          node,
          replaceCount: keepChildren ? node.storedChildren().length : 0,
        ),
      );
      if (keepChildren && node.hasChildren && node.storedParent != null) {
        final parentTitleNode = node.storedParent as TitleNode;
        if (node.childRuleNode == null) {
          parentTitleNode.replaceChildTitleNode(
            node,
            node.storedChildren().cast<TitleNode>(),
          );
        } else {
          parentTitleNode.removeChildTitleNode(node);
          parentTitleNode.replaceChildRule(node.childRuleNode);
        }
      } else if (node.storedParent != null) {
        (node.storedParent as TitleNode).removeChildTitleNode(node);
      } else if (keepChildren && node.hasChildren) {
        final pos = rootNodes.indexOf(node);
        node.storedChildren().forEach((newNode) {
          newNode.storedParent = null;
        });
        rootNodes.replaceRange(
          pos,
          pos + 1,
          node.storedChildren().cast<TitleNode>(),
        );
      } else {
        rootNodes.remove(node);
      }
    } else {
      undoList.add(
        UndoDeleteTreeNode(
          'Delete rule node: ${(node as RuleNode).ruleLine.getUnparsedLine()}',
          storedNodeId(node.storedParent),
          storedNodePos(node),
          node,
          replaceCount: keepChildren ? 1 : 0,
        ),
      );
      if (node.storedParent is TitleNode) {
        // Deleting a RuleNode from a TitleNode.
        (node.storedParent as TitleNode).replaceChildRule(
          keepChildren ? node.childRuleNode : null,
        );
      } else {
        final parentRule = node.storedParent as RuleNode;
        if (keepChildren && node.childRuleNode != null) {
          parentRule.replaceChildRule(node.childRuleNode);
        } else {
          parentRule.childRuleNode = null;
        }
      }
      updateAltFormatFields();
    }
    updateAll();
  }

  /// Called from [TreeConfig] to move a title node up or down.
  void moveTitleNode(TitleNode node, {bool up = true}) {
    final siblings = node.storedParent != null
        ? node.storedParent!.storedChildren()
        : rootNodes;
    var pos = siblings.indexOf(node);
    undoList.add(
      UndoMoveTitleNode(
        'Move title node: ${node.title}',
        storedNodeId(node.storedParent),
        pos,
        up,
      ),
    );
    siblings.removeAt(pos);
    siblings.insert(up ? --pos : ++pos, node);
    updateAll();
  }

  bool canNodeMove(StoredNode node, {bool up = true}) {
    if (node is! TitleNode) return false;
    final siblings = node.storedParent != null
        ? node.storedParent!.storedChildren()
        : rootNodes;
    var pos = siblings.indexOf(node);
    if (up && pos > 0) return true;
    if (!up && pos < siblings.length - 1) return true;
    return false;
  }

  /// Called from [RuleEdit] to set default rule sort keys.
  void ruleSortKeysToDefault(RuleNode node) {
    undoList.add(
      UndoEditSortKeys(
        'Rule sort keys to default',
        storedNodeId(node),
        node.sortFields,
        isCustom: node.hasCustomSortFields,
      ),
    );
    node.hasCustomSortFields = false;
    node.setDefaultRuleSortFields();
    updateAll();
  }

  /// Called from [RuleEdit] to set default child sort keys.
  void childSortKeysToDefault(RuleNode node) {
    undoList.add(
      UndoEditSortKeys(
        'Child sort keys to default',
        storedNodeId(node),
        node.childSortFields,
        isCustom: node.hasCustomChildSortFields,
        isChildSort: true,
      ),
    );
    node.hasCustomChildSortFields = false;
    node.setDefaultChildSortFields();
    updateAll();
  }

  /// Called from [RuleEdit] to set custom rule sort keys.
  void updateRuleSortKeys(RuleNode node, List<SortKey> newKeys) {
    undoList.add(
      UndoEditSortKeys(
        'Edit rule sort keys',
        storedNodeId(node),
        node.sortFields,
        isCustom: node.hasCustomSortFields,
      ),
    );
    node.hasCustomSortFields = true;
    node.sortFields = newKeys;
    updateAll();
  }

  /// Called from [RuleEdit] to set custom child sort keys.
  void updateChildSortKeys(RuleNode node, List<SortKey> newKeys) {
    undoList.add(
      UndoEditSortKeys(
        'Edit child sort keys',
        storedNodeId(node),
        node.childSortFields,
        isCustom: node.hasCustomChildSortFields,
        isChildSort: true,
      ),
    );
    node.hasCustomChildSortFields = true;
    node.childSortFields = newKeys;
    updateAll();
  }

  /// Called from [OutputConfig] to add a new output line.
  void addOutputLine(int pos, ParsedLine newLine) {
    undoList.add(
      UndoAddOutputLine('Add output line: ${newLine.getUnparsedLine()}', pos),
    );
    outputLines.insert(pos, newLine);
    updateAltFormatFields();
    updateAll();
  }

  /// Called from [OutputConfig] to edit a title line or an output line.
  void editOutputLine(ParsedLine origLine, ParsedLine newLine) {
    if (origLine == titleLine) {
      undoList.add(
        UndoEditOutputLine(
          'Edit title line: ${origLine.getUnparsedLine()}',
          -1,
          origLine,
        ),
      );
      titleLine = newLine;
    } else {
      int pos = outputLines.indexOf(origLine);
      undoList.add(
        UndoEditOutputLine(
          'Edit output line: ${origLine.getUnparsedLine()}',
          pos,
          origLine,
        ),
      );
      if (pos >= 0) outputLines[pos] = newLine;
    }
    updateAltFormatFields();
    updateAll();
  }

  /// Called from [OutputConfig] to delete an output line.
  void removeOutputLine(ParsedLine origLine) {
    int pos = outputLines.indexOf(origLine);
    undoList.add(
      UndoRemoveOutputLine(
        'Remove output line: ${origLine.getUnparsedLine()}',
        pos,
        origLine,
      ),
    );
    outputLines.remove(origLine);
    updateAltFormatFields();
    updateAll();
  }

  /// Called from [OutputConfig] to move an output line up or down.
  void moveOutputLine(ParsedLine line, {bool up = true}) {
    var pos = outputLines.indexOf(line);
    undoList.add(
      UndoMoveOutputLine(
        'Move output line: ${line.getUnparsedLine()}',
        pos,
        up,
      ),
    );
    outputLines.removeAt(pos);
    outputLines.insert(up ? --pos : ++pos, line);
    updateAll();
  }

  /// Called from [OptionConfig] to change the Markdown output setting.
  void setMarkdownOutput(bool setting) {
    undoList.add(
      UndoParameters(
        'Set markdown output option',
        useMarkdownOutput,
        useRelativeLinks,
      ),
    );
    useMarkdownOutput = setting;
    updateAll();
  }

  /// Called from [OptionConfig] to change the relative link setting.
  void setUseRelativeLink(bool setting) {
    undoList.add(
      UndoParameters(
        'Set relative link option',
        useMarkdownOutput,
        useRelativeLinks,
      ),
    );
    useRelativeLinks = setting;
  }

  /// Update the views only.
  void updateViews() {
    notifyListeners();
  }

  /// Update tree children, view states and save the file.
  void updateAll() {
    updateAllChildren();
    notifyListeners();
    saveFile();
  }

  /// Update all of the tree children.
  void updateAllChildren({bool forceUpdate = true}) {
    obsoleteNodes.clear();
    var viewAncestors = <DisplayNode>{};
    // Find ancestors from detail views for update even if closed.
    for (var record in detailViewRecords) {
      var node = record.node;
      viewAncestors.add(node);
      while (node.parent != null) {
        node = node.parent!;
        viewAncestors.add(node);
      }
    }
    for (var root in rootNodes) {
      updateChildren(
        root,
        forceUpdate: forceUpdate,
        extraUpdates: viewAncestors,
      );
    }
    // Check whether the position of the current detail node has changed.
    if (detailViewRecords.isNotEmpty) {
      final record = detailViewRecords.last;
      if (record.parent != null &&
          !record.parent!.matchingNodes.contains(record.node)) {
        // The parent at the new position should be opened.
        DisplayNode ancestor = record.parent!;
        // Find the nearest [TitleNode] ancestor.
        while (ancestor.parent != null && ancestor is! TitleNode) {
          ancestor = ancestor.parent!;
        }
        openLeafParent(record.node as LeafNode, startNode: ancestor);
      }
    }
  }
}

/// Update the children of a given [node].
void updateChildren(
  DisplayNode node, {
  bool forceUpdate = true,
  Set<DisplayNode> extraUpdates = const {},
}) {
  if (node.isOpen || extraUpdates.contains(node)) {
    if (node.isStale) {
      forceUpdate = true;
      node.isStale = false;
    }
    for (var child in node.childNodes(forceUpdate: forceUpdate)) {
      updateChildren(
        child,
        forceUpdate: forceUpdate,
        extraUpdates: extraUpdates,
      );
    }
  } else if (forceUpdate && node.hasChildren) {
    node.isStale = true;
  }
}

/// Generate nodes for all of the nodes in the branch.
Iterable<DisplayNode> allNodeGenerator(
  DisplayNode node, {
  DisplayNode? parent,
  bool forceUpdate = false,
}) sync* {
  yield node;
  if (node.isStale) {
    forceUpdate = true;
    node.isStale = false;
  }
  for (var child in node.childNodes(forceUpdate: forceUpdate)) {
    yield* allNodeGenerator(child, parent: node, forceUpdate: forceUpdate);
  }
}

/// Used to store a display node with its ident level in the tree.
class LeveledNode {
  final DisplayNode node;
  final int level;

  /// [parent] stores group parents of leaf instances.
  final DisplayNode? parent;

  LeveledNode(this.node, this.level, {this.parent});
}

/// Generate [LeveledNodes] for all of the nodes in the branch.
///
/// Defaults to only including nodes with open parents.
Iterable<LeveledNode> leveledNodeGenerator(
  DisplayNode node, {
  int level = 0,
  DisplayNode? parent,
  bool openOnly = true,
  bool forceUpdate = false,
}) sync* {
  yield LeveledNode(node, level, parent: parent);
  if (node.isOpen || !openOnly) {
    if (node.isStale) {
      forceUpdate = true;
      node.isStale = false;
    }
    for (var child in node.childNodes(forceUpdate: forceUpdate)) {
      yield* leveledNodeGenerator(
        child,
        level: level + 1,
        parent: node,
        openOnly: openOnly,
        forceUpdate: forceUpdate,
      );
    }
  } else if (forceUpdate && node.hasChildren) {
    node.isStale = true;
  }
}

/// Used to store a display node with its ident level in the tree.
class LeveledStoredNode {
  final StoredNode node;
  final int level;

  LeveledStoredNode(this.node, this.level);
}

/// Generate [LeveledNodes] for all of the stored nodes.
Iterable<LeveledStoredNode> storedNodeGenerator(
  StoredNode node, {
  int level = 0,
}) sync* {
  yield LeveledStoredNode(node, level);
  for (var child in node.storedChildren()) {
    yield* storedNodeGenerator(child, level: level + 1);
  }
}

/// Compare version strings (integers separated by periods).
///
/// Return -1 if first is less, 1 if first is greater, 0 if equal.
int compareVersions(String firstStr, String secondStr) {
  final first = firstStr.split('.');
  final second = secondStr.split('.');
  while (first.length < second.length) {
    first.add('0');
  }
  while (second.length < first.length) {
    second.add('0');
  }
  for (var i = 0; i < first.length; i++) {
    final compare = (int.tryParse(first[i]) ?? 0).compareTo(
      int.tryParse(second[i]) ?? 0,
    );
    if (compare != 0) return compare;
  }
  return 0;
}

/// An exception thrown prior to saving files that were externally modified.
///
/// This is caught at the top level.
class ExternalModException extends IOException {
  final String? msg;

  ExternalModException([this.msg]);

  @override
  String toString() => msg ?? 'ExternalModException';
}
