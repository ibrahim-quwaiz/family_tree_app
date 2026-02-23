import 'package:flutter/material.dart';
import '../../features/tree/screens/tree_screen.dart';
import '../../features/news/screens/news_screen.dart';
import '../../features/directory/screens/directory_screen.dart';
import '../../features/about/screens/about_screen.dart';
import '../theme/app_theme.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const TreeScreen(),
    const NewsScreen(),
    const DirectoryScreen(),
    const AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: _screens[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.bgDeep,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: AppColors.bgDeep,
            selectedItemColor: AppColors.gold,
            unselectedItemColor: AppColors.textSecondary.withOpacity(0.5),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.account_tree_rounded),
                label: 'الشجرة',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.newspaper_rounded),
                label: 'الأخبار',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                label: 'الدليل',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.info_rounded),
                label: 'عن العائلة',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
