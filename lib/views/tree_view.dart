// tree_view.dart, the main view showing indented tree data.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/nodes.dart';
import '../model/structure.dart';
import '../views/detail_view.dart';
import '../views/undo_view.dart';

enum MenuItems { editConfig, undoView, about, close }
const emptyName = '[Empty Title]';
const _closedIcon = Icon(Icons.arrow_right, size: 24.0);
const _openIcon = Icon(Icons.arrow_drop_down, size: 24.0);
const _leafIcon = Icon(Icons.circle, size: 8.0);

/// The main indented tree view.
///
/// A tap opens or closes tree items.
/// A long press opens a [DetailView] for an item and/or its children.
/// Menu items open config views, undo views and do file operations.
class TreeView extends StatelessWidget {
  late final String headerName;

  TreeView({Key? key, required String fileRootName}) : super(key: key) {
    headerName = 'TreeTag - $fileRootName';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(headerName),
        actions: <Widget>[
          PopupMenuButton<MenuItems>(
            icon: const Icon(Icons.more_vert),
            onSelected: (MenuItems result) {
              switch (result) {
                case MenuItems.editConfig:
                  Navigator.pushNamed(context, '/configView');
                  break;
                case MenuItems.undoView:
                  Navigator.pushNamed(context, '/undoView');
                  break;
                case MenuItems.about:
                  showAboutDialog(
                    context: context,
                    applicationName: 'TreeTag',
                    applicationVersion: 'Version $treeTagVersion',
                    applicationLegalese: '©2022 by Douglas W. Bell',
                    applicationIcon:
                        Image.asset('assets/images/tree_icon_48.png'),
                  );
                  break;
                case MenuItems.close:
                  Navigator.pop(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<MenuItems>(
                child: Text('Edit Configuration'),
                value: MenuItems.editConfig,
              ),
              PopupMenuItem<MenuItems>(
                child: Text('View Undo Steps'),
                value: MenuItems.undoView,
              ),
              PopupMenuDivider(),
              PopupMenuItem<MenuItems>(
                child: Text('About TreeTag'),
                value: MenuItems.about,
              ),
              PopupMenuDivider(),
              PopupMenuItem<MenuItems>(
                child: Text('Close File'),
                value: MenuItems.close,
              ),
            ],
          ),
        ],
      ),
      body: Consumer<Structure>(
        builder: (context, model, child) {
          return ListView(
            children: _itemRows(model, context),
          );
        },
      ),
    );
  }

  /// The widgets for each node in the tree.
  List<Widget> _itemRows(Structure model, BuildContext context) {
    final items = <Widget>[];
    for (var root in model.rootNodes) {
      for (var leveledNode in nodeGenerator(root)) {
        items.add(_row(leveledNode, context));
      }
    }
    return items;
  }

  /// A single widget for a tree node.
  Widget _row(LeveledNode leveledNode, BuildContext context) {
    final node = leveledNode.node;
    return Container(
      padding:
          EdgeInsets.fromLTRB(25.0 * leveledNode.level + 4.0, 8.0, 4.0, 8.0),
      child: GestureDetector(
        onTap: () {
          if (node.hasChildren) {
            node.modelRef.toggleNodeOpen(node);
          }
        },
        onLongPress: () {
          Navigator.pushNamed(context, '/detailView', arguments: node);
        },
        child: Row(
          children: <Widget>[
            node.hasChildren
                ? Container(
                    child: node.isOpen ? _openIcon : _closedIcon,
                  )
                : Container(
                    child: _leafIcon,
                    padding: EdgeInsets.only(left: 8.0, right: 8.0),
                  ),
            Expanded(
                child: Text(node.title.isNotEmpty ? node.title : emptyName,
                    softWrap: true)),
          ],
        ),
      ),
    );
  }
}
