import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/config/supabase_config.dart';
import '../features/tree/screens/tree_screen.dart';
import '../features/directory/screens/directory_screen.dart';
import '../features/news/screens/news_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/about/screens/about_screen.dart';
import '../features/stats/screens/stats_screen.dart';
import '../features/profile/screens/my_profile_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/admin/screens/admin_screen.dart';
import '../features/contact/screens/contact_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _HomePage(),
    const TreeScreen(),
    const DirectoryScreen(),
    const NotificationsScreen(),
    const MyProfileScreen(),
  ];

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
        border: Border(
          top: BorderSide(color: AppColors.gold.withOpacity(0.1), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'الرئيسية'),
              _buildNavItem(1, Icons.account_tree_rounded, Icons.account_tree_outlined, 'الشجرة'),
              _buildNavItem(2, Icons.people_rounded, Icons.people_outlined, 'الدليل'),
              _buildNavItem(3, Icons.notifications_rounded, Icons.notifications_outlined, 'التنبيهات'),
              _buildNavItem(4, Icons.person_rounded, Icons.person_outlined, 'حسابي'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? AppColors.gold : AppColors.textSecondary.withOpacity(0.5),
              size: isSelected ? 24 : 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.gold : AppColors.textSecondary.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// الصفحة الرئيسية
// ═══════════════════════════════════════════════════════════════════
class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> with SingleTickerProviderStateMixin {
  String? _userName;
  bool _isAdmin = false;

  // إحصائيات
  int _totalMembers = 0;
  int _maleCount = 0;
  int _femaleCount = 0;
  int _aliveCount = 0;
  bool _statsLoading = true;

  // أخبار
  List<Map<String, dynamic>> _latestNews = [];
  bool _newsLoading = true;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadUserName();
    _loadStats();
    _loadLatestNews();
    AuthService.isAdmin().then((value) {
      if (mounted) setState(() => _isAdmin = value);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final name = await AuthService.getCurrentName();
    if (mounted) setState(() => _userName = name);
  }

  Future<void> _loadStats() async {
    try {
      final response = await SupabaseConfig.client
          .from('people')
          .select('id, gender, is_alive');
      final list = response as List;
      int male = 0, female = 0, alive = 0;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final gender = (map['gender'] as String? ?? '').toLowerCase();
        final isAlive = map['is_alive'] as bool? ?? true;
        if (gender == 'male') male++;
        if (gender == 'female') female++;
        if (isAlive) alive++;
      }
      if (mounted) {
        setState(() {
          _totalMembers = list.length;
          _maleCount = male;
          _femaleCount = female;
          _aliveCount = alive;
          _statsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadLatestNews() async {
    try {
      final response = await SupabaseConfig.client
          .from('news')
          .select('id, news_type, title, content, image_url, author_name, created_at')
          .eq('is_approved', true)
          .order('created_at', ascending: false)
          .limit(3);
      if (mounted) {
        setState(() {
          _latestNews = List<Map<String, dynamic>>.from(response);
          _newsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _newsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.bgCard,
          onRefresh: () async {
            await Future.wait([_loadStats(), _loadLatestNews()]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: FadeTransition(
              opacity: _animController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('القائمة الرئيسية'),
                  const SizedBox(height: 12),
                  _buildGrid(),
                  const SizedBox(height: 24),
                  _buildLatestNewsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── الهيدر ───
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withOpacity(0.08),
            AppColors.bgCard.withOpacity(0.6),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // أيقونة المستخدم
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.gold.withOpacity(0.3), AppColors.goldDark.withOpacity(0.2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: const Icon(Icons.person_rounded, color: AppColors.gold, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً ${_userName ?? ''}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'عائلة القويز',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showLogoutDialog(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgDeep.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.textSecondary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ─── الإحصائيات السريعة ───
  Widget _buildStatsRow() {
    if (_statsLoading) {
      return SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.gold.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        _buildStatCard('الإجمالي', _totalMembers.toString(), Icons.groups_rounded, AppColors.gold),
        const SizedBox(width: 8),
        _buildStatCard('ذكور', _maleCount.toString(), Icons.male_rounded, AppColors.accentBlue),
        const SizedBox(width: 8),
        _buildStatCard('إناث', _femaleCount.toString(), Icons.female_rounded, AppColors.accentPurple),
        const SizedBox(width: 8),
        _buildStatCard('أحياء', _aliveCount.toString(), Icons.favorite_rounded, AppColors.accentGreen),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const Directionality(
                textDirection: TextDirection.rtl,
                child: StatsScreen(),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── عنوان قسم ───
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ─── شبكة الأقسام ───
  Widget _buildGrid() {
    final items = [
      if (_isAdmin)
        _GridItem(
          icon: Icons.admin_panel_settings_rounded,
          title: 'لوحة التحكم',
          color: const Color(0xFFE91E8C),
          route: '/admin',
        ),
      _GridItem(icon: Icons.account_tree_rounded, title: 'شجرة العائلة', color: AppColors.accentGreen, route: '/tree'),
      _GridItem(icon: Icons.people_rounded, title: 'دليل الأعضاء', color: AppColors.accentBlue, route: '/directory'),
      _GridItem(icon: Icons.newspaper_rounded, title: 'الأخبار', color: AppColors.accentPurple, route: '/news'),
      _GridItem(icon: Icons.bar_chart_rounded, title: 'الإحصائيات', color: AppColors.accentAmber, route: '/stats'),
      _GridItem(icon: Icons.info_rounded, title: 'عن العائلة', color: AppColors.accentTeal, route: '/about'),
      _GridItem(icon: Icons.support_agent_rounded, title: 'تواصل معنا', color: AppColors.accentGreen, route: '/contact'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildGridCard(items[index]),
    );
  }

  Widget _buildGridCard(_GridItem item) {
    return GestureDetector(
      onTap: () => _navigateTo(item.route),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.color.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.color, size: 24),
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

  void _navigateTo(String route) {
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();

    switch (route) {
      case '/tree':
        homeState?.setState(() => homeState._currentIndex = 1);
        break;
      case '/directory':
        homeState?.setState(() => homeState._currentIndex = 2);
        break;
      case '/notifications':
        homeState?.setState(() => homeState._currentIndex = 3);
        break;
      case '/admin':
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => const Directionality(textDirection: TextDirection.rtl, child: AdminScreen()),
        ));
        break;
      default:
        Widget? screen;
        switch (route) {
          case '/news':
            screen = const NewsScreen();
            break;
          case '/stats':
            screen = const StatsScreen();
            break;
          case '/about':
            screen = const AboutScreen();
            break;
          case '/contact':
            screen = const ContactScreen();
            break;
        }
        if (screen != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => Directionality(textDirection: TextDirection.rtl, child: screen!),
          ));
        }
    }
  }

  // ─── آخر الأخبار ───
  Widget _buildLatestNewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('آخر الأخبار'),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const Directionality(textDirection: TextDirection.rtl, child: NewsScreen()),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _newsLoading
            ? _buildNewsShimmer()
            : _latestNews.isEmpty
                ? _buildEmptyNews()
                : Column(
                    children: _latestNews.map((news) => _buildNewsCard(news)).toList(),
                  ),
      ],
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> news) {
    final newsType = (news['news_type'] as String? ?? 'general').toLowerCase();
    final typeConfig = _getNewsTypeConfig(newsType);
    final createdAt = news['created_at'] != null ? DateTime.tryParse(news['created_at']) : null;
    final timeAgo = createdAt != null ? _getTimeAgo(createdAt) : '';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => const Directionality(textDirection: TextDirection.rtl, child: NewsScreen()),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: typeConfig['color'].withOpacity(0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // أيقونة النوع
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (typeConfig['color'] as Color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(typeConfig['icon'] as IconData, color: typeConfig['color'] as Color, size: 20),
            ),
            const SizedBox(width: 12),
            // المحتوى
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (typeConfig['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeConfig['label'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: typeConfig['color'] as Color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (timeAgo.isNotEmpty)
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    news['title'] as String? ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    news['content'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withOpacity(0.7),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsShimmer() {
    return Column(
      children: List.generate(2, (index) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.gold.withOpacity(0.3),
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildEmptyNews() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          Icon(Icons.newspaper_rounded, color: AppColors.textSecondary.withOpacity(0.3), size: 36),
          const SizedBox(height: 8),
          Text(
            'لا توجد أخبار حالياً',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getNewsTypeConfig(String type) {
    switch (type) {
      case 'events':
        return {'label': 'مناسبات', 'icon': Icons.celebration, 'color': const Color(0xFF4CAF50)};
      case 'births':
        return {'label': 'ولادات', 'icon': Icons.child_care, 'color': const Color(0xFFE91E63)};
      case 'deaths':
        return {'label': 'وفيات', 'icon': Icons.local_florist, 'color': const Color(0xFF757575)};
      default:
        return {'label': 'أخبار عامة', 'icon': Icons.newspaper, 'color': const Color(0xFF2196F3)};
    }
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return 'منذ ${diff.inDays ~/ 365} سنة';
    if (diff.inDays > 30) return 'منذ ${diff.inDays ~/ 30} شهر';
    if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';
    return 'الآن';
  }

  // ─── تسجيل الخروج ───
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
