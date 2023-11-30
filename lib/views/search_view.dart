// search_view.dart, a viww to do node searches and show results.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_dialogs.dart';
import '../main.dart' show prefs;
import '../model/fields.dart';
import '../model/nodes.dart';
import '../model/structure.dart';

enum MenuItems {
  phraseSearch,
  keywordSearch,
  regExpSearch,
  fieldChange,
  allFields,
  replace,
}

enum SearchType { phrase, keyword, regExp }

/// A view to search for leaf nodes and show results.
///
/// Called from the [FrameView].
class SearchView extends StatefulWidget {
  final Node? parentNode;

  SearchView({super.key, required this.parentNode});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _controller = TextEditingController();
  late final List<LeafNode> availableNodes;
  var resultNodes = <LeafNode>[];
  final selectedNodes = <LeafNode>[];
  var searchType = SearchType.phrase;
  Field? searchField;

  void initState() {
    super.initState();
    final parent = widget.parentNode;
    if (parent != null && parent is GroupNode) {
      availableNodes = parent.availableNodes;
    } else {
      final model = Provider.of<Structure>(context, listen: false);
      availableNodes = model.leafNodes;
    }
    final lastTypeIndex = prefs.getInt('searchtype');
    if (lastTypeIndex != null) {
      searchType = SearchType.values[lastTypeIndex];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Perform the search, updating [resultNodes].
  void doSearch(String searchString) {
    setState(() {
      final model = Provider.of<Structure>(context, listen: false);
      if (searchString.trim().isNotEmpty) {
        if (searchType == SearchType.regExp) {
          try {
            final exp = RegExp(searchString);
            resultNodes = model.regExpSearchResults(exp, availableNodes,
                searchField: searchField);
          } on FormatException {
            resultNodes.clear();
          }
        } else {
          var searchTerms = <String>[];
          searchString = searchString.toLowerCase();
          if (searchType == SearchType.phrase) {
            searchTerms.add(searchString);
          } else {
            // Keyword search.
            searchTerms = searchString.split(' ');
            searchTerms.removeWhere((s) => s.isEmpty);
          }
          resultNodes = model.stringSearchResults(searchTerms, availableNodes,
              searchField: searchField);
        }
      } else {
        resultNodes.clear();
      }
      selectedNodes.clear();
    });
  }

  /// Return a widget with the long node output with matches highlighted.
  Widget longOutput(LeafNode node) {
    final text = node.outputs().join('\n');
    var matches = <Match>[];
    if (searchType == SearchType.phrase) {
      matches =
          node.allPatternMatches(_controller.text.toLowerCase(), searchField);
    } else if (searchType == SearchType.keyword) {
      for (var searchTerm in _controller.text.toLowerCase().split(' ')) {
        if (searchTerm.isNotEmpty) {
          matches.addAll(node.allPatternMatches(searchTerm, searchField));
        }
      }
      matches.sort((a, b) => a.start.compareTo(b.start));
    } else {
      // regExp search.Reg
      matches = node.allPatternMatches(RegExp(_controller.text), searchField);
    }
    if (matches.isEmpty) return Text(text);
    var delta = 0;
    if (searchField != null) {
      final nullableDelta = node.fieldOuputStart(searchField!);
      if (nullableDelta != null) {
        delta = nullableDelta;
      } else {
        return Text(text);
      }
    }
    final spans = <TextSpan>[];
    var nextStart = 0;
    try {
      for (var match in matches) {
        if (match.start + delta != nextStart) {
          spans.add(
              TextSpan(text: text.substring(nextStart, match.start + delta)));
        }
        spans.add(TextSpan(
          text: text.substring(match.start + delta, match.end + delta),
          style: const TextStyle(color: Colors.red),
        ));
        nextStart = match.end + delta;
      }
      if (text.length > matches.last.end + delta) {
        spans.add(TextSpan(text: text.substring(matches.last.end + delta)));
      }
    } on RangeError {
      // Handle an error due to overlapping search results.
      return Text(text);
    }
    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<Structure>(context, listen: false);
    final fieldTitle =
        searchField != null ? '${searchField!.name} field' : 'all fields';
    return WillPopScope(
      onWillPop: () async {
        if (selectedNodes.isNotEmpty) {
          final parent = model.openLeafParent(
            selectedNodes.last,
            startNode: model.currentDetailViewNode(),
          );
          model.addDetailViewRecord(
            selectedNodes.last,
            parent: parent,
            doClearFirst: true,
          );
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Search (${searchType.name}, $fieldTitle)'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50.0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 10.0),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    // Change onChanged to onSubmitted for non-incr. search.
                    onChanged: (String value) {
                      doSearch(value);
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear the search field',
                        onPressed: () {
                          // Clear the search field.
                          _controller.clear();
                          setState(() {
                            resultNodes = [];
                            selectedNodes.clear();
                          });
                        },
                      ),
                      hintText: 'Search...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: <Widget>[
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              onSelected: (result) async {
                switch (result) {
                  case MenuItems.phraseSearch:
                    searchType = SearchType.phrase;
                    prefs.setInt('searchtype', searchType.index);
                    doSearch(_controller.text);
                  case MenuItems.keywordSearch:
                    searchType = SearchType.keyword;
                    prefs.setInt('searchtype', searchType.index);
                    doSearch(_controller.text);
                  case MenuItems.regExpSearch:
                    searchType = SearchType.regExp;
                    prefs.setInt('searchtype', searchType.index);
                    doSearch(_controller.text);
                  case MenuItems.fieldChange:
                    var fieldName = await choiceDialog(
                      context: context,
                      choices: model.fieldMap.keys.toList(),
                      title: 'Choose Field to Search',
                    );
                    if (fieldName != null) {
                      searchField = model.fieldMap[fieldName];
                      doSearch(_controller.text);
                    }
                  case MenuItems.allFields:
                    searchField = null;
                    doSearch(_controller.text);
                  case MenuItems.replace:
                    var result = await _replaceDialog(
                      context: context,
                      hasSelection: selectedNodes.isNotEmpty,
                    );
                    if (result != null) {
                      var changeCount = model.replaceMatches(
                        pattern: searchType == SearchType.phrase
                            ? _controller.text.toLowerCase()
                            : RegExp(_controller.text),
                        replacement: result.replacementString,
                        availableNodes:
                            result.isSelectedOnly ? selectedNodes : resultNodes,
                        searchField: searchField,
                      );
                      await okDialog(
                        context: context,
                        title: 'Nodes Replaced',
                        label: '$changeCount nodes were changed',
                      );
                    }
                }
                setState(() {});
              },
              itemBuilder: (context) => <PopupMenuEntry>[
                if (searchType != SearchType.phrase)
                  PopupMenuItem(
                    child: Text('Phrase Search'),
                    value: MenuItems.phraseSearch,
                  ),
                if (searchType != SearchType.keyword)
                  PopupMenuItem(
                    child: Text('Keyword Search'),
                    value: MenuItems.keywordSearch,
                  ),
                if (searchType != SearchType.regExp)
                  PopupMenuItem(
                    child: Text('Regular Expression Search'),
                    value: MenuItems.regExpSearch,
                  ),
                PopupMenuDivider(),
                PopupMenuItem(
                  child: Text('Change Searched Field'),
                  value: MenuItems.fieldChange,
                ),
                PopupMenuItem(
                  child: Text('Search All Fields'),
                  value: MenuItems.allFields,
                ),
                if (searchType != SearchType.keyword &&
                    resultNodes.isNotEmpty) ...[
                  PopupMenuDivider(),
                  PopupMenuItem(
                    child: Text('Replace Matches'),
                    value: MenuItems.replace,
                  ),
                ],
              ],
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: ListView(
            children: <Widget>[
              for (var node in resultNodes)
                Card(
                  color: selectedNodes.contains(node)
                      ? Theme.of(context).listTileTheme.selectedTileColor
                      : null,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selectedNodes.contains(node)) {
                          selectedNodes.remove(node);
                        } else {
                          selectedNodes.add(node);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: selectedNodes.contains(node)
                          ? longOutput(node)
                          : Text(node.title),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Class to return values from the [_replaceDialog].
class _ReplaceResult {
  final String replacementString;
  final bool isSelectedOnly;

  _ReplaceResult(this.replacementString, this.isSelectedOnly);
}

/// Prompt for a replacement string, with a switch for selected-only.
Future<_ReplaceResult?> _replaceDialog({
  required BuildContext context,
  hasSelection = true,
}) async {
  var replacementString = '';
  var isSelectedOnly = hasSelection;
  return showDialog<_ReplaceResult>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Replace Search Results'),
        // Use [StatefulBuilder] to provide a state.
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  decoration: InputDecoration(labelText: 'Replacement String'),
                  autofocus: true,
                  onChanged: (value) {
                    replacementString = value;
                  },
                  onSubmitted: (value) {
                    // Complete the dialog when the user presses enter.
                    replacementString = value;
                    Navigator.pop(context,
                        _ReplaceResult(replacementString, isSelectedOnly));
                  },
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: InkWell(
                    onTap: () {
                      setState(() => isSelectedOnly = !isSelectedOnly);
                    },
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text('Selected Nodes Only'),
                        ),
                        Switch(
                          value: isSelectedOnly,
                          onChanged: (bool value) {
                            setState(() => isSelectedOnly = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(
                  context, _ReplaceResult(replacementString, isSelectedOnly));
            },
          ),
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      );
    },
  );
}
