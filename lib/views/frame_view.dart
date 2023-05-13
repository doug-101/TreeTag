// frame_view.dart, the main view's frame and controls.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:convert' show json;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_selectionarea/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:split_view/split_view.dart';
import 'common_dialogs.dart' as commonDialogs;
import 'detail_view.dart';
import 'edit_view.dart';
import 'file_control.dart' show fileExtension;
import 'help_view.dart';
import 'search_view.dart';
import 'setting_edit.dart';
import 'tree_view.dart';
import 'undo_view.dart';
import '../main.dart' show prefs;
import '../model/csv_export.dart';
import '../model/io_file.dart';
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
                        leading: const Icon(Icons.merge),
                        title: const Text('Merge Files'),
                        onTap: () async {
                          Navigator.pop(context);
                          var fileList = <IOFile>[];
                          try {
                            var usingLocalFiles =
                                prefs.getBool('uselocalfiles') ?? true;
                            fileList = usingLocalFiles
                                ? await LocalFile.fileList()
                                : await NetworkFile.fileList();
                          } on IOException catch (e) {
                            await commonDialogs.okDialog(
                              context: context,
                              title: 'Error',
                              label: 'Could not read from directory: \n$e',
                              isDissmissable: false,
                            );
                            return;
                          }
                          var filenames = [
                            for (var f in fileList)
                              if (f.nameNoExtension != fileRootName &&
                                  f.extension == fileExtension)
                                f.filename
                          ];
                          filenames.sort();
                          var fileName = await commonDialogs.choiceDialog(
                            context: context,
                            choices: filenames,
                            title: 'Choose File to Merge',
                          );
                          if (fileName != null) {
                            var fileObj = IOFile.currentType(fileName);
                            try {
                              await model.mergeFile(fileObj);
                            } on FormatException {
                              await commonDialogs.okDialog(
                                context: context,
                                title: 'Error',
                                label: 'Could not interpret file: '
                                    '${fileObj.nameNoExtension}',
                                isDissmissable: false,
                              );
                            } on IOException catch (e) {
                              await commonDialogs.okDialog(
                                context: context,
                                title: 'Error',
                                label: 'Could not read file: '
                                    '${fileObj.nameNoExtension}\n$e',
                                isDissmissable: false,
                              );
                            }
                          }
                        },
                      ),
                      Divider(),
                      ListTile(
                        leading: const Icon(Icons.change_circle_outlined),
                        title: const Text('Export to TreeLine'),
                        onTap: () async {
                          Navigator.pop(context);
                          var exportData = TreeLineExport(model).jsonData();
                          var fileObj = IOFile.currentType(
                              model.fileObject.nameNoExtension + '.trln');
                          if (await fileObj.exists) {
                            var ans = await commonDialogs.okCancelDialog(
                              context: context,
                              title: 'Confirm Overwrite',
                              label: 'File ${fileObj.filename} already '
                                  'exists.\n\nOverwrite it?',
                            );
                            if (ans == null || !ans) return;
                          }
                          await fileObj.writeJson(exportData);
                          await commonDialogs.okDialog(
                            context: context,
                            title: 'Export',
                            label: 'File ${fileObj.filename} was written.',
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.table_chart_outlined),
                        title: const Text('Export to CSV'),
                        onTap: () async {
                          Navigator.pop(context);
                          var converter = CsvExport(model);
                          // Ask for raw vs. output string option.
                          const options = [
                            'Field text as output',
                            'Field text as stored',
                          ];
                          var ans = await commonDialogs.choiceDialog(
                            context: context,
                            title: 'CSV Export Options',
                            choices: options,
                          );
                          if (ans == null) return;
                          var useOutput = ans == options[0];
                          var exportData =
                              converter.csvString(useOutput: useOutput);
                          var fileObj = LocalFile(
                              model.fileObject.nameNoExtension + '.csv');
                          if (await fileObj.exists) {
                            var ans = await commonDialogs.okCancelDialog(
                              context: context,
                              title: 'Confirm Overwrite',
                              label: 'File ${fileObj.filename} already '
                                  'exists.\n\nOverwrite it?',
                            );
                            if (ans == null || !ans) return;
                          }
                          await fileObj.writeString(exportData);
                          await commonDialogs.okDialog(
                            context: context,
                            title: 'Export',
                            label:
                                'Local file ${fileObj.filename} was written.',
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
                      if (Platform.isLinux || Platform.isMacOS) Divider(),
                      if (Platform.isLinux || Platform.isMacOS)
                        ListTile(
                          leading: const Icon(Icons.highlight_off_outlined),
                          title: const Text('Quit'),
                          onTap: () {
                            SystemNavigator.pop();
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
                    child: Text('$fileRootName - TreeTag'),
                  ),
                if (model.hasWideDisplay || hasDetailViewOnly)
                  Flexible(
                    child: model.useMarkdownOutput
                        ? MarkdownBody(
                            data: detailViewTitle,
                            styleSheet: MarkdownStyleSheet.fromTheme(
                              ThemeData(
                                textTheme: TextTheme(
                                  bodyText2: TextStyle(
                                    fontSize: 20.0,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Text(detailViewTitle),
                  ),
              ],
            ),
            // A true setting adds a drawer button, false avoids adding an
            // automatic back close button.
            automaticallyImplyLeading: !hasDetailViewOnly,
            leading: hasDetailViewOnly
                ? BackButton(
                    onPressed: () {
                      model.removeDetailViewRecord();
                    },
                  )
                : null,
            actions: <Widget>[
              if (model.hasWideDisplay && model.detailViewRecords.length > 1)
                BackButton(
                  onPressed: () {
                    model.removeDetailViewRecord();
                  },
                ),
              // Reserve space for hidden icons on wide display.
              if (model.hasWideDisplay && !isDetailLeafNode)
                SizedBox(
                  width:
                      iconSize * (model.detailViewRecords.length > 1 ? 1 : 2),
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
