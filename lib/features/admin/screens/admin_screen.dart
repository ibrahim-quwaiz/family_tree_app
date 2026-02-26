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
  bool _isLoadingPeople = true;

  List<Map<String, dynamic>> _allMarriages = [];
  bool _isLoadingMarriages = true;

  List<Map<String, dynamic>> _allGirlsChildren = [];
  List<Map<String, dynamic>> _filteredGirlsChildren = [];
  bool _isLoadingGirlsChildren = true;
  final _girlsChildrenSearchController = TextEditingController();

  List<Map<String, dynamic>> _allNews = [];
  bool _isLoadingNews = true;

  List<Map<String, dynamic>> _allNotifications = [];
  bool _isLoadingNotifications = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
    _girlsChildrenSearchController.dispose();
    super.dispose();
  }

  void _loadTabData(int index) {
    switch (index) {
      case 0: if (_allPeople.isEmpty) _loadPeople(); break;
      case 1: if (_allMarriages.isEmpty) { if (_allPeople.isEmpty) _loadPeople(); _loadMarriages(); } break;
      case 2: if (_allGirlsChildren.isEmpty) { if (_allPeople.isEmpty) _loadPeople(); _loadGirlsChildren(); } break;
      case 3: if (_allNews.isEmpty) _loadNews(); _loadNotifications(); break;
      case 4: if (_allPeople.isEmpty) _loadPeople(); break;
    }
  }

  Future<void> _loadPeople() async {
    setState(() => _isLoadingPeople = true);
    try {
      final response = await SupabaseConfig.client
          .from('people')
          .select('id, legacy_user_id, name, gender, generation, is_alive, father_id, mother_id, mother_external_name, birth_date, death_date, birth_city, birth_country, residence_city, job, education, is_admin, pin_code, sort_order')
          .order('generation')
          .order('name');

      setState(() {
        _allPeople = List<Map<String, dynamic>>.from(response);
        _filteredPeople = _allPeople;
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
          .select('id, husband_id, wife_id, wife_external_name, marriage_order, marriage_date, is_current')
          .order('marriage_order');

      final marriagesWithNames = <Map<String, dynamic>>[];
      for (final m in response) {
        final marriage = Map<String, dynamic>.from(m);

        final husbandId = marriage['husband_id'] as String?;
        if (husbandId != null) {
          try {
            final husband = _allPeople.firstWhere((p) => p['id'] == husbandId);
            marriage['husband_name'] = husband['name'];
          } catch (_) {
            marriage['husband_name'] = 'غير معروف';
          }
        }

        final wifeId = marriage['wife_id'] as String?;
        if (wifeId != null) {
          try {
            final wife = _allPeople.firstWhere((p) => p['id'] == wifeId);
            marriage['wife_name'] = wife['name'];
            marriage['is_external'] = false;
          } catch (_) {
            marriage['wife_name'] = 'غير معروفة';
            marriage['is_external'] = false;
          }
        } else {
          marriage['wife_name'] = marriage['wife_external_name'] ?? 'غير معروفة';
          marriage['is_external'] = true;
        }

        marriagesWithNames.add(marriage);
      }

      setState(() {
        _allMarriages = marriagesWithNames;
        _isLoadingMarriages = false;
      });
    } catch (e) {
      setState(() => _isLoadingMarriages = false);
      _showError('خطأ في تحميل الزواجات: $e');
    }
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
          child['mother_qf'] = mother.isNotEmpty ? mother['legacy_user_id'] : '';
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
        _filteredGirlsChildren = _allGirlsChildren;
      } else {
        final q = query.toLowerCase();
        _filteredGirlsChildren = _allGirlsChildren.where((c) {
          final childName = (c['child_name'] as String? ?? '').toLowerCase();
          final motherName = (c['mother_name'] as String? ?? '').toLowerCase();
          final fatherName = (c['father_name'] as String? ?? '').toLowerCase();
          return childName.contains(q) || motherName.contains(q) || fatherName.contains(q);
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
                        onTap: () {
                          final qf = motherQfController.text.trim().toUpperCase();
                          if (qf.isEmpty) return;
                          final found = _allPeople.firstWhere(
                            (p) => (p['legacy_user_id'] as String? ?? '').toUpperCase() == qf && p['gender'] == 'female',
                            orElse: () => <String, dynamic>{},
                          );
                          if (found.isNotEmpty) {
                            setModalState(() => selectedMother = found);
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

                  _buildLabel('اسم أبو الطفل (زوج البنت) *'),
                  const SizedBox(height: 4),
                  _buildTextField(fatherNameController, 'اسم الزوج'),
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

                  _buildLabel('اسم الأب'),
                  const SizedBox(height: 4),
                  _buildTextField(fatherNameController, 'اسم أبو الطفل'),
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

  Future<void> _deletePerson(Map<String, dynamic> person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('تأكيد الحذف', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'هل أنت متأكد من حذف "${person['name']}"؟\nهذا الإجراء لا يمكن التراجع عنه.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: AppColors.accentRed)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseConfig.client.from('people').delete().eq('id', person['id']);
      _showSuccess('تم حذف "${person['name']}" بنجاح');
      _loadPeople();
    } catch (e) {
      _showError('خطأ في الحذف: $e');
    }
  }

  void _showAddGirlChildDialog(
    String motherId,
    String fatherName,
    StateSetter parentSetState,
    List<Map<String, dynamic>> girlChildren,
  ) {
    final childNameController = TextEditingController();
    final fatherNameController = TextEditingController(text: fatherName);
    String childGender = 'male';
    DateTime? childBirthdate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: const Text('إضافة ابن/بنت',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('اسم الطفل *'),
                  const SizedBox(height: 4),
                  _buildTextField(childNameController, 'الاسم'),
                  const SizedBox(height: 12),
                  _buildLabel('اسم الأب'),
                  const SizedBox(height: 4),
                  _buildTextField(fatherNameController, 'اسم أب الطفل'),
                  const SizedBox(height: 12),
                  _buildLabel('الجنس'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildGenderOption('ذكر', 'male', childGender,
                          (val) => setDialogState(() => childGender = val)),
                      const SizedBox(width: 8),
                      _buildGenderOption('أنثى', 'female', childGender,
                          (val) => setDialogState(() => childGender = val)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLabel('تاريخ الميلاد'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime(2010),
                        firstDate: DateTime(1970),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => childBirthdate = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Text(
                        childBirthdate != null
                            ? '${childBirthdate!.year}/${childBirthdate!.month}/${childBirthdate!.day}'
                            : 'اختر',
                        style: TextStyle(
                            fontSize: 14,
                            color: childBirthdate != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () async {
                  if (childNameController.text.trim().isEmpty) {
                    _showError('اسم الطفل مطلوب');
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final insertData = <String, dynamic>{
                      'mother_id': motherId,
                      'father_name': fatherNameController.text.trim(),
                      'child_name': childNameController.text.trim(),
                      'child_gender': childGender,
                    };
                    if (childBirthdate != null) {
                      insertData['child_birthdate'] =
                          childBirthdate!.toIso8601String().split('T')[0];
                    }
                    final result = await SupabaseConfig.client
                        .from('girls_children')
                        .insert(insertData)
                        .select()
                        .single();
                    girlChildren.add(result);
                    parentSetState(() {});
                    _showSuccess('تم إضافة ${childNameController.text.trim()}');
                  } catch (e) {
                    _showError('خطأ: $e');
                  }
                },
                child: const Text('إضافة',
                    style: TextStyle(
                        color: AppColors.gold, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
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
    final husbandNameController = TextEditingController();
    final husbandQfSearchController = TextEditingController();
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
    bool isMarried = false;
    bool isHusbandExternal = true;
    Map<String, dynamic>? selectedHusbandPerson;
    Map<String, dynamic>? existingGirlMarriage;
    List<Map<String, dynamic>> girlChildren = [];

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
                        if (person['gender'] == 'female') {
                          SupabaseConfig.client
                              .from('marriages')
                              .select('id, husband_id, wife_external_name, marriage_order, is_current')
                              .eq('wife_id', person['id'])
                              .maybeSingle()
                              .then((marriage) {
                                if (marriage != null) {
                                  isMarried = true;
                                  existingGirlMarriage = marriage;
                                  final husbandId = marriage['husband_id'] as String?;
                                  if (husbandId != null) {
                                    isHusbandExternal = false;
                                    try {
                                      final husband = _allPeople.firstWhere(
                                        (p) => p['id'] == husbandId,
                                        orElse: () => <String, dynamic>{},
                                      );
                                      if (husband.isNotEmpty) {
                                        selectedHusbandPerson = husband;
                                        husbandQfSearchController.text =
                                            husband['legacy_user_id'] as String? ?? '';
                                      }
                                    } catch (_) {}
                                  }
                                }
                                setModalState(() {});
                              });
                          SupabaseConfig.client
                              .from('girls_children')
                              .select()
                              .eq('mother_id', person['id'])
                              .order('child_birthdate')
                              .then((children) {
                                girlChildren = List<Map<String, dynamic>>.from(children);
                                setModalState(() {});
                              });
                        }
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
                  if (person['gender'] == 'female') ...[
                    const SizedBox(height: 20),
                    Container(height: 1, color: Colors.white.withOpacity(0.06)),
                    const SizedBox(height: 16),
                    const Text('الزواج والأبناء',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE91E8C))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildLabel('الحالة:'),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setModalState(() => isMarried = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMarried
                                  ? const Color(0xFFE91E8C).withOpacity(0.15)
                                  : AppColors.bgDeep.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: isMarried
                                      ? const Color(0xFFE91E8C)
                                      : Colors.white.withOpacity(0.06)),
                            ),
                            child: Text(
                              'متزوجة',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isMarried
                                      ? const Color(0xFFE91E8C)
                                      : AppColors.textSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setModalState(() => isMarried = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: !isMarried
                                  ? AppColors.textSecondary.withOpacity(0.15)
                                  : AppColors.bgDeep.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: !isMarried
                                      ? AppColors.textSecondary
                                      : Colors.white.withOpacity(0.06)),
                            ),
                            child: Text(
                              'غير متزوجة',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: !isMarried
                                      ? AppColors.textSecondary
                                      : AppColors.textSecondary.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isMarried) ...[
                      const SizedBox(height: 12),
                      _buildLabel('الزوج'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => isHusbandExternal = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isHusbandExternal
                                      ? AppColors.gold.withOpacity(0.15)
                                      : AppColors.bgDeep.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: !isHusbandExternal
                                          ? AppColors.gold
                                          : Colors.white.withOpacity(0.06)),
                                ),
                                child: Center(
                                    child: Text(
                                        'من العائلة',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: !isHusbandExternal
                                                ? AppColors.gold
                                                : AppColors.textSecondary))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => isHusbandExternal = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isHusbandExternal
                                      ? AppColors.gold.withOpacity(0.15)
                                      : AppColors.bgDeep.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: isHusbandExternal
                                          ? AppColors.gold
                                          : Colors.white.withOpacity(0.06)),
                                ),
                                child: Center(
                                    child: Text(
                                        'من خارج العائلة',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isHusbandExternal
                                                ? AppColors.gold
                                                : AppColors.textSecondary))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!isHusbandExternal) ...[
                        Row(
                          children: [
                            Expanded(
                                child: _buildTextField(
                                    husbandQfSearchController, 'رقم QF للزوج')),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                final qf =
                                    husbandQfSearchController.text.trim().toUpperCase();
                                if (qf.isEmpty) {
                                  setModalState(() => selectedHusbandPerson = null);
                                  return;
                                }
                                try {
                                  final found = _allPeople.firstWhere(
                                    (p) =>
                                        (p['legacy_user_id'] as String? ?? '')
                                                .toUpperCase() ==
                                            qf &&
                                        p['gender'] == 'male',
                                    orElse: () => <String, dynamic>{},
                                  );
                                  if (found.isNotEmpty) {
                                    setModalState(() => selectedHusbandPerson = found);
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
                                        content: Text('لم يتم العثور على ذكر بـ $qf'),
                                        backgroundColor: AppColors.accentRed),
                                  );
                                }
                              },
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.search_rounded,
                                    color: AppColors.bgDeep, size: 22),
                              ),
                            ),
                          ],
                        ),
                        if (selectedHusbandPerson != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: AppColors.accentGreen.withOpacity(0.2)),
                            ),
                            child: Text(
                              '${selectedHusbandPerson!['name']} (${selectedHusbandPerson!['legacy_user_id']})',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.accentGreen),
                            ),
                          ),
                        ],
                      ] else ...[
                        _buildTextField(husbandNameController, 'اسم الزوج'),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildLabel('أبناء البنت'),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _showAddGirlChildDialog(
                                person['id'] as String,
                                isHusbandExternal
                                    ? husbandNameController.text.trim()
                                    : (selectedHusbandPerson?['name'] as String? ?? ''),
                                setModalState,
                                girlChildren),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.gold.withOpacity(0.3)),
                              ),
                              child: const Text('+ إضافة ابن/بنت',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.gold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (girlChildren.isEmpty)
                        Text(
                            'لا يوجد أبناء مسجلين',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary.withOpacity(0.7)))
                      else
                        ...girlChildren.map((child) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.bgDeep.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  (child['child_gender'] as String? ?? 'male') ==
                                          'male'
                                      ? Icons.male_rounded
                                      : Icons.female_rounded,
                                  color:
                                      (child['child_gender'] as String? ?? 'male') ==
                                              'male'
                                          ? Colors.blue
                                          : Colors.pink,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    child['child_name'] as String? ?? '—',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary),
                                  ),
                                ),
                                if (child['child_birthdate'] != null)
                                  Text(
                                    child['child_birthdate'] as String? ?? '',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary
                                            .withOpacity(0.7)),
                                  ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () async {
                                    await SupabaseConfig.client
                                        .from('girls_children')
                                        .delete()
                                        .eq('id', child['id']);
                                    girlChildren
                                        .removeWhere((c) => c['id'] == child['id']);
                                    setModalState(() {});
                                  },
                                  child: const Icon(Icons.close_rounded,
                                      color: AppColors.accentRed, size: 16),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ],
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

                          if (person['gender'] == 'female') {
                            if (isMarried) {
                              final marriageData = <String, dynamic>{
                                'wife_id': person['id'],
                                'marriage_order': 1,
                                'is_current': true,
                              };
                              if (!isHusbandExternal && selectedHusbandPerson != null) {
                                marriageData['husband_id'] = selectedHusbandPerson!['id'];
                              } else {
                                marriageData['husband_id'] = null;
                              }
                              if (existingGirlMarriage != null) {
                                await SupabaseConfig.client
                                    .from('marriages')
                                    .update(marriageData)
                                    .eq('id', existingGirlMarriage!['id']);
                              } else {
                                await SupabaseConfig.client.from('marriages').insert(marriageData);
                              }
                            } else if (existingGirlMarriage != null) {
                              await SupabaseConfig.client
                                  .from('marriages')
                                  .delete()
                                  .eq('id', existingGirlMarriage!['id']);
                            }
                          }

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
    Map<String, dynamic>? selectedHusband;
    String? selectedWifeId;
    bool isExternalWife = false;
    final externalNameController = TextEditingController();

    final females = _allPeople.where((p) => p['gender'] == 'female').toList();

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
                            setModalState(() => selectedHusband = null);
                            return;
                          }
                          try {
                            final found = _allPeople.firstWhere(
                              (p) => (p['legacy_user_id'] as String? ?? '').toUpperCase() == qf && p['gender'] == 'male',
                              orElse: () => <String, dynamic>{},
                            );
                            if (found.isNotEmpty) {
                              setModalState(() => selectedHusband = found);
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
                  if (!isExternalWife)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: selectedWifeId,
                          hint: const Text('اختر الزوجة',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          isExpanded: true,
                          dropdownColor: AppColors.bgCard,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          items: females
                              .map((f) => DropdownMenuItem<String?>(
                                    value: f['id'] as String,
                                    child: Text(f['name'] as String),
                                  ))
                              .toList(),
                          onChanged: (val) => setModalState(() => selectedWifeId = val),
                        ),
                      ),
                    )
                  else
                    _buildTextField(externalNameController, 'اسم الزوجة'),
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
                        if (!isExternalWife && selectedWifeId == null) {
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
                          final existingMarriages =
                              _allMarriages.where((m) => m['husband_id'] == husbandId).length;
                          final insertData = <String, dynamic>{
                            'husband_id': husbandId,
                            'marriage_order': existingMarriages + 1,
                            'is_current': true,
                          };
                          if (!isExternalWife) {
                            insertData['wife_id'] = selectedWifeId;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text('تأكيد حذف الزواج', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'حذف زواج ${marriage['husband_name']} و ${marriage['wife_name']}؟',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
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
      await SupabaseConfig.client.from('marriages').delete().eq('id', marriage['id']);
      _showSuccess('تم حذف الزواج');
      _loadMarriages();
    } catch (e) {
      _showError('خطأ: $e');
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
              Text(
                '${_allMarriages.length} زواج',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (_allPeople.isEmpty) _loadPeople();
                  _showAddMarriageDialog();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add_rounded, color: AppColors.bgDeep, size: 18),
                      SizedBox(width: 4),
                      Text('إضافة زواج',
                          style: TextStyle(
                              color: AppColors.bgDeep, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingMarriages
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _allMarriages.length,
                  itemBuilder: (context, index) {
                    final m = _allMarriages[index];
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
                      hintText: 'بحث باسم الطفل أو الأم أو الأب...',
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
        Expanded(
          child: _isLoadingPeople
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _allPeople.length,
                  itemBuilder: (context, index) {
                    final person = _allPeople[index];
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
}
