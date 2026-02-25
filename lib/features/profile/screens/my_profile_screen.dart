import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/current_user.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isLoading = true;
  String? _error;

  // بيانات الشخص
  Map<String, dynamic>? _personData;
  Map<String, dynamic>? _contactData;
  List<Map<String, dynamic>> _children = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // جلب بيانات الشخص
      final personResponse = await SupabaseConfig.client
          .from('people')
          .select()
          .eq('legacy_user_id', CurrentUser.legacyUserId)
          .maybeSingle();

      if (personResponse == null) {
        setState(() {
          _error = 'لم يتم العثور على بياناتك';
          _isLoading = false;
        });
        return;
      }

      _personData = personResponse;

      // جلب بيانات التواصل
      try {
        final contactResponse = await SupabaseConfig.client
            .from('contact_info')
            .select()
            .eq('person_id', _personData!['id'])
            .maybeSingle();
        _contactData = contactResponse;
      } catch (e) {
        print('⚠️ لا توجد بيانات تواصل: $e');
      }

      // جلب الأبناء
      try {
        final childrenResponse = await SupabaseConfig.client
            .from('people')
            .select('id, name, gender, is_alive, birth_date, legacy_user_id')
            .eq('father_id', _personData!['id'])
            .order('birth_date', ascending: true);
        _children = List<Map<String, dynamic>>.from(childrenResponse);
      } catch (e) {
        print('⚠️ خطأ في جلب الأبناء: $e');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          title: const Text('حسابي'),
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          actions: [
            if (_personData != null)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.gold,
                onPressed: _loadProfile,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _loadProfile,
                    color: AppColors.gold,
                    backgroundColor: AppColors.bgCard,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _buildProfileHeader(),
                          const SizedBox(height: 20),
                          _buildPersonalInfo(),
                          const SizedBox(height: 16),
                          _buildContactInfo(),
                          const SizedBox(height: 16),
                          _buildSocialMedia(),
                          const SizedBox(height: 16),
                          _buildChildrenSection(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // الهيدر - الصورة والاسم
  // ═══════════════════════════════════════════
  Widget _buildProfileHeader() {
    final name = _personData?['name'] ?? '';
    final photoUrl = _contactData?['photo_url'] as String?;
    final legacyId = _personData?['legacy_user_id'] ?? '';
    final generation = _personData?['generation'] ?? 0;
    final isAlive = _personData?['is_alive'] ?? true;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          // الصورة
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.gold.withOpacity(0.2),
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0] : '؟',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: GestureDetector(
                  onTap: () => _showEditPhotoDialog(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgCard, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: AppColors.bgDeep,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // الاسم
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // المعرّف والجيل
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  legacyId,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'الجيل $generation',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (isAlive ? AppColors.accentGreen : AppColors.neutralGray).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAlive ? 'حي' : 'متوفى',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAlive ? AppColors.accentGreen : AppColors.neutralGray,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // البيانات الشخصية
  // ═══════════════════════════════════════════
  Widget _buildPersonalInfo() {
    return _buildSection(
      title: 'البيانات الشخصية',
      icon: Icons.person_rounded,
      onEdit: () => _showEditPersonalDialog(),
      children: [
        _buildInfoRow(Icons.badge_rounded, 'الاسم', _personData?['name'] ?? '-'),
        _buildInfoRow(Icons.people_rounded, 'الجنس', _personData?['gender'] == 'male' ? 'ذكر' : 'أنثى'),
        _buildInfoRow(Icons.cake_rounded, 'تاريخ الميلاد', _formatDateStr(_personData?['birth_date'])),
        _buildInfoRow(Icons.location_city_rounded, 'مدينة الميلاد', _personData?['birth_city'] ?? '-'),
        _buildInfoRow(Icons.public_rounded, 'بلد الميلاد', _personData?['birth_country'] ?? '-'),
        _buildInfoRow(Icons.home_rounded, 'مدينة الإقامة', _personData?['residence_city'] ?? '-'),
        _buildInfoRow(Icons.work_rounded, 'الوظيفة', _personData?['job'] ?? '-'),
        _buildInfoRow(Icons.school_rounded, 'التعليم', _personData?['education'] ?? '-'),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // بيانات التواصل
  // ═══════════════════════════════════════════
  Widget _buildContactInfo() {
    final phone = _contactData?['mobile_phone'] as String?;
    final email = _contactData?['email'] as String?;

    return _buildSection(
      title: 'بيانات التواصل',
      icon: Icons.contact_phone_rounded,
      onEdit: () => _showEditContactDialog(),
      children: [
        _buildInfoRow(Icons.phone_rounded, 'الجوال', phone ?? '-'),
        _buildInfoRow(Icons.email_rounded, 'الإيميل', email ?? '-'),
        if (phone != null && phone.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'اتصال',
                  icon: Icons.phone_rounded,
                  color: AppColors.accentGreen,
                  onTap: () => _launchUrl('tel:$phone'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  label: 'واتساب',
                  icon: Icons.chat_rounded,
                  color: const Color(0xFF25D366),
                  onTap: () {
                    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
                    _launchUrl('https://wa.me/$cleaned');
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════
  // وسائل التواصل الاجتماعي
  // ═══════════════════════════════════════════
  Widget _buildSocialMedia() {
    final instagram = _contactData?['instagram'] as String?;
    final twitter = _contactData?['twitter'] as String?;
    final snapchat = _contactData?['snapchat'] as String?;
    final facebook = _contactData?['facebook'] as String?;

    return _buildSection(
      title: 'وسائل التواصل الاجتماعي',
      icon: Icons.public_rounded,
      onEdit: () => _showEditSocialDialog(),
      children: [
        _buildInfoRow(Icons.camera_alt_rounded, 'Instagram', instagram ?? '-'),
        _buildInfoRow(Icons.alternate_email_rounded, 'Twitter', twitter ?? '-'),
        _buildInfoRow(Icons.photo_camera_front_rounded, 'Snapchat', snapchat ?? '-'),
        _buildInfoRow(Icons.facebook_rounded, 'Facebook', facebook ?? '-'),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // الأبناء
  // ═══════════════════════════════════════════
  Widget _buildChildrenSection() {
    return _buildSection(
      title: 'الأبناء (${_children.length})',
      icon: Icons.family_restroom_rounded,
      onEdit: null,
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_rounded, color: AppColors.gold),
        onPressed: () => _showAddChildDialog(),
        tooltip: 'إضافة ابن/ابنة',
      ),
      children: [
        if (_children.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            child: const Center(
              child: Text(
                'لا يوجد أبناء مسجلين',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ..._children.map((child) => _buildChildTile(child)),
      ],
    );
  }

  Widget _buildChildTile(Map<String, dynamic> child) {
    final name = child['name'] as String? ?? '';
    final gender = child['gender'] as String? ?? 'male';
    final isAlive = child['is_alive'] as bool? ?? true;
    final legacyId = child['legacy_user_id'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: gender == 'female'
                ? const Color(0xFFE91E8C).withOpacity(0.15)
                : AppColors.accentBlue.withOpacity(0.15),
            child: Icon(
              gender == 'female' ? Icons.girl_rounded : Icons.boy_rounded,
              size: 20,
              color: gender == 'female' ? const Color(0xFFE91E8C) : AppColors.accentBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (legacyId != null)
                  Text(
                    legacyId,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (isAlive ? AppColors.accentGreen : AppColors.neutralGray).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isAlive ? 'حي' : 'متوفى',
              style: TextStyle(
                fontSize: 10,
                color: isAlive ? AppColors.accentGreen : AppColors.neutralGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ديالوج تعديل البيانات الشخصية
  // ═══════════════════════════════════════════
  void _showEditPersonalDialog() {
    final nameCtrl = TextEditingController(text: _personData?['name'] ?? '');
    final jobCtrl = TextEditingController(text: _personData?['job'] ?? '');
    final educationCtrl = TextEditingController(text: _personData?['education'] ?? '');
    final residenceCtrl = TextEditingController(text: _personData?['residence_city'] ?? '');

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
            top: 24, right: 24, left: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text('تعديل البيانات الشخصية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                _buildTextField(nameCtrl, 'الاسم', Icons.badge_rounded),
                _buildTextField(jobCtrl, 'الوظيفة', Icons.work_rounded),
                _buildTextField(educationCtrl, 'التعليم', Icons.school_rounded),
                _buildTextField(residenceCtrl, 'مدينة الإقامة', Icons.home_rounded),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await _updatePersonData({
                        'name': nameCtrl.text.trim(),
                        'job': jobCtrl.text.trim().isEmpty ? null : jobCtrl.text.trim(),
                        'education': educationCtrl.text.trim().isEmpty ? null : educationCtrl.text.trim(),
                        'residence_city': residenceCtrl.text.trim().isEmpty ? null : residenceCtrl.text.trim(),
                      });
                      if (mounted) Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ديالوج تعديل بيانات التواصل
  // ═══════════════════════════════════════════
  void _showEditContactDialog() {
    final phoneCtrl = TextEditingController(text: _contactData?['mobile_phone'] ?? '');
    final emailCtrl = TextEditingController(text: _contactData?['email'] ?? '');

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
            top: 24, right: 24, left: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text('تعديل بيانات التواصل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                _buildTextField(phoneCtrl, 'رقم الجوال', Icons.phone_rounded, keyboardType: TextInputType.phone),
                _buildTextField(emailCtrl, 'الإيميل', Icons.email_rounded, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await _updateContactData({
                        'mobile_phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                        'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                      });
                      if (mounted) Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ديالوج تعديل وسائل التواصل الاجتماعي
  // ═══════════════════════════════════════════
  void _showEditSocialDialog() {
    final instagramCtrl = TextEditingController(text: _contactData?['instagram'] ?? '');
    final twitterCtrl = TextEditingController(text: _contactData?['twitter'] ?? '');
    final snapchatCtrl = TextEditingController(text: _contactData?['snapchat'] ?? '');
    final facebookCtrl = TextEditingController(text: _contactData?['facebook'] ?? '');

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
            top: 24, right: 24, left: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text('تعديل وسائل التواصل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                _buildTextField(instagramCtrl, 'Instagram', Icons.camera_alt_rounded),
                _buildTextField(twitterCtrl, 'Twitter', Icons.alternate_email_rounded),
                _buildTextField(snapchatCtrl, 'Snapchat', Icons.photo_camera_front_rounded),
                _buildTextField(facebookCtrl, 'Facebook', Icons.facebook_rounded),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await _updateContactData({
                        'instagram': instagramCtrl.text.trim().isEmpty ? null : instagramCtrl.text.trim(),
                        'twitter': twitterCtrl.text.trim().isEmpty ? null : twitterCtrl.text.trim(),
                        'snapchat': snapchatCtrl.text.trim().isEmpty ? null : snapchatCtrl.text.trim(),
                        'facebook': facebookCtrl.text.trim().isEmpty ? null : facebookCtrl.text.trim(),
                      });
                      if (mounted) Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ديالوج إضافة ابن
  // ═══════════════════════════════════════════
  void _showAddChildDialog() {
    final nameCtrl = TextEditingController();
    String selectedGender = 'male';
    DateTime? selectedBirthDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              top: 24, right: 24, left: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text('إضافة ابن / ابنة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 20),
                  _buildTextField(nameCtrl, 'الاسم', Icons.badge_rounded),

                  // اختيار الجنس
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedGender = 'male'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: selectedGender == 'male' ? AppColors.accentBlue.withOpacity(0.15) : AppColors.bgDeep.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedGender == 'male' ? AppColors.accentBlue : Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '👦 ذكر',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: selectedGender == 'male' ? AppColors.accentBlue : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedGender = 'female'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: selectedGender == 'female' ? const Color(0xFFE91E8C).withOpacity(0.15) : AppColors.bgDeep.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedGender == 'female' ? const Color(0xFFE91E8C) : Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '👧 أنثى',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: selectedGender == 'female' ? const Color(0xFFE91E8C) : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // تاريخ الميلاد
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.gold,
                              surface: AppColors.bgCard,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (date != null) {
                        setDialogState(() => selectedBirthDate = date);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cake_rounded, color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            selectedBirthDate != null
                                ? '${selectedBirthDate!.day}/${selectedBirthDate!.month}/${selectedBirthDate!.year}'
                                : 'تاريخ الميلاد (اختياري)',
                            style: TextStyle(
                              fontSize: 14,
                              color: selectedBirthDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('الرجاء إدخال الاسم')),
                          );
                          return;
                        }
                        await _addChild(
                          name: nameCtrl.text.trim(),
                          gender: selectedGender,
                          birthDate: selectedBirthDate,
                        );
                        if (mounted) Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('إضافة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  void _showEditPhotoDialog() {
    final urlCtrl = TextEditingController(text: _contactData?['photo_url'] ?? '');

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
            top: 24, right: 24, left: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('تعديل الصورة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              _buildTextField(urlCtrl, 'رابط الصورة', Icons.link_rounded),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await _updateContactData({
                      'photo_url': urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                    });
                    if (mounted) Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgDeep,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('حفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // عمليات Supabase
  // ═══════════════════════════════════════════
  Future<void> _updatePersonData(Map<String, dynamic> data) async {
    try {
      await SupabaseConfig.client
          .from('people')
          .update(data)
          .eq('id', _personData!['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم تحديث البيانات بنجاح')),
      );
      _loadProfile();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في التحديث: $e')),
      );
    }
  }

  Future<void> _updateContactData(Map<String, dynamic> data) async {
    try {
      if (_contactData != null) {
        // تحديث
        await SupabaseConfig.client
            .from('contact_info')
            .update(data)
            .eq('person_id', _personData!['id']);
      } else {
        // إنشاء جديد
        await SupabaseConfig.client
            .from('contact_info')
            .insert({
          'person_id': _personData!['id'],
          ...data,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم تحديث بيانات التواصل بنجاح')),
      );
      _loadProfile();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في التحديث: $e')),
      );
    }
  }

  Future<void> _addChild({
    required String name,
    required String gender,
    DateTime? birthDate,
  }) async {
    try {
      // حساب الجيل (جيل الأب + 1)
      final parentGeneration = _personData?['generation'] as int? ?? 0;

      await SupabaseConfig.client.from('people').insert({
        'name': name,
        'gender': gender,
        'father_id': _personData!['id'],
        'generation': parentGeneration + 1,
        'is_alive': true,
        'birth_date': birthDate?.toIso8601String().split('T').first,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تمت إضافة $name بنجاح')),
      );
      _loadProfile();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في الإضافة: $e')),
      );
    }
  }

  // ═══════════════════════════════════════════
  // Widgets المساعدة
  // ═══════════════════════════════════════════
  Widget _buildSection({
    required String title,
    required IconData icon,
    required VoidCallback? onEdit,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing,
                if (onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, size: 14, color: AppColors.gold),
                          SizedBox(width: 4),
                          Text('تعديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
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
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
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
            const Icon(Icons.error_outline, size: 64, color: AppColors.accentRed),
            const SizedBox(height: 16),
            Text(_error ?? 'حدث خطأ', style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loadProfile,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateStr(dynamic dateStr) {
    if (dateStr == null) return '-';
    final s = dateStr.toString().trim();
    if (s.isEmpty) return '-';
    try {
      final date = DateTime.parse(s);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return s;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
