// undo_view.dart, a view listing undo steps.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../model/structure.dart';

enum MenuItems { undo, cancelUndo, delete, cancelDelete }

/// A view showing a list of undo objects.
///
/// Called from a menu in a [TreeView].
class UndoView extends StatefulWidget {
  const UndoView({super.key});

  @override
  State<UndoView> createState() => _UndoViewState();
}

class _UndoViewState extends State<UndoView> {
  /// Sets the view to undo all items greater than this position.
  int? undoToPos;

  /// Sets the view to delete all undos earlier than this position.
  int? deleteToPos;

  var _cancelFlag = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          curve: Curves.easeOut,
          duration: const Duration(milliseconds: 500),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    return PopScope<Object?>(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!_cancelFlag) {
          if (undoToPos != null) {
            model.undoList.undoToPos(undoToPos!);
          }
          if (deleteToPos != null) {
            model.undoList.removeRange(0, deleteToPos! + 1);
            model.saveFile();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Undo List'),
          leading: IconButton(
            icon: const Icon(Icons.check_circle),
            tooltip: 'Perform actions and close',
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel pending actions and close',
              onPressed: () {
                _cancelFlag = true;
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(10),
          child: Center(
            child: SizedBox(
              width: 600.0,
              child: ListView(
                controller: _scrollController,
                children: _undoCards(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _undoCards() {
    final model = Provider.of<Structure>(context, listen: false);
    final cards = <Widget>[];

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
            subtitle: Text(
              DateFormat('MMM dd HH:mm').format(model.undoList[pos].timeStamp),
            ),
            enabled: isEnabled,
            selected: isSelected,
            trailing: PopupMenuButton<MenuItems>(
              icon: const Icon(Icons.more_vert),
              onSelected: (MenuItems result) {
                switch (result) {
                  case MenuItems.undo:
                    undoToPos = pos;
                  case MenuItems.cancelUndo:
                    undoToPos = null;
                  case MenuItems.delete:
                    deleteToPos = pos;
                  case MenuItems.cancelDelete:
                    deleteToPos = null;
                }
                setState(() {});
              },
              itemBuilder: (context) => [
                if (pos != undoToPos &&
                    (deleteToPos == null || pos > deleteToPos!))
                  const PopupMenuItem<MenuItems>(
                    value: MenuItems.undo,
                    child: Text('Undo to here'),
                  ),
                if (pos == undoToPos)
                  const PopupMenuItem<MenuItems>(
                    value: MenuItems.cancelUndo,
                    child: Text('Cancel undo'),
                  ),
                if (pos != deleteToPos &&
                    (undoToPos == null || pos < undoToPos!))
                  const PopupMenuItem<MenuItems>(
                    value: MenuItems.delete,
                    child: Text('Delete to here'),
                  ),
                if (pos == deleteToPos)
                  const PopupMenuItem<MenuItems>(
                    value: MenuItems.cancelDelete,
                    child: Text('Cancel delete'),
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
