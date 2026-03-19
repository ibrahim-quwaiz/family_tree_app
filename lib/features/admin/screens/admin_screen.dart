import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/supabase_config.dart';
import '../../profile/services/person_service.dart';

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

  bool _isLoadingSettings = true;
  final _whatsappSettingsController = TextEditingController();
  final _emailSettingsController = TextEditingController();
  final _smsSettingsController = TextEditingController();
  final _manualNotifTitleController = TextEditingController();
  final _manualNotifBodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
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
    _whatsappSettingsController.dispose();
    _emailSettingsController.dispose();
    _smsSettingsController.dispose();
    _manualNotifTitleController.dispose();
    _manualNotifBodyController.dispose();
    super.dispose();
  }

  Future<void> _createNotification({
    required String title,
    required String body,
    required String type,
    String? relatedId,
    String? recipientId,
  }) async {
    try {
      await SupabaseConfig.client.from('notifications').insert({
        'title': title,
        'body': body,
        'type': type,
        if (relatedId != null) 'related_id': relatedId,
        if (recipientId != null) 'recipient_id': recipientId,
      });
    } catch (e) {}
  }

  void _loadTabData(int index) {
    switch (index) {
      case 0: if (_allPeople.isEmpty) _loadPeople(); break;
      case 1: if (_allMarriages.isEmpty) { if (_allPeople.isEmpty) _loadPeople(); _loadMarriages(); } break;
      case 2: if (_allGirlsChildren.isEmpty) { if (_allPeople.isEmpty) _loadPeople(); _loadGirlsChildren(); } break;
      case 3: if (_allNews.isEmpty) _loadNews(); _loadNotifications(); break;
      case 4: if (_allPeople.isEmpty) _loadPeople(); break;
      case 5: _loadSupportRequests(); break;
      case 6: _loadSettings(); break;
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
                        child: Icon(Icons.child_care_rounded, color: Color(0xFFE91E8C), size: 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('إضافة ابن/بنت لبنت العائلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  _buildLabel('الأم (بنت العائلة) — رقم QF *'),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(motherQfController, 'مثال: QF05012')),
                      SizedBox(width: 8),
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
                          child: Icon(Icons.search_rounded, color: AppColors.bgDeep, size: 22),
                        ),
                      ),
                    ],
                  ),
                  if (selectedMother != null) ...[
                    SizedBox(height: 6),
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
                          Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selectedMother!['name']} (${selectedMother!['legacy_user_id']})',
                              style: TextStyle(fontSize: 13, color: AppColors.accentGreen),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModalState(() { selectedMother = null; motherQfController.clear(); }),
                            child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 12),

                  _buildLabel('اسم الطفل *'),
                  SizedBox(height: 4),
                  _buildTextField(childNameController, 'الاسم الكامل'),
                  SizedBox(height: 12),

                  _buildLabel('الأب'),
                  SizedBox(height: 6),
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
                                Text('آباء مسجلين:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                SizedBox(height: 6),
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
                                              SizedBox(width: 4),
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
                                        child: Row(
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
                          SizedBox(height: 8),
                        ],
                        if (allFatherNames.isEmpty || fatherNameController.text.isEmpty || !allFatherNames.contains(fatherNameController.text))
                          _buildTextField(fatherNameController, 'اكتب اسم الأب'),
                      ],
                    ),
                  SizedBox(height: 12),

                  _buildLabel('الجنس'),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      _buildGenderOption('ذكر', 'male', childGender, (val) => setModalState(() => childGender = val)),
                      SizedBox(width: 8),
                      _buildGenderOption('أنثى', 'female', childGender, (val) => setModalState(() => childGender = val)),
                    ],
                  ),
                  SizedBox(height: 12),

                  _buildLabel('تاريخ الميلاد'),
                  SizedBox(height: 4),
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
                  SizedBox(height: 24),

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
                      child: Text('إضافة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
      useSafeArea: true,
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
                        child: Icon(Icons.edit_rounded, color: AppColors.gold, size: 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('تعديل: ${child['child_name']}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text('ابن/بنت: ${child['mother_name'] ?? '—'}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  _buildLabel('اسم الطفل *'),
                  SizedBox(height: 4),
                  _buildTextField(childNameController, 'الاسم'),
                  SizedBox(height: 12),

                  _buildLabel('الأب'),
                  SizedBox(height: 6),
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
                                  Text('آباء مسجلين:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  SizedBox(height: 6),
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
                                                SizedBox(width: 4),
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
                                          child: Row(
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
                            SizedBox(height: 8),
                          ],
                          if (allFatherNames.isEmpty || fatherNameController.text.isEmpty || !allFatherNames.contains(fatherNameController.text))
                            _buildTextField(fatherNameController, 'اكتب اسم الأب'),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 12),

                  _buildLabel('الجنس'),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      _buildGenderOption('ذكر', 'male', childGender, (val) => setModalState(() => childGender = val)),
                      SizedBox(width: 8),
                      _buildGenderOption('أنثى', 'female', childGender, (val) => setModalState(() => childGender = val)),
                    ],
                  ),
                  SizedBox(height: 12),

                  _buildLabel('تاريخ الميلاد'),
                  SizedBox(height: 4),
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
                  SizedBox(height: 24),

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
                      child: Text('حفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
          title: Text('تأكيد الحذف', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('حذف "${child['child_name']}"؟', style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('حذف', style: TextStyle(color: AppColors.accentRed))),
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
    final personName = person['name'] as String? ?? '—';
    final personQf = person['legacy_user_id'] as String? ?? '';
    final personId = person['id'] as String;

    // تأكيد الحذف
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text('حذف "$personName"',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text('هل أنت متأكد من حذف هذا الشخص؟ لا يمكن التراجع.',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('حذف',
                  style: TextStyle(color: AppColors.accentRed)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final error = await PersonService.deletePerson(personId);

    if (error != null) {
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: Text('لا يمكن الحذف',
                style: TextStyle(color: AppColors.accentRed)),
            content: Text(
                'لا يمكن حذف "$personName" ($personQf)\n$error',
                style: TextStyle(color: AppColors.textPrimary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('حسناً', style: TextStyle(color: AppColors.gold)),
              ),
            ],
          ),
        ),
      );
      return;
    }

    _showSuccess('تم حذف "$personName" بنجاح');
    _loadPeople();
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {VoidCallback? onChanged, int? maxLength}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        onChanged: onChanged != null ? (_) => onChanged() : null,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textSecondary),
          counterText: maxLength != null ? '' : null,
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
    Map<String, dynamic>? selectedFather;
    final String? selectedFatherId = person['father_id'] as String?;
    List<Map<String, dynamic>> fatherWives = [];
    Map<String, dynamic>? selectedMotherMarriage;
    bool _contactLoaded = false;
    bool _wivesLoadedForEdit = false;
    String? editNameError;

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
                                currentPhotoUrl = person['photo_url'] as String?;
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
                            .eq('husband_id', selectedFatherId)
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
                        child: Icon(Icons.edit_rounded, color: AppColors.gold, size: 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'تعديل: ${person['name']}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'QF: ${person['legacy_user_id'] ?? '—'}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7)),
                  ),
                  SizedBox(height: 16),
                  _buildLabel('الاسم *'),
                  SizedBox(height: 4),
                  _buildTextField(
                    nameController,
                    'الاسم الكامل',
                    onChanged: () => setModalState(() => editNameError = null),
                  ),
                  if (editNameError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        editNameError!,
                        style: const TextStyle(color: AppColors.accentRed, fontSize: 12),
                      ),
                    ),
                  SizedBox(height: 12),
                  _buildLabel('الجنس'),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      _buildGenderOption('ذكر', 'male', selectedGender, (val) => setModalState(() => selectedGender = val)),
                      SizedBox(width: 8),
                      _buildGenderOption('أنثى', 'female', selectedGender, (val) => setModalState(() => selectedGender = val)),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'الجيل: $generation',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12),
                  _buildLabel('الأب (أدخل رقم QF)'),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(fatherQfController, 'مثال: QF03001'),
                      ),
                      SizedBox(width: 8),
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
                          child: Icon(Icons.search_rounded, color: AppColors.bgDeep, size: 22),
                        ),
                      ),
                    ],
                  ),
                  if (selectedFather != null) ...[
                    SizedBox(height: 6),
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
                          Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selectedFather!['name']} (${selectedFather!['legacy_user_id']}) — ج${selectedFather!['generation']}',
                              style: TextStyle(fontSize: 13, color: AppColors.accentGreen),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModalState(() {
                              selectedFather = null;
                              fatherQfController.clear();
                              fatherWives = [];
                              selectedMotherMarriage = null;
                            }),
                            child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 12),
                  _buildLabel('الأم (من زوجات الأب)'),
                  SizedBox(height: 4),
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
                      child: Text(
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
                          hint: Text('اختر الأم', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          isExpanded: true,
                          dropdownColor: AppColors.bgCard,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
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
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _buildLabel('الحالة:'),
                      SizedBox(width: 12),
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
                      SizedBox(width: 8),
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
                  SizedBox(height: 12),
                  _buildLabel('تاريخ الميلاد'),
                  SizedBox(height: 4),
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
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('مدينة الميلاد'),
                            SizedBox(height: 4),
                            _buildTextField(birthCityController, 'المدينة'),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('الدولة'),
                            SizedBox(height: 4),
                            _buildTextField(birthCountryController, 'الدولة'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildLabel('مدينة الإقامة'),
                  SizedBox(height: 4),
                  _buildTextField(residenceCityController, 'مدينة الإقامة'),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('الوظيفة'),
                            SizedBox(height: 4),
                            _buildTextField(jobController, 'الوظيفة'),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('التعليم'),
                            SizedBox(height: 4),
                            _buildTextField(educationController, 'التعليم'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
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
                        hint: Text('اختر الحالة', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
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
                  SizedBox(height: 12),
                  _buildLabel('رمز PIN'),
                  SizedBox(height: 4),
                  _buildTextField(pinController, 'رمز الدخول (4 أرقام)', maxLength: 4),
                  SizedBox(height: 20),
                  Container(height: 1, color: Colors.white.withOpacity(0.06)),
                  SizedBox(height: 16),
                  Text('معلومات الاتصال',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gold)),
                  SizedBox(height: 12),
                  _buildLabel('رقم الجوال'),
                  SizedBox(height: 4),
                  _buildTextField(mobileController, '05xxxxxxxx'),
                  SizedBox(height: 12),
                  _buildLabel('البريد الإلكتروني'),
                  SizedBox(height: 4),
                  _buildTextField(emailController, 'email@example.com'),
                  SizedBox(height: 12),
                  _buildLabel('الصورة الشخصية'),
                  SizedBox(height: 4),
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
                            ? Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 28)
                            : null,
                      ),
                      SizedBox(width: 12),
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
                                    Icon(Icons.upload_rounded, color: AppColors.gold, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      selectedImageBytes != null ? 'تم اختيار صورة ✓' : 'اختر صورة',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'الحد: 400×400 بكسل، 500KB',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('انستقرام'),
                          SizedBox(height: 4),
                          _buildTextField(instagramController, '@username'),
                        ],
                      )),
                      SizedBox(width: 8),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('تويتر'),
                          SizedBox(height: 4),
                          _buildTextField(twitterController, '@username'),
                        ],
                      )),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('سناب شات'),
                          SizedBox(height: 4),
                          _buildTextField(snapchatController, '@username'),
                        ],
                      )),
                      SizedBox(width: 8),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('فيسبوك'),
                          SizedBox(height: 4),
                          _buildTextField(facebookController, '@username'),
                        ],
                      )                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          setModalState(() => editNameError = 'الاسم مطلوب');
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
                          final contactData = <String, dynamic>{
                            'mobile_phone':
                                mobileController.text.trim().isEmpty ? null : mobileController.text.trim(),
                            'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                            'instagram':
                                instagramController.text.trim().isEmpty ? null : instagramController.text.trim(),
                            'twitter':
                                twitterController.text.trim().isEmpty ? null : twitterController.text.trim(),
                            'snapchat':
                                snapchatController.text.trim().isEmpty ? null : snapchatController.text.trim(),
                            'facebook':
                                facebookController.text.trim().isEmpty ? null : facebookController.text.trim(),
                          };
                          await PersonService.updatePerson(
                            personId: person['id'] as String,
                            personData: updateData,
                            contactData: contactData,
                            photoBytes: selectedImageBytes,
                          );

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
                      child: Text('حفظ التعديلات',
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
    Uint8List? selectedPhotoBytes;
    final instagramController = TextEditingController();
    final twitterController = TextEditingController();
    final snapchatController = TextEditingController();
    final facebookController = TextEditingController();
    String selectedGender = 'male';
    Map<String, dynamic>? selectedFather;
    List<Map<String, dynamic>> fatherWives = [];
    Map<String, dynamic>? selectedMotherMarriage;
    DateTime? birthDate;
    String? fatherSearchError;
    String? nameError;
    String? fatherError;
    String? motherError;
    int currentStep = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> validateStep1AndContinue() async {
            bool hasError = false;
            if (nameController.text.trim().isEmpty) {
              hasError = true;
              nameError = 'الاسم مطلوب';
            } else {
              nameError = null;
            }
            if (selectedFather == null) {
              hasError = true;
              fatherError = 'يجب اختيار الأب';
            } else {
              fatherError = null;
            }
            if (fatherWives.isNotEmpty && selectedMotherMarriage == null) {
              hasError = true;
              motherError = 'يجب اختيار الأم';
            } else {
              motherError = null;
            }
            setModalState(() {});
            if (!hasError) {
              setModalState(() => currentStep = 1);
            }
          }

          Future<void> savePerson() async {
            try {
              final generation = selectedFather != null
                  ? ((selectedFather!['generation'] as int? ?? 0) + 1)
                  : 1;
              final contactData = <String, dynamic>{
                if (mobileController.text.trim().isNotEmpty) 'mobile_phone': mobileController.text.trim(),
                if (emailController.text.trim().isNotEmpty) 'email': emailController.text.trim(),
                if (instagramController.text.trim().isNotEmpty) 'instagram': instagramController.text.trim(),
                if (twitterController.text.trim().isNotEmpty) 'twitter': twitterController.text.trim(),
                if (snapchatController.text.trim().isNotEmpty) 'snapchat': snapchatController.text.trim(),
                if (facebookController.text.trim().isNotEmpty) 'facebook': facebookController.text.trim(),
              };
              final qfId = await PersonService.addPerson(
                name: nameController.text.trim(),
                gender: selectedGender,
                generation: generation,
                fatherId: selectedFather?['id'] as String?,
                motherId: selectedMotherMarriage?['wife_id'] as String?,
                motherExternalName: selectedMotherMarriage?['wife_external_name'] as String?,
                birthDate: birthDate,
                birthCity: birthCityController.text.trim().isEmpty ? null : birthCityController.text.trim(),
                birthCountry: birthCountryController.text.trim().isEmpty ? null : birthCountryController.text.trim(),
                contactData: contactData.isEmpty ? null : contactData,
                photoBytes: selectedPhotoBytes,
              );
              await _createNotification(
                title: 'عضو جديد في العائلة',
                body: 'تمت إضافة ${nameController.text.trim()} إلى شجرة العائلة',
                type: 'new_member',
              );
              if (context.mounted) Navigator.pop(context);
              _showSuccess('تم إضافة "${nameController.text.trim()}" برقم $qfId');
              _loadPeople();
            } catch (e) {
              _showError('خطأ في الإضافة: $e');
            }
          }

          Widget buildStepIndicator() {
            final stepText = 'الخطوة ${currentStep + 1} من 3';
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stepText,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Row(
                  children: List.generate(3, (index) {
                    final bool isActive = index == currentStep;
                    return Container(
                      margin: const EdgeInsetsDirectional.only(start: 6),
                      width: isActive ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.gold : AppColors.bgDeep.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ],
            );
          }

          Widget buildStep1() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('الاسم *'),
                const SizedBox(height: 4),
                _buildTextField(
                  nameController,
                  'الاسم الكامل',
                  onChanged: () => setModalState(() => nameError = null),
                ),
                if (nameError != null)
                  const SizedBox(height: 4),
                if (nameError != null)
                  Text(
                    nameError!,
                    style: const TextStyle(color: AppColors.accentRed, fontSize: 12),
                  ),
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
                      child: _buildTextField(
                        fatherQfController,
                        'مثال: QF03001',
                        onChanged: () => setModalState(() => fatherError = null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final qf = fatherQfController.text.trim().toUpperCase();
                        if (qf.isEmpty) {
                          setModalState(() {
                            selectedFather = null;
                            fatherSearchError = null;
                          });
                          return;
                        }
                        try {
                          final found = _allPeople.firstWhere(
                            (p) => (p['legacy_user_id'] as String? ?? '').toUpperCase() == qf,
                            orElse: () => <String, dynamic>{},
                          );
                          if (found.isNotEmpty) {
                            setModalState(() {
                              selectedFather = found;
                              fatherSearchError = null;
                              fatherError = null;
                            });
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
                            setModalState(() => fatherSearchError = 'لم يتم العثور على $qf');
                          }
                        } catch (_) {
                          setModalState(() => fatherSearchError = 'لم يتم العثور على $qf');
                        }
                      },
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.search_rounded, color: AppColors.bgDeep, size: 22),
                      ),
                    ),
                  ],
                ),
                if (fatherSearchError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    fatherSearchError!,
                    style: const TextStyle(fontSize: 12, color: AppColors.accentRed),
                  ),
                ],
                if (selectedFather != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'الجيل: ${(selectedFather!['generation'] as int? ?? 0) + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
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
                        Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 16),
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
                            fatherSearchError = null;
                            fatherError = null;
                            motherError = null;
                          }),
                          child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accentAmber.withOpacity(0.2)),
                        ),
                        child: const Text(
                          '⚠️ لا توجد زوجات مسجلة لهذا الأب.',
                          style: TextStyle(fontSize: 12, color: AppColors.accentAmber),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddMarriageDialog();
                          },
                          icon: const Icon(Icons.person_add_rounded, size: 18, color: AppColors.accentAmber),
                          label: const Text('إضافة زوجة', style: TextStyle(color: AppColors.accentAmber)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.accentAmber.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
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
                        hint: Text('اختر الأم', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        isExpanded: true,
                        dropdownColor: AppColors.bgCard,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
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
                            setModalState(() {
                              selectedMotherMarriage = fatherWives[index];
                              motherError = null;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                if (fatherError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    fatherError!,
                    style: const TextStyle(color: AppColors.accentRed, fontSize: 12),
                  ),
                ],
                if (motherError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    motherError!,
                    style: const TextStyle(color: AppColors.accentRed, fontSize: 12),
                  ),
                ],
              ],
            );
          }

          Widget buildStep2() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        color: birthDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
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
                _buildLabel('الصورة الشخصية'),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final x = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                      maxWidth: 800,
                    );
                    if (x != null) {
                      final bytes = await x.readAsBytes();
                      if (bytes.length > 500 * 1024) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('الصورة كبيرة جداً. الحد الأقصى 500 كيلوبايت'),
                              backgroundColor: AppColors.accentRed,
                            ),
                          );
                        }
                        return;
                      }
                      setModalState(() => selectedPhotoBytes = bytes);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selectedPhotoBytes != null
                              ? Icons.check_circle_rounded
                              : Icons.add_photo_alternate_rounded,
                          color: selectedPhotoBytes != null
                              ? AppColors.accentGreen
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedPhotoBytes != null ? 'تم اختيار صورة ✓' : 'اختر صورة من الجهاز',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          Widget buildStep3() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'معلومات الاتصال',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLabel('رقم الجوال'),
                const SizedBox(height: 4),
                _buildTextField(mobileController, '05xxxxxxxx'),
                const SizedBox(height: 12),
                _buildLabel('البريد الإلكتروني'),
                const SizedBox(height: 4),
                _buildTextField(emailController, 'email@example.com'),
                const SizedBox(height: 12),
                _buildLabel('روابط التواصل'),
                const SizedBox(height: 8),
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
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('تويتر'),
                          const SizedBox(height: 4),
                          _buildTextField(twitterController, '@username'),
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
                          _buildLabel('سناب شات'),
                          const SizedBox(height: 4),
                          _buildTextField(snapchatController, '@username'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('فيسبوك'),
                          const SizedBox(height: 4),
                          _buildTextField(facebookController, '@username'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: bottomInset + 20,
                  ),
                  child: Column(
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
                            child: Icon(Icons.person_add_rounded, color: AppColors.accentGreen, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'إضافة شخص جديد',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                              ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      buildStepIndicator(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (currentStep == 0) buildStep1(),
                              if (currentStep == 1) buildStep2(),
                              if (currentStep == 2) buildStep3(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (currentStep > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setModalState(() => currentStep -= 1);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('السابق'),
                              ),
                            ),
                          if (currentStep > 0) const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                if (currentStep == 0) {
                                  await validateStep1AndContinue();
                                } else if (currentStep == 1) {
                                  setModalState(() => currentStep = 2);
                                } else {
                                  await savePerson();
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.bgDeep,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                currentStep < 2 ? 'التالي' : 'إضافة',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
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
    String? husbandError;
    String? wifeError;
    String? externalWifeNameError;

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
                        child: Icon(Icons.favorite_rounded, color: Color(0xFFE91E8C), size: 20),
                      ),
                      SizedBox(width: 12),
                      Text('إضافة زواج',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildLabel('الزوج (أدخل رقم QF) *'),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          husbandQfController,
                          'مثال: QF03001',
                          onChanged: () => setModalState(() => husbandError = null),
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final qf = husbandQfController.text.trim().toUpperCase();
                          if (qf.isEmpty) {
                            setModalState(() {
                              selectedHusband = null;
                              marriageOrder = 1;
                              husbandError = 'ابحث عن الزوج برقم QF واختره';
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
                                husbandError = null;
                                // حساب رقم الزواج تلقائياً
                                final existingMarriages = _allMarriages
                                    .where((m) => m['husband_id'] == found['id'])
                                    .length;
                                marriageOrder = existingMarriages + 1;
                              });
                            } else {
                              setModalState(() {
                                selectedHusband = null;
                                marriageOrder = 1;
                                husbandError = 'لم يتم العثور على ذكر بـ $qf';
                              });
                            }
                          } catch (_) {
                            setModalState(() {
                              selectedHusband = null;
                              marriageOrder = 1;
                              husbandError = 'لم يتم العثور على $qf';
                            });
                          }
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.search_rounded, color: AppColors.bgDeep, size: 22),
                        ),
                      ),
                    ],
                  ),
                  if (husbandError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        husbandError!,
                        style: const TextStyle(color: AppColors.accentRed, fontSize: 12),
                      ),
                    ),
                  if (selectedHusband != null) ...[
                    SizedBox(height: 6),
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
                          Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selectedHusband!['name']} (${selectedHusband!['legacy_user_id']}) — ج${selectedHusband!['generation']}',
                              style: TextStyle(fontSize: 13, color: AppColors.accentGreen),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setModalState(() {
                              selectedHusband = null;
                              husbandQfController.clear();
                            }),
                            child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 12),
                  _buildLabel('الزوجة *'),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() {
                            isExternalWife = false;
                            wifeError = null;
                            externalWifeNameError = null;
                          }),
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
                      SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() {
                            isExternalWife = true;
                            wifeError = null;
                            externalWifeNameError = null;
                          }),
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
                  SizedBox(height: 8),
                  if (!isExternalWife) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            wifeQfController,
                            'أدخل رقم QF للزوجة',
                            onChanged: () => setModalState(() => wifeError = null),
                          ),
                        ),
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final qf = wifeQfController.text.trim().toUpperCase();
                            if (qf.isEmpty) {
                              setModalState(() {
                                selectedWife = null;
                                wifeError = 'اختر الزوجة';
                              });
                              return;
                            }
                            try {
                              final found = _allPeople.firstWhere(
                                (p) => (p['legacy_user_id'] as String? ?? '').toUpperCase() == qf && p['gender'] == 'female',
                                orElse: () => <String, dynamic>{},
                              );
                              if (found.isNotEmpty) {
                                setModalState(() {
                                  selectedWife = found;
                                  wifeError = null;
                                });
                              } else {
                                setModalState(() {
                                  selectedWife = null;
                                  wifeError = 'لم يتم العثور على أنثى بـ $qf';
                                });
                              }
                            } catch (_) {
                              setModalState(() {
                                selectedWife = null;
                                wifeError = 'لم يتم العثور على $qf';
                              });
                            }
                          },
                          child: Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.search_rounded, color: AppColors.bgDeep, size: 22),
                          ),
                        ),
                      ],
                    ),
                    if (selectedWife != null) ...[
                      SizedBox(height: 6),
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
                            Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${selectedWife!['name']} (${selectedWife!['legacy_user_id']}) — ج${selectedWife!['generation']}',
                                style: TextStyle(fontSize: 13, color: AppColors.accentGreen),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setModalState(() {
                                selectedWife = null;
                                wifeQfController.clear();
                              }),
                              child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else
                    _buildTextField(
                      externalNameController,
                      'اسم الزوجة',
                      onChanged: () => setModalState(() => externalWifeNameError = null),
                    ),
                  if (wifeError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        wifeError!,
                        style: const TextStyle(color: AppColors.accentRed, fontSize: 12),
                      ),
                    ),
                  if (externalWifeNameError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        externalWifeNameError!,
                        style: const TextStyle(color: AppColors.accentRed, fontSize: 12),
                      ),
                    ),
                  SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildLabel('رقم الزواج:'),
                        SizedBox(width: 8),
                        Text('$marriageOrder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gold)),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        bool hasError = false;
                        if (selectedHusband == null) {
                          husbandError = 'ابحث عن الزوج برقم QF واختره';
                          hasError = true;
                        } else {
                          husbandError = null;
                        }
                        if (!isExternalWife && selectedWife == null) {
                          wifeError = 'اختر الزوجة';
                          hasError = true;
                        } else if (!isExternalWife) {
                          wifeError = null;
                        }
                        if (isExternalWife && externalNameController.text.trim().isEmpty) {
                          externalWifeNameError = 'اكتب اسم الزوجة';
                          hasError = true;
                        } else if (isExternalWife) {
                          externalWifeNameError = null;
                        }
                        setModalState(() {});
                        if (hasError) return;

                        Navigator.pop(context);
                        try {
                          final husbandId = selectedHusband!['id'] as String;
                          await PersonService.addMarriage(
                            husbandId: husbandId,
                            wifeId: !isExternalWife ? selectedWife!['id'] as String? : null,
                            externalName: isExternalWife ? externalNameController.text.trim() : null,
                          );
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
                      child: Text('إضافة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
    final husbandName = marriage['husband_name'] as String? ?? '—';
    final wifeName = marriage['wife_name'] as String? ?? marriage['wife_external_name'] as String? ?? '—';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text('حذف زواج "$husbandName" و "$wifeName"',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text('هل أنت متأكد؟ لا يمكن التراجع.',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('حذف', style: TextStyle(color: AppColors.accentRed)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final wifeId = marriage['wife_id'] as String?;
    final husbandId = marriage['husband_id'] as String? ?? '';
    final wifeExternalName = marriage['wife_external_name'] as String?;

    final error = await PersonService.deleteMarriage(
      marriageId: marriage['id'] as String,
      husbandId: husbandId,
      wifeId: wifeId,
      wifeExternalName: wifeExternalName,
    );

    if (error != null) {
      _showError('لا يمكن الحذف: $error');
      return;
    }

    _showSuccess('تم حذف الزواج بنجاح');
    _loadMarriages();
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
                        child: Icon(Icons.newspaper_rounded, color: AppColors.gold, size: 20),
                      ),
                      SizedBox(width: 12),
                      Text('إضافة خبر',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildLabel('العنوان *'),
                  SizedBox(height: 4),
                  _buildTextField(titleController, 'عنوان الخبر'),
                  SizedBox(height: 12),
                  _buildLabel('المحتوى *'),
                  SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: TextField(
                      controller: bodyController,
                      maxLines: 5,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'محتوى الخبر...',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        contentPadding: EdgeInsets.all(14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildLabel('التصنيف'),
                  SizedBox(height: 4),
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
                  SizedBox(height: 24),
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
                      child: Text('نشر الخبر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
          title: Text('حذف الخبر؟', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('حذف "${news['title']}"؟', style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('حذف', style: TextStyle(color: AppColors.accentRed))),
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

  void _showEditNewsDialog(Map<String, dynamic> news) {
    final titleController = TextEditingController(text: news['title'] as String? ?? '');
    final contentController = TextEditingController(text: news['content'] as String? ?? '');
    String selectedType = news['news_type'] as String? ?? 'general';
    bool isApproved = news['is_approved'] as bool? ?? false;

    final newsTypes = {
      'general': 'أخبار عامة',
      'events': 'مناسبات',
      'births': 'ولادات',
      'deaths': 'وفيات',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                SizedBox(height: 16),
                Text('تعديل الخبر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                SizedBox(height: 16),
                if (news['image_url'] != null && (news['image_url'] as String).toString().isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      news['image_url'] as String,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: AppColors.bgCard,
                          child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 100,
                        color: AppColors.bgCard,
                        child: Center(child: Icon(Icons.broken_image, color: AppColors.textSecondary)),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                ],
                _buildLabel('نوع الخبر'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: AppColors.bgDeep.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.06))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedType,
                      isExpanded: true,
                      dropdownColor: AppColors.bgCard,
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      items: newsTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                      onChanged: (v) => setModalState(() => selectedType = v ?? 'general'),
                    ),
                  ),
                ),
                SizedBox(height: 12),

                _buildLabel('العنوان'),
                _buildTextField(titleController, 'عنوان الخبر'),
                SizedBox(height: 12),

                _buildLabel('المحتوى'),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'محتوى الخبر...',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                    filled: true, fillColor: AppColors.bgDeep.withOpacity(0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
                  ),
                ),
                SizedBox(height: 12),

                Row(
                  children: [
                    _buildLabel('حالة النشر'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setModalState(() => isApproved = !isApproved),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isApproved ? AppColors.accentGreen.withOpacity(0.1) : AppColors.accentAmber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isApproved ? AppColors.accentGreen.withOpacity(0.3) : AppColors.accentAmber.withOpacity(0.3)),
                        ),
                        child: Text(
                          isApproved ? '✅ منشور' : '⏳ معلق',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isApproved ? AppColors.accentGreen : AppColors.accentAmber),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await SupabaseConfig.client.from('news').update({
                          'news_type': selectedType,
                          'title': titleController.text.trim(),
                          'content': contentController.text.trim(),
                          'is_approved': isApproved,
                        }).eq('id', news['id']);
                        Navigator.pop(context);
                        _showSuccess('تم تعديل الخبر');
                        _loadNews();
                      } catch (e) {
                        _showError('خطأ: $e');
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgDeep),
                    child: Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                      child: Icon(Icons.notifications_active_rounded, color: AppColors.gold, size: 20),
                    ),
                    SizedBox(width: 12),
                    Text('إرسال إشعار',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
                SizedBox(height: 16),
                _buildLabel('العنوان *'),
                SizedBox(height: 4),
                _buildTextField(titleController, 'عنوان الإشعار'),
                SizedBox(height: 12),
                _buildLabel('المحتوى *'),
                SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: TextField(
                    controller: bodyController,
                    maxLines: 3,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'نص الإشعار...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      contentPadding: EdgeInsets.all(14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                SizedBox(height: 24),
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
                    child: Text('إرسال', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
          title: Text(action, style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            '${isCurrentlyAdmin ? 'إزالة صلاحية المدير من' : 'تعيين'} "${person['name']}" ${isCurrentlyAdmin ? '؟' : 'كمدير؟'}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
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
          title: Text('لوحة التحكم', style: TextStyle(fontWeight: FontWeight.w700)),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_forward_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'الأشخاص', icon: Icon(Icons.people_rounded, size: 18)),
              Tab(text: 'الزواجات', icon: Icon(Icons.favorite_rounded, size: 18)),
              Tab(text: 'أبناء البنات', icon: Icon(Icons.child_care_rounded, size: 18)),
              Tab(text: 'الأخبار', icon: Icon(Icons.newspaper_rounded, size: 18)),
              Tab(text: 'الصلاحيات', icon: Icon(Icons.admin_panel_settings_rounded, size: 18)),
              Tab(text: 'الطلبات'),
              Tab(text: 'الإعدادات'),
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
            _buildSettingsTab(),
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
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم أو QF...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              GestureDetector(
                onTap: _showAddPersonDialog,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add_rounded, color: AppColors.bgDeep, size: 24),
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
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadPeople,
                child: Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: _isLoadingPeople
              ? Center(child: CircularProgressIndicator(color: AppColors.gold))
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
                          SizedBox(width: 10),
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
                                SizedBox(height: 2),
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
                            icon: Icon(Icons.edit_rounded, size: 18),
                            color: AppColors.gold,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                          IconButton(
                            onPressed: () => _deletePerson(person),
                            icon: Icon(Icons.delete_outline_rounded, size: 18),
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
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'بحث باسم أو رقم QF للزوج أو الزوجة...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
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
                  child: Icon(Icons.add_rounded, color: AppColors.bgDeep, size: 24),
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
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadMarriages,
                child: Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: _isLoadingMarriages
              ? Center(child: CircularProgressIndicator(color: AppColors.gold))
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
                                style: TextStyle(
                                    color: Color(0xFFE91E8C),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${m['husband_name']} ♥ ${m['wife_name']}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      isCurrent ? '💍 حالية' : '📝 سابقة',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    if (isExternal) ...[
                                      SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentAmber.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('خارجية',
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
                            icon: Icon(Icons.edit_rounded, size: 18),
                            color: AppColors.gold,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                          IconButton(
                            onPressed: () => _deleteMarriage(m),
                            icon: Icon(Icons.delete_outline_rounded, size: 18),
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
              SizedBox(height: 16),
              Text('تعديل الزواج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              SizedBox(height: 16),
              Text('الزوج: ${marriage['husband_name'] ?? '—'}', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              SizedBox(height: 4),
              Text('الزوجة: ${marriage['wife_name'] ?? '—'}', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              SizedBox(height: 16),
              _buildLabel('رقم الزواج'),
              _buildTextField(marriageOrderController, 'رقم الزواج (1، 2، 3...)'),
              SizedBox(height: 12),
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
                SizedBox(height: 12),
                _buildLabel('اسم الزوجة الخارجية'),
                _buildTextField(externalNameController, 'اسم الزوجة'),
              ],
              SizedBox(height: 24),
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
                  child: Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.w600)),
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
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'بحث باسم الطفل أو الأم أو الأب أو رقم QF...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (_allPeople.isEmpty) _loadPeople();
                  _showAddGirlChildFromTab();
                },
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.add_rounded, color: AppColors.bgDeep, size: 24),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('${_filteredGirlsChildren.length} طفل/طفلة', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              GestureDetector(onTap: _loadGirlsChildren, child: Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20)),
            ],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: _isLoadingGirlsChildren
              ? Center(child: CircularProgressIndicator(color: AppColors.gold))
              : _filteredGirlsChildren.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.child_care_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
                          SizedBox(height: 12),
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
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(child['child_name'] as String? ?? '—', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                    SizedBox(height: 2),
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
                                icon: Icon(Icons.edit_rounded, size: 18),
                                color: AppColors.gold,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                              IconButton(
                                onPressed: () => _deleteGirlChild(child),
                                icon: Icon(Icons.delete_outline_rounded, size: 18),
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
            child: TabBar(
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
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showAddNewsDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Row(
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
                          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
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
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (news['image_url'] != null && (news['image_url'] as String).toString().isNotEmpty) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            news['image_url'] as String,
                                            height: 200,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Container(
                                                height: 200,
                                                color: AppColors.bgCard,
                                                child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                                              );
                                            },
                                            errorBuilder: (_, __, ___) => Container(
                                              height: 100,
                                              color: AppColors.bgCard,
                                              child: Center(child: Icon(Icons.broken_image, color: AppColors.textSecondary)),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 12),
                                      ],
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  news['title'] as String? ?? '—',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary),
                                            ),
                                            if (!(news['is_approved'] as bool? ?? false))
                                              Container(
                                                margin: const EdgeInsets.only(top: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accentAmber.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text('⏳ بانتظار الموافقة', style: TextStyle(fontSize: 10, color: AppColors.accentAmber, fontWeight: FontWeight.w600)),
                                              ),
                                            SizedBox(height: 4),
                                            Text(
                                              news['content'] as String? ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7)),
                                            ),
                                            if (news['author_name'] != null && (news['author_name'] as String).isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text('بواسطة: ${news['author_name']}', style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withOpacity(0.5))),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _showEditNewsDialog(news),
                                        icon: Icon(Icons.edit_rounded, size: 18),
                                        color: AppColors.gold,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                      ),
                                      if (!(news['is_approved'] as bool? ?? false))
                                        IconButton(
                                          onPressed: () async {
                                            try {
                                              await SupabaseConfig.client.from('news').update({'is_approved': true}).eq('id', news['id']);
                                              await _createNotification(
                                                title: 'خبر جديد: ${news['title']}',
                                                body: 'تم نشر خبر جديد في قسم الأخبار',
                                                type: 'news',
                                                relatedId: news['id']?.toString(),
                                              );
                                              _showSuccess('تم نشر الخبر');
                                              _loadNews();
                                            } catch (e) {
                                              _showError('خطأ: $e');
                                            }
                                          },
                                          icon: Icon(Icons.check_circle_rounded, size: 18),
                                          color: AppColors.accentGreen,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                          tooltip: 'موافقة ونشر',
                                        ),
                                      IconButton(
                                        onPressed: () => _deleteNews(news),
                                        icon: Icon(Icons.delete_outline_rounded, size: 18),
                                        color: AppColors.accentRed,
                                      ),
                                        ],
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
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showSendNotificationDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Row(
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
                          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _allNotifications.length,
                              itemBuilder: (context, index) {
                                final notif = _allNotifications[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
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
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                notif['body'] as String? ?? '',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondary.withOpacity(0.7)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () async {
                                          try {
                                            await SupabaseConfig.client
                                                .from('notifications')
                                                .delete()
                                                .eq('id', notif['id']);
                                            _loadNotifications();
                                          } catch (e) {
                                            _showError('خطأ في حذف الإشعار: $e');
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentRed.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(Icons.delete_outline_rounded, color: AppColors.accentRed, size: 20),
                                        ),
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
                Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 18),
                SizedBox(width: 8),
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
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
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
              ? Center(child: CircularProgressIndicator(color: AppColors.gold))
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
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person['name'] as String? ?? '—',
                                  style: TextStyle(
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
                                      SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentGreen.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('فعّال',
                                            style: TextStyle(fontSize: 9, color: AppColors.accentGreen)),
                                      ),
                                    ],
                                    if (isAdmin) ...[
                                      SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.gold.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('مدير',
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

  Future<void> _loadSettings() async {
    setState(() => _isLoadingSettings = true);
    try {
      final response = await SupabaseConfig.client
          .from('family_info')
          .select()
          .inFilter('type', ['whatsapp', 'email', 'sms']);
      final list = List<Map<String, dynamic>>.from(response);
      String whatsapp = '';
      String email = '';
      String sms = '';
      for (final row in list) {
        final type = row['type'] as String? ?? '';
        final content = row['content'] as String? ?? '';
        if (type == 'whatsapp') whatsapp = content;
        if (type == 'email') email = content;
        if (type == 'sms') sms = content;
      }
      _whatsappSettingsController.text = whatsapp;
      _emailSettingsController.text = email;
      _smsSettingsController.text = sms;
      setState(() {
        _isLoadingSettings = false;
      });
    } catch (e) {
      setState(() => _isLoadingSettings = false);
      _showError('خطأ في تحميل الإعدادات: $e');
    }
  }

  Widget _buildSupportRequestsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('${_allRequests.length} طلب', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              GestureDetector(onTap: _loadSupportRequests, child: Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20)),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingRequests
              ? Center(child: CircularProgressIndicator(color: AppColors.gold))
              : _allRequests.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.inbox_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
                      SizedBox(height: 12),
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
                              SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                                child: Text(req['request_type'] as String? ?? '', style: TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w600))),
                              const Spacer(),
                              Text(req['sender_name'] as String? ?? 'مجهول', style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.7))),
                            ]),
                            SizedBox(height: 8),
                            Text(req['subject'] as String? ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            SizedBox(height: 4),
                            Text(req['message'] as String? ?? '', style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7)), maxLines: 3, overflow: TextOverflow.ellipsis),
                            if (req['admin_reply'] != null && (req['admin_reply'] as String).isNotEmpty) ...[
                              SizedBox(height: 8),
                              Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                                child: Text('الرد: ${req['admin_reply']}', style: TextStyle(fontSize: 12, color: AppColors.accentGreen.withOpacity(0.8)))),
                            ],
                            SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: GestureDetector(onTap: () => _showReplyDialog(req),
                                child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Center(child: Text('رد', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600, fontSize: 12)))))),
                              SizedBox(width: 8),
                              Expanded(child: GestureDetector(onTap: () => _changeRequestStatus(req),
                                child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: AppColors.accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                  child: Center(child: Text('تغيير الحالة', style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.w600, fontSize: 12)))))),
                              SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: AlertDialog(
                                          backgroundColor: AppColors.bgCard,
                                          title: Text('حذف الطلب', style: TextStyle(color: AppColors.textPrimary)),
                                          content: Text('هل أنت متأكد من حذف هذا الطلب؟', style: TextStyle(color: AppColors.textSecondary)),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
                                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('حذف', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.w700))),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (confirmed != true) return;
                                    try {
                                      await SupabaseConfig.client.from('support_requests').delete().eq('id', req['id']);
                                      _loadSupportRequests();
                                    } catch (e) {
                                      _showError('خطأ في الحذف: $e');
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(color: AppColors.accentRed.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                    child: Center(child: Text('حذف', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.w600, fontSize: 12))),
                                  ),
                                ),
                              ),
                            ]),
                          ]),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إعدادات التطبيق',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          SizedBox(height: 20),
          if (_isLoadingSettings)
            Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.gold)))
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('رقم الواتساب'),
                  SizedBox(height: 8),
                  _buildTextField(_whatsappSettingsController, 'مثال: 966555113730'),
                  SizedBox(height: 16),
                  _buildLabel('الإيميل'),
                  SizedBox(height: 8),
                  _buildTextField(_emailSettingsController, 'مثال: admin@example.com'),
                  SizedBox(height: 16),
                  _buildLabel('رقم SMS'),
                  SizedBox(height: 8),
                  _buildTextField(_smsSettingsController, 'رقم SMS للتنبيهات'),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () async {
                        try {
                          await SupabaseConfig.client
                              .from('family_info')
                              .update({'content': _whatsappSettingsController.text.trim()})
                              .eq('type', 'whatsapp');
                          await SupabaseConfig.client
                              .from('family_info')
                              .update({'content': _emailSettingsController.text.trim()})
                              .eq('type', 'email');
                          await SupabaseConfig.client
                              .from('family_info')
                              .update({'content': _smsSettingsController.text.trim()})
                              .eq('type', 'sms');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ تم تحديث الإعدادات بنجاح'),
                                backgroundColor: AppColors.bgCard,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        } catch (e) {
                          _showError('خطأ في حفظ الإعدادات: $e');
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('حفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
        title: Text('رد على الطلب', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: replyController,
          maxLines: 4,
          style: TextStyle(color: AppColors.textPrimary),
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
                await _createNotification(
                  title: 'تم الرد على طلبك',
                  body: 'تم الرد على طلب: ${req['subject']}',
                  type: 'support_reply',
                  relatedId: id,
                  recipientId: req['sender_id'] as String?,
                );
                _loadSupportRequests();
              } catch (e) {
                _showError('خطأ في حفظ الرد: $e');
              }
            },
            child: Text('إرسال'),
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
          SizedBox(height: 16),
          Text('تغيير الحالة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          SizedBox(height: 16),
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
