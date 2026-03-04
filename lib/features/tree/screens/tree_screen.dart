import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';

class TreeScreen extends StatefulWidget {
  final String? highlightPersonId;
  const TreeScreen({super.key, this.highlightPersonId});

  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> {
  // البيانات
  Map<String, dynamic>? _currentPerson;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _searchResults = [];

  // الحالة
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  // التنقل
  final List<Map<String, dynamic>> _history = [];

  // البحث
  final TextEditingController _searchController = TextEditingController();

  // معرّف الجد الأول (الجيل 0)
  String? _rootPersonId;

  @override
  void initState() {
    super.initState();
    if (widget.highlightPersonId != null) {
      _loadPersonWithHistory(widget.highlightPersonId!);
    } else {
      _loadRoot();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// تحميل الجد الأول (الجيل 0)
  Future<void> _loadRoot() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await SupabaseConfig.client
          .from('people')
          .select('id, name, gender, generation, is_alive, father_id, legacy_user_id')
          .eq('generation', 0)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _rootPersonId = response['id'] as String;
        await _loadPerson(_rootPersonId!);
      } else {
        setState(() {
          _error = 'لم يتم العثور على الجد الأول';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ في تحميل البيانات: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPersonWithHistory(String personId) async {
    setState(() => _isLoading = true);

    try {
      // بناء سلسلة الآباء من الشخص للجذر
      final ancestors = <Map<String, dynamic>>[];
      String? currentId = personId;

      while (currentId != null) {
        final person = await SupabaseConfig.client
            .from('people')
            .select('id, name, gender, generation, is_alive, father_id, legacy_user_id')
            .eq('id', currentId)
            .maybeSingle();

        if (person == null) break;
        ancestors.insert(0, person);
        currentId = person['father_id'] as String?;
      }

      // أول عنصر هو الجذر، آخر عنصر هو الشخص المطلوب
      // نضع كل الآباء (ما عدا الشخص المطلوب) في _history
      _history.clear();
      if (ancestors.length > 1) {
        _history.addAll(ancestors.sublist(0, ancestors.length - 1));
      }

      // تحميل الجذر للرجوع إليه
      if (ancestors.isNotEmpty) {
        _rootPersonId = ancestors.first['id'] as String;
      }

      // تحميل الشخص المطلوب
      await _loadPerson(personId);
    } catch (e) {
      setState(() {
        _error = 'خطأ في تحميل البيانات: $e';
        _isLoading = false;
      });
    }
  }

  /// تحميل شخص معين وأبناؤه
  Future<void> _loadPerson(String personId) async {
    setState(() => _isLoading = true);

    try {
      // جلب بيانات الشخص
      final personResponse = await SupabaseConfig.client
          .from('people')
          .select('id, name, gender, generation, is_alive, father_id, legacy_user_id')
          .eq('id', personId)
          .single();

      // جلب أبنائه المباشرين
      final childrenResponse = await SupabaseConfig.client
          .from('people')
          .select('id, name, gender, generation, is_alive, legacy_user_id')
          .eq('father_id', personId)
          .order('name');

      // حساب عدد الذرية لكل ابن (أبناء مباشرين)
      final childrenWithCounts = <Map<String, dynamic>>[];
      for (final child in childrenResponse) {
        final countResponse = await SupabaseConfig.client
            .from('people')
            .select('id')
            .eq('father_id', child['id']);

        childrenWithCounts.add({
          ...child,
          'direct_children_count': (countResponse as List).length,
        });
      }

      // حساب إجمالي الذرية للشخص الحالي (عدد الأبناء المباشرين فقط)
      final int totalDesc = childrenResponse.length;

      setState(() {
        _currentPerson = {
          ...personResponse,
          'direct_children': childrenResponse.length,
          'total_descendants': totalDesc,
        };
        _children = childrenWithCounts;
        _isLoading = false;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _error = 'خطأ في تحميل البيانات: $e';
        _isLoading = false;
      });
    }
  }

  /// التنقل لشخص (ابن)
  void _navigateTo(Map<String, dynamic> child) {
    _history.add(_currentPerson!);
    _loadPerson(child['id'] as String);
  }

  /// الرجوع للأب
  void _goBack() {
    if (_history.isNotEmpty) {
      final prev = _history.removeLast();
      _loadPerson(prev['id'] as String);
    }
  }

  /// الرجوع للجذر
  void _goToRoot() {
    _history.clear();
    if (_rootPersonId != null) {
      _loadPerson(_rootPersonId!);
    }
  }

  /// البحث
  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await SupabaseConfig.client
          .from('people')
          .select('id, name, gender, generation, is_alive, father_id, legacy_user_id')
          .ilike('name', '%${query.trim()}%')
          .order('generation')
          .order('name')
          .limit(20);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('خطأ في البحث: $e');
    }
  }

  /// الانتقال من نتيجة بحث
  void _navigateFromSearch(Map<String, dynamic> person) {
    _searchController.clear();
    _history.clear();
    _loadPerson(person['id'] as String);
  }

  /// بناء مسار الأجداد
  Future<String> _buildAncestorPath(String personId) async {
    final parts = <String>[];
    String? currentId = personId;
    int safetyCounter = 0;

    while (currentId != null && safetyCounter < 10) {
      safetyCounter++;
      try {
        final person = await SupabaseConfig.client
            .from('people')
            .select('name, father_id')
            .eq('id', currentId)
            .maybeSingle();

        if (person == null) break;
        parts.insert(0, (person['name'] as String).split(' ').first);
        currentId = person['father_id'] as String?;
      } catch (e) {
        break;
      }
    }

    return parts.join(' ← ');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildSearchBar(),
              if (!_isSearching && _history.isNotEmpty) _buildBackBar(),
              Expanded(
                child: _isSearching
                    ? _buildSearchResults()
                    : _isLoading
                        ? _buildLoading()
                        : _error != null
                            ? _buildError()
                            : _buildTreeContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // الشريط العلوي
  // ═══════════════════════════════════════════
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          const Text(
            'شجرة العائلة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          _buildIconButton(Icons.home_rounded, _goToRoot),
          const SizedBox(width: 8),
          _buildIconButton(Icons.refresh_rounded, _isLoading ? null : () {
            if (_currentPerson != null) {
              _loadPerson(_currentPerson!['id']);
            } else {
              _loadRoot();
            }
          }),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Icon(icon, color: AppColors.gold, size: 18),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // شريط البحث
  // ═══════════════════════════════════════════
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _performSearch,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'ابحث عن اسم...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _isSearching = false;
                    _searchResults = [];
                  });
                },
                child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // شريط الرجوع والمسار
  // ═══════════════════════════════════════════
  Widget _buildBackBar() {
    // بناء المسار من history
    final pathParts = <String>[];
    for (final h in _history) {
      pathParts.add((h['name'] as String).split(' ').first);
    }
    if (_currentPerson != null) {
      pathParts.add((_currentPerson!['name'] as String).split(' ').first);
    }
    final pathStr = pathParts.join(' ← ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _goBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withOpacity(0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('↑', style: TextStyle(color: AppColors.gold, fontSize: 14)),
                  SizedBox(width: 4),
                  Text(
                    'العودة للأب',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pathStr,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // المحتوى الرئيسي
  // ═══════════════════════════════════════════
  Widget _buildTreeContent() {
    if (_currentPerson == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () => _loadPerson(_currentPerson!['id']),
      color: AppColors.gold,
      backgroundColor: AppColors.bgCard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          _buildCurrentPersonCard(),
          const SizedBox(height: 20),
          if (_children.isNotEmpty) ...[
            _buildChildrenHeader(),
            const SizedBox(height: 12),
            _buildChildrenList(),
          ] else
            _buildEmptyState(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // بطاقة الشخص الحالي
  // ═══════════════════════════════════════════
  Widget _buildCurrentPersonCard() {
    final name = _currentPerson!['name'] as String;
    final gender = _currentPerson!['gender'] as String? ?? 'male';
    final gen = _currentPerson!['generation'] as int? ?? 0;
    final isAlive = _currentPerson!['is_alive'] as bool? ?? true;
    final directChildren = _currentPerson!['direct_children'] as int? ?? 0;
    final totalDesc = _currentPerson!['total_descendants'] ?? 0;

    final genderColor = gender == 'female' ? const Color(0xFFE91E8C) : AppColors.accentBlue;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withOpacity(0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // الشريط الذهبي العلوي
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.gold, AppColors.goldDark, AppColors.gold],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                // الصورة والاسم
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: genderColor.withOpacity(0.12),
                        border: Border.all(
                          color: genderColor.withOpacity(isAlive ? 0.3 : 0.15),
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0] : '؟',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: genderColor.withOpacity(isAlive ? 1 : 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildBadge('الجيل $gen', AppColors.accentBlue),
                              _buildBadge(
                                isAlive ? 'حي يرزق' : 'رحمه الله',
                                isAlive ? AppColors.accentGreen : AppColors.neutralGray,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(color: Colors.white.withOpacity(0.05), height: 1),
                const SizedBox(height: 14),

                // الإحصائيات
                Row(
                  children: [
                    _buildStatItem('$directChildren', 'أبناء مباشرين'),
                    _buildStatDivider(),
                    _buildStatItem('$totalDesc', 'إجمالي الذرية'),
                    _buildStatDivider(),
                    _buildStatItem('$gen', 'الجيل'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withOpacity(0.06),
    );
  }

  // ═══════════════════════════════════════════
  // عنوان الأبناء
  // ═══════════════════════════════════════════
  Widget _buildChildrenHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'الأبناء والبنات',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        Text(
          '${_children.length} أفراد',
          style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // قائمة الأبناء مع الخط العمودي
  // ═══════════════════════════════════════════
  Widget _buildChildrenList() {
    return Stack(
      children: [
        // الخط العمودي
        Positioned(
          right: 8,
          top: 0,
          bottom: 20,
          child: Container(
            width: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.gold.withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // البطاقات
        Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Column(
            children: _children.asMap().entries.map((entry) {
              final index = entry.key;
              final child = entry.value;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + (index * 50)),
                curve: Curves.easeOutCubic,
                builder: (context, value, widget) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(15 * (1 - value), 0),
                      child: widget,
                    ),
                  );
                },
                child: _buildChildItem(child),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildChildItem(Map<String, dynamic> child) {
    final name = child['name'] as String? ?? '';
    final gender = child['gender'] as String? ?? 'male';
    final isAlive = child['is_alive'] as bool? ?? true;
    final directChildrenCount = child['direct_children_count'] as int? ?? 0;
    final genderColor = gender == 'female' ? const Color(0xFFE91E8C) : AppColors.accentBlue;

    return Stack(
      children: [
        // الفرع الأفقي
        Positioned(
          right: -16,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              width: 16,
              height: 2,
              color: AppColors.gold.withOpacity(0.2),
            ),
          ),
        ),

        // النقطة
        Positioned(
          right: -20,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withOpacity(0.4),
              ),
            ),
          ),
        ),

        // البطاقة
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _navigateTo(child),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  // الشريط الجانبي الملون
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: genderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // الأفاتار
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: genderColor.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0] : '؟',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: genderColor.withOpacity(isAlive ? 1 : 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // الاسم والتفاصيل
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isAlive ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              isAlive ? '🟢 حي' : '⚪ متوفى',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            if (directChildrenCount > 0) ...[
                              Container(
                                width: 3,
                                height: 3,
                                margin: const EdgeInsets.symmetric(horizontal: 5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.textSecondary.withOpacity(0.4),
                                ),
                              ),
                              Text(
                                '$directChildrenCount أبناء',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // عدد الأبناء + السهم
                  if (directChildrenCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$directChildrenCount',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // نتائج البحث
  // ═══════════════════════════════════════════
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && _searchController.text.length >= 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'لا توجد نتائج لـ "${_searchController.text}"',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        Text(
          '${_searchResults.length} نتيجة',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ..._searchResults.map((person) => _buildSearchResultItem(person)),
      ],
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> person) {
    final name = person['name'] as String? ?? '';
    final gender = person['gender'] as String? ?? 'male';
    final gen = person['generation'] as int? ?? 0;
    final genderColor = gender == 'female' ? const Color(0xFFE91E8C) : AppColors.accentBlue;

    return GestureDetector(
      onTap: () => _navigateFromSearch(person),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: genderColor.withOpacity(0.1),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0] : '؟',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: genderColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  Text(
                    'الجيل $gen',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // حالة فارغة
  // ═══════════════════════════════════════════
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04), style: BorderStyle.solid),
      ),
      child: const Column(
        children: [
          Text('🍃', style: TextStyle(fontSize: 32)),
          SizedBox(height: 10),
          Text(
            'لا يوجد أبناء مسجلين لهذا الفرع',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // التحميل والخطأ
  // ═══════════════════════════════════════════
  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.gold),
          SizedBox(height: 16),
          Text('جاري تحميل البيانات...', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.accentRed),
            const SizedBox(height: 12),
            Text(
              _error ?? 'حدث خطأ',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loadRoot,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
