import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  String? _error;

  // إحصائيات عامة
  int _totalCount = 0;
  int _maleCount = 0;
  int _femaleCount = 0;
  int _aliveCount = 0;
  int _deceasedCount = 0;

  // توزيع الأجيال
  Map<int, int> _generationDistribution = {};

  // أكبر الفروع
  List<Map<String, dynamic>> _topBranches = [];

  // توزيع المدن
  Map<String, int> _cityDistribution = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadGeneralStats(),
        _loadGenerationDistribution(),
        _loadTopBranches(),
        _loadCityDistribution(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'خطأ في تحميل الإحصائيات: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGeneralStats() async {
    final response = await SupabaseConfig.client
        .from('people')
        .select('id, gender, is_alive');

    final list = response as List;
    _totalCount = list.length;
    _maleCount = 0;
    _femaleCount = 0;
    _aliveCount = 0;
    _deceasedCount = 0;

    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final gender = (map['gender'] as String? ?? '').toLowerCase();
      final isAlive = map['is_alive'] as bool? ?? true;

      if (gender == 'male') _maleCount++;
      if (gender == 'female') _femaleCount++;
      if (isAlive) _aliveCount++;
      else _deceasedCount++;
    }
  }

  Future<void> _loadGenerationDistribution() async {
    final response = await SupabaseConfig.client
        .from('people')
        .select('generation');

    final list = response as List;
    _generationDistribution = {};

    for (final item in list) {
      final gen = (item as Map<String, dynamic>)['generation'] as int? ?? 0;
      _generationDistribution[gen] = (_generationDistribution[gen] ?? 0) + 1;
    }
  }

  Future<void> _loadTopBranches() async {
    // جلب أبناء الجيل 1 (الفروع الرئيسية) مع عدد ذريتهم
    final gen1Response = await SupabaseConfig.client
        .from('people')
        .select('id, name')
        .eq('generation', 1)
        .order('name');

    _topBranches = [];

    for (final person in gen1Response) {
      final personId = person['id'] as String;
      final personName = person['name'] as String;

      int count = 0;
      try {
        final countResponse = await SupabaseConfig.client
            .from('people_with_children')
            .select('children_count')
            .eq('id', personId)
            .maybeSingle();
        count = countResponse?['children_count'] as int? ?? 0;
      } catch (e) {
        final directChildren = await SupabaseConfig.client
            .from('people')
            .select('id')
            .eq('father_id', personId);
        count = (directChildren as List).length;
      }

      _topBranches.add({
        'name': personName,
        'count': count,
      });
    }

    _topBranches.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  Future<void> _loadCityDistribution() async {
    final response = await SupabaseConfig.client
        .from('people')
        .select('residence_city')
        .not('residence_city', 'is', null);

    final list = response as List;
    _cityDistribution = {};

    for (final item in list) {
      final city = (item as Map<String, dynamic>)['residence_city'] as String? ?? '';
      if (city.isNotEmpty) {
        _cityDistribution[city] = (_cityDistribution[city] ?? 0) + 1;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          title: const Text('إحصائيات العائلة'),
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _loadStats,
                    color: AppColors.gold,
                    backgroundColor: AppColors.bgCard,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _buildGeneralStats(),
                          const SizedBox(height: 20),
                          _buildGenerationChart(),
                          const SizedBox(height: 20),
                          _buildTopBranchesSection(),
                          const SizedBox(height: 20),
                          _buildCityDistributionSection(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // إحصائيات عامة
  // ═══════════════════════════════════════════
  Widget _buildGeneralStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'الإحصائيات العامة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            '$_totalCount',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'إجمالي أفراد العائلة',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              _buildStatCard('👨', 'ذكور', '$_maleCount', AppColors.accentBlue),
              const SizedBox(width: 10),
              _buildStatCard('👩', 'إناث', '$_femaleCount', const Color(0xFFE91E8C)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatCard('🟢', 'أحياء', '$_aliveCount', AppColors.accentGreen),
              const SizedBox(width: 10),
              _buildStatCard('⚪', 'متوفين', '$_deceasedCount', AppColors.neutralGray),
            ],
          ),

          if (_totalCount > 0) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  Expanded(
                    flex: _maleCount > 0 ? _maleCount : 1,
                    child: Container(
                      height: 8,
                      color: AppColors.accentBlue,
                    ),
                  ),
                  Expanded(
                    flex: _femaleCount > 0 ? _femaleCount : 1,
                    child: Container(
                      height: 8,
                      color: const Color(0xFFE91E8C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ذكور ${_totalCount > 0 ? (_maleCount * 100 ~/ _totalCount) : 0}%',
                  style: const TextStyle(fontSize: 11, color: AppColors.accentBlue),
                ),
                Text(
                  'إناث ${_totalCount > 0 ? (_femaleCount * 100 ~/ _totalCount) : 0}%',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFE91E8C)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
                ),
                Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // توزيع الأجيال (رسم بياني)
  // ═══════════════════════════════════════════
  Widget _buildGenerationChart() {
    if (_generationDistribution.isEmpty) return const SizedBox.shrink();

    final sortedGens = _generationDistribution.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxCount = sortedGens.fold<int>(0, (max, e) => e.value > max ? e.value : max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'توزيع الأجيال',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          ...sortedGens.map((entry) {
            final percentage = maxCount > 0 ? entry.value / maxCount : 0.0;
            final barColor = _getGenerationColor(entry.key);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 55,
                    child: Text(
                      'الجيل ${entry.key}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final barWidth = constraints.maxWidth * percentage;
                        return Stack(
                          children: [
                            Container(
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            SizedBox(
                              width: barWidth,
                              child: Container(
                                height: 26,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [barColor, barColor.withOpacity(0.6)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '${entry.value}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getGenerationColor(int gen) {
    final colors = [
      AppColors.gold,
      AppColors.accentBlue,
      AppColors.accentGreen,
      AppColors.accentAmber,
      AppColors.accentPurple,
      AppColors.accentTeal,
      const Color(0xFFE91E8C),
      AppColors.accentRed,
      AppColors.accentBlue,
      AppColors.gold,
    ];
    return colors[gen % colors.length];
  }

  // ═══════════════════════════════════════════
  // أكبر الفروع
  // ═══════════════════════════════════════════
  Widget _buildTopBranchesSection() {
    if (_topBranches.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'أكبر الفروع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ..._topBranches.asMap().entries.map((entry) {
            final index = entry.key;
            final branch = entry.value;
            final name = branch['name'] as String;
            final count = branch['count'] as int;

            Color medalColor;
            String medal;
            if (index == 0) {
              medalColor = const Color(0xFFFFD700);
              medal = '🥇';
            } else if (index == 1) {
              medalColor = const Color(0xFFC0C0C0);
              medal = '🥈';
            } else if (index == 2) {
              medalColor = const Color(0xFFCD7F32);
              medal = '🥉';
            } else {
              medalColor = AppColors.textSecondary;
              medal = '${index + 1}';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgDeep.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: index < 3
                    ? Border.all(color: medalColor.withOpacity(0.2))
                    : null,
              ),
              child: Row(
                children: [
                  Text(medal, style: TextStyle(fontSize: index < 3 ? 22 : 14)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'فرع $name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: index < 3 ? medalColor : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$count فرد',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // توزيع المدن
  // ═══════════════════════════════════════════
  Widget _buildCityDistributionSection() {
    if (_cityDistribution.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'توزيع المدن',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد بيانات سكن مسجلة حالياً',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final sortedCities = _cityDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sortedCities.fold<int>(0, (sum, e) => sum + e.value);

    final cityColors = [
      AppColors.gold,
      AppColors.accentBlue,
      AppColors.accentGreen,
      const Color(0xFFE91E8C),
      AppColors.accentPurple,
      AppColors.accentAmber,
      AppColors.accentTeal,
      AppColors.accentRed,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'توزيع المدن',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '$total شخص',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: sortedCities.asMap().entries.map((entry) {
                final colorIndex = entry.key % cityColors.length;
                return Expanded(
                  flex: entry.value.value,
                  child: Container(
                    height: 10,
                    color: cityColors[colorIndex],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          ...sortedCities.take(10).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final city = entry.value;
            final color = cityColors[index % cityColors.length];
            final percentage = total > 0 ? (city.value * 100 / total).toStringAsFixed(1) : '0';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      city.key,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    '${city.value} ($percentage%)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // خطأ
  // ═══════════════════════════════════════════
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
              onPressed: _loadStats,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
