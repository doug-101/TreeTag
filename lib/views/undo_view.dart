// undo_view.dart, a view listing undo steps.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../model/structure.dart';
import '../model/undos.dart';

enum MenuItems { undo, cancelUndo, delete, cancelDelete }

/// A view showing a list of undo objects.
class UndoView extends StatefulWidget {
  @override
  State<UndoView> createState() => _UndoViewState();
}

class _UndoViewState extends State<UndoView> {
  int? undoToPos;
  int? deleteToPos;

  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    return WillPopScope(
      onWillPop: () async {
        var model = Provider.of<Structure>(context, listen: false);
        if (undoToPos != null) {
          model.undoList.undoToPos(undoToPos!);
        }
        if (deleteToPos != null) {
          model.undoList.removeRange(0, deleteToPos! + 1);
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Undo List'),
        ),
        body: ListView(
          children: [
            for (var pos = 0; pos < model.undoList.length; pos++)
              Card(
                child: ListTile(
                  title: Text(model.undoList[pos].title),
                  subtitle: Text(DateFormat('MMM dd HH:mm')
                      .format(model.undoList[pos].timeStamp)),
                  enabled: deleteToPos == null || pos > deleteToPos!,
                  selected: undoToPos != null && pos >= undoToPos!,
                  trailing: PopupMenuButton<MenuItems>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (MenuItems result) {
                      switch (result) {
                        case MenuItems.undo:
                          undoToPos = pos;
                          break;
                        case MenuItems.cancelUndo:
                          undoToPos = null;
                          break;
                        case MenuItems.delete:
                          deleteToPos = pos;
                          break;
                        case MenuItems.cancelDelete:
                          deleteToPos = null;
                          break;
                      }
                      setState(() {});
                    },
                    itemBuilder: (context) => [
                      if (pos != undoToPos &&
                          (deleteToPos == null || pos > deleteToPos!))
                        PopupMenuItem<MenuItems>(
                          child: Text('Undo to here'),
                          value: MenuItems.undo,
                        ),
                      if (pos == undoToPos)
                        PopupMenuItem<MenuItems>(
                          child: Text('Cancel undo'),
                          value: MenuItems.cancelUndo,
                        ),
                      if (pos != deleteToPos &&
                          (undoToPos == null || pos < undoToPos!))
                        PopupMenuItem<MenuItems>(
                          child: Text('Delete to here'),
                          value: MenuItems.delete,
                        ),
                      if (pos == deleteToPos)
                        PopupMenuItem<MenuItems>(
                          child: Text('Cancel delete'),
                          value: MenuItems.cancelDelete,
                        ),
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
