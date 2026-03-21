import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart';
import 'dart:typed_data';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/current_user.dart';
import '../../auth/services/auth_service.dart';
import '../services/person_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../../screens/home_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme_provider.dart';

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
  List<Map<String, dynamic>> _marriages = [];
  Uint8List? _selectedImageBytes;
  int _photoCacheKey = 0;

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
      await CurrentUser.loadFromSession();
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
      } catch (e) {}

      // جلب الأبناء
      try {
        final childrenResponse = await SupabaseConfig.client
            .from('people')
            .select('id, name, gender, is_alive, birth_date, legacy_user_id, mother_id, mother_external_name')
            .eq('father_id', _personData!['id']);
        final rawChildren = List<Map<String, dynamic>>.from(childrenResponse);
        rawChildren.sort((a, b) {
          final aDate = a['birth_date'] as String?;
          final bDate = b['birth_date'] as String?;
          if (aDate != null && bDate != null) return aDate.compareTo(bDate);
          if (aDate != null) return -1;
          if (bDate != null) return 1;
          final aId = a['legacy_user_id'] as String? ?? '';
          final bId = b['legacy_user_id'] as String? ?? '';
          return aId.compareTo(bId);
        });
        _children = rawChildren;
      } catch (e) {}

      await _loadMarriages();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMarriages() async {
    if (_personData == null) return;
    final personId = _personData!['id'] as String;
    final gender = _personData!['gender'] as String? ?? 'male';

    try {
      List<dynamic> response;
      if (gender == 'male') {
        response = await SupabaseConfig.client
            .from('marriages')
            .select('id, wife_id, wife_external_name, marriage_order, marriage_date, is_current')
            .eq('husband_id', personId)
            .order('marriage_order');
      } else {
        response = await SupabaseConfig.client
            .from('marriages')
            .select('id, husband_id, marriage_order, marriage_date, is_current')
            .eq('wife_id', personId)
            .order('marriage_order');
      }

      final marriagesWithNames = <Map<String, dynamic>>[];
      for (final marriage in response) {
        final m = Map<String, dynamic>.from(marriage);

        if (gender == 'male') {
          final wifeId = m['wife_id'] as String?;
          if (wifeId != null) {
            final wife = await SupabaseConfig.client
                .from('people')
                .select('name')
                .eq('id', wifeId)
                .maybeSingle();
            m['wife_name'] = wife?['name'] ?? 'غير معروفة';
            m['is_external'] = false;
          } else {
            m['wife_name'] = m['wife_external_name'] ?? 'غير معروفة';
            m['is_external'] = true;
          }
        } else {
          final husbandId = m['husband_id'] as String?;
          if (husbandId != null) {
            final husband = await SupabaseConfig.client
                .from('people')
                .select('name')
                .eq('id', husbandId)
                .maybeSingle();
            m['husband_name'] = husband?['name'] ?? 'غير معروف';
          }
        }

        marriagesWithNames.add(m);
      }

      if (mounted) {
        setState(() => _marriages = marriagesWithNames);
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          title: Text('حسابي'),
          backgroundColor: AppColors.bgDeep,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          actions: [
            if (_personData != null)
              IconButton(
                icon: Icon(Icons.refresh_rounded),
                color: AppColors.gold,
                onPressed: _loadProfile,
              ),
          ],
        ),
        body: _isLoading
            ? Center(
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
                          SizedBox(height: 20),
                          _buildPersonalInfo(),
                          SizedBox(height: 16),
                          _buildContactInfo(),
                          SizedBox(height: 16),
                          _buildSocialMedia(),
                          SizedBox(height: 16),
                          _buildMarriagesSection(),
                          SizedBox(height: 16),
                          _buildChildrenSection(),
                          SizedBox(height: 16),
                          _buildThemeSection(),
                          SizedBox(height: 8),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _showChangePinDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.gold,
                                side: BorderSide(color: AppColors.gold.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('تغيير الرقم السري', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: AlertDialog(
                                      backgroundColor: AppColors.bgCard,
                                      title: Text('تسجيل الخروج', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                                      content: Text('هل تريد تسجيل الخروج من التطبيق؟', style: TextStyle(color: AppColors.textSecondary)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: Text('خروج', style: TextStyle(color: AppColors.accentRed)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                if (confirm == true && mounted) {
                                  await AuthService.logout();
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                    (route) => false,
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentRed,
                                side: BorderSide(color: AppColors.accentRed.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('تسجيل الخروج', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 30),
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
    final rawPhotoUrl = _personData?['photo_url'] as String?;
    final photoUrl = rawPhotoUrl != null && rawPhotoUrl.isNotEmpty
        ? '$rawPhotoUrl?v=$_photoCacheKey'
        : null;
    final legacyId = _personData?['legacy_user_id'] ?? '';
    final generation = _personData?['generation'] ?? 0;
    final isAlive = _personData?['is_alive'] ?? true;
    final currentPersonId = _personData?['id'] as String?;

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
                        style: TextStyle(
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
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 400,
                      maxHeight: 400,
                      imageQuality: 70,
                    );
                    if (picked == null) return;
                    final bytes = await picked.readAsBytes();
                    if (bytes.length > 500 * 1024) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('الصورة كبيرة جداً. الحد الأقصى 500 كيلوبايت'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }
                    try {
                      final personId = _personData!['id'] as String;
                      final url = await PersonService.uploadPhoto(personId, bytes);
                      if (url != null) {
                        await _loadProfile();
                        if (mounted) setState(() => _photoCacheKey++);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('خطأ في رفع الصورة'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطأ في رفع الصورة: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgCard, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: AppColors.bgDeep,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // الاسم
          Text(
            name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),

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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'الجيل $generation',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentBlue,
                  ),
                ),
              ),
              SizedBox(width: 8),
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
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                if (currentPersonId == null) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(initialIndex: 1, highlightPersonId: currentPersonId),
                  ),
                  (route) => false,
                );
              },
              icon: Icon(Icons.account_tree_rounded, size: 18),
              label: Text('عرض في شجرة العائلة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: BorderSide(color: AppColors.primaryGreen.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
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
          SizedBox(height: 12),
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
              SizedBox(width: 10),
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
        SizedBox(height: 12),
        Divider(color: Colors.white.withOpacity(0.06)),
        SizedBox(height: 8),
        Text('إعدادات الخصوصية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        SizedBox(height: 4),
        _buildPrivacyToggle('إظهار رقم الجوال', 'show_mobile', _contactData?['show_mobile'] ?? true),
        _buildPrivacyToggle('إظهار الإيميل', 'show_email', _contactData?['show_email'] ?? true),
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
        SizedBox(height: 12),
        Divider(color: Colors.white.withOpacity(0.06)),
        SizedBox(height: 8),
        Text('إعدادات الخصوصية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        SizedBox(height: 4),
        _buildPrivacyToggle('إظهار Instagram', 'show_instagram', _contactData?['show_instagram'] ?? true),
        _buildPrivacyToggle('إظهار Twitter', 'show_twitter', _contactData?['show_twitter'] ?? true),
        _buildPrivacyToggle('إظهار Snapchat', 'show_snapchat', _contactData?['show_snapchat'] ?? true),
        _buildPrivacyToggle('إظهار Facebook', 'show_facebook', _contactData?['show_facebook'] ?? true),
      ],
    );
  }

  Widget _buildPrivacyToggle(String label, String field, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          Switch(
            value: value,
            activeTrackColor: AppColors.gold,
            onChanged: (newValue) async {
              try {
                await PersonService.upsertContact(_personData!['id'] as String, {field: newValue});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ تم تحديث بيانات التواصل بنجاح')),
                  );
                  _loadProfile();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ خطأ في التحديث: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
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
        icon: Icon(Icons.add_circle_rounded, color: AppColors.gold),
        onPressed: () => _showAddChildDialog(),
        tooltip: 'إضافة ابن/ابنة',
      ),
      children: [
        if (_children.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            child: Center(
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

  Widget _buildMarriagesSection() {
    final gender = _personData?['gender'] as String? ?? 'male';
    final title = gender == 'male' ? 'الزوجات' : 'الأزواج';
    final icon = Icons.favorite_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E8C).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFE91E8C), size: 18),
              ),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '${_marriages.length}',
                style: TextStyle(fontSize: 13, color: AppColors.gold, fontWeight: FontWeight.w600),
              ),
              SizedBox(width: 8),
              if (_personData?['gender'] == 'male')
                GestureDetector(
                  onTap: _showAddMarriageDialog,
                  child: Icon(Icons.add_circle_rounded, color: const Color(0xFFE91E8C), size: 24),
                ),
            ],
          ),

          if (_marriages.isEmpty) ...[
            SizedBox(height: 16),
            Center(
              child: Text(
                'لا توجد بيانات زواج مسجلة',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withOpacity(0.7)),
              ),
            ),
          ] else ...[
            SizedBox(height: 12),
            ..._marriages.asMap().entries.map((entry) {
              final index = entry.key;
              final marriage = entry.value;
              return _buildMarriageCard(marriage, index, gender);
            }),
          ],

          if (gender == 'male' && _isCurrentUser()) ...[
            SizedBox(height: 12),
            GestureDetector(
              onTap: _showAddMarriageDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: AppColors.gold, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'إضافة زوجة',
                      style: TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarriageCard(Map<String, dynamic> marriage, int index, String gender) {
    final name = gender == 'male'
        ? marriage['wife_name'] as String? ?? 'غير معروفة'
        : marriage['husband_name'] as String? ?? 'غير معروف';
    final isExternal = marriage['is_external'] as bool? ?? false;
    final isCurrent = marriage['is_current'] as bool? ?? true;
    final order = marriage['marriage_order'] as int? ?? (index + 1);
    final marriageDate = marriage['marriage_date'] as String? ?? '';

    int childrenCount = 0;
    if (gender == 'male') {
      final wifeId = marriage['wife_id'] as String?;
      final wifeName = marriage['wife_external_name'] as String?;
      for (final child in _children) {
        if (wifeId != null && child['mother_id'] == wifeId) {
          childrenCount++;
        } else if (wifeName != null && child['mother_external_name'] == wifeName) {
          childrenCount++;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFE91E8C).withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE91E8C).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$order',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE91E8C),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isExternal) ...[
                      SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'خارجية',
                          style: TextStyle(fontSize: 9, color: AppColors.accentAmber),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      isCurrent ? '💍 حالية' : '📝 سابقة',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (childrenCount > 0) ...[
                      Container(
                        width: 3, height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textSecondary.withOpacity(0.4),
                        ),
                      ),
                      Text(
                        '$childrenCount أبناء',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                    if (marriageDate.isNotEmpty) ...[
                      Container(
                        width: 3, height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textSecondary.withOpacity(0.4),
                        ),
                      ),
                      Text(
                        marriageDate,
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => _showEditMarriageDialog(marriage),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.edit_rounded, size: 16, color: AppColors.gold),
                      ),
                    ),
                    SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _deleteMarriage(marriage),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.accentRed.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.delete_rounded, size: 16, color: AppColors.accentRed),
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

  bool _isCurrentUser() {
    final authUser = SupabaseConfig.client.auth.currentUser;
    if (authUser == null) return false;
    final personAuthId = _personData?['auth_user_id'] as String?;
    return personAuthId == authUser.id;
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
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (legacyId != null)
                  Text(
                    legacyId,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
          SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showEditChildDialog(child),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.edit_rounded, size: 16, color: AppColors.gold),
            ),
          ),
          SizedBox(width: 6),
          GestureDetector(
            onTap: () => _deleteChild(child),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_rounded, size: 16, color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditChildDialog(Map<String, dynamic> child) {
    final nameController = TextEditingController(text: child['name'] as String? ?? '');
    final birthDate = child['birth_date'] as String?;
    final childMotherId = child['mother_id'] as String?;
    final childMotherExternalName = child['mother_external_name'] as String?;
    DateTime? selectedDate = birthDate != null ? DateTime.tryParse(birthDate) : null;
    Map<String, dynamic>? selectedMotherMarriage;
    String? nameError;
    String? motherError;

    if (_marriages.isNotEmpty) {
      for (final marriage in _marriages) {
        final wifeId = marriage['wife_id'] as String?;
        final wifeExternalName = marriage['wife_external_name'] as String?;
        final matchedById = childMotherId != null && wifeId == childMotherId;
        final matchedByExternalName = childMotherExternalName != null && wifeExternalName == childMotherExternalName;
        if (matchedById || matchedByExternalName) {
          selectedMotherMarriage = marriage;
          break;
        }
      }
    }

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
                          color: AppColors.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.edit_rounded, color: AppColors.gold, size: 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('تعديل بيانات الابن',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  _buildDialogLabel('الاسم *'),
                  SizedBox(height: 6),
                  _buildDialogTextField(nameController, 'الاسم',
                      onChanged: (v) => setModalState(() => nameError = null)),
                  if (nameError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(nameError!, style: TextStyle(color: AppColors.accentRed, fontSize: 12)),
                    ),
                  SizedBox(height: 16),
                  _buildDialogLabel('الأم *'),
                  SizedBox(height: 6),
                  if (_marriages.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accentAmber.withOpacity(0.2)),
                      ),
                      child: Text(
                        '⚠️ لا توجد زوجات مسجلة — أضف زوجة من قسم الزوجات أعلاه ثم عد لتعديل الأم',
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
                              ? _marriages.indexOf(selectedMotherMarriage!)
                              : null,
                          hint: Text('اختر الأم', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          isExpanded: true,
                          dropdownColor: AppColors.bgCard,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          items: _marriages.asMap().entries.map((entry) {
                            final m = entry.value;
                            final name = m['wife_name'] as String? ?? m['wife_external_name'] as String? ?? 'غير معروفة';
                            final isExt = m['is_external'] as bool? ?? false;
                            return DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text('$name${isExt ? " (خارجية)" : ""}'),
                            );
                          }).toList(),
                          onChanged: (index) {
                            if (index != null) {
                              setModalState(() {
                                selectedMotherMarriage = _marriages[index];
                                motherError = null;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  if (motherError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(motherError!, style: TextStyle(color: AppColors.accentRed, fontSize: 12)),
                    ),
                  SizedBox(height: 16),
                  _buildDialogLabel('تاريخ الميلاد'),
                  SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppColors.gold,
                              surface: AppColors.bgCard,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setModalState(() => selectedDate = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary, size: 18),
                          SizedBox(width: 10),
                          Text(
                            selectedDate != null
                                ? '${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}'
                                : 'اختر التاريخ',
                            style: TextStyle(
                              color: selectedDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          setModalState(() => nameError = 'الاسم مطلوب');
                          return;
                        }
                        if (_marriages.isNotEmpty && selectedMotherMarriage == null) {
                          setModalState(() => motherError = 'الرجاء اختيار الأم');
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        try {
                          await PersonService.updatePerson(
                            personId: child['id'] as String,
                            personData: {
                              'name': nameController.text.trim(),
                              'birth_date': selectedDate != null
                                  ? selectedDate!.toIso8601String().split('T').first
                                  : null,
                              'mother_id': selectedMotherMarriage?['wife_id'],
                              'mother_external_name': selectedMotherMarriage?['wife_external_name'],
                            },
                          );
                          messenger.showSnackBar(SnackBar(
                            content: Text('✅ تم تعديل البيانات بنجاح'),
                            backgroundColor: AppColors.accentGreen,
                          ));
                          _loadProfile();
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(
                            content: Text('❌ خطأ: $e'),
                            backgroundColor: AppColors.accentRed,
                          ));
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

  Future<void> _deleteChild(Map<String, dynamic> child) async {
    final childName = child['name'] as String? ?? '—';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text('حذف "$childName"',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text('هل أنت متأكد من حذف هذا الشخص؟ لا يمكن التراجع.',
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

    final error = await PersonService.deletePerson(child['id'] as String);

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ لا يمكن الحذف: $error'),
          backgroundColor: AppColors.accentRed,
        ));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ تم حذف "$childName" بنجاح'),
        backgroundColor: AppColors.accentGreen,
      ));
      _loadProfile();
    }
  }

  // ═══════════════════════════════════════════
  // ديالوج تعديل البيانات الشخصية
  // ═══════════════════════════════════════════
  void _showEditPersonalDialog() {
    final nameCtrl = TextEditingController(text: _personData?['name'] ?? '');
    final jobCtrl = TextEditingController(text: _personData?['job'] ?? '');
    final educationCtrl = TextEditingController(text: _personData?['education'] ?? '');
    final residenceCtrl = TextEditingController(text: _personData?['residence_city'] ?? '');
    final birthCityCtrl = TextEditingController(text: _personData?['birth_city'] ?? '');
    final birthCountryCtrl = TextEditingController(text: _personData?['birth_country'] ?? '');
    final birthDateCtrl = TextEditingController(text: _personData?['birth_date'] ?? '');
    String selectedGender = _personData?['gender'] ?? 'male';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black54,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              top: 24, right: 24, left: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: StatefulBuilder(
                builder: (context, setModalState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text('تعديل البيانات الشخصية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                  SizedBox(height: 20),
                  _buildTextField(nameCtrl, 'الاسم', Icons.badge_rounded),
                  _buildTextField(jobCtrl, 'الوظيفة', Icons.work_rounded),
                  _buildTextField(educationCtrl, 'التعليم', Icons.school_rounded),
                  _buildTextField(residenceCtrl, 'مدينة الإقامة', Icons.home_rounded),
                  _buildTextField(birthCityCtrl, 'مدينة الميلاد', Icons.location_city_rounded),
                  _buildTextField(birthCountryCtrl, 'بلد الميلاد', Icons.public_rounded),
                  _buildDialogLabel('الجنس'),
                  SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => setModalState(() => selectedGender = 'male'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedGender == 'male' ? AppColors.gold.withOpacity(0.15) : AppColors.bgDeep.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selectedGender == 'male' ? AppColors.gold : Colors.white.withOpacity(0.06)),
                        ),
                        child: Center(child: Text('ذكر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selectedGender == 'male' ? AppColors.gold : AppColors.textSecondary))),
                      ),
                    )),
                    SizedBox(width: 8),
                    Expanded(child: GestureDetector(
                      onTap: () => setModalState(() => selectedGender = 'female'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedGender == 'female' ? AppColors.gold.withOpacity(0.15) : AppColors.bgDeep.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selectedGender == 'female' ? AppColors.gold : Colors.white.withOpacity(0.06)),
                        ),
                        child: Center(child: Text('أنثى', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selectedGender == 'female' ? AppColors.gold : AppColors.textSecondary))),
                      ),
                    )),
                  ]),
                  SizedBox(height: 12),
                  _buildDialogLabel('تاريخ الميلاد (YYYY-MM-DD)'),
                  SizedBox(height: 6),
                  _buildDialogTextField(birthDateCtrl, 'مثال: 1990-01-15'),
                  SizedBox(height: 12),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                    onPressed: () async {
                      try {
                        await PersonService.updatePerson(
                          personId: _personData!['id'] as String,
                          personData: {
                            'name': nameCtrl.text.trim(),
                            'job': jobCtrl.text.trim().isEmpty ? null : jobCtrl.text.trim(),
                            'education': educationCtrl.text.trim().isEmpty ? null : educationCtrl.text.trim(),
                            'residence_city': residenceCtrl.text.trim().isEmpty ? null : residenceCtrl.text.trim(),
                            'birth_city': birthCityCtrl.text.trim().isEmpty ? null : birthCityCtrl.text.trim(),
                            'birth_country': birthCountryCtrl.text.trim().isEmpty ? null : birthCountryCtrl.text.trim(),
                            'gender': selectedGender,
                            'birth_date': birthDateCtrl.text.trim().isEmpty ? null : birthDateCtrl.text.trim(),
                          },
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ تم تحديث البيانات بنجاح')),
                          );
                          Navigator.pop(context);
                          _loadProfile();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ خطأ في التحديث: $e')),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                ],
                ),
              ),
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
      useSafeArea: true,
      barrierColor: Colors.black54,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              top: 24, right: 24, left: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text('تعديل بيانات التواصل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                SizedBox(height: 20),
                _buildTextField(phoneCtrl, 'رقم الجوال', Icons.phone_rounded, keyboardType: TextInputType.phone),
                _buildTextField(emailCtrl, 'الإيميل', Icons.email_rounded, keyboardType: TextInputType.emailAddress),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await PersonService.upsertContact(_personData!['id'] as String, {
                          'mobile_phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ تم تحديث بيانات التواصل بنجاح')),
                          );
                          Navigator.pop(context);
                          _loadProfile();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ خطأ في التحديث: $e')),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
      useSafeArea: true,
      barrierColor: Colors.black54,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              top: 24, right: 24, left: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text('تعديل وسائل التواصل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                SizedBox(height: 20),
                _buildTextField(instagramCtrl, 'Instagram', Icons.camera_alt_rounded),
                _buildTextField(twitterCtrl, 'Twitter', Icons.alternate_email_rounded),
                _buildTextField(snapchatCtrl, 'Snapchat', Icons.photo_camera_front_rounded),
                _buildTextField(facebookCtrl, 'Facebook', Icons.facebook_rounded),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await PersonService.upsertContact(_personData!['id'] as String, {
                          'instagram': instagramCtrl.text.trim().isEmpty ? null : instagramCtrl.text.trim(),
                          'twitter': twitterCtrl.text.trim().isEmpty ? null : twitterCtrl.text.trim(),
                          'snapchat': snapchatCtrl.text.trim().isEmpty ? null : snapchatCtrl.text.trim(),
                          'facebook': facebookCtrl.text.trim().isEmpty ? null : facebookCtrl.text.trim(),
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ تم تحديث بيانات التواصل بنجاح')),
                          );
                          Navigator.pop(context);
                          _loadProfile();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ خطأ في التحديث: $e')),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgDeep,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  // ═══════════════════════════════════════════
  // ديالوج إضافة ابن
  // ═══════════════════════════════════════════
  void _showAddChildDialog() {
    final nameController = TextEditingController();
    final birthCityController = TextEditingController();
    final birthCountryController = TextEditingController();
    String selectedGender = 'male';
    DateTime? selectedDate;
    Map<String, dynamic>? selectedMotherMarriage;
    String? childNameError;
    String? motherError;

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
                  // العنوان
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.person_add_rounded, color: AppColors.gold, size: 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'إضافة ابن/ابنة',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
                  SizedBox(height: 8),
                  Text(
                    'سيتم توليد رقم QF تلقائياً',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7)),
                  ),
                  SizedBox(height: 20),

                  // الاسم (مطلوب)
                  _buildDialogLabel('الاسم *'),
                  SizedBox(height: 6),
                  _buildDialogTextField(
                    nameController,
                    'أدخل اسم الابن/الابنة',
                    onChanged: (v) => setModalState(() => childNameError = null),
                  ),
                  if (childNameError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        childNameError!,
                        style: const TextStyle(color: AppColors.accentRed, fontSize: 12),
                      ),
                    ),
                  SizedBox(height: 16),

                  // الجنس
                  _buildDialogLabel('الجنس *'),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedGender = 'male'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedGender == 'male'
                                  ? AppColors.accentBlue.withOpacity(0.15)
                                  : AppColors.bgDeep.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedGender == 'male'
                                    ? AppColors.accentBlue
                                    : Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('👨', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 6),
                                Text(
                                  'ذكر',
                                  style: TextStyle(
                                    color: selectedGender == 'male' ? AppColors.accentBlue : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedGender = 'female'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedGender == 'female'
                                  ? const Color(0xFFE91E8C).withOpacity(0.15)
                                  : AppColors.bgDeep.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedGender == 'female'
                                    ? const Color(0xFFE91E8C)
                                    : Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('👩', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 6),
                                Text(
                                  'أنثى',
                                  style: TextStyle(
                                    color: selectedGender == 'female' ? const Color(0xFFE91E8C) : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // اختيار الأم (من زوجات الأب)
                  _buildDialogLabel('الأم *'),
                  SizedBox(height: 6),
                  if (_marriages.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accentAmber.withOpacity(0.2)),
                      ),
                      child: Text(
                        '⚠️ لا توجد زوجات مسجلة — أضف زوجة من قسم الزوجات أعلاه ثم عد لإضافة الابن',
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
                              ? _marriages.indexOf(selectedMotherMarriage!)
                              : null,
                          hint: Text('اختر الأم', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          isExpanded: true,
                          dropdownColor: AppColors.bgCard,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          items: _marriages.asMap().entries.map((entry) {
                            final m = entry.value;
                            final name = m['wife_name'] as String? ?? m['wife_external_name'] as String? ?? 'غير معروفة';
                            final isExt = m['is_external'] as bool? ?? false;
                            return DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text('$name${isExt ? " (خارجية)" : ""}'),
                            );
                          }).toList(),
                          onChanged: (index) {
                            if (index != null) {
                              setModalState(() {
                                selectedMotherMarriage = _marriages[index];
                                motherError = null;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  if (motherError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        motherError!,
                        style: const TextStyle(color: AppColors.accentRed, fontSize: 12),
                      ),
                    ),
                  SizedBox(height: 16),

                  // تاريخ الميلاد
                  _buildDialogLabel('تاريخ الميلاد'),
                  SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppColors.gold,
                              surface: AppColors.bgCard,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bgDeep.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary, size: 18),
                          SizedBox(width: 10),
                          Text(
                            selectedDate != null
                                ? '${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}'
                                : 'اختر التاريخ',
                            style: TextStyle(
                              color: selectedDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // مدينة الميلاد + الدولة (صف واحد)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDialogLabel('مدينة الميلاد'),
                            SizedBox(height: 6),
                            _buildDialogTextField(birthCityController, 'المدينة'),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDialogLabel('الدولة'),
                            SizedBox(height: 6),
                            _buildDialogTextField(birthCountryController, 'الدولة'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // زر الإضافة
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          setModalState(() => childNameError = 'الرجاء إدخال الاسم');
                          return;
                        }
                        if (_marriages.isNotEmpty && selectedMotherMarriage == null) {
                          setModalState(() => motherError = 'الرجاء اختيار الأم');
                          return;
                        }
                        try {
                          final parentId = _personData!['id'] as String;
                          final parentGeneration = _personData!['generation'] as int? ?? 0;
                          final childGeneration = parentGeneration + 1;
                          final name = nameController.text.trim();
                          final qfId = await PersonService.addPerson(
                            name: name,
                            gender: selectedGender,
                            generation: childGeneration,
                            fatherId: parentId,
                            motherId: selectedMotherMarriage?['wife_id'] as String?,
                            motherExternalName: selectedMotherMarriage?['wife_external_name'] as String?,
                            birthDate: selectedDate,
                            birthCity: birthCityController.text.trim().isEmpty ? null : birthCityController.text.trim(),
                            birthCountry: birthCountryController.text.trim().isEmpty ? null : birthCountryController.text.trim(),
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ تمت إضافة $name بنجاح (رقم العضوية: $qfId)'),
                                backgroundColor: AppColors.accentGreen,
                              ),
                            );
                            _loadProfile();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ خطأ في الإضافة: $e'),
                                backgroundColor: AppColors.accentRed,
                              ),
                            );
                          }
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'إضافة',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
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

  Widget _buildDialogLabel(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String hint, {ValueChanged<String>? onChanged}) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
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

  Future<void> _showAddMarriageDialog() async {
    List<Map<String, dynamic>> femalesList = [];
    try {
      final response = await SupabaseConfig.client
          .from('people')
          .select('id, name, legacy_user_id')
          .eq('gender', 'female')
          .order('name');
      femalesList = List<Map<String, dynamic>>.from(response);
    } catch (_) {}

    final externalNameController = TextEditingController();
    final wifeQfController = TextEditingController();
    bool isExternalWife = false;
    Map<String, dynamic>? selectedWife;
    String? wifeSearchError;
    String? submitError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black54,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
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
                          child: Icon(Icons.favorite_rounded, color: Color(0xFFE91E8C), size: 20),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('إضافة زوجة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                    SizedBox(height: 20),

                    _buildDialogLabel('الزوجة'),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() { isExternalWife = false; submitError = null; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isExternalWife ? AppColors.gold.withOpacity(0.15) : AppColors.bgDeep.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: !isExternalWife ? AppColors.gold : Colors.white.withOpacity(0.06)),
                              ),
                              child: Center(
                                child: Text('من العائلة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: !isExternalWife ? AppColors.gold : AppColors.textSecondary)),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() { isExternalWife = true; submitError = null; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isExternalWife ? AppColors.gold.withOpacity(0.15) : AppColors.bgDeep.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isExternalWife ? AppColors.gold : Colors.white.withOpacity(0.06)),
                              ),
                              child: Center(
                                child: Text('من خارج العائلة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isExternalWife ? AppColors.gold : AppColors.textSecondary)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    if (!isExternalWife) ...[
                      Row(
                        children: [
                          Expanded(child: _buildDialogTextField(wifeQfController, 'أدخل رقم QF للزوجة')),
                          SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              final qf = wifeQfController.text.trim().toUpperCase();
                              if (qf.isEmpty) {
                                setModalState(() => selectedWife = null);
                                return;
                              }
                              final found = femalesList.where(
                                (p) => (p['legacy_user_id'] ?? '').toString().toUpperCase() == qf,
                              ).toList();
                              if (found.isNotEmpty) {
                                setModalState(() {
                                  selectedWife = found.first;
                                  wifeSearchError = null;
                                  submitError = null;
                                });
                              } else {
                                setModalState(() => wifeSearchError = 'لم يتم العثور على زوجة برقم $qf');
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
                      if (wifeSearchError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(wifeSearchError!, style: TextStyle(color: AppColors.accentRed, fontSize: 12)),
                        ),
                    ],
                    if (!isExternalWife && selectedWife != null) ...[
                      SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accentGreen.withOpacity(0.2)),
                        ),
                        child: Text(
                          '${selectedWife!['name']} (${selectedWife!['legacy_user_id']})',
                          style: TextStyle(fontSize: 13, color: AppColors.accentGreen),
                        ),
                      ),
                    ],
                    if (isExternalWife)
                      _buildDialogTextField(externalNameController, 'اكتب اسم الزوجة'),

                    SizedBox(height: 24),

                    if (submitError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(submitError!, style: TextStyle(color: AppColors.accentRed, fontSize: 12)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () async {
                          if (!isExternalWife && selectedWife == null) {
                            setModalState(() => submitError = 'الرجاء اختيار الزوجة');
                            return;
                          }
                          if (isExternalWife && externalNameController.text.trim().isEmpty) {
                            setModalState(() => submitError = 'الرجاء كتابة اسم الزوجة');
                            return;
                          }

                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);

                          try {
                            final personId = _personData!['id'] as String;
                            await PersonService.addMarriage(
                              husbandId: personId,
                              wifeId: !isExternalWife ? selectedWife!['id'] as String? : null,
                              externalName: isExternalWife ? externalNameController.text.trim() : null,
                            );
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text('✅ تمت إضافة الزوجة بنجاح'), backgroundColor: AppColors.accentGreen),
                            );
                            if (mounted) _loadProfile();
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: AppColors.accentRed),
                            );
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
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteMarriage(Map<String, dynamic> marriage) async {
    final wifeName = marriage['wife_name'] as String? ?? marriage['wife_external_name'] as String? ?? '—';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text('حذف الزوجة "$wifeName"',
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

    final error = await PersonService.deleteMarriage(
      marriageId: marriage['id'] as String,
      husbandId: _personData!['id'] as String,
      wifeId: marriage['wife_id'] as String?,
      wifeExternalName: marriage['wife_external_name'] as String?,
    );

    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ لا يمكن الحذف: $error'),
          backgroundColor: AppColors.accentRed,
        ));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ تم حذف الزوجة بنجاح'),
        backgroundColor: AppColors.accentGreen,
      ));
      _loadProfile();
    }
  }

  void _showEditMarriageDialog(Map<String, dynamic> marriage) {
    bool isCurrent = marriage['is_current'] as bool? ?? true;

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
                      child: Icon(Icons.edit_rounded, color: const Color(0xFFE91E8C), size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('تعديل بيانات الزواج',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                _buildDialogLabel('حالة الزواج'),
                SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isCurrent = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isCurrent ? AppColors.accentGreen.withOpacity(0.15) : AppColors.bgDeep.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isCurrent ? AppColors.accentGreen : Colors.white.withOpacity(0.06)),
                          ),
                          child: Center(child: Text('حالي', style: TextStyle(
                            color: isCurrent ? AppColors.accentGreen : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ))),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isCurrent = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isCurrent ? AppColors.accentRed.withOpacity(0.15) : AppColors.bgDeep.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: !isCurrent ? AppColors.accentRed : Colors.white.withOpacity(0.06)),
                          ),
                          child: Center(child: Text('سابق', style: TextStyle(
                            color: !isCurrent ? AppColors.accentRed : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ))),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        await PersonService.updateMarriage(
                          marriageId: marriage['id'] as String,
                          isCurrent: isCurrent,
                        );
                        messenger.showSnackBar(SnackBar(
                          content: Text('✅ تم تعديل بيانات الزواج بنجاح'),
                          backgroundColor: AppColors.accentGreen,
                        ));
                        _loadProfile();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('❌ خطأ: $e'),
                          backgroundColor: AppColors.accentRed,
                        ));
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
    );
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
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
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
                      child: Row(
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
          SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
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
        style: TextStyle(color: AppColors.textPrimary),
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
              SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePinDialog() {
    final currentPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black54,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setModalState) => Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.only(
                top: 24, right: 24, left: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.lock_rounded, color: AppColors.gold, size: 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('تغيير الرقم السري', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                  SizedBox(height: 20),
                  _buildPinField(currentPinCtrl, 'الرقم السري الحالي', Icons.lock_outline_rounded),
                  SizedBox(height: 12),
                  _buildPinField(newPinCtrl, 'الرقم السري الجديد', Icons.lock_rounded),
                  SizedBox(height: 12),
                  _buildPinField(confirmPinCtrl, 'تأكيد الرقم السري الجديد', Icons.lock_rounded),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: isLoading ? null : () async {
                        final currentPin = currentPinCtrl.text.trim();
                        final newPin = newPinCtrl.text.trim();
                        final confirmPin = confirmPinCtrl.text.trim();

                        if (currentPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى ملء جميع الحقول'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (newPin.length != 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('الرقم السري يجب أن يكون 4 أرقام بالضبط'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('الرقم السري يجب أن يحتوي على أرقام فقط'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (newPin != confirmPin) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('الرقم السري الجديد غير متطابق'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        final storedPin = _personData?['pin_code'] as String?;
                        if (storedPin != currentPin) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('الرقم السري الحالي غير صحيح'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        setModalState(() => isLoading = true);

                        try {
                          final qfId = _personData?['legacy_user_id'] as String? ?? '';

                          await SupabaseConfig.client
                              .from('people')
                              .update({'pin_code': newPin})
                              .eq('id', _personData!['id']);

                          await SupabaseConfig.client.auth.updateUser(
                            UserAttributes(password: '${qfId.toUpperCase()}_$newPin'),
                          );

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ تم تغيير الرقم السري بنجاح'),
                                backgroundColor: AppColors.accentGreen,
                              ),
                            );
                            _loadProfile();
                          }
                        } catch (e) {
                          setModalState(() => isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: AppColors.accentRed),
                            );
                          }
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bgDeep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isLoading
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDeep))
                          : Text('تغيير الرقم السري', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      inputFormatters: [
        TextInputFormatter.withFunction((oldValue, newValue) {
          final converted = newValue.text
              .replaceAll('٠', '0').replaceAll('١', '1')
              .replaceAll('٢', '2').replaceAll('٣', '3')
              .replaceAll('٤', '4').replaceAll('٥', '5')
              .replaceAll('٦', '6').replaceAll('٧', '7')
              .replaceAll('٨', '8').replaceAll('٩', '9');
          return newValue.copyWith(text: converted);
        }),
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      style: TextStyle(color: AppColors.textPrimary, fontSize: 20, letterSpacing: 8),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        counterText: '',
        filled: true,
        fillColor: AppColors.bgDeep.withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.06))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gold)),
      ),
    );
  }

  Widget _buildThemeSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final current = themeProvider.themeMode;

    return _buildSection(
      title: 'المظهر',
      icon: Icons.palette_rounded,
      onEdit: null,
      children: [
        Row(
          children: [
            _buildThemeOption(
              label: 'داكن',
              icon: Icons.dark_mode_rounded,
              selected: current == ThemeMode.dark,
              onTap: () => themeProvider.setTheme(ThemeMode.dark),
            ),
            SizedBox(width: 8),
            _buildThemeOption(
              label: 'فاتح',
              icon: Icons.light_mode_rounded,
              selected: current == ThemeMode.light,
              onTap: () => themeProvider.setTheme(ThemeMode.light),
            ),
            SizedBox(width: 8),
            _buildThemeOption(
              label: 'تلقائي',
              icon: Icons.brightness_auto_rounded,
              selected: current == ThemeMode.system,
              onTap: () => themeProvider.setTheme(ThemeMode.system),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppColors.gold : AppColors.textSecondary, size: 22),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppColors.gold : AppColors.textSecondary,
                ),
              ),
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
            Icon(Icons.error_outline, size: 64, color: AppColors.accentRed),
            SizedBox(height: 16),
            Text(_error ?? 'حدث خطأ', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            SizedBox(height: 24),
            FilledButton(
              onPressed: _loadProfile,
              child: Text('إعادة المحاولة'),
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
