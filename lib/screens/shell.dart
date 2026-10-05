import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import 'home_screen.dart';
import 'manager/team_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';
import 'tasks_screen.dart';

/// The main tabs. Managers get a «فريقي» tab.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  void _open(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<Session>().isManager;
    final pages = <Widget>[
      HomeScreen(onOpenTab: _open),
      const RequestsScreen(),
      const TasksScreen(),
      if (manager) const TeamScreen(),
      const ProfileScreen(),
    ];
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'الرئيسية'),
      const BottomNavigationBarItem(icon: Icon(Icons.description_outlined), activeIcon: Icon(Icons.description), label: 'طلباتي'),
      const BottomNavigationBarItem(icon: Icon(Icons.task_alt_outlined), activeIcon: Icon(Icons.task_alt), label: 'المهام'),
      if (manager) const BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'فريقي'),
      const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'حسابي'),
    ];
    final index = _index.clamp(0, pages.length - 1);
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: BottomNavigationBar(currentIndex: index, onTap: _open, items: items),
    );
  }
}

/// Tab positions, so screens can send the user to another tab.
class Tabs {
  static const home = 0;
  static const requests = 1;
  static const tasks = 2;
}
