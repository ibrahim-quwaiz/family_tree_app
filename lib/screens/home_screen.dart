import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/tree/screens/tree_screen.dart';
import '../features/directory/screens/directory_screen.dart';
import '../features/news/screens/news_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/about/screens/about_screen.dart';
import '../features/stats/screens/stats_screen.dart';
import '../features/profile/screens/my_profile_screen.dart';
import '../features/admin/screens/admin_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/auth/screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _userName;

  // الصفحات الرئيسية (تتبدل بالبار السفلي)
  final List<Widget> _pages = [
    const _HomePage(),        // 0: الرئيسية
    const TreeScreen(),       // 1: الشجرة
    const NotificationsScreen(), // 2: الإشعارات
    const MyProfileScreen(),  // 3: حسابي
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await AuthService.getCurrentName();
    if (mounted) {
      setState(() => _userName = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textSecondary.withOpacity(0.5),
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_tree_rounded),
            label: 'الشجرة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_rounded),
            label: 'التنبيهات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// الصفحة الرئيسية (المحتوى فقط بدون Scaffold)
// ═══════════════════════════════════════════════════════════════════
class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  String? _userName;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadAdminFlag();
  }

  Future<void> _loadUserName() async {
    final name = await AuthService.getCurrentName();
    if (mounted) {
      setState(() => _userName = name);
    }
  }

  Future<void> _loadAdminFlag() async {
    final isAdmin = await AuthService.isAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الترحيب
              _buildHeader(),
              const SizedBox(height: 24),
              // الشبكة
              _buildGrid(),
              const SizedBox(height: 24),
              // آخر الأخبار
              _buildLatestNewsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أهلاً ${_userName ?? ''}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'عائلة القويز',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // زر تسجيل الخروج
        GestureDetector(
          onTap: () => _showLogoutDialog(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: const Icon(Icons.logout_rounded, color: AppColors.textSecondary, size: 20),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text('هل تريد تسجيل الخروج؟', style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true && mounted) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildGrid() {
    final items = [
      _GridItem(icon: Icons.account_tree_rounded, title: 'شجرة العائلة', color: AppColors.accentGreen, route: '/tree'),
      _GridItem(icon: Icons.people_rounded, title: 'دليل الأعضاء', color: AppColors.accentBlue, route: '/directory'),
      _GridItem(icon: Icons.newspaper_rounded, title: 'الأخبار', color: AppColors.accentPurple, route: '/news'),
      _GridItem(icon: Icons.bar_chart_rounded, title: 'الإحصائيات', color: AppColors.accentAmber, route: '/stats'),
      _GridItem(icon: Icons.info_rounded, title: 'عن العائلة', color: AppColors.accentTeal, route: '/about'),
      _GridItem(icon: Icons.notifications_rounded, title: 'الإشعارات', color: AppColors.accentRed, route: '/notifications'),
      if (_isAdmin)
        _GridItem(icon: Icons.admin_panel_settings_rounded, title: 'لوحة التحكم', color: AppColors.gold, route: '/admin'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildGridCard(item);
      },
    );
  }

  Widget _buildGridCard(_GridItem item) {
    return GestureDetector(
      onTap: () {
        // الصفحات اللي في البار السفلي → نتنقل بالبار
        final homeState = context.findAncestorStateOfType<_HomeScreenState>();

        switch (item.route) {
          case '/tree':
            homeState?.setState(() => homeState._currentIndex = 1);
            break;
          case '/notifications':
            homeState?.setState(() => homeState._currentIndex = 2);
            break;
          default:
            // الصفحات الفرعية تنفتح فوق (بدون بار)
            Widget? screen;
            switch (item.route) {
              case '/directory':
                screen = const DirectoryScreen();
                break;
              case '/admin':
                screen = const AdminScreen();
                break;
              case '/news':
                screen = const NewsScreen();
                break;
              case '/stats':
                screen = const StatsScreen();
                break;
              case '/about':
                screen = const AboutScreen();
                break;
            }
            if (screen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: screen!,
                  ),
                ),
              );
            }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestNewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'آخر الأخبار',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Directionality(
                      textDirection: TextDirection.rtl,
                      child: NewsScreen(),
                    ),
                  ),
                );
              },
              child: const Text(
                'عرض الكل',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: const Text(
            'تابعونا لمعرفة آخر أخبار العائلة والفعاليات القادمة',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
          ),
        ),
      ],
    );
  }
}

class _GridItem {
  final IconData icon;
  final String title;
  final Color color;
  final String route;

  _GridItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.route,
  });
}
