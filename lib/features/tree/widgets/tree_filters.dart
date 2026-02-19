import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// فلاتر الشجرة
class TreeFilters {
  bool showAlive;
  bool showDeceased;
  Set<int> selectedGenerations;
  String searchQuery;

  TreeFilters({
    this.showAlive = true,
    this.showDeceased = true,
    Set<int>? selectedGenerations,
    this.searchQuery = '',
  }) : selectedGenerations = selectedGenerations ?? {0, 1, 2, 3, 4, 5, 6, 7};

  TreeFilters copyWith({
    bool? showAlive,
    bool? showDeceased,
    Set<int>? selectedGenerations,
    String? searchQuery,
  }) {
    return TreeFilters(
      showAlive: showAlive ?? this.showAlive,
      showDeceased: showDeceased ?? this.showDeceased,
      selectedGenerations: selectedGenerations ?? this.selectedGenerations,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// شريط البحث والفلاتر
class SearchAndFiltersBar extends StatelessWidget {
  final TreeFilters filters;
  final Function(TreeFilters) onFiltersChanged;
  final VoidCallback onFiltersTap;

  const SearchAndFiltersBar({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
    required this.onFiltersTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          // شريط البحث
          Expanded(
            child: TextField(
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن شخص...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                onFiltersChanged(filters.copyWith(searchQuery: value));
              },
            ),
          ),
          
          const SizedBox(width: 12),
          
          // زر الفلاتر
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _hasActiveFilters() 
                  ? AppColors.primaryGreen 
                  : AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.tune,
                color: _hasActiveFilters() 
                    ? Colors.white 
                    : AppColors.textSecondary,
              ),
              onPressed: onFiltersTap,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return !filters.showAlive || 
           !filters.showDeceased || 
           filters.selectedGenerations.length < 8;
  }
}

/// Bottom Sheet للفلاتر
class FiltersBottomSheet extends StatefulWidget {
  final TreeFilters initialFilters;
  final Function(TreeFilters) onApply;

  const FiltersBottomSheet({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  @override
  State<FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<FiltersBottomSheet> {
  late TreeFilters filters;

  @override
  void initState() {
    super.initState();
    filters = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // العنوان
          const Text(
            'الفلاتر',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // الحالة
          const Text(
            'الحالة:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Row(
                    children: [
                      Text('🟢'),
                      SizedBox(width: 8),
                      Text('الأحياء'),
                    ],
                  ),
                  value: filters.showAlive,
                  onChanged: (value) {
                    setState(() {
                      filters = filters.copyWith(showAlive: value);
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Row(
                    children: [
                      Text('⚪'),
                      SizedBox(width: 8),
                      Text('المتوفين'),
                    ],
                  ),
                  value: filters.showDeceased,
                  onChanged: (value) {
                    setState(() {
                      filters = filters.copyWith(showDeceased: value);
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // الجيل
          const Text(
            'الجيل:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(8, (index) {
              final isSelected = filters.selectedGenerations.contains(index);
              return FilterChip(
                label: Text('الجيل $index'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    final newGens = Set<int>.from(filters.selectedGenerations);
                    if (selected) {
                      newGens.add(index);
                    } else {
                      newGens.remove(index);
                    }
                    filters = filters.copyWith(selectedGenerations: newGens);
                  });
                },
                selectedColor: AppColors.primaryGreen.withOpacity(0.2),
                checkmarkColor: AppColors.primaryGreen,
              );
            }),
          ),
          
          const SizedBox(height: 24),
          
          // الأزرار
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      filters = TreeFilters(); // إعادة تعيين
                    });
                  },
                  child: const Text('إعادة تعيين'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    widget.onApply(filters);
                    Navigator.pop(context);
                  },
                  child: const Text('تطبيق'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}