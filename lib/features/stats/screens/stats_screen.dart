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

  // توزيع المدن
  Map<String, int> _cityDistribution = {};

  // توزيع الحالة الاجتماعية
  int _marriedCount = 0;
  int _singleCount = 0;
  int _unknownMaritalCount = 0;

  // المواليد حسب السنة
  Map<int, int> _birthsByYear = {};

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
        _loadCityDistribution(),
        _loadMaritalStatus(),
        _loadBirthsByYear(),
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

  Future<void> _loadMaritalStatus() async {
    final response = await SupabaseConfig.client
        .from('people')
        .select('marital_status');

    final list = response as List;
    _marriedCount = 0;
    _singleCount = 0;

    for (final item in list) {
      final status = (item as Map<String, dynamic>)['marital_status'] as String?;
      if (status == 'متزوج') {
        _marriedCount++;
      } else if (status == 'أعزب') {
        _singleCount++;
      }
    }
  }

  Future<void> _loadBirthsByYear() async {
    final response = await SupabaseConfig.client
        .from('people')
        .select('birth_date')
        .not('birth_date', 'is', null);

    final list = response as List;
    _birthsByYear = {};

    for (final item in list) {
      final dateStr = (item as Map<String, dynamic>)['birth_date'] as String?;
      if (dateStr != null && dateStr.isNotEmpty) {
        final date = DateTime.tryParse(dateStr);
        if (date != null && date.year > 1900) {
          _birthsByYear[date.year] = (_birthsByYear[date.year] ?? 0) + 1;
        }
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
                          _buildMaritalStatusSection(),
                          const SizedBox(height: 20),
                          _buildGenerationChart(),
                          const SizedBox(height: 20),
                          _buildBirthsByYearSection(),
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
                    child: Container(height: 8, color: AppColors.accentBlue),
                  ),
                  Expanded(
                    flex: _femaleCount > 0 ? _femaleCount : 1,
                    child: Container(height: 8, color: const Color(0xFFE91E8C)),
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
  // توزيع الحالة الاجتماعية
  // ═══════════════════════════════════════════
  Widget _buildMaritalStatusSection() {
    final total = _marriedCount + _singleCount;
    if (total == 0) return const SizedBox.shrink();

    final marriedPercent = (total > 0) ? (_marriedCount * 100 / total).toStringAsFixed(1) : '0';
    final singlePercent = (total > 0) ? (_singleCount * 100 / total).toStringAsFixed(1) : '0';

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
              const Icon(Icons.favorite_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'الحالة الاجتماعية',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // الدوائر
          Row(
            children: [
              Expanded(
                child: _buildCircularStat(
                  'متزوج',
                  _marriedCount,
                  total,
                  AppColors.accentGreen,
                  Icons.people_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCircularStat(
                  'أعزب',
                  _singleCount,
                  total,
                  AppColors.accentBlue,
                  Icons.person_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // شريط النسبة
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: _marriedCount > 0 ? _marriedCount : 1,
                  child: Container(height: 8, color: AppColors.accentGreen),
                ),
                Expanded(
                  flex: _singleCount > 0 ? _singleCount : 1,
                  child: Container(height: 8, color: AppColors.accentBlue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'متزوج $marriedPercent%',
                style: const TextStyle(fontSize: 11, color: AppColors.accentGreen),
              ),
              Text(
                'أعزب $singlePercent%',
                style: const TextStyle(fontSize: 11, color: AppColors.accentBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularStat(String label, int count, int total, Color color, IconData icon) {
    final percentage = total > 0 ? count / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: percentage,
                    strokeWidth: 6,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
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
  // المواليد حسب السنة
  // ═══════════════════════════════════════════
  Widget _buildBirthsByYearSection() {
    if (_birthsByYear.isEmpty) return const SizedBox.shrink();

    final sortedYears = _birthsByYear.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxCount = sortedYears.fold<int>(0, (max, e) => e.value > max ? e.value : max);
    final totalBirths = sortedYears.fold<int>(0, (sum, e) => sum + e.value);

    // تجميع حسب العقود لو البيانات كثيرة
    final bool groupByDecade = sortedYears.length > 20;

    List<MapEntry<String, int>> displayData;

    if (groupByDecade) {
      final decades = <String, int>{};
      for (final entry in sortedYears) {
        final decade = '${(entry.key ~/ 10) * 10}s';
        final decadeLabel = '${(entry.key ~/ 10) * 10}';
        decades[decadeLabel] = (decades[decadeLabel] ?? 0) + entry.value;
      }
      displayData = decades.entries.toList();
    } else {
      displayData = sortedYears.map((e) => MapEntry('${e.key}', e.value)).toList();
    }

    final displayMax = displayData.fold<int>(0, (max, e) => e.value > max ? e.value : max);

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
              const Icon(Icons.cake_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              const Text(
                'المواليد حسب السنة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '$totalBirths مسجل',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (groupByDecade)
            Text(
              'مجمّع حسب العقد',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.6)),
            ),
          const SizedBox(height: 16),

          // رسم بياني عمودي
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: displayData.map((entry) {
                final barHeight = displayMax > 0 ? (entry.value / displayMax) * 150 : 0.0;
                final colorIndex = displayData.indexOf(entry);
                final color = _getBirthYearColor(colorIndex, displayData.length);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.value}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: barHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [color, color.withOpacity(0.4)],
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        RotatedBox(
                          quarterTurns: -1,
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // أعلى وأقل سنة
          if (sortedYears.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildBirthHighlight(
                    'أكثر سنة مواليد',
                    '${sortedYears.reduce((a, b) => a.value > b.value ? a : b).key}',
                    '${sortedYears.reduce((a, b) => a.value > b.value ? a : b).value} مولود',
                    AppColors.accentGreen,
                    Icons.trending_up_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildBirthHighlight(
                    'أقدم مولود مسجل',
                    '${sortedYears.first.key}',
                    '',
                    AppColors.accentAmber,
                    Icons.history_rounded,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getBirthYearColor(int index, int total) {
    // تدرج من الذهبي إلى الأخضر
    final t = total > 1 ? index / (total - 1) : 0.0;
    return Color.lerp(AppColors.gold, AppColors.accentGreen, t) ?? AppColors.gold;
  }

  Widget _buildBirthHighlight(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10, color: color.withOpacity(0.7)),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: color.withOpacity(0.6)),
                  ),
              ],
            ),
          ),
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
                  child: Container(height: 10, color: cityColors[colorIndex]),
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
