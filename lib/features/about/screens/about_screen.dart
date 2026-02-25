import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _isLoading = true;
  String? _error;

  int _totalCount = 0;
  int _maleCount = 0;
  int _femaleCount = 0;
  int _aliveCount = 0;
  int _deceasedCount = 0;

  List<Map<String, dynamic>> _familyInfo = [];
  String _lineageContent = '';
  String _aboutAppContent = '';
  String _whatsappNumber = '966501643437';
  String _smsNumber = '966555113730';
  String _email = 'support@alquwaizfamily.com';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Future.wait([_loadPeopleStats(), _loadFamilyInfo()]);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPeopleStats() async {
    final response = await SupabaseConfig.client
        .from('people')
        .select('id, gender, is_alive');

    final list = response as List;
    _totalCount = list.length;
    _maleCount = 0;
    _femaleCount = 0;
    _aliveCount = 0;
    _deceasedCount = 0;

    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final gender = (map['gender'] as String? ?? '').toLowerCase();
      final isAlive = map['is_alive'] as bool? ?? true;

      if (gender == 'male') _maleCount++;
      if (gender == 'female') _femaleCount++;
      if (isAlive) _aliveCount++;
      else _deceasedCount++;
    }
  }

  Future<void> _loadFamilyInfo() async {
    final response =
        await SupabaseConfig.client.from('family_info').select();
    _familyInfo = List<Map<String, dynamic>>.from(
      (response as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final lineage = _familyInfo
        .where((e) => (e['type'] as String? ?? '') == 'النسب')
        .toList();
    _lineageContent = lineage.isNotEmpty
        ? (lineage.first['content'] as String? ?? '')
        : '';

    final aboutApp = _familyInfo
        .where((e) => (e['type'] as String? ?? '') == 'عن التطبيق')
        .toList();
    _aboutAppContent = aboutApp.isNotEmpty
        ? (aboutApp.first['content'] as String? ?? '')
        : '';

    final whatsapp =
        _familyInfo.where((e) => (e['type'] as String? ?? '') == 'whatsapp');
    if (whatsapp.isNotEmpty) {
      final v = (whatsapp.first['content'] as String? ?? '')
          .replaceAll(RegExp(r'[^\d]'), '');
      if (v.isNotEmpty) _whatsappNumber = v;
    }
    final sms =
        _familyInfo.where((e) => (e['type'] as String? ?? '') == 'sms');
    if (sms.isNotEmpty) {
      final v = (sms.first['content'] as String? ?? '')
          .replaceAll(RegExp(r'[^\d]'), '');
      if (v.isNotEmpty) _smsNumber = v;
    }
    final email =
        _familyInfo.where((e) => (e['type'] as String? ?? '') == 'email');
    if (email.isNotEmpty) {
      final v = email.first['content'] as String? ?? '';
      if (v.isNotEmpty) _email = v;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('عن العائلة'),
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsSection(),
                        const SizedBox(height: 24),
                        _buildLineageSection(),
                        const SizedBox(height: 24),
                        _buildAboutAppSection(),
                        const SizedBox(height: 24),
                        _buildContactSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إحصائيات العائلة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatBox('الإجمالي', '$_totalCount', AppColors.gold),
                _buildStatBox('الرجال', '$_maleCount', Colors.blue.shade700),
                _buildStatBox('النساء', '$_femaleCount', Colors.pink.shade600),
                _buildStatBox('الأحياء', '$_aliveCount', AppColors.successGreen),
                _buildStatBox('المتوفين', '$_deceasedCount', AppColors.neutralGray),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_tree,
              color: AppColors.gold,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'نسب العائلة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            _lineageContent.isNotEmpty
                ? _lineageContent
                : 'لا يوجد محتوى للنسب حالياً.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutAppSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppColors.gold,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'عن التطبيق',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            _aboutAppContent.isNotEmpty
                ? _aboutAppContent
                : 'لا يوجد محتوى لعن التطبيق حالياً.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.contact_phone,
              color: AppColors.gold,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'تواصل معنا',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              _buildContactButton(
                label: 'واتساب',
                icon: Icons.chat,
                color: const Color(0xFF25D366),
                onTap: () => _launchUrl('https://wa.me/$_whatsappNumber'),
              ),
              const SizedBox(height: 10),
              _buildContactButton(
                label: 'رسالة SMS',
                icon: Icons.sms,
                color: Colors.blue.shade600,
                onTap: () => _launchUrl('sms:$_smsNumber'),
              ),
              const SizedBox(height: 10),
              _buildContactButton(
                label: 'إيميل',
                icon: Icons.email,
                color: Colors.red.shade600,
                onTap: () => _launchUrl('mailto:$_email'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildContactButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
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
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تحميل البيانات',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loadData,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
