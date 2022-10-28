// search_view.dart, a viww to do node searches and show results.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/nodes.dart';
import '../model/structure.dart';

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
  LeafNode? selectedNode;

  void initState() {
    super.initState();
    var parent = widget.parentNode;
    if (parent != null && parent is GroupNode) {
      availableNodes = parent.availableNodes;
    } else {
      var model = Provider.of<Structure>(context, listen: false);
      availableNodes = model.leafNodes;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    return WillPopScope(
      onWillPop: () async {
        if (selectedNode != null) {
          model.openLeafParent(selectedNode!);
          model.addDetailViewNode(selectedNode!, doClearFirst: true);
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: TextField(
                controller: _controller,
                autofocus: true,
                // Change onChanged to onSubmitted for non-incremental search.
                onChanged: (String value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      resultNodes = model.searchResults(value, availableNodes);
                      selectedNode = null;
                    });
                  } else {
                    setState(() {
                      resultNodes.clear();
                      selectedNode = null;
                    });
                  }
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
                        selectedNode = null;
                      });
                    },
                  ),
                  hintText: 'Search...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          actions: <Widget>[],
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: ListView(
            children: <Widget>[
              for (var node in resultNodes)
                Card(
                  color: node == selectedNode
                      ? Theme.of(context).highlightColor
                      : null,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (node != selectedNode) {
                          selectedNode = node;
                        } else {
                          selectedNode = null;
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                        node != selectedNode
                            ? node.title
                            : node.outputs().join('\n'),
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
