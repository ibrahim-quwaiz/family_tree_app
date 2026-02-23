import 'package:flutter/material.dart';
import '../models/person.dart';
import '../widgets/person_card.dart';
import '../widgets/tree_filters.dart';
import '../layout/tree_layout.dart';
import '../widgets/tree_painter.dart';
import '../../../core/theme/app_theme.dart';

class TreeScreen extends StatefulWidget {
  const TreeScreen({super.key});

  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> {
  final TransformationController _transformationController = TransformationController();
  final TreeLayout _treeLayout = TreeLayout();
  
  late List<Person> allPeople;
  late List<Person> filteredPeople;
  
  Map<String, Offset> _positions = {};
  Size _treeSize = const Size(800, 600);
  
  double _currentZoom = 1.0;
  final double _minZoom = 0.3;
  final double _maxZoom = 3.0;
  
  TreeFilters filters = TreeFilters();
  String? highlightedPersonId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() => _isLoading = true);
    
    print('🚀 بدء تحميل الأشخاص...');
    
    try {
      // جلب من Supabase
      print('📡 محاولة جلب البيانات من Supabase...');
      final fetchedPeople = await Person.fetchFromSupabase();
      
      print('📊 النتيجة: ${fetchedPeople.length} شخص');
      
      setState(() {
        if (fetchedPeople.isNotEmpty) {
          // بيانات حقيقية من Supabase
          allPeople = fetchedPeople;
          filteredPeople = allPeople;
          print('✅ تم تحميل ${allPeople.length} شخص من Supabase بنجاح');
          print('📈 توزيع الأجيال:');
          final generationCounts = <int, int>{};
          for (var person in allPeople) {
            generationCounts[person.generation] = 
                (generationCounts[person.generation] ?? 0) + 1;
          }
          generationCounts.forEach((gen, count) {
            print('   الجيل $gen: $count شخص');
          });
        } else {
          // بيانات تجريبية (فقط في حالة الفشل)
          print('⚠️ لم يتم جلب بيانات من Supabase، استخدام البيانات التجريبية');
          allPeople = Person.getSampleFamily();
          filteredPeople = allPeople;
          print('📝 تم تحميل ${allPeople.length} شخص تجريبي');
        }
        _isLoading = false;
      });
      
      // حساب المواقع بعد تحميل البيانات
      _computePositions();
    } catch (e, stackTrace) {
      print('❌ خطأ في _loadPeople: $e');
      print('📋 Stack trace: $stackTrace');
      
      setState(() {
        // في حالة الخطأ، استخدام البيانات التجريبية
        allPeople = Person.getSampleFamily();
        filteredPeople = allPeople;
        _isLoading = false;
        print('⚠️ تم استخدام البيانات التجريبية بسبب الخطأ');
      });
      
      _computePositions();
    }
  }

  /// Calculate positions for all filtered people
  void _computePositions() {
    if (filteredPeople.isEmpty) {
      _positions = {};
      _treeSize = const Size(800, 600);
      return;
    }

    _positions = _treeLayout.calculatePositions(filteredPeople);
    _treeSize = _treeLayout.getTreeSize(_positions);
    
    print('📍 تم حساب ${_positions.length} موقع');
    print('📐 حجم الشجرة: ${_treeSize.width.toInt()} x ${_treeSize.height.toInt()}');
  }

  void _applyFilters(TreeFilters newFilters) {
    setState(() {
      filters = newFilters;
      
      filteredPeople = allPeople.where((person) {
        if (!filters.showAlive && person.isAlive) return false;
        if (!filters.showDeceased && !person.isAlive) return false;
        if (!filters.selectedGenerations.contains(person.generation)) return false;
        
        if (filters.searchQuery.isNotEmpty) {
          return person.name.contains(filters.searchQuery);
        }
        
        return true;
      }).toList();
      
      if (filters.searchQuery.isNotEmpty && filteredPeople.isNotEmpty) {
        highlightedPersonId = filteredPeople.first.id;
      } else {
        highlightedPersonId = null;
      }
      
      // إعادة حساب المواقع للأشخاص المرئيين فقط
      _computePositions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.bgDeep,
          title: const Text('شجرة العائلة'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadPeople,
              tooltip: 'تحديث البيانات',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            SearchAndFiltersBar(
              filters: filters,
              onFiltersChanged: _applyFilters,
              onFiltersTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => FiltersBottomSheet(
                    initialFilters: filters,
                    onApply: _applyFilters,
                  ),
                );
              },
            ),
            
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'جاري تحميل البيانات من Supabase...',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Stack(
                  children: [
                    InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: _minZoom,
                      maxScale: _maxZoom,
                      boundaryMargin: const EdgeInsets.all(500),
                      constrained: false,
                      onInteractionUpdate: (details) {
                        setState(() {
                          _currentZoom = _transformationController.value.getMaxScaleOnAxis();
                        });
                      },
                      child: _buildTree(),
                    ),
                    
                    Positioned(bottom: 100, right: 16, child: _buildZoomControls()),
                    Positioned(top: 16, right: 16, child: _buildZoomIndicator()),
                    Positioned(bottom: 16, left: 16, child: _buildMinimap()),
                    
                    if (filters.searchQuery.isNotEmpty)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${filteredPeople.length} نتيجة',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTree() {
    if (filteredPeople.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد بيانات للعرض',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      );
    }

    return SizedBox(
      width: _treeSize.width,
      height: _treeSize.height,
      child: Stack(
        children: [
          // Draw connection lines
          CustomPaint(
            size: _treeSize,
            painter: TreePainter(
              positions: _positions,
              people: filteredPeople,
            ),
          ),
          
          // Draw person cards
          ...filteredPeople.map((person) {
            final position = _positions[person.id];
            if (position == null) return const SizedBox.shrink();
            
            final isHighlighted = highlightedPersonId == person.id;
            final useSimplified = _currentZoom < 0.5;
            
            return Positioned(
              left: position.dx,
              top: position.dy,
              child: RepaintBoundary(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: isHighlighted 
                      ? (Matrix4.identity()..scale(1.1)) 
                      : Matrix4.identity(),
                  child: useSimplified
                      ? _buildSimplifiedCard(person)
                      : PersonCard(
                          person: person,
                          isCurrentUser: person.legacyUserId == 'QF02004',
                          onTap: () => _showPersonDetails(person),
                        ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Build simplified card for zoom < 0.5
  Widget _buildSimplifiedCard(Person person) {
    final isHighlighted = highlightedPersonId == person.id;
    final genderColor = person.gender == 'male' 
        ? Colors.blue.withOpacity(0.3)
        : person.gender == 'female'
            ? Colors.pink.withOpacity(0.3)
            : AppColors.primaryGreen.withOpacity(0.2);

    return GestureDetector(
      onTap: () => _showPersonDetails(person),
      child: Container(
        width: 160,
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: genderColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlighted 
                ? AppColors.secondaryGold 
                : AppColors.primaryGreen.withOpacity(0.5),
            width: isHighlighted ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            person.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          mini: true,
          backgroundColor: AppColors.bgCard,
          child: const Icon(Icons.add, color: AppColors.gold),
          onPressed: _zoomIn,
          heroTag: 'zoom_in',
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          mini: true,
          backgroundColor: AppColors.bgCard,
          child: const Icon(Icons.remove, color: AppColors.gold),
          onPressed: _zoomOut,
          heroTag: 'zoom_out',
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          mini: true,
          backgroundColor: AppColors.bgCard,
          child: const Icon(Icons.center_focus_strong, color: AppColors.gold),
          onPressed: _resetZoom,
          heroTag: 'zoom_reset',
        ),
      ],
    );
  }

  Widget _buildZoomIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${(_currentZoom * 100).toInt()}%',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMinimap() {
    return Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people, color: AppColors.gold, size: 40),
          const SizedBox(height: 8),
          Text(
            '${filteredPeople.length}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
          const Text(
            'شخص',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _zoomIn() => _animateZoom((_currentZoom * 1.2).clamp(_minZoom, _maxZoom));
  void _zoomOut() => _animateZoom((_currentZoom / 1.2).clamp(_minZoom, _maxZoom));
  void _resetZoom() => _animateZoom(1.0);

  void _animateZoom(double targetZoom) {
    _transformationController.value = Matrix4.identity()..scale(targetZoom);
    setState(() => _currentZoom = targetZoom);
  }

  void _showPersonDetails(Person person) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              person.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'الجيل ${person.generation}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(width: 16),
                Text(
                  person.isAlive ? '🟢 حي' : '⚪ متوفى',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            if (person.legacyUserId != null) ...[
              const SizedBox(height: 8),
              Text(
                'الرقم: ${person.legacyUserId}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'عدد الأبناء: ${person.childrenCount}',
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
            if (person.mobilePhone != null) ...[
              const SizedBox(height: 12),
              Text(
                'الجوال: ${person.mobilePhone}',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}
