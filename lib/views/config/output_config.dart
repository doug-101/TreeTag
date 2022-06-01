// output_config.dart, a view to edit the title and output line configuration.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2022, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/parsed_line.dart';
import '../../model/structure.dart';
import 'line_edit.dart';

/// The output config widget.
///
/// Lists the title line and the output lines.
/// One of the tabbed items on the [ConfigView].
class OutputConfig extends StatefulWidget {
  @override
  State<OutputConfig> createState() => _OutputConfigState();
}

class _OutputConfigState extends State<OutputConfig> {
  ParsedLine? selectedLine;
  @override
  Widget build(BuildContext context) {
    var model = Provider.of<Structure>(context, listen: false);
    var lineNum = 1;
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Add a new output line before the selection or at the end.
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: selectedLine == model.titleLine
                  ? null
                  : () async {
                      final newLine = ParsedLine.empty();
                      final isChanged = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              LineEdit(line: newLine, title: 'New Output Line'),
                        ),
                      );
                      if (isChanged) {
                        var pos = model.outputLines.length;
                        if (selectedLine != null) {
                          pos = model.outputLines.indexOf(selectedLine!);
                        }
                        setState(() {
                          model.addOutputLine(pos, newLine);
                          selectedLine = newLine;
                        });
                      }
                    },
            ),
            // Edit the selected line.
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: selectedLine == null
                  ? null
                  : () async {
                      final title = selectedLine == model.titleLine
                          ? 'Title Line Edit'
                          : 'Output Line Edit';
                      final editedLine = selectedLine!.copy();
                      final isChanged = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              LineEdit(line: editedLine, title: title),
                        ),
                      );
                      if (isChanged) {
                        setState(() {
                          model.editOutputLine(selectedLine!, editedLine);
                          selectedLine = editedLine;
                        });
                      }
                    },
            ),
            // Delete the selected line.
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: (selectedLine == null ||
                      selectedLine == model.titleLine ||
                      model.outputLines.length < 2)
                  ? null
                  : () {
                      setState(() {
                        model.removeOutputLine(selectedLine!);
                        selectedLine = null;
                      });
                    },
            ),
            // Move the selected line up.
            IconButton(
              icon: const Icon(Icons.arrow_circle_up),
              onPressed: (selectedLine == null ||
                      selectedLine == model.titleLine ||
                      model.outputLines.indexOf(selectedLine!) == 0)
                  ? null
                  : () {
                      setState(() {
                        model.moveOutputLine(selectedLine!);
                      });
                    },
            ),
            // Move the selected line down.
            IconButton(
              icon: const Icon(Icons.arrow_circle_down),
              onPressed: (selectedLine == null ||
                      selectedLine == model.titleLine ||
                      model.outputLines.indexOf(selectedLine!) ==
                          model.outputLines.length - 1)
                  ? null
                  : () {
                      setState(() {
                        model.moveOutputLine(selectedLine!, up: false);
                      });
                    },
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: ListView(
              children: <Widget>[
                _lineRow('Title Line', model.titleLine),
                Divider(),
                for (var outLine in model.outputLines)
                  _lineRow('Output Line ${lineNum++}', outLine),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _lineRow(String heading, ParsedLine line) {
    return InkWell(
      onTap: () {
        setState(() {
          if (line != selectedLine) {
            selectedLine = line;
          } else {
            selectedLine = null;
          }
        });
      },
      child: Card(
        color: line == selectedLine ? Theme.of(context).highlightColor : null,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(heading, style: Theme.of(context).textTheme.caption),
              Padding(
                padding: EdgeInsets.only(top: 6.0),
                child: Text.rich(
                  TextSpan(
                    children: line.richLineSpans(TextStyle(
                        color: Theme.of(context).colorScheme.secondary)),
                  ),
                  style: Theme.of(context).textTheme.subtitle1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
