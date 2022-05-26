// adaptive_split.dart, a view that is split on wide screens.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_view/split_view.dart';
import 'detail_view.dart';
import 'tree_view.dart';
import '../model/structure.dart';

class AdaptiveSplit extends StatelessWidget {
  final String fileRootName;

  AdaptiveSplit({Key? key, required this.fileRootName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    model.hasWideDisplay = MediaQuery.of(context).size.width > 600;
    if (model.hasWideDisplay) {
    return SplitView(
      viewMode: SplitViewMode.Horizontal,
      children: <Widget>[
        TreeView(fileRootName: fileRootName),
        DetailView(),
      ],
    );
    } else {
      return TreeView(fileRootName: fileRootName);
    }
  }
}
