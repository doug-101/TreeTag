// config_view.dart, a view to edit file configurations.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2021, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import 'field_config.dart';
import 'tree_config.dart';

// The base config view.
class ConfigView extends StatefulWidget {
  @override
  State<ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<ConfigView> {
  int _selectedIndex = 0;

  static List<Widget> pages = [
    FieldConfig(),
    TreeConfig(),
    Container(color: Colors.blue),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('File Config'),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            label: 'Fields',
            icon: Icon(Icons.settings),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Tree',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Output',
          ),
        ],
      ),
    );
  }
}
