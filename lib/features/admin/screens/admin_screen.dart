import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import '../../directory/utils/arabic_search.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isLoading = true;
  bool _isAdmin = false;

  List<Map<String, dynamic>> _allPeople = [];
  List<Map<String, dynamic>> _filteredPeople = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
    _searchController.addListener(_applySearch);
  }

  Future<void> _init() async {
    try {
      _isAdmin = await AuthService.isAdmin();
    } catch (_) {
      _isAdmin = false;
    }
    await _loadPeople();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() => _filteredPeople = List<Map<String, dynamic>>.from(_allPeople));
      return;
    }
    final nq = ArabicSearch.normalize(q);
    setState(() {
      _filteredPeople = _allPeople.where((p) {
        final name = ArabicSearch.normalize((p['name'] as String?) ?? '');
        final legacy = ((p['legacy_user_id'] as String?) ?? '').toLowerCase();
        return name.contains(nq) || legacy.contains(q.toLowerCase());
      }).toList();
    });
  }

  Future<void> _loadPeople() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseConfig.client
          .from('people')
          .select('''
            id,
            legacy_user_id,
            name,
            gender,
            is_alive,
            generation,
            father_id,
            mother_id,
            mother_external_name,
            birth_date,
            death_date,
            birth_city,
            birth_country,
            residence_city,
            education,
            job,
            is_vip,
            contact_info(photo_url)
          ''')
          .order('generation')
          .order('name')
          .limit(2000);

      _allPeople = List<Map<String, dynamic>>.from(response);
      _filteredPeople = List<Map<String, dynamic>>.from(_allPeople);
      _applySearch();
    } catch (e) {
      _showError('خطأ في التحميل: $e');
      _allPeople = [];
      _filteredPeople = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --------------------------
  // Supabase helpers
  // --------------------------

  Future<List<Map<String, dynamic>>> _fetchFatherWives(String fatherId) async {
    final response = await SupabaseConfig.client
        .from('marriages')
        .select('id, wife_id, wife_external_name, marriage_order, is_current')
        .eq('husband_id', fatherId)
        .order('marriage_order');

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
    return wives;
  }

  Future<Map<String, dynamic>?> _fetchContact(String personId) async {
    try {
      return await SupabaseConfig.client
          .from('contact_info')
          .select()
          .eq('person_id', personId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<void> _upsertContact(String personId, Map<String, dynamic> data) async {
    final existing = await _fetchContact(personId);
    if (existing != null) {
      await SupabaseConfig.client
          .from('contact_info')
          .update(data)
          .eq('person_id', personId);
    } else {
      await SupabaseConfig.client.from('contact_info').insert({
        'person_id': personId,
        ...data,
      });
    }
  }

  Future<String?> _uploadProfilePhoto(String personId, Uint8List bytes) async {
    try {
      final fileName = 'profile_$personId.jpg';
      final storagePath = 'profiles/$fileName';

      await SupabaseConfig.client.storage.from('photos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      return SupabaseConfig.client.storage.from('photos').getPublicUrl(storagePath);
    } catch (e) {
      print('خطأ في رفع الصورة: $e');
      return null;
    }
  }

  // --------------------------
  // UI
  // --------------------------

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          title: const Text('لوحة التحكم'),
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.textPrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadPeople,
              tooltip: 'تحديث',
            ),
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: _showAddPersonDialog,
                tooltip: 'إضافة شخص',
              ),
          ],
        ),
        body: !_isAdmin
            ? Center(
                child: Text(
                  'ليس لديك صلاحية الوصول',
                  style: TextStyle(color: AppColors.textSecondary.withOpacity(0.8)),
                ),
              )
            : _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'بحث بالاسم أو رقم QF',
                            hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.6)),
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: AppColors.bgCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.gold),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _filteredPeople.isEmpty
                            ? Center(
                                child: Text(
                                  'لا توجد نتائج',
                                  style: TextStyle(color: AppColors.textSecondary.withOpacity(0.8)),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredPeople.length,
                                itemBuilder: (context, index) => _buildPersonTile(_filteredPeople[index]),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPersonTile(Map<String, dynamic> person) {
    final name = (person['name'] as String?) ?? '';
    final legacy = (person['legacy_user_id'] as String?) ?? '';
    final generation = (person['generation'] as int?) ?? 0;
    final gender = (person['gender'] as String?) ?? 'male';
    final photoUrl = _extractPhotoUrl(person);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.bgCard,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: gender == 'female' ? const Color(0xFFE91E8C) : AppColors.primaryGreen,
          backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: (photoUrl == null || photoUrl.isEmpty)
              ? Text(
                  name.isNotEmpty ? name[0] : '؟',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        subtitle: Text(
          '$legacy • الجيل $generation',
          style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_rounded, color: AppColors.gold),
          onPressed: () => _showEditPersonDialog(person),
        ),
      ),
    );
  }

  String? _extractPhotoUrl(Map<String, dynamic> person) {
    final contact = person['contact_info'];
    if (contact is List && contact.isNotEmpty) {
      final first = contact.first;
      if (first is Map<String, dynamic>) {
        return first['photo_url'] as String?;
      }
    } else if (contact is Map<String, dynamic>) {
      return contact['photo_url'] as String?;
    }
    return null;
  }

  // --------------------------
  // Dialogs: Add / Edit person
  // --------------------------

  void _showAddPersonDialog() {
    final nameController = TextEditingController();
    final legacyIdController = TextEditingController();
    final generationController = TextEditingController();

    String gender = 'male';
    bool isAlive = true;

    final fatherQfController = TextEditingController();
    Map<String, dynamic>? selectedFather;

    List<Map<String, dynamic>> fatherWives = [];
    Map<String, dynamic>? selectedMotherMarriage;

    Uint8List? selectedImageBytes;
    String? selectedImageName;
    String? currentPhotoUrl;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: const Text(
              'إضافة شخص',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('الاسم *'),
                  const SizedBox(height: 4),
                  _buildTextField(nameController, 'الاسم'),
                  const SizedBox(height: 12),

                  _buildLabel('رقم QF *'),
                  const SizedBox(height: 4),
                  _buildTextField(legacyIdController, 'QF07023'),
                  const SizedBox(height: 12),

                  _buildLabel('الجيل *'),
                  const SizedBox(height: 4),
                  _buildTextField(generationController, 'مثال: 7', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),

                  _buildLabel('الجنس'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildGenderOption('ذكر', 'male', gender, (v) => setModalState(() => gender = v)),
                      const SizedBox(width: 8),
                      _buildGenderOption('أنثى', 'female', gender, (v) => setModalState(() => gender = v)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildLabel('الحالة'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildToggleChip(
                        label: 'حي',
                        selected: isAlive,
                        onTap: () => setModalState(() => isAlive = true),
                      ),
                      const SizedBox(width: 8),
                      _buildToggleChip(
                        label: 'متوفى',
                        selected: !isAlive,
                        onTap: () => setModalState(() => isAlive = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('الأب (بحث برقم QF)'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(fatherQfController, 'QF...', textDirection: TextDirection.ltr)),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final qf = fatherQfController.text.trim().toUpperCase();
                          if (qf.isEmpty) return;
                          try {
                            final found = await SupabaseConfig.client
                                .from('people')
                                .select('id, name, legacy_user_id')
                                .eq('legacy_user_id', qf)
                                .maybeSingle();
                            if (found == null) {
                              _showError('لم يتم العثور على الأب');
                              return;
                            }
                            setModalState(() {
                              selectedFather = Map<String, dynamic>.from(found);
                              fatherWives = [];
                              selectedMotherMarriage = null;
                            });

                            final wives = await _fetchFatherWives(found['id'] as String);
                            setModalState(() {
                              fatherWives = wives;
                              selectedMotherMarriage = null;
                            });
                          } catch (e) {
                            _showError('خطأ: $e');
                          }
                        },
                        style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgDeep),
                        child: const Text('بحث'),
                      ),
                    ],
                  ),
                  if (selectedFather != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'تم اختيار الأب: ${selectedFather!['name']} (${selectedFather!['legacy_user_id']})',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.8)),
                    ),
                  ],

                  const SizedBox(height: 12),
                  _buildLabel('الأم (من زوجات الأب)'),
                  const SizedBox(height: 4),
                  if (selectedFather == null)
                    _infoBox('اختر الأب أولاً لعرض زوجاته')
                  else if (fatherWives.isEmpty)
                    _warningBox('⚠️ لا توجد زوجات مسجلة لهذا الأب. أضف زوجة من تبويب الزواجات أولاً.')
                  else
                    _motherDropdown(
                      fatherWives: fatherWives,
                      selectedMotherMarriage: selectedMotherMarriage,
                      setSelected: (m) => setModalState(() => selectedMotherMarriage = m),
                    ),

                  const SizedBox(height: 16),
                  _buildLabel('الصورة الشخصية'),
                  const SizedBox(height: 4),
                  _imagePickerRow(
                    context: ctx,
                    selectedImageBytes: selectedImageBytes,
                    currentPhotoUrl: currentPhotoUrl,
                    onPick: (bytes, name) {
                      setModalState(() {
                        selectedImageBytes = bytes;
                        selectedImageName = name;
                      });
                    },
                  ),
                  if ((selectedImageName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      selectedImageName!,
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withOpacity(0.6)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final legacy = legacyIdController.text.trim().toUpperCase();
                  final gen = int.tryParse(generationController.text.trim());

                  if (name.isEmpty) {
                    _showError('الاسم مطلوب');
                    return;
                  }
                  if (legacy.isEmpty) {
                    _showError('رقم QF مطلوب');
                    return;
                  }
                  if (gen == null) {
                    _showError('الجيل غير صحيح');
                    return;
                  }

                  Navigator.pop(ctx);

                  try {
                    final insertData = <String, dynamic>{
                      'name': name,
                      'legacy_user_id': legacy,
                      'gender': gender,
                      'is_alive': isAlive,
                      'generation': gen,
                    };

                    if (selectedFather != null) {
                      insertData['father_id'] = selectedFather!['id'];
                    }

                    // الأم — من زوجات الأب
                    if (selectedMotherMarriage != null) {
                      final wifeId = selectedMotherMarriage!['wife_id'] as String?;
                      if (wifeId != null) {
                        insertData['mother_id'] = wifeId;
                        insertData['mother_external_name'] = null;
                      } else {
                        insertData['mother_id'] = null;
                        insertData['mother_external_name'] = selectedMotherMarriage!['wife_external_name'] as String?;
                      }
                    } else {
                      insertData['mother_id'] = null;
                      insertData['mother_external_name'] = null;
                    }

                    final created = await SupabaseConfig.client
                        .from('people')
                        .insert(insertData)
                        .select()
                        .single();

                    final personId = created['id'] as String;

                    // رفع الصورة إذا تم اختيار صورة جديدة
                    String? photoUrl;
                    if (selectedImageBytes != null) {
                      photoUrl = await _uploadProfilePhoto(personId, selectedImageBytes!);
                    }
                    if (photoUrl != null) {
                      await _upsertContact(personId, {'photo_url': photoUrl});
                    }

                    _showSuccess('تمت الإضافة بنجاح');
                    await _loadPeople();
                  } catch (e) {
                    _showError('خطأ في الإضافة: $e');
                  }
                },
                child: const Text('حفظ', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditPersonDialog(Map<String, dynamic> person) async {
    final id = person['id'] as String;
    final nameController = TextEditingController(text: (person['name'] as String?) ?? '');
    final legacyIdController = TextEditingController(text: (person['legacy_user_id'] as String?) ?? '');
    final generationController = TextEditingController(text: ((person['generation'] as int?) ?? 0).toString());

    String gender = (person['gender'] as String?) ?? 'male';
    bool isAlive = (person['is_alive'] as bool?) ?? true;

    // الأب
    final fatherQfController = TextEditingController();
    Map<String, dynamic>? selectedFather;
    if (person['father_id'] != null) {
      try {
        final father = await SupabaseConfig.client
            .from('people')
            .select('id, name, legacy_user_id')
            .eq('id', person['father_id'])
            .maybeSingle();
        if (father != null) {
          selectedFather = Map<String, dynamic>.from(father);
          fatherQfController.text = (father['legacy_user_id'] as String?) ?? '';
        }
      } catch (_) {}
    }

    // الأم — من زوجات الأب
    List<Map<String, dynamic>> fatherWives = [];
    Map<String, dynamic>? selectedMotherMarriage;
    bool fatherWivesLoaded = false;

    // الصورة
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    String? currentPhotoUrl;
    final contact = await _fetchContact(id);
    currentPhotoUrl = contact?['photo_url'] as String?;

    // أبناء البنت
    List<Map<String, dynamic>> girlChildren = [];
    bool girlChildrenLoaded = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // تحميل زوجات الأب مرة واحدة عند فتح التعديل
          if (selectedFather != null && !fatherWivesLoaded) {
            fatherWivesLoaded = true;
            _fetchFatherWives(selectedFather!['id'] as String).then((wives) {
              setModalState(() {
                fatherWives = wives;
                selectedMotherMarriage = null;

                // بعد تحميل fatherWives، حدد الأم الحالية
                if (person['mother_id'] != null) {
                  selectedMotherMarriage = fatherWives.firstWhere(
                    (w) => w['wife_id'] == person['mother_id'],
                    orElse: () => <String, dynamic>{},
                  );
                  if (selectedMotherMarriage!.isEmpty) selectedMotherMarriage = null;
                } else if (person['mother_external_name'] != null &&
                    (person['mother_external_name'] as String).isNotEmpty) {
                  selectedMotherMarriage = fatherWives.firstWhere(
                    (w) => w['wife_external_name'] == person['mother_external_name'],
                    orElse: () => <String, dynamic>{},
                  );
                  if (selectedMotherMarriage!.isEmpty) selectedMotherMarriage = null;
                }
              });
            });
          }

          // تحميل أبناء البنت (مرة واحدة) داخل builder
          if (gender == 'female' && !girlChildrenLoaded) {
            girlChildrenLoaded = true;
            SupabaseConfig.client
                .from('girls_children')
                .select()
                .eq('mother_id', id)
                .then((response) {
              girlChildren = List<Map<String, dynamic>>.from(response);
              setModalState(() {});
            }).catchError((e) {
              print('خطأ في تحميل أبناء البنت: $e');
            });
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: AppColors.bgCard,
              title: const Text(
                'تعديل الشخص',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('الاسم *'),
                    const SizedBox(height: 4),
                    _buildTextField(nameController, 'الاسم'),
                    const SizedBox(height: 12),

                    _buildLabel('رقم QF *'),
                    const SizedBox(height: 4),
                    _buildTextField(legacyIdController, 'QF07023'),
                    const SizedBox(height: 12),

                    _buildLabel('الجيل *'),
                    const SizedBox(height: 4),
                    _buildTextField(generationController, 'مثال: 7', keyboardType: TextInputType.number),
                    const SizedBox(height: 12),

                    _buildLabel('الجنس'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildGenderOption('ذكر', 'male', gender, (v) => setModalState(() => gender = v)),
                        const SizedBox(width: 8),
                        _buildGenderOption('أنثى', 'female', gender, (v) => setModalState(() => gender = v)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildLabel('الحالة'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildToggleChip(
                          label: 'حي',
                          selected: isAlive,
                          onTap: () => setModalState(() => isAlive = true),
                        ),
                        const SizedBox(width: 8),
                        _buildToggleChip(
                          label: 'متوفى',
                          selected: !isAlive,
                          onTap: () => setModalState(() => isAlive = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildLabel('الأب (بحث برقم QF)'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(fatherQfController, 'QF...', textDirection: TextDirection.ltr)),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final qf = fatherQfController.text.trim().toUpperCase();
                            if (qf.isEmpty) return;
                            try {
                              final found = await SupabaseConfig.client
                                  .from('people')
                                  .select('id, name, legacy_user_id')
                                  .eq('legacy_user_id', qf)
                                  .maybeSingle();
                              if (found == null) {
                                _showError('لم يتم العثور على الأب');
                                return;
                              }
                              setModalState(() {
                                selectedFather = Map<String, dynamic>.from(found);
                                fatherWives = [];
                                selectedMotherMarriage = null;
                                fatherWivesLoaded = true;
                              });

                              final wives = await _fetchFatherWives(found['id'] as String);
                              setModalState(() {
                                fatherWives = wives;
                                selectedMotherMarriage = null;
                              });
                            } catch (e) {
                              _showError('خطأ: $e');
                            }
                          },
                          style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.bgDeep),
                          child: const Text('بحث'),
                        ),
                      ],
                    ),
                    if (selectedFather != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'تم اختيار الأب: ${selectedFather!['name']} (${selectedFather!['legacy_user_id']})',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.8)),
                      ),
                    ],

                    const SizedBox(height: 12),
                    _buildLabel('الأم (من زوجات الأب)'),
                    const SizedBox(height: 4),
                    if (selectedFather == null)
                      _infoBox('اختر الأب أولاً لعرض زوجاته')
                    else if (fatherWives.isEmpty)
                      _warningBox('⚠️ لا توجد زوجات مسجلة لهذا الأب. أضف زوجة من تبويب الزواجات أولاً.')
                    else
                      _motherDropdown(
                        fatherWives: fatherWives,
                        selectedMotherMarriage: selectedMotherMarriage,
                        setSelected: (m) => setModalState(() => selectedMotherMarriage = m),
                      ),

                    const SizedBox(height: 16),
                    _buildLabel('الصورة الشخصية'),
                    const SizedBox(height: 4),
                    _imagePickerRow(
                      context: ctx,
                      selectedImageBytes: selectedImageBytes,
                      currentPhotoUrl: currentPhotoUrl,
                      onPick: (bytes, name) {
                        setModalState(() {
                          selectedImageBytes = bytes;
                          selectedImageName = name;
                        });
                      },
                    ),
                    if ((selectedImageName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        selectedImageName!,
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withOpacity(0.6)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // أبناء البنت — تبسيط (بدون أي حفظ في marriages)
                    if (gender == 'female') ...[
                      const SizedBox(height: 20),
                      Container(height: 1, color: Colors.white.withOpacity(0.06)),
                      const SizedBox(height: 16),
                      const Text(
                        'أبناء البنت',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE91E8C)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'أبناء البنت لا يدخلون في شجرة العائلة الرئيسية',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.6)),
                      ),
                      const SizedBox(height: 12),
                      if (girlChildren.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.bgDeep.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'لا يوجد أبناء مسجلين',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withOpacity(0.7)),
                          ),
                        )
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
                                  (child['child_gender'] as String? ?? 'male') == 'male'
                                      ? Icons.male_rounded
                                      : Icons.female_rounded,
                                  color: (child['child_gender'] as String? ?? 'male') == 'male' ? Colors.blue : Colors.pink,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        child['child_name'] as String? ?? '—',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if ((child['father_name'] as String? ?? '').isNotEmpty)
                                        Text(
                                          'الأب: ${child['father_name']}',
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.7)),
                                        ),
                                    ],
                                  ),
                                ),
                                if (child['child_birthdate'] != null)
                                  Text(
                                    child['child_birthdate'] as String? ?? '',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.7)),
                                  ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () async {
                                    try {
                                      await SupabaseConfig.client.from('girls_children').delete().eq('id', child['id']);
                                      girlChildren.removeWhere((c) => c['id'] == child['id']);
                                      setModalState(() {});
                                      _showSuccess('تم حذف ${child['child_name']}');
                                    } catch (e) {
                                      _showError('خطأ: $e');
                                    }
                                  },
                                  child: const Icon(Icons.close_rounded, color: AppColors.accentRed, size: 16),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _showAddGirlChildDialog(id, setModalState, girlChildren),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91E8C).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE91E8C).withOpacity(0.2)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, color: Color(0xFFE91E8C), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'إضافة ابن / بنت',
                                style: TextStyle(color: Color(0xFFE91E8C), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
                ),
                TextButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final legacy = legacyIdController.text.trim().toUpperCase();
                    final gen = int.tryParse(generationController.text.trim());

                    if (name.isEmpty) {
                      _showError('الاسم مطلوب');
                      return;
                    }
                    if (legacy.isEmpty) {
                      _showError('رقم QF مطلوب');
                      return;
                    }
                    if (gen == null) {
                      _showError('الجيل غير صحيح');
                      return;
                    }

                    Navigator.pop(ctx);

                    try {
                      final updateData = <String, dynamic>{
                        'name': name,
                        'legacy_user_id': legacy,
                        'gender': gender,
                        'is_alive': isAlive,
                        'generation': gen,
                      };

                      updateData['father_id'] = selectedFather?['id'];

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

                      await SupabaseConfig.client.from('people').update(updateData).eq('id', id);

                      String? photoUrl = currentPhotoUrl;
                      if (selectedImageBytes != null) {
                        final uploaded = await _uploadProfilePhoto(id, selectedImageBytes!);
                        if (uploaded != null && uploaded.isNotEmpty) {
                          photoUrl = uploaded;
                        }
                      }
                      if (photoUrl != currentPhotoUrl) {
                        await _upsertContact(id, {'photo_url': photoUrl});
                      }

                      _showSuccess('تم الحفظ');
                      await _loadPeople();
                    } catch (e) {
                      _showError('خطأ في الحفظ: $e');
                    }
                  },
                  child: const Text('حفظ', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --------------------------
  // Girl children dialog
  // --------------------------

  void _showAddGirlChildDialog(
    String motherId,
    StateSetter parentSetState,
    List<Map<String, dynamic>> girlChildren,
  ) {
    final childNameController = TextEditingController();
    final fatherNameController = TextEditingController();
    String childGender = 'male';
    DateTime? childBirthdate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: const Text(
              'إضافة ابن/بنت',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('اسم الطفل *'),
                  const SizedBox(height: 4),
                  _buildTextField(childNameController, 'الاسم'),
                  const SizedBox(height: 12),

                  _buildLabel('اسم الأب *'),
                  const SizedBox(height: 4),
                  _buildTextField(fatherNameController, 'اسم أبو الطفل'),
                  const SizedBox(height: 12),

                  _buildLabel('الجنس'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildGenderOption('ذكر', 'male', childGender, (val) => setDialogState(() => childGender = val)),
                      const SizedBox(width: 8),
                      _buildGenderOption('أنثى', 'female', childGender, (val) => setDialogState(() => childGender = val)),
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
                            : 'اختر التاريخ',
                        style: TextStyle(
                          fontSize: 14,
                          color: childBirthdate != null ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () async {
                  if (childNameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اسم الطفل مطلوب'), backgroundColor: AppColors.accentRed),
                    );
                    return;
                  }
                  if (fatherNameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('اسم الأب مطلوب'), backgroundColor: AppColors.accentRed),
                    );
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
                      insertData['child_birthdate'] = childBirthdate!.toIso8601String().split('T')[0];
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
                    _showError('خطأ في الإضافة: $e');
                  }
                },
                child: const Text('إضافة', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------
  // Small UI helpers
  // --------------------------

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    TextDirection? textDirection,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: textDirection,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.bgDeep.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildGenderOption(String label, String value, String current, ValueChanged<String> onChanged) {
    final selected = current == value;
    final color = value == 'female' ? const Color(0xFFE91E8C) : AppColors.accentBlue;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : AppColors.bgDeep.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : Colors.white.withOpacity(0.06)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleChip({required String label, required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withOpacity(0.15) : AppColors.bgDeep.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.gold : Colors.white.withOpacity(0.06)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.gold : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7)),
      ),
    );
  }

  Widget _warningBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentAmber.withOpacity(0.2)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.accentAmber)),
    );
  }

  Widget _motherDropdown({
    required List<Map<String, dynamic>> fatherWives,
    required Map<String, dynamic>? selectedMotherMarriage,
    required ValueChanged<Map<String, dynamic>> setSelected,
  }) {
    final selectedIndex = selectedMotherMarriage != null ? fatherWives.indexOf(selectedMotherMarriage) : -1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedIndex >= 0 ? selectedIndex : null,
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
              setSelected(fatherWives[index]);
            }
          },
        ),
      ),
    );
  }

  Widget _imagePickerRow({
    required BuildContext context,
    required Uint8List? selectedImageBytes,
    required String? currentPhotoUrl,
    required void Function(Uint8List bytes, String name) onPick,
  }) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.bgDeep.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            image: selectedImageBytes != null
                ? DecorationImage(image: MemoryImage(selectedImageBytes), fit: BoxFit.cover)
                : (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty)
                    ? DecorationImage(image: NetworkImage(currentPhotoUrl), fit: BoxFit.cover)
                    : null,
          ),
          child: (selectedImageBytes == null && (currentPhotoUrl == null || currentPhotoUrl.isEmpty))
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
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الصورة كبيرة جداً. الحد الأقصى 500 كيلوبايت'),
                          backgroundColor: AppColors.accentRed,
                        ),
                      );
                      return;
                    }
                    onPick(bytes, picked.name);
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
                'الحد الأقصى: 400×400 بكسل، 500 كيلوبايت',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.accentGreen),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.accentRed),
    );
  }
}

