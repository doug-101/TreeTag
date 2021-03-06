// undo_view.dart, a view listing undo steps.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../model/structure.dart';
import '../model/undos.dart';

enum MenuItems { undo, cancelUndo, delete, cancelDelete }

/// A view showing a list of undo objects.
///
/// Called from a menu in a [TreeView].
class UndoView extends StatefulWidget {
  @override
  State<UndoView> createState() => _UndoViewState();
}

class _UndoViewState extends State<UndoView> {

  /// Sets the view to undo all items greater than this position.
  int? undoToPos;

  /// Sets the view to delete all undos earlier than this position.
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
          children: _undoCards(),
        ),
      ),
    );
  }

  List<Widget> _undoCards() {
    var model = Provider.of<Structure>(context, listen: false);
    var cards = <Widget>[];
    /// Flag to show whether there are undo items ealier than redo items.
    var hasPrevUndo = false;
    for (var pos = 0; pos < model.undoList.length; pos++) {
      var isEnabled = true;
      var isSelected = false;
      if (deleteToPos != null && pos <= deleteToPos!) {
        isEnabled = false;
      }
      if (undoToPos != null && pos >= undoToPos!) {
        // Disable redo items if an earlier undo is being undone.
        if (hasPrevUndo && model.undoList[pos].isRedo) {
          isEnabled = false;
        } else {
          isSelected = true;
        }
        if (!model.undoList[pos].isRedo) hasPrevUndo = true;
      }
      cards.add(
        Card(
          child: ListTile(
            title: Text(model.undoList[pos].title),
            subtitle: Text(DateFormat('MMM dd HH:mm')
                .format(model.undoList[pos].timeStamp)),
            enabled: isEnabled,
            selected: isSelected,
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
        ),
      );
    }
    return cards;
  }
}
