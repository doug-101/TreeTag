// frame_view.dart, the main view's frame and controls.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert' show json;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:split_view/split_view.dart';
import 'common_dialogs.dart' as commonDialogs;
import 'detail_view.dart';
import 'edit_view.dart';
import 'help_view.dart';
import 'search_view.dart';
import 'setting_edit.dart';
import 'tree_view.dart';
import 'undo_view.dart';
import '../model/nodes.dart';
import '../model/structure.dart';
import '../model/treeline_export.dart';

const emptyViewName = '[No Current Nodes]';
const emptyTitleName = '[Empty Title]';

enum MenuItems { editChildren, deleteChildren }

/// A Scafold and Appbar for the main tree and detail views.
///
/// It includes the drawer and icon controls, and splits the tree and detail
/// views when on a wide screen.
class FrameView extends StatelessWidget {
  final String fileRootName;

  FrameView({Key? key, required this.fileRootName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<Structure>(
      builder: (context, model, child) {
        model.hasWideDisplay = MediaQuery.of(context).size.width > 600;
        var detailRootNode = model.currentDetailViewNode();
        var detailViewTitle = detailRootNode != null
            ? (detailRootNode.title.isNotEmpty
                ? detailRootNode.title
                : emptyTitleName)
            : emptyViewName;
        var isDetailLeafNode = detailRootNode is LeafNode &&
            !model.obsoleteNodes.contains(detailRootNode);
        var hasDetailViewOnly = !model.hasWideDisplay && detailRootNode != null;
        // Size placeholder for hidden icons, includes 8/side padding.
        var iconSize = (IconTheme.of(context).size ?? 24.0) + 16.0;
        return Scaffold(
          drawer: hasDetailViewOnly
              ? null
              : Drawer(
                  child: ListView(
                    children: <Widget>[
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: Text(
                          'TreeTag',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 36,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.construction),
                        title: const Text('Edit Configuration'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/configView');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.undo),
                        title: const Text('View Undo Steps'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/undoView');
                        },
                      ),
                      Divider(),
                      ListTile(
                        leading: const Icon(Icons.change_circle_outlined),
                        title: const Text('Export to TreeLine'),
                        onTap: () async {
                          Navigator.pop(context);
                          var exportData = TreeLineExport(model).jsonData();
                          var fileObj = File(
                              '${p.withoutExtension(model.fileObject.path)}'
                              '.trln');
                          if (fileObj.existsSync()) {
                            var ans = await commonDialogs.okCancelDialog(
                              context: context,
                              title: 'Confirm Overwrite',
                              label: 'File ${p.basename(fileObj.path)} already '
                                  'exists.\n\nOverwrite it?',
                            );
                            if (ans == null || !ans) return;
                          }
                          await fileObj.writeAsString(json.encode(exportData));
                          await commonDialogs.okDialog(
                            context: context,
                            title: 'Export',
                            label:
                                'File ${p.basename(fileObj.path)} was written.',
                          );
                        },
                      ),
                      Divider(),
                      ListTile(
                        leading: const Icon(Icons.close),
                        title: const Text('Close File'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                      ),
                      Divider(),
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text('Settings'),
                        onTap: () async {
                          Navigator.pop(context);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SettingEdit(),
                            ),
                          );
                        },
                      ),
                      Divider(),
                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: const Text('Help View'),
                        onTap: () async {
                          Navigator.pop(context);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HelpView(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About TreeTag'),
                        onTap: () {
                          Navigator.pop(context);
                          commonDialogs.aboutDialog(context: context);
                        },
                      ),
                    ],
                  ),
                ),
          appBar: AppBar(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                // Flexible widgets are required to prevent overflow.
                if (model.hasWideDisplay || !hasDetailViewOnly)
                  Flexible(
                    child: Text('TreeTag - $fileRootName'),
                  ),
                if (model.hasWideDisplay || hasDetailViewOnly)
                  Flexible(
                    child: Text(detailViewTitle),
                  ),
              ],
            ),
            // A true setting adds a drawer button, false avoids adding an
            // automatic back close button.
            automaticallyImplyLeading: !hasDetailViewOnly,
            leading: hasDetailViewOnly
                ? BackButton(
                    onPressed: () {
                      model.removeDetailViewNode();
                    },
                  )
                : null,
            actions: <Widget>[
              if (model.hasWideDisplay && model.detailViewNodes.length > 1)
                BackButton(
                  onPressed: () {
                    model.removeDetailViewNode();
                  },
                ),
              // Reserve space for hidden icons on wide display.
              if (model.hasWideDisplay && !isDetailLeafNode)
                SizedBox(
                  width: iconSize * (model.detailViewNodes.length > 1 ? 1 : 2),
                  height: 1.0,
                ),
              if (!isDetailLeafNode)
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SearchView(parentNode: detailRootNode),
                      ),
                    );
                  },
                ),
              if (isDetailLeafNode)
                IconButton(
                  icon: const Icon(Icons.delete),
                  // Delete the shown [LeafNode].
                  onPressed: () {
                    model.deleteNode(detailRootNode as LeafNode);
                  },
                ),
              if (isDetailLeafNode)
                IconButton(
                  icon: const Icon(Icons.edit),
                  // Edit the shown [LeafNode].
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditView(node: detailRootNode as LeafNode),
                      ),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                // Create a new node using data copied from the shown nodes.
                onPressed: () {
                  var newNode = model.newNode(copyFromNode: detailRootNode);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EditView(node: newNode, editMode: EditMode.newNode),
                    ),
                  );
                },
              ),
              if (!isDetailLeafNode &&
                  (hasDetailViewOnly ||
                      (model.hasWideDisplay && detailRootNode != null)))
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (result) async {
                    switch (result) {
                      case MenuItems.editChildren:
                        var commonNode = model.commonChildDataNode();
                        if (commonNode != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditView(
                                node: commonNode,
                                editMode: EditMode.nodeChildren,
                              ),
                            ),
                          );
                        }
                        break;
                      case MenuItems.deleteChildren:
                        if (detailRootNode is TitleNode) {
                          var ans = await commonDialogs.okCancelDialog(
                            context: context,
                            title: 'Confirm Delete',
                            label: 'Deleting from a title node deletes all '
                                'leaf nodes.\n\nContinue?',
                          );
                          if (ans == null || !ans) break;
                        }
                        model.deleteChildren();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Text('Edit All Children'),
                      value: MenuItems.editChildren,
                    ),
                    PopupMenuItem(
                      child: Text('Delete All Children'),
                      value: MenuItems.deleteChildren,
                    ),
                  ],
                ),
              // Reserve space for hidden menu icon if not present.
              if (isDetailLeafNode ||
                  (!hasDetailViewOnly &&
                      (!model.hasWideDisplay || detailRootNode == null)))
                SizedBox(
                  width: iconSize,
                  height: 1.0,
                ),
            ],
          ),
          body: model.hasWideDisplay
              ? SplitView(
                  viewMode: SplitViewMode.Horizontal,
                  children: <Widget>[
                    TreeView(fileRootName: fileRootName),
                    DetailView(),
                  ],
                )
              : hasDetailViewOnly
                  ? DetailView()
                  : TreeView(fileRootName: fileRootName),
        );
      },
    );
  }
}
