import 'dart:async';
import 'package:flutter/material.dart';
import '../models/directory_person.dart';
import '../utils/ancestral_chain_search.dart';
import '../utils/arabic_search.dart';
import '../../../core/theme/app_theme.dart';

class ChainSearchTab extends StatefulWidget {
  final List<DirectoryPerson> allPeople;
  final Function(DirectoryPerson)? onPersonSelected;

  const ChainSearchTab({
    super.key,
    required this.allPeople,
    this.onPersonSelected,
  });

  @override
  State<ChainSearchTab> createState() => _ChainSearchTabState();
}

class _ChainSearchTabState extends State<ChainSearchTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<DirectoryPerson> _results = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      final query = _searchController.text.trim();
      setState(() {
        _searchQuery = query;
        if (query.isEmpty) {
          _results = [];
        } else {
          _results = AncestralChainSearch.searchByAncestralChain(
            query: query,
            allPeople: widget.allPeople,
          );
        }
      });
    });
  }

  void _showPersonDetails(DirectoryPerson person) {
    if (widget.onPersonSelected != null) {
      widget.onPersonSelected!(person);
    }
  }

  Color _getPersonColor(DirectoryPerson person) {
    if (!person.isAlive) return AppColors.neutralGray;
    if (person.gender == 'female') return const Color(0xFFE91E8C);
    return AppColors.primaryGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'مثال: محمد عبدالله سعد',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _results = [];
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.bgCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // نص توضيحي
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: AppColors.primaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'اكتب: اسمه ثم اسم أبيه ثم اسم جده\nمثال: "محمد عبدالله" أو "محمد عبدالله سعد"',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // نتائج البحث
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_results.length} نتيجة',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // قائمة النتائج
          Expanded(
            child: _results.isEmpty && _searchQuery.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا توجد نتائج',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'ابدأ بالبحث عن شخص',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final person = _results[index];
                          final ancestralPath = AncestralChainSearch.buildAncestralPath(
                            person: person,
                            allPeople: widget.allPeople,
                            levels: 4,
                          );
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: _getPersonColor(person),
                                backgroundImage: person.photoUrl != null
                                    ? NetworkImage(person.photoUrl!)
                                    : null,
                                child: person.photoUrl == null
                                    ? Text(
                                        person.firstLetter,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                person.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    ancestralPath,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'الجيل ${person.generation}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (person.residenceCity != null) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          person.residenceCity!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _showPersonDetails(person),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
