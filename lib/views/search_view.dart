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
}

enum SearchType { phrase, keyword, regExp }

/// A view to search for leaf nodes and show results.
///
/// Called from the [FrameView].
class SearchView extends StatefulWidget {
  final Node? parentNode;

  SearchView({Key? key, required this.parentNode}) : super(key: key);

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _controller = TextEditingController();
  late final List<LeafNode> availableNodes;
  var resultNodes = <LeafNode>[];
  var selectedNodes = <LeafNode>[];
  var searchType = SearchType.phrase;
  Field? searchField;

  void initState() {
    super.initState();
    var parent = widget.parentNode;
    if (parent != null && parent is GroupNode) {
      availableNodes = parent.availableNodes;
    } else {
      var model = Provider.of<Structure>(context, listen: false);
      availableNodes = model.leafNodes;
    }
    var lastTypeIndex = prefs.getInt('searchtype');
    if (lastTypeIndex != null) {
      searchType = SearchType.values[lastTypeIndex];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void doSearch(String searchString) {
    setState(() {
      var model = Provider.of<Structure>(context, listen: false);
      if (searchString.trim().isNotEmpty) {
        if (searchType == SearchType.regExp) {
          try {
            var exp = RegExp(searchString);
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

  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    var fieldTitle =
        searchField != null ? '${searchField!.name} field' : 'all fields';
    return WillPopScope(
      onWillPop: () async {
        if (selectedNodes.isNotEmpty) {
          model.openLeafParent(selectedNodes.last);
          model.addDetailViewNode(selectedNodes.last, doClearFirst: true);
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
                  color: Colors.white,
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
                    break;
                  case MenuItems.keywordSearch:
                    searchType = SearchType.keyword;
                    prefs.setInt('searchtype', searchType.index);
                    doSearch(_controller.text);
                    break;
                  case MenuItems.regExpSearch:
                    searchType = SearchType.regExp;
                    prefs.setInt('searchtype', searchType.index);
                    doSearch(_controller.text);
                    break;
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
                    break;
                  case MenuItems.allFields:
                    searchField = null;
                    doSearch(_controller.text);
                    break;
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
                      ? Theme.of(context).highlightColor
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
                      child: Text(
                        selectedNodes.contains(node)
                            ? node.outputs().join('\n')
                            : node.title,
                      ),
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
