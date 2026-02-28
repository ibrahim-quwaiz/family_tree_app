import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedType = 'تعديل بيانات';
  bool _isSending = false;

  // بيانات المرسل
  String? _senderName;
  String? _senderId;

  static const _requestTypes = [
    'تعديل بيانات',
    'إبلاغ عن خطأ',
    'إضافة خبر أو مناسبة',
    'اقتراح أو ملاحظة',
    'أخرى',
  ];

  static const _adminPhone = '966555113730';
  static const _adminEmail = 'ibrahim.sec@gmail.com';

  @override
  void initState() {
    super.initState();
    _loadSenderInfo();
  }

  Future<void> _loadSenderInfo() async {
    final name = await AuthService.getCurrentName();
    final id = await AuthService.getCurrentUserId();
    if (mounted) {
      setState(() {
        _senderName = name;
        _senderId = id;
      });
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDeep,
        appBar: AppBar(
          title: const Text('تواصل معنا'),
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
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // طرق التواصل السريعة
              _buildQuickContactSection(),
              const SizedBox(height: 24),
              // نموذج الطلب
              _buildRequestForm(),
              const SizedBox(height: 24),
              // الطلبات السابقة
              _buildPreviousRequests(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ─── طرق التواصل السريعة ───
  Widget _buildQuickContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('تواصل مباشر', Icons.flash_on_rounded),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildContactCard(
                icon: Icons.chat_rounded,
                title: 'واتساب',
                subtitle: 'رد سريع',
                color: const Color(0xFF25D366),
                onTap: _openWhatsApp,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildContactCard(
                icon: Icons.email_rounded,
                title: 'إيميل',
                subtitle: 'رسالة مفصلة',
                color: AppColors.accentBlue,
                onTap: _openEmail,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── نموذج إرسال طلب ───
  Widget _buildRequestForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('إرسال طلب', Icons.edit_note_rounded),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // نوع الطلب
                const Text(
                  'نوع الطلب',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      dropdownColor: AppColors.bgCard,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.gold),
                      items: _requestTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedType = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // الموضوع
                const Text(
                  'الموضوع',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _subjectController,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'اكتب موضوع الطلب...',
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
                      borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'الرجاء كتابة الموضوع';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // الرسالة
                const Text(
                  'التفاصيل',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageController,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'اكتب تفاصيل طلبك هنا...',
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
                      borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'الرجاء كتابة التفاصيل';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // زر الإرسال
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isSending ? null : _submitRequest,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bgDeep,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDeep),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('إرسال الطلب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── الطلبات السابقة ───
  Widget _buildPreviousRequests() {
    if (_senderId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('طلباتي السابقة', Icons.history_rounded),
        const SizedBox(height: 12),
        FutureBuilder(
          future: SupabaseConfig.client
              .from('support_requests')
              .select()
              .eq('sender_id', _senderId!)
              .order('created_at', ascending: false)
              .limit(5),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold.withOpacity(0.5)),
                  ),
                ),
              );
            }

            final data = snapshot.data as List? ?? [];

            if (data.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, color: AppColors.textSecondary.withOpacity(0.3), size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'لا توجد طلبات سابقة',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withOpacity(0.5)),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: data.map((item) {
                final map = item as Map<String, dynamic>;
                return _buildRequestCard(map);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] as String? ?? 'جديد';
    final statusConfig = _getStatusConfig(status);
    final createdAt = request['created_at'] != null ? DateTime.tryParse(request['created_at']) : null;
    final adminReply = request['admin_reply'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (statusConfig['color'] as Color).withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (statusConfig['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusConfig['icon'] as IconData, size: 12, color: statusConfig['color'] as Color),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusConfig['color'] as Color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  request['request_type'] as String? ?? '',
                  style: const TextStyle(fontSize: 10, color: AppColors.gold, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              if (createdAt != null)
                Text(
                  _getTimeAgo(createdAt),
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withOpacity(0.5)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request['subject'] as String? ?? '',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            request['message'] as String? ?? '',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7), height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (adminReply != null && adminReply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentGreen.withOpacity(0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply_rounded, size: 16, color: AppColors.accentGreen.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رد الإدارة',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accentGreen.withOpacity(0.8)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          adminReply,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.8), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── عنوان قسم ───
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: AppColors.gold, size: 18),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  // ─── الدوال ───
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      await SupabaseConfig.client.from('support_requests').insert({
        'sender_id': _senderId,
        'sender_name': _senderName,
        'request_type': _selectedType,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'جديد',
      });

      if (mounted) {
        _subjectController.clear();
        _messageController.clear();
        setState(() {
          _isSending = false;
          _selectedType = 'تعديل بيانات';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 20),
                SizedBox(width: 8),
                Text('تم إرسال طلبك بنجاح'),
              ],
            ),
            backgroundColor: AppColors.bgCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // تحديث الطلبات السابقة
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: AppColors.accentRed, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('حدث خطأ: $e')),
              ],
            ),
            backgroundColor: AppColors.bgCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp() async {
    final message = 'السلام عليكم، أنا ${_senderName ?? ''} من تطبيق عائلة القويز';
    final url = Uri.parse('https://wa.me/$_adminPhone?text=${Uri.encodeComponent(message)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('لم يتم العثور على تطبيق واتساب'),
            backgroundColor: AppColors.bgCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _openEmail() async {
    final subject = 'تواصل من تطبيق عائلة القويز - ${_senderName ?? ''}';
    final url = Uri.parse('mailto:$_adminEmail?subject=${Uri.encodeComponent(subject)}');
    try {
      await launchUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('لم يتم العثور على تطبيق البريد'),
            backgroundColor: AppColors.bgCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'جديد':
        return {'color': AppColors.accentAmber, 'icon': Icons.fiber_new_rounded};
      case 'قيد المراجعة':
        return {'color': AppColors.accentBlue, 'icon': Icons.hourglass_top_rounded};
      case 'تم الرد':
        return {'color': AppColors.accentGreen, 'icon': Icons.check_circle_rounded};
      case 'مغلق':
        return {'color': AppColors.neutralGray, 'icon': Icons.lock_rounded};
      default:
        return {'color': AppColors.textSecondary, 'icon': Icons.help_outline_rounded};
    }
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return 'منذ ${diff.inDays ~/ 365} سنة';
    if (diff.inDays > 30) return 'منذ ${diff.inDays ~/ 30} شهر';
    if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';
    return 'الآن';
  }
}
