import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/navigation/main_navigation.dart';
import '../features/tree/screens/tree_screen.dart';
import '../features/directory/screens/directory_screen.dart';
import '../features/news/screens/news_screen.dart';
import '../features/about/screens/about_screen.dart';
import '../features/profile/screens/my_profile_screen.dart';
import '../features/stats/screens/stats_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/auth/screens/login_screen.dart';
import '../core/theme/app_theme.dart';

// ============================================================
// الصفحة الرئيسية - عائلة القويز
// ============================================================

// --- نموذج بيانات القسم ---
class GridSection {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? badge;
  final String routeName;

  const GridSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.badge,
    required this.routeName,
  });
}

// --- نموذج بيانات الخبر ---
class NewsItem {
  final String title;
  final String tag;
  final String date;

  const NewsItem({
    required this.title,
    required this.tag,
    required this.date,
  });
}

// ============================================================
// الصفحة الرئيسية
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentNavIndex = 0;

  late AnimationController _animController;
  late List<Animation<double>> _cardAnimations;

  // --- أقسام الشبكة ---
  final List<GridSection> _sections = const [
    GridSection(
      title: 'شجرة العائلة',
      description: 'تصفح أفراد العائلة وعلاقاتهم',
      icon: Icons.account_tree_rounded,
      color: AppColors.accentGreen,
      badge: 'تفاعلية',
      routeName: '/tree',
    ),
    GridSection(
      title: 'دليل العائلة',
      description: 'ابحث عن أي فرد بالاسم أو الفرع',
      icon: Icons.search_rounded,
      color: AppColors.accentBlue,
      routeName: '/directory',
    ),
    GridSection(
      title: 'الأخبار',
      description: 'آخر أخبار ومناسبات العائلة',
      icon: Icons.newspaper_rounded,
      color: AppColors.accentRed,
      badge: '٨ أخبار',
      routeName: '/news',
    ),
    GridSection(
      title: 'الأنساب',
      description: 'تاريخ ونسب عائلة القويز',
      icon: Icons.menu_book_rounded,
      color: AppColors.accentPurple,
      routeName: '/genealogy',
    ),
    GridSection(
      title: 'التواصل',
      description: 'تواصل مع أفراد العائلة',
      icon: Icons.phone_rounded,
      color: AppColors.accentTeal,
      routeName: '/contact',
    ),
    GridSection(
      title: 'المعرض',
      description: 'صور ولقطات من مناسبات العائلة',
      icon: Icons.photo_library_rounded,
      color: AppColors.accentAmber,
      routeName: '/gallery',
    ),
  ];

  // --- آخر الأخبار ---
  final List<NewsItem> _latestNews = const [
    NewsItem(
      title: 'تهنئة بمناسبة حفل زواج سعود بن محمد القويز',
      tag: 'مناسبة',
      date: 'قبل ٣ أيام',
    ),
    NewsItem(
      title: 'لقاء العائلة السنوي - الرياض ٢٠٢٦',
      tag: 'إعلان',
      date: 'قبل أسبوع',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _cardAnimations = List.generate(8, (index) {
      final start = (index * 0.08).clamp(0.0, 0.7);
      final end = (start + 0.3).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHero()),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 28, 24, 16),
                        child: Text(
                          'الأقسام الرئيسية',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.95,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildAnimatedCard(
                              index: index,
                              child: _buildGridCard(_sections[index]),
                            );
                          },
                          childCount: _sections.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildNewsSection()),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 20),
                    ),
                  ],
                ),
              ),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.8, -1),
          end: Alignment(0.8, 1),
          colors: [
            Color(0xFF132240),
            AppColors.bgDeep,
            Color(0xFF1a1a10),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: AlertDialog(
                        backgroundColor: AppColors.bgCard,
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
                  if (confirm == true) {
                    await AuthService.logout();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.textSecondary, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFamilyCrest(),
          const SizedBox(height: 16),
          const Text(
            'عائلة القويز',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'الموقع الرسمي للعائلة',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: AppColors.gold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.gold.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildFamilyCrest() {
    return FadeTransition(
      opacity: _cardAnimations[0],
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gold, AppColors.goldDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.diamond_rounded,
          size: 36,
          color: AppColors.bgDeep,
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = [
      {'number': '٤٨٧', 'label': 'فرد'},
      {'number': '١٢', 'label': 'فرع'},
      {'number': '٨', 'label': 'أخبار'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: stats.asMap().entries.map((entry) {
        final index = entry.key;
        final stat = entry.value;
        return FadeTransition(
          opacity: _cardAnimations[index + 1],
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(_cardAnimations[index + 1]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    stat['number']!,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stat['label']!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnimatedCard({required int index, required Widget child}) {
    final animIndex = (index + 3).clamp(0, _cardAnimations.length - 1);
    return FadeTransition(
      opacity: _cardAnimations[animIndex],
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(_cardAnimations[animIndex]),
        child: child,
      ),
    );
  }

  Widget _buildGridCard(GridSection section) {
    return GestureDetector(
      onTap: () {
        Widget? screen;
        switch (section.routeName) {
          case '/tree':
            screen = const TreeScreen();
            break;
          case '/directory':
            screen = const DirectoryScreen();
            break;
          case '/news':
            screen = const NewsScreen();
            break;
          case '/genealogy':
            screen = const StatsScreen();
            break;
          case '/contact':
            screen = const AboutScreen();
            break;
        }
        if (screen != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Directionality(
              textDirection: TextDirection.rtl,
              child: screen!,
            )),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: section.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                section.icon,
                size: 22,
                color: section.color,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              section.description,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w300,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            if (section.badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: section.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  section.badge!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: section.color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'آخر الأخبار',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Directionality(
                      textDirection: TextDirection.rtl,
                      child: NewsScreen(),
                    )),
                  );
                },
                child: const Text(
                  'عرض الكل ←',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._latestNews.map((news) => _buildNewsCard(news)),
        ],
      ),
    );
  }

  Widget _buildNewsCard(NewsItem news) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    news.tag,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentRed,
                    ),
                  ),
                ),
                Text(
                  news.date,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              news.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final navItems = [
      {'icon': Icons.home_rounded, 'label': 'الرئيسية'},
      {'icon': Icons.search_rounded, 'label': 'البحث'},
      {'icon': Icons.notifications_rounded, 'label': 'التنبيهات'},
      {'icon': Icons.person_rounded, 'label': 'حسابي'},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: navItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isActive = index == _currentNavIndex;

          return GestureDetector(
            onTap: () {
              setState(() => _currentNavIndex = index);
              Widget? screen;
              switch (index) {
                case 1: // البحث
                  screen = const DirectoryScreen();
                  break;
                case 2: // التنبيهات
                  screen = const NotificationsScreen();
                  break;
                case 3: // حسابي
                  screen = const MyProfileScreen();
                  break;
              }
              if (screen != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: screen!,
                  )),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 24,
                    color: isActive ? AppColors.gold : AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isActive ? AppColors.gold : AppColors.textSecondary.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
