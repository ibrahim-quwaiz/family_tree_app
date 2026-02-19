import 'package:flutter/material.dart';
import '../../features/tree/screens/tree_screen.dart';
import '../../features/directory/screens/directory_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const TreeScreen(),
    const DirectoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_tree),
              label: 'الشجرة',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.contacts),
              label: 'الدليل',
            ),
          ],
          selectedItemColor: Colors.green[700],
          unselectedItemColor: Colors.grey,
        ),
      ),
    );
  }
}
