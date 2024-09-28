// frame_view.dart, the main view's frame and controls.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:split_view/split_view.dart';
import 'common_dialogs.dart' as common_dialogs;
import 'common_widgets.dart';
import 'detail_view.dart';
import 'edit_view.dart';
import 'file_control.dart' show fileExtension;
import 'help_view.dart';
import 'search_view.dart';
import 'setting_edit.dart';
import 'tree_view.dart';
import '../main.dart' show prefs;
import '../model/csv_export.dart';
import '../model/display_node.dart';
import '../model/io_file.dart';
import '../model/stored_node.dart';
import '../model/structure.dart';
import '../model/text_export.dart';
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

  const FrameView({super.key, required this.fileRootName});

  @override
  Widget build(BuildContext context) {
    return Consumer<Structure>(
      builder: (context, model, child) {
        model.hasWideDisplay = MediaQuery.of(context).size.width > 600;
        final detailRootNode = model.currentDetailViewNode();
        final detailViewTitle = detailRootNode != null
            ? (detailRootNode.title.isNotEmpty
                ? detailRootNode.title
                : emptyTitleName)
            : emptyViewName;
        final isDetailLeafNode = detailRootNode is LeafNode &&
            !model.obsoleteNodes.contains(detailRootNode);
        final hasDetailViewOnly =
            !model.hasWideDisplay && detailRootNode != null;
        // Size placeholder for hidden icons, includes 8/side padding.
        final iconSize = (IconTheme.of(context).size ?? 24.0) + 16.0;
        return Scaffold(
          drawer: hasDetailViewOnly
              ? null
              : Drawer(
                  child: ListView(
                    children: <Widget>[
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        child: Text(
                          'TreeTag',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onTertiary,
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
                      const Divider(),
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
                            if (!context.mounted) return;
                            await common_dialogs.okDialog(
                              context: context,
                              title: 'Error',
                              label: 'Could not read from directory: \n$e',
                              isDissmissable: false,
                            );
                            return;
                          }
                          final filenames = [
                            for (var f in fileList)
                              if (f.nameNoExtension != fileRootName &&
                                  f.extension == fileExtension)
                                f.filename
                          ];
                          filenames.sort();
                          if (!context.mounted) return;
                          final fileName = await common_dialogs.choiceDialog(
                            context: context,
                            choices: filenames,
                            title: 'Choose File to Merge',
                          );
                          if (fileName != null) {
                            final fileObj = IOFile.currentType(fileName);
                            try {
                              await model.mergeFile(fileObj);
                            } on FormatException {
                              if (!context.mounted) return;
                              await common_dialogs.okDialog(
                                context: context,
                                title: 'Error',
                                label: 'Could not interpret file: '
                                    '${fileObj.nameNoExtension}',
                                isDissmissable: false,
                              );
                            } on IOException catch (e) {
                              if (!context.mounted) return;
                              await common_dialogs.okDialog(
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
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.change_circle_outlined),
                        title: const Text('Export to TreeLine'),
                        onTap: () async {
                          Navigator.pop(context);
                          final exportData = TreeLineExport(model).jsonData();
                          final fileObj = IOFile.currentType(
                              '${model.fileObject.nameNoExtension}.trln');
                          if (await fileObj.exists) {
                            if (!context.mounted) return;
                            var ans = await common_dialogs.okCancelDialog(
                              context: context,
                              title: 'Confirm Overwrite',
                              label: 'File ${fileObj.filename} already '
                                  'exists.\n\nOverwrite it?',
                            );
                            if (ans == null || !ans) return;
                          }
                          await fileObj.writeJson(exportData);
                          if (!context.mounted) return;
                          await common_dialogs.okDialog(
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
                          final converter = CsvExport(model);
                          // Ask for raw vs. output string option.
                          const options = [
                            'Field text as output',
                            'Field text as stored',
                          ];
                          final ans = await common_dialogs.choiceDialog(
                            context: context,
                            title: 'CSV Export Options',
                            choices: options,
                          );
                          if (ans == null) return;
                          final useOutput = ans == options[0];
                          final exportData =
                              converter.csvString(useOutput: useOutput);
                          final fileObj = LocalFile(
                              '${model.fileObject.nameNoExtension}.csv');
                          if (await fileObj.exists) {
                            if (!context.mounted) return;
                            final ans = await common_dialogs.okCancelDialog(
                              context: context,
                              title: 'Confirm Overwrite',
                              label: 'File ${fileObj.filename} already '
                                  'exists.\n\nOverwrite it?',
                            );
                            if (ans == null || !ans) return;
                          }
                          await fileObj.writeString(exportData);
                          if (!context.mounted) return;
                          await common_dialogs.okDialog(
                            context: context,
                            title: 'Export',
                            label:
                                'Local file ${fileObj.filename} was written.',
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.format_align_right),
                        title: const Text('Export to indented text'),
                        onTap: () async {
                          Navigator.pop(context);
                          final converter = TextExport(model);
                          const options = [
                            'Title lines only',
                            'All output lines',
                          ];
                          final ans = await common_dialogs.choiceDialog(
                            context: context,
                            title: 'Text Export Options',
                            choices: options,
                          );
                          if (ans == null) return;
                          final includeOutput = ans == options[1];
                          final exportText = converter.textString(
                            includeOutput: includeOutput,
                          );
                          final fileObj = LocalFile(
                              '${model.fileObject.nameNoExtension}.txt');
                          if (await fileObj.exists) {
                            if (!context.mounted) return;
                            final ans = await common_dialogs.okCancelDialog(
                              context: context,
                              title: 'Confirm Overwrite',
                              label: 'File ${fileObj.filename} already '
                                  'exists.\n\nOverwrite it?',
                            );
                            if (ans == null || !ans) return;
                          }
                          await fileObj.writeString(exportText);
                          if (!context.mounted) return;
                          await common_dialogs.okDialog(
                            context: context,
                            title: 'Export',
                            label:
                                'Local file ${fileObj.filename} was written.',
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.close),
                        title: const Text('Close File'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text('Settings'),
                        onTap: () async {
                          Navigator.pop(context);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingEdit(),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: const Text('Help View'),
                        onTap: () async {
                          Navigator.pop(context);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HelpView(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('About TreeTag'),
                        onTap: () {
                          Navigator.pop(context);
                          common_dialogs.aboutDialog(context: context);
                        },
                      ),
                      if (Platform.isLinux || Platform.isMacOS) const Divider(),
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
                        ? MarkdownWithLinks(
                            data: detailViewTitle,
                            theme: ThemeData(
                              textTheme: TextTheme(
                                bodyMedium: TextStyle(
                                  fontSize: 20.0,
                                  color: Theme.of(context)
                                      .appBarTheme
                                      .foregroundColor,
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
              if (isDetailLeafNode) ...[
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete leaf node',
                  // Delete the shown [LeafNode].
                  onPressed: () {
                    model.deleteNode(detailRootNode);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit leaf node',
                  // Edit the shown [LeafNode].
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditView(node: detailRootNode),
                      ),
                    );
                  },
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search children',
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
              ],
              IconButton(
                icon: const Icon(Icons.add_circle),
                tooltip: 'Add a new leaf node',
                // Create a new node using data copied from the shown nodes.
                onPressed: () {
                  final newNode = model.newNode(copyFromNode: detailRootNode);
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
                      (model.hasWideDisplay && detailRootNode != null))) ...[
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (result) async {
                    switch (result) {
                      case MenuItems.editChildren:
                        final commonNode = model.commonChildDataNode();
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
                          final ans = await common_dialogs.okCancelDialog(
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
                    const PopupMenuItem(
                      value: MenuItems.editChildren,
                      child: Text('Edit All Children'),
                    ),
                    const PopupMenuItem(
                      value: MenuItems.deleteChildren,
                      child: Text('Delete All Children'),
                    ),
                  ],
                ),
              ] else ...[
                // Reserve space for hidden menu icon if not present.
                SizedBox(
                  width: iconSize,
                  height: 1.0,
                ),
              ],
            ],
          ),
          body: model.hasWideDisplay
              ? SplitView(
                  viewMode: SplitViewMode.Horizontal,
                  children: <Widget>[
                    TreeView(fileRootName: fileRootName),
                    const DetailView(),
                  ],
                )
              : hasDetailViewOnly
                  ? const DetailView()
                  : TreeView(fileRootName: fileRootName),
        );
      },
    );
  }
}
