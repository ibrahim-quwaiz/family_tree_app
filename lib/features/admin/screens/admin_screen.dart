import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/supabase_config.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _allPeople = [];
  List<Map<String, dynamic>> _filteredPeople = [];
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredUsers = [];
  final _usersSearchController = TextEditingController();
  bool _isLoadingPeople = true;

  List<Map<String, dynamic>> _allMarriages = [];
  List<Map<String, dynamic>> _filteredMarriages = [];
  bool _isLoadingMarriages = true;
  final _marriagesSearchController = TextEditingController();

  List<Map<String, dynamic>> _allGirlsChildren = [];
  List<Map<String, dynamic>> _filteredGirlsChildren = [];
  bool _isLoadingGirlsChildren = true;
  final _girlsChildrenSearchController = TextEditingController();

  List<Map<String, dynamic>> _allNews = [];
  bool _isLoadingNews = true;

  List<Map<String, dynamic>> _allNotifications = [];
  bool _isLoadingNotifications = true;

  List<Map<String, dynamic>> _allRequests = [];
  bool _isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadTabData(_tabController.index);
      }
    });
    _loadPeople();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _marriagesSearchController.dispose();
    _girlsChildrenSearchController.dispose();
    _usersSearchController.dispose();
    super.dispose();
  }

  void _loadTabData(int index) {
    switch (index) {
      case 0: if (_allPeople.isEmpty) _loadPeople(); break;
      case 1: if (_allMarriages.isEmpty) { if (_allPeople.isEmpty) _loadPeople(); _loadMarriages(); } break;
      case 2: if (_allGirlsChildren.isEmpty) { if (_allPeople.isEmpty) _loadPeople(); _loadGirlsChildren(); } break;
      case 3: if (_allNews.isEmpty) _loadNews(); _loadNotifications(); break;
      case 4: if (_allPeople.isEmpty) _loadPeople(); break;
      case 5: _loadSupportRequests(); break;
    }
  }

  Future<void> _loadPeople() async {
    setState(() => _isLoadingPeople = true);
    try {
      final response = await SupabaseConfig.client
          .from('people')
          .select('id, legacy_user_id, name, gender, generation, is_alive, father_id, mother_id, mother_external_name, birth_date, death_date, birth_city, birth_country, residence_city, job, education, marital_status, is_admin, pin_code, sort_order')
          .order('generation')
          .order('name');

      setState(() {
        _allPeople = List<Map<String, dynamic>>.from(response);
        _filteredPeople = _allPeople;
        _filteredUsers = _allPeople;
        _isLoadingPeople = false;
      });
    } catch (e) {
      setState(() => _isLoadingPeople = false);
      _showError('خطأ في تحميل الأشخاص: $e');
    }
  }

  Future<void> _loadMarriages() async {
    setState(() => _isLoadingMarriages = true);
    try {
      final response = await SupabaseConfig.client
          .from('marriages')
          .select('id, husband_id, wife_id, wife_external_name, marriage_order, is_current')
          .order('marriage_order');

      final marriagesWithNames = <Map<String, dynamic>>[];
      for (final m in response) {
        final marriage = Map<String, dynamic>.from(m);

        final husbandId = marriage['husband_id'] as String?;
        if (husbandId != null) {
          try {
            final husband = _allPeople.firstWhere((p) => p['id'] == husbandId);
            marriage['husband_name'] = husband['name'];
            marriage['husband_qf'] = husband['legacy_user_id'] as String? ?? '';
          } catch (_) {
            marriage['husband_name'] = 'غير معروف';
            marriage['husband_qf'] = '';
          }
        }

        final wifeId = marriage['wife_id'] as String?;
        if (wifeId != null) {
          try {
            final wife = _allPeople.firstWhere((p) => p['id'] == wifeId);
            marriage['wife_name'] = wife['name'];
            marriage['wife_qf'] = wife['legacy_user_id'] as String? ?? '';
            marriage['is_external'] = false;
          } catch (_) {
            marriage['wife_name'] = 'غير معروفة';
            marriage['wife_qf'] = '';
            marriage['is_external'] = false;
          }
        } else {
          marriage['wife_name'] = marriage['wife_external_name'] ?? 'غير معروفة';
          marriage['wife_qf'] = '';
          marriage['is_external'] = true;
        }

        marriagesWithNames.add(marriage);
      }

      setState(() {
        _allMarriages = marriagesWithNames;
        _filteredMarriages = List.from(_allMarriages);
        _isLoadingMarriages = false;
      });
    } catch (e) {
      setState(() => _isLoadingMarriages = false);
      _showError('خطأ في تحميل الزواجات: $e');
    }
  }

  void _filterMarriages(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMarriages = List.from(_allMarriages);
      } else {
        _filteredMarriages = _allMarriages.where((m) {
          final husbandName = (m['husband_name'] as String? ?? '').toLowerCase();
          final wifeName = (m['wife_name'] as String? ?? '').toLowerCase();
          final husbandQf = (m['husband_qf'] as String? ?? '').toLowerCase();
          final wifeQf = (m['wife_qf'] as String? ?? '').toLowerCase();
          final q = query.toLowerCase();
          return husbandName.contains(q) || wifeName.contains(q) || husbandQf.contains(q) || wifeQf.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _loadGirlsChildren() async {
    setState(() => _isLoadingGirlsChildren = true);
    try {
      final response = await SupabaseConfig.client
          .from('girls_children')
          .select('id, mother_id, father_name, child_name, child_gender, child_birthdate')
          .order('child_name');

      final childrenWithNames = <Map<String, dynamic>>[];
      for (final c in response) {
        final child = Map<String, dynamic>.from(c);
        final motherId = child['mother_id'] as String?;
        if (motherId != null && _allPeople.isNotEmpty) {
          final mother = _allPeople.firstWhere(
            (p) => p['id'] == motherId,
            orElse: () => <String, dynamic>{},
          );
          child['mother_name'] = mother.isNotEmpty ? mother['name'] : 'غير معروفة';
          child['mother_qf'] = mother.isNotEmpty ? (mother['legacy_user_id'] as String? ?? '') : '';
        } else {
          child['mother_name'] = 'غير معروفة';
          child['mother_qf'] = '';
        }
        childrenWithNames.add(child);
      }

      if (mounted) {
        setState(() {
          _allGirlsChildren = childrenWithNames;
          _filteredGirlsChildren = childrenWithNames;
          _isLoadingGirlsChildren = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGirlsChildren = false);
      _showError('خطأ في تحميل أبناء البنات: $e');
    }
  }

  void _filterGirlsChildren(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGirlsChildren = List.from(_allGirlsChildren);
      } else {
        _filteredGirlsChildren = _allGirlsChildren.where((c) {
          final childName = (c['child_name'] as String? ?? '').toLowerCase();
          final motherName = (c['mother_name'] as String? ?? '').toLowerCase();
          final fatherName = (c['father_name'] as String? ?? '').toLowerCase();
          final motherQf = (c['mother_qf'] as String? ?? '').toLowerCase();
          final q = query.toLowerCase();
          return childName.contains(q) || motherName.contains(q) || fatherName.contains(q) || motherQf.contains(q);
        }).toList();
      }
    });
  }

  void _showAddGirlChildFromTab() {
    final childNameController = TextEditingController();
    final fatherNameController = TextEditingController();
    final motherQfController = TextEditingController();
    Map<String, dynamic>? selectedMother;
    String childGender = 'male';
    DateTime? childBirthdate;
    List<String> allFatherNames = [];
    List<String> filteredFatherNames = [];
    bool showFatherSuggestions = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E8C).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.child_care_rounded, color: Color(0xFFE91E8C), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('إضافة ابن/بنت لبنت العائلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('الأم (بنت العائلة) — رقم QF *'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(motherQfController, 'مثال: QF05012')),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final qf = motherQfController.text.trim().toUpperCase();
                          if (qf.isEmpty) return;
                          final found = _allPeople.firstWhere(
                            (p) => (p['legacy_user_id'] as String? ?? '').toUpperCase() == qf && p['gender'] == 'female',
                            orElse: () => <String, dynamic>{},
                          );
                          if (found.isNotEmpty) {
                            setModalState(() => selectedMother = found);
                            // جلب أسماء الآباء الفريدة من girls_children
                            final fathersResponse = await SupabaseConfig.client
                                .from('girls_children')
                                .select('father_name')
                                .eq('mother_id', selectedMother!['id']);
                            final fatherSet = <String>{};
                            for (final r in fathersResponse) {
                              if (r['father_name'] != null && (r['father_name'] as String).isNotEmpty) {
                                fatherSet.add(r['father_name'] as String);
                              }
                            }
                            allFatherNames = fatherSet.toList();
                            setModalState(() {});
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('لم يتم العثور على أنثى بـ $qf'), backgroundColor: AppColors.accentRed),
                            );
                          }
                        },
                        child: Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.search_rounded, color: AppColors.bgDeep, size: 22),
                        ),
                      ),
                    ],
                  ),
                  if (selectedMother != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accentGreen.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selectedMother!['name']} (${selectedMother!['legacy_user_id']})',
                              style: const TextStyle(fontSize: 13, color: AppColors.accentGreen),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModalState(() { selectedMother = null; motherQfController.clear(); }),
                            child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  _buildLabel('اسم الطفل *'),
                  const SizedBox(height: 4),
                  _buildTextField(childNameController, 'الاسم الكامل'),
                  const SizedBox(height: 12),

                  _buildLabel('الأب'),
                  const SizedBox(height: 6),
                  if (selectedMother == null)
                    Text('اختر الأم أولاً', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (allFatherNames.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.gold.withOpacity(0.15)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('آباء مسجلين:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    ...allFatherNames.map((name) {
                                      final isSelected = fatherNameController.text == name;
                                      return GestureDetector(
                                        onTap: () {
                                          fatherNameController.text = name;
                                          showFatherSuggestions = false;
                                          setModalState(() {});
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.accentGreen.withOpacity(0.15)
                                                : AppColors.bgDeep,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppColors.accentGreen.withOpacity(0.4)
                                                  : Colors.white.withOpacity(0.08),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isSelected ? Icons.check_circle_rounded : Icons.person_outline_rounded,
                                                size: 14,
                                                color: isSelected ? AppColors.accentGreen : AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isSelected ? AppColors.accentGreen : AppColors.textPrimary,
                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                    GestureDetector(
                                      onTap: () {
                                        fatherNameController.clear();
                                        showFatherSuggestions = false;
                                        setModalState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.gold.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add_rounded, size: 14, color: AppColors.gold),
                                            SizedBox(width: 4),
                                            Text('أب جديد', style: TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (allFatherNames.isEmpty || fatherNameController.text.isEmpty || !allFatherNames.contains(fatherNameController.text))
                          _buildTextField(fatherNameController, 'اكتب اسم الأب'),
                      ],
                    ),
                  const SizedBox(height: 12),

                  _buildLabel('الجنس'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildGenderOption('ذكر', 'male', childGender, (val) => setModalState(() => childGender = val)),
                      const SizedBox(width: 8),
                      _buildGenderOption('أنثى', 'female', childGender, (val) => setModalState(() => childGender = val)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildLabel('تاريخ الميلاد'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(2010),
                        firstDate: DateTime(1970),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setModalState(() => childBirthdate = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Text(
                        childBirthdate != null ? '${childBirthdate!.year}/${childBirthdate!.month}/${childBirthdate!.day}' : 'اختر التاريخ',
                        style: TextStyle(fontSize: 14, color: childBirthdate != null ? AppColors.textPrimary : AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        if (selectedMother == null) { _showError('اختر الأم'); return; }
                        if (childNameController.text.trim().isEmpty) { _showError('اسم الطفل مطلوب'); return; }
                        if (fatherNameController.text.trim().isEmpty) { _showError('اسم الأب مطلوب'); return; }

                        Navigator.pop(context);
                        try {
                          final insertData = <String, dynamic>{
                            'mother_id': selectedMother!['id'],
                            'father_name': fatherNameController.text.trim(),
                            'child_name': childNameController.text.trim(),
                            'child_gender': childGender,
                          };
                          if (childBirthdate != null) {
                            insertData['child_birthdate'] = childBirthdate!.toIso8601String().split('T')[0];
                          }
                          await SupabaseConfig.client.from('girls_children').insert(insertData);
                          _showSuccess('تم إضافة ${childNameController.text.trim()}');
                          _loadGirlsChildren();
                        } catch (e) {
                          _showError('خطأ: $e');
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('إضافة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditGirlChildDialog(Map<String, dynamic> child) {
    final childNameController = TextEditingController(text: child['child_name'] as String? ?? '');
    final fatherNameController = TextEditingController(text: child['father_name'] as String? ?? '');
    String childGender = child['child_gender'] as String? ?? 'male';
    DateTime? childBirthdate;
    if (child['child_birthdate'] != null) {
      try { childBirthdate = DateTime.parse(child['child_birthdate'] as String); } catch (_) {}
    }
    List<String> allFatherNames = [];
    bool editFatherNamesLoaded = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.edit_rounded, color: AppColors.gold, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('تعديل: ${child['child_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text('ابن/بنت: ${child['mother_name'] ?? '—'}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('اسم الطفل *'),
                  const SizedBox(height: 4),
                  _buildTextField(childNameController, 'الاسم'),
                  const SizedBox(height: 12),

                  _buildLabel('الأب'),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final motherId = child['mother_id'] as String?;
                      if (motherId != null && !editFatherNamesLoaded) {
                        editFatherNamesLoaded = true;
                        Future.microtask(() async {
                          final fathersResponse = await SupabaseConfig.client
                              .from('girls_children')
                              .select('father_name')
                              .eq('mother_id', motherId);
                          final fatherSet = <String>{};
                          for (final r in fathersResponse) {
                            if (r['father_name'] != null && (r['father_name'] as String).isNotEmpty) {
                              fatherSet.add(r['father_name'] as String);
                            }
                          }
                          allFatherNames = fatherSet.toList();
                          if (context.mounted) setModalState(() {});
                        });
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (allFatherNames.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.gold.withOpacity(0.15)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('آباء مسجلين:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ...allFatherNames.map((name) {
                                        final isSelected = fatherNameController.text == name;
                                        return GestureDetector(
                                          onTap: () {
                                            fatherNameController.text = name;
                                            setModalState(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.accentGreen.withOpacity(0.15)
                                                  : AppColors.bgDeep,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppColors.accentGreen.withOpacity(0.4)
                                                    : Colors.white.withOpacity(0.08),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isSelected ? Icons.check_circle_rounded : Icons.person_outline_rounded,
                                                  size: 14,
                                                  color: isSelected ? AppColors.accentGreen : AppColors.textSecondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isSelected ? AppColors.accentGreen : AppColors.textPrimary,
                                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                      GestureDetector(
                                        onTap: () {
                                          fatherNameController.clear();
                                          setModalState(() {});
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.add_rounded, size: 14, color: AppColors.gold),
                                              SizedBox(width: 4),
                                              Text('أب جديد', style: TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (allFatherNames.isEmpty || fatherNameController.text.isEmpty || !allFatherNames.contains(fatherNameController.text))
                            _buildTextField(fatherNameController, 'اكتب اسم الأب'),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildLabel('الجنس'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildGenderOption('ذكر', 'male', childGender, (val) => setModalState(() => childGender = val)),
                      const SizedBox(width: 8),
                      _buildGenderOption('أنثى', 'female', childGender, (val) => setModalState(() => childGender = val)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildLabel('تاريخ الميلاد'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: childBirthdate ?? DateTime(2010),
                        firstDate: DateTime(1970),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setModalState(() => childBirthdate = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Text(
                        childBirthdate != null ? '${childBirthdate!.year}/${childBirthdate!.month}/${childBirthdate!.day}' : 'اختر',
                        style: TextStyle(fontSize: 14, color: childBirthdate != null ? AppColors.textPrimary : AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        if (childNameController.text.trim().isEmpty) { _showError('اسم الطفل مطلوب'); return; }
                        Navigator.pop(context);
                        try {
                          final updateData = <String, dynamic>{
                            'child_name': childNameController.text.trim(),
                            'father_name': fatherNameController.text.trim(),
                            'child_gender': childGender,
                          };
                          if (childBirthdate != null) {
                            updateData['child_birthdate'] = childBirthdate!.toIso8601String().split('T')[0];
                          }
                          await SupabaseConfig.client.from('girls_children').update(updateData).eq('id', child['id']);
                          _showSuccess('تم التعديل');
                          _loadGirlsChildren();
                        } catch (e) {
                          _showError('خطأ: $e');
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('حفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGirlChild(Map<String, dynamic> child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('تأكيد الحذف', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('حذف "${child['child_name']}"؟', style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: AppColors.accentRed))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseConfig.client.from('girls_children').delete().eq('id', child['id']);
      _showSuccess('تم الحذف');
      _loadGirlsChildren();
    } catch (e) {
      _showError('خطأ: $e');
    }
  }

  Future<void> _loadNews() async {
    setState(() => _isLoadingNews = true);
    try {
      final response = await SupabaseConfig.client
          .from('news')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _allNews = List<Map<String, dynamic>>.from(response);
        _isLoadingNews = false;
      });
    } catch (e) {
      setState(() => _isLoadingNews = false);
      _showError('خطأ في تحميل الأخبار: $e');
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoadingNotifications = true);
    try {
      final response = await SupabaseConfig.client
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _allNotifications = List<Map<String, dynamic>>.from(response);
        _isLoadingNotifications = false;
      });
    } catch (e) {
      setState(() => _isLoadingNotifications = false);
    }
  }

  void _filterPeople(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPeople = _allPeople;
      } else {
        _filteredPeople = _allPeople.where((p) {
          final name = (p['name'] as String? ?? '').toLowerCase();
          final qf = (p['legacy_user_id'] as String? ?? '').toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || qf.contains(q);
        }).toList();
      }
    });
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allPeople;
      } else {
        _filteredUsers = _allPeople.where((p) {
          final name = (p['name'] as String? ?? '').toLowerCase();
          final qf = (p['legacy_user_id'] as String? ?? '').toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || qf.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _deletePerson(Map<String, dynamic> person) async {
    final personId = person['id'] as String;
    final personName = person['name'] as String? ?? '—';
    final personQf = person['legacy_user_id'] as String? ?? '';

    // التحقق من الارتباطات
    final children = _allPeople.where((p) => p['father_id'] == personId || p['mother_id'] == personId).toList();
    final marriages = _allMarriages.where((m) => m['husband_id'] == personId || m['wife_id'] == personId).toList();
    
    // التحقق من أبناء البنات
    int girlsChildrenCount = 0;
    if (person['gender'] == 'female') {
      try {
        final gc = await SupabaseConfig.client
            .from('girls_children')
            .select('id')
            .eq('mother_id', personId);
        girlsChildrenCount = (gc as List).length;
      } catch (_) {}
    }

    final hasRelations = children.isNotEmpty || marriages.isNotEmpty || girlsChildrenCount > 0;

    if (hasRelations) {
      // لا يسمح بالحذف — يعرض تفاصيل الارتباطات
      String details = '';
      if (children.isNotEmpty) {
        details += '👨‍👩‍👦 ${children.length} ابن/بنت\n';
      }
      if (marriages.isNotEmpty) {
        details += '💍 ${marriages.length} زواج\n';
      }
      if (girlsChildrenCount > 0) {
        details += '👶 $girlsChildrenCount من أبناء البنات\n';
      }

      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: Row(
              children: [
                const Icon(Icons.block_rounded, color: AppColors.accentRed, size: 22),
                const SizedBox(width: 8),
                const Text('لا يمكن الحذف', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"$personName" ($personQf) مرتبط بالتالي:',
                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
                  ),
                  child: Text(details, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.8)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'لحذف هذا الشخص، يجب أولاً حذف أو نقل جميع الارتباطات المتعلقة به من التبويبات المخصصة (الأشخاص، الزواجات، أبناء البنات).',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('فهمت', style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // لا يوجد ارتباطات — يسمح بالحذف
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('تأكيد الحذف', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'هل أنت متأكد من حذف "$personName"؟\nهذا الإجراء لا يمكن التراجع عنه.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      // حذف بيانات التواصل أولاً
      await SupabaseConfig.client.from('contact_info').delete().eq('person_id', personId);
      // حذف الشخص
      await SupabaseConfig.client.from('people').delete().eq('id', personId);
      _showSuccess('تم حذف "$personName" بنجاح');
      _loadPeople();
    } catch (e) {
      _showError('خطأ في الحذف: $e');
    }
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildGenderOption(String label, String value, String current, Function(String) onTap) {
    final isSelected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.gold.withOpacity(0.15) : AppColors.bgDeep.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.06)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.gold : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditPersonDialog(Map<String, dynamic> person) {
    final nameController = TextEditingController(text: person['name'] as String? ?? '');
    final birthCityController = TextEditingController(text: person['birth_city'] as String? ?? '');
    final birthCountryController = TextEditingController(text: person['birth_country'] as String? ?? '');
    final residenceCityController = TextEditingController(text: person['residence_city'] as String? ?? '');
    final jobController = TextEditingController(text: person['job'] as String? ?? '');
    final educationController = TextEditingController(text: person['education'] as String? ?? '');
    String maritalStatus = person['marital_status'] as String? ?? '';
    final pinController = TextEditingController(text: person['pin_code'] as String? ?? '');
    final fatherQfController = TextEditingController();
    final mobileController = TextEditingController();
    final emailController = TextEditingController();
    Uint8List? selectedImageBytes;
    String? currentPhotoUrl;
    final instagramController = TextEditingController();
    final twitterController = TextEditingController();
    final snapchatController = TextEditingController();
    final facebookController = TextEditingController();
    String selectedGender = person['gender'] as String? ?? 'male';
    bool isAlive = person['is_alive'] as bool? ?? true;
    final int generation = person['generation'] as int? ?? 1;
    DateTime? birthDate;
    DateTime? deathDate;
    Map<String, dynamic>? selectedFather;
    final String? selectedFatherId = person['father_id'] as String?;
    List<Map<String, dynamic>> fatherWives = [];
    Map<String, dynamic>? selectedMotherMarriage;
    bool _contactLoaded = false;
    bool _wivesLoadedForEdit = false;

    if (person['father_id'] != null) {
      try {
        final father = _allPeople.firstWhere(
          (p) => p['id'] == person['father_id'],
          orElse: () => <String, dynamic>{},
        );
        if (father.isNotEmpty) {
          selectedFather = father;
          fatherQfController.text = father['legacy_user_id'] as String? ?? '';
        }
      } catch (_) {}
    }

    if (person['birth_date'] != null) {
      try {
        birthDate = DateTime.parse(person['birth_date'] as String);
      } catch (_) {}
    }
    if (person['death_date'] != null) {
      try {
        deathDate = DateTime.parse(person['death_date'] as String);
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_contactLoaded) ...[
                    Builder(
                      builder: (_) {
                        _contactLoaded = true;
                        SupabaseConfig.client
                            .from('contact_info')
                            .select()
                            .eq('person_id', person['id'])
                            .maybeSingle()
                            .then((contact) {
                              if (contact != null) {
                                mobileController.text = contact['mobile_phone'] as String? ?? '';
                                emailController.text = contact['email'] as String? ?? '';
                                currentPhotoUrl = contact['photo_url'] as String?;
                                instagramController.text = contact['instagram'] as String? ?? '';
                                twitterController.text = contact['twitter'] as String? ?? '';
                                snapchatController.text = contact['snapchat'] as String? ?? '';
                                facebookController.text = contact['facebook'] as String? ?? '';
                              }
                              setModalState(() {});
                            });
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                  if (!_wivesLoadedForEdit && selectedFatherId != null)
                    Builder(
                      builder: (_) {
                        _wivesLoadedForEdit = true;
                        SupabaseConfig.client
                            .from('marriages')
                            .select('id, wife_id, wife_external_name, marriage_order, is_current')
                            .eq('husband_id', selectedFatherId!)
                            .order('marriage_order')
                            .then((response) async {
                          final wives = <Map<String, dynamic>>[];
                          for (final m in response) {
                            final marriage = Map<String, dynamic>.from(m);
                            final wifeId = marriage['wife_id'] as String?;
                            if (wifeId != null) {
                              final wife = await SupabaseConfig.client
                                  .from('people')
                                  .select('name')
                                  .eq('id', wifeId)
                                  .maybeSingle();
                              marriage['wife_name'] = wife?['name'] ?? 'غير معروفة';
                              marriage['is_external'] = false;
                            } else {
                              marriage['wife_name'] = marriage['wife_external_name'] ?? 'غير معروفة';
                              marriage['is_external'] = true;
                            }
                            wives.add(marriage);
                          }
                          setModalState(() {
                            fatherWives = wives;
                            if (person['mother_id'] != null) {
                              try {
                                selectedMotherMarriage = fatherWives.cast<Map<String, dynamic>?>().firstWhere(
                                  (w) => w?['wife_id'] == person['mother_id'],
                                  orElse: () => null,
                                );
                              } catch (_) {}
                            } else if (person['mother_external_name'] != null && (person['mother_external_name'] as String).isNotEmpty) {
                              try {
                                selectedMotherMarriage = fatherWives.cast<Map<String, dynamic>?>().firstWhere(
                                  (w) => w?['wife_external_name'] == person['mother_external_name'],
                                  orElse: () => null,
                                );
                              } catch (_) {}
                            }
                          });
                        });
                        return const SizedBox.shrink();
                      },
                    ),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_rounded, color: AppColors.gold, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'تعديل: ${person['name']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'QF: ${person['legacy_user_id'] ?? '—'}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('الاسم *'),
                  const SizedBox(height: 4),
                  _buildTextField(nameController, 'الاسم الكامل'),
                  const SizedBox(height: 12),
                  _buildLabel('الجنس'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildGenderOption('ذكر', 'male', selectedGender, (val) => setModalState(() => selectedGender = val)),
                      const SizedBox(width: 8),
                      _buildGenderOption('أنثى', 'female', selectedGender, (val) => setModalState(() => selectedGender = val)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'الجيل: $generation',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('الأب (أدخل رقم QF)'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(fatherQfController, 'مثال: QF03001'),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final qf = fatherQfController.text.trim().toUpperCase();
                          if (qf.isEmpty) {
                            setModalState(() => selectedFather = null);
                            return;
                          }
                          try {
                            final found = _allPeople.firstWhere(
                              (p) => (p['legacy_user_id'] as String? ?? '').toUpperCase() == qf,
                              orElse: () => <String, dynamic>{},
                            );
                            if (found.isNotEmpty) {
                              setModalState(() => selectedFather = found);
                              // جلب زوجات الأب
                              SupabaseConfig.client
                                  .from('marriages')
                                  .select('id, wife_id, wife_external_name, marriage_order, is_current')
                                  .eq('husband_id', found['id'])
                                  .order('marriage_order')
                                  .then((response) async {
                                final wives = <Map<String, dynamic>>[];
                                for (final m in response) {
                                  final marriage = Map<String, dynamic>.from(m);
                                  final wifeId = marriage['wife_id'] as String?;
                                  if (wifeId != null) {
                                    final wife = await SupabaseConfig.client
                                        .from('people')
                                        .select('name')
                                        .eq('id', wifeId)
                                        .maybeSingle();
                                    marriage['wife_name'] = wife?['name'] ?? 'غير معروفة';
                                    marriage['is_external'] = false;
                                  } else {
                                    marriage['wife_name'] = marriage['wife_external_name'] ?? 'غير معروفة';
                                    marriage['is_external'] = true;
                                  }
                                  wives.add(marriage);
                                }
                                setModalState(() {
                                  fatherWives = wives;
                                  if (person['mother_id'] != null) {
                                    try {
                                      selectedMotherMarriage = fatherWives.cast<Map<String, dynamic>?>().firstWhere(
                                        (w) => w?['wife_id'] == person['mother_id'],
                                        orElse: () => null,
                                      );
                                    } catch (_) {}
                                  } else if (person['mother_external_name'] != null && (person['mother_external_name'] as String).isNotEmpty) {
                                    try {
                                      selectedMotherMarriage = fatherWives.cast<Map<String, dynamic>?>().firstWhere(
                                        (w) => w?['wife_external_name'] == person['mother_external_name'],
                                        orElse: () => null,
                                      );
                                    } catch (_) {}
                                  }
                                });
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('لم يتم العثور على $qf'),
                                    backgroundColor: AppColors.accentRed),
                              );
                            }
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('لم يتم العثور على $qf'),
                                  backgroundColor: AppColors.accentRed),
                            );
                          }
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.search_rounded, color: AppColors.bgDeep, size: 22),
                        ),
                      ),
                    ],
                  ),
                  if (selectedFather != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accentGreen.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selectedFather!['name']} (${selectedFather!['legacy_user_id']}) — ج${selectedFather!['generation']}',
                              style: const TextStyle(fontSize: 13, color: AppColors.accentGreen),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModalState(() {
                              selectedFather = null;
                              fatherQfController.clear();
                              fatherWives = [];
                              selectedMotherMarriage = null;
                            }),
                            child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildLabel('الأم (من زوجات الأب)'),
                  const SizedBox(height: 4),
                  if (selectedFather == null && selectedFatherId == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'اختر الأب أولاً لعرض زوجاته',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7)),
                      ),
                    )
                  else if (fatherWives.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentAmber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accentAmber.withOpacity(0.2)),
                      ),
                      child: const Text(
                        '⚠️ لا توجد زوجات مسجلة لهذا الأب.\nأضف زوجة من تبويب الزواجات أولاً.',
                        style: TextStyle(fontSize: 12, color: AppColors.accentAmber),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: () {
                              if (selectedMotherMarriage == null) return null;
                              final i = fatherWives.indexWhere((m) => m['id'] == selectedMotherMarriage!['id']);
                              return i >= 0 ? i : null;
                            }(),
                          hint: const Text('اختر الأم', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          isExpanded: true,
                          dropdownColor: AppColors.bgCard,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          items: fatherWives.asMap().entries.map((entry) {
                            final m = entry.value;
                            final name = m['wife_name'] as String? ?? 'غير معروفة';
                            final isExt = m['is_external'] as bool? ?? false;
                            return DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text('$name${isExt ? " (خارجية)" : ""}'),
                            );
                          }).toList(),
                          onChanged: (index) {
                            if (index != null) {
                              setModalState(() => selectedMotherMarriage = fatherWives[index]);
                            }
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildLabel('الحالة:'),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setModalState(() => isAlive = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isAlive
                                ? AppColors.accentGreen.withOpacity(0.15)
                                : AppColors.bgDeep.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isAlive ? AppColors.accentGreen : Colors.white.withOpacity(0.06)),
                          ),
                          child: Text(
                            'حي',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isAlive ? AppColors.accentGreen : AppColors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setModalState(() => isAlive = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: !isAlive
                                ? AppColors.accentRed.withOpacity(0.15)
                                : AppColors.bgDeep.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: !isAlive ? AppColors.accentRed : Colors.white.withOpacity(0.06)),
                          ),
                          child: Text(
                            'متوفى',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: !isAlive ? AppColors.accentRed : AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('تاريخ الميلاد'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: birthDate ?? DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setModalState(() => birthDate = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Text(
                        birthDate != null
                            ? '${birthDate!.year}/${birthDate!.month}/${birthDate!.day}'
                            : 'اختر التاريخ',
                        style: TextStyle(
                            fontSize: 14,
                            color: birthDate != null ? AppColors.textPrimary : AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('مدينة الميلاد'),
                            const SizedBox(height: 4),
                            _buildTextField(birthCityController, 'المدينة'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('الدولة'),
                            const SizedBox(height: 4),
                            _buildTextField(birthCountryController, 'الدولة'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('مدينة الإقامة'),
                  const SizedBox(height: 4),
                  _buildTextField(residenceCityController, 'مدينة الإقامة'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('الوظيفة'),
                            const SizedBox(height: 4),
                            _buildTextField(jobController, 'الوظيفة'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('التعليم'),
                            const SizedBox(height: 4),
                            _buildTextField(educationController, 'التعليم'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('الحالة الاجتماعية'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: maritalStatus.isEmpty ? null : maritalStatus,
                        isExpanded: true,
                        dropdownColor: AppColors.bgCard,
                        hint: const Text('اختر الحالة', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'متزوج', child: Text('متزوج')),
                          DropdownMenuItem(value: 'أعزب', child: Text('أعزب')),
                          DropdownMenuItem(value: 'مطلق', child: Text('مطلق')),
                          DropdownMenuItem(value: 'أرمل', child: Text('أرمل/أرملة')),
                        ],
                        onChanged: (value) {
                          setModalState(() => maritalStatus = value ?? '');
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('رمز PIN'),
                  const SizedBox(height: 4),
                  _buildTextField(pinController, 'رمز الدخول (4 أرقام)'),
                  const SizedBox(height: 20),
                  Container(height: 1, color: Colors.white.withOpacity(0.06)),
                  const SizedBox(height: 16),
                  const Text('معلومات الاتصال',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gold)),
                  const SizedBox(height: 12),
                  _buildLabel('رقم الجوال'),
                  const SizedBox(height: 4),
                  _buildTextField(mobileController, '05xxxxxxxx'),
                  const SizedBox(height: 12),
                  _buildLabel('البريد الإلكتروني'),
                  const SizedBox(height: 4),
                  _buildTextField(emailController, 'email@example.com'),
                  const SizedBox(height: 12),
                  _buildLabel('الصورة الشخصية'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.bgDeep.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                          image: selectedImageBytes != null
                              ? DecorationImage(image: MemoryImage(selectedImageBytes!), fit: BoxFit.cover)
                              : (currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty)
                                  ? DecorationImage(image: NetworkImage(currentPhotoUrl!), fit: BoxFit.cover)
                                  : null,
                        ),
                        child: (selectedImageBytes == null && (currentPhotoUrl == null || currentPhotoUrl!.isEmpty))
                            ? const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 28)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 400,
                                  maxHeight: 400,
                                  imageQuality: 70,
                                );
                                if (picked != null) {
                                  final bytes = await picked.readAsBytes();
                                  if (bytes.length > 500 * 1024) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('الصورة كبيرة جداً. الحد الأقصى 500 كيلوبايت'), backgroundColor: AppColors.accentRed),
                                      );
                                    }
                                    return;
                                  }
                                  setModalState(() => selectedImageBytes = bytes);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.upload_rounded, color: AppColors.gold, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      selectedImageBytes != null ? 'تم اختيار صورة ✓' : 'اختر صورة',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الحد: 400×400 بكسل، 500KB',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('انستقرام'),
                          const SizedBox(height: 4),
                          _buildTextField(instagramController, '@username'),
                        ],
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('تويتر'),
                          const SizedBox(height: 4),
                          _buildTextField(twitterController, '@username'),
                        ],
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('سناب شات'),
                          const SizedBox(height: 4),
                          _buildTextField(snapchatController, '@username'),
                        ],
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('فيسبوك'),
                          const SizedBox(height: 4),
                          _buildTextField(facebookController, '@username'),
                        ],
                      )                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          _showError('الاسم مطلوب');
                          return;
                        }
                        Navigator.pop(context);
                        try {
                          final updateData = <String, dynamic>{
                            'name': nameController.text.trim(),
                            'gender': selectedGender,
                            'is_alive': isAlive,
                            'father_id': selectedFather?['id'],
                            'birth_city': birthCityController.text.trim().isEmpty
                                ? null
                                : birthCityController.text.trim(),
                            'birth_country': birthCountryController.text.trim().isEmpty
                                ? null
                                : birthCountryController.text.trim(),
                            'residence_city': residenceCityController.text.trim().isEmpty
                                ? null
                                : residenceCityController.text.trim(),
                            'job': jobController.text.trim().isEmpty ? null : jobController.text.trim(),
                            'education':
                                educationController.text.trim().isEmpty ? null : educationController.text.trim(),
                            'marital_status': maritalStatus.isEmpty ? null : maritalStatus,
                          };
                          // الأم — من زوجات الأب
                          if (selectedMotherMarriage != null) {
                            final wifeId = selectedMotherMarriage!['wife_id'] as String?;
                            if (wifeId != null) {
                              updateData['mother_id'] = wifeId;
                              updateData['mother_external_name'] = null;
                            } else {
                              updateData['mother_id'] = null;
                              updateData['mother_external_name'] = selectedMotherMarriage!['wife_external_name'] as String?;
                            }
                          } else {
                            updateData['mother_id'] = null;
                            updateData['mother_external_name'] = null;
                          }
                          if (birthDate != null) {
                            updateData['birth_date'] = birthDate!.toIso8601String().split('T')[0];
                          }
                          if (pinController.text.trim().isNotEmpty) {
                            updateData['pin_code'] = pinController.text.trim();
                          }
                          await SupabaseConfig.client
                              .from('people')
                              .update(updateData)
                              .eq('id', person['id']);

                          // رفع الصورة إذا تم اختيار صورة جديدة
                          String? photoUrl = currentPhotoUrl;
                          if (selectedImageBytes != null) {
                            try {
                              final personId = person['id'] as String;
                              final storagePath = 'profiles/profile_$personId.jpg';

                              await SupabaseConfig.client.storage
                                  .from('photos')
                                  .uploadBinary(
                                    storagePath,
                                    selectedImageBytes!,
                                    fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
                                  );

                              photoUrl = SupabaseConfig.client.storage
                                  .from('photos')
                                  .getPublicUrl(storagePath);
                            } catch (e) {
                              print('خطأ في رفع الصورة: $e');
                            }
                          }

                          final contactData = <String, dynamic>{
                            'person_id': person['id'],
                            'mobile_phone':
                                mobileController.text.trim().isEmpty ? null : mobileController.text.trim(),
                            'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                            'photo_url': photoUrl,
                            'instagram':
                                instagramController.text.trim().isEmpty ? null : instagramController.text.trim(),
                            'twitter':
                                twitterController.text.trim().isEmpty ? null : twitterController.text.trim(),
                            'snapchat':
                                snapchatController.text.trim().isEmpty ? null : snapchatController.text.trim(),
                            'facebook':
                                facebookController.text.trim().isEmpty ? null : facebookController.text.trim(),
                          };
                          await SupabaseConfig.client
                              .from('contact_info')
                              .upsert(contactData, onConflict: 'person_id');

                          _showSuccess('تم تعديل "${nameController.text.trim()}" بنجاح');
                          _loadPeople();
                        } catch (e) {
                          _showError('خطأ في التعديل: $e');
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('حفظ التعديلات',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddPersonDialog() {
    final nameController = TextEditingController();
    final birthCityController = TextEditingController();
    final birthCountryController = TextEditingController();
    final fatherQfController = TextEditingController();
    final mobileController = TextEditingController();
    final emailController = TextEditingController();
    final photoUrlController = TextEditingController();
    final instagramController = TextEditingController();
    final twitterController = TextEditingController();
    final snapchatController = TextEditingController();
    final facebookController = TextEditingController();
    String selectedGender = 'male';
    Map<String, dynamic>? selectedFather;
    List<Map<String, dynamic>> fatherWives = [];
    Map<String, dynamic>? selectedMotherMarriage;
    DateTime? birthDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: AppColors.accentGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('إضافة شخص جديد',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('الاسم *'),
                  const SizedBox(height: 4),
                  _buildTextField(nameController, 'الاسم الكامل'),
                  const SizedBox(height: 12),
                  _buildLabel('الجنس'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildGenderOption('ذكر', 'male', selectedGender, (val) => setModalState(() => selectedGender = val)),
                      const SizedBox(width: 8),
                      _buildGenderOption('أنثى', 'female', selectedGender, (val) => setModalState(() => selectedGender = val)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('الأب (أدخل رقم QF)'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(fatherQfController, 'مثال: QF03001'),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final qf = fatherQfController.text.trim().toUpperCase();
                          if (qf.isEmpty) {
                            setModalState(() => selectedFather = null);
                            return;
                          }
                          try {
                            final found = _allPeople.firstWhere(
                              (p) => (p['legacy_user_id'] as String? ?? '').toUpperCase() == qf,
                              orElse: () => <String, dynamic>{},
                            );
                            if (found.isNotEmpty) {
                              setModalState(() => selectedFather = found);
                              SupabaseConfig.client
                                  .from('marriages')
                                  .select('id, wife_id, wife_external_name, marriage_order, is_current')
                                  .eq('husband_id', found['id'])
                                  .order('marriage_order')
                                  .then((response) async {
                                final wives = <Map<String, dynamic>>[];
                                for (final m in response) {
                                  final marriage = Map<String, dynamic>.from(m);
                                  final wifeId = marriage['wife_id'] as String?;
                                  if (wifeId != null) {
                                    final wife = await SupabaseConfig.client
                                        .from('people')
                                        .select('name')
                                        .eq('id', wifeId)
                                        .maybeSingle();
                                    marriage['wife_name'] = wife?['name'] ?? 'غير معروفة';
                                    marriage['is_external'] = false;
                                  } else {
                                    marriage['wife_name'] = marriage['wife_external_name'] ?? 'غير معروفة';
                                    marriage['is_external'] = true;
                                  }
                                  wives.add(marriage);
                                }
                                setModalState(() {
                                  fatherWives = wives;
                                  selectedMotherMarriage = null;
                                });
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('لم يتم العثور على $qf'),
                                    backgroundColor: AppColors.accentRed),
                              );
                            }
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('لم يتم العثور على $qf'),
                                  backgroundColor: AppColors.accentRed),
                            );
                          }
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.search_rounded, color: AppColors.bgDeep, size: 22),
                        ),
                      ),
                    ],
                  ),
                  if (selectedFather != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'الجيل: ${(selectedFather!['generation'] as int? ?? 0) + 1}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.gold, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accentGreen.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selectedFather!['name']} (${selectedFather!['legacy_user_id']}) — ج${selectedFather!['generation']}',
                              style: const TextStyle(fontSize: 13, color: AppColors.accentGreen),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModalState(() {
                              selectedFather = null;
                              fatherQfController.clear();
                              fatherWives = [];
                              selectedMotherMarriage = null;
                            }),
                            child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildLabel('الأم (من زوجات الأب)'),
                  const SizedBox(height: 4),
                  if (selectedFather == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'اختر الأب أولاً لعرض زوجاته',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7)),
                      ),
                    )
                  else if (fatherWives.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentAmber.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accentAmber.withOpacity(0.2)),
                      ),
                      child: const Text(
                        '⚠️ لا توجد زوجات مسجلة لهذا الأب.\nأضف زوجة من تبويب الزواجات أولاً.',
                        style: TextStyle(fontSize: 12, color: AppColors.accentAmber),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedMotherMarriage != null
                              ? (() {
                                  final i = fatherWives.indexWhere((m) => m['id'] == selectedMotherMarriage!['id']);
                                  return i >= 0 ? i : null;
                                })()
                              : null,
                          hint: const Text('اختر الأم', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          isExpanded: true,
                          dropdownColor: AppColors.bgCard,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          items: fatherWives.asMap().entries.map((entry) {
                            final m = entry.value;
                            final name = m['wife_name'] as String? ?? 'غير معروفة';
                            final isExt = m['is_external'] as bool? ?? false;
                            return DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text('$name${isExt ? " (خارجية)" : ""}'),
                            );
                          }).toList(),
                          onChanged: (index) {
                            if (index != null) {
                              setModalState(() => selectedMotherMarriage = fatherWives[index]);
                            }
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildLabel('تاريخ الميلاد'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setModalState(() => birthDate = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Text(
                        birthDate != null
                            ? '${birthDate!.year}/${birthDate!.month}/${birthDate!.day}'
                            : 'اختر التاريخ',
                        style: TextStyle(
                            fontSize: 14,
                            color: birthDate != null ? AppColors.textPrimary : AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('مدينة الميلاد'),
                            const SizedBox(height: 4),
                            _buildTextField(birthCityController, 'المدينة'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('الدولة'),
                            const SizedBox(height: 4),
                            _buildTextField(birthCountryController, 'الدولة'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(height: 1, color: Colors.white.withOpacity(0.06)),
                  const SizedBox(height: 16),
                  const Text('معلومات الاتصال', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gold)),
                  const SizedBox(height: 12),
                  _buildLabel('رقم الجوال'),
                  const SizedBox(height: 4),
                  _buildTextField(mobileController, '05xxxxxxxx'),
                  const SizedBox(height: 12),
                  _buildLabel('البريد الإلكتروني'),
                  const SizedBox(height: 4),
                  _buildTextField(emailController, 'email@example.com'),
                  const SizedBox(height: 12),
                  _buildLabel('رابط الصورة'),
                  const SizedBox(height: 4),
                  _buildTextField(photoUrlController, 'https://...'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('انستقرام'),
                                const SizedBox(height: 4),
                                _buildTextField(instagramController, '@username'),
                              ])),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('تويتر'),
                                const SizedBox(height: 4),
                                _buildTextField(twitterController, '@username'),
                              ])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('سناب شات'),
                                const SizedBox(height: 4),
                                _buildTextField(snapchatController, '@username'),
                              ])),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('فيسبوك'),
                                const SizedBox(height: 4),
                                _buildTextField(facebookController, '@username'),
                              ])),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          _showError('الاسم مطلوب');
                          return;
                        }
                        Navigator.pop(context);
                        try {
                          final generation = selectedFather != null
                              ? ((selectedFather!['generation'] as int? ?? 0) + 1)
                              : 1;
                          final genStr = generation.toString().padLeft(2, '0');
                          final existing = _allPeople
                              .where((p) => (p['legacy_user_id'] as String? ?? '').startsWith('QF$genStr'))
                              .length;
                          final seq = (existing + 1).toString().padLeft(3, '0');
                          final qfId = 'QF$genStr$seq';

                          final insertData = <String, dynamic>{
                            'name': nameController.text.trim(),
                            'gender': selectedGender,
                            'generation': generation,
                            'legacy_user_id': qfId,
                            'is_alive': true,
                            'is_admin': false,
                            'is_vip': false,
                          };
                          insertData['father_id'] = selectedFather?['id'];
                          // الأم
                          if (selectedMotherMarriage != null) {
                            final wifeId = selectedMotherMarriage!['wife_id'] as String?;
                            if (wifeId != null) {
                              insertData['mother_id'] = wifeId;
                            } else {
                              insertData['mother_external_name'] = selectedMotherMarriage!['wife_external_name'] as String?;
                            }
                          }
                          if (birthDate != null) {
                            insertData['birth_date'] = birthDate!.toIso8601String().split('T')[0];
                          }
                          if (birthCityController.text.trim().isNotEmpty) {
                            insertData['birth_city'] = birthCityController.text.trim();
                          }
                          if (birthCountryController.text.trim().isNotEmpty) {
                            insertData['birth_country'] = birthCountryController.text.trim();
                          }
                          final result = await SupabaseConfig.client
                              .from('people')
                              .insert(insertData)
                              .select('id')
                              .single();
                          final newPersonId = result['id'] as String;
                          if (mobileController.text.trim().isNotEmpty ||
                              emailController.text.trim().isNotEmpty ||
                              photoUrlController.text.trim().isNotEmpty ||
                              instagramController.text.trim().isNotEmpty ||
                              twitterController.text.trim().isNotEmpty ||
                              snapchatController.text.trim().isNotEmpty ||
                              facebookController.text.trim().isNotEmpty) {
                            await SupabaseConfig.client.from('contact_info').insert({
                              'person_id': newPersonId,
                              'mobile_phone': mobileController.text.trim().isEmpty ? null : mobileController.text.trim(),
                              'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                              'photo_url': photoUrlController.text.trim().isEmpty ? null : photoUrlController.text.trim(),
                              'instagram': instagramController.text.trim().isEmpty ? null : instagramController.text.trim(),
                              'twitter': twitterController.text.trim().isEmpty ? null : twitterController.text.trim(),
                              'snapchat': snapchatController.text.trim().isEmpty ? null : snapchatController.text.trim(),
                              'facebook': facebookController.text.trim().isEmpty ? null : facebookController.text.trim(),
                            });
                          }
                          _showSuccess('تم إضافة "${nameController.text.trim()}" برقم $qfId');
                          _loadPeople();
                        } catch (e) {
                          _showError('خطأ في الإضافة: $e');
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('إضافة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMarriageDialog() {
    final husbandQfController = TextEditingController();
    final wifeQfController = TextEditingController();
    Map<String, dynamic>? selectedHusband;
    Map<String, dynamic>? selectedWife;
    bool isExternalWife = false;
    final externalNameController = TextEditingController();
    int marriageOrder = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E8C).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.favorite_rounded, color: Color(0xFFE91E8C), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('إضافة زواج',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('الزوج (أدخل رقم QF) *'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(husbandQfController, 'مثال: QF03001')),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final qf = husbandQfController.text.trim().toUpperCase();
                          if (qf.isEmpty) {
                            setModalState(() {
                              selectedHusband = null;
                              marriageOrder = 1;
                            });
                            return;
                          }
                          try {
                            final found = _allPeople.firstWhere(
                              (p) => (p['legacy_user_id'] as String? ?? '').toUpperCase() == qf && p['gender'] == 'male',
                              orElse: () => <String, dynamic>{},
                            );
                            if (found.isNotEmpty) {
                              setModalState(() {
                                selectedHusband = found;
                                // حساب رقم الزواج تلقائياً
                                final existingMarriages = _allMarriages
                                    .where((m) => m['husband_id'] == found['id'])
                                    .length;
                                marriageOrder = existingMarriages + 1;
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('لم يتم العثور على ذكر بـ $qf'),
                                    backgroundColor: AppColors.accentRed),
                              );
                            }
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('لم يتم العثور على $qf'),
                                  backgroundColor: AppColors.accentRed),
                            );
                          }
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.search_rounded, color: AppColors.bgDeep, size: 22),
                        ),
                      ),
                    ],
                  ),
                  if (selectedHusband != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accentGreen.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selectedHusband!['name']} (${selectedHusband!['legacy_user_id']}) — ج${selectedHusband!['generation']}',
                              style: const TextStyle(fontSize: 13, color: AppColors.accentGreen),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModalState(() {
                              selectedHusband = null;
                              husbandQfController.clear();
                            }),
                            child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildLabel('الزوجة *'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => isExternalWife = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isExternalWife
                                  ? AppColors.gold.withOpacity(0.15)
                                  : AppColors.bgDeep.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: !isExternalWife ? AppColors.gold : Colors.white.withOpacity(0.06)),
                            ),
                            child: Center(
                              child: Text(
                                'من العائلة',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: !isExternalWife ? AppColors.gold : AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => isExternalWife = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isExternalWife
                                  ? AppColors.gold.withOpacity(0.15)
                                  : AppColors.bgDeep.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: isExternalWife ? AppColors.gold : Colors.white.withOpacity(0.06)),
                            ),
                            child: Center(
                              child: Text(
                                'خارجية',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isExternalWife ? AppColors.gold : AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (!isExternalWife) ...[
                    Row(
                      children: [
                        Expanded(child: _buildTextField(wifeQfController, 'أدخل رقم QF للزوجة')),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final qf = wifeQfController.text.trim().toUpperCase();
                            if (qf.isEmpty) {
                              setModalState(() => selectedWife = null);
                              return;
                            }
                            try {
                              final found = _allPeople.firstWhere(
                                (p) => (p['legacy_user_id'] as String? ?? '').toUpperCase() == qf && p['gender'] == 'female',
                                orElse: () => <String, dynamic>{},
                              );
                              if (found.isNotEmpty) {
                                setModalState(() => selectedWife = found);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('لم يتم العثور على أنثى بـ $qf'), backgroundColor: AppColors.accentRed),
                                );
                              }
                            } catch (_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('لم يتم العثور على $qf'), backgroundColor: AppColors.accentRed),
                              );
                            }
                          },
                          child: Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.search_rounded, color: AppColors.bgDeep, size: 22),
                          ),
                        ),
                      ],
                    ),
                    if (selectedWife != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accentGreen.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${selectedWife!['name']} (${selectedWife!['legacy_user_id']}) — ج${selectedWife!['generation']}',
                                style: const TextStyle(fontSize: 13, color: AppColors.accentGreen),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setModalState(() {
                                selectedWife = null;
                                wifeQfController.clear();
                              }),
                              child: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else
                    _buildTextField(externalNameController, 'اسم الزوجة'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildLabel('رقم الزواج:'),
                        const SizedBox(width: 8),
                        Text('$marriageOrder', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        if (selectedHusband == null) {
                          _showError('ابحث عن الزوج برقم QF واختره');
                          return;
                        }
                        if (!isExternalWife && selectedWife == null) {
                          _showError('اختر الزوجة');
                          return;
                        }
                        if (isExternalWife && externalNameController.text.trim().isEmpty) {
                          _showError('اكتب اسم الزوجة');
                          return;
                        }
                        Navigator.pop(context);
                        try {
                          final husbandId = selectedHusband!['id'] as String;
                          final insertData = <String, dynamic>{
                            'husband_id': husbandId,
                            'marriage_order': marriageOrder,
                            'is_current': true,
                          };
                          if (!isExternalWife) {
                            insertData['wife_id'] = selectedWife!['id'];
                          } else {
                            insertData['wife_external_name'] = externalNameController.text.trim();
                          }
                          await SupabaseConfig.client.from('marriages').insert(insertData);
                          _showSuccess('تم إضافة الزواج بنجاح');
                          _loadMarriages();
                        } catch (e) {
                          _showError('خطأ: $e');
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('إضافة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteMarriage(Map<String, dynamic> marriage) async {
    final marriageId = marriage['id'] as String;
    final husbandName = marriage['husband_name'] as String? ?? '—';
    final wifeName = marriage['wife_name'] as String? ?? '—';
    final isExternal = marriage['is_external'] as bool? ?? false;
    final wifeId = marriage['wife_id'] as String?;
    final husbandId = marriage['husband_id'] as String?;
    final wifeExternalName = marriage['wife_external_name'] as String?;

    // التحقق من وجود أبناء مرتبطين بهذا الزواج
    int childrenCount = 0;

    if (husbandId != null) {
      final allChildren = _allPeople.where((p) => p['father_id'] == husbandId).toList();
      for (final child in allChildren) {
        if (!isExternal && wifeId != null && child['mother_id'] == wifeId) {
          childrenCount++;
        } else if (isExternal && wifeExternalName != null && child['mother_external_name'] == wifeExternalName) {
          childrenCount++;
        }
      }
    }

    if (childrenCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: Row(
              children: [
                const Icon(Icons.block_rounded, color: AppColors.accentRed, size: 22),
                const SizedBox(width: 8),
                const Text('لا يمكن الحذف', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'زواج "$husbandName" و "$wifeName" مرتبط بـ:',
                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
                  ),
                  child: Text(
                    '👨‍👩‍👦 $childrenCount ابن/بنت',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'لحذف هذا الزواج، يجب أولاً حذف أو نقل الأبناء المرتبطين من تبويب الأشخاص.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('فهمت', style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // لا يوجد أبناء — يسمح بالحذف
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('تأكيد الحذف', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'هل أنت متأكد من حذف زواج "$husbandName" و "$wifeName"؟',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseConfig.client.from('marriages').delete().eq('id', marriageId);
      _showSuccess('تم حذف الزواج بنجاح');
      _loadMarriages();
    } catch (e) {
      _showError('خطأ في الحذف: $e');
    }
  }

  void _showAddNewsDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedCategory = 'general';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.newspaper_rounded, color: AppColors.gold, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('إضافة خبر',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('العنوان *'),
                  const SizedBox(height: 4),
                  _buildTextField(titleController, 'عنوان الخبر'),
                  const SizedBox(height: 12),
                  _buildLabel('المحتوى *'),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: TextField(
                      controller: bodyController,
                      maxLines: 5,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'محتوى الخبر...',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        contentPadding: EdgeInsets.all(14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('التصنيف'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: ['general', 'event', 'announcement', 'condolence'].map((cat) {
                      const labels = {
                        'general': 'عام',
                        'event': 'مناسبة',
                        'announcement': 'إعلان',
                        'condolence': 'تعزية',
                      };
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedCategory = cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selectedCategory == cat
                                ? AppColors.gold.withOpacity(0.15)
                                : AppColors.bgDeep.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: selectedCategory == cat ? AppColors.gold : Colors.white.withOpacity(0.06)),
                          ),
                          child: Text(
                            labels[cat]!,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selectedCategory == cat ? AppColors.gold : AppColors.textSecondary),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty || bodyController.text.trim().isEmpty) {
                          _showError('العنوان والمحتوى مطلوبين');
                          return;
                        }
                        Navigator.pop(context);
                        try {
                          await SupabaseConfig.client.from('news').insert({
                            'title': titleController.text.trim(),
                            'body': bodyController.text.trim(),
                            'category': selectedCategory,
                          });
                          _showSuccess('تم إضافة الخبر');
                          _loadNews();
                        } catch (e) {
                          _showError('خطأ: $e');
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('نشر الخبر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNews(Map<String, dynamic> news) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('حذف الخبر؟', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('حذف "${news['title']}"؟', style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف', style: TextStyle(color: AppColors.accentRed))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseConfig.client.from('news').delete().eq('id', news['id']);
      _showSuccess('تم حذف الخبر');
      _loadNews();
    } catch (e) {
      _showError('خطأ: $e');
    }
  }

  void _showSendNotificationDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: AppColors.gold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('إرسال إشعار',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel('العنوان *'),
                const SizedBox(height: 4),
                _buildTextField(titleController, 'عنوان الإشعار'),
                const SizedBox(height: 12),
                _buildLabel('المحتوى *'),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: TextField(
                    controller: bodyController,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'نص الإشعار...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      contentPadding: EdgeInsets.all(14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty || bodyController.text.trim().isEmpty) {
                        _showError('العنوان والمحتوى مطلوبين');
                        return;
                      }
                      Navigator.pop(context);
                      try {
                        await SupabaseConfig.client.from('notifications').insert({
                          'title': titleController.text.trim(),
                          'body': bodyController.text.trim(),
                          'type': 'admin_message',
                        });
                        _showSuccess('تم إرسال الإشعار');
                        _loadNotifications();
                      } catch (e) {
                        _showError('خطأ: $e');
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgDeep,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('إرسال', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAdmin(Map<String, dynamic> person) async {
    final isCurrentlyAdmin = person['is_admin'] == true;
    final action = isCurrentlyAdmin ? 'إزالة صلاحية المدير من' : 'تعيين مدير';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text(action, style: const TextStyle(color: AppColors.textPrimary)),
          content: Text(
            '${isCurrentlyAdmin ? 'إزالة صلاحية المدير من' : 'تعيين'} "${person['name']}" ${isCurrentlyAdmin ? '؟' : 'كمدير؟'}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('تأكيد',
                    style: TextStyle(
                        color: isCurrentlyAdmin ? AppColors.accentRed : AppColors.accentGreen))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseConfig.client
          .from('people')
          .update({'is_admin': !isCurrentlyAdmin})
          .eq('id', person['id']);
      _showSuccess(isCurrentlyAdmin ? 'تم إزالة صلاحية المدير' : 'تم تعيين "${person['name']}" كمدير');
      _loadPeople();
    } catch (e) {
      _showError('خطأ: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $msg'), backgroundColor: AppColors.accentRed),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ $msg'), backgroundColor: AppColors.accentGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.textPrimary,
          title: const Text('لوحة التحكم', style: TextStyle(fontWeight: FontWeight.w700)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'الأشخاص', icon: Icon(Icons.people_rounded, size: 18)),
              Tab(text: 'الزواجات', icon: Icon(Icons.favorite_rounded, size: 18)),
              Tab(text: 'أبناء البنات', icon: Icon(Icons.child_care_rounded, size: 18)),
              Tab(text: 'الأخبار', icon: Icon(Icons.newspaper_rounded, size: 18)),
              Tab(text: 'الصلاحيات', icon: Icon(Icons.admin_panel_settings_rounded, size: 18)),
              Tab(text: 'الطلبات'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPeopleTab(),
            _buildMarriagesTab(),
            _buildGirlsChildrenTab(),
            _buildNewsTab(),
            _buildUsersTab(),
            _buildSupportRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeopleTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterPeople,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'بحث بالاسم أو QF...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showAddPersonDialog,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.bgDeep, size: 24),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${_filteredPeople.length} شخص',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadPeople,
                child: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoadingPeople
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredPeople.length,
                  itemBuilder: (context, index) {
                    final person = _filteredPeople[index];
                    final gender = person['gender'] as String? ?? 'male';
                    final gen = person['generation'] as int? ?? 0;
                    final isAlive = person['is_alive'] as bool? ?? true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: (gender == 'male' ? Colors.blue : Colors.pink).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              gender == 'male' ? Icons.male_rounded : Icons.female_rounded,
                              color: gender == 'male' ? Colors.blue : Colors.pink,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person['name'] as String? ?? '—',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isAlive ? AppColors.textPrimary : AppColors.textSecondary,
                                    decoration: !isAlive ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${person['legacy_user_id'] ?? '—'} • ج$gen${!isAlive ? ' • متوفى' : ''}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary.withOpacity(0.7)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showEditPersonDialog(person),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            color: AppColors.gold,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                          IconButton(
                            onPressed: () => _deletePerson(person),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            color: AppColors.accentRed,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMarriagesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _marriagesSearchController,
                    onChanged: _filterMarriages,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'بحث باسم أو رقم QF للزوج أو الزوجة...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (_allPeople.isEmpty) _loadPeople();
                  _showAddMarriageDialog();
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.bgDeep, size: 24),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${_filteredMarriages.length} زواج',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadMarriages,
                child: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoadingMarriages
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredMarriages.length,
                  itemBuilder: (context, index) {
                    final m = _filteredMarriages[index];
                    final isExternal = m['is_external'] as bool? ?? false;
                    final isCurrent = m['is_current'] as bool? ?? true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isCurrent
                                ? const Color(0xFFE91E8C).withOpacity(0.15)
                                : Colors.white.withOpacity(0.04)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E8C).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${m['marriage_order'] ?? ''}',
                                style: const TextStyle(
                                    color: Color(0xFFE91E8C),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${m['husband_name']} ♥ ${m['wife_name']}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      isCurrent ? '💍 حالية' : '📝 سابقة',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    if (isExternal) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentAmber.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('خارجية',
                                            style: TextStyle(fontSize: 9, color: AppColors.accentAmber)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showEditMarriageDialog(m),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            color: AppColors.gold,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                          IconButton(
                            onPressed: () => _deleteMarriage(m),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            color: AppColors.accentRed,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showEditMarriageDialog(Map<String, dynamic> marriage) {
    final isExternal = marriage['is_external'] as bool? ?? false;
    final marriageOrderController = TextEditingController(text: '${marriage['marriage_order'] ?? 1}');
    bool isCurrent = marriage['is_current'] as bool? ?? true;
    bool isExternalWife = isExternal;
    final externalNameController = TextEditingController(text: marriage['wife_external_name'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('تعديل الزواج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Text('الزوج: ${marriage['husband_name'] ?? '—'}', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('الزوجة: ${marriage['wife_name'] ?? '—'}', style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              _buildLabel('رقم الزواج'),
              _buildTextField(marriageOrderController, 'رقم الزواج (1، 2، 3...)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildLabel('حالة الزواج'),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setModalState(() => isCurrent = !isCurrent),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.accentGreen.withOpacity(0.1) : AppColors.accentRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isCurrent ? AppColors.accentGreen.withOpacity(0.3) : AppColors.accentRed.withOpacity(0.3)),
                      ),
                      child: Text(
                        isCurrent ? '💍 حالية' : '📝 سابقة',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isCurrent ? AppColors.accentGreen : AppColors.accentRed),
                      ),
                    ),
                  ),
                ],
              ),
              if (isExternalWife) ...[
                const SizedBox(height: 12),
                _buildLabel('اسم الزوجة الخارجية'),
                _buildTextField(externalNameController, 'اسم الزوجة'),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      final updateData = <String, dynamic>{
                        'marriage_order': int.tryParse(marriageOrderController.text.trim()) ?? 1,
                        'is_current': isCurrent,
                      };
                      if (isExternalWife && externalNameController.text.trim().isNotEmpty) {
                        updateData['wife_external_name'] = externalNameController.text.trim();
                      }
                      await SupabaseConfig.client.from('marriages').update(updateData).eq('id', marriage['id']);
                      Navigator.pop(context);
                      _showSuccess('تم تعديل الزواج بنجاح');
                      _loadMarriages();
                    } catch (e) {
                      _showError('خطأ: $e');
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgDeep),
                  child: const Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGirlsChildrenTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    controller: _girlsChildrenSearchController,
                    onChanged: _filterGirlsChildren,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'بحث باسم الطفل أو الأم أو الأب أو رقم QF...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (_allPeople.isEmpty) _loadPeople();
                  _showAddGirlChildFromTab();
                },
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add_rounded, color: AppColors.bgDeep, size: 24),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('${_filteredGirlsChildren.length} طفل/طفلة', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              GestureDetector(onTap: _loadGirlsChildren, child: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoadingGirlsChildren
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : _filteredGirlsChildren.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.child_care_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text('لا يوجد أبناء بنات مسجلين', style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredGirlsChildren.length,
                      itemBuilder: (context, index) {
                        final child = _filteredGirlsChildren[index];
                        final gender = child['child_gender'] as String? ?? 'male';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: (gender == 'male' ? Colors.blue : Colors.pink).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  gender == 'male' ? Icons.male_rounded : Icons.female_rounded,
                                  color: gender == 'male' ? Colors.blue : Colors.pink,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(child['child_name'] as String? ?? '—', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'الأم: ${child['mother_name'] ?? '—'} • الأب: ${child['father_name'] ?? '—'}',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.7)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (child['child_birthdate'] != null)
                                      Text('📅 ${child['child_birthdate']}', style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withOpacity(0.5))),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showEditGirlChildDialog(child),
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                color: AppColors.gold,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                              IconButton(
                                onPressed: () => _deleteGirlChild(child),
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                color: AppColors.accentRed,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildNewsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const TabBar(
              indicatorColor: AppColors.gold,
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'الأخبار'),
                Tab(text: 'الإشعارات'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            '${_allNews.length} خبر',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showAddNewsDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Row(
                                children: [
                                  Icon(Icons.add_rounded, color: AppColors.bgDeep, size: 18),
                                  SizedBox(width: 4),
                                  Text('إضافة خبر',
                                      style: TextStyle(
                                          color: AppColors.bgDeep,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isLoadingNews
                          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _allNews.length,
                              itemBuilder: (context, index) {
                                final news = _allNews[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgCard,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              news['title'] as String? ?? '—',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              news['body'] as String? ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary.withOpacity(0.7)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteNews(news),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                        color: AppColors.accentRed,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            '${_allNotifications.length} إشعار',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showSendNotificationDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Row(
                                children: [
                                  Icon(Icons.add_rounded, color: AppColors.bgDeep, size: 18),
                                  SizedBox(width: 4),
                                  Text('إرسال إشعار',
                                      style: TextStyle(
                                          color: AppColors.bgDeep,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isLoadingNotifications
                          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _allNotifications.length,
                              itemBuilder: (context, index) {
                                final notif = _allNotifications[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgCard,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notif['title'] as String? ?? '—',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        notif['body'] as String? ?? '',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary.withOpacity(0.7)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'المدير يقدر يعدّل ويضيف ويحذف كل البيانات. الشخص العادي يعدّل بياناته فقط ويضيف أبناءه.',
                    style: TextStyle(fontSize: 12, color: AppColors.gold.withOpacity(0.9)),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _usersSearchController,
              onChanged: _filterUsers,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'بحث باسم أو رقم QF...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingPeople
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final person = _filteredUsers[index];
                    final isAdmin = person['is_admin'] == true;
                    final hasPin = (person['pin_code'] as String? ?? '').isNotEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isAdmin
                                ? AppColors.gold.withOpacity(0.2)
                                : Colors.white.withOpacity(0.04)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? AppColors.gold.withOpacity(0.12)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                              color: isAdmin ? AppColors.gold : AppColors.textSecondary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person['name'] as String? ?? '—',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      person['legacy_user_id'] as String? ?? '—',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary.withOpacity(0.7)),
                                    ),
                                    if (hasPin) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentGreen.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('فعّال',
                                            style: TextStyle(fontSize: 9, color: AppColors.accentGreen)),
                                      ),
                                    ],
                                    if (isAdmin) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.gold.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('مدير',
                                            style: TextStyle(fontSize: 9, color: AppColors.gold)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _toggleAdmin(person),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? AppColors.accentRed.withOpacity(0.1)
                                    : AppColors.accentGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: isAdmin
                                        ? AppColors.accentRed.withOpacity(0.3)
                                        : AppColors.accentGreen.withOpacity(0.3)),
                              ),
                              child: Text(
                                isAdmin ? 'إزالة' : 'تعيين مدير',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isAdmin ? AppColors.accentRed : AppColors.accentGreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _loadSupportRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final response = await SupabaseConfig.client
          .from('support_requests')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _allRequests = List<Map<String, dynamic>>.from(response);
        _isLoadingRequests = false;
      });
    } catch (e) {
      setState(() => _isLoadingRequests = false);
      _showError('خطأ في تحميل الطلبات: $e');
    }
  }

  Widget _buildSupportRequestsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('${_allRequests.length} طلب', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              GestureDetector(onTap: _loadSupportRequests, child: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20)),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingRequests
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : _allRequests.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.inbox_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text('لا توجد طلبات', style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7))),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _allRequests.length,
                      itemBuilder: (context, index) {
                        final req = _allRequests[index];
                        final status = req['status'] as String? ?? 'جديد';
                        final statusColor = status == 'جديد' ? AppColors.accentAmber
                            : status == 'قيد المراجعة' ? AppColors.accentBlue
                            : status == 'تم الرد' ? AppColors.accentGreen
                            : AppColors.textSecondary;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.15))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor))),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                                child: Text(req['request_type'] as String? ?? '', style: const TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w600))),
                              const Spacer(),
                              Text(req['sender_name'] as String? ?? 'مجهول', style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.7))),
                            ]),
                            const SizedBox(height: 8),
                            Text(req['subject'] as String? ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Text(req['message'] as String? ?? '', style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7)), maxLines: 3, overflow: TextOverflow.ellipsis),
                            if (req['admin_reply'] != null && (req['admin_reply'] as String).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                                child: Text('الرد: ${req['admin_reply']}', style: TextStyle(fontSize: 12, color: AppColors.accentGreen.withOpacity(0.8)))),
                            ],
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: GestureDetector(onTap: () => _showReplyDialog(req),
                                child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                  child: const Center(child: Text('رد', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: 12)))))),
                              const SizedBox(width: 8),
                              Expanded(child: GestureDetector(onTap: () => _changeRequestStatus(req),
                                child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: AppColors.accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                  child: const Center(child: Text('تغيير الحالة', style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.w600, fontSize: 12)))))),
                            ]),
                          ]),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _showReplyDialog(Map<String, dynamic> req) async {
    final id = req['id'] as String?;
    if (id == null) return;
    final replyController = TextEditingController(text: req['admin_reply'] as String? ?? '');
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('رد على الطلب', style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: replyController,
          maxLines: 4,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'اكتب ردك...',
            hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.6)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgDeep),
            onPressed: () async {
              final reply = replyController.text.trim();
              Navigator.pop(context);
              try {
                await SupabaseConfig.client.from('support_requests').update({'admin_reply': reply, 'status': 'تم الرد'}).eq('id', id);
                _loadSupportRequests();
              } catch (e) {
                _showError('خطأ في حفظ الرد: $e');
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    replyController.dispose();
  }

  void _changeRequestStatus(Map<String, dynamic> request) {
    final statuses = ['جديد', 'قيد المراجعة', 'تم الرد', 'مغلق'];
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('تغيير الحالة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...statuses.map((s) => ListTile(
            title: Text(s, style: TextStyle(color: s == request['status'] ? AppColors.gold : AppColors.textPrimary)),
            leading: Icon(Icons.circle, size: 12, color: s == request['status'] ? AppColors.gold : AppColors.textSecondary.withOpacity(0.3)),
            onTap: () async {
              try {
                await SupabaseConfig.client.from('support_requests').update({'status': s, 'updated_at': DateTime.now().toIso8601String()}).eq('id', request['id']);
                Navigator.pop(context);
                _showSuccess('تم تغيير الحالة');
                _loadSupportRequests();
              } catch (e) { _showError('خطأ: $e'); }
            },
          )),
        ]),
      ),
    );
  }
}
